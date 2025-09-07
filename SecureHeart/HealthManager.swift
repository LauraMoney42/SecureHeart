//
//  HealthManager.swift
//  Secure Heart
//
//  HealthKit Manager for iPhone App
//

import Foundation
import SwiftUI

// MARK: - Heart Rate Entry Model
struct HeartRateEntry: Identifiable {
    let id = UUID()
    let heartRate: Int
    let date: Date
    let delta: Int
    let context: String? // Context like "Standing", "Sitting", etc.
    
    init(heartRate: Int, date: Date, delta: Int = 0, context: String? = nil) {
        self.heartRate = heartRate
        self.date = date
        self.delta = delta
        self.context = context
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a MM/dd/yy"
        return formatter.string(from: date)
    }
    
    var deltaText: String {
        guard abs(delta) >= 30 else { return "" } // Only show changes of 30+ BPM
        let arrow = delta > 0 ? "↑" : "↓"
        return "\(arrow)\(abs(delta))"
    }
}

// MARK: - Orthostatic Event Model
struct OrthostaticEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let baselineHeartRate: Int
    let peakHeartRate: Int
    let increase: Int
    let severity: String
    let sustainedDuration: TimeInterval // How long heart rate stayed elevated (30+ BPM)
    let recoveryTime: TimeInterval? // Time to recover to within 10 BPM of baseline, nil if not recovered
    let isRecovered: Bool // Whether heart rate returned to near baseline
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var description: String {
        let sustainedText = sustainedDuration >= 60 ? String(format: " (sustained %.0f min)", sustainedDuration / 60) : ""
        let recoveryText = if let recoveryTime = recoveryTime {
            String(format: ", recovered in %.0fs", recoveryTime)
        } else if isRecovered {
            ", recovered"
        } else {
            ", not recovered"
        }
        return "\(severity): +\(increase) BPM when standing\(sustainedText)\(recoveryText)"
    }
    
    var clinicalSummary: String {
        let severityIndicator = sustainedDuration >= 600 && increase >= 30 ? " [Sustained Response]" : ""
        return "Peak: +\(increase) BPM, Sustained: \(Int(sustainedDuration))s\(severityIndicator)"
    }
    
    var sustainedMinutes: String {
        if sustainedDuration < 60 {
            return "\(Int(sustainedDuration))s"
        } else {
            return String(format: "%.1f min", sustainedDuration / 60)
        }
    }
    
    var recoveryText: String {
        if let recovery = recoveryTime {
            if recovery < 60 {
                return "\(Int(recovery))s"
            } else {
                return String(format: "%.1f min", recovery / 60)
            }
        } else if isRecovered {
            return "Yes"
        } else {
            return "None"
        }
    }
}

// MARK: - Health Manager
class HealthManager: ObservableObject {
    @Published var currentHeartRate: Int = 72
    @Published var averageHeartRate: Int = 78
    @Published var minHeartRate: Int = 48
    @Published var maxHeartRate: Int = 162
    @Published var lastUpdated: String = "Just now"
    @Published var heartRateHistory: [HeartRateEntry] = []
    @Published var isAuthorized = false
    @Published var isWatchConnected: Bool = false
    @Published var liveHeartRate: Int = 0  // Real-time from watch
    @Published var heartRateDelta: Int = 0  // Change from previous reading
    @Published var recentAverageHeartRate: Int = 0  // 5-minute moving average
    @Published var deltaFromAverage: Int = 0  // Current HR vs Recent Average (for standing response monitoring)
    @Published var orthostaticEvents: [OrthostaticEvent] = [] // Orthostatic events from watch
    
    init() {
        // COMMENTED OUT FOR REAL DEVICE TESTING
        // Generate comprehensive medical test data
        // generateRealisticMedicalTestData()
        
        // Update current stats - start with 0 for real data
        currentHeartRate = 0  // Will be populated by real heart rate data
        lastUpdated = "Waiting for data..."
        
        // Listen for heart rate updates from Apple Watch
        setupWatchConnectivityListeners()
    }
    
    private func setupWatchConnectivityListeners() {
        print("📱 [iPhone] Setting up WatchConnectivity listeners in HealthManager")
        
        // Listen for heart rate updates
        NotificationCenter.default.addObserver(
            forName: Notification.Name("HeartRateUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let heartRate = notification.userInfo?["heartRate"] as? Int {
                print("📱 [iPhone] HealthManager received heart rate: \(heartRate)")
                self?.updateHeartRateFromWatch(heartRate)
            }
        }
        
        // Listen for heart rate delta updates
        NotificationCenter.default.addObserver(
            forName: Notification.Name("HeartRateDeltaUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let delta = notification.userInfo?["delta"] as? Int {
                print("📱 [iPhone] HealthManager received delta: \(delta)")
                self?.deltaFromAverage = delta
            }
        }
    }
    
