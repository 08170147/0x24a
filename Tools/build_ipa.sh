#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNITY="${UNITY:-/Applications/Unity/Hub/Editor/2022.3.62f3/Unity.app/Contents/MacOS/Unity}"
BUILD_ROOT="$PROJECT_ROOT/Builds"
XCODE_DIR="$BUILD_ROOT/iOS"
ARCHIVE="$BUILD_ROOT/KanadeDX.xcarchive"
EXPORT_DIR="$BUILD_ROOT/IPA"
SCHEME="Unity-iPhone"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-app.KanadeDX}"
EXPORT_METHOD="${EXPORT_METHOD:-development}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"

[[ "$(uname -s)" == "Darwin" ]] || { echo "ERROR: Must run on macOS." >&2; exit 2; }
[[ -x "$UNITY" ]] || { echo "ERROR: Unity not found: $UNITY" >&2; exit 2; }
command -v xcodebuild >/dev/null || { echo "ERROR: xcodebuild not found." >&2; exit 2; }
[[ -n "$TEAM_ID" ]] || { echo "ERROR: TEAM_ID is required." >&2; exit 2; }

if [[ "$EXPORT_METHOD" == "app-store" ]]; then EXPORT_METHOD="app-store-connect"; fi
case "$EXPORT_METHOD" in
  development|ad-hoc|app-store-connect) ;;
  *) echo "ERROR: EXPORT_METHOD must be development, ad-hoc, or app-store-connect." >&2; exit 2;;
esac

rm -rf "$XCODE_DIR" "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_ROOT" "$EXPORT_DIR"

echo "== 1/4 Unity -> Xcode =="
"$UNITY" -batchmode -quit \
  -projectPath "$PROJECT_ROOT" \
  -buildTarget iOS \
  -executeMethod KanadeDXiOSBuild.Build \
  -logFile -

test -d "$XCODE_DIR/Unity-iPhone.xcodeproj"

PROVISION_ARGS=()
[[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]] && PROVISION_ARGS+=("-allowProvisioningUpdates")

# Override the placeholder project settings at build time. Xcode's automatic
# signing uses the Apple account/profiles already available on this Mac.
SIGNING_ARGS=(
  "DEVELOPMENT_TEAM=$TEAM_ID"
  "CODE_SIGN_STYLE=Automatic"
  "PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID"
)

echo "== 2/4 Xcode Archive =="
echo "Bundle ID: $BUNDLE_ID"
echo "Team ID: $TEAM_ID"
echo "Export method: $EXPORT_METHOD"
xcodebuild \
  -project "$XCODE_DIR/Unity-iPhone.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  "${SIGNING_ARGS[@]}" \
  archive \
  "${PROVISION_ARGS[@]}"

test -d "$ARCHIVE"

cat > "$BUILD_ROOT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$EXPORT_METHOD</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict>
</plist>
PLIST

echo "== 3/4 Export IPA =="
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_ROOT/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  "${PROVISION_ARGS[@]}"

IPA="$(find "$EXPORT_DIR" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "$IPA" ]] || { echo "ERROR: No IPA produced." >&2; exit 3; }

cp "$IPA" "$BUILD_ROOT/KanadeDX.ipa"
IPA="$BUILD_ROOT/KanadeDX.ipa"

echo "== 4/4 Verify IPA =="
bash "$PROJECT_ROOT/Tools/verify_ipa.sh" "$IPA" "$BUNDLE_ID" "$TEAM_ID"

echo
echo "========================================"
echo "BUILD SUCCESS"
echo "IPA:     $IPA"
echo "Archive: $ARCHIVE"
echo "Method:  $EXPORT_METHOD"
echo "Team:    $TEAM_ID"
echo "Bundle:  $BUNDLE_ID"
echo "========================================"
