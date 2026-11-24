import AppKit

@MainActor
final class TranslationCoordinator {
    private let translator = Translator()
    private let appleTranslator = AppleTranslator()
    private let popup = PopupController()
    private var targetApplication: NSRunningApplication?

    init() {
        popup.onChoose = { [weak self] text in self?.apply(text) }
        popup.onClose = { [weak self] in
            self?.translator.cancel()
            self?.appleTranslator.cancel()
        }
        translator.start()
        appleTranslator.warmUp()
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
        popup.showLoading(original: text, anchor: anchor)
        appleTranslator.translate(text) { [weak self] result in
            switch result {
            case .success(let translation): self?.popup.showApple(.done(translation))
            case .failure(let error): self?.popup.showApple(.failed(error.localizedDescription))
            }
        }
        translator.translate(text) { [weak self] result in
            switch result {
            case .success(let response): self?.popup.showClaude(.done(response))
            case .failure(let error): self?.popup.showClaude(.failed(error.localizedDescription))
            }
        }
    }

    private func apply(_ text: String) {
        popup.close()
        TextReplacer.replaceSelection(with: text, in: targetApplication)
    }
}
