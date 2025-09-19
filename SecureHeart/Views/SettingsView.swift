//
//  SettingsView.swift
//  Secure Heart
//
//  Settings and configuration view
//

import SwiftUI

struct SettingsTabView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("highHeartRateAlert") private var highHeartRateAlert = 150
    @AppStorage("lowHeartRateAlert") private var lowHeartRateAlert = 40
    @AppStorage("recordingInterval") private var recordingInterval = 60.0
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @EnvironmentObject var emergencyManager: EmergencyContactsManager
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device Connection") {
                    WatchStatusCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Emergency Contacts") {
                    NavigationLink("Manage Emergency Contacts") {
                        SimplifiedEmergencyContactsView()
                    }

                    HStack {
                        Text("Active Contacts")
                        Spacer()
                        Text("\(emergencyManager.contacts.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }
                
                Section("Recording Settings") {
                    Picker("Recording Interval", selection: $recordingInterval) {
                        Text("8 seconds").tag(8.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: recordingInterval) { _, newInterval in
                        // Send the new interval to the Apple Watch
                        WatchConnectivityManager.shared.sendRecordingInterval(newInterval)
                        print("📱 [iPhone] Sending recording interval to Watch: \(newInterval) seconds")
                    }
                }
                
                Section("Heart Rate Alerts") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Alert Thresholds")
                            .font(.headline)
                        Text("Set heart rate values that will trigger emergency notifications to your contacts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("High Threshold")
                                Text("Emergency alert for high heart rate")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            VStack {
                                Text("\(highHeartRateAlert) BPM")
                                    .font(.headline)
                                    .foregroundColor(.red)

                                Stepper("", value: $highHeartRateAlert, in: 90...250, step: 5)
                                    .labelsHidden()
                                    .onChange(of: highHeartRateAlert) { _, _ in
                                        validateHeartRateThresholds()
                                    }
                            }
                        }
                        Text("Range: 90-250 BPM (tachycardia to emergency)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Low Threshold")
                                Text("Emergency alert for low heart rate")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            VStack {
                                Text("\(lowHeartRateAlert) BPM")
                                    .font(.headline)
                                    .foregroundColor(.blue)

                                Stepper("", value: $lowHeartRateAlert, in: 25...90, step: 5)
                                    .labelsHidden()
                                    .onChange(of: lowHeartRateAlert) { _, _ in
                                        validateHeartRateThresholds()
                                    }
                            }
                        }
                        Text("Range: 25-90 BPM (severe bradycardia to normal)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About Heart") {
                    NavigationLink("About This App") {
                        AboutView()
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Learn More at KindCode.us", destination: URL(string: "https://kindcode.us")!)
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Send current recording interval to Watch when settings appear
                WatchConnectivityManager.shared.sendRecordingInterval(recordingInterval)
                print("📱 [iPhone] Sent initial recording interval to Watch: \(recordingInterval) seconds")
            }
        }
    }

    private func validateHeartRateThresholds() {
        // Steppers inherently prevent values outside ranges, but ensure logical consistency
        // Make sure low threshold is always lower than high threshold
        if lowHeartRateAlert >= highHeartRateAlert {
            // Adjust the high threshold to maintain separation
            highHeartRateAlert = lowHeartRateAlert + 10
            // Ensure high threshold doesn't exceed maximum
            if highHeartRateAlert > 250 {
                highHeartRateAlert = 250
                lowHeartRateAlert = 240
            }
        }

        print("📱 [Settings] Heart rate thresholds: Low: \(lowHeartRateAlert), High: \(highHeartRateAlert)")
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Heart")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Keep track of your heart rate safely and privately.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("What Heart Does:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        BulletPoint("Checks your heart rate all day long")
                        BulletPoint("Shows your heart rate right on your Apple Watch")
                        BulletPoint("Warns you when your heart rate goes up or down by 30 beats per minute")
                        BulletPoint("Alerts you if your heart rate gets too high or too low")
                        BulletPoint("Makes easy-to-read charts of your heart data")
                        // BulletPoint("Great for people with standing response patterns and other heart conditions") // Commented out for MVP2
                        BulletPoint("Great for people with heart rate monitoring needs and other heart conditions")
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Data Stays Safe:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        BulletPoint("Everything stays on your phone and watch only")
                        BulletPoint("We never put your heart data on the internet")
                        BulletPoint("No one else can see your information")
                        BulletPoint("No ads or tracking")
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Easy to Share When You Need To:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        BulletPoint("Send your heart rate charts to your doctor")
                        BulletPoint("Email or text your data anytime")
                        BulletPoint("Print copies for doctor visits")
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Part of Secure Health:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        BulletPoint("Works with all your other Secure Health apps")
                        BulletPoint("All your health tracking in one safe place")
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why Choose Heart:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Other apps sell your personal health information to make money. We don't. Your heart data belongs to you, not big companies.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your heart. Your data. Your choice.")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Link("Learn more at KindCode.us", destination: URL(string: "https://kindcode.us")!)
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }
}

struct WatchStatusCard: View {
    var body: some View {
        HStack {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("Apple Watch")
                    .font(.headline)
                Text("Not Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}