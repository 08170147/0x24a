using System;
using System.Threading.Tasks;

namespace KanadeDX.Remote
{
    public interface IRemoteCardReader
    {
        Task<string> GetAccessCodeAsync();
    }

    public sealed class KdxRemoteCardReader : IRemoteCardReader
    {
        private readonly string endpoint;
        public KdxRemoteCardReader(string endpoint) { this.endpoint = endpoint; }
        public Task<string> GetAccessCodeAsync() =>
            throw new NotSupportedException("WebSocket message schema was not fully recovered from the APK.");
        public string Endpoint => endpoint;
    }
}
