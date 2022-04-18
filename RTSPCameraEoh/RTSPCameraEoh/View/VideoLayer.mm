
#import "VideoLayer.h"
#import "Masonry.h"

#define kContentInset 1

@interface VideoLayer() <VideoPlayerDelegate> {
    VideoPlayer *_activeView;
    
    VideoPlayer *primaryView;
    CGRect curPrimaryRect;
    
    BOOL startAnimate;
    BOOL willAnimateToPrimary;
}

@end

@implementation VideoLayer

#pragma mark - init

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        
        _resuedViews = [[NSMutableArray alloc] init];
    }
    
    return self;
}

#pragma mark - public method

- (VideoPlayer *)nextAvailableContainer {
    int nIndex = -1;
    
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        
        if (videoView.videoStatus == Stopped && videoView.active) {
            nIndex = i;
            break;
        }
    }
    
    VideoPlayer *videoView = nil;
    
    if (nIndex >= 0) {
        videoView = [_resuedViews objectAtIndex:nIndex];
    } else {
        videoView = [_resuedViews firstObject];
    }
    
    return videoView;
}

- (void)stopAll {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        [videoView stopPlay];
    }
}

- (void)startAll:(NSArray<URLModel *> *)urlModels {
    
    for (int i = 0; i < [_resuedViews count]; i++) {
        URLModel *model = urlModels[i];
        
        if (!model.url) {
            continue;
        }
        
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        videoView.url = model.url;
        videoView.transportMode = model.transportMode;
        videoView.sendOption = model.sendOption;
        
        [videoView stopPlay];
        
//        [videoView startPlay];
    }
//    [self stopAll];
}

- (void)restore {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        
        if (videoView.videoStatus == Stopped) {
//            [videoView startPlay];
            [videoView stopPlay];
        }
    }
}

#pragma mark - setter

- (void)setActiveView:(VideoPlayer *)activeView {
    if (_activeView != activeView) {
        _activeView.active = NO;
        _activeView = activeView;
        _activeView.active = YES;
    }
}

- (void)setLayout:(IVideoLayout)layout currentURL:(NSString *)url URLs:(NSArray<URLModel *> *)urlModels {
    //    if (_layout == layout) {
    //        return;
    //    }
    
    _layout = layout;
    
    NSInteger diff = _layout - [_resuedViews count];
    int count = (int)[_resuedViews count];
    
    for (int i = 0; i < diff; i++) {
        VideoPlayer *videoView = [[VideoPlayer alloc] init];
        videoView.delegate = self;
        [_resuedViews addObject:videoView];
        
        videoView.addButton.tag = i + count;
        [videoView.addButton addTarget:self action:@selector(addCameraRes:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    for (int i = (int)layout; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        if (videoView.videoStatus >= Connecting) {
            [videoView stopPlay];
            videoView.url = nil;
        }
    }
    
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        if (videoView.superview != nil) {
            [videoView removeFromSuperview];
        }
    }
    
    BOOL hasActiveView = NO;
    VideoPlayer *topView = nil;
    
    NSInteger rowCount = [self rowCount];       // Number of lines spilt
    NSInteger columnCount = _layout / rowCount; // Number of columns
    
    CGFloat itemH, itemW;
    if (self.frame.size.height > self.frame.size.width) {
        itemH = self.frame.size.width / rowCount;
        itemW = self.frame.size.height / rowCount;
    } else {
        itemH = self.frame.size.height / rowCount;
        itemW = self.frame.size.width / rowCount;
    }
    
//    itemW = itemW ;
//    itemH = itemW * 9.0 / 16.0;
    
//
//    NSLog(@"itemH = %0.2f  itemW = %0.2f  rowCount  = %d self.frame.size.width  = %0.2f   self.frame.size.height  = %0.2f columnCount = %d ",itemH,itemW,rowCount,self.frame.size.width, self.frame.size.height);
    
    
    for (int i = 0; i < rowCount; i++) {
        VideoPlayer *leftView = nil;
        NSMutableArray *viewsOneRow = [[NSMutableArray alloc] init];
        
        for (int j = 0; j < columnCount; j++) {
            VideoPlayer *view = [_resuedViews objectAtIndex:(i * columnCount + j)];
            view.landspaceButton.hidden = YES;
            view.urlThumnail = @"https://eoh-gateway-backend.eoh.io/image-asset.jpeg";
            [viewsOneRow addObject:view];
            [self addSubview:view];
            [view mas_updateConstraints:^(MASConstraintMaker *make) {
                make.size.equalTo(CGSizeMake(itemW, itemH));
            }];
            
            if (view.active) {
                hasActiveView = YES;
            }
            
            if (leftView == nil) {
                [view mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(@0);
                }];
                
                if (topView == nil) {
                    [view mas_updateConstraints:^(MASConstraintMaker *make) {
                        make.top.equalTo(@0);
                    }];
                } else {
                    [view mas_makeConstraints:^(MASConstraintMaker *make) {
                        make.top.equalTo(topView.mas_bottom).offset(kContentInset);
                    }];
                }
                
                if (i == rowCount - 1) {
                    [view mas_makeConstraints:^(MASConstraintMaker *make) {
                        make.bottom.equalTo(@0);
                    }];
                }
                
                topView = view;
            } else {
                [view mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(leftView.mas_right).offset(kContentInset);
                    make.top.equalTo(topView.mas_top);
                }];
            }
            
            if (j == columnCount - 1) {
                [view mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(@0);
                }];
            }
            
            leftView = view;
        }
        
        leftView = nil;
    }
    
    //    if (!hasActiveView) {
    //        for (VideoView *view in _resuedViews) {
    //            view.active = NO;
    //        }
    //
    //        VideoView *view = [_resuedViews firstObject];
    //        [self videoViewBeginActive:view];
    //    }
    
    if (url) {
        // When full screen, it needs to be set to 1 split screen, and set the current VideoView as the first View
        VideoPlayer *view = [_resuedViews firstObject];
        view.url = url;
        [self videoViewBeginActive:view];
    } else {
        [self startAll:urlModels];
    }
}

