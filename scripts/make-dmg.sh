#!/usr/bin/env bash
# Erstellt eine DMG-Disk-Image mit InnoWhisper.app + Applications-Symlink +
# Pfeil-Background, fertig fuer Drag-and-Drop-Install.
# Wird nach build-release.sh aufgerufen.
#
# Nutzt das vendored create-dmg in tools/create-dmg, weil Hand-rolled
# AppleScript fuer "set background picture" auf macOS Sequoia still failt.
#
# Ergebnis: dist/InnoWhisper-<VERSION>.dmg, signiert mit demselben Cert.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CERT_NAME="${CERT_NAME:-WhisperDictation Developer}"
DD="${DERIVED_DATA:-/tmp/wd-build}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
APP_PATH="$DD/Build/Products/Release/WhisperDictation.app"
VOL_NAME="InnoWhisper"
APP_NAME_IN_DMG="InnoWhisper.app"
CREATE_DMG="$REPO_ROOT/tools/create-dmg/create-dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "fehler: gebaute .app nicht gefunden: $APP_PATH (erst build-release.sh ausfuehren)"
  exit 1
fi

if [[ ! -x "$CREATE_DMG" ]]; then
  echo "fehler: create-dmg nicht gefunden: $CREATE_DMG"
  echo "  hole es: git clone --depth 1 https://github.com/create-dmg/create-dmg.git tools/create-dmg"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$OUT_DIR/InnoWhisper-$VERSION.dmg"

STAGE_PARENT="$(mktemp -d)"
SRC_DIR="$STAGE_PARENT/source"
BG_PNG="$STAGE_PARENT/background.png"

cleanup() {
  if [[ -d "/Volumes/$VOL_NAME" ]]; then
    hdiutil detach "/Volumes/$VOL_NAME" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGE_PARENT"
}
trap cleanup EXIT

mkdir -p "$OUT_DIR" "$SRC_DIR"

# Vorheriges Volume falls noch gemounted
if [[ -d "/Volumes/$VOL_NAME" ]]; then
  hdiutil detach "/Volumes/$VOL_NAME" -force >/dev/null 2>&1 || true
fi

echo "==> Source-Folder vorbereiten ..."
ditto "$APP_PATH" "$SRC_DIR/$APP_NAME_IN_DMG"

echo "==> Background-Image generieren ..."
SWIFT_GEN="$STAGE_PARENT/gen-bg.swift"
cat > "$SWIFT_GEN" <<'SWIFT_EOF'
import AppKit
import Foundation

// Window-Logik: 600x320 Punkte, Icons bei (150,160) und (450,160), Icon-Size 96.
// Pfeil zwischen den Icons, vertikal auf Icon-Mitte ausgerichtet.

// Finder behandelt das DMG-Background-PNG als 1x (PNG hat keinen DPI-Flag).
// Daher 1:1 mit der window-size erzeugen, sonst zeigt Finder nur einen Ausschnitt.
let scale: CGFloat = 1
let widthLogical: CGFloat = 600
let heightLogical: CGFloat = 320
let width = widthLogical * scale
let height = heightLogical * scale

let img = NSImage(size: NSSize(width: width, height: height))
img.lockFocus()

NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

let yLogical: CGFloat = 160
let yCanvas = height - yLogical * scale
let startX: CGFloat = 240 * scale
let endX: CGFloat = 360 * scale

NSColor(white: 0.55, alpha: 1.0).setStroke()

let stroke: CGFloat = 4 * scale
let shaft = NSBezierPath()
shaft.lineWidth = stroke
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: startX, y: yCanvas))
shaft.line(to: NSPoint(x: endX, y: yCanvas))
shaft.stroke()

let headSize: CGFloat = 12 * scale
let head = NSBezierPath()
head.lineWidth = stroke
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: NSPoint(x: endX - headSize, y: yCanvas + headSize))
head.line(to: NSPoint(x: endX, y: yCanvas))
head.line(to: NSPoint(x: endX - headSize, y: yCanvas - headSize))
head.stroke()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("error: png encode failed\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT_EOF
swift "$SWIFT_GEN" "$BG_PNG"

# Falls ein altes DMG mit gleichem Namen existiert, weg
rm -f "$DMG_PATH"

echo "==> Baue DMG via create-dmg ..."
"$CREATE_DMG" \
  --volname "$VOL_NAME" \
  --background "$BG_PNG" \
  --window-pos 200 120 \
  --window-size 600 320 \
  --icon-size 96 \
  --icon "$APP_NAME_IN_DMG" 150 160 \
  --app-drop-link 450 160 \
  --no-internet-enable \
  --hdiutil-quiet \
  --codesign "$CERT_NAME" \
  "$DMG_PATH" \
  "$SRC_DIR"

echo "==> Verifiziere DMG-Signatur ..."
codesign --verify --verbose=2 "$DMG_PATH"

echo ""
echo "Fertig:"
echo "  DMG:    $DMG_PATH"
echo "  Groesse: $(du -h "$DMG_PATH" | awk '{print $1}')"
echo "  Version: $VERSION"
