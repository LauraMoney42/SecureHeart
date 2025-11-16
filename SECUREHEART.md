# SecureHeart Project Configuration

**IMPORTANT: This file is automatically read by Claude Code when working in the SecureHeart directory**

## 🏥 PROJECT OVERVIEW

**SecureHeart MVP1** - A privacy-first Apple Watch heart rate monitoring app that keeps all data local to user devices with zero external transmission.

### Core Mission:
- **Privacy-first**: Apple Watch heart rate monitoring app
- **Local-only**: Keeps all data on user devices with zero external transmission
- **POTS-focused**: Designed specifically for people with POTS and heart rate conditions
- **Emergency alerts**: Firebase-based emergency contact system with confirmation dialogs

## 🎨 UI/UX DESIGN PRINCIPLES

### **Apple Best Practices - ALWAYS FOLLOW:**
- **Human Interface Guidelines** - Follow Apple's HIG religiously
- **Simple & Streamlined** - Every interface should be clean and intuitive
- **Privacy First** - User privacy is paramount in all design decisions
- **Accessibility** - Support VoiceOver, Dynamic Type, and assistive technologies
- **Native Patterns** - Use standard iOS/watchOS UI patterns and controls

### **Design Philosophy:**
- **Minimal & Purposeful** - No feature bloat, every element serves a purpose
- **User Control** - Users control their data, sharing, and privacy settings
- **Secure by Design** - Privacy and security built into every feature
- **Medical-Grade** - Reliable, accurate, appropriate for health monitoring

## 🏗️ ARCHITECTURE & PRIVACY

### **Data Storage:**
- **Local-only**: All heart rate data stays on iPhone/Apple Watch
- **No cloud sync**: Zero external data transmission for health data
- **Firebase exception**: Only for anonymous emergency contact linking
- **HealthKit integration**: Read-only access for heart rate sensors

### **Privacy Implementation:**
- **Anonymous authentication**: Firebase anonymous auth for emergency contacts
- **First name only**: Never store full names or identifying information
- **User consent**: Explicit permission for all data sharing
- **No analytics**: No third-party analytics or tracking

## 🚨 EMERGENCY CONTACT SYSTEM

### **Architecture:**
- **Firebase-only**: No Twilio/SendGrid - use Firebase + native iOS messaging
- **Simplified flow**: Anonymous auth → invitation codes → bidirectional linking
- **Native messaging**: iOS MessageUI for contact invitations
- **Confirmation dialogs**: 15-second countdown before sending emergency alerts

### **POTS-Specific Features:**
- **Configurable thresholds**: High/Low BPM customizable
- **Rapid increase detection**: +30 BPM in 10 minutes (POTS diagnostic criteria)
- **Extreme spike alerts**: +40 BPM in 5 minutes
- **Rate limiting**: Max 3 alerts per hour to prevent spam

## 📱 TECHNICAL REQUIREMENTS

### **Platform Support:**
- **Apple Watch Series 4+** and newer
- **iOS 15+** for iPhone companion
- **watchOS 8+** for Watch app
- **HealthKit read-only** access for heart rate sensors

### **Dependencies:**
- **Firebase SDK**: Auth, Firestore, Functions, Messaging
- **Native frameworks**: HealthKit, MessageUI, Contacts, ContactsUI
- **No third-party**: Avoid external dependencies beyond Firebase

## 🔧 DEVELOPMENT STANDARDS

### **Code Quality:**
- **SwiftUI-first**: Use SwiftUI for all new UI development
- **Clean architecture**: Separate ViewModels, Models, and Services
- **Error handling**: Graceful error handling with user-friendly messages
- **Performance**: Minimal battery impact, efficient data processing

### **File Organization:**
- **Feature-based**: Group files by feature, not file type
- **Clear naming**: Descriptive file and variable names
- **Documentation**: Comment complex logic, especially health-related calculations

## 🧪 TESTING & VALIDATION

### **Health Data Accuracy:**
- **Real device testing**: Always test on real Apple Watch for heart rate accuracy
- **Medical validation**: Ensure thresholds align with medical research
- **POTS research**: Base features on current POTS diagnostic criteria

### **Privacy Verification:**
- **No external transmission**: Verify no health data leaves the device
- **Anonymous testing**: Ensure Firebase system truly anonymous
- **Data audit**: Regular checks that only necessary data is stored

## 🚀 MVP1 SCOPE - STANDALONE APPLE WATCH APP

**🎯 STRATEGIC SHIFT (Nov 16, 2025):** Watch app first, iPhone companion becomes MVP2
**Target Ship Date:** November 23, 2025 (1 week)
**Rationale:** Faster time to market, validate core POTS monitoring value, simpler App Store review

