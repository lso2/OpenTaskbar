// SettingsModel.swift
// An observable copy of the settings that SwiftUI controls bind to, writing each change through SettingsStore.
// Exists so the Settings window redraws when the store changes and every edit reaches the bar at once.
// Defines: SettingsModel
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsModel.swift.md
import SwiftUI

@MainActor
@Observable
final class SettingsModel {
    static let shared = SettingsModel()

    var value = SettingsStore.shared.current
    var hour24 = ClockPreference.hour24
    var refresh = 0

    private init() {
        SettingsStore.shared.observe { SettingsModel.shared.value = SettingsStore.shared.current }
    }

    func binding<T>(_ path: WritableKeyPath<BarSettings, T>) -> Binding<T> {
        Binding(get: { self.value[keyPath: path] },
                set: { newValue in SettingsStore.shared.update { $0[keyPath: path] = newValue } })
    }

    func show(_ item: String) -> Binding<Bool> {
        Binding(get: { self.value.shows(item) },
                set: { on in SettingsStore.shared.update { $0.show[item] = on } })
    }

    func module(_ name: String) -> Binding<Bool> {
        Binding(get: { self.value.moduleOn(name) },
                set: { on in SettingsStore.shared.update { $0.moduleSwitches[name] = on } })
    }

    var hour24Binding: Binding<Bool> {
        Binding(get: { self.hour24 }, set: { on in
            ClockPreference.setHour24(on)
            self.hour24 = on
            BarController.shared.redraw()
        })
    }
}
