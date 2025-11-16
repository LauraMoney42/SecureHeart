# 🎯 MVP1 DEVELOPER TASKS - STANDALONE WATCH APP

**Date**: November 16, 2025, 5:00 PM
**Status**: 🚀 Strategic Pivot - Watch App First, iPhone App MVP2
**Target Ship Date**: November 23, 2025 (1 week)
**Focus**: Standalone Apple Watch app without iPhone dependencies

---

## 📋 **STRATEGIC SHIFT NOTICE**

### **New Direction (Nov 16, 2025):**
- **MVP1:** Standalone Apple Watch app (ship in 1 week)
- **MVP2:** iPhone companion app with emergency features (ship in 4-8 weeks)
- **Rationale:** Faster time to market, validate core value, simpler scope

### **What Changed:**
- iPhone app features → Deferred to MVP2
- Emergency contacts/Firebase → Deferred to MVP2
- Watch app → Make fully standalone and self-sufficient
- Test data → Already disabled for real device testing

---

## 🚨 **CRITICAL MVP1 TASKS** (Ship Week: Nov 16-23)

### **TASK_MVP1_001: Create WatchDataStore for Persistent Storage** (HIGH PRIORITY - 2 HOURS)
**Status**: ⏳ PENDING
**File**: `/SecureHeart Watch App/WatchDataStore.swift` (NEW)
**Priority**: CRITICAL - Required for data persistence
**Requirements:**
- Create new WatchDataStore.swift class
- Implement UserDefaults-based persistence
- Add save/load methods for heart rate history
- Add save/load methods for orthostatic events
- Add save/load methods for watch settings
- Add clearAllData() method
- Add getDataSize() method for storage monitoring

**Implementation Details:**
- See MVP1_IMPLEMENTATION_PLAN.md, Task 1.1 for complete code
- Use JSONEncoder/JSONDecoder for serialization
- Store in UserDefaults with appropriate keys
- Implement WatchSettings struct for configuration

**Success Criteria:**
- [ ] WatchDataStore class compiles without errors
- [ ] Save/load methods work correctly
- [ ] Data persists after app restart
- [ ] No memory leaks

**Testing:**
- [ ] Save 100 heart rate entries, restart, verify load
- [ ] Save orthostatic events, restart, verify load
- [ ] Test clearAllData() removes all data
- [ ] Verify getDataSize() returns reasonable values

---

### **TASK_MVP1_002: Comment Out WatchConnectivity Calls** (HIGH PRIORITY - 1 HOUR)
**Status**: ⏳ PENDING
**File**: `/SecureHeart Watch App/HeartRateManager.swift`
**Priority**: CRITICAL - Required for standalone mode
**Requirements:**
- Comment out (DO NOT DELETE) WatchConnectivityManager.shared.sendHeartRateUpdate() - Line ~803
- Comment out WatchConnectivityManager.shared.sendSignificantChange() - Line ~841
- Comment out WatchConnectivityManager.shared.sendOrthostaticEvent() - Line ~1209
- Add MVP2 comment headers for each commented section
- Add console log messages showing "WATCH-MVP1" prefix
- Replace iPhone sync with local storage saves

**Code Pattern:**
```swift
// MARK: - MVP2 FEATURE - [Description]
// TODO: Re-enable for MVP2 when iPhone app is available
// Commented out: 2025-11-16 for MVP1 standalone watch app
/*
[original WatchConnectivity code]
*/
print("💓 [WATCH-MVP1] [Event] (saved locally, not synced to iPhone)")
```

**Success Criteria:**
- [ ] All 3 WatchConnectivity calls commented out
- [ ] MVP2 comment headers added
- [ ] App builds without errors
- [ ] No crashes when iPhone not paired
- [ ] Log messages show "WATCH-MVP1" prefix

**Testing:**
- [ ] Build and run on real Apple Watch
- [ ] Verify no crashes without iPhone
- [ ] Verify heart rate monitoring still works
- [ ] Check console logs show MVP1 messages

---

