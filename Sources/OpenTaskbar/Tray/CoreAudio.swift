// CoreAudio.swift
// Typed reads and writes of Core Audio device properties: default device, volume, mute, names.
// Exists so Volume and Microphone share one set of property calls for their two scopes.
// Defines: CoreAudio, AudioLevel, AudioWatch
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/CoreAudio.swift.md
import AudioToolbox
import CoreAudio
import Foundation

struct AudioLevel: Equatable, Sendable {
    let device: AudioObjectID
    let name: String
    let level: Double      // 0 to 100
    let muted: Bool
}

enum CoreAudio {
    static func scope(input: Bool) -> AudioObjectPropertyScope {
        input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private static func read<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: inout T) -> Bool {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return false }
        var size = UInt32(MemoryLayout<T>.size)
        return withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) } == noErr
    }

    private static func write<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: T) -> Bool {
        var address = address
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &address),
              AudioObjectIsPropertySettable(object, &address, &settable) == noErr, settable.boolValue else { return false }
        var value = value
        let size = UInt32(MemoryLayout<T>.size)
        return withUnsafePointer(to: &value) { AudioObjectSetPropertyData(object, &address, 0, nil, size, $0) } == noErr
    }

    static func defaultDevice(input: Bool) -> AudioObjectID? {
        var device = AudioObjectID(0)
        let selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        guard read(AudioObjectID(kAudioObjectSystemObject), address(selector), &device), device != 0 else { return nil }
        return device
    }

    static func setDefaultDevice(_ device: AudioObjectID, input: Bool) {
        let selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        _ = write(AudioObjectID(kAudioObjectSystemObject), address(selector), device)
    }

    static func name(_ device: AudioObjectID) -> String {
        var name: Unmanaged<CFString>?
        guard read(device, address(kAudioObjectPropertyName), &name), let value = name?.takeRetainedValue() else {
            return "Unknown device"
        }
        return value as String
    }

    // The virtual main volume covers devices with no main element; single channels are the fallback.
    static func volume(_ device: AudioObjectID, input: Bool) -> Double? {
        var value = Float32(0)
        if read(device, address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope(input: input)), &value) {
            return Double(value) * 100
        }
        if read(device, address(kAudioDevicePropertyVolumeScalar, scope(input: input)), &value) {
            return Double(value) * 100
        }
        var total = Double(0)
        var count = 0
        for channel in UInt32(1)...UInt32(2)
        where read(device, address(kAudioDevicePropertyVolumeScalar, scope(input: input), channel), &value) {
            total += Double(value)
            count += 1
        }
        return count > 0 ? (total / Double(count)) * 100 : nil
    }

    static func setVolume(_ device: AudioObjectID, input: Bool, _ percent: Double) {
        let value = Float32(min(100, max(0, percent)) / 100)
        if write(device, address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope(input: input)), value) {
            return
        }
        if write(device, address(kAudioDevicePropertyVolumeScalar, scope(input: input)), value) { return }
        for channel in UInt32(1)...UInt32(2) {
            _ = write(device, address(kAudioDevicePropertyVolumeScalar, scope(input: input), channel), value)
        }
    }

    // Measured on the development Mac: the main element of the device's own scope reports
    // mute correctly. Nil means the device publishes no mute switch.
    static func mute(_ device: AudioObjectID, input: Bool) -> Bool? {
        var value = UInt32(0)
        guard read(device, address(kAudioDevicePropertyMute, scope(input: input)), &value) else { return nil }
        return value != 0
    }

    @discardableResult
    static func setMute(_ device: AudioObjectID, input: Bool, _ muted: Bool) -> Bool {
        write(device, address(kAudioDevicePropertyMute, scope(input: input)), UInt32(muted ? 1 : 0))
    }

    static func level(input: Bool) -> AudioLevel? {
        guard let device = defaultDevice(input: input) else { return nil }
        let volume = self.volume(device, input: input) ?? 0
        let muted = (mute(device, input: input) ?? false) || volume <= 0
        return AudioLevel(device: device, name: name(device), level: volume, muted: muted)
    }

    // Every device carrying at least one stream in the requested direction.
    static func devices(input: Bool) -> [(id: AudioObjectID, name: String)] {
        var systemAddress = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &systemAddress, 0, nil, &size) == noErr
        else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &systemAddress, 0, nil, &size, &ids) == noErr
        else { return [] }

        return ids.compactMap { id in
            var streams = address(kAudioDevicePropertyStreams, scope(input: input))
            var streamSize = UInt32(0)
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            return (id, name(id))
        }
    }

    static func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       _ scope: AudioObjectPropertyScope, _ block: @escaping @Sendable () -> Void) {
        var watched = address(selector, scope)
        guard AudioObjectHasProperty(object, &watched) else { return }
        AudioObjectAddPropertyListenerBlock(object, &watched, DispatchQueue.main) { _, _ in block() }
    }
}

// Follows the default device of one direction and calls back when it, its volume or its
// mute changes. Each device is watched once, however often it becomes the default again.
@MainActor
final class AudioWatch {
    private let input: Bool
    private let changed: @MainActor () -> Void
    private var watched: Set<AudioObjectID> = []

    init(input: Bool, changed: @escaping @MainActor () -> Void) {
        self.input = input
        self.changed = changed
        let selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        CoreAudio.listen(AudioObjectID(kAudioObjectSystemObject), selector, kAudioObjectPropertyScopeGlobal) { [weak self] in
            MainActor.assumeIsolated {
                self?.watchDefault()
                self?.changed()
            }
        }
        watchDefault()
    }

    private func watchDefault() {
        guard let device = CoreAudio.defaultDevice(input: input), !watched.contains(device) else { return }
        watched.insert(device)
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyVolumeScalar,
                         kAudioDevicePropertyMute] {
            CoreAudio.listen(device, selector, CoreAudio.scope(input: input)) { [weak self] in
                MainActor.assumeIsolated { self?.changed() }
            }
        }
    }
}
