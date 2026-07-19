import Combine
import Foundation

// единственный источник версии - CFBundleShortVersionString из Info.plist (задаётся в build.sh);
// в debug/swift run бандла нет - тогда "dev"
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

// ответ GitHub Releases API (нужны только тег и ссылка на страницу релиза)
struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, url: String)
    case failed(String)
}

enum UpdateError: LocalizedError {
    case badStatus(Int)
    case rateLimited

    // 4xx и rate limit повтором через полсекунды не лечатся - пробрасываем сразу
    var retriable: Bool {
        switch self {
        case .rateLimited: return false
        case .badStatus(let code): return !(400..<500).contains(code)
        }
    }

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "GitHub API returned status \(code)"
        case .rateLimited: return "GitHub API rate limit reached, try again later"
        }
    }
}

// коннектор к GitHub Releases API для проверки обновлений
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var state: UpdateState = .idle

    private let releaseURLString = "https://api.github.com/repos/boundlessend/rsync-builder/releases/latest"

    // ручная проверка (кнопка в Настройках): показывает любой исход, включая ошибки
    func check() async {
        state = .checking
        do {
            let release = try await fetchLatest()
            state =
                isUpdateAvailable(current: appVersion, latestTag: release.tagName)
                ? .available(version: release.tagName, url: release.htmlURL)
                : .upToDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // тихая автопроверка при запуске: показываем только при наличии обновления,
    // сетевые сбои намеренно игнорируем - фоновую проверку не выносим пользователю
    func checkSilently() async {
        guard let release = try? await fetchLatest() else { return }
        if isUpdateAvailable(current: appVersion, latestTag: release.tagName) {
            state = .available(version: release.tagName, url: release.htmlURL)
        }
    }

    // до 3 попыток для временных сбоев (сеть, 5xx), затем пробрасываем последнюю ошибку
    private func fetchLatest() async throws -> GitHubRelease {
        guard let url = URL(string: releaseURLString) else { throw UpdateError.badStatus(-1) }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("rsync-builder (github.com/boundlessend/rsync-builder)", forHTTPHeaderField: "User-Agent")
        var lastError: Error = UpdateError.badStatus(-1)
        for attempt in 1...3 {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw UpdateError.badStatus(-1) }
                if http.statusCode == 403 { throw UpdateError.rateLimited }
                guard http.statusCode == 200 else { throw UpdateError.badStatus(http.statusCode) }
                return try JSONDecoder().decode(GitHubRelease.self, from: data)
            } catch {
                if let e = error as? UpdateError, !e.retriable { throw e }
                lastError = error
                if attempt < 3 { try? await Task.sleep(nanoseconds: 500_000_000) }
            }
        }
        throw lastError
    }
}
