-- The Audit: the final shift's boss. A giant gold behemoth lands on the far
-- coast and walks to your terminal. Any terminal it stands near stops
-- shipping. Kill it for a bonus worth 60% of the quota.

local C = require("lib.config")
local U = require("lib.util")
local W = require("lib.world")
local L = require("lib.ledger")
local S = require("lib.sfx")
local T = require("lib.terminals")

local AU = {}

function AU.reset()
  local q = storage.q
  if q.aud and q.aud.entity and q.aud.entity.valid then q.aud.entity.destroy() end
  q.aud = nil
  q.frozen = {}
end

function AU.start()
  storage.q.aud = { warned = false }
end

local function nearest_terminal(pos, exclude)
  local best, best_d
  for _, t in ipairs(T.list()) do
    if t.entity.unit_number ~= exclude then
      local d = U.dist2(pos, t.entity.position)
      if not best_d or d < best_d then best, best_d = t.entity, d end
    end
  end
  return best
end

local function walk_to(aud, terminal)
  local e = aud.entity
  if not (e and e.valid and terminal and terminal.valid) then return end
  aud.target = terminal.unit_number
  aud.arrived_at = nil
  aud.ordered_at = game.tick
  e.commandable.set_command({
    type = defines.command.go_to_location,
    destination_entity = terminal,
    radius = 4,
    distraction = defines.distraction.by_damage,
  })
end

local function spawn(aud)
  local surface = U.surface()
  if not surface then return end
  local spot = W.coast_spot({ x = 0, y = 0 }) or { x = 40, y = 40 }
  local pos = surface.find_non_colliding_position("quota-auditor", spot, 16, 1) or spot
  local e = surface.create_entity({ name = "quota-auditor", position = pos, force = "enemy" })
  if not e then return end
  aud.entity = e
  aud.spawned = game.tick
  surface.create_entity({ name = "big-explosion", position = pos })
  for _ = 1, 6 do
    surface.create_trivial_smoke({ name = "artillery-smoke", position = { pos.x + U.random(-3, 3), pos.y + U.random(-3, 3) } })
  end
  rendering.draw_text({
    text = "THE AUDITOR", surface = surface, target = { entity = e, offset = { 0, -5.5 } },
    color = { 1, 0.78, 0.2 }, scale = 2.2, font = "default-bold", alignment = "center", vertical_alignment = "middle",
  })
  rendering.draw_circle({
    surface = surface, target = e, radius = 6, color = { 1, 0.78, 0.2, 0.9 }, filled = true, render_mode = "chart",
  })
  U.force().chart(surface, { { pos.x - 32, pos.y - 32 }, { pos.x + 32, pos.y + 32 } })
  U.company({ "", "[color=255,90,80][font=default-large-bold]THE AUDITOR HAS ARRIVED.[/font][/color] ",
    "It is walking to your terminal. Terminals it stands near stop shipping. Kill it for a ",
    U.money(storage.q.quota * C.AUDITOR_BOUNTY), " bonus." })
  S.play("quota-siren", 0.7)
  S.play("quota-crash", 0.8)
  walk_to(aud, nearest_terminal(pos))
end

-- Every second during the audit shift.
function AU.tick()
  local q = storage.q
  local aud = q.aud
  if not aud or aud.killed then return end
  -- Relative to the shift start, so the test harness can fast-forward.
  local spawn_at = q.shift_start + C.AUDITOR_SPAWN_AT
  if not aud.entity then
    if not aud.warned and game.tick >= spawn_at - 15 * 60 then
      aud.warned = true
      U.company("The Auditor lands in 15 seconds. Have your paperwork ready.")
      S.play("quota-alarm", 0.8)
    end
    if game.tick >= spawn_at then spawn(aud) end
    return
  end
  local e = aud.entity
  if not e.valid then return end

  -- Freeze nearby terminals.
  local changed = false
  local r2 = C.AUDITOR_FREEZE_RADIUS * C.AUDITOR_FREEZE_RADIUS
  for _, t in ipairs(T.list()) do
    local u = t.entity.unit_number
    local near = U.dist2(e.position, t.entity.position) <= r2
    if near and not q.frozen[u] then
      q.frozen[u] = true
      changed = true
      U.company("The Auditor is reviewing a terminal. It has stopped shipping.")
      S.play("quota-buzzer", 0.6)
    elseif not near and q.frozen[u] then
      q.frozen[u] = nil
      changed = true
    end
  end
  if changed then T.refresh_labels() end

  local target
  for _, t in ipairs(T.list()) do
    if t.entity.unit_number == aud.target then target = t.entity end
  end
  if not target then
    walk_to(aud, nearest_terminal(e.position))
    return
  end
  local close = U.dist2(e.position, target.position) <= 7 * 7
  if close and not aud.arrived_at then aud.arrived_at = game.tick end
  if aud.arrived_at and game.tick - aud.arrived_at > 45 * 60 then
    local other = nearest_terminal(e.position, aud.target)
    if other then
      U.company("The Auditor moves on to your next terminal.")
      walk_to(aud, other)
    else
      aud.arrived_at = game.tick
    end
  elseif not close and game.tick - (aud.ordered_at or 0) > 15 * 60 then
    walk_to(aud, target)
  end
end

function AU.on_died(entity)
  local q = storage.q
  local aud = q.aud
  if not aud or aud.entity ~= entity then return end
  aud.killed = true
  aud.entity = nil
  q.frozen = {}
  T.refresh_labels()
  q.stats.auditor_killed = true
  local bounty = q.quota * C.AUDITOR_BOUNTY
  L.bonus(bounty, "AUDIT PASSED", entity.position)
  S.jingle("jackpot")
  U.company({ "", "[color=100,255,110][font=default-large-bold]THE AUDITOR IS DOWN.[/font][/color] ",
    "Your paperwork is in order. +", U.money(bounty), " bonus." })
end

function AU.stop()
  local q = storage.q
  local aud = q.aud
  if aud and aud.entity and aud.entity.valid then
    local surface = aud.entity.surface
    local pos = aud.entity.position
    aud.entity.destroy()
    surface.create_trivial_smoke({ name = "artillery-smoke", position = pos })
    U.company("The Auditor has seen enough.")
  end
  q.aud = nil
  q.frozen = {}
  T.refresh_labels()
end

-- HUD: health fraction or nil.
function AU.health()
  local aud = storage.q.aud
  if not (aud and aud.entity and aud.entity.valid) then return nil end
  return aud.entity.health / aud.entity.max_health
end

function AU.status()
  local aud = storage.q.aud
  if not aud then return nil end
  if aud.killed then return "killed" end
  if not aud.entity then return "incoming", math.max(0, storage.q.shift_start + C.AUDITOR_SPAWN_AT - game.tick) end
  return "active"
end

return AU
