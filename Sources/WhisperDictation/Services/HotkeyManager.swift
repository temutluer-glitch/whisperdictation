import Foundation
import AppKit
import HotKey

@MainActor
final class HotkeyManager {
    private var hotKeys: [UUID: HotKey] = [:]
    private var bindings: [UUID: HotkeyBinding] = [:]
    private var flagsMonitor: Any?
    private var pressedBindingID: UUID?
    private var pressedRequiredModifiers: NSEvent.ModifierFlags = []
    private var modifierOnlyHeld: Set<UUID> = []

    var onPress: ((UUID) -> Void)?
    var onRelease: ((UUID) -> Void)?

    func register(bindings: [HotkeyBinding]) {
        unregisterAll()

        for binding in bindings {
            register(binding: binding)
        }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event: event) }
        }
    }

    func unregisterAll() {
        hotKeys.removeAll()
        bindings.removeAll()
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
        flagsMonitor = nil
        pressedBindingID = nil
        pressedRequiredModifiers = []
        modifierOnlyHeld.removeAll()
    }

    private func register(binding: HotkeyBinding) {
        bindings[binding.id] = binding

        if binding.config.isModifierOnly {
            return
        }

        guard let key = binding.config.hotKeyKey else {
            DebugLog.write("HotkeyManager invalid keyCode=\(binding.config.keyCode)")
            return
        }
        let modifiers = binding.config.nsEventModifiers
        let hk = HotKey(key: key, modifiers: modifiers)
        let id = binding.id
        hk.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.handleKeyDown(bindingID: id)
            }
        }
        hotKeys[id] = hk
    }

    private func handleKeyDown(bindingID: UUID) {
        guard let binding = bindings[bindingID] else { return }
        switch binding.mode {
        case .holdToTalk:
            guard pressedBindingID == nil else { return }
            pressedBindingID = bindingID
            pressedRequiredModifiers = binding.config.nsEventModifiers
            onPress?(bindingID)
        case .toggle:
            if pressedBindingID == bindingID {
                pressedBindingID = nil
                onRelease?(bindingID)
            } else if pressedBindingID == nil {
                pressedBindingID = bindingID
                onPress?(bindingID)
            }
        }
    }

    private func handleFlagsChanged(event: NSEvent) {
        let rawFlags = UInt(event.modifierFlags.rawValue)

        for binding in bindings.values {
            guard let modOnly = binding.config.modifierOnly else { continue }
            let mask = modOnly.deviceMask
            let isPressed = (rawFlags & mask) != 0
            let wasHeld = modifierOnlyHeld.contains(binding.id)

            switch binding.mode {
            case .holdToTalk:
                if isPressed && !wasHeld {
                    modifierOnlyHeld.insert(binding.id)
                    onPress?(binding.id)
                } else if !isPressed && wasHeld {
                    modifierOnlyHeld.remove(binding.id)
                    onRelease?(binding.id)
                }
            case .toggle:
                if isPressed && !wasHeld {
                    modifierOnlyHeld.insert(binding.id)
                    if pressedBindingID == binding.id {
                        pressedBindingID = nil
                        onRelease?(binding.id)
                    } else if pressedBindingID == nil {
                        pressedBindingID = binding.id
                        onPress?(binding.id)
                    }
                } else if !isPressed && wasHeld {
                    modifierOnlyHeld.remove(binding.id)
                }
            }
        }

        guard let id = pressedBindingID,
              let binding = bindings[id],
              binding.mode == .holdToTalk,
              !binding.config.isModifierOnly else { return }

        let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !current.isSuperset(of: pressedRequiredModifiers) {
            pressedBindingID = nil
            pressedRequiredModifiers = []
            onRelease?(id)
        }
    }
}
