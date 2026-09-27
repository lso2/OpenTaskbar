// FlashAlert.swift
// A large centered message that shows for a second and fades, such as MIC MUTED.
// Exists as the port of the hs.alert call init.lua used for the microphone key.
// Defines: FlashAlert
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/FlashAlert.swift.md
import AppKit

@MainActor
final class FlashAlert {
    static let shared = FlashAlert()

    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var timer: Timer?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        let content = NSView()
        content.wantsLayer = true
        content.layer?.cornerRadius = 14
        label.font = NSFont.systemFont(ofSize: 40, weight: .regular)
        label.textColor = .white
        content.addSubview(label)
        panel.contentView = content
    }

    // Colors from init.lua: a dark red for muted, a dark green for live.
    static let red = NSColor(calibratedRed: 0.55, green: 0.05, blue: 0.05, alpha: 0.92)
    static let green = NSColor(calibratedRed: 0.05, green: 0.42, blue: 0.18, alpha: 0.92)
    static let neutral = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.92)

    func show(_ text: String, color: NSColor, seconds: TimeInterval = 1.1) {
        label.stringValue = text
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 48, height: label.frame.height + 28)
        label.frame.origin = NSPoint(x: 24, y: 14)
        panel.contentView?.layer?.backgroundColor = color.cgColor
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let area = screen?.frame ?? .zero
        panel.setFrame(NSRect(x: area.midX - (size.width / 2), y: area.midY - (size.height / 2),
                              width: size.width, height: size.height), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    FlashAlert.shared.panel.animator().alphaValue = 0
                } completionHandler: {
                    MainActor.assumeIsolated { FlashAlert.shared.panel.orderOut(nil) }
                }
            }
        }
    }
}
