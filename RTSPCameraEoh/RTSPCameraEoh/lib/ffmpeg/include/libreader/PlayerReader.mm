//
//  PlayerReader.cpp
//  RTSPCameraEoh
//
//  Created by a on 4/12/22.
//
//

#import "PlayerReader.h"

#include <pthread.h>
#include <vector>
#include <set>
#include <string.h>
#include <math.h>

#import  "CoreCameraEoh/HWVideoDecoder.h"
#import  "CoreCameraEoh/NSUserDefaultsUnit.h"
#include "CoreCameraEoh/VideoDecode.h"
#include "CoreCameraEoh/EasyAudioDecoder.h"
#include "CoreCameraEoh/Muxer.h"
#include "CoreCameraEoh/RTSPUnit.h"

struct FrameInfo {
    FrameInfo() : pBuf(NULL), frameLen(0), type(0), timeStamp(0), width(0), height(0){}
    
    unsigned char *pBuf;
    int frameLen;
    int type;
    CGFloat timeStamp;// Milliseconds (1 second = 1000 milliseconds 1 second = 1000000 microseconds)
    int width;
    int height;
};

class compare {
public:
    bool operator ()(FrameInfo *lhs, FrameInfo *rhs) const {
        return lhs->timeStamp < rhs->timeStamp;
    }
};

pthread_mutex_t mutexRecordVideoFrame;
pthread_mutex_t mutexRecordAudioFrame;

std::multiset<FrameInfo *, compare> recordVideoFrameSet;
std::multiset<FrameInfo *, compare> recordAudioFrameSet;

int isKeyFrame = 0; // Frame is not kiểm tra khu hình trên fps của 1 giây
int *stopRecord = (int *)malloc(sizeof(int));// Stop recording

@interface PlayerReader()<HWVideoDecoderDelegate> {
    // RTSP pull stream handle
    Easy_Handle rtspHandle;
    
    //Mutex
    pthread_mutex_t mutexVideoFrame;
    pthread_mutex_t mutexAudioFrame;
    
    pthread_mutex_t mutexCloseAudio;
    pthread_mutex_t mutexCloseVideo;
    
    pthread_mutex_t mutexInit;
    pthread_mutex_t mutexStop;
    
    void *_videoDecHandle;  // Video decode handle
    void *_audioDecHandle;  // Audio decode handle
    
    EASY_MEDIA_INFO_T _mediaInfo;   // Media information
    
    std::multiset<FrameInfo *, compare> videoFrameSet;
    std::multiset<FrameInfo *, compare> audioFrameSet;
    
    // The unit is in milliseconds
    long previousStampUs;
    long lastFrameStampUs;
    long decodeBegin;
    long hwSleepTime;
    CGFloat mNewestStample;
    
    CGFloat _lastVideoFramePosition;
    
    // Video Hard Codec ffmpeg xử lý các frame khi ping về
    HWVideoDecoder *_hwDec;
}

@property (nonatomic, readwrite) BOOL running;
@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) NSThread *audioThread;

@property (nonatomic, assign) int lastWidth;
@property (nonatomic, assign) int lastHeight;

// EASY_SDK_VIDEO_CODEC_H265/EASY_SDK_VIDEO_CODEC_H264编码方式
@property (nonatomic) enum AVCodecID codecID;

- (void)pushFrame:(char *)pBuf frameInfo:(EASY_FRAME_INFO *)info type:(int)type;
- (void)recvMediaInfo:(EASY_MEDIA_INFO_T *)info;

@end

#pragma mark - Callback after pulling the stream

/*
 _channelId: channel number, temporarily not used
  _channelPtr: Channel corresponding object
  _frameType: EASY_SDK_VIDEO_FRAME_FLAG/EASY_SDK_AUDIO_FRAME_FLAG/EASY_SDK_EVENT_FRAME_FLAG/...
  _pBuf: The data part of the callback, see Demo for specific usage
  _frameInfo: frame structure data
 */
