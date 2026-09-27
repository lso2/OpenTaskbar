// SliderPanel.swift
// One slider flyout shared by volume, microphone, screen brightness and keyboard brightness.
// Exists as the port of bottombar-panel.lua: a mark on the left that mutes, a track on the right that sets the level.
// Defines: SliderPanel, SliderView
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/SliderPanel.swift.md
import AppKit

@MainActor
final class SliderPanel {
    static let shared = SliderPanel()

    enum Kind { case volume, microphone, display, keyboard }

    static let size = NSSize(width: 210, height: 34)
    private let panel = PopupPanel(size: SliderPanel.size)
    private let view = SliderView(frame: NSRect(origin: .zero, size: SliderPanel.size))
    private(set) var kind: Kind?

    private init() {
        panel.contentView = view
        panel.onDismiss = { SliderPanel.shared.kind = nil }
    }

    var isOpen: Bool { panel.isOpen }

    func toggle(_ kind: Kind, above anchor: NSRect, bar: BarView) {
        if panel.isOpen && self.kind == kind {
            panel.dismiss()
            return
        }
        self.kind = kind
        view.kind = kind
        view.needsDisplay = true
        panel.present(size: SliderPanel.size, above: anchor, bar: bar)
    }

    // Level 0 to 100, and whether the kind is muted. Brightness kinds have no mute.
    static func read(_ kind: Kind) -> (level: Double, muted: Bool) {
        switch kind {
        case .volume:
            AudioControl.output.refresh()
            return (AudioControl.output.state?.level ?? 0, AudioControl.output.state?.muted ?? false)
        case .microphone:
            AudioControl.input.refresh()
            return (AudioControl.input.state?.level ?? 0, AudioControl.input.state?.muted ?? false)
        case .display: return (DisplayBrightness.level ?? 0, false)
        case .keyboard: return (KeyboardBacklight.shared.level ?? 0, false)
        }
    }

    static func set(_ kind: Kind, _ level: Double) {
        switch kind {
        case .volume: AudioControl.output.setLevel(level)
        case .microphone: AudioControl.input.setLevel(level)
        case .display: DisplayBrightness.set(level)
        case .keyboard: KeyboardBacklight.shared.set(level)
        }
    }

    static func toggleMute(_ kind: Kind) {
        switch kind {
        case .volume: AudioControl.output.toggleMute()
        case .microphone: AudioControl.input.toggleMute()
        case .display, .keyboard: break
        }
    }
}

@MainActor
final class SliderView: NSView {
    var kind: SliderPanel.Kind = .volume
    private var dragging = false
    private var lastApplied = Date.distantPast

    static let markSlot: CGFloat = 30
    static let trackInset: CGFloat = 6

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var track: (left: CGFloat, width: CGFloat) {
        let left = SliderView.markSlot + SliderView.trackInset
        return (left, bounds.width - 14 - left)
    }

    override func draw(_ dirtyRect: NSRect) {
        let (level, muted) = SliderPanel.read(kind)
        let centerY = bounds.height / 2
        let ink = NSColor(white: 1, alpha: 0.92)
        NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.97).setFill()
        bounds.fill()

        let (left, width) = track
        GlyphPen.fillRect(NSRect(x: left, y: centerY - 2, width: width, height: 4), color: NSColor(white: 1, alpha: 0.22))

        let markBox = NSRect(x: 7, y: centerY - 8, width: 16, height: 16)
        switch kind {
        case .volume: TrayGlyph.volume(level: level, muted: muted).draw(in: markBox, color: ink)
        case .microphone: BarGlyph.microphone(muted: muted).draw(in: markBox, color: ink)
        case .display: BarGlyph.displayBrightness.draw(in: markBox, color: ink)
        case .keyboard: BarGlyph.keyboardBrightness.draw(in: markBox, color: ink)
        }

        guard !muted else { return }
        let filled = max(0, width * CGFloat(level / 100))
        GlyphPen.fillRect(NSRect(x: left, y: centerY - 2, width: filled, height: 4), color: ink)
        GlyphPen.fillRect(NSRect(x: left + filled - 2, y: centerY - 7, width: 4, height: 14), color: ink)
    }

    private func setLevel(_ x: CGFloat, force: Bool) {
        guard force || Date().timeIntervalSince(lastApplied) > 0.06 else { return }
        lastApplied = Date()
        let (left, width) = track
        SliderPanel.set(kind, Double(min(1, max(0, (x - left) / width))) * 100)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        if x < SliderView.markSlot {
            SliderPanel.toggleMute(kind)
            needsDisplay = true
            return
        }
        dragging = true
        setLevel(x, force: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        setLevel(convert(event.locationInWindow, from: nil).x, force: false)
    }

    override func mouseUp(with event: NSEvent) {
        if dragging { setLevel(convert(event.locationInWindow, from: nil).x, force: true) }
        dragging = false
    }
}
