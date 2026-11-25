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
    private let recorder: ShortcutRecorder
    private let settingsWindow: SettingsWindowController
    private let serviceProvider = ServiceProvider()

    private let settingsModel: SettingsModel

    override init() {
        let settings = AppSettings()
        L10n.language = UILanguage.forLanguage(settings.languagePair.mine)
        let secrets = KeychainSecretStore()
        let translator = Translator(settings: settings, secrets: secrets)
        let coordinator = TranslationCoordinator(settings: settings, translator: translator)
        let hotKey = HotKey { coordinator.translateCurrentSelection() }
        let shortcuts = ShortcutManager(settings: settings, hotKey: hotKey)
        let recorder = ShortcutRecorder(manager: shortcuts)
        let settingsModel = SettingsModel(
            settings: settings,
            secrets: secrets,
            translator: translator,
            shortcut: recorder.model,
            onLanguagePairChange: { coordinator.languagePairDidChange() }
        )
        self.settings = settings
        self.coordinator = coordinator
        self.hotKey = hotKey
        self.shortcuts = shortcuts
        self.recorder = recorder
        self.settingsModel = settingsModel
        settingsWindow = SettingsWindowController(model: settingsModel, recorder: recorder)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()
        recorder.onChange = { [weak self] shortcut in self?.updateTranslateItem(shortcut) }
        settingsModel.onUILanguageChange = { [weak self] in
            self?.setUpMainMenu()
            self?.rebuildStatusMenu()
            self?.settingsWindow.refreshTitle()
        }
        coordinator.onOpenSettings = { [weak self] tab in self?.settingsWindow.show(tab: tab) }
        if !shortcuts.activate() {
            NSSound.beep()
            settingsWindow.show()
        }
        serviceProvider.onText = { [weak self] text in
            self?.coordinator.translate(text: text, anchor: nil)
        }
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        Accessibility.requestTrustIfNeeded()
    }

    private func setUpMainMenu() {
        let mainMenu = NSMenu()

        let strings = L10n.strings
        let appMenu = NSMenu(title: "Quick Translator")
        let settingsItem = NSMenuItem(title: strings.settingsEllipsis, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: strings.quitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editMenu = NSMenu(title: EditMenu.title())
        for (index, section) in EditMenu.sections().enumerated() {
            if index > 0 { editMenu.addItem(.separator()) }
            for spec in section {
                let item = NSMenuItem(title: spec.title, action: NSSelectorFromString(spec.action), keyEquivalent: spec.key)
                item.keyEquivalentModifierMask = spec.modifiers.reduce(into: []) { flags, modifier in
                    switch modifier {
                    case .command: flags.insert(.command)
                    case .shift: flags.insert(.shift)
                    }
                }
                editMenu.addItem(item)
            }
        }
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Quick Translator")
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let strings = L10n.strings
        let menu = NSMenu()
        let translateItem = NSMenuItem(title: strings.translateSelection, action: #selector(translateFromMenu), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)
        self.translateItem = translateItem
        updateTranslateItem(shortcuts.current)
        let settingsItem = NSMenuItem(title: strings.settingsEllipsis, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let accessibilityItem = NSMenuItem(title: strings.accessibilityPermission, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: strings.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func updateTranslateItem(_ shortcut: Shortcut) {
        guard let translateItem else { return }
        if let keyEquivalent = shortcut.menuKeyEquivalent {
            translateItem.title = L10n.strings.translateSelection
            translateItem.keyEquivalent = keyEquivalent
            translateItem.keyEquivalentModifierMask = Self.modifierFlags(shortcut.modifiers)
        } else {
            translateItem.title = "\(L10n.strings.translateSelection) (\(shortcut.displayString))"
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

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func translateFromMenu() {
        coordinator.translateCurrentSelection()
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
