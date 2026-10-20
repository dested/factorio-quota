-- The Company Handbook: everything the run can throw at you or sell you, in one
-- browsable window (from Run Setup and the Catalog). Conditions, events and the
-- swamp nests carry their on/off switch: in Run Setup a switch edits the draft,
-- mid-run it writes the mod setting and applies from the next shift.

local C = require("lib.config")
local U = require("lib.util")
local P = require("lib.perks")
local K = require("lib.conditions")
local E = require("lib.events")
local W = require("lib.world")
local SH = require("lib.shop")
local Z = require("lib.zoning")
local R = require("lib.rules")
local G = require("lib.gui.common")

local HB = {}

local NAME = "quota_handbook"
local W_PANE = 860
local H_PANE = 580
local TABS = { "Contracts", "Conditions", "Events", "Tech", "Supplies", "Land", "Deals" }

function HB.is_open(player)
  local el = player.gui.screen[NAME]
  return el ~= nil and el.valid
end

function HB.close(player)
  G.destroy(player, NAME)
end

-- Is a switch on, as this player sees it right now (the setup draft before a run).
function HB.switch_on(player, key)
  local q = storage.q
  if q.phase == "orientation" then
    local draft = G.ui(player).setup
    return not (draft and draft.off[key])
  end
  return R.on(key)
end

local function scroll(pane, note)
  local sp = pane.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto-and-reserve-space" })
  sp.style.height = H_PANE - 40
  sp.style.width = W_PANE - 16
  if note then
    local l = G.label(sp, note, "label", { wrap = true, width = W_PANE - 60, color = { 0.7, 0.7, 0.7 } })
    l.style.bottom_margin = 4
  end
  local t = sp.add({ type = "table", column_count = 2 })
  t.style.horizontal_spacing = 6
  t.style.vertical_spacing = 6
  return sp, t
end

-- One entry: icon, name (+ tag), description, optional switch.
local function entry(parent, player, o)
  local row = parent.add({ type = "frame", style = "quota_row_frame", direction = "horizontal" })
  row.style.width = (W_PANE - 50) / 2
  row.style.vertical_align = "top"
  if o.item then G.item_icon(row, o.item, 40) else G.icon(row, o.sprite, 40, nil, nil, o.style) end
  local col = row.add({ type = "flow", direction = "vertical" })
  col.style.vertical_spacing = 0
  local nf = col.add({ type = "flow", direction = "horizontal" })
  G.label(nf, o.name, "bold_label", { color = o.color })
  if o.tag then G.label(nf, o.tag, "label", { color = o.tag_color or { 0.7, 0.85, 1 } }).style.left_margin = 6 end
  G.label(col, o.desc or "", "label", { wrap = true, width = o.switch and 250 or 320 })
  if o.extra then o.extra(col) end
  if o.switch then
    G.pusher(row)
    local sw = R.SWITCH_BY_KEY[o.switch]
    local tip = sw and sw.desc or nil
    G.checkbox(row, "On", HB.switch_on(player, o.switch), "handbook_switch", { key = o.switch }, tip)
  end
end

local function tab_contracts(pane, player)
  local _, t = scroll(pane, "Contracts bend the rules for the rest of the run. Three go on the table every break; five slots; sell one back for half what you paid.")
  for _, d in ipairs(P.DEFS) do
    local c = C.RARITY[d.rarity].color
    entry(t, player, { sprite = d.sprite, name = d.name, tag = C.RARITY[d.rarity].name, tag_color = { c[1], c[2], c[3] }, desc = d.desc })
  end
end

local function tab_conditions(pane, player)
  local _, t = scroll(pane)
  for _, d in ipairs(K.DEFS) do
    local tag = d.special and "Final shift" or (d.good and "Good" or (d.tier == 1 and "From shift 2" or "From shift 4"))
    local key
    for _, s in ipairs(R.SWITCHES) do
      if U.contains(s.conds or {}, d.id) then key = s.key end
    end
    entry(t, player, {
      sprite = d.sprite, name = d.name, tag = tag, desc = d.desc, switch = key,
      style = d.good and "slot_button" or "red_slot_button",
      color = d.good and { 0.5, 1, 0.55 } or { 1, 0.6, 0.5 },
    })
  end
end

local function tab_events(pane, player)
  local _, t = scroll(pane)
  for _, d in ipairs(E.DEFS) do
    local key
    for _, s in ipairs(R.SWITCHES) do
      if U.contains(s.events or {}, d.id) then key = s.key end
    end
    entry(t, player, {
      sprite = d.sprite, name = d.name, tag = d.good and "Good" or "Bad", desc = d.desc, switch = key,
      style = d.good and "slot_button" or "red_slot_button",
      color = d.good and { 0.5, 1, 0.55 } or { 1, 0.6, 0.5 },
    })
  end
