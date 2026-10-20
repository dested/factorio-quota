-- QUOTA: The Factory Must Grow (Or Else)
-- Event wiring, the GUI action router, and the "quota" remote interface
-- that the automated test drives.

local C = require("lib.config")
local U = require("lib.util")
local P = require("lib.perks")
local W = require("lib.world")
local S = require("lib.sfx")
local A = require("lib.anim")
local T = require("lib.terminals")
local H = require("lib.hazards")
local E = require("lib.events")
local AU = require("lib.auditor")
local SH = require("lib.shop")
local SF = require("lib.shift")
local G = require("lib.gui.common")
local GM = require("lib.gui.main")
local HUD = require("lib.gui.hud")
local CAT = require("lib.gui.catalog")
local SC = require("lib.gui.screens")
local M = require("lib.market")
local V = require("lib.values")
local L = require("lib.ledger")
local R = require("lib.rules")
local Z = require("lib.zoning")
local HB = require("lib.gui.handbook")
local MP = require("lib.gui.market_panel")

-- Errors in a handler are logged and printed once instead of ending the game.
local seen_errors = {}
local function guard(name, fn)
  return function(event)
    local ok, err = pcall(fn, event)
    if not ok then
      local msg = "[quota] " .. name .. ": " .. tostring(err)
      log(msg)
      if game and not seen_errors[msg] then
        seen_errors[msg] = true
        game.print(msg, { color = { 1, 0.3, 0.3 } })
      end
    end
  end
end

local function ready()
  return storage.q ~= nil and storage.q.surface_index ~= nil
end

-- ------------------------------------------------------------ freeplay ---

local function quiet_freeplay()
  local fp = remote.interfaces["freeplay"]
  if not fp then return end
  if fp.set_skip_intro then remote.call("freeplay", "set_skip_intro", true) end
  if fp.set_disable_crashsite then remote.call("freeplay", "set_disable_crashsite", true) end
  if fp.set_created_items then remote.call("freeplay", "set_created_items", {}) end
  if fp.set_respawn_items then remote.call("freeplay", "set_respawn_items", {}) end
  if fp.set_chart_distance then remote.call("freeplay", "set_chart_distance", 0) end
end

-- ---------------------------------------------------------------- init ---

-- QUOTA runs in its own scenario (New Game > Scenarios > QUOTA) and stays dormant in every other
-- game, so the mod can sit in a normal mod list. The test harnesses (and the dev launcher's
-- quota-dev marker mod) run it on a plain --create map instead.
local DEV_MODS = { "quota-autotest", "quota-shots", "quota-dev" }
local function wanted()
  local level = script.level
  if level and level.mod_name == "quota" then return true end
  for _, name in ipairs(DEV_MODS) do
    if script.active_mods[name] then return true end
  end
  return false
end

script.on_init(guard("on_init", function()
  if not wanted() then
    log("QUOTA dormant: not the QUOTA scenario")
    return
  end
  log("QUOTA active")
  storage.q = SF.fresh_state(nil)
  local seed = 1
  local nauvis = game.surfaces["nauvis"]
  if nauvis then seed = nauvis.map_gen_settings.seed end
  U.seed(seed + 9001)
  SF.new_world()
  quiet_freeplay()
end))

script.on_configuration_changed(guard("on_configuration_changed", function()
  if not ready() then return end
  local q = storage.q
  -- v1 saves: rules from the settings plus the run's difficulty; the property counter is gone.
  if not q.rules then
    q.rules = R.read()
    if q.difficulty and C.DIFFICULTIES[q.difficulty] then q.rules.difficulty = q.difficulty end
  end
  q.gifted = nil
  q.zoned = q.zoned or {}
  q.tech_tiers = nil
  V.refresh()
  P.apply()
  if q.phase ~= "orientation" then Z.apply() end
  U.force().create_ghost_on_entity_death = true
  GM.refresh_all(false)
end))

-- -------------------------------------------------------------- intro ---

local function intro(player)
  local surface = U.surface()
  if not (surface and player.character) then
    GM.refresh(player, true)
    return
  end
  local ok = pcall(function()
    player.set_controller({
      type = defines.controllers.cutscene,
      start_position = { 0, -10 },
      start_zoom = 0.35,
      waypoints = {
        { position = { 0, -4 }, transition_time = 30, time_to_wait = 100, zoom = 0.32 },
        { target = player.character, transition_time = 120, time_to_wait = 20, zoom = 0.9 },
      },
      final_transition_time = 30,
    })
  end)
  if not ok then GM.refresh(player, true) end
