import SwiftUI
import AppKit

/// Inhalt des Menüleisten-Popovers. Schnellzugriff: Status, letzte Transkription,
/// Verlauf und Wörterbuch. Bewusst transluzent (keine undurchsichtigen
/// Hintergründe), damit das Glas-Material des NSPopover durchscheint. Folgt der
/// System-Appearance (hell/dunkel). Aufnahme läuft über die Hotkeys.
struct MenuPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updater: UpdateController
    @EnvironmentObject private var axTrust: AccessibilityTrustObserver

    @State private var tab: QuickTab = .history

    enum QuickTab: String, CaseIterable, Identifiable {
        case history = "Verlauf"
        case vocab = "Wörterbuch"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            if !axTrust.isTrusted {
                Button { axTrust.openAccessibilitySettings() } label: {
                    Label("Bedienungshilfen fehlen, hier öffnen", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }

            statusRow

            Picker("", selection: $tab) {
                ForEach(QuickTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            quickContent
                .frame(height: 300)

            Divider().opacity(0.5)

            HStack(spacing: 14) {
                SettingsLink {
                    Label("Einstellungen", systemImage: "gearshape").font(.caption)
                }
                .buttonStyle(.borderless)

                Button { updater.checkForUpdates() } label: {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath").font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(!updater.canCheckForUpdates)

                Spacer()

                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power").font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("Beenden")
                .keyboardShortcut("q")
            }
        }
        .padding(10)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusLine).font(.callout)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }

    @ViewBuilder
    private var quickContent: some View {
        switch tab {
        case .history:
            HistoryView(compact: true)
        case .vocab:
            ScrollView { VocabularyEditor().padding(.top, 2) }
        }
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle: return .secondary
        case .recording: return .red
        case .transcribing, .processing: return .blue
        case .error: return .orange
        }
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
