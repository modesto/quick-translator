import Foundation

public enum TranslationProviderKind: String, CaseIterable, Codable, Sendable {
    case claudeCode = "claude-code"
    case claudeAPI = "claude-api"
    case deepL = "deepl"

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .claudeAPI: return "Claude API"
        case .deepL: return "DeepL"
        }
    }

    public var symbolName: String {
        switch self {
        case .claudeCode, .claudeAPI: return "sparkles"
        case .deepL: return "character.book.closed"
        }
    }

    public var keyAccount: String? {
        switch self {
        case .claudeCode: return nil
        case .claudeAPI: return "anthropic-api-key"
        case .deepL: return "deepl-auth-key"
        }
    }

    public var keyEnvironmentVariable: String? {
        switch self {
        case .claudeCode: return nil
        case .claudeAPI: return "QT_ANTHROPIC_API_KEY"
        case .deepL: return "QT_DEEPL_AUTH_KEY"
        }
    }

    public var keyPage: (title: String, url: URL)? {
        switch self {
        case .claudeCode: return nil
        case .claudeAPI: return ("Crear una clave en platform.claude.com", URL(string: "https://platform.claude.com/settings/keys")!)
        case .deepL: return ("Conseguir una clave de DeepL API (hay plan gratuito)", URL(string: "https://www.deepl.com/pro-api")!)
        }
    }

    public var showsModelName: Bool { self != .deepL }
}

public struct ClaudeModelOption: Equatable, Sendable, Identifiable {
    public let id: String
    public let note: String

    public var displayName: String { ModelName.displayName(forModel: id) }

    public static let all = [
        ClaudeModelOption(id: "claude-haiku-5-5", note: "la más rápida"),
        ClaudeModelOption(id: "claude-sonnet-5-5", note: "más calidad"),
        ClaudeModelOption(id: "claude-opus-5-5", note: "la de más calidad, más lenta"),
    ]

    public static let `default` = all[0]
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
    public static func arguments(cliPath: String, provider: TranslationProviderKind, apiModel: String) -> [String] {
        [cliPath, "--server", "--provider", provider.rawValue, "--api-model", apiModel]
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
