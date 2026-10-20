-- Drives a whole QUOTA run with no player: start, sell through the terminal,
-- fire every event and hazard, shop in every break, miss a quota on purpose,
-- fight The Audit, go endless, get fired, reapply. Writes
-- script-output/quota-autotest.log; any "FAIL" line or "[quota]" error in
-- factorio-current.log is a failure.

local OUT = "quota-autotest.log"

local function out(...)
  local parts = {}
  for _, v in ipairs({ ... }) do parts[#parts + 1] = type(v) == "table" and helpers.table_to_json(v) or tostring(v) end
  helpers.write_file(OUT, table.concat(parts, " ") .. "\n", true)
end

local function call(fn, ...)
  return remote.call("quota", fn, ...)
end

local function check(cond, what)
  out(cond and "PASS" or "FAIL", what)
end

local function st() return call("state") end

local VALUE_PROBE = {
  "iron-ore", "iron-plate", "copper-plate", "steel-plate", "stone-brick", "iron-gear-wheel", "copper-cable",
  "electronic-circuit", "advanced-circuit", "processing-unit", "plastic-bar", "engine-unit", "electric-engine-unit", "shotgun-shell",
  "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "transport-belt", "inserter",
  "assembling-machine-1", "firearm-magazine", "piercing-rounds-magazine", "solid-fuel", "rocket-fuel", "battery",
  "sulfur", "flying-robot-frame", "low-density-structure", "uranium-235", "raw-fish", "wood", "barrel",
}

local function dump_values(tag)
  local v = call("values", VALUE_PROBE)
  for _, n in ipairs(VALUE_PROBE) do
    local e = v[n]
    out("VALUE", tag, n, string.format("%.2f", e.base), "depth", e.depth, "premium", string.format("%.2f", e.premium),
      "recipe", e.recipe)
  end
end

local THREAT_CONDS = { meteors = true, gremlins = true, quakes = true, strike = true, raids = true, audit = true }

-- One scripted step per second. Each step returns the number of seconds to wait.
local plan = {}
local function step(fn) plan[#plan + 1] = fn end

local function shift_body(n, opts)
  opts = opts or {}
  step(function()
    local s = st()
    check(s.phase == "shift", "shift " .. n .. " running (phase=" .. tostring(s.phase) .. ")")
    check(s.shift == n, "shift number " .. n .. " (got " .. tostring(s.shift) .. ")")
    out("SHIFT", n, "quota", s.quota, "conditions", s.conditions, "hot", s.hot, "wallet", math.floor(s.wallet))
    if n < 4 then
      local early = false
      for _, id in ipairs(s.conditions or {}) do
        if id == "meteors" or id == "gremlins" then early = true end
      end
      check(not early, "no meteor shower or gremlins before shift 4 (shift " .. n .. ")")
    end
    -- Real sales through the terminal (a trickle on shifts we mean to miss).
    if opts.miss then
      call("terminal_insert", "iron-plate", 5)
    else
      call("terminal_insert", "iron-plate", 200)
      call("terminal_insert", "iron-gear-wheel", 100)
      call("terminal_insert", "electronic-circuit", 50)
      if s.hot and s.hot[1] then call("terminal_insert", s.hot[1], 20) end
    end
    storage.before = s.shipped
    return 2
  end)
  step(function()
    local s = st()
    check(s.shipped > storage.before, "terminal sold goods in shift " .. n .. " (+" .. math.floor(s.shipped - storage.before) .. ")")
    if n >= 2 and not opts.miss then
      for _, id in ipairs({ "flash", "bounty", "supply", "rally", "meteor", "gremlin", "crash", "raid" }) do
        local ok = call("fire_event", id)
        out("EVENT", id, ok)
      end
    end
    call("hazard", "gremlin")
    call("hazard", "meteor")
    call("hazard", "quake")
    if n >= 3 then call("hazard", "raid") end
    return 4
  end)
  step(function()
    -- Let hazards play out: meteors land, quake fires, pods land.
    call("advance", 30)
    return 15
  end)
  if opts.audit then
    step(function()
      local s = st()
      out("AUDIT before spawn", s.auditor)
      call("advance", 95)
      return 3
    end)
    step(function()
      local s = st()
      check(s.auditor == "active", "auditor spawned (" .. tostring(s.auditor) .. ")")
      return 20
    end)
    step(function()
      local surface = game.get_surface(storage.surface_name)
      local found = surface and surface.find_entities_filtered({ name = "quota-auditor" }) or {}
      check(#found == 1, "auditor entity exists")
      if found[1] then
        out("AUDITOR at", found[1].position, "health", found[1].health)
        found[1].die("player")
      end
      return 2
    end)
    step(function()
      local s = st()
      check(s.auditor == "killed", "auditor killed (" .. tostring(s.auditor) .. ")")
      return 1
    end)
  end
  step(function()
    local s = st()
    if opts.miss then
      out("MISSING shift", n, "on purpose", s.shipped, "of", s.quota)
      check(s.shipped < s.quota, "shift " .. n .. " is short of quota")
    else
      local need = s.quota * 1.6 - s.shipped
      if need > 0 then call("ship", need) end
      local s2 = st()
      check(s2.shipped >= s2.quota, "quota met in shift " .. n)
      if opts.clock_out then
        local bonus = call("clock_out_bonus")
        local w = s2.wallet
        check(bonus > 0 and call("clock_out"), "clocked out early in shift " .. n .. " for " .. tostring(bonus))
        local s3 = st()
        check(s3.phase == "break" and s3.wallet >= w + bonus - 1, "clock-out bonus paid and break started")
        return 2
      end
      if opts.audit then check(call("clock_out_bonus") == 0, "no clocking out of The Audit") end
    end
    call("skip")
    return 2
  end)
end

local function holds(list, id)
  for _, v in ipairs(list or {}) do if v == id then return true end end
  return false
end

-- Hype Machine and Insider Trading count for the very next shift when signed
-- in a break, and stop counting when sold.
local function contract_timing(s)
  local before = s.next and s.next.mults or {}
  if not holds(s.perks, "hype") and next(before) then
    call("grant_perk", "hype")
    local after = st().next.mults
    local ok = true
    for name, m in pairs(before) do
      if math.abs((after[name] or 0) - m - 1) > 1e-6 then ok = false end
    end
    check(ok, "Hype Machine boosts the next shift as soon as it is signed")
    call("buy", "sell", "hype")
    after = st().next.mults
    ok = true
    for name, m in pairs(before) do
      if math.abs((after[name] or 0) - m) > 1e-6 then ok = false end
    end
    check(ok, "selling Hype Machine drops the boost again")
  end
  if not holds(s.perks, "insider") and s.last_best then
    call("grant_perk", "insider")
    local nx = st().next
    check(holds(nx.hot, s.last_best), "Insider Trading makes " .. s.last_best .. " hot next shift")
    call("buy", "sell", "insider")
    check(st().next.insider == nil, "selling Insider Trading removes its hot slot")
  end
end

local function break_body(n, opts)
  opts = opts or {}
  step(function()
    local s = st()
    out("REPORT", s.report)
    if opts.expect then
      check(s.phase == opts.expect, "after shift " .. n .. " phase is " .. opts.expect .. " (got " .. tostring(s.phase) .. ")")
    else
      check(s.phase == "break", "break after shift " .. n .. " (phase=" .. tostring(s.phase) .. ")")
    end
    if s.phase ~= "break" then return 1 end
    out("NEXT", s.next, "offers", s.offers, "corporate", s.corporate, "warnings", s.warnings_left)
    check(s.jammed == 0, "no machine left jammed into break " .. n .. " (" .. tostring(s.jammed) .. ")")
    if n == 2 then contract_timing(s) end
    call("money", 200000)
    local r
    -- Keep a slot free so every break can buy.
    if #s.perks >= 5 then
      r = call("buy", "sell", s.perks[1])
      out("SELL contract", s.perks[1], r)
      check(r.ok, "sold contract " .. s.perks[1])
    end
    if s.offers and s.offers[1] then
      r = call("buy", "contract", s.offers[1])
      out("BUY contract", s.offers[1], r)
      check(r.ok, "bought contract " .. s.offers[1])
    end
    r = call("buy", "reroll")
    check(r.ok, "reroll")
    local s2 = st()
    if s2.offers and s2.offers[1] and #s2.perks < 5 then out("BUY contract2", s2.offers[1], call("buy", "contract", s2.offers[1])) end
    -- Land: try the four neighbours of every owned plot.
    local bought = false
    for px = -4, 4 do
      for py = -4, 4 do
        if not bought then
          local res = call("buy", "plot", px, py)
          if res.ok then
            bought = true
            out("BUY plot", px, py)
          end
        end
      end
    end
    check(bought, "bought a plot")
    local rnd = ({ "steel", "greensci", "oil", "plastics", "sulfur", "bluesci", "robots", "prodsci" })[n] or "blue"
    out("BUY rnd", rnd, call("buy", "rnd", rnd))
    out("BUY upgrade", call("buy", "upgrade", "mining"))
    out("BUY crate", call("buy", "crate", ({ "belts", "inserters", "mining", "assembly", "smelting", "power", "defense", "oil" })[n] or "robots"))
    if n == 1 then
      out("BUY mystery", call("buy", "mystery"))
      out("BUY terminal", call("buy", "terminal"))
    end
    if s.corporate then
      local id = s.corporate[1]
      local res = call("buy", "corporate", id)
      out("CORPORATE", id, res)
      check(res.ok, "accepted corporate offer " .. id)
    end
    return 3
  end)
  step(function()
    local s = st()
    if s.phase == "break" then call("clock_in") end
    return 2
  end)
end

-- --------------------------------------------------------------- plan ---

step(function()
  local s = st()
  check(s.phase == "orientation", "starts in orientation")
  check(s.plots == 1, "owns the HQ plot")
  check(s.terminals == 1, "HQ terminal registered")
  call("start", { mode = "simple", difficulty = "associate" })
  dump_values("simple")
  return 2
end)
step(function()
  local s = st()
  check(s.phase == "break" and s.briefing == true and s.next and s.next.n == 1,
    "briefing before shift 1 (phase=" .. tostring(s.phase) .. ")")
  check(#(s.offers or {}) == 0, "no contracts on the table in the briefing")
  check(s.mode == "simple" and s.final == 8, "simple mode, 8 shifts (" .. tostring(s.mode) .. ", " .. tostring(s.final) .. ")")
  check(call("value", "firearm-magazine") > 2, "crafted ammo keeps its value")
  local z = call("zoning")
  check(z.licensed >= 4 and z.rnd.oil == false, "simple mode: no zoning locks")
  call("clock_in")
  return 1
end)

-- A few machines for gremlins to jam (the starter kit is still in the chest).
step(function()
  local surface = game.surfaces[storage.surface_name]
  for i, name in ipairs({ "assembling-machine-1", "assembling-machine-1", "stone-furnace", "inserter" }) do
    local pos = surface.find_non_colliding_position(name, { -20 + i * 4, 22 }, 30, 1)
    if pos then surface.create_entity({ name = name, position = pos, force = "player" }) end
  end
  return 1
end)

for n = 1, 8 do
  shift_body(n, { miss = (n == 3), audit = (n == 8), clock_out = (n == 2) })
  if n < 8 then break_body(n) end
end
step(function()
  local s = st()
  out("REPORT", s.report)
  check(s.phase == "promoted", "promoted after shift 8 (phase=" .. tostring(s.phase) .. ")")
  call("endless")
  return 2
end)
break_body(9)
shift_body(9, { miss = true })
-- A corporate deal may have handed out spare warnings: keep missing until fired.
for _ = 1, 6 do
  step(function()
    local s = st()
    if s.phase == "break" then call("clock_in") elseif s.phase == "shift" then call("skip") end
    return 2
  end)
end
step(function()
  local s = st()
  check(s.phase == "fired", "fired after missing an endless shift with no warnings (phase=" .. tostring(s.phase) .. ")")
  out("FINAL STATS", s.stats)
  call("reapply")
  return 3
end)
step(function()
  local s = st()
  check(s.phase == "orientation", "reapply returns to orientation")
  check(s.plots == 1, "fresh island")
  check(s.terminals == 1, "fresh terminal")
  -- Second run: Complex, Crunch, every threat switched off.
  call("start", { mode = "complex", difficulty = "crunch",
    off = { meteors = true, gremlins = true, quakes = true, strike = true, raids = true, nests = true, audit = true } })
  return 5
end)
step(function()
  local s = st()
  check(s.phase == "break" and s.briefing == true, "briefing before the new run")
  check(s.mode == "complex" and s.final == 10, "complex mode, 10 shifts (" .. tostring(s.mode) .. ", " .. tostring(s.final) .. ")")
  dump_values("complex")
  local z = call("zoning")
  out("ZONING", z)
  check(z.bought == 0 and type(z.rnd.oil) == "string", "complex: Oil Industry zoned with no plots (" .. tostring(z.rnd.oil) .. ")")
  check(z.tech["oil-processing"] and z.tech["oil-processing"].enabled == false, "complex: oil-processing disabled in the tech tree")
  check(type(z.rnd.greensci) ~= "string" or not z.rnd.greensci:find("Zoning"), "complex: green science not zoned")
  call("money", 500000)
  local n = 0
  for _ = 1, 3 do
    for px = -2, 2 do
      for py = -2, 2 do
        if n < 2 and call("buy", "plot", px, py).ok then n = n + 1 end
      end
    end
  end
  local z2 = call("zoning")
  out("ZONING after plots", z2)
  check(z2.bought == 2 and z2.rnd.oil == false, "complex: two plots license Oil Industry")
  check(z2.tech["oil-processing"].enabled == true, "complex: oil-processing re-enabled")
  check(type(z2.rnd.bluesci) == "string", "complex: blue science still zoned at 2 plots")
  -- With every threat off, no threat condition rolls (shift 5+ rolls two on Crunch).
  local clean = true
  for i = 1, 6 do
    call("jump", 4 + i)
    local nx = st().next
    out("ROLL", nx.n, nx.conditions)
    for _, id in ipairs(nx.conditions or {}) do
      if THREAT_CONDS[id] then clean = false end
    end
  end
  check(clean, "threat switches off: no threat conditions roll")
  call("jump", 10)
  local fin = st().next
  local audit = false
  for _, id in ipairs(fin.conditions or {}) do if id == "audit" then audit = true end end
  check(not audit, "audit switched off: the final shift has no Auditor")
  call("jump", 5)
  -- Let it run out instead of clocking in.
  return 30
end)
step(function()
  local s = st()
  check(s.phase == "shift" and s.shift == 5, "new run shift 5 running (" .. tostring(s.phase) .. " " .. tostring(s.shift) .. ")")
  out("DONE")
  return 9999
end)

-- --------------------------------------------------------------- loop ---

script.on_init(function()
  storage.i = 1
  storage.next = 120
  helpers.write_file(OUT, "autotest start\n", false)
end)

script.on_nth_tick(60, function()
  if game.tick < (storage.next or 0) then return end
  local fn = plan[storage.i]
  if not fn then return end
  storage.surface_name = "quota"
  for _, s in pairs(game.surfaces) do
    if s.name:find("^quota") then storage.surface_name = s.name end
  end
  local ok, wait = pcall(fn)
  if not ok then
    out("FAIL step", storage.i, "error:", wait)
    wait = 1
  end
  storage.i = storage.i + 1
  storage.next = game.tick + (wait or 1) * 60
end)
