//
//  SimplifiedEmergencyContactsView.swift
//  SecureHeart
//
//  Simplified UI with iOS Contacts integration and native messaging
//

import SwiftUI
import MessageUI
import Contacts
import ContactsUI

struct SimplifiedEmergencyContactsView: View {
    @StateObject private var emergencyManager = SimplifiedEmergencyContactsManager()
    @StateObject private var messagingManager = NativeMessagingManager()

    @State private var showingAddOptions = false
    @State private var showingSetupProfile = false
    @State private var showingInvitationCode = false
    @State private var showingAcceptInvitation = false
    @State private var showingLocationSettings = false

    // SMS/Email composer states
    @State private var showingSMSComposer = false
    @State private var showingEmailComposer = false
    @State private var currentSMSData: (recipients: [String], message: String)?
    @State private var currentEmailData: (recipients: [String], subject: String, message: String)?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status
                    SimplifiedConnectionStatusHeader(connectionStatus: emergencyManager.connectionStatus, isLoading: emergencyManager.isLoading)

                    // User Profile Section
                    if let profile = emergencyManager.userProfile {
                        UserProfileCard(
                            profile: profile,
                            onEditProfile: { showingSetupProfile = true },
                            onLocationSettings: { showingLocationSettings = true }
                        )
                    } else {
                        SetupProfilePrompt { showingSetupProfile = true }
                    }

                    // Linked Contacts Section with title above icon
                    VStack(spacing: 16) {
                        // Emergency Contacts title above the people+ graphic
                        Text("Emergency Contacts")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if emergencyManager.linkedContacts.isEmpty {
                            EmptyLinkedContactsView()
                        } else {
                            LinkedContactsList(
                                contacts: emergencyManager.linkedContacts,
                                onLocationPermissionChanged: { contactID, shareLocationWithMe, shareMyLocationWithThem in
                                    Task {
                                        try await emergencyManager.updateContactLocationPermission(
                                            contactUserID: contactID,
                                            shareLocationWithMe: shareLocationWithMe,
                                            shareMyLocationWithThem: shareMyLocationWithThem
                                        )
                                    }
                                }
                            )
                        }
                    }

                    // Emergency Status
                    SimplifiedEmergencyStatusCard(
                        emergencyTriggered: emergencyManager.emergencyTriggered,
                        lastEmergencyAlert: emergencyManager.lastEmergencyAlert,
                        onResolve: {
                            Task {
                                try await emergencyManager.resolveEmergency()
                            }
                        }
                    )

