//
//  NSUserDefaultsUnit.h
//  EasyPlayer
//
//  Created by Levu on 2022/03/22.
//

#import <Foundation/Foundation.h>

/**
 management of settings
 */
@interface NSUserDefaultsUnit : NSObject

#pragma mark - Turn on autoplay audio

+ (void) setAutoAudio:(BOOL)isAudio;

+ (BOOL) isAutoAudio;

#pragma mark - Whether to record video while opening video

+ (void) setAutoRecord:(BOOL)isRecord;

+ (BOOL) isAutoRecord;

#pragma mark - Whether to use FFMpeg for video soft decoding

+ (void) setFFMpeg:(BOOL)isFFMpeg;

+ (BOOL) isFFMpeg;

#pragma mark - key Validity period

+ (void) setActiveDay:(int)value;

+ (int) activeDay;


+ (void) setStartRTSP:(BOOL)isStartRTSP;
+ (BOOL) isStartRTSP;

@end
