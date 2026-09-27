// StartIconStore.swift
// Resolves which image the Start launcher draws: a built-in, the user's own, or the drawn mark.
// Exists so the bar, the settings window and backups agree on where launcher images are kept.
// Defines: StartIconStore
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/StartIconStore.swift.md
import AppKit

@MainActor
enum StartIconStore {
    static let builtIn = ["start-orb", "blue-start-orb", "blue-orb", "apple-start-orb", "apple-logo"]
    static let extensions = ["png", "svg", "pdf", "icns", "jpg", "jpeg", "tiff"]

    static var supportFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OpenTaskbar", isDirectory: true)
    }

    static func builtInURL(_ name: String) -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("icons/\(name).png")
    }

    // The uploaded image, whichever extension it arrived with.
    static var customURL: URL? {
        for ext in extensions {
            let url = supportFolder.appendingPathComponent("start-icon.\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // "drawn" means the mark drawn in code; a built-in name wins next; the upload is the fallback.
    static func currentURL(for name: String) -> URL? {
        if name == "drawn" { return nil }
        if !name.isEmpty, let url = builtInURL(name), FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return customURL
    }

    private static var cache: (path: String, image: NSImage)?

    static func currentImage(for name: String) -> NSImage? {
        guard let url = currentURL(for: name) else { return nil }
        if let cache, cache.path == url.path { return cache.image }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache = (url.path, image)
        return image
    }

    static func removeCustom() {
        for ext in extensions {
            let url = supportFolder.appendingPathComponent("start-icon.\(ext)")
            try? FileManager.default.removeItem(at: url)
        }
        cache = nil
    }

    // Replaces any earlier upload with the file at source.
    @discardableResult
    static func installCustom(from source: URL) -> Bool {
        let ext = source.pathExtension.lowercased()
        guard extensions.contains(ext) else { return false }
        removeCustom()
        try? FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        do {
            try FileManager.default.copyItem(at: source, to: supportFolder.appendingPathComponent("start-icon.\(ext)"))
            return true
        } catch {
            Log.settings.info("launcher image copy failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    static func installCustom(data: Data, extension ext: String) -> Bool {
        let lowered = ext.lowercased()
        guard extensions.contains(lowered) else { return false }
        removeCustom()
        try? FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        return FileManager.default.createFile(
            atPath: supportFolder.appendingPathComponent("start-icon.\(lowered)").path, contents: data)
    }
}
