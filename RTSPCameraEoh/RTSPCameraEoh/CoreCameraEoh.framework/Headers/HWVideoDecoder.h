//
//  CVPixelVideoDecoder.h
//  iMCU2
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "KxMovieDecoder.h"

typedef enum {
    DEC_264,
    DEC_265,
}DecoderType;

@protocol HWVideoDecoderDelegate;

@interface HWVideoDecoder : NSObject

@property (nonatomic, assign) DecoderType type;
@property (nonatomic, assign) id<HWVideoDecoderDelegate> hwDelegate;

// Initialize the video decoder and set delegate
- (id)initWithDelegate:(id<HWVideoDecoderDelegate>)aDelegate;

// Decode video data
- (int)decodeVideoData:(unsigned char *)pH264Data len:(int)len isInit:(BOOL)isInit;

// Close the decoder and Release declock
- (void)closeDecoder;

@end

@protocol HWVideoDecoderDelegate <NSObject>

-(void) getDecodePictureData:(KxVideoFrame *) frame length:(unsigned int) length;
-(void) getDecodePixelData:(CVImageBufferRef) frame;

@end
