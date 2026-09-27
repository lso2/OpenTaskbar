// LauncherReorder.swift
// Dragging a pinned launcher among the button slots to reorder it, or off the bar to unpin it.
// Exists as the port of the reorder half of bottombar-dragdrop.lua, extended to wrapped rows.
// Defines: LauncherReorder
// Notes: docs/notes/app/Sources/OpenTaskbar/Launchers/LauncherReorder.swift.md
import AppKit

@MainActor
final class LauncherReorder {
    static let shared = LauncherReorder()

    enum Outcome {
        case none
        case click(Int)
        case reordered([String])
        case unpinned(String)
    }

    // The pinned launchers' button rects in order, which may span more than one row.
    struct Geometry {
        let slots: [NSRect]
        let iconBox: CGFloat
        let paths: [String]

        func iconOrigin(_ slot: Int) -> NSPoint {
            let rect = slots[slot]
            return NSPoint(x: rect.midX - (iconBox / 2), y: rect.midY - (iconBox / 2))
        }
    }

    static let moveThreshold: CGFloat = 6
    static let lift: CGFloat = 4
    static let ease: CGFloat = 0.28

    private var pressedIndex: Int?
    private var pressPoint: NSPoint = .zero
    private var geometry: Geometry?
    private(set) var active = false
    private var fromIndex = 0
    private var targetIndex = 0
    private var grab = NSPoint.zero
    private var positions: [NSPoint] = []
    private var targets: [NSPoint] = []
    private var timer: Timer?

    // True from the press on a launcher until the button comes up, so auto-hide waits.
    var inGesture: Bool { pressedIndex != nil || active }

    // index counts launchers from the first pinned one; geometry is nil on a paged bar.
    func press(index: Int, at point: NSPoint, geometry: Geometry?) {
        pressedIndex = index
        pressPoint = point
        self.geometry = geometry
        active = false
    }

    // Returns true once the pointer has moved far enough to count as a drag.
    @discardableResult
    func drag(to point: NSPoint) -> Bool {
        guard let index = pressedIndex, let geometry, index < geometry.slots.count else { return false }
        if !active {
            guard hypot(point.x - pressPoint.x, point.y - pressPoint.y) > LauncherReorder.moveThreshold else { return false }
            active = true
            fromIndex = index
            targetIndex = index
            let origin = geometry.iconOrigin(index)
            grab = NSPoint(x: pressPoint.x - origin.x, y: pressPoint.y - origin.y)
            positions = geometry.slots.indices.map { geometry.iconOrigin($0) }
            targets = positions
            startEasing()
        }

        // The target is the slot whose center is nearest the pointer.
        targetIndex = geometry.slots.indices.min { lhs, rhs in
            let a = geometry.slots[lhs], b = geometry.slots[rhs]
            return hypot(a.midX - point.x, a.midY - point.y) < hypot(b.midX - point.x, b.midY - point.y)
        } ?? fromIndex

        let places = LauncherReorder.places(count: geometry.slots.count, from: fromIndex, to: targetIndex)
        for index in geometry.slots.indices { targets[index] = geometry.iconOrigin(places[index]) }

        // The launcher in hand follows the pointer; the others ease toward their slots.
        let held = NSPoint(x: point.x - grab.x, y: point.y - grab.y)
        targets[fromIndex] = held
        positions[fromIndex] = held
        return true
    }

    func release(onBar: Bool) -> Outcome {
        defer { finish() }
        guard let index = pressedIndex else { return .none }
        guard active, let geometry else { return .click(index) }
        if !onBar { return .unpinned(geometry.paths[fromIndex]) }

        let places = LauncherReorder.places(count: geometry.paths.count, from: fromIndex, to: targetIndex)
        var ordered = geometry.paths
        for (index, path) in geometry.paths.enumerated() { ordered[places[index]] = path }
        return .reordered(ordered)
    }

    func cancel() { finish() }

    // Where the pinned icon at index is drawn during a drag.
    func iconOrigin(_ index: Int) -> NSPoint? {
        guard active, positions.indices.contains(index) else { return nil }
        return positions[index]
    }

    func lift(_ index: Int) -> CGFloat {
        active && index == fromIndex ? LauncherReorder.lift : 0
    }

    // The row without the dragged launcher, with a hole opened at the target slot.
    static func places(count: Int, from: Int, to: Int) -> [Int] {
        var places = [Int](repeating: 0, count: count)
        var others = (0..<count).filter { $0 != from }.makeIterator()
        for position in 0..<count {
            if position == to {
                places[from] = position
            } else if let next = others.next() {
                places[next] = position
            }
        }
        return places
    }

    private func startEasing() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            MainActor.assumeIsolated { LauncherReorder.shared.stepEasing() }
        }
    }

    private func stepEasing() {
        guard active else { return }
        for index in positions.indices where index != fromIndex {
            let dx = targets[index].x - positions[index].x
            let dy = targets[index].y - positions[index].y
            if abs(dx) < 0.4 && abs(dy) < 0.4 {
                positions[index] = targets[index]
            } else {
                positions[index] = NSPoint(x: positions[index].x + (dx * LauncherReorder.ease),
                                           y: positions[index].y + (dy * LauncherReorder.ease))
            }
        }
        BarController.shared.redraw()
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        pressedIndex = nil
        geometry = nil
        active = false
        positions = []
        targets = []
    }
}
