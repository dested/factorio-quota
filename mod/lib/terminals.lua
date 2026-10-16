-- Shipping Terminals. During a shift, everything placed in a terminal is
-- sold every half second. Items with no value stay in the chest.

local C = require("lib.config")
local U = require("lib.util")
local V = require("lib.values")
local M = require("lib.market")
local L = require("lib.ledger")
local S = require("lib.sfx")
local A = require("lib.anim")

local T = {}

local function selling()
  local phase = storage.q.phase
  return phase == "shift" or phase == "retired"
end
T.selling = selling

local function status()
  local q = storage.q
  if q.phase == "shift" then return "OPEN", { 0.4, 1, 0.45 } end
  if q.phase == "retired" then return "OPEN", { 0.4, 1, 0.45 } end
  if q.phase == "break" then return "CLOSED: ON BREAK", { 0.75, 0.75, 0.75 } end
  if q.phase == "fired" then return "TERMINATED", { 1, 0.35, 0.3 } end
  if q.phase == "promoted" then return "CLOSED: CELEBRATING", { 1, 0.78, 0.2 } end
  return "CLOSED", { 0.75, 0.75, 0.75 }
end

function T.register(entity, hq)
  local q = storage.q
  if not (entity and entity.valid and entity.unit_number) then return end
  entity.destructible = false
  if hq then entity.minable_flag = false end
  local surface = entity.surface
  local title = rendering.draw_text({
    text = hq and "SHIPPING TERMINAL" or "SHIPPING TERMINAL #" .. (q.terminal_serial + 1),
    surface = surface, target = { entity = entity, offset = { 0, -4.2 } },
    color = { 1, 0.85, 0.4 }, scale = 1.5, alignment = "center", vertical_alignment = "middle",
    font = "default-bold",
  })
  local label = rendering.draw_text({
    text = "", surface = surface, target = { entity = entity, offset = { 0, -3.4 } },
    color = { 1, 1, 1 }, scale = 1.2, alignment = "center", vertical_alignment = "middle",
    font = "default-bold",
  })
  q.terminal_serial = q.terminal_serial + 1
  q.terminals[entity.unit_number] = {
    entity = entity, hq = hq or false, title = title, label = label,
    pending = 0, last_fly = 0, launch_acc = 0, last_launch = 0,
  }
  T.refresh_labels()
end

function T.unregister(unit_number)
  local q = storage.q
  local t = q.terminals[unit_number]
  if not t then return end
  for _, o in pairs({ t.title, t.label }) do
    if o and o.valid then o.destroy() end
  end
  q.terminals[unit_number] = nil
  q.frozen[unit_number] = nil
end

function T.refresh_labels()
  local q = storage.q
  local text, color = status()
  for unit, t in pairs(q.terminals) do
    if t.label and t.label.valid then
      if q.frozen[unit] then
        t.label.text = "UNDER AUDIT"
        t.label.color = { 1, 0.3, 0.25 }
      else
        t.label.text = text
        t.label.color = color
      end
    end
  end
end

function T.list()
  local out = {}
  for unit, t in pairs(storage.q.terminals) do
    if t.entity and t.entity.valid then out[#out + 1] = t else T.unregister(unit) end
  end
  return out
end

function T.hq()
  for _, t in pairs(storage.q.terminals) do
    if t.hq and t.entity and t.entity.valid then return t.entity end
  end
  return nil
end

-- Sell one terminal's contents. Returns credits earned.
local function sell_terminal(t)
  local q = storage.q
  local inv = t.entity.get_inventory(defines.inventory.chest)
  if not inv or inv.is_empty() then return 0 end
  local total, jackpot = 0, 0
  local property = 0
  for _, stack in pairs(inv.get_contents()) do
    local name, count = stack.name, stack.count
    if V.base(name) > 0 then
      local gifted = math.min(count, q.gifted[name] or 0)
      if gifted > 0 then
        q.gifted[name] = (q.gifted[name] or 0) - gifted
        if q.gifted[name] <= 0 then q.gifted[name] = nil end
        local scrap = V.full(name) * C.SCRAP_RATE * gifted
        total = total + scrap
        property = property + scrap
      end
      local rest = count - gifted
      if rest > 0 then
        local credits, jp = M.sell(name, rest)
        total = total + credits
        jackpot = jackpot + jp
      end
      inv.remove({ name = name, count = count, quality = stack.quality })
    end
  end
  if property > 0 and game.tick - (q.property_warned or -99999) > 60 * 60 then
    q.property_warned = game.tick
    U.fly("Company property: sold for scrap", { x = t.entity.position.x, y = t.entity.position.y - 5 },
      U.COLORS.grey, t.entity.surface, 150)
  end
  if jackpot > 0 then
    S.jingle("jackpot")
    U.fly("GOLDEN GEAR JACKPOT! +" .. U.money(jackpot), { x = t.entity.position.x, y = t.entity.position.y - 6 },
      U.COLORS.gold, t.entity.surface, 240)
  end
  return total
end

function T.sweep()
  local q = storage.q
  if not selling() then return end
  for unit, t in pairs(q.terminals) do
    local e = t.entity
    if not (e and e.valid) then
      T.unregister(unit)
    elseif not q.frozen[unit] then
      local earned = sell_terminal(t)
      if earned > 0 then
        L.ship(earned)
        t.pending = t.pending + earned
        t.launch_acc = t.launch_acc + earned
      end
      local pos = e.position
      if t.pending > 0 and game.tick - t.last_fly >= C.TERMINAL_FLY_INTERVAL then
        U.fly("+" .. U.money(t.pending), { x = pos.x, y = pos.y - 3 }, U.COLORS.gold, e.surface, 80)
        t.pending = 0
        t.last_fly = game.tick
      end
      local threshold = math.max(25, (q.quota or 0) * 0.03)
      if t.launch_acc >= threshold and game.tick - t.last_launch >= 120 then
        A.launch(e.surface, pos)
        S.play("quota-cash", 0.35)
        t.launch_acc = 0
        t.last_launch = game.tick
      end
    end
  end
end

-- Company property decays: after a shift or two it's just stuff you own.
function T.decay_gifted()
  local q = storage.q
  for name, n in pairs(q.gifted) do
    local nv = math.floor(n * 0.5)
    if nv <= 0 then q.gifted[name] = nil else q.gifted[name] = nv end
  end
end

return T
