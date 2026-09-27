// Permissions.swift
// Reads and requests the privacy grants OpenTaskbar uses, and opens their System Settings panes.
// Exists so Settings and the first-launch walk list each grant's state and ask for it.
// Defines: Permissions
// Notes: docs/notes/app/Sources/OpenTaskbar/App/Permissions.swift.md
import AppKit
import ApplicationServices
import CoreLocation

@MainActor
enum Permissions {
    enum Grant: String, CaseIterable {
        case accessibility = "Accessibility"
        case inputMonitoring = "Input Monitoring"
        case screenRecording = "Screen Recording"
        case location = "Location"

        var purpose: String {
            switch self {
            case .accessibility: return "Window list, app menus, Dock menus, status items, key and click rewriting"
            case .inputMonitoring: return "Opening Start by tapping a modifier key"
            case .screenRecording: return "Live window previews, screen recording, status item capture"
            case .location: return "Wi-Fi network names in the Wi-Fi panel"
            }
        }

        var pane: String {
            switch self {
            case .accessibility: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .inputMonitoring: return "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            case .screenRecording: return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .location: return "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
            }
        }
    }

    static func granted(_ grant: Grant) -> Bool {
        switch grant {
        case .accessibility: return AXIsProcessTrusted()
        case .inputMonitoring: return CGPreflightListenEventAccess()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .location: return WiFi.shared.locationAllowed
        }
    }

    static func request(_ grant: Grant) {
        switch grant {
        case .accessibility:
            // The value of kAXTrustedCheckOptionPrompt, which Swift 6 treats as shared mutable state.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .inputMonitoring: CGRequestListenEventAccess()
        case .screenRecording: CGRequestScreenCaptureAccess()
        case .location: WiFi.shared.requestLocationIfNeeded()
        }
    }

    static func openPane(_ grant: Grant) {
        if let url = URL(string: grant.pane) { NSWorkspace.shared.open(url) }
    }
}
