//
//  BaseModel.h
//  Easy
//
//  Created by Levu on 2022/03/22.
//

#import <Foundation/Foundation.h>

#if __has_include(<YYModel/YYModel.h>)
    FOUNDATION_EXPORT double YYModelVersionNumber;
    FOUNDATION_EXPORT const unsigned char YYModelVersionString[];
    #import <YYModel/NSObject+YYModel.h>
    #import <YYModel/YYClassInfo.h>
#else
    #import "NSObject+YYModel.h"
    #import "YYClassInfo.h"
#endif

/**
 class BaseModel
 */
@interface BaseModel : NSObject<NSCoding, NSCopying>

+ (instancetype) convertFromDict:(NSDictionary *)dict;
+ (NSMutableArray *) convertFromArray:(NSArray *)array;

@end
