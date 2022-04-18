
#import "VideoPlayer.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import "UIColor+HexColor.h"
#import "CoreCameraEoh/KxMovieGLView.h"
#import "CoreCameraEoh/PathUnit.h"
#import "CoreCameraEoh/NSUserDefaultsUnit.h"
#import <CoreCameraEoh/URLModel.h>
#import "Masonry.h"
#import "YYKit.h"

#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
#define RATIO_FRAME_VIDEO (9/16)


@interface VideoPlayer() <UIScrollViewDelegate> {
    UIScrollView *scrollView;
    KxMovieGLView *kxGlView;
    UIActivityIndicatorView *activityIndicatorView;
    
    BOOL firstFrame;                // Get the first frame, adjust the relevant UI
    BOOL transforming;
    BOOL needChangeViewFrame;
    
    // width and height of the video frame
    int displayWidth;
    int displayHeight;
    
    NSMutableArray *rgbFrameArray;  // decoded video data
    NSMutableArray *_audioFrames;   // decoded audio data
    
    NSData  *_currentAudioFrame;    // currently playing audio frame
    NSUInteger _currentAudioFramePos;
    
    NSTimeInterval _tickCorrectionTime;
    NSTimeInterval _tickCorretionPosition;
    
    CGFloat _moviePosition;         // Timestamp of the currently playing video (in milliseconds)
}

@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, assign) int frameLength;

@property (nonatomic, strong) UIView *statusView;
@property (nonatomic, strong) UIButton *playButton;     // play button

@property (nonatomic, strong) UIView *btnView;
@property (nonatomic, strong) UILabel *kbpsLabel;       // kbps
//@property (nonatomic, strong) UIView *backView;

@property (nonatomic, strong) UIImageView *imgThumnail; // Thumnail

@property (nonatomic, readwrite) CGFloat bufferdDuration;

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGesture;

@property (nonatomic, strong) NSTimer *timerHiddenButtonPlay;


- (void)showActivity;
- (void)hideActivity;

- (void)fillAudioData:(SInt16 *)outData numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels;

@end

@implementation VideoPlayer

#pragma mark - init

- (void)drawRect:(CGRect)rect{
    [super drawRect:rect];
    [self initFrameView];
    
    //  init default model 
    URLModel *model = [[URLModel alloc] initDefault];
    model.url = self.url;
    model.urlThumnail = self.urlThumnail;
    self.transportMode = model.transportMode;
    self.sendOption = model.sendOption;
    self.url = model.url;
    self.urlThumnail = model.urlThumnail;
    
    /// Update image thumnail
    [_imgThumnail setImageURL:[NSURL URLWithString: self.urlThumnail]];
    [self stopPlay];
}

- (id)init : (CGFloat) widthVD
{
    if (self = [super init]) {
    }
    
    return self;
}


- (id)initWithFrame:(CGRect)frame {
   
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor grayColor];
        
        [self addGesture];
        [self addItemView];
        
        firstFrame = YES;
        self.videoStatus = Stopped;
        needChangeViewFrame = NO;
        _showActiveStatus = YES;
        
        self.useHWDecoder = ![NSUserDefaultsUnit isFFMpeg];
        self.audioPlaying = YES;
        
        rgbFrameArray = [[NSMutableArray alloc] init];
        _audioFrames = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void) initFrameView{
    CGFloat wVideo = self.widthPlayer ;
    CGFloat hVideo = wVideo * 9/16;
    
    [self updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(hVideo));
        make.width.equalTo(@(wVideo));
    }];
}

- (void) addGesture {
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    self.tapGesture.delegate = self;
    [self addGestureRecognizer:self.tapGesture];
}

- (void) addImageViewThumnail{
    //Image view thumnail
    _imgThumnail = [[UIImageView alloc] init];
    [self addSubview:_imgThumnail];
    [_imgThumnail makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(@0);
    }];
}

