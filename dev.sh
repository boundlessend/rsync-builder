#!/bin/bash
# debug-сборка с -interposable + запуск; с запущенным InjectionIII.app правки методов
# подхватываются на лету (без зависимости Inject авто-refresh SwiftUI-вью не происходит)
# https://github.com/johnno1962/InjectionIII
set -euo pipefail
cd "$(dirname "$0")"

[ -d rsync-builder.app ] || ./build.sh
swift build -Xlinker -interposable
cp .build/debug/rsync-builder rsync-builder.app/Contents/MacOS/rsync-builder
open rsync-builder.app
echo "запущено (debug+interposable). Открой InjectionIII.app и правь Sources/*.swift"
