import Foundation
import Observation

/// OpenRouter API key (Keychain) and model ID (UserDefaults), shared by the settings and cook tabs.
@Observable
final class AISettings {
    /// Shown as quick picks under the model field; the first is the initial model.
    static let suggestedModels = [
        "anthropic/claude-haiku-5.5",
        "openai/gpt-6-luna",
        "deepseek/deepseek-v4.1-flash",
    ]

    private static let keyAccount = "openrouter.apiKey"
    private static let modelDefaultsKey = "ai.model"

    var apiKey: String {
        didSet { KeychainStore.set(trimmedKey.isEmpty ? nil : trimmedKey, for: Self.keyAccount) }
    }

    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Self.modelDefaultsKey) }
    }

    var trimmedKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedModel: String { model.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isConfigured: Bool { !trimmedKey.isEmpty && !trimmedModel.isEmpty }

    init() {
        var key = KeychainStore.string(for: Self.keyAccount) ?? ""
        #if DEBUG
        // For local testing: `-debugAPIKey <key>` uses a key for this launch without saving it.
        if let debugKey = UserDefaults.standard.string(forKey: "debugAPIKey") { key = debugKey }
        #endif
        apiKey = key  // single assignment in init: didSet does not run, nothing is written to the Keychain
        model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.suggestedModels[0]
    }

    func makeClient() -> OpenRouterClient {
        OpenRouterClient(apiKey: trimmedKey, model: trimmedModel)
    }
}
