import SwiftUI
import HotKey
import AppKit // Import AppKit for NSEvent.ModifierFlags

// This view will be part of the onboarding flow to set the global hotkey.
struct HotkeyOnboardingView: View {
    @ObservedObject var settings = AppSettings.shared
    var onCompletion: () -> Void // Add completion closure
    @State private var isRecordingHotkey = false // State to control recording

    var body: some View {
        VStack(spacing: 20) {
            Text("Set Your Global Hotkey")
                .font(.largeTitle)
                .padding(.bottom)

            Text("Press the button below and then press a key combination to set the hotkey for opening and closing Overly.") // Updated instructions
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            KeybindRecorderView(
                key: $settings.toggleHotkeyKey,
                modifiers: $settings.toggleHotkeyModifiers,
                isRecording: $isRecordingHotkey, // Pass the binding
                showLabel: false // Hide the internal label
            )
            // Removed the fixed frame, now controlled by parent OnboardingView
            .padding()

            // Add the "Record New Hotkey" button
            Button(action: {
                // Start recording when the button is pressed
                isRecordingHotkey = true
            }) {
                Text(isRecordingHotkey ? "Recording..." : "Record New Hotkey")
            }
            .buttonStyle(.borderedProminent) // Use a prominent button style
            .tint(.red) // Match Raycast's red button color

            Spacer()

            // Add a Continue button
            Button(action: {
                onCompletion()
            }) {
                HStack(spacing: 8) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(OnboardingButtonStyle()) // Use the same button style as other onboarding views
            // Disable if default hotkey (Cmd+J) is still set and no other key is recorded yet
            .disabled(settings.toggleHotkeyKey == .j && settings.toggleHotkeyModifiers == [.command])

        }
        .padding()
    }
}

// The KeybindRecorderView struct and its helper methods are defined in KeybindRecorderView.swift

#Preview {
    HotkeyOnboardingView(onCompletion: {})
} 