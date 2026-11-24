import AppKit
import SwiftUI

final class PopupModel: ObservableObject {
    enum State {
        case loading
        case result(TranslationResult)
        case error(String)
    }

    @Published var original = ""
    @Published var state: State = .loading
    var onChoose: (TranslationVariant) -> Void = { _ in }
    var onClose: () -> Void = {}
}

private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PopupController {
    var onChoose: (TranslationVariant) -> Void = { _ in }
    var onClose: () -> Void = {}

    private static let width: CGFloat = 420
    private let model = PopupModel()
    private var panel: PopupPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?

    init() {
        model.onChoose = { [weak self] variant in self?.onChoose(variant) }
        model.onClose = { [weak self] in self?.close() }
    }

    func showLoading(original: String, anchor: NSRect?) {
        model.original = original
        model.state = .loading
        present(anchor: anchor)
    }

    func showResult(_ result: TranslationResult) {
        model.state = .result(result)
        resizeToFit()
    }

    func showError(_ message: String) {
        model.state = .error(message)
        resizeToFit()
    }

    func close() {
        guard let panel else { return }
        removeMonitors()
        panel.orderOut(nil)
        self.panel = nil
        onClose()
    }

    private func present(anchor: NSRect?) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        resizeToFit()
        panel.setFrameOrigin(origin(for: panel.frame.size, anchor: anchor))
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    private func makePanel() -> PopupPanel {
        let panel = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 120),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PopupView(model: model).frame(width: Self.width))
        return panel
    }

    private func resizeToFit() {
        guard let panel, let content = panel.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = NSSize(width: Self.width, height: size.height)
        panel.setFrame(frame, display: true)
    }

    private func origin(for size: NSSize, anchor: NSRect?) -> NSPoint {
        let reference = anchor ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen = NSScreen.screens.first { $0.frame.contains(reference.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var origin = NSPoint(x: reference.minX, y: reference.minY - size.height - 6)
        if origin.y < visible.minY { origin.y = reference.maxY + 6 }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        return origin
    }

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) == true ? nil : event
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            close()
            return true
        }
        guard case .result(let result) = model.state,
              let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
              (1...result.variants.count).contains(digit) else { return false }
        onChoose(result.variants[digit - 1])
        return true
    }
}

private struct PopupView: View {
    @ObservedObject var model: PopupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            content
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(model.original)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Button(action: model.onClose) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Cerrar (Esc)")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Traduciendo…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        case .result(let result):
            VStack(alignment: .leading, spacing: 8) {
                Text("\(result.sourceLanguage) → \(result.targetLanguage)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                ForEach(Array(result.variants.enumerated()), id: \.element.id) { index, variant in
                    VariantRow(index: index + 1, variant: variant) { model.onChoose(variant) }
                }
            }
        }
    }
}

private struct VariantRow: View {
    let index: Int
    let variant: TranslationVariant
    let choose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(variant.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(variant.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Usar \(index)", action: choose)
                .controlSize(.small)
                .help("Sustituir la selección (tecla \(index))")
        }
    }
}
