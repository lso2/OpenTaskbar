// LauncherHop.swift
// The short hop a launcher makes when pressed, the way a Dock icon bounces.
// Exists so a click that starts a slow app shows a response before the app appears.
// Defines: LauncherHop
// Notes: docs/notes/app/Sources/OpenTaskbar/Launchers/LauncherHop.swift.md
import AppKit

@MainActor
final class LauncherHop {
    static let shared = LauncherHop()

    // Fractions of the full lift per 26 millisecond step, from bottombar-pinned.lua.
    private static let rise: [CGFloat] = [0.35, 0.7, 0.92, 1, 0.92, 0.66, 0.36, 0.12]

    private var path: String?
    private var step = 0
    private var timer: Timer?

    func start(_ path: String) {
        timer?.invalidate()
        self.path = path
        step = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.026, repeats: true) { _ in
            MainActor.assumeIsolated { LauncherHop.shared.advance() }
        }
    }

    static let height: CGFloat = 4

    // Points to raise the launcher at path by at this step of the hop.
    func lift(for path: String) -> CGFloat {
        guard path == self.path, step > 0, step <= LauncherHop.rise.count else { return 0 }
        return LauncherHop.rise[step - 1] * LauncherHop.height
    }

    private func advance() {
        step += 1
        if step > LauncherHop.rise.count {
            timer?.invalidate()
            timer = nil
            path = nil
        }
        BarController.shared.redraw()
    }
}
