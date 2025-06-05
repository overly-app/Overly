//
//  StandaloneCommandPalette.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import AppKit

struct StandaloneCommandPalette: View {
    @State private var command: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedIndex: Int = 0
    let onNavigate: (URL) -> Void
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
            return settings.activeProviderIds.contains(commandInfo.serviceId ?? "")
        }
    }
    
    // Computed properties for autocomplete
    private var filteredCommands: [CommandInfo] {
        if command.isEmpty || command == "/" {
            return availableCommands
        }
        
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCommand.contains(" ") {
            return availableCommands.filter { cmd in
                cmd.command.lowercased().hasPrefix(trimmedCommand.lowercased())
            }
        }
        
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
                        if !newValue.isEmpty && !newValue.hasPrefix("/") {
                            command = "/" + newValue
                        }
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
        .frame(maxWidth: 600, maxHeight: 380)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            selectedIndex = 0
            command = "/"
            
            // Ensure focus with a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isInputFocused = true
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
    
    private func shouldHighlight(_ commandInfo: CommandInfo, index: Int) -> Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.isEmpty || trimmedCommand == "/" {
            return index == selectedIndex
        }
        
        if !trimmedCommand.contains(" ") {
            return index == selectedIndex && commandInfo.command.lowercased().hasPrefix(trimmedCommand.lowercased())
        }
        
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
            command = selectedCommand.command + " "
        }
    }
    
    private func hideCommandPalette() {
        // Close the window
        if let window = NSApp.keyWindow {
            window.orderOut(nil)
        }
    }
    
    private func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Track if command was executed successfully
        var commandExecuted = false
        
        if trimmedCommand.hasPrefix("/t3 ") {
            let query = String(trimmedCommand.dropFirst(4))
            navigateToT3(with: query)
            commandExecuted = true
        } else if trimmedCommand == "/t3" {
            navigateToT3(with: "")
            commandExecuted = true
        } else if trimmedCommand.hasPrefix("/chat ") {
            let query = String(trimmedCommand.dropFirst(6))
            navigateToChatGPT(with: query)
            commandExecuted = true
        } else if trimmedCommand == "/chat" {
            navigateToChatGPT(with: "")
            commandExecuted = true
        } else if trimmedCommand.hasPrefix("/claude ") {
            let query = String(trimmedCommand.dropFirst(8))
            navigateToClaude(with: query)
            commandExecuted = true
        } else if trimmedCommand == "/claude" {
            navigateToClaude(with: "")
            commandExecuted = true
        } else if trimmedCommand.hasPrefix("/perplexity ") {
            let query = String(trimmedCommand.dropFirst(12))
            navigateToPerplexity(with: query)
            commandExecuted = true
        } else if trimmedCommand == "/perplexity" {
            navigateToPerplexity(with: "")
            commandExecuted = true
        } else if trimmedCommand.hasPrefix("/copilot ") {
            let query = String(trimmedCommand.dropFirst(9))
            navigateToCopilot(with: query)
            commandExecuted = true
        } else if trimmedCommand == "/copilot" {
            navigateToCopilot(with: "")
            commandExecuted = true
        }
        
        // If command was executed successfully, clear the field and close window
        if commandExecuted {
            self.command = ""
            hideCommandPalette()
        }
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

#Preview {
    StandaloneCommandPalette { _ in }
        .frame(width: 600, height: 400)
} 