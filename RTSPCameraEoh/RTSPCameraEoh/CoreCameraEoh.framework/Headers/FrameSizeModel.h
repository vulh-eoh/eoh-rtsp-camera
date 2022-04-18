//
//  FrameSizeModel.h
//  CoreCameraEoh
//
//  Created by a on 4/17/22.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FrameSizeModel : BaseModel

@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;

- (instancetype) initDefault;

@end

NS_ASSUME_NONNULL_END
