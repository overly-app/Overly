//
//  CommandHistory.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI

// Command History Manager
class CommandHistory: ObservableObject {
    static let shared = CommandHistory()
    
    private let maxHistorySize = 50
    private let historyKey = "CommandPaletteHistory"
    
    @Published private(set) var history: [String] = []
    
    init() {
        loadHistory()
    }
    
    func addCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't add empty commands or just "/"
        guard !trimmedCommand.isEmpty && trimmedCommand != "/" else { return }
        
        // Remove if already exists to move to front
        history.removeAll { $0 == trimmedCommand }
        
        // Add to front
        history.insert(trimmedCommand, at: 0)
        
        // Limit size
        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }
        
        saveHistory()
    }
    
    private func loadHistory() {
        if let savedHistory = UserDefaults.standard.array(forKey: historyKey) as? [String] {
            history = savedHistory
        }
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: historyKey)
    }
} 