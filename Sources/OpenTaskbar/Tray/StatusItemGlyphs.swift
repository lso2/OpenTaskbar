// StatusItemGlyphs.swift
// Captures each mirrored status item's own glyph from the menu bar and keeps it in memory and on disk.
// Exists because a status item's image is readable only as the pixels of its window, and only while the menu bar shows.
// Defines: StatusGlyph, StatusItemGlyphs
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/StatusItemGlyphs.swift.md
import AppKit
import ScreenCaptureKit

// A trimmed capture. One-color glyphs are redrawn in the bar's ink; colored ones keep their colors.
struct StatusGlyph {
    let image: NSImage
    let monochrome: Bool
}

@MainActor
final class StatusItemGlyphs {
    static let shared = StatusItemGlyphs()

    private var glyphs: [String: StatusGlyph] = [:]
    private var capturing = false
    private var pending: [(app: String, x: CGFloat)] = []
    private var onCaptured: (@MainActor () -> Void)?
    private var watch: Timer?

    private var folder: URL {
        StartIconStore.supportFolder.appendingPathComponent("status-glyphs", isDirectory: true)
    }

    private func file(for app: String) -> URL {
        folder.appendingPathComponent(app.replacingOccurrences(of: "/", with: "-") + ".png")
    }

    func glyph(for app: String) -> StatusGlyph? {
        if let cached = glyphs[app] { return cached }
        guard let image = NSImage(contentsOf: file(for: app)) else { return nil }
        let glyph = StatusItemGlyphs.prepare(image)
        glyphs[app] = glyph
        return glyph
    }

    // Items without a glyph wait here until the menu bar shows. With the menu bar hidden each
    // item window sits above the screen and its capture fails, so a one second check of the
    // status windows' positions starts the capture the moment the menu bar slides in.
    func capture(_ wanted: [(app: String, x: CGFloat)], done: @escaping @MainActor () -> Void) {
        pending = wanted.filter { glyph(for: $0.app) == nil }
        onCaptured = done
        guard !pending.isEmpty, CGPreflightScreenCaptureAccess() else {
            stopWatching()
            return
        }
        if StatusItemGlyphs.menuBarShowing() { run() } else { startWatching() }
    }

    private func startWatching() {
        guard watch == nil else { return }
        watch = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                if StatusItemGlyphs.menuBarShowing() { StatusItemGlyphs.shared.run() }
            }
        }
    }

    private func stopWatching() {
        watch?.invalidate()
        watch = nil
    }

    static func menuBarShowing() -> Bool {
        let level = Int(CGWindowLevelForKey(.statusWindow))
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return list.contains { window in
            guard (window[kCGWindowLayer as String] as? Int) == level,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            return (bounds["Y"] ?? -1) >= 0 && (bounds["Height"] ?? 0) > 0
        }
    }

    // On macOS 26 every status item window belongs to Control Center, so a window is matched to
    // its app by the x position the app's accessibility element reports.
    private func run() {
        guard !capturing, !pending.isEmpty else { return }
        capturing = true
        let missing = pending
        Task {
            defer { StatusItemGlyphs.shared.capturing = false }
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            else { return }
            let level = Int(CGWindowLevelForKey(.statusWindow))
            var found: Set<String> = []
            for window in content.windows where window.windowLayer == level && window.frame.minY >= 0 {
                guard let item = missing.first(where: { abs($0.x - window.frame.minX) < 2 }) else { continue }
                let configuration = SCStreamConfiguration()
                configuration.width = Int(window.frame.width * 2)
                configuration.height = Int(window.frame.height * 2)
                configuration.showsCursor = false
                guard let image = try? await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration) else { continue }
                StatusItemGlyphs.shared.store(NSImage(cgImage: image, size: window.frame.size), for: item.app)
                found.insert(item.app)
            }
            let glyphs = StatusItemGlyphs.shared
            glyphs.pending.removeAll { found.contains($0.app) }
            if glyphs.pending.isEmpty { glyphs.stopWatching() }
            if !found.isEmpty { glyphs.onCaptured?() }
        }
    }

    private func store(_ image: NSImage, for app: String) {
        let glyph = StatusItemGlyphs.prepare(image)
        glyphs[app] = glyph
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let tiff = glyph.image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: file(for: app))
        Log.tray.debug("captured the status item glyph of \(app, privacy: .public)")
    }

    // Cuts the capture down to its visible pixels, since the item window pads the glyph on every
    // side, and notes whether every visible pixel is gray.
    static func prepare(_ image: NSImage) -> StatusGlyph {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return StatusGlyph(image: image, monochrome: true)
        }
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return StatusGlyph(image: image, monochrome: true) }

        var minX = width, minY = height, maxX = -1, maxY = -1
        var colored = false
        for y in 0..<height {
            for x in 0..<width {
                let offset = ((y * width) + x) * 4
                guard pixels[offset + 3] > 24 else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
                if max(red, green, blue) - min(red, green, blue) > 40 { colored = true }
            }
        }
        guard maxX >= minX, maxY >= minY else { return StatusGlyph(image: image, monochrome: true) }
        // Bitmap rows run top to bottom, the same direction cropping counts in.
        let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cut = cg.cropping(to: crop) else { return StatusGlyph(image: image, monochrome: !colored) }
        let scale = image.size.width > 0 ? CGFloat(width) / image.size.width : 2
        return StatusGlyph(image: NSImage(cgImage: cut, size: NSSize(width: crop.width / scale, height: crop.height / scale)),
                           monochrome: !colored)
    }
}
