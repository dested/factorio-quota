-- Contracts (the jokers) and R&D upgrades, plus the one place that turns all
-- of them into force modifiers, recipe productivity and price multipliers.
--
-- apply() is idempotent: it remembers what it last added to each force field
-- and applies only the difference, so it coexists with vanilla research
-- bonuses and can be called after any change.

local C = require("lib.config")
local U = require("lib.util")

local P = {}

local SCRAP_ITEMS = {
  ["iron-ore"] = true, ["copper-ore"] = true, ["stone"] = true, ["coal"] = true, ["uranium-ore"] = true,
  ["iron-plate"] = true, ["copper-plate"] = true, ["steel-plate"] = true, ["stone-brick"] = true, ["wood"] = true,
}
local OIL_ITEMS = {
  ["plastic-bar"] = true, ["sulfur"] = true, ["solid-fuel"] = true, ["rocket-fuel"] = true,
  ["crude-oil-barrel"] = true, ["heavy-oil-barrel"] = true, ["light-oil-barrel"] = true,
  ["petroleum-gas-barrel"] = true, ["lubricant-barrel"] = true, ["sulfuric-acid-barrel"] = true,
  ["explosives"] = true, ["battery"] = true,
}

P.DEFS = {
  -- common ------------------------------------------------------------
  { id = "espresso", name = "Espresso Machine", rarity = "common", sprite = "utility/character_running_speed_modifier_icon",
    desc = "+50% running speed. +50% hand-crafting speed.", mods = { running = 0.5, craft = 0.5 } },
  { id = "pockets", name = "Cargo Pants", rarity = "common", sprite = "utility/character_inventory_slots_bonus_modifier_icon",
    desc = "+20 inventory slots.", mods = { inventory = 20 } },
  { id = "arms", name = "Telescoping Arms", rarity = "common", sprite = "utility/character_reach_distance_modifier_icon",
    desc = "+8 reach and build distance. +4 mining reach.", mods = { reach = 8, build = 8, resource_reach = 4 } },
  { id = "wholesale", name = "Wholesale License", rarity = "common", sprite = "virtual-signal/signal-percent",
    desc = "Everything sells for +15%." },
  { id = "scrap", name = "Scrap Dealer", rarity = "common", sprite = "item/iron-plate",
    desc = "Raw ore, plates, steel, bricks and wood sell for x2." },
  { id = "gearhead", name = "Gear Head", rarity = "common", sprite = "item/iron-gear-wheel",
    desc = "Iron gear wheels get +100% productivity. Two gears for the price of one.", recipes = { ["iron-gear-wheel"] = 1.0 } },
  { id = "wirewizard", name = "Wire Wizard", rarity = "common", sprite = "item/copper-cable",
    desc = "Copper cable gets +100% productivity.", recipes = { ["copper-cable"] = 1.0 } },
  { id = "handshake", name = "Golden Handshake", rarity = "common", sprite = "virtual-signal/signal-heart",
    desc = "Overtime bonus doubled: 40% of everything above quota." },
  { id = "earlybird", name = "Early Bird", rarity = "common", sprite = "virtual-signal/signal-sun",
    desc = "The clock-in-early bonus is tripled." },
  { id = "bigguns", name = "Company Security", rarity = "common", sprite = "item/gun-turret",
    desc = "+40% damage for bullets, shotguns, grenades, rockets and gun turrets.", mods = { damage = 0.4 } },
  -- uncommon ------------------------------------------------------------
  { id = "interest", name = "Compound Interest", rarity = "uncommon", sprite = "virtual-signal/signal-percent",
    desc = "Every payday, earn 10% interest on your wallet (up to 50% of the next quota)." },
  { id = "diversified", name = "Diversified Portfolio", rarity = "uncommon", sprite = "virtual-signal/signal-shuffle",
    desc = "+4% to all prices for each different item you have shipped this shift (max +60%)." },
  { id = "hype", name = "Hype Machine", rarity = "uncommon", sprite = "virtual-signal/signal-fire",
    desc = "Hot item multipliers are +1 higher." },
  { id = "orewhisperer", name = "Ore Whisperer", rarity = "uncommon", sprite = "utility/mining_drill_productivity_bonus_modifier_icon",
    desc = "+40% mining productivity.", mods = { mining = 0.4 } },
  { id = "dangerpay", name = "Danger Pay", rarity = "uncommon", sprite = "virtual-signal/signal-weapon",
    desc = "Every enemy you kill pays a bounty. Gremlin bounties are tripled." },
  { id = "meteorins", name = "Meteor Insurance", rarity = "uncommon", sprite = "virtual-signal/signal-explosion",
    desc = "Every meteor that lands pays out, and leaves triple the ore." },
  { id = "blackmarket", name = "Black Market", rarity = "uncommon", sprite = "virtual-signal/signal-lock",
    desc = "Tech, Supplies and Land are 25% cheaper." },
  { id = "pyramid", name = "Pyramid Scheme", rarity = "uncommon", sprite = "virtual-signal/up-arrow",
    desc = "Every payday, earn 6% of the quota for each contract you hold (this one included)." },
  { id = "unionrep", name = "Union Rep", rarity = "uncommon", sprite = "utility/inserter_stack_size_bonus_modifier_icon",
    desc = "Immune to strikes. Inserters carry +1 item, bulk inserters +2.", mods = { inserter_stack = 1, bulk = 2 } },
  { id = "nightowl", name = "Night Owl", rarity = "uncommon", sprite = "virtual-signal/signal-moon",
    desc = "Everything sells for +40% in the last 90 seconds of a shift, and +50% all through an Eclipse." },
  { id = "rocketscience", name = "Rocket Science", rarity = "uncommon", sprite = "item/automation-science-pack",
    desc = "Science packs sell for x3." },
  { id = "insider", name = "Insider Trading", rarity = "uncommon", sprite = "virtual-signal/signal-info",
    desc = "One extra hot item every shift: always your best seller from the shift before." },
  { id = "lucky", name = "Lucky Rabbit's Foot", rarity = "uncommon", sprite = "virtual-signal/signal-star",
    desc = "One extra contract offered every break. Good events happen twice as often." },
  -- rare ------------------------------------------------------------------
  { id = "monopoly", name = "Monopoly", rarity = "rare", sprite = "virtual-signal/signal-check",
    desc = "Your best-selling item each shift never floods the market." },
  { id = "silicon", name = "Silicon Valley", rarity = "rare", sprite = "item/electronic-circuit",
    desc = "All circuits get +50% productivity.",
    recipes = { ["electronic-circuit"] = 0.5, ["advanced-circuit"] = 0.5, ["processing-unit"] = 0.5 } },
  { id = "parachute", name = "Golden Parachute", rarity = "rare", sprite = "virtual-signal/signal-white-flag",
    desc = "Miss a quota and this contract gets shredded instead of you getting a warning. One use." },
  { id = "workaholic", name = "Workaholic", rarity = "rare", sprite = "virtual-signal/signal-clock",
    desc = "+6% to all prices, permanently, each time you hit quota with a minute to spare. Stacks." },
  { id = "smelter", name = "Smelters' Guild", rarity = "rare", sprite = "item/stone-furnace",
    desc = "Iron, copper, steel and brick smelting get +30% productivity.",
    recipes = { ["iron-plate"] = 0.3, ["copper-plate"] = 0.3, ["steel-plate"] = 0.3, ["stone-brick"] = 0.3 } },
  { id = "oilbaron", name = "Oil Baron", rarity = "rare", sprite = "fluid/crude-oil",
    desc = "Oil refining and plastic get +50% productivity. Oil products sell for +25%.",
    recipes = { ["basic-oil-processing"] = 0.5, ["advanced-oil-processing"] = 0.5, ["plastic-bar"] = 0.5 } },
  { id = "goldengear", name = "The Golden Gear", rarity = "rare", sprite = "item/iron-gear-wheel",
    desc = "Every 400th item you ship is golden and worth 100x. JACKPOT." },
}

