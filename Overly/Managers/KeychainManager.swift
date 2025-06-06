//
//  KeychainManager.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.overly.apikeys"
    
    private init() {}
    
    // MARK: - API Key Storage
    
    func storeAPIKey(_ key: String, for provider: ChatProviderType) -> Bool {
        let keyData = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("KeychainManager: Successfully stored API key for \(provider.rawValue)")
            return true
        } else {
            print("KeychainManager: Failed to store API key for \(provider.rawValue), status: \(status)")
            return false
        }
    }
    
    func retrieveAPIKey(for provider: ChatProviderType) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        } else {
            if status != errSecItemNotFound {
                print("KeychainManager: Failed to retrieve API key for \(provider.rawValue), status: \(status)")
            }
            return nil
        }
    }
    
    func deleteAPIKey(for provider: ChatProviderType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("KeychainManager: Successfully deleted API key for \(provider.rawValue)")
            return true
        } else {
            print("KeychainManager: Failed to delete API key for \(provider.rawValue), status: \(status)")
            return false
        }
    }
    
    func hasAPIKey(for provider: ChatProviderType) -> Bool {
        return retrieveAPIKey(for: provider) != nil
    }
    
    // MARK: - Validation
    
    func validateAPIKey(_ key: String, for provider: ChatProviderType) async -> Bool {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Basic format validation
        switch provider {
        case .openai:
            return key.hasPrefix("sk-") && key.count > 20
        case .gemini:
            return key.count > 20 // Gemini keys are typically longer
        case .groq:
            return key.hasPrefix("gsk_") && key.count > 20
        }
    }
    
    // MARK: - Utility
    
    func getAllStoredProviders() -> [ChatProviderType] {
        return ChatProviderType.allCases.filter { hasAPIKey(for: $0) }
    }
    
    func clearAllAPIKeys() {
        for provider in ChatProviderType.allCases {
            _ = deleteAPIKey(for: provider)
        }
    }
} 