#!/bin/bash
# hot-reload запуск для Inject: debug-сборка с -interposable + запуск
# требуется установленный и запущенный InjectionIII.app: https://github.com/johnno1962/InjectionIII
set -euo pipefail
cd "$(dirname "$0")"

[ -d rsync-builder.app ] || ./build.sh
swift build -Xlinker -interposable
cp .build/debug/rsync-builder rsync-builder.app/Contents/MacOS/rsync-builder
open rsync-builder.app
echo "запущено (debug+interposable). Открой InjectionIII.app, правь Sources/*.swift - UI обновится на лету"
