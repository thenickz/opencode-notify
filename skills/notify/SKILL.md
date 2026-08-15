---
name: notify
description: Sets up, configures, and troubleshoots opencode notifications — Telegram bot and OS desktop notifications (WSL/Windows/Linux/macOS). Use when the user wants to be notified when opencode asks a question, asks for permission, or finishes a response; when setting up a Telegram bot (BotFather token, chat id); when configuring the opencode-notify plugin env vars; when the user asks to turn notifications off, enable or disable Telegram or OS notifications, or change a notification event (response finished / permission / question); when notifications are not arriving.
---

# notify — opencode notifications (OS + Telegram)

The **opencode-notify** plugin (installed by `install.sh`) sends a notification on
three kinds of events:

| Event | Notification |
|---|---|
| `session.idle` (root session) | "response finished" |
| `permission.asked` | "asking permission" |
| `question` tool invoked (`tool.execute.before`) | "question" (sent when asked, before the user answers) |

Two channels, each independently togglable:
- **OS desktop** — dispatched by `scripts/notify.sh`, auto-detects the platform
  (WSL → Windows toast, macOS → osascript, Linux → notify-send, Windows → BurntToast).
- **Telegram** — optional; only active when a bot token + chat id are configured.

Repo: <https://github.com/thenickz/opencode-notify>

## 1. Install (first time)

```bash
git clone https://github.com/thenickz/opencode-notify.git ~/.opencode-notify
~/.opencode-notify/install.sh
```

This symlinks the plugin into `~/.config/opencode/plugins/`, the dispatcher into
`~/.config/opencode/notify.sh`, the skill into the tools' skill paths, and
creates a commented config template at
`~/.config/opencode/opencode-notify.env` (only if the file does not exist).
**Restart opencode** afterwards — plugins load at startup.

## 2. Check current state

```bash
ls -l ~/.config/opencode/plugins/opencode-notify.js ~/.config/opencode/notify.sh 2>&1
env | grep -E '^OPENCODE_(NOTIFY|TELEGRAM)' || echo "no OPENCODE_NOTIFY/TELEGRAM env vars set"
```

If the plugin/script symlinks are missing, re-run `~/.opencode-notify/install.sh`.

## 3. Set up Telegram (guided)

