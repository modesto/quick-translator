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
    @Published var automatic: Bool
    @Published var languagePair: LanguagePair
    @Published var keyDrafts: [TranslationProviderKind: String] = [:]
    @Published var savedKeys: Set<TranslationProviderKind> = []
    @Published var testState: TestState = .idle

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
        translator.translate("Hola, ¿nos vemos mañana a primera hora?", languagePair: settings.languagePair, provider: kind) { [weak self] result in
            guard let self, self.provider == kind else { return }
            switch result {
            case .success(let translation):
                let first = translation.result.variants.first?.text ?? ""
                let time = translation.elapsed.map(Elapsed.format) ?? ""
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

    func windowWillClose(_ notification: Notification) {
        recorder.stop()
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ajustes de Quick Translator"
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
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ProviderSettingsView(model: model)
                .tabItem { Label("Proveedor", systemImage: "sparkles") }
                .tag(SettingsTab.provider)
        }
        .frame(width: 520, height: 420)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: SettingsModel

    private static let codes = Languages.supportedCodes.sorted {
        Languages.displayName(forCode: $0) < Languages.displayName(forCode: $1)
    }

    var body: some View {
        Form {
            Section("Atajo de teclado") {
                ShortcutRecorderView(model: model.shortcut)
            }
            Section {
                Picker("Mi idioma", selection: Binding(get: { model.languagePair.mine }, set: model.setMine)) {
                    ForEach(Self.codes, id: \.self) { Text(Languages.displayName(forCode: $0)).tag($0) }
                }
                Picker("Idioma destino", selection: Binding(get: { model.languagePair.target }, set: model.setTarget)) {
                    ForEach(Self.codes, id: \.self) { Text(Languages.displayName(forCode: $0)).tag($0) }
                }
            } header: {
                Text("Idiomas")
            } footer: {
                Text("Lo que esté en tu idioma se traduce al destino; cualquier otro idioma, al tuyo.")
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
                Picker("Proveedor", selection: Binding(get: { model.provider }, set: model.selectProvider)) {
                    ForEach(TranslationProviderKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Traducir automáticamente", isOn: Binding(get: { model.automatic }, set: model.setAutomatic))
            } header: {
                Text("Varias versiones")
            } footer: {
                Text(model.automatic
                    ? "Se pide a \(model.provider.displayName) en cada traducción, junto a Apple Translation."
                    : "El pop-up muestra un botón para pedir las versiones a \(model.provider.displayName) (tecla C).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(model.provider.displayName) {
                providerDetails
                HStack {
                    Button("Probar", action: model.testProvider)
                        .disabled(model.testState == .running || !isConfigured)
                    testResult
                }
            }
        }
        .formStyle(.grouped)
    }

    private var isConfigured: Bool {
        model.provider.keyAccount == nil || model.savedKeys.contains(model.provider)
    }

    @ViewBuilder
    private var providerDetails: some View {
        switch model.provider {
        case .claudeCode:
            Text("Usa tu sesión de Claude Code; no necesita clave. Modelo: Claude Haiku 5.5.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .claudeAPI:
            KeyField(model: model, kind: .claudeAPI, placeholder: "sk-ant-…", help: "Se factura aparte de tu suscripción.")
            Picker("Modelo", selection: Binding(get: { model.claudeAPIModel }, set: model.selectClaudeAPIModel)) {
                ForEach(ClaudeModelOption.all) { option in
                    Text("\(option.displayName) — \(option.note)").tag(option.id)
                }
            }
        case .deepL:
            KeyField(model: model, kind: .deepL, placeholder: "xxxxxxxx-…:fx", help: "Las claves gratuitas terminan en :fx. Da una versión formal y otra informal cuando el idioma lo admite.")
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

private struct KeyField: View {
    @ObservedObject var model: SettingsModel
    let kind: TranslationProviderKind
    let placeholder: String
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SecureField(model.savedKeys.contains(kind) ? "Clave guardada en el Llavero" : placeholder, text: Binding(
                    get: { model.keyDrafts[kind] ?? "" },
                    set: { model.keyDrafts[kind] = $0 }
                ))
                .onSubmit { model.saveKey(for: kind) }
                Button("Guardar") { model.saveKey(for: kind) }
                    .disabled((model.keyDrafts[kind] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
                if model.savedKeys.contains(kind) {
                    Button("Borrar", role: .destructive) { model.removeKey(for: kind) }
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
