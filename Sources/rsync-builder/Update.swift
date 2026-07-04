import Foundation
import Combine

// единственный источник версии в коде; Info.plist задаётся в build.sh тем же числом
let appVersion = "1.2"

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

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "GitHub API returned status \(code)"
        }
    }
}

// коннектор к GitHub Releases API для проверки обновлений
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var state: UpdateState = .idle

    private let releaseURL = URL(string: "https://api.github.com/repos/boundlessend/rsync-builder/releases/latest")!

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

    // до 3 попыток, затем пробрасываем последнюю ошибку
    private func fetchLatest() async throws -> GitHubRelease {
        var req = URLRequest(url: releaseURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        var lastError: Error = UpdateError.badStatus(-1)
        for attempt in 1...3 {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw UpdateError.badStatus(-1) }
                guard http.statusCode == 200 else { throw UpdateError.badStatus(http.statusCode) }
                return try JSONDecoder().decode(GitHubRelease.self, from: data)
            } catch {
                lastError = error
                if attempt < 3 { try? await Task.sleep(nanoseconds: 500_000_000) }
            }
        }
        throw lastError
    }
}