- (void) addItemView {
    scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    [self addSubview:scrollView];
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.backgroundColor = [UIColor grayColor];
    scrollView.delegate = self;
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.zoomScale = 1;
    scrollView.minimumZoomScale = 1;
    scrollView.maximumZoomScale = 4.0;
    scrollView.bouncesZoom = NO;
    scrollView.bounces = NO;
    scrollView.scrollEnabled = NO;
    
    kxGlView = [[KxMovieGLView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    [scrollView addSubview:kxGlView];
    
    // Click on video, hide bottom button
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideStatusView)];
    gesture.numberOfTapsRequired = 1;
    [kxGlView addGestureRecognizer:gesture];
    
    _addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_addButton setImage:[UIImage imageNamed:@"ic_action_add"] forState:UIControlStateNormal];
    _addButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_addButton];
    
    activityIndicatorView = [[UIActivityIndicatorView alloc] init];
    activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    activityIndicatorView.hidesWhenStopped = YES;
    [self addSubview:activityIndicatorView];
    [activityIndicatorView makeConstraints:^(MASConstraintMaker *make) {
        make.size.equalTo(CGSizeMake(10, 10));
        make.centerX.equalTo(self.mas_centerX);
        make.centerY.equalTo(self.mas_centerY);
    }];
    
//    CGFloat size = 45;
    
    [self addImageViewThumnail];
    
    
    _statusView = [[UIView alloc] init];
    _statusView.backgroundColor = [UIColor clearColor];
    _statusView.hidden = YES;
    [self addSubview:_statusView];
    [_statusView makeConstraints:^(MASConstraintMaker *make) {
        make.size.equalTo(CGSizeMake(60, 60));
        make.centerX.equalTo(self.mas_centerX);
        make.centerY.equalTo(self.mas_centerY);
        
    }];
    
    _landspaceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_landspaceButton setImage:[UIImage imageNamed:@"CoreCameraEoh.framework/LandspaceVideo"] forState:UIControlStateNormal];
    [_landspaceButton setImage:[UIImage imageNamed:@"CoreCameraEoh.framework/PortraitVideo"] forState:UIControlStateSelected];
    [_landspaceButton addTarget:self action:@selector(landspaceButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    _landspaceButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
//    _landspaceButton.hidden = YES;
    [self addSubview:_landspaceButton];
    [_landspaceButton makeConstraints:^(MASConstraintMaker *make) {
        make.size.equalTo(CGSizeMake(30, 30));
        make.right.bottom.equalTo(@(-5));
    }];
    
    
    
    _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_playButton setImage:[UIImage imageNamed:@"CoreCameraEoh.framework/play.png"] forState:UIControlStateNormal];
    [_playButton setImage:[UIImage imageNamed:@"CoreCameraEoh.framework/pause.png"] forState:UIControlStateSelected];
    [_playButton addTarget:self action:@selector(playButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_statusView addSubview:_playButton];
    [_playButton makeConstraints:^(MASConstraintMaker *make) {
//        make.width.equalTo(@(size));
        make.size.equalTo(CGSizeMake(50, 50));
        make.top.left.bottom.equalTo(@0);
    }];
    
    
    _btnView = [[UIView alloc] init];
    _btnView.backgroundColor = [UIColor clearColor];
    [_statusView addSubview:_btnView];
    [_btnView makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.right.equalTo(@0);
        make.left.equalTo(self.playButton.mas_right).offset(20);
    }];
    
    _kbpsLabel = [[UILabel alloc] init];
    _kbpsLabel.text = @"0kbps";
    _kbpsLabel.textColor = UIColorFromRGB(SelectBtnColor);
    _kbpsLabel.font = [UIFont systemFontOfSize:13];
    _kbpsLabel.hidden = YES;
    [_btnView addSubview:_kbpsLabel];
    [_kbpsLabel makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(@0);
    }];
}

// Click on video, hide bottom button
- (void) hideStatusView {
    _statusView.hidden = !_statusView.hidden;
    
    // btnView is not hidden, it is not split screen
    if (!self.btnView.isHidden) {
        if (_landspaceButton.isSelected) {//When in landscape
//            _backView.hidden = _statusView.hidden;
        }
    }
}