end

local function finish_intro(event)
  local player = game.get_player(event.player_index)
  if player and ready() then GM.refresh(player, true) end
end

script.on_event(defines.events.on_cutscene_finished, guard("cutscene_finished", finish_intro))
script.on_event(defines.events.on_cutscene_cancelled, guard("cutscene_cancelled", finish_intro))

-- ------------------------------------------------------------ players ---

script.on_event(defines.events.on_player_created, guard("on_player_created", function(event)
  if not ready() then return end
  quiet_freeplay()
  local player = game.get_player(event.player_index)
  if not player then return end
  SF.place_player(player)
  if storage.q.phase == "orientation" and not storage.q.skip_intro then
    intro(player)
  else
    GM.refresh(player, true)
  end
end))

script.on_event(defines.events.on_player_respawned, guard("on_player_respawned", function(event)
  if not ready() then return end
  local player = game.get_player(event.player_index)
  if player then SF.place_player(player) end
end))

script.on_event(defines.events.on_player_display_resolution_changed, guard("resolution", function(event)
  if not ready() then return end
  local player = game.get_player(event.player_index)
  if player then
    HUD.reposition(player)
    if player.gui.screen["quota_orientation"] then SC.orientation(player) end
  end
end))
script.on_event(defines.events.on_player_display_scale_changed, guard("scale", function(event)
  if not ready() then return end
  local player = game.get_player(event.player_index)
  if player then
    HUD.reposition(player)
    if player.gui.screen["quota_orientation"] then SC.orientation(player) end
  end
end))

-- -------------------------------------------------------------- world ---

script.on_event(defines.events.on_chunk_generated, guard("on_chunk_generated", function(event)
  if not ready() then return end
  W.on_chunk_generated(event)
end))

local function on_built(event)
  if not ready() then return end
  local e = event.entity
  if e and e.valid and e.name == "quota-terminal" and e.surface == U.surface() then
    T.register(e, false)
  end
end
local built_filter = { { filter = "name", name = "quota-terminal" } }
script.on_event(defines.events.on_built_entity, guard("on_built_entity", on_built), built_filter)
script.on_event(defines.events.on_robot_built_entity, guard("on_robot_built_entity", on_built), built_filter)
script.on_event(defines.events.script_raised_built, guard("script_raised_built", on_built), built_filter)

local function on_removed(event)
  if not ready() then return end
  local e = event.entity
  if not (e and e.valid) then return end
  local u = e.unit_number
  if u then
    if storage.q.terminals[u] then T.unregister(u) end
    if storage.q.disabled[u] or storage.q.hz.gremlins[u] then H.forget(u) end
  end
end
script.on_event(defines.events.on_player_mined_entity, guard("on_player_mined_entity", on_removed))
script.on_event(defines.events.on_robot_mined_entity, guard("on_robot_mined_entity", on_removed))
script.on_event(defines.events.script_raised_destroy, guard("script_raised_destroy", on_removed))

script.on_event(defines.events.on_entity_died, guard("on_entity_died", function(event)
  if not ready() then return end
  local e = event.entity
  if not (e and e.valid) then return end
  if e.name == "quota-auditor" then
    AU.on_died(e)
    return
  end
  if e.force.name == "enemy" then
    H.on_enemy_died(e, event.force)
    return
  end
  on_removed(event)
end))

script.on_event(defines.events.on_script_trigger_effect, guard("on_script_trigger_effect", function(event)
  if not ready() then return end
  if event.effect_id == "quota-meteor-impact" then
    H.on_meteor_impact(event.target_position)
  end
end))

-- -------------------------------------------------------------- ticks ---

script.on_event(defines.events.on_tick, guard("on_tick", function()
  if not ready() then return end
  A.tick()
  S.tick()
end))

script.on_nth_tick(10, guard("nth_10", function()
  if not ready() then return end
  H.fast_tick()
end))

script.on_nth_tick(30, guard("nth_30", function()
  if not ready() then return end
  T.sweep()
  GM.update_all()
end))

