import Foundation
import AppKit
import HotKey

@MainActor
final class HotkeyManager {
    private var hotKey: HotKey?
    private var flagsMonitor: Any?
    private var isKeyDown = false
    private var currentMode: HotkeyMode = .holdToTalk
    private var requiredModifiers: NSEvent.ModifierFlags = []

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    func register(config: HotkeyConfig, mode: HotkeyMode) {
        unregister()
        guard let key = config.hotKeyKey else {
            NSLog("HotkeyManager: invalid key code \(config.keyCode)")
            return
        }

        currentMode = mode
        requiredModifiers = config.nsEventModifiers

        let hk = HotKey(key: key, modifiers: requiredModifiers)
        hk.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.handleKeyDown()
            }
        }
        self.hotKey = hk

        if mode == .holdToTalk && !requiredModifiers.isEmpty {
            flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                Task { @MainActor in
                    self?.handleFlagsChanged(event: event)
                }
            }
        }
    }

    func unregister() {
        hotKey = nil
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
        flagsMonitor = nil
        isKeyDown = false
    }

    private func handleKeyDown() {
        switch currentMode {
        case .holdToTalk:
            guard !isKeyDown else { return }
            isKeyDown = true
            onPress?()
        case .toggle:
            if isKeyDown {
                isKeyDown = false
                onRelease?()
            } else {
                isKeyDown = true
                onPress?()
            }
        }
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard isKeyDown, currentMode == .holdToTalk else { return }
        let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !current.isSuperset(of: requiredModifiers) {
            isKeyDown = false
            onRelease?()
        }
    }
}
