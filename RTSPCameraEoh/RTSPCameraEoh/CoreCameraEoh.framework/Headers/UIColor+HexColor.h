//
//  UIColor+HexColor.h
//  Text2Group
//
//  Created by Levu on 2022/03/22.
//

#import <UIKit/UIKit.h>

#define TableViewBKColor 0xe1e1e1
#define SeperatorColor  0xe3e3e3
#define BlueNavigationBar 0x1a7cc5
#define YellowNavigationBar 0xb75a17
#define LightGray 0xe3e3e3

@interface UIColor (HexColor)

+ (UIColor *)colorFromHex:(NSInteger) value;
+ (UIColor *)colorWithHex:(NSInteger)value alpa:(float)alpa;

@end
