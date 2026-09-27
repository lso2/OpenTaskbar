// BatteryPanelView.swift
// The content of the battery flyout, in the order of the macOS battery menu.
// Exists as the presentation half of BatteryPanel.
// Defines: BatteryPanelView
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/BatteryPanelView.swift.md
import AppKit
import SwiftUI

struct BatteryPanelView: View {
    @Bindable var model: BatteryPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Battery").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(model.percent.rounded(.down)))%").foregroundStyle(FlyoutStyle.dim)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 4, trailing: 14))
            Text("Power Source: \(model.source)").foregroundStyle(FlyoutStyle.dim).padding(.horizontal, 14)
            Text(model.status).foregroundStyle(FlyoutStyle.dim)
                .padding(EdgeInsets(top: 2, leading: 14, bottom: 10, trailing: 14))
            rule
            HStack {
                Text("Low Power Mode")
                Spacer()
                FlyoutSwitch(isOn: model.lowPower) { BatteryPanel.shared.setLowPower($0) }
            }
            .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            rule
            HStack(spacing: 6) {
                Text("Using Significant Energy").font(.system(size: 11, weight: .semibold)).foregroundStyle(FlyoutStyle.dim)
                if model.measuring { ProgressView().controlSize(.mini) }
            }
            .padding(EdgeInsets(top: 8, leading: 14, bottom: 3, trailing: 14))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.apps.isEmpty {
                        Text(model.measuring ? "Measuring..." : "No Apps Using Significant Energy")
                            .foregroundStyle(FlyoutStyle.dim).padding(.horizontal, 14).padding(.vertical, 4)
                    }
                    ForEach(model.apps) { app in appRow(app) }
                }
            }
            rule
            FlyoutRow(title: "Battery Settings...") { BatteryPanel.shared.openSettings() }
                .padding(.vertical, 4)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(FlyoutStyle.text)
        .frame(width: BatteryPanel.size.width, height: BatteryPanel.size.height, alignment: .top)
        .background(FlyoutStyle.background)
    }

    private var rule: some View {
        Rectangle().fill(FlyoutStyle.rule).frame(height: 1)
    }

    private func appRow(_ app: EnergyApp) -> some View {
        HStack(spacing: 8) {
            if let path = app.path {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 18, height: 18)
            }
            Text(app.name).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { BatteryPanel.shared.open(app) }
    }
}
