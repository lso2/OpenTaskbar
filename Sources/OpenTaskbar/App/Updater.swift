// Updater.swift
// Starts Sparkle's updater at launch and runs a check when asked.
// Exists so releases published to lso2/OpenTaskbar reach installed copies through the signed appcast.
// Defines: Updater
// Notes: docs/notes/app/Sources/OpenTaskbar/App/Updater.swift.md
import AppKit
import Sparkle

@MainActor
final class Updater {
    static let shared = Updater()

    // The feed address and public key come from SUFeedURL and SUPublicEDKey in Info.plist.
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil,
                                                          userDriverDelegate: nil)

    func start() {
        controller.startUpdater()
    }

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}