script.on_nth_tick(60, guard("nth_60", function()
  if not ready() then return end
  SF.tick_second()
end))

-- ---------------------------------------------------------------- GUI ---

local function after_buy(player, ok, msg)
  G.notify(player, msg or "", ok)
  if ok then
    CAT.rebuild(player)
    GM.update_all()
  end
end

local ACT = {}

ACT.toggle_catalog = function(p)
  local phase = storage.q.phase
  if phase == "shift" or phase == "break" or phase == "retired" then CAT.toggle(p)
  elseif phase == "fired" or phase == "promoted" then SC.end_screen(p) end
end
ACT.close_catalog = function(p) CAT.close(p) end
ACT.clock_in = function() SF.clock_in(true) end
-- Two clicks within 5 s: the first arms, the second clocks out.
ACT.clock_out = function(p)
  local s = G.ui(p)
  if s.clockout_armed and game.tick - s.clockout_armed < 5 * 60 then
    s.clockout_armed = nil
    SF.clock_out()
  else
    s.clockout_armed = game.tick
    HUD.update(p)
  end
end
-- Writing the rules back raises on_runtime_mod_setting_changed; this marks our own writes.
local writing_rules = false
local function write_setting(fn)
  writing_rules = true
  local ok, err = pcall(fn)
  writing_rules = false
  if not ok then error(err) end
end

ACT.start_run = function(p)
  local draft = SC.setup_draft(p)
  write_setting(function() R.write(draft) end)
  SF.start_run(R.copy(draft))
  for _, pl in pairs(game.players) do G.ui(pl).setup = nil end
end

-- Run Setup edits the draft, then redraws.
local function setup_edit(p, fn)
  if storage.q.phase ~= "orientation" then return end
  fn(SC.setup_draft(p))
  SC.orientation(p)
  HB.rebuild(p)
end
ACT.setup_mode = function(p, t) setup_edit(p, function(d) if R.MODES[t.id] then d.mode = t.id end end) end
ACT.setup_diff = function(p, t) setup_edit(p, function(d) if C.DIFFICULTIES[t.id] then d.difficulty = t.id end end) end
ACT.setup_preset = function(p, t) setup_edit(p, function(d) d.off = R.preset_off(t.id) end) end
ACT.setup_switch = function(p, t, event)
  local on = event.element.state
  setup_edit(p, function(d) d.off[t.key] = (not on) or nil end)
end
ACT.setup_knob = function(p, t, event)
  setup_edit(p, function(d)
    for _, k in ipairs(R.KNOBS) do
      if k.key == t.key then
        local v = k.choices[event.element.selected_index]
        if v ~= nil then d[k.key] = v end
      end
    end
  end)
end

ACT.open_handbook = function(p) HB.open(p) end
ACT.close_handbook = function(p)
  HB.close(p)
  local cat = p.gui.screen["quota_catalog"]
  if cat and cat.valid then p.opened = cat end
end
-- A Handbook switch: the draft before a run, the mod setting during one (applies next shift).
ACT.handbook_switch = function(p, t, event)
  local on = event.element.state
  if storage.q.phase == "orientation" then
    setup_edit(p, function(d) d.off[t.key] = (not on) or nil end)
    return
  end
  write_setting(function() settings.global[R.setting_name(t.key)] = { value = on } end)
  R.refresh_live()
  SF.reprepare()
  local sw = R.SWITCH_BY_KEY[t.key]
  U.company({ "", SC.switch_name(sw), on and " switched on" or " switched off", " from the next shift." })
  GM.refresh_all(false)
end
ACT.toggle_market = function(p) MP.toggle(p) end

ACT.buy_contract = function(p, t) after_buy(p, SH.buy_contract(t.id)) end
ACT.sell_contract = function(p, t) after_buy(p, SH.sell_contract(t.id)) end
ACT.reroll = function(p) after_buy(p, SH.reroll()) end
ACT.buy_rnd = function(p, t) after_buy(p, SH.buy_rnd(t.id)) end
ACT.buy_upgrade = function(p, t) after_buy(p, SH.buy_upgrade(t.id)) end
ACT.buy_crate = function(p, t) after_buy(p, SH.buy_crate(t.id)) end
ACT.buy_mystery = function(p) after_buy(p, SH.buy_mystery()) end
ACT.buy_terminal = function(p) after_buy(p, SH.buy_terminal()) end
ACT.select_plot = function(p, t)
  local s = G.ui(p)
  local key = W.key(t.px, t.py)
  s.plot = s.plot ~= key and key or nil
  CAT.rebuild(p)
