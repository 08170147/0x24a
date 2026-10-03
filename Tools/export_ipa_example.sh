#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT/Builds/KanadeDX.xcarchive"
EXPORT="$ROOT/Builds/IPA"
SCHEME="Unity-iPhone"

rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$EXPORT"

echo "1) Archive with Xcode first (Product > Archive), or use xcodebuild archive with your Team/signing settings."
echo "2) Then export with:"
echo "xcodebuild -exportArchive -archivePath \"$ARCHIVE\" -exportOptionsPlist ExportOptions.plist -exportPath \"$EXPORT\""
echo "Signing is intentionally not hard-coded; Team, provisioning and distribution method belong to the Apple account used on the Mac."
