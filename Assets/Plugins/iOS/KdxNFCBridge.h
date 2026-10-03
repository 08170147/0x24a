#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*KdxNFCResultCallback)(const char *payload);
void KdxNFC_SetCallback(KdxNFCResultCallback callback);
void KdxNFC_Start(void);
void KdxNFC_Stop(void);
int KdxNFC_IsAvailable(void);

#ifdef __cplusplus
}
#endif
