# SecureHeart MVP1 - Standalone Apple Watch App
## Implementation Plan

**Last Updated:** November 16, 2025
**Status:** 🔄 IN PROGRESS
**Target Ship Date:** November 23, 2025 (1 week)
**Strategy:** Ship minimal viable standalone watch app, defer iPhone companion to MVP2

---

## 📱 MVP1 Scope: Standalone Apple Watch App

### ✅ Features INCLUDED in MVP1 (All Currently Working)

| Feature | Status | Location | Notes |
|---------|--------|----------|-------|
| **Real-time Heart Rate Display** | ✅ Complete | HeartRateView.swift | Large BPM display, color zones |
| **Color-Coded Heart Rate Zones** | ✅ Complete | HeartRateManager.swift | Blue/Green/Yellow/Orange/Red |
| **14 Color Theme Variants** | ✅ Complete | HeartRateView.swift | Full customization |
| **6 Watch Face Styles** | ✅ Complete | HeartRateView.swift | Classic/Minimal/Chunky/Numbers/etc |
| **POTS Orthostatic Detection** | ✅ Complete | HeartRateManager.swift | +30 BPM standing response |
| **Posture Detection** | ✅ Complete | MotionDetectionManager.swift | Standing/Sitting/Walking |
| **Haptic Feedback** | ✅ Complete | HeartRateManager.swift | Alerts for events |
| **Always-On Display** | ✅ Complete | HeartRateView.swift | watchOS integration |
| **Heart Rate History (Session)** | ✅ Complete | HeartRateManager.swift | In-memory during session |
| **Settings Panel** | ✅ Complete | SettingsView.swift | Theme/color customization |

### 🔧 Features NEEDING MODIFICATION for MVP1

| Feature | Current State | Required Change | Priority | Effort |
|---------|--------------|-----------------|----------|--------|
| **Persistent Data Storage** | Volatile (lost on restart) | Add UserDefaults persistence | HIGH | 2 hours |
| **Emergency Thresholds** | Synced from iPhone | Add watch-side settings UI | HIGH | 3 hours |
| **WatchConnectivity** | Sends to iPhone | Comment out calls | HIGH | 1 hour |
| **Test Data Button** | Sends to iPhone | Remove from settings | LOW | 15 min |

### 📦 Features DEFERRED to MVP2 (iPhone Companion App)

| Feature | Why Deferred | MVP2 Timeline |
|---------|--------------|---------------|
| **Emergency Contact Notifications** | Requires iPhone + Firebase | Week 4-6 |
| **SMS/Email Alerts** | Requires cloud functions | Week 4-6 |
| **Contact Verification** | Requires iPhone UI | Week 6-8 |
| **Data Export (CSV/PDF)** | Better on iPhone | Week 4-5 |
| **Weekly/Monthly Trends** | Better on iPhone screen | Week 5-6 |
| **Firebase Integration** | Emergency-only feature | Week 4-6 |
| **Medical Data Encryption** | For cloud sync only | Week 6-7 |
| **iPhone Dashboard** | Companion app feature | Week 4-8 |

---

## 🛠️ Implementation Tasks

### Phase 1: Code Cleanup & Preparation (Day 1-2)

#### Task 1.1: Create WatchDataStore for Persistence
**File:** `/SecureHeart Watch App/WatchDataStore.swift` (NEW)
**Priority:** HIGH
**Effort:** 2 hours
**Status:** ⏳ PENDING

**Implementation:**
```swift
// MARK: - WatchDataStore.swift (NEW FILE)
import Foundation

class WatchDataStore {
    static let shared = WatchDataStore()

    private let heartRateKey = "SecureHeart_Watch_HeartRateHistory"
    private let orthostaticKey = "SecureHeart_Watch_OrthostaticEvents"
    private let settingsKey = "SecureHeart_Watch_Settings"

    // MARK: - Heart Rate Persistence
    func saveHeartRateHistory(_ history: [HeartRateReading]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(history) {
            UserDefaults.standard.set(encoded, forKey: heartRateKey)
        }
    }

    func loadHeartRateHistory() -> [HeartRateReading] {
        guard let data = UserDefaults.standard.data(forKey: heartRateKey),
              let decoded = try? JSONDecoder().decode([HeartRateReading].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Orthostatic Events Persistence
    func saveOrthostaticEvents(_ events: [OrthostaticEvent]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(events) {
            UserDefaults.standard.set(encoded, forKey: orthostaticKey)
        }
    }

    func loadOrthostaticEvents() -> [OrthostaticEvent] {
        guard let data = UserDefaults.standard.data(forKey: orthostaticKey),
              let decoded = try? JSONDecoder().decode([OrthostaticEvent].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Settings Persistence
    func saveSettings(_ settings: WatchSettings) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    func loadSettings() -> WatchSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(WatchSettings.self, from: data) else {
            return WatchSettings.default
        }
        return decoded
    }

    // MARK: - Data Management
    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: heartRateKey)
        UserDefaults.standard.removeObject(forKey: orthostaticKey)
        print("🗑️ [WatchDataStore] Cleared all watch data")
    }

    func getDataSize() -> Int {
        // Estimate storage size
        let hrSize = (UserDefaults.standard.data(forKey: heartRateKey)?.count ?? 0)
        let orthoSize = (UserDefaults.standard.data(forKey: orthostaticKey)?.count ?? 0)
        return hrSize + orthoSize
    }
}

// MARK: - Settings Model
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
```

