#!/bin/bash
# собирает релиз и заворачивает бинарь в rsync-builder.app
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="rsync-builder.app"
BIN=".build/release/rsync-builder"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/rsync-builder"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp menubar-icon.png "$APP/Contents/Resources/menubar-icon.png"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>rsync builder</string>
  <key>CFBundleIdentifier</key><string>dev.senya.rsync-builder</string>
  <key>CFBundleExecutable</key><string>rsync-builder</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleShortVersionString</key><string>1.3.1</string>
  <key>CFBundleVersion</key><string>1.3.1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Arseni Okhrimenko. BSD 3-Clause.</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "готово: $(pwd)/$APP"
