// SettingsControls.swift
// The labeled slider and section views every Settings tab is built from.
// Exists so each tab states only which setting a control edits, with one look for all of them.
// Defines: SliderRow, SettingsSection
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsControls.swift.md
import SwiftUI

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit = "%"

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.rounded()))\(unit)").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(.bottom, 14)
    }
}
