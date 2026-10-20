-- Item valuation, derived from the real recipe graph at init so every item the
-- game knows about gets a price without a hand-maintained table.
--
-- Raws are seeded from config. Then recipes are processed in waves: a recipe
-- whose ingredients all have values prices its products as
--   (sum of ingredient values + seconds * TIME_VALUE) * MARKUP / product units
-- and the cheapest recipe found in the earliest wave wins. Waves make cycles
-- (barrel fill/empty, kovarex) harmless: a product is priced once. The wave an
-- item is priced in is its depth (raws 0, plates 1, gears 2, circuits 3...),
-- which Complex mode's "Complexity Pays" premium reads.

local C = require("lib.config")

local V = {}

local function expected_amount(p)
  local amount = p.amount
  if amount == nil then
    amount = ((p.amount_min or 0) + (p.amount_max or 0)) / 2
  end
  amount = amount * (p.probability or 1)
  amount = amount + (p.extra_count_fraction or 0)
  return amount
end

function V.compute()
  local iv, fv = {}, {}
  local depth, via = {}, {}

  for name, v in pairs(C.RAW_VALUES) do
    if prototypes.item[name] then iv[name] = v end
    if prototypes.fluid[name] then fv[name] = v end
  end

  -- Anything a resource yields that config didn't price is a cheap raw.
  for _, ent in pairs(prototypes.get_entity_filtered({ { filter = "type", type = "resource" } })) do
    local mp = ent.mineable_properties
    if mp and mp.products then
      for _, p in pairs(mp.products) do
        if p.type == "fluid" then
          if fv[p.name] == nil then fv[p.name] = 0.05 end
        elseif iv[p.name] == nil then
          iv[p.name] = 1
        end
      end
    end
  end
  -- Fluids that come from pumping rather than recipes.
  for name in pairs(prototypes.fluid) do
    if fv[name] == nil and (name == "water" or name == "steam") then fv[name] = 0 end
  end

  local recipes = {}
  for _, r in pairs(prototypes.recipe) do
    if not r.hidden and not r.parameter then recipes[#recipes + 1] = r end
  end
  table.sort(recipes, function(a, b) return a.name < b.name end)

  for wave = 1, 60 do
    local found = {}
    for _, r in ipairs(recipes) do
      local ok = true
      local cost = (r.energy or 0.5) * C.TIME_VALUE
      for _, ing in pairs(r.ingredients) do
        local t = ing.type == "fluid" and fv or iv
        local v = t[ing.name]
        if v == nil then ok = false break end
        cost = cost + v * (ing.amount or 0)
      end
      if ok then
        cost = cost * C.MARKUP
        local units = 0
        for _, p in pairs(r.products) do
          if p.type == "item" or p.type == "fluid" then units = units + expected_amount(p) end
        end
        if units > 0 then
          local each = cost / units
          for _, p in pairs(r.products) do
            if p.type == "item" or p.type == "fluid" then
              local t = p.type == "fluid" and fv or iv
              if t[p.name] == nil then
                local key = p.type .. ":" .. p.name
                if found[key] == nil or each < found[key].v then
                  found[key] = { t = t, name = p.name, v = each, item = p.type == "item", recipe = r.name }
                end
              end
            end
          end
        end
      end
    end
    local any = false
    for _, f in pairs(found) do
      f.t[f.name] = f.v
      if f.item then
        depth[f.name] = wave
        via[f.name] = f.recipe
      end
      any = true
    end
    if not any then break end
  end

  for name, k in pairs(C.VALUE_SCALE) do
    if iv[name] then iv[name] = iv[name] * k end
  end
  for name, v in pairs(C.VALUE_OVERRIDES) do
    if prototypes.item[name] then iv[name] = v end
  end

  -- Equipment = anything you place as an entity. It only ever scraps.
  local equipment = {}
  for name, proto in pairs(prototypes.item) do
    if proto.place_result then equipment[name] = true end
  end
  iv["quota-terminal"] = nil

  return iv, fv, equipment, depth, via
end

function V.refresh()
  local q = storage.q
  local iv, fv, equipment, depth, via = V.compute()
  q.values = iv
  q.fluid_values = fv
  q.equipment = equipment
  q.depth = depth
  q.value_recipe = via
end

-- Complex mode: deeper products pay more per unit of value.
function V.premium(name)
  local q = storage.q
  if not (q.rules and q.rules.mode == "complex") then return 1 end
  local d = (q.depth and q.depth[name]) or 0
  return math.min(C.COMPLEX_CAP, C.COMPLEX_BASE + C.COMPLEX_STEP * d)
end

-- Base sale value per unit before any multiplier (scrap applied).
function V.base(name)
  local q = storage.q
  local v = q.values[name]
  if not v or v <= 0 then return 0 end
  if q.equipment[name] then return v * C.SCRAP_RATE end
  return v * V.premium(name)
end

-- Full (unscrapped, unpremiumed) value, used for pricing supply crates.
function V.full(name)
  return storage.q.values[name] or 0
end

function V.is_product(name)
  local q = storage.q
  return (q.values[name] or 0) > 0 and not q.equipment[name]
end

-- Crafting steps from raw materials (0 for raws and unpriced items).
function V.depth(name)
  local q = storage.q
  return (q.depth and q.depth[name]) or 0
end

-- The recipe an item's value came from, for recipe tooltips.
function V.recipe(name)
  local q = storage.q
  local r = q.value_recipe and q.value_recipe[name]
  if r and prototypes.recipe[r] then return r end
  if prototypes.recipe[name] then return name end
  return nil
end

return V
