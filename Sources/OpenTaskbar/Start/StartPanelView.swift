// StartPanelView.swift
// The Start panel's two columns: apps and search on the left, places and power on the right.
// Exists as the port of the Open-Shell arrangement bottombar-startpanel.lua drew in HTML.
// Defines: StartPanelView, StartStyle, StartRow
// Notes: docs/notes/app/Sources/OpenTaskbar/Start/StartPanelView.swift.md
import SwiftUI

// Colors and sizes from the Start panel settings, as panelStyle in bottombar-settings.lua derived them.
struct StartStyle {
    let background: Color
    let sidebar: Color
    let hover: Color
    let rule: Color
    let text: Color
    let dim: Color
    let font: CGFloat
    let icon: CGFloat
    let sidebarWidth: CGFloat

    init(_ settings: BarSettings) {
        let level = settings.panelBrightness / 100
        let alpha = settings.panelTransparencyOn ? 1 - (settings.panelTransparency / 100) : 1
        func shade(_ value: Double, _ opacity: Double) -> Color {
            Color(red: min(1, value), green: min(1, value), blue: min(1, value + (3.0 / 255)), opacity: min(1, opacity))
        }
        let light = level > 0.55
        background = shade(level, alpha)
        sidebar = shade(level + 0.06, alpha)
        hover = shade(level + 0.11, alpha + 0.06)
        rule = shade(level + 0.16, alpha + 0.1)
        text = light ? Color(red: 0.078, green: 0.078, blue: 0.086) : Color(red: 0.925, green: 0.925, blue: 0.937)
        dim = light ? Color(red: 0.353, green: 0.353, blue: 0.376) : Color(red: 0.561, green: 0.561, blue: 0.6)
        let fontScale = settings.panelFontScale / 100
        font = 12.5 * fontScale
        icon = 17 * (settings.panelIconScale / 100)
        sidebarWidth = 168 * fontScale
    }
}

struct StartPanelView: View {
    @Bindable var model: StartModel
    @FocusState private var searchFocused: Bool
    @FocusState private var renameFocused: Bool

    var body: some View {
        let style = StartStyle(model.settings)
        HStack(spacing: 0) {
            left(style)
            right(style).frame(width: style.sidebarWidth)
        }
        .font(.system(size: style.font))
        .foregroundStyle(style.text)
        .onChange(of: model.focusToken) { searchFocused = true }
        .onExitCommand { StartPanel.shared.close() }
    }

    private var displayName: String {
        model.settings.displayName.isEmpty ? NSUserName() : model.settings.displayName
    }

    private func left(_ style: StartStyle) -> some View {
        VStack(spacing: 0) {
            editable(.displayName, text: displayName, style: style)
                .font(.system(size: style.font * 1.2, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(EdgeInsets(top: style.font * 0.9, leading: style.font * 1.1, bottom: style.font * 0.6, trailing: style.font * 1.1))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.visibleApps) { app in
                        StartRow(style: style) {
                            HStack(spacing: style.font * 0.6) {
                                Image(nsImage: AppCatalog.icon(app.path)).resizable().frame(width: style.icon, height: style.icon)
                                Text(app.title).lineLimit(1).truncationMode(.tail)
                                Spacer(minLength: 0)
                            }
                            .padding(EdgeInsets(top: style.font * 0.25, leading: style.font * 0.65,
                                                bottom: style.font * 0.25, trailing: style.font * 0.65))
                        } action: {
                            StartPanel.shared.launch(app.path)
                        }
                        .contextMenu { appMenu(app) }
                    }
                }
                .padding(.horizontal, style.font * 0.4)
            }

            Rectangle().fill(style.rule).frame(height: 1).padding(.horizontal, style.font * 0.8).padding(.vertical, style.font * 0.4)

            StartRow(style: style) {
                HStack {
                    Text("All Programs").fontWeight(.semibold)
                    Spacer()
                    Text("\u{203A}").foregroundStyle(style.dim)
                }
                .padding(EdgeInsets(top: style.font * 0.5, leading: style.font, bottom: style.font * 0.5, trailing: style.font))
            } action: {
                model.showAll.toggle()
            }

            Text("Right click an application to pin it to the bar")
                .font(.system(size: style.font * 0.88)).foregroundStyle(style.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 0, leading: style.font, bottom: style.font * 0.4, trailing: style.font))

