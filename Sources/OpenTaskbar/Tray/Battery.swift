// Battery.swift
// Charge, charging state, time remaining, condition and cycle count from IOKit.
// Exists so the battery mark redraws on the system's own power source notifications.
// Defines: BatteryState, Battery
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/Battery.swift.md
import Foundation
import IOKit
import IOKit.ps

struct BatteryState: Equatable {
    let present: Bool
    let percent: Double
    let charging: Bool
    let onAdapter: Bool
    let minutesRemaining: Int?     // nil while the system is still estimating
    let condition: String?
    let cycles: Int?
}

@MainActor
final class Battery {
    static let shared = Battery()

    private(set) var state = BatteryState(present: false, percent: 0, charging: false, onAdapter: true,
                                          minutesRemaining: nil, condition: nil, cycles: nil)
    private var observers: [@MainActor () -> Void] = []
    private var started = false

    func observe(_ observer: @escaping @MainActor () -> Void) {
        observers.append(observer)
    }

    func start() {
        guard !started else { return }
        started = true
        refresh()
        if let source = IOPSNotificationCreateRunLoopSource(batteryChanged, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func refresh() {
        let fresh = Battery.read()
        guard fresh != state else { return }
        state = fresh
        for observer in observers { observer() }
    }

    static func read() -> BatteryState {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let current = Double(description[kIOPSCurrentCapacityKey] as? Int ?? 0)
            let maximum = Double(description[kIOPSMaxCapacityKey] as? Int ?? 100)
            let onAdapter = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let estimate = IOPSGetTimeRemainingEstimate()
            let minutes: Int? = estimate == kIOPSTimeRemainingUnknown ? nil
                : estimate == kIOPSTimeRemainingUnlimited ? -2 : Int(estimate / 60)

            return BatteryState(present: true,
                                percent: maximum > 0 ? (current / maximum) * 100 : 0,
                                charging: description[kIOPSIsChargingKey] as? Bool ?? false,
                                onAdapter: onAdapter,
                                minutesRemaining: minutes,
                                condition: description[kIOPSBatteryHealthKey] as? String,
                                cycles: cycleCount())
        }
        return BatteryState(present: false, percent: 0, charging: false, onAdapter: true,
                            minutesRemaining: -2, condition: nil, cycles: nil)
    }

    private static func cycleCount() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)
        return value?.takeRetainedValue() as? Int
    }

    var summary: String {
        let percent = Int(state.percent.rounded(.down))
        if state.charging { return "\(percent)%   charging" }
        if let minutes = state.minutesRemaining, minutes > 0 {
            return String(format: "%d%%   %d h %02d m left", percent, minutes / 60, minutes % 60)
        }
        if state.minutesRemaining == -2 { return "\(percent)%   on power adapter" }
        return "\(percent)%"
    }
}

// IOKit calls this on the main run loop, where Battery.start placed the source.
private func batteryChanged(_ context: UnsafeMutableRawPointer?) {
    MainActor.assumeIsolated { Battery.shared.refresh() }
}
