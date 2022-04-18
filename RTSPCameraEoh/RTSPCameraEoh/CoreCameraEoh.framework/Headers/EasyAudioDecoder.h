#ifndef _RTSPAudioDecode_h
#define _RTSPAudioDecode_h

#include "AACDecoder.h"

#ifdef __cplusplus
extern "C" {
#endif
    
typedef struct _HANDLE_ {
    unsigned int code;
    void *pContext;
} EasyAudioHandle;

// Create an audio codec
EasyAudioHandle* EasyAudioDecodeCreate(int code, int sample_rate, int channels, int sample_bit);

// Decode a frame of audio data
int EasyAudioDecode(EasyAudioHandle* pHandle, unsigned char* buffer, int offset, int length, unsigned char* pcm_buffer, int* pcm_length);
    
// Turn off audio decoding frames
void EasyAudioDecodeClose(EasyAudioHandle* pHandle);

#ifdef __cplusplus
}
#endif

#endif
