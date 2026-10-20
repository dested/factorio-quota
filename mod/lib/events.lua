-- Mid-shift events, from shift 2: flash sales, bounties, supply drops,
-- market swings, stray meteors, single gremlins and raids.

local U = require("lib.util")
local V = require("lib.values")
local M = require("lib.market")
local L = require("lib.ledger")
local P = require("lib.perks")
local S = require("lib.sfx")
local D = require("lib.delivery")
local H = require("lib.hazards")
local R = require("lib.rules")

local E = {}

-- Care packages carry machines only: never products you could sell, so a free package
-- can't be flipped at the terminal.
local SUPPLY_POOL = {
  "assembling-machine-2", "fast-inserter", "fast-transport-belt", "electric-mining-drill", "solar-panel",
  "medium-electric-pole", "steel-furnace", "big-electric-pole", "bulk-inserter", "assembling-machine-1", "inserter", "transport-belt", "stone-furnace",
  "gun-turret", "pipe", "boiler", "steam-engine", "underground-belt", "splitter",
}

E.DEFS = {
  { id = "flash", good = true, weight = 3, name = "Flash Sale", sprite = "virtual-signal/signal-fire",
    desc = "Your best seller this shift sells for x4 for 60 seconds." },
  { id = "bounty", good = true, weight = 3, name = "Bounty", sprite = "virtual-signal/signal-star",
    desc = "Ship a set number of one item within 90 seconds for a bonus worth 15% of the quota." },
  { id = "supply", good = true, weight = 2, name = "Care Package", sprite = "item/wooden-chest",
    desc = "A free drop pod of machines lands next to you." },
  { id = "rally", good = true, weight = 2, name = "Market Rally", sprite = "virtual-signal/up-arrow",
    desc = "Everything sells for x1.5 for 45 seconds." },
  { id = "meteor", good = false, weight = 2, name = "Stray Meteor", sprite = "virtual-signal/signal-explosion",
    desc = "One meteor. Watch for the red circle. Leaves a crater full of ore." },
  { id = "gremlin", good = false, weight = 2, name = "Stray Gremlin", sprite = "entity/small-biter",
    desc = "A gremlin jams one machine. Walk up to it to whack it." },
  { id = "crash", good = false, weight = 1.5, name = "Market Crash", sprite = "virtual-signal/down-arrow",
    desc = "Everything sells for x0.6 for 30 seconds. Maybe hold your stock." },
  { id = "raid", good = false, weight = 1.5, from = 4, name = "Surprise Raid", sprite = "item/gun-turret",
    desc = "From shift 4: a rival firm lands a pack of biters on your shore." },
}
E.BY_ID = {}
for _, d in ipairs(E.DEFS) do E.BY_ID[d.id] = d end

function E.reset()
  storage.q.ev = { next = nil, active = nil }
end

function E.start_shift()
  local q = storage.q
  E.reset()
  if (q.shift or 1) >= 2 then
    q.ev.next = game.tick + U.random(40, 70) * 60
  end
end

local function unlocked(item)
  local force = U.force()
  local r = force.recipes[item]
  return r ~= nil and r.enabled
end

local function timed(id, seconds, fields)
  local q = storage.q
  local a = { id = id, ends = game.tick + seconds * 60, len = seconds * 60 }
  for k, v in pairs(fields or {}) do a[k] = v end
  q.ev.active = a
  return a
end

