# GitHub Actions → IPA

這個專案已整理成「上傳 GitHub → Actions → Run workflow → 下載 IPA」流程。

## 1. 建立 GitHub repository

把 `KanadeDX_Unity_iOS` 目錄中的**內容**上傳到 repository 根目錄，確認：

```text
.github/workflows/build-ios-ipa.yml
Assets/
Packages/
ProjectSettings/
Tools/
```

不要上傳 `Library/`、`Temp/`、`Builds/` 或 Apple/Unity 私密金鑰。

## 2. GitHub Secrets

到 **Settings → Secrets and variables → Actions → Secrets**：

### Unity

Unity Personal：

- `UNITY_LICENSE`
- `UNITY_EMAIL`
- `UNITY_PASSWORD`

Unity Pro/Plus/Enterprise：

- `UNITY_EMAIL`
- `UNITY_PASSWORD`
- `UNITY_SERIAL`

GameCI 官方文件說明 Unity Personal 需要一次性的手動 activation，並把 license 檔內容存成 `UNITY_LICENSE`；Pro 類型使用 serial + 帳密。不要把這些值寫進 repository。

### Apple

- `APPLE_TEAM_ID`
- `APPSTORE_CERTIFICATES_FILE_BASE64`
- `APPSTORE_CERTIFICATES_PASSWORD`
- `APPSTORE_API_PRIVATE_KEY`

其中 `.p12` 必須包含可用的 Apple signing certificate + private key。

### GitHub Variables（不是 Secrets）

到 **Settings → Secrets and variables → Actions → Variables**：

- `APPSTORE_ISSUER_ID`
- `APPSTORE_API_KEY_ID`

## 3. Apple 前置條件

Apple Developer / App Store Connect 必須已有對應 Bundle ID，例如：

```text
app.KanadeDX
```

並允許 NFC Tag Reading。

API key、certificate、provisioning profile 必須屬於同一個 Apple Developer Team。

## 4. 執行

GitHub：

**Actions → KanadeDX iOS IPA → Run workflow**

選：

- `app-store`：App Store / TestFlight distribution
- `ad-hoc`：Ad Hoc IPA
- `development`：Development IPA

Bundle ID 預設：

```text
app.KanadeDX
```

成功後到 workflow run 的 **Artifacts** 下載：

```text
KanadeDX-IPA-<method>
```

裡面就是：

```text
KanadeDX.ipa
```

## 5. 重要說明

這不是把 Android APK「轉檔」成 IPA。

GitHub macOS runner 會：

1. 使用 Unity 2022.3.62f3 建立 iOS Xcode project
2. 套用 CoreNFC / NFC Tag Reading 設定
3. 取得 Apple provisioning profile
4. 匯入 signing certificate
5. Xcode archive
6. export signed IPA
7. 驗證 Bundle ID、Team ID、NFC entitlement 和 code signature
8. 將 IPA 上傳成 GitHub Actions artifact

GitHub Actions 本身不會替你產生 Apple Developer 憑證；你仍需要自己的 Apple Developer / App Store Connect 資訊。
