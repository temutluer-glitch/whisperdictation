#!/usr/bin/env bash
# End-to-End Release-Pipeline (Single-Repo-Variante):
#   1. Bumpt Version in project.yml
#   2. Baut + signiert App (build-release.sh)
#   3. Sparkle-signiert das Zip mit EdDSA-Key
#   4. Aktualisiert appcast.xml im Repo-Root (committed = saubere Historie)
#   5. Committet, taggt, pusht
#   6. Erstellt GitHub Release mit Zip als Asset (nicht committed)
#
# Usage: scripts/release.sh 1.2.0 "Optionale Release-Notes als String"

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [release-notes]"
  echo "  Beispiel: $0 1.2.0 'Sprechblase-Fix in Slack'"
  exit 1
fi

VERSION="$1"
NOTES="${2:-Update auf v$VERSION}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Repo-Konfiguration (single repo: source + releases zusammen)
REPO_SLUG="${REPO_SLUG:-temutluer-glitch/whisperdictation}"

GH="${GH:-$HOME/.local/bin/gh}"
command -v gh >/dev/null 2>&1 && GH="$(command -v gh)"

# Vorausverifikation: kein dirty working tree (außer in gewollten Files)
if ! git diff --quiet -- ':!project.yml' ':!appcast.xml'; then
  echo "fehler: working tree hat uncommittierte Änderungen außerhalb von project.yml/appcast.xml. Erst aufräumen."
  git status
  exit 1
fi

echo "==> Bump Version auf $VERSION in project.yml …"
sed -i '' "s|MARKETING_VERSION: \"[^\"]*\"|MARKETING_VERSION: \"$VERSION\"|" project.yml
sed -i '' "s|CFBundleShortVersionString: \"[^\"]*\"|CFBundleShortVersionString: \"$VERSION\"|" project.yml
# Build-Number = Anzahl Commits +1 (monoton steigend)
BUILD_NUM=$(git rev-list --count HEAD)
BUILD_NUM=$((BUILD_NUM + 1))
sed -i '' "s|CFBundleVersion: \"[^\"]*\"|CFBundleVersion: \"$BUILD_NUM\"|" project.yml
sed -i '' "s|CURRENT_PROJECT_VERSION: \"[^\"]*\"|CURRENT_PROJECT_VERSION: \"$BUILD_NUM\"|" project.yml

echo "==> Baue + signiere …"
bash scripts/build-release.sh

ZIP_PATH="$REPO_ROOT/dist/WhisperDictation-$VERSION.zip"
DMG_PATH="$REPO_ROOT/dist/WhisperDictation-$VERSION.dmg"
if [[ ! -f "$ZIP_PATH" ]]; then
  echo "fehler: Zip nicht gefunden: $ZIP_PATH"
  exit 1
fi
if [[ ! -f "$DMG_PATH" ]]; then
  echo "fehler: DMG nicht gefunden: $DMG_PATH"
  exit 1
fi

# Sparkle sign_update finden
SIGN_UPDATE="$(find /tmp/wd-build -name sign_update -type f 2>/dev/null | head -1)"
if [[ -z "${SIGN_UPDATE:-}" ]]; then
  echo "fehler: sign_update binary nicht in /tmp/wd-build gefunden."
  exit 1
fi

echo "==> Sparkle EdDSA-Signatur erzeugen …"
SPARKLE_SIG="$("$SIGN_UPDATE" "$ZIP_PATH" 2>&1 | tail -1)"
echo "    $SPARKLE_SIG"

ZIP_SIZE=$(stat -f %z "$ZIP_PATH")
PUBDATE="$(date -u +"%a, %d %b %Y %H:%M:%S +0000")"
DOWNLOAD_URL="https://github.com/$REPO_SLUG/releases/download/v$VERSION/WhisperDictation-$VERSION.zip"

APPCAST="$REPO_ROOT/appcast.xml"

if [[ ! -f "$APPCAST" ]]; then
  echo "==> appcast.xml erstmalig anlegen …"
  cat > "$APPCAST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>WhisperDictation</title>
    <link>https://github.com/$REPO_SLUG</link>
    <description>WhisperDictation Update Feed</description>
    <language>de</language>
  </channel>
</rss>
EOF
fi

# Neuen Item-Block einfügen direkt vor </channel>
ITEM_XML=$(cat <<EOF
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$BUILD_NUM</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<p>$NOTES</p>]]></description>
      <enclosure
        url="$DOWNLOAD_URL"
        type="application/octet-stream"
        $SPARKLE_SIG />
    </item>
EOF
)

TMP_ITEM="$(mktemp)"
echo "$ITEM_XML" > "$TMP_ITEM"
awk -v itemfile="$TMP_ITEM" '
  /<\/channel>/ {
    while ((getline line < itemfile) > 0) print line
    close(itemfile)
  }
  { print }
' "$APPCAST" > "$APPCAST.tmp" && mv "$APPCAST.tmp" "$APPCAST"
rm -f "$TMP_ITEM"

echo "==> Commit & Tag …"
git add project.yml appcast.xml
git commit -m "release: v$VERSION

$NOTES"
git tag "v$VERSION"

echo "==> Push to origin …"
git push origin "$(git branch --show-current)"
git push origin "v$VERSION"

echo "==> GitHub Release erstellen mit Zip + DMG als Assets …"
"$GH" release create "v$VERSION" \
  --repo "$REPO_SLUG" \
  --title "v$VERSION" \
  --notes "$NOTES" \
  "$ZIP_PATH" \
  "$DMG_PATH"

echo ""
echo "Fertig."
echo "  Release: https://github.com/$REPO_SLUG/releases/tag/v$VERSION"
echo "  Appcast: https://raw.githubusercontent.com/$REPO_SLUG/main/appcast.xml"
echo ""
echo "Mitarbeiter-Apps werden innerhalb 24 h (oder bei nächstem manuellen Check) updaten."
