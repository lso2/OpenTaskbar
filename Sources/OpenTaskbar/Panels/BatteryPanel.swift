// BatteryPanel.swift
// The battery flyout above the tray: charge, power source, time, Low Power Mode and apps drawing significant power.
// Exists as the native battery menu macOS shows, built on IOKit and the kernel's energy counters.
// Defines: BatteryPanelModel, BatteryPanel
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/BatteryPanel.swift.md
import AppKit
import SwiftUI

@MainActor
@Observable
final class BatteryPanelModel {
    var percent: Double = 0
    var charging = false
    var onAdapter = false
    var minutesRemaining: Int?
    var lowPower = false
    var apps: [EnergyApp] = []
    var measuring = false

    var source: String { onAdapter ? "Power Adapter" : "Battery" }

    // The wording of the macOS battery menu for each state IOKit reports.
    var status: String {
        if charging { return "Charging" }
        if onAdapter { return percent >= 99 ? "Fully Charged" : "Not Charging" }
        guard let minutes = minutesRemaining, minutes > 0 else { return "Calculating Time Remaining" }
        return String(format: "%d:%02d Remaining", minutes / 60, minutes % 60)
    }
}

@MainActor
final class BatteryPanel {
    static let shared = BatteryPanel()
    static let size = NSSize(width: 300, height: 320)

    let model = BatteryPanelModel()
    private let panel = PopupPanel(size: BatteryPanel.size)

    private init() {
        panel.contentView = NSHostingView(rootView: BatteryPanelView(model: model))
        Battery.shared.observe { if BatteryPanel.shared.panel.isOpen { BatteryPanel.shared.refresh() } }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BatteryPanel.shared.model.lowPower = LowPowerMode.isOn }
        }
    }

    var isOpen: Bool { panel.isOpen }

    func toggle(above anchor: NSRect, bar: BarView) {
        if panel.isOpen {
            panel.dismiss()
            return
        }
        Battery.shared.refresh()
        refresh()
        measure()
        panel.present(size: BatteryPanel.size, above: anchor, bar: bar)
    }

    func refresh() {
        let state = Battery.shared.state
        model.percent = state.percent
        model.charging = state.charging
        model.onAdapter = state.onAdapter
        model.minutesRemaining = state.minutesRemaining
        model.lowPower = LowPowerMode.isOn
    }

    private func measure() {
        guard !model.measuring else { return }
        model.measuring = true
        Task {
            let apps = await EnergyUsage.significant()
            let model = BatteryPanel.shared.model
            model.apps = apps
            model.measuring = false
        }
    }

    func setLowPower(_ on: Bool) {
        Task {
            let ran = await LowPowerMode.set(on)
            Log.tray.info("low power mode \(on ? "on" : "off", privacy: .public): pmset ran \(ran)")
            BatteryPanel.shared.model.lowPower = LowPowerMode.isOn
        }
    }

    func open(_ app: EnergyApp) {
        panel.dismiss()
        guard let path = app.path else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openSettings() {
        panel.dismiss()
        TrayMenus.openPane("x-apple.systempreferences:com.apple.Battery-Settings.extension")()
    }
}
