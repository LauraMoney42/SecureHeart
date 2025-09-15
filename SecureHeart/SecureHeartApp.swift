//
//  SecureHeartApp.swift
//  Secure Heart
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI
import Firebase
import FirebaseMessaging
import UserNotifications

@main
struct SecureHeartApp: App {
    @StateObject private var emergencyManager = EmergencyContactsManager()

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Set up Firebase Messaging delegate
        setupFirebaseMessaging()

        // Request notification permissions
        requestNotificationPermissions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(emergencyManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Handle app becoming active
                    clearBadgeCount()
                }
        }
    }

    private func setupFirebaseMessaging() {
        // Set up Firebase Messaging
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = FirebaseMessagingDelegate.shared
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
                if granted {
                    print("✅ Notification permission granted")
                } else if let error = error {
                    print("❌ Notification permission error: \(error)")
                }
            }
        }

        UIApplication.shared.registerForRemoteNotifications()
        Messaging.messaging().delegate = FirebaseMessagingDelegate.shared
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Push notifications authorized")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Push notifications denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func clearBadgeCount() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}

// MARK: - Firebase Messaging Delegate

class FirebaseMessagingDelegate: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = FirebaseMessagingDelegate()

    private override init() {
        super.init()
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }

        print("✅ Firebase FCM token received: \(fcmToken)")

        // Store token in Firestore for this user
        // This will be handled by EmergencyContactsManager's setupFCMToken method
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        // Check if this is an emergency notification
        if let notificationType = userInfo["type"] as? String, notificationType == "emergency_alert" {
            // Show emergency notifications even when app is in foreground
            completionHandler([.alert, .sound, .badge])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Handle emergency notification tap
        if let notificationType = userInfo["type"] as? String, notificationType == "emergency_alert" {
            print("🚨 Emergency notification tapped")

            // Navigate to emergency contacts or show emergency details
            NotificationCenter.default.post(
                name: NSNotification.Name("EmergencyNotificationTapped"),
                object: nil,
                userInfo: userInfo
            )
        }

        completionHandler()
    }

    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs device token received")
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}
