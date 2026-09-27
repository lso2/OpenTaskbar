// PermissionsSetupView.swift
// The content of the OpenTaskbar Permissions window: one row per grant and the walk's buttons.
// Exists as the presentation half of PermissionsSetup, which owns the walk and the window.
// Defines: PermissionsSetupView
// Notes: docs/notes/app/Sources/OpenTaskbar/App/PermissionsSetupView.swift.md
import SwiftUI

struct PermissionsSetupView: View {
    let setup: PermissionsSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Four permissions to turn on").font(.headline)
            Text("Continue opens each page in System Settings with OpenTaskbar already in the list. "
                 + "Turn on its switch and the next page opens by itself. Location asks with an Allow button. "
                 + "OpenTaskbar restarts after the last one.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(PermissionsSetup.required, id: \.self) { grant in
                row(grant)
            }
            HStack {
                Button("Later") { setup.later() }
                Spacer()
                if setup.current != nil {
                    Button("Restart Now") { StartContextMenu.relaunch() }
                }
                Button(setup.current == nil ? "Continue" : "Open Page Again") { setup.start() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 440)
    }

    private func row(_ grant: Permissions.Grant) -> some View {
        let isGranted = setup.granted[grant] == true
        let isCurrent = setup.current == grant
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : isCurrent ? "arrow.right.circle.fill" : "circle")
                .foregroundStyle(isGranted ? Color.green : isCurrent ? Color.accentColor : Color.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(grant.rawValue)
                Text(grant.purpose).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