P.BY_ID = {}
for _, d in ipairs(P.DEFS) do P.BY_ID[d.id] = d end

-- R&D upgrades (repeatable). Price = base * growth ^ level.
P.UPGRADES = {
  { id = "mining", name = "Mining Productivity", sprite = "utility/mining_drill_productivity_bonus_modifier_icon",
    desc = "+10% mining productivity.", base = 900, growth = 1.6, max = 8, mods = { mining = 0.1 } },
  { id = "stack", name = "Inserter Capacity", sprite = "utility/inserter_stack_size_bonus_modifier_icon",
    desc = "+1 item per inserter swing, +2 for bulk inserters.", base = 1400, growth = 2.0, max = 3, mods = { inserter_stack = 1, bulk = 2 } },
  { id = "damage", name = "Weapons Upgrade", sprite = "technology/physical-projectile-damage-1",
    desc = "+20% damage for bullets, shells, grenades, rockets and turrets.", base = 700, growth = 1.5, max = 6, mods = { damage = 0.2 } },
  { id = "crafting", name = "Hand-Crafting Training", sprite = "utility/character_crafting_speed_modifier_icon",
    desc = "+50% hand-crafting speed.", base = 500, growth = 1.8, max = 3, mods = { craft = 0.5 } },
  { id = "robots", name = "Worker Robot Speed", sprite = "technology/worker-robots-speed-1",
    desc = "+40% worker robot speed. Needs Construction Robots.", base = 2500, growth = 1.6, max = 4, mods = { robot_speed = 0.4 },
    requires = "robots" },
}
P.UPGRADE_BY_ID = {}
for _, u in ipairs(P.UPGRADES) do P.UPGRADE_BY_ID[u.id] = u end

