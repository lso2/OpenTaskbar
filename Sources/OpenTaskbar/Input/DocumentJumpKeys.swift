// DocumentJumpKeys.swift
// Control with F14 or F15 jumps to the start or end of the whole document, with Shift to select.
// Exists as the port of the document jump bindings in init.lua.
// Defines: DocumentJumpKeys
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/DocumentJumpKeys.swift.md
import CoreGraphics

@MainActor
enum DocumentJumpKeys {
    static let module = HotKeyModule([
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f14, modifiers: HotKey.control), {
            KeySender.stroke(keyCode: KeySender.upArrow, flags: .maskCommand)
        }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f15, modifiers: HotKey.control), {
            KeySender.stroke(keyCode: KeySender.downArrow, flags: .maskCommand)
        }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f14, modifiers: HotKey.control | HotKey.shift), {
            KeySender.stroke(keyCode: KeySender.upArrow, flags: [.maskCommand, .maskShift])
        }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f15, modifiers: HotKey.control | HotKey.shift), {
            KeySender.stroke(keyCode: KeySender.downArrow, flags: [.maskCommand, .maskShift])
        }),
    ])
}
