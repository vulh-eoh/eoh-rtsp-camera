#ifndef _AACDecoder_h
#define _AACDecoder_h

#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavformat/avformat.h"
#include "libswresample/swresample.h"
#include "libavcodec/avcodec.h"
    
    typedef struct AACDFFmpeg {
        AVCodec *avCodec;
        // Encoder context (stores data related to the decoding method used by the video/audio stream)
        AVCodecContext *pCodecCtx;
        // Store a frame of decoded pixel (sample) data
        AVFrame *pFrame;
        // Resampling structure
        struct SwrContext *au_convert_ctx;
        int out_buffer_size;
        uint8_t audio_buf[100 * 1024];// (uint8_t *)av_malloc(AVCODEC_MAX_AUDIO_FRAME_SIZE * 2);
    } AACDFFmpeg;
    
    //Create aac decoder
    void *aac_decoder_create(enum AVCodecID codecid, int sample_rate, int channels, int bit_rate);
    
    // Decode a frame of audio data
    int aac_decode_frame(void *pParam, unsigned char *pData, int nLen, unsigned char *pPCM, unsigned int *outLen);
    
    // Turn off aac decoder
    void aac_decode_close(void *pParam);
    
#ifdef __cplusplus
}
#endif

#endif



