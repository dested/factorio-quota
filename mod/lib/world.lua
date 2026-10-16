-- The island. A 9x9 grid of 64x64 plots in an endless ocean; you own the HQ
-- plot and buy the rest. Tiles are a pure function of (plot ownership, plot
-- features, coordinates), so painting a chunk, raising a plot, and repainting
-- a coastline all go through tile_at() and always agree.

local C = require("lib.config")
local U = require("lib.util")

local W = {}

local P = C.PLOT
local HALF = P / 2
local R = C.GRID_RADIUS

-- ------------------------------------------------------------ types ---

W.TYPES = {
  hq = { name = "Headquarters", sprite = "item/quota-terminal", base = 0,
    desc = "Company property. Your terminal, a lake and a little of everything." },
  iron = { name = "Iron Seam", sprite = "item/iron-ore", base = 550,
    desc = "A wide, rich iron ore deposit." },
  copper = { name = "Copper Seam", sprite = "item/copper-ore", base = 550,
    desc = "A wide, rich copper ore deposit." },
  coal = { name = "Coal Bed", sprite = "item/coal", base = 400,
    desc = "A big coal field. Fuel for the furnaces, carbon for the plastics." },
  quarry = { name = "Quarry", sprite = "item/stone", base = 380,
    desc = "Stone, a little coal, and a lot of rocks." },
  mixed = { name = "Mixed Ores", sprite = "item/iron-ore", base = 850,
    desc = "Iron, copper and coal in one tidy plot." },
  lake = { name = "Lakeside", sprite = "item/offshore-pump", base = 320,
    desc = "A big lake with fish, ringed by trees. Room for a power plant." },
  forest = { name = "Old Forest", sprite = "item/wood", base = 220,
    desc = "Dense woodland. Cheap land, if you like chopping." },
  flat = { name = "Zoned Industrial", sprite = "item/stone-brick", base = 300,
    desc = "Flat, empty and ready to build on." },
  oil = { name = "Oil Field", sprite = "fluid/crude-oil", base = 1500,
    desc = "Crude oil wells. You will need Oil Industry from R&D." },
  ruins = { name = "Abandoned Facility", sprite = "item/iron-gear-wheel", base = 700,
    desc = "A previous contractor's site. They left in a hurry. Loot inside." },
  infested = { name = "Infested Swamp", sprite = "virtual-signal/signal-skull", base = 240,
    desc = "Very rich ore, very cheap, because of the nests. Bring turrets." },
  bonanza = { name = "Bonanza", sprite = "virtual-signal/signal-star", base = 2400,
    desc = "Absurdly rich iron and copper. Priced accordingly." },
  uranium = { name = "Uranium Crater", sprite = "item/uranium-ore", base = 2800,
    desc = "An old impact site. Uranium needs sulfuric acid to mine." },
}

-- Feature recipes per plot type. Positions are rolled when the grid is rolled.
local FEATURES = {
  iron = { { kind = "ore", name = "iron-ore", r = 11, rich = 1800 }, { kind = "trees", n = 30 } },
  copper = { { kind = "ore", name = "copper-ore", r = 11, rich = 1800 }, { kind = "trees", n = 30 } },
  coal = { { kind = "ore", name = "coal", r = 10, rich = 1600 }, { kind = "rocks", n = 4 } },
  quarry = { { kind = "ore", name = "stone", r = 9, rich = 1500 }, { kind = "ore", name = "coal", r = 6, rich = 1200 }, { kind = "rocks", n = 12 } },
  mixed = { { kind = "ore", name = "iron-ore", r = 8, rich = 1600 }, { kind = "ore", name = "copper-ore", r = 8, rich = 1600 }, { kind = "ore", name = "coal", r = 6, rich = 1400 } },
  lake = { { kind = "lake", r = 13 }, { kind = "trees", n = 90 }, { kind = "fish", n = 8 } },
  forest = { { kind = "trees", n = 320 }, { kind = "rocks", n = 3 } },
  flat = {},
  oil = { { kind = "oil", n = 6, amount = 900000 }, { kind = "rocks", n = 3 } },
  ruins = { { kind = "ruins" }, { kind = "trees", n = 25 }, { kind = "rocks", n = 4 } },
  infested = { { kind = "ore", name = "?", r = 12, rich = 2600 }, { kind = "nests", spawners = 3, worms = 4 }, { kind = "trees", n = 40 } },
  bonanza = { { kind = "ore", name = "iron-ore", r = 10, rich = 4200 }, { kind = "ore", name = "copper-ore", r = 10, rich = 4200 } },
  uranium = { { kind = "ore", name = "uranium-ore", r = 8, rich = 2200 }, { kind = "ore", name = "stone", r = 6, rich = 1500 }, { kind = "rocks", n = 6 } },
}

