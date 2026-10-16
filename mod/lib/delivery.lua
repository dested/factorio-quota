-- Supply pods: a cargo pod falls out of the sky, slams into the ground and
-- turns into a container holding the delivery. It vanishes once emptied.
--
-- Products delivered by The Company are tracked as "company property": the
-- first that many units of each sell for scrap, so a kit full of ammo and coal
-- can't be flipped at the terminal.

local U = require("lib.util")
local V = require("lib.values")
local W = require("lib.world")
local A = require("lib.anim")

local D = {}

local FALL_TICKS = 70
local FALL_HEIGHT = 36

function D.mark_gifted(name, count)
  local q = storage.q
  if V.is_product(name) then
    q.gifted[name] = (q.gifted[name] or 0) + count
  end
end

-- Keep pods off terminal pads so their labels never cover the terminal.
local function clear_of_terminals(surface, spot)
  return surface.count_entities_filtered({ name = "quota-terminal", position = spot, radius = 9 }) == 0
end

-- Pick a landing spot near `pos` on dry land.
local function landing_spot(surface, pos)
  for _ = 1, 12 do
    local a = U.random() * 2 * math.pi
    local d = 4 + U.random() * 5
    local try = { x = pos.x + math.cos(a) * d, y = pos.y + math.sin(a) * d }
    local spot = surface.find_non_colliding_position("quota-supply-pod", try, 10, 1)
    if spot and not W.is_water(surface, spot) and clear_of_terminals(surface, spot) then return spot end
  end
  return surface.find_non_colliding_position("quota-supply-pod", { x = 0, y = 12 }, 30, 1)
end

-- items: list of { name, count }. opts: near (position), label, gifted (bool), sound (bool)
function D.drop(items, opts)
  opts = opts or {}
  local surface = U.surface()
  if not surface then return end
  local near = opts.near
  if not near then
    for _, p in pairs(U.players()) do
      local c = p.character
      if c and c.surface == surface then near = c.position break end
    end
  end
  near = near or { x = 0, y = 9 }
  local spot = landing_spot(surface, near)
  if not spot then return end

  local list = {}
  for _, it in ipairs(items) do
    if prototypes.item[it[1]] and it[2] > 0 then
      list[#list + 1] = { name = it[1], count = math.floor(it[2]) }
      if opts.gifted ~= false then D.mark_gifted(it[1], math.floor(it[2])) end
    end
  end

  local marker = rendering.draw_circle({
    surface = surface, target = spot, radius = 1.6, color = { 0.4, 0.9, 1, 0.5 },
    width = 3, filled = false, draw_on_ground = true, time_to_live = FALL_TICKS + 10,
  })
  local shadow = rendering.draw_sprite({
    sprite = "quota-pod-shadow", surface = surface, target = spot, x_scale = 0.2, y_scale = 0.2,
  })
  local pod = rendering.draw_sprite({
    sprite = "quota-pod", surface = surface, target = { spot.x, spot.y - FALL_HEIGHT }, render_layer = "air-object",
  })
  A.add({
    kind = "pod", t = 0, x = spot.x, y = spot.y, pod = pod, shadow = shadow, marker = marker,
    items = list, label = opts.label or "Supply Pod",
  })
  U.sound("quota-reverse-cymbal", 0.6)
end

local function fill_pods(surface, spot, items, label)
  local i = 1
  local pods = 0
  while i <= #items and pods < 6 do
    local pos = surface.find_non_colliding_position("quota-supply-pod", spot, 12, 1) or spot
    local ent = surface.create_entity({ name = "quota-supply-pod", position = pos, force = "player" })
    if not ent then break end
    pods = pods + 1
    local inv = ent.get_inventory(defines.inventory.chest)
    while i <= #items do
      local it = items[i]
      local n = inv and inv.insert({ name = it.name, count = it.count }) or 0
      if n < it.count then
        it.count = it.count - n
        break
      end
      i = i + 1
    end
    rendering.draw_text({
      text = label, surface = surface, target = { entity = ent, offset = { 0, -2.6 } },
      color = { 0.55, 0.9, 1 }, scale = 1.3, alignment = "center", vertical_alignment = "middle",
      font = "default-bold", use_rich_text = true,
    })
    if inv and inv.is_empty() then ent.destroy() end
  end
  -- Anything that still didn't fit spills on the ground.
  for j = i, #items do
    surface.spill_item_stack({ position = spot, stack = { name = items[j].name, count = items[j].count }, enable_looted = true })
  end
end

A.register("pod", function(job)
  local surface = U.surface()
  if not surface then return true end
  job.t = job.t + 1
  local k = job.t / FALL_TICKS
  local h = FALL_HEIGHT * (1 - k * k)
  if job.pod and job.pod.valid then job.pod.target = { job.x, job.y - h } end
  if job.shadow and job.shadow.valid then
    local s = 0.2 + 0.8 * k
    job.shadow.x_scale, job.shadow.y_scale = s, s
  end
  if job.t < FALL_TICKS then return false end

  for _, o in pairs({ job.pod, job.shadow, job.marker }) do
    if o and o.valid then o.destroy() end
  end
  local spot = { x = job.x, y = job.y }
  surface.create_entity({ name = "medium-explosion", position = spot })
  for _ = 1, 4 do
    surface.create_trivial_smoke({ name = "artillery-smoke", position = { spot.x + U.random() * 2 - 1, spot.y + U.random() * 2 - 1 } })
  end
  U.sound("quota-kick", 1)
  U.sound("quota-crash", 0.5)
  fill_pods(surface, spot, job.items, job.label)
  U.fly(job.label .. " delivered", { x = spot.x, y = spot.y - 2 }, U.COLORS.blue, surface, 150)
  return true
end)

return D