                    // Emergency Settings
                    EmergencyThresholdSettingsCard()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingInvitationCode = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }

        // Sheets
        .sheet(isPresented: $showingSetupProfile) {
            SetupProfileView(emergencyManager: emergencyManager)
        }
        .sheet(isPresented: $showingInvitationCode) {
            CreateInvitationView(
                emergencyManager: emergencyManager,
                messagingManager: messagingManager
            )
        }
        .sheet(isPresented: $showingAcceptInvitation) {
            AcceptInvitationView(emergencyManager: emergencyManager)
        }
        .sheet(isPresented: $showingLocationSettings) {
            LocationSettingsView(emergencyManager: emergencyManager)
        }

        // Contact Picker
        .sheet(isPresented: $messagingManager.showingContactPicker) {
            ContactPickerView(isPresented: $messagingManager.showingContactPicker) { contact in
                handleContactSelection(contact)
            }
        }

        // SMS Composer
        .sheet(isPresented: $showingSMSComposer) {
            if let smsData = currentSMSData {
                SMSComposerView(
                    recipients: smsData.recipients,
                    message: smsData.message,
                    isPresented: $showingSMSComposer
                )
            }
        }

        // Email Composer
        .sheet(isPresented: $showingEmailComposer) {
            if let emailData = currentEmailData {
                EmailComposerView(
                    recipients: emailData.recipients,
                    subject: emailData.subject,
                    message: emailData.message,
                    isPresented: $showingEmailComposer
                )
            }
        }

        // Notification observers for native messaging
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSMSComposer"))) { notification in
            if let userInfo = notification.userInfo,
               let recipients = userInfo["recipients"] as? [String],
               let message = userInfo["message"] as? String {
                currentSMSData = (recipients: recipients, message: message)
                showingSMSComposer = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowEmailComposer"))) { notification in
            if let userInfo = notification.userInfo,
               let recipients = userInfo["recipients"] as? [String],
               let subject = userInfo["subject"] as? String,
               let message = userInfo["message"] as? String {
                currentEmailData = (recipients: recipients, subject: subject, message: message)
                showingEmailComposer = true
            }
        }
        .alert("Emergency Alert", isPresented: $emergencyManager.showingEmergencyConfirmation) {
            Button("Cancel", role: .cancel) {
                emergencyManager.cancelEmergencyAlert()
            }
            Button("Send Alert") {
                emergencyManager.confirmEmergencyAlert()
            }
        } message: {
            Text("Sending emergency alert to \(emergencyManager.linkedContacts.count) contact\(emergencyManager.linkedContacts.count == 1 ? "" : "s") in \(emergencyManager.emergencyConfirmationTimeRemaining) seconds.\n\nHeart Rate: \(emergencyManager.pendingEmergencyHeartRate) BPM")
        }
    }

    private func handleContactSelection(_ contact: CNContact) {
        guard let contactInfo = messagingManager.extractContactInfo(from: contact),
              let profile = emergencyManager.userProfile else { return }

        // Show option to send SMS or Email invitation
        showContactInvitationOptions(for: contactInfo, userFirstName: profile.firstName)
    }

    private func showContactInvitationOptions(for contactInfo: ContactInfo, userFirstName: String) {
        Task {
            do {
                let invitationCode = try await emergencyManager.createInvitationLink(userFirstName: userFirstName)

                DispatchQueue.main.async {
                    // Show action sheet for SMS or Email
                    let hasPhone = contactInfo.phoneNumber != nil
                    let hasEmail = contactInfo.email != nil

                    if hasPhone {
                        self.messagingManager.sendSMSInvitation(
                            to: contactInfo.phoneNumber!,
                            invitationCode: invitationCode,
                            userFirstName: userFirstName
                        )
                    } else if hasEmail {
                        self.messagingManager.sendEmailInvitation(
                            to: contactInfo.email!,
                            invitationCode: invitationCode,
                            userFirstName: userFirstName
                        )
                    }
                }
            } catch {
                print("❌ Error creating invitation: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct SimplifiedConnectionStatusHeader: View {
    let connectionStatus: String
    let isLoading: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(connectionStatus)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private var statusColor: Color {
        switch connectionStatus {
        case "Connected": return .green
        case "Connecting...": return .orange
        default: return .red
        }
    }
}

struct UserProfileCard: View {
    let profile: UserProfile
    let onEditProfile: () -> Void
    let onLocationSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(profile.linkedContacts.count) linked contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button("Edit Name", systemImage: "pencil") {
                        onEditProfile()
                    }
                    Button("Location Settings", systemImage: "location") {
                        onLocationSettings()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }

            if profile.shareLocationByDefault {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Location sharing enabled")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SetupProfilePrompt: View {
    let onSetup: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Set up your profile")
                .font(.headline)

            Text("Enter your first name so emergency contacts know who's reaching out")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Set Up Profile") {
                onSetup()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyLinkedContactsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No Emergency Contacts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the + button above to create an invitation link. Share it with family and friends who should receive emergency alerts.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct LinkedContactsList: View {
    let contacts: [LinkedContact]
    let onLocationPermissionChanged: (String, Bool, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Linked Contacts")
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 12) {
                ForEach(contacts) { contact in
                    LinkedContactRow(
                        contact: contact,
                        onLocationPermissionChanged: onLocationPermissionChanged
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct LinkedContactRow: View {
    let contact: LinkedContact
    let onLocationPermissionChanged: (String, Bool, Bool) -> Void
    @State private var showingLocationSettings = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.contactFirstName)
                    .font(.headline)

                Text("Linked \(contact.linkedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if contact.shareLocationWithMe || contact.shareMyLocationWithThem {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Location sharing enabled")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Menu {
                Button("Location Settings", systemImage: "location") {
                    showingLocationSettings = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingLocationSettings) {
            ContactLocationSettingsView(
                contact: contact,
                onPermissionChanged: onLocationPermissionChanged
            )
        }
    }
}

struct SimplifiedEmergencyStatusCard: View {
    let emergencyTriggered: Bool
    let lastEmergencyAlert: Date?
    let onResolve: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: emergencyTriggered ? "exclamationmark.triangle.fill" : "shield.checkered")
                    .foregroundColor(emergencyTriggered ? .red : .green)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text(emergencyTriggered ? "Emergency Active" : "Monitoring Active")
                        .font(.headline)
                        .foregroundColor(emergencyTriggered ? .red : .primary)

                    if let lastAlert = lastEmergencyAlert {
                        Text("Last alert: \(lastAlert, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No recent alerts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if emergencyTriggered {
                Button("Resolve Emergency") {
                    onResolve()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Modal Views

struct SetupProfileView: View {
    @ObservedObject var emergencyManager: SimplifiedEmergencyContactsManager
    @Environment(\.dismiss) var dismiss
    @State private var firstName = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                } header: {
                    Text("Your Name")
                } footer: {
                    Text("Emergency contacts will see this name when they receive alerts")
                }
            }
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            try await emergencyManager.updateUserProfile(firstName: firstName)
                            dismiss()
                        }
                    }
                    .disabled(firstName.isEmpty)
                }
            }
        }
        .onAppear {
            firstName = emergencyManager.userProfile?.firstName ?? ""
        }
    }
}

struct CreateInvitationView: View {
    @ObservedObject var emergencyManager: SimplifiedEmergencyContactsManager
    @ObservedObject var messagingManager: NativeMessagingManager
    @Environment(\.dismiss) var dismiss
    @State private var invitationCode = ""
    @State private var isLoading = false
    @State private var showingShareSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Invitation Code")
                    .font(.title2)
                    .fontWeight(.semibold)

                if !invitationCode.isEmpty {
                    Text(invitationCode)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .tracking(4)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                Text("Share this code with someone you trust. They can enter it in their SecureHeart app to receive your emergency alerts.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                if !invitationCode.isEmpty {
                    Button("Share Invitation") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Create Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await createInvitation()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareText = createShareText() {
                    ShareSheet(items: [shareText])
                }
            }
        }
    }

    private func createInvitation() async {
        guard let profile = emergencyManager.userProfile else { return }

        isLoading = true
        do {
            let code = try await emergencyManager.createInvitationLink(userFirstName: profile.firstName)
            invitationCode = code
        } catch {
            print("❌ Error creating invitation: \(error)")
        }
        isLoading = false
    }

    private func createShareText() -> String? {
        guard let profile = emergencyManager.userProfile, !invitationCode.isEmpty else { return nil }

        return """
        Hi! 👋

        \(profile.firstName) has added you as an emergency contact on SecureHeart, a heart rate monitoring app for people with POTS.

        To receive emergency alerts, please:
        1. Download SecureHeart: https://apps.apple.com/app/secureheart-pots-monitor
        2. Open the app and enter this code: \(invitationCode)

        You'll only receive alerts if \(profile.firstName) experiences concerning heart rate patterns.

        SecureHeart - Helping people with POTS stay safe 💚
        """
    }
}

struct AcceptInvitationView: View {
    @ObservedObject var emergencyManager: SimplifiedEmergencyContactsManager
    @Environment(\.dismiss) var dismiss
    @State private var invitationCode = ""
    @State private var firstName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                } header: {
                    Text("Your Name")
                }

                Section {
                    TextField("Invitation Code", text: $invitationCode)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.allCharacters)
                } header: {
                    Text("Invitation Code")
                } footer: {
                    Text("Enter the 6-character code shared by your emergency contact")
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Accept Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accept") {
                        Task {
                            await acceptInvitation()
                        }
                    }
                    .disabled(invitationCode.isEmpty || firstName.isEmpty || isLoading)
                }
            }
        }
    }

    private func acceptInvitation() async {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        do {
            let linkedWith = try await emergencyManager.acceptInvitation(code: invitationCode, contactFirstName: firstName)
            successMessage = "Successfully linked with \(linkedWith)!"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct LocationSettingsView: View {
    @ObservedObject var emergencyManager: SimplifiedEmergencyContactsManager
    @Environment(\.dismiss) var dismiss
    @State private var shareLocationByDefault = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Share my location in emergency alerts", isOn: $shareLocationByDefault)
                } footer: {
                    Text("When enabled, your location will be included in emergency notifications to help contacts find you quickly. Location is only shared during actual emergencies.")
                }
            }
            .navigationTitle("Location Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            try await emergencyManager.updateLocationSharingPreference(shareByDefault: shareLocationByDefault)
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            shareLocationByDefault = emergencyManager.userProfile?.shareLocationByDefault ?? false
        }
    }
}

