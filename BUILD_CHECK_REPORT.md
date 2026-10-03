# KanadeDX iOS build check

Checked from the supplied ZIP before repackaging.

## Result

**PASS — handoff package prepared for macOS/Xcode IPA build.**

## Verified

- Unity version: `2022.3.62f3`
- Main scene: `Assets/Scenes/Main.unity`
- iOS build method: `KanadeDXiOSBuild.Build`
- Xcode post-process: `KanadeDXiOSPostProcess`
- Native NFC bridge: `Assets/Plugins/iOS/KdxNFCBridge.mm/.h`
- CoreNFC framework and NFC Tag Reading capability configured
- `NFCReaderUsageDescription` added by post-process
- iOS deployment target: `13.0`
- Target device: iPhone/iPad
- Initial app version changed from `0.0.0` to `1.0.0`
- Initial iOS build number changed from `0` to `1`
- Shell build scripts pass `bash -n` syntax validation
- Unnecessary Unity generated folders (`Library`, `Temp`, `Obj`, `Builds`) are not included

## Signing / Bundle ID

The project intentionally keeps `app.KanadeDX` as a placeholder Bundle ID because the final ID must belong to the Apple Developer team that will sign the app.

On the Mac, run `Build_KanadeDX_IPA.command` and enter:

1. Apple Team ID
2. Your real Bundle ID, e.g. `com.yourcompany.kanadedx`
3. `development`, `ad-hoc`, or `app-store-connect`

The script then performs Unity → Xcode → Archive → IPA export and runs the included IPA verification script.

## Important limitation

This environment cannot perform the final Apple code-signing step because that requires the signing identity/provisioning assets on a macOS/Xcode machine. The ZIP is therefore a build handoff package, not a pre-signed IPA.
