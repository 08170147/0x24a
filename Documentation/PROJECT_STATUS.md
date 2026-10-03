# KanadeDX Unity iOS skeleton — source basis and boundaries

Target Unity: **2022.3.62f3**.

## Confirmed from the supplied APK

- Unity IL2CPP application.
- `KdxCardScannerService.SubmitAccessCode` enforces a 1.5 second elapsed-time gate and stores the submitted code.
- MIFARE block #2 is reduced with offset 6 / length 10 and converted to hex to form the recovered access-code path.
- AimeDB native request builder writes magic bytes `3E A1 87 30` at request `+0x20..+0x23`.
- Opcode is little-endian at `+0x24..+0x25`.
- The common builder receives payload-length argument `0x0A` for the recovered Hello/Register/Lookup paths.
- Hello opcode `0x000F`; Register opcode `0x0005`; LookupV2 opcode `0x0064`.
- LookupV2 native allocation size is `0x20`; Register and Hello are `0x30`.
- Recovered result parser reads status from response `+0x08` and an 8-byte value from `+0x20`.
- The recovered result type names that value `AimeId`.

## Deliberately NOT inferred

- The exact final serialized payload semantics beyond the verified header and observed copy lengths.
- The semantic meaning of status `0x0000` vs `0xFFFF`.
- The complete WebSocket message schema.
- A production iOS NFC/USB reader implementation.
- The live server endpoint/credentials.

The skeleton isolates these boundaries so they can be filled in after byte-for-byte validation against captured/test fixtures or an authorized implementation.
