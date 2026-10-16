-- Things that go wrong on shift: gremlins, strikes, earthquakes, meteors and
-- raids. Conditions switch them on for a whole shift; events fire single ones.
--
-- Machines are switched off through one ledger (q.disabled) keyed by
-- unit_number with a set of reasons, so a gremlin-jammed inserter stays
-- jammed when the strike that also stopped it ends.

local C = require("lib.config")
local U = require("lib.util")
local W = require("lib.world")
local L = require("lib.ledger")
local P = require("lib.perks")
local S = require("lib.sfx")

local H = {}

local RED = { 1, 0.25, 0.2, 0.8 }

local function hz()
  return storage.q.hz
end

-- ---------------------------------------------------------- disabling ---

function H.disable(entity, reason, label)
  local q = storage.q
  local u = entity.unit_number
  if not u then return end
  local d = q.disabled[u] or { entity = entity, reasons = {} }
  d.reasons[reason] = label
  q.disabled[u] = d
  entity.disabled_by_script = true
  entity.custom_status = { diode = defines.entity_status_diode.red, label = label }
end

function H.enable(u, reason)
  local q = storage.q
  local d = q.disabled[u]
  if not d then return end
  d.reasons[reason] = nil
  local e = d.entity
  if not (e and e.valid) then
    q.disabled[u] = nil
    return
  end
  local _, label = next(d.reasons)
  if label then
    e.custom_status = { diode = defines.entity_status_diode.red, label = label }
  else
    e.disabled_by_script = false
    e.custom_status = nil
    q.disabled[u] = nil
  end
end

-- Remove a gremlin and its visuals; the machine keeps its other disable reasons.
local function drop_gremlin(u)
  local q = storage.q
  local g = q.hz.gremlins[u]
  if g then
    for _, o in pairs({ g.sprite, g.bang, g.chart }) do
      if o and o.valid then o.destroy() end
    end
    q.hz.gremlins[u] = nil
  end
end

-- An entity left the world (mined or destroyed).
function H.forget(u)
  storage.q.disabled[u] = nil
  drop_gremlin(u)
end

-- ------------------------------------------------------------- reset ---

function H.reset()
  storage.q.hz = {
    gremlins = {},
    gremlin_next = nil,
    strike = nil,
    quakes = nil,
    meteor_next = nil,
    raid = nil,
    raid_spots = {},
  }
end

-- --------------------------------------------------------- gremlins ---

local GREMLIN_TYPES = { "assembling-machine", "furnace", "mining-drill", "inserter", "lab" }
H.GREMLIN_TYPES = GREMLIN_TYPES

local function gremlin_count()
  local n = 0
  for _ in pairs(hz().gremlins) do n = n + 1 end
  return n
end

local function jam(entity)
  local q = storage.q
  local surface = entity.surface
  H.disable(entity, "gremlin", "GREMLIN! Walk up to it to whack it")
  local sprite = rendering.draw_sprite({
    sprite = "entity/small-biter", surface = surface, target = { entity = entity, offset = { 0, -0.4 } },
    tint = { 0.45, 1, 0.3, 1 }, x_scale = 1.3, y_scale = 1.3, render_layer = "air-object",
  })
  local bang = rendering.draw_text({
    text = "!", surface = surface, target = { entity = entity, offset = { 0.9, -1.6 } },
    color = { 1, 0.3, 0.2 }, scale = 2.2, font = "default-bold", alignment = "center", blink_interval = 20,
  })
  local chart = rendering.draw_circle({
    surface = surface, target = entity, radius = 4, color = { 0.45, 1, 0.3, 0.9 }, filled = true,
    render_mode = "chart",
  })
  q.hz.gremlins[entity.unit_number] = {
    entity = entity, sprite = sprite, bang = bang, chart = chart,
    spread_at = game.tick + C.GREMLIN_SPREAD_AFTER, born = game.tick,
  }
end

local function candidates(surface, area)
  return surface.find_entities_filtered({ force = C.FORCE, type = GREMLIN_TYPES, area = area })
end

function H.spawn_gremlin()
  local surface = U.surface()
  if not surface or gremlin_count() >= C.GREMLIN_MAX then return false end
  local list = candidates(surface, nil)
  if #list == 0 then return false end
  local pick
  for _ = 1, 12 do
    local e = U.pick(list)
    if e and e.valid and e.unit_number and not hz().gremlins[e.unit_number] then
      pick = e
      if e.status == defines.entity_status.working then break end
    end
  end
  if not pick then return false end
  jam(pick)
  S.play("quota-buzzer", 0.4)
  U.fly("A gremlin got in!", { x = pick.position.x, y = pick.position.y - 2 }, U.COLORS.green, surface, 150)
  return true