struct ContactLocationSettingsView: View {
    let contact: LinkedContact
    let onPermissionChanged: (String, Bool, Bool) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var shareLocationWithMe = false
    @State private var shareMyLocationWithThem = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Share my location with \(contact.contactFirstName)", isOn: $shareMyLocationWithThem)
                } footer: {
                    Text("\(contact.contactFirstName) will see your location when you send emergency alerts")
                }

                Section {
                    Toggle("Receive \(contact.contactFirstName)'s location", isOn: $shareLocationWithMe)
                } footer: {
                    Text("You'll see \(contact.contactFirstName)'s location when they send emergency alerts")
                }
            }
            .navigationTitle("Location Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onPermissionChanged(contact.contactUserID, shareLocationWithMe, shareMyLocationWithThem)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            shareLocationWithMe = contact.shareLocationWithMe
            shareMyLocationWithThem = contact.shareMyLocationWithThem
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Emergency Threshold Settings

struct EmergencyThresholdSettingsCard: View {
    @AppStorage("emergencyHighBPM") private var highBPM: Double = 150
    @AppStorage("emergencyLowBPM") private var lowBPM: Double = 40
    @AppStorage("highAlertEnabled") private var highAlertEnabled = true
    @AppStorage("lowAlertEnabled") private var lowAlertEnabled = true
    @AppStorage("rapidIncreaseEnabled") private var rapidIncreaseEnabled = true
    @AppStorage("rapidIncreaseBPM") private var rapidIncreaseBPM: Double = 30
    @AppStorage("extremeSpikeEnabled") private var extremeSpikeEnabled = true
    @AppStorage("extremeSpikeBPM") private var extremeSpikeBPM: Double = 40
    @AppStorage("maxAlertsPerHour") private var maxAlertsPerHour: Double = 3


    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.red)
                Text("Emergency Alert Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 12) {
                // Static Thresholds
                VStack(alignment: .leading, spacing: 12) {
                    Text("Heart Rate Thresholds")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    // High Alert Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("High Emergency Alert", isOn: $highAlertEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("High Threshold:")
                                    .foregroundColor(highAlertEnabled ? .primary : .secondary)
                                Text("Emergency alert trigger")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            VStack {
                                Text("\(Int(highBPM)) BPM")
                                    .font(.headline)
                                    .foregroundColor(highAlertEnabled ? .red : .secondary)

                                Stepper("", value: $highBPM, in: 90...250, step: 10)
                                    .labelsHidden()
                                    .disabled(!highAlertEnabled)
                                    .opacity(highAlertEnabled ? 1.0 : 0.6)
                            }
                        }
                    }

                    // Low Alert Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Low Emergency Alert", isOn: $lowAlertEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Low Threshold:")
                                    .foregroundColor(lowAlertEnabled ? .primary : .secondary)
                                Text("Emergency alert trigger")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            VStack {
                                Text("\(Int(lowBPM)) BPM")
                                    .font(.headline)
                                    .foregroundColor(lowAlertEnabled ? .blue : .secondary)

                                Stepper("", value: $lowBPM, in: 25...90, step: 10)
                                    .labelsHidden()
                                    .disabled(!lowAlertEnabled)
                                    .opacity(lowAlertEnabled ? 1.0 : 0.6)
                            }
                        }
                    }
                }

                Divider()

                // Advanced Detection Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Advanced Detection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Toggle(isOn: $rapidIncreaseEnabled) {
                        VStack(alignment: .leading) {
                            Text("Rapid Increase Alert")
                            Text("+\(Int(rapidIncreaseBPM)) BPM in 10 minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if rapidIncreaseEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Increase Threshold:")
                                    .foregroundColor(.primary)
                                Text("BPM increase in 10 minutes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            VStack {
                                Text("+\(Int(rapidIncreaseBPM)) BPM")
                                    .font(.headline)
                                    .foregroundColor(.orange)

                                Stepper("", value: $rapidIncreaseBPM, in: 20...100, step: 10)
                                    .labelsHidden()
                            }
                        }
                    }

                    Toggle(isOn: $extremeSpikeEnabled) {
                        VStack(alignment: .leading) {
                            Text("Extreme Spike Alert")
                            Text("+\(Int(extremeSpikeBPM)) BPM in 5 minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if extremeSpikeEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Spike Threshold:")
                                    .foregroundColor(.primary)
                                Text("BPM spike in 5 minutes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            VStack {
                                Text("+\(Int(extremeSpikeBPM)) BPM")
                                    .font(.headline)
                                    .foregroundColor(.red)

                                Stepper("", value: $extremeSpikeBPM, in: 30...100, step: 10)
                                    .labelsHidden()
                            }
                        }
                    }
                }

                Divider()

                // Alert Frequency
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alert Frequency")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Max alerts per hour:")
                        Spacer()
                        Text("\(Int(maxAlertsPerHour))")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                            .frame(width: 30)
                        Stepper("", value: $maxAlertsPerHour, in: 1...20, step: 1)
                            .labelsHidden()
                        Text("alerts")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(12)
        .onAppear {
            // Initialize text fields with current values (for remaining text fields)
        }
    }

    // Helper function to validate BPM input
    private func isValidBPM(_ value: String) -> Bool {
        guard let bpm = Double(value) else { return false }
        return bpm >= 30 && bpm <= 220
    }
}