// AudioControl.swift
// Volume and microphone level and mute for the default output and input devices.
// Exists so the tray marks, the slider panel and the F13 key share one mute definition per direction.
// Defines: AudioControl
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/AudioControl.swift.md
import CoreAudio
import Foundation

@MainActor
final class AudioControl {
    static let output = AudioControl(input: false, key: "volume", label: "Volume")
    static let input = AudioControl(input: true, key: "microphone", label: "Microphone")

    let isInput: Bool
    let key: String
    let label: String
    private(set) var state: AudioLevel?
    private var watch: AudioWatch?
    private var observers: [@MainActor () -> Void] = []

    private init(input: Bool, key: String, label: String) {
        self.isInput = input
        self.key = key
        self.label = label
    }

    func start() {
        guard watch == nil else { return }
        refresh()
        watch = AudioWatch(input: isInput) { AudioControl.control(input: self.isInput).refresh() }
    }

    static func control(input: Bool) -> AudioControl { input ? AudioControl.input : AudioControl.output }

    func observe(_ observer: @escaping @MainActor () -> Void) {
        observers.append(observer)
    }

    func refresh() {
        let fresh = CoreAudio.level(input: isInput)
        guard fresh != state else { return }
        state = fresh
        for observer in observers { observer() }
    }

    // Asking for a level is asking to hear it, so this also comes off mute.
    func setLevel(_ percent: Double) {
        guard let device = CoreAudio.defaultDevice(input: isInput) else { return }
        CoreAudio.setMute(device, input: isInput, false)
        CoreAudio.setVolume(device, input: isInput, percent)
        refresh()
    }

    func toggleMute() {
        refresh()
        setMuted(!(state?.muted ?? false))
    }

    // Muting keeps the level where the device offers a mute switch and drops it to zero where it
    // does not. Unmuting from a level of zero puts back the level remembered at the last mute.
    func setMuted(_ wanted: Bool) {
        guard let device = CoreAudio.defaultDevice(input: isInput) else { return }
        let level = CoreAudio.volume(device, input: isInput) ?? 0
        if wanted {
            if level > 0 { SettingsStore.shared.update { $0.restoreLevels[key] = level } }
            if !CoreAudio.setMute(device, input: isInput, true) {
                CoreAudio.setVolume(device, input: isInput, 0)
            }
        } else {
            CoreAudio.setMute(device, input: isInput, false)
            if level <= 0 {
                CoreAudio.setVolume(device, input: isInput, SettingsStore.shared.current.restoreLevels[key] ?? 50)
            }
        }
        refresh()
    }

    var summary: String {
        guard let state else { return isInput ? "No input device" : "No output device" }
        if state.muted { return "\(label)   muted" }
        return "\(label)   \(Int(state.level.rounded(.down)))%"
    }

    func setDefault(_ device: AudioObjectID) {
        CoreAudio.setDefaultDevice(device, input: isInput)
        refresh()
    }
}
