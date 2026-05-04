# Release-Workflow für Timur

Diese Doku beschreibt, wie du nach Initial-Setup eine neue Version an dein Team ausrollst.

## Initial-Setup (einmalig)

Du machst diese drei Schritte **genau einmal** auf deinem Mac:

### 1. Self-Signed Code-Signing-Cert erstellen

```bash
cd "/Users/timurmutluer/Desktop/Claude - Arbeitsordner/WhisperDictation"
./scripts/setup-signing-cert.sh
```

Das Skript erstellt das Zertifikat `WhisperDictation Developer` im macOS-Schlüsselbund und exportiert das Public-Cert nach `signing/cert-public.cer`. Letzteres wird ins Repo committed und von Mitarbeitern installiert.

Falls macOS einen Schlüsselbund-Dialog zeigt: zustimmen.

### 2. Sparkle EdDSA-Keys generieren

```bash
./scripts/setup-sparkle-keys.sh
```

Das Skript:
- baut die App einmal (damit das eingebaute Sparkle-CLI verfügbar ist),
- generiert ein EdDSA-Keypair im macOS-Schlüsselbund,
- patcht den Public Key in `project.yml` (`SUPublicEDKey`).

**Wichtig**: Den Privat-Key NIE löschen oder verlieren – sonst können keine signierten Updates mehr erstellt werden. Er liegt im macOS-Schlüsselbund unter "ed25519".

### 3. Repo öffentlich stellen

Sparkle braucht einen öffentlich zugänglichen Ort für `appcast.xml` und die Zip-Downloads. Wir nutzen das Source-Repo direkt:

- `appcast.xml` liegt im Repo-Root und wird mit jedem Release committed → vollständige Versionshistorie via `git log appcast.xml`.
- Zip-Dateien werden NICHT committed (sonst Repo-Bloat), sondern als GitHub-Release-Assets hochgeladen.

```bash
~/.local/bin/gh repo edit temutluer-glitch/whisperdictation --visibility public
```

Im Repo gibt es keine Secrets (Groq-API-Keys liegen im macOS-Keychain der Nutzer, nicht im Code). Die einmalige Public-Schaltung wird vom Setup-Skript bestätigt.

## Neuen Release ausrollen (jedes Mal)

Nachdem du Code-Änderungen gemacht und auf `main` gemerged hast:

```bash
./scripts/release.sh 1.2.0 "Sprechblase-Fix in Slack, neuer LLM-Prompt 'Verbessern'"
```

Das Skript erledigt:
1. Version-Bump in `project.yml`
2. Build + Re-Sign mit Self-Signed-Cert
3. Sparkle-Signatur des Zips
4. Update von `appcast.xml`
5. Push ins Releases-Repo
6. GitHub Release erstellen (mit `gh`)

Innerhalb 24 h (oder bei manuellem "Auf Updates prüfen") kommt das Update auf alle Team-Macs.

## Was passiert auf den Mitarbeiter-Macs

- App startet → Sparkle prüft `https://raw.githubusercontent.com/temutluer-glitch/whisperdictation/main/appcast.xml`.
- Findet eine neuere Version → Dialog "Update verfügbar".
- Mitarbeiter klickt "Installieren" → Sparkle lädt das Zip, verifiziert die EdDSA-Signatur, ersetzt die App in `/Applications`, startet neu.
- Mikrofon- und Bedienungshilfen-Berechtigungen bleiben erhalten, weil die Code-Signing-Identität (`WhisperDictation Developer`) zwischen Versionen konstant ist.

## Wichtige Dateien

- [project.yml](../project.yml) – Versionsangaben, Sparkle-Config (`SUFeedURL`, `SUPublicEDKey`)
- [scripts/build-release.sh](../scripts/build-release.sh) – Build + Sign
- [scripts/release.sh](../scripts/release.sh) – Komplette Pipeline
- [signing/cert-public.cer](../signing/cert-public.cer) – Public-Cert für Mitarbeiter

## Versionsschema

`MAJOR.MINOR.PATCH`. Nutze:
- **PATCH** (1.1.0 → 1.1.1): Bugfixes, kein Breaking Change
- **MINOR** (1.1.x → 1.2.0): Neue Features, abwärtskompatibel
- **MAJOR** (1.x.x → 2.0.0): Settings-Migrationen, größere Umbauten

Sparkle ordnet anhand `CFBundleVersion` (numerisch, monoton steigend = Anzahl Commits + 1).

## Alternative: privates Hosting

Wenn ihr kein public Releases-Repo wollt:

- **Cloudflare R2 / S3 Bucket** mit signierten URLs: aufwändiger einzurichten, aber Source-Code bleibt komplett privat.
- **Eigener kleiner Webserver**: appcast.xml + zips per scp deployen, Auth via Basic Auth oder Token.

In beiden Fällen `SUFeedURL` in `project.yml` anpassen und `release.sh` so erweitern, dass es nicht in ein git-Repo, sondern in den Bucket/Server pusht.

## Troubleshooting

**`gh release create` schlägt fehl**: 
- `gh auth status` prüfen → ggf. `gh auth login`.
- Existiert das Releases-Repo? `gh repo view temutluer-glitch/whisperdictation-releases`.

**Build schlägt mit "no signing identity" fehl**:
- `security find-identity -v -p codesigning | grep WhisperDictation` muss eine Zeile zeigen. Sonst `./scripts/setup-signing-cert.sh` neu ausführen.

**Sparkle-Updates zeigen "signature not valid"**:
- Public Key in `project.yml` muss zu dem Privat-Key matchen, der `sign_update` aufgerufen hat. `./scripts/setup-sparkle-keys.sh` überprüft das.

**Mitarbeiter melden: "Permissions wurden zurückgesetzt nach Update"**:
- Cert-Identifikator hat sich geändert. Prüfen mit `codesign -dv --verbose=2 /Applications/WhisperDictation.app | grep Authority`. Identity muss `WhisperDictation Developer` sein, nicht `Sign to Run Locally`. → `build-release.sh` läuft korrekt durch?
