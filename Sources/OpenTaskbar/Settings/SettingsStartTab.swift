// SettingsStartTab.swift
// The Start tab: panel names, panel look and size, preview width, the Start key and the launcher image.
// Exists as the port of the Start pane of bottombar-settings-page.lua.
// Defines: SettingsStartTab
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsStartTab.swift.md
import SwiftUI
import UniformTypeIdentifiers

struct SettingsStartTab: View {
    @Bindable var model: SettingsModel

    // What each Start key choice means once the keyboard's own remapping has had its way. Option
    // and Command were measured on the development Mac, where Karabiner swaps them.
    static let keys: [(id: String, label: String, mode: String, flag: String, code: Int)] = [
        ("opt", "Option key", "key", "cmd", 55), ("cmd", "Command key", "key", "alt", 58),
        ("ctrl", "Control key", "key", "ctrl", 59), ("globe", "Globe key", "key", "fn", 63),
        ("rcmd", "Right Command", "key", "alt", 61), ("ropt", "Right Option", "key", "cmd", 54),
        ("learn", "Learn from my next tap", "learn", "", 0), ("off", "Nothing", "off", "", 0),
    ]

    private var startKey: Binding<String> {
        Binding(get: {
            let settings = model.value
            if settings.startTapMode != "key" { return settings.startTapMode }
            return SettingsStartTab.keys.first { $0.flag == settings.startTapFlag && $0.code == settings.startTapCode }?.id ?? "learn"
        }, set: { id in
            guard let choice = SettingsStartTab.keys.first(where: { $0.id == id }) else { return }
            SettingsStore.shared.update { settings in
                settings.startTapMode = choice.mode
                if choice.mode == "key" {
                    settings.startTapFlag = choice.flag
                    settings.startTapCode = choice.code
                }
            }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection(title: "Names on the panel") {
                TextField("Display name", text: model.binding(\.displayName), prompt: Text(NSUserName()))
                TextField("Computer label", text: model.binding(\.thisMacLabel))
                Text("Both appear on the Start panel only. Right clicking either on the panel renames it there too.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsSection(title: "Panel") {
                SliderRow(title: "Font size", value: model.binding(\.panelFontScale), range: 70...250)
                SliderRow(title: "Icon size", value: model.binding(\.panelIconScale), range: 70...250)
                SliderRow(title: "Background", value: model.binding(\.panelBrightness), range: 0...100)
                Toggle("Use transparency", isOn: model.binding(\.panelTransparencyOn))
                SliderRow(title: "Transparency", value: model.binding(\.panelTransparency), range: 0...100)
                Toggle("Blur behind the panel", isOn: model.binding(\.panelBlur))
                SliderRow(title: "Maximum width", value: model.binding(\.panelMaxWidth), range: 360...1400, step: 20, unit: " pt")
                SliderRow(title: "Maximum height", value: model.binding(\.panelMaxHeight), range: 320...1200, step: 20, unit: " pt")
                Button("Reset these sliders") {
                    SettingsStore.shared.update { settings in
                        let defaults = BarSettings()
                        settings.panelFontScale = defaults.panelFontScale
                        settings.panelIconScale = defaults.panelIconScale
                        settings.panelBrightness = defaults.panelBrightness
                        settings.panelTransparency = defaults.panelTransparency
                        settings.panelMaxWidth = defaults.panelMaxWidth
                        settings.panelMaxHeight = defaults.panelMaxHeight
                        settings.startIconScale = defaults.startIconScale
                    }
                }
            }
            SettingsSection(title: "Opening and launcher") {
                SliderRow(title: "Hover preview width", value: model.binding(\.previewWidth), range: 260...640, step: 20, unit: " pt")
                Picker("Opened by tapping", selection: startKey) {
                    ForEach(SettingsStartTab.keys, id: \.id) { Text($0.label).tag($0.id) }
                }
                SliderRow(title: "Start icon size", value: model.binding(\.startIconScale), range: 40...200)
                Text("Start icon").padding(.top, 4)
                iconChoices
                HStack {
                    Button("Choose an image") { chooseImage() }
                    Button("Use the drawn mark") { SettingsStore.shared.update { $0.startIconName = "drawn" } }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconChoices: some View {
        HStack(spacing: 8) {
            ForEach(StartIconStore.builtIn, id: \.self) { name in
                let chosen = model.value.startIconName == name
                Button {
                    SettingsStore.shared.update { $0.startIconName = name }
                } label: {
                    Group {
                        if let url = StartIconStore.builtInURL(name), let image = NSImage(contentsOf: url) {
                            Image(nsImage: image).resizable().scaledToFit()
                        } else {
                            Text(name).font(.caption2)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .padding(4)
                    .background(chosen ? Color.accentColor.opacity(0.35) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = StartIconStore.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url, StartIconStore.installCustom(from: url) else { return }
        SettingsStore.shared.update { $0.startIconName = "" }
        BarController.shared.redraw()
    }
}
