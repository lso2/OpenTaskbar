// HotKeyModule.swift
// A set of hotkey bindings that registers together when its module is switched on and unregisters when off.
// Exists so each init.lua behavior states its bindings once and the switch in Settings controls all of them.
// Defines: HotKeyModule, HotKeyModule.Binding
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/HotKeyModule.swift.md
import Foundation

@MainActor
final class HotKeyModule {
    // A named initializer gives each closure literal its full type up front.
    struct Binding {
        let key: HotKey
        let action: @MainActor @Sendable () -> Void

        init(_ key: HotKey, _ action: @escaping @MainActor @Sendable () -> Void) {
            self.key = key
            self.action = action
        }
    }

    private let bindings: [Binding]
    private var ids: [UInt32] = []

    init(_ bindings: [Binding]) {
        self.bindings = bindings
    }

    var running: Bool { !ids.isEmpty }

    func start() {
        guard ids.isEmpty else { return }
        ids = bindings.compactMap { HotKeyCenter.shared.register($0.key, $0.action) }
    }

    func stop() {
        for id in ids { HotKeyCenter.shared.unregister(id) }
        ids = []
    }
}
