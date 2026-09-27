// BarSettings.swift
// Every stored preference in one Codable value, with the defaults and limits the Lua build used.
// Exists so the bar, panels, backup and importer all read and write the same structure.
// Defines: BarSettings, BarSettings.Loose
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/BarSettings.swift.md
import Foundation

struct BarSettings: Codable, Equatable, Sendable {
    // The bar items that can each be switched off, in the order Settings lists them.
    static let items = [
        "appMenu", "pinned", "running", "taskView", "displayOff", "calculator", "tools", "search",
        "volume", "microphone", "keyboardBrightness", "displayBrightness", "wifi", "battery",
        "batteryText", "spotlight", "controlCenter", "date", "time", "notifications", "statusItems", "showDesktop",
    ]
    static let itemsOffByDefault: Set<String> = ["batteryText", "search"]

    // The init.lua behaviors, each with its own switch.
    static let modules = [
        "ctrlClickLink", "micMuteKey", "homeEndKeys", "documentJumpKeys",
        "terminalPaste", "windowSnapping", "closeQuitsApp",
    ]

    var brightness: Double = 8
    var transparency: Double = 6
    var transparencyOn = true
    var blur = false
    var whiteStatusMarks = false
    var displayName = ""
    var thisMacLabel = "This Mac"
    var pinnedApps: [String] = []
    var hiddenStatus: [String: Bool] = [:]
    var hiddenTray: [String: Bool] = [:]
    var trayOrder: [String] = []
    var barHeight: Double = 30
    var iconSize: Double = 16
    var rows = 1
    var textScale: Double = 100
    var startIconScale: Double = 80
    var startIconName = ""
    var startTapMode = "key"
    var startTapFlag = "cmd"
    var startTapCode = 55
    var pinnedAlign = "left"
    var dateFormat = "%-m/%-d/%Y"
    var clockStacked = true
    var previewWidth: Double = 400
    var panelFontScale: Double = 100
    var panelIconScale: Double = 100
    var panelBrightness: Double = 12
    var panelTransparency: Double = 4
    var panelTransparencyOn = true
    var panelBlur = false
    var panelMaxWidth: Double = 900
    var panelMaxHeight: Double = 820
    var show: [String: Bool] = Dictionary(
        uniqueKeysWithValues: BarSettings.items.map { ($0, !BarSettings.itemsOffByDefault.contains($0)) })
    var restoreLevels: [String: Double] = [:]
    var autoHide = true
    var launchAtLogin = true
    var moduleSwitches: [String: Bool] = Dictionary(
        uniqueKeysWithValues: BarSettings.modules.map { ($0, true) })

    func shows(_ item: String) -> Bool {
        show[item] ?? !BarSettings.itemsOffByDefault.contains(item)
    }

    func moduleOn(_ module: String) -> Bool {
        moduleSwitches[module] ?? true
    }

    // The same limits the Lua settings reader applied on every load.
    func clamped() -> BarSettings {
        var value = self
        value.brightness = min(100, max(0, brightness))
        value.transparency = min(100, max(0, transparency))
        value.barHeight = min(60, max(22, barHeight))
        value.iconSize = min(48, max(12, iconSize))
        value.rows = min(3, max(1, rows))
        value.textScale = min(250, max(70, textScale))
        value.startIconScale = min(200, max(40, startIconScale))
        value.previewWidth = min(640, max(260, previewWidth))
        value.panelFontScale = min(250, max(70, panelFontScale))
        value.panelIconScale = min(250, max(70, panelIconScale))
        value.panelBrightness = min(100, max(0, panelBrightness))
        value.panelTransparency = min(100, max(0, panelTransparency))
        value.panelMaxWidth = min(1400, max(360, panelMaxWidth))
        value.panelMaxHeight = min(1200, max(320, panelMaxHeight))
        if !["left", "center", "right"].contains(pinnedAlign) { value.pinnedAlign = "center" }
        if !["off", "key", "learn"].contains(startTapMode) { value.startTapMode = "key" }
        if thisMacLabel.isEmpty { value.thisMacLabel = "This Mac" }
        if dateFormat.isEmpty { value.dateFormat = "%-m/%-d/%Y" }
        for item in BarSettings.items where value.show[item] == nil {
            value.show[item] = !BarSettings.itemsOffByDefault.contains(item)
        }
        for module in BarSettings.modules where value.moduleSwitches[module] == nil {
            value.moduleSwitches[module] = true
        }
        return value
    }
}

