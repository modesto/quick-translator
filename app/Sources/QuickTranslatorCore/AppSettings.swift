import Foundation

public final class AppSettings {
    public static let automaticClaudeKey = "automaticClaudeTranslation"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var automaticClaude: Bool {
        get { defaults.object(forKey: Self.automaticClaudeKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.automaticClaudeKey) }
    }
}