local TREES = { "tree-01", "tree-02", "tree-03", "tree-04", "tree-05", "tree-06", "tree-07", "tree-08", "tree-09", "tree-02-red", "tree-08-brown" }
local ROCKS = { "huge-rock", "big-rock", "big-rock", "big-sand-rock" }

local RUIN_LOOT = {
  { "electronic-circuit", 80, 200 }, { "iron-gear-wheel", 100, 250 }, { "steel-plate", 80, 200 },
  { "assembling-machine-2", 4, 10 }, { "fast-inserter", 20, 50 }, { "fast-transport-belt", 100, 200 },
  { "engine-unit", 10, 30 }, { "solar-panel", 6, 16 }, { "medium-electric-pole", 20, 40 },
  { "speed-module", 2, 6 }, { "productivity-module", 2, 6 }, { "piercing-rounds-magazine", 100, 200 },
  { "grenade", 10, 30 }, { "advanced-circuit", 20, 60 }, { "steel-furnace", 6, 16 },
  { "electric-mining-drill", 6, 14 }, { "plastic-bar", 50, 150 }, { "car", 1, 1 },
  { "big-electric-pole", 5, 15 }, { "bulk-inserter", 6, 14 },
}

-- ----------------------------------------------------------- helpers ---

function W.key(px, py) return px .. "," .. py end

function W.plot(px, py)
  return storage.q.plots[W.key(px, py)]
end

local function owned(px, py)
  local p = storage.q.plots[px .. "," .. py]
  return p ~= nil and p.owned
end
W.owned = owned

function W.plot_coords(x, y)
  return math.floor((x + HALF) / P), math.floor((y + HALF) / P)
end

function W.plot_origin(px, py)
  return px * P - HALF, py * P - HALF
end

function W.plot_center(px, py)
  return { x = px * P, y = py * P }
end

function W.in_grid(px, py)
  return math.abs(px) <= R and math.abs(py) <= R
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

function W.purchasable(px, py)
  if not W.in_grid(px, py) or owned(px, py) then return false end
  for _, d in ipairs(DIRS) do
    if owned(px + d[1], py + d[2]) then return true end
  end
  return false
end

function W.owned_count()
  local n = 0
  for _, p in pairs(storage.q.plots) do if p.owned then n = n + 1 end end
  return n
end

-- --------------------------------------------------------- the grid ---

