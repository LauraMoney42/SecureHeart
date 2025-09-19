# 🎯 UPDATED DEVELOPER TASKS

**Date**: September 18, 2025, 6:05 PM
**From**: PM (Claude)
**Status**: New Emergency Contacts Issue Found

## 🚨 **NEW URGENT TASK - EMERGENCY CONTACTS**

---

## 🚨 **CRITICAL EMERGENCY TASK**

### **TASK_EMERGENCY: RESOLVE BUILD FAILURES** (IMMEDIATE - BLOCKING ALL WORK)
**Issue**: App won't build after Emergency Contacts changes - "tons of errors"
**Priority**: CRITICAL - Nothing else can proceed until build is fixed
**Requirements:**
- Immediately fix all build errors
- Restore app to buildable state
- Identify what broke during Emergency Contacts + button fix
- Get clean build with no errors
- Preserve working functionality

**Debugging Steps:**
1. Run build and capture exact error messages
2. Check if packages/dependencies were accidentally removed
3. Verify SimplifiedEmergencyContactsView.swift syntax
4. Fix import statements if broken
5. Resolve compilation errors systematically
6. Ensure clean build before proceeding

**Success Criteria:**
- App builds successfully with no errors
- All existing functionality preserved
- Ready for Emergency Contacts + button fix (if that caused the issue)

---

## 🔧 **PRIORITY TASKS** (AFTER BUILD IS FIXED)

### **TASK_NEW: Improve Heart Rate Validation for Emergency Alert Thresholds** (HIGH PRIORITY)
**Issue**: Need to restrict medically impossible heart rate values in emergency alert settings
**Requirements:**
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