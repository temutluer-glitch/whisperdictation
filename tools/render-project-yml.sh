#!/usr/bin/env bash
# Rendert project.yml zu project.generated.yml. WD_*-Defaults werden gesetzt,
# wenn sie nicht in der Umgebung definiert sind, dann werden ${WD_*}-Platzhalter
# in project.yml literal ersetzt.
#
# Hintergrund: xcodegen 2.42.0 expandiert nur ${VAR}, nicht ${VAR:-default}.
# envsubst ist auf diesem System nicht verfügbar, daher Python 3.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/project.yml"
OUT="$REPO_ROOT/project.generated.yml"

: "${WD_BUNDLE_ID:=com.innosolv.WhisperDictation}"
: "${WD_DISPLAY_NAME:=WhisperDictation}"
: "${WD_APPICON:=AppIcon}"
: "${WD_FEED_URL:=https://raw.githubusercontent.com/temutluer-glitch/whisperdictation/main/appcast.xml}"
: "${WD_SPARKLE_ENABLED:=true}"

export WD_BUNDLE_ID WD_DISPLAY_NAME WD_APPICON WD_FEED_URL WD_SPARKLE_ENABLED SRC OUT

python3 <<'PY'
import os
src_path = os.environ["SRC"]
out_path = os.environ["OUT"]
keys = ["WD_BUNDLE_ID", "WD_DISPLAY_NAME", "WD_APPICON", "WD_FEED_URL", "WD_SPARKLE_ENABLED"]
with open(src_path, "r", encoding="utf-8") as f:
    text = f.read()
for k in keys:
    placeholder = "${" + k + "}"
    if placeholder not in text:
        raise SystemExit(f"fehler: Placeholder {placeholder} nicht in {src_path} gefunden")
    text = text.replace(placeholder, os.environ[k])
# Schutz: keine WD_*-Platzhalter dürfen im Output verbleiben
import re
leftover = re.findall(r"\$\{WD_[A-Z_]+\}", text)
if leftover:
    raise SystemExit(f"fehler: nicht ersetzte Platzhalter im Output: {leftover}")
with open(out_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"wrote {out_path}")
PY
