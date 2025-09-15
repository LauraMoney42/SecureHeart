//
//  ContactVerificationManager.swift
//  SecureHeart
//
//  Phone number and email verification for emergency contacts
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class ContactVerificationManager: ObservableObject {
    @Published var verificationInProgress: [String: Bool] = [:] // ContactID -> Bool
    @Published var verificationResults: [String: String] = [:] // ContactID -> Status

    private let db = Firestore.firestore()

    // MARK: - Phone Number Verification

    func initiatePhoneVerification(for contact: EmergencyContact) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        DispatchQueue.main.async {
            self.verificationInProgress[contact.id] = true
        }

        // Create verification request
        let verificationCode = generateVerificationCode()
        let verificationData: [String: Any] = [
            "type": "phone_verification",
            "contactID": contact.id,
            "userID": userID,
            "contactPhone": contact.phoneNumber,
            "contactName": contact.name,
            "verificationCode": verificationCode,
            "createdAt": Timestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(300)), // 5 minutes
            "verified": false
        ]

        try await db.collection("verifications")
            .document(contact.id)
            .setData(verificationData)

        // Send SMS via Cloud Function trigger
        let smsData: [String: Any] = [
            "type": "verification_sms",
            "contactID": contact.id,
            "contactPhone": contact.phoneNumber,
            "contactName": contact.name,
            "verificationCode": verificationCode,
            "message": generateVerificationMessage(name: contact.name, code: verificationCode)
        ]

        try await db.collection("sms_requests")
            .document(UUID().uuidString)
            .setData(smsData)

        DispatchQueue.main.async {
            self.verificationResults[contact.id] = "SMS sent - waiting for response"
            self.verificationInProgress[contact.id] = false
        }

        print("📱 Phone verification SMS sent to \(contact.name)")
    }

    func verifyPhoneNumber(contactID: String, code: String) async throws -> Bool {
        let verificationDoc = try await db.collection("verifications")
            .document(contactID)
            .getDocument()

        guard let data = verificationDoc.data(),
              let storedCode = data["verificationCode"] as? String,
              let expiresAt = data["expiresAt"] as? Timestamp else {
            DispatchQueue.main.async {
                self.verificationResults[contactID] = "Verification not found or expired"
            }
            return false
        }

        // Check if expired
        if expiresAt.dateValue() < Date() {
            DispatchQueue.main.async {
                self.verificationResults[contactID] = "Verification code expired"
            }
            return false
        }

        // Check if codes match
        if storedCode == code {
            // Mark as verified
            try await db.collection("verifications")
                .document(contactID)
                .updateData([
                    "verified": true,
                    "verifiedAt": Timestamp()
                ])

            DispatchQueue.main.async {
                self.verificationResults[contactID] = "Phone number verified ✅"
            }

            return true
        } else {
            DispatchQueue.main.async {
                self.verificationResults[contactID] = "Invalid verification code"
            }
            return false
        }
    }

    // MARK: - Email Verification

    func initiateEmailVerification(for contact: EmergencyContact) async throws {
        guard let email = contact.email, !email.isEmpty else {
            throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No email address provided"])
        }

        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        DispatchQueue.main.async {
            self.verificationInProgress[contact.id] = true
        }

        // Create email verification request
        let verificationToken = generateVerificationToken()
        let verificationData: [String: Any] = [
            "type": "email_verification",
            "contactID": contact.id,
            "userID": userID,
            "contactEmail": email,
            "contactName": contact.name,
            "verificationToken": verificationToken,
            "createdAt": Timestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(3600)), // 1 hour
            "verified": false
        ]

        try await db.collection("verifications")
            .document("\(contact.id)_email")
            .setData(verificationData)

        // Send email via Cloud Function trigger
        let emailData: [String: Any] = [
            "type": "verification_email",
            "contactID": contact.id,
            "contactEmail": email,
            "contactName": contact.name,
            "verificationToken": verificationToken,
            "verificationUrl": "https://secureheart.app/verify/\(verificationToken)"
        ]

        try await db.collection("email_requests")
            .document(UUID().uuidString)
            .setData(emailData)

        DispatchQueue.main.async {
            self.verificationResults[contact.id] = "Verification email sent"
            self.verificationInProgress[contact.id] = false
        }

        print("📧 Email verification sent to \(contact.name)")
    }

    // MARK: - Verification Status Checking

    func checkVerificationStatus(for contactID: String) async throws -> ContactVerificationStatus {
        // Check phone verification
        let phoneVerificationDoc = try await db.collection("verifications")
            .document(contactID)
            .getDocument()

        // Check email verification
        let emailVerificationDoc = try await db.collection("verifications")
            .document("\(contactID)_email")
            .getDocument()

        var phoneVerified = false
        var emailVerified = false

        if let phoneData = phoneVerificationDoc.data(),
           let verified = phoneData["verified"] as? Bool {
            phoneVerified = verified
        }

        if let emailData = emailVerificationDoc.data(),
           let verified = emailData["verified"] as? Bool {
            emailVerified = verified
        }

        return ContactVerificationStatus(
            contactID: contactID,
            phoneVerified: phoneVerified,
            emailVerified: emailVerified,
            overallStatus: (phoneVerified || emailVerified) ? .verified : .pending
        )
    }

    // MARK: - Utility Functions

    private func generateVerificationCode() -> String {
        return String(format: "%06d", Int.random(in: 100000...999999))
    }

    private func generateVerificationToken() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private func generateVerificationMessage(name: String, code: String) -> String {
        return """
        Hi \(name)! 👋

        Your verification code for SecureHeart emergency contact is: \(code)

        This code will expire in 5 minutes. Please reply with this code to verify your phone number.

        SecureHeart helps monitor heart conditions and will only contact you in emergencies.

        If you didn't expect this message, please ignore it.
        """
    }

    // MARK: - Contact Preference Management

    func updateContactPreferences(contactID: String, preferences: ContactPreferences) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .document(contactID)
            .updateData([
                "preferences": [
                    "smsEnabled": preferences.smsEnabled,
                    "emailEnabled": preferences.emailEnabled,
                    "pushEnabled": preferences.pushEnabled,
                    "quietHours": [
                        "enabled": preferences.quietHours.enabled,
                        "startHour": preferences.quietHours.startHour,
                        "endHour": preferences.quietHours.endHour
                    ],
                    "emergencyOnly": preferences.emergencyOnly
                ]
            ])

        print("✅ Contact preferences updated for \(contactID)")
    }
}

// MARK: - Data Models

struct ContactVerificationStatus {
    let contactID: String
    let phoneVerified: Bool
    let emailVerified: Bool
    let overallStatus: VerificationStatus

    enum VerificationStatus {
        case pending
        case verified
        case failed
    }
}

struct ContactPreferences: Codable {
    var smsEnabled: Bool = true
    var emailEnabled: Bool = true
    var pushEnabled: Bool = true
    var quietHours: QuietHours = QuietHours()
    var emergencyOnly: Bool = false // Only receive critical alerts

    struct QuietHours: Codable {
        var enabled: Bool = false
        var startHour: Int = 22 // 10 PM
        var endHour: Int = 7   // 7 AM
    }
}