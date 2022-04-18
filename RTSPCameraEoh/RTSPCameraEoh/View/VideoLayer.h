
#import <UIKit/UIKit.h>
#import "VideoPlayer.h"
#import <CoreCameraEoh/URLModel.h>

typedef NS_OPTIONS(NSInteger, IVideoLayout){
    IVL_One = 1,
    IVL_Four = 4,
    IVL_Eight = 8,
    IVL_Nine = 9,
    IVL_Twelve = 12,
    IVL_SixTen = 16
   
};

@protocol VideoLayerDelegate;

@interface VideoLayer : UIView

@property (nonatomic, weak) id<VideoLayerDelegate> delegate;

@property (nonatomic, retain) NSMutableArray *resuedViews;
@property (nonatomic, strong) VideoPlayer *activeView;
@property (nonatomic, assign) IVideoLayout layout;

- (VideoPlayer *) nextAvailableContainer;

// Restart playback of all videos
- (void) restore;

// Stop playback of all videos
- (void) stopAll;

// Start playback of all videos
- (void) startAll:(NSArray<URLModel *> *)urlModels;

// Set up split screen
- (void)setLayout:(IVideoLayout)layout currentURL:(NSString *)url URLs:(NSArray<URLModel *> *)urlModels;

// hide bottom button
- (void) hideBtnView;

// landscape rotate
- (void) changeHorizontalScreen:(BOOL) horizontal;

@end

@protocol VideoLayerDelegate <NSObject>

@optional
- (void) activeViewDidiUpdateStream:(VideoPlayer *)view;
- (void) didSelectVideoView:(VideoPlayer *)view;
- (void) activeVideoViewRendStatusChanged:(VideoPlayer *)view;

- (void) videoViewWillAnimateToFullScreen:(VideoPlayer *)view;
- (void) videoViewWillAnimateToNomarl:(VideoPlayer *)view;

// Add new video source
- (void) videoViewWillAddNewRes:(VideoPlayer *)view index:(int)index;

- (void) back;

@end
