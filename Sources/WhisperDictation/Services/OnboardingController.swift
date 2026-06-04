import Foundation
import SwiftUI
import AppKit
import AVFoundation
import ApplicationServices

/// Die Schritte des Erst-Start-Wizards in Reihenfolge.
enum OnboardingStep: Int, CaseIterable, Comparable, Identifiable {
    case welcome
    case apiKey
    case microphonePermission
    case accessibilityPermission
    case microphoneSelection
    case hotkey
    case testDictation
    case done

    var id: Int { rawValue }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .welcome: return "Willkommen bei InnoWhisper"
        case .apiKey: return "Groq API-Key"
        case .microphonePermission: return "Mikrofon-Zugriff"
        case .accessibilityPermission: return "Bedienungshilfen"
        case .microphoneSelection: return "Mikrofon auswählen"
        case .hotkey: return "Dein Hotkey"
        case .testDictation: return "Test-Diktat"
        case .done: return "Alles bereit"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: return "hand.wave"
        case .apiKey: return "key"
        case .microphonePermission: return "mic"
        case .accessibilityPermission: return "accessibility"
        case .microphoneSelection: return "waveform"
        case .hotkey: return "keyboard"
        case .testDictation: return "checkmark.bubble"
        case .done: return "sparkles"
        }
    }
}

/// Status der optionalen Groq-Key-Prüfung im API-Key-Schritt.
enum KeyValidation: Equatable {
    case unknown
    case validating
    case valid
    case invalid(String)
}

/// Steuert den Erst-Start-Onboarding-Wizard: eigenes `NSWindow`, Schritt-Navigation,
/// Live-Permission-Polling, Skip-Logik und den Relaunch nach Bedienungshilfen-Erteilung.
@MainActor
final class OnboardingController: NSObject, ObservableObject, NSWindowDelegate {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isPresented: Bool = false

    /// Live geprüfter Permission-Status (Polling alle 1 s, solange das Fenster offen ist).
    @Published private(set) var micAuthorized: Bool = false
    @Published private(set) var axTrusted: Bool = false

    @Published var keyValidation: KeyValidation = .unknown

    /// Einmalige Markierung: nach einem Relaunch aus dem Wizard heraus das Onboarding
    /// fortsetzen, auch wenn es (z. B. bei manueller Wiederholung oder vorhandenem Key)
    /// schon als abgeschlossen gilt.
    private static let resumeDefaultsKey = "onboardingResumeAfterRelaunch"

    let settingsStore: SettingsStore
    let tester: OnboardingDictationTester

