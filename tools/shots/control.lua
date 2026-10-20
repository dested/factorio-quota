-- Screenshot driver: once the local player exists, walks through every QUOTA
-- screen and saves PNGs to script-output/quota-shots/. Writes
-- script-output/quota-shots/done.txt at the end.

local DIR = "quota-shots/"

local function call(fn, ...) return remote.call("quota", fn, ...) end
local function note(s) helpers.write_file(DIR .. "log.txt", s .. "\n", true) end

local function shot(name, opts)
  local p = game.get_player(1)
  if not p then return end
  opts = opts or {}
  game.take_screenshot({
    player = p, by_player = p, path = DIR .. name .. ".png", show_gui = opts.gui ~= false,
    zoom = opts.zoom, position = opts.position, resolution = opts.resolution, force_render = true,
  })
  note("shot " .. name)
end

local function surface()
  for _, s in pairs(game.surfaces) do
    if s.name:find("^quota") then return s end
  end
end

-- A little fake factory so gremlins, quakes and meteors have targets.
local function build_props()
  local s = surface()
  if not s then return end
  for i = 0, 3 do
    s.create_entity({ name = "assembling-machine-1", position = { 14 + i * 4, -12 }, force = "player" })
    s.create_entity({ name = "inserter", position = { 14 + i * 4, -9.5 }, force = "player" })
  end
  for x = 10, 30 do
    s.create_entity({ name = "transport-belt", position = { x + 0.5, -8.5 }, direction = defines.direction.east, force = "player" })
  end
  for i = 0, 2 do
    s.create_entity({ name = "stone-furnace", position = { -16 + i * 3, 14 }, force = "player" })
  end
end

-- "full" walks every screen; "quick" re-checks the break room, catalog tabs
-- and the end screens; "thumb" grabs the art for mod/thumbnail.png.
local PLAN = "full"

