//
//  WatchConnectivityManager.swift
//  Secure Heart Watch App
//
//  Handles communication between Apple Watch and iPhone
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isPhoneConnected: Bool = false
    private var session: WCSession?
    private var lastSentHeartRate: Int = 0
    private var lastSentTime: Date = Date()
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("🔧 [WATCH] WatchConnectivity session activating...")
        } else {
            print("🔴 [WATCH] WatchConnectivity not supported")
        }
    }
    
    // Send heart rate update to iPhone
    func sendHeartRateUpdate(heartRate: Int, delta: Int = 0) {
        guard let session = session else { 
            print("🔴 [WATCH] No WCSession available")
            return 
        }
        
        // Throttle updates - send at most once per second for the same value
        let now = Date()
        if heartRate == lastSentHeartRate && now.timeIntervalSince(lastSentTime) < 1.0 {
            return
        }
        
        lastSentHeartRate = heartRate
        lastSentTime = now
        
        let message: [String: Any] = [
            "heartRate": heartRate,
            "heartRateDelta": delta,
            "timestamp": now
        ]
        
        print("💓 [WATCH] Sending heart rate: \(heartRate) BPM, delta: \(delta)")
        print("🔗 [WATCH] Session reachable: \(session.isReachable)")
        
        // Try to send via message if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                print("✅ [WATCH] iPhone replied: \(reply)")
            }) { error in
                print("🔴 [WATCH] Error sending heart rate to iPhone: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ [WATCH] iPhone not reachable, using background sync")
        }
        
        // Always update application context for background sync
        do {
            try session.updateApplicationContext(message)
            print("📤 [WATCH] Updated application context")
        } catch {
            print("🔴 [WATCH] Error updating application context: \(error.localizedDescription)")
        }
    }
    
    // Send significant change alert to iPhone
    func sendSignificantChange(fromRate: Int, toRate: Int, delta: Int) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "significantChange": [
                "fromRate": fromRate,
                "toRate": toRate,
                "delta": delta,
                "timestamp": Date()
            ]
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending significant change: \(error.localizedDescription)")
        }
    }
    
    // Send orthostatic event to iPhone
    func sendOrthostaticEvent(baselineHeartRate: Int, peakHeartRate: Int, increase: Int, severity: String, sustainedDuration: TimeInterval = 30.0, recoveryTime: TimeInterval? = nil, isRecovered: Bool = false, timestamp: Date = Date()) {
        guard let session = session else {
            print("🔴 [WATCH] WatchConnectivity session is nil")
            return
        }
        
        guard session.isReachable else { 
            print("⚠️ [WATCH] iPhone not reachable")
            return 
        }
        
        var eventData: [String: Any] = [
            "baselineHeartRate": baselineHeartRate,
            "peakHeartRate": peakHeartRate,
            "increase": increase,
            "severity": severity,
            "timestamp": timestamp,
            "sustainedDuration": sustainedDuration,
            "isRecovered": isRecovered
        ]
        
        if let recoveryTime = recoveryTime {
            eventData["recoveryTime"] = recoveryTime
        }
        
        let message: [String: Any] = [
            "orthostaticEvent": eventData
        ]
        
        print("🩺 [WATCH] Sending orthostatic event: +\(increase) BPM (\(severity))")
        
        session.sendMessage(message, replyHandler: { reply in
            print("✅ [WATCH] Orthostatic event acknowledged by iPhone")
        }) { error in
            print("🔴 [WATCH] Error sending orthostatic event: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneConnected = (activationState == .activated && session.isCompanionAppInstalled)
        }
        
        if let error = error {
            print("🔴 [WATCH] WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [WATCH] WCSession activated with state: \(activationState.rawValue)")
            print("📱 [WATCH] Companion app installed: \(session.isCompanionAppInstalled)")
            print("🔗 [WATCH] Session reachable: \(session.isReachable)")
        }
    }
    
    // Receive message from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle recording interval updates from iPhone
        if let interval = message["recordingInterval"] as? TimeInterval {
            print("📥 [WATCH] Received recording interval: \(interval)s")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("RecordingIntervalUpdated"),
                    object: nil,
                    userInfo: ["interval": interval]
                )
            }
            return
        }
        
        // Handle requests from iPhone
        if let request = message["request"] as? String {
            switch request {
            case "heartRateUpdate":
                // Send current heart rate immediately
                if lastSentHeartRate > 0 {
                    sendHeartRateUpdate(heartRate: lastSentHeartRate)
                }
            default:
                break
            }
        }
    }
}