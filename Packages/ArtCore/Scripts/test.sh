#!/bin/sh
# Runs the ArtCore tests: `Packages/ArtCore/Scripts/test.sh [extra swift test args]`
#
# Why this exists: with only the Command Line Tools installed (Swift 6.3.1, no Xcode), SwiftPM
# passes the CLT Frameworks directory to the compiler with -I instead of -F. `import Testing`
# then fails, and SwiftPM's generated test runner (`#if canImport(Testing)`) silently compiles
# without Swift Testing. Passing the paths explicitly fixes both. With Xcode selected the
# flags are not added and this is plain `swift test`.
set -eu
PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEV_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
CLT=/Library/Developer/CommandLineTools
FW="$CLT/Library/Developer/Frameworks"
LIB="$CLT/Library/Developer/usr/lib"
if [ "$DEV_DIR" = "$CLT" ] && [ -d "$FW/Testing.framework" ]; then
  exec swift test --package-path "$PACKAGE_DIR" \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$LIB" "$@"
fi
exec swift test --package-path "$PACKAGE_DIR" "$@"
