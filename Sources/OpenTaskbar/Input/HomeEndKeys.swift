// HomeEndKeys.swift
// F14 and F15, with Shift for selection, move to the start and end of a line in text and send Home and End elsewhere.
// Exists because Cocoa binds Home to scrolling, which Chromium gives priority over the focused text field.
// Defines: HomeEndKeys
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/HomeEndKeys.swift.md
import CoreGraphics

@MainActor
enum HomeEndKeys {
    static let module = HotKeyModule([
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f14, modifiers: 0), { send(start: true, select: false) }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f15, modifiers: 0), { send(start: false, select: false) }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f14, modifiers: HotKey.shift), { send(start: true, select: true) }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f15, modifiers: HotKey.shift), { send(start: false, select: true) }),
    ])

    private static func send(start: Bool, select: Bool) {
        Task {
            let text = await FocusedText.acceptsText()
            let shift: CGEventFlags = select ? .maskShift : []
            if text {
                KeySender.stroke(keyCode: start ? KeySender.leftArrow : KeySender.rightArrow, flags: shift.union(.maskCommand))
            } else {
                KeySender.stroke(keyCode: start ? KeySender.home : KeySender.end, flags: shift)
            }
        }
    }
}