- (void) changeHorizontalScreen:(BOOL) horizontal {
    _landspaceButton.selected = horizontal;
    
    [self updateHeight];
}

#pragma mark - override

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _addButton.frame = self.bounds;
    
    if (_landspaceButton.selected) {
        kxGlView.frame = scrollView.bounds;
        scrollView.contentSize = scrollView.frame.size;
        
        if (displayHeight != 0 && displayWidth != 0) {
            if (displayWidth < displayHeight) {
                CGFloat height = scrollView.bounds.size.height;
                CGFloat width = height * displayWidth / displayHeight;
                
                scrollView.contentSize = CGSizeMake(width, height);
                
                CGFloat x = (scrollView.bounds.size.width - width) / 2;
                kxGlView.frame = CGRectMake(x, 0, width, height);
            }
        }
    } else {
        if (_showAllRegon) {
            CGRect rc = scrollView.frame;
            scrollView.contentSize = rc.size;
            if (displayWidth != 0 && displayHeight != 0) {
                int x = displayWidth > self.bounds.size.width ? 0 : (int)(fabs(self.bounds.size.width - displayWidth) / 2.0 + 0.5);
                int cx = MIN(displayWidth, self.bounds.size.width);
                int cy = MIN(displayHeight * cx / displayWidth, self.bounds.size.height);
                int y = (self.bounds.size.height - cy) / 2.0 + 0.5;
                
                CGRect imageRect;
                imageRect.origin = CGPointMake(x, y);
                imageRect.size = CGSizeMake(cx, cy);
                kxGlView.frame = imageRect;
            }
        } else {
            // ratio 16:9
            CGFloat height = scrollView.bounds.size.height;
            CGFloat width = scrollView.bounds.size.height * 16.0 / 9.0;
            
            if (displayHeight != 0 && displayWidth != 0) {
                if (displayWidth > displayHeight) {
                    width = scrollView.bounds.size.height * (float)displayWidth / (float)displayHeight;
                    if (width < scrollView.bounds.size.width) {
                        width = scrollView.bounds.size.width;
                    }
                } else {
                    width = height * displayWidth / displayHeight;
                }
            }
            
            scrollView.contentSize = CGSizeMake(width, height);
            
            if (width < scrollView.bounds.size.width) {
                CGFloat x = (scrollView.bounds.size.width - width) / 2;
                kxGlView.frame = CGRectMake(x, 0, width, height);
            } else {
                kxGlView.frame = CGRectMake(0, 0, width, height);
                scrollView.contentOffset = CGPointMake((width - scrollView.bounds.size.width) / 2, 0);
            }
            
//            NSLog(@"displayWidth = %d displayHeight = %d %f %f frameWidht = %f frameHeight = %f", displayWidth, displayHeight, width, height, self.frame.size.width, self.frame.size.height);
            
            [self reCalculateArcPos];
        }
    }
}


- (void)startPlay {
  
    if (!self.url || self.url.length == 0) {
        return;
    }
    
    
    _tickCorrectionTime = 0;
    _tickCorretionPosition = 0;
    _moviePosition = 0;
    _currentAudioFramePos = 0;
    _bufferdDuration = 0;
    
    [self stopPlay];
    
    self.videoStatus = Connecting;
    [self showActivity];
    self.addButton.hidden = YES;
    [self.delegate videoViewWillTryToConnect:self];
    
    __weak VideoPlayer *weakSelf = self;
    _reader = [[PlayerReader alloc] initWithUrl:self.url];
    _reader.useHWDecoder = self.useHWDecoder;
    _reader.transportMode = self.transportMode;
    _reader.sendOption = self.sendOption;
    
    
    // get media type
    _reader.fetchMediaInfoSuccessBlock = ^(void){
        weakSelf.videoStatus = Rendering;
        [weakSelf updateUI];
        [weakSelf presentFrame];
        
       
    };
    
    // Get decoded audio frame/video frame
    _reader.frameOutputBlock = ^(KxMovieFrame *frame, unsigned int length) {
        [weakSelf addFrame:frame];
        [weakSelf sendPacket:length];
    };
    [_reader start];
    
    _playButton.selected = FALSE;
    _imgThumnail.hidden = TRUE;
    [self hiddenButtonPlay];
}

