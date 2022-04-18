//
//  URLModel.h
//  CameraRTSPEoh
///Users/a/Documents/Project/CameraEoh/CameraRTSPEoh/CameraRTSPEoh/Model/URLModel.h
//  Created by Levu on 2022/03/22.
//

#import "BaseModel.h"
#import "EasyTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface URLModel : BaseModel

@property (nonatomic, copy) NSString *url;  // address stream
@property (nonatomic, copy) NSString *urlThumnail;

// Transfer Protocol: TCP/UDP(EASY_RTP_CONNECT_TYPE：0x01，0x02)
@property (nonatomic, assign) EASY_RTP_CONNECT_TYPE transportMode;

// Send keep-alive packets (heartbeat: 0x00 does not send heartbeats, 0x01 OPTIONS， 0x02 GET_PARAMETER)
@property (nonatomic, assign) int sendOption;

@property (nonatomic, copy) NSString *audienceNumber;// Current number of audio

- (instancetype) initDefault;

@end

NS_ASSUME_NONNULL_END
