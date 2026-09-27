// WiFi.swift
// Wi-Fi power, association, network name and signal through CoreWLAN.
// Exists so the tray reads the network name once OpenTaskbar holds its own Location grant.
// Defines: WiFiState, WiFi
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/WiFi.swift.md
import CoreLocation
import CoreWLAN
import Foundation

struct WiFiState: Equatable {
    let powered: Bool
    let connected: Bool
    let ssid: String?
    let rssi: Int?
    let channel: Int?
    let address: String?
}

@MainActor
final class WiFi: NSObject {
    static let shared = WiFi()

    private(set) var state = WiFiState(powered: false, connected: false, ssid: nil, rssi: nil, channel: nil, address: nil)
    private var observers: [@MainActor () -> Void] = []
    private var location: CLLocationManager?
    private var started = false

    func observe(_ observer: @escaping @MainActor () -> Void) {
        observers.append(observer)
    }

    func start() {
        guard !started else { return }
        started = true
        let client = CWWiFiClient.shared()
        client.delegate = self
        for event in [CWEventType.powerDidChange, .ssidDidChange, .linkDidChange, .linkQualityDidChange] {
            try? client.startMonitoringEvent(with: event)
        }
        refresh()
    }

    var locationStatus: CLAuthorizationStatus {
        location?.authorizationStatus ?? CLLocationManager().authorizationStatus
    }

    // Raw values 3 and 4 are "always" and "when in use"; macOS reports either for a granted app.
    var locationAllowed: Bool {
        [3, 4].contains(locationStatus.rawValue)
    }

    // Asked at first use, from the Wi-Fi menu or tooltip, so the prompt appears next to the thing needing it.
    func requestLocationIfNeeded() {
        if location == nil {
            let manager = CLLocationManager()
            manager.delegate = self
            location = manager
        }
        if location?.authorizationStatus == .notDetermined {
            location?.requestWhenInUseAuthorization()
        }
    }

    func refresh() {
        let fresh = WiFi.read()
        guard fresh != state else { return }
        state = fresh
        for observer in observers { observer() }
    }

    static func read() -> WiFiState {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiState(powered: false, connected: false, ssid: nil, rssi: nil, channel: nil, address: nil)
        }
        let powered = interface.powerOn()
        let rssi = interface.rssiValue()
        let ssid = interface.ssid()
        let connected = powered && (ssid != nil || rssi != 0)
        return WiFiState(powered: powered, connected: connected, ssid: ssid,
                         rssi: connected ? rssi : nil,
                         channel: interface.wlanChannel()?.channelNumber,
                         address: connected ? ipv4Address(interface.interfaceName) : nil)
    }

    private static func ipv4Address(_ name: String?) -> String? {
        guard let name else { return nil }
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return nil }
        defer { freeifaddrs(head) }
        var cursor = head
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard String(cString: entry.pointee.ifa_name) == name,
                  let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            }
        }
        return nil
    }

    // Signal bars from RSSI, where Control Center's own description is not available.
    var bars: Int? {
        if let description = ControlCenterReader.shared.describe("wi-fi") ?? ControlCenterReader.shared.describe("wifi"),
           let match = description.firstMatch(of: /(\d+) bars?/), let value = Int(match.1) {
            return value
        }
        guard let rssi = state.rssi else { return nil }
        return rssi >= -60 ? 3 : rssi >= -70 ? 2 : 1
    }

    var summary: String {
        if !state.powered { return "Wi-Fi is off" }
        if !state.connected { return "Wi-Fi not connected" }
        var parts = [state.ssid ?? "Connected (name needs Location Services)"]
        if let bars { parts.append("\(bars) of 3 bars") }
        if let rssi = state.rssi { parts.append("\(rssi) dBm") }
        return parts.joined(separator: "   ")
    }

    func setPower(_ on: Bool) {
        try? CWWiFiClient.shared().interface()?.setPower(on)
        refresh()
    }

    // A Location answer changes what can be read without changing the Wi-Fi state, so observers always hear it.
    func locationChanged() {
        state = WiFi.read()
        for observer in observers { observer() }
    }
}

extension WiFi: CWEventDelegate {
    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in WiFi.shared.refresh() }
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in WiFi.shared.refresh() }
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in WiFi.shared.refresh() }
    }

    nonisolated func linkQualityDidChangeForWiFiInterface(withName interfaceName: String, rssi: Int, transmitRate: Double) {
        Task { @MainActor in WiFi.shared.refresh() }
    }
}

extension WiFi: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in WiFi.shared.locationChanged() }
    }
}
