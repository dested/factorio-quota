-- Run rules: mode, difficulty, length, knobs and which threats are switched on.
--
-- The runtime-global mod settings hold them, so the main menu sets the defaults for a new game
-- and Run Setup writes the chosen rules back. storage.q.rules is the run's copy: switches and
-- knobs follow a mid-run settings change from the next shift; mode, difficulty, run length and
-- warnings lock when the run starts.

local C = require("lib.config")

local R = {}

R.MODES = {
  simple = {
    name = "Simple", shifts = 8,
    blurb = "First time? Play this.",
    lines = { "8 shifts, about an hour", "Prices follow ingredients", "All tech for sale" },
  },
  complex = {
    name = "Complex", shifts = 10,
    blurb = "Longer and deeper. Build big.",
    lines = { "10 shifts, about 80 min", "Deep chains pay up to 2.6x", "Tech zoned by land owned" },
  },
}
R.MODE_ORDER = { "simple", "complex" }

-- Switches. A switch turns off conditions and/or events (nests: the Infested Swamp spawners).
-- Threat switches carry their own name; condition and event switches borrow the def's.
R.SWITCHES = {
  { key = "meteors", group = "threats", name = "Meteors", sprite = "virtual-signal/signal-explosion",
    desc = "Meteor Shower condition and stray meteors.", conds = { "meteors" }, events = { "meteor" } },
  { key = "gremlins", group = "threats", name = "Gremlins", sprite = "entity/small-biter",
    desc = "Gremlin Infestation condition and stray gremlins.", conds = { "gremlins" }, events = { "gremlin" } },
  { key = "quakes", group = "threats", name = "Earthquakes", sprite = "virtual-signal/signal-alarm",
    desc = "The Seismic Activity condition.", conds = { "quakes" } },
  { key = "strike", group = "threats", name = "Union strikes", sprite = "item/inserter",
    desc = "The Union Strike condition.", conds = { "strike" } },
  { key = "raids", group = "threats", biters = true, name = "Biter raids", sprite = "item/gun-turret",
    desc = "Hostile Takeover condition and surprise raids.", conds = { "raids" }, events = { "raid" } },
  { key = "nests", group = "threats", biters = true, name = "Swamp nests", sprite = "entity/biter-spawner",
    desc = "Biter nests on Infested Swamp plots. Off: the swamps are just cheap, rich land." },
  { key = "audit", group = "threats", biters = true, name = "The Audit", sprite = "entity/behemoth-biter",
    desc = "The final-shift boss. Off: the last shift is just a big quota.", conds = { "audit" } },
  { key = "eclipse", group = "conditions", conds = { "eclipse" } },
  { key = "hotpotato", group = "conditions", conds = { "hotpotato" } },
  { key = "picky", group = "conditions", conds = { "picky" } },
  { key = "volatile", group = "conditions", conds = { "volatile" } },
  { key = "rush", group = "conditions", conds = { "rush" } },
  { key = "mandate", group = "conditions", conds = { "mandate" } },
  { key = "lowgrav", group = "conditions", conds = { "lowgrav" } },
  { key = "golden", group = "conditions", conds = { "golden" } },
  { key = "flash", group = "events", events = { "flash" } },
  { key = "bounty", group = "events", events = { "bounty" } },
  { key = "supply", group = "events", events = { "supply" } },
  { key = "rally", group = "events", events = { "rally" } },
  { key = "crash", group = "events", events = { "crash" } },
}
R.SWITCH_BY_KEY = {}
local COND_SWITCH, EVENT_SWITCH = {}, {}
for _, s in ipairs(R.SWITCHES) do
  R.SWITCH_BY_KEY[s.key] = s
  for _, id in ipairs(s.conds or {}) do COND_SWITCH[id] = s.key end
  for _, id in ipairs(s.events or {}) do EVENT_SWITCH[id] = s.key end
end

R.PRESETS = {
  { id = "full", name = "Full Company", desc = "Everything on. The intended chaos." },
  { id = "nobiters", name = "No Biters", desc = "No raids, no nests, no Audit boss. Meteors, gremlins and the rest stay." },
  { id = "clock", name = "Race the Clock", desc = "Every threat off. Just you, the quota and the market." },
}

function R.preset_off(id)
  local off = {}
  for _, s in ipairs(R.SWITCHES) do
    if id == "nobiters" and s.biters then off[s.key] = true end
    if id == "clock" and s.group == "threats" then off[s.key] = true end
  end
  return off
end

-- Fine print. Choices are what Run Setup offers; the mod settings accept any value in range.
R.KNOBS = {
  { key = "shifts", setting = "quota-shifts", name = "Run length",
    choices = { "auto", "5", "6", "8", "10", "12", "15" } },
  { key = "warnings", setting = "quota-warnings", name = "Written warnings",
    choices = { "auto", "0", "1", "2", "3", "5" } },
  { key = "quota_scale", setting = "quota-quota-scale", name = "Quota size", choices = { 0.5, 0.75, 1, 1.25, 1.5, 2 } },
  { key = "shift_len", setting = "quota-shift-length", name = "Shift length", choices = { 0.75, 1, 1.25, 1.5, 2 } },
  { key = "break_secs", setting = "quota-break-length", name = "Break length", choices = { 45, 60, 90, 120, 180 } },
}

