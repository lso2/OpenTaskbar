// EnergyUsage.swift
// Measures how much power each running app draws, from the kernel's per-process energy counters.
// Exists as the "Using Significant Energy" list of the battery flyout.
// Defines: EnergyApp, EnergyUsage
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/EnergyUsage.swift.md
import AppKit
import Darwin

struct EnergyApp: Identifiable, Equatable {
    let name: String
    let path: String?
    let watts: Double
    var id: String { name }
}

@MainActor
enum EnergyUsage {
    // An app drawing at least this much over the sample is listed.
    static let significantWatts = 1.0
    static let interval: Duration = .seconds(2)

    // Two readings of every app's energy, the sample interval apart, turned into watts.
    static func significant() async -> [EnergyApp] {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let appPIDs = Set(apps.map(\.processIdentifier))
        let first = reading(appPIDs)
        let start = ContinuousClock.now
        try? await Task.sleep(for: interval)
        let second = reading(appPIDs)
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds) + (Double(elapsed.components.attoseconds) / 1e18)
        guard seconds > 0 else { return [] }

        var found: [EnergyApp] = []
        for app in apps {
            let pid = app.processIdentifier
            guard let before = first[pid], let after = second[pid], after > before else { continue }
            let watts = Double(after - before) / 1e9 / seconds
            guard watts >= significantWatts else { continue }
            found.append(EnergyApp(name: app.localizedName ?? "App", path: app.bundleURL?.path, watts: watts))
        }
        return found.sorted { $0.watts > $1.watts }
    }

    // Nanojoules per app so far, with each helper process counted toward the app above it.
    static func reading(_ appPIDs: Set<pid_t>) -> [pid_t: UInt64] {
        let pids = allPIDs()
        var parents: [pid_t: pid_t] = [:]
        for pid in pids { parents[pid] = parent(of: pid) }
        var totals: [pid_t: UInt64] = [:]
        for pid in pids {
            guard let owner = owner(of: pid, apps: appPIDs, parents: parents), let energy = energy(of: pid) else { continue }
            totals[owner, default: 0] += energy
        }
        return totals
    }

    private static func owner(of pid: pid_t, apps: Set<pid_t>, parents: [pid_t: pid_t]) -> pid_t? {
        var current = pid
        for _ in 0..<16 {
            if apps.contains(current) { return current }
            guard let next = parents[current], next > 1, next != current else { return nil }
            current = next
        }
        return nil
    }

    private static func allPIDs() -> [pid_t] {
        let count = Int(proc_listallpids(nil, 0))
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: count + 64)
        let filled = pids.withUnsafeMutableBufferPointer { buffer in
            Int(proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.size)))
        }
        return Array(pids.prefix(max(0, filled))).filter { $0 > 0 }
    }

    private static func parent(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    // Processes of other users refuse the read, and are skipped.
    private static func energy(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
        }
        return result == 0 ? info.ri_energy_nj : nil
    }
}
