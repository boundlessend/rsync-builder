import Foundation

enum RunState: Equatable {
    case idle, running
    case finished(Int32)
}

// как показывать успех: toast - ничего (обычный Run, хватает крутилки в кнопке);
// showOutput - показать вывод (Preview, где вывод и есть цель)
enum SuccessMode {
    case toast, showOutput
}

// запуск rsync через Process без терминала; состояние публикуется, UI рисует ContentView (крутилка в кнопке, баннер результата).
// пароль (если задан) подаётся ssh через SSH_ASKPASS и на диск не пишется - только в окружении дочернего процесса.
// ponytail: не эмулятор терминала; -P прогресс с \r в выводе рисуется грубовато, для живого прогресса есть fallback "в терминале"
final class CommandRunner: ObservableObject {
    @Published private(set) var state: RunState = .idle
    @Published private(set) var output = ""
    private(set) var successMode: SuccessMode = .toast
    private var process: Process?
    private var generation = 0

    func run(command: String, port: String, password: String, successMode: SuccessMode) {
        // повторный запуск: гасим прошлый процесс, чтобы не наслаивался
        if let old = process, old.isRunning { old.terminate() }
        generation += 1
        let gen = generation
        self.successMode = successMode
        output = ""
        state = .running

        let (cmd, rsh) = runTransport(command: command, port: port)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]
        proc.environment = runEnvironment(
            base: ProcessInfo.processInfo.environment, password: password,
            rsh: rsh, askpassPath: askpassHelperPath())

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.output += text }
        }
        proc.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }  // отменён или запущен новый - игнор
                self.state = .finished(finished.terminationStatus)
                self.process = nil
            }
        }
        do {
            try proc.run()
            process = proc
        } catch {
            output = error.localizedDescription
            state = .finished(127)
        }
    }

    // отмена текущего запуска: гасим процесс, возвращаемся в покой без баннера ошибки
    func cancel() {
        generation += 1  // инвалидирует terminationHandler, чтобы не показать ложную "ошибку"
        process?.terminate()
        process = nil
        state = .idle
        output = ""
    }

    // закрыть баннер результата
    func dismiss() {
        state = .idle
        output = ""
    }

    // хелпер для SSH_ASKPASS: печатает пароль из переменной окружения. Секрета в файле нет, только чтение env
    private func askpassHelperPath() -> String {
        let path = NSTemporaryDirectory() + "rsync-builder-askpass.sh"
        FileManager.default.createFile(
            atPath: path,
            contents: askpassScript.data(using: .utf8),
            attributes: [.posixPermissions: 0o700]
        )
        return path
    }
}