int RTSPDataCallBack(int channelId, void *channelPtr, int frameType, char *pBuf, EASY_FRAME_INFO *frameInfo) {
    if (channelPtr == NULL) {
        return 0;
    }
    
    if (pBuf == NULL) {
        return 0;
    }
    
    PlayerReader *reader = (__bridge PlayerReader *)channelPtr;
    
    if (frameInfo != NULL) {
        if (frameType == EASY_SDK_AUDIO_FRAME_FLAG) {// EASY_SDK_AUDIO_FRAME_FLAG Audio frame flag
            [reader pushFrame:pBuf frameInfo:frameInfo type:frameType];
        } else if (frameType == EASY_SDK_VIDEO_FRAME_FLAG ) {   // EASY_SDK_VIDEO_FRAME_FLAG Video frame logo
            [reader pushFrame:pBuf frameInfo:frameInfo type:frameType];
            
            if (frameInfo->codec == EASY_SDK_VIDEO_CODEC_H265) {// H265 Video encoding dựa trên H265 rtsp
                reader.codecID = AV_CODEC_ID_HEVC;
            } else if (frameInfo->codec == EASY_SDK_VIDEO_CODEC_H264) {// H264 Video encoding
                reader.codecID = AV_CODEC_ID_H264;
            }
        }
    } else {
        if (frameType == EASY_SDK_MEDIA_INFO_FLAG) {// EASY_SDK_MEDIA_INFO_FLAG Media type flag
            EASY_MEDIA_INFO_T mediaInfo = *((EASY_MEDIA_INFO_T *)pBuf);
            
//            NSLog(@"\n Media Info:video:%u fps:%u audio:%u channel:%u sampleRate:%u \n",
//                  mediaInfo.u32VideoCodec,
//                  mediaInfo.u32VideoFps,
//                  mediaInfo.u32AudioCodec,
//                  mediaInfo.u32AudioChannel,
//                  mediaInfo.u32AudioSamplerate);
            
            if (mediaInfo.u32AudioChannel <= 0 || mediaInfo.u32AudioChannel > 2) {
                mediaInfo.u32AudioChannel = 1;
            }
            
            [reader recvMediaInfo:&mediaInfo];
        }
    }
    
    return 0;
}

@implementation PlayerReader

+ (void)startUp {
    DecodeRegiestAll();
}

#pragma mark - init

- (id)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        
        //Active Videoo
       
        // The dynamic way is to use the pthread_mutex_init() function to initialize the mutex
        pthread_mutex_init(&mutexVideoFrame, 0);
        pthread_mutex_init(&mutexAudioFrame, 0);
        
        pthread_mutex_init(&mutexRecordVideoFrame, 0);
        pthread_mutex_init(&mutexRecordAudioFrame, 0);
        
        pthread_mutex_init(&mutexCloseAudio, 0);
        pthread_mutex_init(&mutexCloseVideo, 0);
        
        pthread_mutex_init(&mutexInit, 0);
        pthread_mutex_init(&mutexStop, 0);
        
        _videoDecHandle = NULL;
        _audioDecHandle = NULL;
        
        self.url = url;
        
        // Initialize the hard decoder
        [RTSPUnit initDefault];
        _hwDec = [[HWVideoDecoder alloc] initWithDelegate:self];
    }
    
    return self;
}

#pragma mark - public method

- (void)start {
    
    if (self.url.length == 0) {
        return;
    }
    
    mNewestStample = 0;
    _lastVideoFramePosition = 0;
    _running = YES;
    
    self.videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(videoThreadFunc) object:nil];
    [self.videoThread start];
    
}

- (void)stop {
    pthread_mutex_lock(&mutexStop);
    
    if (!_running) {
        pthread_mutex_unlock(&mutexStop);
        return;
    }
    
    if (rtspHandle != NULL) {
        EasyRTSP_SetCallback(rtspHandle, NULL);
        EasyRTSP_CloseStream(rtspHandle);// Close network stream
    }
    
    mNewestStample = 0;
    _running = false;
    [self.videoThread cancel];
    [self.audioThread cancel];
    
    pthread_mutex_unlock(&mutexStop);
}

#pragma mark - dealloc

- (void)dealloc {
    
    [self stop];
    
    [self removeVideoFrameSet];
    [self removeAudioFrameSet];
    [self removeRecordFrameSet];
    
    // Unregister mutex
    pthread_mutex_destroy(&mutexVideoFrame);
    pthread_mutex_destroy(&mutexAudioFrame);
    pthread_mutex_destroy(&mutexInit);
    pthread_mutex_destroy(&mutexRecordVideoFrame);
    pthread_mutex_destroy(&mutexRecordAudioFrame);
    
    pthread_mutex_destroy(&mutexCloseVideo);
    pthread_mutex_destroy(&mutexCloseAudio);
    pthread_mutex_destroy(&mutexStop);
}

