#!/bin/bash
# awake installer — interactive setup for the awake CLI and LaunchDaemon root service.
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

# ANSI Colors & Styles
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_DIM="\033[2m"
C_BLUE="\033[1;34m"
C_MAGENTA="\033[1;35m"

err()  { printf "  ${C_RED}✗ %s${C_RESET}\n" "$*" >&2; }
info() { printf "  ${C_GREEN}✓ %s${C_RESET}\n" "$*"; }
warn() { printf "  ${C_YELLOW}! %s${C_RESET}\n" "$*"; }

# Braille Spinner for animated feedback
spin_chars=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
run_with_spinner() {
  local msg="$1"
  shift
  local log_tmp
  log_tmp=$(mktemp -t awake.log.XXXXXX)

  # Fallback for non-interactive / non-tty environments
  if [ ! -t 1 ]; then
    printf "  %s..." "$msg"
    if "$@" > "$log_tmp" 2>&1; then
      printf " ${C_GREEN}✓${C_RESET}\n"
      rm -f "$log_tmp"
      return 0
    else
      printf " ${C_RED}✗${C_RESET}\n"
      cat "$log_tmp" >&2
      rm -f "$log_tmp"
      return 1
    fi
  fi

  "$@" > "$log_tmp" 2>&1 &
  local pid=$!
  local i=0

  printf '\033[?25l' # hide cursor
  while kill -0 "$pid" 2>/dev/null; do
    local char="${spin_chars[$(( i % 10 ))]}"
    printf "\r  ${C_CYAN}%s${C_RESET} %s" "$char" "$msg"
    sleep 0.08
    i=$(( i + 1 ))
  done
  wait "$pid"
  local exit_code=$?
  printf '\033[?25h' # restore cursor

  if [ "$exit_code" -eq 0 ]; then
    printf "\r  ${C_GREEN}✓${C_RESET} %s\033[K\n" "$msg"
    rm -f "$log_tmp"
    return 0
  else
    printf "\r  ${C_RED}✗${C_RESET} %s\033[K\n" "$msg"
    if [ -s "$log_tmp" ]; then
      cat "$log_tmp" >&2
    fi
    rm -f "$log_tmp"
    return "$exit_code"
  fi
}

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
printf "  ${C_DIM}MacAwake v1.1.0 • Lid-closed sleep manager for macOS${C_RESET}\n\n"

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

  download_core() {
    curl -fsSL "$REPO_RAW/awake" -o "$TMP"
    head -1 "$TMP" | grep -q '^#!/bin/bash' || return 1
  }

  run_with_spinner "Downloading MacAwake core from GitHub..." download_core || {
    err "Failed to download core package. Please check your internet connection."
    exit 1
  }
  SOURCE_SCRIPT="$TMP"
fi
echo

# ---- Step 3: Admin Authentication & LaunchDaemon Setup ----
printf "  ${C_BOLD}[3/4] 🔐 Installing LaunchDaemon root service...${C_RESET}\n"

# Authenticate upfront if sudo session is not already cached
if ! sudo -n true 2>/dev/null; then
  printf "  ${C_YELLOW}┌─────────────────────────────────────────────────────────────┐${C_RESET}\n"
  printf "  ${C_YELLOW}│${C_RESET}  ${C_BOLD}🔑 Administrator authentication required (ONCE ONLY)${C_RESET}        ${C_YELLOW}│${C_RESET}\n"
  printf "  ${C_YELLOW}│${C_RESET}  ${C_DIM}MacAwake needs admin once to install its background daemon.${C_RESET} ${C_YELLOW}│${C_RESET}\n"
  printf "  ${C_YELLOW}│${C_RESET}  ${C_DIM}You will NEVER need admin or a password for daily use.${C_RESET}       ${C_YELLOW}│${C_RESET}\n"
  printf "  ${C_YELLOW}└─────────────────────────────────────────────────────────────┘${C_RESET}\n\n"
  sudo -v || { err "Authentication failed."; exit 1; }
  echo
fi

install_daemon() {
  sudo bash "$SOURCE_SCRIPT" --install "$TARGET_USER" --quiet
}

run_with_spinner "Registering LaunchDaemon & setting permissions..." install_daemon || {
  err "Installation failed during LaunchDaemon setup."
  exit 1
}
echo

# ---- Step 4: Verification & Readiness ----
printf "  ${C_BOLD}[4/4] ⚡ Verifying service & initializing power state...${C_RESET}\n"

verify_setup() {
  # 1. Binary is installed and executable
  [ -x "/usr/local/bin/awake" ] || return 1
  # 2. Daemon is registered in launchd
  if command -v launchctl >/dev/null 2>&1; then
    launchctl list 2>/dev/null | grep -q "com.awake.guard" || return 1
  fi
  # 3. Application Support directory exists
  [ -d "/Library/Application Support/awake" ] || return 1
  return 0
}

run_with_spinner "Verifying background service and configuration..." verify_setup || {
  warn "Service registered, but background check took longer than expected."
}
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
