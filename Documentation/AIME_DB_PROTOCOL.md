# Recovered AimeDB protocol skeleton

## Request header

The common native request builder writes, at object offset `0x20`:

| Offset | Meaning | Confirmed value |
|---|---|---|
| +0x20 | magic[0] | `0x3E` |
| +0x21 | magic[1] | `0xA1` |
| +0x22 | magic[2] | `0x87` |
| +0x23 | magic[3] | `0x30` |
| +0x24 | opcode LE | operation-specific |
| +0x26 | payload-length argument LE | `0x000A` in recovered calls |

Operations:

- Hello: opcode `0x000F`, allocation `0x30`.
- Register: opcode `0x0005`, allocation `0x30`.
- LookupV2: opcode `0x0064`, allocation `0x20`.

The native helper then copies a 10-byte region from one object field and, for the larger request path, a 20-byte region from another field. Their exact semantic layout is not fully proven and is intentionally isolated in the skeleton.

## Response

The recovered parsers require a response longer than `0x27` bytes. They read:

- `UInt16` status at response offset `0x08`.
- `UInt64` AimeId at response offset `0x20`.

## Status branch

The recovered `UseAime` coroutine treats status `0x0000` and `0xFFFF` as a special branch. This skeleton does not label either value as success/failure because the supplied binary analysis did not prove that semantic mapping.