local function setting_name(key) return "quota-s-" .. key end
R.setting_name = setting_name

-- ------------------------------------------------------------ read/write ---

local function sv(name, fallback)
  local s = settings.global[name]
  if s == nil or s.value == nil then return fallback end
  return s.value
end

local function default_rules()
  return {
    mode = "simple", difficulty = "associate", shifts = "auto", warnings = "auto",
    quota_scale = 1, shift_len = 1, break_secs = C.BREAK_SECONDS, off = {},
  }
end

-- Rules as the mod settings have them right now.
function R.read()
  local d = default_rules()
  local r = {
    mode = sv("quota-mode", d.mode), difficulty = sv("quota-difficulty", d.difficulty),
    shifts = sv("quota-shifts", d.shifts), warnings = sv("quota-warnings", d.warnings),
    quota_scale = sv("quota-quota-scale", d.quota_scale), shift_len = sv("quota-shift-length", d.shift_len),
    break_secs = sv("quota-break-length", d.break_secs), off = {},
  }
  if not R.MODES[r.mode] then r.mode = d.mode end
  if not C.DIFFICULTIES[r.difficulty] then r.difficulty = d.difficulty end
  for _, s in ipairs(R.SWITCHES) do
    if sv(setting_name(s.key), true) == false then r.off[s.key] = true end
  end
  return r
end

local function put(name, value)
  if settings.global[name] ~= nil then settings.global[name] = { value = value } end
end

-- Write rules back to the mod settings (Run Setup, Handbook switches).
function R.write(r)
  put("quota-mode", r.mode)
  put("quota-difficulty", r.difficulty)
  put("quota-shifts", tostring(r.shifts))
  put("quota-warnings", tostring(r.warnings))
  put("quota-quota-scale", r.quota_scale)
  put("quota-shift-length", r.shift_len)
  put("quota-break-length", r.break_secs)
  for _, s in ipairs(R.SWITCHES) do put(setting_name(s.key), not r.off[s.key]) end
end

function R.copy(r)
  local c = {}
  for k, v in pairs(r) do c[k] = v end
  c.off = {}
  for k, v in pairs(r.off or {}) do c.off[k] = v end
  return c
end

-- Pick up the live parts (switches and knobs) of a settings change mid-run.
-- Returns true when a locked field differs (it will apply next run).
function R.refresh_live()
  local q = storage.q
  local fresh = R.read()
  local cur = q.rules
  if not cur then
    q.rules = fresh
    return false
  end
  cur.quota_scale, cur.shift_len, cur.break_secs, cur.off = fresh.quota_scale, fresh.shift_len, fresh.break_secs, fresh.off
  return fresh.mode ~= cur.mode or fresh.difficulty ~= cur.difficulty
    or tostring(fresh.shifts) ~= tostring(cur.shifts) or tostring(fresh.warnings) ~= tostring(cur.warnings)
end

-- ----------------------------------------------------------------- query ---

function R.get()
  local q = storage.q
  if not q.rules then q.rules = R.read() end
  return q.rules
end

function R.mode() return R.get().mode end
function R.complex() return R.get().mode == "complex" end
function R.mode_def() return R.MODES[R.get().mode] or R.MODES.simple end
function R.diff() return C.DIFFICULTIES[R.get().difficulty] or C.DIFFICULTIES.associate end

-- Number of shifts before The Audit closes the run.
function R.final()
  local r = R.get()
  local n = tonumber(r.shifts)
  if not n or n < 1 then n = (R.MODES[r.mode] or R.MODES.simple).shifts end
  return math.floor(n)
end

function R.warnings()
  local r = R.get()
  local n = tonumber(r.warnings)
  if not n then return R.diff().warnings end
  return math.max(0, math.floor(n))
end

function R.break_secs()
  return math.max(15, math.floor(R.get().break_secs or C.BREAK_SECONDS))
end

function R.on(key)
  return not R.get().off[key]
end

function R.cond_on(id)
  local key = COND_SWITCH[id]
  return key == nil or R.on(key)
end

function R.event_on(id)
  local key = EVENT_SWITCH[id]
  return key == nil or R.on(key)
end

-- Short summary for the end screen and chat.
function R.describe(r)
  r = r or R.get()
  local off = 0
  for _ in pairs(r.off or {}) do off = off + 1 end
  local mode = (R.MODES[r.mode] or R.MODES.simple).name
  local diff = (C.DIFFICULTIES[r.difficulty] or C.DIFFICULTIES.associate).name
  return mode .. ", " .. diff .. (off > 0 and (", " .. off .. " switches off") or "")
end

return R
