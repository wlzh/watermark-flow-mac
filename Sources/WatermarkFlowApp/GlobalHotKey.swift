import AppKit
import Carbon
import Foundation

struct HotKeyConfiguration: Codable, Equatable {
    static let defaultsKey = "globalHotKeyConfiguration"
    static let `default` = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_W),
        modifiers: UInt32(cmdKey | optionKey),
        keyLabel: "W"
    )

    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var displayName: String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value + keyLabel.uppercased()
    }

    var hasRequiredModifier: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    static func load(from defaults: UserDefaults = .standard) -> HotKeyConfiguration {
        guard let data = defaults.data(forKey: defaultsKey),
              let configuration = try? JSONDecoder().decode(HotKeyConfiguration.self, from: data),
              configuration.hasRequiredModifier else { return .default }
        return configuration
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    static func from(event: NSEvent) -> HotKeyConfiguration? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        let label = keyLabel(for: event)
        let configuration = HotKeyConfiguration(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers,
            keyLabel: label
        )
        return configuration.hasRequiredModifier && !label.isEmpty ? configuration : nil
    }

    private static func keyLabel(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return event.charactersIgnoringModifiers?.uppercased() ?? ""
        }
    }
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    private(set) var configuration: HotKeyConfiguration
    private(set) var isRegistered = false

    init(configuration: HotKeyConfiguration, action: @escaping () -> Void) {
        self.configuration = configuration
        self.action = action
        if installHandler() {
            isRegistered = register(configuration)
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    func update(configuration newConfiguration: HotKeyConfiguration) -> Bool {
        let previous = configuration
        unregister()
        if register(newConfiguration) {
            configuration = newConfiguration
            isRegistered = true
            return true
        }
        isRegistered = register(previous)
        return false
    }

    private func installHandler() -> Bool {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { owner.action() }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        return status == noErr
    }

    private func register(_ configuration: HotKeyConfiguration) -> Bool {
        let identifier = EventHotKeyID(signature: 0x57464C57, id: 1) // WFLW
        let status = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        isRegistered = false
    }
}
