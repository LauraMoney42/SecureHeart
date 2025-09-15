//
//  ConfigurationManager.swift
//  SecureHeart
//
//  Secure configuration management for sensitive data
//

import Foundation
import CryptoKit
import UIKit

// MARK: - Configuration Manager
class ConfigurationManager {
    static let shared = ConfigurationManager()

    private let keychain = KeychainManager()
    private let configFileName = "GoogleService-Info"

    private init() {}

    // MARK: - Firebase Configuration

    /// Loads Firebase configuration from secure sources
    /// Priority: 1. Keychain, 2. Local file (for development), 3. Bundle
    func loadFirebaseConfig() -> [String: Any]? {
        // First, try to load from Keychain (most secure)
        if let secureConfig = loadFromKeychain() {
            return secureConfig
        }

        // Second, try to load from local file (development)
        if let localConfig = loadFromLocalFile() {
            // Store in keychain for future use
            saveToKeychain(localConfig)
            return localConfig
        }

        // Last resort: bundle (should only contain template)
        return loadFromBundle()
    }

    /// Validates that configuration contains required keys
    func validateConfiguration(_ config: [String: Any]) -> Bool {
        let requiredKeys = [
            "API_KEY",
            "GCM_SENDER_ID",
            "BUNDLE_ID",
            "PROJECT_ID",
            "STORAGE_BUCKET",
            "GOOGLE_APP_ID",
            "CLIENT_ID"
        ]

        for key in requiredKeys {
            guard let value = config[key] as? String,
                  !value.isEmpty,
                  !value.contains("YOUR_") && !value.contains("EXAMPLE") else {
                print("⚠️ Invalid or missing configuration for key: \(key)")
                return false
            }
        }

        return true
    }

    // MARK: - Private Methods

    private func loadFromKeychain() -> [String: Any]? {
        guard let data = keychain.retrieve(key: "firebase_config"),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return config
    }

    private func saveToKeychain(_ config: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: config) else {
            return
        }
        keychain.store(key: "firebase_config", data: data)
    }

    private func loadFromLocalFile() -> [String: Any]? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first
        guard let url = documentsPath?.appendingPathComponent("\(configFileName).plist"),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                      format: nil) as? [String: Any] else {
            return nil
        }

        return plist
    }

    private func loadFromBundle() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: configFileName, ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return plist
    }
}

// MARK: - Keychain Manager
class KeychainManager {

    func store(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain store failed: \(status)")
        }
    }

    func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Secure User ID Generator
extension ConfigurationManager {

    /// Generates a cryptographically secure anonymous user ID
    /// Uses SHA256 hash of device ID + salt for privacy
    func generateSecureUserID() -> String {
        // Get or create a persistent salt
        let saltKey = "user_id_salt"
        var salt: Data

        if let existingSalt = keychain.retrieve(key: saltKey) {
            salt = existingSalt
        } else {
            // Generate new salt
            salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            keychain.store(key: saltKey, data: salt)
        }

        // Get device identifier (fallback to random if unavailable)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        // Combine device ID with salt
        var combinedData = Data(deviceID.utf8)
        combinedData.append(salt)

        // Create SHA256 hash
        let hashed = SHA256.hash(data: combinedData)

        // Convert to hex string
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Gets or creates a persistent anonymous user ID
    func getAnonymousUserID() -> String {
        let userIDKey = "anonymous_user_id"

        // Check if we already have a stored ID
        if let storedData = keychain.retrieve(key: userIDKey),
           let storedID = String(data: storedData, encoding: .utf8) {
            return storedID
        }

        // Generate new anonymous ID
        let newID = generateSecureUserID()
        if let data = newID.data(using: .utf8) {
            keychain.store(key: userIDKey, data: data)
        }

        return newID
    }
}