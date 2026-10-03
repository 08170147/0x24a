using System;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;
using KanadeDX.Reader;

namespace KanadeDX.Core
{
    public sealed class KdxCardScannerService : MonoBehaviour
    {
        [SerializeField] private bool initializeOnStart = true;
        private ICardReaderTransport reader;
        private IOSReaderTransport iosReader;
        private string lastAccessCode;
        private float lastSubmitTime = -100f;

        public event Action<string> AccessCodeRead;
        public string LastAccessCode => lastAccessCode;

        public void Bootstrap(ICardReaderTransport transport) => reader = transport;

        private async void Start()
        {
            if (!initializeOnStart) return;
            iosReader = new IOSReaderTransport();
            Bootstrap(iosReader);
            await reader.InitializeAsync();
        }

        private async void Update()
        {
            iosReader?.Pump();
            if (reader == null || Time.unscaledTime - lastSubmitTime < 1.5f) return;
            var result = await reader.ReadCardAsync();
            if (!result.Success || string.IsNullOrEmpty(result.AccessCode)) return;
            SubmitAccessCode(result.AccessCode);
        }

        public void SubmitAccessCode(string accessCode)
        {
            if (string.IsNullOrEmpty(accessCode)) return;
            if (string.Equals(lastAccessCode, accessCode, StringComparison.Ordinal)) return;
            if (Time.unscaledTime - lastSubmitTime < 1.5f) return;
            lastAccessCode = accessCode;
            lastSubmitTime = Time.unscaledTime;
            AccessCodeRead?.Invoke(accessCode);
        }

        private async void OnDestroy()
        {
            if (reader != null) await reader.ShutdownAsync();
        }
    }
}
