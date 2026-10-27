#!/usr/bin/env bash
# Builds scroll-fix, installs it into ~/.local/bin and loads it as a LaunchAgent.
# Usage: ./install.sh [uninstall]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.lkteloeken.scrollfix"
BIN_DIR="${SCROLL_FIX_BIN_DIR:-$HOME/.local/bin}"
BIN="$BIN_DIR/scroll-fix"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

unload() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
}

if [[ "${1:-}" == "uninstall" ]]; then
  unload
  rm -f "$PLIST" "$BIN"
  echo "Removed $LABEL"
  exit 0
fi

mkdir -p "$ROOT/build" "$BIN_DIR" "$(dirname "$PLIST")"
swiftc -O "$ROOT/Sources/main.swift" -o "$ROOT/build/scroll-fix"
# Ad-hoc signature: macOS ties the Accessibility grant to it, so every rebuild asks again.
codesign --force --sign - --identifier "$LABEL" "$ROOT/build/scroll-fix"

unload
install -m 755 "$ROOT/build/scroll-fix" "$BIN"
sed -e "s|@BIN@|$BIN|" -e "s|@HOME@|$HOME|g" "$ROOT/launchd/$LABEL.plist" > "$PLIST"
launchctl bootstrap "$DOMAIN" "$PLIST"

echo "Installed $BIN and loaded $LABEL"
echo "Grant Accessibility to scroll-fix when prompted. Logs: ~/Library/Logs/scroll-fix.log"
