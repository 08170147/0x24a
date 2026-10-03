#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

test -f ProjectSettings/ProjectVersion.txt
grep -q '2022.3.62f3' ProjectSettings/ProjectVersion.txt
test -f Assets/Editor/KanadeDXiOSBuild.cs
test -f Assets/Editor/KanadeDXiOSPostProcess.cs
test -f .github/workflows/build-ios-ipa.yml

echo "KanadeDX GitHub IPA handoff: structure OK."
