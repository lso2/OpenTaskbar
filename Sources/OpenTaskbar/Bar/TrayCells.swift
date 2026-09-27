// TrayCells.swift
// Builds the zone kind, width and marks of each tray item from its TrayOrder identifier.
// Exists so the bar, the chevron flyout and the drag image draw a tray item the same way.
// Defines: TrayCell, TrayCells
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/TrayCells.swift.md
import AppKit

struct TrayCell {
    let id: String
    let kind: BarZoneKind
    let width: CGFloat
    let marks: (NSRect) -> [BarMark]
}

@MainActor
enum TrayCells {
    // Compact cells leave out the battery percentage, for the flyout's square cells.
    static func cells(_ ids: [String], inputs: BarInputs, color: NSColor, compact: Bool = false) -> [TrayCell] {
        ids.compactMap { cell($0, inputs: inputs, color: color, compact: compact) }
    }

    static func cell(_ id: String, inputs: BarInputs, color: NSColor, compact: Bool = false) -> TrayCell? {
        guard let kind = BarZoneKind.tray(id) else { return nil }
        let pitch = TaskbarMetrics.trayPitch
        let icon = TaskbarMetrics.trayIcon
        func box(_ rect: NSRect) -> NSRect { BarGlyph.box(center: NSPoint(x: rect.midX, y: rect.midY), size: icon) }
        func glyph(_ mark: BarGlyph) -> TrayCell {
            TrayCell(id: id, kind: kind, width: pitch) { [.glyph(mark, box($0), color: color)] }
        }
        func tray(_ mark: TrayGlyph) -> TrayCell {
            TrayCell(id: id, kind: kind, width: pitch) { [.tray(mark, box($0), color: color)] }
        }

        switch kind {
        case .statusItem(let app):
            guard let tile = inputs.statusItems.first(where: { $0.app == app }) else { return nil }
            let useGlyph = !inputs.settings.whiteStatusMarks
            return TrayCell(id: id, kind: kind, width: pitch) { rect in
                if useGlyph, let glyph = tile.glyph {
                    let fitted = BarGlyph.aspectFit(glyph.image.size, in: box(rect))
                    return [glyph.monochrome ? .tinted(glyph.image, fitted, color: color) : .image(glyph.image, fitted)]
                }
                // The letter stands in until the item's menu bar glyph has been captured.
                let mark = BarLayout.text(tile.letter, font: NSFont.boldSystemFont(ofSize: inputs.palette.clockFontSize),
                                          color: color)
                let size = mark.size()
                return [.text(mark, at: NSPoint(x: rect.midX - (size.width / 2), y: rect.midY - (size.height / 2)))]
            }
        case .tools: return glyph(.tools)
        case .display: return glyph(.displayBrightness)
        case .keyboard: return glyph(.keyboardBrightness)
        case .microphone: return glyph(.microphone(muted: inputs.microphone?.muted ?? false))
        case .spotlight: return glyph(.spotlight)
        case .controlCenter: return glyph(.controlCenter)
        case .volume: return tray(.volume(level: inputs.volume?.level ?? 0, muted: inputs.volume?.muted ?? false))
        case .wifi: return tray(.wifi(connected: inputs.wifi.connected, powered: inputs.wifi.powered, bars: inputs.wifiBars))
        case .battery:
            let battery = TrayGlyph.battery(percent: inputs.battery.percent, charging: inputs.battery.charging,
                                            plugged: inputs.battery.onAdapter)
            guard !compact, inputs.settings.shows("batteryText") else { return tray(battery) }
            let label = BarLayout.text("\(Int(inputs.battery.percent.rounded(.down)))%", font: inputs.palette.clockFont,
                                       color: color)
            let size = label.size()
            let textWidth = BarLayout.snap(size.width + 8)
            return TrayCell(id: id, kind: kind, width: pitch + textWidth) { rect in
                let iconRect = NSRect(x: rect.minX, y: rect.minY, width: pitch, height: rect.height)
                return [.tray(battery, box(iconRect), color: color),
                        .text(label, at: NSPoint(x: iconRect.maxX + ((textWidth - size.width) / 2),
                                                 y: rect.midY - (size.height / 2)))]
            }
        default:
            return nil
        }
    }

    // The item's marks drawn alone, for the image that follows the pointer while it is dragged.
    static func image(_ id: String, inputs: BarInputs) -> NSImage? {
        guard let cell = cell(id, inputs: inputs, color: inputs.palette.text) else { return nil }
        let size = NSSize(width: cell.width, height: inputs.metrics.rowHeight)
        guard let bitmap = BarRenderer.bitmap(size: size, scale: 2, drawing: {
            for mark in cell.marks(NSRect(origin: .zero, size: size)) { BarRenderer.draw(mark) }
        }) else { return nil }
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}
