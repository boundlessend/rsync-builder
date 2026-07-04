import SwiftUI

// окно Настроек (⌘,): язык интерфейса + проверка обновлений
struct SettingsView: View {
    @AppStorage("lang") private var lang: Lang = .en
    @StateObject private var updater = UpdateChecker()
    @Environment(\.openURL) private var openURL

    private var s: L10n { .of(lang) }

    var body: some View {
        Form {
            Picker(s.settingsLanguage, selection: $lang) {
                ForEach(Lang.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Section(s.updateSection) {
                HStack(spacing: 8) {
                    Button(s.checkUpdatesButton) { Task { await updater.check() } }
                        .disabled(updater.state == .checking)
                    if updater.state == .checking { ProgressView().controlSize(.small) }
                    Spacer()
                    Text("v\(appVersion)").font(.caption).foregroundStyle(.secondary)
                }
                updateStatus
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 220)
    }

    // строка результата проверки обновления
    @ViewBuilder private var updateStatus: some View {
        switch updater.state {
        case .idle, .checking:
            EmptyView()
        case .upToDate:
            Label(s.updateUpToDate, systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.green)
        case .available(let version, let url):
            VStack(alignment: .leading, spacing: 4) {
                Label("\(s.updateAvailable) \(version)", systemImage: "arrow.down.circle").font(.caption)
                Button(s.updateOpenRelease) {
                    if let u = URL(string: url) { openURL(u) }
                }
                .controlSize(.small)
            }
        case .failed(let msg):
            Label("\(s.updateFailed) \(msg)", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.orange)
        }
    }
}
