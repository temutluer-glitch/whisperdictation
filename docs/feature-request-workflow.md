# Feature-Request-Workflow

Stand: 2026-05-04

Dieser Prozess regelt, wie Feature-Wünsche aus der Notion-Datenbank "🎙️ WhisperDictation – Feature Wünsche" in die App fließen, ohne dass die Production-Installation des Teams kompromittiert wird.

## Ziele

1. Feature-Wünsche werden zentral in Notion gesammelt.
2. Implementierung passiert in isolierten Feature-Branches.
3. Vor dem Rollout testet Timur in einer parallel installierten Beta-App.
4. Mehrere Features sind gleichzeitig in einem Beta-Build testbar.
5. Approvte Features sammeln sich, bis Timur einen Sammel-Release auslöst.

## Notion-Datenbank

URL: https://www.notion.so/innosolv/35623553acb780839d8ac203cf99d46f

Schema:
- `Feature` (title)
- `Erklärung` (text)
- `Eingangsdatum` (date)
- `Status` (status)

Status-Lifecycle (eine neue Option `Release` wird einmalig hinzugefügt):

```
Idee  →  Umsetzung  →  Human Review  →  Release  →  Erledigt
```

| Status | Bedeutung |
|---|---|
| Idee | Eintrag liegt in der DB, noch nicht gestartet |
| Umsetzung | Feature-Branch existiert, Code wird geschrieben |
| Human Review | Feature ist in `beta` gemerged, Beta-App liegt zum Testen bereit |
| Release | Feature ist auf `main` gemerged, wartet auf Sammel-Release |
| Erledigt | `release.sh` ist gelaufen, Sparkle hat das Update verteilt |

Technische Notizen (Branch-Name, GitHub-URL, Build-Datum, Iterations-Logs) schreibe ich in den Page-Body des jeweiligen Notion-Eintrags, niemals als neue Spalten ins Schema.

## Branch-Strategie

Drei Branch-Typen:

- `main`: Production. Nur approvte und auf `main` gemergte Features. Tags markieren Releases.
- `beta`: Integrations-Branch. Immer = `main` plus alle aktuell offenen Feature-Branches (Status `Human Review`). Aus diesem Branch wird die Beta-App gebaut.
- `feature/<slug>`: Pro Notion-Eintrag genau einer. Slug wird aus dem Feature-Titel auto-generiert.

Regeln:
- Kein Force-Push auf `main`.
- Keine direkten Commits auf `main` während aktiver Feature-Arbeit. Hotfixes laufen ebenfalls über einen Feature-Branch.
- `beta` ist regenerierbar. Wenn der Branch durcheinandergerät, wird er aus `main` plus den aktuellen Feature-Branches frisch aufgebaut.

## Beta-App

Damit Beta- und Production-App parallel auf demselben Mac laufen können:

- **Bundle-Identifier**: `com.innosolv.WhisperDictation.beta` (eigene TCC-Permissions, eigene Keychain-Items, eigener Sparkle-Pfad).
- **Display-Name**: `WhisperDictation Beta`.
- **App-Icon**: gleiches Mikrofon-Glyph wie Production, aber in Orange-Ton mit kleinem β-Badge unten rechts. Wird zur Build-Zeit per Swift+CoreGraphics aus dem Production-Icon generiert (analog zur DMG-Background-Generation in `tools/`). Kein zusätzliches Icon-Asset im Repo.
- **Menubar-Icon**: ebenfalls farblich differenziert. Gleicher Orange-Tint wie das App-Icon, damit auch in der Menüleiste auf den ersten Blick erkennbar ist, ob die Production- oder Beta-App im Vordergrund läuft.
- **UserDefaults-Domain**: separat (folgt automatisch aus dem geänderten Bundle-Identifier). Beta hat damit eigene API-Keys, Prompt-Presets, Hotkey-Settings. Beim ersten Start einmal eingeben, danach persistent.
- **Sparkle**: in der Beta deaktiviert. Beta erhält ihre Updates ausschließlich über lokale `build-release.sh --beta`-Läufe. Kein Appcast für Beta.
- **Hardened Runtime + disable-library-validation Entitlement**: identisch zur Production.
- **Code-Signing**: gleiche self-signed Cert "WhisperDictation Developer". Stabile Designated Requirement, damit Beta-TCC-Permissions zwischen Builds erhalten bleiben.