### **TASK_MVP1_003: Add Persistence Calls to HeartRateManager** (HIGH PRIORITY - 1 HOUR)
**Status**: ⏳ PENDING
**File**: `/SecureHeart Watch App/HeartRateManager.swift`
**Priority**: CRITICAL - Required for data persistence
**Requirements:**
- Add WatchDataStore.loadHeartRateHistory() call in init()
- Add WatchDataStore.loadOrthostaticEvents() call in init()
- Add WatchDataStore.loadSettings() call in init()
- Create periodic auto-save timer (every 60 seconds)
- Add saveDataToStorage() method
- Add save call in deinit for app termination
- Add save call after orthostatic events

**Implementation Details:**
- See MVP1_IMPLEMENTATION_PLAN.md, Task 1.3 for complete code
- Use Timer.scheduledTimer for periodic saves
- Invalidate timer in deinit
- Log save operations with size

**Success Criteria:**
- [ ] Data loads on app launch
- [ ] Data saves every 60 seconds automatically
- [ ] Data saves on app termination
- [ ] Data persists after force-quit
- [ ] No performance impact from auto-save

**Testing:**
- [ ] Launch app, verify history loads from previous session
- [ ] Monitor console for auto-save messages every 60s
- [ ] Force-quit app, restart, verify data persists
- [ ] Generate orthostatic event, verify it's saved

---

### **TASK_MVP1_004: Add Watch-Side Settings UI** (MEDIUM PRIORITY - 3 HOURS)
**Status**: ⏳ PENDING
**File**: `/SecureHeart Watch App/SettingsView.swift`
**Priority**: MEDIUM - Nice to have for MVP1
**Requirements:**
- Add "Emergency Thresholds" section to SettingsView
- Add High Heart Rate stepper (100-220 BPM, step 10)
- Add Low Heart Rate stepper (30-90 BPM, step 5)
- Add Orthostatic Threshold stepper (20-50 BPM, step 5)
- Add onChange handlers to save immediately
- Load saved settings on view appear
- Add icons for each setting (heart.fill, figure.stand)

**Implementation Details:**
- See MVP1_IMPLEMENTATION_PLAN.md, Task 1.4 for complete code
- Use @State variables for UI binding
- Use WatchDataStore for persistence
- Show current values prominently

**Success Criteria:**
- [ ] Settings UI displays correctly on watch
- [ ] Steppers work smoothly
- [ ] Settings save immediately on change
- [ ] Settings persist after app restart
- [ ] Settings apply to heart rate monitoring

**Testing:**
- [ ] Change high threshold, verify it saves
- [ ] Restart app, verify threshold persisted
- [ ] Trigger high threshold, verify alert works
- [ ] Test all three threshold settings

---

### **TASK_MVP1_005: Remove "Send Test Data" Button** (LOW PRIORITY - 15 MIN)
**Status**: ⏳ PENDING
**File**: `/SecureHeart Watch App/SettingsView.swift`
**Priority**: LOW - Cleanup task
**Requirements:**
- Comment out "Send Test Data" button (Line ~169)
- Add MVP2 comment header
- Verify settings view still displays correctly

**Code Pattern:**
```swift
// MARK: - MVP2 FEATURE - Send Test Data to iPhone
// TODO: Re-enable for MVP2 when iPhone app is available
// Commented out: 2025-11-16 for MVP1 standalone watch app
/*
Button(action: { ... }) {
    Label("Send Test Data", systemImage: "paperplane.fill")
}
*/
```

**Success Criteria:**
- [ ] Button no longer visible
- [ ] No crashes in settings view
- [ ] Settings view layout still looks good

---

## 🧪 **TESTING TASKS** (Days 3-4)

### **TASK_MVP1_TEST_001: Real Apple Watch Testing** (CRITICAL - 4 HOURS)
**Status**: ⏳ PENDING
**Priority**: CRITICAL - Must pass before ship
**Requirements:**
- Install on real Apple Watch (not simulator)
- Test without iPhone nearby
- Test all 14 color themes
- Test all 6 watch faces
- Test orthostatic detection
- Test haptic feedback
- Test settings persistence
- Monitor battery life (24+ hours)
- Test for 24 hours continuous
- Check memory usage (<50MB)

