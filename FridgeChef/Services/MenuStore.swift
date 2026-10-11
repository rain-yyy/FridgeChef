import Foundation
import Observation

/// Runs menu generation and keeps the latest result, persisted to Application Support so it
/// survives tab switches and app restarts. Shared through the environment.
@Observable
final class MenuStore {
    enum Phase: Equatable {
        case idle
        case loading
        case failed(AIError)
    }

    struct Request: Equatable {
        var cuisine: Cuisine
        var servings: Int
    }

    private(set) var phase: Phase = .idle
    /// The last successful generation (kept while a new one loads or fails).
    private(set) var result: MenuResult?
    /// What is being (or was last) generated; used for the loading text and retries.
    private(set) var request: Request?

    private var task: Task<Void, Never>?
    private let fileURL: URL?

    /// `fileURL == nil` keeps everything in memory (previews, tests).
    init(fileURL: URL? = MenuStore.defaultFileURL) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            result = try? Self.decoder.decode(MenuResult.self, from: data)
        }
    }

    func generate(_ request: Request, items: [FoodItem], settings: AISettings) {
        task?.cancel()
        self.request = request
        phase = .loading
        let candidates = MenuPrompt.candidates(from: items)
        let messages = MenuPrompt.messages(
            candidates: candidates, cuisine: request.cuisine, servings: request.servings,
            languageName: Self.replyLanguageName)
        let client = settings.makeClient()

        task = Task {
            do throws(AIError) {
                let content = try await client.complete(messages, responseFormat: MenuPrompt.responseFormat)
                let plans = try MenuPrompt.parse(content, candidates: candidates)
                guard !Task.isCancelled else { return }
                let result = MenuResult(
                    cuisine: request.cuisine, servings: request.servings, createdAt: .now, plans: plans)
                self.result = result
                phase = .idle
                save(result)
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error)
            }
        }
    }

    /// Re-runs the last request (or the saved result's settings after a relaunch).
    func retry(items: [FoodItem], settings: AISettings) {
        guard let request = request ?? result.map({ Request(cuisine: $0.cuisine, servings: $0.servings) }) else { return }
        generate(request, items: items, settings: settings)
    }

    // MARK: - Private

    static let defaultFileURL: URL? = {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else { return nil }
        return directory.appendingPathComponent("last_menu.json")
    }()

    /// The language the AI should write in: the app's current localization.
    private static var replyLanguageName: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true ? "Simplified Chinese" : "English"
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Writes the result to disk (internal for tests).
    func save(_ result: MenuResult) {
        guard let fileURL, let data = try? Self.encoder.encode(result) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
