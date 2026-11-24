import AppKit

final class TranslationCoordinator {
    private let translator = Translator()
    private let popup = PopupController()
    private var targetApplication: NSRunningApplication?

    init() {
        popup.onChoose = { [weak self] variant in self?.apply(variant) }
        popup.onClose = { [weak self] in self?.translator.cancel() }
    }

    func translateCurrentSelection() {
        guard Accessibility.isTrusted else {
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
        translator.translate(text) { [weak self] result in
            switch result {
            case .success(let translation):
                self?.popup.showResult(translation)
            case .failure(let error):
                self?.popup.showError(error.localizedDescription)
            }
        }
    }

    private func apply(_ variant: TranslationVariant) {
        popup.close()
        TextReplacer.replaceSelection(with: variant.text, in: targetApplication)
    }
}
