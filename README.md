# WhisperDictation

Systemweite Diktier-App für macOS. Hotkey drücken, sprechen, Text landet in der aktiven App. Nutzt Groq Whisper (`whisper-large-v3-turbo`) zur Transkription und optional Groq Llama zur automatischen Nachbearbeitung (z.B. Füllwörter entfernen, als E-Mail formatieren).

**Status**: Code ist komplett und per Swift Package Manager erfolgreich kompiliert (alle 16 Swift-Dateien bauen ohne Fehler). Für die fertige `.app` mit Mikrofon-Permission brauchst du eine einmalige Setup-Runde mit Xcode.

## Einmaliges Setup

### 1. Xcode installieren
Öffne den Mac App Store und installiere **Xcode** (kostenlos, ~15 GB). Nach der Installation einmal starten, damit Xcode sich komplett einrichtet und die Lizenz akzeptiert wird.

Danach im Terminal den Developer-Pfad auf Xcode umschalten (statt Command Line Tools):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 2. Xcode-Projekt generieren

Wir nutzen `xcodegen`, um aus `project.yml` ein vollwertiges `.xcodeproj` zu erzeugen. Der xcodegen-Binary liegt unter `/tmp/xcodegen-dl/xcodegen/bin/xcodegen` (von der Setup-Session). Falls du Homebrew installieren willst, geht auch `brew install xcodegen`. Alternativ:

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"

# Option A: xcodegen-Binary von der Setup-Session nutzen
/tmp/xcodegen-dl/xcodegen/bin/xcodegen generate

# Option B: frisches xcodegen aus dem GitHub-Release holen
curl -sSL -o /tmp/xcg.zip https://github.com/yonaskolb/XcodeGen/releases/download/2.42.0/xcodegen.zip
unzip -q /tmp/xcg.zip -d /tmp/xcg && /tmp/xcg/xcodegen/bin/xcodegen generate

# Dann öffnen:
open WhisperDictation.xcodeproj
```

Xcode öffnet sich mit dem fertigen Projekt. Beim ersten Öffnen lädt Swift Package Manager automatisch die `HotKey`-Dependency (https://github.com/soffes/HotKey).

### 3. Build & Run
In Xcode `⌘R` drücken. Die App startet als Menu-Bar-App (kein Dock-Icon, nur ein Icon oben rechts in der Menüleiste).

### 4. Groq API-Key holen
Auf https://console.groq.com/keys einen kostenlosen Key erstellen und beim ersten Start in den Settings eintragen. Der Key wird im macOS-Keychain abgelegt, nicht im Klartext auf der Platte.

### 5. Permissions erteilen
- **Mikrofon**: Beim ersten Hotkey-Druck fragt macOS automatisch.
- **Bedienungshilfen** (für Text-Injection): Die App zeigt beim ersten Start einen Dialog und öffnet auf Klick die richtige Stelle in den Systemeinstellungen. Dort `WhisperDictation` aktivieren und die App neu starten.

## Bedienung

- **Default-Hotkey**: `⌥ + Space` (Alt + Leertaste)
- **Hold-to-Talk**: Hotkey gedrückt halten → sprechen → loslassen → Text wird eingefügt
- **Toggle-Mode**: Hotkey einmal drücken → sprechen → nochmal drücken (in Settings umstellbar)

Menu-Bar-Icon zeigt den Status:
- `mic` — bereit
- `mic.fill` — aufnehmend
- `waveform` — transkribiert / verarbeitet
- `exclamationmark.triangle` — Fehler

## Settings

Menu-Bar-Icon → **Einstellungen…** öffnet das Einstellungsfenster mit Tabs:

- **General**: Launch at Login, Output-Modus (Paste vs. Clipboard-only), Sounds
- **Hotkey**: Hotkey per Klick neu aufnehmen, Hold vs Toggle umschalten
- **Transkription**: Groq API Key, Whisper-Modell (turbo/large-v3), Sprach-Hint
- **LLM Prompts**: LLM-Postprocessing aktivieren, Prompt-Presets verwalten. Mitgeliefert: "Raw", "Clean-up", "E-Mail", "Stichpunkte", "Auf Englisch übersetzen". Alle editierbar, eigene hinzufügbar.
- **History**: Letzte 50 Transkriptionen mit Copy/Delete/Rohtext-Vergleich

## Architektur (kurz)

```
WhisperDictation/
├── Package.swift              ← für "swift build" (Validierung, keine .app)
├── project.yml                ← für xcodegen → WhisperDictation.xcodeproj
├── SupportingFiles/Info.plist ← wird von xcodegen generiert
└── Sources/WhisperDictation/
    ├── WhisperDictationApp.swift
    ├── AppState.swift
    ├── Models/                (Settings, PromptPreset)
    ├── Services/              (HotkeyManager, AudioRecorder, GroqTranscriptionService,
    │                           GroqLLMService, TextInjector, KeychainStore, SettingsStore,
    │                           LaunchAtLogin, TranscriptionHistory, DictationCoordinator)
    └── Views/                 (SettingsView + 5 Tabs, HistoryView)
```

Der `DictationCoordinator` ist der Knotenpunkt: empfängt Hotkey-Events, steuert den `AudioRecorder`, ruft `GroqTranscriptionService` und optional `GroqLLMService` auf, und übergibt das Ergebnis an `TextInjector`, der per Clipboard-Snapshot + Cmd+V einfügt und dein ursprüngliches Clipboard nach ~250ms wiederherstellt.

## Troubleshooting

**"Signature wird nicht akzeptiert"**: Das Projekt ist auf Ad-hoc-Signing gestellt (`Sign to Run Locally`, `CODE_SIGN_IDENTITY: "-"`). Beim ersten Start evtl. Gatekeeper-Warnung → Rechtsklick auf die App → "Öffnen".

**Paste funktioniert nicht**: Bedienungshilfen-Permission fehlt. `Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen` öffnen und WhisperDictation aktivieren. App danach neu starten.

**Transkription schlägt fehl**: API-Key prüfen (Settings → Transkription), Internet-Verbindung prüfen. Fehler erscheinen als Alert-Dialog.

**Hotkey reagiert nicht**: Wenn du einen Hotkey ohne Modifier wählst, bleibt Hold-to-Talk im Toggle-Verhalten hängen — Hold-to-Talk braucht mindestens ⌘/⌥/⌃/⇧, damit die App erkennt, wann du loslässt. Notfalls auf Toggle umstellen.

## Zukunft / nicht im MVP

- Auto-Stop bei Stille (bräuchte Umstieg auf `AVAudioEngine` + RMS-Level-Monitoring; Hold und Toggle decken 95% ab)
- Mehrere Provider-Optionen für LLM (OpenAI, Anthropic)
- Inline-Preset-Switcher im Menu-Bar-Dropdown
- Streaming-Transkription während der Aufnahme
