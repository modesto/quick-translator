import Foundation

public final class AppSettings {
    public static let automaticClaudeKey = "automaticClaudeTranslation"
    public static let shortcutKey = "translateShortcut"
    public static let languagePairKey = "languagePair"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
