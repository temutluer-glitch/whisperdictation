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
        // Menüleisten-Popover über SwiftUIs MenuBarExtra (window-Style). Dadurch
        // ist die App Teil des SwiftUI-Scene-Graphen, sodass SettingsLink das
        // native Einstellungsfenster zuverlässig öffnet.
        MenuBarExtra {
            MenuPopoverView()
                .environmentObject(services.appState)
                .environmentObject(services.settingsStore)
                .environmentObject(services.coordinator)
                .environmentObject(services.history)
                .environmentObject(updateController)
                .environmentObject(axTrust)
        } label: {
            MenuBarLabel(appState: services.appState)
        }
        .menuBarExtraStyle(.window)

        // Native Settings-Scene = vertraute Preferences-Optik. Der onAppear-Block
        // holt das Fenster zuverlässig in den Vordergrund (behebt Punkt 3).
        Settings {
            SettingsView()
                .environmentObject(services.settingsStore)
                .environmentObject(services.appState)
                .environmentObject(services.history)
                .environmentObject(updateController)
                .environmentObject(services.onboarding)
                .frame(minWidth: 680, minHeight: 520)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        for window in NSApp.windows where window.identifier?.rawValue.contains("Settings") == true {
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                    }
                }
        }
    }
}

/// Menüleisten-Icon: InnoSolv-Ringmarke im Ruhezustand (Branding), klare
/// Status-Symbole während Aufnahme/Verarbeitung/Fehler.
struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if appState.status == .idle {
            Image("InnosolvMenuBar")
        } else {
            Image(systemName: appState.menuBarIconName)
                .symbolRenderingMode(.hierarchical)
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
