import Foundation
import AppKit
import AVFoundation
import Combine

@MainActor
final class DictationCoordinator: ObservableObject {
    private let hotkeyManager = HotkeyManager()
    let recorder = AudioRecorder()
    private let history = TranscriptionHistory.shared
    private let overlay = CursorOverlay()

    private var settingsStore: SettingsStore?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private var activeBindingID: UUID?

    private static let hallucinationPhrases: Set<String> = [
        "thank you", "thank you.", "thanks", "thanks.", "thanks for watching",
        "thanks for watching.", "thanks for watching!", "thank you for watching",
        "thank you for watching.", "thank you very much", "thank you very much.",
        "you", "you.", "...", ".", "danke", "danke.", "vielen dank", "vielen dank.",
        "tschüss", "tschüss.", "bye", "bye.", "untertitel der amara.org-community",
        "untertitelung des zdf für funk, 2017", "untertitelung aufgrund der amara.org-community",
        "untertitel im auftrag des zdf, 2020", "untertitel im auftrag des zdf, 2017",
        "untertitel im auftrag des zdf für funk, 2017",
        "amara.org community", "♪♪", "music", "[music]"
    ]

    func attach(settingsStore: SettingsStore, appState: AppState) {
        self.settingsStore = settingsStore
        self.appState = appState

        hotkeyManager.onPress = { [weak self] bindingID in
            self?.startRecording(bindingID: bindingID)
        }
        hotkeyManager.onRelease = { [weak self] bindingID in
            self?.stopAndProcess(bindingID: bindingID)
        }

        reregisterBindings()

        settingsStore.$hotkeyBindings
            .sink { [weak self] _ in
                Task { @MainActor in self?.reregisterBindings() }
            }
            .store(in: &cancellables)
    }

    private func reregisterBindings() {
        guard let settingsStore else { return }
        hotkeyManager.register(bindings: settingsStore.hotkeyBindings)
    }

    func toggleRecording() {
        guard let appState, let settingsStore else { return }
        if appState.isRecording {
            if let id = activeBindingID {
                stopAndProcess(bindingID: id)
            }
        } else if let defaultBinding = settingsStore.defaultBinding {
            startRecording(bindingID: defaultBinding.id)
        }
    }

    private func startRecording(bindingID: UUID) {
        guard let appState else { return }
        guard !appState.isRecording else { return }

        activeBindingID = bindingID
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        DebugLog.write("hotkeyPress frontApp=\(front) binding=\(bindingID.uuidString.prefix(8))")

        let preferredDeviceID = settingsStore?.preferredInputDeviceID ?? ""

        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .notDetermined {
                _ = await recorder.requestPermission()
            }

            recorder.preferredInputDeviceID = preferredDeviceID

            do {
                _ = try recorder.start()
                appState.status = .recording
                overlay.show(status: .recording, recorder: recorder)
                playSoundIfEnabled(.begin)
            } catch {
                appState.status = .error(error.localizedDescription)
                overlay.hide()
                showAlert(title: "Aufnahme-Fehler", body: error.localizedDescription)
                resetToIdleAfterDelay()
            }
        }
    }

    private func stopAndProcess(bindingID: UUID) {
        guard let appState, let settingsStore else { return }

        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        DebugLog.write("hotkeyRelease frontApp=\(front)")

        guard let stopResult = recorder.stop() else {
            overlay.hide()
            appState.status = .idle
            activeBindingID = nil
            return
        }

        if stopResult.durationSeconds < 0.4 || stopResult.maxLevelDb < -42 {
            try? FileManager.default.removeItem(at: stopResult.url)
            overlay.hide()
            appState.status = .idle
            activeBindingID = nil
            return
        }

        appState.status = .transcribing
        overlay.updateStatus(.transcribing)
        playSoundIfEnabled(.end)

        let model = settingsStore.whisperModel.rawValue
        let languageHint = settingsStore.languageHint
        let apiKey = settingsStore.groqAPIKey
        let llmModel = settingsStore.llmModel
        let outputMode = settingsStore.outputMode
        let vocabularyPrompt = Self.normalizedVocabularyPrompt(settingsStore.customVocabulary)
        let binding = settingsStore.binding(forID: bindingID) ?? settingsStore.defaultBinding
        let preset = binding.flatMap { settingsStore.preset(for: $0) }

        Task {
            do {
                let transcriber = GroqTranscriptionService(apiKey: apiKey)
                let raw = try await transcriber.transcribe(
                    fileURL: stopResult.url,
                    model: model,
                    language: languageHint.isEmpty ? nil : languageHint,
                    prompt: vocabularyPrompt
                )

                try? FileManager.default.removeItem(at: stopResult.url)

                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if Self.isLikelyHallucination(trimmed) {
                    overlay.hide()
                    appState.status = .idle
                    activeBindingID = nil
                    return
                }

                var final = trimmed
                var presetName: String? = preset?.name

                if let preset, !preset.instruction.isEmpty {
                    appState.status = .processing
                    overlay.updateStatus(.processing)
                    let llm = GroqLLMService(apiKey: apiKey)
                    final = try await llm.process(text: trimmed, instruction: preset.instruction, model: llmModel)
                }

                appState.lastTranscription = final
                history.add(HistoryEntry(rawText: trimmed, processedText: final, presetName: presetName))
                overlay.hide()
                TextInjector.inject(final, mode: outputMode)

                appState.status = .idle
                activeBindingID = nil
            } catch {
                appState.status = .error(error.localizedDescription)
                overlay.hide()
                showAlert(title: "Transkription fehlgeschlagen", body: error.localizedDescription)
                resetToIdleAfterDelay()
                activeBindingID = nil
            }
        }
    }

    static func normalizedVocabularyPrompt(_ raw: String) -> String? {
        let terms = raw
            .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",;")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return nil }
        return terms.joined(separator: ", ")
    }

    private static func isLikelyHallucination(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if normalized.isEmpty { return true }
        if hallucinationPhrases.contains(normalized) { return true }
        let collapsed = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if hallucinationPhrases.contains(collapsed) { return true }
        return false
    }

    private func resetToIdleAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.appState?.status = .idle
        }
    }

    private enum SoundKind { case begin, end }

    private func playSoundIfEnabled(_ kind: SoundKind) {
        guard settingsStore?.playSounds == true else { return }
        let name: NSSound.Name = kind == .begin ? NSSound.Name("Tink") : NSSound.Name("Pop")
        NSSound(named: name)?.play()
    }

    private func showAlert(title: String, body: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
