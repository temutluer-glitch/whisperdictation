import Foundation
import Combine
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    /// UserDefaults-Key des Onboarding-Flags. Öffentlich und nonisolated, damit der
    /// AppDelegate den Bedienungshilfen-Start-Alert während des Onboardings unterdrücken kann.
    nonisolated static let onboardingDefaultsKey = "hasCompletedOnboarding"

    private enum Key {
        static let hotkeyBindings = "hotkeyBindings"
        static let legacyHotkeyConfig = "hotkeyConfig"
        static let legacyHotkeyMode = "hotkeyMode"
        static let whisperModel = "whisperModel"
        static let languageHint = "languageHint"
        static let outputMode = "outputMode"
        static let playSounds = "playSounds"
        static let launchAtLogin = "launchAtLogin"
        static let llmEnabled = "llmEnabled"
        static let llmModel = "llmModel"
        static let llmPresets = "llmPresets"
        static let hasGroqKey = "hasGroqKey"
        static let customVocabulary = "customVocabulary"
        static let preferredInputDeviceID = "preferredInputDeviceID"
        static let hasCompletedOnboarding = SettingsStore.onboardingDefaultsKey
    }

    @Published var hotkeyBindings: [HotkeyBinding] {
        didSet { save(hotkeyBindings, key: Key.hotkeyBindings) }
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

    @Published var groqAPIKey: String {
        didSet {
            KeychainStore.set(groqAPIKey, for: KeychainStore.Account.groqAPIKey)
            UserDefaults.standard.set(!groqAPIKey.isEmpty, forKey: Key.hasGroqKey)
        }
    }

    @Published var customVocabulary: String {
        didSet { UserDefaults.standard.set(customVocabulary, forKey: Key.customVocabulary) }
    }

    /// Empty string means "system default input device".
    @Published var preferredInputDeviceID: String {
        didSet { UserDefaults.standard.set(preferredInputDeviceID, forKey: Key.preferredInputDeviceID) }
    }

    /// `true`, sobald der Erst-Start-Onboarding-Wizard abgeschlossen (oder migriert) wurde.
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    func preset(for binding: HotkeyBinding) -> PromptPreset? {
        llmPresets.first(where: { $0.id == binding.presetID })
    }

    func binding(forID id: UUID) -> HotkeyBinding? {
        hotkeyBindings.first(where: { $0.id == id })
    }

    var defaultBinding: HotkeyBinding? {
        hotkeyBindings.first
    }

    init() {
        let defaults = UserDefaults.standard

        self.whisperModel = WhisperModel(rawValue: defaults.string(forKey: Key.whisperModel) ?? "") ?? .largeV3Turbo
        self.languageHint = defaults.string(forKey: Key.languageHint) ?? ""
        self.outputMode = OutputMode(rawValue: defaults.string(forKey: Key.outputMode) ?? "") ?? .pasteIntoActiveApp
        self.playSounds = defaults.object(forKey: Key.playSounds) as? Bool ?? true
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        self.llmEnabled = defaults.bool(forKey: Key.llmEnabled)
        self.llmModel = defaults.string(forKey: Key.llmModel) ?? "llama-3.3-70b-versatile"

        let presets: [PromptPreset]
        if let data = defaults.data(forKey: Key.llmPresets),
           let decoded = try? JSONDecoder().decode([PromptPreset].self, from: data),
           !decoded.isEmpty {
            presets = decoded
        } else {
            presets = PromptPreset.defaults
        }
        self.llmPresets = presets

        if let data = defaults.data(forKey: Key.hotkeyBindings),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data),
           !decoded.isEmpty {
            self.hotkeyBindings = decoded
        } else if let legacyData = defaults.data(forKey: Key.legacyHotkeyConfig),
                  let legacyConfig = try? JSONDecoder().decode(HotkeyConfig.self, from: legacyData) {
            let legacyMode = HotkeyMode(rawValue: defaults.string(forKey: Key.legacyHotkeyMode) ?? "") ?? .holdToTalk
            let rawPreset = presets.first(where: { $0.name == PromptPreset.raw.name }) ?? presets[0]
            self.hotkeyBindings = [HotkeyBinding(presetID: rawPreset.id, config: legacyConfig, mode: legacyMode)]
        } else {
            let rawPreset = presets.first(where: { $0.name == PromptPreset.raw.name }) ?? presets[0]
            self.hotkeyBindings = [HotkeyBinding(presetID: rawPreset.id, config: .defaultConfig, mode: .holdToTalk)]
        }

        let storedKey = KeychainStore.get(KeychainStore.Account.groqAPIKey) ?? ""
        self.groqAPIKey = storedKey
        self.customVocabulary = defaults.string(forKey: Key.customVocabulary) ?? ""
        self.preferredInputDeviceID = defaults.string(forKey: Key.preferredInputDeviceID) ?? ""

        // Onboarding-Flag. Wenn der Schlüssel bereits existiert, übernehmen wir ihn.
        // Fehlt er, läuft die Migration: bestehende, bereits konfigurierte Nutzer
        // (haben einen API-Key) gelten als fertig onboarded und sehen den Wizard
        // nach einem Update nicht. Nur echte Erst-Nutzer ohne Key bekommen ihn.
        if defaults.object(forKey: Key.hasCompletedOnboarding) != nil {
            self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        } else {
            let alreadyConfigured = !storedKey.isEmpty || defaults.bool(forKey: Key.hasGroqKey)
            self.hasCompletedOnboarding = alreadyConfigured
            defaults.set(alreadyConfigured, forKey: Key.hasCompletedOnboarding)
        }
    }

    /// Setzt das Onboarding zurück, sodass der Wizard erneut erscheint
    /// (Einstellungen → General → „Onboarding nochmal starten").
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }

    /// Markiert das Onboarding als abgeschlossen.
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
