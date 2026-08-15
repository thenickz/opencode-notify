# opencode-notify

Notifications for opencode: OS desktop + optional Telegram on question, permission,
and response-finished events. Ships an opencode plugin, a cross-platform shell
dispatcher, and a portable Agent Skills `notify` skill.

## Stack
- Plugin: JavaScript (ESM, zero deps — Bun `fetch`, `$`, SDK client only).
- Dispatcher: Bash (`scripts/notify.sh`), no external deps beyond the OS's native
  notify tool (`notify-send`, `osascript`, PowerShell BurntToast).
- Skill: Agent Skills format (`skills/notify/SKILL.md`, `name` + `description` frontmatter).

## Commands
> EXACT and verified commands.
- Install (symlinks plugin + dispatcher + skill): `./install.sh`
- Preview: `./install.sh --dry-run`
- Remove symlinks: `./install.sh --unlink`
- Validate plugin syntax, dispatcher syntax, and skill frontmatter: `./scripts/validate.sh`
- OS dispatcher smoke test: `~/.config/opencode/notify.sh "opencode" "test" done`
- Live plugin trace: run opencode with `OPENCODE_NOTIFY_DEBUG=1`, log at `/tmp/opencode/notify-debug.log`

## Conventions
- Plugin env vars: `OPENCODE_NOTIFY_*` (OS/channel) and `OPENCODE_TELEGRAM_*`
  (Telegram). Every event toggle defaults to ON; `=0` disables.
- Config resolution at plugin load: `~/.config/opencode/opencode-notify.env`
  (canonical, wins) over `process.env` (shell/`~/.bashrc` fallback). The file
  is read directly, so edits apply even from a stale parent shell; a restart is
  still required. Missing/empty file ⇒ current (env-only) behavior.
- Config file format: one `KEY=value` per line, `#` comments, optional `export `
  prefix and surrounding quotes; no inline comments. `install.sh` creates a
  commented template if missing and keeps it `chmod 600`.
- Keep `README.md`, `skills/notify/SKILL.md`, and this file in sync when behavior
  or config changes.
- The plugin resolves `notify.sh` from `$HOME/.config/opencode/notify.sh` first,
  then `../scripts/notify.sh` relative to the plugin's realpath — keep that fallback.
- Never store tokens in docs or logs; keep them in env vars or the private
  `opencode-notify.env` (chmod 600) only.

## Structure
```
plugins/opencode-notify.js   opencode plugin (events → notify, env-file config)
scripts/notify.sh            OS dispatcher (auto-detect platform)
scripts/notify-env-test.mjs  unit tests for the plugin's config-file parser
skills/notify/SKILL.md       portable skill (setup + config + self-diagnosis)
install.sh                   symlink installer (non-destructive, --dry-run/--unlink)
scripts/validate.sh          syntax + parser + frontmatter checks
```

## Boundaries
- `install.sh` never overwrites existing config (skips with a warning).
- OS channel is silent by default; failures only print with `OPENCODE_NOTIFY_DEBUG=1`.
