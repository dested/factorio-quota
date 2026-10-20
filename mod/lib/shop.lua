-- The Company Catalog: Contracts, R&D, Supplies, Land and Corporate Offers.
-- Every buy_* returns ok, message.

local C = require("lib.config")
local U = require("lib.util")
local V = require("lib.values")
local P = require("lib.perks")
local M = require("lib.market")
local L = require("lib.ledger")
local W = require("lib.world")
local D = require("lib.delivery")
local S = require("lib.sfx")
local Z = require("lib.zoning")

local SH = {}

-- ================================================================ R&D ===

SH.RND = {
  { id = "steel", name = "Steel Processing", tech = "steel-processing", price = 250,
    techs = { "steel-processing", "steel-axe" }, desc = "Steel plates (they sell well) and a faster axe." },
  { id = "fastins", name = "Fast Inserters", tech = "fast-inserter", price = 300,
    techs = { "fast-inserter" }, desc = "Inserters that don't dawdle." },
  { id = "greensci", name = "Logistic Science", tech = "logistic-science-pack", price = 300,
    techs = { "logistic-science-pack" }, desc = "Green science packs. Something new to sell." },
  { id = "toolbelt", name = "Toolbelt", tech = "toolbelt", price = 250,
    techs = { "toolbelt" }, desc = "+10 inventory slots." },
  { id = "gates", name = "Gates", tech = "gate", price = 200,
    techs = { "gate" }, desc = "Gates for your walls." },
  { id = "power1", name = "Medium Poles", tech = "electric-energy-distribution-1", price = 400,
    techs = { "electric-energy-distribution-1" }, desc = "Medium and big electric poles." },
  { id = "logistics2", name = "Fast Belts", tech = "logistics-2", price = 600,
    techs = { "logistics-2" }, desc = "Fast transport belts, undergrounds and splitters." },
  { id = "engine", name = "Engines", tech = "engine", price = 600,
    techs = { "engine" }, desc = "Engine units. Pricey, sellable, needed for cars and pumpjacks." },
  { id = "automation2", name = "Assembler 2", tech = "automation-2", price = 700,
    techs = { "automation-2" }, desc = "Faster assemblers that take fluids." },
  { id = "military2", name = "Military 2", tech = "military-2", price = 500,
    techs = { "military-2", "physical-projectile-damage-1", "weapon-shooting-speed-1" },
    desc = "Piercing rounds and grenades, plus a damage and fire-rate bump." },
  { id = "car", name = "Automobilism", tech = "automobilism", price = 700,
    techs = { "automobilism" }, desc = "A car. Faster commute between plots." },
  { id = "smelting2", name = "Steel Furnaces", tech = "advanced-material-processing", price = 800,
    techs = { "advanced-material-processing" }, desc = "Twice the smelting speed per furnace." },
  { id = "solar", name = "Solar Energy", tech = "solar-energy", price = 900,
    techs = { "solar-energy" }, desc = "Solar panels. Free power, by day." },
  { id = "oil", name = "Oil Industry", tech = "oil-processing", price = 1600,
    techs = { "oil-processing", "fluid-handling" }, desc = "Pumpjacks, refineries, chemical plants, tanks and pumps." },
  { id = "plastics", name = "Plastics & Red Circuits", tech = "advanced-circuit", price = 2200, requires = "oil",
    techs = { "plastics", "advanced-circuit" }, desc = "Plastic bars and advanced circuits. Very sellable." },
  { id = "sulfur", name = "Sulfur & Batteries", tech = "battery", price = 1800, requires = "oil",
    techs = { "sulfur-processing", "battery" }, desc = "Sulfur, sulfuric acid and batteries." },
  { id = "accumulators", name = "Accumulators", tech = "electric-energy-accumulators", price = 1500, requires = "sulfur",
    techs = { "electric-energy-accumulators" }, desc = "Store solar power for an eclipse." },
  { id = "flamer", name = "Flamethrower Turrets", tech = "flamethrower", price = 2500, requires = "oil",
    techs = { "flamethrower" }, desc = "Burn the raiders." },
  { id = "modules", name = "Modules", tech = "modules", price = 3000, requires = "plastics",
    techs = { "modules", "speed-module", "productivity-module", "efficiency-module" },
    desc = "Speed, productivity and efficiency modules." },
  { id = "bulk", name = "Bulk Inserters", tech = "bulk-inserter", price = 3200, requires = "plastics",
    techs = { "bulk-inserter" }, desc = "Inserters that move whole handfuls." },
  { id = "bluesci", name = "Chemical Science", tech = "chemical-science-pack", price = 2600, requires = "sulfur",
    techs = { "chemical-science-pack" }, desc = "Blue science packs. Unlocks the late catalog." },
  { id = "power2", name = "Substations", tech = "electric-energy-distribution-2", price = 2800, requires = "bluesci",
    techs = { "electric-energy-distribution-2" }, desc = "Substations." },
  { id = "efurnace", name = "Electric Furnaces", tech = "advanced-material-processing-2", price = 3500, requires = "bluesci",
    techs = { "advanced-material-processing-2" }, desc = "Electric furnaces: steel-furnace speed, no fuel, two module slots." },
  { id = "advoil", name = "Advanced Oil", tech = "advanced-oil-processing", price = 2500, requires = "bluesci",
    techs = { "advanced-oil-processing" }, desc = "Advanced oil processing and cracking." },
  { id = "lasers", name = "Laser Turrets", tech = "laser-turret", price = 4500, requires = "bluesci",
    techs = { "laser-turret" }, desc = "Turrets that need no ammo." },
  { id = "robots", name = "Construction Robots", tech = "construction-robotics", price = 5000, requires = "bluesci",
    techs = { "construction-robotics" }, desc = "Roboports and construction robots. Blueprints build themselves." },
  { id = "logibots", name = "Logistic Robots", tech = "logistic-robotics", price = 5000, requires = "robots",
    techs = { "logistic-robotics" }, desc = "Logistic robots and chests." },
  { id = "blue", name = "Processing Units", tech = "processing-unit", price = 6000, requires = "bluesci",
    techs = { "processing-unit" }, desc = "Blue circuits. The good stuff." },
  { id = "uranium", name = "Uranium Processing", tech = "uranium-processing", price = 5000, requires = "bluesci",
    techs = { "uranium-mining", "uranium-processing" }, desc = "Mine uranium with acid, spin it in centrifuges." },
  { id = "prodsci", name = "Production Science", tech = "production-science-pack", price = 7000, requires = "modules",
    techs = { "production-science-pack" }, desc = "Purple science packs (and rails). A fortune per pack." },
  { id = "logistics3", name = "Express Belts", tech = "logistics-3", price = 7500, requires = "prodsci",
    techs = { "logistics-3" }, desc = "Express transport belts." },
  { id = "automation3", name = "Assembler 3", tech = "automation-3", price = 8000, requires = "prodsci",
    techs = { "automation-3" }, desc = "The fastest assemblers." },
  { id = "utilsci", name = "Utility Science", tech = "utility-science-pack", price = 9000, requires = "blue",
    techs = { "utility-science-pack" }, desc = "Yellow science packs. Worth a fortune." },
}
SH.RND_BY_ID = {}
for _, r in ipairs(SH.RND) do SH.RND_BY_ID[r.id] = r end

