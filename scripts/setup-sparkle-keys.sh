#!/usr/bin/env bash
# One-time: generiert Sparkle EdDSA-Keypair zum Signieren von Update-Payloads.
# Privater Key landet im macOS-Keychain (von Sparkle verwaltet),
# öffentlicher Key wird in project.yml unter SUPublicEDKey eingetragen.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="${DERIVED_DATA:-/tmp/wd-build}"

# Such generate_keys binary in den Sparkle Resources
find_sparkle_tool() {
  find "$DD" -name "$1" -type f 2>/dev/null | head -1
}

GEN="$(find_sparkle_tool generate_keys)"
if [[ -z "${GEN:-}" ]]; then
  echo "==> Sparkle binary nicht gefunden in $DD. Baue zuerst die App …"
  cd "$REPO_ROOT"
  XCG="${XCODEGEN:-/tmp/xcg/xcodegen/bin/xcodegen}"
  command -v xcodegen >/dev/null 2>&1 && XCG="$(command -v xcodegen)"
  if [[ ! -x "$XCG" ]]; then
    echo "fehler: xcodegen nicht installiert. Hole es per: brew install xcodegen"
    exit 1
  fi
  "$XCG" generate >/dev/null
  xcodebuild -project WhisperDictation.xcodeproj -scheme WhisperDictation \
    -configuration Release -derivedDataPath "$DD" \
    -destination 'platform=macOS' \
    build >/dev/null
  GEN="$(find_sparkle_tool generate_keys)"
fi

if [[ -z "${GEN:-}" ]]; then
  echo "fehler: generate_keys nicht gefunden in $DD nach Build."
  echo "       Versuche manuell: find $DD -name generate_keys"
  exit 1
fi
echo "==> Verwende: $GEN"

echo "==> Prüfe vorhandenes Sparkle-Keypair im Keychain …"
if "$GEN" -p >/dev/null 2>&1; then
  PUB="$("$GEN" -p)"
  echo "    Keypair existiert bereits."
else
  echo "    Generiere neues Keypair …"
  "$GEN"
  PUB="$("$GEN" -p)"
fi

echo ""
echo "==> Public Key (SUPublicEDKey):"
echo "    $PUB"
echo ""

# Patche project.yml: ersetze REPLACE_WITH_SPARKLE_PUBLIC_KEY oder den vorhandenen Eintrag
PROJECT_YML="$REPO_ROOT/project.yml"
if grep -q 'REPLACE_WITH_SPARKLE_PUBLIC_KEY' "$PROJECT_YML"; then
  sed -i '' "s|REPLACE_WITH_SPARKLE_PUBLIC_KEY|$PUB|" "$PROJECT_YML"
  echo "==> project.yml aktualisiert (Platzhalter ersetzt)."
elif grep -q 'SUPublicEDKey:' "$PROJECT_YML"; then
  sed -i '' "s|SUPublicEDKey: \".*\"|SUPublicEDKey: \"$PUB\"|" "$PROJECT_YML"
  echo "==> project.yml aktualisiert (Public Key ersetzt)."
else
  echo "warnung: SUPublicEDKey nicht in project.yml gefunden — bitte manuell eintragen."
fi

echo ""
echo "Fertig. Privat-Key liegt sicher im macOS-Keychain (Suchbegriff: 'ed25519')."
echo "Verlasse niemals diesen Mac ohne diesen Key — sonst können keine signierten Updates mehr erstellt werden."
