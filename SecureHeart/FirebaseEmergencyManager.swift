//
//  FirebaseEmergencyManager.swift
//  SecureHeart
//
//  Firebase-enabled Emergency Contacts Manager with real messaging
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import Combine

// MARK: - Firebase Data Models

struct FirebaseEmergencyContact: Identifiable, Codable {
    let id: String
    var name: String
    var phoneNumber: String
    var email: String?
    var relationship: String
    var isPrimary: Bool
    var isVerified: Bool
    var fcmToken: String?
    var invitationSent: Bool
    var invitationAccepted: Bool
    var createdAt: Timestamp
    var lastNotified: Timestamp?

    init(name: String, phoneNumber: String, email: String? = nil, relationship: String, isPrimary: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.relationship = relationship
        self.isPrimary = isPrimary
        self.isVerified = false
        self.fcmToken = nil
        self.invitationSent = false
        self.invitationAccepted = false
        self.createdAt = Timestamp()
        self.lastNotified = nil
    }
}

struct EmergencyEvent: Codable {
    let id: String
    let userID: String
    let heartRate: Int
    let timestamp: Timestamp
    let location: GeoPoint?
    let contactsNotified: [String] // Contact IDs
    let notificationStatus: [String: String] // ContactID: Status
    var resolved: Bool
    var resolvedAt: Timestamp?
    let severity: EmergencySeverity

    enum EmergencySeverity: String, Codable {
        case critical = "critical"  // HR < 40 or > 150
        case high = "high"         // HR 40-50 or 130-150
        case moderate = "moderate" // Other concerning readings
    }
}

struct NotificationDelivery: Codable {
    let id: String
    let emergencyEventID: String
    let contactID: String
    let method: String // "sms", "email", "push"
    let status: String // "pending", "sent", "delivered", "failed"
    let timestamp: Timestamp
    let retryCount: Int
    let errorMessage: String?
}

// MARK: - Firebase Emergency Manager

class FirebaseEmergencyManager: ObservableObject {
    @Published var contacts: [FirebaseEmergencyContact] = []
    @Published var emergencyTriggered = false
    @Published var lastEmergencyAlert: Date?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var userID: String?
    private var listenerRegistration: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupFirebase()
        observeAuthChanges()
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Firebase Setup

    private func setupFirebase() {
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }

