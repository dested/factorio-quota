-- The Company Catalog. During a break it is the Break Room: shift report and
-- next-shift preview on the left, the shop on the right. During a shift it
-- is just the shop, with a rush fee and no new contracts.

local C = require("lib.config")
local U = require("lib.util")
local M = require("lib.market")
local P = require("lib.perks")
local W = require("lib.world")
local K = require("lib.conditions")
local SH = require("lib.shop")
local Z = require("lib.zoning")
local R = require("lib.rules")
local G = require("lib.gui.common")

local CAT = {}

local NAME = "quota_catalog"
local RIGHT_W = 860
local RIGHT_H = 600
local TABS = { "Contracts", "Tech", "Supplies", "Land", "Market" }

function CAT.is_open(player)
  local el = player.gui.screen[NAME]
  return el ~= nil and el.valid
end

function CAT.close(player)
  G.destroy(player, NAME)
  G.ui(player).cat = nil
end

local function heading(parent, text)
  local l = parent.add({ type = "label", caption = text, style = "heading_2_label" })
  l.style.top_margin = 4
  return l
end

local function rarity_color(r)
  local c = C.RARITY[r].color
  return { c[1], c[2], c[3] }
end

-- ------------------------------------------------------- break panel ---

local function report_section(parent)
  local q = storage.q
  local rep = q.report
  if not rep then return end
  local box = parent.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  box.style.horizontally_stretchable = true
  local title, color
  if rep.met then
    title, color = "SHIFT " .. rep.n .. " COMPLETE", { 0.4, 1, 0.45 }
  else
    title, color = "QUOTA MISSED", { 1, 0.4, 0.35 }
  end
  G.label(box, title, "quota_big_label", { color = color })
  G.label(box, { "", "Shipped ", U.money(rep.shipped), " of ", U.money(rep.quota), "  (", U.pct(rep.quota > 0 and rep.shipped / rep.quota or 0), ")" }, "semibold_label")
  if rep.best then
    G.label(box, { "", "Best seller: [item=", rep.best, "] ", U.money(rep.best_v) }, "label")
  end
  for _, line in ipairs(rep.lines) do
    local f = box.add({ type = "flow", direction = "horizontal" })
    local l = G.label(f, line[1], "label", { wrap = true, width = 210 })
    if line.color then l.style.font_color = line.color end
    G.pusher(f)
    if line[2] then
      G.label(f, (line[2] >= 0 and "+" or "") .. U.money(line[2]), "bold_label", { color = { 0.45, 1, 0.5 } })
    end
  end
  if rep.payday and rep.payday > 0 then
    local f = box.add({ type = "flow", direction = "horizontal" })
    G.label(f, "Payday", "bold_label")
    G.pusher(f)
    G.label(f, "+" .. U.money(rep.payday), "quota_gold_label")
  end
end

local function next_section(parent)
  local q = storage.q
  local nx = q.next
  if not nx then return end
  local box = parent.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  box.style.horizontally_stretchable = true
  local caption = q.endless and ("NEXT: SHIFT " .. nx.n) or ("NEXT: SHIFT " .. nx.n .. " OF " .. R.final())
  G.label(box, caption, "quota_mid_label", { color = { 0.75, 0.85, 1 } })
  local f = box.add({ type = "flow", direction = "horizontal" })
  f.style.vertical_align = "center"
  G.label(f, U.money(nx.quota), "quota_title_label")
  G.pusher(f)
  G.label(f, U.time(nx.len * 60) .. " shift", "semibold_label")
  if #nx.conditions > 0 then
    heading(box, "Conditions")
    for _, id in ipairs(nx.conditions) do
      local d = K.BY_ID[id]
      local row = box.add({ type = "flow", direction = "horizontal" })
      row.style.vertical_align = "top"
      G.icon(row, d.sprite, 36, nil, nil, d.good and "slot_button" or "red_slot_button")
      local col = row.add({ type = "flow", direction = "vertical" })
      col.style.vertical_spacing = 0
      G.label(col, d.name, "bold_label", { color = d.good and { 0.5, 1, 0.55 } or { 1, 0.55, 0.45 } })
      G.label(col, d.desc, "label", { wrap = true, width = 230 })
    end
  else
    G.label(box, "No special conditions. Enjoy it.", "label", { color = { 0.7, 0.7, 0.7 } })
  end
  heading(box, "Hot items")
  local hf = box.add({ type = "flow", direction = "horizontal" })
  hf.style.vertical_align = "center"
  if #nx.hot_order == 0 then G.label(hf, "None yet. Unlock more recipes.", "label") end
  for _, name in ipairs(nx.hot_order) do
    local m = M.boosted(nx.hot[name])
    G.item_icon(hf, name, 36)
    G.label(hf, U.mult(m), "bold_label", { color = { 1, 0.6, 0.15 } })
  end
