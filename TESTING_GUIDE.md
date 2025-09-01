# Secure Heart WatchConnectivity Testing Guide

## ✅ Setup Complete
- **Simulators Paired**: iPhone 16 Pro ↔ Apple Watch Series 10
- **Debugging Added**: Both apps now log connectivity status
- **Apps Built**: Ready for testing

## 🧪 How to Test WatchConnectivity

### Method 1: Xcode Simulators (RECOMMENDED)
1. **Open Xcode**
   ```
   open SecureHeart.xcodeproj
   ```

2. **Run the combined app:**
   - Select **"Secure Heart"** scheme (not "Secure Heart Watch App")
   - Choose **iPhone 16 Pro** as destination
   - Click **Run** ▶️
   - This will launch BOTH iPhone and Watch apps simultaneously

3. **Watch the console for logs:**
   - In Xcode, go to **Window > Developer Tools > Console**
   - Look for messages starting with:
     - `✅ [iPhone] WCSession activated`
     - `✅ [WATCH] WCSession activated`
     - `💓 [WATCH] Sending heart rate:`
     - `📩 [iPhone] Received message`

### Method 2: Manual Testing (If needed)
1. **Start iPhone app first:**
   - Select "Secure Heart" scheme
   - Choose iPhone 16 Pro simulator
   - Run

2. **Then start Watch app:**
   - Select "Secure Heart Watch App" scheme  
   - Choose Apple Watch Series 10 simulator
   - Run

### 🔍 What to Look For

#### On the Watch App:
- Heart rate readings should appear
- Console logs: `💓 [WATCH] Sending heart rate: XX BPM`
- Console logs: `🔗 [WATCH] Session reachable: true`

#### On the iPhone App:
- **"LIVE" indicator** should appear next to heart rate
- **Watch status** should show "Connected"
- Console logs: `📩 [iPhone] Received message from Watch`
- Console logs: `✅ [iPhone] Updated UI with heart rate: XX`

## 🚨 Troubleshooting

### If No Connection:
1. **Check pairing:**
   ```bash
   xcrun simctl list pairs
   ```
   Should show: `iPhone 16 Pro paired with Apple Watch Series 10`

2. **Re-pair if needed:**
   ```bash
   xcrun simctl pair [iPhone-ID] [Watch-ID]
   ```

3. **Check console logs** for error messages

### If Still Not Working:
- **Physical devices** are more reliable for WatchConnectivity
- Simulators sometimes have timing issues
- Try restarting both simulators

## 📱 Physical Device Testing

For the most reliable testing:
1. Install on actual iPhone + Apple Watch
2. Ensure both devices are paired via Apple Watch app
3. Install both apps via Xcode
4. WatchConnectivity works better on real hardware

## 🎯 Expected Behavior

When working correctly:
1. **Watch** continuously monitors heart rate
2. **Watch** sends updates to iPhone every second
3. **iPhone** shows "LIVE" indicator
4. **iPhone** displays real-time heart rate from Watch
5. Both apps show connection status as "Connected"

---

**Apps are ready for testing!** The debugging will show exactly what's happening with the connection.