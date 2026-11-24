import AppKit

final class ServiceProvider: NSObject {
    var onText: ((String) -> Void)?

    @objc func translateSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No hay texto seleccionado" as NSString
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onText?(text)
        }
    }
}
