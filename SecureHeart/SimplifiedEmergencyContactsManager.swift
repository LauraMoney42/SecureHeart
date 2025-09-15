//
//  SimplifiedEmergencyContactsManager.swift
//  SecureHeart
//
//  Simplified Firebase-only emergency contacts with native iOS messaging
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import FirebaseFunctions
import CoreLocation

// MARK: - Data Models

struct LinkedContact: Identifiable, Codable {
    let id: String
    let contactUserID: String
    var contactFirstName: String
    var fcmToken: String
    let linkedAt: Date
    var shareLocationWithMe: Bool
    var shareMyLocationWithThem: Bool

    enum CodingKeys: String, CodingKey {
        case id, contactUserID, contactFirstName, fcmToken, linkedAt
        case shareLocationWithMe, shareMyLocationWithThem
    }
}

struct UserProfile: Codable {
    let userID: String
    var firstName: String
    var fcmToken: String
    var linkedContacts: [String: LinkedContact] // ContactUserID -> LinkedContact
    var shareLocationByDefault: Bool
    let createdAt: Date

    init(userID: String, firstName: String, fcmToken: String = "") {
        self.userID = userID
        self.firstName = firstName
        self.fcmToken = fcmToken
        self.linkedContacts = [:]
        self.shareLocationByDefault = false
        self.createdAt = Date()
    }
}

struct SimplifiedEmergencyEvent: Codable {
    let id: String
    let userID: String
    let userFirstName: String
    let heartRate: Int
    let severity: SimplifiedEmergencySeverity
    let timestamp: Date
    let location: GeoPoint?
    let contactsNotified: [String]
    var resolved: Bool
    var resolvedAt: Date?

    enum SimplifiedEmergencySeverity: String, Codable, CaseIterable {
        case critical = "critical"  // HR < 40 or > 150
        case high = "high"         // HR 40-50 or 130-150
        case moderate = "moderate" // Other concerning readings

        var emoji: String {
            switch self {
            case .critical: return "🚨"
            case .high: return "⚠️"
            case .moderate: return "💛"
            }
        }
    }
}

// MARK: - Simplified Emergency Contacts Manager

