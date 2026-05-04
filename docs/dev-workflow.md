# Dev-Workflow für Timur

Dieser Guide beschreibt den End-zu-End-Loop, wenn du **eine Änderung an WhisperDictation machen willst und sie bei allen Team-Mitgliedern ankommen soll**.

Es gibt nur einen Distributions-Pfad: GitHub-Release + Sparkle-Auto-Update. Du arbeitest lokal, pushst nach `main`, machst ein Release, und alle Mitarbeiter bekommen die neue Version automatisch innerhalb 24 h.

## Voraussetzungen (einmalig)

Wenn du noch nie release.sh ausgeführt hast: erst [docs/release-workflow.md](release-workflow.md) Initial-Setup durchgehen (Self-Signed-Cert + Sparkle-Keys + Repo-Public).

## Der Ablauf in 4 Schritten

```
1. ÄNDERN     →    Code im Editor anpassen
2. TESTEN     →    swift build + Build + In /Applications testen
3. COMMITTEN  →    git add + commit + push
4. RELEASEN   →    ./scripts/release.sh X.Y.Z "Notes"
```

Jeder Schritt im Detail.

### 1. Ändern

Repo: `/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation`

Wo welcher Code lebt:

| Was du ändern willst | Wo |
|----------------------|-----|
| Neue Sprache, Whisper-Modell, Groq-Endpoint | `Sources/WhisperDictation/Services/GroqTranscriptionService.swift` |
| LLM-Postprocessing-Logik | `Sources/WhisperDictation/Services/GroqLLMService.swift` |
| Sprechblase (Position, Aussehen, Animation) | `Sources/WhisperDictation/Services/CursorOverlay.swift` + `Views/RecordingIndicatorView.swift` |
| Hotkey-Verhalten | `Sources/WhisperDictation/Services/HotkeyManager.swift` |
| Settings-Tabs / UI | `Sources/WhisperDictation/Views/` |
| Default-Hotkey, Default-Sprache, Hallucination-Filter | `Sources/WhisperDictation/Services/SettingsStore.swift` und `DictationCoordinator.swift` |
| Text-Insertion (Paste-Logik) | `Sources/WhisperDictation/Services/TextInjector.swift` |
| Version, Bundle-ID, Sparkle-URL | `project.yml` |
| Onboarding-Doku, README | `docs/`, `README.md` |

Tipp: bei größeren Änderungen Claude Code im Repo-Ordner starten und beschreiben was du willst, dann werden die richtigen Files angefasst.

### 2. Testen

#### Schneller Sanity-Check (5 Sekunden, kein Sign)

```bash
swift build
```

Sagt nur, ob alle Sources kompilieren. Kein .app, keine UI.

#### Vollständiger lokaler Test (~30 Sekunden)

```bash
./scripts/build-release.sh
```

Baut signed `.app` + `.zip` + `.dmg` in `/tmp/wd-build/...` bzw. `dist/`. Danach manuell installieren:

```bash
pkill -9 -f "WhisperDictation.app"
rm -rf /Applications/WhisperDictation.app
ditto /tmp/wd-build/Build/Products/Release/WhisperDictation.app /Applications/WhisperDictation.app
open /Applications/WhisperDictation.app
```

