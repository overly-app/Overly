import Foundation
import Combine

class OllamaManager: ObservableObject {
    static let shared = OllamaManager()
    
    @Published var availableModels: [OllamaModel] = []
    @Published var selectedModel: String = ""
    @Published var isLoading = false
    @Published var error: String?
    
    private let keychainManager = KeychainManager.shared
    private let urlSession = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    var baseURL: String {
        return keychainManager.getBaseURL(for: .ollama) ?? "http://localhost:11434"
    }
    
    // MARK: - Model Management
    
    func fetchModels() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let models = try await fetchOllamaModels()
            await MainActor.run {
                self.availableModels = models
                if self.selectedModel.isEmpty && !models.isEmpty {
                    self.selectedModel = models.first?.name ?? ""
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchOllamaModels() async throws -> [OllamaModel] {
        let url = URL(string: "\(baseURL)/api/tags")!
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.invalidResponse
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return ollamaResponse.models
    }
    
    // MARK: - Chat Completion
    
    func sendChatMessage(
        messages: [OllamaChatMessage],
        model: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let modelToUse = model ?? selectedModel
        guard !modelToUse.isEmpty else {
            throw OllamaError.noModelSelected
        }
        
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = OllamaChatRequest(
            model: modelToUse,
            messages: messages,
            stream: true
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (asyncBytes, response) = try await urlSession.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: OllamaError.invalidResponse)
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        if let data = line.data(using: .utf8),
                           let chatResponse = try? JSONDecoder().decode(OllamaChatResponse.self, from: data) {
                            
                            if let content = chatResponse.message?.content, !content.isEmpty {
                                continuation.yield(content)
                            }
                            
                            if chatResponse.done {
                                continuation.finish()
                                return
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Data Models

struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable, Identifiable {
    let name: String
    let modifiedAt: String
    let size: Int64
    let digest: String
    let details: OllamaModelDetails?
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
    
    var displayName: String {
        // Clean up model name for display
        return name.replacingOccurrences(of: ":latest", with: "")
    }
    
    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct OllamaModelDetails: Codable {
    let format: String?
    let family: String?
    let parameterSize: String?
    let quantizationLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case format
        case family
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatResponse: Codable {
    let model: String?
    let createdAt: String?
    let message: OllamaChatMessage?
    let done: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
    }
}

enum OllamaError: LocalizedError {
    case invalidResponse
    case noModelSelected
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Ollama server"
        case .noModelSelected:
            return "No model selected"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
} 