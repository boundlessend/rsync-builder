import SwiftUI
import AppKit

// действия, которые форма публикует в меню-бар через focused value
struct RsyncActions {
    let run: () -> Void
    let copy: () -> Void
    let save: () -> Void
    let clear: () -> Void
    let canRun: Bool
}

struct RsyncActionsKey: FocusedValueKey {
    typealias Value = RsyncActions
}

extension FocusedValues {
    var rsyncActions: RsyncActions? {
        get { self[RsyncActionsKey.self] }
        set { self[RsyncActionsKey.self] = newValue }
    }
}

// пункты меню «Команда» в меню-баре
struct RsyncCommands: View {
    @FocusedValue(\.rsyncActions) private var actions

    var body: some View {
        Button("Запустить") { actions?.run() }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(actions?.canRun != true)
        Button("Скопировать команду") { actions?.copy() }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(actions == nil)
        Divider()
        Button("Сохранить профиль") { actions?.save() }
            .disabled(actions == nil)
        Button("Очистить поля") { actions?.clear() }
            .disabled(actions == nil)
    }
}

// стандартная панель About с версией и лицензией
func showAboutPanel() {
    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "rsync builder",
        .applicationVersion: "1.0",
        .credits: NSAttributedString(
            string: "BSD 3-Clause · © 2026 Arseni Okhrimenko",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        ),
    ])
}
