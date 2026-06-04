import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var updater: UpdateController
    @EnvironmentObject private var onboarding: OnboardingController

    var body: some View {
        Form {
            Section("Verhalten") {
                Toggle("Beim Login starten", isOn: $settings.launchAtLogin)
                Toggle("Sounds bei Start/Stop", isOn: $settings.playSounds)
            }

            Section("Einrichtung") {
                HStack {
                    Text("Einrichtungs-Assistent")
                    Spacer()
                    Button("Onboarding nochmal starten") {
                        onboarding.presentFromStart()
                    }
                }
                Text("Führt dich erneut durch API-Key, Berechtigungen, Mikrofon, Hotkey und ein Test-Diktat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ausgabe") {
                Picker("Modus", selection: $settings.outputMode) {
                    ForEach(OutputMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Updates") {
                Toggle("Automatisch nach Updates suchen", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.setAutomaticallyChecksForUpdates($0) }
                ))
                HStack {
                    Button("Jetzt nach Updates suchen") {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates)
                    Spacer()
                    Text("Version \(updater.currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Über") {
                Text("InnoWhisper – systemweite Diktierfunktion")
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
