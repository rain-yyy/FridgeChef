import Foundation

/// Why an AI request failed. `isNetwork` picks between the two error pages in the design.
enum AIError: Error, Equatable {
    case network
    case invalidKey
    case insufficientCredits
    case modelUnavailable
    case rateLimited
    case server(String?)
    /// The reply could not be read as a menu.
    case badResponse

    var isNetwork: Bool { self == .network }

    /// Fixed in settings by changing the key or topping up, not by switching models.
    var isAccountProblem: Bool { self == .invalidKey || self == .insufficientCredits }

    /// A short explanation for the settings test and the AI error page; nil for generic failures.
    var detail: LocalizedStringResource? {
        switch self {
        case .network: "aiError.network"
        case .invalidKey: "aiError.invalidKey"
        case .insufficientCredits: "aiError.credits"
        case .modelUnavailable: "aiError.model"
        case .rateLimited: "aiError.rateLimited"
        case .server(let message?): "aiError.server \(message)"
        case .server(nil), .badResponse: nil
        }
    }

    /// Maps an OpenRouter HTTP status (and its error message) to an AIError.
    static func from(status: Int, message: String?) -> AIError {
        switch status {
        case 401, 403: .invalidKey
        case 402: .insufficientCredits
        case 404: .modelUnavailable
        case 400 where message?.localizedCaseInsensitiveContains("model") == true: .modelUnavailable
        case 429: .rateLimited
        default: .server(message)
        }
    }
}

struct ChatMessage {
    enum Role: String { case system, user }
    let role: Role
    let content: String
}

/// OpenRouter chat completions (OpenAI-compatible). https://openrouter.ai/docs/api-reference
struct OpenRouterClient {
    let apiKey: String
    let model: String
    var session: URLSession = .shared

    private static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// Sends the messages and returns the assistant's text.
    /// `responseFormat` is passed through as-is (e.g. a JSON schema); models that don't support it ignore it.
    func complete(
        _ messages: [ChatMessage], responseFormat: [String: Any]? = nil,
        maxTokens: Int? = nil, timeout: TimeInterval = 90
    ) async throws(AIError) -> String {
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "reasoning": ["effort": "low"],
        ]
        if let responseFormat { body["response_format"] = responseFormat }
        if let maxTokens { body["max_tokens"] = maxTokens }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("FridgeChef", forHTTPHeaderField: "X-Title")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .network
        }

        let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw AIError.from(status: status, message: decoded?.error?.message)
        }
        if let error = decoded?.error {
            throw AIError.from(status: error.code ?? 500, message: error.message)
        }
        guard let content = decoded?.choices?.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw .badResponse
        }
        return content
    }

    /// A tiny request to check that the key and model work.
    func testConnection() async throws(AIError) {
        _ = try await complete([ChatMessage(role: .user, content: "Reply with OK.")], maxTokens: 16, timeout: 30)
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    struct ErrorBody: Decodable {
        let message: String?
        let code: Int?
    }
    let choices: [Choice]?
    let error: ErrorBody?
}
