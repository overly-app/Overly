import SwiftUI

struct OnboardingView: View {
    // Use AppStorage to manage the onboarding state
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    var body: some View {
        VStack {
            Spacer()

            // Welcome Text
            Text("Welcome to Overly")
                .font(.largeTitle)
                .padding()

            // App Icon (Using the new asset name 'AppIconOnboarding')
            // The scaling will be handled by aspectRatio and frame
            Image("AppIconOnboarding") // Changed from "AppIcon"
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200) // Adjust size as needed
                .padding()

            Spacer()

            // Continue Button
            Button("Continue") {
                // Mark onboarding as complete
                hasCompletedOnboarding = true
            }
            .padding()
            .buttonStyle(.borderedProminent) // Use a prominent style

            Spacer() // Add some space below the button
        }
        .padding() // Add padding around the content
        .frame(width: 700, height: 400) // Explicitly set the frame size
        // We can adjust the frame later in the App struct if needed for window size
    }
}

#Preview {
    OnboardingView()
} 