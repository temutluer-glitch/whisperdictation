import SwiftUI

struct LLMPromptsSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selectedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("LLM-Postprocessing aktivieren", isOn: $settings.llmEnabled)
                .font(.headline)

            HStack {
                Text("Model:")
                TextField("Groq Model ID", text: $settings.llmModel)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Link("Modelle", destination: URL(string: "https://console.groq.com/docs/models")!)
                    .font(.caption)
            }

            HStack {
                Text("Aktives Preset:")
                Picker("", selection: $settings.activePresetID) {
                    ForEach(settings.llmPresets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer()
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
                Button("Auf Defaults zurücksetzen") { settings.llmPresets = PromptPreset.defaults }
            }
        }
        .padding()
        .onAppear {
            if selectedID == nil { selectedID = settings.activePresetID ?? settings.llmPresets.first?.id }
        }
    }

    private var presetList: some View {
        List(settings.llmPresets, selection: $selectedID) { preset in
            HStack {
                Text(preset.name)
                Spacer()
                if preset.id == settings.activePresetID {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
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
                .disabled(preset.id == PromptPreset.raw.id)

                Text("Instruction (System-Prompt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { settings.llmPresets[idx].instruction },
                    set: { settings.llmPresets[idx].instruction = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180)
                .border(Color.secondary.opacity(0.3))
                .disabled(preset.id == PromptPreset.raw.id)
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
        if settings.activePresetID == id { settings.activePresetID = PromptPreset.raw.id }
        selectedID = settings.llmPresets.first?.id
    }
}
