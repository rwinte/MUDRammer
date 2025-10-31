//
//  SPLNotificationManager.swift
//  MUDRammer
//
//  Created by Bob Wintemberg on 9/23/24.
//  Copyright © 2024 splinesoft LLC. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

@MainActor
@objc class SPLNotificationManager: NSObject {
    
    @objc private(set) var askedForLocalNotifications: Bool = false
    
    @objc func registerForNotifications() async {
        guard !askedForLocalNotifications else {
            print("*** Already asked for permissions")
            return
        }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            self.didRegisterForNotifications(granted: granted)
        } catch {
            print("Error requesting notification permissions: \(error)")
        }

        askedForLocalNotifications = true
    }

    @objc func registerForNotificationsFromObjC() {
        Task {
            await registerForNotifications()
        }
    }
    
    @objc func scheduleTimeoutNotification() async {
        if !askedForLocalNotifications {
            await registerForNotifications()
        }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Session Timeout", comment: "Session Timeout")
        content.body = NSLocalizedString("SESSION_TIMEOUT", comment: "Your session will timeout in two minutes.")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8 * 60, repeats: false)
        
        let request = UNNotificationRequest(identifier: "SessionTimeoutNotification", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Timeout notification scheduled successfully")
        } catch {
            print("Error scheduling timeout notification: \(error)")
            // You might want to handle the error more specifically here,
            // such as trying again or notifying the user
        }
    }
    
    @objc func didRegisterForNotifications(granted: Bool) {
        print("Notification permissions granted: \(granted)")
    }
    
    @objc func handleNotificationResponse(_ response: UNNotificationResponse, completion: @escaping () -> Void) {
        print("Received notification response with ID \(response.notification.request.identifier)")
        completion()
    }
}
