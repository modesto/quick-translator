import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private let coordinator = TranslationCoordinator()
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        hotKey = HotKey(keyCode: HotKey.keyCodeT, modifiers: [.command, .option]) { [weak self] in
            self?.coordinator.translateCurrentSelection()
        }
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
        let translateItem = NSMenuItem(title: "Traducir selección", action: #selector(translateFromMenu), keyEquivalent: "t")
        translateItem.keyEquivalentModifierMask = [.command, .option]
        translateItem.target = self
        menu.addItem(translateItem)
        menu.addItem(.separator())
        let accessibilityItem = NSMenuItem(title: "Permiso de Accesibilidad…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
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
