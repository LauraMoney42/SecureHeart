//
//  MedicalDataEncryption.swift
//  SecureHeart
//
//  Encryption utilities for medical data protection
//

import Foundation
import CryptoKit
import Security

// MARK: - Medical Data Encryption Manager
class MedicalDataEncryption {
    static let shared = MedicalDataEncryption()

    private let keychain = KeychainManager()
    private let encryptionKeyName = "medical_data_key"

    private init() {
        // Ensure encryption key exists
        _ = getOrCreateEncryptionKey()
    }

    // MARK: - Key Management

    /// Gets or creates a persistent encryption key for medical data
    private func getOrCreateEncryptionKey() -> SymmetricKey {
        // Try to retrieve existing key
        if let keyData = keychain.retrieve(key: encryptionKeyName) {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        keychain.store(key: encryptionKeyName, data: keyData)

        return key
    }

    // MARK: - Encryption Methods

    /// Encrypts sensitive medical data
    func encrypt(_ data: Data) throws -> Data {
        let key = getOrCreateEncryptionKey()

        // Generate nonce (number used once)
        let nonce = AES.GCM.Nonce()

        // Encrypt the data
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        // Combine nonce + ciphertext + tag for storage
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined
    }

    /// Decrypts medical data
    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = getOrCreateEncryptionKey()

        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)

        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    /// Encrypts a string
    func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidInput
        }
        return try encrypt(data)
    }

    /// Decrypts to a string
    func decryptString(_ encryptedData: Data) throws -> String {
        let decryptedData = try decrypt(encryptedData)
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        return string
    }

    /// Encrypts a Codable object
    func encryptCodable<T: Codable>(_ object: T) throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        return try encrypt(data)
    }

    /// Decrypts to a Codable object
    func decryptCodable<T: Codable>(_ encryptedData: Data, type: T.Type) throws -> T {
        let decryptedData = try decrypt(encryptedData)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: decryptedData)
    }
}

// MARK: - Encryption Errors
enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidInput
    case keyGenerationFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidInput:
            return "Invalid input data"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        }
    }
}

// MARK: - Secure Heart Rate Entry
struct SecureHeartRateEntry: Codable {
    let heartRate: Int
    let timestamp: Date
    let context: String?
    let isEmergency: Bool

    // Encrypted storage
    var encrypted: Data? {
        try? MedicalDataEncryption.shared.encryptCodable(self)
    }

    // Decrypt from data
    static func decrypt(from data: Data) -> SecureHeartRateEntry? {
        try? MedicalDataEncryption.shared.decryptCodable(data, type: SecureHeartRateEntry.self)
    }
}

// MARK: - Secure Emergency Event
struct SecureEmergencyEvent: Codable {
    let id: String
    let heartRate: Int
    let timestamp: Date
    let contacts: [String]
    let location: String?
    let resolved: Bool
    let medicalNotes: String?

    // Encrypted storage
    var encrypted: Data? {
        try? MedicalDataEncryption.shared.encryptCodable(self)
    }

    // Decrypt from data
    static func decrypt(from data: Data) -> SecureEmergencyEvent? {
        try? MedicalDataEncryption.shared.decryptCodable(data, type: SecureEmergencyEvent.self)
    }
}

// MARK: - Privacy Consent Manager
class PrivacyConsentManager {
    static let shared = PrivacyConsentManager()

    private let userDefaults = UserDefaults.standard
    private let consentKeys = [
        "health_data_collection": "Consent to collect heart rate data",
        "emergency_contacts": "Consent to notify emergency contacts",
        "cloud_sync": "Consent to sync data to cloud",
        "analytics": "Consent to anonymous analytics"
    ]

    private init() {}

    /// Checks if user has given consent for a specific feature
    func hasConsent(for feature: String) -> Bool {
        userDefaults.bool(forKey: "consent_\(feature)")
    }

    /// Records user consent
    func setConsent(for feature: String, granted: Bool) {
        userDefaults.set(granted, forKey: "consent_\(feature)")
        userDefaults.set(Date(), forKey: "consent_date_\(feature)")

        // Log consent audit trail
        logConsentChange(feature: feature, granted: granted)
    }

    /// Gets all consent statuses
    func getAllConsents() -> [String: Bool] {
        var consents: [String: Bool] = [:]
        for (key, _) in consentKeys {
            consents[key] = hasConsent(for: key)
        }
        return consents
    }

    /// Checks if essential consents are granted
    func hasEssentialConsents() -> Bool {
        hasConsent(for: "health_data_collection") && hasConsent(for: "emergency_contacts")
    }

    /// Records consent change for audit
    private func logConsentChange(feature: String, granted: Bool) {
        let logEntry = [
            "feature": feature,
            "granted": granted,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ] as [String : Any]

        // Store in secure audit log
        var auditLog = userDefaults.array(forKey: "consent_audit_log") as? [[String: Any]] ?? []
        auditLog.append(logEntry)

        // Keep only last 100 entries
        if auditLog.count > 100 {
            auditLog = Array(auditLog.suffix(100))
        }

        userDefaults.set(auditLog, forKey: "consent_audit_log")
    }

    /// Exports consent audit log
    func exportAuditLog() -> Data? {
        let auditLog = userDefaults.array(forKey: "consent_audit_log") as? [[String: Any]] ?? []
        return try? JSONSerialization.data(withJSONObject: auditLog, options: .prettyPrinted)
    }

    /// Clears all data (for GDPR compliance)
    func clearAllData() {
        // Clear consents
        for (key, _) in consentKeys {
            userDefaults.removeObject(forKey: "consent_\(key)")
            userDefaults.removeObject(forKey: "consent_date_\(key)")
        }

        // Clear audit log
        userDefaults.removeObject(forKey: "consent_audit_log")

        // Clear keychain
        KeychainManager().delete(key: "medical_data_key")
        KeychainManager().delete(key: "anonymous_user_id")
        KeychainManager().delete(key: "user_id_salt")
        KeychainManager().delete(key: "firebase_config")

        // Clear health data
        userDefaults.removeObject(forKey: "EmergencyContacts")

        print("✅ All user data has been cleared")
    }
}