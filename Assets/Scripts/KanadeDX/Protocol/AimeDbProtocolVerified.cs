using System;

namespace KanadeDX.AimeDB
{
    /// <summary>
    /// Byte layouts directly reconstructed from libil2cpp.so.
    /// Do not treat unresolved transformation steps as guesses.
    /// </summary>
    public static class AimeDbProtocolVerified
    {
        public const ushort HelloOpcode = 0x000F;
        public const ushort RegisterOpcode = 0x0005;
        public const ushort LookupV2Opcode = 0x0064;
        public const uint Magic = 0x3087A13E; // bytes: 3E A1 87 30, little-endian view

        public static byte[] BuildHello(byte[] transformedAccessCode10)
            => Build48(HelloOpcode, transformedAccessCode10);

        public static byte[] BuildRegister(byte[] transformedAccessCode10)
            => Build48(RegisterOpcode, transformedAccessCode10);

        public static byte[] BuildLookupV2()
        {
            var packet = BuildHeader(LookupV2Opcode, 0x20);
            return packet;
        }

        private static byte[] Build48(ushort opcode, byte[] transformedAccessCode10)
        {
            var packet = BuildHeader(opcode, 0x30);
            if (transformedAccessCode10 == null)
                throw new ArgumentNullException(nameof(transformedAccessCode10));

            int count = Math.Min(10, transformedAccessCode10.Length);
            Buffer.BlockCopy(transformedAccessCode10, 0, packet, 0x20, count);
            return packet;
        }

        private static byte[] BuildHeader(ushort opcode, int size)
        {
            var packet = new byte[size];
            packet[0] = 0x3E;
            packet[1] = 0xA1;
            packet[2] = 0x87;
            packet[3] = 0x30;
            packet[4] = (byte)(opcode & 0xFF);
            packet[5] = (byte)(opcode >> 8);
            packet[6] = (byte)(size & 0xFF);
            packet[7] = (byte)(size >> 8);
            return packet;
        }
    }
}