- (void)stopPlay {
    
    [self hideActivity];
    
    self.videoStatus = Stopped;
    
    dispatch_queue_t queue = dispatch_queue_create("stop_all_video", NULL);
    dispatch_async(queue, ^{
        [self.reader stop];
    });
    
    @synchronized(rgbFrameArray) {
        [rgbFrameArray removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        [_audioFrames removeAllObjects];
    }
    
    [self updateUI];
    [self flush];
    
    _playButton.selected = TRUE;
    _imgThumnail.hidden = FALSE;
    _statusView.hidden = FALSE;
}

- (void)flush {
    [kxGlView flush];
    firstFrame = YES;
    scrollView.zoomScale = 1.0;
    scrollView.scrollEnabled = NO;
}

- (void)updateUI {
//    self.audioButton.enabled = self.videoStatus == Rendering ? YES : NO;
//    _recordButton.enabled = self.videoStatus == Rendering ? YES : NO;
//    _screenshotButton.enabled = self.videoStatus == Rendering ? YES : NO;
}

#pragma mark - Decoded audio frame/video frame

- (void)addFrame:(KxMovieFrame *)frame {
    if (frame.type == KxMovieFrameTypeVideo) {
        @synchronized(rgbFrameArray) {
            if (self.videoStatus != Rendering) {
                [rgbFrameArray removeAllObjects];
                return;
            }
            
            [rgbFrameArray addObject:frame];
            _bufferdDuration = frame.position - ((KxVideoFrameRGB *)rgbFrameArray.firstObject).position;
        }
    } else if (frame.type == KxMovieFrameTypeAudio) {
        @synchronized(_audioFrames) {
            if (!self.audioPlaying) {
                [_audioFrames removeAllObjects];
                return;
            }
            
            [_audioFrames addObject:frame];
        }
    }
}

#pragma mark - timer hidden button play/pause

- (void)hiddenButtonPlay {
    self.timerHiddenButtonPlay = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(dismissTimerHiddenButtonPlay) userInfo:nil repeats:NO];
}

- (void)dismissTimerHiddenButtonPlay {
    [self.timerHiddenButtonPlay invalidate];
    self.timerHiddenButtonPlay = nil;
    [self hideStatusView];
    
}

#pragma mark - fill video data
- (void)presentFrame {
    CGFloat duration = 0;
    
    if (self.videoStatus == Rendering) {
        NSTimeInterval time = 0.01;
        
        KxVideoFrame *frame = [self popVideoFrame];
        
        if (frame != nil) {
            duration = [self displayFrame:frame];
            
            NSTimeInterval correction = [self tickCorrection];
            
            NSTimeInterval interval = MAX(duration + correction, 0.01);
            
            if (interval >= 0.035) {
                interval = interval / 2;
            }
            
            time = interval;
        }
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            [self presentFrame];
        });
    }
}

