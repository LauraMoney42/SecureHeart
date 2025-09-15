# Firebase Setup for SecureHeart

## Required Firebase SDK Installation

The app needs Firebase SDK dependencies to build and run. Follow these steps:

### 1. Add Firebase SDK via Swift Package Manager

1. Open `SecureHeart.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter Firebase URL: `https://github.com/firebase/firebase-ios-sdk`
4. Click **Add Package**
5. Select these Firebase libraries:
   - **FirebaseAuth** (for anonymous authentication)
   - **FirebaseFirestore** (for database)
   - **FirebaseMessaging** (for push notifications)
   - **FirebaseFunctions** (for Cloud Functions)
6. Click **Add Package**

### 2. Verify GoogleService-Info.plist Files

✅ **Already Present:**
- `SecureHeart/GoogleService-Info.plist`
- `SecureHeart Watch App/GoogleService-Info.plist`

### 3. Cloud Functions Status

✅ **Ready to Deploy:**
- Cloud Functions built successfully
- TypeScript compilation completed
- Functions available: `processEmergencyNotification`, `linkContacts`, cleanup functions

### 4. Next Steps After SDK Installation

1. **Build the app** - Should compile successfully after adding Firebase SDK
2. **Deploy Cloud Functions** - Run `firebase deploy --only functions` in the `firebase-functions` directory
3. **Test end-to-end flow:**
   - Anonymous authentication
   - Contact linking with invitation codes
   - Emergency notifications via Firebase push

## Architecture Summary

- **Authentication**: Firebase Anonymous Auth (privacy-focused)
- **Database**: Cloud Firestore for user profiles and contacts
- **Notifications**: Firebase Cloud Messaging only (no Twilio/SendGrid)
- **Contact Invitations**: Native iOS messaging (SMS/Email)
- **Contact Selection**: iOS Contacts integration
- **Location Sharing**: User consent-based, included in notifications

## Key Features Implemented

✅ Firebase-only emergency notification system
✅ Native iOS messaging for contact invitations
✅ iOS Contacts integration for easy contact selection
✅ Location sharing preferences in UI
✅ First name only usage throughout
✅ Anonymous authentication for privacy
✅ Bidirectional contact linking system