import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject private var controller: OnboardingController

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(current: controller.currentStep)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 14)

            Divider()

            ScrollView {
                stepContent
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            Divider()

            OnboardingFooter()
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
        }
        .frame(width: 580, height: 640)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch controller.currentStep {
        case .welcome: WelcomeStep()
        case .apiKey: APIKeyStep()
        case .microphonePermission: MicrophonePermissionStep()
        case .accessibilityPermission: AccessibilityPermissionStep()
        case .microphoneSelection: MicrophoneSelectionStep()
        case .hotkey: HotkeyStep()
        case .testDictation: TestDictationStep()
        case .done: DoneStep()
        }
    }
}

// MARK: - Gerüst

/// Großer Icon-/Titel-/Beschreibungs-Kopf, den jeder Schritt teilt.
private struct StepHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingProgressBar: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step <= current ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: step == current ? 22 : 8, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: current)
                }
            }
            Spacer()
            Text("Schritt \(current.rawValue + 1) von \(OnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct OnboardingFooter: View {
    @EnvironmentObject private var controller: OnboardingController

    var body: some View {
        HStack {
            if controller.canGoBack {
                Button("Zurück") { controller.goBack() }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            Button(primaryLabel) { controller.advance() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!controller.canAdvance)
        }
    }

    private var primaryLabel: String {
        switch controller.currentStep {
        case .done: return "Fertig"
        case .testDictation: return "Weiter"
        default: return "Weiter"
        }
    }
}

/// Wiederverwendbare Status-Zeile mit grünem Haken bzw. grauem Kreis.
private struct StatusRow: View {
    let granted: Bool
    let grantedText: String
    let pendingText: String

    var body: some View {
        Label {
            Text(granted ? grantedText : pendingText)
                .foregroundStyle(granted ? .primary : .secondary)
        } icon: {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
        }
        .font(.callout)
    }
}

// MARK: - Schritt 1: Willkommen

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "hand.wave",
                title: "Willkommen bei InnoWhisper",
                subtitle: "InnoWhisper diktiert systemweit per Tastendruck: Du hältst deinen Hotkey, sprichst, und der Text landet direkt in der App, in der du gerade tippst."
            )

            VStack(alignment: .leading, spacing: 12) {
                FeatureBullet(icon: "bolt.fill", text: "Schnelle Transkription über Groq Whisper")
                FeatureBullet(icon: "sparkles", text: "Optionale KI-Nachbearbeitung pro Hotkey")
                FeatureBullet(icon: "lock.fill", text: "API-Key bleibt lokal in deinem Schlüsselbund")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

            Text("Das Setup dauert ungefähr 2 Minuten. Wir gehen es Schritt für Schritt durch.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FeatureBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.tint)
            Text(text)
            Spacer()
        }
    }
}

// MARK: - Schritt 2: API-Key

private struct APIKeyStep: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var controller: OnboardingController
    @State private var revealKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "key",
                title: "Groq API-Key",
                subtitle: "InnoWhisper schickt deine Aufnahmen an Groq zur Transkription. Dafür brauchst du einen kostenlosen API-Key."
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Group {
                        if revealKey {
                            TextField("gsk_…", text: $settings.groqAPIKey)
                        } else {
                            SecureField("gsk_…", text: $settings.groqAPIKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    Button(revealKey ? "Verbergen" : "Zeigen") { revealKey.toggle() }
                }

                Link(destination: URL(string: "https://console.groq.com/keys")!) {
                    Label("Key auf console.groq.com/keys erstellen", systemImage: "arrow.up.right.square")
                        .font(.callout)
                }

                HStack(spacing: 10) {
                    Button("Key testen") { controller.validateAPIKey() }
                        .disabled(settings.groqAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
                                  || controller.keyValidation == .validating)
                    validationLabel
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

            Text("Der Key wird sicher im macOS-Schlüsselbund gespeichert und verlässt deinen Mac nur für die Anfragen an Groq.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: settings.groqAPIKey) { _, _ in
            controller.keyValidation = .unknown
        }
    }

    @ViewBuilder
    private var validationLabel: some View {
        switch controller.keyValidation {
        case .unknown:
            EmptyView()
        case .validating:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.5)
                Text("Prüfe…").font(.caption).foregroundStyle(.secondary)
            }
        case .valid:
            Label("Key funktioniert", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        }
    }
}

