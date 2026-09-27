// SettingsWindow.swift
// The Settings window and its tab strip.
// Exists as the native replacement for the web view settings page in bottombar-settings.lua.
// Defines: SettingsWindow, SettingsView
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsWindow.swift.md
import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private lazy var window: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        window.title = "OpenTaskbar Settings"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = NSHostingView(rootView: SettingsView(model: SettingsModel.shared))
        window.center()
        return window
    }()

    func show() {
        SettingsModel.shared.hour24 = ClockPreference.hour24
        SettingsModel.shared.refresh += 1
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        TabView {
            ScrollView { SettingsBarTab(model: model).padding(20) }.tabItem { Text("Bar") }
            ScrollView { SettingsItemsTab(model: model).padding(20) }.tabItem { Text("Items") }
            ScrollView { SettingsStartTab(model: model).padding(20) }.tabItem { Text("Start") }
            ScrollView { SettingsInputTab(model: model).padding(20) }.tabItem { Text("Input") }
            ScrollView { SettingsBackupTab().padding(20) }.tabItem { Text("Backup") }
        }
        .frame(width: 500, height: 720)
    }
}
