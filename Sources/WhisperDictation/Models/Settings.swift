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

enum ModifierKey: String, Codable, CaseIterable, Identifiable {
    case leftOption
    case rightOption
    case leftCommand
    case rightCommand
    case leftControl
    case rightControl
    case leftShift
    case rightShift
    case function

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leftOption: return "Linke Option (⌥)"
        case .rightOption: return "Rechte Option (⌥)"
        case .leftCommand: return "Linke Command (⌘)"
        case .rightCommand: return "Rechte Command (⌘)"
        case .leftControl: return "Linker Control (⌃)"
        case .rightControl: return "Rechter Control (⌃)"
        case .leftShift: return "Linke Shift (⇧)"
        case .rightShift: return "Rechte Shift (⇧)"
        case .function: return "Fn-Taste"
        }
    }

    var shortSymbol: String {
        switch self {
        case .leftOption: return "⌥ L"
        case .rightOption: return "⌥ R"
        case .leftCommand: return "⌘ L"
        case .rightCommand: return "⌘ R"
        case .leftControl: return "⌃ L"
        case .rightControl: return "⌃ R"
        case .leftShift: return "⇧ L"
        case .rightShift: return "⇧ R"
        case .function: return "fn"
        }
    }

    var deviceMask: UInt {
        switch self {
        case .leftControl:   return 0x00000001
        case .leftShift:     return 0x00000002
        case .rightShift:    return 0x00000004
        case .leftCommand:   return 0x00000008
        case .rightCommand:  return 0x00000010
        case .leftOption:    return 0x00000020
        case .rightOption:   return 0x00000040
        case .rightControl:  return 0x00002000
        case .function:      return UInt(NSEvent.ModifierFlags.function.rawValue)
        }
    }

    static func detect(from rawFlags: UInt) -> ModifierKey? {
        for key in ModifierKey.allCases where key != .function {
            if rawFlags & key.deviceMask != 0 { return key }
        }
        if rawFlags & ModifierKey.function.deviceMask != 0 { return .function }
        return nil
    }
}

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt32
    var modifierOnly: ModifierKey?

    static let defaultConfig = HotkeyConfig(
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(optionKey),
        modifierOnly: nil
    )

    init(keyCode: UInt32, modifierFlags: UInt32, modifierOnly: ModifierKey? = nil) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.modifierOnly = modifierOnly
    }

    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
        case modifierOnly
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.keyCode = try c.decode(UInt32.self, forKey: .keyCode)
        self.modifierFlags = try c.decode(UInt32.self, forKey: .modifierFlags)
        self.modifierOnly = try c.decodeIfPresent(ModifierKey.self, forKey: .modifierOnly)
    }

    var isModifierOnly: Bool { modifierOnly != nil }

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
        if let modOnly = modifierOnly {
            return modOnly.shortSymbol
        }
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
