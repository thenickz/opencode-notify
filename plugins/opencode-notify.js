// opencode-notify.js — OS + Telegram notifications for opencode.
//
// Notifies the user on two kinds of events (configurable per event and per
// channel via env vars):
//   - "question / asking permission": the question tool is invoked, or a
//     permission.asked event fires.
//   - "response finished": session.idle on a root session.
//
// Channels:
//   - OS notifications via scripts/notify.sh (auto-detects WSL/Windows/Linux/macOS).
//   - Telegram via the Bot API sendMessage (optional, only if a bot token and
//     chat id are configured).
//
// No external dependencies: uses only process.env, Bun's fetch, Bun's $, and
// the SDK client provided in the plugin context.
//
// Env vars (all optional; every toggle defaults to on):
//   OPENCODE_NOTIFY_DISABLED=1             master switch
//   OPENCODE_NOTIFY_SCRIPT=<path>          override the notify.sh location
//   OPENCODE_NOTIFY_ON_DONE=0              disable "response finished"
//   OPENCODE_NOTIFY_ON_PERMISSION=0        disable "asking permission"
//   OPENCODE_NOTIFY_ON_QUESTION=0          disable "question"
//   OPENCODE_NOTIFY_OS=auto                auto|darwin|linux|wsl|windows|none
//   OPENCODE_TELEGRAM_BOT_TOKEN=...        enables the Telegram channel
//   OPENCODE_TELEGRAM_CHAT_ID=...          target chat (requires bot token)
//   OPENCODE_TELEGRAM_ON_DONE=0            per-event Telegram toggles
//   OPENCODE_TELEGRAM_ON_PERMISSION=0
//   OPENCODE_TELEGRAM_ON_QUESTION=0

import { realpathSync, appendFileSync, mkdirSync } from "node:fs"