#pragma mark -  Thread method GCD

- (void) initRtspHandle {
    // ------------ Lock mutexInit ------------
    pthread_mutex_lock(&mutexInit);
    if (rtspHandle == NULL) {
        int ret = EasyRTSP_Init(&rtspHandle);
        if (ret != 0) {
//            NSLog(@"EasyRTSP_Init err %d", ret);
        } else {
            /* Set data callback */
            EasyRTSP_SetCallback(rtspHandle, RTSPDataCallBack);
            
            /* Open network stream */
            ret = EasyRTSP_OpenStream(rtspHandle,
                                      1,
                                      (char *)[self.url UTF8String],
                                      self.transportMode,
                                      EASY_SDK_VIDEO_FRAME_FLAG | EASY_SDK_AUDIO_FRAME_FLAG,// video frame marker | audio frame marker
                                      0,
                                      0,
                                      (__bridge void *)self,
                                      1000,     // 1000 means long connection, that is, if the network is disconnected, it will automatically reconnect, and other values ​​are the number of connections
                                      0,        // The default is 0, that is, the callback outputs the complete frame, if it is 1, the RTP packet is outpu
                                      self.sendOption,// 0x00: Do not send heartbeat 0x01: OPTIONS 0x02: GET_PARAMETER
                                      3);       // 0 => 3
//            NSLog(@"EasyRTSP_OpenStream ret = %d", ret);
        }
    }
    pthread_mutex_unlock(&mutexInit);
    // ------------ Unlock mutexInit ------------
}

