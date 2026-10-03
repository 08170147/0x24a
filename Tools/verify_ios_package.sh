#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
required=(
  "ProjectSettings/ProjectVersion.txt"
  "ProjectSettings/ProjectSettings.asset"
  "Packages/manifest.json"
  "Assets/Scenes/Main.unity"
  "Assets/Editor/KanadeDXiOSBuild.cs"
  "Assets/Editor/KanadeDXiOSPostProcess.cs"
  "Assets/Plugins/iOS/KdxNFCBridge.mm"
  "Assets/Plugins/iOS/KdxNFCBridge.h"
)
for f in "${required[@]}"; do
  [[ -f "$ROOT/$f" ]] || { echo "MISSING: $f"; exit 1; }
done

grep -q '2022.3.62f3' "$ROOT/ProjectSettings/ProjectVersion.txt"
grep -q 'CoreNFC.framework' "$ROOT/Assets/Editor/KanadeDXiOSPostProcess.cs"
grep -q 'KdxNFC_Start' "$ROOT/Assets/Plugins/iOS/KdxNFCBridge.mm"

echo "KanadeDX iOS package verification: PASS"
echo "Unity: 2022.3.62f3"
echo "Bundle ID: app.KanadeDX (placeholder; set your real Apple App ID before signing)"
echo "NFC: CoreNFC + NFCReader capability post-process configured"
