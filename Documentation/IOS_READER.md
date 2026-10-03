# iOS reader boundary

`ICardReaderTransport` is the only dependency used by the scanner service.

The intended production arrangement is:

`KdxCardScannerService -> ICardReaderTransport -> IOSReaderTransport -> native iOS reader bridge`

The native bridge can later be implemented as an Objective-C/Swift plugin under `Assets/Plugins/iOS` once the actual hardware/API is known. The managed layer expects a 16-byte MIFARE block #2 and derives the AccessCode from bytes 6..15.
