// TerminalPaste.swift
// F16 pastes at a prompt and sends Control+V inside a full screen terminal program such as nano or vim.
// Exists because terminal window titles name the running program, which decides what the key should mean.
// Defines: TerminalPaste
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/TerminalPaste.swift.md
import CoreGraphics

@MainActor
enum TerminalPaste {
    static let fullScreenPrograms: Set<String> = [
        "nano", "pico", "vim", "vi", "nvim", "emacs", "less", "more", "man", "htop", "top", "btop",
        "tmux", "screen", "vimdiff", "crontab",
    ]

    static let module = HotKeyModule([
        HotKeyModule.Binding(HotKey(keyCode: HotKey.f16, modifiers: 0), { paste() }),
    ])

    private static func paste() {
        Task {
            let title = await FocusedText.focusedWindowTitle()?.lowercased() ?? ""
            let words = title.split { !$0.isLetter }.map(String.init)
            let inProgram = words.contains { fullScreenPrograms.contains($0) }
            KeySender.stroke(keyCode: KeySender.v, flags: inProgram ? .maskControl : .maskCommand)
        }
    }
}
