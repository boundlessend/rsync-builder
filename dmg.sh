#!/bin/bash
# собирает оформленный DMG (фон + раскладка иконок) из rsync-builder.app
set -euo pipefail
cd "$(dirname "$0")"

APP="rsync-builder.app"
VOL="rsync builder"
BG="Assets/dmg-background.png"
DMG="rsync-builder.dmg"
STAGING="dmg-staging"
RW="rw.dmg"

[ -d "$APP" ] || { echo "нет $APP - сначала ./build.sh"; exit 1; }

rm -rf "$STAGING" "$DMG" "$RW"
mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/"
cp "$BG" "$STAGING/.background/background.png"
ln -s /Applications "$STAGING/Applications"

# промежуточный read-write образ, чтобы Finder мог разложить иконки
hdiutil create -srcfolder "$STAGING" -volname "$VOL" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -E '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# раскладка окна через Finder: фон, размер, размер и позиции иконок
osascript <<EOF
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 760, 520}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 120
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "$APP" of container window to {160, 200}
    set position of item "Applications" of container window to {400, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$DEV" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$RW" "$STAGING"
echo "готово: $(pwd)/$DMG"
