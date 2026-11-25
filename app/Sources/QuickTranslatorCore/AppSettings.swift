import Foundation

public final class AppSettings {
    public static let automaticClaudeKey = "automaticClaudeTranslation"
    public static let shortcutKey = "translateShortcut"
    public static let languagePairKey = "languagePair"
    public static let providerKey = "translationProvider"
    public static let claudeAPIModelKey = "claudeAPIModel"
    public static let openAIModelKey = "openAIModel"
    public static let openAIBaseURLKey = "openAIBaseURL"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var provider: TranslationProviderKind {
        get { defaults.string(forKey: Self.providerKey).flatMap(TranslationProviderKind.init(rawValue:)) ?? .claudeCode }
        set { defaults.set(newValue.rawValue, forKey: Self.providerKey) }
    }

    public var claudeAPIModel: String {
        get { ModelOption.validated(defaults.string(forKey: Self.claudeAPIModelKey), in: ModelOption.claude) }
        set { defaults.set(newValue, forKey: Self.claudeAPIModelKey) }
    }

    public var openAIModel: String {
        get {
            let stored = defaults.string(forKey: Self.openAIModelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stored.isEmpty ? ModelOption.openAI[0].id : stored
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.openAIModelKey) }
    }

    public var openAIBaseURL: String {
        get { defaults.string(forKey: Self.openAIBaseURLKey).flatMap(OpenAIBaseURL.normalized) ?? OpenAIBaseURL.default }
        set {
            let normalized = OpenAIBaseURL.normalized(newValue) ?? OpenAIBaseURL.default
            if normalized == OpenAIBaseURL.default {
                defaults.removeObject(forKey: Self.openAIBaseURLKey)
            } else {
                defaults.set(normalized, forKey: Self.openAIBaseURLKey)
            }
        }
    }

    public var automaticClaude: Bool {
        get { defaults.object(forKey: Self.automaticClaudeKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.automaticClaudeKey) }
    }

    public var shortcut: Shortcut {
        get {
            guard let data = defaults.data(forKey: Self.shortcutKey),
                  let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data),
                  case .success = ShortcutValidator.validate(shortcut) else { return .default }
            return shortcut
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.shortcutKey) }
    }

    public var languagePair: LanguagePair {
        get {
            guard let data = defaults.data(forKey: Self.languagePairKey),
                  let pair = try? JSONDecoder().decode(LanguagePair.self, from: data),
                  pair.isValid else { return .default }
            return pair
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.languagePairKey) }
    }
}
