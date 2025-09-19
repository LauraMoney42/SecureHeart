# SecureHeart Test Data Documentation
## Complete Test Data Locations & Management Guide

### 📍 TEST DATA LOCATIONS BY FILE

## 1. Watch App Test Data

### `/SecureHeart Watch App/HeartRateManager.swift`

#### Lines 212-216: Main Test Data Toggle (CURRENTLY COMMENTED OUT)
```swift
// COMMENTED OUT FOR REAL DEVICE TESTING
// #if DEBUG && targetEnvironment(simulator)
// // Add test data for simulator testing
// addTestData()
// #endif
```
**Status:** ❌ DISABLED for real device testing
**To Enable:** Uncomment lines 213-215

#### Lines 219-223: Test Data Cleanup for Real Devices
```swift
#if !targetEnvironment(simulator)
orthostaticEvents.removeAll()
significantChanges.removeAll()
print("🧹 [WATCH] Cleared test data for real device testing")
#endif
```
**Status:** ✅ ACTIVE - Clears test data on real devices

#### Lines 226-576: Complete Simulator Test Data Functions
```swift
#if DEBUG && targetEnvironment(simulator)
    // Contains: addTestData(), addTestOrthostaticEvents(),
    // simulateOrthostaticEvent(), createStandingResponseEpisode()
#endif
```
**Status:** Wrapped in DEBUG + simulator check
**Contains:**
- Test heart rates: `[72, 85, 93, 110, 125, 145, 160, 135, 95, 78]`
- Random rate generation: `Int.random(in: 60...180)`
- Orthostatic event simulation
- Standing response patterns

---

## 2. iPhone App Test Data

### `/SecureHeart/HealthManager.swift`

#### Lines 137-141: Test Data Cleanup
```swift
clearStoredHeartRateHistory()
orthostaticEvents.removeAll()
print("🧹 [iPhone] Cleared orthostatic events for real device testing")
```
**Status:** ✅ ACTIVE - Clears existing test data

#### Lines 145-163: Main Test Data Generation (CURRENTLY COMMENTED OUT)
```swift
/*
#if targetEnvironment(simulator)
print("🔧 [INIT] Running in simulator - generating test data")
generateRealisticMedicalTestData()
#else
// ... fallback code ...
#endif
*/
```
**Status:** ❌ DISABLED - Entire block commented out
**To Enable:** Uncomment lines 145-162

#### Lines 677-940: generateRealisticMedicalTestData() Function
- Generates 30 days of comprehensive POTS test data
- Creates realistic medical patterns
- Includes orthostatic events, daily variations, stress episodes
**Status:** Function exists but never called (callers commented out)

---

## 3. ContentView Test Data

### `/SecureHeart/ContentView.swift`

#### Lines 440-456: Orthostatic Chart Data (FIXED)
```swift
// Use real orthostatic events from HealthManager
var orthostaticEvents: [(startTime: String, endTime: String, data: [...])] {
    return healthManager.orthostaticEvents.map { event in
        // Converts real events to chart format
    }
}
```
**Status:** ✅ Now uses REAL data from healthManager
**Previous:** Had hardcoded test orthostatic events

#### Lines 2062-2150: generateSampleTodaysData() Function
- Generates 8 hours of realistic POTS data
- Called when no real data exists for daily graph
**Status:** ⚠️ ACTIVE - Auto-generates when data is empty

---

## 4. Export View Test Data

### `/SecureHeart/Views/ExportView.swift`

#### Lines 24-29: Fallback Sample Data
```swift
if fullHistory.isEmpty {
    if cachedSampleData == nil {
        print("⚠️ [EXPORT] No heart rate data available, generating sample data")
        cachedSampleData = generateSampleExportData()
    }
    return cachedSampleData ?? []
}
```
**Status:** ⚠️ ACTIVE - Generates sample data for empty exports

#### Lines 487-520: generateSampleExportData() Function
- Creates 30 sample readings over 1 hour
- Base rate 75 BPM with realistic variations
**Status:** Function exists and is called when no real data

---

## 🔧 HOW TO TOGGLE TEST DATA

### To ENABLE All Test Data (for development):

1. **Watch App:** Uncomment lines 213-215 in `HeartRateManager.swift`
2. **iPhone App:** Uncomment lines 145-162 in `HealthManager.swift`
3. **Remove cleanup calls:** Comment out lines 137-141 in `HealthManager.swift`
4. **Remove Watch cleanup:** Comment out lines 219-223 in Watch `HeartRateManager.swift`

### To DISABLE All Test Data (for production):

1. **Keep commented:** Lines 213-215 in Watch `HeartRateManager.swift`
2. **Keep commented:** Lines 145-162 in iPhone `HealthManager.swift`
3. **Keep active:** Data cleanup on lines 137-141 in `HealthManager.swift`
4. **Keep active:** Watch cleanup on lines 219-223 in Watch `HeartRateManager.swift`
5. **Optional:** Return empty arrays in export/display fallbacks

### To Enable PARTIAL Test Data:

- **Simulator Only:** Use `#if targetEnvironment(simulator)` wrapper
- **Debug Only:** Use `#if DEBUG` wrapper
- **Manual Toggle:** Create a Settings toggle that controls test data generation

---

## 🎯 RECOMMENDED: Create TestDataManager Component

To make this easier to manage, consider creating a centralized `TestDataManager`:

```swift
// TestDataManager.swift
import Foundation

class TestDataManager {
    static let shared = TestDataManager()

    // Master switch for all test data
    var isTestDataEnabled: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // Individual feature toggles
    var generateHeartRateHistory = true
    var generateOrthostaticEvents = true
    var generateDailyPatterns = true
    var generateExportSamples = true

    func shouldGenerateTestData(for feature: String) -> Bool {
        guard isTestDataEnabled else { return false }

        switch feature {
        case "heartRateHistory": return generateHeartRateHistory
        case "orthostaticEvents": return generateOrthostaticEvents
        case "dailyPatterns": return generateDailyPatterns
        case "exportSamples": return generateExportSamples
        default: return false
        }
    }
}
```

This would allow easy toggling via:
```swift
if TestDataManager.shared.shouldGenerateTestData(for: "heartRateHistory") {
    generateRealisticMedicalTestData()
}
```

---

## 📊 TEST DATA SUMMARY

| Component | Location | Status | Lines |
|-----------|----------|---------|-------|
| Watch Test Data | Watch/HeartRateManager.swift | ❌ Disabled | 213-215 |
| Watch Cleanup | Watch/HeartRateManager.swift | ✅ Active | 219-223 |
| iPhone Test Data | HealthManager.swift | ❌ Disabled | 145-162 |
| iPhone Cleanup | HealthManager.swift | ✅ Active | 137-141 |
| Orthostatic Chart | ContentView.swift | ✅ Real Data | 440-456 |
| Daily Graph Fallback | ContentView.swift | ⚠️ Active | 2062-2150 |
| Export Fallback | ExportView.swift | ⚠️ Active | 24-29, 487-520 |

**Legend:**
- ✅ Active and working as intended
- ❌ Disabled/commented out
- ⚠️ Active but generates test data when real data is empty