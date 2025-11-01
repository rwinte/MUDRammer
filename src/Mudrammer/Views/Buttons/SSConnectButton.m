//
//  SSConnectButton.m
//  Mudrammer
//
//  Created by Jonathan Hersh on 11/3/12.
//  Copyright (c) 2012 Jonathan Hersh. All rights reserved.
//

#import "SSConnectButton.h"
#import "SPLAlerts.h"

@interface SSConnectButton ()

- (void) didTapButton:(id)sender;

@end

@implementation SSConnectButton

- (SSConnectButton *) init {
    if ((self = [self initWithFrame:CGRectZero])) {
        [self setImage:[SPLImagesCatalog connectRedImage]
              forState:UIControlStateNormal];
        [self addTarget:self
                 action:@selector(didTapButton:)
       forControlEvents:UIControlEventTouchUpInside];
        [self sizeToFit];

        _connected = NO;

        self.isAccessibilityElement = YES;
    }

    return self;
}

- (void)dealloc {
    _connectDelegate = nil;
}

#pragma mark - tapping button

- (void)didTapButton:(id)sender {
    NSLog(@"[SSConnectButton] Button tapped. isConnected: %d, delegate: %@", self.isConnected, self.connectDelegate);
    id <SSConnectButtonDelegate> del = self.connectDelegate;

    if (self.isConnected) {
        NSLog(@"[SSConnectButton] Showing disconnect action sheet");
        __weak typeof(self) weakSelf = self;
        [SPLAlerts SPLShowActionViewWithTitle:nil
                                  cancelTitle:NSLocalizedString(@"CANCEL", @"Cancel")
                                  cancelBlock:nil
                             destructiveTitle:NSLocalizedString(@"DISCONNECT", @"Disconnect")
                             destructiveBlock:^{
                                 __strong typeof(weakSelf) strongSelf = weakSelf; (void)strongSelf;
                                 NSLog(@"[SSConnectButton] Disconnect selected");
                                 if ([del respondsToSelector:@selector(connectButton:didChangeState:)]) {
                                     NSLog(@"[SSConnectButton] Calling delegate connectButton:didChangeState:NO");
                                     [del connectButton:self
                                         didChangeState:NO];
                                 } else {
                                     NSLog(@"[SSConnectButton] WARNING: Delegate does not respond to connectButton:didChangeState:");
                                 }
                             }
                                barButtonItem:self.targetBarButton
                                   sourceView:self
                                   sourceRect:self.bounds];
    } else {
        NSLog(@"[SSConnectButton] Calling connect");
        if ([del respondsToSelector:@selector(connectButton:didChangeState:)])
            [del connectButton:self
                didChangeState:YES];
    }
}

#pragma mark - changing state

- (void)setConnected:(BOOL)conn {
    if (_connected == conn)
        return;

    UIImage *newImg = nil;

    if (conn) {
        newImg = [SPLImagesCatalog connectGreenImage];
        self.accessibilityLabel = NSLocalizedString(@"DISCONNECT", nil);
        self.accessibilityHint = @"Disconnects from this World.";
    } else {
        newImg = [SPLImagesCatalog connectRedImage];
        self.accessibilityLabel = NSLocalizedString(@"CONNECT", nil);
        self.accessibilityHint = @"Connects to this World.";
    }

    [self setImage:newImg
          forState:UIControlStateNormal];

    _connected = conn;
}

@end
