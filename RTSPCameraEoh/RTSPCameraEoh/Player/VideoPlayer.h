
#import <UIKit/UIKit.h>
#import "PlayerReader.h"
#import <CoreCameraEoh/FrameSizeModel.h>

typedef enum {
    Stopped,    // stop
    Suspend,    // pause
    Connecting, // connecting
    Rendering,  // playing
}IVideoStatus;

@protocol VideoPlayerDelegate;

@interface VideoPlayer : UIView<UIGestureRecognizerDelegate>

@property (nonatomic, weak) UIView *container;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *landspaceButton;  // full screen button


@property (nonatomic, weak) id<VideoPlayerDelegate> delegate;

// streaming address
@property (nonatomic, copy) NSString *url;
// thumnail url image
@property (nonatomic, copy) NSString *urlThumnail;
//size width - height
@property (nonatomic, assign) CGFloat widthPlayer;
@property (nonatomic, assign) CGFloat heightPlayer;
 
@property (nonatomic, strong) FrameSizeModel *frameModel;


// Transfer Protocol：TCP/UDP(EASY_RTP_CONNECT_TYPE：0x01，0x02)
@property (nonatomic, assign) EASY_RTP_CONNECT_TYPE transportMode;
// Send keep-alive packets (heartbeat: 0x00 don't send heartbeat, 0x01 OPTIONS, 0x02 GET_PARAMETER)
@property (nonatomic, assign) int sendOption;


@property (nonatomic, strong) PlayerReader *reader;
@property (nonatomic, assign) IVideoStatus videoStatus;

@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL useHWDecoder;        // Whether to enable hard solution
@property (nonatomic, assign) BOOL audioPlaying;        // Autoplay audio
@property (nonatomic, assign) BOOL showAllRegon;        //
@property (nonatomic, assign) BOOL showActiveStatus;    //

- (void)beginTransform;
- (void)endTransform;

- (void) hideBtnView;
- (void) changeHorizontalScreen:(BOOL) horizontal;

// ----------------- playback controls-----------------
- (void)stopAudio;
- (void)startPlay;
- (void)stopPlay;
- (void)flush;

+ (id)init : (CGFloat) widthVD;

@end

@protocol VideoPlayerDelegate <NSObject>

@optional

- (void)videoViewDidiUpdateStream:(VideoPlayer *)view;
- (void)videoViewBeginActive:(VideoPlayer *)view;

// Full screen (landscape)
- (void)videoViewWillAnimateToFullScreen:(VideoPlayer *)view;
// vertical screen
- (void)videoViewWillAnimateToNomarl:(VideoPlayer *)view;

// Connect a video source
- (void)videoViewWillTryToConnect:(VideoPlayer *)view;

- (void) back;

@end
