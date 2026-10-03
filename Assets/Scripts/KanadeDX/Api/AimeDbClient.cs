using System;
using System.IO;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using KanadeDX.Protocol;

namespace KanadeDX.Api
{
    public interface IAimeDbTransport
    {
        Task<byte[]> SendAsync(byte[] request, CancellationToken cancellationToken);
    }

    public sealed class TcpAimeDbTransport : IAimeDbTransport
    {
        private readonly string host;
        private readonly int port;
        public TcpAimeDbTransport(string host, int port) { this.host = host; this.port = port; }

        public async Task<byte[]> SendAsync(byte[] request, CancellationToken cancellationToken)
        {
            using var client = new TcpClient();
            await client.ConnectAsync(host, port).ConfigureAwait(false);
            using NetworkStream stream = client.GetStream();
            await stream.WriteAsync(request, 0, request.Length, cancellationToken).ConfigureAwait(false);
            await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
            byte[] buffer = new byte[1024];
            int count = await stream.ReadAsync(buffer, 0, buffer.Length, cancellationToken).ConfigureAwait(false);
            if (count <= 0) throw new IOException("AimeDB returned no data.");
            var result = new byte[count];
            Buffer.BlockCopy(buffer, 0, result, 0, count);
            return result;
        }
    }

    public sealed class AimeDbClient
    {
        private readonly IAimeDbTransport transport;
        public AimeDbClient(IAimeDbTransport transport) { this.transport = transport; }

        public async Task<AimeDbResult> LookupV2Async(byte[] tenBytePayload, CancellationToken ct = default)
        {
            if (tenBytePayload == null || tenBytePayload.Length != 10) throw new ArgumentException("LookupV2 payload must be 10 bytes.");
            // The recovered native allocation is 0x20 bytes; exact payload serialization beyond
            // the verified header is intentionally isolated here for later byte-for-byte validation.
            byte[] request = new byte[0x20];
            AimeDbProtocol.SerializeRequest(request, AimeDbOpcode.LookupV2, tenBytePayload);
            return AimeDbProtocol.ParseResult(await transport.SendAsync(request, ct).ConfigureAwait(false));
        }

        public async Task<AimeDbResult> RegisterAsync(byte[] tenBytePayload, CancellationToken ct = default)
        {
            if (tenBytePayload == null || tenBytePayload.Length != 10) throw new ArgumentException("Register payload must be 10 bytes.");
            byte[] request = new byte[0x30];
            AimeDbProtocol.SerializeRequest(request, AimeDbOpcode.Register, tenBytePayload);
            return AimeDbProtocol.ParseResult(await transport.SendAsync(request, ct).ConfigureAwait(false));
        }
    }
}