export const OpenCodeNotify = async ({ client, $, directory }) => {
  const env = (key, fallback) => {
    const value = process.env[key]
    return value === undefined || value === "" ? fallback : value
  }
  const enabled = (key) => env(key, "1") !== "0"

  const osChannel = env("OPENCODE_NOTIFY_OS", "auto")
  const tgToken = env("OPENCODE_TELEGRAM_BOT_TOKEN", "")
  const tgChatID = env("OPENCODE_TELEGRAM_CHAT_ID", "")
  const tgEnabled = tgToken !== "" && tgChatID !== ""
  const masterDisabled = env("OPENCODE_NOTIFY_DISABLED", "0") === "1"

  // Root sessions only: subagents have a parentID set at creation.
  const subagents = new Set()
  // session.idle can fire twice for the same root session within a few ms;
  // dedupe per session within a short window.
  const lastIdleAt = new Map()
  const IDLE_DEDUPE_MS = 3000

  // Resolve the notify.sh dispatcher.
  let notifyScript = env("OPENCODE_NOTIFY_SCRIPT", "")
  if (!notifyScript) {
    const home = env("HOME", "")
    const candidates = []
    if (home) candidates.push(`${home}/.config/opencode/notify.sh`)
    try {
      const here = realpathSync(import.meta.dir)
      candidates.push(`${here}/../scripts/notify.sh`)
    } catch {
      /* ignore */
    }
    notifyScript = candidates.find((path) => Bun.file(path).exists()) ?? ""
  }
  const haveOS = notifyScript !== "" && osChannel !== "none" && !masterDisabled

  const log = (level, message) => {
    client
      ?.app?.log?.({ body: { service: "opencode-notify", level, message } })
      .catch(() => {})
  }

  const debug = env("OPENCODE_NOTIFY_DEBUG", "0") === "1"
  const debugFile = "/tmp/opencode/notify-debug.log"
  const debugLine = (message) => {
    if (!debug) return
    try {
      mkdirSync("/tmp/opencode", { recursive: true })
      appendFileSync(debugFile, `${new Date().toISOString()} ${message}\n`)
    } catch {
      /* ignore */
    }
  }

  debugLine(
    `loaded debug=${debug} tg=${tgEnabled} masterDisabled=${masterDisabled} os=${osChannel} script=${notifyScript} envToken=${tgToken ? "set" : "unset"} envChat=${tgChatID ? "set" : "unset"}`,
  )

  const projectName = (() => {
    try {
      return directory.split("/").filter(Boolean).pop() ?? "opencode"
    } catch {
      return "opencode"
    }
  })()

  const osNotify = async (kind, title, message) => {
    if (!haveOS || !enabled(`OPENCODE_NOTIFY_ON_${kind.toUpperCase()}`)) return
    debugLine(`osNotify: kind=${kind} enabled`)
    process.env.OPENCODE_NOTIFY_TITLE = title
    process.env.OPENCODE_NOTIFY_MESSAGE = message
    try {
      await $`${notifyScript} ${kind}`.nothrow()
    } catch {
      /* silent */
    }
  }

  const tgNotify = async (kind, text) => {
    if (!tgEnabled || !enabled(`OPENCODE_TELEGRAM_ON_${kind.toUpperCase()}`)) return
    debugLine(`tgNotify: kind=${kind} sending`)
    if (text.length > 4096) text = `${text.slice(0, 4000)}…`
    try {
      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), 10000)
      const res = await fetch(`https://api.telegram.org/bot${tgToken}/sendMessage`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ chat_id: tgChatID, text }),
        signal: controller.signal,
      })
      clearTimeout(timer)
      const body = await res.text().catch(() => "")
      debugLine(`tgNotify: status=${res.status} body=${body.slice(0, 300)}`)
      if (!res.ok) log("warn", `telegram sendMessage failed: ${res.status} ${body.slice(0, 200)}`)
    } catch (err) {
      debugLine(`tgNotify: error ${String(err)}`)
      log("warn", `telegram notification failed: ${String(err)}`)
    }
  }

  const notify = async (kind, title, message, tgText) => {
    if (masterDisabled) return
    await osNotify(kind, title, message)
    await tgNotify(kind, tgText ?? `${title}\n${message}`)
  }

  return {
    event: async ({ event }) => {
      debugLine(`event: ${event.type}${event.properties?.sessionID ? ` sessionID=${event.properties.sessionID}` : ""}`)
      if (event.type === "session.created") {
        if (event.properties?.info?.parentID) subagents.add(event.properties.info.id)
        return
      }

      if (event.type === "permission.asked") {
        const p = event.properties ?? {}
        const detail = p.pattern ? `${p.type}: ${p.pattern}` : String(p.type ?? "tool")
        await notify(
          "permission",
          `opencode · permission`,
          `${projectName} — requesting permission\n${detail}`,
          `[opencode] permission — ${projectName}\n${detail}`,
        )
        return
      }

      if (event.type !== "session.idle") return
      const id = event.properties.sessionID
      if (subagents.has(id)) {
        subagents.delete(id)
        return
      }
      const now = Date.now()
      const last = lastIdleAt.get(id)
      if (last !== undefined && now - last < IDLE_DEDUPE_MS) {
        debugLine(`session.idle deduped for ${id}`)
        return
      }
      lastIdleAt.set(id, now)
      await notify(
        "done",
        `opencode · done`,
        `${projectName} — response finished`,
        `[opencode] response finished — ${projectName}`,
      )
    },

    // Notify when the question is ASKED (before the user answers), not after.
    "tool.execute.before": async (input, output) => {
      debugLine(`tool.execute.before: tool=${input.tool} sessionID=${input.sessionID}`)
      if (input.tool !== "question") return
      const questions = output.args?.questions ?? input.args?.questions
      const first =
        Array.isArray(questions) && questions.length > 0 ? questions[0].prompt : undefined
      await notify(
        "question",
        `opencode · question`,
        `${projectName} — needs your input\n${first ?? ""}`,
        `[opencode] question — ${projectName}\n${first ?? "the agent has a question"}`,
      )
    },
  }
}
