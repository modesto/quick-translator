import AppKit
import QuickTranslatorCore

@MainActor
final class TranslationCoordinator {
    private let translator = Translator()
    private let appleTranslator = AppleTranslator()
    private let popup = PopupController()
    private let settings: AppSettings
    private var targetApplication: NSRunningApplication?
    private var currentText = ""

    init(settings: AppSettings) {
        self.settings = settings
        popup.onChoose = { [weak self] text in self?.apply(text) }
        popup.onRequestClaude = { [weak self] in self?.requestClaude() }
        popup.onClose = { [weak self] in
            self?.translator.cancel()
            self?.appleTranslator.cancel()
        }
        translator.start()
        appleTranslator.warmUp(settings.languagePair)
    }

    func translateCurrentSelection() {
        guard Accessibility.isTrusted else {
            NSSound.beep()
            Accessibility.requestTrustIfNeeded()
            return
        }
        targetApplication = NSWorkspace.shared.frontmostApplication
        SelectionReader.read { [weak self] selection in
            guard let self else { return }
            guard let selection else {
                NSSound.beep()
                return
            }
            self.start(text: selection.text, anchor: selection.screenRect)
        }
    }

    func translate(text: String, anchor: NSRect?) {
        targetApplication = NSWorkspace.shared.frontmostApplication
        start(text: text, anchor: anchor)
    }

    private func start(text: String, anchor: NSRect?) {
        translator.cancel()
        currentText = text
        popup.showLoading(original: text, anchor: anchor)
        appleTranslator.translate(text, languagePair: settings.languagePair) { [weak self] result in
            switch result {
            case .success(let translation): self?.popup.showApple(.done(translation))
            case .failure(let error): self?.popup.showApple(.failed(error.localizedDescription))
            }
        }
        if settings.automaticClaude { requestClaude() }
    }

    private func requestClaude() {
        popup.showClaude(.loading)
        translator.translate(currentText, languagePair: settings.languagePair) { [weak self] result in
            switch result {
            case .success(let response): self?.popup.showClaude(.done(response))
            case .failure(let error): self?.popup.showClaude(.failed(error.localizedDescription))
            }
        }
    }

    func languagePairDidChange() {
        let pair = settings.languagePair
        Task {
            let advice = await appleTranslator.languagePackAdvice(for: pair)
            if advice == .ready {
                appleTranslator.warmUp(pair)
            } else if let alert = advice.alert(for: pair) {
                Self.show(alert)
            }
        }
    }

    private static func show(_ alert: LanguagePackAdvice.Alert) {
        let panel = NSAlert()
        panel.alertStyle = .informational
        panel.messageText = alert.title
        panel.informativeText = alert.message
        if alert.offersSettings {
            panel.addButton(withTitle: "Abrir Ajustes")
            panel.addButton(withTitle: "Ahora no")
        } else {
            panel.addButton(withTitle: "Aceptar")
        }
        NSApp.activate()
        if panel.runModal() == .alertFirstButtonReturn, alert.offersSettings {
            NSWorkspace.shared.open(LanguagePackAdvice.settingsURL)
        }
    }

    private func apply(_ text: String) {
        popup.close()
        TextReplacer.replaceSelection(with: text, in: targetApplication)
    }
}
