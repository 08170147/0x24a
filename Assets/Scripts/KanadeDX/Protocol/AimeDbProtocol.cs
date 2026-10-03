using System;
using System.Buffers;
using System.IO;
using System.Text;

namespace KanadeDX.Protocol
{
    public enum AimeDbOpcode : ushort
    {
        Register = 0x0005,
        Hello = 0x000F,
        LookupV2 = 0x0064,
    }

    public readonly struct AimeDbResult
    {
        public readonly ushort Status;
        public readonly ulong AimeId;
        public AimeDbResult(ushort status, ulong aimeId)
        {
            Status = status;
            AimeId = aimeId;
        }
        public bool HasValue => Status != 0 && Status != 0xFFFF;
        public override string ToString() => $"status=0x{Status:X4}, aimeId={AimeId}";
    }

    public static class AimeDbProtocol
    {
        public const byte Magic0 = 0x3E;
        public const byte Magic1 = 0xA1;
        public const byte Magic2 = 0x87;
        public const byte Magic3 = 0x30;
        public const int HeaderOffset = 0x20;
        public const int HeaderSize = 8;
        public const int PayloadArgumentLength = 0x0A;

        public static byte[] BuildHeader(AimeDbOpcode opcode, ushort length = PayloadArgumentLength)
        {
            return new[] { Magic0, Magic1, Magic2, Magic3,
                (byte)((ushort)opcode & 0xFF), (byte)(((ushort)opcode >> 8) & 0xFF),
                (byte)(length & 0xFF), (byte)(length >> 8) };
        }

        public static byte[] SerializeRequest(byte[] requestObject, AimeDbOpcode opcode, ReadOnlySpan<byte> payload)
        {
            if (requestObject == null) throw new ArgumentNullException(nameof(requestObject));
            if (requestObject.Length < HeaderOffset + HeaderSize + payload.Length)
                throw new ArgumentException("Request buffer is smaller than header + payload.", nameof(requestObject));
            var header = BuildHeader(opcode);
            Buffer.BlockCopy(header, 0, requestObject, HeaderOffset, header.Length);
            payload.CopyTo(requestObject.AsSpan(HeaderOffset + HeaderSize));
            return requestObject;
        }

        // Static-analysis boundary: the APK proves that the common builder copies
        // 10 bytes from an object field at +0x40 (offset 4), and another 20 bytes
        // from +0x50 (offset 11). Their higher-level semantics are not fully proven.
        public static byte[] BuildLookupV2Payload(ReadOnlySpan<byte> tenByteField)
        {
            if (tenByteField.Length != 10) throw new ArgumentException("Expected 10 bytes.");
            return tenByteField.ToArray();
        }

        public static AimeDbResult ParseResult(ReadOnlySpan<byte> response)
        {
            if (response.Length <= 0x27) throw new InvalidDataException("AimeDB response is shorter than the recovered minimum length.");
            ushort status = (ushort)(response[0x08] | (response[0x09] << 8));
            ulong value = 0;
            for (int i = 0; i < 8; i++) value |= ((ulong)response[0x20 + i]) << (8 * i);
            return new AimeDbResult(status, value);
        }
    }
}
