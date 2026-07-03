import Foundation

// профиль сервера: user@host + порт + путь по умолчанию
struct ServerProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var userHost: String
    var port: String
    var remotePath: String
}

// один пункт исключений (--exclude)
struct ExcludeItem: Identifiable, Hashable {
    let id = UUID()
    var pattern: String
    var on: Bool
}

enum Direction: String, CaseIterable {
    case upload = "Upload"
    case download = "Download"
}

// пример профиля; реальные серверы пользователь добавляет сам (хранятся локально в UserDefaults)
let defaultProfiles: [ServerProfile] = [
    ServerProfile(name: "example", userHost: "user@example.com", port: "22", remotePath: "~/remote/"),
]

let defaultExcludes: [ExcludeItem] = [
    ExcludeItem(pattern: ".venv", on: true),
    ExcludeItem(pattern: ".git", on: true),
    ExcludeItem(pattern: ".env", on: true),
    ExcludeItem(pattern: "__pycache__", on: true),
    ExcludeItem(pattern: ".DS_Store", on: true),
    ExcludeItem(pattern: "logs", on: false),
    ExcludeItem(pattern: "google.json", on: false),
]

// экранирование аргумента для shell: кавычим только при наличии небезопасных символов
func shellQuote(_ arg: String) -> String {
    let safe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./:@%+=~-")
    if arg.unicodeScalars.allSatisfy({ safe.contains($0) }) {
        return arg
    }
    return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// чистая функция сборки команды rsync
func buildCommand(
    direction: Direction,
    flagA: Bool,
    flagV: Bool,
    flagC: Bool,
    port: String,
    excludes: [ExcludeItem],
    localPath: String,
    userHost: String,
    remotePath: String
) -> String {
    var flags = ""
    if flagA { flags += "a" }
    if flagV { flags += "v" }
    if flagC { flags += "c" }

    var parts: [String] = ["rsync"]
    if !flags.isEmpty { parts.append("-" + flags) }

    let trimmedPort = port.trimmingCharacters(in: .whitespaces)
    if !trimmedPort.isEmpty, trimmedPort != "22" {
        parts.append("-e \"ssh -p \(trimmedPort)\"")
    }

    for ex in excludes where ex.on && !ex.pattern.trimmingCharacters(in: .whitespaces).isEmpty {
        parts.append("--exclude=" + shellQuote(ex.pattern))
    }

    let local = shellQuote(localPath)
    let remote = shellQuote("\(userHost):\(remotePath)")
    switch direction {
    case .upload:
        parts.append(local)
        parts.append(remote)
    case .download:
        parts.append(remote)
        parts.append(local)
    }
    return parts.filter { !$0.isEmpty }.joined(separator: " ")
}
