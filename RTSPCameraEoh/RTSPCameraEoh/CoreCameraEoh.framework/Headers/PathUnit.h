//
//  PathUnit.h
//  EasyPlayer
//
//  Created by Levu on 2022/03/22.
//

#import <Foundation/Foundation.h>

/**
 Video and screenshot management
 */
@interface PathUnit : NSObject

#pragma mark - record path

// Delete the recording address of the camera
+ (void) deleteBaseRecordPathWithURL:(NSString *)url;

// file under camera
+ (NSArray *) recordListWithURL:(NSString *)url;

// The recording address of the camera
+ (NSString *) recordWithURL:(NSString *)url;

// Temporarily generated h264, aac when recording
+ (NSString *) recordH264;
+ (NSString *) recordAAC;

#pragma mark - image path

// Delete the screenshot address of the camera
+ (void) deleteBaseShotPathWithURL:(NSString *)url;

// file under camera
+ (NSArray *) screenShotListWithURL:(NSString *)url;

// Screenshot URL of the camera
+ (NSString *) screenShotWithURL:(NSString *)url;

// The address where the camera automatically takes screenshots
+ (NSString *) snapshotWithURL:(NSString *)url;

#pragma mark - base path

+ (NSString *) baseRecordPathWithURL:(NSString *)url;
+ (NSString *) baseShotPathWithURL:(NSString *)url;
    
@end
