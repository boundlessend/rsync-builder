import AppKit
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

// пишет пароль в 0600-файл и хелпер, читающий его; возвращает путь хелпера для SSH_ASKPASS.
// имя случайное (не предсказуемое); пароль не попадает в окружение процесса
private func writeAskpass(password: String) -> String {
    let token = UUID().uuidString
    let dir = NSTemporaryDirectory()
    let pwFile = dir + "rb-\(token).pw"
    let helper = dir + "rb-\(token).sh"
    let fm = FileManager.default
    fm.createFile(atPath: pwFile, contents: Data(password.utf8), attributes: [.posixPermissions: 0o600])
    fm.createFile(
        atPath: helper, contents: Data(askpassScript(passwordFile: pwFile).utf8),
        attributes: [.posixPermissions: 0o700])
    return helper
}

// коробка для хвоста недорезанного UTF-8 символа между чанками пайпа;
// класс вместо captured var, чтобы не мутировать захваченную переменную из конкурентных замыканий
// (вызовы readability/termination handler-ов фактически последовательны, гонки нет)
private final class ByteCarry: @unchecked Sendable {
    var data = Data()
}

// удаляет хелпер и парный .pw после запуска (идемпотентно - зовётся и из terminationHandler, и из cancel)
private func cleanupAskpass(helper: String) {
    guard !helper.isEmpty, helper.hasSuffix(".sh") else { return }
    let fm = FileManager.default
    try? fm.removeItem(atPath: helper)
    try? fm.removeItem(atPath: String(helper.dropLast(3)) + ".pw")
}

// запуск rsync через Process без терминала; состояние публикуется, UI рисует ContentView (крутилка в кнопке, баннер результата).
// пароль подаётся ssh через SSH_ASKPASS из 0600-файла и на диск попадает лишь на время запуска, не в окружение.
// ponytail: не эмулятор терминала; -P прогресс с \r в выводе рисуется грубовато, для живого прогресса есть fallback "в терминале"
@MainActor
final class CommandRunner: ObservableObject {
    @Published private(set) var state: RunState = .idle
    @Published private(set) var output = ""
    private(set) var successMode: SuccessMode = .toast
    private var process: Process?
    private var askpassHelper = ""
    private var generation = 0

    // выход из приложения посреди запуска: гасим процесс и подчищаем askpass-файлы,
    // не дожидаясь terminationHandler, который может уже не успеть
    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }
    }

    func run(command: String, port: String, password: String, successMode: SuccessMode) {
        // повторный запуск: гасим прошлый процесс, чтобы не наслаивался
        if let old = process, old.isRunning { old.terminate() }
        generation += 1
        let gen = generation
        self.successMode = successMode
        output = ""
        state = .running

        let (cmd, rsh) = runTransport(command: command, port: port)
        let askpass = password.isEmpty ? "" : writeAskpass(password: password)
        askpassHelper = askpass
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]
        proc.environment = runEnvironment(base: ProcessInfo.processInfo.environment, rsh: rsh, askpass: askpass)

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        // чанк может разрезать многобайтовый символ (кириллица в именах файлов) -
        // недорезанный хвост несём в следующий чанк
        let carry = ByteCarry()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            let (text, rest) = utf8SplitValidPrefix(carry.data + chunk)
            carry.data = rest
            guard !text.isEmpty else { return }
            // DispatchQueue.main, не Task: только serial queue гарантирует порядок чанков
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.append(text) } }
        }
        proc.terminationHandler = { [weak self] finished in
            // снимаем handler и дочитываем остаток - иначе хвост вывода быстрого процесса теряется
            pipe.fileHandleForReading.readabilityHandler = nil
            let tail = ((try? pipe.fileHandleForReading.readToEnd()) ?? nil) ?? Data()
            let text = String(decoding: carry.data + tail, as: UTF8.self)
            cleanupAskpass(helper: askpass)
            let status = finished.terminationStatus
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.generation == gen else { return }  // отменён или запущен новый - игнор
                    if !text.isEmpty { self.append(text) }
                    self.finish(status: status, gen: gen)
                }
            }
        }
        do {
            try proc.run()
            process = proc
        } catch {
            cleanupAskpass(helper: askpass)
            askpassHelper = ""
            output = error.localizedDescription
            state = .finished(127)
        }
    }

    // вывод копится ограниченно, чтобы большой -v перенос не раздувал память и рендер баннера
    // ponytail: жёсткий cap с потерей начала; полный вывод - через "Запустить в терминале"
    private func append(_ text: String) {
        output = String((output + text).suffix(64_000))
    }

    private func finish(status: Int32, gen: Int) {
        state = .finished(status)
        process = nil
        askpassHelper = ""
        // успех обычного Run: короткая галочка-уведомление, затем само гаснет
        if status == 0, successMode == .toast {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                MainActor.assumeIsolated {
                    if self.generation == gen, self.state == .finished(0) { self.dismiss() }
                }
            }
        }
    }

    // отмена текущего запуска: гасим процесс, возвращаемся в покой без баннера ошибки
    func cancel() {
        generation += 1  // инвалидирует terminationHandler, чтобы не показать ложную "ошибку"
        process?.terminate()
        process = nil
        cleanupAskpass(helper: askpassHelper)
        askpassHelper = ""
        state = .idle
        output = ""
    }

    // закрыть баннер результата
    func dismiss() {
        state = .idle
        output = ""
    }
}
