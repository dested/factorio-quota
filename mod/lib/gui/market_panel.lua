-- The market side panel down the left edge (player.gui.left). Collapsible; open by default.
-- Two blocks: HOT (each hot item as base x multiplier = price, so nobody does the maths) and
-- TOP PRICES (the best other payers, two to a row). During a break it previews next shift.
-- Rows are rebuilt only when the item set changes, so hovering an icon for its recipe isn't
-- interrupted by the refresh.

local U = require("lib.util")
local M = require("lib.market")
local G = require("lib.gui.common")

local MP = {}

local NAME = "quota_market_panel"
local TOP = 10
local GREY = { 0.65, 0.65, 0.65 }
local GOLD = { 1, 0.85, 0.35 }
local ORANGE = { 1, 0.6, 0.15 }

function MP.destroy(player)
  local el = player.gui.left[NAME]
  if el and el.valid then el.destroy() end
  G.ui(player).mp = nil
end

local function sized(parent, caption, style, color, width, align)
  local l = G.label(parent, caption, style, { color = color })
  l.style.width = width
  l.style.horizontal_align = align or "left"
  return l
end

local function heading(parent, text, tip)
  local l = G.label(parent, text, "bold_label", { color = GREY })
  l.style.top_margin = 4
  l.tooltip = tip
  return l
end

function MP.build(player)
  local q = storage.q
  MP.destroy(player)
  if not (q.phase == "shift" or q.phase == "break" or q.phase == "retired") then return end
  local s = G.ui(player)
  local frame = player.gui.left.add({ type = "frame", name = NAME, direction = "vertical" })
  frame.style.padding = 6
  frame.style.width = 252
  local head = frame.add({ type = "flow", direction = "horizontal" })
  head.style.vertical_align = "center"
  local title = G.label(head, "MARKET", "bold_label", { color = GOLD })
  title.tooltip = "What the terminal pays per unit. Hover an icon for its recipe."
  local sub = G.label(head, "", "label", { color = GREY })
  sub.style.left_margin = 6
  G.pusher(head)
  local toggle = head.add({
    type = "sprite-button", style = "frame_action_button", tags = { qa = "toggle_market" },
    sprite = s.market_collapsed and "utility/expand" or "utility/collapse",
    tooltip = s.market_collapsed and "Show prices" or "Hide prices",
  })
  toggle.style.size = 20
  local body = frame.add({ type = "flow", direction = "vertical" })
  body.style.vertical_spacing = 2
  body.visible = not s.market_collapsed
  s.mp = { frame = frame, body = body, sub = sub, sig = nil, hot = {}, top = {} }
  MP.update(player)
end

-- Price caption with the flood cut appended when an item is flooded.
local function price_caption(price, flood)
  if flood < 0.995 then
    return U.price_str(price) .. " [color=255,110,90]-" .. math.floor((1 - flood) * 100 + 0.5) .. "%[/color]"
  end
  return U.price_str(price)
end

local function rebuild(mp, hot, top)
  local body = mp.body
  body.clear()
  mp.hot, mp.top = {}, {}
  heading(body, "HOT", "Hot items pay a multiple of their usual price this shift.")
  if #hot == 0 then
    G.label(body, "Nothing hot right now", "label", { color = GREY })
  else
    local t = body.add({ type = "table", column_count = 4 })
    t.style.horizontal_spacing = 4
    t.style.vertical_spacing = 0
    for i, r in ipairs(hot) do
      G.item_icon(t, r.name, 28, nil, "transparent_slot")
      local was = sized(t, "", "label", GREY, 54, "right")
      local mult = sized(t, "", "bold_label", ORANGE, 36, "center")
      local now = sized(t, "", "bold_label", GOLD, 104, "left")
      mp.hot[i] = { was = was, mult = mult, now = now }
    end
  end
  heading(body, "TOP PRICES", "The best-paying things you can make right now. Red % = flooded: selling a lot of one item drops its price; it recovers 75% between shifts.")
  local t = body.add({ type = "table", column_count = 4 })
  t.style.horizontal_spacing = 4
  t.style.vertical_spacing = 0
  for i, r in ipairs(top) do
    G.item_icon(t, r.name, 28, nil, "transparent_slot")
    mp.top[i] = sized(t, "", "bold_label", GOLD, 86, "left")
  end
  if #top == 0 then G.label(body, "Nothing to sell yet", "label", { color = GREY }) end
end

function MP.update(player)
  local q = storage.q
  local s = G.ui(player)
  local mp = s.mp
  if not (mp and mp.frame and mp.frame.valid) then return end
  local preview = q.phase == "break" and q.next ~= nil
  mp.sub.caption = preview and "next shift" or ""
  if s.market_collapsed then return end

  local mults = preview and q.next.hot or q.hot
  local order = preview and q.next.hot_order or q.hot_order or {}
  local hot = {}
  local is_hot = {}
  for _, name in ipairs(order) do
    local m = mults[name]
    if m then
      local price = preview and M.next_price(name) or M.price(name)
      local boosted = M.boosted(m)
      hot[#hot + 1] = { name = name, price = price, mult = boosted, flood = M.flood_mult(name) }
      is_hot[name] = true
    end
  end
  local top = {}
  for _, r in ipairs(M.top(TOP + #hot, preview)) do
    if not is_hot[r.name] and #top < TOP then top[#top + 1] = r end
  end

  local names = {}
  for _, r in ipairs(hot) do names[#names + 1] = r.name end
  names[#names + 1] = "|"
  for _, r in ipairs(top) do names[#names + 1] = r.name end
  local sig = table.concat(names, ",")
  if mp.sig ~= sig then
    rebuild(mp, hot, top)
    mp.sig = sig
  end
  for i, r in ipairs(hot) do
    local el = mp.hot[i]
    if el then
      el.was.caption = U.price_str(r.price / r.mult)
      el.mult.caption = U.mult(r.mult)
      el.now.caption = "= " .. price_caption(r.price, r.flood)
    end
  end
  for i, r in ipairs(top) do
    local el = mp.top[i]
    if el then el.caption = price_caption(r.price, r.flood) end
  end
end

function MP.toggle(player)
  local s = G.ui(player)
  s.market_collapsed = not s.market_collapsed
  MP.build(player)
end

return MP
