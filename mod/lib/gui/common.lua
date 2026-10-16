-- GUI helpers shared by every screen. Every clickable element carries
-- tags = { qa = "<action>", ... }; control.lua routes clicks by that tag.
-- Element names are prefixed "quota_" so they never shadow LuaGuiElement
-- properties when indexed by name.

local U = require("lib.util")

local G = {}

-- Per-player UI state (selected tab, selected plot, element refs).
function G.ui(player)
  local q = storage.q
  q.ui = q.ui or {}
  local s = q.ui[player.index]
  if not s then
    s = { tab = 1, plot = nil, difficulty = "associate" }
    q.ui[player.index] = s
  end
  return s
end

function G.sprite(path)
  if path and helpers.is_valid_sprite_path(path) then return path end
  return "utility/questionmark"
end

function G.pusher(parent, vertical)
  local w = parent.add({ type = "empty-widget" })
  if vertical then w.style.vertically_stretchable = true else w.style.horizontally_stretchable = true end
  return w
end

function G.label(parent, caption, style, opts)
  local l = parent.add({ type = "label", caption = caption, style = style })
  if opts then
    if opts.color then l.style.font_color = opts.color end
    if opts.wrap then
      l.style.single_line = false
      if opts.width then l.style.maximal_width = opts.width end
    end
    if opts.width and not opts.wrap then l.style.width = opts.width end
    if opts.align then l.style.horizontal_align = opts.align end
    if opts.tooltip then l.tooltip = opts.tooltip end
  end
  return l
end

function G.button(parent, caption, action, extra, style, opts)
  local tags = { qa = action }
  for k, v in pairs(extra or {}) do tags[k] = v end
  local b = parent.add({ type = "button", caption = caption, style = style or "button", tags = tags })
  if opts then
    if opts.enabled == false then b.enabled = false end
    if opts.tooltip then b.tooltip = opts.tooltip end
    if opts.width then b.style.width = opts.width end
  end
  return b
end

function G.icon(parent, sprite, size, tooltip, number, style)
  local b = parent.add({
    type = "sprite-button", sprite = G.sprite(sprite), style = style or "slot_button",
    tooltip = tooltip, number = number,
  })
  b.style.size = size or 40
  return b
end

-- A screen frame with a draggable title bar and close button.
function G.window(player, name, title, close_action)
  local frame = player.gui.screen.add({ type = "frame", name = name, direction = "vertical" })
  local bar = frame.add({ type = "flow", direction = "horizontal" })
  bar.drag_target = frame
  bar.style.horizontal_spacing = 8
  local t = bar.add({ type = "label", caption = title, style = "frame_title", ignored_by_interaction = true })
  local drag = bar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = false })
  drag.style.horizontally_stretchable = true
  drag.style.height = 24
  drag.style.right_margin = 4
  drag.drag_target = frame
  if close_action then
    bar.add({
      type = "sprite-button", style = "frame_action_button", sprite = "utility/close",
      tooltip = "Close", tags = { qa = close_action },
    })
  end
  return frame, bar, t
end

function G.destroy(player, name)
  local el = player.gui.screen[name]
  if el and el.valid then el.destroy() end
end

function G.notify(player, text, good)
  player.create_local_flying_text({
    text = text, create_at_cursor = true,
    color = good and U.COLORS.green or U.COLORS.red,
  })
  if not good then player.play_sound({ path = "utility/cannot_build" }) end
end

-- Wallet colouring for prices.
function G.price_color(price)
  return storage.q.wallet >= price and { 1, 0.85, 0.35 } or { 1, 0.4, 0.35 }
end

return G
