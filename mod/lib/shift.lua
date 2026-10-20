-- The run: orientation -> (shift -> break)* -> fired | promoted -> endless.
-- Also builds the world for a new run and tears it down on "Reapply".

local C = require("lib.config")
local U = require("lib.util")
local V = require("lib.values")
local M = require("lib.market")
local L = require("lib.ledger")
local P = require("lib.perks")
local W = require("lib.world")
local S = require("lib.sfx")
local D = require("lib.delivery")
local T = require("lib.terminals")
local K = require("lib.conditions")
local H = require("lib.hazards")
local E = require("lib.events")
local AU = require("lib.auditor")
local SH = require("lib.shop")
local R = require("lib.rules")
local Z = require("lib.zoning")
local GM = require("lib.gui.main")
local HUD = require("lib.gui.hud")
local CAT = require("lib.gui.catalog")

local SF = {}

-- ------------------------------------------------------------- state ---

function SF.fresh_state(old)
  return {
    phase = "orientation",
    rng = old and old.rng or 1,
    surface_serial = old and old.surface_serial or 0,
    terrain_salt = 7,
    run_serial = (old and old.run_serial or 0) + 1,
    plots = {}, signs = {}, jobs = {}, notes = {},
    wallet = 0, shipped = 0, quota = 0, quota_met = false, quota_met_tick = nil,
    shift = 0, shift_start = 0, shift_end = 0, shift_len = 0, run_started = 0,
    difficulty = "associate", warnings_left = 1, endless = false, rules = nil, zoned = {},
    stats = { total_shipped = 0, items_shipped = 0, by_item = {}, total_bonus = 0, total_spent = 0, shifts_done = 0 },
    values = {}, fluid_values = {}, equipment = {},
    hot = {}, hot_order = {}, hot_sig = 0, flood = {},
    shift_sales = {}, shift_credits = {}, shift_distinct = 0, monopoly_item = nil, last_best = nil,
    perks = {}, perk_slots = C.CONTRACT_SLOTS, perk_paid = {}, perk_state = { golden = 0, workaholic = 0 },
    upgrades = {}, cond_active = {}, cond_state = {}, conditions = {}, last_conditions = {},
    applied = {}, applied_recipes = {}, price_mods = { catalog = 1 },
    run_price_mult = 1, shift_price_mult = 1, quota_mult = 1, next_quota_mult = nil, extra_condition = false,
    perf_adjust = 0,
    terminals = {}, terminal_serial = 0, terminals_bought = 0, frozen = {}, disabled = {},
    hz = nil, ev = nil, aud = nil,
    offers = {}, rerolls = 0, corporate = nil, corporate_seen = {},
    next = nil, report = nil, break_end = 0, break_len = 0, briefing = nil,
    ui = {},
  }
end

-- ------------------------------------------------------------- world ---

local function setup_force()
  local force = U.force()
  for _, t in ipairs(C.STARTING_TECHS) do SH.research(t) end
  -- No reclaiming the sea for free: land is bought.
  local lf = force.technologies["landfill"]
  if lf then
    lf.enabled = false
    lf.visible_when_disabled = false
  end
  if force.recipes["landfill"] then force.recipes["landfill"].enabled = false end
  -- Meteors and raids leave ghosts, so a wrecked line can be rebuilt by hand.
  force.create_ghost_on_entity_death = true
  P.apply()
end

function SF.new_world()
  local q = storage.q
  q.terrain_salt = U.random(1, 1000000)
  V.refresh()
  H.reset()
  E.reset()
  local surface = W.create_surface()
  W.roll_grid()
  W.claim(0, 0, true)
  local term = surface.create_entity({ name = "quota-terminal", position = { 0, 0 }, force = C.FORCE })
  T.register(term, true)
  setup_force()
  U.force().set_spawn_position({ 0, 8 }, surface)
  W.refresh_signs()
  game.map_settings.enemy_expansion.enabled = false
  U.force().chart(surface, { { -96, -96 }, { 96, 96 } })
end

