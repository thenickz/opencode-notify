#!/usr/bin/env bash
# validate.sh — syntax + structure checks for the opencode-notify repo.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

check() {
  local label="$1" cmd="$2"
  if eval "$cmd"; then
    echo "ok  $label"
  else
    echo "FAIL  $label"
    FAIL=1
  fi
}

echo "## Plugin (node syntax)"
check "plugins/opencode-notify.js" "node --check '$REPO_DIR/plugins/opencode-notify.js'"

echo "## Dispatcher (bash syntax)"
check "scripts/notify.sh" "bash -n '$REPO_DIR/scripts/notify.sh'"
check "install.sh" "bash -n '$REPO_DIR/install.sh'"
check "scripts/validate.sh" "bash -n '$REPO_DIR/scripts/validate.sh'"

echo "## Skill (frontmatter)"
SKILL="$REPO_DIR/skills/notify/SKILL.md"
check "skills/notify/SKILL.md exists" "[[ -f '$SKILL' ]]"
check "frontmatter name: notify" "grep -q '^name: notify$' '$SKILL'"
check "frontmatter description" "grep -q '^description:' '$SKILL'"

echo "## Installer (dry run in isolated HOME)"
TMP_HOME="$(mktemp -d)"
if HOME="$TMP_HOME" "$REPO_DIR/install.sh" --dry-run >/dev/null 2>&1; then
  echo "ok  install.sh --dry-run"
else
  echo "FAIL  install.sh --dry-run"
  FAIL=1
fi
rm -rf "$TMP_HOME"

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "all checks passed"
else
  echo "some checks FAILED" >&2
  exit 1
fi
