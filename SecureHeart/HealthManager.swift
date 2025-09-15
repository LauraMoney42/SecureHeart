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
    
    // Emergency monitoring
    var emergencyThresholdCallback: ((Int) -> Void)?
    private var consecutiveHighReadings = 0
    private var consecutiveLowReadings = 0

    // POTS-specific monitoring (enhanced POTS detection)
    var rapidIncreaseCallback: ((Int, Int, TimeInterval) -> Void)? // (current, baseline, timeSpan)
    private var potsCheckTimer: Timer?
    
    init() {
        #if targetEnvironment(simulator)
        // Generate comprehensive medical test data for simulator
        generateRealisticMedicalTestData()
        #else
        // Update current stats - start with 0 for real data
        currentHeartRate = 0  // Will be populated by real heart rate data
        lastUpdated = "Waiting for data..."
        #endif
        
        // Listen for heart rate updates from Apple Watch
        setupWatchConnectivityListeners()

        // Start POTS monitoring (periodic checks for rapid increases)
        startPOTSMonitoring()
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

    // MARK: - POTS-Specific Monitoring (Enhanced Detection)

    private func startPOTSMonitoring() {
        // Check every 30 seconds for POTS diagnostic criteria patterns
        potsCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkForPOTSPatterns()
        }
        print("🩺 [iPhone] POTS monitoring started - checking for rapid increases every 30s")
    }

    private func checkForPOTSPatterns() {
        guard !heartRateHistory.isEmpty else { return }

        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-300) // 5 minutes
        let tenMinutesAgo = now.addingTimeInterval(-600)  // 10 minutes

        // Get readings from the specified time windows
        let recent5Min = heartRateHistory.filter { $0.date >= fiveMinutesAgo }
        let recent10Min = heartRateHistory.filter { $0.date >= tenMinutesAgo }

        guard let currentHR = recent5Min.first?.heartRate,
              let baseline5 = recent5Min.last?.heartRate,
              let baseline10 = recent10Min.last?.heartRate else { return }

        // POTS Diagnostic Criteria #1: +30 BPM increase in 10 minutes (sustained)
        let increase10Min = currentHR - baseline10
        if increase10Min >= 30 && recent10Min.count >= 3 {
            print("🚨 [iPhone] POTS pattern detected: +\(increase10Min) BPM over 10 minutes")
            rapidIncreaseCallback?(currentHR, baseline10, 600) // 10 minutes = 600 seconds
        }

        // POTS Extreme Spike: +40 BPM increase in 5 minutes
        let increase5Min = currentHR - baseline5
        if increase5Min >= 40 && recent5Min.count >= 2 {
            print("🚨 [iPhone] Extreme spike detected: +\(increase5Min) BPM over 5 minutes")
            rapidIncreaseCallback?(currentHR, baseline5, 300) // 5 minutes = 300 seconds
        }
    }

    private func stopPOTSMonitoring() {
        potsCheckTimer?.invalidate()
        potsCheckTimer = nil
        print("🩺 [iPhone] POTS monitoring stopped")
    }

    // MARK: - Emergency Monitoring
    
    private func checkEmergencyThresholds(_ heartRate: Int) {
        let isHighRisk = heartRate > 150 || heartRate < 40
        
        if isHighRisk {
            if heartRate > 150 {
                consecutiveHighReadings += 1
                consecutiveLowReadings = 0
                
                // Trigger emergency after 2 consecutive high readings to avoid false positives
                if consecutiveHighReadings >= 2 {
                    print("🚨 [iPhone] Emergency threshold exceeded: \(heartRate) BPM (high)")
                    emergencyThresholdCallback?(heartRate)
                    consecutiveHighReadings = 0 // Reset to avoid repeated triggers
                }
            } else if heartRate < 40 {
                consecutiveLowReadings += 1
                consecutiveHighReadings = 0
                
                // Trigger emergency after 2 consecutive low readings
                if consecutiveLowReadings >= 2 {
                    print("🚨 [iPhone] Emergency threshold exceeded: \(heartRate) BPM (low)")
                    emergencyThresholdCallback?(heartRate)
                    consecutiveLowReadings = 0 // Reset to avoid repeated triggers
                }
            }
        } else {
            // Reset counters when heart rate returns to normal range
            consecutiveHighReadings = 0
            consecutiveLowReadings = 0
        }
    }
    
    private func updateHeartRateFromWatch(_ heartRate: Int) {
        print("📱 [iPhone] Updating UI with Watch heart rate: \(heartRate)")

        // Check for emergency conditions first
        checkEmergencyThresholds(heartRate)

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

        // Save to persistent storage (privacy-first local storage)
        saveHeartRateEntryToPersistentStorage(entry)

        // Limit in-memory history size (keep last 100 for UI performance)
        if heartRateHistory.count > 100 {
            heartRateHistory.removeFirst()
        }

        print("📱 [iPhone] UI updated - current HR: \(currentHeartRate), history count: \(heartRateHistory.count)")
    }
    
    // MARK: - Privacy-First Local Storage (60-minute history)

    private let heartRateStorageKey = "SecureHeart_HeartRateHistory"
    private let maxStorageDuration: TimeInterval = 3600 // 60 minutes

    private func saveHeartRateEntryToPersistentStorage(_ entry: HeartRateEntry) {
        // PRIVACY-FIRST: Store only in UserDefaults (local device only)
        // NO cloud sync, NO external transmission
        var storedEntries = loadStoredHeartRateHistory()
        storedEntries.append(entry)

        // Clean up entries older than 60 minutes
        let cutoffDate = Date().addingTimeInterval(-maxStorageDuration)
        storedEntries = storedEntries.filter { $0.date > cutoffDate }

        // Convert to storage format
        let storageData = storedEntries.map { entry in
            [
                "heartRate": entry.heartRate,
                "timestamp": entry.date.timeIntervalSince1970,
                "delta": entry.delta,
                "context": entry.context ?? ""
            ]
        }

        UserDefaults.standard.set(storageData, forKey: heartRateStorageKey)
        print("💾 [iPhone] Saved \(storedEntries.count) heart rate entries to local storage")
    }

    private func loadStoredHeartRateHistory() -> [HeartRateEntry] {
        guard let storageData = UserDefaults.standard.array(forKey: heartRateStorageKey) as? [[String: Any]] else {
            return []
        }

        var entries: [HeartRateEntry] = []
        for data in storageData {
            guard let heartRate = data["heartRate"] as? Int,
                  let timestamp = data["timestamp"] as? TimeInterval,
                  let delta = data["delta"] as? Int else { continue }

            let context = data["context"] as? String
            let date = Date(timeIntervalSince1970: timestamp)

            // Only include entries from last 60 minutes
            if date > Date().addingTimeInterval(-maxStorageDuration) {
                let entry = HeartRateEntry(
                    heartRate: heartRate,
                    date: date,
                    delta: delta,
                    context: context?.isEmpty == false ? context : nil
                )
                entries.append(entry)
            }
        }

        // Sort by date (newest first)
        return entries.sorted { $0.date > $1.date }
    }

    func loadPersistentHeartRateHistory() {
        // Load stored heart rate history on app launch
        let storedHistory = loadStoredHeartRateHistory()

        // Merge with any existing in-memory history (avoid duplicates)
        var combinedHistory = heartRateHistory

        for storedEntry in storedHistory {
            let isDuplicate = combinedHistory.contains { entry in
                abs(entry.date.timeIntervalSince(storedEntry.date)) < 1.0 && entry.heartRate == storedEntry.heartRate
            }

            if !isDuplicate {
                combinedHistory.append(storedEntry)
            }
        }

        // Sort and limit
        combinedHistory.sort { $0.date > $1.date }
        if combinedHistory.count > 100 {
            combinedHistory = Array(combinedHistory.prefix(100))
        }

        heartRateHistory = combinedHistory

        if !storedHistory.isEmpty {
            updateStatsFromHistory()
            print("📊 [iPhone] Loaded \(storedHistory.count) entries from persistent storage")
        }
    }

    func getFullHeartRateHistory() -> [HeartRateEntry] {
        // Return complete 60-minute history (for export functionality)
        return loadStoredHeartRateHistory()
    }

    func clearStoredHeartRateHistory() {
        // Privacy function to clear all stored data
        UserDefaults.standard.removeObject(forKey: heartRateStorageKey)
        heartRateHistory.removeAll()
        print("🗑️ [iPhone] Cleared all stored heart rate history")
    }

    // MARK: - Request Authorization for Real Device
    func requestAuthorization() {
        // Load any existing persistent data first
        loadPersistentHeartRateHistory()

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
    
    // MARK: - Cleanup
    func stopObserving() {
        stopPOTSMonitoring()
    }

    deinit {
        stopPOTSMonitoring()
    }
    
    // MARK: - Realistic Medical Test Data Generation
    private func generateRealisticMedicalTestData() {
        heartRateHistory = []
        let now = Date()
        let calendar = Calendar.current

        // Generate 30 days of data for weekly/monthly trend analysis
        var currentTime = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let endTime = now

        var lastHeartRate = 72 // Starting baseline

        print("📊 [SAMPLE] Generating 30 days of realistic POTS test data...")

        while currentTime < endTime {
            let dayOfWeek = calendar.component(.weekday, from: currentTime) // 1 = Sunday, 7 = Saturday
            let hourOfDay = calendar.component(.hour, from: currentTime)
            let minuteOfHour = calendar.component(.minute, from: currentTime)
            let daysSinceStart = calendar.dateComponents([.day], from: calendar.date(byAdding: .day, value: -30, to: now)!, to: currentTime).day ?? 0

            // Create weekly patterns for POTS patients
            let weeklyStressLevel = getWeeklyStressLevel(dayOfWeek: dayOfWeek, daysElapsed: daysSinceStart)

            // Determine if this should be a special medical event
            let (heartRate, context, delta) = generateMedicalEventDataWithWeeklyPattern(
                hour: hourOfDay,
                minute: minuteOfHour,
                baseline: lastHeartRate,
                currentTime: currentTime,
                weeklyStress: weeklyStressLevel
            )

            let entry = HeartRateEntry(
                heartRate: heartRate,
                date: currentTime,
                delta: delta,
                context: context
            )

            heartRateHistory.append(entry)
            lastHeartRate = heartRate

            // Advance time - more frequent during active hours (6am-10pm), less at night
            let minutesAdvance: Int
            if hourOfDay >= 6 && hourOfDay <= 22 {
                minutesAdvance = Int.random(in: 3...8) // More frequent monitoring during active hours
            } else {
                minutesAdvance = Int.random(in: 15...30) // Less frequent at night
            }

            currentTime = calendar.date(byAdding: .minute, value: minutesAdvance, to: currentTime) ?? currentTime
        }

        // Sort by date (newest first for our UI)
        heartRateHistory.sort { $0.date > $1.date }

        print("📊 Generated \(heartRateHistory.count) realistic medical test data points over 30 days")

        // Update current stats from the generated data
        updateStatsFromHistory()
    }

    private func getWeeklyStressLevel(dayOfWeek: Int, daysElapsed: Int) -> Double {
        // Simulate weekly patterns for POTS patients
        // Monday (high stress/symptoms), Wed-Fri (moderate), Weekend (lower)

        var baseStress: Double
        switch dayOfWeek {
        case 2: // Monday - "Monday flare"
            baseStress = 0.8
        case 3, 4: // Tuesday, Wednesday - recovering
            baseStress = 0.6
        case 5, 6: // Thursday, Friday - moderate
            baseStress = 0.5
        case 7, 1: // Saturday, Sunday - better rest days
            baseStress = 0.3
        default:
            baseStress = 0.5
        }

        // Add monthly variation (some weeks worse than others)
        let weekNumber = daysElapsed / 7
        let monthlyModifier: Double
        switch weekNumber {
        case 0: // First week - baseline
            monthlyModifier = 0.0
        case 1: // Second week - slightly better
            monthlyModifier = -0.1
        case 2: // Third week - worse (hormonal/stress factors)
            monthlyModifier = 0.2
        case 3: // Fourth week - improving
            monthlyModifier = -0.05
        default:
            monthlyModifier = 0.0
        }

        return min(1.0, max(0.0, baseStress + monthlyModifier))
    }

    private func generateMedicalEventDataWithWeeklyPattern(
        hour: Int,
        minute: Int,
        baseline: Int,
        currentTime: Date,
        weeklyStress: Double
    ) -> (heartRate: Int, context: String, delta: Int) {

        // Base heart rate adjusted for weekly stress pattern
        var baseHR = baseline
        let stressModifier = Int(weeklyStress * 10) // 0-10 BPM increase based on stress
        baseHR += stressModifier

        // Time-of-day patterns
        var timeModifier = 0
        switch hour {
        case 0...5: // Night - lower
            timeModifier = -8
        case 6...9: // Morning - POTS patients often struggle
            timeModifier = 5
        case 10...14: // Midday - moderate
            timeModifier = 2
        case 15...18: // Afternoon - varies
            timeModifier = 0
        case 19...23: // Evening - slightly elevated
            timeModifier = 3
        default:
            timeModifier = 0
        }

        baseHR += timeModifier

        // Check for orthostatic episodes (more frequent during high stress periods)
        let episodeProbability = weeklyStress * 0.15 // 0-15% chance based on stress
        let isEpisode = Double.random(in: 0...1) < episodeProbability

        var finalHR = baseHR
        var context = "Sitting"
        var delta = Int.random(in: -5...8)

        if isEpisode {
            // POTS episode - severity influenced by weekly stress
            let episodeSeverity = weeklyStress
            let increase = Int(25 + episodeSeverity * 30) // 25-55 BPM increase
            finalHR = baseHR + increase + Int.random(in: -5...10)
            context = "Standing"
            delta = increase
        } else {
            // Normal standing occasionally
            if Int.random(in: 1...100) <= 20 { // 20% standing
                context = "Standing"
                let normalIncrease = Int.random(in: 8...18) // Normal standing response
                finalHR = baseHR + normalIncrease
                delta = normalIncrease
            } else {
                // Normal sitting variability
                finalHR = baseHR + Int.random(in: -8...12)
            }
        }

        // Ensure realistic bounds
        finalHR = max(55, min(160, finalHR))

        return (finalHR, context, delta)
    }

    private func updateStatsFromHistory() {
        guard !heartRateHistory.isEmpty else { return }

        // Set current heart rate to the most recent entry
        currentHeartRate = heartRateHistory.first?.heartRate ?? 72

        // Also set live heart rate for simulator so UI shows data
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.liveHeartRate = self.currentHeartRate
            self.isWatchConnected = true // Simulate watch connection for better UI experience
            print("🔧 [SIMULATOR] Setting liveHeartRate to \(self.currentHeartRate), isWatchConnected: \(self.isWatchConnected)")
        }
        #endif

        // Calculate stats from today's data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaysEntries = heartRateHistory.filter { entry in
            entry.date >= today
        }

        if !todaysEntries.isEmpty {
            let heartRates = todaysEntries.map { $0.heartRate }
            averageHeartRate = heartRates.reduce(0, +) / heartRates.count
            minHeartRate = heartRates.min() ?? 48
            maxHeartRate = heartRates.max() ?? 162
        }

        lastUpdated = "Just now"
        isAuthorized = true

        print("📊 Updated current stats - HR: \(currentHeartRate), Avg: \(averageHeartRate), Min: \(minHeartRate), Max: \(maxHeartRate)")
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