end

local function break_panel(parent, player)
  local q = storage.q
  local s = G.ui(player)
  local left = parent.add({ type = "flow", direction = "vertical" })
  left.style.width = 320
  left.style.vertical_spacing = 8
  local scroll = left.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto" })
  scroll.style.height = RIGHT_H - (q.corporate and 124 or 84)
  scroll.style.horizontally_stretchable = true
  local inner = scroll.add({ type = "flow", direction = "vertical" })
  inner.style.vertical_spacing = 8
  inner.style.horizontally_stretchable = true
  report_section(inner)
  next_section(inner)
  if q.corporate then
    G.button(left, "A Corporate Offer is waiting", "show_corporate", nil, "quota_wide_button")
  end
  local foot = left.add({ type = "flow", direction = "horizontal" })
  foot.style.vertical_align = "center"
  local tf = foot.add({ type = "flow", direction = "vertical" })
  tf.style.vertical_spacing = 0
  G.label(tf, "Shift starts in", "label", { color = { 0.7, 0.7, 0.7 } })
  s.cat.break_timer = G.label(tf, "", "quota_mid_label", { color = { 0.75, 0.85, 1 } })
  G.pusher(foot)
  s.cat.clock = G.button(foot, "CLOCK IN", "clock_in", nil, "quota_clockin_button")
  s.cat.clock.style.minimal_width = 190
end

-- --------------------------------------------------------- contracts ---

local function contract_card(parent, id, mode)
  local d = P.BY_ID[id]
  local card = parent.add({ type = "frame", style = "quota_card_frame", direction = "vertical" })
  local top = card.add({ type = "flow", direction = "horizontal" })
  top.style.vertical_align = "center"
  G.icon(top, d.sprite, 52, nil, nil, "slot_button")
  local nf = top.add({ type = "flow", direction = "vertical" })
  nf.style.vertical_spacing = 0
  G.label(nf, d.name, "quota_card_name").style.maximal_width = 120
  G.label(nf, C.RARITY[d.rarity].name, "bold_label", { color = rarity_color(d.rarity) })
  G.label(card, d.desc, "quota_card_desc")
  G.pusher(card, true)
  if mode == "offer" then
    local price = SH.contract_price(id)
    G.label(card, U.money(price), "quota_gold_label").style.font_color = G.price_color(price)
    G.button(card, "BUY", "buy_contract", { id = id }, "quota_buy_button")
  end
  return card
end

local function owned_card(parent, id)
  local q = storage.q
  local d = P.BY_ID[id]
  local card = parent.add({ type = "frame", style = "quota_small_card_frame", direction = "vertical" })
  card.style.width = 162
  card.tooltip = { "", "[font=default-bold]", d.name, "[/font]\n", d.desc }
  local top = card.add({ type = "flow", direction = "horizontal" })
  top.style.vertical_align = "center"
  G.icon(top, d.sprite, 36, card.tooltip)
  G.label(top, d.name, "bold_label", { wrap = true, width = 105, color = rarity_color(d.rarity) })
  G.pusher(card, true)
  local refund = math.floor((q.perk_paid[id] or 0) / 2)
  G.button(card, "Sell  +" .. U.money(refund), "sell_contract", { id = id }, "quota_wide_button")
end