**Wichtig**: nach diesem manuellen Reinstall verlangt macOS die Bedienungshilfen-Permission neu (siehe [Bekanntes Problem](#bekannte-stolperfallen) unten). Im Menü erscheint dann oben "Bedienungshilfen fehlen, hier öffnen". Klick drauf, Schalter aktivieren, App neu starten.

Dann: deine Änderung in echten Apps ausprobieren. Falls Sprechblase, Insertion oder ähnliches involviert ist, schau in [docs/overlay-test-matrix.md](overlay-test-matrix.md) für die Apps die du checken solltest.

#### Logs ansehen

Live-Logs während du testest:

```bash
tail -f /tmp/whisperdictation.log
```

Da steht alles drin: Hotkey-Press/Release, Overlay-Anchor-Berechnungen mit Rejection-Gründen, Inject-Mode, Permission-Status. Wenn was nicht funktioniert, ist die Antwort meistens hier.

### 3. Committen

Wenn der lokale Test gut war:

```bash
git add <files>
git commit -m "fix: <was und warum>"
git push origin main
```

Commit-Message-Konvention: `fix:` für Bugfix, `feat:` für neues Feature, `docs:` für Doku, `chore:` für Wartung. Body kann mehrzeilig sein und sollte den **Why** erklären, nicht den **What**.

Für reine Doku- oder Build-Skript-Änderungen: hier kannst du aufhören. Mitarbeiter brauchen kein neues App-Release.

Für alles was an `Sources/` oder Bundle-Inhalten klebt: weiter zu Schritt 4.

### 4. Releasen

Eine signierte Version mit Auto-Update-Distribution erstellen:

```bash
./scripts/release.sh 1.1.3 "Kurze Beschreibung der Änderung"
```

Was passiert:
1. Version-Bump in `project.yml` (1.1.2 → 1.1.3)
2. Build + Sign + ZIP + DMG
3. Sparkle EdDSA-Signatur fürs ZIP
4. `appcast.xml` aktualisieren
5. Commit `release: v1.1.3` + Tag `v1.1.3` + Push
6. GitHub Release erstellen mit ZIP + DMG als Assets

Versionsschema (Semver):
- **PATCH** (1.1.2 → 1.1.3): Bugfix
- **MINOR** (1.1.x → 1.2.0): Neues Feature, abwärtskompatibel
- **MAJOR** (1.x.x → 2.0.0): Settings-Migration, Breaking Change

Die Release-Notes landen in drei Stellen: Git-Commit, appcast.xml-Description (Sparkle-Update-Dialog beim Mitarbeiter), GitHub-Release-Page.

Innerhalb 24 h (oder bei manuellem "Auf Updates prüfen" im Menü) bekommen alle Team-Mitglieder das Update.

## Wann release.sh, wann nur git push?

| Was geändert | git push allein | release.sh nötig |
|-------------|:---------------:|:----------------:|
| Doku unter `docs/`, `README.md` | ja | nein |
| Build-Skripte unter `scripts/` (nicht funktional fürs Release) | ja | nein |
| Code unter `Sources/` | nein | ja |
| `project.yml`, Entitlements | nein | ja |
| `Package.swift`, neue Dependencies | nein | ja |
| Übersetzungen / Asset-Änderungen | nein | ja |

Wenn unsicher: `release.sh`. Es ist billiger einen Release zu fahren als zu rätseln warum Mitarbeiter eine Änderung nicht sehen.

## Bekannte Stolperfallen

### Bedienungshilfen-Permission verschwindet nach lokalem Reinstall

Reproduzierbar bei lokalem `rm -rf` + `ditto` (= dein Test-Workflow). macOS TCC invalidiert den Eintrag, obwohl die Designated Requirement gleich bleibt. Sparkle-In-Place-Updates erhalten die Permission, lokale Reinstalls nicht.

**Workaround**: nach jedem Test-Reinstall einmal im Menü auf "Bedienungshilfen fehlen, hier öffnen" klicken, Schalter aktivieren, App neu starten. Erst dann wirken Hotkey-Paste und Sprechblase.

### Sparkle-Update verlangt Admin-Passwort

Einmalig pro Update, weil Sparkles Installer Schreibzugriff auf `/Applications` braucht. Das ist normales macOS-Verhalten für selbst-signierte Apps ohne privileged Helper. Die Bedienungshilfen-Permission bleibt dabei erhalten.

### Build schlägt mit "no signing identity"

```bash
security find-identity -v -p codesigning | grep WhisperDictation
```

Muss eine Zeile zurückgeben. Falls nicht: `./scripts/setup-signing-cert.sh` neu ausführen.

### release.sh blockt mit "uncommittierte Änderungen"

Erst mit `git status` schauen was offen ist, dann entweder committen (`git add ... && git commit -m "..."`) oder verwerfen (`git restore ...`). Erst dann release.sh.

### Größere Architektur-Änderung geplant

Vor dem Loslegen: kurz Claude Code im Repo starten, Anforderung beschreiben, einen Plan generieren lassen. Bei umfangreicheren Umbauten ist das schneller als sich allein einzuarbeiten.

## Notfall-Rollback

Falls ein Release etwas kaputt macht und Mitarbeiter melden Probleme:

```bash
# 1. Vorherige Version als neuen Release rauspushen (höhere Versionsnummer wegen Sparkle-monotonic-Pflicht)
git checkout v1.1.2 -- Sources/  # alten Code zurückholen
./scripts/release.sh 1.1.4 "Rollback auf v1.1.2 wegen Bug XYZ"
```

Sparkle bietet jedem Mitarbeiter automatisch die neuere v1.1.4 an, die inhaltlich identisch zu v1.1.2 ist. Die kaputte v1.1.3 bleibt auf GitHub als Tag, wird aber nicht mehr automatisch ausgespielt.

Wenn die kaputte Version niemand bekommen soll der sie noch nicht hat: zusätzlich den entsprechenden Eintrag aus `appcast.xml` löschen und committen, dann sehen neue Updater die Version gar nicht erst.

## Verwandte Docs

- [release-workflow.md](release-workflow.md) — Initial-Setup von Cert + Sparkle-Keys + Repo
- [onboarding-team.md](onboarding-team.md) — was Mitarbeiter machen müssen (für dich gut zu kennen, falls einer fragt)
- [overlay-test-matrix.md](overlay-test-matrix.md) — Test-Plan für die Sprechblase nach Overlay-Änderungen
