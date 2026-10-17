#!/bin/zsh
# App Store screenshot sets (light mode, clean status bar). Usage: appstore_shots.sh <dest dir>
set -u
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
APP=$HOME/Library/Developer/ArtPrice/DerivedData/Build/Products/Debug-iphonesimulator/ArtPrice.app
B=pro.aijam.gtp-art
DEST=$1
capture() {
  SIM=$1; OUT=$2; mkdir -p "$OUT"
  xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b >/dev/null
  xcrun simctl ui "$SIM" appearance light
  xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ""
  xcrun simctl install "$SIM" "$APP"
  shot() { n=$1; w=$2; shift 2
    xcrun simctl terminate "$SIM" $B 2>/dev/null
    xcrun simctl launch "$SIM" $B -uiTesting -fixedDay 2026-10-12 -onboarded "$@" >/dev/null
    sleep "$w"; xcrun simctl io "$SIM" screenshot "$OUT/$n.png" >/dev/null 2>&1; }
  shot 01-pick-question 6 -startMode pick_price
  shot 02-pricier 6 -startMode higher_lower -seedSalt 2
  shot 03-bid-reveal 8 -startMode bid -autoAnswer -autoBest
  shot 04-pick-reveal 8 -startMode pick_price -autoAnswer
  shot 05-daily-result 8 -startMode daily -autoAnswer
  shot 06-taste-reveal 9 -startMode swipe -autoAnswer
  shot 07-category-reveal 8 -startMode category -autoAnswer
  shot 08-home 6
  xcrun simctl terminate "$SIM" $B 2>/dev/null
  xcrun simctl status_bar "$SIM" clear
}
capture ArtCI-26-Max "$DEST/6.9-inch-1320x2868"
capture ArtCI-26 "$DEST/6.3-inch-1206x2622"
for f in "$DEST"/*/*.png; do
  printf '%s %s\n' "$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" | tail -3 | awk '{print $2}' | tr '\n' 'x')" "$(basename "$f")"
done
du -sh "$DEST"
