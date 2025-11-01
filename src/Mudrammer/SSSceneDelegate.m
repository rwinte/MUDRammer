//
//  SSSceneDelegate.m
//  Mudrammer
//
//  Created to support UIScene lifecycle.
//

#import "SSSceneDelegate.h"
#import "SSClientContainer.h"

@implementation SSSceneDelegate

- (instancetype)init {
    if ((self = [super init])) {
        _backgroundTask = UIBackgroundTaskInvalid;
    }
    return self;
}

#pragma mark - UIWindowSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;

    // Create the window
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];

    // Reuse the existing SSClientContainer from SSAppDelegate if it exists,
    // otherwise create a new one
    SSClientContainer *existingContainer = [SSClientContainer sharedClientContainer];
    if (existingContainer) {
        NSLog(@"Scene delegate: Reusing existing SSClientContainer");
        self.window.rootViewController = existingContainer;
    } else {
        NSLog(@"Scene delegate: Creating new SSClientContainer");
        self.window.rootViewController = [SSClientContainer new];
    }

    // Make the window key and visible
    [self.window makeKeyAndVisible];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.

    // End background task now that we're returning to foreground
    [self endBackgroundTask];
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.

    // Begin background task to allow network connections to persist briefly
    // This gives users time to switch apps and return without losing their MUD connection
    [self beginBackgroundTask];
}

#pragma mark - Background Task Management

- (void)beginBackgroundTask {
    // If we already have a background task, don't create another
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"MUDRammer Connection Maintenance" expirationHandler:^{
        // This block is called when the system is about to terminate the background task
        // We should clean up here
        NSLog(@"Background task expired - connections may be closed by system");
        [weakSelf endBackgroundTask];
    }];
}

- (void)endBackgroundTask {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end
