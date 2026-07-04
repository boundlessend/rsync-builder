import SwiftUI

// окно Настроек (⌘,): язык интерфейса (проверка обновлений - в меню «•••»)
struct SettingsView: View {
    @AppStorage("lang") private var lang: Lang = .en

    private var s: L10n { .of(lang) }

    var body: some View {
        Form {
            Picker(s.settingsLanguage, selection: $lang) {
                ForEach(Lang.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 120)
    }
}