- (void)videoThreadFunc {
    // During playback, the thread keeps running
    while (_running) {
        [self initRtspHandle];
        
        // ------------ LockmutexVideoFrame ------------
        pthread_mutex_lock(&mutexVideoFrame);
        
        int count = (int) videoFrameSet.size();
        if (count == 0) {
            pthread_mutex_unlock(&mutexVideoFrame);
            usleep(5 * 1000);
            continue;
        }
        
        FrameInfo *frame = *(videoFrameSet.begin());
        videoFrameSet.erase(videoFrameSet.begin());// erase()
        
        lastFrameStampUs = frame->timeStamp;
        
        pthread_mutex_unlock(&mutexVideoFrame);
        // ------------ unlockmutexVideoFrame ------------
        
        // The resolution of the video has changed, you need to re-initialize the decoder
        BOOL isInit = NO;
        if (frame->type == EASY_SDK_VIDEO_FRAME_I && (self.lastWidth != frame->width || self.lastHeight != frame->height)) {// Type Video Frame Width Height
            isInit = YES;
            
            self.lastWidth = frame->width;
            self.lastHeight = frame->height;
        }
        
        if (self.useHWDecoder) {
            if (hwSleepTime > 0) {
//                usleep((unsigned int) hwSleepTime);
            }
            
//            decodeBegin = (long) [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;// milisecon giây
//            [_hwDec decodeVideoData:frame->pBuf len:frame->frameLen isInit:isInit];
//        } else {
            decodeBegin = (long) [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000;// milisecon giây
            
            [self decodeVideoFrame:frame isInit:isInit];
            
            // Decode load spend when time out put
            long decodeSpend = (long) [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000 - decodeBegin;
            
            if (previousStampUs != 0) {
                long sleepTime = (frame->timeStamp - previousStampUs - decodeSpend) * 1000;
                if (sleepTime > 100000) {
//                    NSLog(@"sleep time.too long:%ld", sleepTime);
                    sleepTime = 100000;
                }
                
                if (sleepTime > 0) {
                    sleepTime %= 100000;
                    
                    // Set the cached timestamp
                    long cache = (mNewestStample - frame->timeStamp) * 1000;
                    
                    sleepTime = [self fixSleepTime:sleepTime totalTimestampDifferUs:cache delayUs:50000];
                    
//                    // usleep The function suspends the process for a period of time, in microseconds (millionths of a second);
//                    usleep((unsigned int) sleepTime);
                }
            }
            
            previousStampUs = frame->timeStamp;
        }
        
        delete []frame->pBuf;
        delete frame;
    }
    
    [self removeVideoFrameSet];
    
    pthread_mutex_lock(&mutexCloseVideo);
    if (_videoDecHandle != NULL) {
        DecodeClose(_videoDecHandle);
        _videoDecHandle = NULL;
    }
    pthread_mutex_unlock(&mutexCloseVideo);
    
    if (self.useHWDecoder) {
        pthread_mutex_lock(&mutexCloseVideo);
        [_hwDec closeDecoder];
        pthread_mutex_unlock(&mutexCloseVideo);
    }
}

#pragma mark - Decode video frame

- (void)decodeVideoFrame:(FrameInfo *)video isInit:(BOOL)isInit {
    if (_videoDecHandle == NULL || isInit) {
        DEC_CREATE_PARAM param;
        param.nMaxImgWidth = video->width;
        param.nMaxImgHeight = video->height;
        param.coderID = CODER_H264;
        param.method = IDM_SW;
        param.avCodecID = self.codecID;
        
        _videoDecHandle = DecodeCreate(&param);
    }
    
    if (_videoDecHandle == NULL) {
        return;
    }
    
    DEC_DECODE_PARAM param;
    param.pStream = video->pBuf;
    param.nLen = video->frameLen;
    param.need_sps_head = false;
    
    DVDVideoPicture picture;
    memset(&picture, 0, sizeof(picture));
    picture.iDisplayWidth = video->width;
    picture.iDisplayHeight = video->height;
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    int nRet = DecodeVideo(_videoDecHandle, &param, &picture);
    
    NSTimeInterval decodeInterval = 1000.0 * ([NSDate timeIntervalSinceReferenceDate] - now);
    
    if (nRet) {
        @autoreleasepool {
            if (_lastVideoFramePosition == 0) {
                _lastVideoFramePosition = video->timeStamp;
            }
            
            CGFloat duration = (video->timeStamp - _lastVideoFramePosition - decodeInterval) / 1000.0;
            if (duration >= 1.0 || duration <= -1.0) {
                duration = 0.02;
            }
            
            // First display：KxVideoFrameYUV
            KxVideoFrameYUV *frame = [KxVideoFrameYUV handleVideoFrame:param.pFrame videoCodecCtx:param.pCodecCtx];
            frame.width = param.nOutWidth;
            frame.height = param.nOutHeight;
            frame.position = video->timeStamp / 1000.0;
            frame.duration = duration;
            
//            // The second display method：KxVideoFrameRGB
//            KxVideoFrameRGB *frame = [[KxVideoFrameRGB alloc] init];
//            frame.width = param.nOutWidth;
//            frame.height = param.nOutHeight;
//            frame.linesize = param.nOutWidth * 3;
//            frame.hasAlpha = NO;
//            frame.rgb = [NSData dataWithBytes:param.pImgRGB length:param.nLineSize * param.nOutHeight];
//            frame.position = video->timeStamp / 1000.0;
//            frame.duration = duration;

            _lastVideoFramePosition = video->timeStamp;
            
            if (self.frameOutputBlock) {
                // First display：KxVideoFrameYUV
                self.frameOutputBlock(frame, (Easy_U32)(frame.luma.length + frame.chromaB.length + frame.chromaR.length));
                
//                // The second display method：KxVideoFrameRGB
//                self.frameOutputBlock(frame, (Easy_U32)frame.rgb.length);
            }
        }
    }
}

#pragma mark - Decode audio frame

- (void)removeVideoFrameSet {
    // ------------------ frameSet ------------------
    pthread_mutex_lock(&mutexVideoFrame);
    
    std::set<FrameInfo *>::iterator videoItem = videoFrameSet.begin();
    while (videoItem != videoFrameSet.end()) {
        FrameInfo *frameInfo = *videoItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        
        videoItem++;   // Very important, actively move the pointer forward
    }
    videoFrameSet.clear();
    
    pthread_mutex_unlock(&mutexVideoFrame);
}

- (void)removeAudioFrameSet {
    pthread_mutex_lock(&mutexAudioFrame);
    
    std::set<FrameInfo *>::iterator it = audioFrameSet.begin();
    while (it != audioFrameSet.end()) {
        FrameInfo *frameInfo = *it;
        delete []frameInfo->pBuf;
        delete frameInfo;
        
        it++;   //count frame when tăng buffer
    }
    audioFrameSet.clear();
    
    pthread_mutex_unlock(&mutexAudioFrame);
}

- (void) removeRecordFrameSet {
    // ------------------ recordVideoFrameSet ------------------
    pthread_mutex_lock(&mutexRecordVideoFrame);
    std::set<FrameInfo *>::iterator videoItem = recordVideoFrameSet.begin();
    while (videoItem != recordVideoFrameSet.end()) {
        FrameInfo *frameInfo = *videoItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        videoItem++;
    }
    recordVideoFrameSet.clear();
    pthread_mutex_unlock(&mutexRecordVideoFrame);
    
    // ------------------ recordAudioFrameSet ------------------
    pthread_mutex_lock(&mutexRecordAudioFrame);
    std::set<FrameInfo *>::iterator audioItem = recordAudioFrameSet.begin();
    while (audioItem != recordAudioFrameSet.end()) {
        FrameInfo *frameInfo = *audioItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        audioItem++;
    }
    recordAudioFrameSet.clear();
    pthread_mutex_unlock(&mutexRecordAudioFrame);
}

#pragma mark - Video

/**
 Register the callback function of av_read_frame
 
 @param opaque URLContext
 @param buf buf
 @param buf_size buf_size
 @return 0
 */
int read_video_packet(void *opaque, uint8_t *buf, int buf_size) {
    pthread_mutex_lock(&mutexRecordVideoFrame);
    
    int count = (int) recordVideoFrameSet.size();
    if (count == 0) {
        pthread_mutex_unlock(&mutexRecordVideoFrame);
        return 0;
    }
    
    FrameInfo *frame = *(recordVideoFrameSet.begin());
    recordVideoFrameSet.erase(recordVideoFrameSet.begin());
    
    pthread_mutex_unlock(&mutexRecordVideoFrame);
    
    int frameLen = frame->frameLen;
    memcpy(buf, frame->pBuf, frameLen);
    
    delete []frame->pBuf;
    delete frame;
    
    return frameLen;
}

/**
 av_read_frame
 
 @param opaque URLContex
 @param buf buf
 @param buf_size buf_size
 @return 0
 */
int read_audio_packet(void *opaque, uint8_t *buf, int buf_size) {
    pthread_mutex_lock(&mutexRecordAudioFrame);
    
    int count = (int) recordAudioFrameSet.size();
    if (count == 0) {
        pthread_mutex_unlock(&mutexRecordAudioFrame);
        return 0;
    }
    
    FrameInfo *frame = *(recordAudioFrameSet.begin());
    recordAudioFrameSet.erase(recordAudioFrameSet.begin());
    
    pthread_mutex_unlock(&mutexRecordAudioFrame);
    
    int frameLen = frame->frameLen;
    memcpy(buf, frame->pBuf, frameLen);
    
    delete []frame->pBuf;
    delete frame;
    
    return frameLen;
}

#pragma mark - private method

// Get media type
- (void)recvMediaInfo:(EASY_MEDIA_INFO_T *)info {
    _mediaInfo = *info;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fetchMediaInfoSuccessBlock) {
            self.fetchMediaInfoSuccessBlock();
        }
    });
}

