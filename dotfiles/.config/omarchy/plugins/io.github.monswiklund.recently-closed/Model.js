.pragma library

// Pure logic for Recently Closed: parsing what the capture script produced,
// keeping the list of closed windows, and building the Lua that brings one
// back. No QML types here, so every rule is testable with plain node — see
// scripts/test-model.

var STATE_SUCCESS_MARKER = "\nRC_STATE_OK\n"
var MAX_STATE_CHARS = 1024 * 1024
var MAX_SERIALIZED_CHARS = 256 * 1024
var MAX_CLOSED_ROWS = 40
var MAX_COMMAND_CHARS = 64 * 1024
var MAX_CLASS_CHARS = 512
var MAX_TITLE_CHARS = 4096
var MAX_WORKSPACE_CHARS = 64
var MAX_GEOMETRY_CHARS = 128
var MAX_ADDRESS_CHARS = 128

function stateLimits() {
  return {
    inputChars: MAX_STATE_CHARS,
    serializedChars: MAX_SERIALIZED_CHARS,
    rows: MAX_CLOSED_ROWS,
    commandChars: MAX_COMMAND_CHARS,
    titleChars: MAX_TITLE_CHARS
  }
}

function boundedString(value, limit, allowNumber) {
  if (value === undefined || value === null) return ""
  if (typeof value !== "string" && !(allowNumber && typeof value === "number")) return null
  var text = String(value)
  return text.length <= limit ? text : null
}

// Hyprland reports a window's address two ways: `hyprctl clients` writes
// "0x55…" and the event socket writes "55…" for the same window. Everything
// here speaks the prefixed form, so the bare one is converted on the way in —
// otherwise a close event never finds what its own open event stored.
function normalizeAddress(value) {
  var address = String(value || "").trim()
  if (address === "") return ""
  return address.indexOf("0x") === 0 ? address : "0x" + address
}

function parseEntry(json) {
  var text = String(json || "")
  if (text.length > MAX_STATE_CHARS) return null

  var entry
  try {
    entry = JSON.parse(text.trim())
  } catch (e) {
    return null
  }
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) return null

  var cmd = boundedString(entry.cmd, MAX_COMMAND_CHARS, false)
  var rawAddress = boundedString(entry.address, MAX_ADDRESS_CHARS, false)
  var className = boundedString(entry["class"], MAX_CLASS_CHARS, false)
  var title = boundedString(entry.title, MAX_TITLE_CHARS, false)
  var workspace = boundedString(entry.workspace, MAX_WORKSPACE_CHARS, true)
  var at = boundedString(entry.at, MAX_GEOMETRY_CHARS, false)
  var size = boundedString(entry.size, MAX_GEOMETRY_CHARS, false)
  if (cmd === null || rawAddress === null || className === null || title === null
      || workspace === null || at === null || size === null) return null

  cmd = cmd.trim()
  var address = normalizeAddress(rawAddress)
  if (cmd === "" || address === "" || address.length > MAX_ADDRESS_CHARS) return null

  return {
    address: address,
    cmd: cmd,
    "class": className,
    title: title,
    workspace: workspace,
    floating: entry.floating === true,
    at: at,
    size: size
  }
}

function addressesFrom(json) {
  var list
  try {
    list = JSON.parse(json || "[]")
  } catch (e) {
    return []
  }
  if (!Array.isArray(list)) return []

  var addresses = []
  for (var i = 0; i < list.length; i++) {
    var address = normalizeAddress((list[i] && list[i].address) || "")
    if (address !== "") addresses.push(address)
  }
  return addresses
}

// ------------------------------------------------------------- shortcut
//
// Read from Hyprland rather than written here. Whatever key the user actually
// bound is the one the panel should name, and a hard-coded guess goes stale the
// first time somebody rebinds it.

function modifiersOf(modmask) {
  var mask = Number(modmask) || 0
  var names = []
  if (mask & 64) names.push("SUPER")
  if (mask & 4) names.push("CTRL")
  if (mask & 8) names.push("ALT")
  if (mask & 1) names.push("SHIFT")
  return names
}