- (void) hideBtnView {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        [videoView hideBtnView];
    }
}

- (void) changeHorizontalScreen:(BOOL) horizontal {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoPlayer *videoView = [_resuedViews objectAtIndex:i];
        [videoView changeHorizontalScreen:horizontal];
    }
}

#pragma mark - Click Event

- (void)addCameraRes:(id)sender {
    UIButton *button = (UIButton *)sender;
    int index = (int)button.tag;
    
    VideoPlayer *view = (VideoPlayer *)button.superview;
    
    [self videoViewBeginActive:view];
    [self.delegate videoViewWillAddNewRes:view index:index];
}

#pragma mark - Private Method

- (int)rowCount {
    return (int)sqrt(self.layout);
}

- (CGFloat)cellWidth {
    CGSize size = [UIScreen mainScreen].bounds.size;
    return (size.width - kContentInset * [self insertCount]) / ([self insertCount] + 1);
}

- (CGFloat)cellHeight {
    return (self.frame.size.height - kContentInset * [self insertCount]) / ([self insertCount] + 1);
}

- (NSInteger)insertCount {
    NSInteger insetCount = 0;
    switch (self.layout) {
        case IVL_Four:
            insetCount = 1;
            break;
        case IVL_Nine:
            insetCount = 2;
            break;
        default:
            break;
    }
    
    return insetCount;
}

#pragma mark - VideoViewDelegate

- (void)videoViewBeginActive:(VideoPlayer *)view {
    [self setActiveView:view];
    [self.delegate didSelectVideoView:view];
}

- (void)videoViewWillAnimateToFullScreen:(VideoPlayer *)view {
    [self.delegate videoViewWillAnimateToFullScreen:view];
}

- (void)videoViewWillAnimateToNomarl:(VideoPlayer *)view {
    [self.delegate videoViewWillAnimateToNomarl:view];
}

- (void)videoView:(VideoPlayer *)view response:(int)error {
    if (view == _activeView) {
        [self.delegate activeVideoViewRendStatusChanged:view];
    }
}

- (void)videoView:(VideoPlayer *)view connectionBreak:(int)error {
    if (view == _activeView) {
        [self.delegate activeVideoViewRendStatusChanged:_activeView];
    }
}

- (void)videoViewWillTryToConnect:(VideoPlayer *)view {
    if (view == _activeView) {
        [self.delegate activeVideoViewRendStatusChanged:_activeView];
    }
}

- (void)videoViewDidiUpdateStream:(VideoPlayer *)view {
    if (view == _activeView) {
        [self.delegate activeViewDidiUpdateStream:_activeView];
    }
}

- (void) back {
    if (self.delegate) {
        [self.delegate back];
    }
}

#pragma mark - dealloc

- (void)dealloc {
    
}

#pragma mark - override

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (startAnimate) {
        if (willAnimateToPrimary) {
            primaryView.frame = self.bounds;
        } else {
            primaryView.frame = primaryView.container.frame;
        }
        
        startAnimate = NO;
    }
}

@end
