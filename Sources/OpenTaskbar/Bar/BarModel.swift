// BarModel.swift
// The value types a bar layout reads and produces: inputs, zones and marks.
// Exists so layout stays a pure function from BarInputs to BarLayoutResult.
// Defines: BarInputs, LauncherEntry, TrayDragPreview, BarZoneKind, BarZone, BarMark, TraySlot, BarLayoutResult
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarModel.swift.md
import AppKit

struct LauncherEntry {
    let launcher: Launcher
    let pinned: Bool
    let hasWindows: Bool
    let active: Bool
}

// A tray item being dragged, drawn at the position it would take if dropped now.
struct TrayDragPreview: Equatable {
    let id: String
    let index: Int
}

struct BarInputs {
    let settings: BarSettings
    let palette: BarPalette
    let metrics: TaskbarMetrics
    let width: CGFloat
    let startIcon: NSImage?
    let launchers: [LauncherEntry]
    let menuTitles: [String]
    let volume: AudioLevel?
    let microphone: AudioLevel?
    let battery: BatteryState
    let wifi: WiFiState
    let wifiBars: Int
    let statusItems: [StatusItemTile]     // every mirrored item, shown or behind the chevron
    let hour24: Bool
    let now: Date
    let page: Int
    var trayDrag: TrayDragPreview? = nil
}

enum BarZoneKind: Equatable {
    case start, search, taskView, displayOff, files, calculator
    case menu(Int)
    case launcher(Int)
    case pageUp, pageDown
    case overflow
    case statusItem(String)
    case tools, display, keyboard, microphone, battery, volume, wifi, spotlight, controlCenter
    case clock, notifications, showDesktop

    // The TrayOrder identifier of a tray item, nil for everything outside the tray.
    var trayID: String? {
        switch self {
        case .statusItem(let app): return TrayOrder.statusID(app)
        case .tools: return "tools"
        case .display: return "displayBrightness"
        case .keyboard: return "keyboardBrightness"
        case .microphone: return "microphone"
        case .battery: return "battery"
        case .volume: return "volume"
        case .wifi: return "wifi"
        case .spotlight: return "spotlight"
        case .controlCenter: return "controlCenter"
        default: return nil
        }
    }

    static func tray(_ id: String) -> BarZoneKind? {
        if let app = TrayOrder.app(of: id) { return .statusItem(app) }
        switch id {
        case "tools": return .tools
        case "displayBrightness": return .display
        case "keyboardBrightness": return .keyboard
        case "microphone": return .microphone
        case "battery": return .battery
        case "volume": return .volume
        case "wifi": return .wifi
        case "spotlight": return .spotlight
        case "controlCenter": return .controlCenter
        default: return nil
        }
    }

    // The key BarTooltip looks wording up by.
    var tooltipKey: String? {
        switch self {
        case .start: return "start"
        case .search: return "search"
        case .taskView: return "taskView"
        case .displayOff: return "displayOff"
        case .files: return "files"
        case .calculator: return "calculator"
        case .overflow: return "overflow"
        case .tools: return "tools"
        case .display: return "display"
        case .keyboard: return "keyboard"
        case .microphone: return "microphone"
        case .battery: return "battery"
        case .volume: return "volume"
        case .wifi: return "wifi"
        case .spotlight: return "spotlight"
        case .controlCenter: return "controlCenter"
        case .clock: return "clock"
        case .notifications: return "notifications"
        case .showDesktop: return "showDesktop"
        default: return nil
        }
    }

    // Buttons that light up under the pointer, as Windows taskbar buttons do.
    var highlightsOnHover: Bool {
        switch self {
        case .menu, .showDesktop, .pageUp, .pageDown: return false
        default: return true
        }
    }
}

struct BarZone {
    let kind: BarZoneKind
    let rect: NSRect
}

enum BarMark {
    case launcher(NSRect, image: NSImage?, color: NSColor)
    case glyph(BarGlyph, NSRect, color: NSColor)
    case tray(TrayGlyph, NSRect, color: NSColor)
    case text(NSAttributedString, at: NSPoint)
    case image(NSImage, NSRect)
    case tinted(NSImage, NSRect, color: NSColor)
    case fill(NSRect, color: NSColor)
}

struct TraySlot {
    let id: String
    let rect: NSRect
}

struct BarLayoutResult {
    var marks: [BarMark] = []
    var zones: [BarZone] = []
    var traySlots: [TraySlot] = []
    var chevronRect: NSRect?
    var clockRect: NSRect = .zero
    var pinnedGeometry: LauncherReorder.Geometry?
    var pageCount = 1

    // Zones are checked newest first, so a later zone wins where two overlap.
    func zone(at point: NSPoint) -> BarZone? {
        zones.last { $0.rect.contains(point) }
    }
}