end

local function whack(u, g, player)
  local q = storage.q
  local e = g.entity
  local pos = e.valid and e.position or player.position
  drop_gremlin(u)
  H.enable(u, "gremlin")
  local bounty = math.max(10, (q.quota or 0) * C.GREMLIN_BOUNTY)
  if P.has("dangerpay") then bounty = bounty * 3 end
  L.bonus(bounty)
  q.stats.gremlins = (q.stats.gremlins or 0) + 1
  S.jingle("whack")
  local surface = U.surface()
  if surface then
    surface.create_entity({ name = "blood-explosion-small", position = pos })
  end
  U.fly("WHACK! +" .. U.money(bounty), { x = pos.x, y = pos.y - 1.5 }, U.COLORS.green, surface, 120)
end

local function gremlin_fast()
  local q = storage.q
  local list = U.players()
  for u, g in pairs(q.hz.gremlins) do
    local e = g.entity
    if not (e and e.valid) then
      H.forget(u)
    else
      -- Wiggle.
      if g.sprite and g.sprite.valid then
        g.sprite.orientation = (math.sin(game.tick / 6 + u) * 0.04) % 1
      end
      for _, p in ipairs(list) do
        -- The character, not p.position: that follows the map camera.
        local c = p.character
        if c and c.surface == e.surface
          and U.dist2(c.position, e.position) <= C.GREMLIN_WHACK_RADIUS * C.GREMLIN_WHACK_RADIUS then
          whack(u, g, p)
          break
        end
      end
    end
  end
end

local function gremlin_spread()
  local q = storage.q
  for _, g in pairs(q.hz.gremlins) do
    local e = g.entity
    if e and e.valid and game.tick >= g.spread_at and gremlin_count() < C.GREMLIN_MAX then
      g.spread_at = game.tick + C.GREMLIN_SPREAD_AFTER
      local p = e.position
      local near = candidates(e.surface, { { p.x - 14, p.y - 14 }, { p.x + 14, p.y + 14 } })
      U.shuffle(near)
      for _, n in ipairs(near) do
        if n.valid and n.unit_number and not q.hz.gremlins[n.unit_number] then
          jam(n)
          U.fly("The gremlins are breeding!", { x = n.position.x, y = n.position.y - 2 }, U.COLORS.red, n.surface, 150)
          break
        end
      end
    end
  end
end

function H.clear_gremlins()
  local q = storage.q
  for u in pairs(q.hz.gremlins) do
    drop_gremlin(u)
    H.enable(u, "gremlin")
  end
end

-- ----------------------------------------------------------- strike ---

