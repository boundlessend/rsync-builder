import SwiftUI
import AppKit

// template-иконка для меню-бара (монохром, тонируется системой)
func makeMenuBarIcon() -> NSImage {
    let path = Bundle.main.resourcePath.map { $0 + "/menubar-icon.png" }
    let img = path.flatMap { NSImage(contentsOfFile: $0) }
        ?? NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: "rsync builder")!
    img.isTemplate = true
    img.size = NSSize(width: 18, height: 18)
    return img
}

// стандартная панель About с версией и лицензией
func showAboutPanel() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "rsync builder",
        .applicationVersion: appVersion,
        .credits: NSAttributedString(
            string: "BSD 3-Clause · © 2026 Arseni Okhrimenko",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        ),
    ])
}