local function tab_contracts(pane, player)
  local q = storage.q
  local root = pane.add({ type = "flow", direction = "vertical" })
  root.style.vertical_spacing = 6
  heading(root, { "", "Your contracts (", P.count(), " / ", P.slots(), ")" })
  local owned = root.add({ type = "flow", direction = "horizontal" })
  owned.style.horizontal_spacing = 6
  owned.style.minimal_height = 96
  for _, id in ipairs(q.perks) do owned_card(owned, id) end
  for _ = P.count() + 1, P.slots() do
    local empty = owned.add({ type = "frame", style = "quota_small_card_frame", direction = "vertical" })
    empty.style.width = 162
    G.label(empty, "Empty slot", "label", { color = { 0.5, 0.5, 0.5 } })
  end
  root.add({ type = "line" })
  if q.briefing then
    heading(root, "On the table")
    G.label(root, "Contracts go on the table in the break after each shift.", "label", { wrap = true, width = RIGHT_W - 40 })
    return
  end
  if q.phase ~= "break" then
    heading(root, "On the table")
    G.label(root, "New contracts are only offered during breaks. You can still sell the ones you hold.", "label",
      { wrap = true, width = RIGHT_W - 40 })
    return
  end
  local hf = root.add({ type = "flow", direction = "horizontal" })
  hf.style.vertical_align = "center"
  heading(hf, "On the table")
  G.pusher(hf)
  local rp = SH.reroll_price()
  G.button(hf, { "", "Reroll offers  ", U.money(rp) }, "reroll", nil, "button")
  local offers = root.add({ type = "flow", direction = "horizontal" })
  offers.style.horizontal_spacing = 8
  if #q.offers == 0 then
    G.label(offers, "You bought everything on the table. Reroll for more.", "label")
  end
  for _, id in ipairs(q.offers) do contract_card(offers, id, "offer") end
  G.label(root, "Contracts bend the rules for the rest of the run. Sell one back for half what you paid.", "label",
    { color = { 0.7, 0.7, 0.7 } })
end

-- --------------------------------------------------------------- R&D ---

local function rnd_row(parent, sprite, name, sub, desc, price, action, tags, state, unlocks)
  local row = parent.add({ type = "frame", style = "quota_row_frame", direction = "horizontal" })
  row.style.width = (RIGHT_W - 60) / 2
  row.style.vertical_align = "center"
  G.icon(row, sprite, 44, nil, nil, state == "owned" and "yellow_slot_button" or "slot_button")
  local col = row.add({ type = "flow", direction = "vertical" })
  col.style.vertical_spacing = 0
  local nf = col.add({ type = "flow", direction = "horizontal" })
  G.label(nf, name, "bold_label")
  if sub then G.label(nf, sub, "label", { color = { 0.7, 0.85, 1 } }) end
  G.label(col, desc, "label", { wrap = true, width = 210 })
  if unlocks and #unlocks > 0 then
    local uf = col.add({ type = "flow", direction = "horizontal" })
    uf.style.horizontal_spacing = 0
    for i, rname in ipairs(unlocks) do
      if i > 7 then break end
      local b = uf.add({ type = "sprite-button", sprite = G.sprite("recipe/" .. rname), style = "transparent_slot" })
      b.style.size = 24
      b.elem_tooltip = { type = "recipe", name = rname }
    end
  end
  G.pusher(row)
  local bf = row.add({ type = "flow", direction = "vertical" })
  bf.style.horizontal_align = "right"
  bf.style.width = 96
  if state == "owned" then
    G.label(bf, "OWNED", "bold_label", { color = { 1, 0.8, 0.3 } })
  elseif type(state) == "string" and state ~= "buy" then
    G.label(bf, state, "label", { wrap = true, width = 96, color = { 0.65, 0.65, 0.65 } })
  else
    G.label(bf, U.money(price), "bold_label").style.font_color = G.price_color(price)
    local b = G.button(bf, "BUY", action, tags, "quota_buy_button")
    b.style.width = 90
  end
end