-- Put a player on the island with a character.
function SF.place_player(player)
  local surface = U.surface()
  if not surface then return end
  if player.controller_type == defines.controllers.cutscene then return end
  -- Out of the map view and any vehicle first, or a cross-surface teleport can fail.
  if player.controller_type == defines.controllers.remote then player.exit_remote_view() end
  if player.character and player.character.vehicle then player.character.set_driving(false, true) end
  local pos = surface.find_non_colliding_position("character", { 0, 8 }, 20, 0.5) or { 0, 8 }
  if not player.character then
    if player.controller_type ~= defines.controllers.character then
      local c = surface.create_entity({ name = "character", position = pos, force = C.FORCE })
      if c then player.set_controller({ type = defines.controllers.character, character = c }) end
    end
  end
  if player.surface ~= surface or not player.character then
    player.teleport(pos, surface)
  end
end

-- ------------------------------------------------------- next shift ---

local function hot_count(n)
  return n >= 5 and C.HOT_COUNT_LATE or C.HOT_COUNT
end

-- Work out the upcoming shift (quota, length, conditions, hot items).
-- keep = recompute quota and length but keep the previewed conditions and
-- hot items (after a corporate deal). A Hazard Waiver adds one condition.
-- Length (seconds) and quota of shift n of the run, before conditions and deals.
-- The table covers 8 shifts; longer runs grow LONG_GROWTH a shift, endless ENDLESS_GROWTH.
local function run_row(n)
  local rows = #C.SHIFTS
  local function row(i)
    if i <= rows then return C.SHIFTS[i].len, C.SHIFTS[i].quota end
    return C.SHIFTS[rows].len, C.SHIFTS[rows].quota * C.LONG_GROWTH ^ (i - rows)
  end
  local final = R.final()
  if n <= final then return row(n) end
  local _, q = row(final)
  return C.ENDLESS_LEN, q * C.ENDLESS_GROWTH ^ (n - final)
end
SF.run_row = run_row

function SF.prepare_next(keep)
  local q = storage.q
  local n = q.repeat_shift and q.shift or (q.shift + 1)
  local rules = R.get()
  local len, quota = run_row(n)
  quota = quota * R.diff().quota * (rules.quota_scale or 1)
  if R.complex() then quota = quota * (1 + C.COMPLEX_QUOTA_STEP * math.max(0, n - 3)) end
  len = len * (rules.shift_len or 1)
  quota = quota * q.quota_mult + (q.perf_adjust or 0)
  if q.next_quota_mult then quota = quota * q.next_quota_mult end
  local conds
  -- A new condition (Picky Client) can change how many hot items there are.
  local keep_hot = keep and q.next and not q.add_condition_now
  if keep and q.next then
    conds = K.filter(q.next.conditions)
    if q.add_condition_now then K.add_one(n, conds) end
  else
    conds = K.roll(n)
  end
  q.add_condition_now = nil
  len, quota = K.adjust(conds, len, quota)
  local hot, order, insider
  if keep_hot then
    hot, order, insider = q.next.hot, q.next.hot_order, q.next.insider
  else
    local avoid = {}
    for name in pairs(q.hot) do avoid[name] = true end
    hot, order = M.roll_hot(hot_count(n) + K.extra_hot(conds), avoid)
  end
  q.next = {
    n = n, len = math.floor(len), quota = U.round_nice(quota),
    conditions = conds, hot = hot, hot_order = order, insider = insider,
  }
  M.sync_insider(q.next)
end

-- Bonus for clocking in before the break timer runs out.
function SF.early_bonus()
  local q = storage.q
  if q.phase ~= "break" or not q.next then return 0 end
  local secs = math.max(0, math.floor((q.break_end - game.tick) / 60))
  local mult = P.has("earlybird") and 3 or 1
  return math.floor(secs * C.EARLY_BIRD_RATE * q.next.quota * mult)
end
HUD.early_bonus = SF.early_bonus
CAT.early_bonus = SF.early_bonus

-- Quota met: end the shift now for a bonus on the time left. Never on the final (Audit) shift.
function SF.clock_out_bonus()
  local q = storage.q
  if q.phase ~= "shift" or q.shipped < q.quota then return 0 end
  if q.cond_active.audit or (q.shift == R.final() and not q.endless) then return 0 end
  local secs = math.floor((q.shift_end - game.tick) / 60)
  if secs < C.CLOCK_OUT_MIN_SECS then return 0 end
  return math.floor(math.min(C.CLOCK_OUT_CAP, secs * C.CLOCK_OUT_RATE) * q.quota)