local function roll_features(plot)
  local recipe = FEATURES[plot.type] or {}
  local ox, oy = W.plot_origin(plot.px, plot.py)
  local placed = {}
  plot.features = {}
  for _, f in ipairs(recipe) do
    local feat = {}
    for k, v in pairs(f) do feat[k] = v end
    if feat.kind == "ore" and feat.name == "?" then
      feat.name = U.pick({ "iron-ore", "copper-ore", "iron-ore", "copper-ore", "coal", "stone" })
    end
    if feat.kind == "ore" or feat.kind == "lake" or feat.kind == "oil" or feat.kind == "ruins" or feat.kind == "nests" then
      local r = feat.r or (feat.kind == "oil" and 8 or 9)
      feat.r = r
      local margin = r + 5
      local best
      for _ = 1, 40 do
        local cx = ox + margin + U.random() * (P - 2 * margin)
        local cy = oy + margin + U.random() * (P - 2 * margin)
        local ok = true
        for _, other in ipairs(placed) do
          local need = r + other.r + 4
          if (cx - other.x) ^ 2 + (cy - other.y) ^ 2 < need * need then ok = false break end
        end
        if ok then best = { x = cx, y = cy } break end
      end
      best = best or { x = ox + HALF + (U.random() - 0.5) * 10, y = oy + HALF + (U.random() - 0.5) * 10 }
      feat.x, feat.y = math.floor(best.x), math.floor(best.y)
      placed[#placed + 1] = { x = feat.x, y = feat.y, r = r }
    end
    plot.features[#plot.features + 1] = feat
  end
end

local function hq_features(plot)
  local quads = U.shuffle({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } })
  local ores = {
    { name = "iron-ore", r = 7.5, rich = 1600 },
    { name = "copper-ore", r = 7, rich = 1500 },
    { name = "coal", r = 5.5, rich = 1400 },
    { name = "stone", r = 4.5, rich = 1200 },
  }
  plot.features = {}
  for i, ore in ipairs(ores) do
    local q = quads[i]
    plot.features[#plot.features + 1] = {
      kind = "ore", name = ore.name, r = ore.r, rich = ore.rich,
      x = q[1] * (17 + U.random(-1, 2)), y = q[2] * (17 + U.random(-1, 2)),
    }
  end
  local side = U.pick({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } })
  plot.features[#plot.features + 1] = { kind = "lake", r = 5.5, x = side[1] * 21, y = side[2] * 21 }
  plot.features[#plot.features + 1] = { kind = "trees", n = 40 }
  plot.features[#plot.features + 1] = { kind = "rocks", n = 5 }
  plot.features[#plot.features + 1] = { kind = "fish", n = 3 }
end

function W.roll_grid()
  local q = storage.q
  q.plots = {}
  local basic = { "iron", "copper", "coal", "quarry", "lake", "forest", "flat", "mixed", "ruins" }
  local mid = { "iron", "copper", "coal", "quarry", "lake", "forest", "flat", "mixed", "ruins", "infested", "oil" }
  local far = { "iron", "copper", "coal", "quarry", "lake", "forest", "mixed", "ruins", "infested", "oil", "oil", "bonanza", "uranium", "bonanza" }

  local function set(px, py, t)
    local plot = { px = px, py = py, type = t, owned = false }
    q.plots[W.key(px, py)] = plot
  end

  set(0, 0, "hq")
  -- The four plots you can buy first always cover the basics.
  local first = U.shuffle({ "iron", "copper", U.pick({ "coal", "quarry" }), U.pick({ "lake", "flat", "forest" }) })
  local orth = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
  for i, d in ipairs(orth) do set(d[1], d[2], first[i]) end

  for ring = 1, R do
    local cells = {}
    for px = -ring, ring do
      for py = -ring, ring do
        if math.max(math.abs(px), math.abs(py)) == ring and not q.plots[W.key(px, py)] then
          cells[#cells + 1] = { px, py }
        end
      end
    end
    U.shuffle(cells)
    local must = {}
    if ring == 2 then must = { "oil", "oil", "mixed", "ruins", "infested" } end
    if ring == 3 then must = { "bonanza", "uranium", "oil", "ruins" } end
    local pool = ring == 1 and basic or (ring == 2 and mid or far)
    for i, c in ipairs(cells) do
      set(c[1], c[2], must[i] or U.pick(pool))
    end
  end

  for _, plot in pairs(q.plots) do
    if plot.type == "hq" then hq_features(plot) else roll_features(plot) end
  end
end

-- ------------------------------------------------------------- price ---

function W.price(plot)
  local base = W.TYPES[plot.type].base
  local ring = math.max(math.abs(plot.px), math.abs(plot.py))
  local owned_n = W.owned_count()
  return base * (1 + 0.18 * math.max(0, owned_n - 1)) * (1 + 0.1 * math.max(0, ring - 1))
end

-- ------------------------------------------------------------- tiles ---

local LAND = { "grass-1", "grass-2", "grass-3", "grass-4", "dry-dirt" }

function W.tile_at(x, y)
  local q = storage.q
  local px, py = math.floor((x + HALF) / P), math.floor((y + HALF) / P)
  local lx, ly = x - (px * P - HALF), y - (py * P - HALF)
  local plot = q.plots[px .. "," .. py]

  if not (plot and plot.owned) then
    if (lx < 4 and owned(px - 1, py)) or (lx > P - 5 and owned(px + 1, py))
      or (ly < 4 and owned(px, py - 1)) or (ly > P - 5 and owned(px, py + 1)) then
      return "water"
    end
    return "deepwater"
  end

  local salt = q.terrain_salt or 7
  local coast = 1 + math.floor(U.noise(x, y, 7, salt) * 3.6)
  local function near(dist)
    return (lx < dist and not owned(px - 1, py)) or (lx > P - 1 - dist and not owned(px + 1, py))
      or (ly < dist and not owned(px, py - 1)) or (ly > P - 1 - dist and not owned(px, py + 1))
  end
  if near(coast) then return "water" end
  if near(coast + 2) then return "sand-1" end

  if plot.type == "hq" then
    local ax, ay = math.abs(x + 0.5), math.abs(y + 0.5)
    if ax < C.PAD_HALF and ay < C.PAD_HALF then
      if ax > C.PAD_HALF - 1 or ay > C.PAD_HALF - 1 then return "quota-pad-hazard" end
      return "quota-pad"
    end
  end

  for _, f in ipairs(plot.features or {}) do
    if f.kind == "lake" then
      local dx, dy = x + 0.5 - f.x, y + 0.5 - f.y
      local d = math.sqrt(dx * dx + dy * dy) / f.r + (U.noise(x, y, 4, salt + 3) - 0.5) * 0.45
      if d < 0.55 then return "deepwater" end
      if d < 1 then return "water" end
      if d < 1.12 then return "sand-1" end
    end
  end

  local n = U.noise(x, y, 18, salt + 11)
  if n < 0.28 then return LAND[2] end
  if n < 0.58 then return LAND[1] end
  if n < 0.8 then return LAND[3] end
  if n < 0.93 then return LAND[4] end
  return LAND[5]
end

local WATERY = { water = true, deepwater = true }

-- Paint [x0,x1) x [y0,y1). `protect` = set of "x,y" keys that must not turn to water.
function W.paint_area(surface, x0, y0, x1, y1, protect)
  local tiles = {}
  for x = x0, x1 - 1 do
    for y = y0, y1 - 1 do
      local name = W.tile_at(x, y)
      if not (protect and WATERY[name] and protect[x .. "," .. y]) then
        tiles[#tiles + 1] = { name = name, position = { x, y } }
      end
    end
  end
  surface.set_tiles(tiles, true, false, true, false)
end

function W.on_chunk_generated(event)
  local surface = event.surface
  if surface ~= U.surface() then return end
  local lt, rb = event.area.left_top, event.area.right_bottom
  W.paint_area(surface, lt.x, lt.y, rb.x, rb.y, nil)
end

-- ------------------------------------------------------------ surface ---

function W.create_surface()
  local q = storage.q
  q.surface_serial = (q.surface_serial or 0) + 1
  local name = C.SURFACE_PREFIX .. (q.surface_serial > 1 and ("-" .. q.surface_serial) or "")
  local size = (2 * R + 1) * P + 2 * P
  local settings = {
    seed = U.random(1, 2000000000),
    width = size,
    height = size,
    default_enable_all_autoplace_controls = false,
    autoplace_controls = {},
    autoplace_settings = {
      entity = { treat_missing_as_default = false, settings = {} },
      decorative = { treat_missing_as_default = false, settings = {} },
      tile = { treat_missing_as_default = false, settings = { ["deepwater"] = {} } },
    },
    cliff_settings = { name = "cliff", cliff_elevation_0 = 1024, cliff_elevation_interval = 1024, richness = 0 },
    peaceful_mode = false,
    no_enemies_mode = false,
    starting_area = 1,
  }
  local surface = game.create_surface(name, settings)
  -- Always day: the Eclipse condition is the one night you get.
  surface.always_day = true
  surface.peaceful_mode = false
  q.surface_index = surface.index
  return surface
end

-- ---------------------------------------------------------- features ---

local function ore_blob(surface, f, salt)
  local r = f.r
  local created = 0
  for x = math.floor(f.x - r - 3), math.ceil(f.x + r + 3) do
    for y = math.floor(f.y - r - 3), math.ceil(f.y + r + 3) do
      local dx, dy = x + 0.5 - f.x, y + 0.5 - f.y
      local d = math.sqrt(dx * dx + dy * dy) / r + (U.noise(x, y, 5, salt) - 0.5) * 0.5
      if d < 1 then
        local tile = surface.get_tile(x, y)
        if tile.valid and not WATERY[tile.name] then
          local amount = math.floor(f.rich * (1.35 - 0.7 * d) * (0.85 + 0.3 * U.hash(x, y, salt)))
          if surface.create_entity({ name = f.name, position = { x + 0.5, y + 0.5 }, amount = math.max(50, amount) }) then
            created = created + 1
          end
        end
      end
    end
  end
  return created
end

local function random_spot(plot, avoid)
  local ox, oy = W.plot_origin(plot.px, plot.py)
  for _ = 1, 12 do
    local x = ox + 4 + U.random() * (P - 8)
    local y = oy + 4 + U.random() * (P - 8)
    local clear = true
    for _, f in ipairs(avoid) do
      if (x - f.x) ^ 2 + (y - f.y) ^ 2 < (f.r + 2) ^ 2 then clear = false break end
    end
    if plot.type == "hq" and math.abs(x) < C.PAD_HALF + 4 and math.abs(y) < C.PAD_HALF + 4 then clear = false end
    if clear then return { x = x, y = y } end
  end
  return nil
end

local function place(surface, name, pos, force)
  if not pos then return nil end
  local p = surface.find_non_colliding_position(name, pos, 3, 0.5)
  if not p then return nil end
  return surface.create_entity({ name = name, position = p, force = force or "neutral" })
end

local function fill_loot(container, rolls)
  local inv = container.get_inventory(defines.inventory.chest)
  if not inv then return end
  for _ = 1, rolls do
    local l = U.pick(RUIN_LOOT)
    if l and prototypes.item[l[1]] then
      inv.insert({ name = l[1], count = U.random(l[2], l[3]) })
    end
  end
end

function W.place_features(surface, plot)
  local salt = (storage.q.terrain_salt or 7) + plot.px * 31 + plot.py * 17
  local blobs = {}
  for _, f in ipairs(plot.features or {}) do
    if f.x then blobs[#blobs + 1] = f end
  end
  for _, f in ipairs(plot.features or {}) do
    if f.kind == "ore" then
      ore_blob(surface, f, salt)
    elseif f.kind == "oil" then
      for i = 1, f.n do
        local a = (i / f.n) * 2 * math.pi + U.random() * 0.6
        local d = 2 + U.random() * (f.r - 2)
        local pos = surface.find_non_colliding_position("crude-oil", { f.x + math.cos(a) * d, f.y + math.sin(a) * d }, 6, 1)
        if pos then
          surface.create_entity({ name = "crude-oil", position = pos, amount = math.floor(f.amount * (0.7 + 0.6 * U.random())) })
        end
      end
    elseif f.kind == "trees" then
      for _ = 1, f.n do place(surface, U.pick(TREES), random_spot(plot, blobs)) end
    elseif f.kind == "rocks" then
      for _ = 1, f.n do place(surface, U.pick(ROCKS), random_spot(plot, blobs)) end
    elseif f.kind == "fish" then
      local lake
      for _, g in ipairs(plot.features) do if g.kind == "lake" then lake = g end end
      if lake then
        for _ = 1, f.n do
          local a = U.random() * 2 * math.pi
          local pos = { lake.x + math.cos(a) * lake.r * 0.4, lake.y + math.sin(a) * lake.r * 0.4 }
          local p = surface.find_non_colliding_position("fish", pos, 4, 0.5)
          if p then surface.create_entity({ name = "fish", position = p }) end
        end
      end
    elseif f.kind == "ruins" then
      place(surface, "crash-site-spaceship", { f.x, f.y })
      for i = 1, 4 do
        local a = i * 1.57 + U.random()
        local chest = place(surface, U.pick({ "crash-site-chest-1", "crash-site-chest-2" }),
          { f.x + math.cos(a) * 9, f.y + math.sin(a) * 9 })
        if chest then fill_loot(chest, 3) end
      end
      for _ = 1, 8 do
        local a = U.random() * 2 * math.pi
        local d = 5 + U.random() * 8
        place(surface, "crash-site-spaceship-wreck-small-" .. U.random(1, 6), { f.x + math.cos(a) * d, f.y + math.sin(a) * d })
      end
    elseif f.kind == "nests" then
      for i = 1, f.spawners do
        local a = (i / f.spawners) * 2 * math.pi
        place(surface, U.pick({ "biter-spawner", "biter-spawner", "spitter-spawner" }),
          { f.x + math.cos(a) * 5, f.y + math.sin(a) * 5 }, "enemy")
      end
      for i = 1, f.worms do
        local a = (i / f.worms) * 2 * math.pi + 0.4
        place(surface, U.pick({ "small-worm-turret", "medium-worm-turret" }),
          { f.x + math.cos(a) * 10, f.y + math.sin(a) * 10 }, "enemy")
      end
    end
  end
end

-- -------------------------------------------------------- materialize ---

-- Tiles under the player's entities never turn into water.
local function protected_tiles(surface, x0, y0, x1, y1)
  local set = {}
  local ents = surface.find_entities_filtered({ area = { { x0 - 2, y0 - 2 }, { x1 + 2, y1 + 2 } }, force = C.FORCE })
  for _, e in pairs(ents) do
    local box = e.bounding_box
    for x = math.floor(box.left_top.x) - 1, math.ceil(box.right_bottom.x) do
      for y = math.floor(box.left_top.y) - 1, math.ceil(box.right_bottom.y) do
        set[x .. "," .. y] = true
      end
    end
  end
  return set
end

local function ensure_generated(surface, px, py)
  local c = W.plot_center(px, py)
  surface.request_to_generate_chunks(c, 3)
  surface.force_generate_chunk_requests()
end

-- Mark a plot owned and raise it out of the sea. `instant` skips the wave
-- (used for the HQ at world creation).
function W.claim(px, py, instant)
  local q = storage.q
  local surface = U.surface()
  local plot = W.plot(px, py)
  if not (surface and plot) or plot.owned then return false end
  ensure_generated(surface, px, py)
  plot.owned = true
  local ox, oy = W.plot_origin(px, py)
  local protect = protected_tiles(surface, ox - 6, oy - 6, ox + P + 6, oy + P + 6)

  if instant then
    W.paint_area(surface, ox - 6, oy - 6, ox + P + 6, oy + P + 6, protect)
    W.place_features(surface, plot)
  else
    -- Sweep from the side that touches existing land.
    local from = "w"
    if owned(px + 1, py) then from = "e" elseif owned(px, py - 1) then from = "n" elseif owned(px, py + 1) then from = "s" end
    q.jobs[#q.jobs + 1] = { kind = "rise", px = px, py = py, step = 0, from = from, protect = protect }
  end
  U.force().chart(surface, { { ox - 8, oy - 8 }, { ox + P + 8, oy + P + 8 } })
  return true
end

-- One step of the land-rising wave: two rows per tick, splashes along the front.
function W.rise_step(job)
  local surface = U.surface()
  if not surface then return true end
  local plot = W.plot(job.px, job.py)
  local ox, oy = W.plot_origin(job.px, job.py)
  local rows = 2
  local total = P + 12
  for _ = 1, rows do
    if job.step >= total then break end
    local i = job.step
    local x0, y0, x1, y1
    if job.from == "w" then x0, x1, y0, y1 = ox - 6 + i, ox - 5 + i, oy - 6, oy + P + 6
    elseif job.from == "e" then x0, x1, y0, y1 = ox + P + 5 - i, ox + P + 6 - i, oy - 6, oy + P + 6
    elseif job.from == "n" then x0, x1, y0, y1 = ox - 6, ox + P + 6, oy - 6 + i, oy - 5 + i
    else x0, x1, y0, y1 = ox - 6, ox + P + 6, oy + P + 5 - i, oy + P + 6 - i end
    W.paint_area(surface, x0, y0, x1, y1, job.protect)
    if i % 6 == 0 then
      for _ = 1, 3 do
        local sx = x0 + U.random() * (x1 - x0)
        local sy = y0 + U.random() * (y1 - y0)
        surface.create_entity({ name = "water-splash", position = { sx, sy } })
      end
    end
    job.step = job.step + 1
  end
  if job.step >= total then
    W.place_features(surface, plot)
    W.refresh_signs()
    return true
  end
  return false
end

-- --------------------------------------------------------------- signs ---

function W.clear_signs()
  local q = storage.q
  for _, ids in pairs(q.signs or {}) do
    for _, obj in pairs(ids) do
      if obj and obj.valid then obj.destroy() end
    end
  end
  q.signs = {}
end

function W.refresh_signs()
  local q = storage.q
  W.clear_signs()
  local surface = U.surface()
  if not surface then return end
  local mult = (q.price_mods and q.price_mods.catalog) or 1
  for _, plot in pairs(q.plots) do
    if W.purchasable(plot.px, plot.py) then
      local t = W.TYPES[plot.type]
      local c = W.plot_center(plot.px, plot.py)
      local ox, oy = W.plot_origin(plot.px, plot.py)
      local objs = {}
      local col = { r = 1, g = 0.8, b = 0.2, a = 0.7 }
      local inset = 6
      local corners = {
        { ox + inset, oy + inset }, { ox + P - inset, oy + inset },
        { ox + P - inset, oy + P - inset }, { ox + inset, oy + P - inset },
      }
      for i = 1, 4 do
        local a, b = corners[i], corners[i % 4 + 1]
        objs[#objs + 1] = rendering.draw_line({
          surface = surface, from = a, to = b, color = col, width = 3,
          dash_length = 2, gap_length = 1.5, draw_on_ground = true,
        })
      end
      objs[#objs + 1] = rendering.draw_sprite({
        sprite = t.sprite, surface = surface, target = { c.x, c.y - 7 }, x_scale = 4, y_scale = 4,
      })
      objs[#objs + 1] = rendering.draw_text({
        text = "FOR SALE", surface = surface, target = { c.x, c.y - 2.5 }, color = { 1, 1, 1, 0.9 },
        scale = 4, alignment = "center", vertical_alignment = "middle", font = "default-bold",
      })
      objs[#objs + 1] = rendering.draw_text({
        text = t.name, surface = surface, target = { c.x, c.y + 1.5 }, color = { 1, 0.9, 0.75 },
        scale = 3.2, alignment = "center", vertical_alignment = "middle", font = "default-bold",
      })
      objs[#objs + 1] = rendering.draw_text({
        text = U.money(W.price(plot) * mult), surface = surface, target = { c.x, c.y + 5 },
        color = { 1, 0.78, 0.2 }, scale = 3.2, alignment = "center", vertical_alignment = "middle", font = "default-bold",
      })
      objs[#objs + 1] = rendering.draw_text({
        text = "Buy it in the Catalog (J), Land tab", surface = surface, target = { c.x, c.y + 8.5 },
        color = { 0.85, 0.85, 0.85, 0.8 }, scale = 1.6, alignment = "center", vertical_alignment = "middle",
      })
      objs[#objs + 1] = rendering.draw_text({
        text = t.name .. " " .. U.money(W.price(plot) * mult), surface = surface, target = { c.x, c.y },
        color = { 1, 0.8, 0.2 }, scale = 6, alignment = "center", vertical_alignment = "middle",
        render_mode = "chart",
      })
      q.signs[W.key(plot.px, plot.py)] = objs
    end
  end
end

-- ------------------------------------------------------------ queries ---

-- A random land tile on owned plots, at least `min_r` from the terminal pad.
function W.random_land(min_r)
  local q = storage.q
  local surface = U.surface()
  if not surface then return nil end
  local owned_list = {}
  for _, p in pairs(q.plots) do if p.owned then owned_list[#owned_list + 1] = p end end
  for _ = 1, 40 do
    local plot = U.pick(owned_list)
    if not plot then return nil end
    local ox, oy = W.plot_origin(plot.px, plot.py)
    local x = ox + 6 + U.random() * (P - 12)
    local y = oy + 6 + U.random() * (P - 12)
    if x * x + y * y >= (min_r or 0) ^ 2 then
      local tile = surface.get_tile(x, y)
      if tile.valid and not WATERY[tile.name] then return { x = x, y = y } end
    end
  end
  return nil
end

-- Land near the coast, preferring spots far from `from`.
function W.coast_spot(from)
  local q = storage.q
  local surface = U.surface()
  if not surface then return nil end
  local best, best_d = nil, -1
  local owned_list = {}
  for _, p in pairs(q.plots) do if p.owned then owned_list[#owned_list + 1] = p end end
  for _ = 1, 30 do
    local plot = U.pick(owned_list)
    if not plot then break end
    local ox, oy = W.plot_origin(plot.px, plot.py)
    local side = U.random(1, 4)
    local t = 6 + U.random() * (P - 12)
    local x, y
    if side == 1 then x, y = ox + 7, oy + t
    elseif side == 2 then x, y = ox + P - 7, oy + t
    elseif side == 3 then x, y = ox + t, oy + 7
    else x, y = ox + t, oy + P - 7 end
    local tile = surface.get_tile(x, y)
    if tile.valid and not WATERY[tile.name] then
      local d = from and U.dist2({ x = x, y = y }, from) or U.random()
      if d > best_d then best, best_d = { x = x, y = y }, d end
    end
  end
  return best
end

function W.is_water(surface, pos)
  local tile = surface.get_tile(pos.x, pos.y)
  return tile.valid and WATERY[tile.name] == true
end

return W
