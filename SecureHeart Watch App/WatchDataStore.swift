//
//  WatchDataStore.swift
//  SecureHeart Watch App
//
//  Created: November 16, 2025
//  Purpose: Local persistent storage for heart rate data and settings on Apple Watch
//  Privacy-First: All data stored locally in UserDefaults, never transmitted externally
//

import Foundation
import SwiftUI

// MARK: - WatchDataStore - Local Persistence Manager

class WatchDataStore {
    static let shared = WatchDataStore()

    // Storage keys for UserDefaults
    private let heartRateKey = "SecureHeart_Watch_HeartRateHistory"
    private let orthostaticKey = "SecureHeart_Watch_OrthostaticEvents"
    private let settingsKey = "SecureHeart_Watch_Settings"
    private let significantChangesKey = "SecureHeart_Watch_SignificantChanges"

    // Maximum storage limits (to prevent UserDefaults bloat)
    private let maxHeartRateEntries = 1000  // ~1-2 days of data
    private let maxOrthostaticEvents = 100  // Several weeks of events

    private init() {
        print("💾 [WatchDataStore] Initialized")
    }

    // MARK: - Heart Rate History Persistence

    func saveHeartRateHistory(_ history: [HeartRateReading]) {
        var limitedHistory = history

        // Limit to max entries (keep most recent)
        if limitedHistory.count > maxHeartRateEntries {
            limitedHistory = Array(limitedHistory.prefix(maxHeartRateEntries))
            print("⚠️ [WatchDataStore] Trimmed heart rate history to \(maxHeartRateEntries) entries")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(limitedHistory) {
            UserDefaults.standard.set(encoded, forKey: heartRateKey)
            let sizeKB = encoded.count / 1024
            print("💾 [WatchDataStore] Saved \(limitedHistory.count) heart rate entries (\(sizeKB) KB)")
        } else {
            print("❌ [WatchDataStore] Failed to encode heart rate history")
        }
    }

    func loadHeartRateHistory() -> [HeartRateReading] {
        guard let data = UserDefaults.standard.data(forKey: heartRateKey) else {
            print("💾 [WatchDataStore] No saved heart rate history found")
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode([HeartRateReading].self, from: data)
            print("💾 [WatchDataStore] Loaded \(decoded.count) heart rate entries")
            return decoded
        } catch {
            print("❌ [WatchDataStore] Failed to decode heart rate history: \(error)")
            return []
        }
    }

    // MARK: - Orthostatic Events Persistence

    func saveOrthostaticEvents(_ events: [OrthostaticEvent]) {
        var limitedEvents = events

        // Limit to max events (keep most recent)
        if limitedEvents.count > maxOrthostaticEvents {
            limitedEvents = Array(limitedEvents.prefix(maxOrthostaticEvents))
            print("⚠️ [WatchDataStore] Trimmed orthostatic events to \(maxOrthostaticEvents) entries")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(limitedEvents) {
            UserDefaults.standard.set(encoded, forKey: orthostaticKey)
            let sizeKB = encoded.count / 1024
            print("💾 [WatchDataStore] Saved \(limitedEvents.count) orthostatic events (\(sizeKB) KB)")
        } else {
            print("❌ [WatchDataStore] Failed to encode orthostatic events")
        }
    }

    func loadOrthostaticEvents() -> [OrthostaticEvent] {
        guard let data = UserDefaults.standard.data(forKey: orthostaticKey) else {
            print("💾 [WatchDataStore] No saved orthostatic events found")
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode([OrthostaticEvent].self, from: data)
            print("💾 [WatchDataStore] Loaded \(decoded.count) orthostatic events")
            return decoded
        } catch {
            print("❌ [WatchDataStore] Failed to decode orthostatic events: \(error)")
            return []
        }
    }

    // MARK: - Settings Persistence

    func saveSettings(_ settings: WatchSettings) {
        let encoder = JSONEncoder()

        if let encoded = try? encoder.encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
            print("💾 [WatchDataStore] Saved settings - High: \(settings.highHeartRateThreshold), Low: \(settings.lowHeartRateThreshold)")
        } else {
            print("❌ [WatchDataStore] Failed to encode settings")
        }
    }

    func loadSettings() -> WatchSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            print("💾 [WatchDataStore] No saved settings found, using defaults")
            return WatchSettings.default
        }

        let decoder = JSONDecoder()

        do {
            let decoded = try decoder.decode(WatchSettings.self, from: data)
            print("💾 [WatchDataStore] Loaded settings - High: \(decoded.highHeartRateThreshold), Low: \(decoded.lowHeartRateThreshold)")
            return decoded
        } catch {
            print("❌ [WatchDataStore] Failed to decode settings: \(error), using defaults")
            return WatchSettings.default
        }
    }

    // MARK: - Data Management

    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: heartRateKey)
        UserDefaults.standard.removeObject(forKey: orthostaticKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)
        UserDefaults.standard.removeObject(forKey: significantChangesKey)
        print("🗑️ [WatchDataStore] Cleared all watch data")
    }

    func clearHeartRateHistory() {
        UserDefaults.standard.removeObject(forKey: heartRateKey)
        print("🗑️ [WatchDataStore] Cleared heart rate history")
    }

    func clearOrthostaticEvents() {
        UserDefaults.standard.removeObject(forKey: orthostaticKey)
        print("🗑️ [WatchDataStore] Cleared orthostatic events")
    }

    func getDataSize() -> Int {
        let hrSize = UserDefaults.standard.data(forKey: heartRateKey)?.count ?? 0
        let orthoSize = UserDefaults.standard.data(forKey: orthostaticKey)?.count ?? 0
        let settingsSize = UserDefaults.standard.data(forKey: settingsKey)?.count ?? 0
        let totalSize = hrSize + orthoSize + settingsSize

        let totalKB = totalSize / 1024
        print("📊 [WatchDataStore] Total storage: \(totalKB) KB (HR: \(hrSize/1024)KB, Ortho: \(orthoSize/1024)KB)")

        return totalSize
    }

    func getStorageInfo() -> StorageInfo {
        let hrCount = loadHeartRateHistory().count
        let orthoCount = loadOrthostaticEvents().count
        let size = getDataSize()

        return StorageInfo(
            heartRateEntries: hrCount,
            orthostaticEvents: orthoCount,
            totalSizeBytes: size
        )
    }
}

// MARK: - Storage Info Model

struct StorageInfo {
    let heartRateEntries: Int
    let orthostaticEvents: Int
    let totalSizeBytes: Int

    var totalSizeKB: Int {
        totalSizeBytes / 1024
    }

    var formattedSize: String {
        if totalSizeKB < 1 {
            return "\(totalSizeBytes) bytes"
        } else if totalSizeKB < 1024 {
            return "\(totalSizeKB) KB"
        } else {
            let mb = Double(totalSizeKB) / 1024.0
            return String(format: "%.1f MB", mb)
        }
    }
}

// MARK: - Watch Settings Model

struct WatchSettings: Codable {
    var highHeartRateThreshold: Int
    var lowHeartRateThreshold: Int
    var orthostaticThreshold: Int
    var recordingInterval: TimeInterval
    var enableHapticAlerts: Bool

    static let `default` = WatchSettings(
        highHeartRateThreshold: 150,
        lowHeartRateThreshold: 40,
        orthostaticThreshold: 30,
        recordingInterval: 60.0,
        enableHapticAlerts: true
    )
}

// MARK: - Note About Data Models
//
// HeartRateReading, OrthostaticEvent, and OrthostacSeverity are defined in HeartRateManager.swift
// We make them Codable there to enable persistence here
// This keeps the models in one place and avoids duplication