local function tab_rnd(pane)
  local scroll = pane.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto-and-reserve-space" })
  scroll.style.height = RIGHT_H - 72
  scroll.style.width = RIGHT_W - 20
  local intro = scroll.add({ type = "frame", style = "quota_section_frame", direction = "vertical" })
  G.label(intro, "How tech works here", "bold_label", { color = { 1, 0.85, 0.35 } })
  G.label(intro, "Technology below is Factorio's own tech tree (press T to see it). Buying a license researches that technology on the spot, prerequisites included: no labs, no science packs. Your labs still work the normal way too, so you can always research with science instead of cash. Hover the small icons for the recipes a tech unlocks.",
    "label", { wrap = true, width = RIGHT_W - 70 })
  G.label(intro, "Company upgrades are QUOTA's own: they stack on top of Factorio's bonuses.", "label",
    { wrap = true, width = RIGHT_W - 70, color = { 0.7, 0.7, 0.7 } })
  if R.complex() then
    G.label(intro, "Zoning: " .. Z.summary(), "label", { wrap = true, width = RIGHT_W - 70, color = { 1, 0.7, 0.4 } })
  end
  heading(scroll, "Company upgrades")
  local ut = scroll.add({ type = "table", column_count = 2 })
  ut.style.horizontal_spacing = 6
  ut.style.vertical_spacing = 6
  for _, u in ipairs(P.UPGRADES) do
    local lvl = SH.upgrade_level(u.id)
    local lock = SH.upgrade_locked(u)
    local state = "buy"
    if lvl >= u.max then state = "MAXED" elseif lock then state = lock end
    rnd_row(ut, u.sprite, u.name, "  Lv " .. lvl .. "/" .. u.max, u.desc, SH.upgrade_price(u), "buy_upgrade", { id = u.id }, state)
  end
  heading(scroll, "Tech licenses (Factorio research)")
  local tt = scroll.add({ type = "table", column_count = 2 })
  tt.style.horizontal_spacing = 6
  tt.style.vertical_spacing = 6
  local entries = {}
  for _, r in ipairs(SH.RND) do
    local owned = SH.rnd_owned(r)
    local lock = SH.rnd_locked(r)
    entries[#entries + 1] = { r = r, rank = owned and 3 or (lock and 2 or 1), lock = lock }
  end
  table.sort(entries, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.r.price < b.r.price
  end)
  for _, e in ipairs(entries) do
    local state = "buy"
    if e.rank == 3 then state = "owned" elseif e.lock then state = e.lock end
    rnd_row(tt, "technology/" .. e.r.tech, e.r.name, nil, e.r.desc, SH.rnd_price(e.r), "buy_rnd", { id = e.r.id }, state,
      SH.rnd_unlocks(e.r))
  end
end

-- ----------------------------------------------------------- supplies ---

local function crate_card(parent, sprite, name, desc, items, price, action, tags, locked)
  local card = parent.add({ type = "frame", style = "quota_small_card_frame", direction = "vertical" })
  card.style.width = math.floor((RIGHT_W - 60) / 3)
  local top = card.add({ type = "flow", direction = "horizontal" })
  top.style.vertical_align = "center"
  G.icon(top, sprite, 40)
  local nf = top.add({ type = "flow", direction = "vertical" })
  nf.style.vertical_spacing = 0
  G.label(nf, name, "bold_label")
  if desc then G.label(nf, desc, "label", { wrap = true, width = 200, color = { 0.75, 0.75, 0.75 } }) end
  if items then
    local f = card.add({ type = "flow", direction = "horizontal" })
    f.style.horizontal_spacing = 0
    for _, it in ipairs(items) do G.item_icon(f, it[1], 36, it[2]) end
  end
  G.pusher(card, true)
  local bf = card.add({ type = "flow", direction = "horizontal" })
  bf.style.vertical_align = "center"
  if locked then
    G.label(bf, locked, "label", { color = { 0.65, 0.65, 0.65 } })
  else
    G.label(bf, U.money(price), "quota_gold_label").style.font_color = G.price_color(price)
    G.pusher(bf)
    local b = G.button(bf, "BUY", action, tags, "quota_buy_button")
    b.style.width = 100
    b.style.horizontally_stretchable = false
  end
end

local function tab_supplies(pane)
  local scroll = pane.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto-and-reserve-space" })
  scroll.style.height = RIGHT_H - 72
  scroll.style.width = RIGHT_W - 20
  G.label(scroll, "Everything here falls from orbit in a drop pod that lands next to you: empty the pod to collect it.", "label",
    { wrap = true, width = RIGHT_W - 60, color = { 0.7, 0.7, 0.7 } })
  local t = scroll.add({ type = "table", column_count = 3 })
  t.style.horizontal_spacing = 6
  t.style.vertical_spacing = 6
  crate_card(t, "item/quota-terminal", "Shipping Terminal", "Another terminal. Place it anywhere.", nil,
    SH.terminal_price(), "buy_terminal", nil, nil)
  crate_card(t, "virtual-signal/signal-info", "Mystery Crate", "Five random stacks of machinery. Usually a bargain.", nil,
    SH.mystery_price(), "buy_mystery", nil, nil)
  local locked = {}
  for _, c in ipairs(SH.CRATES) do
    if SH.crate_available(c) then
      crate_card(t, c.sprite, c.name, nil, SH.crate_items(c), SH.crate_price(c), "buy_crate", { id = c.id }, nil)
    else
      locked[#locked + 1] = c
    end
  end
  for _, c in ipairs(locked) do
    crate_card(t, c.sprite, c.name, nil, nil, 0, nil, nil, "Locked: needs the tech")
  end
end

-- --------------------------------------------------------------- land ---

local function tab_land(pane, player)
  local q = storage.q
  local s = G.ui(player)
  local root = pane.add({ type = "flow", direction = "horizontal" })
  root.style.horizontal_spacing = 12
  local gridbox = root.add({ type = "frame", style = "deep_frame_in_shallow_frame", direction = "vertical" })
  local grid = gridbox.add({ type = "table", column_count = 2 * C.GRID_RADIUS + 1 })
  grid.style.horizontal_spacing = 0
  grid.style.vertical_spacing = 0
  local GR = C.GRID_RADIUS
  for py = -GR, GR do
    for px = -GR, GR do
      local plot = W.plot(px, py)
      local t = W.TYPES[plot.type]
      local key = W.key(px, py)
      local forsale = not plot.owned and W.purchasable(px, py)
      if plot.owned or forsale then
        local style = plot.owned and "quota_plot_owned" or "quota_plot_buy"
        if s.plot == key then style = "quota_plot_selected" end
        local tip = plot.owned and { "", t.name, " (yours)" } or { "", t.name, "  ", U.money(SH.plot_price(plot)), "\nClick for details." }
        grid.add({
          type = "sprite-button", sprite = G.sprite(t.sprite), style = style, tooltip = tip,
          tags = { qa = "select_plot", px = px, py = py },
        })
      else
        -- Unexplored: no icon until it borders your land.
        local b = grid.add({ type = "sprite-button", style = "quota_plot_button", tooltip = "Unexplored. Buy land next to it to see what's here." })
        b.enabled = false
      end
    end
  end
  local legend = gridbox.add({ type = "label", style = "label",
    caption = "[color=255,210,80]Gold[/color]: your land    [color=110,220,110]Green[/color]: for sale next door (click one)" })
  legend.style.font_color = { 0.75, 0.75, 0.75 }
  legend.style.left_padding = 6
  legend.style.top_padding = 4

  local info = root.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  info.style.width = RIGHT_W - 9 * 52 - 50
  info.style.vertically_stretchable = true
  local sel = s.plot and q.plots[s.plot]
  if not sel then
    G.label(info, "The island", "quota_mid_label")
    G.label(info, "Your island is the gold square. The green squares next to it are for sale: click one to see what's on it and buy it. Bought land rises out of the sea, and the plots around it come up for sale next.",
      "label", { wrap = true, width = RIGHT_W - 9 * 52 - 80 })
    G.label(info, { "", "You own ", W.owned_count(), " plots. Each plot you buy makes the next one 18% pricier." }, "label",
      { wrap = true, width = RIGHT_W - 9 * 52 - 80, color = { 0.75, 0.75, 0.75 } })
    if R.complex() then
      G.label(info, "Zoning: " .. Z.summary(), "label", { wrap = true, width = RIGHT_W - 9 * 52 - 80, color = { 1, 0.7, 0.4 } })
    end
    return
  end
  local t = W.TYPES[sel.type]
  local top = info.add({ type = "flow", direction = "horizontal" })
  top.style.vertical_align = "center"
  G.icon(top, t.sprite, 64)
  local nf = top.add({ type = "flow", direction = "vertical" })
  G.label(nf, t.name, "quota_mid_label")
  local ring = math.max(math.abs(sel.px), math.abs(sel.py))
  G.label(nf, { "", "Plot ", sel.px, ", ", sel.py, "   Ring ", ring }, "label", { color = { 0.7, 0.7, 0.7 } })
  G.label(info, t.desc, "label", { wrap = true, width = RIGHT_W - 9 * 52 - 80 })
  local feats = {}
  for _, f in ipairs(sel.features or {}) do
    if f.kind == "ore" then feats[#feats + 1] = "[item=" .. f.name .. "]" end
    if f.kind == "oil" then feats[#feats + 1] = "[fluid=crude-oil]" end
    if f.kind == "nests" then feats[#feats + 1] = "[entity=biter-spawner]" end
    if f.kind == "ruins" then feats[#feats + 1] = "[entity=crash-site-spaceship]" end
    if f.kind == "lake" then feats[#feats + 1] = "[item=offshore-pump]" end
  end
  if #feats > 0 then G.label(info, "Contains: " .. table.concat(feats, " "), "label") end
  G.pusher(info, true)
  if sel.owned then
    G.label(info, "You own this plot.", "bold_label", { color = { 1, 0.8, 0.3 } })
  elseif W.purchasable(sel.px, sel.py) then
    local price = SH.plot_price(sel)
    G.label(info, U.money(price), "quota_title_label").style.font_color = G.price_color(price)
    G.button(info, "BUY THIS PLOT", "buy_plot", { px = sel.px, py = sel.py }, "quota_buy_button")
  else
    G.label(info, { "", "Not for sale yet: buy a plot next to it first. (", U.money(SH.plot_price(sel)), " today)" },
      "label", { wrap = true, width = RIGHT_W - 9 * 52 - 80, color = { 0.7, 0.7, 0.7 } })
  end
end

-- ------------------------------------------------------------- market ---

local function tab_market(pane)
  local root = pane.add({ type = "flow", direction = "vertical" })
  G.label(root, "What the terminal pays per unit. Usual x Hot, minus any flood (selling lots of one item drops its price; it recovers 75% between shifts). Machinery sells for scrap. Hover an icon for its recipe.",
    "label", { wrap = true, width = RIGHT_W - 40, color = { 0.75, 0.75, 0.75 } })
  local scroll = root.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto-and-reserve-space" })
  scroll.style.height = RIGHT_H - 130
  scroll.style.width = RIGHT_W - 20
  local t = scroll.add({ type = "table", column_count = 6 })
  t.style.horizontal_spacing = 14
  t.style.vertical_spacing = 0
  -- Same width and alignment for header and cells so the columns line up.
  local cols = { { "", 28 }, { "Item", 300 }, { "Usual", 80, "right" }, { "Hot", 50, "center" },
    { "Flooded", 70, "right" }, { "Pays now", 100, "right" } }
  local function cell(i, caption, style, color)
    local l = G.label(t, caption, style, { color = color })
    l.style.width = cols[i][2]
    l.style.horizontal_align = cols[i][3] or "left"
    return l
  end
  for i, c in ipairs(cols) do cell(i, c[1], "bold_label", { 0.7, 0.7, 0.7 }) end
  local rows = M.price_list()
  for i, r in ipairs(rows) do
    if i > 120 then break end
    local usual = r.price / (r.hot or 1) / math.max(0.01, r.flood)
    G.item_icon(t, r.name, 28, nil, "transparent_slot")
    cell(2, prototypes.item[r.name] and prototypes.item[r.name].localised_name or r.name, "label")
    cell(3, U.price_str(usual), "label", { 0.7, 0.7, 0.7 })
    cell(4, r.hot and U.mult(r.hot) or "", "bold_label", { 1, 0.6, 0.15 })
    cell(5, r.flood < 0.995 and ("-" .. math.floor((1 - r.flood) * 100 + 0.5) .. "%") or "", "label", { 1, 0.45, 0.35 })
    cell(6, U.price_str(r.price), "bold_label", { 1, 0.85, 0.35 })
  end
end

-- ------------------------------------------------------------- window ---

function CAT.open(player)
  local q = storage.q
  CAT.close(player)
  local s = G.ui(player)
  s.cat = {}
  local is_break = q.phase == "break"
  local title = is_break and not q.briefing and "Break Room" or "The Company Catalog"
  local frame = G.window(player, NAME, title, "close_catalog")
  frame.auto_center = true
  s.cat.frame = frame

  local head = frame.add({ type = "flow", direction = "horizontal" })
  head.style.vertical_align = "center"
  head.style.bottom_margin = 4
  s.cat.wallet = G.label(head, "", "quota_big_label", { color = { 1, 0.85, 0.35 } })
  G.pusher(head)
  G.button(head, "Handbook", "open_handbook", nil, "button", { tooltip = "Every contract, condition, event, tech, crate and plot, with the hazard switches." })
  if q.phase == "shift" then
    G.label(head, "Rush order: Tech, Supplies and Land cost +25% during a shift.", "semibold_label", { color = { 1, 0.6, 0.4 } })
  elseif P.has("blackmarket") then
    G.label(head, "Black Market: 25% off Tech, Supplies and Land.", "semibold_label", { color = { 0.6, 1, 0.6 } })
  end

  local body = frame.add({ type = "flow", direction = "horizontal" })
  body.style.horizontal_spacing = 12
  if is_break then break_panel(body, player) end

  local right = body.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  local tp = right.add({ type = "tabbed-pane", style = "tabbed_pane_with_no_side_padding" })
  tp.style.width = RIGHT_W
  tp.style.height = RIGHT_H
  tp.tags = { qa = "tab" }
  for i, name in ipairs(TABS) do
    local tab = tp.add({ type = "tab", caption = name })
    local content = tp.add({ type = "flow", direction = "vertical" })
    content.style.padding = 8
    tp.add_tab(tab, content)
    if i == 1 then tab_contracts(content, player)
    elseif i == 2 then tab_rnd(content)
    elseif i == 3 then tab_supplies(content)
    elseif i == 4 then tab_land(content, player)
    else tab_market(content) end
  end
  tp.selected_tab_index = math.min(#TABS, math.max(1, s.tab or 1))
  player.opened = frame
  CAT.update(player)
end

function CAT.toggle(player)
  if CAT.is_open(player) then CAT.close(player) else CAT.open(player) end
end

function CAT.rebuild(player)
  if CAT.is_open(player) then CAT.open(player) end
end

-- Set by shift.lua.
CAT.early_bonus = nil

function CAT.update(player)
  local q = storage.q
  local s = G.ui(player)
  local c = s.cat
  if not (c and c.frame and c.frame.valid) then return end
  c.wallet.caption = { "", "Wallet  ", U.money(q.wallet) }
  if c.break_timer and c.break_timer.valid and q.phase == "break" then
    c.break_timer.caption = U.time(q.break_end - game.tick)
    local bonus = CAT.early_bonus and CAT.early_bonus() or 0
    c.clock.caption = bonus > 0 and { "", "CLOCK IN  +", U.money(bonus) } or "CLOCK IN"
    c.clock.tooltip = bonus > 0 and "Clock in early for a bonus: the more break time you skip, the bigger it is." or nil
  end
end

return CAT
