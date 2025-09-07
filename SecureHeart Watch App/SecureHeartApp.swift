//
//  SecureHeartApp.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI
import WatchKit

@main
struct SecureHeartWatchApp: App {
    @StateObject private var heartRateManager = HeartRateManager.sharedInstance
    // @StateObject private var watchFaceManager = WatchFaceManager() // Disabled to avoid runtime session errors
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(heartRateManager)
                // .environmentObject(watchFaceManager) // Disabled
                .onAppear {
                    print("🚀 SecureHeart Watch App appeared - initializing...")
                    // Resume monitoring when app appears
                    heartRateManager.resumeMonitoringIfNeeded()
                    
                    print("✅ SecureHeart Watch App initialization complete")
                }
                .preferredColorScheme(.dark) // Always use dark mode for watch face
        }
    }
}

// Watch Face Management Class
class WatchFaceManager: NSObject, ObservableObject {
    @Published var isWatchFaceMode = true
    @Published var preventSleep = true
    
    private var extendedRuntimeSession: WKExtendedRuntimeSession?
    
    func enableWatchFaceMode() {
        isWatchFaceMode = true
        preventSleep = true
        
        // Start extended runtime session for continuous operation
        startExtendedRuntimeSession()
        
        // Keep screen active
        keepScreenActive()
    }
    
    private func startExtendedRuntimeSession() {
        extendedRuntimeSession = WKExtendedRuntimeSession()
        extendedRuntimeSession?.delegate = self
        extendedRuntimeSession?.start()
    }
    
    private func keepScreenActive() {
        // Request to stay active and prevent screen dimming
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            // Subtle screen update to prevent sleep
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
}

// Extended Runtime Session Delegate
extension WatchFaceManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("✅ Extended runtime session started - Watch face mode active")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⚠️ Extended runtime session will expire - Attempting to restart")
        // Try to restart the session
        startExtendedRuntimeSession()
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("🔴 Extended runtime session invalidated: \(reason)")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        // Try to restart after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startExtendedRuntimeSession()
        }
    }
}