// Decoding accepts what the Lua build and Hammerspoon's plist wrote: 1 and 0 for booleans,
// numbers stored as strings, and an empty Lua table encoded as an array.
extension BarSettings {
    enum Loose: Decodable {
        case number(Double)
        case flag(Bool)
        case text(String)
        case list([Loose])
        case table([String: Loose])
        case none

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .none; return }
            if let value = try? container.decode(Bool.self) { self = .flag(value); return }
            if let value = try? container.decode(Double.self) { self = .number(value); return }
            if let value = try? container.decode(String.self) { self = .text(value); return }
            if let value = try? container.decode([Loose].self) { self = .list(value); return }
            if let value = try? container.decode([String: Loose].self) { self = .table(value); return }
            self = .none
        }

        var number: Double? {
            switch self {
            case .number(let value): return value
            case .flag(let value): return value ? 1 : 0
            case .text(let value): return Double(value)
            default: return nil
            }
        }

        var flag: Bool? {
            switch self {
            case .flag(let value): return value
            case .number(let value): return value != 0
            case .text(let value): return value == "true" || value == "1"
            default: return nil
            }
        }

        var text: String? {
            if case .text(let value) = self { return value }
            return nil
        }

        var strings: [String]? {
            if case .list(let values) = self { return values.compactMap(\.text) }
            return nil
        }

        var flags: [String: Bool]? {
            switch self {
            case .table(let values): return values.compactMapValues(\.flag)
            case .list(let values) where values.isEmpty: return [:]
            default: return nil
            }
        }

        var numbers: [String: Double]? {
            switch self {
            case .table(let values): return values.compactMapValues(\.number)
            case .list(let values) where values.isEmpty: return [:]
            default: return nil
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func loose(_ key: CodingKeys) -> Loose? {
            (try? container.decodeIfPresent(Loose.self, forKey: key)) ?? nil
        }

        var value = BarSettings()
        if let v = loose(.brightness)?.number { value.brightness = v }
        if let v = loose(.transparency)?.number { value.transparency = v }
        if let v = loose(.transparencyOn)?.flag { value.transparencyOn = v }
        if let v = loose(.blur)?.flag { value.blur = v }
        if let v = loose(.whiteStatusMarks)?.flag { value.whiteStatusMarks = v }
        if let v = loose(.displayName)?.text { value.displayName = v }
        if let v = loose(.thisMacLabel)?.text { value.thisMacLabel = v }
        if let v = loose(.pinnedApps)?.strings { value.pinnedApps = v }
        if let v = loose(.hiddenStatus)?.flags { value.hiddenStatus = v.filter(\.value) }
        if let v = loose(.hiddenTray)?.flags { value.hiddenTray = v.filter(\.value) }
        if let v = loose(.trayOrder)?.strings { value.trayOrder = v }
        if let v = loose(.barHeight)?.number { value.barHeight = v }
        if let v = loose(.iconSize)?.number { value.iconSize = v }
        if let v = loose(.rows)?.number { value.rows = Int(v) }
        if let v = loose(.textScale)?.number { value.textScale = v }
        if let v = loose(.startIconScale)?.number { value.startIconScale = v }
        if let v = loose(.startIconName)?.text { value.startIconName = v }
        if let v = loose(.startTapMode)?.text { value.startTapMode = v }
        if let v = loose(.startTapFlag)?.text { value.startTapFlag = v }
        if let v = loose(.startTapCode)?.number { value.startTapCode = Int(v) }
        if let v = loose(.pinnedAlign)?.text { value.pinnedAlign = v }
        if let v = loose(.dateFormat)?.text { value.dateFormat = v }
        if let v = loose(.clockStacked)?.flag { value.clockStacked = v }
        if let v = loose(.previewWidth)?.number { value.previewWidth = v }
        if let v = loose(.panelFontScale)?.number { value.panelFontScale = v }
        if let v = loose(.panelIconScale)?.number { value.panelIconScale = v }
        if let v = loose(.panelBrightness)?.number { value.panelBrightness = v }
        if let v = loose(.panelTransparency)?.number { value.panelTransparency = v }
        if let v = loose(.panelTransparencyOn)?.flag { value.panelTransparencyOn = v }
        if let v = loose(.panelBlur)?.flag { value.panelBlur = v }
        if let v = loose(.panelMaxWidth)?.number { value.panelMaxWidth = v }
        if let v = loose(.panelMaxHeight)?.number { value.panelMaxHeight = v }
        if let v = loose(.show)?.flags { value.show.merge(v) { _, stored in stored } }
        if let v = loose(.restoreLevels)?.numbers { value.restoreLevels = v }
        if let v = loose(.autoHide)?.flag { value.autoHide = v }
        if let v = loose(.launchAtLogin)?.flag { value.launchAtLogin = v }
        if let v = loose(.moduleSwitches)?.flags { value.moduleSwitches.merge(v) { _, stored in stored } }
        self = value.clamped()
    }
}
