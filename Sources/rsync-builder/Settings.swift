import SwiftUI

// окно Настроек (⌘,) с выбором языка интерфейса
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
        .frame(width: 360, height: 120)
    }
}
