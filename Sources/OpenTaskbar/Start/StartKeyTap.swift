// StartKeyTap.swift
// Opens the Start panel when one modifier key is tapped on its own, and learns which key that is.
// Exists as the port of bottombar-tap.lua, on a listen-only event tap the app delegate keeps for the app's lifetime.
// Defines: StartKeyTap
// Notes: docs/notes/app/Sources/OpenTaskbar/Start/StartKeyTap.swift.md
import AppKit

@MainActor
final class StartKeyTap {
    static let shared = StartKeyTap()

    // Released within this many seconds, with nothing else pressed meanwhile, counts as a tap.
    static let window: TimeInterval = 0.4

    private var tap: CFMachPort?
    private var downAt: Date?
    private var downCode: Int64 = 0
    private var downFlag: String?
    private var used = false

    static let flags: [(name: String, flag: CGEventFlags)] = [
        ("cmd", .maskCommand), ("alt", .maskAlternate), ("ctrl", .maskControl), ("fn", .maskSecondaryFn),
    ]

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask = [CGEventType.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: startKeyCallback, userInfo: nil) else {
            Log.input.info("start key tap needs Input Monitoring")
            return
        }
        tap = port
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    // Exactly one of the four modifiers, and no Shift, is what a tap looks like when the key goes down.
    private func loneModifier(_ flags: CGEventFlags) -> String? {
        guard !flags.contains(.maskShift) else { return nil }
        let held = StartKeyTap.flags.filter { flags.contains($0.flag) }
        return held.count == 1 ? held[0].name : nil
    }

    fileprivate func handle(_ type: CGEventType, flags: CGEventFlags, code: Int64) {
        let settings = SettingsStore.shared.current
        guard settings.startTapMode != "off" else { return }

        guard type == .flagsChanged else {
            used = true
            return
        }

        if let lone = loneModifier(flags) {
            downAt = Date()
            downCode = code
            downFlag = lone
            used = false
            return
        }

        let anyHeld = StartKeyTap.flags.contains { flags.contains($0.flag) } || flags.contains(.maskShift)
        guard !anyHeld else { return }
        defer { downAt = nil; downFlag = nil }
        guard let downAt, let downFlag, !used, Date().timeIntervalSince(downAt) < StartKeyTap.window else { return }

        if settings.startTapMode == "learn" {
            let code = Int(downCode)
            SettingsStore.shared.update { settings in
                settings.startTapMode = "key"
                settings.startTapFlag = downFlag
                settings.startTapCode = code
            }
            FlashAlert.shared.show("The Start panel now opens on this key", color: FlashAlert.neutral, seconds: 1.6)
        } else if downFlag == settings.startTapFlag && Int(downCode) == settings.startTapCode {
            StartPanel.shared.openAtPointer()
        }
    }
}

// Runs on the main run loop, where start placed the tap's source.
private func startKeyCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
                              _ userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    MainActor.assumeIsolated {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            StartKeyTap.shared.reenable()
        } else {
            StartKeyTap.shared.handle(type, flags: flags, code: code)
        }
    }
    return Unmanaged.passUnretained(event)
}
