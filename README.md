# MacAwake ☕️

> Keep your MacBook awake — **even with the lid closed** — then restore sleep normally again.

Standard tools like `caffeinate` cannot block lid-close sleep: when the lid closes, macOS triggers a hardware clamshell sleep that power assertions and caffeinate can't override. The only mechanism that keeps a MacBook running headless with the lid closed is the system-level flag `pmset -a disablesleep 1`.

However, `disablesleep` requires root privileges and, left enabled, prevents your Mac from sleeping forever. **MacAwake** wraps that flag safely and elegantly:
- Turns insomnia on when requested, and **always guarantees normal sleep is restored** (on timers, on Ctrl+C, when commands finish, or if force-killed).
- Features a real-time **Trading Terminal TUI** with live countdown tickers, power metrics, and fast single-key hotkeys.
- Built specifically for **MDM-managed Macs** that grant admin for only a few minutes: admin is needed **once at install**, and never again.
- **Multi-session safe**: Multiple terminal tabs can run `awake` concurrently without clobbering each other.
- **Battery & Thermal Protection**: Automatically restores sleep if battery drops below **30%** (user customizable), and lets you sleep the display to prevent closed-lid heat buildup.

---

## 🖥 Trading Terminal Mode

Run `awake` without arguments in any terminal (or with `awake -t 2h`) to launch the live **Trading Terminal Dashboard**:

```text
╔══════════════════════════════════════════════════════════════════════════════╗
║  MACAWAKE TRADING TERMINAL  v1.1.0                     ● LIVE  [LID SAFE]    ║
╚══════════════════════════════════════════════════════════════════════════════╝

  [SYSTEM TICKER]
  STATUS  : ● SLEEP DISABLED (Mac stays awake even with lid closed)
  POWER   : ⚡ AC Connected (52%, charging)  │ BATT GUARD : ACTIVE (<=30%)
  SESSION : PID 48291 (TITANHACKY)            │ DAEMON     : ACTIVE (launchd)

  [COUNTDOWN TICKER]
  REMAINING : 01h 45m 30s                  TARGET   : 11:30:15
  PROGRESS  : [██████████████░░░░░░░░]  68%  (00h 47m 45s elapsed)

  [STATUS LOG]
  FEED > Sleep prevention active. Lid closed is OK.

────────────────────────────────────────────────────────────────────────────────
  HOTKEYS:
   [+] / [e] +15m       [-] -15m          [t] Set Duration     [p] Pause/Resume
   [d] Sleep Display   [b] Battery Guard  [r] Run Command      [?] Help Overlay
   [q] Exit / Restore Sleep
────────────────────────────────────────────────────────────────────────────────
```

### Fast Hotkey Commands (Trading Terminal)
| Key | Action | Description |
| :--- | :--- | :--- |
| `[+]` or `[e]` | **Extend Timer** | Instantly adds +15 minutes to the active session |
| `[-]` | **Shorten Timer** | Reduces timer by -15 minutes |
| `[t]` | **Set Duration** | Prompt to change target time (e.g. `45m`, `2h`, `1h30m`, `inf`) |
| `[p]` or `[space]` | **Pause / Resume** | Temporarily restore normal sleep or re-engage awake lock |
| `[d]` | **Sleep Display** | Turns off screen backlight immediately (runs cool with lid closed) |
| `[b]` | **Battery Guard** | Set cutoff percentage or toggle guard on/off (defaults to **30%**) |
| `[r]` | **Run Command** | Execute a shell command interactively while holding awake lock |
| `[?]` or `[h]` | **Cheat Sheet** | Toggles interactive manual and hotkey overlay |
| `[q]` | **Quit** | Gracefully restores sleep and cleans up session |

---

## ⚡️ Quick Install

Run this command in Terminal (admin password needed **once**):

```bash
/bin/bash -c "$(curl --connect-timeout 2 -fsSL https://raw.githubusercontent.com/TITANHACKY/macawake/main/install.sh)"
```

Or piped via curl:
```bash
curl --connect-timeout 2 -fsSL https://raw.githubusercontent.com/TITANHACKY/macawake/main/install.sh | bash
```

Or clone and install locally:

```bash
git clone https://github.com/TITANHACKY/macawake.git
cd macawake
bash install.sh
```

---

## 🚀 CLI Usage

