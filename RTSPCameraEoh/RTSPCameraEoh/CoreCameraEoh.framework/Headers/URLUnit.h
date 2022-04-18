//
//  URLUnit.h
//  CameraRTSPEoh
//
//  Created by Levu on 2022/03/22.
//

#import <Foundation/Foundation.h>
#import "URLModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Management of stream addresses
 */
@interface URLUnit : NSObject

#pragma mark - storage of playback url

// get all urls
+ (NSMutableArray *) urlModels;

// add url
+ (void) addURLModel:(URLModel *)model;
+ (void) updateURLModel:(URLModel *)model oldModel:(URLModel *)m;

// remove url
+ (void) removeURLModel:(URLModel *)model;

@end

NS_ASSUME_NONNULL_END
