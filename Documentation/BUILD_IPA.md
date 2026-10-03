# KanadeDX IPA build handoff (2022.3.62f3)

This project is prepared for Unity 2022.3.62f3 -> Xcode -> IPA.

## Mac build
1. Install Unity 2022.3.62f3 with iOS Build Support and Xcode.
2. Open `KanadeDX_Unity_iOS` in Unity.
3. File > Build Settings > iOS > Switch Platform.
4. Set the real Bundle Identifier and Apple Developer Team in Player Settings/Xcode. The project ships with placeholder Bundle ID `app.KanadeDX`; replace it with an App ID that exists in your Apple Developer account.
5. Build to an empty `Builds/iOS` directory.
6. Open `Unity-iPhone.xcodeproj` in Xcode.
7. Select the `Unity-iPhone` target, set Team/signing, and verify `Near Field Communication Tag Reading`.
8. Connect a real iPhone and use Product > Run for device validation.
9. For a distributable IPA, select an appropriate archive destination and Product > Archive.
10. Organizer > Distribute App > Export (or Upload for TestFlight/App Store Connect).

## What is automated
`Assets/Editor/KanadeDXiOSPostProcess.cs` automatically adds CoreNFC.framework, NFC tag-reading capability, and the NFC usage description to the generated Xcode project.

`Assets/Plugins/iOS/KdxNFCBridge.mm` is a diagnostic Core NFC bridge. It detects MIFARE tags and reports family/UID/historical bytes to the managed layer, but deliberately does NOT issue the block-2 authentication/read command yet.

## Important NFC limitation
APK analysis proves: read MIFARE block #2 -> 16 bytes -> take bytes [6..15] -> hex -> 20-character AccessCode.
It does not prove the MIFARE family, authentication key, authentication command, or exact native PN532 command sequence. Therefore the bridge must not guess those values.

## Signing
No signed IPA is included. Apple signing credentials and Xcode are required on macOS.

## Mac command-line helper
Set UNITY if Unity is installed elsewhere, then run:

    ./Tools/build_ios_xcode.sh

This invokes Unity 2022.3.62f3 in batch mode and opens the generated Xcode project.
The script does not invent Apple signing settings.

## v4 stability notes

The iOS transport retains the native callback delegate for the lifetime of the process, and ignores events after a terminal NFC session. This prevents a late Core NFC callback from completing a later Unity read operation.

The project still intentionally does not invent a MIFARE Classic key or authentication sequence. The APK analysis proves the downstream transform (block 2 -> 16 bytes -> bytes 6..15 -> hex AccessCode), but not the upstream authentication key/command sequence.
