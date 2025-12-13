//
//  NotificationManager.swift
//  OdysseyTest
//
//  Simple wrapper around UNUserNotificationCenter for local notifications
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// Ask the user for permission to show local notifications
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        // Make sure notifications can appear even while app is in foreground
        center.delegate = NotificationDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                TimestampUtility.log("Notification authorization error: \(error.localizedDescription)", category: "Notification")
                DebugLogger.shared.log(.error, category: "Notification", message: "Authorization error: \(error.localizedDescription)")
                return
            }
            
            let status = granted ? "granted" : "denied"
            TimestampUtility.log("Notification authorization \(status)", category: "Notification")
            DebugLogger.shared.log(.info, category: "Notification", message: "Authorization \(status)")
        }
    }
    
    /// Schedule a simple one-off local notification with a short delay
    func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Fire shortly after scheduling
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                TimestampUtility.log("Failed to schedule notification: \(error.localizedDescription)", category: "Notification")
                DebugLogger.shared.log(.error, category: "Notification", message: "Schedule error: \(error.localizedDescription)")
            }
        }
    }
}


