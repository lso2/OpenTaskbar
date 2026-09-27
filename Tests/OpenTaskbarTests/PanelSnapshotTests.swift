// PanelSnapshotTests.swift
// Renders the Start panel, the Wi-Fi flyout and the battery flyout at 2x and writes each render as a PNG.
// Exists so each panel's layout can be looked at without opening it on screen.
// Defines: PanelSnapshotTests
// Notes: docs/notes/app/Tests/OpenTaskbarTests/PanelSnapshotTests.swift.md
import AppKit
import SwiftUI
import Testing
@testable import OpenTaskbar

@MainActor
struct PanelSnapshotTests {
    // An offscreen window lets AppKit-backed controls such as switches and text fields draw.
    private func render<V: View>(_ view: V, size: NSSize, name: String) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let url = BarSnapshotTests.folder.appendingPathComponent("\(name).png")
        try data.write(to: url)
        print("snapshot: \(url.path)")
    }

    @Test func startPanel() throws {
        let model = StartModel()
        model.settings = BarSettings().clamped()
        model.apps = TestInputs.appPaths(12).map { path in
            CatalogApp(title: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, path: path, system: false)
        }
        try render(StartPanelView(model: model), size: NSSize(width: 480, height: 620), name: "start-panel")
    }

    @Test func wifiPanel() throws {
        let model = WiFiPanelModel()
        model.powered = true
        model.connected = true
        model.ssid = "Home"
        model.strength = 1
        model.locationAllowed = true
        model.networks = [
            NearbyNetwork(ssid: "Home", rssi: -45, secure: true, known: true),
            NearbyNetwork(ssid: "Office", rssi: -62, secure: true, known: true),
            NearbyNetwork(ssid: "Cafe Guest", rssi: -68, secure: false),
            NearbyNetwork(ssid: "Neighbor 5G", rssi: -78, secure: true),
        ]
        model.askingPassword = "Neighbor 5G"
        try render(WiFiPanelView(model: model), size: WiFiPanel.size, name: "wifi-panel")
    }

    @Test func batteryPanel() throws {
        let model = BatteryPanelModel()
        model.percent = 83
        model.minutesRemaining = 312
        model.apps = [EnergyApp(name: "Safari", path: "/Applications/Safari.app", watts: 2.4)]
        try render(BatteryPanelView(model: model), size: BatteryPanel.size, name: "battery-panel")
    }
}
