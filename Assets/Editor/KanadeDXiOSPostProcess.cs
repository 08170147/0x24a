#if UNITY_IOS
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;

public static class KanadeDXiOSPostProcess
{
    [PostProcessBuild(100)]
    public static void OnPostProcessBuild(BuildTarget target, string path)
    {
        if (target != BuildTarget.iOS)
            return;

        string projPath = PBXProject.GetPBXProjectPath(path);

        var project = new PBXProject();
        project.ReadFromFile(projPath);

        string mainTarget = project.GetUnityMainTargetGuid();
        string frameworkTarget = project.GetUnityFrameworkTargetGuid();

        // ------------------------------------------------------------
        // Core NFC
        // ------------------------------------------------------------

        project.AddFrameworkToProject(
            frameworkTarget,
            "CoreNFC.framework",
            false
        );

        project.AddFrameworkToProject(
            mainTarget,
            "CoreNFC.framework",
            false
        );

        var nfcCapability =
            PBXCapabilityType.StringToPBXCapabilityType(
                "com.apple.NearFieldCommunication"
            );

        project.AddCapability(
            mainTarget,
            nfcCapability
        );

        // ------------------------------------------------------------
        // Personal Team / Automatic Signing
        // ------------------------------------------------------------

        // Xcode should manage signing automatically.
        project.SetBuildProperty(
            mainTarget,
            "CODE_SIGN_STYLE",
            "Automatic"
        );

        project.SetBuildProperty(
            mainTarget,
            "DEVELOPMENT_TEAM",
            ""
        );

        // Let Xcode select the Apple Development certificate.
        project.SetBuildProperty(
            mainTarget,
            "CODE_SIGN_IDENTITY",
            "Apple Development"
        );

        project.SetBuildProperty(
            mainTarget,
            "CODE_SIGN_IDENTITY[sdk=iphoneos*]",
            "Apple Development"
        );

        // Do not use a manually specified provisioning profile.
        project.SetBuildProperty(
            mainTarget,
            "PROVISIONING_PROFILE",
            ""
        );

        project.SetBuildProperty(
            mainTarget,
            "PROVISIONING_PROFILE_SPECIFIER",
            ""
        );

        // ------------------------------------------------------------
        // Bundle Identifier
        // ------------------------------------------------------------

        project.SetBuildProperty(
            mainTarget,
            "PRODUCT_BUNDLE_IDENTIFIER",
            "app.KanadeDX"
        );

        // ------------------------------------------------------------
        // Info.plist
        // ------------------------------------------------------------

        string plistPath = Path.Combine(
            path,
            "Info.plist"
        );

        var plist = new PlistDocument();
        plist.ReadFromFile(plistPath);

        plist.root.SetString(
            "NFCReaderUsageDescription",
            "This app uses NFC to read supported MIFARE cards."
        );

        plist.WriteToFile(plistPath);

        // ------------------------------------------------------------
        // NFC Entitlements
        // ------------------------------------------------------------

        string entitlementsPath =
            Path.Combine(
                path,
                "KanadeDX.entitlements"
            );

        var entitlements = new PlistDocument();

        if (File.Exists(entitlementsPath))
            entitlements.ReadFromFile(entitlementsPath);
        else
            entitlements.Create();

        // Avoid duplicate entitlement arrays.
        entitlements.root.values.Remove(
            "com.apple.developer.nfc.readersession.formats"
        );

        var formats =
            entitlements.root.CreateArray(
                "com.apple.developer.nfc.readersession.formats"
            );

        formats.AddString("TAG");

        entitlements.WriteToFile(
            entitlementsPath
        );

        project.SetBuildProperty(
            mainTarget,
            "CODE_SIGN_ENTITLEMENTS",
            "KanadeDX.entitlements"
        );

        // ------------------------------------------------------------
        // Write Xcode project
        // ------------------------------------------------------------

        project.WriteToFile(projPath);

        // ------------------------------------------------------------
        // Unity's PBXProject API does not expose ProvisioningStyle
        // directly, so patch the generated pbxproj for the main target.
        // ------------------------------------------------------------

        string pbxproj =
            File.ReadAllText(projPath);

        const string mainTargetMarker =
            "1D6058900D05DD3D006BFB54 = {";

        int targetStart =
            pbxproj.IndexOf(mainTargetMarker);

        if (targetStart >= 0)
        {
            int targetEnd =
                pbxproj.IndexOf(
                    "};",
                    targetStart
                );

            if (targetEnd >= 0)
            {
                string targetBlock =
                    pbxproj.Substring(
                        targetStart,
                        targetEnd - targetStart
                    );

                targetBlock =
                    targetBlock.Replace(
                        "ProvisioningStyle = Manual;",
                        "ProvisioningStyle = Automatic;"
                    );

                pbxproj =
                    pbxproj.Substring(
                        0,
                        targetStart
                    )
                    + targetBlock
                    + pbxproj.Substring(
                        targetEnd
                    );

                File.WriteAllText(
                    projPath,
                    pbxproj
                );
            }
        }
    }
}
#endif
