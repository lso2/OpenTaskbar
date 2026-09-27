// CtrlClickLink.swift
// Rewrites Control+click and Globe+click into Command+click, which opens a link in a new tab.
// Exists because Karabiner-Elements cannot modify clicks from Apple's internal trackpad.
// Defines: CtrlClickLink
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/CtrlClickLink.swift.md
import AppKit

@MainActor
final class CtrlClickLink {
    static let shared = CtrlClickLink()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var running: Bool { tap != nil }

    // A tap that changes events needs the Accessibility grant.
    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: mask, callback: ctrlClickCallback, userInfo: nil) else {
            Log.input.info("control click tap needs Accessibility")
            return
        }
        tap = port
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, port, 0)
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    // Control or Globe without Command becomes Command, keeping Shift and Option.
    nonisolated static func rewrite(_ event: CGEvent) {
        let flags = event.flags
        guard flags.contains(.maskControl) || flags.contains(.maskSecondaryFn), !flags.contains(.maskCommand) else { return }
        var rewritten: CGEventFlags = .maskCommand
        if flags.contains(.maskShift) { rewritten.insert(.maskShift) }
        if flags.contains(.maskAlternate) { rewritten.insert(.maskAlternate) }
        event.flags = rewritten
    }
}

// Runs on the main run loop, where start placed the tap's source.
private func ctrlClickCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
                               _ userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { CtrlClickLink.shared.reenable() }
        return Unmanaged.passUnretained(event)
    }
    CtrlClickLink.rewrite(event)
    return Unmanaged.passUnretained(event)
}
