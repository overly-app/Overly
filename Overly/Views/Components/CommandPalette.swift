//
//  CommandPalette.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import AppKit

struct CommandPalette: View {
    @Binding var isVisible: Bool
    @State private var command: String = ""
    @FocusState private var isInputFocused: Bool
    let onNavigate: (URL) -> Void // Closure to handle navigation in the WebView
    
    var body: some View {
        if isVisible {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideCommandPalette()
                    }
                
                // Command input box
                VStack(spacing: 0) {
                    HStack {
                        Text(">")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, design: .monospaced))
                        
                        TextField("Type a command...", text: $command)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, design: .monospaced))
                            .focused($isInputFocused)
                            .onSubmit {
                                executeCommand(command)
                            }
                            .onChange(of: command) { _, newValue in
                                // Auto-add "/" if user starts typing without it and it's not empty
                                if !newValue.isEmpty && !newValue.hasPrefix("/") {
                                    command = "/" + newValue
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .cornerRadius(8)
                    
                    // Command hints
                    if command.isEmpty || command.hasPrefix("/") {
                        VStack(alignment: .leading, spacing: 4) {
                            CommandHint(
                                command: "/t3",
                                description: "Open T3 chat with query",
                                isHighlighted: command.hasPrefix("/t3") || command.isEmpty
                            )
                            CommandHint(
                                command: "/chat",
                                description: "Open ChatGPT with query",
                                isHighlighted: command.hasPrefix("/chat")
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: 400)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            }
            .onAppear {
                isInputFocused = true
                // Pre-fill with "/" when opening
                if command.isEmpty {
                    command = "/"
                }
            }
            .onKeyPress(.escape) {
                hideCommandPalette()
                return .handled
            }
        }
    }
    
    private func hideCommandPalette() {
        isVisible = false
        command = ""
        isInputFocused = false
    }
    
    private func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.hasPrefix("/t3 ") {
            let query = String(trimmedCommand.dropFirst(4)) // Remove "/t3 "
            if !query.isEmpty {
                navigateToT3(with: query)
            }
        } else if trimmedCommand == "/t3" {
            // Open T3 without a query
            navigateToT3(with: "")
        } else if trimmedCommand.hasPrefix("/chat ") {
            let query = String(trimmedCommand.dropFirst(6)) // Remove "/chat "
            if !query.isEmpty {
                navigateToChatGPT(with: query)
            }
        } else if trimmedCommand == "/chat" {
            // Open ChatGPT without a query
            navigateToChatGPT(with: "")
        }
        
        hideCommandPalette()
    }
    
    private func navigateToT3(with query: String) {
        var urlString = "https://www.t3.chat/new"
        
        if !query.isEmpty {
            // URL encode the query
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?q=\(encodedQuery)"
            }
        }
        
        if let url = URL(string: urlString) {
            onNavigate(url)
        }
    }
    
    private func navigateToChatGPT(with query: String) {
        var urlString = "https://chat.openai.com/"
        
        if !query.isEmpty {
            // URL encode the query - ChatGPT uses q parameter
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?q=\(encodedQuery)"
            }
        }
        
        if let url = URL(string: urlString) {
            onNavigate(url)
        }
    }
}

struct CommandHint: View {
    let command: String
    let description: String
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isHighlighted ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isHighlighted ? Color.accentColor.opacity(0.3) : Color.clear)
                .cornerRadius(4)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(isHighlighted ? .primary : .secondary)
            
            Spacer()
        }
    }
}

#Preview {
    CommandPalette(isVisible: .constant(true), onNavigate: { _ in })
        .frame(width: 500, height: 300)
} 