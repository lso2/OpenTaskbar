// WiFiPanelView.swift
// The content of the Wi-Fi flyout: the power switch, the joined network and the network lists.
// Exists as the presentation half of WiFiPanel, laid out in the order of the macOS Wi-Fi menu.
// Defines: WiFiPanelView, WiFiNetworkRow
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/WiFiPanelView.swift.md
import SwiftUI

struct WiFiPanelView: View {
    @Bindable var model: WiFiPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Wi-Fi").font(.system(size: 13, weight: .semibold))
                Spacer()
                FlyoutSwitch(isOn: model.powered) { WiFiPanel.shared.setPower($0) }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 14))
            rule
            if model.powered {
                ScrollView { lists.padding(.vertical, 4) }
            } else {
                Text("Wi-Fi is off").foregroundStyle(FlyoutStyle.dim).padding(14)
                Spacer(minLength: 0)
            }
            rule
            FlyoutRow(title: "Wi-Fi Settings...") { WiFiPanel.shared.openSettings() }
                .padding(.vertical, 4)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(FlyoutStyle.text)
        .frame(width: WiFiPanel.size.width, height: WiFiPanel.size.height, alignment: .top)
        .background(FlyoutStyle.background)
    }

    private var rule: some View {
        Rectangle().fill(FlyoutStyle.rule).frame(height: 1)
    }

    @ViewBuilder
    private var lists: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.locationAllowed {
                HStack(alignment: .top) {
                    Text("Network names need Location Services.").foregroundStyle(FlyoutStyle.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Allow") { WiFiPanel.shared.allowLocation() }.controlSize(.small)
                }
                .padding(EdgeInsets(top: 6, leading: 14, bottom: 8, trailing: 14))
            }
            if model.connected {
                header("Connected")
                WiFiNetworkRow(name: model.ssid ?? "Connected network", strength: model.strength, secure: false,
                               connected: true, busy: false, action: {})
            }
            if !model.known.isEmpty {
                header("Known Networks")
                ForEach(model.known) { row($0) }
            }
            header("Other Networks", busy: model.scanning)
            if model.others.isEmpty {
                Text(model.scanning ? "Searching..." : "No other networks found")
                    .foregroundStyle(FlyoutStyle.dim).padding(.horizontal, 14).padding(.vertical, 4)
            }
            ForEach(model.others) { row($0) }
            if let failure = model.failure {
                Text(failure).foregroundStyle(FlyoutStyle.dim).fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: 6, leading: 14, bottom: 4, trailing: 14))
            }
        }
    }

    private func header(_ title: String, busy: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(FlyoutStyle.dim)
            if busy { ProgressView().controlSize(.mini) }
        }
        .padding(EdgeInsets(top: 8, leading: 14, bottom: 3, trailing: 14))
    }

    @ViewBuilder
    private func row(_ network: NearbyNetwork) -> some View {
        WiFiNetworkRow(name: network.ssid, strength: network.strength, secure: network.secure, connected: false,
                       busy: model.joining == network.ssid) { WiFiPanel.shared.choose(network) }
        if model.askingPassword == network.ssid {
            HStack(spacing: 6) {
                SecureField("Password", text: $model.password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { WiFiPanel.shared.submitPassword() }
                Button("Join") { WiFiPanel.shared.submitPassword() }.controlSize(.small)
                Button("Cancel") { WiFiPanel.shared.cancelPassword() }.controlSize(.small)
            }
            .padding(EdgeInsets(top: 2, leading: 14, bottom: 6, trailing: 14))
        }
    }
}

// One network: the Wi-Fi symbol at its strength, the name, and a lock for secured networks.
struct WiFiNetworkRow: View {
    let name: String
    let strength: Double
    let secure: Bool
    let connected: Bool
    let busy: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(connected ? Color.accentColor : Color.white.opacity(0.14)).frame(width: 26, height: 26)
                Image(systemName: "wifi", variableValue: strength).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(name).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            if busy { ProgressView().controlSize(.mini) }
            if secure { Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(FlyoutStyle.dim) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(hover ? FlyoutStyle.hover : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .padding(.horizontal, 6)
        .onHover { hover = $0 }
        .onTapGesture { action() }
    }
}
