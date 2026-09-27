// BarRightEnd.swift
// Lays out the right end from the screen edge inward: Show Desktop, notifications, clock, tray icons, chevron.
// Exists as the Windows 10 notification area, with its measured offsets and a grid when the bar has rows.
// Defines: BarRightEnd
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarRightEnd.swift.md
import AppKit

@MainActor
enum BarRightEnd {
    static func strftime(_ format: String, _ date: Date) -> String {
        var seconds = time_t(date.timeIntervalSince1970)
        var parts = tm()
        localtime_r(&seconds, &parts)
        var buffer = [CChar](repeating: 0, count: 128)
        let length = Darwin.strftime(&buffer, buffer.count, format, &parts)
        return String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    // Returns the left edge of the tray, where the app buttons have to stop.
    static func layout(_ inputs: BarInputs, into result: inout BarLayoutResult) -> CGFloat {
        let palette = inputs.palette
        let settings = inputs.settings
        let m = inputs.metrics
        let height = m.height
        var edge = inputs.width

        func zone(_ kind: BarZoneKind, _ rect: NSRect) {
            result.zones.append(BarZone(kind: kind, rect: rect))
        }

        // Show Desktop: a strip against the screen edge whose left side is a hairline.
        if settings.shows("showDesktop") {
            let strip = NSRect(x: edge - TaskbarMetrics.showDesktopWidth, y: 0, width: TaskbarMetrics.showDesktopWidth, height: height)
            result.marks.append(.fill(NSRect(x: strip.minX, y: 0, width: TaskbarMetrics.showDesktopLine,
                                             height: height - TaskbarMetrics.showDesktopBottomGap), color: palette.showDesktopLine))
            zone(.showDesktop, strip)
            edge = strip.minX
        }

        // Notifications: the button reaches from the clock to Show Desktop, its mark 33.67 points from the screen edge.
        if settings.shows("notifications") {
            let right = edge
            let left = inputs.width - TaskbarMetrics.clockRightInset
            let center = NSPoint(x: inputs.width - TaskbarMetrics.notificationCenterInset, y: height / 2)
            result.marks.append(.glyph(.notifications, BarGlyph.box(center: center, size: TaskbarMetrics.trayIcon), color: palette.text))
            zone(.notifications, NSRect(x: left, y: 0, width: right - left, height: height))
            edge = left
        }

        edge = clock(inputs, right: edge, into: &result)
        return tray(inputs, right: edge, into: &result)
    }

    private static func clockLines(_ inputs: BarInputs) -> [String] {
        let settings = inputs.settings
        let showDate = settings.shows("date")
        let showTime = settings.shows("time")
        let time = strftime(inputs.hour24 ? "%H:%M" : "%I:%M %p", inputs.now)
        let date = strftime(settings.dateFormat, inputs.now)
        switch (showTime, showDate) {
        case (false, false): return []
        case (true, false): return [time]
        case (false, true): return [date]
        case (true, true):
            if inputs.metrics.rows >= 2 { return [time, strftime("%A", inputs.now), date] }
            if settings.clockStacked || inputs.metrics.large { return [time, date] }
            return ["\(date)   \(time)"]
        }
    }

    // Lines are centered in a button padded 6.67 points a side, stepped by 1.25 line heights
    // where the bar has room, as Windows spaces its two and three line clocks.
    private static func clock(_ inputs: BarInputs, right: CGFloat, into result: inout BarLayoutResult) -> CGFloat {
        let lines = clockLines(inputs)
        guard !lines.isEmpty else { return right }
        let palette = inputs.palette
        let height = inputs.metrics.height
        let labels = lines.map { BarLayout.text($0, font: palette.clockFont, color: palette.text) }
        let widest = labels.map { $0.size().width }.max() ?? 0
        let lineHeight = labels[0].size().height
        let pitch = min(lineHeight * 1.25, height / CGFloat(labels.count))
        let block = (pitch * CGFloat(labels.count - 1)) + lineHeight
        let buttonWidth = BarLayout.snap(widest + (2 * TaskbarMetrics.clockPadding))
        let rect = NSRect(x: right - buttonWidth, y: 0, width: buttonWidth, height: height)
        let top = (height - block) / 2

        for (index, label) in labels.enumerated() {
            result.marks.append(.text(label, at: NSPoint(x: rect.midX - (label.size().width / 2),
                                                         y: top + (CGFloat(index) * pitch))))
        }
        result.zones.append(BarZone(kind: .clock, rect: rect))
        result.clockRect = rect
        return rect.minX
    }

    // Items follow the saved tray order. A dragged item is drawn where it would land, and the
    // chevron appears when status items are mirrored or anything sits behind it.
    private static func tray(_ inputs: BarInputs, right: CGFloat, into result: inout BarLayoutResult) -> CGFloat {
        let palette = inputs.palette
        let settings = inputs.settings
        let m = inputs.metrics
        let pitch = TaskbarMetrics.trayPitch
        let icon = TaskbarMetrics.trayIcon
        let split = TrayOrder.split(settings, apps: inputs.statusItems.map(\.app), batteryPresent: inputs.battery.present)
        var ids = split.shown
        if let drag = inputs.trayDrag {
            ids.removeAll { $0 == drag.id }
            ids.insert(drag.id, at: min(max(0, drag.index), ids.count))
        }
        let cells = TrayCells.cells(ids, inputs: inputs, color: palette.text)

        // Cells fill the rows left to right; each column is as wide as its widest cell.
        let rows = m.rows
        let columns = max(1, Int((Double(cells.count) / Double(rows)).rounded(.up)))
        var columnWidths = [CGFloat](repeating: 0, count: cells.isEmpty ? 0 : columns)
        for (index, cell) in cells.enumerated() {
            columnWidths[index % columns] = max(columnWidths[index % columns], cell.width)
        }
        let total = columnWidths.reduce(0, +)
        var left = right - total
        var columnX: [CGFloat] = []
        for width in columnWidths {
            columnX.append(left)
            left += width
        }
        for (index, cell) in cells.enumerated() {
            let column = index % columns
            let row = index / columns
            let rect = NSRect(x: columnX[column], y: rows > 1 ? m.rowTop(row) : 0,
                              width: columnWidths[column], height: rows > 1 ? m.rowHeight : m.height)
            // The dragged item's spot stays empty; its image follows the pointer.
            if cell.id != inputs.trayDrag?.id { result.marks.append(contentsOf: cell.marks(rect)) }
            result.zones.append(BarZone(kind: cell.kind, rect: rect))
            result.traySlots.append(TraySlot(id: cell.id, rect: rect))
        }

        var trayLeft = right - total
        if settings.shows("statusItems") || !split.hidden.isEmpty {
            let caret = NSRect(x: trayLeft - pitch, y: 0, width: pitch, height: m.height)
            result.marks.append(.glyph(.chevron, BarGlyph.box(center: NSPoint(x: caret.midX, y: caret.midY), size: icon),
                                       color: palette.text))
            result.zones.append(BarZone(kind: .overflow, rect: caret))
            result.chevronRect = caret
            trayLeft = caret.minX
        }
        return trayLeft
    }
}
