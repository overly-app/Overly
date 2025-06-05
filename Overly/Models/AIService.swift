//
//  AIService.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import Foundation

enum AIService: String, CaseIterable, Identifiable {
    case chatgpt = "ChatGPT"
    case gemini = "Gemini"
    case poe = "Poe"
    case perplexity = "Perplexity"
    case copilot = "Copilot"
    case claude = "Claude"
    case t3chat = "T3 Chat"
    case settings = "Settings"

    var id: String { self.rawValue }

    var url: URL? {
        switch self {
        case .chatgpt: return URL(string: "https://chatgpt.com")!
        case .gemini: return URL(string: "https://gemini.google.com")!
        case .poe: return URL(string: "https://poe.com")!
        case .perplexity: return URL(string: "https://perplexity.ai")!
        case .copilot: return URL(string: "https://copilot.microsoft.com")!
        case .claude: return URL(string: "https://claude.ai")!
        case .t3chat: return URL(string: "https://t3.chat")!
        case .settings: return nil
        }
    }

    var iconName: String {
        switch self {
        case .chatgpt: return "openai"
        case .gemini: return "gemini"
        case .poe: return "poe"
        case .perplexity: return "link"
        case .copilot: return "link"
        case .claude: return "link"
        case .t3chat: return "link"
        case .settings: return "gearshape"
        }
    }
} 