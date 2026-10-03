#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${TEAM_ID:?TEAM_ID is required}"
export BUNDLE_ID="${BUNDLE_ID:-app.KanadeDX}"
export EXPORT_METHOD="${EXPORT_METHOD:-app-store}"
export ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"

./Tools/build_ipa.sh
