import AppKit
import SwiftTerm

// отдельное окно с терминалом: печатает команду и запускает, показывает вывод
final class TerminalWindow: ObservableObject, LocalProcessTerminalViewDelegate {
    private let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 760, height: 440))
    private var window: NSWindow?
    private var started = false

    init() {
        view.processDelegate = self
    }

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
        // логин-шелл пользователя (из $SHELL), а не жёстко zsh; -l читает профиль
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        view.startProcess(executable: shell, args: ["-l"], environment: nil, execName: nil, currentDirectory: nil)
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 440),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let lang = Lang(rawValue: UserDefaults.standard.string(forKey: "lang") ?? "en") ?? .en
        w.title = L10n.of(lang).terminalTitle
        w.contentView = view
        w.isReleasedWhenClosed = false
        w.center()
        window = w
    }

    // MARK: LocalProcessTerminalViewDelegate
    // шелл завершился (exit / умер) - сбрасываем флаг, следующий запуск поднимет новый
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        started = false
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
