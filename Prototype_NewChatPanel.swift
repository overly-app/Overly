import SwiftUI

// Standalone prototype for the new chat page UI (not part of Xcode target)
// Safe to keep when reverting project files via git.

struct PrototypeNewChatPanel: View {
    @State private var inputText: String = ""
    @State private var showModelPicker: Bool = false
    
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.11).ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Greeting
                Text("How was your day, hypackel?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 48)
                
                // Single input box with in-field placeholder + controls
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minHeight: 120, maxHeight: 180)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        
                        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("How can I help you today?")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 26)
                                .padding(.top, 20)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        // Model selector (prototype)
                        Button(action: { showModelPicker.toggle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "brain")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                Text("Select Model")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showModelPicker) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Model Picker (Prototype)")
                                    .font(.headline)
                                Text("Place real model list here in-app")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(width: 360, height: 200)
                        }
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: 680)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    PrototypeNewChatPanel()
        .frame(width: 900, height: 700)
}
