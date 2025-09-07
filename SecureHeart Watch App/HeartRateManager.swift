//
//  HeartRateManager.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import Foundation
import HealthKit
import CoreMotion
#if canImport(WatchKit)
import WatchKit
#endif

class HeartRateManager: NSObject, ObservableObject {
    static let sharedInstance = HeartRateManager()
    static var shared: HeartRateManager? {
        return sharedInstance
    }
    
    let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private let heartRateQuantityType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    
    @Published var currentHeartRate: Int = 0
    @Published var heartRateHistory: [HeartRateReading] = []
    @Published var isAuthorized = false
    @Published var isMonitoring = false
    @Published var heartRateDelta: Int = 0
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var significantChanges: [SignificantChange] = []
    
    // Orthostatic monitoring
    @Published var orthostaticEvents: [OrthostaticEvent] = []
    @Published var isStanding = false
    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private var standingStartTime: Date?
    private var standingBaselineHeartRate: Int = 0
    private var debugCounter = 0
    private var lastActivityUpdate = Date()
    private var consecutiveStationaryCount = 0
    
    // Enhanced feature extraction (inspired by Swift-HAR)
    private var xAxisSamples: [Double] = []
    private var yAxisSamples: [Double] = []
    private var zAxisSamples: [Double] = []
    private var movementFrequencySamples: [Double] = []
    private var lastWristAnalysis = Date()
    private var postureConfidence: Double = 0.5 // Start neutral
    
    // Enhanced sustained elevation tracking
    private var currentOrthostaticEvent: OrthostaticEvent?
    private var elevatedStartTime: Date? // When heart rate first exceeded baseline + 30
    private var heartRatePattern: [OrthostaticEvent.HeartRatePoint] = []
    private var isCurrentlyElevated = false
    private var recoveryStartTime: Date? // When recovery began
    private var hasRecovered = false
    
    private let maxHistoryDuration: TimeInterval = 3600 // 60 minutes
    private var previousHeartRate: Int = 0
    private var baselineHeartRate: Int = 0
    private var lastAlertTime = Date()
    
    // Alert thresholds
    private let minorChangeThreshold = 30  // Alert for 30 bpm change
    private let majorChangeThreshold = 50  // Alert for 50 bpm change
    private let alertCooldown: TimeInterval = 30 // Don't repeat alerts for 30 seconds
    
    // Recording interval (configurable via settings)
    @Published var recordingInterval: TimeInterval = 60.0
    
    struct HeartRateReading: Identifiable {
        let id = UUID()
        let heartRate: Int
        let timestamp: Date
        let delta: Int
        let context: String?
        
        init(heartRate: Int, timestamp: Date, delta: Int = 0, context: String? = nil) {
            self.heartRate = heartRate
            self.timestamp = timestamp
            self.delta = delta
            self.context = context
        }
        
        var color: String {
            if heartRate < 80 {
                return "blue"
            } else if heartRate >= 80 && heartRate <= 120 {
                return "green"
            } else if heartRate > 120 && heartRate <= 150 {
                return "yellow"
            } else {
                return "red"
            }
        }
        
        var deltaText: String {
            guard abs(delta) >= 30 else { return "" } // Only show changes of 30+ BPM
            let arrow = delta > 0 ? "↑" : "↓"
            return "\(arrow)\(abs(delta))"
        }
        
