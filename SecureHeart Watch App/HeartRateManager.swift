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

// MARK: - Data Models (MVP1 - Codable for WatchDataStore)

// MARK: - MVP1 FEATURE - Codable for Persistent Storage
struct HeartRateReading: Identifiable, Codable {
    let id: UUID
    let heartRate: Int
    let timestamp: Date
    let delta: Int
    let context: String?

    init(heartRate: Int, timestamp: Date, delta: Int = 0, context: String? = nil, id: UUID = UUID()) {
        self.id = id
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

// MARK: - MVP1 FEATURE - Codable for Persistent Storage
struct OrthostaticEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let baselineHeartRate: Int
    let peakHeartRate: Int
    let increase: Int
    let duration: TimeInterval // Total standing duration when event was detected
    let sustainedDuration: TimeInterval // How long heart rate stayed elevated (30+ BPM)
    let recoveryTime: TimeInterval? // Time to recover to within 10 BPM of baseline, nil if not recovered
    let heartRatePattern: [HeartRatePoint] // Heart rate measurements during the event
    let isRecovered: Bool // Whether heart rate returned to near baseline

    init(timestamp: Date, baselineHeartRate: Int, peakHeartRate: Int, increase: Int,
         duration: TimeInterval, sustainedDuration: TimeInterval, recoveryTime: TimeInterval?,
         heartRatePattern: [HeartRatePoint], isRecovered: Bool, id: UUID = UUID()) {
        self.id = id
        self.timestamp = timestamp
        self.baselineHeartRate = baselineHeartRate
        self.peakHeartRate = peakHeartRate
        self.increase = increase
        self.duration = duration
        self.sustainedDuration = sustainedDuration
        self.recoveryTime = recoveryTime
        self.heartRatePattern = heartRatePattern
        self.isRecovered = isRecovered
    }

    struct HeartRatePoint: Codable {
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

// MARK: - MVP1 FEATURE - Codable for Persistent Storage
enum OrthostacSeverity: String, CaseIterable, Codable {
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

    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .mild: return "exclamationmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Heart Rate Manager

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
    private let motionDetectionManager = MotionDetectionManager()
    private var standingStartTime: Date?
    private var standingBaselineHeartRate: Int = 0
    private var debugCounter = 0
    
    // Motion detection now handled by MotionDetectionManager
    
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
    @Published var recordingInterval: TimeInterval = 300.0 // Default: 5 minutes (normal mode)
    private let significantDeltaRecordingInterval: TimeInterval = 60.0 // 1 minute during significant changes
    private var lastRecordedTime: Date? = nil
    private var lastRecordedHeartRate: Int? = nil
    private var isInSignificantDeltaMode: Bool = false // Track if we're in rapid change mode

    // Alert sound settings (haptics always enabled for accessibility)
    private var alertSoundEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "alertSoundEnabled_v1") }
        set { UserDefaults.standard.set(newValue, forKey: "alertSoundEnabled_v1") }
    }

    // MARK: - MVP1 FEATURE - Persistent Storage
    private var persistenceTimer: Timer?
    private let persistenceInterval: TimeInterval = 60.0 // Auto-save every 60 seconds

    // MARK: - Initialization

    override init() {
        super.init()
        print("🚀 [WATCH] HeartRateManager initializing...")

        // Set default for alert sound (enabled by default)
        if !UserDefaults.standard.bool(forKey: "alertSoundEnabled_initialized") {
            alertSoundEnabled = true
            UserDefaults.standard.set(true, forKey: "alertSoundEnabled_initialized")
        }

        // MARK: - MVP1 FEATURE - Load Persistent Data from Watch Storage
        loadPersistedData()

        requestAuthorization()

        // Initialize clean motion detection
        setupMotionDetection()

        // MARK: - MVP1 FEATURE - Start Periodic Auto-Save
        startPeriodicPersistence()
        
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
        
        // MARK: - Test Data Generation (Disabled by Default)
        // Test data generation is now in TestDataGenerator.swift
        // To enable test data, uncomment the following lines:
        /*
        #if DEBUG && targetEnvironment(simulator)
        let testDataGenerator = TestDataGenerator(heartRateManager: self)
        testDataGenerator.startTestDataGeneration()
        print("🧪 [TEST] Test data generation started - POTS episodes will simulate every 30s")
        #endif
        */
    }

