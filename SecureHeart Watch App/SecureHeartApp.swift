//
//  SecureHeartApp.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

@main
struct SecureHeartWatchApp: App {
    @StateObject private var heartRateManager = HeartRateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(heartRateManager)
                .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationDidBecomeActiveNotification)) { _ in
                    // Resume monitoring when app becomes active
                    heartRateManager.resumeMonitoringIfNeeded()
                }
        }
    }
}
