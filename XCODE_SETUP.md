# Xcode Project Setup for Firebase Integration

This guide will help you add Firebase dependencies to your SecureHeart Xcode project.

## 🔧 Add Firebase SDK Dependencies

### Method 1: Swift Package Manager (Recommended)

1. **Open Xcode project**: `SecureHeart.xcodeproj`

2. **Add Package Dependencies**:
   - Go to `File` → `Add Package Dependencies...`
   - Enter URL: `https://github.com/firebase/firebase-ios-sdk`
   - Click `Add Package`

3. **Select Firebase Products** (choose all that apply):
   - ✅ `FirebaseAuth` - For user authentication
   - ✅ `FirebaseFirestore` - For database operations
   - ✅ `FirebaseMessaging` - For push notifications
   - ✅ `FirebaseFunctions` - For Cloud Functions integration
   - ✅ `FirebaseAnalytics` - For app analytics (optional)

4. **Add to Target**: Select both "Secure Heart" and "Secure Heart Watch App" targets

### Method 2: CocoaPods (Alternative)

If you prefer CocoaPods, create a `Podfile`:

```ruby
# Podfile
platform :ios, '15.0'

target 'Secure Heart' do
  use_frameworks!

  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Messaging'
  pod 'Firebase/Functions'
  pod 'Firebase/Analytics'

  target 'Secure Heart Watch App' do
    # Watch-specific pods if needed
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

Then run:
```bash
pod install
```

## 📱 Configure App Capabilities

### 1. Push Notifications
- Select your target in Xcode
- Go to "Signing & Capabilities"
- Click "+ Capability"
- Add "Push Notifications"

### 2. Background Modes
- Add "Background Modes" capability
- Enable:
  - ✅ Remote notifications
  - ✅ Background processing

### 3. App Groups (for Watch communication)
- Add "App Groups" capability
- Create group: `group.com.kindcode.secureheart`

## 🔐 Configure Firebase

### 1. Update GoogleService-Info.plist
The file is already in your project with your actual Firebase configuration:
- Project ID: `heart-577bc`
- API Key: `AIzaSyApYKAY5xns9NoHyA4BvCEz21CK_e5wcAE`

### 2. Add Firebase Configuration to Watch App
Copy `GoogleService-Info.plist` to both targets:
- Secure Heart (iPhone app)
- Secure Heart Watch App

## 🚀 Build Configuration

### 1. Minimum Deployment Target
Set minimum iOS deployment target to **iOS 15.0** for both targets:
- Select target → General → Deployment Info → iOS Deployment Target

### 2. Swift Language Version
Ensure Swift 5.0+ is selected:
- Build Settings → Swift Language Version → Swift 5

### 3. Other Linker Flags (if needed)
If you encounter linker errors, add:
- Build Settings → Other Linker Flags → Add `-ObjC`

## 🔄 Update Info.plist

Add required Firebase configurations to your `Info.plist`:

```xml
<key>FirebaseAutomaticScreenReportingEnabled</key>
<false/>
<key>FirebaseAnalyticsCollectionEnabled</key>
<false/>
<key>FirebaseMessagingAutoInitEnabled</key>
<true/>
```

## ⚠️ Known Issues & Solutions

### Build Errors:
1. **"No such module 'Firebase'"**
   - Solution: Ensure Firebase SDK is properly added via SPM or CocoaPods

2. **Linker errors**
   - Solution: Add `-ObjC` to Other Linker Flags

3. **Watch App compilation errors**
   - Solution: Some Firebase modules may not be compatible with watchOS
   - Only add essential modules to Watch target

### Runtime Issues:
1. **Firebase not initialized**
   - Solution: Ensure `FirebaseApp.configure()` is called in `SecureHeartApp.init()`

2. **Push notifications not working**
   - Solution: Verify APNs certificates in Firebase Console
   - Check capabilities are properly configured

## 🧪 Test Setup

After adding dependencies, test the setup:

1. **Build the project**: `⌘+B`
2. **Run on simulator**: `⌘+R`
3. **Check console logs** for Firebase initialization messages
4. **Test emergency contact creation** to verify Firestore connection

## 📊 Firebase Console Setup

1. **Enable Authentication**:
   - Go to Firebase Console → Authentication
   - Enable "Anonymous" sign-in method

2. **Configure Firestore**:
   - Go to Firestore Database
   - Start in production mode (rules are already configured)

3. **Set up Cloud Messaging**:
   - Go to Cloud Messaging
   - Upload APNs certificates or configure APNs key

## 🚀 Ready to Deploy

Once Xcode setup is complete:

1. Run the deployment script: `./deploy-firebase.sh`
2. Configure Twilio and SendGrid as per deployment instructions
3. Test the complete emergency notification flow

---

**Need Help?**
- Check Firebase Console for any configuration issues
- Review Xcode build logs for specific errors
- Ensure all capabilities and Info.plist entries are correct