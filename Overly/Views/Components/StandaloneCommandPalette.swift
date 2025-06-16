//
//  StandaloneCommandPalette.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//z

import SwiftUI
import AppKit

struct StandaloneCommandPalette: View {
    @State private var command: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedIndex: Int = 0
    @State private var historyIndex: Int = -1 // -1 means not in history mode
    @State private var isInHistoryMode: Bool = false
    @StateObject private var commandHistory = CommandHistory.shared
    let onNavigate: (URL) -> Void
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var aiProviderManager = AIProviderManager.shared
    
    // Use the command navigation handler
    private var navigationHandler: CommandNavigationHandler {
        CommandNavigationHandler(onNavigate: onNavigate)
    }
    
    // Available commands filtered by enabled services
    private var availableCommands: [CommandInfo] {
        return CommandNavigationHandler.allCommands.filter { commandInfo in
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
    
    // Model suggestions for /ollama command
    private var modelSuggestions: [String] {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedCommand.split(separator: " ")
        
        // Only show model suggestions for /ollama command
        guard parts.count >= 1 && parts[0].lowercased() == "/ollama" else {
            return []
        }
        
        let availableModels = aiProviderManager.availableModels
            .filter { $0.provider == .ollama && $0.isEnabled }
            .map { $0.name }
        
        // If we have parts, check if the last part looks like a partial model name
        if parts.count >= 2 {
            let lastPart = String(parts.last!).lowercased()
            // Only show suggestions if the last part looks like it could be a model name
            if lastPart.contains(".") || lastPart.contains(":") || 
               lastPart.range(of: "^[a-zA-Z0-9]+[0-9]", options: .regularExpression) != nil ||
               availableModels.contains(where: { $0.lowercased().hasPrefix(lastPart) }) {
                return availableModels.filter { $0.lowercased().hasPrefix(lastPart) }
            }
        }
        
        return availableModels
    }
    
    // Check if we should show model suggestions
    private var shouldShowModelSuggestions: Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedCommand.split(separator: " ")
        return parts.count >= 1 && parts[0].lowercased() == "/ollama" && !modelSuggestions.isEmpty
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
    
    // Check if we should show history or autocomplete
    private var shouldShowHistory: Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCommand.isEmpty || trimmedCommand == "/"
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
                        // Reset selection when command changes (unless we're in history mode)
                        if !isInHistoryMode {
                            selectedIndex = 0
                        }
                        // Exit history mode when typing
                        if !shouldShowHistory {
                            isInHistoryMode = false
                            historyIndex = -1
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .cornerRadius(10)
            
            // Command hints and autocomplete or history
            if shouldShowHistory && !commandHistory.history.isEmpty {
                buildHistoryView()
            } else if shouldShowModelSuggestions {
                buildModelSuggestionsView()
            } else if !filteredCommands.isEmpty {
                buildAutocompleteView()
            }
        }
        .frame(maxWidth: 600, maxHeight: 380)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            setupCommandPalette()
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
    
    private func buildHistoryView() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent Commands")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    commandHistory.clearHistory()
                }) {
                    Text("Clear")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    // Add subtle hover effect if needed
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            ForEach(Array(commandHistory.history.enumerated()), id: \.element) { index, historyCommand in
                HStack {
                    Text(historyCommand)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(isInHistoryMode && index == historyIndex ? .white : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isInHistoryMode && index == historyIndex ? Color.accentColor : Color.clear)
                        .cornerRadius(5)
                    
                    Spacer()
                    
                    if isInHistoryMode && index == historyIndex {
                        Text("ENTER")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    command = historyCommand
                    executeCommand(historyCommand)
                }
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(10)
        .padding(.top, 3)
    }
    
    private func buildAutocompleteView() -> some View {
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
    
    private func buildModelSuggestionsView() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Available Models")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            ForEach(Array(modelSuggestions.enumerated()), id: \.element) { index, model in
                let displayText = getDisplayText(for: model)
                
                HStack {
                    Text(displayText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(index == selectedIndex ? .white : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(index == selectedIndex ? Color.accentColor : Color.clear)
                        .cornerRadius(5)
                    
                    Spacer()
                    
                    if index == selectedIndex {
                        Text("TAB")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectModel(model)
                }
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(10)
        .padding(.top, 3)
    }
    
    private func setupCommandPalette() {
        selectedIndex = 0
        historyIndex = -1
        isInHistoryMode = false
        command = "/"
        
        // Ensure focus with a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isInputFocused = true
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
        if shouldShowHistory && !commandHistory.history.isEmpty {
            // Navigate through history
            isInHistoryMode = true
            if historyIndex == -1 {
                historyIndex = 0
            } else {
                historyIndex = max(0, historyIndex - 1)
            }
        } else if shouldShowModelSuggestions {
            // Navigate through model suggestions
            isInHistoryMode = false
            selectedIndex = max(0, selectedIndex - 1)
        } else if !filteredCommands.isEmpty {
            // Navigate through autocomplete
            isInHistoryMode = false
            selectedIndex = max(0, selectedIndex - 1)
        }
    }
    
    private func navigateDown() {
        if shouldShowHistory && !commandHistory.history.isEmpty {
            // Navigate through history
            isInHistoryMode = true
            if historyIndex == -1 {
                historyIndex = 0
            } else {
                historyIndex = min(commandHistory.history.count - 1, historyIndex + 1)
            }
        } else if shouldShowModelSuggestions {
            // Navigate through model suggestions
            isInHistoryMode = false
            selectedIndex = min(modelSuggestions.count - 1, selectedIndex + 1)
        } else if !filteredCommands.isEmpty {
            // Navigate through autocomplete
            isInHistoryMode = false
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
        }
    }
    
    private func handleTabCompletion() {
        if shouldShowHistory && isInHistoryMode && historyIndex >= 0 && historyIndex < commandHistory.history.count {
            // Select from history
            command = commandHistory.history[historyIndex]
            isInHistoryMode = false
            historyIndex = -1
            return
        }
        
        if shouldShowModelSuggestions && selectedIndex < modelSuggestions.count {
            // Select model for /ollama command
            let selectedModel = modelSuggestions[selectedIndex]
            selectModel(selectedModel)
            return
        }
        
        guard selectedIndex < filteredCommands.count else { return }
        let selectedCommand = filteredCommands[selectedIndex]
        
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.isEmpty || trimmedCommand == "/" || !trimmedCommand.contains(" ") {
            command = selectedCommand.command + " "
        }
    }
    
    private func getDisplayText(for model: String) -> String {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedCommand.split(separator: " ")
        
        if parts.count >= 2 {
            let lastPart = String(parts.last!)
            if lastPart.contains(".") || lastPart.contains(":") || 
               lastPart.range(of: "^[a-zA-Z0-9]+[0-9]", options: .regularExpression) != nil ||
               aiProviderManager.availableModels.contains(where: { $0.name.lowercased().hasPrefix(lastPart.lowercased()) }) {
                // Replace the partial model with the full model name
                let queryParts = parts.dropLast()
                if queryParts.isEmpty {
                    return "/ollama \(model)"
                } else {
                    return "/ollama \(queryParts.joined(separator: " ")) \(model)"
                }
            } else {
                // Append model to existing query
                return "\(trimmedCommand) \(model)"
            }
        } else {
            return "/ollama \(model)"
        }
    }
    
    private func selectModel(_ model: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedCommand.split(separator: " ")
        
        if parts.count >= 2 {
            // Check if the last part looks like a partial model name
            let lastPart = String(parts.last!)
            if lastPart.contains(".") || lastPart.contains(":") || 
               lastPart.range(of: "^[a-zA-Z0-9]+[0-9]", options: .regularExpression) != nil ||
               aiProviderManager.availableModels.contains(where: { $0.name.lowercased().hasPrefix(lastPart.lowercased()) }) {
                // Replace the last part (partial model) with the selected model
                let queryParts = parts.dropLast()
                if queryParts.isEmpty {
                    command = "/ollama \(model) "
                } else {
                    command = "/ollama \(queryParts.joined(separator: " ")) \(model) "
                }
            } else {
                // Append the model to the end
                command = "\(trimmedCommand) \(model) "
            }
        } else {
            // Just add the model
            command = "/ollama \(model) "
        }
        
        // Reset selection
        selectedIndex = 0
    }
    
    private func hideCommandPalette() {
        // Close the window
        if let window = NSApp.keyWindow {
            window.orderOut(nil)
        }
    }
    
    private func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle history selection
        if shouldShowHistory && isInHistoryMode && historyIndex >= 0 && historyIndex < commandHistory.history.count {
            let selectedHistoryCommand = commandHistory.history[historyIndex]
            commandHistory.addCommand(selectedHistoryCommand) // Move to front
            navigationHandler.executeCommand(selectedHistoryCommand)
            hideCommandPalette()
            return
        }
        
        // Handle clear command
        if trimmedCommand.lowercased() == "/clear" {
            commandHistory.clearHistory()
            self.command = "/"
            return
        }
        
        // Add to history before executing
        commandHistory.addCommand(trimmedCommand)
        
        navigationHandler.executeCommand(trimmedCommand)
        
        // Add a small delay before hiding the palette to allow notifications to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hideCommandPalette()
        }
    }
}

#Preview {
    StandaloneCommandPalette { _ in }
        .frame(width: 600, height: 400)
} 