- (void)pushFrame:(char *)pBuf frameInfo:(EASY_FRAME_INFO *)info type:(int)type {
    if (!_running || pBuf == NULL || info->length == 0) {
        return;
    }
    
    FrameInfo *frameInfo = (FrameInfo *)malloc(sizeof(FrameInfo));
    frameInfo->type = type;
    frameInfo->frameLen = info->length;
    frameInfo->pBuf = new unsigned char[info->length];
    frameInfo->width = info->width;
    frameInfo->height = info->height;
    // Milliseconds (1 second = 1000 milliseconds 1 second = 1000000 microseconds)
    frameInfo->timeStamp = info->timestamp_sec * 1000 + info->timestamp_usec / 1000.0;
    mNewestStample = frameInfo->timeStamp;
    
    memcpy(frameInfo->pBuf, pBuf, info->length);
    
    // Sort by timestamp
    if (type == EASY_SDK_AUDIO_FRAME_FLAG) {
        pthread_mutex_lock(&mutexAudioFrame);    // Lock
        audioFrameSet.insert(frameInfo);
        pthread_mutex_unlock(&mutexAudioFrame);  // unlock
    } else {
        pthread_mutex_lock(&mutexVideoFrame);    // lock
        videoFrameSet.insert(frameInfo);
        pthread_mutex_unlock(&mutexVideoFrame);  // unlock
    }
    
    // Video: Save the content of the video
//    if (_recordFilePath) {
//
//        if (isKeyFrame == 0) {
//            if (info->type == EASY_SDK_VIDEO_FRAME_I) {// Video frame type
//                isKeyFrame = 1;
//
//                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
//                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, NULL);
//                dispatch_after(time, queue, ^{
//                    // Start recording
//                    *stopRecord = 0;
//                    muxer([self.recordFilePath UTF8String], stopRecord, read_video_packet, read_audio_packet);
//                });
//            }
//        }
//
//        if (isKeyFrame == 1) {
//            FrameInfo *frame = (FrameInfo *)malloc(sizeof(FrameInfo));
//            frame->type = type;
//            frame->frameLen = info->length;
//            frame->pBuf = new unsigned char[info->length];
//            frame->width = info->width;
//            frame->height = info->height;
//            frame->timeStamp = info->timestamp_sec * 1000 + info->timestamp_usec / 1000.0;
//
//            memcpy(frame->pBuf, pBuf, info->length);
//
//            if (type == EASY_SDK_AUDIO_FRAME_FLAG) {
//                pthread_mutex_lock(&mutexRecordAudioFrame);    // Lock
//                recordAudioFrameSet.insert(frame);// Sort by timestamp
//                pthread_mutex_unlock(&mutexRecordAudioFrame);  // Unlock
//            }
//
//            if (type == EASY_SDK_VIDEO_FRAME_FLAG &&    // EASY_SDK_VIDEO_FRAME_FLAG
//                info->codec == EASY_SDK_VIDEO_CODEC_H264) { // H264 encode
//                pthread_mutex_lock(&mutexRecordVideoFrame);    // Lock
//                recordVideoFrameSet.insert(frame);// Sort by timestamp
//                pthread_mutex_unlock(&mutexRecordVideoFrame);  // Unlock
//            }
//        }
//    }
}

