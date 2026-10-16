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

script.on_init(guard("on_init", function()
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
  V.refresh()
  P.apply()
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
  quiet_freeplay()
  if not ready() then return end
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
  if player then HUD.reposition(player) end
end))
script.on_event(defines.events.on_player_display_scale_changed, guard("scale", function(event)
  if not ready() then return end
  local player = game.get_player(event.player_index)
  if player then HUD.reposition(player) end
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
ACT.start_run = function(p) SF.start_run(G.ui(p).difficulty) end
ACT.difficulty = function(p, t)
  if C.DIFFICULTIES[t.id] then G.ui(p).difficulty = t.id end
  SC.orientation(p)
end

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
  local fn = ACT[action]
  local player = game.get_player(event.player_index)
  if fn and player then fn(player, tags, event) end
end))

script.on_event(defines.events.on_gui_selected_tab_changed, guard("on_gui_selected_tab_changed", function(event)
  if not ready() then return end
  local el = event.element
  if el and el.valid and el.tags and el.tags.qa == "tab" then
    local player = game.get_player(event.player_index)
    if player then G.ui(player).tab = el.selected_tab_index end
  end
end))

script.on_event(defines.events.on_gui_closed, guard("on_gui_closed", function(event)
  if not ready() then return end
  local el = event.element
  if el and el.valid and el.name == "quota_catalog" then
    local player = game.get_player(event.player_index)
    if player then CAT.close(player) end
  end
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
  start = function(difficulty) SF.start_run(difficulty or "associate") end,
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
