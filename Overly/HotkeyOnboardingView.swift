import SwiftUI
import HotKey
import AppKit // Import AppKit for NSEvent.ModifierFlags

// This view will be part of the onboarding flow to set the global hotkey.
struct HotkeyOnboardingView: View {
    @ObservedObject var settings = AppSettings.shared
    var onCompletion: () -> Void // Add completion closure
    @State private var isRecordingHotkey = false // State to control recording

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
                    Text("Keep your")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                    Text("muscle memory")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Subtitle
                Text("We've made the transition to Overly as smooth as possible to set you up for success.")
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
                    // Show current modifiers
                    ForEach(modifierFlagsArray(from: settings.toggleHotkeyModifiers), id: \.rawValue) { modifier in
                        Text(modifierSymbol(for: modifier))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if modifier.rawValue != modifierFlagsArray(from: settings.toggleHotkeyModifiers).last?.rawValue {
                            Text("+")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !settings.toggleHotkeyModifiers.isEmpty {
                        Text("+")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Show current key
                    Text(keyDisplayName(for: settings.toggleHotkeyKey))
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
                .disabled(settings.toggleHotkeyKey == .j && settings.toggleHotkeyModifiers == [.command])
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
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