# Windows → Remote Mac / CI setup

## First run on Windows

Double-click:

`Windows_Build_KanadeDX_IPA.bat`

The script now asks for the Remote Mac settings on the first run:

1. Remote Mac username
2. Remote Mac hostname / IP
3. SSH port (default `22`)
4. Apple Developer Team ID
5. Bundle ID (default `app.KanadeDX`)
6. Remote build directory (default `~/KanadeDXRemoteBuild`)
7. Optional SSH private-key path
8. Export type: Development / Ad Hoc / App Store Connect

The settings are saved in:

`Tools\remote-mac.config.json`

This file contains connection metadata and signing identifiers only. It does **not** store an SSH password or private-key contents.

## Reconfigure later

Run:

```bat
Windows_Build_KanadeDX_IPA.bat -Reconfigure
```

If an old configuration contains a bad SSH-key path, you can also run:

```bat
Tools\reset_remote_mac_config.bat
```

The build script automatically ignores a saved SSH-key path that no longer exists and falls back to Windows OpenSSH default/agent authentication.

or run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tools\build_remote_mac.ps1 -Reconfigure
```

## SSH requirement

Windows must have OpenSSH Client (`ssh.exe` and `scp.exe`). Test with:

```bat
ssh user@mac-host
```

The Remote Mac must accept SSH connections and have the required Unity 2022.3.62f3 iOS module and Xcode installation.

## Apple signing

The Remote Mac must already be signed into the Apple Developer account needed by Xcode automatic signing, or otherwise have the appropriate signing/provisioning material available. The build script passes:

- `DEVELOPMENT_TEAM=<Team ID>`
- `CODE_SIGN_STYLE=Automatic`
- `PRODUCT_BUNDLE_IDENTIFIER=app.KanadeDX`

Core NFC TAG entitlement remains part of the Xcode project/app entitlements; it is not configured in the Windows prompt.


### v10 endpoint validation

The Windows launcher accepts a normal hostname/IP and SSH port separately. It also repairs the common typo `192.168.1.100.22` by interpreting it as host `192.168.1.100` and port `22`.

If the saved endpoint is malformed, use `Tools\reset_remote_mac_config.bat` and enter the host and port in separate fields.


## v11 first-run fix

The Windows launcher now collects the Remote Mac hostname/IP before validating it. A blank Host on first run is therefore prompted normally instead of causing `Remote Mac hostname / IP is empty`. Saved endpoints are normalized afterward, including legacy `192.168.1.100.22` values.


## v12 robust first-run handling

The launcher treats a configuration file with missing required fields as incomplete. It prompts for missing Remote Mac username/host/Team ID, then normalizes and validates the endpoint before saving it. Existing malformed endpoints such as `192.168.1.100.22` are repaired.


## Automatic Mac discovery

The Windows build script can discover the active IPv4 subnet and probe TCP port 22 in parallel. If the saved RemoteHost is unreachable, it offers to scan the local network and select an SSH host. The selected IP is saved back to `Tools/remote-mac.config.json`.
