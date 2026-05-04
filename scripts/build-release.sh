#!/usr/bin/env bash
# Baut WhisperDictation als Release-.app und signiert sie mit dem stabilen
# Self-Signed-Cert "WhisperDictation Developer".
#
# Voraussetzung: scripts/setup-signing-cert.sh wurde einmalig ausgeführt.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CERT_NAME="${CERT_NAME:-WhisperDictation Developer}"
DD="${DERIVED_DATA:-/tmp/wd-build}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
SCHEME="WhisperDictation"

if ! security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
  echo "fehler: Cert '$CERT_NAME' nicht im Keychain. Erst 'scripts/setup-signing-cert.sh' ausführen."
  exit 1
fi

XCG="${XCODEGEN:-/tmp/xcg/xcodegen/bin/xcodegen}"
command -v xcodegen >/dev/null 2>&1 && XCG="$(command -v xcodegen)"
if [[ ! -x "$XCG" ]]; then
  echo "fehler: xcodegen nicht gefunden. Hole es: brew install xcodegen"
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "==> Generiere Xcode-Projekt …"
"$XCG" generate >/dev/null

echo "==> Baue Release …"
xcodebuild -project WhisperDictation.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DD" \
  build >/dev/null

APP_PATH="$DD/Build/Products/Release/WhisperDictation.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "fehler: gebaute .app nicht gefunden: $APP_PATH"
  exit 1
fi

ENTITLEMENTS="$REPO_ROOT/Sources/WhisperDictation/WhisperDictation.entitlements"

echo "==> Re-Sign mit '$CERT_NAME' …"
# Erst Frameworks signieren, dann das App-Bundle (deep funktioniert nicht für nested signed bundles wie Sparkle.framework's XPC-Helpers)
find "$APP_PATH/Contents/Frameworks" -type d -name '*.framework' -prune -print 2>/dev/null | while read -r fw; do
  echo "    Sign FW: $fw"
  codesign --force --options=runtime --timestamp=none --sign "$CERT_NAME" "$fw"
done

# Sparkle bundles/XPCs separat signieren
find "$APP_PATH" -type d \( -name "*.xpc" -o -name "*.app" \) -prune -print 2>/dev/null | while read -r nested; do
  if [[ "$nested" != "$APP_PATH" ]]; then
    echo "    Sign Bundle: $nested"
    codesign --force --options=runtime --timestamp=none --sign "$CERT_NAME" "$nested"
  fi
done

echo "    Sign App: $APP_PATH"
codesign --force --options=runtime --timestamp=none \
  --entitlements "$ENTITLEMENTS" \
  --sign "$CERT_NAME" \
  "$APP_PATH"

echo "==> Verifiziere Signatur …"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep -E "(Identifier|Authority|TeamIdentifier|Signature)" || true

# Version aus Info.plist ziehen
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ZIP_PATH="$OUT_DIR/WhisperDictation-$VERSION.zip"

echo "==> Zippe für Sparkle …"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "Fertig:"
echo "  App: $APP_PATH"
echo "  Zip: $ZIP_PATH"
echo "  Version: $VERSION"
