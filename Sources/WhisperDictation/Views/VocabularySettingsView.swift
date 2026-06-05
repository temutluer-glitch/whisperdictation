import SwiftUI

/// Eigener Wörterbuch-Tab im Einstellungsfenster. Trennt das Wörterbuch von der
/// Transkriptions-Seite (Groq-Key, Modell), die dadurch aufgeräumt wird.
struct VocabularySettingsView: View {
    var body: some View {
        Form {
            Section("Eigenes Wörterbuch") {
                VocabularyEditor()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
