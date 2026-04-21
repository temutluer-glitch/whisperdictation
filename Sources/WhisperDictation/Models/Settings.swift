import Foundation
import AppKit
import HotKey
import Carbon.HIToolbox

enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case holdToTalk
    case toggle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .holdToTalk: return "Hold-to-Talk (halten & sprechen)"
        case .toggle: return "Toggle (einmal drücken = start, nochmal = stop)"
        }
    }
}

struct HotkeyBinding: Codable, Identifiable, Equatable {
    var id: UUID
    var presetID: UUID
    var config: HotkeyConfig
    var mode: HotkeyMode

    init(id: UUID = UUID(), presetID: UUID, config: HotkeyConfig, mode: HotkeyMode = .holdToTalk) {
        self.id = id
        self.presetID = presetID
        self.config = config
        self.mode = mode
    }
}

enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    case largeV3Turbo = "whisper-large-v3-turbo"
    case largeV3 = "whisper-large-v3"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .largeV3Turbo: return "Large v3 Turbo (schnell, Default)"
        case .largeV3: return "Large v3 (genauer, für seltene Sprachen)"
        }
    }
}

enum OutputMode: String, Codable, CaseIterable, Identifiable {
    case pasteIntoActiveApp
    case clipboardOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pasteIntoActiveApp: return "In aktive App einfügen (Cmd+V)"
        case .clipboardOnly: return "Nur in Zwischenablage"
        }
    }
}

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt32

    static let defaultConfig = HotkeyConfig(
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(optionKey)
    )

    var hotKeyKey: Key? {
        Key(carbonKeyCode: keyCode)
    }

    var nsEventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifierFlags & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if modifierFlags & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifierFlags & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifierFlags & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    var displayString: String {
        var parts: [String] = []
        if modifierFlags & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifierFlags & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifierFlags & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifierFlags & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let key = Key(carbonKeyCode: keyCode) {
                return String(describing: key).uppercased()
            }
            return "?"
        }
    }
}
