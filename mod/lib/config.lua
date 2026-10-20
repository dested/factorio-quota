-- QUOTA: every tunable number lives here.

local C = {}

C.SURFACE_PREFIX = "quota"
C.FORCE = "player"

-- ------------------------------------------------------------- timing ---
C.SECOND = 60
C.MINUTE = 3600
C.BREAK_SECONDS = 90
C.BRIEFING_SECONDS = 30      -- look-around time before shift 1 (clock in early to skip it)

-- Shift length (seconds) and base quota per shift, Associate difficulty.
C.SHIFTS = {
  { len = 300, quota = 400 },
  { len = 300, quota = 1100 },
  { len = 360, quota = 2400 },
  { len = 360, quota = 4200 },
  { len = 390, quota = 6800 },
  { len = 420, quota = 10500 },
  { len = 420, quota = 15500 },
  { len = 480, quota = 22000 },
}
C.ENDLESS_LEN = 480
C.ENDLESS_GROWTH = 1.45
C.LONG_GROWTH = 1.4           -- runs longer than the table: quota x this per extra shift
C.COMPLEX_QUOTA_STEP = 0.05   -- Complex: quotas +5% per shift from shift 4 (deep goods pay more)

C.DIFFICULTIES = {
  intern = {
    name = "Intern", quota = 0.6, warnings = 2, raid = 0.6, cond_from = 3, double_from = 99,
    blurb = "Gentle quotas. Two written warnings before they let you go.",
  },
  associate = {
    name = "Associate", quota = 1.0, warnings = 1, raid = 1.0, cond_from = 2, double_from = 7,
    blurb = "The intended experience. One written warning.",
  },
  crunch = {
    name = "Crunch Time", quota = 1.4, warnings = 0, raid = 1.4, cond_from = 2, double_from = 5,
    blurb = "Brutal quotas, nasty conditions early, zero warnings. Good luck.",
  },
}
C.DIFFICULTY_ORDER = { "intern", "associate", "crunch" }

-- Exceed quota by this ratio and The Company "adjusts" your next quota.
C.PERFORMANCE_TRIGGER = 1.5
C.PERFORMANCE_TAKE = 0.15

-- --------------------------------------------------------------- money ---
C.OVERTIME_RATE = 0.20        -- share of excess paid as overtime bonus
C.EARLY_BIRD_RATE = 0.001     -- x next quota, per break second skipped
C.CLOCK_OUT_RATE = 0.001      -- quota met: clock out early for this x quota per shift second left
C.CLOCK_OUT_CAP = 0.25        -- ...capped at 25% of the quota
C.CLOCK_OUT_MIN_SECS = 10
C.SCRAP_RATE = 0.10           -- machinery sells for 10% of its value

-- Item valuation: crafted = (inputs + seconds * TIME_VALUE) * MARKUP.
C.TIME_VALUE = 0.4
C.MARKUP = 1.2
C.RAW_VALUES = {
  ["iron-ore"] = 1, ["copper-ore"] = 1, ["coal"] = 1, ["stone"] = 1,
  ["uranium-ore"] = 3, ["wood"] = 1, ["raw-fish"] = 4,
  ["crude-oil"] = 0.15, ["water"] = 0, ["steam"] = 0,
}
C.VALUE_OVERRIDES = { ["uranium-235"] = 300 }
-- Value multipliers after the recipe pass. Shotgun shells are one hand-craft from plates and
-- were the best money in the early game; now they roughly break even on their plates.
C.VALUE_SCALE = { ["shotgun-shell"] = 0.8 }
-- Never rolled hot (still sellable).
C.NOT_HOT = { ["shotgun-shell"] = true }

-- Complex mode, "Complexity Pays": products sell for value x (BASE + STEP x depth), where depth
-- counts crafting steps from raw (plates 1, gears 2, circuits 3, green science 5...).
C.COMPLEX_BASE = 0.6
C.COMPLEX_STEP = 0.2
C.COMPLEX_CAP = 2.6

-- Complex mode, zoning: bought plots (HQ excluded) needed per tech tier.
-- Tier 1 red/green, 2 oil branch and military science, 3 chemical, 4 production and utility.
C.ZONING = { 0, 2, 4, 6 }
C.PACK_TIERS = {
  ["automation-science-pack"] = 1, ["logistic-science-pack"] = 1, ["military-science-pack"] = 2,
  ["chemical-science-pack"] = 3, ["production-science-pack"] = 4, ["utility-science-pack"] = 4,
}
C.OTHER_PACK_TIER = 5         -- space and planet packs: never licensed


