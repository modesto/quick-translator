import AppKit
import QuickTranslatorCore
import SwiftUI

final class PopupModel: ObservableObject {
    @Published var original = ""
    @Published var apple: ProviderState<AppleTranslation> = .loading
    @Published var claude: ProviderState<ClaudeTranslation> = .loading
    @Published var appleOffersDownload = false
    @Published var targetOverride: String?
    var onChoose: (String) -> Void = { _ in }
    var onClose: () -> Void = {}
    var onRequestClaude: () -> Void = {}
    var onOpenLanguageSettings: () -> Void = {}
    var onSelectTarget: (String?) -> Void = { _ in }

    func text(forKey key: Int) -> String? {
        ChoiceKeys.text(forKey: key, apple: apple, claude: claude)
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
    var onSelectTarget: (String?) -> Void = { _ in }

    var hasRequestedClaude: Bool {
        if case .idle = model.claude { return false }
        return true
    }

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
        model.onSelectTarget = { [weak self] code in self?.onSelectTarget(code) }
        model.onOpenLanguageSettings = { [weak self] in
            self?.close()
            NSWorkspace.shared.open(LanguagePackAdvice.settingsURL)
        }
    }

    func showLoading(original: String, anchor: NSRect?) {
        model.original = original
        model.apple = .loading
        model.appleOffersDownload = false
        model.targetOverride = nil
        model.claude = .idle
        present(anchor: anchor)
    }

    func showApple(_ state: ProviderState<AppleTranslation>, offersDownload: Bool = false) {
        model.apple = state
        model.appleOffersDownload = offersDownload
        resizeToFit()
    }

    func showTargetOverride(_ code: String?) {
        model.targetOverride = code
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
        let area = { (screen: NSScreen) in ScreenArea(frame: screen.frame, visibleFrame: screen.visibleFrame) }
        return PopupPlacement.origin(
            for: size,
            anchor: anchor,
            screens: NSScreen.screens.map(area),
            mainScreen: NSScreen.main.map(area)
        )
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
            TargetLanguageMenu(selected: model.targetOverride, select: model.onSelectTarget)
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
            return ModelName.displayName(forModel: modelID)
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
            VStack(alignment: .leading, spacing: 8) {
                FailureRow(message: message)
                if model.appleOffersDownload {
                    Button(action: model.onOpenLanguageSettings) {
                        Label("Descargar idioma…", systemImage: "arrow.down.circle")
                    }
                    .controlSize(.small)
                    .help("Abre Idioma y región; pulsa \"Idiomas de traducción…\" para descargarlo")
                }
            }
        case .done(let translation):
            VariantRow(key: ChoiceKeys.apple, label: nil, text: translation.text) { model.onChoose(translation.text) }
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
                    VariantRow(key: ChoiceKeys.firstClaude + index, label: variant.label, text: variant.text) {
                        model.onChoose(variant.text)
                    }
                }
            }
        }
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

private struct TargetLanguageMenu: View {
    let selected: String?
    let select: (String?) -> Void

    private static let codes = Languages.supportedCodes.sorted {
        Languages.displayName(forCode: $0) < Languages.displayName(forCode: $1)
    }

    var body: some View {
        Menu {
            Button("Idiomas configurados") { select(nil) }
                .disabled(selected == nil)
            Divider()
            ForEach(Self.codes, id: \.self) { code in
                Toggle(Languages.displayName(forCode: code), isOn: Binding(
                    get: { selected == code },
                    set: { _ in select(code) }
                ))
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "globe")
                if let selected {
                    Text(selected.uppercased()).font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(selected == nil ? .tertiary : .secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(selected.map { "Traduciendo a \(Languages.displayName(forCode: $0)) solo esta vez" } ?? "Traducir a otro idioma solo esta vez")
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
