#!/usr/bin/env bash
# Build the Android app and install + launch on every connected device/emulator (Saga + emulator).
# Defaults to RELEASE: debug Fuse Android is unacceptably laggy and misrepresents performance
# (CLAUDE.md §11). Pass --debug ONLY when explicitly needed.
#
# The release `signingConfig` falls back to the debug keystore when there's no keystore.properties,
# so the release APK installs without Play signing set up.
#
# Usage:  scripts/run-android.sh [--release|--debug]   (default: --release)
set -euo pipefail
cd "$(dirname "$0")/.."

ADB="$HOME/Library/Android/sdk/platform-tools/adb"
command -v adb >/dev/null 2>&1 && ADB="$(command -v adb)"
PKG="com.layertwolabs.mobile.ecashwallet"
CONFIG="${1:---release}"
[ "$CONFIG" = "--release" ] || [ "$CONFIG" = "--debug" ] || { echo "usage: $0 [--release|--debug]" >&2; exit 1; }

echo "▸ Building Android ($CONFIG)…"
skip export "$CONFIG"

# The APK is named per build type: -release.apk (minified, signed with debug key as fallback) or
# -debug.apk.
VARIANT="release"
if [ "$CONFIG" = "--debug" ]; then VARIANT="debug"; fi   # plain `&&` one-liner trips `set -e` when false
APK=".build/skip-export/ECashWalletMobile-$VARIANT.apk"
[ -f "$APK" ] || { echo "APK not found at $APK" >&2; exit 1; }

SERIALS="$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1}')"
[ -n "$SERIALS" ] || { echo "No connected Android devices/emulators (check: $ADB devices)." >&2; exit 1; }

for S in $SERIALS; do
  echo "[$S] installing ${VARIANT}..."
  # Debug and release are signed with different keys; if a switch fails with a signature mismatch,
  # uninstall and retry (preserves nothing, but these are dev installs).
  if ! "$ADB" -s "$S" install -r -d "$APK" 2>&1 | tail -1 | grep -q Success; then
    echo "  (signature mismatch? uninstalling + retrying)"
    "$ADB" -s "$S" uninstall "$PKG" >/dev/null 2>&1 || true
    "$ADB" -s "$S" install "$APK" | tail -1
  fi
  "$ADB" -s "$S" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  # Launch is async — poll briefly before deciding (a single immediate pidof races and false-negatives).
  ok=""
  for _ in 1 2 3 4 5 6; do
    if "$ADB" -s "$S" shell pidof "$PKG" >/dev/null 2>&1; then ok=1; break; fi
    sleep 1
  done
  [ -n "$ok" ] && echo "  ✓ running" || echo "  ✗ launch failed"
done
echo "✓ Done."
