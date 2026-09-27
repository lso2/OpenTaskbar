// AXActor.swift
// The one actor every cross-process accessibility call runs on, with typed attribute helpers.
// Exists so a wedged application can stall this serial queue for 0.35 seconds at most and never the main thread.
// Defines: AXActor, AXRef, AX
// Notes: docs/notes/app/Sources/OpenTaskbar/Windows/AXActor.swift.md
import ApplicationServices
import Foundation
import PrivateAPI

@globalActor
actor AXActor {
    static let shared = AXActor()

    private let queue = DispatchSerialQueue(label: "com.plexpixel.OpenTaskbar.accessibility")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }
}

// AXUIElement is a CF type the SDK leaves non-Sendable. The accessibility API is safe to call
// from any thread, and every call through this wrapper happens on AXActor.
struct AXRef: @unchecked Sendable, Hashable {
    let element: AXUIElement

    static func == (lhs: AXRef, rhs: AXRef) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

@AXActor
enum AX {
    static let timeout: Float = 0.35

    static func application(_ pid: pid_t) -> AXRef {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, timeout)
        return AXRef(element: element)
    }

    static var systemWide: AXRef {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, timeout)
        return AXRef(element: element)
    }

    static func value(_ ref: AXRef, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(ref.element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ ref: AXRef, _ attribute: String) -> String? {
        value(ref, attribute) as? String
    }

    static func bool(_ ref: AXRef, _ attribute: String) -> Bool? {
        (value(ref, attribute) as? NSNumber)?.boolValue
    }

    static func element(_ ref: AXRef, _ attribute: String) -> AXRef? {
        guard let object = value(ref, attribute), CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }
        // The type id check above is what makes this downcast safe.
        return AXRef(element: unsafeDowncast(object, to: AXUIElement.self))
    }

    static func elements(_ ref: AXRef, _ attribute: String) -> [AXRef] {
        guard let array = value(ref, attribute) as? [AnyObject] else { return [] }
        return array.compactMap { object in
            guard CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }
            return AXRef(element: unsafeDowncast(object, to: AXUIElement.self))
        }
    }

    static func point(_ ref: AXRef, _ attribute: String = kAXPositionAttribute) -> CGPoint? {
        guard let object = value(ref, attribute), CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(unsafeDowncast(object, to: AXValue.self), .cgPoint, &point) ? point : nil
    }

    static func size(_ ref: AXRef, _ attribute: String = kAXSizeAttribute) -> CGSize? {
        guard let object = value(ref, attribute), CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(unsafeDowncast(object, to: AXValue.self), .cgSize, &size) ? size : nil
    }

    // Top-left origin screen coordinates, as the accessibility API reports them.
    static func frame(_ ref: AXRef) -> CGRect? {
        guard let origin = point(ref), let size = size(ref) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    @discardableResult
    static func set(_ ref: AXRef, _ attribute: String, _ value: AnyObject) -> Bool {
        AXUIElementSetAttributeValue(ref.element, attribute as CFString, value) == .success
    }

    @discardableResult
    static func setPoint(_ ref: AXRef, _ attribute: String, _ point: CGPoint) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return set(ref, attribute, value)
    }

    @discardableResult
    static func setSize(_ ref: AXRef, _ attribute: String, _ size: CGSize) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return set(ref, attribute, value)
    }

    static func isSettable(_ ref: AXRef, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(ref.element, attribute as CFString, &settable) == .success && settable.boolValue
    }

    @discardableResult
    static func perform(_ ref: AXRef, _ action: String) -> Bool {
        AXUIElementPerformAction(ref.element, action as CFString) == .success
    }

    static func performResult(_ ref: AXRef, _ action: String) -> AXError {
        AXUIElementPerformAction(ref.element, action as CFString)
    }

    static func actions(_ ref: AXRef) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(ref.element, &names) == .success, let names = names as? [String] else { return [] }
        return names
    }

    static func windowID(_ ref: AXRef) -> CGWindowID? {
        var identifier = CGWindowID(0)
        return _AXUIElementGetWindow(ref.element, &identifier) == .success ? identifier : nil
    }
}