end
ACT.buy_plot = function(p, t) after_buy(p, SH.buy_plot(t.px, t.py)) end

ACT.show_corporate = function(p) SC.corporate(p) end
ACT.close_corporate = function(p) SC.close_corporate(p) end
ACT.corp_accept = function(p, t)
  local ok, msg = SH.accept_corporate(t.id)
  G.notify(p, msg, ok)
  if ok then
    SF.reprepare()
    for _, pl in pairs(U.players()) do
      SC.close_corporate(pl)
      GM.refresh(pl, false)
    end
  end
end
ACT.corp_decline = function(p)
  SH.decline_corporate()
  for _, pl in pairs(U.players()) do
    SC.close_corporate(pl)
    GM.refresh(pl, false)
  end
end

ACT.reapply = function() SF.reapply() end
ACT.go_endless = function() SF.go_endless() end
ACT.retire = function() SF.retire() end
ACT.close_end = function(p)
  SC.close_end(p)
  p.print("Press J to bring the report back.")
end

script.on_event(defines.events.on_gui_click, guard("on_gui_click", function(event)
  if not ready() then return end
  local el = event.element
  if not (el and el.valid) then return end
  local tags = el.tags
  local action = tags and tags.qa
  if not action or action == "tab" then return end
  -- Drop-downs and checkboxes act on their own events. Handling the click too would redraw the
  -- screen under an open drop-down list (it locked up the GUI).
  if el.type == "drop-down" or el.type == "checkbox" then return end
  local fn = ACT[action]
  local player = game.get_player(event.player_index)
  if fn and player then fn(player, tags, event) end
end))

-- Checkboxes and drop-downs route through the same table.
local function routed(event)
  if not ready() then return end
  local el = event.element
  if not (el and el.valid) then return end
  local tags = el.tags
  local fn = tags and tags.qa and ACT[tags.qa]
  local player = game.get_player(event.player_index)
  if fn and player then fn(player, tags, event) end
end
script.on_event(defines.events.on_gui_checked_state_changed, guard("on_gui_checked_state_changed", routed))
script.on_event(defines.events.on_gui_selection_state_changed, guard("on_gui_selection_state_changed", routed))

script.on_event(defines.events.on_gui_selected_tab_changed, guard("on_gui_selected_tab_changed", function(event)
  if not ready() then return end
  local el = event.element
  if el and el.valid and el.tags and el.tags.qa == "tab" then
    local player = game.get_player(event.player_index)
    if player then G.ui(player).tab = el.selected_tab_index end
  elseif el and el.valid and el.tags and el.tags.qa == "hb_tab" then
    local player = game.get_player(event.player_index)
    if player then G.ui(player).hb_tab = el.selected_tab_index end
  end
end))

script.on_event(defines.events.on_gui_closed, guard("on_gui_closed", function(event)
  if not ready() then return end
  local el = event.element
  local player = game.get_player(event.player_index)
  if not (player and el and el.valid) then return end
  if el.name == "quota_catalog" then
    -- Opening the Handbook from the Catalog takes over player.opened; keep the Catalog.
    if not HB.is_open(player) then CAT.close(player) end
  elseif el.name == "quota_handbook" then
    ACT.close_handbook(player)
  end
end))

-- Opening a terminal holds its sale; say so the first few times.
script.on_event(defines.events.on_gui_opened, guard("on_gui_opened", function(event)
  if not ready() then return end
  local e = event.entity
  if not (e and e.valid and e.name == "quota-terminal" and T.selling()) then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local s = G.ui(player)
  s.hold_hints = (s.hold_hints or 0) + 1
  if s.hold_hints <= 3 then
    player.create_local_flying_text({ text = "Sale on hold while open. Close to ship.", create_at_cursor = true,
      color = { 1, 0.8, 0.3 } })
  end
end))

-- ----------------------------------------------------------- settings ---

