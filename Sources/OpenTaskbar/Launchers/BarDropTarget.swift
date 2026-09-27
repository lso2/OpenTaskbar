// BarDropTarget.swift
// Decides what a drop on the bar does: an app pins, a file dropped on a launcher opens in that app.
// Exists because the native bar view is a real drop destination, which the Lua canvas could not be.
// Defines: BarDropTarget
// Notes: docs/notes/app/Sources/OpenTaskbar/Launchers/BarDropTarget.swift.md
import AppKit

@MainActor
enum BarDropTarget {
    static let types: [NSPasteboard.PasteboardType] = [.fileURL]

    static func urls(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    static func isApp(_ url: URL) -> Bool { url.pathExtension == "app" }

    // A file over a launcher asks to be opened by it; an app anywhere asks to be pinned.
    static func operation(_ info: NSDraggingInfo, launcherPath: String?) -> NSDragOperation {
        let dropped = urls(info)
        guard !dropped.isEmpty else { return [] }
        if dropped.allSatisfy(isApp) { return .link }
        return launcherPath != nil ? .copy : []
    }

    static func perform(_ info: NSDraggingInfo, launcherPath: String?) -> Bool {
        let dropped = urls(info)
        let apps = dropped.filter(isApp)
        let files = dropped.filter { !isApp($0) }

        for app in apps { PinnedStore.pin(app.path) }

        if !files.isEmpty, let launcherPath {
            PinnedStore.open(files: files, with: launcherPath)
            LauncherHop.shared.start(launcherPath)
        }
        return !apps.isEmpty || (!files.isEmpty && launcherPath != nil)
    }
}
