# SecureHeart - Firebase & Emergency Contacts Integration

This branch contains the Firebase integration and Emergency Contacts functionality for the SecureHeart POTS monitoring application.

## Features Added

### 🔥 Firebase Integration
- **Real-time Data Sync**: Heart rate data and emergency events are synced to Firebase Firestore
- **Cross-device Access**: Emergency contacts and settings sync across devices
- **Cloud Backup**: All emergency contacts and health data are safely stored in the cloud
- **Offline Support**: App works offline and syncs when connection is restored

### 🚨 Emergency Contacts System
- **Contact Management**: Add, edit, and manage emergency contacts with names, phone numbers, emails, and relationships
- **Primary Contact**: Designate primary contacts who are notified first during emergencies
- **Automatic Emergency Detection**: App monitors heart rate thresholds and automatically alerts contacts when:
  - Heart rate exceeds 150 BPM (tachycardia)
  - Heart rate drops below 40 BPM (bradycardia)
  - Sustained abnormal readings for 2+ consecutive measurements

### 📱 Emergency Response Features
- **Multi-channel Alerts**: Emergency notifications via Firebase Cloud Messaging, SMS, and email
- **Medical Context**: Alerts include heart rate data, timestamp, and user context
- **Emergency Status Tracking**: Monitor active emergencies and mark them as resolved
- **Emergency History**: Complete log of all emergency events with medical details

## Technical Implementation

### Firebase Configuration
- `GoogleService-Info.plist` files configured for both iPhone and Watch apps
- Firestore database structure for emergency contacts, events, and notifications
- Firebase Authentication ready for multi-user support

### Data Models
- `EmergencyContact`: Contact information with priority levels
- `EmergencyEvent`: Medical emergency records with heart rate data
- Cloud sync with local storage fallback

### Emergency Detection Algorithm
- Consecutive reading validation to prevent false positives
- Configurable thresholds for different medical conditions
- Integration with HealthKit heart rate monitoring

## Setup Instructions

### Firebase Setup
1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add iOS app with bundle ID: `com.kindcode.secureheart`
3. Add watchOS app with bundle ID: `com.kindcode.secureheart.watchkitapp`
4. Download and replace the `GoogleService-Info.plist` files with your project's configuration
5. Enable Firestore Database and Cloud Messaging in Firebase Console

### Required Dependencies
Add to your Xcode project:
```
Firebase/Firestore
Firebase/Messaging
Firebase/Auth (optional for multi-user)
```

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/emergencyContacts/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/emergencyEvents/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Emergency Workflow

1. **Detection**: Watch app continuously monitors heart rate via HealthKit
2. **Threshold Check**: HealthManager checks readings against emergency thresholds
3. **Validation**: Requires 2 consecutive abnormal readings to trigger
4. **Alert**: EmergencyContactsManager sends notifications to designated contacts
5. **Logging**: All events logged to Firebase with medical context
6. **Resolution**: User can mark emergency as resolved when safe

## Medical Considerations

- **POTS-Specific Thresholds**: Configured for common POTS emergency scenarios
- **False Positive Prevention**: Multiple reading validation and smart filtering
- **Medical Context**: Alerts include standing/sitting context and heart rate trends
- **Privacy**: All medical data encrypted and HIPAA-compliant storage

## Usage

### Adding Emergency Contacts
1. Navigate to "Emergency" tab in the app
2. Tap "Add Contact" to add new emergency contact
3. Fill in contact details and set priority level
4. Contacts automatically sync to Firebase

### Testing Emergency System
- Emergency detection is active whenever the Watch app is monitoring heart rate
- Test alerts can be sent manually from the Emergency Contacts screen
- All emergency events are logged for review

## Security & Privacy

- End-to-end encryption for all medical data
- Firebase security rules restrict access to user's own data
- Local storage fallback ensures functionality without internet
- No medical data shared with third parties

## Future Enhancements

- Integration with medical providers
- Geolocation in emergency alerts
- Voice calling during emergencies
- Integration with emergency services (911)
- Medication reminders and tracking
- Advanced POTS monitoring algorithms

---

**Medical Disclaimer**: This app is for monitoring purposes only and should not replace professional medical care. Always consult healthcare providers for medical emergencies.
