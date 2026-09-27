// ScreenRecorder.swift
// Records the screen under the pointer to a movie on the Desktop through ScreenCaptureKit.
// Exists because the Lua build could only start screencapture and stop it with an interrupt signal.
// Defines: ScreenRecorder
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/ScreenRecorder.swift.md
import AppKit
import ScreenCaptureKit

@MainActor
final class ScreenRecorder: NSObject {
    static let shared = ScreenRecorder()

    private var stream: SCStream?
    private var output: SCRecordingOutput?

    var isRecording: Bool { stream != nil }

    func start() {
        guard stream == nil else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            Log.panels.info("screen recording permission not granted")
            return
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let displayID = screen.map(BarPanel.displayID(of:)) ?? CGMainDisplayID()

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first
                else { return }
                let configuration = SCStreamConfiguration()
                configuration.width = display.width * 2
                configuration.height = display.height * 2
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                configuration.showsCursor = true

                let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []),
                                      configuration: configuration, delegate: nil)
                let recording = SCRecordingOutputConfiguration()
                recording.outputURL = ScreenRecorder.destination()
                recording.outputFileType = .mov
                let output = SCRecordingOutput(configuration: recording, delegate: self)
                try stream.addRecordingOutput(output)
                try await stream.startCapture()
                self.stream = stream
                self.output = output
                Log.panels.info("recording to \(recording.outputURL.path, privacy: .public)")
            } catch {
                Log.panels.info("recording did not start: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func stop() {
        guard let stream else { return }
        self.stream = nil
        Task {
            try? await stream.stopCapture()
            self.output = nil
        }
    }

    private static func destination() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        return desktop.appendingPathComponent("Screen Recording \(formatter.string(from: Date())).mov")
    }
}

extension ScreenRecorder: SCRecordingOutputDelegate {
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            Log.panels.info("recording failed: \(message, privacy: .public)")
            ScreenRecorder.shared.stop()
        }
    }
}
