#!/usr/bin/env bash
# notify.sh — cross-platform OS notification dispatcher for opencode.
#
# Auto-detects the platform and sends a desktop notification:
#   WSL     -> PowerShell BurntToast (native Windows toast; fallback: wsl-notify-send.exe)
#   macOS   -> osascript (display notification)
#   Linux   -> notify-send
#   Windows -> PowerShell BurntToast
#
# Usage: notify.sh [title] [message] [kind]
#   kind: done | permission | question | info   (maps to urgency/icon where supported)
# Title/message are read from the env OPENCODE_NOTIFY_TITLE / OPENCODE_NOTIFY_MESSAGE
# when the positional args are empty (avoids shell quoting issues from plugins).
#
# Failures are silent (exit 0); set OPENCODE_NOTIFY_DEBUG=1 to see errors.
# Disable entirely with OPENCODE_NOTIFY_DISABLED=1.
# Force a channel with OPENCODE_NOTIFY_OS=auto|darwin|linux|wsl|windows|none.

set -uo pipefail

TITLE="${1:-${OPENCODE_NOTIFY_TITLE:-opencode}}"
MESSAGE="${2:-${OPENCODE_NOTIFY_MESSAGE:-}}"
KIND="${3:-info}"
FORCE="${OPENCODE_NOTIFY_OS:-auto}"

[[ -n "$MESSAGE" ]] || MESSAGE="$TITLE"

[[ "${OPENCODE_NOTIFY_DISABLED:-0}" == "1" ]] && exit 0
[[ "$FORCE" == "none" ]] && exit 0

debug() {
  [[ "${OPENCODE_NOTIFY_DEBUG:-0}" == "1" ]] && echo "notify: $*" >&2
}

is_wsl() {
  [[ -r /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null
}

is_macos() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]
}

is_windows() {
  [[ "${OS:-}" == "Windows_NT" ]] || [[ "$(uname -s 2>/dev/null)" == *"MSYS"* ]] || [[ "$(uname -s 2>/dev/null)" == *"MINGW"* ]] || [[ "$(uname -s 2>/dev/null)" == *"CYGWIN"* ]]
}

urgency() {
  case "$KIND" in
    permission|question) echo "critical" ;;
    done) echo "normal" ;;
    *) echo "normal" ;;
  esac
}

# --- WSL: forward to a native Windows toast ---
notify_wsl() {
  # Prefer PowerShell + BurntToast: it reports failure when a toast cannot be
  # created, unlike wsl-notify-send.exe which exits 0 even when Windows silently
  # drops the notification (missing Start Menu shortcut for its app id).
  if command -v powershell.exe >/dev/null 2>&1; then
    local esc esc_msg
    esc="${TITLE//\'/\'\'}"; esc="${esc//\"/\"}"
    esc_msg="${MESSAGE//\'/\'\'}"; esc_msg="${esc_msg//\"/\"}"
    # Only report success when BurntToast is actually installed and used.
    if powershell.exe -NoProfile -NonInteractive -Command \
      "if (Get-Module -ListAvailable -Name BurntToast) { New-BurntToastNotification -Text '$esc','$esc_msg'; exit 0 } else { exit 1 }" \
      >/dev/null 2>&1; then
      return 0
    fi
    debug "BurntToast not available, trying wsl-notify-send.exe"
  fi
  if command -v wsl-notify-send.exe >/dev/null 2>&1; then
    wsl-notify-send.exe --category "${WSL_DISTRO_NAME:-WSL}" "$TITLE" "$MESSAGE" 2>/dev/null && return 0
    debug "wsl-notify-send.exe failed, trying notify-send"
  fi
  # Last resort: Linux notify-send (e.g. WSL with an X server).
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a opencode -u "$(urgency)" "$TITLE" "$MESSAGE" 2>/dev/null && return 0
  fi
  debug "no channel available for WSL"
  return 0
}

# --- macOS: AppleScript notification ---
notify_macos() {
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "on run argv" \
      -e "display notification (item 2 of argv) with title (item 1 of argv)" \
      -e "end run" "$TITLE" "$MESSAGE" >/dev/null 2>&1 && return 0
  fi
  debug "osascript failed"
  return 0
}

# --- Linux: notify-send (libnotify) ---
notify_linux() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a opencode -u "$(urgency)" -t 10000 "$TITLE" "$MESSAGE" 2>/dev/null && return 0
    debug "notify-send failed (no display?)"
    return 0
  fi
  debug "notify-send not installed"
  return 0
}

# --- Windows (native): PowerShell BurntToast ---
notify_windows() {
  if command -v powershell.exe >/dev/null 2>&1; then
    local esc esc_msg
    esc="${TITLE//\'/\'\'}"; esc="${esc//\"/\"}"
    esc_msg="${MESSAGE//\'/\'\'}"; esc_msg="${esc_msg//\"/\"}"
    # Only report success when BurntToast is actually installed and used.
    if powershell.exe -NoProfile -NonInteractive -Command \
      "if (Get-Module -ListAvailable -Name BurntToast) { New-BurntToastNotification -Text '$esc','$esc_msg'; exit 0 } else { exit 1 }" \
      >/dev/null 2>&1; then
      return 0
    fi
    debug "BurntToast not available in Windows PowerShell"
  fi
  debug "PowerShell/BurntToast unavailable"
  return 0
}

case "$FORCE" in
  wsl) notify_wsl ;;
  darwin) notify_macos ;;
  linux) notify_linux ;;
  windows) notify_windows ;;
  auto)
    if is_wsl; then
      notify_wsl
    elif is_macos; then
      notify_macos
    elif is_windows; then
      notify_windows
    else
      notify_linux
    fi
    ;;
esac

exit 0