    private func observeAuthChanges() {
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.userID = user?.uid

                if user != nil {
                    self?.loadContacts()
                    self?.setupContactsListener()
                } else {
                    self?.contacts = []
                    self?.listenerRegistration?.remove()
                }
            }
        }
    }

    // MARK: - Authentication

    func signInAnonymously() async throws {
        isLoading = true
        do {
            let result = try await auth.signInAnonymously()
            userID = result.user.uid
            print("✅ Anonymous sign-in successful: \(result.user.uid)")
        } catch {
            print("❌ Anonymous sign-in failed: \(error)")
            throw error
        }
        isLoading = false
    }

    // MARK: - Contact Management

    private func setupContactsListener() {
        guard let userID = userID else { return }

        listenerRegistration = db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading contacts: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    self?.contacts = documents.compactMap { doc in
                        try? doc.data(as: FirebaseEmergencyContact.self)
                    }
                }
            }
    }

    private func loadContacts() {
        guard let userID = userID else { return }

        isLoading = true
        db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .order(by: "createdAt")
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error = error {
                        print("❌ Error loading contacts: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    self?.contacts = documents.compactMap { doc in
                        try? doc.data(as: FirebaseEmergencyContact.self)
                    }
                }
            }
    }

    func addContact(_ contact: FirebaseEmergencyContact) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        var newContact = contact
        newContact.invitationSent = false
        newContact.invitationAccepted = false

        try await db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .document(contact.id)
            .setData(from: newContact)

        // Send invitation after contact is saved
        await sendContactInvitation(contact: newContact)

        print("✅ Contact added successfully: \(contact.name)")
    }

    func updateContact(_ contact: FirebaseEmergencyContact) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .document(contact.id)
            .setData(from: contact)

        print("✅ Contact updated successfully: \(contact.name)")
    }

    func deleteContact(contactID: String) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .document(contactID)
            .delete()

        print("✅ Contact deleted successfully")
    }

    func setPrimaryContact(_ contact: FirebaseEmergencyContact) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let batch = db.batch()

        // Remove primary status from all contacts
        for existingContact in contacts {
            var updatedContact = existingContact
            updatedContact.isPrimary = false

            let docRef = db.collection("users")
                .document(userID)
                .collection("emergencyContacts")
                .document(existingContact.id)

            try batch.setData(from: updatedContact, forDocument: docRef)
        }

        // Set new primary contact
        var primaryContact = contact
        primaryContact.isPrimary = true

        let primaryRef = db.collection("users")
            .document(userID)
            .collection("emergencyContacts")
            .document(contact.id)

        try batch.setData(from: primaryContact, forDocument: primaryRef)

        try await batch.commit()
        print("✅ Primary contact updated: \(contact.name)")
    }

    // MARK: - Emergency Functions

    func triggerEmergency(heartRate: Int, location: GeoPoint? = nil) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        guard !contacts.isEmpty else {
            print("❌ No emergency contacts configured")
            return
        }

        DispatchQueue.main.async {
            self.emergencyTriggered = true
            self.lastEmergencyAlert = Date()
        }

        // Determine severity
        let severity: EmergencyEvent.EmergencySeverity
        if heartRate < 40 || heartRate > 150 {
            severity = .critical
        } else if heartRate <= 50 || heartRate >= 130 {
            severity = .high
        } else {
            severity = .moderate
        }

        // Create emergency event
        let contactsToNotify = getPriorityContacts()
        let eventID = UUID().uuidString

        let emergencyEvent = EmergencyEvent(
            id: eventID,
            userID: userID,
            heartRate: heartRate,
            timestamp: Timestamp(),
            location: location,
            contactsNotified: contactsToNotify.map { $0.id },
            notificationStatus: [:],
            resolved: false,
            resolvedAt: nil,
            severity: severity
        )

        // Save emergency event
        try await db.collection("emergencyEvents")
            .document(eventID)
            .setData(from: emergencyEvent)

        // Trigger notifications via Cloud Function
        let notificationData: [String: Any] = [
            "emergencyEventID": eventID,
            "userID": userID,
            "heartRate": heartRate,
            "severity": severity.rawValue,
            "contactIDs": contactsToNotify.map { $0.id },
            "timestamp": Timestamp().dateValue().timeIntervalSince1970,
            "location": location?.latitude ?? 0 // Will be expanded in Cloud Function
        ]

        try await db.collection("notifications")
            .document(eventID)
            .setData(notificationData)

        print("🚨 Emergency triggered - HR: \(heartRate) BPM, Severity: \(severity.rawValue)")
    }

    private func getPriorityContacts() -> [FirebaseEmergencyContact] {
        let verifiedContacts = contacts.filter { $0.isVerified || $0.invitationAccepted }

        if let primaryContact = verifiedContacts.first(where: { $0.isPrimary }) {
            return [primaryContact]
        } else {
            return Array(verifiedContacts.prefix(2))
        }
    }

    func resolveEmergency(eventID: String? = nil) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        DispatchQueue.main.async {
            self.emergencyTriggered = false
        }

        // If no specific event ID, find the most recent unresolved event
        let finalEventID: String
        if let eventID = eventID {
            finalEventID = eventID
        } else {
            // Query for most recent unresolved event
            let snapshot = try await db.collection("emergencyEvents")
                .whereField("userID", isEqualTo: userID)
                .whereField("resolved", isEqualTo: false)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let document = snapshot.documents.first else {
                print("❌ No unresolved emergency events found")
                return
            }
            finalEventID = document.documentID
        }

        // Update event as resolved
        try await db.collection("emergencyEvents")
            .document(finalEventID)
            .updateData([
                "resolved": true,
                "resolvedAt": Timestamp()
            ])

        print("✅ Emergency resolved: \(finalEventID)")
    }

    // MARK: - Contact Invitations

    private func sendContactInvitation(contact: FirebaseEmergencyContact) async {
        guard let userID = userID else { return }

        // Create invitation data for Cloud Function
        let invitationData: [String: Any] = [
            "type": "contact_invitation",
            "contactID": contact.id,
            "contactName": contact.name,
            "contactPhone": contact.phoneNumber,
            "contactEmail": contact.email ?? "",
            "userID": userID,
            "relationship": contact.relationship,
            "timestamp": Timestamp().dateValue().timeIntervalSince1970
        ]

        do {
            try await db.collection("invitations")
                .document(contact.id)
                .setData(invitationData)

            // Update contact to mark invitation as sent
            var updatedContact = contact
            updatedContact.invitationSent = true
            try await updateContact(updatedContact)

            print("📤 Invitation sent to \(contact.name)")
        } catch {
            print("❌ Failed to send invitation: \(error)")
        }
    }

    // MARK: - Utility Functions

    func getEmergencyHistory() async throws -> [EmergencyEvent] {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let snapshot = try await db.collection("emergencyEvents")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: EmergencyEvent.self)
        }
    }

    func clearEmergencyHistory() async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let snapshot = try await db.collection("emergencyEvents")
            .whereField("userID", isEqualTo: userID)
            .getDocuments()

        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()
        print("✅ Emergency history cleared")
    }
}