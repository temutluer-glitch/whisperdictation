# Feature-Request-Workflow Setup-Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den in [feature-request-workflow.md](feature-request-workflow.md) beschriebenen Prozess produktionsreif machen, damit ab dem nächsten Notion-Eintrag der vollständige Workflow läuft.

**Architecture:** Beta-Variante der App über Build-Time-Override im `project.yml` plus erweitertes `build-release.sh --beta`. Beta-Icon wird zur Build-Zeit aus Production-Icons generiert (Orange-Tint + β-Badge), Menubar-Icon im Swift-Code per Bundle-ID-Check differenziert. `beta`-Branch dient als Integrations-Branch für gleichzeitig testbare Features. Status-Lifecycle in Notion um `Release` erweitert. Workflow als Skill abgelegt, damit Claude in jeder Session weiß, wie Feature-Wünsche bearbeitet werden.

**Tech Stack:** Swift 5.9 / SwiftUI, xcodegen, xcodebuild, Sparkle 2.6, Bash, macOS CoreGraphics (Swift-Script für Icon-Generation), Notion MCP.

---

## File Structure

| Pfad | Verantwortlich | Aktion |
|---|---|---|
| `project.yml` | Build-Konfig, jetzt mit Env-Var-Overrides für Bundle-ID/Display-Name/Icon | modifizieren |
| `tools/generate-beta-icon.swift` | Generiert `AppIconBeta.appiconset` aus den Production-PNGs (Orange-Tint + β-Badge) | neu |
| `Sources/WhisperDictation/Assets.xcassets/AppIconBeta.appiconset/` | Beta-Icon-Set, zur Build-Zeit befüllt | neu (per Generator) |
| `Sources/WhisperDictation/AppState.swift` | Menubar-Icon-Logik, jetzt mit Beta-Detection per Bundle-ID | modifizieren |
| `scripts/build-release.sh` | `--beta`-Flag, der Beta-Variante baut, Sparkle disabled, in `/Applications/WhisperDictation Beta.app` installiert | modifizieren |
| `Skills/feature-request-workflow/SKILL.md` | Skill, der Claude den Workflow beibringt | neu |
| `WhisperDictation/CLAUDE.md` | Verweis auf den Workflow im Repo | neu (oder Update) |
| Notion-DB | Neue Status-Option `Release` | manuell via MCP |
| `beta`-Branch | Integrations-Branch | neu (initial leer = Kopie von main) |

---

## Task 1: Notion-DB um Status-Option `Release` erweitern

**Files:**
- Modify: Notion-DB `🎙️ WhisperDictation – Feature Wünsche` (Property `Status`)

- [ ] **Step 1: Schema vor der Änderung sichern**

Tool: `mcp__claude_ai_Notion__notion-fetch`
Argument: `{"id": "https://www.notion.so/innosolv/35623553acb780839d8ac203cf99d46f"}`
Erwartet: `Status`-Property hat heute die Optionen `Idee`, `Umsetzung`, `Human Review`, `Erledigt`.

- [ ] **Step 2: Status-Option `Release` zwischen `Human Review` und `Erledigt` einfügen**

Tool: `mcp__claude_ai_Notion__notion-update-data-source`
Data-Source-ID: `collection://35623553-acb7-80e6-8993-000b40fd4dbb`
Property: `Status`
Neue Option: `Release`, Farbe `orange`, Position vor `Erledigt`.
(Falls die Notion-API kein direktes Reorder erlaubt: nach Erstellen mit einem Folge-Update die Group-Zuordnung auf `in_progress` setzen.)

- [ ] **Step 3: Verifizieren**

Tool: `mcp__claude_ai_Notion__notion-fetch`, gleiche ID wie Step 1.
Erwartet: `Status` enthält jetzt 5 Optionen in der Reihenfolge `Idee → Umsetzung → Human Review → Release → Erledigt`.

- [ ] **Step 4: Kein git commit nötig**

Notion-Schema ist außerhalb des Repos. Direkt zu Task 2.

---

## Task 2: project.yml für Build-Time-Overrides anpassen

**Files:**
- Modify: `project.yml`

Ziel: `PRODUCT_BUNDLE_IDENTIFIER`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `ASSETCATALOG_COMPILER_APPICON_NAME`, `INFOPLIST_KEY_CFBundleDisplayName` sollen via Umgebungsvariable überschrieben werden können. So kann `build-release.sh --beta` die Beta-Variante bauen, ohne `project.yml` editieren zu müssen.

