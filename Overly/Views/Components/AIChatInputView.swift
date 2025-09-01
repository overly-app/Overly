//
//  AIChatInputView.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

struct AIChatInputView: View {
    @Binding var inputText: String
    @Binding var isGenerating: Bool
    @ObservedObject var textSelectionManager: TextSelectionManager
    @FocusState private var isInputFocused: Bool
    let onSendMessage: () -> Void
    let onStopGeneration: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(spacing: 8) {
                    // Selected text attachment inside input box
                    if let attachment = textSelectionManager.selectedAttachment {
                        SelectedTextAttachmentView(attachment: attachment) {
                            textSelectionManager.clearSelection()
                        }
                    }
                    
                    HStack(spacing: 8) {
                        TextField("Ask a question...", text: $inputText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .focused($isInputFocused)
                            .onSubmit {
                                onSendMessage()
                            }
                        
                        Button(action: isGenerating ? onStopGeneration : onSendMessage) {
                            Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(isGenerating ? Color.red : (inputText.isEmpty ? Color.gray.opacity(0.4) : Color(red: 0.0, green: 0.48, blue: 0.4)))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isGenerating && inputText.isEmpty)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, textSelectionManager.selectedAttachment != nil ? 12 : 14)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
    }
}

#Preview {
    AIChatInputView(
        inputText: .constant(""),
        isGenerating: .constant(false),
        textSelectionManager: TextSelectionManager.shared,
        onSendMessage: {},
        onStopGeneration: {}
    )
    .frame(width: 800, height: 100)
}