        var formattedDateTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a MM/dd/yy"
            return formatter.string(from: timestamp)
        }
    }
    
    struct SignificantChange: Identifiable {
        let id = UUID()
        let timestamp: Date
        let fromRate: Int
        let toRate: Int
        let delta: Int
        let isMajor: Bool // true if 50+ bpm change
        
        var description: String {
            "\(delta > 0 ? "↑" : "↓") \(abs(delta)) BPM"
        }
    }
    
    struct OrthostaticEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let baselineHeartRate: Int
        let peakHeartRate: Int
        let increase: Int
        let duration: TimeInterval // Total standing duration when event was detected
        let sustainedDuration: TimeInterval // How long heart rate stayed elevated (30+ BPM)
        let recoveryTime: TimeInterval? // Time to recover to within 10 BPM of baseline, nil if not recovered
        let heartRatePattern: [HeartRatePoint] // Heart rate measurements during the event
        let isRecovered: Bool // Whether heart rate returned to near baseline
        
        struct HeartRatePoint {
            let heartRate: Int
            let timeFromStanding: TimeInterval // Seconds since standing started
        }
        
        var severity: OrthostacSeverity {
            // Enhanced severity based on both peak increase and sustained duration
            let baseSeverity = switch increase {
            case 30..<40: OrthostacSeverity.mild
            case 40..<50: OrthostacSeverity.moderate
            case 50...: OrthostacSeverity.severe
            default: OrthostacSeverity.normal
            }
            
            // Upgrade severity for sustained elevation (clinical criteria: 30+ BPM for 10+ minutes)
            if sustainedDuration >= 600 && increase >= 30 { // 10 minutes sustained
                return .severe
            } else if sustainedDuration >= 180 { // 3+ minutes sustained
                return baseSeverity == .mild ? .moderate : baseSeverity
            }
            
            return baseSeverity
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
            return "Standing: +\(increase) BPM (\(baselineHeartRate)→\(peakHeartRate))\(sustainedText)\(recoveryText)"
        }
        
        var clinicalSummary: String {
            let severityIndicator = sustainedDuration >= 600 && increase >= 30 ? " [Sustained Response]" : ""
            return "Peak: +\(increase) BPM, Sustained: \(Int(sustainedDuration))s\(severityIndicator)"
        }
    }
    
    enum OrthostacSeverity: String, CaseIterable {
        case normal = "Normal"
        case mild = "Mild Response"
        case moderate = "Moderate Response"
        case severe = "Significant Response"
        
        var color: String {
            switch self {
            case .normal: return "green"
            case .mild: return "yellow"
            case .moderate: return "orange"
            case .severe: return "red"
            }
        }
    }
    
    override init() {
        super.init()
        print("🚀 [WATCH] HeartRateManager initializing...")
        requestAuthorization()
        
        // Initialize motion detection for orthostatic monitoring
        startMotionDetection()
        
        // Start monitoring after a short delay for authorization
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🏁 [WATCH] Starting continuous monitoring after delay...")
            self.startContinuousMonitoring()
            // Also do an immediate fetch
            self.fetchLatestHeartRate()
        }
        
        // Listen for recording interval updates from iPhone
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingIntervalUpdate),
            name: Notification.Name("RecordingIntervalUpdated"),
            object: nil
        )
        
        // COMMENTED OUT FOR REAL DEVICE TESTING
        // #if DEBUG && targetEnvironment(simulator)
        // // Add test data for simulator testing
        // addTestData()
        // #endif
    }
    
    #if DEBUG
    private var simulationTimer: Timer?
    private var orthostaticTestTimer: Timer?
    
    private func addTestData() {
        let testRates = [72, 85, 93, 110, 125, 145, 160, 135, 95, 78]
        for (index, rate) in testRates.enumerated() {
            let reading = HeartRateReading(
                heartRate: rate, 
                timestamp: Date().addingTimeInterval(-Double(index * 60))
            )
            heartRateHistory.append(reading)
        }
        currentHeartRate = testRates.first ?? 72
        
        // Add some test orthostatic events for demonstration
        addTestOrthostaticEvents()
        
        // Simulate changing heart rate based on recording interval setting
        simulationTimer = Timer.scheduledTimer(withTimeInterval: recordingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let randomRate = Int.random(in: 60...180)
            DispatchQueue.main.async {
                let previousRate = self.heartRateHistory.last?.heartRate ?? 0
                let delta = previousRate > 0 ? randomRate - previousRate : 0
                var context: String? = nil
                
                // Generate context for significant changes
                if abs(delta) >= 30 {
                    if delta > 0 {
                        context = "Standing +\(delta)BPM"
                    } else {
                        context = "Sitting \(delta)BPM"
                    }
                }
                
                self.updateHeartRate(randomRate)
                let reading = HeartRateReading(heartRate: randomRate, timestamp: Date(), delta: delta, context: context)
                
                // Only add significant readings to history
                if self.shouldRecordHeartRateEntry(heartRate: randomRate, delta: delta) {
                    self.heartRateHistory.append(reading)
                    print("📊 [WATCH] Recording significant HR event: \(randomRate) BPM (Δ\(delta))")
                }
                
                self.cleanupHistory()
            }
        }
        
        // Simulate orthostatic events every 30 seconds for testing
        orthostaticTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.simulateOrthostaticEvent()
        }
    }
    
    private func addTestOrthostaticEvents() {
        // Realistic standing response test data for comprehensive testing
        
        // Standing Response #1: Classic pattern - sustained high HR with slow recovery
        let episode1 = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            baseline: 68,
            peakHR: 112, // +44 BPM (significant response: 30+ BPM)
            sustainedMinutes: 12.5, // Sustained for 12.5 minutes (sustained response criteria: 10+ min)
            recoverySeconds: 180, // 3 minute recovery
            hasFullRecovery: true
        )
        orthostaticEvents.append(episode1)
        
        // Standing Response #2: Severe response with incomplete recovery
        let episode2 = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            baseline: 72,
            peakHR: 128, // +56 BPM (severe increase)
            sustainedMinutes: 8.2, // 8+ minutes sustained
            recoverySeconds: nil, // No recovery - remained elevated
            hasFullRecovery: false
        )
        orthostaticEvents.append(episode2)
        
        // Normal Orthostatic Response (for comparison)
        let normalResponse = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            baseline: 76,
            peakHR: 98, // +22 BPM (normal response)
            sustainedMinutes: 0.8, // Brief elevation
            recoverySeconds: 45, // Quick recovery
            hasFullRecovery: true
        )
        orthostaticEvents.append(normalResponse)
        
        // Mild Response Pattern
        let mildResponse = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-450), // 7.5 minutes ago
            baseline: 70,
            peakHR: 105, // +35 BPM
            sustainedMinutes: 6.3, // 6+ minutes sustained
            recoverySeconds: 95, // Moderate recovery time
            hasFullRecovery: true
        )
        orthostaticEvents.append(mildResponse)
        
        print("🩺 [TEST] Created standing response test data with sustained elevations and recovery patterns")
        
        // Send test data to iPhone for dashboard display (delayed to ensure WatchConnectivity is ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sendTestOrthostaticEventsToiPhone()
        }
    }
    
    private func createStandingResponseEpisode(timestamp: Date, baseline: Int, peakHR: Int, sustainedMinutes: Double, recoverySeconds: Double?, hasFullRecovery: Bool) -> OrthostaticEvent {
        let increase = peakHR - baseline
        let sustainedDuration = sustainedMinutes * 60 // Convert to seconds
        let totalStandingDuration = sustainedDuration + (recoverySeconds ?? 0) + 30 // Add buffer
        
        // Create realistic heart rate pattern for the episode
        let pattern = generateRealisticHeartRatePattern(
            baseline: baseline,
            peak: peakHR,
            sustainedDuration: sustainedDuration,
            recoveryDuration: recoverySeconds ?? 0
        )
        
        return OrthostaticEvent(
            timestamp: timestamp,
            baselineHeartRate: baseline,
            peakHeartRate: peakHR,
            increase: increase,
            duration: totalStandingDuration,
            sustainedDuration: sustainedDuration,
            recoveryTime: recoverySeconds,
            heartRatePattern: pattern,
            isRecovered: hasFullRecovery
        )
    }
    
    private func generateRealisticHeartRatePattern(baseline: Int, peak: Int, sustainedDuration: TimeInterval, recoveryDuration: TimeInterval) -> [OrthostaticEvent.HeartRatePoint] {
        var pattern: [OrthostaticEvent.HeartRatePoint] = []
        
        // Phase 1: Initial rise (0-30 seconds)
        let risePoints = 6
        for i in 0..<risePoints {
            let time = Double(i) * 5.0 // Every 5 seconds
            let progress = Double(i) / Double(risePoints - 1)
            let hr = baseline + Int(Double(peak - baseline) * progress)
            pattern.append(OrthostaticEvent.HeartRatePoint(heartRate: hr, timeFromStanding: time))
        }
        
        // Phase 2: Sustained elevation (30 seconds to sustainedDuration)
        let sustainedPoints = Int(sustainedDuration / 15) // Every 15 seconds during sustained phase
        for i in 0..<sustainedPoints {
            let time = 30.0 + (Double(i) * 15.0)
            // Add realistic variation (±3-8 BPM) during sustained phase
            let variation = Int.random(in: -5...8)
            let hr = min(max(peak + variation, baseline + 25), peak + 10) // Keep within reasonable bounds
            pattern.append(OrthostaticEvent.HeartRatePoint(heartRate: hr, timeFromStanding: time))
        }
        
        // Phase 3: Recovery (if applicable)
        if recoveryDuration > 0 {
            let recoveryPoints = Int(recoveryDuration / 10) // Every 10 seconds during recovery
            let recoveryStartTime = 30.0 + sustainedDuration
            
            for i in 0..<recoveryPoints {
                let time = recoveryStartTime + (Double(i) * 10.0)
                let progress = Double(i) / Double(recoveryPoints - 1)
                // Gradual decline back to baseline
                _ = baseline + 5 // Slightly above baseline at end
                let currentElevation = peak - baseline
                let remainingElevation = Int(Double(currentElevation) * (1.0 - progress))
                let hr = baseline + remainingElevation + (i == recoveryPoints - 1 ? 0 : Int.random(in: -2...3))
                pattern.append(OrthostaticEvent.HeartRatePoint(heartRate: hr, timeFromStanding: time))
            }
        }
        
        return pattern
    }
    
    private func sendTestOrthostaticEventsToiPhone() {
        // Send the test orthostatic events to iPhone for dashboard display
        for event in orthostaticEvents.prefix(3) { // Send the 3 most recent events
            WatchConnectivityManager.shared.sendOrthostaticEvent(
                baselineHeartRate: event.baselineHeartRate,
                peakHeartRate: event.peakHeartRate,
                increase: event.increase,
                severity: event.severity.rawValue,
                sustainedDuration: event.sustainedDuration,
                recoveryTime: event.recoveryTime,
                isRecovered: event.isRecovered,
                timestamp: event.timestamp
            )
            
            print("📱 [TEST] Sent test orthostatic event to iPhone: \(event.clinicalSummary)")
            
            // Small delay to avoid overwhelming the connection
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    // MARK: - Public method to manually send test data
    func sendTestDataToiPhone() {
        print("🔧 [MANUAL] Manually sending test orthostatic data to iPhone...")
        sendTestOrthostaticEventsToiPhone()
    }
    
    // MARK: - Manual Posture Control for Testing
    func manuallySetStanding(_ standing: Bool) {
        print("🎛️ [MANUAL] User manually set posture to: \(standing ? "STANDING" : "SITTING")")
        
        if standing && !isStanding {
            // Manually trigger standing detection
            startStandingDetection()
        } else if !standing && isStanding {
            // Manually trigger sitting detection
            endStandingDetection()
        }
        
        // Also update the motion detection state directly for consistency
        DispatchQueue.main.async {
            self.isStanding = standing
            
            // Force send current heart rate with updated posture
            if self.currentHeartRate > 0 {
                print("🔄 [MANUAL] Force-sending heart rate \(self.currentHeartRate)")
                WatchConnectivityManager.shared.sendHeartRateUpdate(
                    heartRate: self.currentHeartRate, 
                    delta: self.heartRateDelta,
                    isStanding: self.isStanding
                )
            }
        }
    }
    
    private func simulateOrthostaticEvent() {
        // 60% chance of normal response, 40% chance of elevated response episode
        let isElevatedEpisode = Double.random(in: 0...1) < 0.4
        
        if isElevatedEpisode {
            simulateElevatedResponseEpisode()
        } else {
            simulateNormalOrthostaticResponse()
        }
    }
    
    private func simulateElevatedResponseEpisode() {
        print("🧪 [SIMULATOR] Simulating elevated response episode with sustained elevation...")
        
        let baselineRate = Int.random(in: 68...78)
        let increase = Int.random(in: 35...65) // Elevated response range increase (30+ BPM)
        let peakRate = baselineRate + increase
        
        // Elevated response characteristics: sustained elevation for several minutes
        let sustainedDuration = Double.random(in: 300...900) // 5-15 minutes (elevated response pattern)
        let recoveryTime = Double.random(in: 0...1) < 0.3 ? nil : Double.random(in: 120...300) // 30% no recovery
        
        let pattern = generateRealisticHeartRatePattern(
            baseline: baselineRate,
            peak: peakRate,
            sustainedDuration: sustainedDuration,
            recoveryDuration: recoveryTime ?? 0
        )
        
        let event = OrthostaticEvent(
            timestamp: Date(),
            baselineHeartRate: baselineRate,
            peakHeartRate: peakRate,
            increase: increase,
            duration: sustainedDuration + (recoveryTime ?? 0) + 60,
            sustainedDuration: sustainedDuration,
            recoveryTime: recoveryTime,
            heartRatePattern: pattern,
            isRecovered: recoveryTime != nil
        )
        
        print("🩺 [SIMULATOR] Standing Response Episode: \(event.clinicalSummary)")
        completeSimulatedEvent(event, baselineRate, peakRate)
    }
    
    private func simulateNormalOrthostaticResponse() {
        print("🧪 [SIMULATOR] Simulating normal orthostatic response...")
        
        let baselineRate = Int.random(in: 70...85)
        let increase = Int.random(in: 15...35) // Normal range increase
        let peakRate = baselineRate + increase
        
        // Normal characteristics: brief elevation, quick recovery
        let sustainedDuration = Double.random(in: 30...120) // 30 seconds to 2 minutes
        let recoveryTime = Double.random(in: 30...90) // Quick recovery
        
        let pattern = generateRealisticHeartRatePattern(
            baseline: baselineRate,
            peak: peakRate,
            sustainedDuration: sustainedDuration,
            recoveryDuration: recoveryTime
        )
        
        let event = OrthostaticEvent(
            timestamp: Date(),
            baselineHeartRate: baselineRate,
            peakHeartRate: peakRate,
            increase: increase,
            duration: sustainedDuration + recoveryTime + 30,
            sustainedDuration: sustainedDuration,
            recoveryTime: recoveryTime,
            heartRatePattern: pattern,
            isRecovered: true
        )
        
        print("✅ [SIMULATOR] Normal Response: \(event.clinicalSummary)")
        completeSimulatedEvent(event, baselineRate, peakRate)
    }
    
    private func completeSimulatedEvent(_ event: OrthostaticEvent, _ baselineRate: Int, _ peakRate: Int) {
        DispatchQueue.main.async {
            // Add to orthostatic events
            self.orthostaticEvents.insert(event, at: 0)
            
            // Update current heart rate to the peak
            self.updateHeartRate(peakRate)
            
            // Send to iPhone
            WatchConnectivityManager.shared.sendOrthostaticEvent(
                baselineHeartRate: baselineRate,
                peakHeartRate: peakRate,
                increase: event.increase,
                severity: event.severity.rawValue,
                sustainedDuration: event.sustainedDuration,
                recoveryTime: event.recoveryTime,
                isRecovered: event.isRecovered,
                timestamp: event.timestamp
            )
            
            print("🩺 [SIMULATOR] Event created: \(event.description)")
            
            // Keep only last 20 events
            if self.orthostaticEvents.count > 20 {
                self.orthostaticEvents.removeLast()
            }
        }
        
        // Simulate realistic recovery timing
        let recoveryDelay = event.isRecovered ? (event.recoveryTime ?? 60.0) : 15.0
        DispatchQueue.main.asyncAfter(deadline: .now() + recoveryDelay) {
            let returnRate = event.isRecovered ? 
                baselineRate + Int.random(in: -3...8) : // Full recovery with variation
                baselineRate + Int.random(in: 15...25)  // Incomplete recovery
            self.updateHeartRate(returnRate)
            
            let recoveryStatus = event.isRecovered ? "recovered to baseline" : "incomplete recovery"
            print("🩺 [SIMULATOR] Heart rate \(recoveryStatus): \(returnRate) BPM after \(Int(recoveryDelay))s")
        }
    }
    
    deinit {
        simulationTimer?.invalidate()
        orthostaticTestTimer?.invalidate()
    }
    #endif
    
    // MARK: - Should Record Heart Rate Entry
    private func shouldRecordHeartRateEntry(heartRate: Int, delta: Int) -> Bool {
        // Always record the first entry
        guard !heartRateHistory.isEmpty else { return true }
        
        // Get min/max from existing history
        let heartRates = heartRateHistory.map { $0.heartRate }
        let currentMax = heartRates.max() ?? 0
        let currentMin = heartRates.min() ?? Int.max
        
        // Record if it's a new high or low
        if heartRate > currentMax || heartRate < currentMin {
            return true
        }
        
        // Record if there's a significant change (±30 BPM)
        if abs(delta) >= 30 {
            return true
        }
        
        return false
    }
    
    // MARK: - Recording Interval Management
    @objc private func handleRecordingIntervalUpdate(_ notification: Notification) {
        guard let interval = notification.userInfo?["interval"] as? TimeInterval else { return }
        updateRecordingInterval(interval)
    }
    
    func updateRecordingInterval(_ newInterval: TimeInterval) {
        recordingInterval = newInterval
        print("⏰ [WATCH] Recording interval updated to \(newInterval)s")
        
        // Update simulation timers if running
        #if DEBUG && targetEnvironment(simulator)
        if let timer = simulationTimer, timer.isValid {
            timer.invalidate()
            simulationTimer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let randomRate = Int.random(in: 60...180)
                DispatchQueue.main.async {
                    self.updateHeartRate(randomRate)
                    let reading = HeartRateReading(heartRate: randomRate, timestamp: Date())
                    self.heartRateHistory.append(reading)
                    self.cleanupHistory()
                }
            }
        }
        #endif
    }
    
    func requestAuthorization() {
        // PRIVACY-FIRST: Watch only READS heart rate from sensors
        // NO DATA IS WRITTEN TO HEALTHKIT OR APPLE HEALTH
        // Data only flows: Watch Sensors → Watch App → iPhone App (via WatchConnectivity)
        
        print("📋 [WATCH] Requesting HealthKit authorization...")
        print("🔍 [WATCH] HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
        
        let typesToRead: Set = [heartRateQuantityType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                print("✅ [WATCH] Authorization result: \(success ? "GRANTED" : "DENIED")")
                if success {
                    // Start monitoring immediately after authorization
                    self?.startContinuousMonitoring()
                    self?.fetchLatestHeartRate()
                }
            }
            
            if let error = error {
                print("🔒 [WATCH] Authorization failed: \(error.localizedDescription)")
            } else if success {
                print("🔒 [WATCH] HealthKit READ-only authorization granted - NO data written to Apple Health")
            } else {
                print("❌ [WATCH] Authorization was denied by user")
            }
        }
    }
    
    func startContinuousMonitoring() {
        guard isAuthorized, !isMonitoring else { return }
        startMonitoring()
        enableBackgroundDelivery()
    }
    
    func fetchLatestHeartRate() {
        // Manual fetch of latest heart rate sample
        print("🔄 [WATCH] Manual heart rate fetch triggered")
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateQuantityType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("❌ [WATCH] Manual fetch error: \(error.localizedDescription)")
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("⚠️ [WATCH] No heart rate samples available")
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            print("✅ [WATCH] Manual fetch got heart rate: \(Int(heartRate)) BPM")
            
            DispatchQueue.main.async {
                self?.processHeartRateSamples([sample])
            }
        }
        
        healthStore.execute(query)
    }
    
    func startMonitoring() {
        guard isAuthorized, !isMonitoring else { return }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-maxHistoryDuration),
            end: nil,
            options: .strictStartDate
        )
        
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateQuantityType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
            isMonitoring = true
        }
        
        // Start workout session for continuous heart rate monitoring
        startWorkoutSession()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        
        stopWorkoutSession()
        isMonitoring = false
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for sample in heartRateSamples {
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                let heartRate = Int(sample.quantity.doubleValue(for: heartRateUnit))
                
                let reading = HeartRateReading(heartRate: heartRate, timestamp: sample.endDate)
                
                // Update current heart rate
                if sample.endDate > Date().addingTimeInterval(-10) {
                    self.updateHeartRate(heartRate)
                }
                
                // Add to history
                self.heartRateHistory.append(reading)
            }
            
            // Clean up old history entries
            self.cleanupHistory()
        }
    }
    
    private func updateHeartRate(_ newRate: Int) {
        // Store previous rate
        if currentHeartRate > 0 {
            previousHeartRate = currentHeartRate
        }
        
        // Update current rate
        currentHeartRate = newRate
        
        // Send to iPhone via WatchConnectivity
        print("📱 [WATCH] Sending heart rate \(newRate) to iPhone with delta \(heartRateDelta)")
        WatchConnectivityManager.shared.sendHeartRateUpdate(heartRate: newRate, delta: heartRateDelta, isStanding: isStanding)
        
        // Check for orthostatic response
        checkOrthostaticResponse(heartRate: newRate)
        
        // Set baseline if not set
        if baselineHeartRate == 0 && newRate > 0 {
            baselineHeartRate = newRate
        }
        
        // Calculate delta from previous reading
        if previousHeartRate > 0 {
            heartRateDelta = newRate - previousHeartRate
            
            // Check for significant changes
            checkForSignificantChange(newRate)
        }
    }
    
    private func checkForSignificantChange(_ currentRate: Int) {
        let absoluteDelta = abs(heartRateDelta)
        
        // Record significant changes (30+ bpm)
        if absoluteDelta >= minorChangeThreshold {
            let change = SignificantChange(
                timestamp: Date(),
                fromRate: previousHeartRate,
                toRate: currentRate,
                delta: heartRateDelta,
                isMajor: absoluteDelta >= majorChangeThreshold
            )
            significantChanges.append(change)
            
            // Send significant change to iPhone
            WatchConnectivityManager.shared.sendSignificantChange(
                fromRate: previousHeartRate,
                toRate: currentRate,
                delta: heartRateDelta
            )
            
            // Keep only last 50 changes
            if significantChanges.count > 50 {
                significantChanges.removeFirst()
            }
        }
        
        // Don't alert too frequently
        guard Date().timeIntervalSince(lastAlertTime) > alertCooldown else { return }
        
        if absoluteDelta >= majorChangeThreshold {
            // Major change (50+ bpm)
            let changeText = heartRateDelta > 0 ? "increased +\(heartRateDelta)" : "decreased \(heartRateDelta)"
            
            triggerAlert(
                message: "Heart Rate\n\(changeText)",
                severity: .major
            )
        } else if absoluteDelta >= minorChangeThreshold {
            // Minor change (30+ bpm)
            let changeText = heartRateDelta > 0 ? "increased +\(heartRateDelta)" : "decreased \(heartRateDelta)"
            
            triggerAlert(
                message: "Heart Rate\n\(changeText)",
                severity: .minor
            )
        }
    }
    
    private func triggerAlert(message: String, severity: AlertSeverity) {
        alertMessage = message
        showAlert = true
        lastAlertTime = Date()
        
        // Haptic feedback + sound - all 30+ BPM changes require manual dismissal
        #if canImport(WatchKit)
        switch severity {
        case .minor:
            // Minor alerts (30+ BPM) - notification haptic + sound
            WKInterfaceDevice.current().play(.notification)
            // Multiple vibrations for more noticeable alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WKInterfaceDevice.current().play(.notification)
            }
        case .major:
            // Major alerts (50+ BPM) - more intense haptic + sound
            WKInterfaceDevice.current().play(.failure)
            // Multiple vibrations for major alerts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WKInterfaceDevice.current().play(.failure)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                WKInterfaceDevice.current().play(.failure)
            }
        }
        #endif
    }
    
    func dismissAlert() {
        showAlert = false
    }
    
    enum AlertSeverity {
        case minor
        case major
    }
    
    private func cleanupHistory() {
        let cutoffDate = Date().addingTimeInterval(-maxHistoryDuration)
        heartRateHistory = heartRateHistory.filter { $0.timestamp > cutoffDate }
    }
    
    // MARK: - Workout Session Management
    
    private var workoutSession: HKWorkoutSession?
    #if os(watchOS)
    private var workoutBuilder: HKLiveWorkoutBuilder?
    #endif
    
    private func startWorkoutSession() {
        #if os(watchOS)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if !success {
                    print("Failed to begin workout collection: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func stopWorkoutSession() {
        workoutSession?.end()
        #if os(watchOS)
        workoutBuilder?.endCollection(withEnd: Date()) { success, error in
            self.workoutBuilder?.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self.workoutSession = nil
                    self.workoutBuilder = nil
                }
            }
        }
        #endif
    }
    
    // MARK: - Enhanced Watch Face Integration
    
    func enableHighFrequencyUpdates() {
        // Enable more frequent updates for watch face integration
        // This supports the TachyMon-like always-on functionality
        startWorkoutSession()
    }
    
    
    // MARK: - Background Monitoring Support
    
    func enableBackgroundDelivery() {
        // Enable background delivery for continuous monitoring
        healthStore.enableBackgroundDelivery(for: heartRateQuantityType, frequency: .immediate) { success, error in
            if success {
                print("Background heart rate monitoring enabled")
            }
        }
    }
    
    func resumeMonitoringIfNeeded() {
        // Resume monitoring if it was stopped (app lifecycle)
        if isAuthorized && !isMonitoring {
            startContinuousMonitoring()
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HeartRateManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle state changes if needed
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - Enhanced Orthostatic Monitoring Extension
extension HeartRateManager {
    
    private func startMotionDetection() {
        print("🎯 [WATCH] Starting enhanced motion detection...")
        
        // Try Activity Manager first (more accurate for activity detection)
        if CMMotionActivityManager.isActivityAvailable() {
            print("✅ [WATCH] Activity Manager available - starting activity updates")
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                if let activity = activity {
                    self?.processActivityData(activity)
                }
            }
        } else {
            print("⚠️ [WATCH] Activity Manager not available")
        }
        
        // Start accelerometer for Swift-HAR style wrist position analysis
        if motionManager.isAccelerometerAvailable {
            print("✅ [WATCH] Accelerometer available - starting wrist analysis")
            motionManager.accelerometerUpdateInterval = 1.0 // Once per second
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                if let error = error {
                    print("❌ [WATCH] Accelerometer error: \(error.localizedDescription)")
                    return
                }
                
                guard let accelData = data else { return }
                self?.analyzeWristPosture(acceleration: accelData.acceleration)
            }
        }
        
        print("🏃 [WATCH] Motion detection started")
        
        // Set default posture after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("🎯 [WATCH] Initial posture check - isStanding: \(self.isStanding)")
            
            // Default to standing during daytime hours if no motion detected
            if !self.isStanding {
                let hour = Calendar.current.component(.hour, from: Date())
                if hour >= 6 && hour <= 22 {
                    print("🔧 [WATCH] Defaulting to standing during daytime")
                    self.isStanding = true
                }
            }
        }
        
        // Periodic status check every 60 seconds
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            print("⏰ [WATCH] Status: \(self.isStanding ? "Standing" : "Sitting")")
            
            // Timeout detection - assume sitting if no activity updates
            let timeSinceLastActivity = Date().timeIntervalSince(self.lastActivityUpdate)
            if timeSinceLastActivity > 120 {
                print("🛋️ [WATCH] No activity for \(Int(timeSinceLastActivity))s - assuming sitting")
                if self.isStanding {
                    self.isStanding = false
                    self.endStandingDetection()
                }
            }
        }
    }
    
    // Process activity data from CMMotionActivityManager
    private func processActivityData(_ activity: CMMotionActivity) {
        lastActivityUpdate = Date()
        var newStanding = isStanding
        
        if activity.stationary {
            print("🪑 [ACTIVITY] User is stationary (likely sitting)")
            newStanding = false
            consecutiveStationaryCount += 1
        } else if activity.walking || activity.running {
            print("🚶 [ACTIVITY] User is walking/running (standing)")
            newStanding = true
            consecutiveStationaryCount = 0
        } else if activity.automotive || activity.cycling {
            print("🚗 [ACTIVITY] User in vehicle/cycling (sitting)")
            newStanding = false
            consecutiveStationaryCount += 1
        }
        
        // Multiple stationary readings = definitely sitting
        if consecutiveStationaryCount >= 3 {
            print("🛋️ [ACTIVITY] Multiple stationary readings - definitely sitting")
            newStanding = false
        }
        
        // Require medium/high confidence for activity-based changes
        if activity.confidence != .low && newStanding != isStanding {
            print("🎯 [ACTIVITY] Activity change (conf: \(activity.confidence.rawValue)): \(isStanding ? "Standing" : "Sitting") → \(newStanding ? "Standing" : "Sitting")")
            
            // High-priority activities override wrist analysis
            if activity.walking || activity.running || activity.automotive {
                if newStanding && !isStanding {
                    startStandingDetection()
                } else if !newStanding && isStanding {
                    endStandingDetection()
                }
                print("🎯 [ACTIVITY] High-priority activity - overriding wrist analysis")
            } else if activity.stationary && consecutiveStationaryCount >= 2 {
                if !newStanding && isStanding {
                    endStandingDetection()
                }
            }
        } else {
            print("🔄 [ACTIVITY] Low confidence or no change - letting wrist analysis decide")
        }
    }
    
    // Swift-HAR inspired wrist position analysis
    private func analyzeWristPosture(acceleration: CMAcceleration) {
        let now = Date()
        
        // Capture all three axes separately (Swift-HAR approach)
        xAxisSamples.append(acceleration.x)
        yAxisSamples.append(acceleration.y) 
        zAxisSamples.append(acceleration.z)
        
        // Calculate total acceleration magnitude
        let totalAcceleration = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        movementFrequencySamples.append(totalAcceleration)
        
        // Rolling window of 10 seconds
        let maxSamples = 10
        if xAxisSamples.count > maxSamples {
            xAxisSamples.removeFirst()
            yAxisSamples.removeFirst()
            zAxisSamples.removeFirst()
            movementFrequencySamples.removeFirst()
        }
        
        // Analyze every 10 seconds
        if now.timeIntervalSince(lastWristAnalysis) >= 10.0 && xAxisSamples.count >= 5 {
            lastWristAnalysis = now
            
            // Extract features
            let features = extractPostureFeatures()
            
            // Classify with confidence
            let (likelyStanding, confidence) = classifyPosture(features: features)
            
            print("🤖 [WRIST] X:\(String(format: "%.3f", features.xMean)) Y:\(String(format: "%.3f", features.yMean)) Z:\(String(format: "%.3f", features.zMean)) Conf:\(String(format: "%.3f", confidence)) Standing:\(likelyStanding ? "YES" : "NO")")
            
            postureConfidence = confidence
            
            // Only change with high confidence
            if likelyStanding != isStanding && confidence > 0.7 {
                print("🎯 [WRIST] High confidence change: \(isStanding ? "Standing" : "Sitting") → \(likelyStanding ? "Standing" : "Sitting")")
                
                if likelyStanding && !isStanding {
                    startStandingDetection()
                } else if !likelyStanding && isStanding {
                    endStandingDetection()
                }
            }
        }
    }
    
    // Feature extraction from multi-axis data
    private func extractPostureFeatures() -> PostureFeatures {
        let xMean = xAxisSamples.reduce(0, +) / Double(xAxisSamples.count)
        let yMean = yAxisSamples.reduce(0, +) / Double(yAxisSamples.count)
        let zMean = zAxisSamples.reduce(0, +) / Double(zAxisSamples.count)
        
        let xVariance = calculateVariance(xAxisSamples)
        let yVariance = calculateVariance(yAxisSamples)
        let zVariance = calculateVariance(zAxisSamples)
        
        let movementMean = movementFrequencySamples.reduce(0, +) / Double(movementFrequencySamples.count)
        let movementVariance = calculateVariance(movementFrequencySamples)
        
        let xRange = (xAxisSamples.max() ?? 0) - (xAxisSamples.min() ?? 0)
        let yRange = (yAxisSamples.max() ?? 0) - (yAxisSamples.min() ?? 0)
        let zRange = (zAxisSamples.max() ?? 0) - (zAxisSamples.min() ?? 0)
        
        return PostureFeatures(
            xMean: xMean, yMean: yMean, zMean: zMean,
            xVariance: xVariance, yVariance: yVariance, zVariance: zVariance,
            movementMean: movementMean, movementVariance: movementVariance,
            xRange: xRange, yRange: yRange, zRange: zRange
        )
    }
    
    // Neural network inspired classification
    private func classifyPosture(features: PostureFeatures) -> (standing: Bool, confidence: Double) {
        var standingScore: Double = 0.0
        var totalWeight: Double = 0.0
        
        // Z-axis orientation (40% weight)
        let zWeight = 0.4
        if abs(features.zMean) > 0.5 {
            standingScore += zWeight * (features.zMean > 0 ? 1.0 : 0.0)
        } else {
            standingScore += zWeight * 0.5
        }
        totalWeight += zWeight
        
        // Movement variance (30% weight)
        let movementWeight = 0.3
        if features.movementVariance > 0.02 {
            standingScore += movementWeight * 1.0
        } else if features.movementVariance < 0.005 {
            standingScore += movementWeight * 0.0
        } else {
            standingScore += movementWeight * 0.5
        }
        totalWeight += movementWeight
        
        // Y-axis arm angle (20% weight)
        let yWeight = 0.2
        if abs(features.yMean) > 0.3 {
            standingScore += yWeight * 1.0
        } else {
            standingScore += yWeight * 0.2
        }
        totalWeight += yWeight
        
        // Range of motion (10% weight)
        let rangeWeight = 0.1
        let totalRange = features.xRange + features.yRange + features.zRange
        if totalRange > 0.8 {
            standingScore += rangeWeight * 1.0
        } else if totalRange < 0.2 {
            standingScore += rangeWeight * 0.0
        } else {
            standingScore += rangeWeight * 0.5
        }
        totalWeight += rangeWeight
        
        let normalizedScore = standingScore / totalWeight
        let confidence = abs(normalizedScore - 0.5) * 2.0
        
        return (standing: normalizedScore > 0.5, confidence: confidence)
    }
    
    // Feature structure
    private struct PostureFeatures {
        let xMean, yMean, zMean: Double
        let xVariance, yVariance, zVariance: Double
        let movementMean, movementVariance: Double
        let xRange, yRange, zRange: Double
    }
    
    private func calculateVariance(_ samples: [Double]) -> Double {
        guard samples.count > 1 else { return 0 }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let squaredDifferences = samples.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(samples.count - 1)
    }
    
    private func startStandingDetection() {
        print("🧍 [WATCH] Standing detected - starting enhanced orthostatic monitoring")
        
        isStanding = true
        standingStartTime = Date()
        standingBaselineHeartRate = currentHeartRate > 0 ? currentHeartRate : previousHeartRate
        
        // Reset tracking variables for new standing episode
        currentOrthostaticEvent = nil
        elevatedStartTime = nil
        heartRatePattern = []
        isCurrentlyElevated = false
        recoveryStartTime = nil
        hasRecovered = false
        
        // Alert for standing detection
        if standingBaselineHeartRate > 0 {
            print("🏃 [WATCH] Baseline HR: \(standingBaselineHeartRate) BPM - enhanced monitoring for sustained elevation & recovery")
        }
    }
    
    private func endStandingDetection() {
        guard isStanding, let startTime = standingStartTime else { return }
        
        print("🪑 [WATCH] Sitting/lying detected - ending enhanced orthostatic monitoring")
        
        // Finalize any ongoing orthostatic event
        finalizeCurrentOrthostaticEvent()
        
        isStanding = false
        let duration = Date().timeIntervalSince(startTime)
        standingStartTime = nil
        
        // Reset tracking variables
        currentOrthostaticEvent = nil
        elevatedStartTime = nil
        heartRatePattern = []
        isCurrentlyElevated = false
        recoveryStartTime = nil
        hasRecovered = false
        
        print("📊 [WATCH] Standing episode ended after \(Int(duration))s")
    }
    
    private func checkOrthostaticResponse(heartRate: Int) {
        guard isStanding, 
              let startTime = standingStartTime,
              standingBaselineHeartRate > 0,
              heartRate > 0 else { return }
        
        let increase = heartRate - standingBaselineHeartRate
        let duration = Date().timeIntervalSince(startTime)
        
        // Only check after standing for at least 10 seconds
        guard duration >= 10 else { return }
        
        // Record heart rate point for pattern tracking
        let hrPoint = OrthostaticEvent.HeartRatePoint(heartRate: heartRate, timeFromStanding: duration)
        heartRatePattern.append(hrPoint)
        
        // Keep pattern history manageable (last 10 minutes worth)
        heartRatePattern = heartRatePattern.filter { $0.timeFromStanding > duration - 600 }
        
        let isCurrentlyAtElevation = increase >= 30
        
        if isCurrentlyAtElevation && !isCurrentlyElevated {
            // Heart rate just became elevated
            startElevationTracking(heartRate: heartRate, increase: increase, atTime: duration)
            
        } else if isCurrentlyAtElevation && isCurrentlyElevated {
            // Heart rate continues to be elevated - update peak if needed
            updateOngoingElevation(heartRate: heartRate, increase: increase)
            
        } else if !isCurrentlyAtElevation && isCurrentlyElevated {
            // Heart rate dropped below threshold - check for recovery
            checkForRecovery(heartRate: heartRate, atTime: duration)
            
        } else if !isCurrentlyAtElevation && recoveryStartTime != nil {
            // Continue monitoring recovery
            monitorRecovery(heartRate: heartRate, atTime: duration)
        }
        
        isCurrentlyElevated = isCurrentlyAtElevation
    }
    
    private func startElevationTracking(heartRate: Int, increase: Int, atTime: TimeInterval) {
        elevatedStartTime = Date()
        isCurrentlyElevated = true
        recoveryStartTime = nil
        hasRecovered = false
        
        print("📈 [WATCH] Elevation started: \(heartRate) BPM (+\(increase)) at \(Int(atTime))s")
    }
    
    private func updateOngoingElevation(heartRate: Int, increase: Int) {
        // Update peak heart rate if this is higher
        // The event will be finalized when elevation ends or standing ends
        print("📊 [WATCH] Ongoing elevation: \(heartRate) BPM (+\(increase))")
    }
    
    private func checkForRecovery(heartRate: Int, atTime: TimeInterval) {
        guard let elevationStart = elevatedStartTime else { return }
        
        let sustainedDuration = Date().timeIntervalSince(elevationStart)
        recoveryStartTime = Date()
        
        print("📉 [WATCH] Recovery started after \(Int(sustainedDuration))s sustained elevation")
        
        // Create event for the sustained elevation period that just ended
        createSustainedElevationEvent(sustainedDuration: sustainedDuration, endTime: atTime)
    }
    
    private func monitorRecovery(heartRate: Int, atTime: TimeInterval) {
        guard let recoveryStart = recoveryStartTime else { return }
        
        let increase = heartRate - standingBaselineHeartRate
        let recoveryTime = Date().timeIntervalSince(recoveryStart)
        
        // Consider recovered if within 10 BPM of baseline for 30+ seconds
        if increase <= 10 && recoveryTime >= 30 {
            hasRecovered = true
            print("✅ [WATCH] Full recovery achieved in \(Int(recoveryTime))s")
            
            // Update the most recent orthostatic event with recovery info
            updateMostRecentEventWithRecovery(recoveryTime: recoveryTime)
        }
    }
    
    private func createSustainedElevationEvent(sustainedDuration: TimeInterval, endTime: TimeInterval) {
        guard sustainedDuration >= 30 else { return } // Only create events for 30+ second elevations
        
        let peakHR = heartRatePattern.max(by: { $0.heartRate < $1.heartRate })?.heartRate ?? currentHeartRate
        let increase = peakHR - standingBaselineHeartRate
        
        let event = OrthostaticEvent(
            timestamp: Date().addingTimeInterval(-sustainedDuration),
            baselineHeartRate: standingBaselineHeartRate,
            peakHeartRate: peakHR,
            increase: increase,
            duration: endTime,
            sustainedDuration: sustainedDuration,
            recoveryTime: nil, // Will be updated if recovery occurs
            heartRatePattern: Array(heartRatePattern), // Snapshot of pattern
            isRecovered: false
        )
        
        orthostaticEvents.append(event)
        currentOrthostaticEvent = event
        
        // Send to iPhone
        WatchConnectivityManager.shared.sendOrthostaticEvent(
            baselineHeartRate: standingBaselineHeartRate,
            peakHeartRate: peakHR,
            increase: increase,
            severity: event.severity.rawValue,
            sustainedDuration: event.sustainedDuration,
            recoveryTime: event.recoveryTime,
            isRecovered: event.isRecovered,
            timestamp: event.timestamp
        )
        
        print("🩺 [WATCH] Sustained elevation event: \(event.description)")
        
        // Keep only last 20 events
        if orthostaticEvents.count > 20 {
            orthostaticEvents.removeFirst()
        }
    }
    
    private func updateMostRecentEventWithRecovery(recoveryTime: TimeInterval) {
        guard let lastIndex = orthostaticEvents.indices.last else { return }
        
        let oldEvent = orthostaticEvents[lastIndex]
        let updatedEvent = OrthostaticEvent(
            timestamp: oldEvent.timestamp,
            baselineHeartRate: oldEvent.baselineHeartRate,
            peakHeartRate: oldEvent.peakHeartRate,
            increase: oldEvent.increase,
            duration: oldEvent.duration,
            sustainedDuration: oldEvent.sustainedDuration,
            recoveryTime: recoveryTime,
            heartRatePattern: oldEvent.heartRatePattern,
            isRecovered: true
        )
        
        orthostaticEvents[lastIndex] = updatedEvent
        print("🔄 [WATCH] Updated event with recovery: \(updatedEvent.description)")
    }
    
    private func finalizeCurrentOrthostaticEvent() {
        guard isCurrentlyElevated, let elevationStart = elevatedStartTime else { return }
        
        let sustainedDuration = Date().timeIntervalSince(elevationStart)
        let standingDuration = Date().timeIntervalSince(standingStartTime ?? Date())
        
        // Create final event for any ongoing elevation
        createSustainedElevationEvent(sustainedDuration: sustainedDuration, endTime: standingDuration)
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

#if os(watchOS)
extension HeartRateManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Data collection handled by the anchored object query
    }
}
#endif
