#!/bin/bash
# awake installer — setup for the awake CLI and LaunchDaemon root service.
#
# Usage (Remote):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TITANHACKY/macawake/main/install.sh)"
#   or:
#   curl -fsSL https://raw.githubusercontent.com/TITANHACKY/macawake/main/install.sh | bash
#
# Usage (Local cloned repo):
#   bash install.sh
#
# You will be asked for your admin password ONCE to register the LaunchDaemon.
# After that, awake needs NO admin privileges or password for daily usage.

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/TITANHACKY/macawake/main}"

# ANSI Colors & Styles
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_DIM="\033[2m"

err()  { printf "  ${C_RED}✗ %b${C_RESET}\n" "$*" >&2; }
info() { printf "  ${C_GREEN}✓ %b${C_RESET}\n" "$*"; }
warn() { printf "  ${C_YELLOW}! %b${C_RESET}\n" "$*"; }

TMP=""
cleanup() {
  [ -n "$TMP" ] && rm -f "$TMP"
  printf '\033[?25h' 2>/dev/null || true
}
trap cleanup EXIT

# ---- Banner ----
printf "\n"
printf "${C_CYAN}${C_BOLD}   __  __            _                     _        ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}  |  \/  |__ _ __   /_\ __ __ __ __ _ _ _ | |__     ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}  | |\/| / _\` / _| / _ \\\\ V  V // _\` | / /| / /     ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}  |_|  |_\\__,_\\__|/_/ \\_\\\\_/\\_/ \\__,_|\\_\\| |_\\_\\     ${C_RESET}\n"
printf "  ${C_DIM}MacAwake v1.2.0 • Lid-closed sleep manager for macOS${C_RESET}\n\n"

# ---- Step 1: System Check ----
printf "  ${C_BOLD}[1/4] 🍏 Checking system requirements...${C_RESET}\n"
if [ "$(uname -s)" != "Darwin" ]; then
  err "MacAwake only works on macOS (Darwin). Current OS: $(uname -s)"
  exit 1
fi

TARGET_USER="${SUDO_USER:-$(id -un)}"
if [ "$TARGET_USER" = root ]; then
  err "Please run this installer as your normal user (not via sudo). Sudo will be requested automatically."
  exit 1
fi
info "macOS $(sw_vers -productVersion 2>/dev/null || uname -r) ($(uname -m)) detected. Target user: ${C_BOLD}$TARGET_USER${C_RESET}"
echo

# ---- Step 2: Package Acquisition ----
printf "  ${C_BOLD}[2/4] 📦 Fetching MacAwake package...${C_RESET}\n"
DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
fi

SOURCE_SCRIPT=""
if [ -n "$DIR" ] && [ -f "$DIR/awake" ]; then
  info "Using local package from ${C_DIM}$DIR/awake${C_RESET}"
  SOURCE_SCRIPT="$DIR/awake"
else
  command -v curl >/dev/null 2>&1 || { err "curl is required to download MacAwake."; exit 1; }
  TMP="$(mktemp -t awake.XXXXXX)"

  printf "  ${C_CYAN}⠋${C_RESET} Downloading MacAwake core from GitHub...\r"
  if curl -fsSL --connect-timeout 5 --max-time 30 "$REPO_RAW/awake" -o "$TMP"; then
    if head -1 "$TMP" | grep -q '^#!/bin/bash'; then
      printf "\r  ${C_GREEN}✓${C_RESET} Downloaded core package (v1.2.0)        \n"
    else
      printf "\r  ${C_RED}✗${C_RESET} Downloaded file is corrupted or invalid.\n"
      exit 1
    fi
  else
    printf "\r  ${C_RED}✗${C_RESET} Failed to download from GitHub. Check your connection.\n"
    exit 1
  fi
  SOURCE_SCRIPT="$TMP"
fi
echo

