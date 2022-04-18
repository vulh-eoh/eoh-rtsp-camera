
#import <UIKit/UIKit.h>

@class KxVideoFrame;
@class KxMovieDecoder;

@interface KxMovieGLView : UIView

- (id) initWithFrame:(CGRect)frame;
- (void) render: (KxVideoFrame *) frame;
- (void) flush;

- (UIImage *)curImage;

@end
