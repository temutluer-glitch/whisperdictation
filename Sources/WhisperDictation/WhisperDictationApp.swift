import SwiftUI
import AppKit
import ApplicationServices

@MainActor
final class AccessibilityTrustObserver: ObservableObject {
    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if self.isTrusted != trusted {
                    self.isTrusted = trusted
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class AppServices: ObservableObject {
    let appState = AppState()
    let settingsStore = SettingsStore()
    let coordinator = DictationCoordinator()
    let history = TranscriptionHistory.shared
    let onboarding: OnboardingController

    init() {
        onboarding = OnboardingController(settingsStore: settingsStore)
        coordinator.attach(settingsStore: settingsStore, appState: appState)

        // Beim ersten Start (oder solange das Onboarding nicht abgeschlossen ist)
        // den Wizard zeigen. Verzögert, damit NSApp vollständig läuft.
        let onboarding = self.onboarding
        DispatchQueue.main.async {
            onboarding.presentIfNeeded()
        }
    }
}

@main
struct WhisperDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices()
    @StateObject private var updateController = UpdateController()
    @StateObject private var axTrust = AccessibilityTrustObserver()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(services.appState)
                .environmentObject(services.settingsStore)
                .environmentObject(services.coordinator)
                .environmentObject(updateController)
                .environmentObject(axTrust)
        } label: {
            Image(systemName: services.appState.menuBarIconName)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(services.settingsStore)
                .environmentObject(services.appState)
                .environmentObject(services.history)
                .environmentObject(updateController)
                .environmentObject(services.onboarding)
                .frame(minWidth: 680, minHeight: 520)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let bundlePath = Bundle.main.bundlePath
        let trusted = AXIsProcessTrusted()
        DebugLog.write("launch bundlePath=\(bundlePath) axTrusted=\(trusted)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Während des Onboardings übernimmt der Wizard den Bedienungshilfen-Schritt,
            // daher hier keinen zusätzlichen Alert zeigen.
            if UserDefaults.standard.bool(forKey: SettingsStore.onboardingDefaultsKey) {
                PermissionHelper.checkAccessibilityOnLaunch()
            }
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: DictationCoordinator
    @EnvironmentObject private var updater: UpdateController
    @EnvironmentObject private var axTrust: AccessibilityTrustObserver

    var body: some View {
        if !axTrust.isTrusted {
            Button("Bedienungshilfen fehlen, hier öffnen") {
                axTrust.openAccessibilitySettings()
            }
            Divider()
        }

        Text(statusLine)
            .font(.system(.body, design: .rounded))

        Divider()

        Button(appState.isRecording ? "Aufnahme stoppen" : "Aufnahme starten") {
            coordinator.toggleRecording()
        }
        .keyboardShortcut("r")

        if !appState.lastTranscription.isEmpty {
            Divider()
            Text("Letzte: \(String(appState.lastTranscription.prefix(60)))")
                .font(.caption)
        }

        Divider()

        SettingsLink {
            Text("Einstellungen…")
        }
        .keyboardShortcut(",")

        Button("Auf Updates prüfen…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)

        Button("Beenden") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusLine: String {
        switch appState.status {
        case .idle: return "Bereit"
        case .recording: return "Nimmt auf…"
        case .transcribing: return "Transkribiere…"
        case .processing: return "Verarbeite mit LLM…"
        case .error(let msg): return "Fehler: \(msg)"
        }
    }
}
