<p align="center">
  <img src="Assets/AppIcon.png" alt="иконка rsync builder" width="128">
</p>

<h1 align="center">rsync builder</h1>

<p align="center">
  <strong>Язык:</strong> <a href="README.md">EN</a> | RU
</p>

<p align="center">
  <strong>сборка и запуск команд rsync из меню-бара</strong>
</p>

<p align="center">
  <a href="https://github.com/boundlessend/rsync-builder/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/boundlessend/rsync-builder/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/boundlessend/rsync-builder/actions/workflows/release.yml"><img alt="Release DMG" src="https://github.com/boundlessend/rsync-builder/actions/workflows/release.yml/badge.svg"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-26%2B-111827">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-f05138">
  <img alt="license" src="https://img.shields.io/badge/license-BSD--3--Clause-2563eb">
</p>

`rsync builder` - небольшое нативное macOS-приложение в меню-баре, которое помогает
собирать команды `rsync` для переноса файлов между Mac и сервером. Живёт в меню-баре
(без иконки в доке); по клику открывается компактная панель с живой командой, которую
можно скопировать в буфер или запустить в терминале.

## Возможности

- Живёт в меню-баре, открывается панелью-поповером (без дока и без обычного окна)
- Направление upload / download с подписями источник ⇄ приём
- Профили серверов (`user@host`, порт, удалённый путь), хранятся локально и выбираются из меню
- Перетаскивание файла или папки в локальное поле подставляет полный путь
- Флаги `-a`, `-v`, `-c`; паттерны `--exclude` в поповере
- Поповер доп. опций: `-z` сжатие, `-P` прогресс, `-u` update, `--delete`, `--stats`, `--bwlimit`
- Деплой-хелперы: `--no-owner --no-group`, `--mkpath`, `--chmod`, sudo на сервере и пост-команда
  (только для upload), запускаемая по ssh (напр. `cd ~/app && docker compose up -d`)
- Кнопка Preview: пробный прогон (`-n`), чтобы увидеть, что будет перенесено, до реального запуска
- У каждого переключателя подсказка, за что отвечает флаг
- Живая команда с безопасным shell-квотингом путей
- Копирование в буфер или запуск в отдельном окне терминала (там же вводится пароль SSH)
- Язык интерфейса (English / Русский) переключается в Настройках
- Проверка обновлений в Настройках: сверяет твою версию с последним релизом на GitHub

## Установка

Скачай `rsync-builder.dmg` из [последнего релиза](https://github.com/boundlessend/rsync-builder/releases/latest),
открой и перетащи **rsync builder** в **Applications**. Иконка появится в меню-баре;
выход - **••• → Quit**, настройки - **••• → Settings…**.

Приложение не подписано и не нотаризовано, поэтому при первом запуске кликни по нему
правой кнопкой и выбери **Открыть**, затем подтверди. Требуется macOS 26 или новее.

## Сборка из исходников

```sh
./build.sh            # релиз-сборка -> rsync-builder.app
open rsync-builder.app
```

## Разработка (hot reload)

```sh
./dev.sh              # debug-сборка с -interposable
```

Нужен запущенный [InjectionIII](https://github.com/johnno1962/InjectionIII) для применения
правок SwiftUI на лету.

## Проверка логики

```sh
swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
```

## Зависимости

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - окно терминала для запуска команды
- [Pow](https://github.com/EmergeTools/Pow) - анимации кнопок
- [Defaults](https://github.com/sindresorhus/Defaults) - хранение профилей серверов
- [Inject](https://github.com/krzysztofzablocki/Inject) - hot reload SwiftUI
- Liquid Glass - нативный macOS 26, без зависимости

Твои реальные серверы не хранятся в исходниках: в коде только один профиль `example`,
а сохранённые профили живут лишь в локальном `UserDefaults`.

## Лицензия

BSD 3-Clause. См. [LICENSE](LICENSE).