- (CGFloat)tickCorrection {
    if (_moviePosition == 0) {
        return 0;
    }
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (_tickCorrectionTime == 0) {
        _tickCorrectionTime = now;
        _tickCorretionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorretionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    if (correction > 1.f || correction < -1.f) {
//        NSLog(@"tick correction reset %0.2f", correction);
        correction = 0;
//        _tickCorrectionTime = 0;
    }
    
    if (_bufferdDuration >= 0.3) {
//        NSLog(@"bufferdDuration = %f play faster", _bufferdDuration);
        correction = -1;
    }
    
    return correction;
}

- (KxVideoFrame *)popVideoFrame {   // 队列
    KxVideoFrame *frame = nil;
    @synchronized(rgbFrameArray) {
        if ([rgbFrameArray count] > 0) {
            frame = [rgbFrameArray firstObject];
            [rgbFrameArray removeObjectAtIndex:0];
        }
    }
    
    return frame;
}

- (CGFloat)displayFrame:(KxVideoFrame *)frame {
    if (frame.width != displayWidth || displayHeight != frame.height) {
        needChangeViewFrame = YES;
    }
    
    displayWidth = (int)frame.width;
    displayHeight = (int)frame.height;
    
    if ((self.videoStatus == Rendering) && firstFrame) {
        needChangeViewFrame = YES;
        firstFrame = NO;
        scrollView.scrollEnabled = YES;
        
        // Prevent iOS device from locking screen
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        
        [self hideActivity];
    }
    
    if (needChangeViewFrame) {
        [self setNeedsLayout];
        needChangeViewFrame = NO;
    }
    
    [kxGlView render:frame];
    _moviePosition = frame.position;
    
    return frame.duration;
}

#pragma mark - Traffic detection

- (void) sendPacket:(unsigned int)u32AVFrameLen {
    self.frameLength += u32AVFrameLen;
    
    if (!self.timer) {
        NSTimeInterval period = 1.0; // set time interval
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_timer, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.kbpsLabel.text = [NSString stringWithFormat:@"%dkbps", self.frameLength / 1024 / 1024];
                self.frameLength = 0;
            });
        });
        
        dispatch_resume(self.timer);
    }
}

#pragma mark - fill audio data

- (void)fillAudioData:(SInt16 *) outData numFrames: (UInt32) numFrames numChannels: (UInt32) numChannels {
    @autoreleasepool {
        while (numFrames > 0) {
            if (_currentAudioFrame == nil) {
                @synchronized(_audioFrames) {
                    NSUInteger count = _audioFrames.count;
                    if (count > 0) {
                        KxAudioFrame *frame = _audioFrames[0];
                        CGFloat differ = _moviePosition - frame.position;
                        
                        // doesn't seem to work
                        if (differ < -0.1) {
                            memset(outData, 0, numFrames * numChannels * sizeof(float));
                            break; // silence and exit
                        }
                        
                        [_audioFrames removeObjectAtIndex:0];
                        
                        if (differ > 0.1 && count > 1) {
                            NSLog(@"differ = %.4f", differ);
                            NSLog(@"audio skip movPos = %.4f audioPos = %.4f", _moviePosition, frame.position);
                            continue;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(SInt16);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                if (bytesToCopy < bytesLeft) {
                    _currentAudioFramePos += bytesToCopy;
                } else {
                    _currentAudioFrame = nil;
                }
            } else {
                memset(outData, 0, numFrames * numChannels * sizeof(SInt16));
                break;
            }
        }
    }
}

#pragma mark - public method

- (void)beginTransform {
    scrollView.contentOffset = CGPointZero;
    scrollView.zoomScale = 1;
    transforming = YES;
}

- (void)endTransform {
    transforming = NO;
}

- (void) hideBtnView {
//    self.btnView.hidden = YES;
//    _backView.hidden = YES;
}

#pragma mark - private method

- (void)updateStreamCount {
    [self.delegate videoViewDidiUpdateStream:self];
}

- (void)reCalculateArcPos {
    if (_landspaceButton.selected) {
        return;
    }
    
    CGFloat maxDiffer = scrollView.contentSize.width - scrollView.frame.size.width;
    if (maxDiffer <= 0 || self.videoStatus != Rendering) {
        return;
    } else {
        if (!firstFrame) {
            
        }
    }
}

- (void)showActivity {
    [self bringSubviewToFront:activityIndicatorView];
    [activityIndicatorView startAnimating];
}

- (void)hideActivity {
    [activityIndicatorView stopAnimating];
}

- (void) updateHeight {
    if (_landspaceButton.selected) {
        [_statusView updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@56);
        }];
        
//        _backView.hidden = NO;
    } else {
        [_statusView updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@45);
        }];
        
//        _backView.hidden = YES;
    }
    
    [_statusView layoutSubviews];
}

