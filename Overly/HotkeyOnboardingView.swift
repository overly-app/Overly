import SwiftUI
import HotKey
import AppKit // Import AppKit for NSEvent.ModifierFlags

// This view will be part of the onboarding flow to set the global hotkey.
struct HotkeyOnboardingView: View {
    @ObservedObject var settings = AppSettings.shared
    var onCompletion: () -> Void // Add completion closure
    @State private var isRecordingHotkey = false // State to control recording
    
    // Real-time key monitoring states
    @State private var currentlyPressedModifiers: NSEvent.ModifierFlags = []
    @State private var currentlyPressedKey: Key? = nil
    @State private var keyMonitor: Any? = nil
    @State private var flagsMonitor: Any? = nil
    @State private var localKeyMonitor: Any? = nil
    @State private var localFlagsMonitor: Any? = nil
    @State private var keyUpMonitor: Any? = nil
    @State private var localKeyUpMonitor: Any? = nil

    var body: some View {
        VStack(spacing: 40) {
            // Header section with larger spacing
            VStack(spacing: 16) {
                // Setup badge
                HStack {
                    Text("Setup")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                
                // Main title
                VStack(spacing: 8) {
                    Text("Set Up your Hotkey")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Subtitle
                Text("Get started with Overly by setting a hotkey to toggle the window.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Hotkey recorder section - made much more prominent
            VStack(spacing: 24) {
                // Large hotkey display
                HStack(spacing: 12) {
                    // Show current modifiers (either currently pressed or saved)
                    let displayModifiers = (isRecordingHotkey && !currentlyPressedModifiers.isEmpty) ? currentlyPressedModifiers : settings.toggleHotkeyModifiers
                    let displayKey = (isRecordingHotkey && currentlyPressedKey != nil) ? currentlyPressedKey! : settings.toggleHotkeyKey
                    
                    ForEach(modifierFlagsArray(from: displayModifiers), id: \.rawValue) { modifier in
                        Text(modifierSymbol(for: modifier))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if modifier.rawValue != modifierFlagsArray(from: displayModifiers).last?.rawValue {
                            Text("+")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !displayModifiers.isEmpty {
                        Text("+")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Show current key (either currently pressed or saved)
                    Text(keyDisplayName(for: displayKey))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(minWidth: 80)
                        .frame(height: 60)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Record button
                Button(action: {
                    isRecordingHotkey = true
                    // Disable global hotkey when starting to record
                    disableGlobalHotkey()
                }) {
                    Text(isRecordingHotkey ? "Recording..." : "Record New Hotkey")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Hidden recorder view for actual functionality
            KeybindRecorderView(
                key: $settings.toggleHotkeyKey,
                modifiers: $settings.toggleHotkeyModifiers,
                isRecording: $isRecordingHotkey,
                showLabel: false
            )
            .frame(width: 0, height: 0)
            .opacity(0)
            .onChange(of: isRecordingHotkey) { _, newValue in
                if !newValue {
                    // Don't re-enable global hotkey here - keep it disabled during entire onboarding
                    // It will be re-enabled in onDisappear when leaving the onboarding view
                }
            }
            
            // Continue button at bottom
            HStack {
                Spacer()
                Button(action: {
                    onCompletion()
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("HotkeyOnboardingView: onAppear called")
            setupKeyMonitoring()
            disableGlobalHotkey()
        }
        .onDisappear {
            print("HotkeyOnboardingView: onDisappear called")
            cleanupKeyMonitoring()
            enableGlobalHotkey()
        }
    }
    
    // MARK: - Key Monitoring Methods
    
    private func setupKeyMonitoring() {
        // Monitor modifier flags changes
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            DispatchQueue.main.async {
                let newModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                self.currentlyPressedModifiers = newModifiers
            }
        }
        
        // Monitor key down events
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            DispatchQueue.main.async {
                if let key = Key(carbonKeyCode: UInt32(event.keyCode)) {
                    self.currentlyPressedKey = key
                }
            }
        }
        
        // Monitor key up events to clear the currently pressed key
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { event in
            DispatchQueue.main.async {
                self.currentlyPressedKey = nil
            }
        }
        
        // Also add local monitors for when the app is in focus
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            DispatchQueue.main.async {
                let newModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                self.currentlyPressedModifiers = newModifiers
            }
            return event
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            DispatchQueue.main.async {
                if let key = Key(carbonKeyCode: UInt32(event.keyCode)) {
                    self.currentlyPressedKey = key
                }
            }
            return event
        }
        
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            DispatchQueue.main.async {
                self.currentlyPressedKey = nil
            }
            return event
        }
    }
    
    private func cleanupKeyMonitoring() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
        
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyUpMonitor = nil
        }
        
        // Reset the state
        currentlyPressedModifiers = []
        currentlyPressedKey = nil
    }
    
    private func disableGlobalHotkey() {
        print("HotkeyOnboardingView: Attempting to disable global hotkey...")
        WindowManager.shared.disableGlobalHotkey()
        print("HotkeyOnboardingView: Called disableGlobalHotkey on WindowManager")
    }
    
    private func enableGlobalHotkey() {
        print("HotkeyOnboardingView: Attempting to enable global hotkey...")
        WindowManager.shared.enableGlobalHotkey()
        print("HotkeyOnboardingView: Called enableGlobalHotkey on WindowManager")
    }
    
    // MARK: - Helper Methods
    
    // Helper function to convert modifier flags to array
    private func modifierFlagsArray(from flags: NSEvent.ModifierFlags) -> [NSEvent.ModifierFlags] {
        var result: [NSEvent.ModifierFlags] = []
        
        if flags.contains(.command) {
            result.append(.command)
        }
        if flags.contains(.option) {
            result.append(.option)
        }
        if flags.contains(.control) {
            result.append(.control)
        }
        if flags.contains(.shift) {
            result.append(.shift)
        }
        
        return result
    }
    
    // Helper function to get modifier symbol
    private func modifierSymbol(for modifier: NSEvent.ModifierFlags) -> String {
        switch modifier {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        case .shift:
            return "⇧"
        default:
            return ""
        }
    }
    
    // Helper function to get key display name
    private func keyDisplayName(for key: Key) -> String {
        switch key {
        case .space:
            return "space"
        case .return:
            return "return"
        case .tab:
            return "tab"
        case .escape:
            return "esc"
        case .delete:
            return "delete"
        case .upArrow:
            return "↑"
        case .downArrow:
            return "↓"
        case .leftArrow:
            return "←"
        case .rightArrow:
            return "→"
        default:
            // For letter keys, convert to uppercase
            return String(describing: key).uppercased()
        }
    }
}

// The KeybindRecorderView struct and its helper methods are defined in KeybindRecorderView.swift

#Preview {
    HotkeyOnboardingView(onCompletion: {})
} 