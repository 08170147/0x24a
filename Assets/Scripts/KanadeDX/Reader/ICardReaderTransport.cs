using System.Threading;
using System.Threading.Tasks;

namespace KanadeDX.Reader
{
    public readonly struct CardReadResult
    {
        public readonly bool Success;
        public readonly byte[] Block2;
        public readonly string AccessCode;
        public readonly string Error;
        public CardReadResult(bool success, byte[] block2, string accessCode, string error = null)
        { Success = success; Block2 = block2; AccessCode = accessCode; Error = error; }
    }

    public interface ICardReaderTransport
    {
        Task<bool> InitializeAsync(CancellationToken cancellationToken = default);
        Task<CardReadResult> ReadCardAsync(CancellationToken cancellationToken = default);
        Task ShutdownAsync();
    }
}