local function strike_tick()
  local q = storage.q
  local st = q.hz.strike
  if not st then return end
  if P.has("unionrep") then
    if not st.told then
      st.told = true
      U.company("The union called a strike, but your Union Rep talked them out of it.")
    end
    return
  end
  local t = game.tick
  if not st.on then
    if not st.warned and t >= st.next - C.STRIKE_WARNING then
      st.warned = true
      U.company("The inserters' union is meeting in 10 seconds. Lunch break incoming.")
      S.play("quota-ring", 0.8)
    end
    if t >= st.next then
      local surface = U.surface()
      if not surface then return end
      st.on = true
      st.ends = t + C.STRIKE_LENGTH
      st.units = {}
      for _, e in pairs(surface.find_entities_filtered({ force = C.FORCE, type = "inserter" })) do
        if e.unit_number then
          H.disable(e, "strike", "On lunch break")
          st.units[#st.units + 1] = e.unit_number
        end
      end
      U.company({ "", "[color=255,90,80]STRIKE![/color] Every inserter is on a 20 second lunch break." })
      S.play("quota-siren", 0.5)
    end
  elseif t >= st.ends then
    for _, u in ipairs(st.units) do H.enable(u, "strike") end
    st.units = {}
    st.on = false
    st.warned = false
    st.next = st.next + C.STRIKE_EVERY
    U.company("Lunch is over. Back to work.")
    S.play("quota-whistle", 0.6)
  end
end

function H.end_strike()
  local st = storage.q.hz.strike
  if st and st.on then
    for _, u in ipairs(st.units) do H.enable(u, "strike") end
  end
  storage.q.hz.strike = nil
end

-- ----------------------------------------------------------- quakes ---

local function epicenter(surface)
  local ents = surface.find_entities_filtered({ force = C.FORCE, type = { "inserter", "transport-belt", "assembling-machine" } })
  local e = U.pick(ents)
  if e then return { x = e.position.x + U.random(-6, 6), y = e.position.y + U.random(-6, 6) } end
  return W.random_land(12)
end

function H.quake_now(pos)
  local surface = U.surface()
  if not surface or not pos then return end
  local r = C.QUAKE_RADIUS
  local area = { { pos.x - r, pos.y - r }, { pos.x + r, pos.y + r } }
  local moved = 0
  local ents = surface.find_entities_filtered({ force = C.FORCE, type = { "inserter", "transport-belt" }, area = area })
  U.shuffle(ents)
  for _, e in ipairs(ents) do
    if moved >= 45 then break end
    if e.valid and U.dist2(e.position, pos) <= r * r then
      local p = e.type == "inserter" and 0.35 or 0.22
      if U.chance(p) then
        for _ = 1, U.random(1, 3) do e.rotate() end
        moved = moved + 1
        rendering.draw_circle({
          surface = surface, target = e, radius = 0.55, color = RED, width = 3, filled = false,
          time_to_live = 40 * 60, draw_on_ground = false,
        })
      end
    end
  end
  for _ = 1, 10 do
    local a, d = U.random() * 2 * math.pi, U.random() * r * 0.8
    local p = { pos.x + math.cos(a) * d, pos.y + math.sin(a) * d }
    surface.create_trivial_smoke({ name = "small-dusty-explosion-smoke", position = p })
    if U.chance(0.4) then surface.create_entity({ name = "ground-explosion", position = p }) end
  end
  S.play("quota-kick", 1)
  S.play("quota-crash", 0.8)
  storage.q.stats.quake_moves = (storage.q.stats.quake_moves or 0) + moved
  U.company({ "", "[color=255,90,80]EARTHQUAKE![/color] ", moved, " machines got knocked around. Look for red circles." })
end

local function quake_tick()
  local q = storage.q
  local qk = q.hz.quakes
  if not qk then return end
  local at = qk.times[qk.idx]
  if not at then return end
  local surface = U.surface()
  if not surface then return end
  if not qk.pos and game.tick >= at - C.QUAKE_WARNING then
    qk.pos = epicenter(surface)
    if qk.pos then
      rendering.draw_circle({
        surface = surface, target = qk.pos, radius = C.QUAKE_RADIUS, color = { 1, 0.2, 0.15, 0.6 },
        width = 6, filled = false, draw_on_ground = true, time_to_live = C.QUAKE_WARNING,
      })
      rendering.draw_circle({
        surface = surface, target = qk.pos, radius = C.QUAKE_RADIUS, color = { 1, 0.2, 0.15, 0.4 },
        filled = true, render_mode = "chart", time_to_live = C.QUAKE_WARNING,
      })
      rendering.draw_text({
        text = "TREMORS", surface = surface, target = qk.pos, color = { 1, 0.3, 0.2 }, scale = 5,
        alignment = "center", vertical_alignment = "middle", font = "default-bold", time_to_live = C.QUAKE_WARNING,
      })
      U.company("Tremors detected. Brace for an earthquake in 5 seconds.")
      S.play("quota-alarm", 0.8)
    end
  end
  if game.tick >= at then
    H.quake_now(qk.pos or epicenter(surface))
    qk.pos = nil
    qk.idx = qk.idx + 1
  end
end

-- ----------------------------------------------------------- meteors ---

local METEOR_ORES = { { "iron-ore", 30 }, { "copper-ore", 30 }, { "coal", 20 }, { "stone", 15 }, { "uranium-ore", 5 } }

function H.meteor(target)
  local surface = U.surface()
  if not surface then return end
  if not target then
    if U.chance(0.55) then
      local ents = surface.find_entities_filtered({ force = C.FORCE, type = { "assembling-machine", "furnace", "mining-drill", "transport-belt", "inserter" } })
      local e = U.pick(ents)
      if e then target = { x = e.position.x + U.random(-8, 8), y = e.position.y + U.random(-8, 8) } end
    end
    target = target or W.random_land(14)
  end
  if not target or W.is_water(surface, target) then return end
  -- Keep the terminal pad clear.
  if math.abs(target.x) < C.PAD_HALF + 3 and math.abs(target.y) < C.PAD_HALF + 3 then
    target = { x = target.x + 14, y = target.y + 10 }
  end
  local from = { x = target.x - 22, y = target.y - 40 }
  local dist = math.sqrt(U.dist2(from, target))
  rendering.draw_circle({
    surface = surface, target = target, radius = 3.5, color = RED, width = 3, filled = false,
    draw_on_ground = true, time_to_live = C.METEOR_FLIGHT + 20,
  })
  rendering.draw_circle({
    surface = surface, target = target, radius = 3.5, color = { 1, 0.15, 0.1, 0.35 }, filled = true,
    draw_on_ground = true, time_to_live = C.METEOR_FLIGHT + 20, blink_interval = 12,
  })
  rendering.draw_circle({
    surface = surface, target = target, radius = 4, color = RED, filled = true,
    render_mode = "chart", time_to_live = C.METEOR_FLIGHT + 20,
  })
  surface.create_entity({
    name = "quota-meteor", position = from, target = target, force = "enemy",
    speed = dist / C.METEOR_FLIGHT,
  })
  for _, p in pairs(U.players()) do
    if p.surface == surface and U.dist2(p.position, target) < 70 * 70 then
      p.play_sound({ path = "quota-alarm", volume_modifier = 0.5 })
    end
  end
end

function H.on_meteor_impact(pos)
  local q = storage.q
  local surface = U.surface()
  if not surface or not pos then return end
  local pool = {}
  for _, o in ipairs(METEOR_ORES) do
    if o[1] ~= "uranium-ore" or (q.shift or 0) >= 5 then pool[#pool + 1] = o end
  end
  local ore = U.weighted_pick(pool, function(o) return o[2] end)[1]
  local mult = P.has("meteorins") and 3 or 1
  local r = 2.5 + U.random() * 1.5
  local made = 0
  for x = math.floor(pos.x - r), math.ceil(pos.x + r) do
    for y = math.floor(pos.y - r), math.ceil(pos.y + r) do
      local dx, dy = x + 0.5 - pos.x, y + 0.5 - pos.y
      if dx * dx + dy * dy <= r * r then
        local tile = surface.get_tile(x, y)
        if tile.valid and not W.is_water(surface, { x = x + 0.5, y = y + 0.5 })
          and surface.count_entities_filtered({ type = "resource", position = { x + 0.5, y + 0.5 } }) == 0 then
          surface.create_entity({ name = ore, position = { x + 0.5, y + 0.5 }, amount = math.floor((400 + U.random(0, 300)) * mult) })
          made = made + 1
        end
      end
    end
  end
  q.stats.meteors = (q.stats.meteors or 0) + 1
  if P.has("meteorins") then
    local pay = math.max(20, (q.quota or 0) * 0.02)
    L.bonus(pay, "insurance", { x = pos.x, y = pos.y - 2 })
  end
  if made > 0 then
    U.fly("Crater: [item=" .. ore .. "]", { x = pos.x, y = pos.y - 1 }, U.COLORS.orange, surface, 150)
  end
end

local function meteor_tick()
  local q = storage.q
  if not q.hz.meteor_next then return end
  if game.tick >= q.hz.meteor_next then
    q.hz.meteor_next = game.tick + U.random(C.METEOR_MIN_GAP, C.METEOR_MAX_GAP)
    H.meteor(nil)
  end
end

-- ------------------------------------------------------------- raids ---

local function raid_roster(shift, scale)
  local n = math.floor((3 + shift * 1.6) * scale + 0.5)
  local roster = {}
  for _ = 1, n do
    local r = U.random()
    local name
    if shift <= 3 then
      name = r < 0.8 and "small-biter" or "small-spitter"
    elseif shift <= 5 then
      name = r < 0.45 and "medium-biter" or (r < 0.75 and "small-biter" or "medium-spitter")
    elseif shift <= 7 then
      name = r < 0.25 and "big-biter" or (r < 0.7 and "medium-biter" or "medium-spitter")
    else
      name = r < 0.06 and "behemoth-biter" or (r < 0.45 and "big-biter" or (r < 0.75 and "medium-biter" or "big-spitter"))
    end
    roster[#roster + 1] = name
  end
  return roster
end

function H.raid_warn(spot)
  local surface = U.surface()
  if not surface or not spot then return end
  local ttl = C.RAID_WARNING + 60
  rendering.draw_circle({
    surface = surface, target = spot, radius = 6, color = RED, width = 5, filled = false,
    draw_on_ground = true, time_to_live = ttl, blink_interval = 20,
  })
  rendering.draw_circle({
    surface = surface, target = spot, radius = 10, color = RED, filled = true, render_mode = "chart", time_to_live = ttl,
  })
  rendering.draw_text({
    text = "HOSTILE LANDING", surface = surface, target = { spot.x, spot.y - 7 }, color = { 1, 0.3, 0.2 }, scale = 3,
    alignment = "center", font = "default-bold", time_to_live = ttl,
  })
  rendering.draw_text({
    text = "RAID", surface = surface, target = spot, color = { 1, 0.3, 0.2 }, scale = 8,
    alignment = "center", vertical_alignment = "middle", render_mode = "chart", time_to_live = ttl,
  })
  U.company({ "", "[color=255,90,80]HOSTILE TAKEOVER:[/color] a rival firm is landing biters on your shore in ",
    math.floor(C.RAID_WARNING / 60), " seconds. Check the map." })
  S.play("quota-siren", 0.5)
end

function H.raid_land(spot)
  local q = storage.q
  local surface = U.surface()
  if not surface or not spot then return end
  local diff = C.DIFFICULTIES[q.difficulty or "associate"]
  local shift = q.shift or 1
  local scale = diff.raid * (q.endless and (1 + 0.25 * (shift - C.FINAL_SHIFT)) or 1)
  local group = surface.create_unit_group({ position = spot, force = "enemy" })
  for _, name in ipairs(raid_roster(shift, scale)) do
    local pos = surface.find_non_colliding_position(name, spot, 10, 0.5)
    if pos then
      local u = surface.create_entity({ name = name, position = pos, force = "enemy" })
      if u then group.add_member(u) end
    end
  end
  surface.create_entity({ name = "big-explosion", position = spot })
  local target = { x = 0, y = 0 }
  group.set_command({ type = defines.command.attack_area, destination = target, radius = 40,
    distraction = defines.distraction.by_anything })
  q.stats.raids = (q.stats.raids or 0) + 1
end

local function raid_tick()
  local q = storage.q
  local rd = q.hz.raid
  if not rd then return end
  if not rd.spot and game.tick >= rd.next - C.RAID_WARNING then
    rd.spot = W.coast_spot({ x = 0, y = 0 })
    H.raid_warn(rd.spot)
  end
  if game.tick >= rd.next then
    H.raid_land(rd.spot or W.coast_spot({ x = 0, y = 0 }))
    rd.spot = nil
    rd.next = rd.next + C.RAID_EVERY
  end
end

-- One-off raid from an event: warn now, land after the warning.
function H.schedule_raid()
  local q = storage.q
  local spot = W.coast_spot({ x = 0, y = 0 })
  if not spot then return end
  H.raid_warn(spot)
  q.hz.raid_spots[#q.hz.raid_spots + 1] = { at = game.tick + C.RAID_WARNING, spot = spot }
end

local function raid_spots_tick()
  local q = storage.q
  local keep = {}
  for _, r in ipairs(q.hz.raid_spots) do
    if game.tick >= r.at then H.raid_land(r.spot) else keep[#keep + 1] = r end
  end
  q.hz.raid_spots = keep
end

-- Danger Pay: bounty per kill.
function H.on_enemy_died(entity, cause_force)
  if not P.has("dangerpay") then return end
  if not (cause_force and cause_force.name == C.FORCE) then return end
  local hp = entity.max_health or 0
  if hp <= 0 then return end
  L.bonus(math.max(2, hp * 0.12), nil, entity.position)
end

-- ---------------------------------------------------------- lifecycle ---

-- Arm the condition-driven hazards for a shift that starts now.
function H.start(active, len_ticks)
  local q = storage.q
  local t = game.tick
  if active.gremlins then q.hz.gremlin_next = t + 25 * 60 end
  if active.strike then q.hz.strike = { next = t + 50 * 60 } end
  if active.quakes then
    local times = {}
    for i, f in ipairs({ 0.22, 0.5, 0.78 }) do
      if i <= C.QUAKES_PER_SHIFT then times[#times + 1] = t + math.floor(len_ticks * f) + U.random(-8, 8) * 60 end
    end
    q.hz.quakes = { times = times, idx = 1 }
  end
  if active.meteors then q.hz.meteor_next = t + 15 * 60 end
  if active.raids then q.hz.raid = { next = t + 70 * 60 } end
end

function H.stop()
  local q = storage.q
  H.clear_gremlins()
  H.end_strike()
  q.hz.gremlin_next = nil
  q.hz.quakes = nil
  q.hz.meteor_next = nil
  q.hz.raid = nil
end

-- Every second during a shift.
function H.tick()
  local q = storage.q
  if q.hz.gremlin_next and game.tick >= q.hz.gremlin_next then
    q.hz.gremlin_next = game.tick + C.GREMLIN_INTERVAL
    H.spawn_gremlin()
    if (q.shift or 1) >= 6 then H.spawn_gremlin() end
  end
  gremlin_spread()
  strike_tick()
  quake_tick()
  meteor_tick()
  raid_tick()
  raid_spots_tick()
end

-- Every 10 ticks, any phase (gremlins from events can outlive a condition check).
function H.fast_tick()
  if next(storage.q.hz.gremlins) then gremlin_fast() end
end

function H.gremlin_count()
  return gremlin_count()
end

return H