    private func updateHeartRateFromWatch(_ heartRate: Int) {
        print("📱 [iPhone] Updating UI with Watch heart rate: \(heartRate)")
        
        // Update current heart rate
        currentHeartRate = heartRate
        liveHeartRate = heartRate
        lastUpdated = "Just now"
        
        // Add to history
        let entry = HeartRateEntry(
            heartRate: heartRate,
            date: Date(),
            delta: deltaFromAverage,
            context: "From Apple Watch"
        )
        heartRateHistory.append(entry)
        
        // Limit history size
        if heartRateHistory.count > 100 {
            heartRateHistory.removeFirst()
        }
        
        print("📱 [iPhone] UI updated - current HR: \(currentHeartRate), history count: \(heartRateHistory.count)")
    }
    
    // MARK: - Request Authorization for Real Device
    func requestAuthorization() {
        // For real device testing - iPhone will receive data from Watch via WatchConnectivity
        // No direct HealthKit access needed on iPhone, just mark as authorized for UI
        DispatchQueue.main.async {
            self.isAuthorized = true
        }
    }
    
    // MARK: - Daily Test Data Generation
    private func generateDailyTestData() {
        // Simple test data for now - will elaborate later
        var entries: [HeartRateEntry] = []
        let now = Date()
        
        // Generate 24 data points (hourly) with realistic patterns
        for i in 0..<24 {
            let timeOffset = TimeInterval(i * 60 * 60) // 1 hour intervals
            let timestamp = now.addingTimeInterval(-timeOffset)
            let hour = 23 - i // Count backwards from current hour
            
            // Simple heart rate based on time of day
            let heartRate = getSimpleHeartRateForHour(hour)
            let delta = entries.isEmpty ? 0 : heartRate - entries.last!.heartRate
            
            let entry = HeartRateEntry(
                heartRate: heartRate,
                date: timestamp,
                delta: delta,
                context: nil
            )
            
            entries.append(entry)
        }
        
        DispatchQueue.main.async {
            self.heartRateHistory = entries
            self.updateLiveStatsFromHistory()
            print("📊 [iPhone] Generated \(entries.count) heart rate entries for daily graph")
        }
    }
    
    private func getSimpleHeartRateForHour(_ hour: Int) -> Int {
        switch hour {
        case 0...5: return Int.random(in: 45...55)    // Sleep
        case 6...7: return Int.random(in: 60...75)    // Wake up
        case 8: return Int.random(in: 90...110)       // Morning stress spike
        case 9...11: return Int.random(in: 70...80)   // Work
        case 12: return Int.random(in: 85...105)      // Lunch activity
        case 13...16: return Int.random(in: 68...78)  // Afternoon
        case 17: return Int.random(in: 110...130)     // Exercise spike (moderated for demo)
        case 18: return Int.random(in: 85...100)      // Recovery - FIXED range
        case 19...21: return Int.random(in: 70...80)  // Evening
        case 22...23: return Int.random(in: 60...70)  // Pre-sleep
        default: return 72
        }
    }
    
    private func updateLiveStatsFromHistory() {
        guard !heartRateHistory.isEmpty else { return }
        
        let heartRates = heartRateHistory.map { $0.heartRate }
        minHeartRate = heartRates.min() ?? 0
        maxHeartRate = heartRates.max() ?? 0
        averageHeartRate = heartRates.reduce(0, +) / heartRates.count
        
        // Set current heart rate to the most recent reading
        currentHeartRate = heartRateHistory.first?.heartRate ?? 0
        
        // Calculate delta monitoring metrics
        updateDeltaMonitoring()
        
        lastUpdated = "Just now"
    }
    
    // MARK: - Delta Monitoring System
    private func updateDeltaMonitoring() {
        guard !heartRateHistory.isEmpty else {
            recentAverageHeartRate = 0
            deltaFromAverage = 0
            return
        }
        
        // Calculate 5-minute moving average (or last 5-10 readings)
        let recentReadings = Array(heartRateHistory.prefix(10)) // Last 10 readings (~5-10 minutes)
        let recentHeartRates = recentReadings.map { $0.heartRate }
        recentAverageHeartRate = recentHeartRates.reduce(0, +) / max(recentHeartRates.count, 1)
        
        // Calculate delta from recent average
        deltaFromAverage = currentHeartRate - recentAverageHeartRate
        
        // Update the traditional delta (previous reading)
        if heartRateHistory.count >= 2 {
            let previousReading = heartRateHistory[1].heartRate
            heartRateDelta = currentHeartRate - previousReading
        } else {
            heartRateDelta = 0
        }
    }
    
