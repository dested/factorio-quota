-- The market: prices, flooding, hot items, and the sale itself.
--
-- price = base value x hot x flood x (contracts x conditions x events x run modifiers)
-- Flooding integrates exactly over a batch: selling value ds starting from
-- already-sold s yields  F * ln((1 + (s+ds)/F) / (1 + s/F))  instead of ds,
-- so dumping 4,000 gears at once floods as hard as selling them one by one.

local C = require("lib.config")
local U = require("lib.util")
local V = require("lib.values")
local P = require("lib.perks")

local M = {}

-- Other modules (conditions, events) register price hooks here to avoid
-- circular requires.
local hooks = {}
function M.add_price_hook(fn) hooks[#hooks + 1] = fn end

function M.flood_scale()
  local q = storage.q
  return math.max(C.FLOOD_MIN_BASE, C.FLOOD_SCALE * (q.quota or 0))
end

function M.hot_mult(name)
  local m = storage.q.hot[name]
  return m and M.boosted(m) or 1
end

function M.flood_mult(name)
  if P.no_flood(name) then return 1 end
  return 1 / (1 + (storage.q.flood[name] or 0) / M.flood_scale())
end

function M.other_mult(name)
  local q = storage.q
  local m = P.price_mult(name)
  for _, fn in ipairs(hooks) do m = m * fn(name) end
  m = m * (q.run_price_mult or 1) * (q.shift_price_mult or 1)
  return m
end

-- Current price of one unit.
function M.price(name)
  local base = V.base(name)
  if base <= 0 then return 0 end
  return base * M.hot_mult(name) * M.flood_mult(name) * M.other_mult(name)
end

-- Sell `count` units. Returns credits earned (and the jackpot portion).
function M.sell(name, count)
  local q = storage.q
  local base = V.base(name)
  if base <= 0 or count <= 0 then return 0, 0 end
  local other = M.hot_mult(name) * M.other_mult(name)
  local s0 = q.flood[name] or 0
  local ds = base * count
  local credits
  if P.no_flood(name) then
    credits = other * ds
  else
    local F = M.flood_scale()
    credits = other * F * math.log((1 + (s0 + ds) / F) / (1 + s0 / F))
  end
  q.flood[name] = s0 + ds

  if not q.shift_sales[name] then q.shift_distinct = (q.shift_distinct or 0) + 1 end
  q.shift_sales[name] = (q.shift_sales[name] or 0) + count
  q.shift_credits[name] = (q.shift_credits[name] or 0) + credits
  q.stats.items_shipped = q.stats.items_shipped + count
  q.stats.by_item[name] = (q.stats.by_item[name] or 0) + credits

  if not q.monopoly_item or (q.shift_credits[name] or 0) > (q.shift_credits[q.monopoly_item] or 0) then
    q.monopoly_item = name
  end

  local jackpot = 0
  if P.has("goldengear") then
    local st = q.perk_state
    st.golden = (st.golden or 0) + count
    local hits = math.floor(st.golden / 400)
    if hits > 0 then
      st.golden = st.golden - hits * 400
      jackpot = hits * 100 * (credits / count)
      q.stats.jackpots = (q.stats.jackpots or 0) + hits
    end
  end
  return credits + jackpot, jackpot
end

-- --------------------------------------------------------------- hot ---

local EXCLUDE = { ["quota-terminal"] = true }
-- Hot items, bounties and flash sales stick to real factory output:
-- intermediates, science, ammo and modules. No barrels, guns or armour.
local HOT_TYPES = { item = true, tool = true, ammo = true, module = true }

local function hot_eligible(name)
  local proto = prototypes.item[name]
  return proto ~= nil and HOT_TYPES[proto.type] == true and not name:find("barrel", 1, true)
    and not C.NOT_HOT[name]
end
M.hot_eligible = hot_eligible

-- Products the player can make right now, sorted by name (deterministic).
-- for_hot limits the list to items fit for hot lists and bounties.
function M.makeable(for_hot)
  local force = U.force()
  local set = {}
  for _, recipe in pairs(force.recipes) do
    if recipe.enabled and not recipe.hidden then
      for _, p in pairs(recipe.products) do
        if p.type == "item" and V.is_product(p.name) and not EXCLUDE[p.name]
          and (not for_hot or hot_eligible(p.name)) then
          set[p.name] = true
        end
      end
    end
  end
  local list = {}
  for name in pairs(set) do list[#list + 1] = name end
  table.sort(list)
  return list
end

function M.roll_hot(count, avoid)
  local pool = M.makeable(true)
  local hot, order = {}, {}
  local function weight(name)
    if hot[name] or (avoid and avoid[name]) then return 0 end
    local v = V.base(name)
    return math.sqrt(math.max(2, math.min(80, v)))
  end
  for _ = 1, count do
    local name = U.weighted_pick(pool, weight)
    if not name then
      -- Avoid list exhausted the pool: allow repeats from last time.
      avoid = nil
      name = U.weighted_pick(pool, weight)
    end
    if not name then break end
    hot[name] = U.pick(C.HOT_MULTS)
    order[#order + 1] = name
  end
  return hot, order
end

-- A rolled hot multiplier plus Hype Machine. Rolls store the raw value so the
-- contract counts from the moment it is signed, not from the next roll.
function M.boosted(m)
  return m + P.hot_bonus()
end

-- Insider Trading: last shift's best seller is hot again. `t` holds hot,
-- hot_order and insider (the item this added); the slot is added or removed
-- to match whether the contract is held right now.
function M.sync_insider(t)
  local q = storage.q
  local want = P.has("insider") and q.last_best or nil
  if want and not (V.is_product(want) and hot_eligible(want)) then want = nil end
  if t.insider and t.insider ~= want then
    t.hot[t.insider] = nil
    for i, n in ipairs(t.hot_order) do
      if n == t.insider then table.remove(t.hot_order, i) break end
    end
    t.insider = nil
  end
  if want and not t.insider and not t.hot[want] then
    t.hot[want] = U.pick(C.HOT_MULTS)
    table.insert(t.hot_order, 1, want)
    t.insider = want
  end
end

-- Flood decays between shifts.
function M.decay_flood()
  local q = storage.q
  for name, v in pairs(q.flood) do
    local nv = v * C.FLOOD_CARRYOVER
    if nv < 1 then q.flood[name] = nil else q.flood[name] = nv end
  end
end

-- Item with the most credits this shift.
function M.best_seller()
  local q = storage.q
  local best, best_v = nil, 0
  for name, v in pairs(q.shift_credits) do
    if v > best_v then best, best_v = name, v end
  end
  return best, best_v
end

-- Price of one unit next shift (break preview): next shift's hot list, flood as it stands.
function M.next_price(name)
  local q = storage.q
  local base = V.base(name)
  if base <= 0 then return 0 end
  local m = q.next and q.next.hot[name]
  return base * (m and M.boosted(m) or 1) * M.flood_mult(name) * M.other_mult(name)
end

-- Rows for the market side panel: the n best-paying products right now (or next shift).
function M.top(n, preview)
  local q = storage.q
  local hot = preview and q.next and q.next.hot or q.hot
  local rows = {}
  for _, name in ipairs(M.makeable()) do
    local price = preview and M.next_price(name) or M.price(name)
    if price > 0 then
      local m = hot[name]
      rows[#rows + 1] = { name = name, price = price, hot = m and M.boosted(m), flood = M.flood_mult(name) }
    end
  end
  table.sort(rows, function(a, b)
    if a.price ~= b.price then return a.price > b.price end
    return a.name < b.name
  end)
  local out = {}
  for i = 1, math.min(n, #rows) do out[i] = rows[i] end
  return out
end

-- Price table for the Market tab: makeable products plus anything sold this run.
function M.price_list()
  local q = storage.q
  local names = {}
  local seen = {}
  for _, n in ipairs(M.makeable()) do names[#names + 1] = n; seen[n] = true end
  for n in pairs(q.hot) do if not seen[n] then names[#names + 1] = n; seen[n] = true end end
  local rows = {}
  for _, n in ipairs(names) do
    local base = V.base(n)
    if base > 0 then
      rows[#rows + 1] = {
        name = n, base = base, price = M.price(n),
        flood = M.flood_mult(n), hot = q.hot[n] and M.boosted(q.hot[n]),
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.price ~= b.price then return a.price > b.price end
    return a.name < b.name
  end)
  return rows
end

return M
