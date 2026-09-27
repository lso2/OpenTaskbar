// WiFiNetworks.swift
// Scans for nearby Wi-Fi networks, lists the remembered ones, and joins a network through CoreWLAN.
// Exists as the network list behind the Wi-Fi panel, kept off the main thread since scans block for seconds.
// Defines: NearbyNetwork, WiFiNetworks
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/WiFiNetworks.swift.md
import CoreWLAN
import Foundation

struct NearbyNetwork: Sendable, Equatable, Identifiable {
    let ssid: String
    let rssi: Int
    let secure: Bool
    var known = false

    var id: String { ssid }

    // The three strengths the system's Wi-Fi symbol draws.
    var strength: Double { rssi >= -60 ? 1 : rssi >= -70 ? 0.66 : 0.33 }
}

enum WiFiNetworks {
    // Names are blank without Location Services, so unnamed networks are left out.
    static func scan() async -> [NearbyNetwork] {
        await Task.detached {
            guard let interface = CWWiFiClient.shared().interface(),
                  let networks = try? interface.scanForNetworks(withName: nil) else { return [] }
            var best: [String: NearbyNetwork] = [:]
            for network in networks {
                guard let ssid = network.ssid, !ssid.isEmpty else { continue }
                let found = NearbyNetwork(ssid: ssid, rssi: network.rssiValue, secure: !network.supportsSecurity(.none))
                if (best[ssid]?.rssi ?? Int.min) < found.rssi { best[ssid] = found }
            }
            return best.values.sorted { $0.rssi > $1.rssi }
        }.value
    }

    // The networks in the system's remembered list, by name.
    static func knownNames() -> Set<String> {
        guard let profiles = CWWiFiClient.shared().interface()?.configuration()?.networkProfiles.array as? [CWNetworkProfile]
        else { return [] }
        return Set(profiles.compactMap(\.ssid))
    }

    // Nil when joined, otherwise the system's own error text.
    static func join(ssid: String, password: String?) async -> String? {
        await Task.detached {
            guard let interface = CWWiFiClient.shared().interface() else { return "No Wi-Fi interface" }
            do {
                let found = try interface.scanForNetworks(withName: ssid)
                guard let network = found.max(by: { $0.rssiValue < $1.rssiValue }) else { return "\(ssid) is out of range" }
                try interface.associate(to: network, password: password)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
    }
}
