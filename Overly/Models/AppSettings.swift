import SwiftUI
import Foundation
import HotKey
import AppKit

struct ChatProvider: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    let url: URL?
    let iconName: String
    let isSystemImage: Bool
}

// Extension to convert AIService to ChatProvider
extension AIService {
    var asChatProvider: ChatProvider {
        // Check if the iconName corresponds to a known SF Symbol (like "link" or "gearshape")
        let isSFsymbol = iconName == "link" || iconName == "gearshape"
        
        return ChatProvider(
            id: self.rawValue,
            name: self.rawValue,
            url: self.url,
            iconName: self.iconName,
            isSystemImage: isSFsymbol // Set isSystemImage based on if the iconName is an SF Symbol
        )
    }
}

@MainActor
class AppSettings: ObservableObject, @unchecked Sendable {
    static let shared = AppSettings()
    
    private let userDefaults = UserDefaults.standard
    private let providersKey = "customProviders"
    private let activeProvidersKey = "activeProviderIds"
    private let faviconCacheKey = "faviconCache"
    private let toggleHotkeyKeyKey = "toggleHotkeyKey"
    private let toggleHotkeyModifiersKey = "toggleHotkeyModifiers"
    private let showInDockKey = "showInDock"
    private let windowFrameKey = "windowFrame"
    private let defaultProviderIdKey = "defaultProviderId"
    private let sidebarWidthKey = "sidebarWidth"

    @Published var customProviders: [ChatProvider] = []
    @Published var activeProviderIds: Set<String> = Set()
    @Published var faviconCache: [String: Data] = [:]
    @Published var showInDock: Bool = true
    @Published var toggleHotkeyKey: Key = .j
    @Published var toggleHotkeyModifiers: NSEvent.ModifierFlags = [.command]
    @Published var windowFrame: NSRect = NSRect(x: 0, y: 0, width: 500, height: 600)
    @Published var defaultProviderId: String?
    @Published var sidebarWidth: CGFloat = 300
    
    // Computed property to get all providers (built-in + custom)
    var allBuiltInProviders: [ChatProvider] {
        AIService.allCases.map { $0.asChatProvider }
    }
    
    var activeProviders: [ChatProvider] {
        // Combine built-in and custom providers and filter by activeProviderIds
        (allBuiltInProviders + customProviders).filter { activeProviderIds.contains($0.id) }
    }
    
    // Computed property to get the default provider
    var defaultProvider: ChatProvider? {
        if let defaultProviderId = defaultProviderId {
            return activeProviders.first { $0.id == defaultProviderId }
        }
        return nil
    }
    
    // Method to get the provider to use on startup (default or first active)
    var startupProvider: ChatProvider? {
        if let defaultProvider = defaultProvider {
            return defaultProvider
        }
        return activeProviders.first { $0.url != nil }
    }

    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load custom providers
        if let savedProvidersData = userDefaults.data(forKey: providersKey),
           let decodedProviders = try? JSONDecoder().decode([ChatProvider].self, from: savedProvidersData) {
            customProviders = decodedProviders
        }
        
        // Load active provider IDs
        if let savedActiveIdsData = userDefaults.data(forKey: activeProvidersKey),
           let decodedActiveIds = try? JSONDecoder().decode(Set<String>.self, from: savedActiveIdsData) {
            activeProviderIds = decodedActiveIds
        } else {
            // If no active IDs saved, default to all built-in ones except settings
            activeProviderIds = Set(allBuiltInProviders.filter { $0.url != nil }.map { $0.id })
        }
        
        // Load favicon cache
        if let savedFaviconData = userDefaults.data(forKey: faviconCacheKey),
           let decodedFaviconCache = try? JSONDecoder().decode([String: Data].self, from: savedFaviconData) {
            faviconCache = decodedFaviconCache
        }
        
        // Load showInDock setting
        showInDock = userDefaults.object(forKey: showInDockKey) as? Bool ?? true
        
        // Load window frame
        if let frameData = userDefaults.data(forKey: windowFrameKey) {
            do {
                let decodedFrame = try JSONDecoder().decode(WindowFrameData.self, from: frameData)
                windowFrame = NSRect(x: decodedFrame.x, y: decodedFrame.y, width: decodedFrame.width, height: decodedFrame.height)
            } catch {
                // If decoding fails, use default frame
                windowFrame = NSRect(x: 0, y: 0, width: 500, height: 600)
            }
        }
        
        // Load toggle hotkey settings
        if let keyRawValue = userDefaults.object(forKey: toggleHotkeyKeyKey) as? UInt16 {
            if let key = Key(carbonKeyCode: UInt32(keyRawValue)) {
                toggleHotkeyKey = key
            }
        }
        
        if let modifiersRawValue = userDefaults.object(forKey: toggleHotkeyModifiersKey) as? UInt {
            toggleHotkeyModifiers = NSEvent.ModifierFlags(rawValue: modifiersRawValue)
        }
        
        // Load default provider ID
        defaultProviderId = userDefaults.string(forKey: defaultProviderIdKey)
        
