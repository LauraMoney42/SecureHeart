//
//  TestDataManager.swift
//  SecureHeart
//
//  Centralized test data management for easy toggling between development and production
//

import Foundation
import SwiftUI

class TestDataManager: ObservableObject {
    static let shared = TestDataManager()

    // MARK: - Master Control

    /// Master switch for all test data - automatically determined by environment
    var isTestDataEnabled: Bool {
        #if targetEnvironment(simulator)
        // Always enable test data in simulator
        return true
        #else
        // Check for debug flag or user preference on real devices
        return forceEnableTestData
        #endif
    }

    /// Force enable test data on real devices (for testing purposes)
    @AppStorage("forceEnableTestData") private var forceEnableTestData = false

    // MARK: - Feature Toggles

    /// Generate historical heart rate data
    @AppStorage("testData.heartRateHistory") var generateHeartRateHistory = true

    /// Generate orthostatic events
    @AppStorage("testData.orthostaticEvents") var generateOrthostaticEvents = true

    /// Generate daily pattern data
    @AppStorage("testData.dailyPatterns") var generateDailyPatterns = true

    /// Generate export sample data when no real data exists
    @AppStorage("testData.exportSamples") var generateExportSamples = true

    /// Generate real-time heart rate updates
    @AppStorage("testData.liveUpdates") var generateLiveUpdates = true

    // MARK: - Test Data Configuration

    /// Number of days of historical data to generate
    var historicalDataDays = 30

    /// Number of orthostatic events to generate per day
    var orthostaticEventsPerDay = 3

    /// Base heart rate for test data generation
    var baseHeartRate = 72

    /// Heart rate variation range
    var heartRateVariation = 25

    // MARK: - Public Methods

    /// Check if test data should be generated for a specific feature
    func shouldGenerateTestData(for feature: TestDataFeature) -> Bool {
        guard isTestDataEnabled else { return false }

        switch feature {
        case .heartRateHistory:
            return generateHeartRateHistory
        case .orthostaticEvents:
            return generateOrthostaticEvents
        case .dailyPatterns:
            return generateDailyPatterns
        case .exportSamples:
            return generateExportSamples
        case .liveUpdates:
            return generateLiveUpdates
        }
    }

    /// Clear all test data from storage
    func clearAllTestData() {
        // Clear heart rate history
        UserDefaults.standard.removeObject(forKey: "SecureHeart_HeartRateHistory")

        // Clear other test data keys
        UserDefaults.standard.removeObject(forKey: "testOrthostaticEvents")
        UserDefaults.standard.removeObject(forKey: "testSignificantChanges")

        print("🗑️ [TestDataManager] Cleared all test data")
    }

    /// Generate test heart rate entry
    func generateTestHeartRateEntry(baseRate: Int? = nil, variation: Int? = nil) -> HeartRateEntry {
        let base = baseRate ?? baseHeartRate
        let vary = variation ?? heartRateVariation
        let heartRate = base + Int.random(in: -vary...vary)

        return HeartRateEntry(
            heartRate: max(40, min(200, heartRate)), // Keep within realistic bounds
            date: Date(),
            delta: Int.random(in: -10...10),
            context: "Test Data"
        )
    }

    /// Generate test orthostatic event
    func generateTestOrthostaticEvent() -> OrthostaticEvent {
        let baseline = baseHeartRate + Int.random(in: -5...5)
        let peak = baseline + Int.random(in: 25...45) // POTS-like increase
        let increase = peak - baseline

        return OrthostaticEvent(
            timestamp: Date(),
            baselineHeartRate: baseline,
            peakHeartRate: peak,
            increase: increase,
            severity: increase >= 30 ? "Significant" : "Mild",
            sustainedDuration: Double.random(in: 180...600), // 3-10 minutes elevated
            recoveryTime: Bool.random() ? Double.random(in: 60...300) : nil, // 1-5 minutes to recover or nil
            isRecovered: Bool.random()
        )
    }

    /// Generate array of test heart rates with realistic pattern
    func generateRealisticHeartRatePattern(count: Int = 10) -> [Int] {
        var pattern: [Int] = []
        var currentRate = baseHeartRate

        for _ in 0..<count {
            // Add some realistic variation
            let change = Int.random(in: -5...5)
            currentRate = max(50, min(150, currentRate + change))
            pattern.append(currentRate)
        }

        return pattern
    }

