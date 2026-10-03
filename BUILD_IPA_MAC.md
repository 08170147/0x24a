# One-click macOS IPA build

This project uses Unity 2022.3.62f3 and builds an iOS Xcode project first. The one-click launcher then archives it, exports a signed IPA, and verifies the final IPA.

## Prerequisites

- macOS
- Unity 2022.3.62f3 with iOS Build Support
- Xcode + command-line tools
- Apple Developer account signed into Xcode
- An explicit App ID matching the final Bundle ID, with **Near Field Communication Tag Reading** enabled
- A usable development/ad-hoc/App Store provisioning configuration, depending on `EXPORT_METHOD`

## One click

Double-click:

`Build_KanadeDX_IPA.command`

The script asks for:

- Apple Team ID
- Bundle ID
- export method (`development`, `app-store-connect`, or `ad-hoc`)

It then runs:

`Unity -> Xcode project -> Archive -> Export IPA -> NFC/signing verification`

## Terminal / CI

```bash
TEAM_ID=ABCDE12345 \
BUNDLE_ID=com.example.kanadedx \
EXPORT_METHOD=development \
./Tools/build_ipa.sh
```

For App Store/TestFlight export:

```bash
TEAM_ID=ABCDE12345 \
BUNDLE_ID=app.KanadeDX \
EXPORT_METHOD=app-store-connect \
./Tools/build_ipa.sh
```

If automatic provisioning is unavailable on the Mac, set `ALLOW_PROVISIONING_UPDATES=0` and use profiles/certificates already installed in the keychain.

## Output

- `Builds/iOS/Unity-iPhone.xcodeproj`
- `Builds/KanadeDX.xcarchive`
- `Builds/IPA/*.ipa`
- `Builds/KanadeDX.ipa`
- `Builds/ExportOptions.plist`

## Final checks

`Tools/verify_ipa.sh` verifies:

- final Bundle ID
- `NFCReaderUsageDescription`
- `codesign --verify --deep --strict`
- signed TeamIdentifier
- signed `com.apple.developer.nfc.readersession.formats` contains `TAG`
- `embedded.mobileprovision`
- provisioning `application-identifier`
- provisioning Team ID
- provisioning NFC `TAG` entitlement
- profile expiration
- signed/profile NFC entitlement consistency

The script deliberately does **not** fabricate certificates, provisioning profiles, or Apple credentials. Those must belong to the Apple Developer account used on the Mac.


For Windows -> remote Mac builds, see `Tools/REMOTE_MAC_SETUP.md` and run `Windows_Build_KanadeDX_IPA.bat`.
