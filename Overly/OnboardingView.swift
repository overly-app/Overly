import SwiftUI

// Define the steps in the onboarding flow
enum OnboardingStep {
    case welcome
    case setHotkey
    case selectProviders
}

// Custom button style to ensure proper color handling
struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white : Color.black)
            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
            .cornerRadius(8)
    }
}

struct OnboardingView: View {
    // Use AppStorage to manage the onboarding state
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // State variable to control the current onboarding step
    @State private var onboardingStep: OnboardingStep = .welcome

    var body: some View {
        ZStack { // Use ZStack to layer the views
            // Welcome Screen
            if onboardingStep == .welcome {
                VStack {
                    Spacer()

                    // Welcome Text
                    Text("Welcome to Overly")
                        .font(.largeTitle)
                        .padding()

                    // App Icon (Using the new asset name 'AppIconOnboarding')
                    Image("AppIconOnboarding")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding()

                    Spacer()

                    // Continue Button
                    Button(action: {
                        // Transition to the hotkey setup step
                        withAnimation { // Animate the state change
                            onboardingStep = .setHotkey
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(OnboardingButtonStyle())

                    Spacer()
                }
                .padding()
                .frame(width: 800, height: 500)
                .transition(.opacity) // Fade out the welcome screen
            }

            // Hotkey Setup Screen
            if onboardingStep == .setHotkey {
                HotkeyOnboardingView(onCompletion: {
                    withAnimation { // Animate the state change
                        onboardingStep = .selectProviders
                    }
                })
                .frame(width: 800, height: 500)
                .transition(.move(edge: .leading).combined(with: .opacity)) // Slide and fade in from leading edge
            }

            // Service Selection Screen
            if onboardingStep == .selectProviders {
                ServiceSelectionView(onCompletion: {
                    withAnimation { // Animate the state change
                        hasCompletedOnboarding = true // Mark onboarding complete
                    }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity)) // Slide and fade in from trailing edge
            }
        }
    }
}

#Preview {
    OnboardingView()
} 