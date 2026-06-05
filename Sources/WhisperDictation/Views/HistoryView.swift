import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject private var history: TranscriptionHistory
    @State private var selectedID: UUID?
    @State private var justCopiedID: UUID?
    @State private var expandedIDs: Set<UUID> = []
    /// Im Popover ohne eigenes Padding (das Popover bringt sein eigenes mit),
    /// damit der Verlauf bündig mit Status und Umschalter sitzt.
    var compact: Bool = false

    var body: some View {
        if compact {
            historyStack
        } else {
            historyStack.padding()
        }
    }

    @ViewBuilder
    private var historyStack: some View {
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
                        HistoryRow(
                            entry: entry,
                            justCopied: justCopiedID == entry.id,
                            isExpanded: expandedIDs.contains(entry.id),
                            onToggleExpand: { toggleExpand(entry.id) },
                            onCopy: { copy(entry.processedText, markingID: entry.id) },
                            onCopyRaw: { copy(entry.rawText, markingID: entry.id) },
                            onDelete: { history.remove(entry.id) }
                        )
                        .tag(Optional(entry.id))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func copy(_ text: String, markingID id: UUID) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        justCopiedID = id
        let copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if justCopiedID == copiedID {
                justCopiedID = nil
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let justCopied: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    let onCopyRaw: () -> Void
    let onDelete: () -> Void

    @State private var textWidth: CGFloat = 0

    private static let collapsedLineLimit = 2

    private var isOverflowing: Bool {
        guard textWidth > 0 else { return false }
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributed = NSAttributedString(string: entry.processedText, attributes: [.font: font])
        let bounds = attributed.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let lines = Int((bounds.height / lineHeight).rounded(.up))
        return lines > Self.collapsedLineLimit
    }

    private var showsExpandToggle: Bool { isExpanded || isOverflowing }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
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
                    .lineLimit(isExpanded ? nil : Self.collapsedLineLimit)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { proxy in
                        Color.clear
                            .onAppear { textWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, new in textWidth = new }
                    })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if showsExpandToggle { onToggleExpand() } }

            VStack(spacing: 4) {
                Button(action: onCopy) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(justCopied ? .green : .primary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .help(justCopied ? "Kopiert" : "Text in Zwischenablage kopieren")

                if showsExpandToggle {
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .help(isExpanded ? "Einklappen" : "Vollständigen Text zeigen")
                }
            }
        }
        .contextMenu {
            if showsExpandToggle {
                Button(isExpanded ? "Einklappen" : "Vollständigen Text zeigen") { onToggleExpand() }
            }
            Button("Text kopieren") { onCopy() }
            if entry.rawText != entry.processedText {
                Button("Rohtext kopieren") { onCopyRaw() }
            }
            Button("Löschen", role: .destructive) { onDelete() }
        }
    }
}