script.on_event(defines.events.on_runtime_mod_setting_changed, guard("on_runtime_mod_setting_changed", function(event)
  if not ready() then return end
  local name = event.setting
  if name == "quota-hud-position" then
    local player = event.player_index and game.get_player(event.player_index)
    if player and storage.q.phase ~= "orientation" then HUD.build(player) end
    return
  end
  if writing_rules or name:sub(1, 6) ~= "quota-" then return end
  local q = storage.q
  if q.phase == "orientation" then
    -- Map settings changed from the menu: start every draft from them again.
    for _, p in pairs(game.players) do
      G.ui(p).setup = nil
      if p.gui.screen["quota_orientation"] then SC.orientation(p) end
    end
    return
  end
  local locked = R.refresh_live()
  SF.reprepare()
  if locked then
    U.company("Mode, difficulty, run length and warnings are locked for this run; the new values apply to the next one.")
  else
    U.company("Run settings updated. Changes apply from the next shift.")
  end
  for _, p in pairs(game.players) do HB.rebuild(p) end
  GM.refresh_all(false)
end))

script.on_event("quota-toggle-catalog", guard("toggle_catalog", function(event)
  if not ready() then return end
  local player = game.get_player(event.player_index)
  if player then ACT.toggle_catalog(player) end
end))

-- ------------------------------------------------------------- remote ---
-- Used by the automated test. Everything here is also reachable in-game
-- from the console: /c remote.call("quota", "state")

-- Machines a hazard has switched off right now.
local function jammed()
  local surface = U.surface()
  if not surface then return 0 end
  local n = 0
  for _, e in pairs(surface.find_entities_filtered({ force = C.FORCE, type = H.GREMLIN_TYPES })) do
    if e.disabled_by_script then n = n + 1 end
  end
  return n
end

local function summary()
  local q = storage.q
  local terms = 0
  for _ in pairs(q.terminals) do terms = terms + 1 end
  local mults
  if q.next then
    mults = {}
    for name, m in pairs(q.next.hot) do mults[name] = M.boosted(m) end
  end
  return {
    phase = q.phase, shift = q.shift, quota = q.quota, shipped = q.shipped, wallet = q.wallet,
    warnings_left = q.warnings_left, difficulty = q.difficulty, endless = q.endless,
    rules = q.rules, final = R.final(), mode = q.rules and q.rules.mode or nil,
    zoned = Z.bought(), licensed = Z.licensed(),
    conditions = q.conditions, hot = q.hot_order, perks = q.perks, offers = q.offers,
    next = q.next and { n = q.next.n, quota = q.next.quota, len = q.next.len, conditions = q.next.conditions,
      hot = q.next.hot_order, mults = mults, insider = q.next.insider } or nil,
    last_best = q.last_best, jammed = jammed(), briefing = q.briefing,
    plots = W.owned_count(), terminals = terms, gremlins = H.gremlin_count(),
    event = q.ev and q.ev.active and q.ev.active.id or nil,
    auditor = AU.status(), jobs = #q.jobs, tick = game.tick, stats = q.stats,
    corporate = q.corporate, report = q.report,
  }
end