-- ---------------------------------------------------------------- query ---

function P.has(id)
  local q = storage.q
  for _, v in ipairs(q.perks) do if v == id then return true end end
  return false
end

function P.count()
  return #storage.q.perks
end

function P.slots()
  return storage.q.perk_slots or C.CONTRACT_SLOTS
end

-- Night Owl: the whole of an Eclipse, or the last 90 seconds of any shift.
local function owl_mult()
  local q = storage.q
  if q.phase ~= "shift" then return 1 end
  if q.cond_active and q.cond_active.eclipse then return 1.5 end
  if game.tick >= q.shift_end - 90 * 60 then return 1.4 end
  return 1
end

-- Multiplier on an item's sale price from contracts.
function P.price_mult(name)
  local q = storage.q
  local m = 1
  if P.has("wholesale") then m = m * 1.15 end
  if P.has("scrap") and SCRAP_ITEMS[name] then m = m * 2 end
  if P.has("rocketscience") and name:find("science%-pack$") then m = m * 3 end
  if P.has("diversified") then m = m * (1 + math.min(0.6, 0.04 * (q.shift_distinct or 0))) end
  if P.has("workaholic") then m = m * (1 + 0.06 * (q.perk_state.workaholic or 0)) end
  if P.has("nightowl") then m = m * owl_mult() end
  if P.has("oilbaron") and OIL_ITEMS[name] then m = m * 1.25 end
  return m
end

function P.no_flood(name)
  local q = storage.q
  return P.has("monopoly") and q.monopoly_item == name
end

function P.hot_bonus()
  return P.has("hype") and 1 or 0
end

-- ---------------------------------------------------------------- apply ---

local FORCE_MODS = {
  running = "character_running_speed_modifier",
  inventory = "character_inventory_slots_bonus",
  reach = "character_reach_distance_bonus",
  build = "character_build_distance_bonus",
  resource_reach = "character_resource_reach_distance_bonus",
  mining = "mining_drill_productivity_bonus",
  inserter_stack = "inserter_stack_size_bonus",
  bulk = "bulk_inserter_capacity_bonus",
  craft = "manual_crafting_speed_modifier",
  robot_speed = "worker_robots_speed_modifier",
}
local AMMO = { "bullet", "shotgun-shell", "rocket", "grenade", "cannon-shell" }

function P.apply()
  local q = storage.q
  local force = U.force()
  local want, recipes = {}, {}
  local function add(mods, times)
    for k, v in pairs(mods) do want[k] = (want[k] or 0) + v * (times or 1) end
  end

  for _, id in ipairs(q.perks) do
    local d = P.BY_ID[id]
    if d then
      if d.mods then add(d.mods) end
      if d.recipes then
        for r, b in pairs(d.recipes) do recipes[r] = (recipes[r] or 0) + b end
      end
    end
  end
  for id, level in pairs(q.upgrades) do
    local u = P.UPGRADE_BY_ID[id]
    if u and level > 0 then add(u.mods, level) end
  end
  if q.cond_active and q.cond_active.lowgrav then want.running = (want.running or 0) + 0.8 end

  q.applied = q.applied or {}
  for key, field in pairs(FORCE_MODS) do
    local new = want[key] or 0
    local old = q.applied[key] or 0
    if new ~= old then
      force[field] = force[field] - old + new
      q.applied[key] = new
    end
  end

  local dmg, old_dmg = want.damage or 0, q.applied.damage or 0
  if dmg ~= old_dmg then
    for _, cat in ipairs(AMMO) do
      if prototypes.ammo_category[cat] then
        force.set_ammo_damage_modifier(cat, force.get_ammo_damage_modifier(cat) - old_dmg + dmg)
      end
    end
    force.set_turret_attack_modifier("gun-turret", force.get_turret_attack_modifier("gun-turret") - old_dmg + dmg)
    q.applied.damage = dmg
  end

  q.applied_recipes = q.applied_recipes or {}
  local names = {}
  for r in pairs(recipes) do names[r] = true end
  for r in pairs(q.applied_recipes) do names[r] = true end
  for r in pairs(names) do
    local new, old = recipes[r] or 0, q.applied_recipes[r] or 0
    local recipe = force.recipes[r]
    if new ~= old and recipe then
      recipe.productivity_bonus = recipe.productivity_bonus - old + new
      q.applied_recipes[r] = new
    end
  end

  q.price_mods = q.price_mods or {}
  q.price_mods.catalog = P.has("blackmarket") and 0.75 or 1
end

return P
