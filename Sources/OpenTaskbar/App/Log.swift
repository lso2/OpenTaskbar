// Log.swift
// One os.Logger per area of the app, readable in Console.app under com.plexpixel.OpenTaskbar.
// Exists so every module logs through the same subsystem with a category naming its area.
// Defines: Log
// Notes: docs/notes/app/Sources/OpenTaskbar/App/Log.swift.md
import os

enum Log {
    static let subsystem = "com.plexpixel.OpenTaskbar"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let bar = Logger(subsystem: subsystem, category: "bar")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let windows = Logger(subsystem: subsystem, category: "windows")
    static let menus = Logger(subsystem: subsystem, category: "menus")
    static let tray = Logger(subsystem: subsystem, category: "tray")
    static let input = Logger(subsystem: subsystem, category: "input")
    static let panels = Logger(subsystem: subsystem, category: "panels")
}
