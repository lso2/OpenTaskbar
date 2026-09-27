// BarBackground.swift
// The bar's content view: a behind-window blur that the tinted bar drawing sits on top of.
// Exists because NSVisualEffectView blurs live content, which the Lua build faked with a captured strip.
// Defines: BarBackground
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarBackground.swift.md
import AppKit

@MainActor
final class BarBackground: NSView {
    private let effect = NSVisualEffectView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        effect.frame = bounds
        effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .behindWindow
        effect.material = .hudWindow
        effect.state = .active
        addSubview(effect)
    }

    required init?(coder: NSCoder) { nil }

    // With blur off only the tinted fill the bar view draws is left.
    func apply(_ settings: BarSettings) {
        effect.isHidden = !settings.blur
        effect.appearance = NSAppearance(named: settings.brightness > 55 ? .aqua : .darkAqua)
    }
}
