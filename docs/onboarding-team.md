# InnoWhisper – Installation für InnoSolv-Team

Hi! Mit InnoWhisper kannst du in jeder Mac-App per Tastenkürzel Sprache zu Text wandeln. Diese Anleitung beschreibt die einmalige Installation.

## 1. App herunterladen und installieren

Klicke auf den von Timur geteilten Link zur aktuellen Version. Du landest auf einer GitHub-Release-Seite. Lade dort `InnoWhisper-X.Y.Z.dmg` herunter.

Doppelklick auf die heruntergeladene `.dmg`-Datei. Es öffnet sich ein Fenster mit dem InnoWhisper-Symbol auf der linken Seite und einem Pfeil, der auf den Programme-Ordner rechts zeigt. Zieh das InnoWhisper-Symbol einfach auf das Programme-Ordner-Symbol.

(Falls du stattdessen die `.zip` lädst: entpacken per Doppelklick und manuell nach `/Applications` ziehen.)

Doppelklick auf `InnoWhisper.app` im Programme-Ordner — die App startet, das Mikrofon-Symbol erscheint oben rechts in der Menüleiste.

## 2. Berechtigungen erteilen (einmalig)

Beim ersten Start fragt macOS:

- **Bedienungshilfen**: macOS poppt einen Standard-Dialog „InnoWhisper möchte deinen Computer steuern". Klicke „Systemeinstellungen öffnen", dort den Schalter neben InnoWhisper aktivieren (Mac-Passwort eingeben), dann InnoWhisper einmal beenden und neu starten.
- **Mikrofon**: Beim ersten Drücken des Hotkeys auf „Zulassen" klicken.

Falls du irgendwann den Hinweis „Bedienungshilfen fehlen, hier öffnen" oben im Menü-Dropdown siehst: die Berechtigung wurde von macOS zurückgesetzt (passiert nach OS-Updates oder wenn der Entwickler-Cert wechselt). Klick drauf, Schalter wieder einschalten, App neu starten.

Diese Berechtigungen bleiben nach erstmaliger Erteilung über alle künftigen App-Updates erhalten.

## 3. Groq API-Key eintragen

Die App nutzt [Groq](https://console.groq.com/) für die Transkription. Timur teilt einen Team-Key (oder du erstellst einen kostenlosen eigenen):

1. Menüleisten-Symbol klicken → „Einstellungen…"
2. Tab „Transkription" → API-Key einfügen → Fenster schließen.

Der Key liegt verschlüsselt in deinem macOS-Schlüsselbund, nicht im Klartext.

## 4. Bedienung

- **Default-Hotkey**: ⌥ + Leertaste (Alt + Space).
- **Hold-to-Talk**: Hotkey gedrückt halten → sprechen → loslassen → Text wird in die aktive App eingefügt.
- **Toggle-Mode**: In Settings umstellbar — ein Klick startet, ein zweiter stoppt.

Die kleine Sprechblase neben dem Cursor zeigt dir, dass aufgenommen wird.

## 5. Updates

Updates kommen automatisch:
- Beim Öffnen prüft die App im Hintergrund, ob es eine neue Version gibt.
- Falls ja, erscheint ein Dialog „Update verfügbar". Ein Klick auf „Installieren" reicht.
- Du kannst auch manuell prüfen: Menüleisten-Symbol → „Auf Updates prüfen…"

Berechtigungen und Settings bleiben dabei erhalten.

## Troubleshooting

**Hotkey reagiert nicht oder Text wird nicht eingefügt**: Bedienungshilfen-Berechtigung fehlt. Im Menübar-Icon-Dropdown siehst du dann oben „Bedienungshilfen fehlen, hier öffnen". Klick drauf, Schalter aktivieren, App neu starten.

**Sprechblase erscheint an falscher Stelle**: In einigen Electron- und Web-Apps liefert das System keine zuverlässige Position des Eingabefelds zurück. In dem Fall fällt die Sprechblase auf die aktuelle Mausposition zurück. Falls hartnäckig: Timur Bescheid geben, im Log `/tmp/whisperdictation.log` lässt sich nachvollziehen, welcher App-Kontext aktiv war.

**„Apple konnte nicht überprüfen…"-Dialog beim DMG-Öffnen**: Sollte ab Version 1.2.1 nicht mehr auftreten, weil die App Apple-notarisiert ist. Falls du diesen Dialog dennoch siehst: vermutlich hast du noch eine ältere Version heruntergeladen. Lade die aktuelle Version vom Release-Link und probiere nochmal. Notfalls: Systemeinstellungen → Datenschutz & Sicherheit → ganz unten „Trotzdem öffnen".

**App startet nicht**: Programme-Ordner → `InnoWhisper.app` per Doppelklick öffnen. Falls macOS warnt: die App ist Apple-notarisiert, das sollte nicht passieren — Timur Bescheid geben.

**API-Fehler**: Internet-Verbindung prüfen. Falls Groq-Limits erreicht: Timur fragen.

Bei sonstigen Problemen: Timur direkt anschreiben.