- [ ] **Step 1: Backup-Tag setzen**

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"
git checkout feature/feature-request-workflow
git tag pre-beta-setup
```

- [ ] **Step 2: project.yml im `settings.base`-Block auf Env-Var-Overrides umbauen**

Ersetze den `settings.base`-Block durch:

```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${WD_BUNDLE_ID:-com.innosolv.WhisperDictation}
        MARKETING_VERSION: "1.1.2"
        CURRENT_PROJECT_VERSION: "21"
        SWIFT_VERSION: "5.9"
        ENABLE_HARDENED_RUNTIME: YES
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"
        DEVELOPMENT_TEAM: ""
        CODE_SIGN_ENTITLEMENTS: Sources/WhisperDictation/WhisperDictation.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: ${WD_APPICON:-AppIcon}
        INFOPLIST_KEY_CFBundleDisplayName: ${WD_DISPLAY_NAME:-WhisperDictation}
```

Hinweis: `xcodegen` interpoliert `${VAR:-default}` aus der Shell-Umgebung. Wird die Variable nicht gesetzt, bleibt der Production-Default aktiv.

- [ ] **Step 3: Sparkle nur unter Production-Bundle-ID aktivieren**

Im `info.properties`-Block (gleicher Target-Block) `SUFeedURL` ebenfalls per Env-Var schaltbar machen:

```yaml
        SUFeedURL: ${WD_FEED_URL:-https://raw.githubusercontent.com/temutluer-glitch/whisperdictation/main/appcast.xml}
        SUEnableAutomaticChecks: ${WD_SPARKLE_ENABLED:-true}
```

`SUPublicEDKey` bleibt hardcoded.

- [ ] **Step 4: Production-Build verifizieren (Regression-Test)**

```bash
./scripts/build-release.sh
```

Erwartet:
- Build läuft durch.
- `dist/WhisperDictation-1.1.2.zip` und `dist/WhisperDictation-1.1.2.dmg` werden erzeugt.
- `codesign -dv` zeigt `Identifier=com.innosolv.WhisperDictation`.

Wenn das Build bricht: `git diff project.yml` prüfen, ob die Substitution korrekt ist. Möglicherweise muss `xcodegen` erst neu generiert werden.

- [ ] **Step 5: Commit**

```bash
git add project.yml
git commit -m "build: project.yml unterstützt Build-Time-Overrides für Beta-Variante"
```

---

## Task 3: Beta-Icon-Generator schreiben

**Files:**
- Create: `tools/generate-beta-icon.swift`

Der Generator liest die Production-Icons aus `Sources/WhisperDictation/Assets.xcassets/AppIcon.appiconset/`, wendet einen Orange-Tint an, malt unten rechts ein β-Badge und schreibt die Resultate nach `Sources/WhisperDictation/Assets.xcassets/AppIconBeta.appiconset/` inklusive `Contents.json`.

- [ ] **Step 1: Test-Skript schreiben (Snapshot-basiert)**

Create: `tools/test-generate-beta-icon.sh`

```bash
#!/usr/bin/env bash
# Smoke-Test für den Beta-Icon-Generator. Prüft:
# - Script läuft fehlerfrei.
# - Alle erwarteten PNGs werden erzeugt.
# - Contents.json ist gültiges JSON und referenziert genau diese PNGs.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$REPO_ROOT/Sources/WhisperDictation/Assets.xcassets/AppIconBeta.appiconset"
rm -rf "$ICONSET"
swift "$REPO_ROOT/tools/generate-beta-icon.swift"
EXPECTED=(
  icon_16x16.png icon_16x16@2x.png
  icon_32x32.png icon_32x32@2x.png
  icon_128x128.png icon_128x128@2x.png
  icon_256x256.png icon_256x256@2x.png
  icon_512x512.png icon_512x512@2x.png
  Contents.json
)
for f in "${EXPECTED[@]}"; do
  if [[ ! -f "$ICONSET/$f" ]]; then
    echo "fehler: $ICONSET/$f fehlt"
    exit 1
  fi
done
python3 -c "import json; json.load(open('$ICONSET/Contents.json'))"
echo "ok"
```

```bash
chmod +x tools/test-generate-beta-icon.sh
```

- [ ] **Step 2: Test ausführen, der Test schlägt fehl (Generator existiert noch nicht)**

```bash
./tools/test-generate-beta-icon.sh
```

Erwartet: `error: <unknown>:0: error: cannot find file 'tools/generate-beta-icon.swift'`

- [ ] **Step 3: Generator implementieren**

Create: `tools/generate-beta-icon.swift`

```swift
#!/usr/bin/env swift
// Liest Production-Icons aus AppIcon.appiconset und erzeugt eine Beta-Variante
// (Orange-Tint + kleines Greek-Beta-Badge unten rechts) in AppIconBeta.appiconset.
import AppKit
import CoreGraphics
import Foundation

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assets = repoRoot
    .appendingPathComponent("Sources/WhisperDictation/Assets.xcassets")
let sourceSet = assets.appendingPathComponent("AppIcon.appiconset")
let targetSet = assets.appendingPathComponent("AppIconBeta.appiconset")

if fileManager.fileExists(atPath: targetSet.path) {
    try fileManager.removeItem(at: targetSet)
}
try fileManager.createDirectory(at: targetSet, withIntermediateDirectories: true)

struct IconEntry { let size: Int; let scale: Int; let filename: String }

let entries: [IconEntry] = [
    .init(size: 16,  scale: 1, filename: "icon_16x16.png"),
    .init(size: 16,  scale: 2, filename: "icon_16x16@2x.png"),
    .init(size: 32,  scale: 1, filename: "icon_32x32.png"),
    .init(size: 32,  scale: 2, filename: "icon_32x32@2x.png"),
    .init(size: 128, scale: 1, filename: "icon_128x128.png"),
    .init(size: 128, scale: 2, filename: "icon_128x128@2x.png"),
    .init(size: 256, scale: 1, filename: "icon_256x256.png"),
    .init(size: 256, scale: 2, filename: "icon_256x256@2x.png"),
    .init(size: 512, scale: 1, filename: "icon_512x512.png"),
    .init(size: 512, scale: 2, filename: "icon_512x512@2x.png"),
]

func loadPNG(_ url: URL) -> CGImage {
    guard let dataProvider = CGDataProvider(url: url as CFURL),
          let image = CGImage(pngDataProviderSource: dataProvider,
                              decode: nil,
                              shouldInterpolate: true,
                              intent: .defaultIntent) else {
        FileHandle.standardError.write(Data("fehler: kann \(url.path) nicht lesen\n".utf8))
        exit(1)
    }
    return image
}

func tintAndBadge(image: CGImage, pixelSize: CGFloat) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = Int(pixelSize) * 4
    guard let ctx = CGContext(data: nil,
                              width: Int(pixelSize),
                              height: Int(pixelSize),
                              bitsPerComponent: 8,
                              bytesPerRow: bytesPerRow,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        FileHandle.standardError.write(Data("fehler: CGContext init failed\n".utf8))
        exit(1)
    }
    let rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    ctx.draw(image, in: rect)

    // Orange Multiply-Tint: erhält Form, färbt Highlights orange.
    ctx.setBlendMode(.multiply)
    ctx.setFillColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.55)
    ctx.fill(rect)

    // β-Badge unten rechts. Skalierung relativ zur Pixelgröße.
    ctx.setBlendMode(.normal)
    let badgeDiameter = pixelSize * 0.42
    let badgeRect = CGRect(x: pixelSize - badgeDiameter - pixelSize * 0.04,
                           y: pixelSize * 0.04,
                           width: badgeDiameter,
                           height: badgeDiameter)
    ctx.setFillColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.85)
    ctx.fillEllipse(in: badgeRect)

    let fontSize = badgeDiameter * 0.72
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    let text = NSAttributedString(string: "β", attributes: attrs)
    let textSize = text.size()
    let textRect = CGRect(
        x: badgeRect.midX - textSize.width / 2,
        y: badgeRect.midY - textSize.height / 2,
        width: textSize.width,
        height: textSize.height
    )
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    text.draw(in: textRect)
    NSGraphicsContext.restoreGraphicsState()

    guard let result = ctx.makeImage() else {
        FileHandle.standardError.write(Data("fehler: makeImage failed\n".utf8))
        exit(1)
    }
    return result
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     "public.png" as CFString,
                                                     1, nil) else {
        FileHandle.standardError.write(Data("fehler: kann \(url.path) nicht schreiben\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for entry in entries {
    let pixelSize = CGFloat(entry.size * entry.scale)
    let source = sourceSet.appendingPathComponent(entry.filename)
    let target = targetSet.appendingPathComponent(entry.filename)
    let img = loadPNG(source)
    let processed = tintAndBadge(image: img, pixelSize: pixelSize)
    writePNG(processed, to: target)
    print("schrieb \(target.lastPathComponent)")
}

let contents: [String: Any] = [
    "images": entries.map { entry in
        [
            "size": "\(entry.size)x\(entry.size)",
            "idiom": "mac",
            "filename": entry.filename,
            "scale": "\(entry.scale)x",
        ]
    },
    "info": ["version": 1, "author": "xcode"],
]
let json = try JSONSerialization.data(withJSONObject: contents,
                                      options: [.prettyPrinted, .sortedKeys])
try json.write(to: targetSet.appendingPathComponent("Contents.json"))
print("schrieb Contents.json")
```

- [ ] **Step 4: Test ausführen, alle Assertions sollten passen**

```bash
./tools/test-generate-beta-icon.sh
```

Erwartet: alle 10 PNGs plus `Contents.json` existieren in `Sources/WhisperDictation/Assets.xcassets/AppIconBeta.appiconset/`. Letzte Zeile: `ok`.

- [ ] **Step 5: Visueller Check**

```bash
open Sources/WhisperDictation/Assets.xcassets/AppIconBeta.appiconset/icon_512x512@2x.png
```

Erwartet: Mikrofon-Icon ist orangefarben getönt, unten rechts ein dunkles Kreis-Badge mit weißem β.

- [ ] **Step 6: Commit**

```bash
git add tools/generate-beta-icon.swift tools/test-generate-beta-icon.sh \
        Sources/WhisperDictation/Assets.xcassets/AppIconBeta.appiconset
git commit -m "build: Beta-Icon-Generator und AppIconBeta Asset-Set"
```

---

## Task 4: Menubar-Icon-Differenzierung im Swift-Code

**Files:**
- Modify: `Sources/WhisperDictation/AppState.swift:21-28`

Wenn die App unter der Beta-Bundle-ID läuft, soll das Menubar-Icon visuell differenzierbar sein. SF Symbols `mic.circle` / `mic.circle.fill` / `waveform.circle` sind eindeutig vom Production-Set unterscheidbar.

- [ ] **Step 1: Test schreiben**

Create: `Sources/WhisperDictation/AppStateTests.swift` (oder, falls noch keine Test-Infrastruktur existiert: skip Tests, mache stattdessen einen manuellen Check und überspringe zu Step 3).

Hinweis prüfen: gibt es ein Test-Target? `find . -name '*Tests*' -type d` ausführen. Wenn nein → kein Test schreiben, Code direkt implementieren und im Build verifizieren.

- [ ] **Step 2: Falls Test-Target existiert, Failing Test:**

```swift
import XCTest
@testable import WhisperDictation

final class AppStateMenuBarIconTests: XCTestCase {
    func test_idleIcon_isPlainMicInProduction() {
        let state = AppState(isBeta: false)
        XCTAssertEqual(state.menuBarIconName, "mic")
    }

    func test_idleIcon_isCircleMicInBeta() {
        let state = AppState(isBeta: true)
        XCTAssertEqual(state.menuBarIconName, "mic.circle")
    }
}
```

`swift test` → erwarteter Fehler: `init(isBeta:)` existiert nicht.

- [ ] **Step 3: AppState.swift anpassen**

Ersetze den AppState-Body durch:

```swift
@MainActor
final class AppState: ObservableObject {
    @Published var status: DictationStatus = .idle
    @Published var lastTranscription: String = ""

    let isBeta: Bool

    init(isBeta: Bool = AppState.detectBeta()) {
        self.isBeta = isBeta
    }

    static func detectBeta() -> Bool {
        Bundle.main.bundleIdentifier?.hasSuffix(".beta") ?? false
    }

    var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    var menuBarIconName: String {
        switch status {
        case .idle:
            return isBeta ? "mic.circle" : "mic"
        case .recording:
            return isBeta ? "mic.circle.fill" : "mic.fill"
        case .transcribing, .processing:
            return isBeta ? "waveform.circle" : "waveform"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
```

- [ ] **Step 4: Test bzw. Build verifizieren**

Wenn Tests existieren: `swift test` → grün.
Sonst: `swift build` → erwartet keine Compile-Errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/WhisperDictation/AppState.swift
# falls Tests neu: auch AppStateTests.swift hinzufügen
git commit -m "feat: Menubar-Icon-Variante für Beta-Bundle"
```

---

## Task 5: build-release.sh um `--beta`-Flag erweitern

**Files:**
- Modify: `scripts/build-release.sh`

Neue Flag `--beta` setzt die Env-Vars (siehe Task 2), wählt das Beta-Icon, generiert es, deaktiviert Sparkle, überspringt DMG- und Zip-Erzeugung und installiert das Build direkt nach `/Applications/WhisperDictation Beta.app`.

- [ ] **Step 1: Aktuelles Verhalten regression-testen**

```bash
./scripts/build-release.sh
```

Erwartet: Production-Build läuft durch wie bisher.

- [ ] **Step 2: Flag-Parser am Skript-Anfang einbauen**

Direkt nach `set -euo pipefail` und `cd "$REPO_ROOT"` einfügen:

```bash
BETA_MODE=0
for arg in "$@"; do
  case "$arg" in
    --beta) BETA_MODE=1 ;;
    *) echo "unbekanntes Argument: $arg"; exit 1 ;;
  esac
done

if [[ $BETA_MODE -eq 1 ]]; then
  echo "==> Beta-Variante"
  export WD_BUNDLE_ID="com.innosolv.WhisperDictation.beta"
  export WD_DISPLAY_NAME="WhisperDictation Beta"
  export WD_APPICON="AppIconBeta"
  export WD_SPARKLE_ENABLED="false"
  # Leerer Feed verhindert ausversehentliche Updates aus dem Production-Appcast.
  export WD_FEED_URL="about:blank"
  echo "    Bundle-ID:    $WD_BUNDLE_ID"
  echo "    Display-Name: $WD_DISPLAY_NAME"
  echo "    AppIcon:      $WD_APPICON"
  # Beta-Icon vor xcodegen generieren, sonst fehlt das Asset im Build.
  echo "==> Generiere Beta-Icon"
  swift "$REPO_ROOT/tools/generate-beta-icon.swift"
fi
```

- [ ] **Step 3: Skript-Ende anpassen, DMG/Zip nur in Production**

Den bestehenden Block

```bash
echo "==> Zippe für Sparkle …"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

DMG_PATH="$OUT_DIR/WhisperDictation-$VERSION.dmg"
echo "==> Baue DMG für manuelle Installation …"
bash "$REPO_ROOT/scripts/make-dmg.sh"

echo ""
echo "Fertig:"
echo "  App: $APP_PATH"
echo "  Zip: $ZIP_PATH"
echo "  DMG: $DMG_PATH"
echo "  Version: $VERSION"
```

ersetzen durch:

```bash
if [[ $BETA_MODE -eq 1 ]]; then
  TARGET="/Applications/WhisperDictation Beta.app"
  echo "==> Installiere nach $TARGET"
  rm -rf "$TARGET"
  ditto "$APP_PATH" "$TARGET"
  echo ""
  echo "Fertig (Beta):"
  echo "  Source:   $APP_PATH"
  echo "  Install:  $TARGET"
  echo "  Version:  $VERSION"
  echo "  Bundle:   $WD_BUNDLE_ID"
else
  echo "==> Zippe für Sparkle …"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

  DMG_PATH="$OUT_DIR/WhisperDictation-$VERSION.dmg"
  echo "==> Baue DMG für manuelle Installation …"
  bash "$REPO_ROOT/scripts/make-dmg.sh"

  echo ""
  echo "Fertig:"
  echo "  App: $APP_PATH"
  echo "  Zip: $ZIP_PATH"
  echo "  DMG: $DMG_PATH"
  echo "  Version: $VERSION"
fi
```

- [ ] **Step 4: Beta-Build testen**

```bash
./scripts/build-release.sh --beta
```

Erwartet:
- Beta-Icon wird generiert.
- Build läuft durch.
- `/Applications/WhisperDictation Beta.app` existiert.
- `codesign -dv "/Applications/WhisperDictation Beta.app" 2>&1 | grep Identifier` zeigt `Identifier=com.innosolv.WhisperDictation.beta`.
- `defaults read "/Applications/WhisperDictation Beta.app/Contents/Info.plist" CFBundleDisplayName` zeigt `WhisperDictation Beta`.

- [ ] **Step 5: Production-Regression**

```bash
./scripts/build-release.sh
```

Erwartet:
- Build läuft durch.
- `dist/WhisperDictation-1.1.2.zip` und `.dmg` werden erzeugt.
- `codesign -dv` der gebauten App zeigt `Identifier=com.innosolv.WhisperDictation` (ohne `.beta`).

- [ ] **Step 6: Commit**

```bash
git add scripts/build-release.sh
git commit -m "build: --beta-Flag für parallele Beta-App-Installation"
```

---

## Task 6: `beta`-Branch initial anlegen

**Files:**
- Neu: Branch `beta` (lokal + remote)

- [ ] **Step 1: Branch von main erstellen**

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"
git fetch origin
git checkout main
git pull --ff-only
git checkout -b beta
```

- [ ] **Step 2: Branch pushen**

```bash
git push -u origin beta
```

Erwartet: Remote-Branch `origin/beta` zeigt auf denselben Commit wie `origin/main`.

- [ ] **Step 3: Zurück auf den Feature-Branch wechseln**

```bash
git checkout feature/feature-request-workflow
```

(Wir arbeiten weiterhin auf dem Spec-Branch und mergen am Ende alles zusammen.)

---

## Task 7: Skill `feature-request-workflow` anlegen

**Files:**
- Create: `/Users/timurmutluer/Desktop/Claude - Arbeitsordner/Skills/feature-request-workflow/SKILL.md`

- [ ] **Step 1: Skill-Verzeichnis anlegen**

```bash
mkdir -p "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/Skills/feature-request-workflow"
```

- [ ] **Step 2: SKILL.md schreiben**

Create: `/Users/timurmutluer/Desktop/Claude - Arbeitsordner/Skills/feature-request-workflow/SKILL.md`

```markdown
---
name: feature-request-workflow
description: WhisperDictation Feature-Wunsch-Workflow. Trigger wenn der User sagt "arbeite Feature X", "alle offenen Feature-Wünsche", "neuer Beta-Build", "release jetzt" oder einen Notion-Eintrag aus der DB "WhisperDictation – Feature Wünsche" referenziert. Liest Notion-DB, legt Feature-Branches an, baut die Beta-App, koordiniert Human Review und Sammel-Releases.
---

# WhisperDictation Feature-Request-Workflow

Vollständige Spec: `/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation/docs/feature-request-workflow.md` (immer zuerst lesen, wenn der Skill aktiviert wird).

## Notion-Datenbank

URL: https://www.notion.so/innosolv/35623553acb780839d8ac203cf99d46f
Data-Source-ID: `collection://35623553-acb7-80e6-8993-000b40fd4dbb`

Status-Lifecycle:

```
Idee  →  Umsetzung  →  Human Review  →  Release  →  Erledigt
```

## Repo-Pfad

`/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation`

## Entscheidungsbaum

1. **User nennt einen einzelnen Feature-Titel oder Notion-URL** → diesen Eintrag bearbeiten.
2. **User sagt "alle offenen"** → alle `Idee`-Einträge nacheinander bearbeiten, bei Unklarheit per AskUserQuestion zurückfragen.
3. **User sagt "neuer Beta-Build"** → `beta`-Branch synchronisieren (siehe Spec Abschnitt B), `./scripts/build-release.sh --beta` ausführen.
4. **User gibt Feedback zu einem Feature in Human Review** → bei "passt": auf `main` mergen + Notion auf `Release`. Bei "Änderung": auf gleichem Feature-Branch nacharbeiten, Notion auf `Umsetzung`, neuer Beta-Build.
5. **User sagt "release jetzt"** → Versionsnummer vorschlagen, Release-Notes generieren, `./scripts/release.sh` ausführen, Notion-Einträge auf `Erledigt`, `beta` resetten.

## Branch-Konventionen

- `main`: Production. Nur via Merge von Feature-Branches.
- `beta`: Integrations-Branch, regenerierbar aus main + aktive Feature-Branches.
- `feature/<slug>`: Pro Notion-Eintrag genau einer.

## Niemals

- Direkt auf `main` committen.
- `--no-ff` weglassen beim Merge auf `main` (saubere Historie).
- Beta-Build releasen oder ans Team verteilen.
- Production-Sparkle-Appcast in Beta verwenden.

## Wenn unklar

Spec lesen. Bei verbleibender Unsicherheit: User fragen.
```

- [ ] **Step 3: Skill-Verzeichnis verifizieren**

```bash
ls "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/Skills/feature-request-workflow/"
```

Erwartet: `SKILL.md`.

- [ ] **Step 4: Kein git commit**

Der Skills-Ordner liegt im Arbeitsordner-Root, nicht im WhisperDictation-Repo. Wird nicht versioniert.

---

## Task 8: CLAUDE.md im WhisperDictation-Repo um Workflow-Verweis ergänzen

**Files:**
- Create or Modify: `WhisperDictation/CLAUDE.md`

- [ ] **Step 1: Existenz prüfen**

```bash
ls "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation/CLAUDE.md" 2>/dev/null
```

- [ ] **Step 2a: Falls existiert, Verweis ergänzen**

Mit Edit-Tool den Block

```markdown
## Workflow

Bei Änderungen an dieser App folge dem Feature-Request-Workflow: `docs/feature-request-workflow.md`. Niemals direkt auf `main` committen, sondern immer über `feature/<slug>`-Branches arbeiten.
```

ans Ende der Datei anhängen.

- [ ] **Step 2b: Falls nicht existiert, neu anlegen**

Create: `WhisperDictation/CLAUDE.md`

```markdown
# WhisperDictation

Native macOS Menubar-App für systemweite Sprach-Diktierung via Groq Whisper.

## Workflow

Bei Änderungen an dieser App folge dem Feature-Request-Workflow: [docs/feature-request-workflow.md](docs/feature-request-workflow.md). Niemals direkt auf `main` committen, sondern immer über `feature/<slug>`-Branches arbeiten. Beta-Tests laufen auf einer parallel installierten App `/Applications/WhisperDictation Beta.app`.

## Build

- `./scripts/build-release.sh` für Production
- `./scripts/build-release.sh --beta` für Beta-Variante
- `./scripts/release.sh <version> "<notes>"` für offizielles Release (Sparkle-Update)

## Doku

- [docs/feature-request-workflow.md](docs/feature-request-workflow.md): Feature-Wunsch-Prozess
- [docs/release-workflow.md](docs/release-workflow.md): Sammel-Release-Prozess
- [docs/dev-workflow.md](docs/dev-workflow.md): End-to-End-Dev-Setup
- [docs/onboarding-team.md](docs/onboarding-team.md): Team-Installations-Anleitung
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md verweist auf Feature-Request-Workflow"
```

---

## Task 9: Memory-Update im User-Memory-System

**Files:**
- Modify: `/Users/timurmutluer/.claude/projects/-Users-timurmutluer-Desktop-Claude---Arbeitsordner/memory/whisperdictation_project.md`
- Modify: `/Users/timurmutluer/.claude/projects/-Users-timurmutluer-Desktop-Claude---Arbeitsordner/memory/MEMORY.md`

Bisher steht im Memory: "Jede Code-Änderung wird direkt im GitHub-Repo committed + gepushed (auf `main`)." Diese Regel ist durch den neuen Workflow überholt.

- [ ] **Step 1: `whisperdictation_project.md` editieren**

Mit Edit-Tool den Absatz

```
**User-Anforderung**: Jede Code-Änderung wird direkt im GitHub-Repo committed + gepushed (auf `main`). Kein Force-Push, Versionshistorie bleibt nachvollziehbar. `gh` CLI liegt unter `~/.local/bin/gh`.
```

ersetzen durch:

```
**Workflow für Änderungen** (ab 2026-05-04): Alle Code-Änderungen folgen dem Feature-Request-Workflow in `docs/feature-request-workflow.md`. Niemals direkt auf `main`, immer über `feature/<slug>`-Branches mit Merge `--no-ff`. Beta-Tests auf paralleler App `/Applications/WhisperDictation Beta.app`. Sammel-Releases via `scripts/release.sh`. Kein Force-Push. `gh` CLI liegt unter `~/.local/bin/gh`.
```

- [ ] **Step 2: Neuen Memory-Eintrag für die Workflow-Existenz schreiben**

Create: `/Users/timurmutluer/.claude/projects/-Users-timurmutluer-Desktop-Claude---Arbeitsordner/memory/feedback_whisperdictation_workflow.md`

```markdown
---
name: WhisperDictation Branching-Workflow
description: WhisperDictation nutzt Feature-Branches mit beta-Integrations-Branch und paralleler Beta-App, niemals direkt auf main committen
type: feedback
---

Niemals direkt auf `main` im WhisperDictation-Repo committen oder pushen. Immer über `feature/<slug>`-Branch arbeiten, in `beta` integrieren, Beta-App testen lassen, dann via Merge `--no-ff` nach `main`.

**Why:** Production-App des Teams soll vor ungetesteten Änderungen geschützt werden, Sparkle-Updates dürfen nur ausgespielt werden, nachdem Timur in der Beta-App approved hat. Der Workflow ist in `WhisperDictation/docs/feature-request-workflow.md` vollständig dokumentiert.

**How to apply:** Bei jeder Code-Änderung am WhisperDictation-Repo zuerst Skill `feature-request-workflow` aktivieren (oder Spec-Datei lesen) und dem Branch-Modell folgen. Push auf `main` nur via Merge nach Human-Review-Approval.
```

- [ ] **Step 3: MEMORY.md-Index aktualisieren**

Mit Edit-Tool im File `/Users/timurmutluer/.claude/projects/-Users-timurmutluer-Desktop-Claude---Arbeitsordner/memory/MEMORY.md` unter dem `## Feedback`-Abschnitt diesen Eintrag hinzufügen:

```markdown
- [WhisperDictation Branching-Workflow](feedback_whisperdictation_workflow.md): niemals direkt auf main, immer über feature/<slug>+beta+Human Review
```

- [ ] **Step 4: Verifizieren**

```bash
cat "/Users/timurmutluer/.claude/projects/-Users-timurmutluer-Desktop-Claude---Arbeitsordner/memory/MEMORY.md"
```

Erwartet: neuer Feedback-Eintrag ist im Index.

- [ ] **Step 5: Kein git commit nötig**

Memory liegt außerhalb des Repos.

---

## Task 10: Spec-Branch nach `main` mergen und alles in `beta` integrieren

**Files:**
- Branch-Operation auf `main`, `beta`, `feature/feature-request-workflow`

- [ ] **Step 1: Status auf dem Feature-Branch prüfen**

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"
git status
git log --oneline main..feature/feature-request-workflow
```

Erwartet: alle Commits aus Tasks 2, 3, 4, 5, 8 sind auf dem Branch, working tree clean.

- [ ] **Step 2: Auf `main` wechseln und Branch mergen**

```bash
git checkout main
git pull --ff-only
git merge --no-ff feature/feature-request-workflow -m "merge: feature-request-workflow Setup"
git push origin main
```

Wenn der Push abgelehnt wird (siehe Hook-Protection): explizit User um Approval bitten und Push-Permission per Settings autorisieren oder PR via `gh pr create` öffnen und User mergen lassen.

- [ ] **Step 3: `beta` auf `main` aktualisieren**

```bash
git checkout beta
git reset --hard main
git push origin beta --force-with-lease
```

`--force-with-lease` ist hier sicher, weil `beta` regenerierbar ist und keine schützenswerten Branch-eigenen Commits hat.

- [ ] **Step 4: Aufräumen**

```bash
git branch -d feature/feature-request-workflow
git push origin --delete feature/feature-request-workflow
git tag -d pre-beta-setup
```

---

## Task 11: Beta-App lokal installieren und Permissions erteilen (manueller Step für Timur)

**Files:** keine

Dieser Step muss Timur einmal manuell durchführen, weil TCC-Permissions interaktiv erteilt werden müssen.

- [ ] **Step 1: Initialen Beta-Build erzeugen**

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"
git checkout beta
./scripts/build-release.sh --beta
```

Erwartet: `/Applications/WhisperDictation Beta.app` existiert.

- [ ] **Step 2: App starten**

```bash
open "/Applications/WhisperDictation Beta.app"
```

Erwartet: Menübar-Symbol `mic.circle` erscheint (visuell unterscheidbar vom Production-`mic`).

- [ ] **Step 3: Permissions erteilen**

- macOS fragt nach Mikrofon-Zugriff → erlauben.
- Bei erstem Diktier-Versuch fragt macOS nach Bedienungshilfen-Zugriff → in den Systemeinstellungen erlauben.
- Im Menü der Beta-App API-Keys (Groq) eintragen, Hotkey konfigurieren.

- [ ] **Step 4: Smoke-Test**

Hotkey drücken, kurzen Satz diktieren, Loslassen. Transkription sollte in der aktiven App erscheinen. Damit ist die Beta vollwertig nutzbar.

- [ ] **Step 5: Bestätigen**

Wenn alle vier Steps erfolgreich: dem User Bescheid geben, dass der Workflow live ist.

---

## Self-Review (durchgeführt)

**Spec-Coverage:**
- Status `Release` → Task 1 ✓
- Branch-Strategie main/beta/feature/* → Tasks 6, 10 ✓
- Beta-App mit Bundle-ID + Display-Name + Icon + Sparkle-Disable + UserDefaults → Tasks 2, 3, 4, 5 ✓
- Notion-Page-Body als Notiz-Ablage → Workflow-Doc, kein Setup nötig ✓
- Sammel-Release → bestehende `release.sh`, kein Setup nötig ✓
- Skill-Anlage → Task 7 ✓
- Memory-Update → Task 9 ✓
- CLAUDE.md → Task 8 ✓
- Beta-Erstinstallation → Task 11 ✓

**Placeholder-Scan:** keine TBDs/TODOs offen.

**Type-Konsistenz:** `WD_BUNDLE_ID`, `WD_DISPLAY_NAME`, `WD_APPICON`, `WD_SPARKLE_ENABLED`, `WD_FEED_URL` sind in Tasks 2 und 5 identisch benannt. `AppIconBeta` als Asset-Name konsistent zwischen Task 3 (Generator Output), Task 5 (`WD_APPICON`) und Task 4 (Swift-Code referenziert es nicht direkt).

**Bekannte Annahmen / Risiken:**
- xcodegen-Substitution `${VAR:-default}` kann je nach xcodegen-Version anders interpretiert werden. Falls Step 4 in Task 2 fehlschlägt: Substitution per `envsubst` als Pre-Processing-Schritt im Build-Script fallback.
- Task 4 Step 2 setzt voraus, dass entweder ein Test-Target existiert oder übersprungen wird. Aktuell hat das Repo keines. Default: Tests skip, Build-Verifikation reicht.
- Task 10 Step 2 push auf main kann durch denselben Hook geblockt werden, der bereits den ersten Push verhindert hat. Fallback: PR via `gh pr create` und User mergen lassen.
