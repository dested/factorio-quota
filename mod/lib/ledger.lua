-- Money in, money out. Earnings during a shift count toward the quota;
-- bonuses (overtime, interest, bounties) only go to the wallet.

local C = require("lib.config")
local U = require("lib.util")
local S = require("lib.sfx")

local L = {}

-- Sales from a terminal: wallet + quota progress.
function L.ship(amount)
  local q = storage.q
  if amount <= 0 then return end
  q.wallet = q.wallet + amount
  q.shipped = q.shipped + amount
  q.stats.total_shipped = q.stats.total_shipped + amount
  if not q.quota_met and q.quota > 0 and q.shipped >= q.quota then
    q.quota_met = true
    q.quota_met_tick = game.tick
    S.jingle("quota_met")
    local left = math.max(0, q.shift_end - game.tick)
    U.company({ "", "[color=100,255,110]QUOTA MET[/color] with ", U.time(left),
      " to spare. Everything from here on is overtime." })
    for _, p in pairs(U.players()) do
      p.create_local_flying_text({ text = "QUOTA MET!", create_at_cursor = true, color = U.COLORS.green })
    end
  end
end

-- Bonuses: wallet only.
function L.bonus(amount, reason, position)
  local q = storage.q
  if amount <= 0 then return end
  q.wallet = q.wallet + amount
  q.stats.total_bonus = (q.stats.total_bonus or 0) + amount
  if position then
    U.fly("+" .. U.money(amount) .. (reason and ("  " .. reason) or ""), position, U.COLORS.green)
  end
end

function L.can_afford(amount)
  return storage.q.wallet >= amount
end

function L.spend(amount)
  local q = storage.q
  if q.wallet < amount then return false end
  q.wallet = q.wallet - amount
  q.stats.total_spent = (q.stats.total_spent or 0) + amount
  return true
end

-- Price multiplier for anything bought from the catalog right now.
function L.catalog_mult(rush_applies)
  local q = storage.q
  local m = (q.price_mods and q.price_mods.catalog) or 1
  if rush_applies and q.phase == "shift" then m = m * C.RUSH_FEE end
  return m
end

return L
