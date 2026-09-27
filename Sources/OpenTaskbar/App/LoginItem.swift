// LoginItem.swift
// Registers OpenTaskbar to start at login through SMAppService and reports the registration status.
// Exists so Settings can show whether the login item is in force, read fresh at every launch.
// Defines: LoginItem
// Notes: docs/notes/app/Sources/OpenTaskbar/App/LoginItem.swift.md
import Foundation
import ServiceManagement

@MainActor
enum LoginItem {
    // Only a copy in an Applications folder registers, so a build folder never becomes the login item.
    static var inApplications: Bool {
        let path = Bundle.main.bundlePath
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/")
    }

    static func apply() {
        let wanted = SettingsStore.shared.current.launchAtLogin
        let service = SMAppService.mainApp
        Log.app.info("login item status at launch: \(statusText, privacy: .public)")
        guard inApplications else { return }
        do {
            if wanted && service.status != .enabled {
                try service.register()
            } else if !wanted && service.status == .enabled {
                try service.unregister()
            }
        } catch {
            Log.app.info("login item change failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static var statusText: String {
        if !inApplications { return "Not registered: OpenTaskbar is not in an Applications folder" }
        switch SMAppService.mainApp.status {
        case .enabled: return "Starts at login"
        case .notRegistered: return "Does not start at login"
        case .requiresApproval: return "Waiting for approval in System Settings, General, Login Items"
        case .notFound: return "Login item not found"
        @unknown default: return "Unknown status"
        }
    }
}
