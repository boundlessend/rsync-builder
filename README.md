# rsync builder

нативное окно macOS (SwiftUI): собирает команды rsync/scp для переноса файлов
комп <-> сервер, показывает живую команду и копирует её в буфер для вставки в терминал

## сборка и запуск

```sh
./build.sh            # release-сборка rsync-builder.app
open rsync-builder.app
```

## разработка с hot-reload

```sh
./dev.sh              # debug + -interposable, нужен запущенный InjectionIII.app
```

## проверка логики

```sh
swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
```

## зависимости

- SwiftTerm - терминал в отдельном окне
- Pow - анимации кнопок (spray/shine)
- Defaults - хранение профилей серверов (example, deploy зашиты стартовыми)
- Inject - hot-reload UI при разработке
- Liquid Glass - нативный macOS 26, без зависимости
