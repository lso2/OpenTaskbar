// FlyoutStyle.swift
// The colors, the switch and the plain link row the SwiftUI tray flyouts share.
// Exists so the Wi-Fi and battery flyouts match the Tools pane without repeating its values.
// Defines: FlyoutStyle, FlyoutRow, FlyoutSwitch
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/FlyoutStyle.swift.md
import SwiftUI

// The colors the tray flyouts share with the Tools pane.
enum FlyoutStyle {
    static let background = Color(red: 31 / 255, green: 31 / 255, blue: 34 / 255)
    static let text = Color(red: 236 / 255, green: 236 / 255, blue: 239 / 255)
    static let dim = Color(red: 143 / 255, green: 143 / 255, blue: 153 / 255)
    static let hover = Color.white.opacity(0.08)
    static let rule = Color.white.opacity(0.12)
}

// A one-line text row that lights up under the pointer, for the flyouts' closing links.
struct FlyoutRow: View {
    let title: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Text(title).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(hover ? FlyoutStyle.hover : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .padding(.horizontal, 6)
            .onHover { hover = $0 }
            .onTapGesture { action() }
    }
}

// A switch drawn in the accent color when on. The system switch draws gray in a window that is
// not key, and the flyouts never become key, so on and off would differ only by the knob's side.
struct FlyoutSwitch: View {
    let isOn: Bool
    let action: (Bool) -> Void

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? Color.accentColor : Color.white.opacity(0.22))
            Circle().fill(Color.white).padding(2)
        }
        .frame(width: 32, height: 18)
        .contentShape(Capsule())
        .onTapGesture { action(!isOn) }
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}
