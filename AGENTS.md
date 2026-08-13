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
- Keep `README.md`, `skills/notify/SKILL.md`, and this file in sync when behavior
  or config changes.
- The plugin resolves `notify.sh` from `$HOME/.config/opencode/notify.sh` first,
  then `../scripts/notify.sh` relative to the plugin's realpath — keep that fallback.
- Never store tokens in docs or logs; env vars only.

## Structure
```
plugins/opencode-notify.js   opencode plugin (events → notify)
scripts/notify.sh            OS dispatcher (auto-detect platform)
skills/notify/SKILL.md       portable skill (setup + config + self-diagnosis)
install.sh                   symlink installer (non-destructive, --dry-run/--unlink)
scripts/validate.sh          syntax + frontmatter checks
```

## Boundaries
- `install.sh` never overwrites existing config (skips with a warning).
- OS channel is silent by default; failures only print with `OPENCODE_NOTIFY_DEBUG=1`.
