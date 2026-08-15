<div align="center">

# opencode-notify

**Desktop + Telegram notifications for [opencode](https://opencode.ai)**

Never miss when your AI agent asks a question, requests permission, or finishes a response — even when you are looking away.

Works on **Linux · macOS · Windows · WSL**. Optionally forwards to **Telegram** so you get pings on your phone.

[Install](#quickstart) · [How it works](#how-it-works) · [Configuration](#configuration) · [Agent skills](#agent-skills-your-llm-fixes-it-for-you) · [Troubleshooting](#troubleshooting)

</div>

---

## What it does

`opencode-notify` is an [opencode](https://opencode.ai) plugin that turns long-running agent sessions into an async workflow. You start a task, walk away, and get notified exactly when your input is needed:

| Event | You get notified when |
|---|---|
| 💬 **Question** | opencode asks you something (before you answer) |
| 🔐 **Permission** | opencode requests permission to run a command |
| ✅ **Done** | opencode finishes a response |

## Features

- **3 events, 2 channels** — every event can be independently enabled/disabled per channel.
- **Native OS notifications** — auto-detects the platform: WSL → Windows toast (BurntToast), macOS → `osascript`, Linux → `notify-send`, Windows → BurntToast.
- **Telegram** — one-way alerts to your phone via the Bot API (optional).
- **Dedupe built in** — opencode can emit `session.idle` twice; the plugin collapses duplicates.
- **Zero dependencies** — the plugin uses only Bun + the opencode SDK. No npm install.
- **Non-destructive install** — symlinks only; never overwrites existing config.
- **Portable skill** — ships an [Agent Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) `SKILL.md` so any agent can set up, configure, and fix the notifications for you.

## Quickstart

```bash
git clone https://github.com/thenickz/opencode-notify.git ~/.opencode-notify
~/.opencode-notify/install.sh
```

Then **restart opencode** (plugins load at startup). That's it — OS notifications
work out of the box. Telegram requires a one-time setup (2 minutes):

1. Create a bot with [@BotFather](https://t.me/botfather) and copy the token.
2. Open the bot and press Start (`/start`).
3. Get your chat id: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
4. Add to `~/.config/opencode/opencode-notify.env` (created by `install.sh`),
   then restart opencode:

   ```bash
   echo 'OPENCODE_TELEGRAM_BOT_TOKEN="<BOT_TOKEN>"' >> ~/.config/opencode/opencode-notify.env
   echo 'OPENCODE_TELEGRAM_CHAT_ID="<CHAT_ID>"' >> ~/.config/opencode/opencode-notify.env
   chmod 600 ~/.config/opencode/opencode-notify.env
   ```

   (Alternatively, export both in `~/.bashrc`.)

Full guided walkthrough (including WSL) is in the bundled skill: `skills/notify/SKILL.md`.

## How it works

```
opencode events
  │  session.idle (root) ───────────────┐
  │  permission.asked ────────────────┐ │
  │  tool.execute.before (question) ─┐ │ │
  ▼                                  ▼ ▼ ▼
┌─────────────────────────────────────────────┐
│  plugins/opencode-notify.js                │
│  (filter + dedupe + per-event toggles)     │
└──────────────┬───────────────────┬─────────┘
               ▼                   ▼
      scripts/notify.sh      Telegram Bot API
      (OS dispatcher)        (sendMessage)
               │
      ┌────────┴────────┐
      ▼                 ▼
  desktop toast      phone push
```

- **OS channel** — `scripts/notify.sh` auto-detects the platform and picks the
  best native tool. Errors are silent by default (exit 0); set
  `OPENCODE_NOTIFY_DEBUG=1` to see them.
- **Telegram channel** — one `POST /sendMessage`, active only when a bot token +
  chat id are configured. It does not require Telegram to be installed on the
  machine running opencode.
- **Question events** are sent when the question is *asked*, so you get the
  notification the moment opencode needs you — not after you already answered.

## Installation details

`install.sh` creates symlinks (single source of truth, editable in the repo):

| Target | Purpose |
|---|---|
| `~/.config/opencode/plugins/opencode-notify.js` | the plugin (loaded at opencode startup) |
| `~/.config/opencode/notify.sh` | OS notification dispatcher |
| `~/.claude/skills/notify` | skill — Claude Code + opencode |
| `~/.agents/skills/notify` | skill — Codex + opencode |
| `~/.config/opencode/skills/notify` | skill — opencode native path |

```bash
./install.sh            # install
./install.sh --dry-run  # preview without changing anything
./install.sh --unlink   # remove the symlinks
```

## Configuration

Config comes from two sources, merged at plugin load — the **config file wins**
over the environment:

- **Config file (canonical):** `~/.config/opencode/opencode-notify.env` — one
  `KEY=value` per line, `#` comments, optional `export ` prefix and surrounding
  quotes allowed. `install.sh` creates a commented template if the file is
  missing. The plugin reads the file directly, so edits apply even when opencode
  was launched from a shell whose environment predates the change (stale parent
  shell — see [issue #1](https://github.com/thenickz/opencode-notify/issues/1)).
  Keep it private: `chmod 600` (it may hold the Telegram token).
- **Environment variables:** any `OPENCODE_*` var in the shell (e.g. from
  `~/.bashrc`) — fallback for keys not present in the file.

Every event toggle defaults to on:

| Var | Meaning |
|---|---|
| `OPENCODE_NOTIFY_DISABLED=1` | master switch (disables both channels) |
| `OPENCODE_NOTIFY_OS=auto` | `auto` \| `darwin` \| `linux` \| `wsl` \| `windows` \| `none` |
| `OPENCODE_NOTIFY_ON_DONE=0` | disable OS "response finished" |
| `OPENCODE_NOTIFY_ON_PERMISSION=0` | disable OS "asking permission" |
| `OPENCODE_NOTIFY_ON_QUESTION=0` | disable OS "question" |
| `OPENCODE_NOTIFY_DEBUG=1` | print dispatcher errors |
| `OPENCODE_TELEGRAM_BOT_TOKEN` | enables the Telegram channel |
| `OPENCODE_TELEGRAM_CHAT_ID` | target chat |
| `OPENCODE_TELEGRAM_ON_DONE=0` | disable Telegram "response finished" |
| `OPENCODE_TELEGRAM_ON_PERMISSION=0` | disable Telegram "asking permission" |
| `OPENCODE_TELEGRAM_ON_QUESTION=0` | disable Telegram "question" |

## Agent skills (your LLM fixes it for you)

This repo ships the `notify` skill in the open [Agent Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
format. Once installed, any agent — **opencode**, Claude Code, or Codex — can
load it on demand and:

- walk you through the Telegram setup (BotFather → token → chat id → smoke test),
- configure the plugin from a plain-language request ("turn off Telegram", "only
  notify me when a response ends"),
- **diagnose and fix** missing notifications on its own, following a step-by-step
  troubleshooting procedure (`SKILL.md` section 7).

So if notifications stop working, just tell your agent "notifications aren't
arriving" — it knows exactly how to check the plugin, the env vars, and the
platform dispatcher.

## Troubleshooting

Quick self-check when nothing arrives:

1. `grep OPENCODE_NOTIFY_DISABLED ~/.config/opencode/opencode-notify.env` and
   `env | grep OPENCODE_NOTIFY_DISABLED` → neither must be `1`.
2. `ls -l ~/.config/opencode/plugins/opencode-notify.js` → must exist (re-run `install.sh`).
3. Restart opencode after any config change — the plugin reads config at startup.
   The env file survives stale shells; `~/.bashrc` edits need a fresh shell.
4. `OPENCODE_NOTIFY_DEBUG=1` and watch `/tmp/opencode/notify-debug.log`.

The full decision tree is in the skill (`skills/notify/SKILL.md` section 7), and
your agent can walk it for you. Still stuck? Open an
[issue](https://github.com/thenickz/opencode-notify/issues).

## Requirements

- [opencode](https://opencode.ai) (the plugin is loaded at startup — no other runtime deps)
- Linux/macOS/WSL/Windows shell for the OS dispatcher (Bash)
- Telegram account (only for the Telegram channel)

## License

MIT — see [LICENSE](LICENSE).
