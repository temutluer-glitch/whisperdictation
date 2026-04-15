import SwiftUI
import AppKit
import Carbon.HIToolbox

struct HotkeySettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var isCapturing = false

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Aktueller Hotkey:")
                    Spacer()
                    Text(settings.hotkeyConfig.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Button(isCapturing ? "Drücke neue Tastenkombination…" : "Hotkey ändern") {
                    isCapturing.toggle()
                }
                .background(
                    HotkeyCaptureView(isCapturing: $isCapturing) { newConfig in
                        settings.hotkeyConfig = newConfig
                        isCapturing = false
                    }
                )
            }

            Section("Modus") {
                Picker("Verhalten", selection: $settings.hotkeyMode) {
                    ForEach(HotkeyMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Hinweis: Hold-to-Talk setzt voraus, dass der Hotkey mindestens einen Modifier (⌘ ⌥ ⌃ ⇧) enthält.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct HotkeyCaptureView: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onCapture: (HotkeyConfig) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.isCapturing = isCapturing
        if isCapturing {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class CaptureNSView: NSView {
        var isCapturing = false
        var onCapture: ((HotkeyConfig) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isCapturing else { super.keyDown(with: event); return }
            var carbonFlags: UInt32 = 0
            let flags = event.modifierFlags
            if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
            if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
            if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
            if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }

            let config = HotkeyConfig(keyCode: UInt32(event.keyCode), modifierFlags: carbonFlags)
            onCapture?(config)
        }
    }
}
