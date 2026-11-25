import Foundation

public enum TranslationProviderKind: String, CaseIterable, Codable, Sendable {
    case claudeCode = "claude-code"
    case claudeAPI = "claude-api"
    case openAI = "openai"
    case deepL = "deepl"

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .claudeAPI: return "Claude API"
        case .openAI: return "OpenAI"
        case .deepL: return "DeepL"
        }
    }

    public var symbolName: String {
        switch self {
        case .claudeCode, .claudeAPI, .openAI: return "sparkles"
        case .deepL: return "character.book.closed"
        }
    }

    public var keyAccount: String? {
        switch self {
        case .claudeCode: return nil
        case .claudeAPI: return "anthropic-api-key"
        case .openAI: return "openai-api-key"
        case .deepL: return "deepl-auth-key"
        }
    }

    public var keyEnvironmentVariable: String? {
        switch self {
        case .claudeCode: return nil
        case .claudeAPI: return "QT_ANTHROPIC_API_KEY"
        case .openAI: return "QT_OPENAI_API_KEY"
        case .deepL: return "QT_DEEPL_AUTH_KEY"
        }
    }

    public var keyPage: (title: String, url: URL)? {
        switch self {
        case .claudeCode: return nil
        case .claudeAPI: return (L10n.strings.createKeyAt("platform.claude.com"), URL(string: "https://platform.claude.com/settings/keys")!)
        case .openAI: return (L10n.strings.createKeyAt("platform.openai.com"), URL(string: "https://platform.openai.com/api-keys")!)
        case .deepL: return (L10n.strings.getDeepLKey, URL(string: "https://www.deepl.com/pro-api")!)
        }
    }

    public var showsModelName: Bool { self != .deepL }
}

public struct ModelOption: Equatable, Sendable, Identifiable {
    public enum Note: Sendable {
        case fastest, fastestCheapest, moreQuality, bestQuality

        public func text(in language: UILanguage) -> String {
            let strings = language.strings
            switch self {
            case .fastest: return strings.fastest
            case .fastestCheapest: return strings.fastestCheapest
            case .moreQuality: return strings.moreQuality
            case .bestQuality: return strings.bestQuality
            }
        }
    }

    public let id: String
    public let kind: Note

    public var note: String { kind.text(in: L10n.language) }

    public init(id: String, note: Note) {
        self.id = id
        self.kind = note
    }

    public var displayName: String { ModelName.displayName(forModel: id) }

    public static let claude = [
        ModelOption(id: "claude-haiku-5-5", note: .fastest),
        ModelOption(id: "claude-sonnet-5-5", note: .moreQuality),
        ModelOption(id: "claude-opus-5-5", note: .bestQuality),
    ]

    public static let openAI = [
        ModelOption(id: "gpt-6-luna", note: .fastestCheapest),
        ModelOption(id: "gpt-6.1-terra", note: .moreQuality),
        ModelOption(id: "gpt-6.2-sol", note: .bestQuality),
    ]

    public static func validated(_ id: String?, in options: [ModelOption]) -> String {
        options.first { $0.id == id }?.id ?? options[0].id
    }
}

public enum OpenAIBaseURL {
    public static let `default` = "https://api.openai.com/v1"

    /// Empty means OpenAI itself; anything else must be an http(s) URL.
    public static func normalized(_ input: String) -> String? {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.isEmpty { return Self.default }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host?.isEmpty == false else { return nil }
        if isOfficial(trimmed), url.path.isEmpty { return Self.default }
        return trimmed
    }

    public static func isOfficial(_ url: String) -> Bool {
        URL(string: url)?.host?.lowercased() == "api.openai.com"
    }
}

public enum ProviderSetup {
    public static func isReady(_ provider: TranslationProviderKind, hasKey: Bool, openAIBaseURL: String, openAIModel: String) -> Bool {
        switch provider {
        case .claudeCode: return true
        case .openAI:
            if OpenAIBaseURL.isOfficial(openAIBaseURL) { return hasKey }
            return !openAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .claudeAPI, .deepL: return hasKey
        }
    }
}

public protocol SecretStore: AnyObject {
    func secret(for account: String) -> String?
    func hasSecret(for account: String) -> Bool
    func setSecret(_ value: String?, for account: String)
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]

    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public private(set) var readAccounts: [String] = []

    public func secret(for account: String) -> String? {
        readAccounts.append(account)
        return values[account]
    }

    public func hasSecret(for account: String) -> Bool { !(values[account] ?? "").isEmpty }

    public func setSecret(_ value: String?, for account: String) {
        values[account] = value
    }
}

public enum ServerLaunch {
    public static func arguments(cliPath: String, provider: TranslationProviderKind, claudeAPIModel: String, openAIModel: String, openAIBaseURL: String = OpenAIBaseURL.default) -> [String] {
        var arguments = [cliPath, "--server", "--provider", provider.rawValue, "--api-model", claudeAPIModel, "--openai-model", openAIModel]
        if openAIBaseURL != OpenAIBaseURL.default {
            arguments += ["--openai-base-url", openAIBaseURL]
        }
        return arguments
    }

    public static func environment(base: [String: String], secrets: SecretStore, provider active: TranslationProviderKind) -> [String: String] {
        var environment = base
        for provider in TranslationProviderKind.allCases {
            guard let variable = provider.keyEnvironmentVariable else { continue }
            if provider == active,
               let account = provider.keyAccount,
               let key = secrets.secret(for: account)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty {
                environment[variable] = key
            } else {
                environment.removeValue(forKey: variable)
            }
        }
        return environment
    }
}

public enum ProviderErrorCode: String, Decodable, Sendable {
    case missingKey = "missing_key"
    case authFailed = "auth_failed"
    case quotaExceeded = "quota_exceeded"
    case rateLimited = "rate_limited"
    case unsupportedLanguage = "unsupported_language"
    case refused
    case network
    case providerError = "provider_error"

    public var opensSettings: Bool { self == .missingKey || self == .authFailed }

    public func message(provider: TranslationProviderKind, detail: String, in language: UILanguage = L10n.language) -> String {
        let name = provider.displayName
        let strings = language.strings
        switch self {
        case .missingKey: return strings.missingKey(name)
        case .authFailed: return strings.authFailed(name)
        case .quotaExceeded: return strings.quotaExceeded(name)
        case .rateLimited: return strings.rateLimited(name)
        case .unsupportedLanguage: return strings.unsupportedLanguage(name)
        case .refused: return strings.refused(name)
        case .network: return strings.network(name)
        case .providerError: return strings.providerFailed(name, detail)
        }
    }
}

public enum Elapsed {
    public static func format(_ seconds: TimeInterval, in language: UILanguage = L10n.language) -> String {
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        return "\(formatter.string(from: NSNumber(value: max(seconds, 0))) ?? "0") s"
    }
}
