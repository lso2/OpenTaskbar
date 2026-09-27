// main.swift
// Process entry point for OpenTaskbar.
// Starts an accessory application, which has no Dock icon, and hands control to AppDelegate.
// Defines: no types
// Notes: docs/notes/app/Sources/OpenTaskbar/App/main.swift.md
import AppKit

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
