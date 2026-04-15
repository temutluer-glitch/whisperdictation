import SwiftUI

struct TranscriptionSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var revealKey = false

    var body: some View {
        Form {
            Section("Groq API") {
                HStack {
                    if revealKey {
                        TextField("API Key", text: $settings.groqAPIKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $settings.groqAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(revealKey ? "Verbergen" : "Zeigen") { revealKey.toggle() }
                }
                Link("Key auf console.groq.com/keys erstellen", destination: URL(string: "https://console.groq.com/keys")!)
                    .font(.caption)
            }

            Section("Whisper-Modell") {
                Picker("Modell", selection: $settings.whisperModel) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.label).tag(model)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Sprache") {
                TextField("Sprach-Code (optional, z.B. 'de', 'en')", text: $settings.languageHint)
                    .textFieldStyle(.roundedBorder)
                Text("Leer lassen für automatische Erkennung. ISO-639-1 Code wie 'de' oder 'en' hilft Whisper bei Mehrdeutigkeiten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
