import SwiftUI

struct PromptSuggestionView: View {
    @Binding var isVisible: Bool
    let onPromptSelected: (String) -> Void
    
    private let categories = [
        (icon: "sparkles", title: "Create", color: Color.blue),
        (icon: "doc.text", title: "Explore", color: Color.green),
        (icon: "chevron.left.forwardslash.chevron.right", title: "Code", color: Color.orange),
        (icon: "graduationcap", title: "Learn", color: Color.purple)
    ]
    
    private let suggestedPrompts = [
        "How does AI work?",
        "Are black holes real?",
        "How many Rs are in the word \"strawberry\"?",
        "What is the meaning of life?",
        "Explain quantum computing in simple terms",
        "Write a short story about a robot learning to paint",
        "What are the best practices for learning a new language?",
        "Help me plan a healthy meal for this week"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("How can I help you today?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
            
            // Category buttons
            HStack(spacing: 16) {
                ForEach(categories, id: \.title) { category in
                    Button(action: {
                        // Generate a relevant prompt based on the category
                        let categoryPrompts = [
                            "Create": "Write a creative story about...",
                            "Explore": "Research and explain...",
                            "Code": "Help me write code for...",
                            "Learn": "Teach me about..."
                        ]
                        
                        if let prompt = categoryPrompts[category.title] {
                            onPromptSelected(prompt)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isVisible = false
                            }
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 24))
                                .foregroundColor(category.color)
                            
                            Text(category.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(category.color.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isVisible ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 0.2), value: isVisible)
                }
            }
            .padding(.bottom, 32)
            
            // Suggested prompts
            VStack(spacing: 0) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button(action: {
                        onPromptSelected(prompt)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isVisible = false
                        }
                    }) {
                        HStack {
                            Text(prompt)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if prompt != suggestedPrompts.last {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(8)
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    PromptSuggestionView(isVisible: .constant(true), onPromptSelected: { _ in })
        .frame(width: 400, height: 500)
        .background(Color.black)
}
