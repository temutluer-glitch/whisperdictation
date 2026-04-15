import Foundation
import AppKit
import AVFoundation
import Combine

@MainActor
final class DictationCoordinator: ObservableObject {
    private let hotkeyManager = HotkeyManager()
    private let recorder = AudioRecorder()
    private let history = TranscriptionHistory.shared

    private var settingsStore: SettingsStore?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    func attach(settingsStore: SettingsStore, appState: AppState) {
        self.settingsStore = settingsStore
        self.appState = appState

        hotkeyManager.onPress = { [weak self] in self?.startRecording() }
        hotkeyManager.onRelease = { [weak self] in self?.stopAndProcess() }

        reregisterHotkey()

        settingsStore.$hotkeyConfig
            .combineLatest(settingsStore.$hotkeyMode)
            .sink { [weak self] _, _ in
                Task { @MainActor in self?.reregisterHotkey() }
            }
            .store(in: &cancellables)
    }

    private func reregisterHotkey() {
        guard let settingsStore else { return }
        hotkeyManager.register(config: settingsStore.hotkeyConfig, mode: settingsStore.hotkeyMode)
    }

    func toggleRecording() {
        guard let appState else { return }
        if appState.isRecording {
            stopAndProcess()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let appState else { return }
        guard !appState.isRecording else { return }

        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .notDetermined {
                _ = await recorder.requestPermission()
            }

            do {
                _ = try recorder.start()
                appState.status = .recording
                playSoundIfEnabled(.begin)
            } catch {
                appState.status = .error(error.localizedDescription)
                showAlert(title: "Aufnahme-Fehler", body: error.localizedDescription)
                resetToIdleAfterDelay()
            }
        }
    }

    private func stopAndProcess() {
        guard let appState, let settingsStore else { return }
        guard let url = recorder.stop() else {
            appState.status = .idle
            return
        }
        appState.status = .transcribing
        playSoundIfEnabled(.end)

        let model = settingsStore.whisperModel.rawValue
        let languageHint = settingsStore.languageHint
        let apiKey = settingsStore.groqAPIKey
        let llmEnabled = settingsStore.llmEnabled
        let llmModel = settingsStore.llmModel
        let preset = settingsStore.activePreset
        let outputMode = settingsStore.outputMode

        Task {
            do {
                let transcriber = GroqTranscriptionService(apiKey: apiKey)
                let raw = try await transcriber.transcribe(
                    fileURL: url,
                    model: model,
                    language: languageHint.isEmpty ? nil : languageHint
                )

                try? FileManager.default.removeItem(at: url)

                var final = raw
                var presetName: String? = nil

                if llmEnabled, let preset, !preset.instruction.isEmpty {
                    appState.status = .processing
                    let llm = GroqLLMService(apiKey: apiKey)
                    final = try await llm.process(text: raw, instruction: preset.instruction, model: llmModel)
                    presetName = preset.name
                } else if let preset, preset.instruction.isEmpty {
                    presetName = preset.name
                }

                appState.lastTranscription = final
                history.add(HistoryEntry(rawText: raw, processedText: final, presetName: presetName))
                TextInjector.inject(final, mode: outputMode)

                appState.status = .idle
            } catch {
                appState.status = .error(error.localizedDescription)
                showAlert(title: "Transkription fehlgeschlagen", body: error.localizedDescription)
                resetToIdleAfterDelay()
            }
        }
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
