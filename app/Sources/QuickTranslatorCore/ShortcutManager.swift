import Foundation

public protocol HotKeyRegistering: AnyObject {
    func register(_ shortcut: Shortcut) -> Bool
    func unregister()
}

public enum ShortcutChangeError: Error, Equatable, LocalizedError {
    case invalid(ShortcutValidationError)
    case unavailable(String)

    public var errorDescription: String? { message(in: L10n.language) }

    public func message(in language: UILanguage) -> String {
        switch self {
        case .invalid(let error):
            return error.message(in: language)
        case .unavailable(let shortcut):
            return language.strings.shortcutUnavailable(shortcut)
        }
    }
}

public final class ShortcutManager {
    private let settings: AppSettings
    private let hotKey: HotKeyRegistering

    public private(set) var current: Shortcut
    public private(set) var isActive = false

    public init(settings: AppSettings, hotKey: HotKeyRegistering) {
        self.settings = settings
        self.hotKey = hotKey
        current = settings.shortcut
    }

    @discardableResult
    public func activate() -> Bool {
        isActive = hotKey.register(current)
        return isActive
    }

    public func pause() {
        hotKey.unregister()
        isActive = false
    }

    @discardableResult
    public func change(to shortcut: Shortcut) -> Result<Shortcut, ShortcutChangeError> {
        if case .failure(let error) = ShortcutValidator.validate(shortcut) {
            return .failure(.invalid(error))
        }
        guard hotKey.register(shortcut) else {
            activate()
            return .failure(.unavailable(shortcut.displayString))
        }
        current = shortcut
        isActive = true
        settings.shortcut = shortcut
        return .success(shortcut)
    }

    @discardableResult
    public func reset() -> Result<Shortcut, ShortcutChangeError> {
        change(to: .default)
    }
}
