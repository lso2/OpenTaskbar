// BarTooltip.swift
// The one line tooltip above the bar, with wording read from live state when the pointer settles.
// Exists as the port of bottombar-tooltip.lua.
// Defines: BarTooltip
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/BarTooltip.swift.md
import AppKit

@MainActor
final class BarTooltip {
    static let shared = BarTooltip()
    static let delay: TimeInterval = 0.4

    private let panel = PopupPanel(size: NSSize(width: 100, height: 24))
    private let label = NSTextField(labelWithString: "")
    private var key: String?
    private var timer: Timer?

    private init() {
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.exclusive = false
        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.97).cgColor
        label.font = NSFont.menuBarFont(ofSize: 12)
        label.textColor = NSColor(white: 1, alpha: 0.95)
        content.addSubview(label)
        panel.contentView = content
    }

    // Each is read at the moment the tooltip draws, never cached.
    static func text(_ key: String) -> String? {
        switch key {
        case "start": return "Start"
        case "search": return "Search"
        case "taskView": return "Mission Control"
        case "battery": return Battery.shared.summary
        case "wifi": return WiFi.shared.summary
        case "volume": return AudioControl.output.summary
        case "microphone": return AudioControl.input.summary
        case "display": return DisplayBrightness.summary
        case "keyboard": return KeyboardBacklight.shared.summary
        case "clock":
            let formatter = DateFormatter()
            formatter.dateFormat = ClockPreference.hour24 ? "EEEE, MMMM d, yyyy   HH:mm:ss" : "EEEE, MMMM d, yyyy   h:mm:ss a"
            return formatter.string(from: Date())
        case "displayOff": return "Turn the display off"
        case "files": return "Open a file window"
        case "overflow": return "Show hidden icons"
        case "tools": return "Timers, capture and recording"
        case "calculator": return "Calculator"
        case "notifications": return "Notification Center"
        case "spotlight": return "Spotlight"
        case "controlCenter": return "Control Center"
        case "showDesktop": return "Show desktop"
        default: return nil
        }
    }

    func hover(_ zone: BarZone, anchor: NSRect, bar: BarView) {
        if case .statusItem(let app) = zone.kind {
            guard let tile = StatusItemMirror.shared.tile(app) else { return hide() }
            schedule("status:\(tile.app)", anchor: anchor, bar: bar) { await StatusItemMirror.shared.tooltip(tile) }
            return
        }
        guard let key = zone.kind.tooltipKey, BarTooltip.text(key) != nil else { return hide() }
        schedule(key, anchor: anchor, bar: bar) { BarTooltip.text(key) ?? "" }
    }

    // Moving within one item does not restart the wait.
    private func schedule(_ key: String, anchor: NSRect, bar: BarView, text: @escaping @MainActor () async -> String) {
        guard key != self.key else { return }
        hide()
        self.key = key
        timer = Timer.scheduledTimer(withTimeInterval: BarTooltip.delay, repeats: false) { _ in
            Task { @MainActor in
                let wording = await text()
                guard BarTooltip.shared.key == key, !wording.isEmpty else { return }
                BarTooltip.shared.show(wording, anchor: anchor, bar: bar)
            }
        }
    }

    private func show(_ text: String, anchor: NSRect, bar: BarView) {
        label.stringValue = text
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 30, height: label.frame.height + 12)
        label.frame.origin = NSPoint(x: 12, y: 6)
        panel.present(size: size, above: anchor, bar: bar, gap: 5)
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        key = nil
        panel.dismiss()
    }
}
