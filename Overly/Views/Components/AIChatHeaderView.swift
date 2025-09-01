//
//  AIChatHeaderView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct AIChatHeaderView: View {
    @ObservedObject var providerManager: AIProviderManager
    @Binding var showModelPicker: Bool
    let onNewChat: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("AI Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // New chat button
                Button(action: onNewChat) {
                    Image(systemName: "plus.message")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Start new chat")
            }
            
            // Model picker
            HStack {
                Button(action: {
                    showModelPicker.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(providerManager.selectedModel.isEmpty ? "Select Model" : providerManager.selectedModel.replacingOccurrences(of: ":latest", with: ""))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showModelPicker) {
                    ModelPickerView()
                }
                
                Spacer()
                
                if providerManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onAppear {
            Task {
                await providerManager.refreshAllModels()
            }
        }
    }
}

#Preview {
    AIChatHeaderView(
        providerManager: AIProviderManager.shared,
        showModelPicker: .constant(false),
        onNewChat: {}
    )
    .frame(width: 800, height: 100)
}
