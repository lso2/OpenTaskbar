// ModuleHost.swift
// Starts and stops each init.lua behavior module to match its switch in Settings.
// Exists so every module's on and off state is decided in one readable switch.
// Defines: ModuleHost
// Notes: docs/notes/app/Sources/OpenTaskbar/App/ModuleHost.swift.md
import Foundation

@MainActor
enum ModuleHost {
    static func apply() {
        let settings = SettingsStore.shared.current
        for module in BarSettings.modules {
            let on = settings.moduleOn(module)
            switch module {
            case "ctrlClickLink": on ? CtrlClickLink.shared.start() : CtrlClickLink.shared.stop()
            case "micMuteKey": on ? MicMuteKey.module.start() : MicMuteKey.module.stop()
            case "homeEndKeys": on ? HomeEndKeys.module.start() : HomeEndKeys.module.stop()
            case "documentJumpKeys": on ? DocumentJumpKeys.module.start() : DocumentJumpKeys.module.stop()
            case "terminalPaste": on ? TerminalPaste.module.start() : TerminalPaste.module.stop()
            case "windowSnapping": on ? WindowSnapping.module.start() : WindowSnapping.module.stop()
            case "closeQuitsApp": on ? CloseQuitsApp.shared.start() : CloseQuitsApp.shared.stop()
            default: Log.app.info("no module named \(module, privacy: .public)")
            }
        }
    }

    static let labels: [String: String] = [
        "ctrlClickLink": "Control or Globe click opens links in a new tab",
        "micMuteKey": "F13 mutes the microphone",
        "homeEndKeys": "F14 and F15 are Home and End",
        "documentJumpKeys": "Control with F14 or F15 jumps the whole document",
        "terminalPaste": "F16 pastes, or sends Control+V in nano and vim",
        "windowSnapping": "Command+Option with an arrow snaps windows",
        "closeQuitsApp": "Closing an app's last window quits it",
    ]
}
