// ToolsPanel.swift
// Nine quick controls in a grid: timers, screen captures and screen recordings.
// Exists as the port of bottombar-tools.lua, drawn in SwiftUI in place of a web view.
// Defines: ToolsPanel, ToolsView, ToolCell
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/ToolsPanel.swift.md
import AppKit
import SwiftUI

@MainActor
final class ToolsPanel {
    static let shared = ToolsPanel()
    static let size = NSSize(width: 330, height: 292)

    private let panel = PopupPanel(size: ToolsPanel.size)

    var isOpen: Bool { panel.isOpen }

    func toggle(above anchor: NSRect, bar: BarView) {
        if panel.isOpen {
            panel.dismiss()
            return
        }
        panel.contentView = NSHostingView(rootView: ToolsView(recording: ScreenRecorder.shared.isRecording) { action in
            ToolsPanel.shared.run(action)
        })
        panel.present(size: ToolsPanel.size, above: anchor, bar: bar)
    }

    enum Action { case timer, stopwatch, alarm, captureScreen, captureSelection, captureCustom
                  case recordScreen, recordSelection, recordCustom, stop }

    // The pane is gone before a capture starts, so it never appears in the picture.
    private func run(_ action: Action) {
        panel.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            MainActor.assumeIsolated {
                switch action {
                case .timer, .stopwatch, .alarm: BarClickActions.openApp("com.apple.clock")
                case .captureScreen: KeySender.stroke(keyCode: KeySender.three, flags: [.maskCommand, .maskShift])
                case .captureSelection: KeySender.stroke(keyCode: KeySender.four, flags: [.maskCommand, .maskShift])
                case .captureCustom, .recordSelection, .recordCustom:
                    KeySender.stroke(keyCode: KeySender.five, flags: [.maskCommand, .maskShift])
                case .recordScreen: ScreenRecorder.shared.start()
                case .stop: ScreenRecorder.shared.stop()
                }
            }
        }
    }
}

struct ToolsView: View {
    let recording: Bool
    let run: @MainActor (ToolsPanel.Action) -> Void

    private let background = Color(red: 31 / 255, green: 31 / 255, blue: 34 / 255)
    private let text = Color(red: 236 / 255, green: 236 / 255, blue: 239 / 255)
    private let group = Color(red: 143 / 255, green: 143 / 255, blue: 153 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Time", [("Timer", "timer", .timer), ("Stopwatch", "stopwatch", .stopwatch), ("Alarm", "alarm", .alarm)])
            section("Capture", [("Screen", "rectangle", .captureScreen), ("Selection", "rectangle.dashed", .captureSelection),
                                ("Custom", "rectangle.badge.plus", .captureCustom)])
            section("Record", [recording ? ("Stop", "stop.fill", .stop) : ("Screen", "record.circle", .recordScreen),
                               ("Selection", "rectangle.dashed.badge.record", .recordSelection),
                               ("Custom", "circle.circle", .recordCustom)], last: true)
        }
        .padding(EdgeInsets(top: 12, leading: 10, bottom: 18, trailing: 10))
        .frame(width: ToolsPanel.size.width, height: ToolsPanel.size.height, alignment: .topLeading)
        .background(background)
    }

    private func section(_ title: String, _ cells: [(String, String, ToolsPanel.Action)], last: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 11)).foregroundStyle(group).padding(.horizontal, 4)
            HStack(spacing: 4) {
                ForEach(cells.indices, id: \.self) { index in
                    ToolCell(label: cells[index].0, symbol: cells[index].1, on: cells[index].2 == .stop, text: text) {
                        run(cells[index].2)
                    }
                }
            }
        }
        .padding(.bottom, last ? 0 : 14)
    }
}

private struct ToolCell: View {
    let label: String
    let symbol: String
    let on: Bool
    let text: Color
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 17, weight: .light)).frame(height: 22)
                Text(label).font(.system(size: 11.5))
            }
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 9, leading: 4, bottom: 8, trailing: 4))
            .background(fill, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private var fill: Color {
        if on { return hover ? Color(red: 125 / 255, green: 38 / 255, blue: 38 / 255) : Color(red: 107 / 255, green: 32 / 255, blue: 32 / 255) }
        return hover ? Color(red: 51 / 255, green: 51 / 255, blue: 58 / 255) : .clear
    }
}
