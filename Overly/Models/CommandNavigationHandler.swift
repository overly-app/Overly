//
//  CommandNavigationHandler.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import Foundation

// Handler for command navigation logic
struct CommandNavigationHandler {
    let onNavigate: (URL) -> Void
    
    // All available commands mapped to service IDs
    static let allCommands = [
        CommandInfo(command: "/t3", description: "Open T3 chat with query", placeholder: "Type your question...", serviceId: "T3 Chat"),
        CommandInfo(command: "/chat", description: "Open ChatGPT with query", placeholder: "Type your question...", serviceId: "ChatGPT"),
        CommandInfo(command: "/claude", description: "Open Claude with query", placeholder: "Type your question...", serviceId: "Claude"),
        CommandInfo(command: "/perplexity", description: "Open Perplexity with query", placeholder: "Type your question...", serviceId: "Perplexity"),
        CommandInfo(command: "/copilot", description: "Open Copilot with query", placeholder: "Type your question...", serviceId: "Copilot"),
        CommandInfo(command: "/ollama", description: "Chat with Ollama model", placeholder: "query [model]", serviceId: "AI Chat")
    ]
    
    func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCommand.hasPrefix("/t3 ") {
            let query = String(trimmedCommand.dropFirst(4))
            navigateToT3(with: query)
        } else if trimmedCommand == "/t3" {
            navigateToT3(with: "")
        } else if trimmedCommand.hasPrefix("/chat ") {
            let query = String(trimmedCommand.dropFirst(6))
            navigateToChatGPT(with: query)
        } else if trimmedCommand == "/chat" {
            navigateToChatGPT(with: "")
        } else if trimmedCommand.hasPrefix("/claude ") {
            let query = String(trimmedCommand.dropFirst(8))
            navigateToClaude(with: query)
        } else if trimmedCommand == "/claude" {
            navigateToClaude(with: "")
        } else if trimmedCommand.hasPrefix("/perplexity ") {
            let query = String(trimmedCommand.dropFirst(12))
            navigateToPerplexity(with: query)
        } else if trimmedCommand == "/perplexity" {
            navigateToPerplexity(with: "")
        } else if trimmedCommand.hasPrefix("/copilot ") {
            let query = String(trimmedCommand.dropFirst(9))
            navigateToCopilot(with: query)
        } else if trimmedCommand == "/copilot" {
            navigateToCopilot(with: "")
        } else if trimmedCommand.hasPrefix("/ollama ") {
            let args = String(trimmedCommand.dropFirst(8))
            navigateToOllama(with: args)
        } else if trimmedCommand == "/ollama" {
            navigateToOllama(with: "")
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
    
    private func navigateToOllama(with args: String) {
        // Parse arguments: query with optional model at the end
        let trimmedArgs = args.trimmingCharacters(in: .whitespacesAndNewlines)
        var model = ""
        var query = trimmedArgs
        
        if !trimmedArgs.isEmpty {
            // Check if the last word looks like a model name (contains letters and numbers, possibly with dots/colons)
            let words = trimmedArgs.split(separator: " ")
            if let lastWord = words.last {
                let lastWordStr = String(lastWord)
                // Check if it looks like a model name (alphanumeric with dots/colons, not just a regular word)
                if lastWordStr.contains(":") || lastWordStr.contains(".") || 
                   (lastWordStr.range(of: "^[a-zA-Z0-9]+[0-9]", options: .regularExpression) != nil) {
                    model = lastWordStr
                    // Remove the model from the query
                    if words.count > 1 {
                        query = words.dropLast().joined(separator: " ")
                    } else {
                        query = ""
                    }
                }
            }
        }
        
        // Post notification to switch to AI Chat provider and send message
        NotificationCenter.default.post(
            name: NSNotification.Name("SwitchToAIChat"),
            object: nil,
            userInfo: ["model": model, "query": query]
        )
    }
} 