```bash
# Launch interactive Trading Terminal
awake

# Stay awake for a specific duration with live countdown ticker
awake -t 2h
awake -t 90m
awake -t 45           # Plain number means minutes
awake -t 1h30m

# Stay awake while a command runs in background, then restore sleep
awake python train.py
awake -t 3h make build

# Battery Guard Preferences (defaults to 30%)
awake -b              # View current battery cutoff preference
awake -b 25           # Set cutoff to 25% (auto-sleeps when battery <= 25%)
awake -b off          # Disable battery cutoff guard

# Diagnostics & Status
awake --status        # Show sleep state, power source, and active sessions
awake doctor          # Comprehensive health check of LaunchDaemon & permissions
awake --help          # Full CLI manual & options
awake --version       # Show version

# Restore normal sleep immediately
awake --off
```

### Time Formats
Supports flexible formats: `45` (minutes), `30s` (seconds), `15m` (minutes), `2h` (hours), `1h30m` (combined).

---

## 🛡 How It Works & Why It's MDM-Safe

Disabling lid-close sleep requires root (`pmset -a disablesleep 1`). On MDM-managed company Macs, admin rights are typically granted for only 5–15 minutes, making regular `sudo` commands unusable for daily tasks, while `/etc/sudoers` modifications are actively reverted by MDM profiles.

MacAwake solves this permanently:
1. **Zero Admin After Install**: The installer creates a lightweight LaunchDaemon (`com.awake.guard`) running as root in the background.
2. **Unprivileged Multi-Session IPC**: Daily use only creates unprivileged session files in `/Library/Application Support/awake/sessions/`. The root daemon monitors these files and manages `pmset`.
3. **Anti-Spoofing Security**: The daemon validates that the PID in the request belongs to the user who registered it.
4. **Crash-Proof Safety Net**: The LaunchDaemon checks every ~15 seconds and on session change:
   - Is the session's owning process still alive? If not &rarr; restore normal sleep.
   - Has the timer expired? If so &rarr; restore normal sleep.
   - Is the MacBook on battery with less than the cutoff threshold (default **30%**, user customizable)? If so &rarr; restore normal sleep.
   - Did the user close Terminal or force-quit (`kill -9`)? The daemon cleans up within 15 seconds.

---

## 📁 Installed Files

| Path | Description |
| :--- | :--- |
| `/usr/local/bin/awake` | The `awake` CLI tool |
| `/usr/local/libexec/awake-guard` | Root background daemon executed by `launchd` |
| `/Library/LaunchDaemons/com.awake.guard.plist` | LaunchDaemon definition loaded at boot |
| `/Library/Application Support/awake/sessions/` | Multi-session locks directory |
| `/Library/Application Support/awake/config` | User preference configuration (battery cutoff, etc.) |
| `/Library/Application Support/awake/request` | Backward-compatible IPC request file |

---

## 🩺 Diagnostic Tool (`awake doctor`)

You can run `awake doctor` at any time to verify your system setup:

```bash
$ awake doctor
=== MacAwake Doctor Diagnostics ===
  [✓] OS: macOS 27.0.1 (arm64)
  [✓] LaunchDaemon plist: Found at /Library/LaunchDaemons/com.awake.guard.plist
  [✓] LaunchDaemon service: com.awake.guard is active
  [✓] Guard script: Found and executable at /usr/local/libexec/awake-guard
  [✓] App Support directory: Found at /Library/Application Support/awake
  [✓] Request file: Writable by TITANHACKY
  [✓] Sessions directory: Writable by TITANHACKY
  [✓] Config file: Found at /Library/Application Support/awake/config (Battery guard: 30%, enabled: 1)
  [✓] Power Status: ⚡ AC Power (60%, charging)
  [i] pmset status: SleepDisabled=0 (Normal sleep)
===================================
```

---

## 🗑 Uninstallation

To remove MacAwake and its LaunchDaemon completely:

```bash
sudo awake --uninstall
```

---

## ⚠️ Thermal & Battery Safety Notice

- **Laptop in a Bag**: Never place a running laptop with its lid closed into an unventilated backpack or sleeve. It can overheat and damage hardware. Always stop `awake` or put your Mac to sleep before packing it.
- **Low Battery Safeguard**: MacAwake defaults to an auto-cutoff at **30% battery** (customizable via `awake -b <N>` or in the Trading Terminal). If battery charge falls below this threshold, sleep is automatically restored to preserve battery health.
- **Display Dimming**: Press `[d]` in the Trading Terminal to sleep the screen backlight while keeping background computation active.

---

## 📄 License

MIT — see [LICENSE](LICENSE).