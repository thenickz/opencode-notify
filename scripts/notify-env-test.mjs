// notify-env-test.mjs — unit tests for parseNotifyEnv (plugins/opencode-notify.js).
// Run with: node scripts/notify-env-test.mjs
import { mkdtempSync, writeFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { parseNotifyEnv } from "../plugins/opencode-notify.js"

let failures = 0
const check = (label, actual, expected) => {
  const a = JSON.stringify(actual)
  const e = JSON.stringify(expected)
  if (a === e) {
    console.log(`ok  ${label}`)
  } else {
    console.log(`FAIL ${label}: got ${a}, want ${e}`)
    failures++
  }
}

const dir = mkdtempSync(join(tmpdir(), "notify-env-test-"))
const file = join(dir, "opencode-notify.env")
writeFileSync(
  file,
  [
    "# comment line",
    "OPENCODE_NOTIFY_OS=none",
    "export OPENCODE_NOTIFY_ON_QUESTION=0",
    'OPENCODE_TELEGRAM_BOT_TOKEN="tok 123"',
    "OPENCODE_TELEGRAM_CHAT_ID='12345'",
    "EMPTY_KEY=",
    "not-valid-line-no-equals",
    "",
    "  OPENCODE_NOTIFY_DEBUG=1  ",
  ].join("\n"),
)

const out = parseNotifyEnv(file)
check("parses all valid keys", Object.keys(out).length, 6)
check("simple value", out.OPENCODE_NOTIFY_OS, "none")
check("export prefix", out.OPENCODE_NOTIFY_ON_QUESTION, "0")
check("double-quoted value keeps inner spaces", out.OPENCODE_TELEGRAM_BOT_TOKEN, "tok 123")
check("single-quoted value", out.OPENCODE_TELEGRAM_CHAT_ID, "12345")
check("empty value is kept as empty string", out.EMPTY_KEY, "")
check("whitespace around key=value is trimmed", out.OPENCODE_NOTIFY_DEBUG, "1")
check(
  "comment/malformed lines create no keys",
  Object.prototype.hasOwnProperty.call(out, "not-valid-line-no-equals"),
  false,
)
check("missing file returns empty object", parseNotifyEnv(join(dir, "nope.env")), {})
check("null path returns empty object", parseNotifyEnv(null), {})

rmSync(dir, { recursive: true, force: true })

if (failures) {
  console.error(`${failures} test(s) failed`)
  process.exit(1)
}
console.log("all tests passed")
