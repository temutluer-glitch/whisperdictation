import SwiftUI

struct TranscriptionSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var revealKey = false
    @State private var availableDevices: [AudioInputDevice] = []

    var body: some View {
        Form {
            Section("Mikrofon") {
                Picker("Eingangsquelle", selection: $settings.preferredInputDeviceID) {
                    Text("System-Standard (folgt Auswahl der Systemeinstellungen)")
                        .tag("")
                    if !availableDevices.isEmpty {
                        Divider()
                        ForEach(availableDevices) { device in
                            Text(deviceLabel(device)).tag(device.id)
                        }
                    }
                    if !settings.preferredInputDeviceID.isEmpty,
                       !availableDevices.contains(where: { $0.id == settings.preferredInputDeviceID }) {
                        Divider()
                        Text("Aktuell fixiert (offline): \(settings.preferredInputDeviceID)")
                            .tag(settings.preferredInputDeviceID)
                    }
                }
                .pickerStyle(.menu)
                HStack {
                    Text("Verhindert, dass die Aufnahme bei eingestecktem Kopfhörer auf dessen Mikrofon umschaltet. Ist das fixierte Gerät offline, fällt die App auf den System-Standard zurück.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Liste aktualisieren") { reloadDevices() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

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
        .onAppear { reloadDevices() }
    }

    private func reloadDevices() {
        availableDevices = AudioDeviceCatalog.availableInputDevices()
    }

    private func deviceLabel(_ device: AudioInputDevice) -> String {
        if device.manufacturer.isEmpty {
            return device.name
        }
        return "\(device.name) – \(device.manufacturer)"
    }
}
