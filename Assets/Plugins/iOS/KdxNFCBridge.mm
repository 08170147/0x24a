#import "KdxNFCBridge.h"
#import <CoreNFC/CoreNFC.h>

@interface KdxNFCBridge : NSObject <NFCTagReaderSessionDelegate>
- (void)emit:(NSDictionary *)obj;
@property(nonatomic, strong) NFCTagReaderSession *session;
@property(nonatomic, assign) KdxNFCResultCallback callback;
@end

@implementation KdxNFCBridge
- (void)emit:(NSDictionary *)obj {
    if (!self.callback) return;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
    if (error) return;
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    const char *payload = strdup(s.UTF8String);
    self.callback(payload);
    free((void *)payload);
}
- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags {
    if (tags.count == 0) return;
    id<NFCTag> tag = tags.firstObject;
    if (![tag conformsToProtocol:@protocol(NFCMiFareTag)]) {
        [session invalidateSessionWithErrorMessage:@"Detected tag is not an NFC MIFARE tag."];
        [self emit:@{ @"type": @"tag_mismatch" }];
        return;
    }
    id<NFCMiFareTag> mifare = (id<NFCMiFareTag>)tag;
    NSString *uid = [self hex:mifare.identifier];
    NSString *historical = [self hex:mifare.historicalBytes ?: [NSData data]];
    NSString *family = [NSString stringWithFormat:@"%ld", (long)mifare.mifareFamily];
    [self emit:@{ @"type": @"tag_detected", @"family": family, @"uid": uid, @"historicalBytes": historical }];
    [session connectToTag:mifare completionHandler:^(NSError * _Nullable error) {
        if (error) {
            [self emit:@{ @"type": @"connect_failure", @"message": error.localizedDescription ?: @"connect failed" }];
            [session invalidateSessionWithErrorMessage:error.localizedDescription ?: @"NFC connection failed."];
            return;
        }
        [self emit:@{ @"type": @"tag_connected", @"family": family, @"uid": uid }];
        [self emit:@{ @"type": @"ready_for_read", @"family": family, @"uid": uid }];

        // Non-destructive diagnostic: for MIFARE Ultralight, command 0x30 reads a
        // 4-byte page and the tag returns 16 bytes (four consecutive pages).
        // Do not guess Classic authentication keys here. Classic/Plus/DESFire are
        // reported as unsupported until the original Android command sequence is known.
        if (mifare.mifareFamily == NFCMiFareFamilyUltralight) {
            NSData *command = [NSData dataWithBytes:(uint8_t[]){0x30, 0x02} length:2];
            [mifare sendMiFareCommand:command completionHandler:^(NSData * _Nullable response, NSError * _Nullable readError) {
                if (readError) {
                    [self emit:@{ @"type": @"read_failure", @"code": @"mifare_read", @"message": readError.localizedDescription ?: @"MIFARE read failed" }];
                    [session invalidateSessionWithErrorMessage:readError.localizedDescription ?: @"MIFARE read failed."];
                    return;
                }
                NSString *raw = [self hex:response ?: [NSData data]];
                if ((response.length == 16) && response.length >= 16) {
                    const uint8_t *b = response.bytes;
                    NSMutableData *accessBytes = [NSMutableData dataWithBytes:b + 6 length:10];
                    NSString *accessCode = [self hex:accessBytes];
                    [self emit:@{ @"type": @"read_success", @"block": @2, @"raw16": raw, @"accessCode": accessCode, @"family": family, @"uid": uid }];
                    [session invalidateSession];
                } else {
                    [self emit:@{ @"type": @"read_failure", @"code": @"unexpected_length", @"message": [NSString stringWithFormat:@"Expected 16 bytes, got %lu", (unsigned long)response.length], @"raw": raw }];
                    [session invalidateSessionWithErrorMessage:@"Unexpected MIFARE response length."];
                }
            }];
        } else {
            [self emit:@{ @"type": @"read_not_implemented", @"message": @"MIFARE family requires the original Android authentication/command sequence.", @"family": family, @"uid": uid }];
        }
    }];
}
- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    [self emit:@{ @"type": @"session_invalidated", @"message": error.localizedDescription ?: @"NFC session ended" }];
}
- (NSString *)hex:(NSData *)data {
    const unsigned char *b = data.bytes;
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i=0; i<data.length; i++) [s appendFormat:@"%02X", b[i]];
    return s;
}
@end

static KdxNFCBridge *gBridge;

void KdxNFC_SetCallback(KdxNFCResultCallback callback) {
    if (!gBridge) gBridge = [KdxNFCBridge new];
    gBridge.callback = callback;
}
void KdxNFC_Start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!gBridge) gBridge = [KdxNFCBridge new];
        if (![NFCTagReaderSession readingAvailable]) {
            [gBridge emit:@{ @"type": @"unavailable" }];
            return;
        }
        gBridge.session = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:gBridge queue:dispatch_get_main_queue()];
        gBridge.session.alertMessage = @"Hold the iPhone near the NFC card.";
        [gBridge.session beginSession];
    });
}
void KdxNFC_Stop(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gBridge.session invalidateSession];
        gBridge.session = nil;
    });
}
int KdxNFC_IsAvailable(void) { return [NFCTagReaderSession readingAvailable] ? 1 : 0; }