// MARK: - Schritt 3: Mikrofon-Permission

private struct MicrophonePermissionStep: View {
    @EnvironmentObject private var controller: OnboardingController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "mic",
                title: "Mikrofon-Zugriff",
                subtitle: "InnoWhisper braucht Zugriff auf dein Mikrofon, um deine Sprache aufzunehmen."
            )

            VStack(alignment: .leading, spacing: 14) {
                StatusRow(
                    granted: controller.micAuthorized,
                    grantedText: "Mikrofon-Zugriff erteilt",
                    pendingText: "Noch kein Mikrofon-Zugriff"
                )

                if !controller.micAuthorized {
                    Button {
                        controller.requestMicrophoneAccess()
                    } label: {
                        Label("Mikrofon-Zugriff erlauben", systemImage: "mic.fill")
                    }
                    .controlSize(.large)

                    Text("Falls kein Dialog erscheint, wurde der Zugriff evtl. früher abgelehnt. Aktiviere InnoWhisper dann unter Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        }
    }
}

// MARK: - Schritt 4: Bedienungshilfen

private struct AccessibilityPermissionStep: View {
    @EnvironmentObject private var controller: OnboardingController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "accessibility",
                title: "Bedienungshilfen",
                subtitle: "Um den fertigen Text in die aktive App einzufügen, simuliert InnoWhisper einen Cmd+V-Tastendruck. Dafür ist die Bedienungshilfen-Berechtigung nötig."
            )

            VStack(alignment: .leading, spacing: 14) {
                StatusRow(
                    granted: controller.axTrusted,
                    grantedText: "Bedienungshilfen-Zugriff erteilt",
                    pendingText: "Noch kein Bedienungshilfen-Zugriff"
                )

                if !controller.axTrusted {
                    Button {
                        controller.openAccessibilitySettings()
                    } label: {
                        Label("Bedienungshilfen öffnen", systemImage: "gearshape.fill")
                    }
                    .controlSize(.large)

                    Text("Aktiviere InnoWhisper in der Liste. Der Haken oben wird automatisch grün, sobald du den Zugriff erteilt hast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    restartHint
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        }
    }

    private var restartHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Label {
                Text("Empfohlen: einmal neu starten")
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(.orange)
            }
            Text("macOS übernimmt eine frisch erteilte Bedienungshilfen-Berechtigung erst nach einem Neustart der App zuverlässig. Danach geht es direkt mit der Mikrofon-Auswahl weiter.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                controller.relaunchApp()
            } label: {
                Label("InnoWhisper jetzt neu starten", systemImage: "arrow.clockwise")
            }
        }
    }
}

// MARK: - Schritt 5: Mikrofon-Auswahl

private struct MicrophoneSelectionStep: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var availableDevices: [AudioInputDevice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "waveform",
                title: "Mikrofon auswählen",
                subtitle: "Lass es auf dem System-Standard, oder fixiere ein bestimmtes Mikrofon, damit InnoWhisper nicht versehentlich auf das Kopfhörer-Mikro umschaltet."
            )

            VStack(alignment: .leading, spacing: 12) {
                Picker("Eingangsquelle", selection: $settings.preferredInputDeviceID) {
                    Text("System-Standard").tag("")
                    if !availableDevices.isEmpty {
                        Divider()
                        ForEach(availableDevices) { device in
                            Text(deviceLabel(device)).tag(device.id)
                        }
                    }
                }
                .pickerStyle(.menu)

                Button("Liste aktualisieren") { reloadDevices() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        }
        .onAppear(perform: reloadDevices)
    }

    private func reloadDevices() {
        availableDevices = AudioDeviceCatalog.availableInputDevices()
    }

    private func deviceLabel(_ device: AudioInputDevice) -> String {
        device.manufacturer.isEmpty ? device.name : "\(device.name) – \(device.manufacturer)"
    }
}

