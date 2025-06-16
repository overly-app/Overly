//
//  HotkeyManager.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit
import HotKey

class HotkeyManager: ObservableObject {
    private var toggleHotKey: HotKey?
    private var reloadHotKey: HotKey?
    private var nextServiceHotKey: HotKey?
    private var settingsHotKey: HotKey?
    private var commandPaletteHotKey: HotKey?
    private var toggleSidebarHotKey: HotKey?
    private var isHotkeyDisabled = false
    
    // Closures for actions
    var toggleWindowAction: (() -> Void)?
    var reloadWebViewAction: (() -> Void)?
    var switchToNextServiceAction: (() -> Void)?
    var hideWindowAction: (() -> Void)?
    var showCommandPaletteAction: (() -> Void)?
    var toggleSidebarAction: (() -> Void)?
    
    init() {
        setupInitialHotkeys()
        setupNotificationObservers()
    }
    
    private func setupInitialHotkeys() {
        Task { @MainActor in
            setupToggleHotkey()
        }
        
        // Create a global hotkey for Cmd + , (settings shortcut)
        settingsHotKey = HotKey(key: .comma, modifiers: [.command])
        settingsHotKey?.keyDownHandler = { [weak self] in
            self?.hideWindowAction?()
        }
        
        // Create a global hotkey for Option + Space (command palette)
        commandPaletteHotKey = HotKey(key: .space, modifiers: [.option])
        commandPaletteHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.showCommandPaletteAction?()
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: NSNotification.Name("HotkeySettingsChanged"),
            object: nil
        )
    }
    
    @MainActor
    private func setupToggleHotkey() {
        print("HotkeyManager: setupToggleHotkey called")
        let settings = AppSettings.shared
        
        // Convert NSEvent.ModifierFlags to HotKey modifiers
        var hotkeyModifiers: NSEvent.ModifierFlags = []
        if settings.toggleHotkeyModifiers.contains(.command) {
            hotkeyModifiers.insert(.command)
        }
        if settings.toggleHotkeyModifiers.contains(.option) {
            hotkeyModifiers.insert(.option)
        }
        if settings.toggleHotkeyModifiers.contains(.control) {
            hotkeyModifiers.insert(.control)
        }
        if settings.toggleHotkeyModifiers.contains(.shift) {
            hotkeyModifiers.insert(.shift)
        }
        
        // Create the hotkey
        print("HotkeyManager: Creating hotkey with key: \(settings.toggleHotkeyKey) and modifiers: \(hotkeyModifiers)")
        toggleHotKey = HotKey(key: settings.toggleHotkeyKey, modifiers: hotkeyModifiers)
        toggleHotKey?.keyDownHandler = { [weak self] in
            self?.toggleWindowAction?()
        }
        print("HotkeyManager: Hotkey created and handler set")
    }
    
    @MainActor
    @objc private func hotkeySettingsChanged() {
        if !isHotkeyDisabled {
            setupToggleHotkey()
        }
    }
    
    func disableGlobalHotkey() {
        print("HotkeyManager: disableGlobalHotkey called")
        isHotkeyDisabled = true
        if toggleHotKey != nil {
            print("HotkeyManager: HotKey exists, setting to nil")
            toggleHotKey = nil
            print("HotkeyManager: HotKey set to nil")
        } else {
            print("HotkeyManager: HotKey was already nil")
        }
    }
    
    @MainActor
    func enableGlobalHotkey() {
        print("HotkeyManager: enableGlobalHotkey called")
        isHotkeyDisabled = false
        setupToggleHotkey()
        print("HotkeyManager: setupToggleHotkey completed")
    }
    
    func enableContextHotkeys() {
        // Create the global hotkey for Cmd + R
        reloadHotKey = HotKey(key: .r, modifiers: [.command])
        reloadHotKey?.keyDownHandler = { [weak self] in
            self?.reloadWebViewAction?()
        }

        // Create the global hotkey for Cmd + /
        nextServiceHotKey = HotKey(key: .slash, modifiers: [.command])
        nextServiceHotKey?.keyDownHandler = { [weak self] in
            self?.switchToNextServiceAction?()
        }
        
        // Create the context hotkey for Cmd + E (toggle sidebar)
        toggleSidebarHotKey = HotKey(key: .e, modifiers: [.command])
        toggleSidebarHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.toggleSidebarAction?()
            }
        }
    }
    
    func disableContextHotkeys() {
        reloadHotKey = nil
        nextServiceHotKey = nil
        toggleSidebarHotKey = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 