Build-Ergebnis: `/Applications/WhisperDictation Beta.app`. Existierende Beta-App wird vom Build-Script per `ditto` ersetzt.

## Workflow pro Session

Ein typischer Ablauf:

### A. Neue Features starten

1. Timur sagt "arbeite die offenen Feature-Wünsche" oder "Feature X umsetzen".
2. Ich pulle alle Notion-Einträge mit Status `Idee`.
3. Bei unklaren Erklärungen frage ich per AskUserQuestion (Multiple-Choice) zurück.
4. Pro Eintrag:
   - Branch `feature/<slug>` von `main` erstellen.
   - Status in Notion auf `Umsetzung` setzen, Branch-Name in den Page-Body schreiben.
   - Implementierung. TDD wo sinnvoll, sonst direkter Code mit manueller Test-Validierung.
   - Branch pushen.
5. Wenn alle gestarteten Features implementiert sind: `beta`-Branch aktualisieren (siehe B), Beta-App bauen, alle Notion-Einträge auf `Human Review` setzen.

### B. Beta-Branch synchronisieren

```
git checkout beta
git reset --hard main
for branch in $(notion-status="Human Review" + neu fertig):
  git merge --no-ff feature/<slug>
git push origin beta
```

Wenn ein Merge-Konflikt auftritt: ich löse ihn auf `beta` und dokumentiere im Notion-Eintrag, dass Feature X mit Y kollidiert. Der Konflikt wird nicht in den Feature-Branch zurückportiert, damit der Feature-Branch sauber selektiv mergebar bleibt.

### C. Beta-Build erzeugen

```
./scripts/build-release.sh --beta
```

Das Script:
- Baut aus `beta`-Branch.
- Setzt Bundle-Identifier auf `com.innosolv.WhisperDictation.beta`.
- Generiert Beta-Icon (Orange + β-Badge).
- Signiert mit der Standard-Cert.
- Disabled Sparkle (oder verwendet leeren Appcast).
- Kopiert das Ergebnis nach `/Applications/WhisperDictation Beta.app`.
- Erzeugt **keinen** GitHub-Release, **kein** Tag, **kein** Appcast-Update.

### D. Human Review

Timur testet die Beta-App. Pro getestetem Feature:

- **Passt**: ich merge `feature/<slug>` in `main` (no-ff), pushe `main`, setze Notion-Status auf `Release`. Branch bleibt im Repo (nicht gelöscht), bis Sammel-Release durch ist.
- **Änderung nötig**: Notion-Status zurück auf `Umsetzung`, ich arbeite auf dem gleichen Branch weiter, mergen wieder in `beta`, neuer Beta-Build.

### E. Sammel-Release

Wenn Timur "jetzt releasen" sagt:

