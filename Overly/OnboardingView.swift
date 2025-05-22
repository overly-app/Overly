import SwiftUI

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

    // State variable to control showing the service selection view
    @State private var showServiceSelection = false

    var body: some View {
        ZStack { // Use ZStack to layer the views
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
                    // Show the service selection view
                    withAnimation { // Animate the state change
                        showServiceSelection = true
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
            .frame(width: 700, height: 400)
            .opacity(showServiceSelection ? 0 : 1) // Fade out onboarding when showing service selection

            if showServiceSelection {
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