    // MARK: - Settings UI Helper

    /// Get all test data settings for display in UI
    var allSettings: [(name: String, enabled: Bool, feature: TestDataFeature)] {
        [
            ("Heart Rate History", generateHeartRateHistory, .heartRateHistory),
            ("Orthostatic Events", generateOrthostaticEvents, .orthostaticEvents),
            ("Daily Patterns", generateDailyPatterns, .dailyPatterns),
            ("Export Samples", generateExportSamples, .exportSamples),
            ("Live Updates", generateLiveUpdates, .liveUpdates)
        ]
    }

    /// Toggle a specific feature
    func toggle(_ feature: TestDataFeature) {
        switch feature {
        case .heartRateHistory:
            generateHeartRateHistory.toggle()
        case .orthostaticEvents:
            generateOrthostaticEvents.toggle()
        case .dailyPatterns:
            generateDailyPatterns.toggle()
        case .exportSamples:
            generateExportSamples.toggle()
        case .liveUpdates:
            generateLiveUpdates.toggle()
        }
    }

    // MARK: - Logging

    /// Log current test data configuration
    func logConfiguration() {
        print("🔧 [TestDataManager] Configuration:")
        print("  - Master Switch: \(isTestDataEnabled)")
        print("  - Heart Rate History: \(generateHeartRateHistory)")
        print("  - Orthostatic Events: \(generateOrthostaticEvents)")
        print("  - Daily Patterns: \(generateDailyPatterns)")
        print("  - Export Samples: \(generateExportSamples)")
        print("  - Live Updates: \(generateLiveUpdates)")
    }
}

// MARK: - Test Data Feature Enum

enum TestDataFeature: String, CaseIterable {
    case heartRateHistory = "Heart Rate History"
    case orthostaticEvents = "Orthostatic Events"
    case dailyPatterns = "Daily Patterns"
    case exportSamples = "Export Samples"
    case liveUpdates = "Live Updates"

    var description: String {
        switch self {
        case .heartRateHistory:
            return "Generate historical heart rate data for trends and graphs"
        case .orthostaticEvents:
            return "Generate orthostatic response events for testing"
        case .dailyPatterns:
            return "Generate realistic daily activity patterns"
        case .exportSamples:
            return "Generate sample data when exporting empty datasets"
        case .liveUpdates:
            return "Generate real-time heart rate updates in simulator"
        }
    }

    var icon: String {
        switch self {
        case .heartRateHistory:
            return "clock.arrow.circlepath"
        case .orthostaticEvents:
            return "figure.stand"
        case .dailyPatterns:
            return "chart.line.uptrend.xyaxis"
        case .exportSamples:
            return "square.and.arrow.up"
        case .liveUpdates:
            return "heart.fill"
        }
    }
}

// MARK: - Test Data Templates

extension TestDataManager {

    /// Standard test heart rates for various conditions
    struct TestHeartRates {
        static let resting = [58, 60, 62, 65, 68, 70, 72]
        static let walking = [85, 88, 90, 92, 95, 98, 100]
        static let exercise = [120, 125, 130, 135, 140, 145, 150]
        static let potsEpisode = [70, 85, 95, 105, 115, 120, 125, 120, 110, 95, 85, 75]
        static let orthostaticResponse = [70, 72, 85, 98, 105, 108, 110, 108, 105, 100, 95, 88, 80, 75]
        static let stressResponse = [75, 80, 88, 95, 102, 108, 110, 108, 105, 98, 90, 82, 76]
    }

    /// Generate specific pattern types
    func generatePattern(_ type: PatternType) -> [Int] {
        switch type {
        case .resting:
            return TestHeartRates.resting.shuffled()
        case .walking:
            return TestHeartRates.walking.shuffled()
        case .exercise:
            return TestHeartRates.exercise.shuffled()
        case .potsEpisode:
            return TestHeartRates.potsEpisode
        case .orthostaticResponse:
            return TestHeartRates.orthostaticResponse
        case .stressResponse:
            return TestHeartRates.stressResponse
        }
    }

    enum PatternType {
        case resting
        case walking
        case exercise
        case potsEpisode
        case orthostaticResponse
        case stressResponse
    }
}