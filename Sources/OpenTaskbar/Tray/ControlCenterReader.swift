// ControlCenterReader.swift
// Reads the descriptions Control Center's status items publish and presses one of them by accessibility.
// Exists because those descriptions carry live state such as Wi-Fi bars, and pressing an item opens its native pane.
// Defines: ControlCenterReader
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/ControlCenterReader.swift.md
import AppKit
import ApplicationServices

@MainActor
final class ControlCenterReader {
    static let shared = ControlCenterReader()

    private var descriptions: [String] = []
    private var readAt = Date.distantPast
    private var reading = false
    private var loggedItems = false

    // Cached for three seconds; a stale answer returns at once while a fresh read runs on AXActor.
    func describe(_ fragment: String) -> String? {
        if Date().timeIntervalSince(readAt) > 3 { reread() }
        return descriptions.first { $0.lowercased().contains(fragment.lowercased()) }
    }

    private func reread() {
        guard !reading, AXIsProcessTrusted(), let pid = controlCenterPID else { return }
        reading = true
        let logItems = !loggedItems
        loggedItems = true
        Task { @AXActor in
            let items = ControlCenterReader.items(pid)
            if logItems {
                for item in items {
                    let line = "\(AX.string(item, kAXIdentifierAttribute) ?? "-") actions: \(AX.actions(item).joined(separator: ","))"
                    Log.tray.debug("control center item \(line, privacy: .public)")
                }
            }
            let found = items.compactMap { item -> String? in
                guard let text = AX.string(item, kAXDescriptionAttribute), !text.isEmpty else { return nil }
                // The system writes Wi-Fi with a non-breaking hyphen.
                return text.replacingOccurrences(of: "\u{2011}", with: "-")
            }
            await MainActor.run {
                let reader = ControlCenterReader.shared
                reader.descriptions = found
                reader.readAt = Date()
                reader.reading = false
            }
        }
    }

    private var controlCenterPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first?.processIdentifier
    }

    @AXActor
    static func items(_ pid: pid_t) -> [AXRef] {
        let app = AX.application(pid)
        guard let extras = AX.element(app, kAXExtrasMenuBarAttribute) else { return [] }
        return AX.elements(extras, kAXChildrenAttribute)
    }

    // Presses the first item whose identifier, description or title contains the fragment. The
    // press goes to the element itself; the pointer is never moved.
    func press(_ fragment: String) {
        guard AXIsProcessTrusted(), let pid = controlCenterPID else {
            Log.tray.info("control center press skipped: accessibility \(AXIsProcessTrusted())")
            return
        }
        let wanted = fragment.lowercased()
        Task { @AXActor in
            for item in ControlCenterReader.items(pid) {
                let names = [kAXIdentifierAttribute, kAXDescriptionAttribute, kAXTitleAttribute]
                    .compactMap { AX.string(item, $0)?.lowercased().replacingOccurrences(of: "\u{2011}", with: "-") }
                guard names.contains(where: { $0.contains(wanted) }) else { continue }
                let result = AX.performResult(item, kAXPressAction)
                Log.tray.info("control center press \(wanted, privacy: .public): AXError \(result.rawValue)")
                return
            }
            Log.tray.info("control center item not found: \(wanted, privacy: .public)")
        }
    }
}
