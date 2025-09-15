//
//  NativeMessagingManager.swift
//  SecureHeart
//
//  Native iOS messaging for contact invitations and emergency alerts
//

import Foundation
import SwiftUI
import MessageUI
import Contacts
import ContactsUI

class NativeMessagingManager: NSObject, ObservableObject {
    @Published var showingSMSComposer = false
    @Published var showingEmailComposer = false
    @Published var showingContactPicker = false
    @Published var messagingError: String?

    // MARK: - Contact Invitation

    func sendSMSInvitation(to phoneNumber: String, invitationCode: String, userFirstName: String) {
        guard MFMessageComposeViewController.canSendText() else {
            messagingError = "SMS not available on this device"
            return
        }

        let message = generateInvitationSMSMessage(invitationCode: invitationCode, userFirstName: userFirstName)

        DispatchQueue.main.async {
            self.showingSMSComposer = true
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowSMSComposer"),
                object: nil,
                userInfo: [
                    "recipients": [phoneNumber],
                    "message": message
                ]
            )
        }
    }

    func sendEmailInvitation(to email: String, invitationCode: String, userFirstName: String) {
        guard MFMailComposeViewController.canSendMail() else {
            messagingError = "Email not available on this device"
            return
        }

        let subject = "You're invited to connect on SecureHeart"
        let message = generateInvitationEmailMessage(invitationCode: invitationCode, userFirstName: userFirstName)

        DispatchQueue.main.async {
            self.showingEmailComposer = true
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowEmailComposer"),
                object: nil,
                userInfo: [
                    "recipients": [email],
                    "subject": subject,
                    "message": message
                ]
            )
        }
    }

    // MARK: - Emergency Fallback Messages

    func sendEmergencyFallbackSMS(to phoneNumber: String, userFirstName: String, heartRate: Int, location: String?) {
        guard MFMessageComposeViewController.canSendText() else {
            messagingError = "SMS not available on this device"
            return
        }

        let message = generateEmergencyFallbackMessage(userFirstName: userFirstName, heartRate: heartRate, location: location)

        DispatchQueue.main.async {
            self.showingSMSComposer = true
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowSMSComposer"),
                object: nil,
                userInfo: [
                    "recipients": [phoneNumber],
                    "message": message
                ]
            )
        }
    }

    // MARK: - Message Generation

    private func generateInvitationSMSMessage(invitationCode: String, userFirstName: String) -> String {
        return """
        Hi! 👋

        \(userFirstName) has added you as an emergency contact on SecureHeart, a heart rate monitoring app for people with POTS.

        To receive emergency alerts, please:
        1. Download SecureHeart: https://apps.apple.com/app/secureheart-pots-monitor
        2. Open the app and enter this code: \(invitationCode)

        You'll only receive alerts if \(userFirstName) experiences concerning heart rate patterns.

        SecureHeart - Helping people with POTS stay safe 💚
        """
    }

    private func generateInvitationEmailMessage(invitationCode: String, userFirstName: String) -> String {
        return """
        Hi there! 👋

        \(userFirstName) has added you as an emergency contact on SecureHeart, a heart rate monitoring app designed for people with POTS (Postural Orthostatic Tachycardia Syndrome).

        What this means:
        • You'll receive emergency alerts if \(userFirstName) experiences concerning heart rate patterns
        • Only critical situations will trigger notifications
        • Your privacy is completely protected - no health data is shared

        To get started:
        1. Download SecureHeart from the App Store: https://apps.apple.com/app/secureheart-pots-monitor
        2. Open the app and enter this invitation code: \(invitationCode)
        3. You'll be connected to receive emergency alerts

        About POTS:
        POTS is a condition that affects blood circulation and can cause dangerous heart rate changes. SecureHeart helps monitor these changes and alert trusted contacts when help might be needed.

        Thank you for being part of \(userFirstName)'s support network! 💚

        ---
        SecureHeart - Heart Rate Monitoring for POTS
        Privacy-focused • Emergency-only alerts • Secure connection
        """
    }

    private func generateEmergencyFallbackMessage(userFirstName: String, heartRate: Int, location: String?) -> String {
        let locationText = location != nil ? "\nLocation: \(location!)" : ""

        return """
        🚨 EMERGENCY ALERT - SecureHeart 🚨

        \(userFirstName) is experiencing a heart rate emergency:

        Heart Rate: \(heartRate) BPM
        Time: \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))\(locationText)

        Please check on them immediately or call emergency services if needed.

        This alert was sent because they don't have the SecureHeart app installed. To receive automatic emergency notifications, download SecureHeart from the App Store.
        """
    }

    // MARK: - iOS Contacts Integration

    func presentContactPicker() {
        showingContactPicker = true
    }

    func extractContactInfo(from contact: CNContact) -> ContactInfo? {
        guard !contact.givenName.isEmpty else { return nil }

        let firstName = contact.givenName
        let lastName = contact.familyName
        let fullName = lastName.isEmpty ? firstName : "\(firstName) \(lastName)"

        // Get primary phone number
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue

        // Get primary email
        let email = contact.emailAddresses.first?.value as String?

        // Determine relationship (if available)
        let relationship = determineRelationship(from: contact)

        return ContactInfo(
            fullName: fullName,
            firstName: firstName,
            phoneNumber: phoneNumber,
            email: email,
            relationship: relationship
        )
    }

    private func determineRelationship(from contact: CNContact) -> String {
        // Check if contact has a relationship label
        if let relation = contact.contactRelations.first {
            let relationshipType = CNLabeledValue<CNContactRelation>.localizedString(forLabel: relation.label ?? "")
            return relationshipType.capitalized
        }

        // Default relationship types based on common patterns
        let name = contact.givenName.lowercased()
        if name.contains("mom") || name.contains("mother") {
            return "Parent"
        } else if name.contains("dad") || name.contains("father") {
            return "Parent"
        } else if name.contains("husband") || name.contains("wife") {
            return "Spouse"
        } else if name.contains("sister") || name.contains("brother") {
            return "Sibling"
        } else if name.contains("doctor") || name.contains("dr") {
            return "Doctor"
        }

        return "Friend" // Default
    }
}

// MARK: - Data Models

struct ContactInfo {
    let fullName: String
    let firstName: String
    let phoneNumber: String?
    let email: String?
    let relationship: String
}

// MARK: - SwiftUI Integration Views

struct SMSComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let message: String
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        composer.recipients = recipients
        composer.body = message
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: SMSComposerView

        init(_ parent: SMSComposerView) {
            self.parent = parent
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            parent.isPresented = false

            switch result {
            case .sent:
                print("✅ SMS invitation sent successfully")
            case .cancelled:
                print("❌ SMS invitation cancelled")
            case .failed:
                print("❌ SMS invitation failed")
            @unknown default:
                break
            }
        }
    }
}

struct EmailComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let message: String
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(message, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailComposerView

        init(_ parent: EmailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false

            switch result {
            case .sent:
                print("✅ Email invitation sent successfully")
            case .cancelled:
                print("❌ Email invitation cancelled")
            case .failed:
                print("❌ Email invitation failed: \(error?.localizedDescription ?? "Unknown error")")
            case .saved:
                print("📄 Email invitation saved as draft")
            @unknown default:
                break
            }
        }
    }
}

struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onContactSelected: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView

        init(_ parent: ContactPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected(contact)
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}