**Testing Checklist:**
- [ ] Heart rate monitoring works without iPhone
- [ ] Data persists after removing iPhone pairing
- [ ] All 14 color themes display correctly
- [ ] All 6 watch faces work smoothly
- [ ] Orthostatic detection triggers correctly
- [ ] Haptic feedback works for events
- [ ] Settings save and load correctly
- [ ] Battery life exceeds 24 hours
- [ ] No crashes during 24-hour test
- [ ] Memory usage acceptable

---

## 📦 **DEFERRED TO MVP2** (iPhone Companion App - Week 4-8)

All tasks below are **postponed** until MVP2 development begins. These features require the iPhone companion app and will be implemented after MVP1 ships.

### **MVP2_TASK_001: Emergency Contact Notifications**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Requires iPhone app + Firebase integration
**Timeline**: Week 4-6
**Description**: SMS/Email/Push notifications to emergency contacts when heart rate thresholds exceeded

### **MVP2_TASK_002: Firebase Integration**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Emergency feature only
**Timeline**: Week 4-6
**Description**: Cloud Functions, Firestore, FCM for emergency alerts

### **MVP2_TASK_003: Contact Verification System**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Requires iPhone UI
**Timeline**: Week 6-7
**Description**: Phone/email verification for emergency contacts

### **MVP2_TASK_004: Data Export (CSV/PDF)**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Better user experience on iPhone
**Timeline**: Week 4-5
**Description**: Export heart rate data and orthostatic events to CSV and PDF

### **MVP2_TASK_005: Weekly/Monthly Trend Graphs**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Better visualization on iPhone screen
**Timeline**: Week 5-6
**Description**: Long-term trend analysis with graphs

### **MVP2_TASK_006: iPhone Dashboard**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Companion app feature
**Timeline**: Week 4-8
**Description**: Comprehensive dashboard with all health metrics

### **MVP2_TASK_007: Medical Data Encryption**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: For cloud sync only
**Timeline**: Week 6-7
**Description**: Encrypt sensitive health data for cloud storage

### **MVP2_TASK_008: WatchConnectivity Re-enable**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: iPhone sync feature
**Timeline**: Week 4-5
**Description**: Uncomment WatchConnectivity code for iPhone sync

### **MVP2_TASK_009: Heart Rate Validation for Thresholds**
**Status**: 📦 DEFERRED TO MVP2 (LOW PRIORITY)
**Reason**: Medical validation better on iPhone UI
**Timeline**: Week 7-8
**Description**: Restrict medically impossible heart rate values
**Details:**
- Medical validation to emergency alert threshold inputs
- Prevent dangerous or impossible heart rate values
- Clear error messages with medical context
- Low threshold range: 25-90 BPM
- High threshold range: 90-250 BPM

### **MVP2_TASK_010: Heart Rate Export Frequency Fix**
**Status**: 📦 DEFERRED TO MVP2
**Reason**: Export is iPhone-only feature
**Timeline**: Week 5
**Description**: Fix export to 1 reading/minute instead of 11/minute
**Details:**
- Export logic samples data appropriately
- 1-minute intervals for exported data
- Reduce density from ~11/min to 1/min
- Expected: 1 hour = ~60 readings

---

## 📝 **NOTES FOR MVP2 PLANNING**

### **iPhone App Features to Build:**
1. Emergency contact management UI
2. Firebase authentication and Firestore integration
3. Contact verification flow (SMS/email)
4. Dashboard with heart rate trends
5. Weekly/monthly graph visualization
6. CSV/PDF export functionality
7. Settings sync with Watch app
8. Medical data encryption layer

### **Re-enable for MVP2:**
- All WatchConnectivity calls (currently commented out)
- Firebase SDK integration
- Cloud Functions for notifications
- Medical data encryption
- Contact verification manager

---

## ✅ **COMPLETED TASKS** (Previously Done, Now Part of Watch MVP1)
- Add medical validation to emergency alert threshold inputs
- Prevent users from entering dangerous or impossible heart rate values
- Provide clear error messages with medical context
- Implement scientifically-based heart rate limits