-- Flooding: price x 1 / (1 + sold_value / (FLOOD_SCALE * quota)).
C.FLOOD_SCALE = 1.25
C.FLOOD_MIN_BASE = 250
C.FLOOD_CARRYOVER = 0.25

-- Hot items.
C.HOT_COUNT = 3
C.HOT_COUNT_LATE = 4          -- from shift 5
C.HOT_MULTS = { 2, 2.5, 3 }

-- Terminal.
C.TERMINAL_INTERVAL = 30      -- ticks between sales sweeps
C.TERMINAL_FLY_INTERVAL = 60  -- min ticks between "+$" flying texts per terminal

-- ---------------------------------------------------------------- shop ---
C.RUSH_FEE = 1.25
C.CONTRACT_SLOTS = 5
C.OFFER_COUNT = 3
C.RARITY = {
  common = { name = "Common", weight = 60, price = 0.18, color = { 0.75, 0.75, 0.75 } },
  uncommon = { name = "Uncommon", weight = 30, price = 0.32, color = { 0.35, 0.85, 0.45 } },
  rare = { name = "Rare", weight = 10, price = 0.50, color = { 0.45, 0.65, 1 } },
}
C.CONTRACT_MIN_PRICE = 150
C.REROLL_BASE = 0.04          -- x current quota
C.REROLL_MIN = 50
C.REROLL_GROWTH = 1.6
C.SUPPLY_MARKUP_MACHINE = 0.8 -- crates of placeable things (bulk discount; they only scrap for 10%)
C.SUPPLY_MARKUP_PRODUCT = 1.25 -- crates holding sellable products (company property, so they can't be flipped)

-- --------------------------------------------------------------- world ---
C.PLOT = 64
C.GRID_RADIUS = 4             -- plots from -4..4 on each axis
C.TERMINAL_POS = { x = 0, y = 0 }
C.PAD_HALF = 5                -- concrete pad around the terminal: 10x10

-- ----------------------------------------------------------- hazards ---
C.GREMLIN_INTERVAL = 20 * 60
C.GREMLIN_SPREAD_AFTER = 45 * 60
C.GREMLIN_MAX = 8
C.GREMLIN_WHACK_RADIUS = 4
C.GREMLIN_BOUNTY = 0.012      -- x quota

C.STRIKE_EVERY = 100 * 60
C.STRIKE_LENGTH = 20 * 60
C.STRIKE_WARNING = 10 * 60

C.QUAKES_PER_SHIFT = 3
C.QUAKE_WARNING = 5 * 60
C.QUAKE_RADIUS = 26

C.METEOR_MIN_GAP = 14 * 60   -- shift 8+; earlier showers are thinner (see METEOR_EASE)
C.METEOR_MAX_GAP = 26 * 60
C.METEOR_EASE = 5 * 60        -- extra gap per shift before shift 8
C.METEOR_HEAVY_FROM = 6       -- lighter meteors before this shift
C.METEOR_FLIGHT = 3 * 60

C.RAID_EVERY = 120 * 60
C.RAID_WARNING = 12 * 60

C.AUDITOR_SPAWN_AT = 90 * 60  -- ticks into the final shift
C.AUDITOR_FREEZE_RADIUS = 9
C.AUDITOR_BOUNTY = 0.6        -- x quota

-- Starter kit, dropped by pod at clock-in.
C.STARTER_KIT = {
  { "burner-mining-drill", 12 },
  { "stone-furnace", 24 },
  { "electric-mining-drill", 10 },
  { "assembling-machine-1", 8 },
  { "transport-belt", 300 },
  { "underground-belt", 20 },
  { "splitter", 10 },
  { "inserter", 60 },
  { "long-handed-inserter", 20 },
  { "burner-inserter", 10 },
  { "small-electric-pole", 60 },
  { "offshore-pump", 1 },
  { "boiler", 2 },
  { "steam-engine", 2 },
  { "pipe", 50 },
  { "pipe-to-ground", 10 },
  { "wooden-chest", 20 },
  { "iron-chest", 10 },
  { "coal", 100 },
  { "gun-turret", 6 },
  { "firearm-magazine", 200 },
  { "small-lamp", 10 },
  { "repair-pack", 20 },
}
C.CHARACTER_KIT = {
  { "submachine-gun", 1 },
  { "firearm-magazine", 50 },
}

C.STARTING_TECHS = {
  "steam-power", "electronics", "automation-science-pack", "electric-mining-drill",
  "repair-pack", "radar", "automation", "logistics", "gun-turret", "military",
  "stone-wall", "lamp",
}

return C
