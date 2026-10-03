using System;
using System.Linq;

namespace KanadeDX.Core
{
    public static class KanadeDXAccessCode
    {
        // Recovered from the APK: MIFARE block #2 -> SubArray(offset 6, length 10) -> ToHex.
        public static string FromMifareBlock2(byte[] block2)
        {
            if (block2 == null) throw new ArgumentNullException(nameof(block2));
            if (block2.Length < 16) throw new ArgumentException("MIFARE block #2 must contain at least 16 bytes.");
            return string.Concat(block2.Skip(6).Take(10).Select(b => b.ToString("X2")));
        }
    }
}
