// CalendarPanel.swift
// The month calendar that rises above the clock, with today marked and arrows to move by month.
// Exists as the port of bottombar-calendar.lua, drawn in SwiftUI in place of a web view.
// Defines: CalendarPanel, CalendarModel, CalendarView
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/CalendarPanel.swift.md
import AppKit
import SwiftUI

@MainActor
final class CalendarPanel {
    static let shared = CalendarPanel()
    static let size = NSSize(width: 230, height: 250)

    private let panel = PopupPanel(size: CalendarPanel.size)
    private let model = CalendarModel()

    private init() {
        panel.contentView = NSHostingView(rootView: CalendarView(model: model))
    }

    var isOpen: Bool { panel.isOpen }

    // Right-aligned with the clock, the way the popup sat over the Lua bar's clock.
    func toggle(above anchor: NSRect, bar: BarView) {
        if panel.isOpen {
            panel.dismiss()
            return
        }
        model.shown = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let aligned = NSRect(x: anchor.maxX - CalendarPanel.size.width, y: anchor.minY,
                             width: CalendarPanel.size.width, height: anchor.height)
        panel.present(size: CalendarPanel.size, above: aligned, bar: bar)
    }
}

@MainActor
@Observable
final class CalendarModel {
    var shown = Date()

    func step(_ months: Int) {
        shown = Calendar.current.date(byAdding: .month, value: months, to: shown) ?? shown
    }
}

struct CalendarView: View {
    let model: CalendarModel

    private static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    private let background = Color(red: 31 / 255, green: 31 / 255, blue: 34 / 255)
    private let text = Color(red: 236 / 255, green: 236 / 255, blue: 239 / 255)
    private let muted = Color(red: 154 / 255, green: 154 / 255, blue: 162 / 255)
    private let today = Color(red: 47 / 255, green: 111 / 255, blue: 208 / 255)

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        VStack(alignment: .leading, spacing: 0) {
            Text(now.formatted(.dateTime.weekday(.wide))).font(.system(size: 13, weight: .semibold)).foregroundStyle(text)
            Text(now.formatted(.dateTime.month(.wide).day().year())).font(.system(size: 12)).foregroundStyle(muted)
                .padding(.bottom, 12)
            HStack {
                Text(model.shown.formatted(.dateTime.month(.wide).year())).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(text)
                Spacer()
                Button("\u{2039}") { model.step(-1) }.buttonStyle(.plain).foregroundStyle(text)
                    .padding(.horizontal, 7)
                Button("\u{203A}") { model.step(1) }.buttonStyle(.plain).foregroundStyle(text)
                    .padding(.horizontal, 7)
            }
            .padding(.bottom, 8)
            let days = monthDays(calendar)
            Grid(horizontalSpacing: 0, verticalSpacing: 2) {
                GridRow {
                    ForEach(0..<7, id: \.self) { index in
                        Text(CalendarView.weekdays[index]).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(muted).frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<(days.count / 7), id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { column in
                            let day = days[(row * 7) + column]
                            let isToday = day.map { calendar.isDate($0, inSameDayAs: now) } ?? false
                            Text(day.map { "\(calendar.component(.day, from: $0))" } ?? "")
                                .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                                .foregroundStyle(isToday ? .white : text)
                                .frame(maxWidth: .infinity, minHeight: 20)
                                .background(isToday ? today : .clear, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
        .frame(width: CalendarPanel.size.width, height: CalendarPanel.size.height, alignment: .topLeading)
        .background(background)
    }

    // Blank cells before the first day and after the last, padded to whole weeks.
    private func monthDays(_ calendar: Calendar) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: model.shown) else { return [] }
        let leading = calendar.component(.weekday, from: model.shown) - 1
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: model.shown))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}
