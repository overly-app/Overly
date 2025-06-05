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
    @State private var selectedIndex: Int = 0
    let onNavigate: (URL) -> Void // Closure to handle navigation in the WebView
    @ObservedObject var settings = AppSettings.shared
    
    // All available commands mapped to service IDs
    private let allCommands = [
        CommandInfo(command: "/t3", description: "Open T3 chat with query", placeholder: "Type your question...", serviceId: "T3 Chat"),
        CommandInfo(command: "/chat", description: "Open ChatGPT with query", placeholder: "Type your question...", serviceId: "ChatGPT"),
        CommandInfo(command: "/claude", description: "Open Claude with query", placeholder: "Type your question...", serviceId: "Claude"),
        CommandInfo(command: "/perplexity", description: "Open Perplexity with query", placeholder: "Type your question...", serviceId: "Perplexity"),
        CommandInfo(command: "/copilot", description: "Open Copilot with query", placeholder: "Type your question...", serviceId: "Copilot")
    ]
    
    // Available commands filtered by enabled services
    private var availableCommands: [CommandInfo] {
        return allCommands.filter { commandInfo in
            // Check if the service is enabled in settings
            return settings.activeProviderIds.contains(commandInfo.serviceId ?? "")
        }
    }
    
    // Computed properties for autocomplete
    private var filteredCommands: [CommandInfo] {
        if command.isEmpty || command == "/" {
            return availableCommands
        }
        
        // Check if user is typing a command
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCommand.contains(" ") {
            // Still typing command, filter by prefix
            return availableCommands.filter { cmd in
                cmd.command.lowercased().hasPrefix(trimmedCommand.lowercased())
            }
        }
        
        // User is typing query, show the active command
        let commandPart = String(trimmedCommand.split(separator: " ").first ?? "")
        return availableCommands.filter { cmd in
            cmd.command.lowercased() == commandPart.lowercased()
        }
    }
    
    private var currentQuery: String {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedCommand.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : ""
    }
    
    private var isTypingQuery: Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCommand.contains(" ") && !currentQuery.isEmpty
    }
    
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
                                // Reset selection when command changes
                                selectedIndex = 0
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    
                    // Command hints and autocomplete
                    if !filteredCommands.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.command) { index, commandInfo in
                                CommandHint(
                                    commandInfo: commandInfo,
                                    currentCommand: command,
                                    currentQuery: currentQuery,
                                    isTypingQuery: isTypingQuery,
                                    isHighlighted: shouldHighlight(commandInfo, index: index)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding(.top, 3)
                    }
                }
                .frame(maxWidth: 600) // Made wider
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            }
            .onAppear {
                isInputFocused = true
                selectedIndex = 0
                // Pre-fill with "/" when opening
                if command.isEmpty {
                    command = "/"
                }
            }
            .onKeyPress(.escape) {
                hideCommandPalette()
                return .handled
            }
            .onKeyPress(.tab) {
                handleTabCompletion()
                return .handled
            }
            .onKeyPress(.upArrow) {
                navigateUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                navigateDown()
                return .handled
            }
        }
    }
    
    private func shouldHighlight(_ commandInfo: CommandInfo, index: Int) -> Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.isEmpty || trimmedCommand == "/" {
            return index == selectedIndex
        }
        
        if !trimmedCommand.contains(" ") {
            // Still typing command, use selected index
            return index == selectedIndex && commandInfo.command.lowercased().hasPrefix(trimmedCommand.lowercased())
        }
        
        // Typing query
        let commandPart = String(trimmedCommand.split(separator: " ").first ?? "")
        return commandInfo.command.lowercased() == commandPart.lowercased()
    }
    
    private func navigateUp() {
        if !filteredCommands.isEmpty {
            selectedIndex = max(0, selectedIndex - 1)
        }
    }
    
    private func navigateDown() {
        if !filteredCommands.isEmpty {
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
        }
    }
    
    private func handleTabCompletion() {
        guard selectedIndex < filteredCommands.count else { return }
        let selectedCommand = filteredCommands[selectedIndex]
        
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.isEmpty || trimmedCommand == "/" || !trimmedCommand.contains(" ") {
            // Complete the command and add space for query
            command = selectedCommand.command + " "
        }
    }
    
    private func hideCommandPalette() {
        isVisible = false
        command = ""
        selectedIndex = 0
        isInputFocused = false
        
        // Ensure the main window stays focused after hiding command palette
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                window.makeKey()
            }
        }
    }
    
    private func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.hasPrefix("/t3 ") {
            let query = String(trimmedCommand.dropFirst(4)) // Remove "/t3 "
            navigateToT3(with: query)
        } else if trimmedCommand == "/t3" {
            navigateToT3(with: "")
        } else if trimmedCommand.hasPrefix("/chat ") {
            let query = String(trimmedCommand.dropFirst(6)) // Remove "/chat "
            navigateToChatGPT(with: query)
        } else if trimmedCommand == "/chat" {
            navigateToChatGPT(with: "")
        } else if trimmedCommand.hasPrefix("/claude ") {
            let query = String(trimmedCommand.dropFirst(8)) // Remove "/claude "
            navigateToClaude(with: query)
        } else if trimmedCommand == "/claude" {
            navigateToClaude(with: "")
        } else if trimmedCommand.hasPrefix("/perplexity ") {
            let query = String(trimmedCommand.dropFirst(12)) // Remove "/perplexity "
            navigateToPerplexity(with: query)
        } else if trimmedCommand == "/perplexity" {
            navigateToPerplexity(with: "")
        } else if trimmedCommand.hasPrefix("/copilot ") {
            let query = String(trimmedCommand.dropFirst(9)) // Remove "/copilot "
            navigateToCopilot(with: query)
        } else if trimmedCommand == "/copilot" {
            navigateToCopilot(with: "")
        }
        
        hideCommandPalette()
    }
    
    private func navigateToT3(with query: String) {
        var urlString = "https://www.t3.chat/new"
        
        if !query.isEmpty {
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
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?q=\(encodedQuery)"
            }
        }
        
        if let url = URL(string: urlString) {
            onNavigate(url)
        }
    }
    
    private func navigateToClaude(with query: String) {
        var urlString = "https://claude.ai/new"
        
        if !query.isEmpty {
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?q=\(encodedQuery)"
            }
        }
        
        if let url = URL(string: urlString) {
            onNavigate(url)
        }
    }
    
    private func navigateToPerplexity(with query: String) {
        var urlString = "https://www.perplexity.ai/search"
        
        if !query.isEmpty {
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?q=\(encodedQuery)"
            }
        }
        
        if let url = URL(string: urlString) {
            onNavigate(url)
        }
    }
    
    private func navigateToCopilot(with query: String) {
        var urlString = "https://copilot.microsoft.com/"
        
        if !query.isEmpty {
            if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?q=\(encodedQuery)"
            }
        }
        
        if let url = URL(string: urlString) {
            onNavigate(url)
        }
    }
}