local function fire(id)
  local q = storage.q
  if id == "flash" then
    local best, best_n = nil, 0
    for name, n in pairs(q.shift_sales) do
      if M.hot_eligible(name) and V.is_product(name) and n > best_n then best, best_n = name, n end
    end
    best = best or U.pick(M.makeable(true))
    if not best then return false end
    timed("flash", 60, { item = best })
    U.company({ "", "[color=100,255,110]FLASH SALE![/color] [item=", best, "] sells for x4 for the next 60 seconds." })
    S.jingle("event_good")
  elseif id == "rally" then
    timed("rally", 45)
    U.company("[color=100,255,110]MARKET RALLY![/color] Everything sells for x1.5 for 45 seconds.")
    S.jingle("event_good")
  elseif id == "crash" then
    timed("crash", 30)
    U.company("[color=255,90,80]MARKET CRASH.[/color] Everything sells for x0.6 for 30 seconds. Maybe hold your stock.")
    S.jingle("event_bad")
  elseif id == "bounty" then
    local pool = {}
    for _, n in ipairs(M.makeable(true)) do
      local v = V.base(n)
      if v >= 1.5 and v <= 400 then pool[#pool + 1] = n end
    end
    local item = U.weighted_pick(pool, function(n) return math.sqrt(V.base(n)) end)
    if not item then return false end
    local need = math.floor(math.max(5, math.min(2000, (q.quota * 0.06) / V.base(item))) + 0.5)
    local reward = math.max(60, q.quota * 0.15)
    timed("bounty", 90, { item = item, need = need, start = q.shift_sales[item] or 0, reward = reward })
    U.company({ "", "[color=255,200,70]BOUNTY:[/color] ship ", need, " [item=", item, "] in 90 seconds for a ",
      U.money(reward), " bonus." })
    S.jingle("event_good")
  elseif id == "supply" then
    local options = {}
    for _, n in ipairs(SUPPLY_POOL) do
      if prototypes.item[n] and unlocked(n) then options[#options + 1] = n end
    end
    U.shuffle(options)
    local budget = math.max(150, q.quota * 0.12) / 3
    local items = {}
    for i = 1, math.min(3, #options) do
      local n = options[i]
      local v = math.max(0.5, V.full(n))
      local stack = prototypes.item[n].stack_size
      items[#items + 1] = { n, math.max(1, math.min(stack * 4, math.floor(budget / v))) }
    end
    if #items == 0 then return false end
    D.drop(items, { label = "Care Package" })
    U.company("A care package is on its way down. Compliments of The Company.")
    S.jingle("event_good")
  elseif id == "meteor" then
    H.meteor(nil)
    U.company("[color=255,90,80]Stray meteor incoming![/color] Watch for the red circle.")
  elseif id == "gremlin" then
    if not H.spawn_gremlin() then return false end
    U.company("A gremlin slipped into the factory. Find the green blip on the map.")
  elseif id == "raid" then
    H.schedule_raid()
  end
  q.stats.events = (q.stats.events or 0) + 1
  return true
end

function E.tick()
  local q = storage.q
  local ev = q.ev
  if ev.active and game.tick >= ev.active.ends then
    local a = ev.active
    if a.id == "bounty" then
      U.company({ "", "The bounty on [item=", a.item, "] expired." })
    elseif a.id == "flash" or a.id == "rally" or a.id == "crash" then
      U.company("Prices are back to normal.")
    end
    ev.active = nil
  end
  if ev.active and ev.active.id == "bounty" then
    local a = ev.active
    local got = (q.shift_sales[a.item] or 0) - a.start
    if got >= a.need then
      L.bonus(a.reward)
      S.jingle("payday")
      U.company({ "", "[color=100,255,110]BOUNTY COMPLETE![/color] +", U.money(a.reward), " bonus." })
      for _, p in pairs(U.players()) do
        p.create_local_flying_text({ text = "BOUNTY +" .. U.money(a.reward), create_at_cursor = true, color = U.COLORS.green })
      end
      q.stats.bounties = (q.stats.bounties or 0) + 1
      ev.active = nil
    end
  end
  if not ev.next or game.tick < ev.next then return end
  if game.tick > q.shift_end - 30 * 60 then
    ev.next = nil
    return
  end
  ev.next = game.tick + U.random(55, 95) * 60
  local lucky = P.has("lucky")
  local pool = {}
  for _, d in ipairs(E.DEFS) do
    local ok = (q.shift or 1) >= (d.from or 0) and R.event_on(d.id)
    -- Only one timed event at a time.
    if ev.active and (d.id == "flash" or d.id == "rally" or d.id == "crash" or d.id == "bounty") then ok = false end
    if ok then pool[#pool + 1] = d end
  end
  local d = U.weighted_pick(pool, function(x) return x.weight * ((lucky and x.good) and 2 or 1) end)
  if d then fire(d.id) end
end

-- Remaining ticks and a short label for the HUD status line (its icon shows the item).
function E.describe()
  local q = storage.q
  local a = q.ev and q.ev.active
  if not a then return nil end
  local left = math.max(0, a.ends - game.tick)
  if a.id == "flash" then
    return "[color=100,255,110]FLASH SALE[/color] x4", left, a.len
  elseif a.id == "rally" then
    return "[color=100,255,110]MARKET RALLY[/color] all x1.5", left, a.len
  elseif a.id == "crash" then
    return "[color=255,90,80]MARKET CRASH[/color] all x0.6", left, a.len
  elseif a.id == "bounty" then
    local got = math.max(0, (q.shift_sales[a.item] or 0) - a.start)
    return { "", "[color=255,200,70]BOUNTY[/color] ", math.min(got, a.need), "/", a.need, " for ", U.money(a.reward) },
      left, a.len
  end
  return nil
end

M.add_price_hook(function(name)
  local q = storage.q
  if q.phase ~= "shift" then return 1 end
  local a = q.ev and q.ev.active
  if not a then return 1 end
  if a.id == "flash" and a.item == name then return 4 end
  if a.id == "rally" then return 1.5 end
  if a.id == "crash" then return 0.6 end
  return 1
end)

-- Exposed for the test harness.
E.fire = fire

return E
