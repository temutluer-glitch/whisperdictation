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

# Genau 10 PNGs erwartet, kein Extra-Drift.
PNG_COUNT="$(find "$ICONSET" -name '*.png' -type f | wc -l | tr -d ' ')"
if [[ "$PNG_COUNT" != "10" ]]; then
  echo "fehler: erwartet 10 PNGs in $ICONSET, gefunden $PNG_COUNT"
  exit 1
fi

# Contents.json muss valides JSON sein und genau die erwarteten PNGs referenzieren.
ICONSET="$ICONSET" python3 - <<'PY'
import json, os, sys
iconset = os.environ["ICONSET"]
expected = sorted([
    "icon_16x16.png", "icon_16x16@2x.png",
    "icon_32x32.png", "icon_32x32@2x.png",
    "icon_128x128.png", "icon_128x128@2x.png",
    "icon_256x256.png", "icon_256x256@2x.png",
    "icon_512x512.png", "icon_512x512@2x.png",
])
data = json.load(open(os.path.join(iconset, "Contents.json")))
names = sorted(img["filename"] for img in data["images"])
if names != expected:
    sys.stderr.write(f"fehler: Contents.json drift\n  erwartet: {expected}\n  gefunden: {names}\n")
    sys.exit(1)
PY

echo "ok"
