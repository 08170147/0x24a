#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNITY="${UNITY:-/Applications/Unity/Hub/Editor/2022.3.62f3/Unity.app/Contents/MacOS/Unity}"
OUT="$PROJECT_ROOT/Builds/iOS"

if [[ "$(uname -s)" != "Darwin" ]]; then echo "ERROR: iOS Xcode build requires macOS." >&2; exit 2; fi
if [[ ! -x "$UNITY" ]]; then echo "ERROR: Unity 2022.3.62f3 not found at $UNITY" >&2; exit 2; fi
if ! command -v xcodebuild >/dev/null 2>&1; then echo "ERROR: Xcode command-line tools are not available." >&2; exit 2; fi

rm -rf "$OUT"
mkdir -p "$OUT"
"$UNITY" -batchmode -quit -projectPath "$PROJECT_ROOT" -buildTarget iOS -executeMethod KanadeDXiOSBuild.Build -logFile -

test -d "$OUT/Unity-iPhone.xcodeproj"
echo "Xcode project: $OUT/Unity-iPhone.xcodeproj"
open "$OUT/Unity-iPhone.xcodeproj"
