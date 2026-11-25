import AppKit
import QuickTranslatorCore

final class ServiceProvider: NSObject {
    var onText: ((String) -> Void)?

    @objc func translateSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = L10n.strings.noSelectedText as NSString
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onText?(text)
        }
    }
}
