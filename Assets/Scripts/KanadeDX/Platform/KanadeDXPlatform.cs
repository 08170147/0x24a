namespace KanadeDX.Platform
{
    public static class KanadeDXPlatform
    {
#if UNITY_IOS && !UNITY_EDITOR
        public const string Name = "iOS";
#elif UNITY_ANDROID && !UNITY_EDITOR
        public const string Name = "Android";
#else
        public const string Name = "Editor";
#endif
    }
}
