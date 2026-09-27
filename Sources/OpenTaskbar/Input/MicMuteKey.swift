// MicMuteKey.swift
// F13 toggles the default input device's mute and flashes MIC MUTED or MIC LIVE.
// Exists because macOS has no system microphone mute, so the device itself is muted.
// Defines: MicMuteKey
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/MicMuteKey.swift.md
import AppKit

@MainActor
enum MicMuteKey {
    static let module = HotKeyModule([
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f13, modifiers: 0), { toggle() }),
    ])

    // The flash reports the state read back after the change, not the state asked for.
    private static func toggle() {
        let control = AudioControl.input
        guard control.state != nil || CoreAudio.defaultDevice(input: true) != nil else {
            FlashAlert.shared.show("No input device", color: FlashAlert.red)
            return
        }
        control.toggleMute()
        let muted = control.state?.muted ?? false
        FlashAlert.shared.show(muted ? "MIC MUTED" : "MIC LIVE", color: muted ? FlashAlert.red : FlashAlert.green)
    }
}
