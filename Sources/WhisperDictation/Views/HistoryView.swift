import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject private var history: TranscriptionHistory
    @State private var selectedID: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Letzte \(history.entries.count) Transkriptionen")
                    .font(.headline)
                Spacer()
                Button("Alles löschen", role: .destructive) { history.clear() }
                    .disabled(history.entries.isEmpty)
            }
            .padding(.bottom, 8)

            if history.entries.isEmpty {
                ContentUnavailableView(
                    "Noch keine Transkriptionen",
                    systemImage: "waveform",
                    description: Text("Drücke deinen Hotkey und sprich, um die erste Transkription zu erstellen.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    ForEach(history.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.date, style: .time)
                                Text(entry.date, style: .date)
                                    .foregroundStyle(.secondary)
                                if let name = entry.presetName {
                                    Text("· \(name)")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                                Spacer()
                            }
                            Text(entry.processedText)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                        .tag(Optional(entry.id))
                        .contextMenu {
                            Button("Text kopieren") { copy(entry.processedText) }
                            if entry.rawText != entry.processedText {
                                Button("Rohtext kopieren") { copy(entry.rawText) }
                            }
                            Button("Löschen", role: .destructive) { history.remove(entry.id) }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