        // Load sidebar width
        let defaultSidebarWidth = (NSScreen.main?.frame.width ?? 900) / 3
        sidebarWidth = userDefaults.object(forKey: sidebarWidthKey) as? CGFloat ?? defaultSidebarWidth
    }
    
    func saveSettings() {
        // Save custom providers
        if let encodedProviders = try? JSONEncoder().encode(customProviders) {
            userDefaults.set(encodedProviders, forKey: providersKey)
        }
        
        // Save active provider IDs
        if let encodedActiveIds = try? JSONEncoder().encode(activeProviderIds) {
            userDefaults.set(encodedActiveIds, forKey: activeProvidersKey)
        }
        
        // Save favicon cache
        if let encodedFaviconCache = try? JSONEncoder().encode(faviconCache) {
             userDefaults.set(encodedFaviconCache, forKey: faviconCacheKey)
        }
        
        // Save showInDock setting
        userDefaults.set(showInDock, forKey: showInDockKey)
        
        // Save window frame
        let frameData = WindowFrameData(x: windowFrame.origin.x, y: windowFrame.origin.y, width: windowFrame.size.width, height: windowFrame.size.height)
        if let encodedFrame = try? JSONEncoder().encode(frameData) {
            userDefaults.set(encodedFrame, forKey: windowFrameKey)
        }
        
        // Save toggle hotkey settings
        userDefaults.set(UInt16(toggleHotkeyKey.carbonKeyCode), forKey: toggleHotkeyKeyKey)
        userDefaults.set(toggleHotkeyModifiers.rawValue, forKey: toggleHotkeyModifiersKey)
        
        // Save default provider ID
        if let defaultProviderId = defaultProviderId {
            userDefaults.set(defaultProviderId, forKey: defaultProviderIdKey)
        } else {
            userDefaults.removeObject(forKey: defaultProviderIdKey)
        }
        
        // Save sidebar width
        userDefaults.set(sidebarWidth, forKey: sidebarWidthKey)
        
        // Force synchronization to disk
        userDefaults.synchronize()
    }
    
    // Method to update the toggle hotkey
    func updateToggleHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        toggleHotkeyKey = key
        toggleHotkeyModifiers = modifiers
        saveSettings()
        
        // Notify that hotkey settings changed
        NotificationCenter.default.post(name: NSNotification.Name("HotkeySettingsChanged"), object: nil)
    }
    
    // Method to add a new custom provider
    func addCustomProvider(_ provider: ChatProvider) {
        customProviders.append(provider)
        activeProviderIds.insert(provider.id)
        saveSettings()
    }
    
    // Method to remove a custom provider
    func removeCustomProvider(id: String) {
        customProviders.removeAll(where: { $0.id == id })
        activeProviderIds.remove(id)
        faviconCache.removeValue(forKey: id)
        // If this was the default provider, clear the default
        if defaultProviderId == id {
            defaultProviderId = nil
        }
        saveSettings()
    }
    
    // Method to toggle active state of a provider
    func toggleActiveProvider(id: String) {
        if activeProviderIds.contains(id) {
            activeProviderIds.remove(id)
            // If this was the default provider, clear the default
            if defaultProviderId == id {
                defaultProviderId = nil
            }
        } else {
            activeProviderIds.insert(id)
        }
        saveSettings()
    }
    
    // Method to set the default provider
    func setDefaultProvider(_ provider: ChatProvider?) {
        if let provider = provider, activeProviderIds.contains(provider.id) {
            defaultProviderId = provider.id
        } else {
            defaultProviderId = nil
        }
        saveSettings()
    }
    
    // Method to update the name of a custom provider
    func updateCustomProviderName(id: String, newName: String) {
        if let index = customProviders.firstIndex(where: { $0.id == id }) {
            customProviders[index].name = newName
            saveSettings()
        }
    }
    
    // Method to save a favicon image data for a provider
    func saveFavicon(id: String, data: Data) {
        faviconCache[id] = data
        saveSettings()
    }
    
    // Method to get a favicon Image from cache
    func faviconImage(for provider: ChatProvider) -> Image? {
        if let data = faviconCache[provider.id], let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        } else {
            return nil
        }
    }
    
    // Favicon fetching logic
    func fetchFavicon(for provider: ChatProvider) async {
        guard let url = provider.url else { return }

        // Clear existing favicon data if any
        DispatchQueue.main.async {
            self.faviconCache.removeValue(forKey: provider.id)
            self.saveSettings() // Save the change immediately
        }
        
        // Attempt to fetch /favicon.ico first
        let faviconICOURL = url.appendingPathComponent("favicon.ico")
        if let data = try? await URLSession.shared.data(from: faviconICOURL).0, !data.isEmpty {
            DispatchQueue.main.async {
                self.saveFavicon(id: provider.id, data: data)
            }
            return
        }
        
        // If favicon.ico not found or empty, fetch the main page to parse for link tags
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let htmlString = String(data: data, encoding: .utf8) {
                // Simple regex to find favicon links (handles common formats)
                let linkRegex = /<link\s+.*?rel=[\"'](?:icon|shortcut icon)[\"'].*?href=[\"'](.*?)["'].*?>/
                
                if let match = htmlString.firstMatch(of: linkRegex) {
                    let faviconPath = String(match.output.1)
                    if let faviconURL = URL(string: faviconPath, relativeTo: url)?.absoluteURL {
                        let (faviconData, _) = try await URLSession.shared.data(from: faviconURL)
                        DispatchQueue.main.async {
                            self.saveFavicon(id: provider.id, data: faviconData)
                        }
                    }
                } else {
                    print("No favicon link found in HTML for \(provider.name).")
                }
            }
        } catch {
            print("Error fetching or parsing HTML for \(provider.name): \(error)")
             // Optionally, set a placeholder or update UI to show failure
        }
    }
    
    // Method to update window frame
    func updateWindowFrame(_ frame: NSRect) {
        windowFrame = frame
        saveSettings()
    }
    
    // Method to update sidebar width
    func updateSidebarWidth(_ width: CGFloat) {
        sidebarWidth = width
        saveSettings()
    }
}

// Helper struct for encoding/decoding NSRect
private struct WindowFrameData: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
} 