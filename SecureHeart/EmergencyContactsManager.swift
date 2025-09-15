//
//  EmergencyContactsManager.swift
//  SecureHeart
//
//  Firebase-enabled Emergency Contacts Manager with real messaging
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

// MARK: - Data Models

struct EmergencyContact: Identifiable, Codable {
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
    var createdAt: Date
    var lastNotified: Date?

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
        self.createdAt = Date()
        self.lastNotified = nil
    }

    // Local contact conversion
    init(from localContact: LocalEmergencyContact) {
        self.id = UUID().uuidString
        self.name = localContact.name
        self.phoneNumber = localContact.phoneNumber
        self.email = localContact.email
        self.relationship = localContact.relationship
        self.isPrimary = localContact.isPrimary
        self.isVerified = false
        self.fcmToken = nil
        self.invitationSent = false
        self.invitationAccepted = false
        self.createdAt = Date()
        self.lastNotified = nil
    }
}

// Legacy local contact for migration
struct LocalEmergencyContact: Identifiable, Codable {
    let id = UUID()
    var name: String
    var phoneNumber: String
    var email: String?
    var relationship: String
    var isPrimary: Bool
}

class EmergencyContactsManager: ObservableObject {
    @Published var contacts: [EmergencyContact] = []
    @Published var emergencyTriggered = false
    @Published var lastEmergencyAlert: Date?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var connectionStatus = "Connecting..."

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var userID: String?
    private var listenerRegistration: ListenerRegistration?
    private let localUserID: String

