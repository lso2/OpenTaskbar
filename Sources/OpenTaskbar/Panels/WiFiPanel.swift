// WiFiPanel.swift
// The Wi-Fi flyout above the tray: power, the joined network, remembered and other networks, and joining.
// Exists as the native network list the macOS Wi-Fi menu shows, built on CoreWLAN.
// Defines: WiFiPanelModel, WiFiPanel
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/WiFiPanel.swift.md
import AppKit
import SwiftUI

@MainActor
@Observable
final class WiFiPanelModel {
    var powered = false
    var connected = false
    var ssid: String?
    var strength: Double = 0
    var locationAllowed = false
    var networks: [NearbyNetwork] = []
    var scanning = false
    var joining: String?
    var askingPassword: String?
    var password = ""
    var failure: String?

    var known: [NearbyNetwork] { networks.filter { $0.known && $0.ssid != ssid } }
    var others: [NearbyNetwork] { networks.filter { !$0.known && $0.ssid != ssid } }
}

@MainActor
final class WiFiPanel {
    static let shared = WiFiPanel()
    static let size = NSSize(width: 320, height: 440)

    let model = WiFiPanelModel()
    private let panel = PopupPanel(size: WiFiPanel.size)
    private var rescan: Timer?

    private init() {
        panel.takesKeyboard = true
        panel.contentView = NSHostingView(rootView: WiFiPanelView(model: model))
        panel.onDismiss = {
            let wifi = WiFiPanel.shared
            wifi.rescan?.invalidate()
            wifi.rescan = nil
            wifi.model.askingPassword = nil
            wifi.model.password = ""
            wifi.model.failure = nil
        }
        WiFi.shared.observe { if WiFiPanel.shared.panel.isOpen { WiFiPanel.shared.refresh() } }
    }

    var isOpen: Bool { panel.isOpen }

    func toggle(above anchor: NSRect, bar: BarView) {
        if panel.isOpen {
            panel.dismiss()
            return
        }
        WiFi.shared.requestLocationIfNeeded()
        WiFi.shared.refresh()
        refresh()
        scan()
        panel.present(size: WiFiPanel.size, above: anchor, bar: bar)
        // The system rescans on its own about this often while its Wi-Fi menu is open.
        rescan = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated { WiFiPanel.shared.scan() }
        }
    }

    func refresh() {
        let state = WiFi.shared.state
        model.powered = state.powered
        model.connected = state.connected
        model.ssid = state.ssid
        model.strength = Double(WiFi.shared.bars ?? 0) / 3
        model.locationAllowed = WiFi.shared.locationAllowed
    }

    func scan() {
        guard model.powered, !model.scanning else { return }
        model.scanning = true
        Task {
            let found = await WiFiNetworks.scan()
            let known = WiFiNetworks.knownNames()
            let model = WiFiPanel.shared.model
            model.networks = found.map { network in
                var entry = network
                entry.known = known.contains(network.ssid)
                return entry
            }
            model.scanning = false
        }
    }

    func setPower(_ on: Bool) {
        WiFi.shared.setPower(on)
        refresh()
        if on { scan() } else { model.networks = [] }
    }

    // Open networks and remembered ones are joined at once; a remembered network whose stored
    // password is not accepted, and any other secured network, asks for the password here.
    func choose(_ network: NearbyNetwork) {
        model.failure = nil
        guard network.ssid != model.ssid else { return }
        if network.secure && !network.known {
            askPassword(network.ssid)
            return
        }
        join(network.ssid, password: nil, secure: network.secure)
    }

    func submitPassword() {
        guard let ssid = model.askingPassword, !model.password.isEmpty else { return }
        join(ssid, password: model.password, secure: true)
    }

    func cancelPassword() {
        model.askingPassword = nil
        model.password = ""
    }

    private func askPassword(_ ssid: String) {
        model.askingPassword = ssid
        model.password = ""
        panel.makeKey()
    }

    private func join(_ ssid: String, password: String?, secure: Bool) {
        model.joining = ssid
        Task {
            let failure = await WiFiNetworks.join(ssid: ssid, password: password)
            let wifi = WiFiPanel.shared
            wifi.model.joining = nil
            if let failure {
                Log.tray.info("joining \(ssid, privacy: .public) failed: \(failure, privacy: .public)")
                if password == nil && secure { wifi.askPassword(ssid) } else { wifi.model.failure = failure }
            } else {
                wifi.cancelPassword()
                WiFi.shared.refresh()
                wifi.refresh()
            }
        }
    }

    func allowLocation() {
        if WiFi.shared.locationStatus == .notDetermined {
            WiFi.shared.requestLocationIfNeeded()
        } else {
            panel.dismiss()
            Permissions.openPane(.location)
        }
    }

    func openSettings() {
        panel.dismiss()
        TrayMenus.openPane("x-apple.systempreferences:com.apple.wifi-settings-extension")()
    }
}
