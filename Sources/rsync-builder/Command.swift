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

// стартовые профили из rsync.docx
let defaultProfiles: [ServerProfile] = [
    ServerProfile(name: "example", userHost: "user@example.com", port: "22", remotePath: "~/app/"),
    ServerProfile(name: "deploy", userHost: "deploy@server.example", port: "8022", remotePath: "~/app/"),
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
        parts.append("--exclude='\(ex.pattern)'")
    }

    let remote = "\(userHost):\(remotePath)"
    switch direction {
    case .upload:
        parts.append(localPath)
        parts.append(remote)
    case .download:
        parts.append(remote)
        parts.append(localPath)
    }
    return parts.joined(separator: " ")
}