**Medical Research Findings:**
- **Normal Range**: 60-100 BPM (adults at rest)
- **Bradycardia**: < 50 BPM (updated medical consensus from < 60 BPM)
- **Severe Bradycardia**: < 40 BPM (medical emergency threshold)
- **Tachycardia**: > 100 BPM (traditional) or > 90 BPM (updated consensus)
- **Dangerous Tachycardia**: > 120 BPM sustained (medical attention required)
- **Life-threatening**: > 200 BPM sustained (cardiac arrest risk)
- **Physiological Limit**: ~300 BPM (theoretical maximum due to cardiac refractory period)

**Implementation:**
- **Low Threshold Range**: 25-90 BPM (allow for severe bradycardia to normal high)
- **High Threshold Range**: 90-250 BPM (allow for tachycardia to emergency levels)
- Add real-time validation with medical explanations
- Show warning messages for extreme values
- Prevent submission of impossible values (< 25 or > 250 BPM)

### **TASK_URGENT_1: Fix Missing Emergency Contacts + Button** (CRITICAL)
**Issue**: User reports + button to add Emergency Contacts is still not visible
**Status**: Code exists but + button not showing - MUST FIX IMMEDIATELY
**Requirements:**
- Debug why + button is not visible in Emergency Contacts section
- Fix navigation to ensure + button appears in Settings → Emergency Contacts
- Verify the button is actually clickable and functional
- Take screenshot before and after fix
- Test the complete add contact flow

### **TASK_URGENT_2: Fix Heart Rate Export Data Frequency** (CRITICAL)
**Issue**: Exported heart rate data shows excessive readings (646 in ~1 hour vs expected ~60)
**Problem**: Export is including too many readings - should be 1 reading per minute, not 11+ per minute
**Requirements:**
- Fix export logic to sample heart rate data appropriately
- Implement 1-minute intervals for exported data
- Reduce data density from ~11 readings/minute to 1 reading/minute
- Ensure exported CSV shows accurate, usable data
- Verify export file size and reading count are reasonable

**Expected Behavior:**
- 1 hour = ~60 readings (1 per minute)
- 1 day = ~1440 readings (1 per minute)
- Export should filter/sample data appropriately
- Maintain data accuracy while reducing frequency

---

## ✅ **PREVIOUSLY COMPLETED TASKS**

### **TASK_001: Fix Apple Watch Connection Status Display** (HIGH PRIORITY)
**Issue**: Settings shows "Not Connected" despite watch actively sharing BPM data
**Requirements:**
- Fix the connection status display in Settings → Apple Watch Device
- Should show "Connected" when watch is actively sending data
- Verify the status updates correctly when watch connects/disconnects
- Test with actual Apple Watch device

### **TASK_002: Comment Out All Test Data** (HIGH PRIORITY)
**Purpose**: Enable physical testing with real devices
**Requirements:**
- Comment out or remove all mock/test heart rate data
- Comment out any simulated data generators
- Ensure app only displays actual data from Apple Watch
- Clean up any hardcoded test values
- Verify app works with real device data only

### **TASK_003: Verify Weekly/Monthly Graphs** (MEDIUM PRIORITY)
**Previously identified as missing - needs verification:**
- Check if Weekly trend graph is implemented
- Check if Monthly trend graph is implemented
- Verify time period selectors (Day/Week/Month toggle)
- Test data aggregation for longer periods

## 🔧 **IMPLEMENTATION NOTES:**

### For Apple Watch Connection:
- Check HealthKitManager or similar for connection status logic
- Ensure status reflects actual HealthKit/Watch connectivity
- May need to update status polling or observation

### For Test Data Removal:
- Search for any mock data generators
- Look for hardcoded BPM values (like 57, 72, etc.)
- Check for test data in heart rate history
- Ensure clean slate for real testing

## 📸 **VERIFICATION REQUIRED:**
For each task, provide:
1. Screenshots before changes
2. Code changes made
3. Screenshots after changes
4. Confirmation of functionality with real devices (where applicable)

---

**📝 UPDATE `DEVELOPER_STATUS.json` AS YOU COMPLETE TASKS!**