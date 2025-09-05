//
//  SecureHeartApp.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI

@main
struct SecureHeartWatchApp: App {
    @StateObject private var heartRateManager = HeartRateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(heartRateManager)
                .onAppear {
                    // Resume monitoring when app appears
                    heartRateManager.resumeMonitoringIfNeeded()
                }
        }
    }
}
