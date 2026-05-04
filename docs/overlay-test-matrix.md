# Overlay (Sprechblase) – Test-Matrix

Mit jeder Änderung an [CursorOverlay.swift](../Sources/WhisperDictation/Services/CursorOverlay.swift) muss diese Matrix vor dem Release durchlaufen werden. Bei jedem Test:

1. Hotkey drücken (⌥+Space) während der Cursor im Eingabefeld blinkt.
2. Beobachten: erscheint die Sprechblase **direkt über/unter** dem Eingabefeld?
3. `~/Library/Logs/WhisperDictation/debug.log` öffnen → letzten `overlay anchor=…` und `overlay reposition …` Eintrag prüfen.
4. Ergebnis eintragen.

## Native macOS-Apps (sollten Caret-Bounds liefern)

| App | Eingabe-Kontext | Anchor (caret/element/mouse) | Position OK? |
|-----|-----------------|------------------------------|---------------|
| TextEdit | leeres Dokument | | |
| Mail | Neue Nachricht, Betreff | | |
| Mail | Neue Nachricht, Body | | |
| Notes | Neue Notiz | | |
| Reminders | Neuer Eintrag | | |
| Spotlight | Cmd+Space, Suchfeld | | |
| Safari | Adressleiste | | |
| Safari | Suchfeld auf google.com | | |

## Webview/Electron-Apps (Caret oft nicht via AX verfügbar – Fallback erwartet)

| App | Eingabe-Kontext | Anchor | Position OK? |
|-----|-----------------|--------|---------------|
| Slack-Desktop | Message-Input | | |
| Notion-Desktop | Seitentitel | | |
| Notion-Desktop | Body-Block | | |
| ChatGPT-Desktop | Prompt | | |
| VS Code | Editor | | |
| VS Code | Terminal | | |
| Chrome – Gmail | Compose | | |
| Chrome – ChatGPT (Web) | Prompt | | |

## Multi-Monitor

Falls verfügbar, mit angeschlossenem zweitem Monitor:

| Setup | Test-App | Anchor | Position OK? |
|-------|----------|--------|---------------|
| Sekundär RECHTS vom Primär | Mail auf Sekundär | | |
| Sekundär LINKS vom Primär | Mail auf Sekundär | | |
| Sekundär OBERHALB | Mail auf Sekundär | | |
| Sekundär 4K-Auflösung | Mail auf Sekundär | | |
| Skalierter Modus (Retina vs. nicht) | Mail | | |

## Erfolgskriterium

- 100% der nativen Apps korrekt
- Mind. 5/8 Webview-Cases korrekt (rest: Fallback auf mouse-anchor ist akzeptabel)
- 100% der Multi-Monitor-Cases korrekt

Wenn ein Case fehlschlägt:
1. `debug.log` öffnen, letzten `overlay reposition` Eintrag mit Anchor- und Screen-Koordinaten anschauen.
2. Liegt Anchor in einem Screen-Frame? Falls nein → bug in `convertAXToScreenCoordinates`.
3. Liegt Anchor weit weg vom Mouse? Falls ja → AX hat unsinnige Daten geliefert, Plausibilitätsschwelle anpassen.
4. Gegen `kAXFocusedApplicationAttribute` und `kAXFocusedUIElementAttribute` mit Accessibility Inspector (in Xcode) cross-checken.