#pragma mark - button event

- (void) playButtonClicked:(id)sender {
    _playButton.selected = !_playButton.selected;
    
    if (!_playButton.selected) {
        [self startPlay];
    } else {
        [self stopPlay];
    }
}

- (void) landspaceButtonClicked:(id)sender {
    _landspaceButton.selected = !_landspaceButton.selected;
    
//    [self.delegate videoViewBeginActive:self];
    if (_landspaceButton.selected) {
//        [self.delegate videoViewWillAnimateToFullScreen:self];
        
        [UIView animateWithDuration:0.5 animations:^{
            [self mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(ScreenHeight));
                make.height.equalTo(@(ScreenWidth));
                make.right.equalTo(@(160));
                make.top.equalTo(@(100));
            }];
            self.transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(90));
        }];
        
    } else {
//        [self.delegate videoViewWillAnimateToNomarl:self];
        
        [UIView animateWithDuration:0.5 animations:^{
            self.transform = CGAffineTransformIdentity;
            CGFloat wVideo = ScreenWidth ;
            CGFloat hVideo = wVideo * 9.0 / 16.0;
            
            
            [self updateConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(wVideo));
                make.height.equalTo(@(hVideo));
                make.right.equalTo(@(0));
                make.top.equalTo(@(0));
            }];
        }];
        
       
        
    }
    
//    [self updateHeight];
}

- (void) back {
    [self.delegate back];
}

#pragma mark - Gesture operation

- (void)handleTapGesture:(UITapGestureRecognizer *)tapGesture {
    [self.delegate videoViewBeginActive:self];
}

#pragma mark - setter

- (void)setVideoStatus:(IVideoStatus)videoStatus {
    _videoStatus = videoStatus;
}

- (void)setAudioPlaying:(BOOL)audioPlaying {
//    _audioPlaying = audioPlaying;
//
//    _reader.enableAudio = _audioPlaying;
//
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.audioButton.selected = self.audioPlaying;
//    });
}

- (void)setUrl:(NSString *)url {
    _url = url;
    
    _addButton.hidden = [_url length] == 0 ? NO : YES;
    
    if (url && [_url length] > 0) {
        _statusView.hidden = NO;
    } else {
        _statusView.hidden = YES;
    }
}

- (void)setShowActiveStatus:(BOOL)showActiveStatus {
    _showActiveStatus = showActiveStatus;
    self.layer.borderWidth = _active && _showActiveStatus ? 1 : 0;
}

- (void)setShowAllRegon:(BOOL)showAllRegon {
    _showAllRegon = showAllRegon;
    scrollView.scrollEnabled = _showAllRegon;
}

#pragma mark - UIScrollViewDelegate

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)aScrollView {
    return nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)aScrollView {
    if (transforming) {
        return;
    }
    
    CGPoint point = aScrollView.contentOffset;
    CGFloat maxX = aScrollView.contentSize.width - aScrollView.frame.size.width;
    if (point.x < 0.5) {
        point.x = 0.0;
        aScrollView.contentOffset = point;
    } else if ( point.x > maxX) {
        point.x = maxX;
        aScrollView.contentOffset = point;
    } else if (point.y < 0.5) {
        point.y = 0.0;
        aScrollView.contentOffset = point;
    } else if ( point.y > (aScrollView.contentSize.height - aScrollView.frame.size.height)) {
        point.y = aScrollView.contentSize.height - aScrollView.frame.size.height;
        aScrollView.contentOffset = point;
    }
    
    [self reCalculateArcPos];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([[touch view] isKindOfClass:[UIControl class]]) {
        return NO;
    }
    
    return YES;
}

#pragma mark - dealloc

- (void)dealloc {
    
    NSLog(@"dealloc");
}


#pragma mark - Notification Implementation 

- (void) initKVOAddObserverBackground{
    
}

- (void)becomeActive {
    NSLog(@"BecomeActive");
}

- (void)enterBackground {
    NSLog(@"EnterBackground");
}

@end
