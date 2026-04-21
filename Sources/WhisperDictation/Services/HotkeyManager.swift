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
    }

    private func register(binding: HotkeyBinding) {
        guard let key = binding.config.hotKeyKey else {
            NSLog("HotkeyManager: invalid key code \(binding.config.keyCode)")
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
        bindings[id] = binding
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
        guard let id = pressedBindingID,
              let binding = bindings[id],
              binding.mode == .holdToTalk else { return }

        let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !current.isSuperset(of: pressedRequiredModifiers) {
            pressedBindingID = nil
            pressedRequiredModifiers = []
            onRelease?(id)
        }
    }
}
