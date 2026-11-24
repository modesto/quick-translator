import AppKit
import Carbon.HIToolbox
import QuickTranslatorCore
import SwiftUI

final class ShortcutRecorderModel: ObservableObject {
    @Published var current: Shortcut
    @Published var isRecording = false
    @Published var message: String?
    @Published var isError = false

    var onStartRecording: () -> Void = {}
    var onCancelRecording: () -> Void = {}
    var onReset: () -> Void = {}

    init(current: Shortcut) {
        self.current = current
    }
}

@MainActor
final class ShortcutRecorder {
    var onChange: (Shortcut) -> Void = { _ in }

    let model: ShortcutRecorderModel
    private let manager: ShortcutManager
    private var keyMonitor: Any?

    init(manager: ShortcutManager) {
        self.manager = manager
        model = ShortcutRecorderModel(current: manager.current)
        model.onStartRecording = { [weak self] in self?.startRecording() }
        model.onCancelRecording = { [weak self] in self?.stopRecording() }
        model.onReset = { [weak self] in self?.apply(.default) }
    }

    func refresh() {
        model.current = manager.current
        model.message = nil
    }

    func stop() {
        stopRecording()
    }

    private func startRecording() {
        guard !model.isRecording else { return }
        manager.pause()
        model.isRecording = true
        model.message = "Pulsa la nueva combinación. Esc para cancelar."
        model.isError = false
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    private func stopRecording() {
        guard model.isRecording else { return }
        removeMonitor()
        model.isRecording = false
        model.message = nil
        if !manager.isActive { manager.activate() }
    }

    private func record(_ event: NSEvent) {
        let modifiers = Self.modifiers(from: event.modifierFlags)
        if event.keyCode == UInt16(kVK_Escape), modifiers.isEmpty {
            stopRecording()
            return
        }
        let shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, characters: event.charactersIgnoringModifiers)
        if case .failure(let error) = ShortcutValidator.validate(shortcut) {
            model.message = error.localizedDescription
            model.isError = true
            return
        }
        removeMonitor()
        model.isRecording = false
        apply(shortcut)
    }

    private func apply(_ shortcut: Shortcut) {
        switch manager.change(to: shortcut) {
        case .success(let applied):
            model.current = applied
            model.message = "Atajo cambiado a \(applied.displayString)."
            model.isError = false
            onChange(applied)
        case .failure(let error):
            model.message = error.localizedDescription
            model.isError = true
        }
    }

    private func removeMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Shortcut.Modifiers {
        var modifiers: Shortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}

struct ShortcutRecorderView: View {
    @ObservedObject var model: ShortcutRecorderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(model.isRecording ? "…" : model.current.displayString)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .frame(minWidth: 80, minHeight: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(model.isRecording ? Color.accentColor : .clear, lineWidth: 2)
                    )
                if model.isRecording {
                    Button("Cancelar", action: model.onCancelRecording)
                } else {
                    Button("Grabar nuevo atajo", action: model.onStartRecording)
                }
                Button("Restablecer", action: model.onReset)
                    .disabled(model.isRecording || model.current == .default)
                    .help("Volver a \(Shortcut.default.displayString)")
            }
            if let message = model.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(model.isError ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
