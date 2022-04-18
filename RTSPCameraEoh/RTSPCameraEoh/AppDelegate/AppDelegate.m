//
//  AppDelegate.m
//  RTSPCameraEoh
//
//  Created by a on 4/12/22.
//

#import "AppDelegate.h"
#import "CoreCameraEoh/URLModel.h"
#import "CoreCameraEoh/NSUserDefaultsUnit.h"
#import "PlayerReader.h"

#import "PlayerViewController.h"
#import "GirdPlayerViewController.h"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [NSUserDefaultsUnit setStartRTSP:true];
    [PlayerReader startUp];
    
    return YES;
}

@end
