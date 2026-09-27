// WindowPreview.swift
// Live thumbnails of an app's windows above its launcher, one ScreenCaptureKit stream per window.
// Exists because the Lua build could only show a snapshot taken at the moment of hovering.
// Defines: WindowPreview, PreviewView, PreviewStreamOutput
// Notes: docs/notes/app/Sources/OpenTaskbar/Windows/WindowPreview.swift.md
import AppKit
import ScreenCaptureKit

@MainActor
final class WindowPreview {
    static let shared = WindowPreview()

    static let hoverDelay: TimeInterval = 0.35
    static let labelHeight: CGFloat = 22
    static let maxTiles = 4
    static let gap: CGFloat = 8

    private let panel = PopupPanel(size: NSSize(width: 100, height: 100))
    private let view = PreviewView(frame: .zero)
    private var pendingPath: String?
    private var shownPath: String?
    private var timer: Timer?
    private var streams: [SCStream] = []
    private var outputs: [PreviewStreamOutput] = []
    private var askedPermission = false

    var isShown: Bool { panel.isOpen }

    private init() {
        panel.contentView = view
        panel.exclusive = false
        panel.onDismiss = { WindowPreview.shared.stopStreams() }
    }

    func hover(_ index: Int, anchor: NSRect, bar: BarView) {
        let entries = BarController.shared.currentLaunchers
        guard entries.indices.contains(index) else { return }
        let entry = entries[index]
        let path = entry.launcher.path
        guard path != shownPath, path != pendingPath else { return }
        timer?.invalidate()
        pendingPath = path
        timer = Timer.scheduledTimer(withTimeInterval: WindowPreview.hoverDelay, repeats: false) { _ in
            MainActor.assumeIsolated {
                guard WindowPreview.shared.pendingPath == path else { return }
                WindowPreview.shared.show(entry, anchor: anchor, bar: bar)
            }
        }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        pendingPath = nil
        shownPath = nil
        panel.dismiss()
    }

    // Leaving the bar toward the preview keeps it; leaving to anywhere else closes it.
    func leaveBar() {
        timer?.invalidate()
        pendingPath = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MainActor.assumeIsolated {
                let preview = WindowPreview.shared
                if !preview.panel.frame.contains(NSEvent.mouseLocation) { preview.hide() }
            }
        }
    }

    private func show(_ entry: LauncherEntry, anchor: NSRect, bar: BarView) {
        guard let app = PinnedStore.runningApp(for: entry.launcher.path) else { return }
        let windows = Array(WindowList.shared.windows(for: app.processIdentifier).prefix(WindowPreview.maxTiles))
        guard !windows.isEmpty else { return }

        stopStreams()
        shownPath = entry.launcher.path
        let allWindows = WindowList.shared.count(for: app.processIdentifier)
        let heading = allWindows > 1 ? "\(entry.launcher.title)   \(allWindows) windows" : entry.launcher.title

        let screen = bar.window?.screen?.frame ?? NSScreen.main?.frame ?? .zero
        let barTop = bar.window?.frame.maxY ?? 0
        var tileWidth = CGFloat(SettingsStore.shared.current.previewWidth)
        let first = windows[0].frame ?? CGRect(x: 0, y: 0, width: 16, height: 10)
        let ratio = first.width > 0 ? first.height / first.width : 0.62
        var tileHeight = (tileWidth * ratio).rounded(.down)
        let count = CGFloat(windows.count)
        var total = NSSize(width: (count * tileWidth) + ((count + 1) * WindowPreview.gap),
                           height: WindowPreview.labelHeight + tileHeight + 14)

        // Never wider or taller than the screen leaves room for.
        if total.width > screen.width - 16 {
            let shrink = (screen.width - 16) / total.width
            tileWidth = (tileWidth * shrink).rounded(.down)
            tileHeight = (tileHeight * shrink).rounded(.down)
            total = NSSize(width: (count * tileWidth) + ((count + 1) * WindowPreview.gap),
                           height: WindowPreview.labelHeight + tileHeight + 14)
        }
        let room = screen.maxY - barTop - 12
        if total.height > room {
            tileHeight = (tileHeight * (room / total.height)).rounded(.down)
            total.height = WindowPreview.labelHeight + tileHeight + 14
        }

        view.frame = NSRect(origin: .zero, size: total)
        view.configure(heading: heading, windows: windows, tile: NSSize(width: tileWidth, height: tileHeight))
        panel.present(size: total, above: anchor, bar: bar, gap: 6)
        startStreams(windows, tile: NSSize(width: tileWidth, height: tileHeight))
    }

    private func startStreams(_ windows: [WindowInfo], tile: NSSize) {
        guard CGPreflightScreenCaptureAccess() else {
            if !askedPermission {
                askedPermission = true
                CGRequestScreenCaptureAccess()
            }
            return
        }
        let wanted = windows.compactMap(\.windowID)
        let layers = view.tileLayers
        Task {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
                  WindowPreview.shared.panel.isOpen else { return }
            for (index, id) in wanted.enumerated() where index < layers.count {
                guard let window = content.windows.first(where: { $0.windowID == id }) else { continue }
                let configuration = SCStreamConfiguration()
                configuration.width = Int(tile.width * 2)
                configuration.height = Int(tile.height * 2)
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 10)
                configuration.showsCursor = false
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window),
                                      configuration: configuration, delegate: nil)
                let output = PreviewStreamOutput(layer: layers[index])
                do {
                    try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: PreviewStreamOutput.queue)
                    try await stream.startCapture()
                    WindowPreview.shared.streams.append(stream)
                    WindowPreview.shared.outputs.append(output)
                } catch {
                    Log.windows.info("preview stream did not start: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    fileprivate func stopStreams() {
        let running = streams
        streams = []
        outputs = []
        Task {
            for stream in running { try? await stream.stopCapture() }
        }
    }

    fileprivate func clicked(_ window: WindowInfo) {
        hide()
        WindowActions.raise(window)
    }
}

