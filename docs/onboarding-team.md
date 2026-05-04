# WhisperDictation – Installation für InnoSolv-Team

Hi! Mit WhisperDictation kannst du in jeder Mac-App per Tastenkürzel Sprache zu Text wandeln. Diese Anleitung beschreibt die einmalige Installation.

## 1. App herunterladen

Klicke auf den von Timur geteilten Link zur aktuellen Version. Du landest auf einer GitHub-Release-Seite. Lade dort `WhisperDictation-X.Y.Z.zip` herunter und entpacke es per Doppelklick.

Verschiebe `WhisperDictation.app` per Drag & Drop in deinen Programme-Ordner (`/Applications`).

## 2. Code-Signing-Zertifikat vertrauen (einmalig)

Da wir die App ohne Apple Developer Account ausliefern, signieren wir sie selbst. Dein Mac muss diesem Zertifikat einmalig vertrauen, damit die App nicht bei jedem Update neue Berechtigungen anfordert.

1. Lade die Datei `cert-public.cer` aus dem Release herunter.
2. Doppelklick auf die Datei. Schlüsselbund-Verwaltung öffnet sich.
3. Suche im Schlüsselbund nach `WhisperDictation Developer`.
4. Doppelklick auf den Eintrag → Abschnitt "Vertrauen" aufklappen → bei "Code-Signatur" → "Immer vertrauen" auswählen.
5. Fenster schließen, Mac-Passwort eingeben.

## 3. App das erste Mal öffnen

Da macOS eine selbstsignierte App nicht von Haus aus erlaubt, öffnest du sie einmalig per Rechtsklick:

1. Im Programme-Ordner Rechtsklick auf `WhisperDictation.app` → "Öffnen".
2. macOS warnt "Entwickler nicht überprüft" → Klick auf "Öffnen".
3. Das Mikrofon-Symbol erscheint oben rechts in der Menüleiste.

Ab jetzt startet die App ganz normal per Doppelklick.

## 4. Berechtigungen erteilen (einmalig)

Beim ersten Drücken des Hotkeys fragt macOS:

- **Mikrofon**: "Zulassen" anklicken.
- **Bedienungshilfen**: Die App zeigt einen Dialog mit Button "Einstellungen öffnen". Klick drauf, in den Systemeinstellungen `WhisperDictation` aktivieren, dann App neu starten.

Diese Berechtigungen musst du nur einmal geben – auch nach Updates bleiben sie erhalten.

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

**Hotkey reagiert nicht**: Bedienungshilfen-Berechtigung fehlt. Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → WhisperDictation aktivieren.

**Sprechblase erscheint an falscher Stelle**: Kann in einigen Web-Apps (Slack, Notion-Web) vorkommen. In dem Fall fällt sie auf die Cursor-Position zurück. Falls problematisch: Timur Bescheid geben, im DebugLog (`~/Library/Logs/WhisperDictation/debug.log`) lässt sich nachvollziehen, welcher App-Kontext aktiv war.

**App startet nicht**: Erste Öffnung muss per Rechtsklick → "Öffnen" erfolgen (siehe Schritt 3). Bei späteren Versuchen Doppelklick.

**API-Fehler**: Internet-Verbindung prüfen. Falls Groq-Limits erreicht: Timur fragen.

Bei sonstigen Problemen: Timur direkt anschreiben.
