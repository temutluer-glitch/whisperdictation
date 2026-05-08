# InnoWhisper – Installation für InnoSolv-Team

Hi! Mit InnoWhisper kannst du in jeder Mac-App per Tastenkürzel Sprache zu Text wandeln. Diese Anleitung beschreibt die einmalige Installation.

## 1. App herunterladen

Klicke auf den von Timur geteilten Link zur aktuellen Version. Du landest auf einer GitHub-Release-Seite. Lade dort `InnoWhisper-X.Y.Z.dmg` herunter.

Doppelklick auf die heruntergeladene `.dmg`-Datei.

### Falls eine Sicherheitswarnung erscheint (macOS Sequoia / 15 und neuer)

Auf neueren macOS-Versionen blockt Gatekeeper die DMG beim ersten Öffnen mit der Meldung *„Apple konnte nicht überprüfen, ob `InnoWhisper-X.Y.Z.dmg` frei von Schadsoftware ist"*. Das ist erwartbar, weil wir die App ohne Apple Developer Account ausliefern. Einmaliger Workaround:

1. Im Dialog auf **„Fertig"** klicken (NICHT auf „In den Papierkorb").
2. Apple-Menü oben links → **Systemeinstellungen…** öffnen.
3. Links **Datenschutz & Sicherheit** wählen.
4. Ganz nach unten scrollen zum Abschnitt **„Sicherheit"**. Dort steht der Hinweis *„`InnoWhisper-X.Y.Z.dmg` wurde blockiert, da es nicht von einem identifizierten Entwickler stammt"*.
5. Daneben auf **„Trotzdem öffnen"** klicken.
6. Mac-Passwort eingeben, dann in der Rückfrage nochmals auf **„Öffnen"** klicken.

Die DMG öffnet sich danach normal.

### DMG-Fenster

Es öffnet sich ein Fenster mit dem InnoWhisper-Symbol auf der linken Seite und einem Pfeil, der auf den Programme-Ordner rechts zeigt. Zieh das InnoWhisper-Symbol einfach auf das Programme-Ordner-Symbol.

(Falls du stattdessen die `.zip` lädst: entpacken per Doppelklick und manuell nach `/Applications` ziehen.)

## 2. Code-Signing-Zertifikat vertrauen (einmalig)

Da wir die App ohne Apple Developer Account ausliefern, signieren wir sie selbst. Dein Mac muss diesem Zertifikat einmalig vertrauen, damit die App nicht bei jedem Update neue Berechtigungen anfordert.

1. Lade die Datei `cert-public.cer` aus dem Release herunter.
2. Doppelklick auf die Datei. Schlüsselbund-Verwaltung öffnet sich.
3. Suche im Schlüsselbund nach `WhisperDictation Developer`.
4. Doppelklick auf den Eintrag → Abschnitt "Vertrauen" aufklappen → bei "Code-Signatur" → "Immer vertrauen" auswählen.
5. Fenster schließen, Mac-Passwort eingeben.

## 3. App das erste Mal öffnen

Da macOS eine selbstsignierte App nicht von Haus aus erlaubt, öffnest du sie einmalig per Rechtsklick:

1. Im Programme-Ordner Rechtsklick auf `InnoWhisper.app` → "Öffnen".
2. macOS warnt "Entwickler nicht überprüft" → Klick auf "Öffnen".
3. Das Mikrofon-Symbol erscheint oben rechts in der Menüleiste.

Ab jetzt startet die App ganz normal per Doppelklick.

## 4. Berechtigungen erteilen (einmalig)

Beim ersten Start fragt macOS:

- **Bedienungshilfen**: macOS poppt einen Standard-Dialog "InnoWhisper möchte deinen Computer steuern". Klicke "Systemeinstellungen öffnen", dort den Schalter neben InnoWhisper aktivieren (Mac-Passwort eingeben), dann InnoWhisper einmal beenden und neu starten.
- **Mikrofon**: Beim ersten Drücken des Hotkeys auf "Zulassen" klicken.

Falls du irgendwann den Hinweis "Bedienungshilfen fehlen, hier öffnen" oben im Menü-Dropdown siehst: heißt die Berechtigung wurde von macOS zurückgesetzt (passiert manchmal nach OS-Updates). Klick drauf, Schalter wieder einschalten, App neu starten.

Diese Berechtigungen sollten nach erstmaliger Erteilung über Updates erhalten bleiben.

## 5. Groq API-Key eintragen

Die App nutzt [Groq](https://console.groq.com/) für die Transkription. Timur teilt einen Team-Key (oder du erstellst einen kostenlosen eigenen):

1. Menüleisten-Symbol klicken → "Einstellungen…"
2. Tab "Transkription" → API-Key einfügen → Fenster schließen.

Der Key liegt verschlüsselt in deinem macOS-Schlüsselbund, nicht im Klartext.

## 6. Bedienung

- **Default-Hotkey**: ⌥ + Leertaste (Alt + Space).
- **Hold-to-Talk**: Hotkey gedrückt halten → sprechen → loslassen → Text wird in die aktive App eingefügt.
- **Toggle-Mode**: In Settings umstellbar – ein Klick startet, ein zweiter stoppt.

Die kleine Sprechblase neben dem Cursor zeigt dir, dass aufgenommen wird.

## 7. Updates

Updates kommen automatisch:
- Beim Öffnen prüft die App im Hintergrund, ob es eine neue Version gibt.
- Falls ja, erscheint ein Dialog "Update verfügbar". Ein Klick auf "Installieren" reicht.
- Du kannst auch manuell prüfen: Menüleisten-Symbol → "Auf Updates prüfen…"

Berechtigungen und Settings bleiben dabei erhalten.

## Troubleshooting

**Hotkey reagiert nicht oder Text wird nicht eingefügt**: Bedienungshilfen-Berechtigung fehlt. Im Menübar-Icon-Dropdown siehst du dann oben "Bedienungshilfen fehlen, hier öffnen". Klick drauf, Schalter aktivieren, App neu starten.

**Sprechblase erscheint an falscher Stelle**: In einigen Electron- und Web-Apps liefert das System keine zuverlässige Position des Eingabefelds zurück. In dem Fall fällt die Sprechblase auf die aktuelle Mausposition zurück. Falls hartnäckig: Timur Bescheid geben, im Log `/tmp/whisperdictation.log` lässt sich nachvollziehen, welcher App-Kontext aktiv war.

**DMG lässt sich nicht öffnen ("Apple konnte nicht überprüfen…")**: Auf macOS Sequoia (15) ist das erwartet. Vorgehen siehe Schritt 1, Abschnitt "Falls eine Sicherheitswarnung erscheint".

**App startet nicht**: Erste Öffnung muss per Rechtsklick → "Öffnen" erfolgen (siehe Schritt 3). Bei späteren Versuchen Doppelklick.

**API-Fehler**: Internet-Verbindung prüfen. Falls Groq-Limits erreicht: Timur fragen.

Bei sonstigen Problemen: Timur direkt anschreiben.
