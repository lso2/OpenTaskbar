// BarLayoutTests.swift
// Checks the laid-out bar against the Windows 10 measurements in TaskbarMetrics.
// Exists so a change that moves a button, the tray or the right end off the measured spacing fails a test.
// Defines: BarLayoutTests
// Notes: docs/notes/app/Tests/OpenTaskbarTests/BarLayoutTests.swift.md
import AppKit
import Testing
@testable import OpenTaskbar

@MainActor
struct BarLayoutTests {
    private func launcherRects(_ result: BarLayoutResult) -> [NSRect] {
        result.zones.compactMap { zone in
            if case .launcher = zone.kind { return zone.rect }
            return nil
        }
    }

    private func rect(_ result: BarLayoutResult, _ kind: BarZoneKind) -> NSRect? {
        result.zones.first { $0.kind == kind }?.rect
    }

    @Test func uncrowdedButtonsAre38PointsApart() {
        let result = BarLayout.compute(TestInputs.inputs(TestInputs.settings(), launchers: 6))
        let rects = launcherRects(result)
        #expect(rects.count == 6)
        for (left, right) in zip(rects, rects.dropFirst()) {
            #expect(abs((right.minX - left.minX) - 38) < 0.51)
        }
    }

    @Test func startAndMissionControlAre36PointsWide() {
        let result = BarLayout.compute(TestInputs.inputs(TestInputs.settings(), launchers: 3))
        #expect(rect(result, .start)?.width == 36)
        #expect(rect(result, .taskView)?.minX == 36)
        #expect(rect(result, .taskView)?.width == 36)
    }

    @Test func crowdedButtonsShrinkTogetherBeforePaging() {
        let result = BarLayout.compute(TestInputs.inputs(TestInputs.settings(), launchers: 32))
        let rects = launcherRects(result)
        #expect(rects.count == 32 || result.pageCount > 1)
        if let first = rects.first, let last = rects.last, rects.count > 1 {
            let pitch = (last.minX - first.minX) / CGFloat(rects.count - 1)
            #expect(pitch < 38 && pitch >= 30)
        }
    }

    @Test func largeButtonsPageAtTheirMinimum() {
        let result = BarLayout.compute(TestInputs.inputs(TestInputs.settings(large: true), launchers: 60))
        #expect(result.pageCount > 1)
        #expect(rect(result, .pageUp) != nil)
        let rects = launcherRects(result)
        if rects.count > 1 { #expect(abs((rects[1].minX - rects[0].minX) - 38) < 0.51) }
    }

    @Test func trayCellsAre32PointsApart() {
        let result = BarLayout.compute(TestInputs.inputs(TestInputs.settings(), launchers: 3))
        guard let wifi = rect(result, .wifi), let volume = rect(result, .volume), let battery = rect(result, .battery) else {
            Issue.record("tray cells missing")
            return
        }
        #expect(wifi.minX - volume.minX == 32)
        #expect(volume.minX - battery.minX == 32)
        #expect(wifi.width == 32)
    }

    @Test func rightEndSitsAtTheMeasuredOffsets() {
        let result = BarLayout.compute(TestInputs.inputs(TestInputs.settings(), launchers: 3))
        #expect(rect(result, .showDesktop)?.minX == 1280 - TaskbarMetrics.showDesktopWidth)
        #expect(rect(result, .notifications)?.minX == 1280 - TaskbarMetrics.clockRightInset)
        #expect(result.clockRect.maxX == 1280 - TaskbarMetrics.clockRightInset)
    }

    @Test func twoRowsAre62PointsTallAndWrapRowMajor() {
        let settings = TestInputs.settings(rows: 2)
        #expect(TaskbarMetrics(settings).height == 62)
        let result = BarLayout.compute(TestInputs.inputs(settings, launchers: 40))
        let rows = Set(launcherRects(result).map(\.minY))
        #expect(rows == [0, 32])
    }
}
