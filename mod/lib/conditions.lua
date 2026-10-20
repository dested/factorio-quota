-- Shift conditions: one (later two) per shift, announced during the break
-- before it so you can buy around them.

local U = require("lib.util")
local M = require("lib.market")
local R = require("lib.rules")

local K = {}

K.DEFS = {
  { id = "eclipse", name = "Solar Eclipse", tier = 1, sprite = "virtual-signal/signal-moon",
    desc = "Night all shift. Solar panels are useless. Night-shift rate: everything sells for +20%." },
  { id = "lowgrav", name = "Low Gravity", tier = 1, good = true, sprite = "utility/character_running_speed_modifier_icon",
    desc = "+80% running speed all shift. Wheee." },
  { id = "golden", name = "Golden Hour", tier = 1, good = true, sprite = "virtual-signal/signal-sun",
    desc = "Everything sells for double in the first 90 seconds. Stockpile during the break." },
  { id = "gremlins", name = "Gremlin Infestation", tier = 2, sprite = "virtual-signal/signal-skull",
    desc = "Gremlins jam your machines. Walk up to a jammed machine to whack the gremlin (bounty paid). Ignored gremlins spread." },
  { id = "meteors", name = "Meteor Shower", tier = 2, sprite = "virtual-signal/signal-explosion",
    desc = "Meteors rain on your land all shift (thin early, heavy from shift 6). Red circles mark impacts. Each crater is full of ore. Destroyed machines leave ghosts." },
  { id = "hotpotato", name = "Hot Potato", tier = 1, sprite = "virtual-signal/signal-shuffle",
    desc = "The hot items change every 75 seconds." },
  { id = "strike", name = "Union Strike", tier = 2, sprite = "item/inserter",
    desc = "Every 100 seconds, every inserter takes a 20 second lunch break." },
  { id = "quakes", name = "Seismic Activity", tier = 2, sprite = "virtual-signal/signal-alarm",
    desc = "Three earthquakes. Each one spins inserters and belts near the epicenter. Damaged spots are circled in red." },
  { id = "raids", name = "Hostile Takeover", tier = 2, sprite = "item/gun-turret",
    desc = "A rival firm lands biters on your shores every two minutes. Defend the factory." },
  { id = "picky", name = "Picky Client", tier = 2, sprite = "virtual-signal/signal-info",
    desc = "Only hot items sell at full price; everything else sells for 30%. Two extra hot items." },
  { id = "volatile", name = "Volatile Market", tier = 2, sprite = "virtual-signal/signal-up-down-arrow",
    desc = "Prices swing between x0.5 and x1.7 all shift. Watch the ticker and sell high." },
  { id = "rush", name = "Rush Order", tier = 2, sprite = "virtual-signal/signal-hourglass",
    desc = "The shift is 25% shorter. The quota is only 15% lower." },
  { id = "mandate", name = "Overtime Mandate", tier = 2, sprite = "virtual-signal/signal-clock",
    desc = "The shift runs 90 seconds longer. The quota is 30% higher." },
  { id = "audit", name = "THE AUDIT", tier = 3, special = true, sprite = "entity/behemoth-biter",
    desc = "The Company's Auditor lands 90 seconds in and walks to your terminal. Any terminal it stands near stops shipping. Kill it for a huge bonus." },
}

K.BY_ID = {}
for _, d in ipairs(K.DEFS) do K.BY_ID[d.id] = d end

-- --------------------------------------------------------------- roll ---

