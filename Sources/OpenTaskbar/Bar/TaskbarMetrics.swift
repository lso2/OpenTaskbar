// TaskbarMetrics.swift
// Windows 10 taskbar measurements in points, taken from 150 percent screenshots divided by 1.5.
// Exists so every size and gap on the bar comes from one measured table.
// Defines: TaskbarMetrics
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/TaskbarMetrics.swift.md
import AppKit

struct TaskbarMetrics {
    let rows: Int
    let rowHeight: CGFloat
    let iconSize: CGFloat
    let large: Bool

    init(_ settings: BarSettings) {
        rows = settings.rows
        rowHeight = CGFloat(settings.barHeight)
        iconSize = CGFloat(settings.iconSize)
        large = rowHeight >= 36 || iconSize >= 20
    }

    // Rows are separated by 2 points.
    var height: CGFloat { (CGFloat(rows) * rowHeight) + (CGFloat(rows - 1) * 2) }

    func rowTop(_ row: Int) -> CGFloat { CGFloat(row) * (rowHeight + 2) }

    // Start and Task View: 36 points on a small taskbar, 48 on a large one.
    var fixedButtonWidth: CGFloat { large ? 48 : 36 }
    // The Start logo and every tray mark stay 16 points in both modes.
    static let startLogo: CGFloat = 16
    static let trayIcon: CGFloat = 16

    // App buttons: 38 points each until the row is full, then all shrink together down to the
    // icon plus 7 points a side, and past that the row pages.
    var buttonNominal: CGFloat { max(large ? 48 : 38, iconSize + 22) }
    var buttonMinimum: CGFloat { iconSize + 14 }

    // A macOS app icon leaves about a tenth of its canvas empty on each side, so the box grows
    // until the visible icon matches Windows' size.
    static let inkRatio: CGFloat = 0.805
    var iconBox: CGFloat { (iconSize / TaskbarMetrics.inkRatio).rounded() }

    // The running underline: button width less 5 points a side, 2 points tall, flush with the row bottom.
    static let underlineInset: CGFloat = 5
    static let underlineHeight: CGFloat = 2
    // The active button's highlight stops about two thirds of a point short of each neighbor.
    static let highlightInset: CGFloat = 0.67

    // Gap between the last app button and the tray, and the paging column when the row overflows.
    static let trayGap: CGFloat = 3.33
    static let pagerWidth: CGFloat = 17.33

    // Right end, measured from the screen's right edge.
    static let trayPitch: CGFloat = 32
    static let clockPadding: CGFloat = 6.67
    static let clockRightInset: CGFloat = 54
    static let notificationCenterInset: CGFloat = 33.67
    static let showDesktopWidth: CGFloat = 5.33
    static let showDesktopLine: CGFloat = 1.33
    static let showDesktopBottomGap: CGFloat = 2

    // San Francisco runs wider than Segoe UI, so the clock is set a half point under Windows' 12.
    static let clockFontSize: CGFloat = 11.5

    // The hidden status item flyout: three columns of 40 point cells.
    static let flyoutCell: CGFloat = 40
    static let flyoutColumns = 3
}
