# WhisperDictation

Systemweite Diktier-App für macOS. Hotkey drücken, sprechen, Text landet in der aktiven App. Nutzt Groq Whisper (`whisper-large-v3-turbo`) zur Transkription und optional Groq Llama zur automatischen Nachbearbeitung (z.B. Füllwörter entfernen, als E-Mail formatieren).

Auto-Updates via Sparkle. Code-Signing über Self-Signed-Cert (kein Apple Developer Account nötig).

## Bedienung

- **Default-Hotkey**: ⌥ + Space (Alt + Leertaste)
- **Hold-to-Talk**: Hotkey gedrückt halten → sprechen → loslassen → Text wird eingefügt
- **Toggle-Mode**: Hotkey einmal drücken → sprechen → nochmal drücken (in Settings umstellbar)

Menu-Bar-Icon zeigt den Status:
- `mic` – bereit
- `mic.fill` – aufnehmend
- `waveform` – transkribiert / verarbeitet
- `exclamationmark.triangle` – Fehler

## Settings

Menu-Bar-Icon → **Einstellungen…** öffnet das Einstellungsfenster:

- **General**: Launch at Login, Output-Modus, Sounds, **Auto-Updates**
- **Hotkey**: Hotkey per Klick neu aufnehmen, Hold vs Toggle umschalten
- **Transkription**: Groq API Key, Whisper-Modell, Sprach-Hint
- **LLM Prompts**: LLM-Postprocessing aktivieren, Prompt-Presets
- **History**: Letzte 50 Transkriptionen mit Copy/Delete

## Für Entwickler

### Setup

1. **Xcode** installieren (Mac App Store) und einmal starten.
2. `xcodegen` installieren: `brew install xcodegen` (oder Binary von [Releases](https://github.com/yonaskolb/XcodeGen/releases) ziehen).
3. Projekt generieren und öffnen:

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"
xcodegen generate
open WhisperDictation.xcodeproj
```

In Xcode `⌘R` drücken. Beim ersten Build lädt Swift Package Manager `HotKey` und `Sparkle`.

### Validierungs-Build (ohne .app)

```bash
swift build
```

Schneller Sanity-Check, dass alle Sources kompilieren.

### Release ausrollen

Siehe ausführliche [docs/release-workflow.md](docs/release-workflow.md). Kurz:

```bash
# Einmaliges Setup:
./scripts/setup-signing-cert.sh
./scripts/setup-sparkle-keys.sh

# Pro Release:
./scripts/release.sh 1.2.0 "Release-Notes hier"
```

### Onboarding für Team-Mitglieder

Siehe [docs/onboarding-team.md](docs/onboarding-team.md).

## Architektur

```
WhisperDictation/
├── Package.swift                ← swift build (Validierung)
├── project.yml                  ← xcodegen → .xcodeproj
├── SupportingFiles/Info.plist
├── scripts/
│   ├── setup-signing-cert.sh    ← einmalig: Self-Signed Cert
│   ├── setup-sparkle-keys.sh    ← einmalig: Sparkle EdDSA
│   ├── build-release.sh         ← Build + Re-Sign
│   └── release.sh               ← End-to-End Release
├── docs/
│   ├── release-workflow.md
│   ├── onboarding-team.md
│   └── overlay-test-matrix.md
└── Sources/WhisperDictation/
    ├── WhisperDictationApp.swift
    ├── AppState.swift
    ├── WhisperDictation.entitlements
    ├── Models/                  (Settings, PromptPreset)
    ├── Services/                (HotkeyManager, AudioRecorder,
    │                             GroqTranscriptionService, GroqLLMService,
    │                             TextInjector, KeychainStore, SettingsStore,
    │                             LaunchAtLogin, TranscriptionHistory,
    │                             DictationCoordinator, CursorOverlay,
    │                             UpdateController, DebugLog)
    └── Views/                   (SettingsView + 5 Tabs, HistoryView,
                                   RecordingIndicatorView)
```

`DictationCoordinator` ist der Knotenpunkt: empfängt Hotkey-Events, steuert `AudioRecorder`, ruft `GroqTranscriptionService` und optional `GroqLLMService` auf, übergibt das Ergebnis an `TextInjector` (Clipboard-Snapshot + Cmd+V, Restore nach 600 ms).

`CursorOverlay` zeigt die Sprechblase nahe dem aktiven Textfeld. Anchor-Reihenfolge: caret-bounds → focused-element-top-center → mouse-position. Multi-Monitor-aware.

`UpdateController` kapselt Sparkle (`SPUStandardUpdaterController`).

## Troubleshooting

**Bedienungshilfen-Permission verloren**: kann passieren, wenn die App ohne stabile Code-Signatur gebaut und ersetzt wurde. Lösung: in den Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen den alten Eintrag entfernen und die neu installierte App wieder aktivieren.

**Hotkey reagiert nicht (Hold-to-Talk)**: Hold braucht mindestens einen Modifier (⌥/⌘/⌃/⇧). Notfalls auf Toggle umstellen.

**Sparkle-Updates kommen nicht**: `defaults read com.innosolv.WhisperDictation SUFeedURL` muss die Releases-Repo-URL zeigen. Manuell prüfen: Menüleiste → "Auf Updates prüfen…".

## Zukunft / nicht im MVP

- Auto-Stop bei Stille (AVAudioEngine + RMS-Monitoring)
- Mehrere Provider (OpenAI, Anthropic) für LLM-Postprocessing
- Inline-Preset-Switcher im Menu-Bar-Dropdown
- Streaming-Transkription während der Aufnahme