// MARK: - Schritt 6: Hotkey

private struct HotkeyStep: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "keyboard",
                title: "Dein Hotkey",
                subtitle: "Mit diesem Hotkey startest du eine Aufnahme. Der Standard ist ⌥ + Leertaste. Klick ins Feld, um einen eigenen festzulegen."
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text("Hotkey")
                        .frame(width: 70, alignment: .leading)
                    HotkeyCaptureField(config: bindingConfig)
                        .frame(width: 180)
                }

                HStack(spacing: 12) {
                    Text("Modus")
                        .frame(width: 70, alignment: .leading)
                    Picker("", selection: bindingMode) {
                        ForEach(HotkeyMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

            Text("Hold-to-Talk: gedrückt halten und sprechen, beim Loslassen wird transkribiert. Toggle: einmal drücken startet, nochmal drücken stoppt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bindingConfig: Binding<HotkeyConfig> {
        Binding(
            get: { settings.hotkeyBindings.first?.config ?? .defaultConfig },
            set: { newValue in
                ensureBinding()
                settings.hotkeyBindings[0].config = newValue
            }
        )
    }

    private var bindingMode: Binding<HotkeyMode> {
        Binding(
            get: { settings.hotkeyBindings.first?.mode ?? .holdToTalk },
            set: { newValue in
                ensureBinding()
                settings.hotkeyBindings[0].mode = newValue
            }
        )
    }

    private func ensureBinding() {
        if settings.hotkeyBindings.isEmpty {
            let preset = settings.llmPresets.first ?? PromptPreset.raw
            settings.hotkeyBindings = [HotkeyBinding(presetID: preset.id, config: .defaultConfig, mode: .holdToTalk)]
        }
    }
}

// MARK: - Schritt 7: Test-Diktat

private struct TestDictationStep: View {
    @EnvironmentObject private var tester: OnboardingDictationTester

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "checkmark.bubble",
                title: "Test-Diktat",
                subtitle: "Probier es einmal aus: Starte die Aufnahme, sprich einen Satz, und stoppe wieder. Der erkannte Text erscheint hier – noch ohne ihn irgendwo einzufügen."
            )

            VStack(spacing: 16) {
                recordingArea
                resultArea
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        }
    }

    @ViewBuilder
    private var recordingArea: some View {
        switch tester.phase {
        case .recording:
            VStack(spacing: 12) {
                RecordingIndicatorView(status: .recording, recorder: tester.recorder)
                Button(role: .destructive) {
                    tester.stopAndTranscribe()
                } label: {
                    Label("Aufnahme stoppen", systemImage: "stop.fill")
                }
                .controlSize(.large)
            }
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.7)
                Text("Transkribiere…").foregroundStyle(.secondary)
            }
            .frame(height: 44)
        default:
            Button {
                tester.startRecording()
            } label: {
                Label("Aufnahme starten", systemImage: "mic.fill")
            }
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        switch tester.phase {
        case .success(let text):
            VStack(alignment: .leading, spacing: 8) {
                Label("Erkannt", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(.green)
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            }
        case .failure(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Erneut versuchen") { tester.reset() }
                    Button("Mikrofon-Einstellungen") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        default:
            Text("Dieser Schritt ist optional – du kannst ihn auch überspringen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Schritt 8: Fertig

private struct DoneStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "sparkles",
                title: "Alles bereit",
                subtitle: "InnoWhisper läuft jetzt in deiner Menüleiste. Drück deinen Hotkey, wann immer du diktieren willst."
            )

            VStack(alignment: .leading, spacing: 12) {
                FeatureBullet(icon: "clock.arrow.circlepath", text: "History: alle Transkriptionen in den Einstellungen")
                FeatureBullet(icon: "text.book.closed", text: "Eigenes Wörterbuch für Namen und Fachbegriffe")
                FeatureBullet(icon: "arrow.down.circle", text: "Updates kommen automatisch über die Menüleiste")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

            Text("Du findest alle Einstellungen jederzeit über das Menüleisten-Symbol. Das Onboarding lässt sich dort unter „General“ erneut starten.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
