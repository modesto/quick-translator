import AppKit
import QuickTranslatorCore
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    enum TestState: Equatable {
        case idle
        case running
        case passed(String)
        case failed(String)
    }

    @Published var provider: TranslationProviderKind
    @Published var claudeAPIModel: String
    @Published var openAIModel: String
    @Published var openAIModelDraft: String
    @Published var openAIBaseURL: String
    @Published var openAIBaseURLDraft: String
    @Published var openAIBaseURLInvalid = false
    @Published var automatic: Bool
    @Published var languagePair: LanguagePair
    @Published var keyDrafts: [TranslationProviderKind: String] = [:]
    @Published var savedKeys: Set<TranslationProviderKind> = []
    @Published var testState: TestState = .idle
    @Published private(set) var uiLanguage = L10n.language

    var onUILanguageChange: (() -> Void)?

    let shortcut: ShortcutRecorderModel

    private let settings: AppSettings
    private let secrets: SecretStore
    private let translator: Translator
    private let onLanguagePairChange: () -> Void

    init(settings: AppSettings, secrets: SecretStore, translator: Translator, shortcut: ShortcutRecorderModel, onLanguagePairChange: @escaping () -> Void) {
        self.settings = settings
        self.secrets = secrets
        self.translator = translator
        self.shortcut = shortcut
        self.onLanguagePairChange = onLanguagePairChange
        provider = settings.provider
        claudeAPIModel = settings.claudeAPIModel
        openAIModel = settings.openAIModel
        openAIModelDraft = settings.openAIModel
        openAIBaseURL = settings.openAIBaseURL
        openAIBaseURLDraft = settings.openAIBaseURL
        automatic = settings.automaticClaude
        languagePair = settings.languagePair
        reloadKeys()
    }

    func reloadKeys() {
        savedKeys = Set(TranslationProviderKind.allCases.filter { kind in
            kind.keyAccount.flatMap(secrets.secret(for:)).map { !$0.isEmpty } ?? false
        })
        keyDrafts = [:]
    }

    func selectProvider(_ kind: TranslationProviderKind) {
        guard kind != settings.provider else { return }
        provider = kind
        settings.provider = kind
        testState = .idle
        translator.restart()
    }

    func selectClaudeAPIModel(_ id: String) {
        guard id != settings.claudeAPIModel else { return }
        claudeAPIModel = id
        settings.claudeAPIModel = id
        testState = .idle
        translator.restart()
    }

    func selectOpenAIModel(_ id: String) {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        openAIModelDraft = id.isEmpty ? settings.openAIModel : id
        guard !id.isEmpty, id != settings.openAIModel else { return }
        openAIModel = id
        settings.openAIModel = id
        testState = .idle
        translator.restart()
    }

    var isProviderReady: Bool {
        ProviderSetup.isReady(provider, hasKey: savedKeys.contains(provider), openAIBaseURL: openAIBaseURL, openAIModel: openAIModel)
    }

    func saveOpenAIBaseURL() {
        guard let normalized = OpenAIBaseURL.normalized(openAIBaseURLDraft) else {
            openAIBaseURLInvalid = true
            return
        }
        openAIBaseURLInvalid = false
        openAIBaseURLDraft = normalized
        guard normalized != settings.openAIBaseURL else { return }
        settings.openAIBaseURL = normalized
        openAIBaseURL = normalized
        openAIModel = settings.openAIModel
        openAIModelDraft = openAIModel
        testState = .idle
        translator.restart()
    }

    func setAutomatic(_ value: Bool) {
        automatic = value
        settings.automaticClaude = value
    }

    func setMine(_ code: String) {
        updatePair(settings.languagePair.withMine(code))
    }

    func setTarget(_ code: String) {
        updatePair(settings.languagePair.withTarget(code))
    }

    func saveKey(for kind: TranslationProviderKind) {
        guard let account = kind.keyAccount else { return }
        let value = keyDrafts[kind]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        secrets.setSecret(value.isEmpty ? nil : value, for: account)
        reloadKeys()
        testState = .idle
        translator.restart()
    }

    func removeKey(for kind: TranslationProviderKind) {
        guard let account = kind.keyAccount else { return }
        secrets.setSecret(nil, for: account)
        reloadKeys()
        testState = .idle
        translator.restart()
    }

    func testProvider() {
        let kind = provider
        testState = .running
        translator.translate(L10n.strings.testSentence, languagePair: settings.languagePair, provider: kind) { [weak self] result in
            guard let self, self.provider == kind else { return }
            switch result {
            case .success(let translation):
                let first = translation.result.variants.first?.text ?? ""
                let time = translation.elapsed.map { Elapsed.format($0) } ?? ""
                self.testState = .passed("\(time) · «\(first)»")
            case .failure(let error):
                self.testState = .failed(error.localizedDescription)
            }
        }
    }

    private func updatePair(_ pair: LanguagePair) {
        guard pair != settings.languagePair else { return }
        settings.languagePair = pair
        languagePair = pair
        let language = UILanguage.forLanguage(pair.mine)
        if language != L10n.language {
            L10n.language = language
            uiLanguage = language
            onUILanguageChange?()
        }
        onLanguagePairChange()
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private let recorder: ShortcutRecorder
    private var window: NSWindow?

    init(model: SettingsModel, recorder: ShortcutRecorder) {
        self.model = model
        self.recorder = recorder
    }

    func show(tab: SettingsTab = .general) {
        let window = self.window ?? makeWindow()
        self.window = window
        recorder.refresh()
        model.reloadKeys()
        SettingsTabSelection.shared.tab = tab
        if !window.isVisible { window.center() }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate()
        DispatchQueue.main.async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func refreshTitle() {
        window?.title = L10n.strings.settingsTitle
    }

    func windowWillClose(_ notification: Notification) {
        recorder.stop()
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.strings.settingsTitle
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView(model: model, selection: SettingsTabSelection.shared))
        return window
    }
}