    private var window: NSWindow?
    private var pollTimer: Timer?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.tester = OnboardingDictationTester(settings: settingsStore)
        super.init()
    }

    // MARK: - Präsentation

    /// Zeigt den Wizard beim App-Start, falls das Onboarding noch nicht abgeschlossen wurde
    /// oder nach einem Relaunch aus dem Wizard heraus fortgesetzt werden soll.
    /// Springt per Skip-Logik direkt zum ersten noch offenen Schritt (z. B. nach einem
    /// Neustart wegen Bedienungshilfen direkt zur Mikrofon-Auswahl).
    func presentIfNeeded() {
        let resumeAfterRelaunch = UserDefaults.standard.bool(forKey: Self.resumeDefaultsKey)
        if resumeAfterRelaunch {
            UserDefaults.standard.removeObject(forKey: Self.resumeDefaultsKey)
        }
        guard !settingsStore.hasCompletedOnboarding || resumeAfterRelaunch else { return }
        present(resumingFromState: true)
    }

    /// Öffnet den Wizard manuell von vorn (Einstellungen → „Onboarding nochmal starten").
    func presentFromStart() {
        present(resumingFromState: false)
    }

    private func present(resumingFromState: Bool) {
        refreshPermissionStatus()
        keyValidation = .unknown
        tester.reset()
        currentStep = resumingFromState ? resolvedStartStep() : .welcome

        if window == nil {
            let hosting = NSHostingController(
                rootView: OnboardingView()
                    .environmentObject(self)
                    .environmentObject(settingsStore)
                    .environmentObject(tester)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "Willkommen bei InnoWhisper"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.setContentSize(NSSize(width: 580, height: 640))
            w.center()
            w.delegate = self
            w.isReleasedWhenClosed = false
            window = w
        }

        startPolling()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        isPresented = true
    }

    /// Skip-Logik: wählt den ersten Schritt, der noch echte Eingabe braucht.
    private func resolvedStartStep() -> OnboardingStep {
        if settingsStore.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .welcome
        }
        if !micAuthorized { return .microphonePermission }
        if !axTrusted { return .accessibilityPermission }
        return .microphoneSelection
    }

    // MARK: - Navigation

    func advance() {
        let steps = OnboardingStep.allCases
        guard let idx = steps.firstIndex(of: currentStep) else { return }
        if idx + 1 < steps.count {
            currentStep = steps[idx + 1]
            if currentStep != .testDictation { tester.reset() }
        } else {
            finish()
        }
    }

    func goBack() {
        let steps = OnboardingStep.allCases
        guard let idx = steps.firstIndex(of: currentStep), idx > 0 else { return }
        if currentStep == .testDictation { tester.reset() }
        currentStep = steps[idx - 1]
    }

    var canGoBack: Bool { currentStep > .welcome }

    /// Ob der „Weiter"-Button im jeweiligen Schritt aktiv sein darf.
    var canAdvance: Bool {
        switch currentStep {
        case .welcome, .microphoneSelection, .hotkey, .testDictation, .done:
            return true
        case .apiKey:
            return !settingsStore.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .microphonePermission:
            return micAuthorized
        case .accessibilityPermission:
            return axTrusted
        }
    }

    func finish() {
        settingsStore.completeOnboarding()
        closeWindow()
    }

    private func closeWindow() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopPolling()
        tester.reset()
        isPresented = false
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Permissions

    private func startPolling() {
        refreshPermissionStatus()
        pollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissionStatus() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshPermissionStatus() {
        micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        axTrusted = AXIsProcessTrusted()
    }

    /// Fragt die Mikrofon-Berechtigung über den System-Dialog an.
    func requestMicrophoneAccess() {
        Task {
            let granted = await tester.recorder.requestPermission()
            micAuthorized = granted || AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            if micAuthorized, currentStep == .microphonePermission {
                advance()
            }
        }
    }

    /// Öffnet die System-Einstellungen für Bedienungshilfen.
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Relaunch

    /// Beendet die App und startet sie sofort neu. Nötig, damit TCC eine frisch
    /// erteilte Bedienungshilfen-Berechtigung zuverlässig mountet.
    ///
    /// Ein direktes `open -n` parallel zum laufenden Beenden schlägt fehl: LaunchServices
    /// verwirft den Start einer neuen Instanz, solange dieselbe Bundle-ID noch terminiert.
    /// Deshalb startet ein abgekoppelter Helper, der wartet, bis dieser Prozess wirklich
    /// beendet ist, und erst dann die App neu öffnet.
    func relaunchApp() {
        // Nach dem Neustart soll der Wizard sicher wieder erscheinen und an der
        // Mikrofon-Auswahl weitermachen, auch wenn das Onboarding schon als
        // abgeschlossen gilt. Synchronize erzwingt das Flushen vor dem Beenden.
        UserDefaults.standard.set(true, forKey: Self.resumeDefaultsKey)
        UserDefaults.standard.synchronize()

        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        DebugLog.write("onboarding relaunch requested bundle=\(bundlePath) pid=\(pid)")
        // $1 = Bundle-Pfad (als Argument übergeben, damit Leerzeichen im Pfad sicher sind).
        let script = "while /bin/kill -0 \(pid) >/dev/null 2>&1; do /bin/sleep 0.1; done; /usr/bin/open \"$1\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, "wd-relaunch", bundlePath]
        do {
            try task.run()
        } catch {
            // Helper konnte nicht starten: dann NICHT beenden, sonst bliebe die App
            // weg ohne Neustart. Der Nutzer kann stattdessen manuell neu starten.
            DebugLog.write("relaunch helper failed: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: - API-Key-Validierung

    /// Prüft den eingegebenen Key gegen den leichten Groq-`/models`-Endpoint.
    func validateAPIKey() {
        let key = settingsStore.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            keyValidation = .invalid("Kein Key eingegeben.")
            return
        }
        keyValidation = .validating
        Task {
            var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    keyValidation = .invalid("Keine gültige Antwort von Groq.")
                    return
                }
                switch http.statusCode {
                case 200:
                    keyValidation = .valid
                case 401:
                    keyValidation = .invalid("Key wird abgelehnt (401). Bitte prüfen.")
                default:
                    keyValidation = .invalid("Groq antwortete mit Status \(http.statusCode).")
                }
            } catch {
                keyValidation = .invalid("Netzwerkfehler: \(error.localizedDescription)")
            }
        }
    }
}

/// Kapselt das Test-Diktat in Schritt 7: nimmt über einen eigenen `AudioRecorder` auf
/// und transkribiert via Groq, ohne den globalen Hotkey-Pfad oder Text-Injection zu nutzen.
@MainActor
final class OnboardingDictationTester: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case success(String)
        case failure(String)
    }

    @Published var phase: Phase = .idle
    let recorder = AudioRecorder()

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isRecording: Bool { phase == .recording }

    func startRecording() {
        guard phase != .recording else { return }
        Task {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await recorder.requestPermission()
            }
            recorder.preferredInputDeviceID = settings.preferredInputDeviceID
            do {
                _ = try recorder.start()
                phase = .recording
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }

    func stopAndTranscribe() {
        guard phase == .recording else { return }
        guard let result = recorder.stop() else {
            phase = .idle
            return
        }
        if result.durationSeconds < 0.4 || result.maxLevelDb < -42 {
            try? FileManager.default.removeItem(at: result.url)
            phase = .failure("Kein Audio erkannt. Sprich nach dem Start deutlich ins Mikrofon.")
            return
        }

        phase = .transcribing
        let apiKey = settings.groqAPIKey
        let model = settings.whisperModel.rawValue
        let language = settings.languageHint
        Task {
            do {
                let service = GroqTranscriptionService(apiKey: apiKey)
                let text = try await service.transcribe(
                    fileURL: result.url,
                    model: model,
                    language: language.isEmpty ? nil : language,
                    prompt: nil
                )
                try? FileManager.default.removeItem(at: result.url)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                phase = .success(trimmed.isEmpty ? "(nichts erkannt – versuch es nochmal)" : trimmed)
            } catch {
                try? FileManager.default.removeItem(at: result.url)
                phase = .failure(error.localizedDescription)
            }
        }
    }

    func reset() {
        if recorder.startTime != nil {
            recorder.cancel()
        }
        phase = .idle
    }
}
