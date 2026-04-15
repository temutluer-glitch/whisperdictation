import Foundation
import Combine
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let hotkeyConfig = "hotkeyConfig"
        static let hotkeyMode = "hotkeyMode"
        static let whisperModel = "whisperModel"
        static let languageHint = "languageHint"
        static let outputMode = "outputMode"
        static let playSounds = "playSounds"
        static let launchAtLogin = "launchAtLogin"
        static let llmEnabled = "llmEnabled"
        static let llmModel = "llmModel"
        static let llmPresets = "llmPresets"
        static let activePresetID = "activePresetID"
        static let hasGroqKey = "hasGroqKey"
    }

    @Published var hotkeyConfig: HotkeyConfig {
        didSet { save(hotkeyConfig, key: Key.hotkeyConfig) }
    }

    @Published var hotkeyMode: HotkeyMode {
        didSet { UserDefaults.standard.set(hotkeyMode.rawValue, forKey: Key.hotkeyMode) }
    }

    @Published var whisperModel: WhisperModel {
        didSet { UserDefaults.standard.set(whisperModel.rawValue, forKey: Key.whisperModel) }
    }

    @Published var languageHint: String {
        didSet { UserDefaults.standard.set(languageHint, forKey: Key.languageHint) }
    }

    @Published var outputMode: OutputMode {
        didSet { UserDefaults.standard.set(outputMode.rawValue, forKey: Key.outputMode) }
    }

    @Published var playSounds: Bool {
        didSet { UserDefaults.standard.set(playSounds, forKey: Key.playSounds) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Key.launchAtLogin)
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    @Published var llmEnabled: Bool {
        didSet { UserDefaults.standard.set(llmEnabled, forKey: Key.llmEnabled) }
    }

    @Published var llmModel: String {
        didSet { UserDefaults.standard.set(llmModel, forKey: Key.llmModel) }
    }

    @Published var llmPresets: [PromptPreset] {
        didSet { save(llmPresets, key: Key.llmPresets) }
    }

    @Published var activePresetID: UUID? {
        didSet {
            if let id = activePresetID {
                UserDefaults.standard.set(id.uuidString, forKey: Key.activePresetID)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.activePresetID)
            }
        }
    }

    @Published var groqAPIKey: String {
        didSet {
            KeychainStore.set(groqAPIKey, for: KeychainStore.Account.groqAPIKey)
            UserDefaults.standard.set(!groqAPIKey.isEmpty, forKey: Key.hasGroqKey)
        }
    }

    var activePreset: PromptPreset? {
        guard let id = activePresetID else { return nil }
        return llmPresets.first(where: { $0.id == id })
    }

    init() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: Key.hotkeyConfig),
           let decoded = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            self.hotkeyConfig = decoded
        } else {
            self.hotkeyConfig = .defaultConfig
        }

        self.hotkeyMode = HotkeyMode(rawValue: defaults.string(forKey: Key.hotkeyMode) ?? "") ?? .holdToTalk
        self.whisperModel = WhisperModel(rawValue: defaults.string(forKey: Key.whisperModel) ?? "") ?? .largeV3Turbo
        self.languageHint = defaults.string(forKey: Key.languageHint) ?? ""
        self.outputMode = OutputMode(rawValue: defaults.string(forKey: Key.outputMode) ?? "") ?? .pasteIntoActiveApp
        self.playSounds = defaults.object(forKey: Key.playSounds) as? Bool ?? true
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        self.llmEnabled = defaults.bool(forKey: Key.llmEnabled)
        self.llmModel = defaults.string(forKey: Key.llmModel) ?? "llama-3.3-70b-versatile"

        if let data = defaults.data(forKey: Key.llmPresets),
           let decoded = try? JSONDecoder().decode([PromptPreset].self, from: data),
           !decoded.isEmpty {
            self.llmPresets = decoded
        } else {
            self.llmPresets = PromptPreset.defaults
        }

        if let idString = defaults.string(forKey: Key.activePresetID),
           let uuid = UUID(uuidString: idString) {
            self.activePresetID = uuid
        } else {
            self.activePresetID = PromptPreset.raw.id
        }

        self.groqAPIKey = KeychainStore.get(KeychainStore.Account.groqAPIKey) ?? ""
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
