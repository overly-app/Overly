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
    
    private init() {}
    
    private let service = "com.hypackel.overlyapp"
    
    enum APIProvider: String, CaseIterable {
        case openai = "openai"
        case anthropic = "anthropic"
        case gemini = "gemini"
        case ollama = "ollama"
        case customOpenAI = "custom_openai"
        
        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .anthropic: return "Anthropic"
            case .gemini: return "Google Gemini"
            case .ollama: return "Ollama"
            case .customOpenAI: return "Custom OpenAI"
            }
        }
        
        var defaultBaseURL: String {
            switch self {
            case .openai: return "https://api.openai.com/v1"
            case .anthropic: return "https://api.anthropic.com"
            case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
            case .ollama: return "http://localhost:11434"
            case .customOpenAI: return ""
            }
        }
    }
    
    // MARK: - API Key Management
    
    func saveAPIKey(_ key: String, for provider: APIProvider) -> Bool {
        let account = "\(provider.rawValue)_api_key"
        return saveToKeychain(key: key, account: account)
    }
    
    func getAPIKey(for provider: APIProvider) -> String? {
        let account = "\(provider.rawValue)_api_key"
        return getFromKeychain(account: account)
    }
    
    func deleteAPIKey(for provider: APIProvider) -> Bool {
        let account = "\(provider.rawValue)_api_key"
        return deleteFromKeychain(account: account)
    }
    
    // MARK: - Base URL Management
    
    func saveBaseURL(_ url: String, for provider: APIProvider) -> Bool {
        let account = "\(provider.rawValue)_base_url"
        return saveToKeychain(key: url, account: account)
    }
    
    func getBaseURL(for provider: APIProvider) -> String? {
        let account = "\(provider.rawValue)_base_url"
        return getFromKeychain(account: account) ?? provider.defaultBaseURL
    }
    
    func deleteBaseURL(for provider: APIProvider) -> Bool {
        let account = "\(provider.rawValue)_base_url"
        return deleteFromKeychain(account: account)
    }
    
    // MARK: - Private Keychain Operations
    
    private func saveToKeychain(key: String, account: String) -> Bool {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func deleteFromKeychain(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
} 