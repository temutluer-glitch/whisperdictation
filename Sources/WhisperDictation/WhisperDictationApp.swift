import SwiftUI
import AppKit

@MainActor
final class AppServices: ObservableObject {
    let appState = AppState()
    let settingsStore = SettingsStore()
    let coordinator = DictationCoordinator()
    let history = TranscriptionHistory.shared

    init() {
        coordinator.attach(settingsStore: settingsStore, appState: appState)
    }
}

@main
struct WhisperDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(services.appState)
                .environmentObject(services.settingsStore)
                .environmentObject(services.coordinator)
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
                .frame(minWidth: 680, minHeight: 520)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PermissionHelper.checkAccessibilityOnLaunch()
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coordinator: DictationCoordinator

    var body: some View {
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
