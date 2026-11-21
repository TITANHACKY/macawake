#!/bin/bash
# awake installer — sets up the awake CLI and LaunchDaemon root service.
#
# Usage (Remote):
#   curl -fsSL https://raw.githubusercontent.com/TITANHACKY/macawake/main/install.sh | bash
#
# Usage (Local cloned repo):
#   bash install.sh
#
# You will be asked for your admin password ONCE to register the LaunchDaemon.
# After that, awake needs NO admin privileges or password for daily usage.

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/TITANHACKY/macawake/main}"

err()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }
info() { printf '\033[1;32m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }

# macOS only — pmset -a disablesleep is a macOS feature.
if [ "$(uname -s)" != "Darwin" ]; then
  err "MacAwake only works on macOS."
  exit 1
fi

# Target user who will own the awake configuration.
TARGET_USER="${SUDO_USER:-$(id -un)}"
if [ "$TARGET_USER" = root ]; then
  err "Run this installer as your normal user (not via sudo). Sudo will be requested automatically."
  exit 1
fi

TMP=""
cleanup() {
  [ -n "$TMP" ] && rm -f "$TMP"
}
trap cleanup EXIT

# Check if installing from local directory or downloading
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
SOURCE_SCRIPT=""

if [ -n "$DIR" ] && [ -f "$DIR/awake" ]; then
  info "Using local awake script from $DIR/awake"
  SOURCE_SCRIPT="$DIR/awake"
else
  command -v curl >/dev/null 2>&1 || { err "curl is required to download awake."; exit 1; }
  TMP="$(mktemp -t awake.XXXXXX)"
  info "Downloading awake from GitHub…"
  curl -fsSL "$REPO_RAW/awake" -o "$TMP"
  head -1 "$TMP" | grep -q '^#!/bin/bash' || { err "Downloaded file is corrupted or not a valid script. Aborting."; exit 1; }
  SOURCE_SCRIPT="$TMP"
fi

info "Installing MacAwake (Admin password required ONCE for LaunchDaemon setup)…"
sudo bash "$SOURCE_SCRIPT" --install "$TARGET_USER"

# Check if /usr/local/bin is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "/usr/local/bin"; then
  echo
  warn "NOTE: /usr/local/bin is not in your current PATH."
  echo "Add it to your shell config (~/.zshrc or ~/.bash_profile):"
  echo "    export PATH=\"/usr/local/bin:\$PATH\""
fi

echo
info "Installation complete! Try it out (no sudo needed):"
echo "    awake                # Open live Trading Terminal"
echo "    awake -t 2h          # Stay awake 2 hours with live countdown ticker"
echo "    awake --help         # Full options & cheatsheet"