    // MARK: - Delta Monitoring Helpers
    func isDeltaSignificant() -> Bool {
        return abs(deltaFromAverage) >= 30  // Standing response threshold
    }
    
    func getDeltaDescription() -> String {
        if !isDeltaSignificant() {
            return ""
        }
        
        let direction = deltaFromAverage > 0 ? "above" : "below"
        return "\(abs(deltaFromAverage)) BPM \(direction) recent average"
    }
    
    func getDeltaIcon() -> String {
        if !isDeltaSignificant() {
            return ""
        }
        return deltaFromAverage > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
    
    func getDeltaColor() -> Color {
        if !isDeltaSignificant() {
            return .secondary
        }
        
        // For standing response monitoring: increases are more concerning than decreases
        if deltaFromAverage >= 30 {
            return .red  // Potential standing response
        } else if deltaFromAverage <= -30 {
            return .orange  // Significant drop
        } else {
            return .secondary
        }
    }
    
    // MARK: - Simplified cleanup (no-op for demo)
    func stopObserving() {
        // Simplified for demo
    }
    
    // MARK: - Realistic Medical Test Data Generation
    private func generateRealisticMedicalTestData() {
        heartRateHistory = []
        let now = Date()
        let calendar = Calendar.current
        
        // Generate data every 2-5 minutes over 24 hours for realistic density
        var currentTime = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        let endTime = now
        
        var lastHeartRate = 72 // Starting baseline
        
        while currentTime < endTime {
            let hourOfDay = calendar.component(.hour, from: currentTime)
            let minuteOfHour = calendar.component(.minute, from: currentTime)
            
            // Determine if this should be a special medical event
            let (heartRate, context, delta) = generateMedicalEventData(
                hour: hourOfDay,
                minute: minuteOfHour,
                baseline: lastHeartRate,
                currentTime: currentTime
            )
            
            let entry = HeartRateEntry(
                heartRate: heartRate,
                date: currentTime,
                delta: delta,
                context: context
            )
            
            heartRateHistory.append(entry)
            lastHeartRate = heartRate
            
            // Advance time by 2-5 minutes randomly for realistic spacing
            let minutesAdvance = Int.random(in: 2...5)
            currentTime = calendar.date(byAdding: .minute, value: minutesAdvance, to: currentTime) ?? currentTime
        }
        
        // Sort by date (newest first for our UI)
        heartRateHistory.sort { $0.date > $1.date }
        
        print("📊 Generated \(heartRateHistory.count) realistic medical test data points")
    }
    
    private func generateMedicalEventData(hour: Int, minute: Int, baseline: Int, currentTime: Date) -> (heartRate: Int, context: String?, delta: Int) {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: currentTime) ?? 1
        
        // Create pseudo-random but consistent events based on time
        let timeHash = hour * 100 + minute + dayOfYear
        
        // Check for specific medical events
        
        // 1. TACHYCARDIA EPISODES - Sustained high heart rate (moderated for demo)
        if shouldGenerateTachycardiaEvent(hour: hour, minute: minute, timeHash: timeHash) {
            let tachyHeartRate = Int.random(in: 125...145) // Reduced from 155-185
            let delta = tachyHeartRate - baseline
            let _ = Int.random(in: 8...25) // 8-25 minutes (unused for now)
            return (tachyHeartRate, "Elevated episode", delta) // Removed "Standing" for MVP2
        }
        
        // 2. BRADYCARDIA EPISODES - Sustained low heart rate (moderated for demo)
        if shouldGenerateBradycardiaEvent(hour: hour, minute: minute, timeHash: timeHash) {
            let bradyHeartRate = Int.random(in: 50...58) // Raised from 35-48
            let delta = bradyHeartRate - baseline
            return (bradyHeartRate, "Low HR", delta) // Removed "Sitting" for MVP2
        }
        
        // 3. ARRHYTHMIA PATTERNS - Irregular rhythms
        if shouldGenerateArrhythmiaEvent(hour: hour, minute: minute, timeHash: timeHash) {
            let irregularRate = baseline + Int.random(in: -25...25)
            let boundedRate = max(45, min(140, irregularRate)) // Keep in reasonable bounds
            let delta = boundedRate - baseline
            return (boundedRate, "Irregular rhythm detected", delta)
        }
        
        // 4. ORTHOSTATIC EVENTS - Standing transitions (moderated for demo)
        if shouldGenerateOrthostaticEvent(hour: hour, minute: minute, timeHash: timeHash) {
            let orthoHeartRate = baseline + Int.random(in: 25...45) // Reduced from 35-65
            let delta = orthoHeartRate - baseline
            return (orthoHeartRate, "Elevated +\(delta)BPM", delta) // Removed "Standing" for MVP2
        }
        
        // 5. SITTING RECOVERY EVENTS
        if shouldGenerateSittingEvent(hour: hour, minute: minute, timeHash: timeHash) {
            let sittingRate = max(50, baseline - Int.random(in: 15...35))
            let delta = sittingRate - baseline
            return (sittingRate, "Recovery \(delta)BPM", delta) // Removed "Sitting" for MVP2
        }
        
        // 6. NORMAL VARIATIONS with activity context
        let normalRate = getNormalHeartRateForHour(hour)
        let variation = Int.random(in: -8...8)
        let finalRate = max(45, min(150, normalRate + variation))
        let delta = finalRate - baseline
        
        // Add occasional activity context to normal readings - Commented out for MVP2
        // let context: String? = timeHash % 15 == 0 ? (finalRate > 90 ? "Standing" : "Sitting") : nil
        let context: String? = nil // No posture context for MVP2
        
        return (finalRate, context, delta)
    }
    
