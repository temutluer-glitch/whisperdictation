import SwiftUI

/// Geteilter Wörterbuch-Editor im Chip-Stil (Eigennamen als Kapseln). Wird im
/// Einstellungsfenster (eigener Tab) und im Menüleisten-Popover verwendet.
/// Quelle der Wahrheit bleibt `settings.customVocabulary` (kommagetrennt),
/// damit die bestehende Transkriptions-Pipeline unverändert funktioniert.
struct VocabularyEditor: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var newTerm: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if terms.isEmpty {
                Text("Noch keine Begriffe. Füge unten Eigennamen, Fachbegriffe oder Abkürzungen hinzu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(terms, id: \.self) { term in
                        chip(term)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Begriff hinzufügen…", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTerm() }
                Button("Hinzufügen") { addTerm() }
                    .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("Eigennamen, Fachbegriffe oder Abkürzungen, die Whisper kennen soll. Mehrere auf einmal gehen kommagetrennt. Wird als Kontext mit jeder Aufnahme an Whisper geschickt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ term: String) -> some View {
        HStack(spacing: 4) {
            Text(term)
                .font(.callout)
                .lineLimit(1)
            Button { removeTerm(term) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Entfernen")
        }
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
    }

    // MARK: - Datenhaltung (kommagetrennt in settings.customVocabulary)

    private var terms: [String] {
        Self.dedupe(Self.parse(settings.customVocabulary))
    }

    private func addTerm() {
        let incoming = Self.parse(newTerm)
        guard !incoming.isEmpty else { return }
        var current = Self.dedupe(Self.parse(settings.customVocabulary))
        current.append(contentsOf: incoming)
        settings.customVocabulary = Self.dedupe(current).joined(separator: ", ")
        newTerm = ""
    }

    private func removeTerm(_ term: String) {
        let remaining = Self.dedupe(Self.parse(settings.customVocabulary))
            .filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        settings.customVocabulary = remaining.joined(separator: ", ")
    }

    private static func parse(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func dedupe(_ arr: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for term in arr {
            let key = term.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                out.append(term)
            }
        }
        return out
    }
}

/// Einfaches umbrechendes Flow-Layout für die Chips (macOS 13+).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }

        let width = maxWidth == .infinity ? usedWidth : maxWidth
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