1. Ich liste alle Notion-Einträge mit Status `Release`.
2. Schlage Versionsnummer vor (Default: Patch-Bump). Timur kann Minor/Major überstimmen.
3. Generiere deutsche Release-Notes (knapp, Feature-orientiert, eine Zeile pro Eintrag).
4. Führe `scripts/release.sh <version> "<notes>"` auf `main` aus. Das erzeugt Tag, GitHub-Release, ZIP+DMG-Assets, signiert mit EdDSA, pusht den Appcast.
5. Setze **alle** Notion-Einträge mit Status `Release` auf `Erledigt` (nicht nur die in diesem Release neu hinzugekommenen — alles, was auf `main` liegt, geht mit raus) und schreibe Release-Tag plus -URL in den jeweiligen Page-Body.
6. Aktualisiere den **InnoWhisper-Installationsguide** in Notion (Page-ID `35623553-acb7-8175-afb4-d750db7f1363`): neue Versionsnummer und Download-Link plus alle UI-/Bedienungs-Änderungen aus diesem Release. Prüfe dabei den **gesamten** Guide auf veraltete oder für neue Nutzer irrelevante Inhalte (historische „ab Version X"-Hinweise, alte Migrations-/Cert-Wechsel-Troubleshooting, Vorgänger-App-Reste) und entferne sie. Der Guide bleibt so kurz und einfach wie möglich und für Non-Tech-Mitarbeiter verständlich (es gibt zusätzlich einen begleiteten Walkthrough).
7. Resette `beta` auf den frischen `main` und merge die noch verbleibenden `Human Review`-Branches neu rein. Erzeuge frischen Beta-Build.
8. Lösche die gemergten Feature-Branches lokal und remote.

## Konflikt-Handling

| Situation | Vorgehen |
|---|---|
| Zwei in-review Features kollidieren in `beta` | Konflikt in `beta` lösen, Hinweis in beide Notion-Einträge. Timur entscheidet, ob beide approved werden oder eines zurückgestellt wird. |
| Approval von A, B kollidiert beim Merge in `main` | B-Branch auf neuen `main` rebasen, neuer Beta-Build, B bleibt in Human Review. |
| Beta-App startet nach Build nicht | Code-Signing-Check (codesign -dvvv), Hardened Runtime, Library Validation. Kein Auto-Rollback, weil Beta keine Production-Installation überschreibt. |
| Timur ändert Notion-Status manuell zurück | Ich respektiere den manuellen Status beim nächsten Sync. |

## Annahmen und Out-of-Scope

- Beta-Builds passieren lokal auf Timurs Mac, weil die self-signed Cert nur in seinem Login-Keychain liegt. Kein CI-Build.
- Beta nutzt **eigene** UserDefaults und Keychain-Items (nicht geteilt mit Production), damit Test-Bugs Production-Settings nicht korrumpieren. Trade-off: API-Keys müssen in der Beta einmal initial eingegeben werden.
- Mehrere Features parallel werden **sequenziell** implementiert (eine Code-Änderung nach der anderen), aber **gemeinsam** in einer Beta getestet.
- Out-of-Scope: automatische Rollouts, Beta-Channel für andere Team-Mitglieder, externe Issue-Tracker-Integration, automatische Tests in CI.

## Einmalige Setup-Tasks

1. **Notion-DB**: Status-Option `Release` (Farbe Orange) zwischen `Human Review` und `Erledigt` hinzufügen.
2. **Repo**:
   - `build-release.sh` um `--beta`-Flag erweitern (Bundle-ID-Override, Display-Name-Override, Icon-Generation, Sparkle-Disable, Install nach `/Applications/WhisperDictation Beta.app`).
   - Beta-Icon-Generator als Swift-Script in `tools/` (Production-Icon laden, Orange-Tint anwenden, β-Badge zeichnen).
   - `project.yml` so anpassen, dass Bundle-ID und Display-Name per Build-Setting überschreibbar sind.
   - `beta`-Branch initial anlegen.
3. **Lokale Installation**: Beta einmal starten, Mikrofon- und Bedienungshilfen-Permissions erteilen. Bleiben dann über alle weiteren Beta-Builds erhalten (stabile Designated Requirement).
4. **Skill anlegen**: Neuer Skill `Skills/feature-request-workflow/` mit `SKILL.md`, der den hier beschriebenen Prozess als Schritt-für-Schritt-Anleitung enthält. Damit kennt Claude in jeder Session den Workflow ohne Memory-Trick.
5. **Memory-Update**: Bisherige Regel "direkt auf main pushen" durch Verweis auf diesen Workflow ersetzen.
6. **CLAUDE.md des WhisperDictation-Repos** um einen Verweis auf diesen Workflow ergänzen.

## Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| `beta` driftet von `main` ab und merge wird unmöglich | `beta` ist regenerierbar. Bei Problemen frischer Aufbau aus `main` + aktive Feature-Branches. |
| Timur vergisst, welcher Beta-Build welches Feature enthält | Beta-App zeigt im "Über"-Dialog die enthaltenen Feature-Slugs plus Build-Datum. |
| TCC-Permissions der Beta gehen verloren | Stabile Cert + Designated Requirement. Falls doch verloren: einmal manuell neu erteilen, danach wieder persistent. |
| Production-User updaten zu früh, weil sie Beta-Appcast finden | Beta hat keinen öffentlichen Appcast. Sparkle in der Beta ist deaktiviert. |
| Konflikt zwischen zwei Features blockiert Test | Konflikt nur in `beta` lösen, Feature-Branches bleiben sauber selektiv mergebar. |

## Referenzen

- [release-workflow.md](release-workflow.md): bestehender Sammel-Release-Prozess
- [dev-workflow.md](dev-workflow.md): End-to-End-Dev-Setup
- [onboarding-team.md](onboarding-team.md): Team-Installations-Anleitung