// Matched on the description, because the dispatcher is opaque: Omarchy's
// bindings all arrive as "__lua" with a number for an argument.
function shortcutFrom(json, needle) {
  var binds
  try {
    binds = JSON.parse(json || "[]")
  } catch (e) {
    return ""
  }
  if (!Array.isArray(binds)) return ""

  var wanted = String(needle || "").toLowerCase()
  for (var i = 0; i < binds.length; i++) {
    var bind = binds[i]
    var description = String((bind && bind.description) || "").toLowerCase()
    if (description === "" || description.indexOf(wanted) === -1) continue

    var key = String(bind.key || "").toUpperCase()
    if (key === "") continue
    return modifiersOf(bind.modmask).concat([key]).join(" ")
  }
  return ""
}

// --------------------------------------------------------------- ignored
//
// Some windows are not closed so much as finished. The screensaver dismisses
// itself the moment you touch the keyboard, and offering to bring it back is
// offering to blank your screen — the one thing you just told it not to do.
//
// Kept deliberately short. Omarchy's other own windows — btop, a terminal, the
// about box — are windows you might genuinely want back, so only what closes
// itself belongs here.
function ignoredClasses() {
  return ["org.omarchy.screensaver"]
}

function isIgnored(entry) {
  var name = String((entry && entry["class"]) || "").toLowerCase()
  if (name === "") return false

  var ignored = ignoredClasses()
  for (var i = 0; i < ignored.length; i++)
    if (name === ignored[i].toLowerCase()) return true
  return false
}

// ------------------------------------------------------------------ list
//
// Newest first, capped, and one row per window closed.
//
// There was a rule here that collapsed identical entries, on the theory that
// four terminals closed in the same directory should be offered once. That was
// wrong: two windows closed are two windows lost, and a list that offers one of
// them back cannot give you the other. Two identical rows are two identical
// windows, which is exactly what you had.
//
// Nothing needs deduplicating, because a window closes once — and reopening
// takes its row off the list, so closing and reopening the same thing over and
// over never accumulates.
function boundedClosedRow(row) {
  if (!row || typeof row !== "object" || Array.isArray(row)) return null

  var cmd = boundedString(row.cmd, MAX_COMMAND_CHARS, false)
  var className = boundedString(row["class"], MAX_CLASS_CHARS, false)
  var title = boundedString(row.title, MAX_TITLE_CHARS, false)
  var workspace = boundedString(row.workspace, MAX_WORKSPACE_CHARS, true)
  var at = boundedString(row.at, MAX_GEOMETRY_CHARS, false)
  var size = boundedString(row.size, MAX_GEOMETRY_CHARS, false)
  if (cmd === null || className === null || title === null || workspace === null
      || at === null || size === null || cmd.trim() === "") return null

  var closedAt = Number(row.closedAt)
  if (!isFinite(closedAt) || closedAt < 0) closedAt = 0

  var normalized = {
    cmd: cmd,
    "class": className,
    title: title,
    closedAt: closedAt,
    workspace: workspace,
    floating: row.floating === true,
    at: at,
    size: size
  }
  return JSON.stringify(normalized).length <= MAX_SERIALIZED_CHARS ? normalized : null
}

function boundedClosedRows(list, limit) {
  if (!Array.isArray(list)) return []

  var ceiling = Math.min(MAX_CLOSED_ROWS, Math.max(0, Math.floor(Number(limit) || 0)))
  var out = []
  for (var i = 0; i < list.length && i < MAX_CLOSED_ROWS && out.length < ceiling; i++) {
    var row = boundedClosedRow(list[i])
    if (row) out.push(row)
  }
  return out
}

function withClosed(list, entry, limit, now) {
  var candidate = {
    closedAt: Number(now) || 0,
    cmd: entry.cmd,
    "class": entry["class"],
    title: entry.title,
    workspace: entry.workspace,
    floating: entry.floating,
    at: entry.at,
    size: entry.size
  }
  return boundedClosedRows([candidate].concat(Array.isArray(list) ? list : []), limit)
}

function closedRowsFromText(text) {
  var source = String(text || "")
  if (source.length > MAX_STATE_CHARS) return null

  var data
  try {
    data = JSON.parse(source.trim() || "[]")
  } catch (e) {
    return null
  }
  if (!Array.isArray(data)) return null
  return boundedClosedRows(data, MAX_CLOSED_ROWS)
}

function parseClosed(text) {
  return closedRowsFromText(text) || []
}