            HStack(spacing: style.font * 0.55) {
                TextField("Search programs and files", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { if let first = model.visibleApps.first { StartPanel.shared.launch(first.path) } }
                Image(systemName: "magnifyingglass").opacity(0.6)
            }
            .padding(EdgeInsets(top: style.font * 0.32, leading: style.font * 0.6, bottom: style.font * 0.32, trailing: style.font * 0.6))
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(style.rule, lineWidth: 1))
            .padding(EdgeInsets(top: style.font * 0.55, leading: style.font * 0.8, bottom: style.font * 0.7, trailing: style.font * 0.8))
        }
        .background(style.background)
    }

    @ViewBuilder
    private func appMenu(_ app: CatalogApp) -> some View {
        if model.settings.pinnedApps.contains(app.path) {
            Button("Unpin from taskbar") { PinnedStore.unpin(app.path) }
        } else {
            Button("Pin to taskbar") { PinnedStore.pin(app.path) }
        }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }
    }

    private func right(_ style: StartStyle) -> some View {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return VStack(spacing: 0) {
            Circle().fill(style.rule).frame(width: style.font * 3.9, height: style.font * 3.9)
                .overlay(Image(systemName: "person.fill").resizable().scaledToFit().padding(style.font * 0.95)
                    .foregroundStyle(Color(red: 0.83, green: 0.83, blue: 0.85)))
                .padding(EdgeInsets(top: style.font * 0.95, leading: 0, bottom: style.font * 0.55, trailing: 0))

            VStack(spacing: 0) {
                link(displayName, style) { StartPanel.shared.launch(home) }
                link("Documents", style) { StartPanel.shared.launch("\(home)/Documents") }
                link("Downloads", style) { StartPanel.shared.launch("\(home)/Downloads") }
                link("Music", style) { StartPanel.shared.launch("\(home)/Music") }
                rule(style)
                StartRow(style: style) {
                    editable(.thisMacLabel, text: model.settings.thisMacLabel, style: style)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: style.font * 0.4, leading: style.font, bottom: style.font * 0.4, trailing: style.font))
                } action: {
                    StartPanel.shared.launch("/")
                }
                rule(style)
                link("Settings", style) { StartPanel.shared.launch("/System/Applications/System Settings.app") }
                link("Activity Monitor", style) { StartPanel.shared.launch("/System/Applications/Utilities/Activity Monitor.app") }
            }
            .padding(.top, style.font * 0.15)

            Spacer(minLength: 0)

            if model.showPower {
                VStack(spacing: 0) {
                    link("Sleep", style) { StartPanel.shared.power(.sleep) }
                    link("Lock Screen", style) { StartPanel.shared.power(.lock) }
                    link("Log Out", style) { StartPanel.shared.power(.logout) }
                    link("Restart", style) { StartPanel.shared.power(.restart) }
                }
                .background(style.sidebar)
            }

            HStack(spacing: 0) {
                StartRow(style: style) {
                    Text("Shut down").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: style.font * 0.65, leading: style.font * 0.9, bottom: style.font * 0.65, trailing: style.font * 0.9))
                } action: {
                    StartPanel.shared.power(.shutdown)
                }
                Rectangle().fill(style.hover).frame(width: 1)
                StartRow(style: style) {
                    Text("\u{203A}").foregroundStyle(style.dim)
                        .padding(EdgeInsets(top: style.font * 0.65, leading: style.font * 0.85, bottom: style.font * 0.65, trailing: style.font * 0.85))
                } action: {
                    model.showPower.toggle()
                }
                .fixedSize()
            }
            // The divider has no height of its own, so the row is held to its text's height.
            .fixedSize(horizontal: false, vertical: true)
            .background(style.rule)
        }
        .background(style.sidebar)
    }

    private func link(_ title: String, _ style: StartStyle, action: @escaping () -> Void) -> some View {
        StartRow(style: style) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: style.font * 0.4, leading: style.font, bottom: style.font * 0.4, trailing: style.font))
        } action: {
            action()
        }
    }

    private func rule(_ style: StartStyle) -> some View {
        Rectangle().fill(style.rule).frame(height: 1).padding(.horizontal, style.font).padding(.vertical, style.font * 0.45)
    }

    // A label that becomes a text field from its right click menu, saving on Return or losing focus.
    @ViewBuilder
    private func editable(_ field: StartModel.Field, text: String, style: StartStyle) -> some View {
        if model.editing == field {
            TextField("", text: $model.draft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(field == .displayName ? .center : .leading)
                .focused($renameFocused)
                .onAppear { renameFocused = true }
                .onSubmit { finishRename(field) }
                .onChange(of: renameFocused) { if !renameFocused { finishRename(field) } }
                .onExitCommand { model.editing = nil }
        } else {
            Text(text).lineLimit(1)
                .contextMenu {
                    Button("Rename") {
                        model.draft = text
                        model.editing = field
                    }
                }
        }
    }

    private func finishRename(_ field: StartModel.Field) {
        guard model.editing == field else { return }
        StartPanel.shared.rename(field, to: model.draft)
        model.editing = nil
    }
}

// A full-width row that lights up under the pointer and runs its action on click.
struct StartRow<Content: View>: View {
    let style: StartStyle
    @ViewBuilder let content: () -> Content
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        content()
            .contentShape(Rectangle())
            .background(hover ? style.hover : Color.clear, in: RoundedRectangle(cornerRadius: 3))
            .onHover { hover = $0 }
            .onTapGesture { action() }
    }
}