    // MARK: - Test Data Functions Removed
    // All test data generation has been moved to TestDataGenerator.swift
    // This keeps the production code clean and separates test logic

    #if DEBUG && targetEnvironment(simulator)
    // Removed: addTestData(), addTestOrthostaticEvents(), createStandingResponseEpisode(), etc.
    // See TestDataGenerator.swift for all test data generation code
    deinit {
        // Simulator cleanup if needed
        print("👋 [WATCH] HeartRateManager deinitialized (simulator)")
    }
    #else
    deinit {
        // Production builds: clean up persistence
        persistenceTimer?.invalidate()
        saveDataToStorage() // Save on app termination
        print("👋 [WATCH-MVP1] HeartRateManager deinitialized, data saved")
    }
    #endif

    // MARK: - Manual Posture Control for Testing (moved from old test code)
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

            // MVP1: Log posture change locally only
            if self.currentHeartRate > 0 {
                print("🔄 [WATCH-MVP1] Posture changed to \(standing ? "STANDING" : "SITTING"), HR: \(self.currentHeartRate) (local only)")
            }
        }
    }

    // REMOVED OLD TEST FUNCTIONS - See TestDataGenerator.swift
    // All test data generation code has been extracted to TestDataGenerator.swift
    // This includes: addTestData(), addTestOrthostaticEvents(), createStandingResponseEpisode(),
    // generateRealisticHeartRatePattern(), simulateOrthostaticEvent(), etc.

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

        // Note: Simulation timer updates removed - test data now in TestDataGenerator.swift
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

                // Only update current heart rate for recent samples (within 10 seconds)
                // and only call updateHeartRate for the most recent sample to avoid excessive calls
                if sample.endDate > Date().addingTimeInterval(-10) {
                    // Only process the most recent sample or significant changes
                    if sample == heartRateSamples.last || abs(heartRate - self.currentHeartRate) >= self.minorChangeThreshold {
                        self.updateHeartRate(heartRate)
                    } else {
                        print("⏰ [WATCH] Skipping updateHeartRate for sample: \(heartRate) BPM (not most recent)")
                    }
                }

                // Smart recording: Only add to history if it meets recording criteria
                if self.shouldRecordToHistory(heartRate: heartRate, timestamp: sample.endDate) {
                    self.heartRateHistory.append(reading)
                    self.lastRecordedTime = sample.endDate
                    self.lastRecordedHeartRate = heartRate
                    print("📊 [WATCH] Recorded to history: \(heartRate) BPM at \(sample.endDate)")
                } else {
                    print("⏭️ [WATCH] Skipped recording: \(heartRate) BPM (no significant change)")
                }
            }
            
            // Clean up old history entries
            self.cleanupHistory()
        }
    }
    
    // MARK: - Smart Recording Logic

    /// Determines if a heart rate reading should be recorded to history
    /// Normal mode: Records every 5 minutes
    /// Significant delta mode: Records every 1 minute when heart rate changes rapidly (±30 BPM)
    private func shouldRecordToHistory(heartRate: Int, timestamp: Date) -> Bool {
        // Always record the first reading
        guard !heartRateHistory.isEmpty else {
            print("📊 [RECORDING] First reading - recording")
            return true
        }

        // Must have a last recorded time to proceed
        guard let lastTime = lastRecordedTime, let lastRecorded = lastRecordedHeartRate else {
            print("📊 [RECORDING] No last recorded data - recording")
            return true
        }

        // Calculate time since last recording
        let timeSinceLastRecord = timestamp.timeIntervalSince(lastTime)

        // Calculate delta from last RECORDED heart rate
        let delta = abs(heartRate - lastRecorded)

        // Check if we're experiencing a significant delta (±30 BPM)
        let hasSignificantDelta = delta >= 30

        // Update significant delta mode status
        if hasSignificantDelta && !isInSignificantDeltaMode {
            isInSignificantDeltaMode = true
            print("🔥 [RECORDING] Entering significant delta mode (Δ\(delta) BPM)")
        } else if !hasSignificantDelta && isInSignificantDeltaMode && delta < 15 {
            // Exit significant delta mode when heart rate stabilizes (within 15 BPM)
            isInSignificantDeltaMode = false
            print("✅ [RECORDING] Exiting significant delta mode (heart rate stabilized)")
        }

        // Determine required interval based on mode
        let requiredInterval = isInSignificantDeltaMode ? significantDeltaRecordingInterval : recordingInterval

        // Only record if enough time has passed
        if timeSinceLastRecord >= requiredInterval {
            let mode = isInSignificantDeltaMode ? "DELTA MODE (1 min)" : "NORMAL (5 min)"
            print("📊 [RECORDING] Time threshold met - recording (\(mode), Δ\(delta) BPM, \(Int(timeSinceLastRecord))s elapsed)")
            return true
        }

        // Don't record - not enough time has passed
        let mode = isInSignificantDeltaMode ? "1 min" : "5 min"
        let timeLeft = Int(requiredInterval - timeSinceLastRecord)
        print("⏭️ [RECORDING] Skipped - need \(timeLeft)s more for \(mode) interval (Δ\(delta) BPM)")
        return false
    }

    private func updateHeartRate(_ newRate: Int) {
        // Store previous rate
        if currentHeartRate > 0 {
            previousHeartRate = currentHeartRate
        }

        // Update current rate
        currentHeartRate = newRate

        // Check if enough time has passed since last recording (for iPhone sync in MVP2)
        let now = Date()
        let shouldRecord: Bool

        if let lastTime = lastRecordedTime {
            let timeSinceLastRecord = now.timeIntervalSince(lastTime)
            shouldRecord = timeSinceLastRecord >= recordingInterval
        } else {
            // First reading, always record
            shouldRecord = true
        }

        // MARK: - MVP2 FEATURE - Send Heart Rate to iPhone
        // TODO: Re-enable for MVP2 when iPhone app is available
        // Commented out: 2025-11-16 for MVP1 standalone watch app
        /*
        // Only send to iPhone if interval has passed or it's a significant change
        if shouldRecord || abs(heartRateDelta) >= minorChangeThreshold {
            print("📱 [WATCH] Sending heart rate \(newRate) to iPhone with delta \(heartRateDelta) (interval: \(shouldRecord), significant: \(abs(heartRateDelta) >= minorChangeThreshold))")
            WatchConnectivityManager.shared.sendHeartRateUpdate(heartRate: newRate, delta: heartRateDelta, isStanding: isStanding)
            lastRecordedTime = now
        } else {
            print("⏰ [WATCH] Skipping heart rate update (waiting for interval)")
        }
        */

        // MVP1: Data saved locally only (not synced to iPhone)
        if shouldRecord || abs(heartRateDelta) >= minorChangeThreshold {
            print("💓 [WATCH-MVP1] Heart rate: \(newRate) BPM, delta: \(heartRateDelta) (saved locally, not synced to iPhone)")
            lastRecordedTime = now
        }

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

            // MARK: - MVP2 FEATURE - Send Significant Changes to iPhone
            // TODO: Re-enable for MVP2 when iPhone app is available
            // Commented out: 2025-11-16 for MVP1 standalone watch app
            /*
            // Send significant change to iPhone
            WatchConnectivityManager.shared.sendSignificantChange(
                fromRate: previousHeartRate,
                toRate: currentRate,
                delta: heartRateDelta
            )
            */

            // MVP1: Significant change saved locally only
            print("📊 [WATCH-MVP1] Significant change: \(heartRateDelta > 0 ? "+" : "")\(heartRateDelta) BPM (\(previousHeartRate)→\(currentRate)) (saved locally, not synced to iPhone)")

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

        // Haptic feedback - always enabled for accessibility
        // Sound - only if alertSoundEnabled is true
        #if canImport(WatchKit)
        switch severity {
        case .minor:
            // Minor alerts (30+ BPM) - notification haptic with optional sound
            let hapticType: WKHapticType = alertSoundEnabled ? .notification : .directionUp
            WKInterfaceDevice.current().play(hapticType)
            // Multiple vibrations for more noticeable alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WKInterfaceDevice.current().play(hapticType)
            }
        case .major:
            // Major alerts (50+ BPM) - more intense haptic with optional sound
            let hapticType: WKHapticType = alertSoundEnabled ? .failure : .directionDown
            WKInterfaceDevice.current().play(hapticType)
            // Multiple vibrations for major alerts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WKInterfaceDevice.current().play(hapticType)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                WKInterfaceDevice.current().play(hapticType)
            }
        }
        print("🔔 [WATCH] Alert triggered: \(message) (sound: \(alertSoundEnabled ? "enabled" : "muted"))")
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

    // MARK: - MVP1 FEATURE - Data Persistence Methods

    private func loadPersistedData() {
        // One-time migration: Clear old high-frequency history data (Nov 17, 2025)
        let migrationKey = "heartRateHistoryMigration_v2_2025_11_17"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            print("🔄 [MIGRATION] Clearing old high-frequency history data...")
            WatchDataStore.shared.clearHeartRateHistory()
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ [MIGRATION] Migration complete - starting with fresh history")
            return // Don't load old data
        }

        // Load saved heart rate history
        let savedHistory = WatchDataStore.shared.loadHeartRateHistory()
        if !savedHistory.isEmpty {
            self.heartRateHistory = savedHistory
            print("💾 [WATCH-MVP1] Loaded \(savedHistory.count) heart rate readings from storage")
        }

        // Load saved orthostatic events
        let savedEvents = WatchDataStore.shared.loadOrthostaticEvents()
        if !savedEvents.isEmpty {
            self.orthostaticEvents = savedEvents
            print("💾 [WATCH-MVP1] Loaded \(savedEvents.count) orthostatic events from storage")
        }

        // Load watch settings
        let settings = WatchDataStore.shared.loadSettings()
        // Apply loaded settings to properties
        self.recordingInterval = settings.recordingInterval
        print("⚙️ [WATCH-MVP1] Loaded settings from storage (interval: \(Int(settings.recordingInterval))s)")
    }

    private func startPeriodicPersistence() {
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: persistenceInterval, repeats: true) { [weak self] _ in
            self?.saveDataToStorage()
        }
        print("💾 [WATCH-MVP1] Started periodic data persistence (every \(Int(persistenceInterval))s)")
    }

    private func saveDataToStorage() {
        WatchDataStore.shared.saveHeartRateHistory(heartRateHistory)
        WatchDataStore.shared.saveOrthostaticEvents(orthostaticEvents)

        let size = WatchDataStore.shared.getDataSize()
        print("💾 [WATCH-MVP1] Saved data to watch storage (\(size) bytes)")
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
    
    // MARK: - Clean Motion Detection Setup
    private func setupMotionDetection() {
        print("🎯 [WATCH] Setting up clean motion detection...")

        // Start our new motion detection manager
        motionDetectionManager.startDetection()

        // Listen for posture changes
        NotificationCenter.default.addObserver(
            forName: .postureChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let newStanding = userInfo["isStanding"] as? Bool else { return }

            self?.handlePostureChange(isStanding: newStanding)
        }

        print("✅ [WATCH] Clean motion detection setup complete")
    }

    private func handlePostureChange(isStanding newStanding: Bool) {
        let wasStanding = isStanding

        guard wasStanding != newStanding else { return }

        print("🔄 [WATCH] Posture change: \(wasStanding ? "Standing" : "Sitting") → \(newStanding ? "Standing" : "Sitting")")

        DispatchQueue.main.async {
            self.isStanding = newStanding

            if newStanding && !wasStanding {
                // Started standing
                self.startStandingDetection()
            } else if !newStanding && wasStanding {
                // Started sitting
                self.endStandingDetection()
            }
        }
    }

    // MARK: - Legacy motion detection methods removed
    // Replaced with clean MotionDetectionManager implementation
    
    
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

        // MARK: - MVP2 FEATURE - Send Orthostatic Events to iPhone
        // TODO: Re-enable for MVP2 when iPhone app is available
        // Commented out: 2025-11-16 for MVP1 standalone watch app
        /*
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
        */

        // MVP1: Save orthostatic event to local storage
        WatchDataStore.shared.saveOrthostaticEvents(orthostaticEvents)
        print("🚨 [WATCH-MVP1] Orthostatic event: +\(increase) BPM (\(standingBaselineHeartRate)→\(peakHR)), sustained \(Int(sustainedDuration))s (saved locally, not synced to iPhone)")

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