**Testing:**
- [ ] Save heart rate history with 100 entries
- [ ] Restart watch app, verify history loads
- [ ] Save orthostatic events
- [ ] Restart watch app, verify events load
- [ ] Test clearAllData() function
- [ ] Verify getDataSize() returns reasonable values

---

#### Task 1.2: Comment Out WatchConnectivity Calls
**File:** `/SecureHeart Watch App/HeartRateManager.swift`
**Priority:** HIGH
**Effort:** 1 hour
**Status:** ⏳ PENDING

**Changes:**

**Location 1: Line ~803 - Heart Rate Updates**
```swift
// MARK: - MVP2 FEATURE - Send Heart Rate to iPhone
// TODO: Re-enable for MVP2 when iPhone app is available
// Commented out: 2025-11-16 for MVP1 standalone watch app
/*
WatchConnectivityManager.shared.sendHeartRateUpdate(
    heartRate: currentHeartRate,
    delta: heartRateDelta,
    isStanding: isStanding
)
*/
print("💓 [WATCH-MVP1] Heart rate: \(currentHeartRate) BPM (not synced to iPhone)")
```

**Location 2: Line ~841 - Significant Changes**
```swift
// MARK: - MVP2 FEATURE - Send Significant Changes to iPhone
// TODO: Re-enable for MVP2 when iPhone app is available
// Commented out: 2025-11-16 for MVP1 standalone watch app
/*
WatchConnectivityManager.shared.sendSignificantChange(
    fromRate: previousRate,
    toRate: currentRate,
    delta: delta
)
*/
print("📊 [WATCH-MVP1] Significant change: \(delta) BPM (not synced to iPhone)")
```

**Location 3: Line ~1209 - Orthostatic Events**
```swift
// MARK: - MVP2 FEATURE - Send Orthostatic Events to iPhone
// TODO: Re-enable for MVP2 when iPhone app is available
// Commented out: 2025-11-16 for MVP1 standalone watch app
/*
WatchConnectivityManager.shared.sendOrthostaticEvent(
    baselineHeartRate: baselineHeartRate,
    peakHeartRate: peakHeartRate,
    increase: increase,
    severity: severity,
    sustainedDuration: sustainedDuration,
    recoveryTime: recoveryTime,
    isRecovered: isRecovered,
    timestamp: timestamp
)
*/
print("🚨 [WATCH-MVP1] Orthostatic event: +\(increase) BPM (saved locally)")

// NEW: Save to local storage instead
WatchDataStore.shared.saveOrthostaticEvents(orthostaticEvents)
```

**Testing:**
- [ ] Heart rate monitoring still works
- [ ] No crashes when iPhone not paired
- [ ] Log messages show "WATCH-MVP1" prefix
- [ ] Events saved to local storage

---

#### Task 1.3: Add Persistence Calls to HeartRateManager
**File:** `/SecureHeart Watch App/HeartRateManager.swift`
**Priority:** HIGH
**Effort:** 1 hour
**Status:** ⏳ PENDING

**Changes:**

**Add to init() - Load Saved Data:**
```swift
init() {
    // ... existing initialization ...

    // MARK: - MVP1 FEATURE - Load Persistent Data
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
    self.highHeartRateThreshold = settings.highHeartRateThreshold
    self.lowHeartRateThreshold = settings.lowHeartRateThreshold
    print("⚙️ [WATCH-MVP1] Loaded settings - High: \(settings.highHeartRateThreshold), Low: \(settings.lowHeartRateThreshold)")
}
```

