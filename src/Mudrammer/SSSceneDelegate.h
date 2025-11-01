//
//  SSSceneDelegate.h
//  Mudrammer
//
//  Created to support UIScene lifecycle.
//

#import <UIKit/UIKit.h>

@interface SSSceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;

@end
