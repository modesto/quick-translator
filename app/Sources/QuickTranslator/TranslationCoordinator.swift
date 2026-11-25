import AppKit
import QuickTranslatorCore

@MainActor
final class TranslationCoordinator {
    private let translator: Translator
    private let appleTranslator = AppleTranslator()
    private let popup = PopupController()
    private let settings: AppSettings
    private var targetApplication: NSRunningApplication?
    private var currentText = ""
    private var targetOverride: String?

    var onOpenSettings: (SettingsTab) -> Void = { _ in }

    init(settings: AppSettings, translator: Translator) {
        self.settings = settings
        self.translator = translator
        popup.onChoose = { [weak self] text in self?.apply(text) }
        popup.onRequestClaude = { [weak self] in self?.requestClaude() }
        popup.onSelectTarget = { [weak self] code in self?.retranslate(to: code) }
        popup.onOpenProviderSettings = { [weak self] in self?.onOpenSettings(.provider) }
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
        targetOverride = nil
        popup.showLoading(original: text, anchor: anchor, provider: settings.provider)
        translateWithApple()
        if settings.automaticClaude { requestClaude() }
    }

    private func retranslate(to code: String?) {
        guard code != targetOverride else { return }
        targetOverride = code
        popup.showTargetOverride(code)
        translateWithApple()
        if popup.hasRequestedClaude { requestClaude() }
    }

    private func translateWithApple() {
        popup.showApple(.loading)
        let started = Date()
        appleTranslator.translate(currentText, languagePair: settings.languagePair, targetOverride: targetOverride) { [weak self] result in
            switch result {
            case .success(let translation): self?.popup.showApple(.done(translation), elapsed: Date().timeIntervalSince(started))
            case .failure(let error):
                self?.popup.showApple(
                    .failed(error.localizedDescription),
                    offersDownload: AppleTranslatorError.offersLanguageDownload(error)
                )
            }
        }
    }

    private func requestClaude() {
        popup.showClaude(.loading)
        translator.translate(currentText, languagePair: settings.languagePair, targetOverride: targetOverride) { [weak self] result in
            switch result {
            case .success(let response): self?.popup.showClaude(.done(response))
            case .failure(let error):
                let opensSettings = (error as? TranslatorError)?.opensSettings ?? false
                self?.popup.showClaude(.failed(error.localizedDescription), offersSettings: opensSettings)
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
            panel.addButton(withTitle: L10n.strings.openSettings)
            panel.addButton(withTitle: L10n.strings.notNow)
        } else {
            panel.addButton(withTitle: L10n.strings.ok)
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
