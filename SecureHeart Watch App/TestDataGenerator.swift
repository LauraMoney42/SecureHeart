//
//  TestDataGenerator.swift
//  Secure Heart Watch App
//
//  Created by Claude on 11/16/25.
//  Test data generation for POTS episode simulation
//

import Foundation

#if DEBUG && targetEnvironment(simulator)

/// Test data generator for simulating POTS episodes and heart rate changes
/// This class is only available in DEBUG builds on the simulator
class TestDataGenerator {

    private weak var heartRateManager: HeartRateManager?
    private var simulationTimer: Timer?
    private var orthostaticTestTimer: Timer?

    init(heartRateManager: HeartRateManager) {
        self.heartRateManager = heartRateManager
    }

    // MARK: - Public Test Data Methods

    /// Starts generating test data for POTS episodes and heart rate changes
    func startTestDataGeneration() {
        print("🧪 [TEST] Starting POTS episode test data generation...")
        addInitialTestData()
        startSimulationTimers()
    }

    /// Stops all test data generation
    func stopTestDataGeneration() {
        print("🧪 [TEST] Stopping POTS episode test data generation...")
        simulationTimer?.invalidate()
        orthostaticTestTimer?.invalidate()
        simulationTimer = nil
        orthostaticTestTimer = nil
    }

    // MARK: - Private Test Data Methods

    private func addInitialTestData() {
        guard let manager = heartRateManager else { return }

        let testRates = [72, 85, 93, 110, 125, 145, 160, 135, 95, 78]
        for (index, rate) in testRates.enumerated() {
            let reading = HeartRateReading(
                heartRate: rate,
                timestamp: Date().addingTimeInterval(-Double(index * 60))
            )
            manager.heartRateHistory.append(reading)
        }
        manager.currentHeartRate = testRates.first ?? 72

        // Add some test orthostatic events for demonstration
        addTestOrthostaticEvents()
    }

    private func startSimulationTimers() {
        guard let manager = heartRateManager else { return }

        // Simulate changing heart rate based on recording interval setting
        simulationTimer = Timer.scheduledTimer(withTimeInterval: manager.recordingInterval, repeats: true) { [weak self, weak manager] _ in
            guard let self = self, let manager = manager else { return }
            let randomRate = Int.random(in: 60...180)
            DispatchQueue.main.async {
                let previousRate = manager.heartRateHistory.last?.heartRate ?? 0
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

                self.updateHeartRate(randomRate, manager: manager)
                let reading = HeartRateReading(heartRate: randomRate, timestamp: Date(), delta: delta, context: context)

                // Only add significant readings to history
                if self.shouldRecordHeartRateEntry(heartRate: randomRate, delta: delta, manager: manager) {
                    manager.heartRateHistory.append(reading)
                    print("📊 [TEST] Recording significant HR event: \(randomRate) BPM (Δ\(delta))")
                }

                self.cleanupHistory(manager: manager)
            }
        }

        // Simulate orthostatic events every 30 seconds for testing
        orthostaticTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.simulateOrthostaticEvent()
        }

        print("🧪 [TEST] Test data timers started (HR updates every \(manager.recordingInterval)s, POTS episodes every 30s)")
    }

    private func addTestOrthostaticEvents() {
        guard let manager = heartRateManager else { return }

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
        manager.orthostaticEvents.append(episode1)

        // Standing Response #2: Severe response with incomplete recovery
        let episode2 = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            baseline: 72,
            peakHR: 128, // +56 BPM (severe increase)
            sustainedMinutes: 8.2, // 8+ minutes sustained
            recoverySeconds: nil, // No recovery - remained elevated
            hasFullRecovery: false
        )
        manager.orthostaticEvents.append(episode2)

        // Normal Orthostatic Response (for comparison)
        let normalResponse = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            baseline: 76,
            peakHR: 98, // +22 BPM (normal response)
            sustainedMinutes: 0.8, // Brief elevation
            recoverySeconds: 45, // Quick recovery
            hasFullRecovery: true
        )
        manager.orthostaticEvents.append(normalResponse)

        // Mild Response Pattern
        let mildResponse = createStandingResponseEpisode(
            timestamp: Date().addingTimeInterval(-450), // 7.5 minutes ago
            baseline: 70,
            peakHR: 105, // +35 BPM
            sustainedMinutes: 6.3, // 6+ minutes sustained
            recoverySeconds: 95, // Moderate recovery time
            hasFullRecovery: true
        )
        manager.orthostaticEvents.append(mildResponse)

        print("🩺 [TEST] Created standing response test data with sustained elevations and recovery patterns")
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
        guard let manager = heartRateManager else { return }

        print("🧪 [TEST] Simulating elevated response episode with sustained elevation...")

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

        print("🩺 [TEST] Standing Response Episode: \(event.clinicalSummary)")
        completeSimulatedEvent(event, baselineRate, peakRate)
    }

    private func simulateNormalOrthostaticResponse() {
        guard let manager = heartRateManager else { return }

        print("🧪 [TEST] Simulating normal orthostatic response...")

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

        print("✅ [TEST] Normal Response: \(event.clinicalSummary)")
        completeSimulatedEvent(event, baselineRate, peakRate)
    }

    private func completeSimulatedEvent(_ event: OrthostaticEvent, _ baselineRate: Int, _ peakRate: Int) {
        guard let manager = heartRateManager else { return }

        DispatchQueue.main.async {
            // Add to orthostatic events
            manager.orthostaticEvents.insert(event, at: 0)

            // Update current heart rate to the peak
            self.updateHeartRate(peakRate, manager: manager)

            print("🩺 [TEST] Event created: \(event.description)")

            // Keep only last 20 events
            if manager.orthostaticEvents.count > 20 {
                manager.orthostaticEvents.removeLast()
            }
        }

        // Simulate realistic recovery timing
        let recoveryDelay = event.isRecovered ? (event.recoveryTime ?? 60.0) : 15.0
        DispatchQueue.main.asyncAfter(deadline: .now() + recoveryDelay) {
            let returnRate = event.isRecovered ?
                baselineRate + Int.random(in: -3...8) : // Full recovery with variation
                baselineRate + Int.random(in: 15...25)  // Incomplete recovery
            self.updateHeartRate(returnRate, manager: manager)

            let recoveryStatus = event.isRecovered ? "recovered to baseline" : "incomplete recovery"
            print("🩺 [TEST] Heart rate \(recoveryStatus): \(returnRate) BPM after \(Int(recoveryDelay))s")
        }
    }

    // MARK: - Helper Methods

    private func updateHeartRate(_ newRate: Int, manager: HeartRateManager) {
        // Access the private updateHeartRate method through reflection or make it internal
        // For now, directly set the published property
        manager.currentHeartRate = newRate

        // Calculate delta
        let previousRate = manager.heartRateHistory.last?.heartRate ?? 0
        if previousRate > 0 {
            manager.heartRateDelta = newRate - previousRate
        }
    }

    private func shouldRecordHeartRateEntry(heartRate: Int, delta: Int, manager: HeartRateManager) -> Bool {
        // Always record the first entry
        guard !manager.heartRateHistory.isEmpty else { return true }

        // Get min/max from existing history
        let heartRates = manager.heartRateHistory.map { $0.heartRate }
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

    private func cleanupHistory(manager: HeartRateManager) {
        let maxHistoryDuration: TimeInterval = 3600 // 60 minutes
        let cutoffDate = Date().addingTimeInterval(-maxHistoryDuration)
        manager.heartRateHistory = manager.heartRateHistory.filter { $0.timestamp > cutoffDate }
    }

    deinit {
        stopTestDataGeneration()
    }
}

#endif