end
HUD.clock_out_bonus = SF.clock_out_bonus

function SF.clock_out()
  local q = storage.q
  local bonus = SF.clock_out_bonus()
  if bonus <= 0 then return false end
  q.clocked_out = bonus
  q.stats.clock_outs = (q.stats.clock_outs or 0) + 1
  q.shift_end = game.tick
  U.company({ "", "Clocked out early with ", U.money(bonus), " for the time left." })
  SF.end_shift()
  return true
end

-- ---------------------------------------------------------------- run ---

-- rules: a table from Run Setup (lib/rules.lua shape), a difficulty id (tests), or nil
-- for whatever the mod settings say.
function SF.start_run(rules)
  local q = storage.q
  if q.phase ~= "orientation" then return end
  if type(rules) == "string" then
    local id = rules
    rules = R.read()
    if C.DIFFICULTIES[id] then rules.difficulty = id end
  end
  q.rules = R.copy(rules or R.read())
  if not R.MODES[q.rules.mode] then q.rules.mode = "simple" end
  if not C.DIFFICULTIES[q.rules.difficulty] then q.rules.difficulty = "associate" end
  local diff = R.diff()
  q.difficulty = q.rules.difficulty
  q.warnings_left = R.warnings()
  q.run_started = game.tick
  q.shift = 0
  Z.apply()
  SF.prepare_next(false)
  for _, p in pairs(U.players()) do
    SF.place_player(p)
    if p.character then
      for _, it in ipairs(C.CHARACTER_KIT) do
        p.insert({ name = it[1], count = it[2] })
      end
    end
  end
  D.drop(C.STARTER_KIT, { label = "Starter Kit" })
  U.company({ "", "Welcome aboard. ", R.mode_def().name, " mode, ", diff.name, ", ", R.final(),
    " shifts. Your starter kit is on its way down. Shift 1 starts in ",
    C.BRIEFING_SECONDS, " seconds: grab the kit, look around, clock in when you're ready." })
  if R.complex() then
    U.company("Zoning is in force: oil and plastics need 2 plots of land, chemical science 4, production science 6.")
  end
  SF.start_briefing()
end

-- The look-around before shift 1: a short break with no report, no
-- contracts and no Break Room popping up. The clock waits; clocking in early pays.
function SF.start_briefing()
  local q = storage.q
  q.phase = "break"
  q.briefing = true
  q.break_len = C.BRIEFING_SECONDS * 60
  q.break_end = game.tick + q.break_len
  q.offers = {}
  T.refresh_labels()
  GM.refresh_all(true)
end