1. **Create a bot** with [@BotFather](https://t.me/botfather): send `/newbot`, pick a
   name and a username ending in `bot`. Copy the token (`123456789:AA...`).
2. **Start the chat**: open the bot and press Start (send `/start`). A bot cannot
   message you until you do this.
3. **Get your chat id**: open in a browser, replacing `<BOT_TOKEN>`:

   ```
   https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
   ```

   Look for `"message": { "chat": { "id": <your-id> } }`. Group chats use a
   negative id. If empty, send another message to the bot and refresh.
4. **Smoke test** (from any shell):

   ```bash
   curl -sS -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
     -d "chat_id=<CHAT_ID>" --data-urlencode "text=opencode notify smoke test"
   ```

   No message in the chat? Fix token/chat id before continuing.
5. **Persist the config** (recommended: the plugin's env file — survives stale
   shells, no `source` needed):

   ```bash
   tee -a ~/.config/opencode/opencode-notify.env >/dev/null <<'EOF'
   OPENCODE_TELEGRAM_BOT_TOKEN="<BOT_TOKEN>"
   OPENCODE_TELEGRAM_CHAT_ID="<CHAT_ID>"
   EOF
   chmod 600 ~/.config/opencode/opencode-notify.env
   ```

   (Alternative, legacy: add the two `export ...` lines to `~/.bashrc` and
   `source ~/.bashrc`.)

   Never commit the token; never store it in `memory.md` or `AGENTS.md`.
6. **Restart opencode** so the plugin picks up the new environment.

## 4. Set up OS notifications on WSL (optional, recommended)

On WSL the Linux `notify-send` does not surface on Windows. The dispatcher prefers
PowerShell + **BurntToast** (it fails loudly when a toast cannot be created), then
`wsl-notify-send.exe`, then `notify-send`.

1. Install the BurntToast module (per-user, no admin):
   `powershell.exe -NoProfile -NonInteractive -Command "Install-Module -Name BurntToast -Scope CurrentUser -Force -AllowClobber"`
2. (Alternative) `wsl-notify-send.exe` from
   <https://github.com/stuartleeks/wsl-notify-send/releases>, placed somewhere in
   the Windows `PATH`. Caveat: it exits 0 even when Windows silently drops the
   toast (missing Start Menu shortcut for its app id) — BurntToast is more reliable.
3. Test:

   ```bash
   OPENCODE_NOTIFY_DEBUG=1 ~/.config/opencode/notify.sh "opencode" "OS toast test" done
   ```

   You should see a Windows toast. If no channel is available, the dispatcher
   prints the failure only with `OPENCODE_NOTIFY_DEBUG=1`.

## 5. Configuration

Config comes from two sources, merged at plugin load — the **config file wins**
over the environment:

- **Config file (canonical):** `~/.config/opencode/opencode-notify.env` — one
  `KEY=value` per line, `#` comments, optional `export ` prefix and surrounding
  single/double quotes allowed; no inline comments. `install.sh` creates a
  commented template if the file is missing. Because the plugin reads the file
  directly, edits apply even when opencode was launched from a shell whose
  environment predates the change — no `source ~/.bashrc` or new terminal
  needed. Keep it private (`chmod 600`; it may hold the Telegram token).
- **Environment variables:** any `OPENCODE_*` var in the shell (e.g. from
  `~/.bashrc`) — used as a fallback for keys not present in the file.

Every event toggle defaults to on — see the request→change map below.

| Var | Meaning |
|---|---|
| `OPENCODE_NOTIFY_DISABLED=1` | master switch (disables both channels) |
| `OPENCODE_NOTIFY_OS=auto` | `auto` \| `darwin` \| `linux` \| `wsl` \| `windows` \| `none` |
| `OPENCODE_NOTIFY_ON_DONE` / `_ON_PERMISSION` / `_ON_QUESTION=0` | disable an OS event |
| `OPENCODE_NOTIFY_DEBUG=1` | print dispatcher errors |
| `OPENCODE_TELEGRAM_BOT_TOKEN` | enables Telegram |
| `OPENCODE_TELEGRAM_CHAT_ID` | target chat |
| `OPENCODE_TELEGRAM_ON_DONE` / `_ON_PERMISSION` / `_ON_QUESTION=0` | disable a Telegram event |

### Changing config when the user asks

When the user asks to turn notifications on/off, enable or disable a channel, or
change an event, apply the request with this procedure:

1. Find the current values: `grep -n OPENCODE ~/.config/opencode/opencode-notify.env`
   (if the file is missing, create it: re-run `install.sh` or copy the template
   from the repo).
2. Edit/add the matching `OPENCODE_*` line(s) in that file. A key present in the
   file overrides the environment — remove the line to fall back to the env.
3. Tell the user to **restart opencode** so the plugin re-reads the file (no
   `source` needed).

> If the user has an existing `~/.bashrc` setup (no env file yet), you may keep
> editing `~/.bashrc` — but prefer creating the env file so future edits do not
> depend on the launching shell. (See issue #1: stale parent shell.)

Request → change map (defaults = all events on, both channels):

| User asks | Change |
|---|---|
| "turn off notifications" | add `export OPENCODE_NOTIFY_DISABLED=1` |
| "turn notifications back on" | remove/comment that line |
| "only Telegram" | `export OPENCODE_NOTIFY_OS=none` |
| "turn OS back on" | set `OPENCODE_NOTIFY_OS=auto` (or delete the line) |
| "turn off Telegram" | comment out `OPENCODE_TELEGRAM_BOT_TOKEN` and `OPENCODE_TELEGRAM_CHAT_ID` (channel becomes inactive) |
| "turn Telegram back on" | uncomment / restore the two `OPENCODE_TELEGRAM_*` lines |
| "stop notifying when a response ends" | `OPENCODE_NOTIFY_ON_DONE=0` and/or `OPENCODE_TELEGRAM_ON_DONE=0` |
| "stop notifying on permission" | `OPENCODE_NOTIFY_ON_PERMISSION=0` and/or `OPENCODE_TELEGRAM_ON_PERMISSION=0` |
| "stop notifying on questions" | `OPENCODE_NOTIFY_ON_QUESTION=0` and/or `OPENCODE_TELEGRAM_ON_QUESTION=0` |
| "turn that event back on" | delete the `=0` (or set to `1`) |
| "send to another chat / user" | change `OPENCODE_TELEGRAM_CHAT_ID` |

Note: the plugin reads the config file (and snapshots env) at startup, so a
running opencode ignores edits until it restarts — always end with the restart
reminder.

## 6. Testing all three notifications

Restart opencode, then send this prompt in a session with the plugin loaded:

```
Test notifications: first ask me a question with the question tool, then request
permission to run a harmless command like `pwd` (set permission to ask for bash
if needed), then finish your response.
```

Expected, in order: OS/Telegram "question", "asking permission", then "response
finished". If a channel is quiet, follow the diagnosis in section 7.

Notes:
- "response finished" (`session.idle`) can fire twice for the same session in a
  few ms; the plugin dedupes duplicates within a 3s window.
- The "permission" event only fires when opencode actually asks for permission.
  If bash is auto-allowed (default in many setups), no permission.asked event is
  emitted — nothing to fix, it's expected silence.
- For tracing, run opencode with `OPENCODE_NOTIFY_DEBUG=1` (plugin writes
  `/tmp/opencode/notify-debug.log`); remove the var for normal use.

## 7. Troubleshooting (self-diagnosis)

Diagnose in this order. Stop at the first section that explains the symptom.

1. **Nothing arrives at all** — check in order:
   - `grep OPENCODE_NOTIFY_DISABLED ~/.config/opencode/opencode-notify.env` and
     `env | grep OPENCODE_NOTIFY_DISABLED` → neither must be `1`.
   - `ls -l ~/.config/opencode/plugins/opencode-notify.js` → must exist
     (re-run `~/.opencode-notify/install.sh` if missing).
   - The plugin reads config (file, then env) at startup — a terminal that
     predates an export change won't see it, but the env file works regardless.
     **Restart opencode** after any config edit.
2. **Telegram silent** — one of:
   - `/start` was never sent to the bot (mandatory first step).
   - Token and chat id swapped or mistyped.
   - The opencode process never received the env vars (add them to
     `~/.config/opencode/opencode-notify.env`, or export in the same shell that
     starts opencode / add to `~/.bashrc`).
   - Verify the channel independently: run the curl smoke test from section 3.
     If curl works but opencode doesn't, it's a config problem (previous bullet).
3. **OS silent** — run the dispatcher by hand to isolate the plugin:
   `OPENCODE_NOTIFY_DEBUG=1 ~/.config/opencode/notify.sh "opencode" "test" done`
   - WSL: install BurntToast (section 4). `wsl-notify-send.exe` may exit 0
     without showing a toast if its app id has no Start Menu shortcut.
   - Linux: install `notify-send` (package `libnotify-bin`/`libnotify`) and check
     there is a display (Wayland/x11 session).
   - If the manual run works but opencode is still quiet, the plugin did not load:
     check `ls -l` the plugin symlink and restart opencode.
4. **Plugin loads but still silent** — run opencode with
   `OPENCODE_NOTIFY_DEBUG=1`; the plugin appends a trace to
   `/tmp/opencode/notify-debug.log`. Look at the final lines: does it log
   `osNotify: kind=... enabled` / `tgNotify: kind=... sending`? If neither
   appears, the event never reached the plugin (dedupe? wrong session?).
5. **Only one channel missing** — that channel is off. Check the per-channel and
   per-event toggles in the table in section 5, and `OPENCODE_NOTIFY_OS`.
6. **Still broken after all of the above** — create an issue at
   <https://github.com/thenickz/opencode-notify/issues> with:
   - `opencode --version`
   - output of `env | grep '^OPENCODE_'`
   - the tail of `/tmp/opencode/notify-debug.log` (if any)
   - the OS/WSL distribution
