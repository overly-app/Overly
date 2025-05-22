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

    var body: some View {
        VStack {
            Spacer()

            // Welcome Text
            Text("Welcome to Overly")
                .font(.largeTitle)
                .padding()

            // App Icon (Using the new asset name 'AppIconOnboarding')
            // The scaling will be handled by aspectRatio and frame
            Image("AppIconOnboarding")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding()

            Spacer()

            // Debug text to verify view hierarchy

            // Continue Button
            Button(action: {
                hasCompletedOnboarding = true
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
    }
}

#Preview {
    OnboardingView()
} 