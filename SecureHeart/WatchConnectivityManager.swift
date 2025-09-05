//
//  WatchConnectivityManager.swift
//  Secure Heart
//
//  Handles communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var latestHeartRate: Int = 0
    @Published var isWatchConnected: Bool = false
    
    // Settings sync
    func sendRecordingInterval(_ interval: TimeInterval) {
        guard let session = session, session.isReachable else {
            print("⚠️ [iPhone] Cannot send recording interval - Watch not reachable")
            return
        }
        
        let message: [String: Any] = [
            "recordingInterval": interval
        ]
        
        print("📤 [iPhone] Sending recording interval: \(interval)s")
        
        session.sendMessage(message, replyHandler: { reply in
            print("✅ [iPhone] Recording interval acknowledged by Watch")
        }) { error in
            print("🔴 [iPhone] Error sending recording interval: \(error.localizedDescription)")
        }
    }
    @Published var lastMessageReceived: Date?
    @Published var heartRateHistory: [(heartRate: Int, timestamp: Date)] = []
    
    private var session: WCSession?
    private let maxHistoryCount = 100
    
    override init() {
        super.init()
        
        // Only activate if watch connectivity is supported
        // This prevents crashes when no watch is paired
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            // Activate on a background queue to avoid blocking UI
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.session?.activate()
            }
        }
    }
    
    // Send message to watch
    func sendMessageToWatch(_ message: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message to watch: \(error.localizedDescription)")
        }
    }
    
    // Request latest heart rate from watch
    func requestHeartRateUpdate() {
        sendMessageToWatch(["request": "heartRateUpdate"])
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated)
        }
        
        if let error = error {
            print("🔴 [iPhone] WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [iPhone] WCSession activated with state: \(activationState.rawValue)")
            #if os(iOS)
            print("⌚ [iPhone] Watch app installed: \(session.isWatchAppInstalled)")
            #endif
            print("🔗 [iPhone] Session reachable: \(session.isReachable)")
        }
    }
    
    #if os(iOS)
    // iPhone specific delegates
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        session.activate()
    }
    #endif
    
    // Receive message from watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📩 [iPhone] Received message from Watch: \(message)")
        
        DispatchQueue.main.async {
            // Handle heart rate update from watch
            if let heartRate = message["heartRate"] as? Int {
                print("💓 [iPhone] Processing heart rate: \(heartRate) BPM")
                self.latestHeartRate = heartRate
                self.lastMessageReceived = Date()
                
                // Get posture data if available
                let posture = message["posture"] as? String
                let isStanding = message["isStanding"] as? Bool
                
                // Add to history with posture context
                self.heartRateHistory.append((heartRate: heartRate, timestamp: Date()))
                
                // Limit history size
                if self.heartRateHistory.count > self.maxHistoryCount {
                    self.heartRateHistory.removeFirst()
                }
                
                // Post notification for other parts of the app with posture data
                var userInfo: [String: Any] = ["heartRate": heartRate]
                if let posture = posture {
                    userInfo["posture"] = posture
                }
                if let isStanding = isStanding {
                    userInfo["isStanding"] = isStanding
                }
                
                NotificationCenter.default.post(
                    name: Notification.Name("HeartRateUpdated"),
                    object: nil,
                    userInfo: userInfo
                )
                
                if let posture = posture {
                    print("✅ [iPhone] Updated UI with heart rate: \(heartRate) (\(posture))")
                } else {
                    print("✅ [iPhone] Updated UI with heart rate: \(heartRate)")
                }
            }
            
            // Handle heart rate delta
            if let delta = message["heartRateDelta"] as? Int {
                NotificationCenter.default.post(
                    name: Notification.Name("HeartRateDeltaUpdated"),
                    object: nil,
                    userInfo: ["delta": delta]
                )
            }
            
            // Handle significant changes
            if let changeInfo = message["significantChange"] as? [String: Any] {
                NotificationCenter.default.post(
                    name: Notification.Name("SignificantHeartRateChange"),
                    object: nil,
                    userInfo: changeInfo
                )
            }
            
            // Handle orthostatic events
            if let orthostaticInfo = message["orthostaticEvent"] as? [String: Any] {
                print("🩺 [iPhone] Received orthostatic event: \(orthostaticInfo)")
                NotificationCenter.default.post(
                    name: Notification.Name("OrthostaticEventReceived"),
                    object: nil,
                    userInfo: orthostaticInfo
                )
            }
        }
    }
    
    // Handle messages with reply handlers
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 [iPhone] Received message with reply handler: \(message)")
        
        // Process the message (same logic as didReceiveMessage)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Handle heart rate updates
            if let heartRate = message["heartRate"] as? Int {
                self.latestHeartRate = heartRate
                self.lastMessageReceived = Date()
                
                // Get posture data if available
                let posture = message["posture"] as? String
                let isStanding = message["isStanding"] as? Bool
                
                // Add to history (using tuple format for iPhone)
                let historyEntry = (heartRate: heartRate, timestamp: Date())
                self.heartRateHistory.append(historyEntry)
                
                // Limit history size
                if self.heartRateHistory.count > self.maxHistoryCount {
                    self.heartRateHistory.removeFirst()
                }
                
                // Post notification for other parts of the app with posture data
                var userInfo: [String: Any] = ["heartRate": heartRate]
                if let posture = posture {
                    userInfo["posture"] = posture
                }
                if let isStanding = isStanding {
                    userInfo["isStanding"] = isStanding
                }
                
                NotificationCenter.default.post(
                    name: Notification.Name("HeartRateUpdated"),
                    object: nil,
                    userInfo: userInfo
                )
                
                if let posture = posture {
                    print("✅ [iPhone] Updated UI with heart rate: \(heartRate) (\(posture)) via reply handler")
                } else {
                    print("✅ [iPhone] Updated UI with heart rate: \(heartRate) via reply handler")
                }
            }
            
            // Handle heart rate delta
            if let delta = message["heartRateDelta"] as? Int {
                NotificationCenter.default.post(
                    name: Notification.Name("HeartRateDeltaUpdated"),
                    object: nil,
                    userInfo: ["delta": delta]
                )
            }
            
            // Handle significant changes
            if let changeType = message["significantChange"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("SignificantHeartRateChange"),
                    object: nil,
                    userInfo: ["changeType": changeType, "message": message]
                )
            }
            
            // Handle orthostatic events
            if let eventData = message["orthostaticEvent"] as? [String: Any] {
                NotificationCenter.default.post(
                    name: Notification.Name("OrthostaticEventReceived"),
                    object: nil,
                    userInfo: eventData
                )
            }
        }
        
        // Send reply to acknowledge receipt
        replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }
    
    // Receive application context
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            // Handle background updates
            if let heartRate = applicationContext["heartRate"] as? Int {
                self.latestHeartRate = heartRate
                self.lastMessageReceived = Date()
            }
        }
    }
    
    // Watch reachability changed
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
        }
    }
}