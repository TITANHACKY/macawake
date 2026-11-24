#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || {
    printf 'Expected output to contain: %s\n%s\n' "$needle" "$haystack" >&2
    exit 1
  }
}

bash -n "$ROOT_DIR/awake"

FAKE_PMSET="$TMP_DIR/pmset"
printf '#!/bin/bash\nif [ "$1" = "-g" ] && [ "${2:-}" = "batt" ]; then\n  printf "Now drawing from '\''AC Power'\''\\n -InternalBattery-0 (id=1)\t100; charged; 0:00 remaining present: true\\n"\nelif [ "$1" = "-g" ]; then\n  printf " SleepDisabled 1\\n"\nfi\n' > "$FAKE_PMSET"
chmod 755 "$FAKE_PMSET"

TEST_ROOT="$TMP_DIR/root"
STATUS_ROOT="$TEST_ROOT/Library/Application Support/awake/status"
mkdir -p "$STATUS_ROOT"
NOW=$(date +%s)
printf 'timestamp=%s\npid=123\ndesired=1\nsleep_disabled=1\nsessions=2\nreason=active\npmset_error=0\n' "$NOW" > "$STATUS_ROOT/$UID"

status_output=$(AWAKE_TEST_ROOT="$TEST_ROOT" AWAKE_PMSET="$FAKE_PMSET" "$ROOT_DIR/awake" --status)
assert_contains "$status_output" "Daemon Health    : HEALTHY"
assert_contains "$status_output" "Daemon Heartbeat"

SESSION_DIR="$TEST_ROOT/Library/Application Support/awake/sessions/$UID"
mkdir -p "$SESSION_DIR"
printf 'state=on pid=111 uid=%s until=0 started=%s\n' "$UID" "$NOW" > "$SESSION_DIR/111.session"
printf 'state=on pid=222 uid=%s until=0 started=%s\n' "$UID" "$NOW" > "$SESSION_DIR/222.session"
AWAKE_TEST_ROOT="$TEST_ROOT" AWAKE_PMSET="$FAKE_PMSET" "$ROOT_DIR/awake" --off 111 >/dev/null
[ ! -e "$SESSION_DIR/111.session" ]
[ -e "$SESSION_DIR/222.session" ]

echo "awake tests passed"
