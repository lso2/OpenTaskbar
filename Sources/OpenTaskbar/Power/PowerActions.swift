// PowerActions.swift
// Shut down, restart, log out, sleep, lock and display sleep.
// Exists so the Start panel and the context menus share one implementation of each power action.
// Defines: PowerActions
// Notes: docs/notes/app/Sources/OpenTaskbar/Power/PowerActions.swift.md
import AppKit
import IOKit.pwr_mgt

@MainActor
enum PowerActions {
    enum Action: String {
        case shutdown, restart, logout, sleep, lock, displaySleep
    }

    static func perform(_ action: Action) {
        switch action {
        case .shutdown: sendToLoginWindow(kAEShutDown)
        case .restart: sendToLoginWindow(kAERestart)
        case .logout: sendToLoginWindow(kAELogOut)
        case .sleep: sleepNow()
        case .lock: KeySender.stroke(keyCode: 12, flags: [.maskCommand, .maskControl])
        case .displaySleep: run("/usr/bin/pmset", ["displaysleepnow"])
        }
    }

    // loginwindow shows its own confirmation for these, the same path the Apple menu uses.
    // Sending them needs the Automation permission for loginwindow.
    private static func sendToLoginWindow(_ event: AEEventID) {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.loginwindow")
        let descriptor = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: event,
                                                targetDescriptor: target,
                                                returnID: AEReturnID(kAutoGenerateReturnID),
                                                transactionID: AETransactionID(kAnyTransactionID))
        do {
            _ = try descriptor.sendEvent(options: [.noReply], timeout: 10)
        } catch {
            Log.app.info("loginwindow event \(event) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func sleepNow() {
        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard port != 0 else { return }
        IOPMSleepSystem(port)
        IOServiceClose(port)
    }

    static func run(_ path: String, _ arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        do {
            try task.run()
        } catch {
            Log.app.info("\(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
