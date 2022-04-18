//
//  GirdPlayerViewController.m
//  RTSPCameraEoh
//
//  Created by a on 4/13/22.
//

#import "GirdPlayerViewController.h"
#import "UIColor+HexColor.h"
#import "VideoLayer.h"
#import "Masonry.h"
#import "CoreCameraEoh/NSUserDefaultsUnit.h"


@interface GirdPlayerViewController ()<VideoLayerDelegate> {
    
    BOOL crossScreen;   // Whether horizontal screen
    BOOL fullScreen;    // full screen
    BOOL firstFullScreen;   // Full screen or landscape first
}

@property (nonatomic, retain) NSMutableArray *urlModels;
@property (nonatomic, strong) VideoLayer *panel;

@property (nonatomic, assign) BOOL statusBarHidden;
@property (nonatomic, assign) CGRect panelFrame;

@property (nonatomic, retain) NSArray *arrayUrls;


@end

@implementation GirdPlayerViewController


- (instancetype) initWithStoryboard {
    return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"GirdPlayerViewController"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.statusBarHidden = NO;
    [self prefersStatusBarHidden];
    
    _arrayUrls = @[
        @"rtsp://admin:hd543211@203.205.32.86:10556/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10555/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10557/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10554/ISAPI/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10558/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10556/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10555/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10557/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10554/ISAPI/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10558/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10558/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10556/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10555/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10557/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10554/ISAPI/Streaming/Channels/101/",
        @"rtsp://admin:hd543211@203.205.32.86:10558/Streaming/Channels/101/",
    ];
    
    
    // Up to 9 split screens, up to 9 URLs
    _urlModels = [[NSMutableArray alloc] init];
    for (int i = 0; i < _arrayUrls.count; i++) {
        [_urlModels addObject:[[URLModel alloc] initDefault]];
    }
    
    //init
    for (int i = 0; i < _arrayUrls.count; i++) {
        URLModel *model = [[URLModel alloc] initDefault];
        model.url = [_arrayUrls objectAtIndex: i] ;  //@"rtsp://admin:hd543211@203.205.32.86:10556/Streaming/Channels/101/";
        model.urlThumnail = @"https://eoh-gateway-backend.eoh.io/image-asset.jpeg";
        [self.urlModels replaceObjectAtIndex:i withObject:model];
        [self.panel startAll:self.urlModels];
    }
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >=7.0) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.navigationItem.title = @"Gird Player";
    self.view.backgroundColor = [UIColor colorFromHex:0xfefefe];
    
    
    self.panelFrame = CGRectMake(0, 70, ScreenWidth, ScreenWidth);
    self.panel = [[VideoLayer alloc] initWithFrame:self.panelFrame];
    self.panel.delegate = self;
    [self.view addSubview:self.panel];
    [self.panel hideBtnView];
    [self.panel setLayout:IVL_SixTen currentURL:nil URLs:_urlModels];
    [self regestAppStatusNotification];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self normalScreenWithDuration:0];// Return to vertical screen
    
    [self.panel stopAll];
}

- (void)dealloc {
    [self removeAppStutusNotification];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

#pragma mark - Horizontal and vertical screen settings

- (void) normalScreenWithDuration:(NSTimeInterval)duration {
    crossScreen = NO;
    fullScreen = NO;
    
    [self layoutChanged:nil];
    
    [UIView animateWithDuration:duration animations:^{
        [self.navigationController setNavigationBarHidden:NO];
        
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        self.statusBarHidden = YES;
        [self prefersStatusBarHidden];
        
        self.panel.frame = self.panelFrame;
        self.panel.transform = CGAffineTransformIdentity;
        
        [self layoutChanged:nil];
    }];
    
}

#pragma mark - click event

- (void)layoutChanged:(id)sender {
        [self.panel setLayout:IVL_SixTen currentURL:nil URLs:_urlModels];
}

- (void)goBack:(id)sender {
    [self.panel stopAll];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)enterBackground {
    [self.panel stopAll];
}

#pragma mark - VideoLayerDelegate

- (void)activeViewDidiUpdateStream:(VideoPlayer *)view {
    
}

- (void)didSelectVideoView:(VideoPlayer *)view {
    BOOL enable = view.videoStatus == Rendering;
    NSLog(@"%d", enable);
}

- (void)activeVideoViewRendStatusChanged:(VideoPlayer *)view {
    
}

- (void)videoViewWillAddNewRes:(VideoPlayer *)view index:(int)index {
    [self normalScreenWithDuration:0];// Return to vertical screen
}


- (void)videoViewWillAnimateToNomarl:(VideoPlayer *)view {
    if (fullScreen) {
        if (firstFullScreen) {
            // full screen -> portrait
            [self normalScreenWithDuration:0.5];
        } else {
            // full screen -> landscape
//            segment.selectedSegmentIndex = segment.selectedSegmentIndex;
            [self layoutChanged:nil];
        }
    }
    
    fullScreen = NO;
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

#pragma mark - Notification impletement

- (void)becomeActive {
    [self.panel restore];
}

#pragma mark - StatusBar

- (BOOL)prefersStatusBarHidden {
    return self.statusBarHidden;
}


@end
