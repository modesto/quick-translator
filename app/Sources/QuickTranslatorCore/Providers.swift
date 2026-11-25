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
        case .claudeAPI: return ("Crear una clave en platform.claude.com", URL(string: "https://platform.claude.com/settings/keys")!)
        case .openAI: return ("Crear una clave en platform.openai.com", URL(string: "https://platform.openai.com/api-keys")!)
        case .deepL: return ("Conseguir una clave de DeepL API (hay plan gratuito)", URL(string: "https://www.deepl.com/pro-api")!)
        }
    }

    public var showsModelName: Bool { self != .deepL }
}

public struct ModelOption: Equatable, Sendable, Identifiable {
    public let id: String
    public let note: String

    public var displayName: String { ModelName.displayName(forModel: id) }

    public static let claude = [
        ModelOption(id: "claude-haiku-5-5", note: "la más rápida"),
        ModelOption(id: "claude-sonnet-5-5", note: "más calidad"),
        ModelOption(id: "claude-opus-5-5", note: "la de más calidad, más lenta"),
    ]

    public static let openAI = [
        ModelOption(id: "gpt-6-luna", note: "la más rápida y barata"),
        ModelOption(id: "gpt-6.1-terra", note: "más calidad"),
        ModelOption(id: "gpt-6.2-sol", note: "la de más calidad, más lenta"),
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
    func setSecret(_ value: String?, for account: String)
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]

    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public func secret(for account: String) -> String? { values[account] }

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

    public static func environment(base: [String: String], secrets: SecretStore) -> [String: String] {
        var environment = base
        for provider in TranslationProviderKind.allCases {
            guard let variable = provider.keyEnvironmentVariable else { continue }
            if let account = provider.keyAccount,
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

    public func message(provider: TranslationProviderKind, detail: String) -> String {
        let name = provider.displayName
        switch self {
        case .missingKey: return "Falta la clave de \(name). Añádela en Ajustes."
        case .authFailed: return "\(name) ha rechazado la clave. Revísala en Ajustes."
        case .quotaExceeded: return "Se ha agotado la cuota de \(name)."
        case .rateLimited: return "Demasiadas peticiones a \(name). Espera un momento."
        case .unsupportedLanguage: return "\(name) no admite este idioma."
        case .refused: return "\(name) no ha querido traducir este texto."
        case .network: return "No se ha podido conectar con \(name)."
        case .providerError: return "\(name) ha fallado: \(detail)"
        }
    }
}

public enum Elapsed {
    public static func format(_ seconds: TimeInterval) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        return "\(formatter.string(from: NSNumber(value: max(seconds, 0))) ?? "0,0") s"
    }
}
