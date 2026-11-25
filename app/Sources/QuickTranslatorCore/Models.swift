import Foundation

public struct TranslationVariant: Decodable, Identifiable, Equatable, Sendable {
    public let label: String
    public let text: String
    public var id: String { label + text }

    public init(label: String, text: String) {
        self.label = label
        self.text = text
    }
}

public struct TranslationResult: Decodable, Equatable, Sendable {
    public let sourceLanguage: String
    public let targetLanguage: String
    public let variants: [TranslationVariant]

    public init(sourceLanguage: String, targetLanguage: String, variants: [TranslationVariant]) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.variants = variants
    }
}

public struct ClaudeTranslation: Equatable, Sendable {
    public let result: TranslationResult
    public let model: String?
    public let provider: TranslationProviderKind
    public let elapsed: TimeInterval?

    public init(result: TranslationResult, model: String?, provider: TranslationProviderKind = .claudeCode, elapsed: TimeInterval? = nil) {
        self.result = result
        self.model = model
        self.provider = provider
        self.elapsed = elapsed
    }
}

public struct AppleTranslation: Equatable, Sendable {
    public let text: String
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(text: String, sourceLanguage: String, targetLanguage: String) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public enum ProviderState<Value> {
    case idle
    case loading
    case done(Value)
    case failed(String)
}

extension ProviderState: Sendable where Value: Sendable {}

public enum TranslatorError: LocalizedError, Equatable {
    case notConfigured
    case serverStopped
    case failed(String)
    case provider(ProviderErrorCode, TranslationProviderKind, String)

    public var opensSettings: Bool {
        if case .provider(let code, _, _) = self { return code.opensSettings }
        return false
    }

    public var errorDescription: String? { message(in: L10n.language) }

    public func message(in language: UILanguage) -> String {
        switch self {
        case .notConfigured:
            return language.strings.cliNotFound
        case .serverStopped:
            return language.strings.serverStopped
        case .failed(let message):
            return message
        case .provider(let code, let provider, let detail):
            return code.message(provider: provider, detail: detail, in: language)
        }
    }
}

public enum ChoiceKeys {
    public static let apple = 1
    public static let firstClaude = 2

    public static func text(forKey key: Int, apple: ProviderState<AppleTranslation>, claude: ProviderState<ClaudeTranslation>) -> String? {
        if key == Self.apple, case .done(let translation) = apple { return translation.text }
        guard case .done(let translation) = claude else { return nil }
        let index = key - firstClaude
        let variants = translation.result.variants
        return variants.indices.contains(index) ? variants[index].text : nil
    }
}

public enum ModelName {
    public static func displayName(forModel id: String) -> String {
        let parts = id.split(separator: "-").map(String.init)
        if parts.count >= 2, parts[0] == "gpt" {
            return (["GPT-\(parts[1])"] + parts.dropFirst(2).map(\.capitalized)).joined(separator: " ")
        }
        guard parts.count >= 2, parts[0] == "claude" else { return id }
        let family = parts[1].capitalized
        let version = parts.dropFirst(2).joined(separator: ".")
        return version.isEmpty ? "Claude \(family)" : "Claude \(family) \(version)"
    }
}