end

local function tab_tech(pane, player)
  local _, t = scroll(pane, "Tech licenses are Factorio's own technologies: buying one researches it on the spot, prerequisites included, no labs needed. Labs still research the normal way. Company upgrades are QUOTA's own and stack on Factorio's bonuses. Complex mode zoning: tier 2 needs 2 bought plots, tier 3 needs 4, tier 4 needs 6. Simple mode sells every tier.")
  for _, u in ipairs(P.UPGRADES) do
    entry(t, player, { sprite = u.sprite, name = u.name, tag = "Upgrade, " .. u.max .. " levels",
      desc = u.desc .. " From " .. U.money(u.base) .. "." })
  end
  for _, r in ipairs(SH.RND) do
    local tag = "Tier " .. Z.entry_tier(r)
    if r.requires and SH.RND_BY_ID[r.requires] then tag = tag .. ", after " .. SH.RND_BY_ID[r.requires].name end
    entry(t, player, { sprite = "technology/" .. r.tech, name = r.name, tag = tag, desc = r.desc .. " " .. U.money(r.price) .. "." })
  end
end

local function tab_supplies(pane, player)
  local _, t = scroll(pane, "Supplies fall from orbit in a drop pod that lands right where you're standing. Empty the pod to collect them.")
  entry(t, player, { sprite = "item/quota-terminal", name = "Shipping Terminal", tag = "Supplies",
    desc = "Another terminal, placed anywhere. Each one sells independently, which matters when The Auditor visits." })
  entry(t, player, { sprite = "virtual-signal/signal-info", name = "Mystery Crate", tag = "Supplies",
    desc = "Five random stacks of machinery worth 1.2x to 2.4x what you paid." })
  for _, c in ipairs(SH.CRATES) do
    entry(t, player, {
      sprite = c.sprite, name = c.name, tag = c.needs and "Needs the tech" or "Supplies",
      desc = "Arrives by drop pod where you stand.",
      extra = function(col)
        local f = col.add({ type = "flow", direction = "horizontal" })
        f.style.horizontal_spacing = 0
        for _, it in ipairs(c.items) do G.item_icon(f, it[1], 32, it[2]) end
      end,
    })
  end
end

local function tab_land(pane, player)
  local _, t = scroll(pane, "Land next to yours is for sale between and during shifts. Bought plots rise out of the sea. Each plot makes the next 18% pricier; farther rings cost more.")
  local order = { "hq", "iron", "copper", "coal", "quarry", "mixed", "lake", "forest", "flat", "oil", "ruins", "infested", "bonanza", "uranium" }
  for _, id in ipairs(order) do
    local d = W.TYPES[id]
    if d then
      entry(t, player, { sprite = d.sprite, name = d.name, tag = d.base > 0 and ("from " .. U.money(d.base)) or "Yours",
        desc = d.desc, switch = id == "infested" and "nests" or nil })
    end
  end
end

local function tab_deals(pane, player)
  local _, t = scroll(pane)
  for _, o in ipairs(SH.OFFERS) do
    entry(t, player, { sprite = o.sprite, name = o.name, tag = "Corporate Offer", desc = o.blurb })
  end
end

function HB.open(player)
  HB.close(player)
  local s = G.ui(player)
  local frame = G.window(player, NAME, "The Company Handbook", "close_handbook")
  frame.auto_center = true
  G.label(frame, "Everything The Company can offer you or throw at you. Switches apply from the next shift (in Run Setup: to this run).",
    "label", { color = { 0.75, 0.75, 0.75 } })
  local right = frame.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  local tp = right.add({ type = "tabbed-pane", style = "tabbed_pane_with_no_side_padding" })
  tp.style.width = W_PANE
  tp.style.height = H_PANE
  tp.tags = { qa = "hb_tab" }
  for i, name in ipairs(TABS) do
    local tab = tp.add({ type = "tab", caption = name })
    local content = tp.add({ type = "flow", direction = "vertical" })
    content.style.padding = 8
    tp.add_tab(tab, content)
    if i == 1 then tab_contracts(content, player)
    elseif i == 2 then tab_conditions(content, player)
    elseif i == 3 then tab_events(content, player)
    elseif i == 4 then tab_tech(content, player)
    elseif i == 5 then tab_supplies(content, player)
    elseif i == 6 then tab_land(content, player)
    else tab_deals(content, player) end
  end
  tp.selected_tab_index = math.min(#TABS, math.max(1, s.hb_tab or 1))
  frame.bring_to_front()
  player.opened = frame
end

function HB.toggle(player)
  if HB.is_open(player) then HB.close(player) else HB.open(player) end
end

function HB.rebuild(player)
  if HB.is_open(player) then HB.open(player) end
end

return HB
