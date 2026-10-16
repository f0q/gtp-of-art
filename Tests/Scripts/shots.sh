#!/bin/zsh
# Captures simulator screenshots of the main screens using DEBUG launch arguments.
# Usage: Tests/Scripts/shots.sh <simulator> <path/to/ArtPrice.app> <output dir> [light|dark]
set -euo pipefail
SIM=${1:-ArtCI-26}; APP=$2; OUT=${3:-.build/shots}; APPEARANCE=${4:-light}
BUNDLE=pro.aijam.gtp-art
BASE=(-uiTesting -fixedDay 2026-10-12)
mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl ui "$SIM" appearance "$APPEARANCE"
xcrun simctl install "$SIM" "$APP"
shot() { # name, wait seconds, extra args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$SIM" $BUNDLE 2>/dev/null || true
  xcrun simctl launch "$SIM" $BUNDLE "${BASE[@]}" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "$OUT/$name.png"
}
shot onboarding-1 6
shot home 6 -onboarded
shot pick-question 6 -onboarded -startMode pick_price
shot pick-reveal 8 -onboarded -startMode pick_price -autoAnswer
shot bid 6 -onboarded -startMode bid
shot bid-reveal 8 -onboarded -startMode bid -autoAnswer
shot pricier 6 -onboarded -startMode higher_lower
shot pricier-reveal 8 -onboarded -startMode higher_lower -autoAnswer
shot category-question 6 -onboarded -startMode category
shot category-reveal 8 -onboarded -startMode category -autoAnswer
shot daily-intro 6 -onboarded -startMode daily
shot daily-result 8 -onboarded -startMode daily -autoAnswer
xcrun simctl terminate "$SIM" $BUNDLE 2>/dev/null || true
xcrun simctl ui "$SIM" appearance light
