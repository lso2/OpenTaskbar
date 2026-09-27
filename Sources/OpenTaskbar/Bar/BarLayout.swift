// BarLayout.swift
// Places Start, Task View, the app menus and the app buttons, wrapping, shrinking and paging like Windows 10.
// Exists so the left and middle of the bar follow the measured TaskbarMetrics exactly.
// Defines: BarLayout
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarLayout.swift.md
import AppKit

@MainActor
enum BarLayout {
    enum Button {
        case quick(BarZoneKind, BarGlyph)
        case launcher(Int, LauncherEntry)
    }

    static func text(_ string: String, font: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    static func snap(_ value: CGFloat) -> CGFloat { (value * 2).rounded() / 2 }

    static func compute(_ inputs: BarInputs) -> BarLayoutResult {
        var result = BarLayoutResult()
        let settings = inputs.settings
        let palette = inputs.palette
        let m = inputs.metrics
        let height = m.height

        let trayLeft = BarRightEnd.layout(inputs, into: &result)

        // Start, Search and Task View each take a fixed width and center their mark on the whole bar.
        var x: CGFloat = 0
        let fixed = m.fixedButtonWidth
        let startSide = TaskbarMetrics.startLogo * CGFloat(settings.startIconScale / 80)
        result.marks.append(.launcher(BarGlyph.box(center: NSPoint(x: fixed / 2, y: height / 2), size: startSide),
                                      image: inputs.startIcon, color: palette.bright))
        result.zones.append(BarZone(kind: .start, rect: NSRect(x: 0, y: 0, width: fixed, height: height)))
        x = fixed
        for (item, kind, glyph) in [("search", BarZoneKind.search, BarGlyph.search), ("taskView", .taskView, .taskView)]
        where settings.shows(item) {
            result.marks.append(.glyph(glyph, BarGlyph.box(center: NSPoint(x: x + (fixed / 2), y: height / 2),
                                                           size: TaskbarMetrics.startLogo), color: palette.text))
            result.zones.append(BarZone(kind: kind, rect: NSRect(x: x, y: 0, width: fixed, height: height)))
            x += fixed
        }

        // The frontmost app's menus sit on the first row, the first one bold as the menu bar draws it.
        if settings.shows("appMenu") {
            x += 6
            for (index, title) in inputs.menuTitles.enumerated() {
                let label = text(title, font: index == 0 ? palette.boldFont : palette.regularFont,
                                 color: index == 0 ? palette.bright : palette.text)
                let size = label.size()
                result.marks.append(.text(label, at: NSPoint(x: x + 5, y: m.rowTop(0) + ((m.rowHeight - size.height) / 2))))
                result.zones.append(BarZone(kind: .menu(index), rect: NSRect(x: x, y: m.rowTop(0), width: size.width + 10, height: m.rowHeight)))
                x += size.width + 10
            }
            x += 6
        }

        var buttons: [Button] = []
        if settings.shows("displayOff") { buttons.append(.quick(.displayOff, .displayOff)) }
        buttons.append(.quick(.files, .folder))
        if settings.shows("calculator") { buttons.append(.quick(.calculator, .calculator)) }
        for (index, entry) in inputs.launchers.enumerated() { buttons.append(.launcher(index, entry)) }

        layoutButtons(buttons, inputs, from: x, to: trayLeft, into: &result)
        return result
    }

    // Buttons keep their nominal width until the rows are full, then all shrink together, and
    // once they reach their minimum the rows page behind the up and down arrows.
    private static func layoutButtons(_ buttons: [Button], _ inputs: BarInputs, from left: CGFloat, to trayLeft: CGFloat,
                                      into result: inout BarLayoutResult) {
        let m = inputs.metrics
        let rows = m.rows
        var available = trayLeft - TaskbarMetrics.trayGap - left
        guard !buttons.isEmpty, available > m.buttonMinimum else { return }

        var width = m.buttonNominal
        var perRow = max(1, Int(available / width))
        var visible = buttons[...]

        if buttons.count > perRow * rows {
            let columns = Int((Double(buttons.count) / Double(rows)).rounded(.up))
            let shrunk = available / CGFloat(columns)
            if shrunk >= m.buttonMinimum {
                width = shrunk
                perRow = columns
            } else {
                available -= TaskbarMetrics.pagerWidth
                width = m.buttonMinimum
                perRow = max(1, Int(available / width))
                let pageSize = perRow * rows
                result.pageCount = Int((Double(buttons.count) / Double(pageSize)).rounded(.up))
                let page = min(max(0, inputs.page), result.pageCount - 1)
                visible = buttons[(page * pageSize)..<min(buttons.count, (page + 1) * pageSize)]
                pager(inputs, right: trayLeft, into: &result)
            }
        }

        var slots: [NSRect] = []
        var paths: [String] = []
        for (offset, button) in visible.enumerated() {
            let row = offset / perRow
            let column = offset % perRow
            let rect = NSRect(x: snap(left + (CGFloat(column) * width)), y: m.rowTop(row),
                              width: snap(left + (CGFloat(column + 1) * width)) - snap(left + (CGFloat(column) * width)),
                              height: m.rowHeight)
            switch button {
            case .quick(let kind, let glyph):
                result.marks.append(.glyph(glyph, BarGlyph.box(center: NSPoint(x: rect.midX, y: rect.midY), size: m.iconSize),
                                           color: inputs.palette.text))
                result.zones.append(BarZone(kind: kind, rect: rect))
            case .launcher(let index, let entry):
                drawLauncher(entry, index: index, slot: rect, inputs, into: &result)
                result.zones.append(BarZone(kind: .launcher(index), rect: rect))
                if entry.pinned {
                    slots.append(rect)
                    paths.append(entry.launcher.path)
                }
            }
        }
        // Reordering needs every pinned launcher on screen, so a paged bar does not offer it.
        if !slots.isEmpty, result.pageCount == 1 {
            result.pinnedGeometry = LauncherReorder.Geometry(slots: slots, iconBox: m.iconBox, paths: paths)
        }
    }

    private static func drawLauncher(_ entry: LauncherEntry, index: Int, slot: NSRect, _ inputs: BarInputs,
                                     into result: inout BarLayoutResult) {
        let palette = inputs.palette
        let m = inputs.metrics
        let reorder = LauncherReorder.shared
        let inset = entry.active ? TaskbarMetrics.highlightInset : TaskbarMetrics.underlineInset

        if entry.active {
            result.marks.append(.fill(slot.insetBy(dx: TaskbarMetrics.highlightInset, dy: 0), color: palette.activeFill))
        }

        let pinnedIndex = entry.pinned ? inputs.launchers[..<index].filter(\.pinned).count : nil
        let lift = LauncherHop.shared.lift(for: entry.launcher.path) + (pinnedIndex.map { reorder.lift($0) } ?? 0)
        var icon = BarGlyph.box(center: NSPoint(x: slot.midX, y: slot.midY), size: m.iconBox)
        if let pinnedIndex, let moved = reorder.iconOrigin(pinnedIndex) { icon.origin = moved }
        icon.origin.y -= lift
        result.marks.append(.image(entry.launcher.icon, icon))

        // The underline travels with its icon during a drag and never lifts.
        if entry.hasWindows {
            let offset = icon.midX - slot.midX
            result.marks.append(.fill(NSRect(x: slot.minX + inset + offset, y: slot.maxY - TaskbarMetrics.underlineHeight,
                                             width: slot.width - (2 * inset), height: TaskbarMetrics.underlineHeight),
                                      color: palette.underline))
        }
    }

    // A light column split into an up half and a down half, hard against the tray.
    private static func pager(_ inputs: BarInputs, right: CGFloat, into result: inout BarLayoutResult) {
        let height = inputs.metrics.height
        let column = NSRect(x: right - TaskbarMetrics.pagerWidth, y: 0, width: TaskbarMetrics.pagerWidth, height: height)
        result.marks.append(.fill(column, color: NSColor(white: 240 / 255, alpha: 1)))
        let ink = NSColor(white: 0.25, alpha: 1)
        let up = NSRect(x: column.minX, y: 0, width: column.width, height: height / 2)
        let down = NSRect(x: column.minX, y: height / 2, width: column.width, height: height / 2)
        result.marks.append(.glyph(.pagerUp, BarGlyph.box(center: NSPoint(x: up.midX, y: up.midY), size: 16), color: ink))
        result.marks.append(.glyph(.pagerDown, BarGlyph.box(center: NSPoint(x: down.midX, y: down.midY), size: 16), color: ink))
        result.zones.append(BarZone(kind: .pageUp, rect: up))
        result.zones.append(BarZone(kind: .pageDown, rect: down))
    }
}