// prepare-state writes the marker only after one descriptor has been opened,
// validated and read within its byte ceiling. No marker means no trusted read.
function parseStateOutput(output) {
  var text = String(output || "")
  if (text.length > MAX_STATE_CHARS + STATE_SUCCESS_MARKER.length) return null
  if (text.slice(-STATE_SUCCESS_MARKER.length) !== STATE_SUCCESS_MARKER) return null
  return closedRowsFromText(text.slice(0, -STATE_SUCCESS_MARKER.length))
}

function withoutIndex(list, index) {
  if (index < 0 || index >= list.length) return null
  var next = list.slice()
  next.splice(index, 1)
  return next
}

function serialize(list) {
  var rows = boundedClosedRows(list, MAX_CLOSED_ROWS)
  var text = JSON.stringify(rows, null, 2) + "\n"
  while (text.length > MAX_SERIALIZED_CHARS && rows.length > 0) {
    rows.pop()
    text = JSON.stringify(rows, null, 2) + "\n"
  }
  return text
}

// -------------------------------------------------------------- reopening

function luaString(value) {
  return '"' + String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n") + '"'
}

// Back where it was, and without dragging the screen there. A floating window
// arrives already placed; a tiled one takes its place from the layout, because
// no dispatcher rebuilds a split tree.
// `onto` overrides where it lands. A closed window usually wants to come back
// where it was, but not always: after you have moved on, the workspace you are
// standing in is the one you meant.
function reopenExpr(entry, onto) {
  var workspace = onto === undefined || onto === null || String(onto) === ""
    ? entry.workspace
    : String(onto)

  var rules = []
  if (workspace !== "" && Number(workspace) > 0)
    rules.push("workspace = " + luaString(workspace + " silent"))

  if (entry.floating) {
    rules.push("float = true")
    if (entry.size) rules.push("size = " + luaString(entry.size.replace(/,/g, " ")))
    if (entry.at) rules.push("move = " + luaString(entry.at.replace(/,/g, " ")))
  }

  if (rules.length === 0) return "hl.dsp.exec_cmd(" + luaString(entry.cmd) + ")"
  return "hl.dsp.exec_cmd(" + luaString(entry.cmd) + ", { " + rules.join(", ") + " })"
}

// ------------------------------------------------------------------ age
//
// A list of recently closed windows without a "when" is half a list: the window
// you closed two minutes ago is nearly always the one you are looking for, and
// one from the day before yesterday is what you scroll past.

function ageLabel(closedAt, now) {
  var then = Number(closedAt) || 0
  if (then <= 0) return ""

  var seconds = Math.max(0, Math.round(((Number(now) || 0) - then) / 1000))
  if (seconds < 60) return "now"

  var minutes = Math.round(seconds / 60)
  if (minutes < 60) return minutes + "m"

  var hours = Math.round(minutes / 60)
  if (hours < 24) return hours + "h"

  var days = Math.round(hours / 24)
  return days + "d"
}

// How many pages a browser row will bring back. Counted from the command, so it
// says what a click actually does rather than what the window used to be.
function tabCount(entry) {
  var matches = String(entry.cmd || "").match(/(^| )(https?|file):\/\/\S+/g)
  return matches ? matches.length : 0
}

// --------------------------------------------------------------- labels

// A path said the way a person says it. Two trailing components is right for a
// project buried deep — "sportson/service-system" — but wrong just under home,
// where it surfaces the username and reads like a filesystem root rather than a
// folder you chose. Anything inside home keeps the tilde it deserves.
function shortenPath(dir, home) {
  var path = String(dir || "").replace(/\/+$/, "")
  if (path === "") return ""
  if (home && path === home) return "~"

  if (home && path.indexOf(home + "/") === 0) {
    var relative = path.slice(home.length + 1)
    if (relative.split("/").length <= 2) return "~/" + relative
  }

  var parts = path.split("/")
  return parts.length <= 2 ? parts.join("/") : parts.slice(-2).join("/")
}

// What the window was, said the way you would say it. The command a terminal
// ran names the window better than the terminal does.
function entryLabel(entry) {
  var exec = String(entry.cmd).match(/\s-e\s+(.+)$/)
  if (exec) return exec[1]
  return String(entry.cmd).split(/\s+/)[0].split("/").pop()
}

function entryDetail(entry, home) {
  var match = String(entry.cmd).match(/--(?:working-directory|directory|cwd)[= ](\S+)/)
  if (!match) return entry.title || ""

  var dir = match[1].replace(/\\ /g, " ")
  if (home && dir === home) return "~"
  return shortenPath(dir, home)
}