local plan = {}
local function step(secs, fn) plan[#plan + 1] = { secs = secs, fn = fn } end

local function full()
  step(1.5, function() shot("01-intro") end)
  step(7, function() shot("02-orientation") end)
  step(0.1, function() call("gui", "handbook") end)
  step(0.6, function() shot("02b-handbook") end)
  step(0.5, function()
    local p = game.get_player(1)
    p.zoom = 0.75
    call("start", "associate")
    build_props()
  end)
  step(0.6, function() shot("03-starter-pod-falling") end)
  step(3, function() shot("04-briefing-hud") end)
  step(0.5, function() call("clock_in") end)
  step(1, function() shot("04b-shift1-hud") end)
  step(0.5, function()
    call("terminal_insert", "iron-plate", 150)
    call("terminal_insert", "iron-gear-wheel", 40)
  end)
  step(1.2, function() shot("05-selling", { position = { 0, 0 } }) end)
  step(0.5, function() call("gui", 1) end)
  step(0.5, function() shot("06-catalog-contracts") end)
  step(0.1, function() call("gui", 2) end)
  step(0.5, function() shot("07-catalog-rnd") end)
  step(0.1, function() call("gui", 3) end)
  step(0.5, function() shot("08-catalog-supplies") end)
  step(0.1, function() call("select_plot", 1, 0); call("gui", 4) end)
  step(0.5, function() shot("09-catalog-land") end)
  step(0.1, function() call("gui", 5) end)
  step(0.5, function() shot("10-catalog-market") end)
  step(0.1, function()
    call("gui", "close")
    call("gui", "refresh")
    call("fire_event", "bounty")
    call("hazard", "gremlin")
  end)
  step(1, function() shot("11-hud-bounty-gremlin") end)
  step(0.1, function()
    local p = game.get_player(1)
    p.teleport({ 20, -4 }, surface())
  end)
  step(1, function() shot("12-gremlin-closeup", { zoom = 1.2 }) end)
  step(0.1, function()
    local s = surface()
    local p = game.get_player(1)
    p.teleport({ 0, 8 }, s)
    call("hazard", "meteor")
  end)
  step(1.2, function() shot("13-meteor-incoming", { zoom = 0.6 }) end)
  step(3, function() shot("14-meteor-crater", { zoom = 0.6 }) end)
  step(0.1, function() call("hazard", "quake") end)
  step(1, function() shot("15-quake", { zoom = 0.6 }) end)
  -- Finish shift 1.
  step(0.5, function()
    local st = call("state")
    call("ship", st.quota * 1.3)
    call("skip")
  end)
  step(2.5, function() shot("16-breakroom") end)
  -- Fast-forward to the corporate offer after shift 3.
  step(0.5, function() call("money", 50000) call("clock_in") end)
  step(1, function() local st = call("state") call("ship", st.quota * 1.1) call("skip") end)
  step(2, function() call("clock_in") end)
  step(1, function() local st = call("state") call("ship", st.quota * 1.1) call("skip") end)
  step(2.5, function() shot("17-corporate-offer") end)
  step(0.1, function()
    call("gui", "close")
    call("gui", "refresh")
    local p = game.get_player(1)
    p.teleport({ 30, 0 }, surface())
    p.zoom = 0.5
    local r = call("buy", "plot", 1, 0)
    note("plot buy " .. tostring(r.ok) .. " " .. tostring(r.msg))
  end)
  step(0.4, function() shot("18-land-rising", { zoom = 0.45 }) end)
  step(3, function() shot("19-land-risen", { zoom = 0.45 }) end)
  step(0.1, function()
    call("gui", "close")
    call("hazard", "raid")
  end)
  step(1, function() shot("20-raid-warning", { zoom = 0.35 }) end)
  -- Jump to the audit.
  step(0.5, function()
    call("jump", 8)
    call("clock_in")
  end)
  step(1, function()
    call("advance", 92)
  end)
  step(4, function()
    local s = surface()
    local a = s.find_entities_filtered({ name = "quota-auditor" })[1]
    if a then
      local p = game.get_player(1)
      p.teleport({ a.position.x + 6, a.position.y + 6 }, s)
      p.zoom = 0.7
    end
  end)
  step(1, function() shot("21-auditor") end)
  step(0.1, function()
    local st = call("state")
    call("ship", st.quota * 1.05)
    call("skip")
  end)
  step(3, function() shot("22-promoted") end)
  step(0.1, function() call("endless") end)
  step(2, function() call("clock_in") end)
  step(1, function() call("set", "warnings_left", 0) call("skip") end)
  step(3, function() shot("23-fired") end)
  step(0.1, function() call("reapply") end)
  step(8, function() shot("24-reapplied") end)
end

local function quick()
  step(1.5, function() shot("q01-orientation") end)
  step(0.5, function()
    game.get_player(1).zoom = 0.75
    call("start", "associate")
    build_props()
  end)
  step(4, function() shot("q02-pod-landed") end)
  step(0.5, function() call("gui", 1) end)
  step(0.5, function() shot("q02b-briefing-catalog") end)
  step(0.5, function() call("gui", "close") call("clock_in") end)
  step(0.5, function() call("gui", 2) end)
  step(0.5, function() shot("q03-rnd-icons") end)
  step(0.1, function() call("gui", 3) end)
  step(0.5, function() shot("q04-supplies") end)
  step(0.1, function() call("select_plot", 1, 0); call("gui", 4) end)
  step(0.5, function() shot("q05-land-legend") end)
  step(0.1, function() call("gui", 5) end)
  step(0.5, function() shot("q06-market") end)
  step(0.1, function()
    call("gui", "close")
    call("gui", "refresh")
    call("fire_event", "bounty")
  end)
  step(1, function() shot("q07-hud-bounty") end)
  step(0.1, function() local st = call("state") call("ship", st.quota * 1.3) call("skip") end)
  step(2.5, function() shot("q08-breakroom") end)
  step(0.1, function() call("gui", "close") call("gui", "refresh") end)
  step(0.5, function() shot("q09-break-hud") end)
  step(0.5, function()
    call("money", 50000)
    call("jump", 8)
    call("clock_in")
  end)
  step(1, function() local st = call("state") call("ship", st.quota * 1.05) call("skip") end)
  step(3, function() shot("q10-promoted") end)
  step(0.1, function() call("endless") end)
  step(2, function() call("clock_in") end)
  step(1, function() call("set", "warnings_left", 0) call("skip") end)
  step(3, function() shot("q11-fired") end)
  step(0.1, function() call("reapply") end)
  step(8, function() shot("q12-reapplied") end)
end

local function thumb()
  step(1.5, function()
    local p = game.get_player(1)
    game.take_screenshot({
      player = p, surface = surface(), position = { 0, -0.5 }, resolution = { 640, 640 }, zoom = 1.6,
      show_gui = false, show_entity_info = false, path = DIR .. "thumb-raw.png", force_render = true,
    })
    note("shot thumb-raw")
  end)
end

if PLAN == "full" then full() elseif PLAN == "thumb" then thumb() else quick() end
step(1, function() helpers.write_file(DIR .. "done.txt", "done\n") end)

script.on_init(function()
  storage.i = 1
  storage.next = nil
  helpers.write_file(DIR .. "log.txt", "start\n")
end)

script.on_event(defines.events.on_tick, function()
  local p = game.get_player(1)
  if not (p and p.connected) then return end
  if not storage.next then storage.next = game.tick + 30 end
  if game.tick < storage.next then return end
  local s = plan[storage.i]
  if not s then return end
  note("step " .. storage.i .. " tick " .. game.tick)
  local ok, err = pcall(s.fn)
  if not ok then note("ERROR step " .. storage.i .. ": " .. tostring(err)) end
  storage.i = storage.i + 1
  local nxt = plan[storage.i]
  storage.next = game.tick + math.floor((nxt and nxt.secs or 1) * 60)
end)
