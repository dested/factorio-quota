-- Complex mode zoning: The Company licenses technology by how much land you hold.
-- Tier 1 (red/green) runs on HQ alone; the oil branch and military science need
-- 2 bought plots, chemical science 4, production and utility 6.
--
-- A tech's tier is the highest of its own science packs and its prerequisites'
-- tiers, with oil-processing pinned to at least 2, so the whole oil branch
-- follows. Locked techs are disabled in the vanilla tree too (labs can't bypass
-- zoning); only techs this module disabled are ever re-enabled.

local C = require("lib.config")
local U = require("lib.util")
local W = require("lib.world")
local R = require("lib.rules")

local Z = {}

local OIL_ROOT = "oil-processing"

local function pack_tier(tech)
  local tier = 1
  for _, ing in pairs(tech.research_unit_ingredients or {}) do
    local t = C.PACK_TIERS[ing.name] or C.OTHER_PACK_TIER
    if t > tier then tier = t end
  end
  return tier
end

local function tier_of(tech, memo, depth)
  local name = tech.name
  if memo[name] then return memo[name] end
  if depth > 200 then return 1 end
  memo[name] = 1 -- cycle guard
  local tier = pack_tier(tech)
  if name == OIL_ROOT and tier < 2 then tier = 2 end
  for _, pre in pairs(tech.prerequisites) do
    local t = tier_of(pre, memo, depth + 1)
    if t > tier then tier = t end
  end
  memo[name] = tier
  return tier
end

-- Zoning tier of a technology (by name).
function Z.tier(name)
  local q = storage.q
  q.tech_tiers = q.tech_tiers or {}
  local cached = q.tech_tiers[name]
  if cached then return cached end
  local tech = U.force().technologies[name]
  if not tech then return 1 end
  local t = tier_of(tech, q.tech_tiers, 0)
  return t
end

function Z.bought()
  return math.max(0, W.owned_count() - 1)
end

-- Highest tier the current land allows.
function Z.licensed()
  if not R.complex() then return 99 end
  local n = Z.bought()
  local tier = 0
  for i, need in ipairs(C.ZONING) do
    if n >= need then tier = i end
  end
  return tier
end

-- Plots needed for a tier, or nil when no amount of land licenses it.
function Z.needed(tier)
  return C.ZONING[tier]
end

-- Highest tier among an R&D entry's techs.
function Z.entry_tier(entry)
  local tier = 1
  for _, t in ipairs(entry.techs) do
    local tt = Z.tier(t)
    if tt > tier then tier = tt end
  end
  return tier
end

-- Lock text for an R&D entry, or nil when zoning allows it.
function Z.lock(entry)
  if not R.complex() then return nil end
  local tier = Z.entry_tier(entry)
  if tier <= Z.licensed() then return nil end
  local need = Z.needed(tier)
  if not need then return "Not licensed" end
  return "Zoning: own " .. need .. " plots (you own " .. Z.bought() .. ")"
end

-- Disable vanilla research above the licensed tier; re-enable what we disabled once licensed.
function Z.apply()
  local q = storage.q
  local force = U.force()
  q.zoned = q.zoned or {}
  local cap = Z.licensed()
  local opened = 0
  for name, tech in pairs(force.technologies) do
    if not tech.researched then
      local tier = Z.tier(name)
      if tier > cap then
        if tech.enabled and not q.zoned[name] then
          tech.enabled = false
          tech.visible_when_disabled = true
          q.zoned[name] = true
        end
      elseif q.zoned[name] then
        tech.enabled = true
        q.zoned[name] = nil
        opened = opened + 1
      end
    elseif q.zoned[name] then
      q.zoned[name] = nil
    end
  end
  return opened
end

-- Lines for the Land tab: each tier, what it needs, whether it's open.
function Z.summary()
  local rows = {}
  local names = { "Basics: red and green science", "Oil, plastics, batteries, military science",
    "Chemical science, robots, modules, nuclear", "Production and utility science" }
  local cap = Z.licensed()
  for i, need in ipairs(C.ZONING) do
    rows[#rows + 1] = { tier = i, need = need, name = names[i] or ("Tier " .. i), open = i <= cap }
  end
  return rows
end

return Z
