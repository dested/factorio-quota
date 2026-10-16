-- QUOTA's four custom entities, all built from vanilla art so they read as
-- native Factorio:
--   quota-terminal    the Shipping Terminal (cargo-hub art at 3/4 scale)
--   quota-supply-pod  a landed cargo pod that holds a delivery and vanishes when emptied
--   quota-meteor      an artillery arc carrying a glowing rock
--   quota-auditor     the final boss: a giant gold-masked behemoth

local util = require("util")

-- Multiply every `scale` and `shift` in a sprite/animation tree.
local function rescale(node, k)
  if type(node) ~= "table" then return end
  if type(node.scale) == "number" then node.scale = node.scale * k end
  if type(node.shift) == "table" then
    local sx = node.shift[1] or node.shift.x or 0
    local sy = node.shift[2] or node.shift.y or 0
    node.shift = { sx * k, sy * k }
  end
  for key, child in pairs(node) do
    if key ~= "shift" and type(child) == "table" then rescale(child, k) end
  end
end

local function scale_box(box, k)
  return { { box[1][1] * k, box[1][2] * k }, { box[2][1] * k, box[2][2] * k } }
end

-- ---------------------------------------------------------- terminal ---

local TERMINAL_SCALE = 0.75 -- 8x8 cargo hub art -> 6x6 terminal

local function terminal_picture()
  local layers = {}
  local pad = data.raw["cargo-landing-pad"]["cargo-landing-pad"]
  for _, group in pairs(pad.graphics_set.picture or {}) do
    -- The hatch occluder only makes sense with the real hatch animations.
    if group.render_layer ~= "above-inserters" then
      for _, layer in pairs(group.layers or { group }) do
        if layer.filename then
          local copy = util.table.deepcopy(layer)
          copy.render_layer = nil
          layers[#layers + 1] = copy
        end
      end
    end
  end
  local picture = { layers = layers }
  rescale(picture, TERMINAL_SCALE)
  return picture
end

data:extend({
  {
    type = "container",
    name = "quota-terminal",
    icon = "__base__/graphics/icons/cargo-landing-pad.png",
    icon_size = 64,
    flags = { "placeable-player", "player-creation", "not-upgradable" },
    minable = { mining_time = 1, result = "quota-terminal" },
    max_health = 5000,
    corpse = "big-remnants",
    collision_box = { { -2.9, -2.9 }, { 2.9, 2.9 } },
    selection_box = { { -3, -3 }, { 3, 3 } },
    inventory_size = 64,
    inventory_type = "normal",
    picture = terminal_picture(),
    open_sound = { filename = "__base__/sound/open-close/metal-large-open.ogg", volume = 0.6 },
    close_sound = { filename = "__base__/sound/open-close/metal-large-close.ogg", volume = 0.6 },
    impact_category = "metal",
    map_color = { 1, 0.75, 0.1 },
    circuit_wire_max_distance = 0,
  },
  {
    type = "item",
    name = "quota-terminal",
    icon = "__base__/graphics/icons/cargo-landing-pad.png",
    icon_size = 64,
    subgroup = "storage",
    order = "z[quota-terminal]",
    place_result = "quota-terminal",
    stack_size = 5,
  },
})

-- -------------------------------------------------------- supply pod ---

local pod = util.table.deepcopy(data.raw["temporary-container"]["cargo-pod-container"])
pod.name = "quota-supply-pod"
pod.inventory_size = 64
pod.destroy_on_empty = true
pod.alert_after_time = 0
pod.time_to_live = 0
pod.minable = { mining_time = 0.3 }
pod.max_health = 2000
pod.map_color = { 0.4, 0.9, 1 }
pod.hidden_in_factoriopedia = true
data:extend({ pod })

-- ------------------------------------------------------------ meteor ---

local meteor = util.table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
meteor.name = "quota-meteor"
meteor.reveal_map = false
meteor.hidden_in_factoriopedia = true
local rock = util.table.deepcopy(data.raw["simple-entity"]["huge-rock"].pictures[1])
rock.scale = (rock.scale or 0.5) * 0.9
rock.tint = { r = 1, g = 0.55, b = 0.25 }
rock.draw_as_glow = true
meteor.picture = rock
meteor.height_from_ground = 6
meteor.action = {
  type = "direct",
  action_delivery = {
    type = "instant",
    target_effects = {
      {
        type = "nested-result",
        action = {
          type = "area",
          radius = 3.5,
          action_delivery = {
            type = "instant",
            target_effects = {
              { type = "damage", damage = { amount = 140, type = "explosion" } },
              { type = "damage", damage = { amount = 60, type = "physical" } },
            },
          },
        },
      },
      {
        type = "create-trivial-smoke",
        smoke_name = "artillery-smoke",
        initial_height = 0,
        speed_from_center = 0.05,
        speed_from_center_deviation = 0.005,
        offset_deviation = { { -3, -3 }, { 3, 3 } },
        max_radius = 3,
        repeat_count = 120,
      },
      { type = "create-entity", entity_name = "big-artillery-explosion" },
      { type = "show-explosion-on-chart", scale = 0.25 },
      { type = "script", effect_id = "quota-meteor-impact" },
    },
  },
}
data:extend({ meteor })

-- ----------------------------------------------------------- auditor ---

local AUDITOR_SCALE = 2.5
local auditor = util.table.deepcopy(data.raw.unit["behemoth-biter"])
auditor.name = "quota-auditor"
auditor.max_health = 10000
auditor.healing_per_tick = 0
auditor.movement_speed = 0.035
auditor.distance_per_frame = auditor.distance_per_frame * AUDITOR_SCALE
auditor.vision_distance = 30
auditor.collision_box = scale_box(auditor.collision_box, 1.5)
auditor.selection_box = scale_box(auditor.selection_box, AUDITOR_SCALE)
auditor.sticker_box = scale_box(auditor.sticker_box or auditor.selection_box, AUDITOR_SCALE)
auditor.resistances = {
  { type = "physical", decrease = 2, percent = 20 },
  { type = "explosion", decrease = 0, percent = 15 },
  { type = "fire", decrease = 0, percent = 40 },
  { type = "acid", decrease = 0, percent = 0 },
  { type = "poison", decrease = 0, percent = 50 },
}
auditor.ai_settings = {
  destroy_when_commands_fail = false,
  allow_try_return_to_spawner = false,
  do_separation = true,
}
auditor.hidden_in_factoriopedia = true
auditor.factoriopedia_simulation = nil
auditor.water_reflection = nil
rescale(auditor.run_animation, AUDITOR_SCALE)
rescale(auditor.attack_parameters.animation, AUDITOR_SCALE)
auditor.attack_parameters.range = 2.5
auditor.attack_parameters.cooldown = 70
auditor.attack_parameters.ammo_type = {
  target_type = "entity",
  action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "damage", damage = { amount = 260, type = "physical" } },
        { type = "create-entity", entity_name = "big-explosion" },
      },
    },
  },
}

