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
