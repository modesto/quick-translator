import AppKit
import ApplicationServices
import QuickTranslatorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var translateItem: NSMenuItem?
    private let settings: AppSettings
    private let coordinator: TranslationCoordinator
    private let hotKey: HotKey
    private let shortcuts: ShortcutManager
    private let shortcutWindow: ShortcutWindowController
    private let serviceProvider = ServiceProvider()

    override init() {
        let settings = AppSettings()
        let coordinator = TranslationCoordinator(settings: settings)
        let hotKey = HotKey { coordinator.translateCurrentSelection() }
        let shortcuts = ShortcutManager(settings: settings, hotKey: hotKey)
        self.settings = settings
        self.coordinator = coordinator
        self.hotKey = hotKey
        self.shortcuts = shortcuts
        shortcutWindow = ShortcutWindowController(manager: shortcuts)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        if !shortcuts.activate() {
            NSSound.beep()
            shortcutWindow.show()
        }
        shortcutWindow.onChange = { [weak self] shortcut in self?.updateTranslateItem(shortcut) }
        serviceProvider.onText = { [weak self] text in
            self?.coordinator.translate(text: text, anchor: nil)
        }
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        Accessibility.requestTrustIfNeeded()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Quick Translator")

        let menu = NSMenu()
        let translateItem = NSMenuItem(title: "Traducir selección", action: #selector(translateFromMenu), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)
        self.translateItem = translateItem
        updateTranslateItem(shortcuts.current)
        let shortcutItem = NSMenuItem(title: "Cambiar atajo…", action: #selector(openShortcutWindow), keyEquivalent: "")
        shortcutItem.target = self
        menu.addItem(shortcutItem)
        menu.addItem(.separator())
        let automaticClaudeItem = NSMenuItem(title: "Traducir con Claude automáticamente", action: #selector(toggleAutomaticClaude(_:)), keyEquivalent: "")
        automaticClaudeItem.target = self
        automaticClaudeItem.state = settings.automaticClaude ? .on : .off
        menu.addItem(automaticClaudeItem)
        menu.addItem(.separator())
        let accessibilityItem = NSMenuItem(title: "Permiso de Accesibilidad…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func updateTranslateItem(_ shortcut: Shortcut) {
        guard let translateItem else { return }
        if let keyEquivalent = shortcut.menuKeyEquivalent {
            translateItem.title = "Traducir selección"
            translateItem.keyEquivalent = keyEquivalent
            translateItem.keyEquivalentModifierMask = Self.modifierFlags(shortcut.modifiers)
        } else {
            translateItem.title = "Traducir selección (\(shortcut.displayString))"
            translateItem.keyEquivalent = ""
        }
    }

    private static func modifierFlags(_ modifiers: Shortcut.Modifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }

    @objc private func openShortcutWindow() {
        shortcutWindow.show()
    }

    @objc private func translateFromMenu() {
        coordinator.translateCurrentSelection()
    }

    @objc private func toggleAutomaticClaude(_ sender: NSMenuItem) {
        settings.automaticClaude.toggle()
        sender.state = settings.automaticClaude ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        Accessibility.openSettings()
    }
}

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }
    private static var hasPrompted = false

    static func requestTrustIfNeeded() {
        guard !hasPrompted, !isTrusted else { return }
        hasPrompted = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
