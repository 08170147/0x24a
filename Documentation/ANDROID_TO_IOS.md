# Android -> iOS adapter boundary

Android-specific transport must not be copied into iOS. The intended boundary is:

`KdxCardScannerService -> ICardReaderTransport -> IOSReaderTransport -> external reader`

The concrete external-reader connection must be selected from the actual hardware/protocol. No hardware protocol is assumed here.