class SimplifiedEmergencyContactsManager: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var linkedContacts: [LinkedContact] = []
    @Published var emergencyTriggered = false
    @Published var lastEmergencyAlert: Date?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var connectionStatus = "Connecting..."

    // Emergency confirmation
    @Published var showingEmergencyConfirmation = false
    @Published var pendingEmergencyHeartRate: Int = 0
    @Published var emergencyConfirmationTimeRemaining: Int = 15

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let functions = Functions.functions()
    private var userID: String?
    private var listenerRegistration: ListenerRegistration?
    private let locationManager = CLLocationManager()

    init() {
        setupFirebase()
        observeAuthChanges()
        requestLocationPermission()
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Firebase Setup

    private func setupFirebase() {
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
                    self?.loadUserProfile()
                    self?.setupUserProfileListener()
                } else {
                    Task {
                        await self?.signInAnonymously()
                    }
                }
            }
        }
    }

    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
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

    // MARK: - User Profile Management

    private func loadUserProfile() {
        guard let userID = userID else { return }

        isLoading = true
        db.collection("users").document(userID).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Error loading user profile: \(error)")
                    return
                }

                if let document = document, document.exists,
                   let profile = try? document.data(as: UserProfile.self) {
                    self?.userProfile = profile
                    self?.linkedContacts = Array(profile.linkedContacts.values)
                } else {
                    // Create new user profile
                    self?.createNewUserProfile()
                }
            }
        }
    }

    private func createNewUserProfile() {
        guard let userID = userID else { return }

        let defaultFirstName = "User" // Will be updated when user sets their name
        let profile = UserProfile(userID: userID, firstName: defaultFirstName)

        do {
            try db.collection("users").document(userID).setData(from: profile)
            DispatchQueue.main.async {
                self.userProfile = profile
            }
            print("✅ Created new user profile")
        } catch {
            print("❌ Error creating user profile: \(error)")
        }
    }

    private func setupUserProfileListener() {
        guard let userID = userID else { return }

        listenerRegistration = db.collection("users")
            .document(userID)
            .addSnapshotListener { [weak self] document, error in
                if let error = error {
                    print("❌ Error listening to user profile: \(error)")
                    return
                }

                if let document = document, document.exists,
                   let profile = try? document.data(as: UserProfile.self) {
                    DispatchQueue.main.async {
                        self?.userProfile = profile
                        self?.linkedContacts = Array(profile.linkedContacts.values)
                    }
                }
            }
    }

    func updateUserProfile(firstName: String) async throws {
        guard let userID = userID, var profile = userProfile else {
            throw NSError(domain: "ProfileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user profile found"])
        }

        profile.firstName = firstName

        try await db.collection("users").document(userID).setData(from: profile)

        DispatchQueue.main.async {
            self.userProfile = profile
        }

        print("✅ User profile updated: \(firstName)")
    }

    func updateFCMToken(_ token: String) async throws {
        guard let userID = userID, var profile = userProfile else { return }

        profile.fcmToken = token

        try await db.collection("users").document(userID).setData(from: profile)

        DispatchQueue.main.async {
            self.userProfile = profile
        }

        print("✅ FCM token updated")
    }

    // MARK: - Invitation Code System

    func generateInvitationCode() -> String {
        let characters = "ABCDEFGHIJKLMNPQRSTUVWXYZ123456789" // Excluding O, 0 for clarity
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    func createInvitationLink(userFirstName: String) async throws -> String {
        guard let userID = userID else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let invitationCode = generateInvitationCode()

        // Store invitation request in Firebase
        let linkRequest: [String: Any] = [
            "type": "contact_link_request",
            "inviterUserID": userID,
            "inviterFirstName": userFirstName,
            "invitationCode": invitationCode,
            "timestamp": Timestamp().dateValue().timeIntervalSince1970
        ]

        try await db.collection("linkRequests")
            .document(UUID().uuidString)
            .setData(linkRequest)

        print("✅ Invitation link created: \(invitationCode)")
        return invitationCode
    }

    func acceptInvitation(code: String, contactFirstName: String) async throws -> String {
        guard let userID = userID else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Get current FCM token
        let fcmToken = await getFCMToken()

        // Call Cloud Function to link contacts
        let linkData: [String: Any] = [
            "invitationCode": code,
            "contactFirstName": contactFirstName,
            "contactFCMToken": fcmToken
        ]

        do {
            let result = try await functions.httpsCallable("linkContacts").call(linkData)

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               let linkedWith = data["linkedWith"] as? String,
               success {
                print("✅ Successfully linked with \(linkedWith)")
                return linkedWith
            } else {
                throw NSError(domain: "LinkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to link contacts"])
            }
        } catch {
            print("❌ Error accepting invitation: \(error)")
            throw error
        }
    }

    private func getFCMToken() async -> String {
        do {
            let token = try await Messaging.messaging().token()
            return token
        } catch {
            print("❌ Error getting FCM token: \(error)")
            return ""
        }
    }

    // MARK: - Emergency Functions

    func showEmergencyConfirmation(heartRate: Int) {
        DispatchQueue.main.async {
            self.pendingEmergencyHeartRate = heartRate
            self.emergencyConfirmationTimeRemaining = 15
            self.showingEmergencyConfirmation = true
            self.startConfirmationCountdown()
        }
    }

    private func startConfirmationCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.emergencyConfirmationTimeRemaining > 0 {
                    self.emergencyConfirmationTimeRemaining -= 1
                } else {
                    timer.invalidate()
                    if self.showingEmergencyConfirmation {
                        // Auto-confirm if user doesn't cancel
                        self.confirmEmergencyAlert()
                    }
                }
            }
        }
    }

    func cancelEmergencyAlert() {
        DispatchQueue.main.async {
            self.showingEmergencyConfirmation = false
            self.pendingEmergencyHeartRate = 0
            self.emergencyConfirmationTimeRemaining = 15
        }
        print("🚫 Emergency alert cancelled by user")
    }

    func confirmEmergencyAlert() {
        DispatchQueue.main.async {
            self.showingEmergencyConfirmation = false
        }

        Task {
            do {
                try await self.triggerEmergency(heartRate: self.pendingEmergencyHeartRate)
            } catch {
                print("❌ Error sending emergency alert: \(error)")
            }
        }
    }

    func triggerEmergency(heartRate: Int, includeLocation: Bool = true) async throws {
        guard let userID = userID, let profile = userProfile else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        guard !linkedContacts.isEmpty else {
            print("❌ No linked contacts configured")
            return
        }

        DispatchQueue.main.async {
            self.emergencyTriggered = true
            self.lastEmergencyAlert = Date()
        }

        // Determine severity
        let severity: SimplifiedEmergencyEvent.SimplifiedEmergencySeverity
        if heartRate < 40 || heartRate > 150 {
            severity = .critical
        } else if heartRate <= 50 || heartRate >= 130 {
            severity = .high
        } else {
            severity = .moderate
        }

        // Get location if requested and authorized
        var location: GeoPoint?
        if includeLocation && profile.shareLocationByDefault {
            location = await getCurrentLocation()
        }

        let eventID = UUID().uuidString

        // Create notification data for Cloud Function
        let notificationData: [String: Any] = [
            "emergencyEventID": eventID,
            "userID": userID,
            "userFirstName": profile.firstName,
            "heartRate": heartRate,
            "severity": severity.rawValue,
            "linkedContactTokens": linkedContacts.compactMap { $0.fcmToken },
            "timestamp": Timestamp().dateValue().timeIntervalSince1970,
            "location": location != nil ? [
                "latitude": location!.latitude,
                "longitude": location!.longitude
            ] : nil,
            "shareLocation": includeLocation && profile.shareLocationByDefault
        ]

        // Trigger Cloud Function
        try await db.collection("notifications")
            .document(eventID)
            .setData(notificationData)

        print("🚨 Emergency notification sent - Event ID: \(eventID)")
    }

    private func getCurrentLocation() async -> GeoPoint? {
        // This would typically use CLLocationManager to get current location
        // For now, return nil - location can be implemented separately
        return nil
    }

    func resolveEmergency() async throws {
        DispatchQueue.main.async {
            self.emergencyTriggered = false
        }

        // Find and resolve most recent emergency event
        guard let userID = userID else { return }

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

        try await document.reference.updateData([
            "resolved": true,
            "resolvedAt": Timestamp()
        ])

        print("✅ Emergency resolved: \(document.documentID)")
    }

    // MARK: - Utility Functions

    func updateLocationSharingPreference(shareByDefault: Bool) async throws {
        guard let userID = userID, var profile = userProfile else { return }

        profile.shareLocationByDefault = shareByDefault

        try await db.collection("users").document(userID).setData(from: profile)

        DispatchQueue.main.async {
            self.userProfile = profile
        }

        print("✅ Location sharing preference updated: \(shareByDefault)")
    }

    func updateContactLocationPermission(contactUserID: String, shareLocationWithMe: Bool, shareMyLocationWithThem: Bool) async throws {
        guard let userID = userID, var profile = userProfile else { return }

        if var contact = profile.linkedContacts[contactUserID] {
            contact.shareLocationWithMe = shareLocationWithMe
            contact.shareMyLocationWithThem = shareMyLocationWithThem
            profile.linkedContacts[contactUserID] = contact

            try await db.collection("users").document(userID).setData(from: profile)

            DispatchQueue.main.async {
                self.userProfile = profile
                if let index = self.linkedContacts.firstIndex(where: { $0.contactUserID == contactUserID }) {
                    self.linkedContacts[index] = contact
                }
            }

            print("✅ Contact location permissions updated for \(contact.contactFirstName)")
        }
    }

    func getEmergencyHistory() async throws -> [SimplifiedEmergencyEvent] {
        guard let userID = userID else { return [] }

        let snapshot = try await db.collection("emergencyEvents")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: SimplifiedEmergencyEvent.self)
        }
    }
}