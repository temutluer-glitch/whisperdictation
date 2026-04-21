import SwiftUI
import AppKit
import Carbon.HIToolbox

struct HotkeySettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hotkey-Bindings")
                .font(.headline)

            Text("Jeder Hotkey ist mit einem Prompt-Preset verknüpft. Drückst du den Hotkey, läuft die Aufnahme automatisch durch das verbundene Preset (oder bleibt 'Raw' für ungefilterten Text).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($settings.hotkeyBindings) { $binding in
                        BindingRow(
                            binding: $binding,
                            presets: settings.llmPresets,
                            onDelete: { remove(binding.id) }
                        )
                    }
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("+ Neues Binding") { addBinding() }
                Spacer()
                if settings.hotkeyBindings.count > 0 {
                    Text("\(settings.hotkeyBindings.count) aktiv")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func addBinding() {
        let preset = settings.llmPresets.first ?? PromptPreset.raw
        settings.hotkeyBindings.append(
            HotkeyBinding(presetID: preset.id, config: .defaultConfig, mode: .holdToTalk)
        )
    }

    private func remove(_ id: UUID) {
        settings.hotkeyBindings.removeAll { $0.id == id }
    }
}

private struct BindingRow: View {
    @Binding var binding: HotkeyBinding
    let presets: [PromptPreset]
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HotkeyCaptureField(config: $binding.config)
                .frame(width: 170)

            Picker("", selection: $binding.mode) {
                ForEach(HotkeyMode.allCases) { mode in
                    Text(modeShortLabel(mode)).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            Picker("", selection: $binding.presetID) {
                ForEach(presets) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func modeShortLabel(_ mode: HotkeyMode) -> String {
        switch mode {
        case .holdToTalk: return "Hold"
        case .toggle: return "Toggle"
        }
    }
}

struct HotkeyCaptureField: NSViewRepresentable {
    @Binding var config: HotkeyConfig

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = { newConfig in
            DispatchQueue.main.async {
                self.config = newConfig
            }
        }
        view.update(displayString: config.displayString)
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.update(displayString: config.displayString)
    }

    final class CaptureNSView: NSView {
        var onCapture: ((HotkeyConfig) -> Void)?
        private var monitor: Any?
        private let label = NSTextField(labelWithString: "")
        private var isCapturing = false

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

            label.alignment = .center
            label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            label.textColor = .labelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                heightAnchor.constraint(equalToConstant: 26)
            ])

            let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
            addGestureRecognizer(click)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
            if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        }

        func update(displayString: String) {
            if !isCapturing {
                label.stringValue = displayString
            }
        }

        @objc private func handleClick() {
            if isCapturing {
                stopCapture(restoreOriginal: true)
            } else {
                startCapture()
            }
        }

        private var flagsMonitor: Any?
        private var pendingModifier: ModifierKey?

        private func startCapture() {
            isCapturing = true
            label.stringValue = "Tasten drücken… (ESC abbrechen)"
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            pendingModifier = nil

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == kVK_Escape {
                    self.stopCapture(restoreOriginal: true)
                    return nil
                }
                var carbon: UInt32 = 0
                let f = event.modifierFlags
                if f.contains(.command) { carbon |= UInt32(cmdKey) }
                if f.contains(.option) { carbon |= UInt32(optionKey) }
                if f.contains(.control) { carbon |= UInt32(controlKey) }
                if f.contains(.shift) { carbon |= UInt32(shiftKey) }
                let newConfig = HotkeyConfig(keyCode: UInt32(event.keyCode), modifierFlags: carbon, modifierOnly: nil)
                self.onCapture?(newConfig)
                self.label.stringValue = newConfig.displayString
                self.stopCapture(restoreOriginal: false)
                return nil
            }

            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
                guard let self, self.isCapturing else { return event }
                let raw = UInt(event.modifierFlags.rawValue)
                if let detected = ModifierKey.detect(from: raw) {
                    self.pendingModifier = detected
                    self.label.stringValue = "\(detected.shortSymbol) – loslassen bestätigt"
                } else if let detected = self.pendingModifier {
                    let newConfig = HotkeyConfig(keyCode: 0, modifierFlags: 0, modifierOnly: detected)
                    self.onCapture?(newConfig)
                    self.label.stringValue = newConfig.displayString
                    self.stopCapture(restoreOriginal: false)
                }
                return event
            }
        }

        private func stopCapture(restoreOriginal: Bool) {
            isCapturing = false
            pendingModifier = nil
            if let m = monitor { NSEvent.removeMonitor(m) }
            if let m = flagsMonitor { NSEvent.removeMonitor(m) }
            monitor = nil
            flagsMonitor = nil
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
