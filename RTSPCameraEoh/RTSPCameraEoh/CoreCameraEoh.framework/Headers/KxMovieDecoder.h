
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

extern NSString * kxmovieErrorDomain;

typedef enum {
    kxMovieErrorNone,
    kxMovieErrorOpenFile,
    kxMovieErrorStreamInfoNotFound,
    kxMovieErrorStreamNotFound,
    kxMovieErrorCodecNotFound,
    kxMovieErrorOpenCodec,
    kxMovieErrorAllocateFrame,
    kxMovieErroSetupScaler,
    kxMovieErroReSampler,
    kxMovieErroUnsupported
} kxMovieError;

typedef enum {
    KxMovieFrameTypeAudio,
    KxMovieFrameTypeVideo,
    KxMovieFrameTypeArtwork,
    KxMovieFrameTypeSubtitle
} KxMovieFrameType;

typedef enum {
    KxVideoFrameFormatRGB,
    KxVideoFrameFormatYUV
} KxVideoFrameFormat;


@interface KxMovieFrame : NSObject

@property (readonly, nonatomic) KxMovieFrameType type;
@property (nonatomic) CGFloat position;
@property (nonatomic) CGFloat duration;

@end


@interface KxAudioFrame : KxMovieFrame

@property (nonatomic, strong) NSData *samples;

@end


@interface KxVideoFrame : KxMovieFrame

@property (readonly, nonatomic) KxVideoFrameFormat format;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;

@end


@interface KxVideoFrameRGB : KxVideoFrame

@property (nonatomic) NSUInteger linesize;
@property (nonatomic, strong) NSData *rgb;
@property (nonatomic) BOOL hasAlpha;

- (UIImage *) asImage;

@end


@interface KxVideoFrameYUV : KxVideoFrame

// Y represents brightness (Luminance or Luma), U and V represent chroma (Chrominance or Chroma)
@property ( nonatomic, strong) NSData *luma;    // Y
@property ( nonatomic, strong) NSData *chromaB; // Cb
@property ( nonatomic, strong) NSData *chromaR; // Cr

+ (instancetype) handleVideoFrame:(AVFrame *)videoFrame videoCodecCtx:(AVCodecContext *)videoCodecCtx;

@end


@interface KxArtworkFrame : KxMovieFrame

@property (readonly, nonatomic, strong) NSData *picture;

- (UIImage *) asImage;

@end


@interface KxSubtitleFrame : KxMovieFrame

@property (readonly, nonatomic, strong) NSString *text;

@end