function SF.start_shift()
  local q = storage.q
  local nx = q.next
  if not nx then SF.prepare_next(false) nx = q.next end
  q.shift = nx.n
  q.repeat_shift = nil
  q.quota = nx.quota
  q.shift_len = nx.len * 60
  q.shipped = 0
  q.quota_met = false
  q.quota_met_tick = nil
  q.shift_start = game.tick
  q.shift_end = game.tick + q.shift_len
  M.sync_insider(nx)
  q.hot, q.hot_order, q.hot_insider = nx.hot, nx.hot_order, nx.insider
  q.hot_sig = (q.hot_sig or 0) + 1
  q.conditions = nx.conditions
  q.shift_sales, q.shift_credits, q.shift_distinct = {}, {}, 0
  q.monopoly_item = nil
  q.next_quota_mult = nil
  q.perf_adjust = 0
  q.next = nil
  q.corporate = nil
  q.phase = "shift"

  K.start(q.conditions)
  P.apply()
  H.start(q.cond_active, q.shift_len)
  E.start_shift()
  if q.cond_active.audit then AU.start() end
  T.refresh_labels()

  S.play("quota-whistle", 1)
  local names = {}
  for _, id in ipairs(q.conditions) do names[#names + 1] = K.BY_ID[id].name end
  U.company({ "", "[font=default-large-bold]SHIFT ", q.shift, "[/font]  Quota ", U.money(q.quota), " in ",
    U.time(q.shift_len), #names > 0 and (".  Conditions: " .. table.concat(names, ", ")) or ".", "  Clock's ticking." })
  GM.refresh_all(true)
end

-- Hot Potato.
function SF.reroll_hot()
  local q = storage.q
  local avoid = {}
  for name in pairs(q.hot) do avoid[name] = true end
  local t = {}
  t.hot, t.hot_order = M.roll_hot(math.max(1, #q.hot_order - (q.hot_insider and 1 or 0)), avoid)
  M.sync_insider(t)
  q.hot, q.hot_order, q.hot_insider = t.hot, t.hot_order, t.insider
  q.hot_sig = (q.hot_sig or 0) + 1
  local list = {}
  for _, n in ipairs(q.hot_order) do list[#list + 1] = "[item=" .. n .. "]" end
  U.company("Hot Potato! The hot items are now " .. table.concat(list, " "))
  S.jingle("event_good")
end

local function add_line(rep, text, amount, color)
  rep.lines[#rep.lines + 1] = { text, amount, color = color }
end

function SF.end_shift()
  local q = storage.q
  if q.phase ~= "shift" then return end
  local was_audit = q.cond_active.audit
  K.stop()
  P.apply()
  H.stop()
  if was_audit then AU.stop() end
  E.reset()

  local met = q.shipped >= q.quota
  local best, best_v = M.best_seller()
  local rep = { n = q.shift, quota = q.quota, shipped = q.shipped, met = met, lines = {}, best = best, best_v = best_v, payday = 0 }
  q.last_best = best
  q.last_conditions = q.conditions
  local payday = 0
  local outcome = "continue"

  if met then
    local excess = q.shipped - q.quota
    local rate = C.OVERTIME_RATE * (P.has("handshake") and 2 or 1)
    local ot = excess * rate
    if ot >= 1 then
      add_line(rep, "Overtime (" .. U.pct(rate) .. " of the excess)", ot)
      payday = payday + ot
    end
    if q.shipped > C.PERFORMANCE_TRIGGER * q.quota then
      q.perf_adjust = (q.shipped - C.PERFORMANCE_TRIGGER * q.quota) * C.PERFORMANCE_TAKE
      add_line(rep, "Performance review: you did so well, next quota +" .. U.money(q.perf_adjust), nil, { 1, 0.7, 0.4 })
    end
    if P.has("workaholic") and q.quota_met_tick and q.shift_end - q.quota_met_tick >= 60 * 60 then
      q.perk_state.workaholic = (q.perk_state.workaholic or 0) + 1
      add_line(rep, "Workaholic: prices +" .. (6 * q.perk_state.workaholic) .. "% for good", nil, { 0.6, 0.9, 1 })
    end
    if q.clocked_out then
      add_line(rep, "Clocked out early", q.clocked_out)
      payday = payday + q.clocked_out
    end
    if q.shift == R.final() and not q.endless then outcome = "promoted" end
  else
    if P.has("parachute") then
      local keep = {}
      for _, id in ipairs(q.perks) do if id ~= "parachute" then keep[#keep + 1] = id end end
      q.perks = keep
      P.apply()
      add_line(rep, "Golden Parachute deployed. No warning this time.", nil, { 1, 0.8, 0.3 })
    elseif q.warnings_left > 0 then
      q.warnings_left = q.warnings_left - 1
      add_line(rep, "WRITTEN WARNING. Warnings left: " .. q.warnings_left, nil, { 1, 0.4, 0.35 })
    else
      outcome = "fired"
    end
    if outcome ~= "fired" and q.shift == R.final() and not q.endless then
      q.repeat_shift = true
      add_line(rep, "The final shift is not over. You'll redo shift " .. q.shift .. ".", nil, { 1, 0.6, 0.4 })
    end
  end

  q.clocked_out = nil
  if outcome ~= "fired" then q.stats.shifts_done = (q.stats.shifts_done or 0) + 1 end
  M.decay_flood()
  q.report = rep

  if outcome == "fired" then
    q.phase = "fired"
    T.refresh_labels()
    S.play("quota-trombone", 1)
    U.company({ "", "[color=255,90,80][font=default-large-bold]YOU'RE FIRED.[/font][/color] Shipped ",
      U.money(q.shipped), " of ", U.money(q.quota), "." })
    GM.refresh_all(true)
    return
  end
  if outcome == "promoted" then
    rep.payday = payday
    if payday > 0 then L.bonus(payday) end
    q.phase = "promoted"
    T.refresh_labels()
    S.jingle("promoted")
    U.company("[color=255,200,70][font=default-large-bold]PROMOTED![/font][/color] You survived The Audit.")
    GM.refresh_all(true)
    return
  end

  SF.prepare_next(false)
  if P.has("interest") then
    local i = math.min(q.wallet * 0.1, q.next.quota * 0.5)
    if i >= 1 then
      add_line(rep, "Compound interest (10% of wallet)", i)
      payday = payday + i
    end
  end
  if P.has("pyramid") then
    local pv = 0.06 * q.quota * P.count()
    add_line(rep, "Pyramid scheme (" .. P.count() .. " contracts)", pv)
    payday = payday + pv
  end
  rep.payday = payday
  if payday > 0 then L.bonus(payday) end
  SF.start_break(met)
end

function SF.start_break(met)
  local q = storage.q
  q.phase = "break"
  q.briefing = nil
  q.break_len = R.break_secs() * 60
  q.break_end = game.tick + q.break_len
  q.rerolls = 0
  SH.roll_offers()
  local corp = q.shift > 0 and q.shift % 3 == 0 and q.shift < R.final()
  if corp and not q.corporate_seen[q.shift] and not q.endless then
    q.corporate_seen[q.shift] = true
    SH.roll_corporate()
  end
  T.refresh_labels()
  if met then
    S.jingle("payday")
    U.company({ "", "Shift ", q.report.n, " done: ", U.money(q.report.shipped), " shipped. Take a break. Next shift in ",
      R.break_secs(), " seconds." })
  else
    S.jingle("warn")
    U.company({ "", "[color=255,90,80]Quota missed.[/color] This goes in your file." })
  end
  GM.refresh_all(true)
end

function SF.clock_in(early)
  local q = storage.q
  if q.phase ~= "break" then return end
  if early then
    local bonus = SF.early_bonus()
    if bonus > 0 then
      L.bonus(bonus)
      U.company({ "", "Early bird bonus: +", U.money(bonus) })
    end
  end
  q.briefing = nil
  SF.start_shift()
end

-- After a corporate deal changes quotas or conditions, redo the preview.
function SF.reprepare()
  local q = storage.q
  if q.phase ~= "break" then return end
  SF.prepare_next(true)
end

function SF.go_endless()
  local q = storage.q
  if q.phase ~= "promoted" then return end
  q.endless = true
  SF.prepare_next(false)
  SF.start_break(true)
end

function SF.retire()
  local q = storage.q
  q.phase = "retired"
  T.refresh_labels()
  U.company("Retired. The terminals still buy whatever you make. Enjoy the island.")
  GM.refresh_all(true)
end

-- --------------------------------------------------------------- tick ---

function SF.tick_second()
  local q = storage.q
  if q.phase == "shift" then
    K.tick(SF.reroll_hot)
    H.tick()
    E.tick()
    if q.cond_active.audit then AU.tick() end
    local left = q.shift_end - game.tick
    if left > 0 and left <= 10 * 60 then S.jingle("tick") end
    if game.tick >= q.shift_end then SF.end_shift() end
  elseif q.phase == "break" then
    local left = q.break_end - game.tick
    if left > 0 and left <= 5 * 60 then S.jingle("tick") end
    if game.tick >= q.break_end then SF.clock_in(false) end
  end
end

-- ------------------------------------------------------------ reapply ---

function SF.reapply()
  local old = storage.q
  local old_surface = U.surface()
  for _, p in pairs(game.players) do GM.destroy_all(p) end
  W.clear_signs()
  storage.q = SF.fresh_state(old)
  local force = U.force()
  force.reset()
  force.reset_evolution()
  SF.new_world()
  for _, p in pairs(game.players) do
    if p.character then p.character.clear_items_inside() end
    local inv = p.get_main_inventory()
    if inv then inv.clear() end
    p.clear_cursor()
    SF.place_player(p)
  end
  if old_surface and old_surface.valid then game.delete_surface(old_surface) end
  GM.refresh_all(true)
end

return SF
