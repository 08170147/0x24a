#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$PROJECT_ROOT/Builds"
XCODE_DIR="$BUILD_ROOT/iOS"
ARCHIVE="$BUILD_ROOT/KanadeDX.xcarchive"
EXPORT_DIR="$BUILD_ROOT/IPA"
SCHEME="Unity-iPhone"

: "${TEAM_ID:?TEAM_ID is required}"
: "${BUNDLE_ID:=app.KanadeDX}"
: "${EXPORT_METHOD:=app-store}"
: "${PROFILE_NAME:?PROFILE_NAME is required}"

case "$EXPORT_METHOD" in
  app-store|ad-hoc|development) ;;
  app-store-connect) EXPORT_METHOD="app-store" ;;
  *) echo "Unsupported EXPORT_METHOD: $EXPORT_METHOD" >&2; exit 2 ;;
esac

rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_ROOT" "$EXPORT_DIR"

cat > "$BUILD_ROOT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>$EXPORT_METHOD</string>
<key>signingStyle</key><string>manual</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>provisioningProfiles</key><dict>
<key>$BUNDLE_ID</key><string>$PROFILE_NAME</string>
</dict>
<key>stripSwiftSymbols</key><true/>
<key>compileBitcode</key><false/>
</dict></plist>
PLIST

echo "== Archive =="
xcodebuild \
  -project "$XCODE_DIR/Unity-iPhone.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
  archive

echo "== Export IPA =="
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_ROOT/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

IPA="$(find "$EXPORT_DIR" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
if [[ -z "$IPA" ]]; then
  echo "ERROR: No IPA produced." >&2
  exit 3
fi

cp "$IPA" "$BUILD_ROOT/KanadeDX.ipa"
echo "IPA=$BUILD_ROOT/KanadeDX.ipa"
