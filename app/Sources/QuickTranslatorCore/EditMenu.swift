public struct MenuItemSpec: Equatable, Sendable {
    public enum Modifier: Sendable { case command, shift }

    public let title: String
    public let action: String
    public let key: String
    public let modifiers: [Modifier]

    public init(title: String, action: String, key: String, modifiers: [Modifier] = [.command]) {
        self.title = title
        self.action = action
        self.key = key
        self.modifiers = modifiers
    }
}

/// An accessory app has no menu bar, but text fields only get ⌘C/⌘V/⌘X/⌘A/⌘Z through the main menu's key equivalents.
public enum EditMenu {
    public static func title(in language: UILanguage = L10n.language) -> String { language.strings.editMenu }

    public static func sections(in language: UILanguage = L10n.language) -> [[MenuItemSpec]] {
        let strings = language.strings
        return [
            [
                MenuItemSpec(title: strings.undo, action: "undo:", key: "z"),
                MenuItemSpec(title: strings.redo, action: "redo:", key: "z", modifiers: [.command, .shift]),
            ],
            [
                MenuItemSpec(title: strings.cut, action: "cut:", key: "x"),
                MenuItemSpec(title: strings.copy, action: "copy:", key: "c"),
                MenuItemSpec(title: strings.paste, action: "paste:", key: "v"),
                MenuItemSpec(title: strings.selectAll, action: "selectAll:", key: "a"),
            ],
        ]
    }
}
