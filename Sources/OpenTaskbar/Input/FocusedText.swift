// FocusedText.swift
// Answers whether the focused element accepts text, and reads the focused window's title.
// Exists so Home, End and paste keys can pick a text editing command or a page command.
// Defines: FocusedText
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/FocusedText.swift.md
import ApplicationServices

@AXActor
enum FocusedText {
    static let editableRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    static func acceptsText() -> Bool {
        guard let focused = AX.element(AX.systemWide, kAXFocusedUIElementAttribute) else { return false }
        let role = AX.string(focused, kAXRoleAttribute)
        if let role, editableRoles.contains(role) { return true }
        // Web content and Electron report an editable ancestor in place of a text role.
        if AX.value(focused, "AXEditableAncestor") != nil { return true }
        return role != kAXStaticTextRole && AX.isSettable(focused, kAXValueAttribute)
    }

    static func focusedWindowTitle() -> String? {
        guard let app = AX.element(AX.systemWide, kAXFocusedApplicationAttribute),
              let window = AX.element(app, kAXFocusedWindowAttribute) else { return nil }
        return AX.string(window, kAXTitleAttribute)
    }
}