-- Conditions for shift `n` given difficulty.
function K.roll(n)
  local q = storage.q
  local diff = R.diff()
  local final = R.final()
  local chosen = {}
  -- The Audit closes the run, and returns every third endless shift.
  local audit = (n == final and not q.endless) or (q.endless and n > final and (n - final) % 3 == 0)
  if audit and R.cond_on("audit") then chosen[#chosen + 1] = "audit" end
  if n < diff.cond_from then return chosen end
  local count = (n >= diff.double_from or q.endless) and 2 or 1
  if q.extra_condition then count = count + 1 end
  if audit then count = count - 1 end
  for _ = 1, count do K.add_one(n, chosen) end
  return chosen
end

local CLASHES = { rush = "mandate", mandate = "rush" }

-- Append one more random condition to `chosen` (in place).
function K.add_one(n, chosen)
  local q = storage.q
  local function eligible(d)
    if d.special or U.contains(chosen, d.id) or not R.cond_on(d.id) then return false end
    if CLASHES[d.id] and U.contains(chosen, CLASHES[d.id]) then return false end
    if U.contains(q.last_conditions or {}, d.id) then return false end
    if n <= 3 then return d.tier == 1 end
    return true
  end
  local pool = {}
  for _, d in ipairs(K.DEFS) do if eligible(d) then pool[#pool + 1] = d end end
  local pick = U.weighted_pick(pool, function(d)
    if n >= 4 and d.tier == 2 then return 3 end
    return 2
  end)
  if pick then chosen[#chosen + 1] = pick.id end
  return chosen
end

-- Drop conditions switched off since they were rolled (a mid-break settings change).
function K.filter(ids)
  local keep = {}
  for _, id in ipairs(ids) do
    if R.cond_on(id) then keep[#keep + 1] = id end
  end
  return keep
end

-- Length and quota adjustments a condition list implies.
function K.adjust(ids, len, quota)
  for _, id in ipairs(ids) do
    if id == "rush" then len, quota = len * 0.75, quota * 0.85 end
    if id == "mandate" then len, quota = len + 90, quota * 1.3 end
  end
  return len, quota
end

function K.extra_hot(ids)
  return U.contains(ids, "picky") and 2 or 0
end

-- ------------------------------------------------------------ runtime ---

function K.active(id)
  local q = storage.q
  return q.phase == "shift" and q.cond_active[id] == true
end

function K.start(ids)
  local q = storage.q
  q.cond_active = {}
  q.cond_state = {}
  for _, id in ipairs(ids) do q.cond_active[id] = true end
  local surface = U.surface()
  if q.cond_active.eclipse and surface then
    surface.always_day = false
    surface.freeze_daytime = true
    surface.daytime = 0.5
  end
  if q.cond_active.volatile then
    q.cond_state.vol = { value = 1, target = 1.4, next = game.tick + 20 * 60 }
  end
  if q.cond_active.hotpotato then
    q.cond_state.potato_next = game.tick + 75 * 60
  end
end

function K.stop()
  local q = storage.q
  local surface = U.surface()
  if q.cond_active.eclipse and surface then
    surface.freeze_daytime = false
    surface.always_day = true
  end
  q.cond_active = {}
  q.cond_state = {}
end

-- Called every second during a shift.
function K.tick(reroll_hot)
  local q = storage.q
  local st = q.cond_state
  if q.cond_active.volatile and st.vol then
    local v = st.vol
    v.value = v.value + (v.target - v.value) * 0.12
    if game.tick >= v.next then
      v.target = 0.5 + U.random() * 1.2
      v.next = game.tick + U.random(18, 32) * 60
    end
  end
  if q.cond_active.hotpotato and st.potato_next and game.tick >= st.potato_next then
    st.potato_next = game.tick + 75 * 60
    reroll_hot()
  end
end

function K.volatile_value()
  local q = storage.q
  local v = q.cond_state and q.cond_state.vol
  return v and v.value or 1, v and v.target or 1
end

M.add_price_hook(function(name)
  local q = storage.q
  if q.phase ~= "shift" then return 1 end
  local a = q.cond_active
  local m = 1
  if a.eclipse then m = m * 1.2 end
  if a.golden and game.tick < q.shift_start + 90 * 60 then m = m * 2 end
  if a.picky and not q.hot[name] then m = m * 0.3 end
  if a.volatile then m = m * K.volatile_value() end
  return m
end)

return K
