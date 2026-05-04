#!/usr/bin/env bash
# Baut WhisperDictation als Release-.app und signiert sie mit dem stabilen
# Self-Signed-Cert "WhisperDictation Developer".
#
# Voraussetzung: scripts/setup-signing-cert.sh wurde einmalig ausgeführt.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BETA_MODE=0
for arg in "$@"; do
  case "$arg" in
    --beta) BETA_MODE=1 ;;
    *) echo "unbekanntes Argument: $arg"; exit 1 ;;
  esac
done

if [[ $BETA_MODE -eq 1 ]]; then
  echo "==> Beta-Variante"
  export WD_BUNDLE_ID="com.innosolv.WhisperDictation.beta"
  export WD_DISPLAY_NAME="InnoWhisper Beta"
  export WD_APPICON="AppIconBeta"
  export WD_SPARKLE_ENABLED="false"
  export WD_FEED_URL="about:blank"
  echo "    Bundle-ID:    $WD_BUNDLE_ID"
  echo "    Display-Name: $WD_DISPLAY_NAME"
  echo "    AppIcon:      $WD_APPICON"
  echo "==> Generiere Beta-Icon"
  swift "$REPO_ROOT/tools/generate-beta-icon.swift"
fi

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

echo "==> Rendere project.yml zu project.generated.yml …"
bash "$REPO_ROOT/tools/render-project-yml.sh" >/dev/null

echo "==> Generiere Xcode-Projekt …"
"$XCG" generate --spec "$REPO_ROOT/project.generated.yml" >/dev/null

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
SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"

# Stale signatures der nested bundles entfernen, damit die anschliessende
# Deep-Signing keinen Konflikt mit pre-existing _CodeSignature/CodeResources
# Dateien hat (verursacht sonst "Sparkle.cstemp missing" verify errors).
echo "    Clean: alte _CodeSignature/ in Sparkle.framework entfernen"
find "$SPARKLE_FW" -name _CodeSignature -type d -exec rm -rf {} + 2>/dev/null || true
find "$SPARKLE_FW" -name "*.cstemp" -delete 2>/dev/null || true

# Sparkle.framework rekursiv mit Deep signen — re-signiert alle nested
# XPC services, Updater.app, Autoupdate consistent mit unserer Identity.
echo "    Sign: Sparkle.framework (deep)"
codesign --force --deep --options=runtime --timestamp=none \
  --sign "$CERT_NAME" "$SPARKLE_FW"

# App-Bundle als letztes (mit Entitlements, ohne deep — Frameworks sind schon korrekt)
echo "    Sign: WhisperDictation.app"
codesign --force --options=runtime --timestamp=none \
  --entitlements "$ENTITLEMENTS" \
  --sign "$CERT_NAME" "$APP_PATH"

echo "==> Verifiziere Signatur …"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep -E "(Identifier|Authority|TeamIdentifier|Signature)" || true

# Version aus Info.plist ziehen
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ZIP_PATH="$OUT_DIR/InnoWhisper-$VERSION.zip"

if [[ $BETA_MODE -eq 1 ]]; then
  TARGET="/Applications/InnoWhisper Beta.app"
  LEGACY_TARGET="/Applications/WhisperDictation Beta.app"

  quit_running_beta() {
    local bundle_path="$1"
    local app_name
    app_name="$(basename "$bundle_path" .app)"
    if ! pgrep -f "$bundle_path/Contents/MacOS/WhisperDictation" >/dev/null 2>&1; then
      return 0
    fi
    echo "==> Laufende Beta '$app_name' wird per Apple-Event beendet …"
    osascript -e "tell application \"$app_name\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5; do
      pgrep -f "$bundle_path/Contents/MacOS/WhisperDictation" >/dev/null 2>&1 || return 0
      sleep 1
    done
    echo "fehler: Beta-Instanz '$app_name' reagiert nicht auf Quit. Bitte manuell im Menubar beenden." >&2
    return 1
  }

  quit_running_beta "$TARGET" || exit 1
  quit_running_beta "$LEGACY_TARGET" || exit 1
  echo "==> Installiere nach $TARGET"
  rm -rf "$TARGET"
  ditto "$APP_PATH" "$TARGET"
  if [[ -d "$LEGACY_TARGET" ]]; then
    echo "==> Entferne alte Beta unter $LEGACY_TARGET"
    rm -rf "$LEGACY_TARGET"
  fi
  echo ""
  echo "Fertig (Beta):"
  echo "  Source:   $APP_PATH"
  echo "  Install:  $TARGET"
  echo "  Version:  $VERSION"
  echo "  Bundle:   $WD_BUNDLE_ID"
else
  echo "==> Zippe für Sparkle …"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

  DMG_PATH="$OUT_DIR/InnoWhisper-$VERSION.dmg"
  echo "==> Baue DMG für manuelle Installation …"
  bash "$REPO_ROOT/scripts/make-dmg.sh"

  echo ""
  echo "Fertig:"
  echo "  App: $APP_PATH"
  echo "  Zip: $ZIP_PATH"
  echo "  DMG: $DMG_PATH"
  echo "  Version: $VERSION"
fi
