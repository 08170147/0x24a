using System.Threading;
using System.Threading.Tasks;
using KanadeDX.Core;
using KanadeDX.Protocol;

namespace KanadeDX.Api
{
    // High-level replacement for the recovered AMDaemon.API.UseAime flow.
    public sealed class KanadeDXApi
    {
        private readonly AimeDbClient client;
        public KanadeDXApi(AimeDbClient client) { this.client = client; }

        public Task<AimeDbResult> UseAimeAsync(string accessCode, CancellationToken ct = default)
        {
            byte[] raw = System.Text.Encoding.ASCII.GetBytes(accessCode ?? string.Empty);
            if (raw.Length != 10) throw new System.ArgumentException("Recovered request path passes a 10-byte field; exact access-code encoding must be validated before production use.");
            return client.LookupV2Async(raw, ct);
        }
    }
}
