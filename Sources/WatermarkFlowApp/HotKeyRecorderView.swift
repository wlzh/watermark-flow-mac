import AppKit
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
    let configuration: HotKeyConfiguration
    let onChange: (HotKeyConfiguration) -> Void
    let onInvalid: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onInvalid: onInvalid)
    }

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.beginRecording(_:))
        button.configuration = configuration
        button.toolTip = "点击后按下新的全局快捷键"
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onInvalid = onInvalid
        if !button.isRecording { button.configuration = configuration }
    }

    final class Coordinator: NSObject {
        var onChange: (HotKeyConfiguration) -> Void
        var onInvalid: () -> Void

        init(onChange: @escaping (HotKeyConfiguration) -> Void, onInvalid: @escaping () -> Void) {
            self.onChange = onChange
            self.onInvalid = onInvalid
        }

        @objc func beginRecording(_ sender: RecorderButton) {
            sender.isRecording = true
            sender.window?.makeFirstResponder(sender)
        }
    }
}

final class RecorderButton: NSButton {
    var configuration: HotKeyConfiguration = .default {
        didSet { if !isRecording { title = configuration.displayName } }
    }
    var isRecording = false {
        didSet { title = isRecording ? "请按新快捷键…" : configuration.displayName }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 {
            isRecording = false
            return
        }
        guard let newConfiguration = HotKeyConfiguration.from(event: event) else {
            NSSound.beep()
            (target as? HotKeyRecorderView.Coordinator)?.onInvalid()
            return
        }
        configuration = newConfiguration
        isRecording = false
        (target as? HotKeyRecorderView.Coordinator)?.onChange(newConfiguration)
    }
}
