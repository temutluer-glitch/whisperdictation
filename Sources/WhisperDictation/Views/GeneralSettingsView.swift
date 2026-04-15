import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Form {
            Section("Verhalten") {
                Toggle("Beim Login starten", isOn: $settings.launchAtLogin)
                Toggle("Sounds bei Start/Stop", isOn: $settings.playSounds)
            }

            Section("Ausgabe") {
                Picker("Modus", selection: $settings.outputMode) {
                    ForEach(OutputMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Über") {
                Text("WhisperDictation v1.0.0")
                    .foregroundStyle(.secondary)
                Text("Nutzt Groq Whisper API für Transkription und optional Groq Chat für LLM-Postprocessing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
