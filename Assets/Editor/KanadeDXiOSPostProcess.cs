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
        if (target != BuildTarget.iOS) return;

        string projPath = PBXProject.GetPBXProjectPath(path);
        var project = new PBXProject();
        project.ReadFromFile(projPath);
        string mainTarget = project.GetUnityMainTargetGuid();
        string frameworkTarget = project.GetUnityFrameworkTargetGuid();

        // KdxNFCBridge.mm is compiled into UnityFramework, so link CoreNFC there
        // as well as the app target. The NFC capability/entitlement belongs on
        // the final app target.
        project.AddFrameworkToProject(frameworkTarget, "CoreNFC.framework", false);
        project.AddFrameworkToProject(mainTarget, "CoreNFC.framework", false);
        project.AddCapability(mainTarget, PBXCapabilityType.NFCReader);
        project.WriteToFile(projPath);

        string plistPath = Path.Combine(path, "Info.plist");
        var plist = new PlistDocument();
        plist.ReadFromFile(plistPath);
        plist.root.SetString("NFCReaderUsageDescription", "This app uses NFC to read supported MIFARE cards.");
        plist.WriteToFile(plistPath);

        string entitlementsPath = Path.Combine(path, "KanadeDX.entitlements");
        var entitlements = new PlistDocument();
        if (File.Exists(entitlementsPath)) entitlements.ReadFromFile(entitlementsPath);
        else entitlements.Create();
        var formats = entitlements.root.CreateArray("com.apple.developer.nfc.readersession.formats");
        formats.AddString("TAG");
        entitlements.WriteToFile(entitlementsPath);
        project.SetBuildProperty(mainTarget, "CODE_SIGN_ENTITLEMENTS", "KanadeDX.entitlements");
        project.WriteToFile(projPath);
    }
}
#endif