-- Gold mask: The Company's colours.
local function gild(node)
  if type(node) ~= "table" then return end
  if node.tint then node.tint = { r = 0.95, g = 0.72, b = 0.12, a = 1 } end
  for _, child in pairs(node) do
    if type(child) == "table" then gild(child) end
  end
end
gild(auditor.run_animation)
gild(auditor.attack_parameters.animation)
data:extend({ auditor })

-- ------------------------------------------------------------- tiles ---
-- The terminal pad. Copies of refined concrete that can't be mined, so the
-- pad can't be dug up and sold as concrete.

local function pad_tile(name, from)
  local t = util.table.deepcopy(data.raw.tile[from])
  t.name = name
  t.minable = nil
  t.placeable_by = nil
  t.next_direction = nil
  t.hidden_in_factoriopedia = true
  t.map_color = { 0.55, 0.45, 0.2 }
  return t
end

data:extend({
  pad_tile("quota-pad", "refined-concrete"),
  pad_tile("quota-pad-hazard", "refined-hazard-concrete-left"),
})

-- ----------------------------------------------------------- sprites ---
-- A closed cargo pod, drawn falling for supply drops and rising off the
-- terminal when a shipment leaves.

data:extend({
  {
    type = "sprite",
    name = "quota-pod",
    filename = "__base__/graphics/entity/cargo-pod/pod-landing.png",
    x = 0,
    y = 0,
    width = 192,
    height = 258,
    scale = 0.5,
  },
  {
    type = "sprite",
    name = "quota-pod-shadow",
    filename = "__base__/graphics/entity/cargo-pod/pod-static-shadow.png",
    width = 174,
    height = 56,
    scale = 0.5,
    draw_as_shadow = true,
  },
})
