import AppKit
import SwiftTerm

// отдельное окно с терминалом: печатает команду и запускает, показывает вывод
final class TerminalWindow: ObservableObject {
    private let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 760, height: 440))
    private var window: NSWindow?
    private var started = false

    func run(command: String) {
        ensureWindow()
        startShellIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        view.send(txt: command + "\n")
    }

    private func startShellIfNeeded() {
        guard !started else { return }
        started = true
        view.startProcess(executable: "/bin/zsh", args: ["-l"], environment: nil, execName: nil, currentDirectory: nil)
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 440),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Терминал - rsync builder"
        w.contentView = view
        w.isReleasedWhenClosed = false
        w.center()
        window = w
    }
}