enum SettingsTab: Hashable {
    case general
    case provider
}

@MainActor
final class SettingsTabSelection: ObservableObject {
    static let shared = SettingsTabSelection()
    @Published var tab: SettingsTab = .general
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var selection: SettingsTabSelection

    var body: some View {
        TabView(selection: $selection.tab) {
            GeneralSettingsView(model: model)
                .tabItem { Label(L10n.strings.generalTab, systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ProviderSettingsView(model: model)
                .tabItem { Label(L10n.strings.providerTab, systemImage: "sparkles") }
                .tag(SettingsTab.provider)
        }
        .id(model.uiLanguage)
        .frame(width: 560, height: 500)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: SettingsModel

    private static var codes: [String] { Languages.supportedCodes.sorted {
        Languages.displayName(forCode: $0) < Languages.displayName(forCode: $1)
    } }

    var body: some View {
        Form {
            Section(L10n.strings.shortcutSection) {
                ShortcutRecorderView(model: model.shortcut)
            }
            Section {
                Picker(L10n.strings.myLanguage, selection: Binding(get: { model.languagePair.mine }, set: model.setMine)) {
                    ForEach(Self.codes, id: \.self) { Text(Languages.displayName(forCode: $0)).tag($0) }
                }
                Picker(L10n.strings.targetLanguage, selection: Binding(get: { model.languagePair.target }, set: model.setTarget)) {
                    ForEach(Self.codes, id: \.self) { Text(Languages.displayName(forCode: $0)).tag($0) }
                }
            } header: {
                Text(L10n.strings.languagesSection)
            } footer: {
                Text(L10n.strings.languagesFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ProviderSettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker(L10n.strings.provider, selection: Binding(get: { model.provider }, set: model.selectProvider)) {
                    ForEach(TranslationProviderKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle(L10n.strings.translateAutomatically, isOn: Binding(get: { model.automatic }, set: model.setAutomatic))
            } header: {
                Text(L10n.strings.variantsSection)
            } footer: {
                Text(model.automatic
                    ? L10n.strings.automaticFooter(model.provider.displayName)
                    : L10n.strings.manualFooter(model.provider.displayName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(model.provider.displayName) {
                providerDetails
                HStack {
                    Button(L10n.strings.test, action: model.testProvider)
                        .disabled(model.testState == .running || !model.isProviderReady)
                    testResult
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var providerDetails: some View {
        switch model.provider {
        case .claudeCode:
            Text(L10n.strings.claudeCodeDetails)
                .font(.callout)
                .foregroundStyle(.secondary)
        case .claudeAPI:
            KeyField(model: model, kind: .claudeAPI, placeholder: "sk-ant-…", help: L10n.strings.billedSeparately)
            Picker(L10n.strings.model, selection: Binding(get: { model.claudeAPIModel }, set: model.selectClaudeAPIModel)) {
                ForEach(ModelOption.claude) { option in
                    Text("\(option.displayName) — \(option.note)").tag(option.id)
                }
            }
        case .openAI:
            OpenAIBaseURLField(model: model)
            KeyField(
                model: model,
                kind: .openAI,
                placeholder: "sk-…",
                help: OpenAIBaseURL.isOfficial(model.openAIBaseURL)
                    ? L10n.strings.billedByUsage
                    : L10n.strings.keyOptional
            )
            OpenAIModelField(model: model)
        case .deepL:
            KeyField(model: model, kind: .deepL, placeholder: "xxxxxxxx-…:fx", help: L10n.strings.deepLHelp)
        }
    }

    @ViewBuilder
    private var testResult: some View {
        switch model.testState {
        case .idle:
            EmptyView()
        case .running:
            ProgressView().controlSize(.small)
        case .passed(let summary):
            Label(summary, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .lineLimit(2)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(3)
        }
    }
}

private struct OpenAIBaseURLField: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(L10n.strings.apiURL, text: $model.openAIBaseURLDraft, prompt: Text(OpenAIBaseURL.default))
                    .onSubmit(model.saveOpenAIBaseURL)
                Button(L10n.strings.save, action: model.saveOpenAIBaseURL)
                    .disabled(OpenAIBaseURL.normalized(model.openAIBaseURLDraft) == model.openAIBaseURL)
            }
            if model.openAIBaseURLInvalid {
                Text(L10n.strings.invalidURL)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(OpenAIBaseURL.isOfficial(model.openAIBaseURL)
                    ? L10n.strings.officialURLHelp
                    : L10n.strings.compatibleURLHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OpenAIModelField: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack {
            TextField(L10n.strings.model, text: $model.openAIModelDraft, prompt: Text(L10n.strings.modelPlaceholder))
                .onSubmit { model.selectOpenAIModel(model.openAIModelDraft) }
            Menu {
                ForEach(ModelOption.openAI) { option in
                    Button("\(option.displayName) — \(option.note)") { model.selectOpenAIModel(option.id) }
                }
            } label: {
                Image(systemName: "list.bullet")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L10n.strings.openAIModelsHelp)
            Button(L10n.strings.save) { model.selectOpenAIModel(model.openAIModelDraft) }
                .disabled(model.openAIModelDraft.trimmingCharacters(in: .whitespacesAndNewlines) == model.openAIModel)
        }
    }
}

private struct KeyField: View {
    @ObservedObject var model: SettingsModel
    let kind: TranslationProviderKind
    let placeholder: String
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SecureField(model.savedKeys.contains(kind) ? L10n.strings.keySaved : placeholder, text: Binding(
                    get: { model.keyDrafts[kind] ?? "" },
                    set: { model.keyDrafts[kind] = $0 }
                ))
                .onSubmit { model.saveKey(for: kind) }
                Button(L10n.strings.save) { model.saveKey(for: kind) }
                    .disabled((model.keyDrafts[kind] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
                if model.savedKeys.contains(kind) {
                    Button(L10n.strings.remove, role: .destructive) { model.removeKey(for: kind) }
                }
            }
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let page = kind.keyPage {
                Link(destination: page.url) {
                    Label(page.title, systemImage: "arrow.up.right.square")
                }
                .font(.caption)
            }
        }
    }
}
