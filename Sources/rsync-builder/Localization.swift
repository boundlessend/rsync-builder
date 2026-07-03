import Foundation

enum Lang: String, CaseIterable, Identifiable {
    case en, ru
    var id: String { rawValue }
    var title: String { self == .en ? "English" : "Русский" }
}

// все пользовательские строки; выбор языка - в Настройках
struct L10n {
    let upload, download: String
    let serverSection, serverProfiles, saveButton, saveHelp, portPlaceholder, portLabel: String
    let pathsSection, sourceLocal, destLocal, destServer, sourceServer: String
    let localPlaceholder, localHelp, browse, browseHelp, localTip: String
    let remotePlaceholder, remoteHelp: String
    let optionsSection, flags, flagAHelp, flagVHelp, flagCHelp: String
    let flagAA11y, flagVA11y, flagCA11y: String
    let excludeSection, excludePlaceholder, addExcludeHelp: String
    let incompleteWarning: String
    let copy, copied, copyHelp, run, runHelp: String
    let commandMenu, menuRun, menuCopy, menuSaveProfile, menuClear: String
    let terminalTitle, settingsLanguage, settingsItem, quitItem: String

    static func of(_ lang: Lang) -> L10n { lang == .ru ? ru : en }

    static let en = L10n(
        upload: "Upload",
        download: "Download",
        serverSection: "Server",
        serverProfiles: "Server profiles",
        saveButton: "Save",
        saveHelp: "Save the current server as a profile",
        portPlaceholder: "SSH port",
        portLabel: "Port",
        pathsSection: "Paths",
        sourceLocal: "Source · local",
        destLocal: "Destination · local",
        destServer: "Destination · server",
        sourceServer: "Source · server",
        localPlaceholder: "Drop a file here or paste a path",
        localHelp: "Drag a file/folder or type a path. A trailing '/' copies the folder's contents, without it - the folder itself",
        browse: "Browse",
        browseHelp: "Choose a file or folder",
        localTip: "Tip: you can drag a file or folder here from Finder",
        remotePlaceholder: "Path on the server, e.g. ~/app/",
        remoteHelp: "Path on the remote machine. A trailing '/' means the contents, without it - the folder itself",
        optionsSection: "Options",
        flags: "Flags",
        flagAHelp: "archive mode: recursive, preserves permissions, timestamps and symlinks",
        flagVHelp: "verbose - show each transferred file",
        flagCHelp: "compare by checksum instead of size and time",
        flagAA11y: "archive mode",
        flagVA11y: "verbose output",
        flagCA11y: "checksum comparison",
        excludeSection: "Exclude",
        excludePlaceholder: "custom exclude",
        addExcludeHelp: "add exclude",
        incompleteWarning: "Fill in the server and both paths",
        copy: "Copy",
        copied: "Copied",
        copyHelp: "Copy the command to the clipboard",
        run: "Run",
        runHelp: "Run the command in the terminal",
        commandMenu: "Command",
        menuRun: "Run",
        menuCopy: "Copy command",
        menuSaveProfile: "Save profile",
        menuClear: "Clear fields",
        terminalTitle: "Terminal - rsync builder",
        settingsLanguage: "Language",
        settingsItem: "Settings…",
        quitItem: "Quit"
    )

    static let ru = L10n(
        upload: "Отправка",
        download: "Загрузка",
        serverSection: "Сервер",
        serverProfiles: "Профили серверов",
        saveButton: "Сохранить",
        saveHelp: "сохранить текущий сервер как профиль",
        portPlaceholder: "порт SSH",
        portLabel: "Порт",
        pathsSection: "Пути",
        sourceLocal: "Источник · локально",
        destLocal: "Приём · локально",
        destServer: "Приём · на сервере",
        sourceServer: "Источник · на сервере",
        localPlaceholder: "перетащи файл сюда или вставь путь",
        localHelp: "перетащи файл/папку или впиши путь. С '/' в конце папки копируется её содержимое, без '/' - сама папка",
        browse: "Обзор",
        browseHelp: "выбрать файл или папку",
        localTip: "подсказка: сюда можно перетащить файл или папку из Finder",
        remotePlaceholder: "путь на сервере, напр. ~/app/",
        remoteHelp: "путь на удалённой машине. С '/' в конце - содержимое, без - сама папка",
        optionsSection: "Опции",
        flags: "Флаги",
        flagAHelp: "архивный режим: рекурсивно, сохраняет права, время и симлинки",
        flagVHelp: "подробный вывод - показывать каждый передаваемый файл",
        flagCHelp: "сверять по контрольной сумме, а не по размеру и времени",
        flagAA11y: "архивный режим",
        flagVA11y: "подробный вывод",
        flagCA11y: "сверка по контрольной сумме",
        excludeSection: "Исключить",
        excludePlaceholder: "своё исключение",
        addExcludeHelp: "добавить исключение",
        incompleteWarning: "заполни сервер и оба пути",
        copy: "Копировать",
        copied: "Скопировано",
        copyHelp: "скопировать команду в буфер обмена",
        run: "Старт",
        runHelp: "запустить команду в терминале",
        commandMenu: "Команда",
        menuRun: "Запустить",
        menuCopy: "Скопировать команду",
        menuSaveProfile: "Сохранить профиль",
        menuClear: "Очистить поля",
        terminalTitle: "Терминал - rsync builder",
        settingsLanguage: "Язык",
        settingsItem: "Настройки…",
        quitItem: "Выход"
    )
}
