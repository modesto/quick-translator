import AppKit
import QuickTranslatorCore
import SwiftUI

final class PopupModel: ObservableObject {
    @Published var original = ""
    @Published var apple: ProviderState<AppleTranslation> = .loading
    @Published var claude: ProviderState<ClaudeTranslation> = .loading
    @Published var provider: TranslationProviderKind = .claudeCode
    @Published var appleElapsed: TimeInterval?
    @Published var claudeOffersSettings = false
    @Published var appleOffersDownload = false
    @Published var targetOverride: String?
    var onChoose: (String) -> Void = { _ in }
    var onClose: () -> Void = {}
    var onRequestClaude: () -> Void = {}
    var onOpenProviderSettings: () -> Void = {}
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
    var onOpenProviderSettings: () -> Void = {}

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
        model.onOpenProviderSettings = { [weak self] in
            self?.close()
            self?.onOpenProviderSettings()
        }
        model.onOpenLanguageSettings = { [weak self] in
            self?.close()
            NSWorkspace.shared.open(LanguagePackAdvice.settingsURL)
        }
    }

    func showLoading(original: String, anchor: NSRect?, provider: TranslationProviderKind) {
        model.original = original
        model.provider = provider
        model.appleElapsed = nil
        model.claudeOffersSettings = false
        model.apple = .loading
        model.appleOffersDownload = false
        model.targetOverride = nil
        model.claude = .idle
        present(anchor: anchor)
    }

    func showApple(_ state: ProviderState<AppleTranslation>, offersDownload: Bool = false, elapsed: TimeInterval? = nil) {
        model.apple = state
        model.appleElapsed = elapsed
        model.appleOffersDownload = offersDownload
        resizeToFit()
    }

    func showTargetOverride(_ code: String?) {
        model.targetOverride = code
        resizeToFit()
    }

    func showClaude(_ state: ProviderState<ClaudeTranslation>, offersSettings: Bool = false) {
        model.claude = state
        model.claudeOffersSettings = offersSettings
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
            ProviderSection(icon: "apple.logo", title: "Apple Translation", subtitle: appleSubtitle, elapsed: model.appleElapsed) {
                appleContent
            }
            Divider()
            ProviderSection(icon: model.provider.symbolName, title: claudeTitle, subtitle: claudeSubtitle, elapsed: claudeElapsed) {
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
            .help(L10n.strings.close)
        }
    }

    private var appleSubtitle: String {
        if case .done(let translation) = model.apple {
            return "\(L10n.strings.onDevice) · \(translation.sourceLanguage) → \(translation.targetLanguage)"
        }
        return L10n.strings.onDevice
    }

    private var claudeTitle: String {
        if case .done(let translation) = model.claude, translation.provider.showsModelName, let modelID = translation.model {
            return "\(translation.provider.displayName) · \(ModelName.displayName(forModel: modelID))"
        }
        return model.provider.displayName
    }

    private var claudeSubtitle: String {
        if case .done(let translation) = model.claude {
            return "\(Languages.displayName(forEnglishName: translation.result.sourceLanguage)) → \(Languages.displayName(forEnglishName: translation.result.targetLanguage))"
        }
        return ""
    }

    private var claudeElapsed: TimeInterval? {
        if case .done(let translation) = model.claude { return translation.elapsed }
        return nil
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
                        Label(L10n.strings.downloadLanguage, systemImage: "arrow.down.circle")
                    }
                    .controlSize(.small)
                    .help(L10n.strings.downloadLanguageHelp)
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
            ClaudeRequestButton(title: L10n.strings.translateWith(model.provider.displayName), action: model.onRequestClaude)
        case .loading:
            LoadingRow()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                FailureRow(message: message)
                HStack {
                    if model.claudeOffersSettings {
                        Button(action: model.onOpenProviderSettings) {
                            Label(L10n.strings.settingsEllipsis, systemImage: "gearshape")
                        }
                        .controlSize(.small)
                    }
                    ClaudeRequestButton(title: L10n.strings.retry, action: model.onRequestClaude)
                }
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
    var elapsed: TimeInterval?
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
                Spacer(minLength: 4)
                if let elapsed {
                    Text(Elapsed.format(elapsed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .help(L10n.strings.responseTime)
                }
            }
            content
        }
    }
}

private struct TargetLanguageMenu: View {
    let selected: String?
    let select: (String?) -> Void

    private static var codes: [String] { Languages.supportedCodes.sorted {
        Languages.displayName(forCode: $0) < Languages.displayName(forCode: $1)
    } }

    var body: some View {
        Menu {
            Button(L10n.strings.configuredLanguages) { select(nil) }
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
        .help(selected.map { L10n.strings.translatingOnceTo(Languages.name(forCode: $0)) } ?? L10n.strings.translateOnceHelp)
    }
}

private struct ClaudeRequestButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("\(title)  (C)", systemImage: "sparkles")
        }
        .controlSize(.small)
        .help(L10n.strings.requestVariantsHelp)
    }
}

private struct LoadingRow: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(L10n.strings.translating).foregroundStyle(.secondary)
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
            Button(L10n.strings.use("\(key)"), action: choose)
                .controlSize(.small)
                .help(L10n.strings.useHelp("\(key)"))
        }
    }
}
