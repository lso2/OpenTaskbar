// HotKeyCenter.swift
// Registers global hotkeys through Carbon's RegisterEventHotKey and runs each one's closure.
// Exists because Carbon hotkeys need no Input Monitoring grant, unlike an event tap.
// Defines: HotKeyCenter, HotKey
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/HotKeyCenter.swift.md
import Carbon
import Foundation

struct HotKey: Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    // Virtual key codes and Carbon modifier bits the modules bind.
    static let f13: UInt32 = UInt32(kVK_F13)
    static let f14: UInt32 = UInt32(kVK_F14)
    static let f15: UInt32 = UInt32(kVK_F15)
    static let f16: UInt32 = UInt32(kVK_F16)
    static let left: UInt32 = UInt32(kVK_LeftArrow)
    static let right: UInt32 = UInt32(kVK_RightArrow)
    static let up: UInt32 = UInt32(kVK_UpArrow)
    static let down: UInt32 = UInt32(kVK_DownArrow)
    static let command = UInt32(cmdKey)
    static let option = UInt32(optionKey)
    static let control = UInt32(controlKey)
    static let shift = UInt32(shiftKey)
}

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    nonisolated static let signature: OSType = 0x4F54_4252 // "OTBR"

    private var handlers: [UInt32: @MainActor @Sendable () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var installed = false

    // Returns an id to unregister with, or nil when another process already holds the combination.
    func register(_ key: HotKey, _ handler: @escaping @MainActor @Sendable () -> Void) -> UInt32? {
        installHandler()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(key.keyCode, key.modifiers, EventHotKeyID(signature: HotKeyCenter.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.input.info("hotkey \(key.keyCode) with modifiers \(key.modifiers) not registered: \(status)")
            return nil
        }
        refs[id] = ref
        handlers[id] = handler
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers.removeValue(forKey: id)
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installHandler() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, nil, nil)
    }
}

// Carbon delivers hotkey events on the main thread's event loop.
private func hotKeyCallback(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKey = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
    guard status == noErr, hotKey.signature == HotKeyCenter.signature else { return OSStatus(eventNotHandledErr) }
    let id = hotKey.id
    MainActor.assumeIsolated { HotKeyCenter.shared.fire(id) }
    return noErr
}
