# KanadeDX — Unity 2022.3.62f3 iOS project skeleton

This is a **buildable architecture skeleton**, not a claim that the original Android binary has been fully reconstructed.

## Open

Open this folder in **Unity 2022.3.62f3**. Then select iOS as the build target.

## Main components

- `KdxCardScannerService` — recovered scanner-side behavior and 1.5 s submission gate.
- `KanadeDXAccessCode` — recovered MIFARE block #2 -> offset 6 / 10 bytes -> uppercase hex path.
- `ICardReaderTransport` — platform-neutral reader contract.
- `IOSReaderTransport` — iOS managed placeholder for the eventual native reader plugin.
- `AimeDbProtocol` — recovered AimeDB header/opcode/result structures.
- `AimeDbClient` — async TCP transport abstraction and request/response framing skeleton.
- `KanadeDXApi` — high-level UseAime-style façade.

## Important

The exact payload semantics after the recovered header are not fully established from the supplied APK. The code intentionally does not invent those bytes. Likewise, no live endpoint is configured.

For a final IPA, run the Unity iOS build on macOS, open the generated Xcode project, add the authorized reader native bridge, configure signing, and archive/export the IPA.

## Windows → Remote Mac first-run setup

Run `Windows_Build_KanadeDX_IPA.bat`. On the first run it interactively asks for the Remote Mac SSH details, Apple Team ID, Bundle ID, remote build directory, optional SSH key, and export type. Settings are saved to `Tools\remote-mac.config.json` for subsequent runs. Use `-Reconfigure` to change them.

## Windows Remote Mac setup

Run `Windows_Build_KanadeDX_IPA.bat`. On first run it asks for the Remote Mac username/host, SSH port, Apple Team ID, Bundle ID, optional SSH key, and IPA export type. Settings are saved under `Tools\remote-mac.config.json`. If an old configuration contains an invalid SSH key path, the script automatically ignores it and uses the normal Windows OpenSSH authentication.


## Cloud macOS IPA build from Windows

This project includes `Windows_Upload_To_Cloud_IPA.bat` and `.github/workflows/build-ios-ipa.yml`. They upload the Unity project from Windows to GitHub, then use a hosted macOS runner to run Unity 2022.3.62f3, generate the Xcode project, sign with Apple credentials, and export `KanadeDX.ipa`. See `Documentation/CLOUD_BUILD_GITHUB.md`.
