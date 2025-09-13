//
//  EmergencyContactsManager.swift
//  SecureHeart
//
//  Created by Laura Money on 9/12/25.
//

import Foundation
import Firebase
import FirebaseFirestore

struct EmergencyContact: Identifiable, Codable {
    let id = UUID()
    var name: String
    var phoneNumber: String
    var email: String?
    var relationship: String
    var isPrimary: Bool
    
    init(name: String, phoneNumber: String, email: String? = nil, relationship: String, isPrimary: Bool = false) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.relationship = relationship
        self.isPrimary = isPrimary
    }
}

class EmergencyContactsManager: ObservableObject {
    @Published var contacts: [EmergencyContact] = []
    @Published var emergencyTriggered = false
    @Published var lastEmergencyAlert: Date?
    
    private let db = Firestore.firestore()
    private let userID: String
    
    init() {
        self.userID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        loadEmergencyContacts()
    }
    
    // MARK: - Local Storage Management
    
    func loadEmergencyContacts() {
        if let data = UserDefaults.standard.data(forKey: "EmergencyContacts"),
           let contacts = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            self.contacts = contacts
        }
        
        // Also load from Firebase
        loadFromFirebase()
    }
    
    func saveEmergencyContacts() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: "EmergencyContacts")
        }
        
        // Also save to Firebase
        saveToFirebase()
    }
    
    // MARK: - Firebase Integration
    
    func saveToFirebase() {
        let contactsData = contacts.map { contact in
            [
                "name": contact.name,
                "phoneNumber": contact.phoneNumber,
                "email": contact.email ?? "",
                "relationship": contact.relationship,
                "isPrimary": contact.isPrimary
            ]
        }
        
        db.collection("users").document(userID).collection("emergencyContacts").document("contacts").setData([
            "contacts": contactsData,
            "lastUpdated": Timestamp()
        ]) { error in
            if let error = error {
                print("Error saving emergency contacts to Firebase: \(error)")
            } else {
                print("Emergency contacts successfully saved to Firebase")
            }
        }
    }
    
    func loadFromFirebase() {
        db.collection("users").document(userID).collection("emergencyContacts").document("contacts").getDocument { document, error in
            if let error = error {
                print("Error loading emergency contacts from Firebase: \(error)")
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data(),
                  let contactsArray = data["contacts"] as? [[String: Any]] else {
                return
            }
            
            DispatchQueue.main.async {
                self.contacts = contactsArray.compactMap { contactData in
                    guard let name = contactData["name"] as? String,
                          let phoneNumber = contactData["phoneNumber"] as? String,
                          let relationship = contactData["relationship"] as? String,
                          let isPrimary = contactData["isPrimary"] as? Bool else {
                        return nil
                    }
                    
                    let email = contactData["email"] as? String
                    return EmergencyContact(
                        name: name,
                        phoneNumber: phoneNumber,
                        email: email?.isEmpty == true ? nil : email,
                        relationship: relationship,
                        isPrimary: isPrimary
                    )
                }
            }
        }
    }
    
    // MARK: - Contact Management
    
    func addContact(_ contact: EmergencyContact) {
        contacts.append(contact)
        saveEmergencyContacts()
    }
    
    func updateContact(_ contact: EmergencyContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            saveEmergencyContacts()
        }
    }
    
    func deleteContact(at indexSet: IndexSet) {
        contacts.remove(atOffsets: indexSet)
        saveEmergencyContacts()
    }
    
    func setPrimaryContact(_ contact: EmergencyContact) {
        // Remove primary status from all contacts
        for index in contacts.indices {
            contacts[index].isPrimary = false
        }
        
        // Set the selected contact as primary
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index].isPrimary = true
        }
        
        saveEmergencyContacts()
    }
    
    // MARK: - Emergency Functions
    
    func triggerEmergency(heartRate: Int, timestamp: Date = Date()) {
        guard !contacts.isEmpty else {
            print("No emergency contacts configured")
            return
        }
        
        emergencyTriggered = true
        lastEmergencyAlert = timestamp
        
        // Log emergency event to Firebase
        logEmergencyEvent(heartRate: heartRate, timestamp: timestamp)
        
        // Send notifications to emergency contacts
        sendEmergencyNotifications(heartRate: heartRate, timestamp: timestamp)
        
        print("Emergency triggered - HR: \(heartRate) BPM at \(timestamp)")
    }
    
    private func logEmergencyEvent(heartRate: Int, timestamp: Date) {
        let emergencyData: [String: Any] = [
            "heartRate": heartRate,
            "timestamp": Timestamp(date: timestamp),
            "contacts": contacts.map { $0.name },
            "location": "Unknown", // Could be enhanced with location services
            "resolved": false
        ]
        
        db.collection("users").document(userID).collection("emergencyEvents").addDocument(data: emergencyData) { error in
            if let error = error {
                print("Error logging emergency event: \(error)")
            } else {
                print("Emergency event logged successfully")
            }
        }
    }
    
    private func sendEmergencyNotifications(heartRate: Int, timestamp: Date) {
        let primaryContact = contacts.first { $0.isPrimary }
        let contactsToNotify = primaryContact != nil ? [primaryContact!] : Array(contacts.prefix(2))
        
        for contact in contactsToNotify {
            sendNotificationToContact(contact, heartRate: heartRate, timestamp: timestamp)
        }
    }
    
    private func sendNotificationToContact(_ contact: EmergencyContact, heartRate: Int, timestamp: Date) {
        // In a real implementation, this would integrate with:
        // 1. Push notifications via Firebase Cloud Messaging
        // 2. SMS service like Twilio
        // 3. Email service
        
        let message = """
        EMERGENCY ALERT from SecureHeart POTS Monitor
        
        Heart rate detected: \(heartRate) BPM
        Time: \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .medium))
        
        Please check on your contact immediately.
        
        This is an automated message from the SecureHeart app.
        """
        
        print("Would send emergency notification to \(contact.name) (\(contact.phoneNumber)): \(message)")
        
        // Log notification attempt to Firebase
        db.collection("users").document(userID).collection("notifications").addDocument(data: [
            "contactName": contact.name,
            "contactPhone": contact.phoneNumber,
            "message": message,
            "timestamp": Timestamp(date: timestamp),
            "type": "emergency_alert"
        ])
    }
    
    func resolveEmergency() {
        emergencyTriggered = false
        
        // Update the most recent emergency event as resolved
        if let lastAlert = lastEmergencyAlert {
            db.collection("users").document(userID).collection("emergencyEvents")
                .whereField("timestamp", isGreaterThan: Timestamp(date: lastAlert.addingTimeInterval(-60)))
                .whereField("resolved", isEqualTo: false)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents, !documents.isEmpty else { return }
                    
                    let document = documents[0]
                    document.reference.updateData(["resolved": true, "resolvedAt": Timestamp()])
                }
        }
    }
}
