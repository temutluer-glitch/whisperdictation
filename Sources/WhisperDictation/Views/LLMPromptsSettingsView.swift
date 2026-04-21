import SwiftUI

struct LLMPromptsSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selectedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt-Presets")
                .font(.headline)

            Text("Jedes Preset ist eine LLM-Anweisung, die nach der Transkription auf den Text angewendet wird. Verbinde Presets im 'Hotkey'-Tab mit Tastenkombinationen. 'Raw' (leeres Preset) gibt den unveränderten Text zurück.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("LLM-Modell:")
                TextField("Groq Model ID", text: $settings.llmModel)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Link("Modelle", destination: URL(string: "https://console.groq.com/docs/models")!)
                    .font(.caption)
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                presetList
                    .frame(width: 200)

                presetEditor
            }

            HStack {
                Button("Neu") { addPreset() }
                Button("Duplizieren") { duplicatePreset() }.disabled(selectedPreset == nil)
                Button("Löschen", role: .destructive) { deletePreset() }
                    .disabled(selectedPreset == nil || selectedPreset?.id == PromptPreset.raw.id)
                Spacer()
                Button("Auf Defaults zurücksetzen") {
                    settings.llmPresets = PromptPreset.defaults
                }
            }
        }
        .padding()
        .onAppear {
            if selectedID == nil { selectedID = settings.llmPresets.first?.id }
        }
    }

    private var presetList: some View {
        List(settings.llmPresets, selection: $selectedID) { preset in
            HStack {
                Text(preset.name)
                Spacer()
                if preset.instruction.isEmpty {
                    Text("Raw")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tag(Optional(preset.id))
        }
        .listStyle(.bordered)
    }

    private var presetEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let preset = selectedPreset, let idx = presetIndex(preset.id) {
                TextField("Name", text: Binding(
                    get: { settings.llmPresets[idx].name },
                    set: { settings.llmPresets[idx].name = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Text("Instruction (System-Prompt). Leer = Raw, kein LLM-Aufruf.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { settings.llmPresets[idx].instruction },
                    set: { settings.llmPresets[idx].instruction = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180)
                .border(Color.secondary.opacity(0.3))
            } else {
                Text("Wähle links ein Preset oder erstelle ein neues.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedPreset: PromptPreset? {
        guard let id = selectedID else { return nil }
        return settings.llmPresets.first(where: { $0.id == id })
    }

    private func presetIndex(_ id: UUID) -> Int? {
        settings.llmPresets.firstIndex(where: { $0.id == id })
    }

    private func addPreset() {
        let new = PromptPreset(name: "Neues Preset", instruction: "")
        settings.llmPresets.append(new)
        selectedID = new.id
    }

    private func duplicatePreset() {
        guard let preset = selectedPreset else { return }
        let copy = PromptPreset(name: preset.name + " (Kopie)", instruction: preset.instruction)
        settings.llmPresets.append(copy)
        selectedID = copy.id
    }

    private func deletePreset() {
        guard let id = selectedID else { return }
        settings.llmPresets.removeAll { $0.id == id }
        settings.hotkeyBindings.removeAll { $0.presetID == id }
        selectedID = settings.llmPresets.first?.id
    }
}
