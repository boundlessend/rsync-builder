import Foundation

enum Lang: String, CaseIterable, Identifiable {
    case en, ru
    var id: String { rawValue }
    var title: String { self == .en ? "English" : "Русский" }
}

// все пользовательские строки; выбор языка - в Настройках
struct L10n {
    let upload, download: String
    let serverProfiles, saveButton, saveHelp, portPlaceholder, portLabel: String
    let sourceLocal, destLocal, destServer, sourceServer: String
    let localPlaceholder, localHelp, browse, browseHelp, localTip: String
    let remotePlaceholder, remoteHelp: String
    let flags, flagAHelp, flagVHelp, flagCHelp: String
    let flagAA11y, flagVA11y, flagCA11y: String
    let excludeSection, excludePlaceholder, addExcludeHelp: String
    let incompleteWarning: String
    let copy, copied, copyHelp, run, runHelp: String
    let terminalTitle, settingsLanguage, settingsItem, quitItem: String
    let previewLabel, previewHelp, optionsTitle, safetyHeader, transferHeader: String
    let optDeleteLabel, optDeleteHelp, optDeleteWarn, optUpdateLabel, optUpdateHelp: String
    let optCompressLabel, optCompressHelp, optProgressLabel, optProgressHelp: String
    let optStatsLabel, optStatsHelp, optBwlimitLabel, optBwlimitHelp: String

    static func of(_ lang: Lang) -> L10n { lang == .ru ? ru : en }

    static let en = L10n(
        upload: "Upload",
        download: "Download",
        serverProfiles: "Server profiles",
        saveButton: "Save",
        saveHelp: "Save the current server as a profile",
        portPlaceholder: "SSH port",
        portLabel: "Port",
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
        terminalTitle: "Terminal - rsync builder",
        settingsLanguage: "Language",
        settingsItem: "Settings…",
        quitItem: "Quit",
        previewLabel: "Preview",
        previewHelp: "dry run: show what would transfer without changing anything",
        optionsTitle: "Options",
        safetyHeader: "Safety",
        transferHeader: "Transfer",
        optDeleteLabel: "--delete (mirror)",
        optDeleteHelp: "delete files on the destination that no longer exist in the source",
        optDeleteWarn: "removes files on the other side - run Preview first",
        optUpdateLabel: "-u update",
        optUpdateHelp: "skip files that are newer on the destination",
        optCompressLabel: "-z compress",
        optCompressHelp: "compress file data during transfer (useful on slow links)",
        optProgressLabel: "-P progress",
        optProgressHelp: "show progress and keep partially transferred files (resume)",
        optStatsLabel: "--stats",
        optStatsHelp: "print a transfer summary with human-readable sizes",
        optBwlimitLabel: "bandwidth",
        optBwlimitHelp: "limit transfer speed in KB/s; empty = unlimited"
    )

    static let ru = L10n(
        upload: "Отправка",
        download: "Загрузка",
        serverProfiles: "Профили серверов",
        saveButton: "Сохранить",
        saveHelp: "сохранить текущий сервер как профиль",
        portPlaceholder: "порт SSH",
        portLabel: "Порт",
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
        terminalTitle: "Терминал - rsync builder",
        settingsLanguage: "Язык",
        settingsItem: "Настройки…",
        quitItem: "Выход",
        previewLabel: "Превью",
        previewHelp: "пробный прогон: показать, что будет перенесено, ничего не меняя",
        optionsTitle: "Опции",
        safetyHeader: "Безопасность",
        transferHeader: "Передача",
        optDeleteLabel: "--delete (зеркало)",
        optDeleteHelp: "удалять на приёмнике файлы, которых больше нет в источнике",
        optDeleteWarn: "удаляет файлы на той стороне - сначала запусти Preview",
        optUpdateLabel: "-u обновление",
        optUpdateHelp: "не трогать файлы, которые новее на приёмнике",
        optCompressLabel: "-z сжатие",
        optCompressHelp: "сжимать данные при передаче (полезно на медленной сети)",
        optProgressLabel: "-P прогресс",
        optProgressHelp: "показывать прогресс и хранить частичные файлы для докачки",
        optStatsLabel: "--stats",
        optStatsHelp: "печатать сводку по переносу с человекочитаемыми размерами",
        optBwlimitLabel: "скорость",
        optBwlimitHelp: "ограничить скорость в КБ/с; пусто = без лимита"
    )
}