**Add Periodic Auto-Save (every 60 seconds):**
```swift
private var persistenceTimer: Timer?

private func startPeriodicPersistence() {
    persistenceTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
        self?.saveDataToStorage()
    }
    print("💾 [WATCH-MVP1] Started periodic data persistence (every 60s)")
}

private func saveDataToStorage() {
    WatchDataStore.shared.saveHeartRateHistory(heartRateHistory)
    WatchDataStore.shared.saveOrthostaticEvents(orthostaticEvents)

    let size = WatchDataStore.shared.getDataSize()
    print("💾 [WATCH-MVP1] Saved data to watch storage (\(size) bytes)")
}

deinit {
    persistenceTimer?.invalidate()
    saveDataToStorage() // Save on app termination
}
```

**Testing:**
- [ ] Data loads on app launch
- [ ] Data saves every 60 seconds
- [ ] Data persists after force-quit
- [ ] No performance impact

---

#### Task 1.4: Add Watch-Side Settings UI
**File:** `/SecureHeart Watch App/SettingsView.swift`
**Priority:** MEDIUM
**Effort:** 3 hours
**Status:** ⏳ PENDING

**Changes:**

**Add Emergency Threshold Settings Section:**
```swift
// MARK: - Emergency Thresholds Section (MVP1 - Watch-Side Settings)
Section(header: Text("Emergency Thresholds")) {
    VStack(alignment: .leading, spacing: 8) {
        Text("High Heart Rate Alert")
            .font(.caption)
            .foregroundColor(.secondary)

        Stepper(value: $highThreshold, in: 100...220, step: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(highThreshold) BPM")
                    .font(.headline)
            }
        }
        .onChange(of: highThreshold) { newValue in
            saveThresholds()
        }
    }

    VStack(alignment: .leading, spacing: 8) {
        Text("Low Heart Rate Alert")
            .font(.caption)
            .foregroundColor(.secondary)

        Stepper(value: $lowThreshold, in: 30...90, step: 5) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.blue)
                Text("\(lowThreshold) BPM")
                    .font(.headline)
            }
        }
        .onChange(of: lowThreshold) { newValue in
            saveThresholds()
        }
    }

    VStack(alignment: .leading, spacing: 8) {
        Text("Orthostatic Threshold")
            .font(.caption)
            .foregroundColor(.secondary)

        Stepper(value: $orthostaticThreshold, in: 20...50, step: 5) {
            HStack {
                Image(systemName: "figure.stand")
                    .foregroundColor(.orange)
                Text("+\(orthostaticThreshold) BPM")
                    .font(.headline)
            }
        }
        .onChange(of: orthostaticThreshold) { newValue in
            saveThresholds()
        }
    }
}

// Add state variables
@State private var highThreshold: Int = 150
@State private var lowThreshold: Int = 40
@State private var orthostaticThreshold: Int = 30

// Add save function
private func saveThresholds() {
    var settings = WatchDataStore.shared.loadSettings()
    settings.highHeartRateThreshold = highThreshold
    settings.lowHeartRateThreshold = lowThreshold
    settings.orthostaticThreshold = orthostaticThreshold
    WatchDataStore.shared.saveSettings(settings)

    print("💾 [WATCH-MVP1] Saved thresholds - High: \(highThreshold), Low: \(lowThreshold), Ortho: \(orthostaticThreshold)")
}
```

**Testing:**
- [ ] Steppers work smoothly
- [ ] Settings save immediately
- [ ] Settings persist after restart
- [ ] Thresholds apply to monitoring

---

#### Task 1.5: Remove "Send Test Data" Button
**File:** `/SecureHeart Watch App/SettingsView.swift`
**Priority:** LOW
**Effort:** 15 minutes
**Status:** ⏳ PENDING

**Changes:**
```swift
// MARK: - MVP2 FEATURE - Send Test Data to iPhone
// TODO: Re-enable for MVP2 when iPhone app is available
// Commented out: 2025-11-16 for MVP1 standalone watch app
/*
Button(action: {
    WatchConnectivityManager.shared.sendTestData()
}) {
    Label("Send Test Data", systemImage: "paperplane.fill")
}
*/
```

**Testing:**
- [ ] Button no longer visible
- [ ] No crashes in settings view

---

### Phase 2: Testing & Validation (Day 3-4)

#### Task 2.1: Real Apple Watch Testing
**Priority:** CRITICAL
**Effort:** 4 hours
**Status:** ⏳ PENDING

**Testing Checklist:**
- [ ] Install on real Apple Watch (not simulator)
- [ ] Heart rate monitoring works without iPhone nearby
- [ ] Data persists after removing iPhone pairing
- [ ] All 14 color themes work
- [ ] All 6 watch faces work
- [ ] Orthostatic detection works
- [ ] Haptic feedback works
- [ ] Settings save correctly
- [ ] Battery life acceptable (24+ hours)
- [ ] No crashes during 24-hour test
- [ ] Memory usage acceptable (<50MB)

