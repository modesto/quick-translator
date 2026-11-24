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
    public static let title = "Edición"

    public static let sections: [[MenuItemSpec]] = [
        [
            MenuItemSpec(title: "Deshacer", action: "undo:", key: "z"),
            MenuItemSpec(title: "Rehacer", action: "redo:", key: "z", modifiers: [.command, .shift]),
        ],
        [
            MenuItemSpec(title: "Cortar", action: "cut:", key: "x"),
            MenuItemSpec(title: "Copiar", action: "copy:", key: "c"),
            MenuItemSpec(title: "Pegar", action: "paste:", key: "v"),
            MenuItemSpec(title: "Seleccionar todo", action: "selectAll:", key: "a"),
        ],
    ]
}