// Receives frames on its own queue and hands each frame's IOSurface to the tile layer on main.
final class PreviewStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    static let queue = DispatchQueue(label: "com.plexpixel.OpenTaskbar.preview")
    // Touched only on the main queue.
    private let layer: CALayer

    init(layer: CALayer) {
        self.layer = layer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else { return }
        let frame = SurfaceBox(surface: surface)
        DispatchQueue.main.async { [layer] in
            layer.contents = frame.surface
        }
    }

    private struct SurfaceBox: @unchecked Sendable { let surface: IOSurface }
}

@MainActor
final class PreviewView: NSView {
    private(set) var tileLayers: [CALayer] = []
    private var windows: [WindowInfo] = []
    private var tileRects: [NSRect] = []
    private let heading = NSTextField(labelWithString: "")
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.97).cgColor
        heading.font = NSFont.menuBarFont(ofSize: 12)
        heading.textColor = NSColor(white: 1, alpha: 0.92)
        heading.lineBreakMode = .byTruncatingTail
        addSubview(heading)
    }

    required init?(coder: NSCoder) { nil }

    func configure(heading text: String, windows: [WindowInfo], tile: NSSize) {
        self.windows = windows
        heading.stringValue = text
        heading.frame = NSRect(x: 10, y: 4, width: bounds.width - 20, height: WindowPreview.labelHeight - 4)
        for old in tileLayers { old.removeFromSuperlayer() }
        tileRects = windows.indices.map { index in
            NSRect(x: WindowPreview.gap + (CGFloat(index) * (tile.width + WindowPreview.gap)), y: WindowPreview.labelHeight,
                   width: tile.width, height: tile.height)
        }
        tileLayers = tileRects.enumerated().map { index, rect in
            let tileLayer = CATextLayer()
            tileLayer.frame = NSRect(x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height)
            tileLayer.contentsGravity = .resizeAspect
            tileLayer.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
            // Without screen recording the tile carries the window's title in place of its picture.
            if !CGPreflightScreenCaptureAccess() {
                tileLayer.string = windows[index].title.isEmpty ? "Window" : windows[index].title
                tileLayer.fontSize = 12
                tileLayer.alignmentMode = .center
                tileLayer.foregroundColor = NSColor(white: 1, alpha: 0.8).cgColor
                tileLayer.contentsScale = 2
            }
            layer?.addSublayer(tileLayer)
            return tileLayer
        }
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = tileRects.firstIndex(where: { $0.contains(point) }) else { return }
        WindowPreview.shared.clicked(windows[index])
    }

    override func mouseExited(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let overBar = BarController.shared.panels.contains { $0.frame.contains(mouse) }
        if !overBar { WindowPreview.shared.hide() }
    }
}
