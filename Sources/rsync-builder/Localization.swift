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
    let deployHeader, optNoOwnerLabel, optNoOwnerHelp, optMkpathLabel, optMkpathHelp: String
    let optChmodLabel, optChmodHelp, optSudoLabel, optSudoHelp: String
    let optPostLabel, optPostHelp, optPostPlaceholder, optPostUploadOnly: String
    let checkUpdatesButton, updateUpToDate: String
    let updateAvailable, updateChecking, updateFailed: String
    let passwordLabel, passwordPlaceholder, passwordHelp: String
    let runInTerminalItem: String
    let runRunning, runDone, runFailed, runClose: String

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
        optStatsLabel: "--stats -h",
        optStatsHelp: "print a transfer summary; -h shows human-readable sizes",
        optBwlimitLabel: "bandwidth",
        optBwlimitHelp: "limit transfer speed in KB/s; empty = unlimited",
        deployHeader: "Deploy",
        optNoOwnerLabel: "don't preserve owner/group",
        optNoOwnerHelp: "add --no-owner --no-group: files take the server's account (useful when UIDs differ)",
        optMkpathLabel: "--mkpath",
        optMkpathHelp: "create missing destination directories (needs rsync 3.2.3+ on both sides)",
        optChmodLabel: "chmod",
        optChmodHelp: "set permissions on transferred files, e.g. Du=rwx,go=rx; empty = leave as is",
        optSudoLabel: "sudo on server",
        optSudoHelp: "run rsync via sudo on the remote (--rsync-path=\"sudo rsync\") to write into system paths",
        optPostLabel: "post-sync command",
        optPostHelp: "after a successful upload, run this over ssh on the server (e.g. cd ~/app && docker compose up -d)",
        optPostPlaceholder: "cd ~/app && docker compose up -d",
        optPostUploadOnly: "post-sync command applies to upload only",
        checkUpdatesButton: "Check for updates",
        updateUpToDate: "You're on the latest version",
        updateAvailable: "Update available:",
        updateChecking: "Checking…",
        updateFailed: "Check failed:",
        passwordLabel: "Password",
        passwordPlaceholder: "empty if using SSH keys",
        passwordHelp: "SSH password. Kept in memory only, never saved. Leave empty for key-based login",
        runInTerminalItem: "Run in terminal",
        runRunning: "Running…",
        runDone: "Done",
        runFailed: "Failed",
        runClose: "Close"
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
        optStatsLabel: "--stats -h",
        optStatsHelp: "печатать сводку по переносу; -h - человекочитаемые размеры",
        optBwlimitLabel: "скорость",
        optBwlimitHelp: "ограничить скорость в КБ/с; пусто = без лимита",
        deployHeader: "Деплой",
        optNoOwnerLabel: "не сохранять владельца/группу",
        optNoOwnerHelp: "добавить --no-owner --no-group: файлы получат аккаунт сервера (полезно при разных UID)",
        optMkpathLabel: "--mkpath",
        optMkpathHelp: "создавать недостающие папки назначения (нужен rsync 3.2.3+ с обеих сторон)",
        optChmodLabel: "права",
        optChmodHelp: "выставить права на переданные файлы, напр. Du=rwx,go=rx; пусто = не менять",
        optSudoLabel: "sudo на сервере",
        optSudoHelp: "запускать rsync через sudo на сервере (--rsync-path=\"sudo rsync\"), чтобы писать в системные пути",
        optPostLabel: "пост-команда",
        optPostHelp: "после успешной отправки выполнить по ssh на сервере (напр. cd ~/app && docker compose up -d)",
        optPostPlaceholder: "cd ~/app && docker compose up -d",
        optPostUploadOnly: "пост-команда работает только при upload",
        checkUpdatesButton: "Проверить обновления",
        updateUpToDate: "Установлена последняя версия",
        updateAvailable: "Доступно обновление:",
        updateChecking: "Проверка…",
        updateFailed: "Не удалось проверить:",
        passwordLabel: "Пароль",
        passwordPlaceholder: "пусто при входе по SSH-ключу",
        passwordHelp: "пароль SSH. Хранится только в памяти, не сохраняется. Пусто = вход по ключу",
        runInTerminalItem: "Запустить в терминале",
        runRunning: "Выполняется…",
        runDone: "Готово",
        runFailed: "Не удалось",
        runClose: "Закрыть"
    )
}
