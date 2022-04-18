//
//  ViewController.m
//  RTSPCameraEoh
//
//  Created by a on 4/12/22.
//

#import "PlayerViewController.h"
#import "VideoPlayer.h"
#import <CoreCameraEoh/URLModel.h>
#import <CoreCameraEoh/FrameSizeModel.h>
#import "Masonry.h"
#import "UIColor+HexColor.h"

#define RECT_MAKE_VIDEO CGRectMake(0, 0, 1, 1)

@interface PlayerViewController ()

  @property (nonatomic, strong) VideoPlayer *videoPlayer;

@end

@implementation PlayerViewController

- (instancetype) initWithStoryboard {
    return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"PlayerViewController"];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Player";
    self.view.backgroundColor = [UIColor colorFromHex:0xfefefe];
    
    _videoPlayer = [[VideoPlayer alloc] initWithFrame:RECT_MAKE_VIDEO];
    _videoPlayer.widthPlayer = ScreenWidth;
    _videoPlayer.url = @"rtsp://admin:hd543211@203.205.32.86:10556/Streaming/Channels/101/";
    _videoPlayer.urlThumnail = @"https://eoh-gateway-backend.eoh.io/image-asset.jpeg";
    [self.view addSubview:_videoPlayer];
    
    //Notifiy KVO
    [self regestAppStatusNotification];
}



- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.videoPlayer stopPlay];
}


- (void)dealloc {
    [self removeAppStutusNotification];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}


#pragma mark - Notification

- (void)regestAppStatusNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(becomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)removeAppStutusNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - Notification Implementation

- (void)becomeActive {
    [self.videoPlayer stopPlay];
}

- (void)enterBackground {
    [self.videoPlayer stopPlay];
}

@end
