//
//  CommandInfo.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI

// Command information structure
struct CommandInfo: Equatable {
    let command: String
    let description: String
    let placeholder: String
    let serviceId: String?
    
    static func == (lhs: CommandInfo, rhs: CommandInfo) -> Bool {
        return lhs.command == rhs.command
    }
}

// SwiftUI view for displaying command hints
struct CommandHint: View {
    let commandInfo: CommandInfo
    let currentCommand: String
    let currentQuery: String
    let isTypingQuery: Bool
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(commandInfo.command)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(isHighlighted ? .white : .primary)
                    
                    if isTypingQuery && !currentQuery.isEmpty {
                        Text(currentQuery)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(isHighlighted ? .white.opacity(0.8) : .primary.opacity(0.8))
                    }
                    
                    Spacer()
                }
                
                Text(commandInfo.description)
                    .font(.system(size: 11))
                    .foregroundColor(isHighlighted ? .white.opacity(0.7) : .secondary)
                
                if !isTypingQuery && !commandInfo.placeholder.isEmpty {
                    Text(commandInfo.placeholder)
                        .font(.system(size: 10))
                        .foregroundColor(isHighlighted ? .white.opacity(0.5) : .secondary.opacity(0.7))
                        .italic()
                }
            }
            
            if isHighlighted {
                Text("ENTER")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHighlighted ? Color.accentColor : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
} 