    init() {
        self.localUserID = ConfigurationManager.shared.getAnonymousUserID()
        setupFirebase()
        observeAuthChanges()
        requestNotificationPermissions()
        setupFCMToken()
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Firebase Setup

    private func setupFirebase() {
        // Configure Firestore settings for offline support
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
                self?.connectionStatus = user != nil ? "Connected" : "Offline"

                if user != nil {
                    self?.migrateLocalContacts()
                    self?.loadContacts()
                    self?.setupContactsListener()
                } else {
                    // Try to authenticate automatically
                    Task {
                        await self?.signInAnonymously()
                    }
                }
            }
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("✅ Notification permission granted: \(granted)")
            }
        }
    }

    private func setupFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("✅ FCM registration token: \(token)")
                // Store token for this user
                self?.updateUserFCMToken(token)
            }
        }
    }

    private func updateUserFCMToken(_ token: String) {
        guard let userID = userID else { return }

        db.collection("users").document(userID).setData([
            "fcmToken": token,
            "lastUpdated": Timestamp()
        ], merge: true) { error in
            if let error = error {
                print("❌ Error updating FCM token: \(error)")
            } else {
                print("✅ FCM token updated successfully")
            }
        }
    }

    // MARK: - Authentication

    func signInAnonymously() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.connectionStatus = "Connecting..."
        }

        do {
            let result = try await auth.signInAnonymously()
            DispatchQueue.main.async {
                self.userID = result.user.uid
                self.isLoading = false
                self.connectionStatus = "Connected"
            }
            print("✅ Anonymous sign-in successful: \(result.user.uid)")
        } catch {
            print("❌ Anonymous sign-in failed: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.connectionStatus = "Connection Failed"
            }
        }
    }

    // MARK: - Migration from Local Storage

    private func migrateLocalContacts() {
        guard let data = UserDefaults.standard.data(forKey: "EmergencyContacts"),
              let localContacts = try? JSONDecoder().decode([LocalEmergencyContact].self, from: data),
              !localContacts.isEmpty else {
            return
        }

        print("🔄 Migrating \(localContacts.count) local contacts to Firebase")

        for localContact in localContacts {
            let firebaseContact = EmergencyContact(from: localContact)
            Task {
                try await self.addContact(firebaseContact)
            }
        }

        // Clear local storage after migration
        UserDefaults.standard.removeObject(forKey: "EmergencyContacts")
        print("✅ Local contacts migrated and cleared")
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
                        try? doc.data(as: EmergencyContact.self)
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
                        try? doc.data(as: EmergencyContact.self)
                    }
                }
            }
    }

    func addContact(_ contact: EmergencyContact) {
        Task {
            do {
                try await addContactAsync(contact)
            } catch {
                print("❌ Error adding contact: \(error)")
            }
        }
    }

    private func addContactAsync(_ contact: EmergencyContact) async throws {
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

    func updateContact(_ contact: EmergencyContact) {
        Task {
            do {
                try await updateContact(contact)
            } catch {
                print("❌ Error updating contact: \(error)")
            }
        }
    }

    private func updateContact(_ contact: EmergencyContact) async throws {
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

    func deleteContact(at indexSet: IndexSet) {
        for index in indexSet {
            let contact = contacts[index]
            Task {
                do {
                    try await deleteContact(contactID: contact.id)
                } catch {
                    print("❌ Error deleting contact: \(error)")
                }
            }
        }
    }

    private func deleteContact(contactID: String) async throws {
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

    func setPrimaryContact(_ contact: EmergencyContact) {
        Task {
            do {
                try await setPrimaryContact(contact)
            } catch {
                print("❌ Error setting primary contact: \(error)")
            }
        }
    }

    private func setPrimaryContact(_ contact: EmergencyContact) async throws {
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

    func triggerEmergency(heartRate: Int, timestamp: Date = Date()) {
        guard !contacts.isEmpty else {
            print("❌ No emergency contacts configured")
            return
        }

        emergencyTriggered = true
        lastEmergencyAlert = timestamp

        print("🚨 Emergency triggered - HR: \(heartRate) BPM at \(timestamp)")

        Task {
            do {
                try await triggerEmergency(heartRate: heartRate, location: nil)
            } catch {
                print("❌ Error triggering emergency: \(error)")
            }
        }
    }

    private func triggerEmergency(heartRate: Int, location: GeoPoint? = nil) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Determine severity
        let severity: String
        if heartRate < 40 || heartRate > 150 {
            severity = "critical"
        } else if heartRate <= 50 || heartRate >= 130 {
            severity = "high"
        } else {
            severity = "moderate"
        }

        // Get contacts to notify
        let contactsToNotify = getPriorityContacts()
        let eventID = UUID().uuidString

        // Create notification data for Cloud Function
        let notificationData: [String: Any] = [
            "emergencyEventID": eventID,
            "userID": userID,
            "heartRate": heartRate,
            "severity": severity,
            "contactIDs": contactsToNotify.map { $0.id },
            "timestamp": Timestamp().dateValue().timeIntervalSince1970
        ]

        // This will trigger the Cloud Function
        try await db.collection("notifications")
            .document(eventID)
            .setData(notificationData)

        print("🚨 Emergency notification sent to Firebase - Event ID: \(eventID)")

        // Also use local queue as backup
        for contact in contactsToNotify {
            let priority: QueuedNotification.NotificationPriority =
                heartRate > 150 || heartRate < 40 ? .critical : .high

            EmergencyNotificationQueue.shared.enqueueEmergencyAlert(
                contactName: contact.name,
                contactPhone: contact.phoneNumber,
                contactEmail: contact.email,
                heartRate: heartRate,
                emergencyID: eventID,
                priority: priority
            )
        }
    }

    private func getPriorityContacts() -> [EmergencyContact] {
        let verifiedContacts = contacts.filter { $0.isVerified || $0.invitationAccepted }

        if let primaryContact = verifiedContacts.first(where: { $0.isPrimary }) {
            return [primaryContact]
        } else if !verifiedContacts.isEmpty {
            return Array(verifiedContacts.prefix(2))
        } else {
            // If no verified contacts, use first 2 contacts anyway
            return Array(contacts.prefix(2))
        }
    }

    func resolveEmergency() {
        emergencyTriggered = false

        Task {
            do {
                try await resolveEmergency(eventID: nil)
            } catch {
                print("❌ Error resolving emergency: \(error)")
            }
        }
    }

    private func resolveEmergency(eventID: String? = nil) async throws {
        guard let userID = userID else {
            throw NSError(domain: "FirebaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // If no specific event ID, find the most recent unresolved event
        let finalEventID: String
        if let eventID = eventID {
            finalEventID = eventID
        } else {
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

    private func sendContactInvitation(contact: EmergencyContact) async {
        guard let userID = userID else { return }

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

            var updatedContact = contact
            updatedContact.invitationSent = true
            try await updateContact(updatedContact)

            print("📤 Invitation sent to \(contact.name)")
        } catch {
            print("❌ Failed to send invitation: \(error)")
        }
    }

    // MARK: - Legacy Support

    func getEmergencyHistory() -> [[String: Any]] {
        // This is kept for backwards compatibility but will eventually move to Firebase
        return UserDefaults.standard.array(forKey: "EmergencyEvents") as? [[String: Any]] ?? []
    }

    func clearEmergencyHistory() {
        UserDefaults.standard.removeObject(forKey: "EmergencyEvents")
        UserDefaults.standard.removeObject(forKey: "NotificationLog")

        // Also clear Firebase history if connected
        Task {
            do {
                try await clearFirebaseHistory()
            } catch {
                print("❌ Error clearing Firebase history: \(error)")
            }
        }
    }

    private func clearFirebaseHistory() async throws {
        guard let userID = userID else { return }

        let snapshot = try await db.collection("emergencyEvents")
            .whereField("userID", isEqualTo: userID)
            .getDocuments()

        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()
        print("✅ Firebase emergency history cleared")
    }
}