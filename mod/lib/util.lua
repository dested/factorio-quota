-- Stateless helpers plus the run's deterministic RNG.

local C = require("lib.config")

local U = {}

U.COLORS = {
  gold = { r = 1, g = 0.78, b = 0.2 },
  green = { r = 0.4, g = 1, b = 0.45 },
  red = { r = 1, g = 0.35, b = 0.3 },
  blue = { r = 0.5, g = 0.75, b = 1 },
  white = { r = 1, g = 1, b = 1 },
  grey = { r = 0.65, g = 0.65, b = 0.65 },
  orange = { r = 1, g = 0.6, b = 0.15 },
  purple = { r = 0.8, g = 0.5, b = 1 },
  cream = { r = 1, g = 0.9, b = 0.75 },
}

-- --------------------------------------------------------------- state ---

function U.q()
  return storage.q
end

function U.surface()
  local q = storage.q
  if not (q and q.surface_index) then return nil end
  local s = game.surfaces[q.surface_index]
  if s and s.valid then return s end
  return nil
end

function U.force()
  return game.forces[C.FORCE]
end

-- -------------------------------------------------------------- random ---
-- Park-Miller LCG with its state in storage, so saves replay identically.

function U.seed(n)
  local s = math.floor(math.abs(n or 1)) % 2147483646
  if s == 0 then s = 1 end
  storage.q.rng = s
end

function U.random(a, b)
  local q = storage.q
  q.rng = (q.rng * 48271) % 2147483647
  local f = (q.rng - 1) / 2147483646
  if a == nil then return f end
  if b == nil then a, b = 1, a end
  return a + math.floor(f * (b - a + 1))
end

function U.chance(p)
  return U.random() < p
end

function U.pick(list)
  if #list == 0 then return nil end
  return list[U.random(1, #list)]
end

function U.shuffle(list)
  for i = #list, 2, -1 do
    local j = U.random(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

-- weights: function(item) -> number >= 0
function U.weighted_pick(list, weight)
  local total = 0
  for _, item in ipairs(list) do total = total + math.max(0, weight(item)) end
  if total <= 0 then return nil end
  local r = U.random() * total
  for _, item in ipairs(list) do
    r = r - math.max(0, weight(item))
    if r <= 0 then return item end
  end
  return list[#list]
end

-- Exact 32-bit multiply (doubles lose the low bits of a full 64-bit product).
local TWO32 = 4294967296
local function mul32(a, b)
  local alo, ahi = a % 65536, math.floor(a / 65536)
  local blo, bhi = b % 65536, math.floor(b / 65536)
  return (((ahi * blo + alo * bhi) % 65536) * 65536 + alo * blo) % TWO32
end

-- Stateless hash noise in [0,1) for terrain (independent of the run RNG).
function U.hash(x, y, salt)
  local h = (mul32(x % TWO32, 374761393) + mul32(y % TWO32, 668265263) + mul32((salt or 0) % TWO32, 2246822519)) % TWO32
  h = bit32.bxor(h, bit32.rshift(h, 13))
  h = mul32(h, 1274126177)
  h = bit32.bxor(h, bit32.rshift(h, 16))
  return h / TWO32
end

-- Smooth value noise in [0,1).
function U.noise(x, y, cell, salt)
  local gx, gy = math.floor(x / cell), math.floor(y / cell)
  local fx, fy = x / cell - gx, y / cell - gy
  fx = fx * fx * (3 - 2 * fx)
  fy = fy * fy * (3 - 2 * fy)
  local a = U.hash(gx, gy, salt)
  local b = U.hash(gx + 1, gy, salt)
  local c = U.hash(gx, gy + 1, salt)
  local d = U.hash(gx + 1, gy + 1, salt)
  return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

-- ------------------------------------------------------------ format ---

local function commas(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if out:sub(1, 1) == "," then out = out:sub(2) end
  if out:sub(1, 2) == "-," then out = "-" .. out:sub(3) end
  return out
end

function U.money(n)
  n = n or 0
  if n < 0 then return "-" .. U.money(-n) end
  if n >= 10000000 then return string.format("$%.1fM", n / 1000000) end
  return "$" .. commas(math.floor(n + 0.5))
end

function U.num(n)
  return commas(math.floor((n or 0) + 0.5))
end

function U.price_str(v)
  if v >= 100 then return "$" .. commas(math.floor(v + 0.5)) end
  if v >= 10 then return string.format("$%.1f", v) end
  return string.format("$%.2f", v)
end

function U.time(ticks)
  ticks = math.max(0, ticks or 0)
  local s = math.floor(ticks / 60)
  if s >= 3600 then
    return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
  end
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function U.pct(x)
  return string.format("%d%%", math.floor(x * 100 + 0.5))
end

function U.mult(x)
  if math.abs(x - math.floor(x)) < 0.01 then return string.format("x%d", math.floor(x + 0.5)) end
  return string.format("x%.1f", x)
end

function U.item_label(name)
  return "[item=" .. name .. "]"
end

-- ------------------------------------------------------------ players ---

function U.players()
  local list = {}
  for _, p in pairs(game.players) do
    if p.valid and p.connected then list[#list + 1] = p end
  end
  return list
end

function U.print(msg, color)
  game.print(msg, { color = color or U.COLORS.cream, skip = defines.print_skip.never })
end

-- The Company's voice in chat.
function U.company(msg)
  game.print({ "", "[color=255,200,70][font=default-bold]THE COMPANY:[/font][/color] ", msg },
    { color = U.COLORS.cream, skip = defines.print_skip.never })
end

function U.sound(path, volume)
  for _, p in pairs(U.players()) do
    p.play_sound({ path = path, volume_modifier = volume or 1 })
  end
end

function U.fly(text, position, color, surface, ttl)
  surface = surface or U.surface()
  for _, p in pairs(U.players()) do
    if p.surface == surface then
      p.create_local_flying_text({
        text = text,
        position = position,
        color = color or U.COLORS.gold,
        time_to_live = ttl or 90,
        speed = 1.2,
      })
    end
  end
end

function U.dist2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

function U.round_nice(v)
  if v < 100 then return math.max(5, math.floor(v / 5 + 0.5) * 5) end
  if v < 1000 then return math.floor(v / 10 + 0.5) * 10 end
  if v < 10000 then return math.floor(v / 50 + 0.5) * 50 end
  return math.floor(v / 100 + 0.5) * 100
end

function U.contains(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

return U
