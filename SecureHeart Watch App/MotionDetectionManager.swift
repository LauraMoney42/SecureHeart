//
//  MotionDetectionManager.swift
//  Secure Heart Watch App
//
//  Created by Claude Code on 9/14/25.
//

import Foundation
import CoreMotion
import Combine

/// A clean, reliable implementation of standing/sitting detection using Apple's recommended CoreMotion APIs
/// Based on research of Apple Watch, Fitbit, and academic best practices for activity recognition
class MotionDetectionManager: ObservableObject {

    // MARK: - Published Properties
    @Published var isStanding = false
    @Published var currentActivity: String = "Unknown"
    @Published var confidence: CMMotionActivityConfidence = .low
    @Published var lastUpdate = Date()

    // MARK: - Private Properties
    private let activityManager = CMMotionActivityManager()
    private var isMonitoring = false
    private var activityTimer: Timer?

    // State tracking for reliability
    private var recentActivities: [CMMotionActivity] = []
    private var consecutiveStationaryCount = 0
    private var standingConfirmedTime: Date?

    // Configuration based on research
    private let confidenceThreshold: CMMotionActivityConfidence = .medium
    private let stabilizationDelay: TimeInterval = 5.0  // Wait 5s before confirming state changes
    private let maxActivityHistoryCount = 10

    // MARK: - Initialization
    init() {
        print("🎯 [MOTION] MotionDetectionManager initialized")
    }

    // MARK: - Public Interface

    /// Start motion detection using CMMotionActivityManager (Apple's recommended approach)
    func startDetection() {
        guard !isMonitoring else {
            print("⚠️ [MOTION] Already monitoring")
            return
        }

        print("🚀 [MOTION] Starting motion detection...")

        // Check availability
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("❌ [MOTION] Motion activity not available on this device")
            return
        }

        // Request authorization if needed
        let status = CMMotionActivityManager.authorizationStatus()
        print("🔐 [MOTION] Authorization status: \(status.rawValue)")

        if status == .denied {
            print("❌ [MOTION] Motion access denied")
            return
        }

        // Start activity updates
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            self?.processActivity(activity)
        }

        // Start periodic status logging
        startStatusTimer()

        isMonitoring = true
        print("✅ [MOTION] Motion detection started successfully")
    }

    /// Stop motion detection
    func stopDetection() {
        guard isMonitoring else { return }

        print("🛑 [MOTION] Stopping motion detection")
        activityManager.stopActivityUpdates()
        activityTimer?.invalidate()
        activityTimer = nil
        isMonitoring = false
    }

    /// Get current status for debugging
    func getStatusSummary() -> String {
        return """
        Standing: \(isStanding)
        Activity: \(currentActivity)
        Confidence: \(confidence.description)
        Last Update: \(Int(Date().timeIntervalSince(lastUpdate)))s ago
        Consecutive Stationary: \(consecutiveStationaryCount)
        """
    }

    // MARK: - Private Methods

    private func processActivity(_ activity: CMMotionActivity?) {
        guard let activity = activity else {
            print("⚠️ [MOTION] Received nil activity")
            return
        }

        lastUpdate = Date()
        confidence = activity.confidence

        // Add to recent history
        recentActivities.append(activity)
        if recentActivities.count > maxActivityHistoryCount {
            recentActivities.removeFirst()
        }

        // Determine current activity type
        let activityType = determineActivityType(activity)
        let wasStanding = isStanding
        let newStanding = shouldBeStanding(activity: activity, type: activityType)

        // Update current activity description
        DispatchQueue.main.async {
            self.currentActivity = activityType
        }

        // Only process high/medium confidence changes (Apple's recommendation)
        if activity.confidence != .low {
            processStateChange(from: wasStanding, to: newStanding, activity: activity, type: activityType)
        } else {
            print("🔸 [MOTION] Low confidence activity ignored: \(activityType)")
        }
    }

    private func determineActivityType(_ activity: CMMotionActivity) -> String {
        // Use Apple's activity classifications directly
        if activity.walking {
            return "Walking"
        } else if activity.running {
            return "Running"
        } else if activity.automotive {
            return "Driving"
        } else if activity.cycling {
            return "Cycling"
        } else if activity.stationary {
            return "Stationary"
        } else {
            return "Unknown"
        }
    }

    private func shouldBeStanding(activity: CMMotionActivity, type: String) -> Bool {
        // Research-based activity classification
        switch type {
        case "Walking", "Running":
            consecutiveStationaryCount = 0
            return true

        case "Driving", "Cycling":
            consecutiveStationaryCount += 1
            return false

        case "Stationary":
            consecutiveStationaryCount += 1
            // Multiple stationary readings = likely sitting (research finding)
            return consecutiveStationaryCount < 3

        default:
            return isStanding // Maintain current state for unknown activities
        }
    }

    private func processStateChange(from wasStanding: Bool, to newStanding: Bool, activity: CMMotionActivity, type: String) {
        guard wasStanding != newStanding else { return }

        let changeDescription = "\(wasStanding ? "Standing" : "Sitting") → \(newStanding ? "Standing" : "Sitting")"
        print("🔄 [MOTION] State change detected: \(changeDescription) (Activity: \(type), Confidence: \(activity.confidence.description))")

        // Apply stabilization delay for sitting detection (reduce false positives)
        if !newStanding && wasStanding {
            // Standing → Sitting: Apply delay to prevent false sitting detection
            DispatchQueue.main.asyncAfter(deadline: .now() + stabilizationDelay) { [weak self] in
                self?.confirmStateChange(to: newStanding, delayedChange: true)
            }
        } else {
            // Sitting → Standing: Immediate response (important for posture change detection)
            confirmStateChange(to: newStanding, delayedChange: false)
        }
    }

    private func confirmStateChange(to newStanding: Bool, delayedChange: Bool) {
        // Double-check that the state change is still valid
        if delayedChange && consecutiveStationaryCount < 2 {
            print("🚫 [MOTION] Delayed sitting change cancelled - not consistently stationary")
            return
        }

        DispatchQueue.main.async {
            let previousState = self.isStanding ? "Standing" : "Sitting"
            self.isStanding = newStanding
            let newState = newStanding ? "Standing" : "Sitting"

            if newStanding {
                self.standingConfirmedTime = Date()
            }

            print("✅ [MOTION] State confirmed: \(previousState) → \(newState)")

            // Post notification for other components
            NotificationCenter.default.post(
                name: .postureChanged,
                object: nil,
                userInfo: ["isStanding": newStanding, "wasDelayed": delayedChange]
            )
        }
    }

    private func startStatusTimer() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            print("📊 [MOTION] Status: \(self.getStatusSummary())")
        }
    }
}

// MARK: - Extensions

extension CMMotionActivityConfidence {
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        @unknown default: return "Unknown"
        }
    }
}

extension Notification.Name {
    static let postureChanged = Notification.Name("PostureChanged")
}