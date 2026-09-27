// SettingsStore.swift
// Holds the live BarSettings and writes it to UserDefaults under one key on every change.
// Exists so every module reads one current value and hears about changes the moment they land.
// Defines: SettingsStore
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsStore.swift.md
import Foundation

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    static let key = "barSettings"

    private(set) var current: BarSettings
    private var observers: [@MainActor () -> Void] = []

    private init() {
        current = SettingsStore.decode(UserDefaults.standard.dictionary(forKey: SettingsStore.key))
            ?? BarSettings()
    }

    var hasStoredValue: Bool {
        UserDefaults.standard.dictionary(forKey: SettingsStore.key) != nil
    }

    // A property list dictionary goes through JSON so it meets the same lenient decoder
    // that reads Lua backups and Hammerspoon's plist.
    static func decode(_ dictionary: [String: Any]?) -> BarSettings? {
        guard let dictionary,
              JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary) else { return nil }
        return try? JSONDecoder().decode(BarSettings.self, from: data)
    }

    static func propertyList(_ settings: BarSettings) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(settings),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }

    func replace(_ settings: BarSettings) {
        let clamped = settings.clamped()
        guard clamped != current else { return }
        current = clamped
        if let plist = SettingsStore.propertyList(clamped) {
            UserDefaults.standard.set(plist, forKey: SettingsStore.key)
        }
        for observer in observers { observer() }
    }

    func update(_ change: (inout BarSettings) -> Void) {
        var value = current
        change(&value)
        replace(value)
    }

    func observe(_ observer: @escaping @MainActor () -> Void) {
        observers.append(observer)
    }
}
