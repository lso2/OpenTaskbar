// BarSnapshotTests.swift
// Renders the bar at 2x in the three Windows 10 configurations and writes each render as a PNG.
// Exists so the drawn bar can be compared pixel for pixel with the Windows screenshots it copies.
// Defines: BarSnapshotTests
// Notes: docs/notes/app/Tests/OpenTaskbarTests/BarSnapshotTests.swift.md
import AppKit
import Testing
@testable import OpenTaskbar

@MainActor
struct BarSnapshotTests {
    // OPENTASKBAR_SNAPSHOTS names the folder; the system temporary folder is the fallback.
    static var folder: URL {
        let path = ProcessInfo.processInfo.environment["OPENTASKBAR_SNAPSHOTS"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("opentaskbar-snapshots").path
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func render(_ name: String, _ inputs: BarInputs) throws {
        let layout = BarLayout.compute(inputs)
        let size = NSSize(width: inputs.width, height: inputs.metrics.height)
        let data = try #require(BarRenderer.png(layout, palette: inputs.palette, size: size, scale: 2))
        let url = BarSnapshotTests.folder.appendingPathComponent("\(name).png")
        try data.write(to: url)
        print("snapshot: \(url.path)")
    }

    @Test func smallOneRow() throws {
        try render("small-one-row", TestInputs.inputs(TestInputs.settings(), launchers: 30))
    }

    @Test func smallTwoRows() throws {
        try render("small-two-rows", TestInputs.inputs(TestInputs.settings(rows: 2), launchers: 31))
    }

    @Test func largeOneRowOverflow() throws {
        try render("large-one-row-overflow", TestInputs.inputs(TestInputs.settings(large: true), launchers: 40))
    }

    @Test func smallFewButtons() throws {
        try render("small-few-buttons", TestInputs.inputs(TestInputs.settings(), launchers: 5))
    }
}
