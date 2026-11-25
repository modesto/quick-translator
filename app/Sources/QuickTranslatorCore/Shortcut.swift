import Carbon.HIToolbox

public struct Shortcut: Codable, Equatable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    public let keyCode: UInt32
    public let modifiers: Modifiers
    public let key: String

    public init(keyCode: UInt32, modifiers: Modifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    public init(keyCode: UInt32, modifiers: Modifiers, characters: String?) {
        self.init(keyCode: keyCode, modifiers: modifiers, key: Self.keyLabel(keyCode: keyCode, characters: characters))
    }

    public static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [.command, .option], key: "T")

    public var displayString: String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols + (keyCode == UInt32(kVK_Space) ? L10n.strings.spaceKey : key)
    }

    public var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    public var menuKeyEquivalent: String? {
        guard key.count == 1, let character = key.first, !character.isWhitespace else { return nil }
        return key.lowercased()
    }

    public static func keyLabel(keyCode: UInt32, characters: String?) -> String {
        if keyCode == UInt32(kVK_Space) { return L10n.strings.spaceKey }
        if let special = specialKeys[Int(keyCode)] { return special }
        let trimmed = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "#\(keyCode)" : trimmed.uppercased()
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩",
        kVK_Tab: "⇥",
        kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",
        kVK_Home: "↖",
        kVK_End: "↘",
        kVK_PageUp: "⇞",
        kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
        kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]
}

public enum ShortcutValidationError: Error, Equatable, LocalizedError {
    case needsModifier
    case reserved(String)

    public var errorDescription: String? { message(in: L10n.language) }

    public func message(in language: UILanguage) -> String {
        switch self {
        case .needsModifier:
            return language.strings.shortcutNeedsModifier
        case .reserved(let shortcut):
            return language.strings.shortcutReserved(shortcut)
        }
    }
}

public enum ShortcutValidator {
    private static let reservedCommandKeys: Set<Int> = [
        kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z,
        kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_H, kVK_ANSI_M, kVK_Tab, kVK_Space,
    ]

    public static func validate(_ shortcut: Shortcut) -> Result<Shortcut, ShortcutValidationError> {
        guard !shortcut.modifiers.isDisjoint(with: [.command, .option, .control]) else {
            return .failure(.needsModifier)
        }
        if shortcut.modifiers == [.command], reservedCommandKeys.contains(Int(shortcut.keyCode)) {
            return .failure(.reserved(shortcut.displayString))
        }
        return .success(shortcut)
    }
}
