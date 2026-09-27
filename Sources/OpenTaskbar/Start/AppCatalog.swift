// AppCatalog.swift
// The applications the Start panel lists, read from the standard application folders.
// Exists so the panel's list, search and pinning all work from one sorted catalog.
// Defines: AppCatalog, CatalogApp
// Notes: docs/notes/app/Sources/OpenTaskbar/Start/AppCatalog.swift.md
import AppKit

struct CatalogApp: Identifiable, Hashable, Sendable {
    let title: String
    let path: String
    let system: Bool
    var id: String { path }
}

@MainActor
enum AppCatalog {
    // Installed apps show by default; the system folders appear under All Programs.
    static let folders: [(path: String, system: Bool)] = [
        ("/Applications", false),
        (FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path, false),
        ("/Applications/Utilities", true),
        ("/System/Applications", true),
        ("/System/Applications/Utilities", true),
    ]

    private static var icons: [String: NSImage] = [:]

    // The first folder to hold a name wins, so an app in two folders is listed once.
    static func load() -> [CatalogApp] {
        var seen = Set<String>()
        var apps: [CatalogApp] = []
        for folder in folders {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names where name.hasSuffix(".app") && !name.hasPrefix(".") {
                let title = String(name.dropLast(4))
                guard seen.insert(title).inserted else { continue }
                apps.append(CatalogApp(title: title, path: "\(folder.path)/\(name)", system: folder.system))
            }
        }
        return apps.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func icon(_ path: String) -> NSImage {
        if let cached = icons[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        icons[path] = image
        return image
    }
}
