import AppKit
import Foundation

// запуск rsync через Process без терминала: вывод стримится в нативное окно.
// пароль (если задан) подаётся ssh через SSH_ASKPASS и на диск не пишется - только в окружении дочернего процесса.
// ponytail: не эмулятор терминала; -P прогресс с \r рисуется грубовато, для живого прогресса есть fallback "в терминале"
final class CommandRunner: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?
    private let textView = NSTextView()
    private var process: Process?
    private let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    func run(command: String, port: String, password: String, title: String) {
        // повторный запуск: гасим прошлый процесс, чтобы не наслаивался
        if let old = process, old.isRunning { old.terminate() }
        ensureWindow(title: title)
        clear()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let (cmd, rsh) = runTransport(command: command, port: port)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["RSYNC_RSH"] = rsh
        if !password.isEmpty {
            env["SSH_ASKPASS"] = askpassHelperPath()
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = env["DISPLAY"] ?? ":0"
            env["RSYNC_BUILDER_PASS"] = password
        }
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.append(text) }
        }
        proc.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.append("\n[exit \(finished.terminationStatus)]\n")
                if self?.process === finished { self?.process = nil }
            }
        }
        do {
            try proc.run()
            process = proc
        } catch {
            append("failed to start: \(error.localizedDescription)\n")
        }
    }

    // хелпер для SSH_ASKPASS: печатает пароль из переменной окружения. Секрета в файле нет, только чтение env
    private func askpassHelperPath() -> String {
        let path = NSTemporaryDirectory() + "rsync-builder-askpass.sh"
        let script = "#!/bin/sh\nprintf '%s\\n' \"$RSYNC_BUILDER_PASS\"\n"
        FileManager.default.createFile(
            atPath: path,
            contents: script.data(using: .utf8),
            attributes: [.posixPermissions: 0o700]
        )
        return path
    }

    private func append(_ text: String) {
        textView.textStorage?.append(
            NSAttributedString(string: text, attributes: [.font: mono, .foregroundColor: NSColor.textColor])
        )
        textView.scrollToEndOfDocument(nil)
    }

    private func clear() {
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }

    private func ensureWindow(title: String) {
        if let w = window {
            w.title = title
            return
        }
        let rect = NSRect(x: 0, y: 0, width: 760, height: 440)
        let scroll = NSScrollView(frame: rect)
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder

        textView.isEditable = false
        textView.isRichText = false
        textView.font = mono
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView

        let w = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = title
        w.contentView = scroll
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        window = w
    }

    // окно закрыли - гасим процесс, чтобы rsync не работал вслепую в фоне
    func windowWillClose(_ notification: Notification) {
        if let p = process, p.isRunning { p.terminate() }
    }
}
