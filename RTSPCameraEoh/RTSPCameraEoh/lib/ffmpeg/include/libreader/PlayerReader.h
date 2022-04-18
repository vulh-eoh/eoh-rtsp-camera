//
//  PlayerReader.hpp
//  RTSPCameraEoh
//
//  Created by a on 4/12/22.
//

#import  <Foundation/Foundation.h>
#import  <UIKit/UIKit.h>
#import  "CoreCameraEoh/KxMovieDecoder.h"
#include "CoreCameraEoh/EasyRTSPClientAPI.h"

/**
 Get RTSP stream, de-protocol, de-encapsulate, and then decode audio and video separately
 */
@interface PlayerReader : NSObject

// Streaming address
@property (nonatomic, copy) NSString *url;
// Protocol：TCP/UDP(EASY_RTP_CONNECT_TYPE：0x01，0x02)
@property (nonatomic, assign) EASY_RTP_CONNECT_TYPE transportMode;
// Send Byte：0x00 Option， 0x01 OPTIONS， 0x02 GET_PARAMETER)
@property (nonatomic, assign) int sendOption;

@property (nonatomic, readonly) BOOL running;           // playing

@property (nonatomic, assign) BOOL enableAudio;
@property (nonatomic, assign) BOOL useHWDecoder;        // Whether to enable hard decoding

// Get media type
@property (nonatomic, copy) void (^fetchMediaInfoSuccessBlock)(void);

// Get decoded audio frame/video frame
@property (nonatomic, copy) void (^frameOutputBlock)(KxMovieFrame *frame, unsigned int length);

+ (void)startUp;

- (id)initWithUrl:(NSString *)url;
- (void)start;
- (void)stop;

- (EASY_MEDIA_INFO_T)mediaInfo;

@end