local function tech(name)
  return U.force().technologies[name]
end

function SH.rnd_owned(entry)
  for _, t in ipairs(entry.techs) do
    local tt = tech(t)
    if tt and not tt.researched then return false end
  end
  return true
end

-- Why an R&D entry can't be bought yet (prerequisite entry or zoning), or nil.
function SH.rnd_locked(entry)
  if entry.requires then
    local req = SH.RND_BY_ID[entry.requires]
    if req and not SH.rnd_owned(req) then return "Needs " .. req.name end
  end
  return Z.lock(entry)
end

-- Recipes the entry's technologies unlock (for the hover icons).
function SH.rnd_unlocks(entry)
  local out, seen = {}, {}
  for _, name in ipairs(entry.techs) do
    local proto = prototypes.technology[name]
    for _, eff in ipairs(proto and proto.effects or {}) do
      if eff.type == "unlock-recipe" and eff.recipe and not seen[eff.recipe] and prototypes.recipe[eff.recipe] then
        seen[eff.recipe] = true
        out[#out + 1] = eff.recipe
      end
    end
  end
  return out
end

function SH.rnd_price(entry)
  return U.round_nice(entry.price * L.catalog_mult(true))
end

local function research(name, seen)
  seen = seen or {}
  if seen[name] then return end
  seen[name] = true
  local t = tech(name)
  if not t or t.researched then return end
  for pname in pairs(t.prerequisites) do research(pname, seen) end
  t.researched = true
end
SH.research = research

function SH.buy_rnd(id)
  local entry = SH.RND_BY_ID[id]
  if not entry then return false, "Unknown item." end
  if SH.rnd_owned(entry) then return false, "Already researched." end
  local lock = SH.rnd_locked(entry)
  if lock then return false, lock .. "." end
  local price = SH.rnd_price(entry)
  if not L.spend(price) then return false, "Not enough money." end
  local seen = {}
  for _, t in ipairs(entry.techs) do research(t, seen) end
  storage.q.stats.rnd = (storage.q.stats.rnd or 0) + 1
  S.jingle("buy")
  U.company({ "", "Tech licensed and researched: [technology=", entry.tech, "]" })
  return true, entry.name .. " researched."
end

-- Repeatable upgrades.
function SH.upgrade_level(id)
  return storage.q.upgrades[id] or 0
end

function SH.upgrade_price(u)
  local lvl = SH.upgrade_level(u.id)
  return U.round_nice(u.base * u.growth ^ lvl * L.catalog_mult(true))
end

function SH.upgrade_locked(u)
  if u.requires == "robots" then
    local t = tech("construction-robotics")
    if not (t and t.researched) then return "Needs Construction Robots." end
  end
  return nil
end

function SH.buy_upgrade(id)
  local u = P.UPGRADE_BY_ID[id]
  if not u then return false, "Unknown upgrade." end
  local lvl = SH.upgrade_level(id)
  if lvl >= u.max then return false, "Maxed out." end
  local lock = SH.upgrade_locked(u)
  if lock then return false, lock end
  if not L.spend(SH.upgrade_price(u)) then return false, "Not enough money." end
  storage.q.upgrades[id] = lvl + 1
  P.apply()
  S.jingle("buy")
  return true, u.name .. " upgraded to level " .. (lvl + 1) .. "."
end

-- =========================================================== Supplies ===

-- items: { name, count, alt = better item used once unlocked, needs = recipe that must be unlocked }
SH.CRATES = {
  { id = "belts", name = "Belt Bundle", sprite = "item/transport-belt",
    items = { { "transport-belt", 150 }, { "underground-belt", 16 }, { "splitter", 4 } } },
  { id = "inserters", name = "Inserter Pack", sprite = "item/inserter",
    items = { { "inserter", 30 }, { "long-handed-inserter", 10 }, { "fast-inserter", 10, needs = "fast-inserter" } } },
  { id = "mining", name = "Mining Expansion", sprite = "item/electric-mining-drill",
    items = { { "electric-mining-drill", 10 }, { "small-electric-pole", 20, alt = "medium-electric-pole" } } },
  { id = "assembly", name = "Assembly Line", sprite = "item/assembling-machine-1",
    items = { { "assembling-machine-1", 8, alt = "assembling-machine-2" } } },
  { id = "smelting", name = "Smelting Column", sprite = "item/stone-furnace",
    items = { { "stone-furnace", 24, alt = "steel-furnace" } } },
  { id = "power", name = "Steam Expansion", sprite = "item/steam-engine",
    items = { { "boiler", 1 }, { "steam-engine", 2 }, { "pipe", 10 } } },
  { id = "powerplant", name = "Steam Power Plant", sprite = "item/boiler",
    items = { { "offshore-pump", 1 }, { "boiler", 4 }, { "steam-engine", 8 }, { "pipe", 30 } } },
  { id = "grid", name = "Power Grid", sprite = "item/substation",
    items = { { "small-electric-pole", 30, alt = "medium-electric-pole" }, { "big-electric-pole", 10, needs = "big-electric-pole" },
      { "substation", 10, needs = "substation" } } },
  { id = "defense", name = "Security Kit", sprite = "item/gun-turret",
    items = { { "gun-turret", 4 }, { "firearm-magazine", 100, alt = "piercing-rounds-magazine" }, { "stone-wall", 60 } } },
  { id = "fastbelts", name = "Fast Belt Bundle", sprite = "item/fast-transport-belt", needs = "fast-transport-belt",
    items = { { "fast-transport-belt", 200 }, { "fast-underground-belt", 20 }, { "fast-splitter", 6 } } },
  { id = "solar", name = "Solar Farm", sprite = "item/solar-panel", needs = "solar-panel",
    items = { { "solar-panel", 20 }, { "accumulator", 10, needs = "accumulator" } } },
  { id = "oil", name = "Oil Rig", sprite = "item/pumpjack", needs = "oil-refinery",
    items = { { "pumpjack", 4 }, { "oil-refinery", 2 }, { "chemical-plant", 4 }, { "pipe", 60 },
      { "pipe-to-ground", 10 }, { "storage-tank", 2 } } },
  { id = "robots", name = "Robot Starter", sprite = "item/roboport", needs = "roboport",
    items = { { "roboport", 2 }, { "construction-robot", 20 }, { "logistic-robot", 10, needs = "logistic-robot" },
      { "passive-provider-chest", 4, needs = "passive-provider-chest" }, { "storage-chest", 4, needs = "storage-chest" } } },
  { id = "modules", name = "Module Case", sprite = "item/productivity-module", needs = "productivity-module",
    items = { { "speed-module", 6 }, { "productivity-module", 6 } } },
}
SH.CRATE_BY_ID = {}
for _, c in ipairs(SH.CRATES) do SH.CRATE_BY_ID[c.id] = c end

local function unlocked(recipe)
  local r = U.force().recipes[recipe]
  return r ~= nil and r.enabled
end
SH.unlocked = unlocked

function SH.crate_available(c)
  return not c.needs or unlocked(c.needs)
end

-- Resolved contents for a crate right now.
function SH.crate_items(c)
  local out = {}
  for _, it in ipairs(c.items) do
    local name = it[1]
    if it.alt and unlocked(it.alt) then name = it.alt end
    if (not it.needs or unlocked(it.needs)) and prototypes.item[name] then
      out[#out + 1] = { name, it[2] }
    end
  end
  return out
end

function SH.crate_price(c)
  local total = 0
  for _, it in ipairs(SH.crate_items(c)) do
    local markup = storage.q.equipment[it[1]] and C.SUPPLY_MARKUP_MACHINE or C.SUPPLY_MARKUP_PRODUCT
    total = total + V.full(it[1]) * it[2] * markup
  end
  return U.round_nice(math.max(50, total) * L.catalog_mult(true))
end

function SH.buy_crate(id)
  local c = SH.CRATE_BY_ID[id]
  if not c then return false, "Unknown crate." end
  if not SH.crate_available(c) then return false, "Not unlocked yet." end
  if not L.spend(SH.crate_price(c)) then return false, "Not enough money." end
  D.drop(SH.crate_items(c), { label = c.name })
  storage.q.stats.crates = (storage.q.stats.crates or 0) + 1
  S.jingle("buy")
  return true, c.name .. ": drop pod inbound, landing next to you."
end

-- Single orders: any placeable item whose recipe you've unlocked, by the pack or the stack.
-- Placeables only: they scrap for 10% at the terminal, so buying them can't be flipped for profit.
-- Tiles (landfill) stay out on purpose: land is bought plot by plot.
local made_by -- item name -> recipe names; prototypes don't change at runtime, so a local cache is safe

local function index()
  if made_by then return made_by end
  made_by = {}
  for rname, r in pairs(prototypes.recipe) do
    local ok = not r.hidden and not r.parameter
    for cat in pairs(r.categories or {}) do
      if C.UNPRICED_CATEGORIES[cat] then ok = false end
    end
    if ok then
      for _, p in ipairs(r.products or {}) do
        if p.type == "item" then
          local list = made_by[p.name] or {}
          list[#list + 1] = rname
          made_by[p.name] = list
        end
      end
    end
  end
  return made_by
end

function SH.orderable(name)
  local proto = prototypes.item[name]
  if not proto or proto.hidden or proto.parameter then return false end
  if name:sub(1, 6) == "quota-" then return false end
  if not storage.q.equipment[name] or V.full(name) <= 0 then return false end
  for _, rname in ipairs(index()[name] or {}) do
    if unlocked(rname) then return true end
  end
  return false
end

-- Orderable items in the crafting menu's order.
function SH.order_list()
  local out = {}
  for name in pairs(index()) do
    if SH.orderable(name) then out[#out + 1] = prototypes.item[name] end
  end
  table.sort(out, function(a, b)
    if a.group.order ~= b.group.order then return a.group.order < b.group.order end
    if a.subgroup.order ~= b.subgroup.order then return a.subgroup.order < b.subgroup.order end
    if a.order ~= b.order then return a.order < b.order end
    return a.name < b.name
  end)
  local names = {}
  for i, p in ipairs(out) do names[i] = p.name end
  return names
end

-- The two sizes on offer: a tenth of a stack and a full stack.
function SH.order_sizes(name)
  local stack = prototypes.item[name].stack_size
  local small = math.max(1, math.floor(stack / 10))
  if small == stack then return { stack } end
  return { small, stack }
end

function SH.order_price(name, n)
  return U.round_nice(V.full(name) * n * C.SUPPLY_MARKUP_MACHINE * L.catalog_mult(true))
end

function SH.buy_order(name, n)
  if not SH.orderable(name) then return false, "Not unlocked yet." end
  if not U.contains(SH.order_sizes(name), n) then return false, "Not a size we sell." end
  if not L.spend(SH.order_price(name, n)) then return false, "Not enough money." end
  local pretty = name:gsub("-", " "):gsub("^%l", string.upper)
  D.drop({ { name, n } }, { label = n .. "x " .. pretty })
  storage.q.stats.crates = (storage.q.stats.crates or 0) + 1
  S.jingle("buy")
  return true, "Order placed: drop pod inbound, landing next to you."
end

-- Mystery crate: a gamble, usually worth it.
local MYSTERY = {
  "assembling-machine-2", "steel-furnace", "electric-mining-drill", "fast-inserter", "bulk-inserter",
  "fast-transport-belt", "express-transport-belt", "solar-panel", "accumulator", "medium-electric-pole",
  "big-electric-pole", "substation", "roboport", "construction-robot", "gun-turret", "laser-turret",
  "assembling-machine-3", "electric-furnace", "beacon", "pumpjack", "chemical-plant", "car", "tank",
  "speed-module", "productivity-module", "efficiency-module", "lab", "radar", "steel-chest",
}

function SH.mystery_price()
  return U.round_nice(math.max(300, (storage.q.quota or 400) * 0.1) * L.catalog_mult(true))
end

function SH.buy_mystery()
  local price = SH.mystery_price()
  if not L.spend(price) then return false, "Not enough money." end
  local budget = price * (1.2 + U.random() * 1.2)
  local items = {}
  local pool = {}
  for _, n in ipairs(MYSTERY) do if prototypes.item[n] then pool[#pool + 1] = n end end
  U.shuffle(pool)
  for i = 1, math.min(5, #pool) do
    local n = pool[i]
    local v = math.max(1, V.full(n))
    local count = math.max(1, math.floor((budget / 5) / v))
    count = math.min(count, prototypes.item[n].stack_size * 2)
    items[#items + 1] = { n, count }
  end
  D.drop(items, { label = "Mystery Crate" })
  S.jingle("buy")
  return true, "Mystery Crate: drop pod inbound, landing next to you."
end

function SH.terminal_price()
  local extra = storage.q.terminals_bought or 0
  return U.round_nice(1500 * 1.7 ^ extra * L.catalog_mult(true))
end

function SH.buy_terminal()
  if not L.spend(SH.terminal_price()) then return false, "Not enough money." end
  storage.q.terminals_bought = (storage.q.terminals_bought or 0) + 1
  D.drop({ { "quota-terminal", 1 } }, { label = "Shipping Terminal", issue = false })
  S.jingle("buy")
  return true, "Shipping Terminal: drop pod inbound, landing next to you. Place it anywhere."
end

-- ============================================================== Land ===

function SH.plot_price(plot)
  return U.round_nice(W.price(plot) * L.catalog_mult(true))
end

function SH.buy_plot(px, py)
  local plot = W.plot(px, py)
  if not plot then return false, "No such plot." end
  if plot.owned then return false, "You already own it." end
  if not W.purchasable(px, py) then return false, "Only plots next to your land are for sale." end
  local price = SH.plot_price(plot)
  if not L.spend(price) then return false, "Not enough money." end
  local before = Z.licensed()
  W.claim(px, py, false)
  storage.q.stats.plots = (storage.q.stats.plots or 0) + 1
  S.jingle("land")
  U.company({ "", "Deed transferred: ", W.TYPES[plot.type].name, ". Watch it rise." })
  Z.apply()
  if Z.licensed() > before then
    U.company({ "", "[color=100,255,110]Zoning approved:[/color] tier ", Z.licensed(),
      " technology is now licensed. Check the Tech tab." })
  end
  return true, W.TYPES[plot.type].name .. " is rising from the sea."
end

-- ========================================================= Contracts ===

function SH.contract_price(id)
  local q = storage.q
  local d = P.BY_ID[id]
  local r = C.RARITY[d.rarity]
  local basis = (q.next and q.next.quota) or q.quota or 400
  return U.round_nice(math.max(C.CONTRACT_MIN_PRICE, r.price * basis))
end

function SH.roll_offers()
  local q = storage.q
  local count = C.OFFER_COUNT + (P.has("lucky") and 1 or 0)
  local offers = {}
  local taken = {}
  for _, id in ipairs(q.perks) do taken[id] = true end
  for _ = 1, count do
    local pool = {}
    for _, d in ipairs(P.DEFS) do
      if not taken[d.id] then pool[#pool + 1] = d end
    end
    local d = U.weighted_pick(pool, function(x) return C.RARITY[x.rarity].weight end)
    if not d then break end
    taken[d.id] = true
    offers[#offers + 1] = d.id
  end
  q.offers = offers
end

function SH.reroll_price()
  local q = storage.q
  local basis = (q.next and q.next.quota) or q.quota or 400
  return U.round_nice(math.max(C.REROLL_MIN, C.REROLL_BASE * basis) * C.REROLL_GROWTH ^ (q.rerolls or 0))
end

function SH.reroll()
  local q = storage.q
  if q.phase ~= "break" then return false, "Contracts are only offered during breaks." end
  if not L.spend(SH.reroll_price()) then return false, "Not enough money." end
  q.rerolls = (q.rerolls or 0) + 1
  SH.roll_offers()
  S.play("quota-snare", 0.8)
  return true, "New contracts on the table."
end

function SH.buy_contract(id)
  local q = storage.q
  if q.phase ~= "break" then return false, "Contracts are only offered during breaks." end
  if not U.contains(q.offers, id) then return false, "That contract is no longer on offer." end
  if P.count() >= P.slots() then return false, "No free contract slot. Sell one first." end
  local price = SH.contract_price(id)
  if not L.spend(price) then return false, "Not enough money." end
  q.perks[#q.perks + 1] = id
  q.perk_paid[id] = price
  local keep = {}
  for _, o in ipairs(q.offers) do if o ~= id then keep[#keep + 1] = o end end
  q.offers = keep
  P.apply()
  M.sync_insider(q.next)
  S.jingle("buy")
  return true, "Signed: " .. P.BY_ID[id].name .. "."
end

function SH.sell_contract(id)
  local q = storage.q
  if not P.has(id) then return false, "You don't hold that contract." end
  local refund = math.floor((q.perk_paid[id] or 0) / 2)
  local keep = {}
  for _, v in ipairs(q.perks) do if v ~= id then keep[#keep + 1] = v end end
  q.perks = keep
  q.perk_paid[id] = nil
  q.wallet = q.wallet + refund
  P.apply()
  if q.next then M.sync_insider(q.next) end
  S.play("quota-snare", 0.8)
  return true, "Sold " .. P.BY_ID[id].name .. " for " .. U.money(refund) .. "."
end

-- ==================================================== Corporate offers ===

SH.OFFERS = {
  { id = "buyout", name = "Leveraged Buyout", sprite = "virtual-signal/signal-percent",
    blurb = "Cash now (75% of the next quota). Every future quota is 15% higher.",
    text = function(c) return "Get " .. U.money(c) .. " right now. Every future quota is 15% higher." end,
    cash = 0.75 },
  { id = "options", name = "Stock Options", sprite = "virtual-signal/up-arrow",
    blurb = "+1 contract slot. Every future quota is 10% higher.",
    text = function() return "+1 contract slot. Every future quota is 10% higher." end },
  { id = "waiver", name = "Hazard Waiver", sprite = "virtual-signal/signal-skull",
    blurb = "Cash now (50% of the next quota). Every shift from now on has one extra condition.",
    text = function(c) return "Get " .. U.money(c) .. " right now. Every shift from now on has one extra condition." end,
    cash = 0.5 },
  { id = "outsourcing", name = "Outsourcing", sprite = "virtual-signal/signal-shuffle",
    blurb = "Your next quota is 40% lower. Everything sells for 12% less for the rest of the run.",
    text = function() return "Your next quota is 40% lower. Everything sells for 12% less for the rest of the run." end },
  { id = "fraud", name = "Insurance Fraud", sprite = "virtual-signal/signal-white-flag",
    blurb = "Gain one extra written warning. Lose 40% of your wallet.",
    text = function() return "Gain one extra written warning. Lose 40% of your wallet." end },
  { id = "venture", name = "Venture Capital", sprite = "virtual-signal/signal-star",
    blurb = "Cash now (a full next quota). You lose every written warning you have left.",
    text = function(c) return "Get " .. U.money(c) .. " right now. You lose every written warning you have left." end,
    cash = 1.0 },
}
SH.OFFER_BY_ID = {}
for _, o in ipairs(SH.OFFERS) do SH.OFFER_BY_ID[o.id] = o end

function SH.offer_cash(o)
  local q = storage.q
  if not o.cash then return 0 end
  return U.round_nice(o.cash * ((q.next and q.next.quota) or q.quota or 400))
end

function SH.roll_corporate()
  local q = storage.q
  local pool = {}
  for _, o in ipairs(SH.OFFERS) do pool[#pool + 1] = o.id end
  U.shuffle(pool)
  q.corporate = { pool[1], pool[2], pool[3] }
end

-- Returns ok, message, needs_reprepare.
function SH.accept_corporate(id)
  local q = storage.q
  if not (q.corporate and U.contains(q.corporate, id)) then return false, "That offer has expired." end
  local o = SH.OFFER_BY_ID[id]
  local cash = SH.offer_cash(o)
  if cash > 0 then q.wallet = q.wallet + cash end
  if id == "buyout" then q.quota_mult = q.quota_mult * 1.15 end
  if id == "options" then
    q.perk_slots = (q.perk_slots or C.CONTRACT_SLOTS) + 1
    q.quota_mult = q.quota_mult * 1.10
  end
  if id == "waiver" then
    q.extra_condition = true
    q.add_condition_now = true
  end
  if id == "outsourcing" then
    q.next_quota_mult = 0.6
    q.run_price_mult = (q.run_price_mult or 1) * 0.88
  end
  if id == "fraud" then
    q.warnings_left = q.warnings_left + 1
    q.wallet = q.wallet * 0.6
  end
  if id == "venture" then q.warnings_left = 0 end
  q.corporate = nil
  q.stats.deals = (q.stats.deals or 0) + 1
  S.jingle("payday")
  U.company({ "", "Deal signed: ", o.name, ". Pleasure doing business." })
  return true, o.name .. " signed.", true
end

function SH.decline_corporate()
  storage.q.corporate = nil
  return true, "Offer declined."
end

return SH
