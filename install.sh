#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$REPO_DIR/plugins/opencode-notify.js"
NOTIFY_SRC="$REPO_DIR/scripts/notify.sh"
SKILL_SRC="$REPO_DIR/skills/notify"

OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"
NOTIFY_DEST="$HOME/.config/opencode/notify.sh"
ENV_DEST="$HOME/.config/opencode/opencode-notify.env"
SKILL_DEST_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.config/opencode/skills"
)

read -r -d '' ENV_TEMPLATE <<'EOF' || true
# opencode-notify configuration
# The plugin reads this file at startup. Values here take precedence over the
# environment, so changes apply even when opencode was launched from a shell
# whose environment predates the edit (stale parent shell problem).
#
# Format: one KEY=value per line. Lines starting with '#' are ignored. An
# optional 'export ' prefix and surrounding single/double quotes are allowed.
# No inline comments. Missing lines fall back to environment variables.
#
# Keep this file private (chmod 600): it may hold your Telegram bot token.
#
# OPENCODE_NOTIFY_DISABLED=0
# OPENCODE_NOTIFY_OS=auto
# OPENCODE_NOTIFY_ON_DONE=1
# OPENCODE_NOTIFY_ON_PERMISSION=1
# OPENCODE_NOTIFY_ON_QUESTION=1
# OPENCODE_NOTIFY_DEBUG=0
# OPENCODE_TELEGRAM_BOT_TOKEN=
# OPENCODE_TELEGRAM_CHAT_ID=
# OPENCODE_TELEGRAM_ON_DONE=1
# OPENCODE_TELEGRAM_ON_PERMISSION=1
# OPENCODE_TELEGRAM_ON_QUESTION=1
EOF

DRY=false
UNLINK=false

usage() {
  cat <<'EOF'
Installs the opencode-notify plugin, the OS notification dispatcher, and the
"notify" skill as symlinks in the tools' global paths.

Usage: ./install.sh [--dry-run] [--unlink]

Paths (created if missing):
  ~/.config/opencode/plugins/opencode-notify.js   the opencode plugin
  ~/.config/opencode/notify.sh                    OS notification dispatcher
  ~/.config/opencode/opencode-notify.env          config template (commented)
  ~/.claude/skills/notify                         skill (Claude Code + opencode)
  ~/.agents/skills/notify                         skill (Codex + opencode)
  ~/.config/opencode/skills/notify                skill (opencode native path)

Options:
  --dry-run  show what it would do without changing anything
  --unlink   remove the created symlinks (does not touch the repo or the env file)

Non-destructive: never overwrites an existing dir/file that is not a symlink
to this repo; in those cases it skips with a warning.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=true ;;
    --unlink) UNLINK=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [[ ! -f "$PLUGIN_SRC" ]]; then
  echo "Error: plugin not found at $PLUGIN_SRC" >&2
  exit 1
fi

link_one() {
  local src="$1" dest="$2"

  if [[ "$UNLINK" == true ]]; then
    if [[ -L "$dest" ]]; then
      echo "  remove $dest"
      if [[ "$DRY" == false ]]; then
        rm "$dest"
      fi
    else
      echo "  skip $dest (not a symlink)"
    fi
    return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      echo "  ok $dest (already linked)"
    else
      echo "  SKIP $dest (exists and is not a symlink to this repo)"
    fi
    return
  fi

  echo "  link $dest"
  if [[ "$DRY" == false ]]; then
    ln -s "$src" "$dest"
  fi
}

if [[ "$DRY" == true ]]; then
  echo "## DRY RUN — nothing will be changed"
fi

if [[ "$UNLINK" == false && "$DRY" == false ]]; then
  mkdir -p "$OPENCODE_PLUGIN_DIR"
  for dir in "${SKILL_DEST_DIRS[@]}"; do
    mkdir -p "$dir"
  done
fi

echo "## Plugin"
link_one "$PLUGIN_SRC" "$OPENCODE_PLUGIN_DIR/opencode-notify.js"

echo "## Notification dispatcher"
if [[ -f "$NOTIFY_SRC" ]]; then
  link_one "$NOTIFY_SRC" "$NOTIFY_DEST"
else
  echo "skip notify.sh (missing $NOTIFY_SRC)"
fi

echo "## Config file"
if [[ "$UNLINK" == true ]]; then
  echo "  keep $ENV_DEST (user config, not a symlink)"
elif [[ -f "$ENV_DEST" ]]; then
  echo "  ok $ENV_DEST (exists)"
else
  echo "  create $ENV_DEST"
  if [[ "$DRY" == false ]]; then
    printf '%s\n' "$ENV_TEMPLATE" > "$ENV_DEST"
    chmod 600 "$ENV_DEST"
  fi
fi

echo "## Skill"
if [[ -d "$SKILL_SRC" ]]; then
  for dir in "${SKILL_DEST_DIRS[@]}"; do
    link_one "$SKILL_SRC" "$dir/notify"
  done
else
  echo "skip skill (missing $SKILL_SRC)"
fi

echo "done."