remote.add_interface("quota", {
  state = function() return summary() end,
  dump = function(file)
    helpers.write_file(file or "quota-state.json", helpers.table_to_json(summary()) .. "\n", true)
  end,
  -- A difficulty id or a rules table (lib/rules.lua shape; missing fields come from the settings).
  start = function(rules)
    if type(rules) == "table" then
      local r = R.read()
      for k, v in pairs(rules) do r[k] = v end
      r.off = r.off or {}
      SF.start_run(r)
    else
      SF.start_run(rules or "associate")
    end
  end,
  -- Mid-run: change live rules (switches, knobs) as if from Map settings.
  set_rules = function(fields)
    local r = R.get()
    for k, v in pairs(fields) do r[k] = v end
    if r.off == nil then r.off = {} end
    SF.reprepare()
  end,
  values = function(names)
    local out = {}
    for _, n in ipairs(names) do
      out[n] = { base = V.base(n), depth = V.depth(n), recipe = V.recipe(n), premium = V.premium(n) }
    end
    return out
  end,
  zoning = function()
    local locked = {}
    for _, r in ipairs(SH.RND) do locked[r.id] = SH.rnd_locked(r) or false end
    local tech = {}
    for _, n in ipairs({ "oil-processing", "advanced-circuit", "chemical-science-pack", "production-science-pack" }) do
      local t = U.force().technologies[n]
      tech[n] = t and { enabled = t.enabled, tier = Z.tier(n) } or false
    end
    return { bought = Z.bought(), licensed = Z.licensed(), rnd = locked, tech = tech }
  end,
  -- End the current shift or break at the next second.
  skip = function()
    local q = storage.q
    if q.phase == "shift" then q.shift_end = game.tick + 1 end
    if q.phase == "break" then q.break_end = game.tick + 1 end
  end,
  -- Fast-forward the current shift clock by `secs`.
  advance = function(secs)
    local q = storage.q
    local d = math.floor(secs * 60)
    if q.phase == "shift" then
      q.shift_start = q.shift_start - d
      q.shift_end = q.shift_end - d
    end
  end,
  money = function(n) storage.q.wallet = storage.q.wallet + n end,
  ship = function(amount) L.ship(amount) end,
  clock_in = function() SF.clock_in(true) end,
  clock_out_bonus = function() return SF.clock_out_bonus() end,
  clock_out = function() return SF.clock_out() end,
  fire_event = function(id) return E.fire(id) end,
  buy = function(kind, a, b)
    local ok, msg = (function()
    if kind == "contract" then return SH.buy_contract(a) end
    if kind == "sell" then return SH.sell_contract(a) end
    if kind == "reroll" then return SH.reroll() end
    if kind == "rnd" then return SH.buy_rnd(a) end
    if kind == "upgrade" then return SH.buy_upgrade(a) end
    if kind == "crate" then return SH.buy_crate(a) end
    if kind == "mystery" then return SH.buy_mystery() end
    if kind == "terminal" then return SH.buy_terminal() end
    if kind == "plot" then return SH.buy_plot(a, b) end
    if kind == "corporate" then
      local ok, msg = SH.accept_corporate(a)
      if ok then SF.reprepare() end
      return ok, msg
    end
    return false, "unknown kind"
    end)()
    return { ok = ok, msg = msg }
  end,
  -- Put items straight into the HQ terminal.
  terminal_insert = function(name, count)
    local t = T.hq()
    if not t then return 0 end
    return t.get_inventory(defines.inventory.chest).insert({ name = name, count = count })
  end,
  grant_perk = function(id)
    local q = storage.q
    if P.BY_ID[id] and not P.has(id) then
      q.perks[#q.perks + 1] = id
      q.perk_paid[id] = 0
      P.apply()
      if q.next then M.sync_insider(q.next) end
    end
  end,
  set_conditions = function(ids)
    local q = storage.q
    if q.next then q.next.conditions = ids end
  end,
  hazard = function(kind)
    if kind == "gremlin" then return H.spawn_gremlin() end
    if kind == "meteor" then H.meteor(nil) return true end
    if kind == "quake" then H.quake_now(W.random_land(10)) return true end
    if kind == "raid" then H.schedule_raid() return true end
    return false
  end,
  price = function(name) return M.price(name) end,
  value = function(name) return V.base(name) end,
  reapply = function() SF.reapply() end,
  endless = function() SF.go_endless() end,
  skip_intro = function() storage.q.skip_intro = true end,
  -- Debug: during a break, make the next shift number n.
  jump = function(n)
    local q = storage.q
    if q.phase ~= "break" then return false end
    q.shift = n - 1
    SF.prepare_next(false)
    GM.refresh_all(false)
    return true
  end,
  -- Debug: poke a top-level run field (warnings_left, wallet...).
  set = function(key, value) storage.q[key] = value end,
  -- Open every GUI for a screenshot pass.
  gui = function(which, player_index)
    local player = game.get_player(player_index or 1)
    if not player then return end
    if which == "orientation" then SC.orientation(player)
    elseif which == "handbook" then HB.open(player)
    elseif which == "catalog" then CAT.open(player)
    elseif which == "corporate" then SC.corporate(player)
    elseif which == "end" then SC.end_screen(player)
    elseif which == "close" then GM.destroy_all(player)
    elseif which == "refresh" then GM.refresh(player, false)
    elseif type(which) == "number" then
      G.ui(player).tab = which
      CAT.open(player)
    end
  end,
  select_plot = function(px, py, player_index)
    local player = game.get_player(player_index or 1)
    if player then G.ui(player).plot = W.key(px, py) end
  end,
})