#pragma mark - HWVideoDecoderDelegate

-(void) getDecodePictureData:(KxVideoFrame *)frame  length:(unsigned int) length {
    if (self.frameOutputBlock) {
        frame.position = lastFrameStampUs / 1000.0;
        self.frameOutputBlock(frame, length);
    }
    
    // Timer start when play beging video
    
    long decodeSpend = (long) [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970] * 1000 - decodeBegin;
    
    if (previousStampUs != 0) {
        long sleepTime = (lastFrameStampUs - previousStampUs - decodeSpend) * 1000;
        if (sleepTime > 100000) {
            //NSLog(@"sleep time.too long:%ld", sleepTime);
            sleepTime = 100000;
        }
        
        if (sleepTime > 0) {
            sleepTime %= 100000;
            
            // Set the catched timestamp
            long cache = (mNewestStample - lastFrameStampUs) * 1000;
            
            hwSleepTime = [self fixSleepTime:sleepTime totalTimestampDifferUs:cache delayUs:50000];
        }
    }
    
    previousStampUs = lastFrameStampUs;
}

-(void) getDecodePixelData:(CVImageBufferRef)frame {
//    NSLog(@"--> %@", frame);
}

#pragma mark - getter/setter

- (EASY_MEDIA_INFO_T)mediaInfo {
    return _mediaInfo;
}


/**
 @param sleepTimeUs The difference between the current frame timestamp and the previous frame timestamp and remove the decoding time (unit is microseconds)
  @param total The length of time currently cached in microseconds
  @param delayUs The total size of the cache for personal settings:
  For hard decoding, the default buffer is set to 100,000 microseconds, and for soft decoding, it is set to 50,000 microseconds.
  If you want to reduce the delay to the limit, adjust the third parameter to 0, so that you don't want the upper layer to cache the data, and decode it and display it on the screen as soon as possible.
  @return delayed timestamp
 */
- (float) fixSleepTime:(float)sleepTimeUs totalTimestampDifferUs:(float)total delayUs:(float)delayUs {
    if (total < 0) {
        //NSLog(@"totalTimestampDifferUs is:%f, this should not be happen.", total);
        total = 0;
    }
    
    double dValue = ((double) (delayUs - total)) / 1000000;
    double radio = exp(dValue);
    double r = sleepTimeUs * radio + 0.5f;
    
    //NSLog(@"===>> %ff, %f, %f->%f microseconds", sleepTimeUs, total, delayUs, r);
    
    return (long) r;
}

@end
