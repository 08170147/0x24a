using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using AOT;
using UnityEngine;

namespace KanadeDX.Reader
{
    public sealed class IOSReaderTransport : ICardReaderTransport
    {
#if UNITY_IOS && !UNITY_EDITOR
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void NativeCallback(IntPtr payload);

        [DllImport("__Internal")] private static extern void KdxNFC_SetCallback(NativeCallback callback);
        [DllImport("__Internal")] private static extern void KdxNFC_Start();
        [DllImport("__Internal")] private static extern void KdxNFC_Stop();
        [DllImport("__Internal")] private static extern int KdxNFC_IsAvailable();
        private static readonly NativeCallback s_nativeCallback = NativeEvent;
#endif

        private readonly ConcurrentQueue<string> events = new ConcurrentQueue<string>();
        private static IOSReaderTransport active;
        private bool initialized;
        private bool terminal;
        private TaskCompletionSource<CardReadResult> pendingRead;
        private long sessionGeneration;

        public Task<bool> InitializeAsync(CancellationToken cancellationToken = default)
        {
#if UNITY_IOS && !UNITY_EDITOR
            active = this;
            terminal = false;
            KdxNFC_SetCallback(s_nativeCallback);
            initialized = KdxNFC_IsAvailable() != 0;
            if (initialized)
            {
                sessionGeneration++;
                KdxNFC_Start();
            }
            return Task.FromResult(initialized);
#else
            initialized = false;
            return Task.FromResult(false);
#endif
        }

        public Task<CardReadResult> ReadCardAsync(CancellationToken cancellationToken = default)
        {
            if (!initialized || terminal)
                return Task.FromResult(new CardReadResult(false, null, null, "iOS NFC is unavailable or session is terminal."));

            if (pendingRead != null)
                return pendingRead.Task;

            pendingRead = new TaskCompletionSource<CardReadResult>(TaskCreationOptions.RunContinuationsAsynchronously);
            DrainEvents();
            return pendingRead.Task;
        }

        public Task ShutdownAsync()
        {
#if UNITY_IOS && !UNITY_EDITOR
            if (initialized) KdxNFC_Stop();
#endif
            terminal = true;
            initialized = false;
            sessionGeneration++;
            pendingRead?.TrySetResult(new CardReadResult(false, null, null, "NFC reader stopped."));
            pendingRead = null;
            if (ReferenceEquals(active, this)) active = null;
            return Task.CompletedTask;
        }

        public void Pump()
        {
            if (!terminal) DrainEvents();
        }

#if UNITY_IOS && !UNITY_EDITOR
        [MonoPInvokeCallback(typeof(NativeCallback))]
        private static void NativeEvent(IntPtr payload)
        {
            var owner = active;
            if (owner == null || payload == IntPtr.Zero) return;
            string json = Marshal.PtrToStringAnsi(payload);
            if (!string.IsNullOrEmpty(json)) owner.events.Enqueue(json);
        }
#endif

        private void DrainEvents()
        {
            while (events.TryDequeue(out var json))
            {
                if (terminal) continue;

                string type = Extract(json, "type");
                switch (type)
                {
                    case "tag_detected":
                    case "tag_connected":
                    case "ready_for_read":
                        break;
                    case "read_success":
                        {
                            string accessCode = Extract(json, "accessCode");
                            pendingRead?.TrySetResult(new CardReadResult(true, null, accessCode, null));
                            pendingRead = null;
                            terminal = true;
                            break;
                        }
                    case "tag_mismatch":
                    case "connect_failure":
                    case "read_failure":
                    case "session_invalidated":
                    case "unavailable":
                        pendingRead?.TrySetResult(new CardReadResult(false, null, json, json));
                        pendingRead = null;
                        terminal = true;
                        break;
                }
            }
        }

        private static string Extract(string json, string key)
        {
            string marker = "\"" + key + "\":\"";
            int start = json.IndexOf(marker, StringComparison.Ordinal);
            if (start < 0) return null;
            start += marker.Length;
            int end = json.IndexOf('"', start);
            return end > start ? json.Substring(start, end - start) : null;
        }
    }
}