### **✅ In Scope for MVP1 (Standalone Watch App):**
- ✅ Real-time heart rate monitoring with large, readable BPM display
- ✅ Color-coded heart rate zones (Blue: <80, Green: 80-120, Yellow: 120-150, Red: >150)
- ✅ 14 color theme variants (fully customizable)
- ✅ 6 watch face styles (Classic, Minimal, Chunky, Numbers Only, Watch Face, etc.)
- ✅ Pulse animation synchronized to heart rate
- ✅ POTS-aware orthostatic detection (+30 BPM standing response)
- ✅ Posture detection (Standing/Sitting/Walking via CoreMotion)
- ✅ Haptic feedback for heart rate events
- ✅ Always-on display support (watchOS integration)
- ✅ Persistent local storage (heart rate history saved to watch)
- ✅ Watch-side settings UI (emergency thresholds configurable on watch)
- ✅ Session-based heart rate history
- ✅ Local orthostatic event logging

### **📦 Deferred to MVP2 (iPhone Companion App - Week 4-8):**
- 📦 Emergency contact notifications (SMS/Email/Push)
- 📦 Firebase integration and cloud functions
- 📦 Contact verification system
- 📦 Data export (CSV/PDF reports)
- 📦 Weekly/monthly trend graphs (better on iPhone screen)
- 📦 Medical data encryption (for cloud sync)
- 📦 iPhone dashboard and settings sync
- 📦 WatchConnectivity data synchronization

### **❌ Out of Scope for MVP1:**
- Cloud synchronization (privacy-first local storage only)
- Share with healthcare providers (MVP3+)
- Custom heart rate zones (use medical defaults)
- System notification alerts (haptic alerts included)
- Workout integration (future feature)
- Complications (watchOS refresh limitations)

### **Success Criteria for MVP1:**
- [ ] Reliable heart rate display within 10 seconds on real Apple Watch
- [ ] All 14 color themes work smoothly
- [ ] All 6 watch face styles display correctly
- [ ] Data persists after app restart
- [ ] Orthostatic detection works without iPhone
- [ ] Settings save locally to watch
- [ ] Battery life exceeds 24 hours
- [ ] Zero external data transmission verified
- [ ] App passes App Store security review
- [ ] Stable performance during 24-hour continuous use
- [ ] Works completely offline (no iPhone required)

## 🔄 CURRENT IMPLEMENTATION STATUS (Updated Nov 16, 2025)

### **✅ Completed (MVP1 - Watch App):**
- ✅ Real-time heart rate monitoring (HealthKit integration)
- ✅ Color-coded heart rate zones with 14 theme variants
- ✅ 6 watch face style options
- ✅ POTS-aware orthostatic detection
- ✅ Posture detection via CoreMotion
- ✅ Haptic feedback system
- ✅ Always-on display support
- ✅ Session-based heart rate history

### **🔧 In Progress (MVP1 - Week of Nov 16-23):**
- 🔄 Persistent local storage (WatchDataStore class)
- 🔄 Watch-side settings UI for emergency thresholds
- 🔄 Commenting out WatchConnectivity for standalone mode
- 🔄 Real device testing and optimization
- 🔄 App Store submission preparation

### **📦 Deferred to MVP2 (iPhone Companion App - Week 4-8):**
- 📦 Firebase-based emergency contact system
- 📦 Native iOS messaging for contact invitations
- 📦 iOS Contacts integration for easy contact selection
- 📦 Location sharing preferences with user consent
- 📦 Emergency threshold settings (POTS-aware) - synced from iPhone
- 📦 Confirmation dialogs with 15-second countdown
- 📦 Anonymous Firebase authentication
- 📦 Bidirectional contact linking system
- 📦 Data export (CSV/PDF)
- 📦 Weekly/monthly trend graphs
- 📦 Medical data encryption

### **🎯 Active Development Focus:**
- Standalone watch app independence (remove iPhone dependencies)
- Local data persistence (UserDefaults + file storage)
- Watch-side configuration UI
- Battery optimization for 24+ hour use
- App Store privacy compliance

## 📝 DEVELOPMENT NOTES

### **When Working on SecureHeart:**
1. **Always prioritize privacy** - Question any data collection or transmission
2. **Test on real devices** - Simulators don't provide accurate heart rate data
3. **Follow Apple HIG** - Every UI element should feel native and intuitive
4. **POTS-aware design** - Consider the specific needs of POTS patients
5. **Medical accuracy** - Ensure all health-related features are medically sound

### **Code Review Checklist:**
- [ ] No health data transmitted externally
- [ ] UI follows Apple Human Interface Guidelines
- [ ] Accessibility support implemented
- [ ] Error handling graceful and user-friendly
- [ ] Performance impact minimal
- [ ] Privacy settings respected
- [ ] POTS-specific features medically accurate

---

*"Your heart. Your data. Your choice." - SecureHeart Privacy Promise*