    // Medical event probability functions
    private func shouldGenerateTachycardiaEvent(hour: Int, minute: Int, timeHash: Int) -> Bool {
        // More likely during stress periods: morning rush, afternoon stress
        let highStressHours = [8, 9, 14, 15, 16]
        let stressFactor = highStressHours.contains(hour) ? 3 : 1
        return timeHash % (150 / stressFactor) == 0
    }
    
    private func shouldGenerateBradycardiaEvent(hour: Int, minute: Int, timeHash: Int) -> Bool {
        // More likely during rest periods: early morning, late evening
        let restHours = [2, 3, 4, 5, 23, 0, 1]
        let restFactor = restHours.contains(hour) ? 2 : 1
        return timeHash % (200 / restFactor) == 0
    }
    
    private func shouldGenerateArrhythmiaEvent(hour: Int, minute: Int, timeHash: Int) -> Bool {
        // Can happen any time, but slightly more during sleep
        let sleepHours = [0, 1, 2, 3, 4, 5, 6]
        let sleepFactor = sleepHours.contains(hour) ? 2 : 1
        return timeHash % (180 / sleepFactor) == 0
    }
    
    private func shouldGenerateOrthostaticEvent(hour: Int, minute: Int, timeHash: Int) -> Bool {
        // More likely during active hours when standing frequently
        let activeHours = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
        let activeFactor = activeHours.contains(hour) ? 4 : 1
        return timeHash % (120 / activeFactor) == 0
    }
    
    private func shouldGenerateSittingEvent(hour: Int, minute: Int, timeHash: Int) -> Bool {
        // More likely during work/rest hours
        let sittingHours = [9, 10, 11, 13, 14, 15, 19, 20, 21, 22]
        let sittingFactor = sittingHours.contains(hour) ? 3 : 1
        return timeHash % (100 / sittingFactor) == 0
    }
    
    private func getNormalHeartRateForHour(_ hour: Int) -> Int {
        switch hour {
        case 0...5: return Int.random(in: 45...55)    // Sleep
        case 6...7: return Int.random(in: 60...75)    // Wake up
        case 8: return Int.random(in: 70...90)        // Morning routine
        case 9...11: return Int.random(in: 65...80)   // Morning work
        case 12: return Int.random(in: 75...95)       // Lunch activity
        case 13...16: return Int.random(in: 68...78)  // Afternoon work
        case 17: return Int.random(in: 90...120)      // Evening activity
        case 18: return Int.random(in: 75...85)       // Early evening
        case 19...21: return Int.random(in: 70...80)  // Evening
        case 22...23: return Int.random(in: 60...70)  // Pre-sleep
        default: return 72
        }
    }
    
    // MARK: - Heart Rate Zone Colors
    func heartRateColor(for heartRate: Int) -> Color {
        switch heartRate {
        case 0:
            return .gray
        case 1..<60:
            return .blue        // Low/Resting
        case 60..<100:
            return .green       // Normal
        case 100..<140:
            return .yellow      // Moderate
        case 140..<170:
            return .orange      // High
        default:
            return .red         // Maximum/Very High
        }
    }
    
    func heartRateZone(for heartRate: Int) -> String {
        switch heartRate {
        case 0:
            return "No Reading"
        case 1..<60:
            return "Low"
        case 60..<100:
            return "Normal"
        case 100..<140:
            return "Elevated"
        case 140..<170:
            return "High"
        default:
            return "Maximum"
        }
    }
    
}