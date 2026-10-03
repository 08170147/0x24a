#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "KanadeDX Unity iOS — one-click IPA builder"
echo
read -r -p "Apple Team ID: " TEAM_ID
read -r -p "Bundle ID [app.KanadeDX]: " BUNDLE_ID
BUNDLE_ID="${BUNDLE_ID:-app.KanadeDX}"
read -r -p "Export method [development/ad-hoc/app-store] (development): " EXPORT_METHOD
EXPORT_METHOD="${EXPORT_METHOD:-development}"

export TEAM_ID BUNDLE_ID EXPORT_METHOD
./Tools/build_ipa.sh
STATUS=$?

echo
if [[ "$STATUS" -eq 0 ]]; then
  echo "IPA created and verified: Builds/KanadeDX.ipa"
else
  echo "Build failed. Review the log above."
fi
read -r -p "Press Enter to close..." _
exit "$STATUS"