# ---- Step 3: Admin Authentication & LaunchDaemon Setup ----
printf "  ${C_BOLD}[3/4] 🔐 Installing LaunchDaemon root service...${C_RESET}\n"
printf "  ${C_DIM}Admin password is required ONCE to install the background service.${C_RESET}\n"
printf "  ${C_DIM}You will NEVER need admin or a password for daily usage.${C_RESET}\n\n"

# Ensure cursor is visible for password prompt
printf '\033[?25h'

if sudo bash "$SOURCE_SCRIPT" --install "$TARGET_USER" --quiet; then
  printf "  ${C_GREEN}✓ LaunchDaemon registered and running${C_RESET}\n"
else
  printf "  ${C_RED}✗ Installation failed during LaunchDaemon setup.${C_RESET}\n"
  exit 1
fi
echo

# ---- Step 4: Verification & Readiness ----
printf "  ${C_BOLD}[4/4] ⚡ Verifying service & initializing power state...${C_RESET}\n"

if [ -x "/usr/local/bin/awake" ] && [ -d "/Library/Application Support/awake" ]; then
  info "Background service and files verified"
else
  warn "Service registered; verifying in background"
fi
echo

# ---- PATH Check ----
if ! echo "$PATH" | tr ':' '\n' | grep -qx "/usr/local/bin"; then
  printf "  ${C_YELLOW}┌─────────────────────────────────────────────────────────────────┐${C_RESET}\n"
  printf "  ${C_YELLOW}│${C_RESET}  ${C_BOLD}! Notice: /usr/local/bin is not in your current PATH${C_RESET}           ${C_YELLOW}│${C_RESET}\n"
  printf "  ${C_YELLOW}│${C_RESET}  ${C_DIM}Add it to your shell config (~/.zshrc or ~/.bash_profile):${C_RESET}       ${C_YELLOW}│${C_RESET}\n"
  printf "  ${C_YELLOW}│${C_RESET}      ${C_CYAN}export PATH=\"/usr/local/bin:\$PATH\"${C_RESET}                         ${C_YELLOW}│${C_RESET}\n"
  printf "  ${C_YELLOW}└─────────────────────────────────────────────────────────────────┘${C_RESET}\n\n"
fi

# ---- Completion Summary Card ----
printf "${C_CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
printf "${C_CYAN}║${C_RESET}  ${C_GREEN}${C_BOLD}🎉 MacAwake successfully installed!${C_RESET}                                         ${C_CYAN}║${C_RESET}\n"
printf "${C_CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${C_RESET}\n"
printf "\n"
printf "  ${C_BOLD}Installed Locations:${C_RESET}\n"
printf "    • CLI Binary   : ${C_CYAN}/usr/local/bin/awake${C_RESET}\n"
printf "    • Root Daemon  : ${C_DIM}/usr/local/libexec/awake-guard${C_RESET}\n"
printf "    • LaunchDaemon : ${C_DIM}/Library/LaunchDaemons/com.awake.guard.plist${C_RESET}\n"
printf "    • Config File  : ${C_DIM}/Library/Application Support/awake/config (30%% cutoff)${C_RESET}\n"
printf "\n"
printf "${C_DIM}────────────────────────────────────────────────────────────────────────────────${C_RESET}\n"
printf "  ${C_BOLD}QUICK START (NO ADMIN / NO PASSWORD NEEDED):${C_RESET}\n"
printf "    ${C_CYAN}awake${C_RESET}                Launch live Trading Terminal TUI\n"
printf "    ${C_CYAN}awake -t 2h${C_RESET}          Stay awake for 2 hours with live countdown ticker\n"
printf "    ${C_CYAN}awake -b 25${C_RESET}          Set battery cutoff preference to 25%% (default: 30%%)\n"
printf "    ${C_CYAN}awake --status${C_RESET}       Inspect power, active sessions, and daemon health\n"
printf "    ${C_CYAN}awake --help${C_RESET}         View all CLI options & hotkeys cheatsheet\n"
printf "${C_DIM}────────────────────────────────────────────────────────────────────────────────${C_RESET}\n\n"