struct CommandInfo {
    let command: String
    let description: String
    let placeholder: String
    let serviceId: String? // Optional service ID for filtering
}

extension CommandInfo: Equatable {
    static func == (lhs: CommandInfo, rhs: CommandInfo) -> Bool {
        return lhs.command == rhs.command
    }
}

struct CommandHint: View {
    let commandInfo: CommandInfo
    let currentCommand: String
    let currentQuery: String
    let isTypingQuery: Bool
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            Text(commandInfo.command)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(isHighlighted ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isHighlighted ? Color.accentColor : Color.clear)
                .cornerRadius(5)
            
            if isTypingQuery && isHighlighted && !currentQuery.isEmpty {
                // Show the actual query being typed
                Text("→ \"\(currentQuery)\"")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .italic()
            } else {
                // Show the description or placeholder
                let displayText = isHighlighted && currentCommand.hasPrefix(commandInfo.command) && currentCommand.contains(" ") 
                    ? commandInfo.placeholder 
                    : commandInfo.description
                
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(isHighlighted ? .primary : .secondary)
            }
            
            Spacer()
            
            if isHighlighted && !isTypingQuery {
                Text("TAB")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CommandPalette(isVisible: .constant(true), onNavigate: { _ in })
        .frame(width: 700, height: 400)
} 