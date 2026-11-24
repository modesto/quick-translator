import AppKit
import SwiftUI

enum ProviderState<Value> {
    case idle
    case loading
    case done(Value)
    case failed(String)
}

final class PopupModel: ObservableObject {
    @Published var original = ""
    @Published var apple: ProviderState<AppleTranslation> = .loading
    @Published var claude: ProviderState<ClaudeTranslation> = .loading
    var onChoose: (String) -> Void = { _ in }
    var onClose: () -> Void = {}
    var onRequestClaude: () -> Void = {}

    static let appleKey = 1
    static let firstClaudeKey = 2

    func text(forKey key: Int) -> String? {
        if key == Self.appleKey, case .done(let translation) = apple { return translation.text }
        if case .done(let translation) = claude {
            let index = key - Self.firstClaudeKey
            if translation.result.variants.indices.contains(index) { return translation.result.variants[index].text }
        }
        return nil
    }
}

private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PopupController {
    var onChoose: (String) -> Void = { _ in }
    var onClose: () -> Void = {}
    var onRequestClaude: () -> Void = {}

    private static let width: CGFloat = 440
    private let model = PopupModel()
    private var panel: PopupPanel?
    private var anchor: NSRect = .zero
    private var keyMonitor: Any?
    private var clickMonitor: Any?

    init() {
        model.onChoose = { [weak self] text in self?.onChoose(text) }
        model.onClose = { [weak self] in self?.close() }
        model.onRequestClaude = { [weak self] in self?.onRequestClaude() }
    }

    func showLoading(original: String, anchor: NSRect?) {
        model.original = original
        model.apple = .loading
        model.claude = .idle
        present(anchor: anchor)
    }

    func showApple(_ state: ProviderState<AppleTranslation>) {
        model.apple = state
        resizeToFit()
    }

    func showClaude(_ state: ProviderState<ClaudeTranslation>) {
        model.claude = state
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
        self.anchor = anchor ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let panel = self.panel ?? makePanel()
        self.panel = panel
        resizeToFit()
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
        let size = NSSize(width: Self.width, height: content.fittingSize.height)
        panel.setFrame(NSRect(origin: origin(for: size), size: size), display: true)
    }

    private func origin(for size: NSSize) -> NSPoint {
        let margin: CGFloat = 8
        let gap: CGFloat = 6
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let spaceBelow = anchor.minY - visible.minY - margin - gap
        let spaceAbove = visible.maxY - anchor.maxY - margin - gap
        let y: CGFloat
        if size.height <= spaceBelow {
            y = anchor.minY - gap - size.height
        } else if size.height <= spaceAbove {
            y = anchor.maxY + gap
        } else {
            y = visible.maxY - margin - size.height
        }

        let x = min(max(anchor.minX, visible.minX + margin), visible.maxX - margin - size.width)
        return NSPoint(x: x, y: max(y, visible.minY + margin))
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
        if event.charactersIgnoringModifiers?.lowercased() == "c" {
            switch model.claude {
            case .idle, .failed:
                onRequestClaude()
                return true
            case .loading, .done:
                return false
            }
        }
        guard let key = event.charactersIgnoringModifiers.flatMap(Int.init),
              let text = model.text(forKey: key) else { return false }
        onChoose(text)
        return true
    }
}

private struct PopupView: View {
    @ObservedObject var model: PopupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            ProviderSection(icon: "apple.logo", title: "Apple Translation", subtitle: appleSubtitle) {
                appleContent
            }
            Divider()
            ProviderSection(icon: "sparkles", title: claudeTitle, subtitle: claudeSubtitle) {
                claudeContent
            }
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

    private var appleSubtitle: String {
        if case .done(let translation) = model.apple {
            return "En el Mac · \(translation.sourceLanguage) → \(translation.targetLanguage)"
        }
        return "En el Mac"
    }

    private var claudeTitle: String {
        if case .done(let translation) = model.claude, let modelID = translation.model {
            return Self.displayName(forModel: modelID)
        }
        return "Claude"
    }

    private var claudeSubtitle: String {
        if case .done(let translation) = model.claude {
            return "Claude Code · \(translation.result.sourceLanguage) → \(translation.result.targetLanguage)"
        }
        return "Claude Code"
    }

    @ViewBuilder
    private var appleContent: some View {
        switch model.apple {
        case .idle, .loading:
            LoadingRow()
        case .failed(let message):
            FailureRow(message: message)
        case .done(let translation):
            VariantRow(key: PopupModel.appleKey, label: nil, text: translation.text) { model.onChoose(translation.text) }
        }
    }

    @ViewBuilder
    private var claudeContent: some View {
        switch model.claude {
        case .idle:
            ClaudeRequestButton(action: model.onRequestClaude)
        case .loading:
            LoadingRow()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                FailureRow(message: message)
                ClaudeRequestButton(title: "Reintentar con Claude", action: model.onRequestClaude)
            }
        case .done(let translation):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(translation.result.variants.enumerated()), id: \.element.id) { index, variant in
                    VariantRow(key: PopupModel.firstClaudeKey + index, label: variant.label, text: variant.text) {
                        model.onChoose(variant.text)
                    }
                }
            }
        }
    }

    private static func displayName(forModel id: String) -> String {
        let parts = id.split(separator: "-").map(String.init)
        guard parts.count >= 2, parts[0] == "claude" else { return id }
        let family = parts[1].capitalized
        let version = parts.dropFirst(2).joined(separator: ".")
        return version.isEmpty ? "Claude \(family)" : "Claude \(family) \(version)"
    }
}

private struct ProviderSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            content
        }
    }
}

private struct ClaudeRequestButton: View {
    var title = "Traducir con Claude"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("\(title)  (C)", systemImage: "sparkles")
        }
        .controlSize(.small)
        .help("Pedir varias versiones a Claude (tecla C)")
    }
}

private struct LoadingRow: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Traduciendo…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FailureRow: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct VariantRow: View {
    let key: Int
    let label: String?
    let text: String
    let choose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let label {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Usar \(key)", action: choose)
                .controlSize(.small)
                .help("Sustituir la selección (tecla \(key))")
        }
    }
}