#### Task 2.2: Edge Case Testing
**Priority:** HIGH
**Effort:** 2 hours
**Status:** ⏳ PENDING

**Test Cases:**
- [ ] Force quit app, restart, verify data loads
- [ ] Fill history with 1000+ entries, verify performance
- [ ] Airplane mode enabled, verify app works
- [ ] Bluetooth off, verify app works
- [ ] Low battery mode, verify app works
- [ ] Always-on display enabled, verify visibility
- [ ] Multiple orthostatic events in 1 hour
- [ ] Heart rate stays at threshold for extended period

---

### Phase 3: App Store Preparation (Day 5-7)

#### Task 3.1: Privacy Policy & Documentation
**Priority:** CRITICAL
**Effort:** 3 hours
**Status:** ⏳ PENDING

**Required Documents:**
- [ ] Privacy Policy emphasizing local-only storage
- [ ] HealthKit usage description
- [ ] App description for App Store
- [ ] Feature list for App Store
- [ ] Keywords for App Store search
- [ ] Support email/website

#### Task 3.2: Screenshots & Marketing Materials
**Priority:** HIGH
**Effort:** 2 hours
**Status:** ⏳ PENDING

**Required Screenshots (from real Apple Watch):**
- [ ] Main heart rate display (Classic theme)
- [ ] Color theme selection
- [ ] Watch face variants
- [ ] Orthostatic event detection
- [ ] Settings screen
- [ ] Always-on display mode

#### Task 3.3: App Store Listing
**Priority:** HIGH
**Effort:** 2 hours
**Status:** ⏳ PENDING

**App Store Information:**
- [ ] App name: "SecureHeart - POTS Monitor"
- [ ] Subtitle: "Local Heart Rate Tracking"
- [ ] Category: Health & Fitness
- [ ] Age rating: 4+
- [ ] Price: $2.99 (or free with in-app purchase)
- [ ] Version: 1.0.0
- [ ] Build number: 1

---

## 📊 Progress Tracking

### Overall MVP1 Progress: 0% Complete

| Phase | Tasks | Completed | Progress |
|-------|-------|-----------|----------|
| Phase 1: Code Cleanup | 5 | 0 | ⬜⬜⬜⬜⬜ 0% |
| Phase 2: Testing | 2 | 0 | ⬜⬜⬜⬜⬜ 0% |
| Phase 3: App Store | 3 | 0 | ⬜⬜⬜⬜⬜ 0% |

### Daily Progress Goals

**Day 1 (Nov 16):** ✅ Strategic planning, documentation, worklog setup
**Day 2 (Nov 17):** Task 1.1, 1.2, 1.3 (WatchDataStore + persistence)
**Day 3 (Nov 18):** Task 1.4, 1.5 (Settings UI)
**Day 4 (Nov 19):** Task 2.1 (Real device testing)
**Day 5 (Nov 20):** Task 2.2 (Edge case testing)
**Day 6 (Nov 21):** Task 3.1, 3.2 (Documentation + screenshots)
**Day 7 (Nov 22):** Task 3.3 (App Store submission)
**Day 8 (Nov 23):** 🚀 **SHIP MVP1**

---

## 🚫 What We're NOT Doing in MVP1

| Feature | Why Deferred | When |
|---------|--------------|------|
| iPhone app | Complexity, time | MVP2 (Week 4-8) |
| Emergency contacts | Requires iPhone | MVP2 |
| Firebase integration | Emergency-only | MVP2 |
| SMS/Email alerts | Cloud functions needed | MVP2 |
| Data export | Better on iPhone | MVP2 |
| Weekly/monthly trends | Better on iPhone screen | MVP2 |
| Contact verification | iPhone UI needed | MVP2 |
| Medical encryption | For cloud sync only | MVP2 |

---

## 📝 Success Criteria for MVP1 Ship

- [ ] All Phase 1 tasks complete
- [ ] All Phase 2 testing passed
- [ ] All Phase 3 materials prepared
- [ ] App submitted to App Store
- [ ] Test flight build available
- [ ] No critical bugs
- [ ] Battery life >24 hours
- [ ] Privacy policy published
- [ ] Support email active

---

## 🔄 Next Steps After MVP1 Ships

1. Monitor App Store review process
2. Gather user feedback
3. Fix any critical bugs
4. Begin MVP2 planning (iPhone companion app)
5. Design emergency contact UI for iPhone
6. Re-enable Firebase integration
7. Build notification system

---

**Document Version:** 1.0
**Last Updated:** November 16, 2025 17:00 PST
**Owner:** Laura Money
**Developer:** Claude Code Assistant
