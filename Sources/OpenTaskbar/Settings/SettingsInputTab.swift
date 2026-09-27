// SettingsInputTab.swift
// The Input tab: a switch for each keyboard and window module, the login item, and each permission's state.
// Exists so every module ported from init.lua can be turned off on its own, and missing grants are visible.
// Defines: SettingsInputTab
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsInputTab.swift.md
import SwiftUI

struct SettingsInputTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection(title: "Keyboard and windows") {
                ForEach(BarSettings.modules, id: \.self) { module in
                    Toggle(ModuleHost.labels[module] ?? module, isOn: model.module(module))
                }
                Text("F13 to F16 come from Karabiner-Elements mappings, which stay where they are.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsSection(title: "Login") {
                Toggle("Start OpenTaskbar at login", isOn: model.binding(\.launchAtLogin))
                    .onChange(of: model.value.launchAtLogin) { LoginItem.apply() }
                Text(LoginItem.statusText).font(.caption).foregroundStyle(.secondary)
                    .id(model.refresh)
            }
            SettingsSection(title: "Permissions") {
                ForEach(Permissions.Grant.allCases, id: \.self) { grant in
                    HStack(alignment: .top) {
                        Image(systemName: Permissions.granted(grant) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Permissions.granted(grant) ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(grant.rawValue)
                            Text(grant.purpose).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open") {
                            Permissions.request(grant)
                            Permissions.openPane(grant)
                        }
                    }
                    .id("\(grant.rawValue)\(model.refresh)")
                }
                Button("Set Up Permissions") { PermissionsSetup.shared.show() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
