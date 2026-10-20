-- Full-screen moments: Run Setup, corporate offers, fired and promoted.

local C = require("lib.config")
local U = require("lib.util")
local P = require("lib.perks")
local W = require("lib.world")
local SH = require("lib.shop")
local K = require("lib.conditions")
local E = require("lib.events")
local R = require("lib.rules")
local G = require("lib.gui.common")

local SC = {}

local ORIENT = "quota_orientation"
local CORP = "quota_corporate"
local ENDS = "quota_end"

-- ---------------------------------------------------------- run setup ---
-- Replaces the old difficulty pick. The draft lives in G.ui(player).setup until TAKE THE JOB
-- writes it to the mod settings and starts the run.

local RULES = {
  { "item/quota-terminal", "Every shift has a timer and a quota. Products in the Shipping Terminal sell at market price, live. Open the terminal to hold a sale: nothing ships while you're looking inside." },
  { "virtual-signal/signal-white-flag", "Miss a quota and you get a written warning. Miss one with none left and you're fired. The last shift is The Audit." },
  { "item/cargo-landing-pad", "Between shifts, shop in the Catalog (J): Contracts, Tech Licenses (buy Factorio research outright), machines and land. Purchases fall from orbit in a drop pod, right next to you." },
  { "virtual-signal/signal-fire", "Crafted goods pay more than their ingredients. Hot items pay x2 to x3; flooding one item drops its price. The MARKET panel on the left shows the best payers." },
}

function SC.close_orientation(player)
  G.destroy(player, ORIENT)
end

-- The setup draft for this player (starts from the mod settings).
function SC.setup_draft(player)
  local s = G.ui(player)
  if not s.setup then s.setup = R.read() end
  return s.setup
end

local function knob_caption(k, v)
  if k.key == "shifts" then
    if v == "auto" then return "Mode default" end
    return v .. " shifts"
  elseif k.key == "warnings" then
    if v == "auto" then return "Difficulty default" end
    return v == "1" and "1 warning" or (v .. " warnings")
  elseif k.key == "break_secs" then
    return v .. " s"
  end
  return "x" .. v
end

-- Dropdown captions for a knob and the index of `value` (appended when the settings hold an odd value).
function SC.knob_items(k, value)
  local items, index = {}, nil
  for i, c in ipairs(k.choices) do
    items[i] = knob_caption(k, tostring(c))
    if tostring(c) == tostring(value) then index = i end
  end
  if not index then
    items[#items + 1] = knob_caption(k, tostring(value))
    index = #items
  end
  return items, index
end

local function switch_name(sw)
  if sw.name then return sw.name, sw.sprite, sw.desc end
  local id = (sw.conds and sw.conds[1]) or (sw.events and sw.events[1])
  local d = (sw.conds and K.BY_ID[id]) or E.BY_ID[id]
  if d then return d.name, d.sprite, d.desc end
  return sw.key, nil, nil
end
SC.switch_name = switch_name

local function section(parent, title)
  local f = parent.add({ type = "frame", style = "quota_section_frame", direction = "vertical" })
  G.label(f, title, "heading_2_label")
  return f
end

-- Which preset (if any) the draft's switches match exactly.
local function active_preset(draft)
  for _, pr in ipairs(R.PRESETS) do
    local want = R.preset_off(pr.id)
    local same = true
    for _, sw in ipairs(R.SWITCHES) do
      if (want[sw.key] or false) ~= (draft.off[sw.key] or false) then same = false end
    end
    if same then return pr.id end
  end
  return nil
end

local SETUP_W = 880
local COL_L = 410
local COL_R = 430

function SC.orientation(player)
  SC.close_orientation(player)
  local draft = SC.setup_draft(player)
  local scale = player.display_scale > 0 and player.display_scale or 1
  local screen_w = math.floor(player.display_resolution.width / scale)
  local screen_h = math.floor(player.display_resolution.height / scale)

  local frame = player.gui.screen.add({ type = "frame", name = ORIENT, direction = "vertical" })
  frame.auto_center = true
  frame.style.width = math.min(SETUP_W, screen_w - 20)
  frame.style.maximal_height = screen_h - 40
  frame.style.padding = 10

  local head = frame.add({ type = "flow", direction = "horizontal" })
  head.style.vertical_align = "center"
  head.drag_target = frame
  local title = G.label(head, "QUOTA", "quota_title_label", { color = { 1, 0.78, 0.2 } })
  title.ignored_by_interaction = true
  local sub = G.label(head, "The Factory Must Grow (Or Else)", "quota_mid_label")
  sub.style.left_margin = 10
  sub.ignored_by_interaction = true
  G.pusher(head)

  -- Everything between the title and the footer scrolls on short screens.
  local body = frame.add({ type = "scroll-pane", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto" })
  body.style.maximal_height = screen_h - 160
  body.style.horizontally_stretchable = true

  local list = body.add({ type = "table", column_count = 2 })
  list.style.horizontal_spacing = 10
  list.style.vertical_spacing = 2
  for _, r in ipairs(RULES) do
    local row = list.add({ type = "flow", direction = "horizontal" })
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 6
    G.icon(row, r[1], 28, nil, nil, "transparent_slot")
    G.label(row, r[2], "label", { wrap = true, width = (SETUP_W - 110) / 2 })
  end

  local cols = body.add({ type = "flow", direction = "horizontal" })
  cols.style.horizontal_spacing = 8
  cols.style.top_margin = 6
  local left = cols.add({ type = "flow", direction = "vertical" })
  left.style.width = COL_L
  left.style.vertical_spacing = 6
  local right = cols.add({ type = "flow", direction = "vertical" })
  right.style.width = COL_R
  right.style.vertical_spacing = 6

  -- Mode
  local mode = section(left, "Mode")
  local cards = mode.add({ type = "flow", direction = "horizontal" })
  cards.style.horizontal_spacing = 6
  for _, id in ipairs(R.MODE_ORDER) do
    local m = R.MODES[id]
    local card = cards.add({ type = "frame", style = "quota_mode_card", direction = "vertical" })
    card.style.width = (COL_L - 30) / 2
    local b = G.button(card, m.name, "setup_mode", { id = id }, "button")
    b.style.horizontally_stretchable = true
    b.toggled = draft.mode == id
    for _, line in ipairs(m.lines) do G.label(card, line, "label", { wrap = true, width = (COL_L - 30) / 2 - 16 }) end
    G.label(card, m.blurb, "label", { wrap = true, width = (COL_L - 30) / 2 - 16,
      color = id == "simple" and { 0.5, 1, 0.55 } or { 0.7, 0.7, 0.7 } })
  end

  -- Difficulty
  local diff = section(left, "Difficulty")
  local df = diff.add({ type = "flow", direction = "horizontal" })
  df.style.horizontal_spacing = 6
  for _, id in ipairs(C.DIFFICULTY_ORDER) do
    local d = C.DIFFICULTIES[id]
    local b = G.button(df, d.name, "setup_diff", { id = id }, "button", { width = (COL_L - 40) / 3 })
    b.toggled = draft.difficulty == id
  end
  local d = C.DIFFICULTIES[draft.difficulty] or C.DIFFICULTIES.associate
  G.label(diff, { "", d.blurb, "  Quotas x", d.quota, "." }, "label", { wrap = true, width = COL_L - 30, color = { 0.8, 0.8, 0.8 } })

  -- Fine print
  local fine = section(left, "Fine print")
  local ft = fine.add({ type = "table", column_count = 2 })
  ft.style.horizontal_spacing = 8
  ft.style.vertical_spacing = 2
  for _, k in ipairs(R.KNOBS) do
    G.label(ft, k.name, "label", { width = 150 })
    local items, index = SC.knob_items(k, draft[k.key])
    local dd = G.dropdown(ft, items, index, "setup_knob", { key = k.key })
    dd.style.width = COL_L - 190
  end

  -- Threats
  local th = section(right, "Threats and events")
  G.label(th, "Tick what can happen this run. Presets tick the boxes for you:", "label",
    { wrap = true, width = COL_R - 30, color = { 0.75, 0.75, 0.75 } })
  local pf = th.add({ type = "flow", direction = "horizontal" })
  pf.style.horizontal_spacing = 4
  local current = active_preset(draft)
  for _, pr in ipairs(R.PRESETS) do
    local b = G.button(pf, pr.name, "setup_preset", { id = pr.id }, "button", { tooltip = pr.desc, width = (COL_R - 38) / 3 })
    b.toggled = current == pr.id
  end
  local groups = {
    { "threats", "Threats" }, { "conditions", "Market conditions" }, { "events", "Mid-shift events" },
  }
  for _, g in ipairs(groups) do
    G.label(th, g[2], "bold_label", { color = { 0.75, 0.75, 0.75 } }).style.top_margin = 2
    local t = th.add({ type = "table", column_count = 3 })
    t.style.horizontal_spacing = 4
    t.style.vertical_spacing = 0
    for _, sw in ipairs(R.SWITCHES) do
      if sw.group == g[1] then
        local name, sprite, desc = switch_name(sw)
        local cap = sprite and { "", "[img=", sprite, "] ", name } or name
        local cb = G.checkbox(t, cap, not draft.off[sw.key], "setup_switch", { key = sw.key },
          desc and { "", "[font=default-bold]", name, "[/font]\n", desc } or nil)
        cb.style.width = math.floor((COL_R - 40) / 3)
      end
    end
  end
  G.label(th, "Change them mid-run in the Handbook; they apply from the next shift.",
    "label", { wrap = true, width = COL_R - 30, color = { 0.6, 0.6, 0.6 } })

  local foot = frame.add({ type = "flow", direction = "horizontal" })
  foot.style.top_margin = 8
  foot.style.vertical_align = "center"
  G.button(foot, "Handbook", "open_handbook", nil, "button", { tooltip = "Every contract, condition, event, tech, crate and plot." })
  local sum = G.label(foot, R.describe(draft), "bold_label", { color = { 1, 0.85, 0.35 } })
  sum.style.left_margin = 10
  sum.tooltip = { "", "A starter kit drops from orbit, then you get ", C.BRIEFING_SECONDS, " seconds to look around." }
  G.pusher(foot)
  G.button(foot, "TAKE THE JOB", "start_run", nil, "quota_clockin_button")
end

-- ---------------------------------------------------- corporate offer ---

function SC.close_corporate(player)
  G.destroy(player, CORP)
end

function SC.corporate(player)
  local q = storage.q
  SC.close_corporate(player)
  if not q.corporate then return end
  local frame = G.window(player, CORP, "Corporate Offer", "close_corporate")
  frame.auto_center = true
  G.label(frame, "The board has a proposal. One signature, no take-backs. You can also walk away.", "label",
    { wrap = true, width = 640 })
  local row = frame.add({ type = "flow", direction = "horizontal" })
  row.style.horizontal_spacing = 8
  row.style.top_margin = 6
  for _, id in ipairs(q.corporate) do
    local o = SH.OFFER_BY_ID[id]
    local card = row.add({ type = "frame", style = "quota_card_frame", direction = "vertical" })
    card.style.height = 230
    local top = card.add({ type = "flow", direction = "horizontal" })
    top.style.vertical_align = "center"
    G.icon(top, o.sprite, 48)
    G.label(top, o.name, "quota_card_name").style.maximal_width = 120
    G.label(card, o.text(SH.offer_cash(o)), "quota_card_desc")
    G.pusher(card, true)
    G.button(card, "SIGN", "corp_accept", { id = id }, "quota_buy_button")
  end
  local foot = frame.add({ type = "flow", direction = "horizontal" })
  foot.style.top_margin = 6
  G.pusher(foot)
  G.button(foot, "No thanks", "corp_decline", nil, "red_button")
  frame.bring_to_front()
end

-- -------------------------------------------------------- end screens ---

function SC.close_end(player)
  G.destroy(player, ENDS)
end

local function stat_rows(parent)
  local q = storage.q
  local t = parent.add({ type = "table", column_count = 2 })
  t.style.horizontal_spacing = 30
  t.style.vertical_spacing = 2
  local best, best_v = nil, 0
  for name, v in pairs(q.stats.by_item) do
    if v > best_v then best, best_v = name, v end
  end
  local played = game.tick - (q.run_started or 0)
  local rows = {
    { "Shifts survived", tostring(q.stats.shifts_done or 0) },
    { "Total shipped", U.money(q.stats.total_shipped) },
    { "Items shipped", U.num(q.stats.items_shipped) },
    { "Best product", best and { "", "[item=", best, "] ", U.money(best_v) } or "-" },
    { "Bonuses earned", U.money(q.stats.total_bonus or 0) },
    { "Money spent", U.money(q.stats.total_spent or 0) },
    { "Plots owned", tostring(W.owned_count()) },
    { "Contracts held", tostring(P.count()) },
    { "Gremlins whacked", tostring(q.stats.gremlins or 0) },
    { "Meteors", tostring(q.stats.meteors or 0) },
    { "Bounties completed", tostring(q.stats.bounties or 0) },
    { "Golden Gear jackpots", tostring(q.stats.jackpots or 0) },
    { "The Auditor", q.stats.auditor_killed and "Defeated" or "Survived" },
    { "Time on the clock", U.time(played) },
    { "Rules", R.describe() },
  }
  for _, r in ipairs(rows) do
    G.label(t, r[1], "label", { color = { 0.75, 0.75, 0.75 } })
    G.label(t, r[2], "bold_label")
  end
end

function SC.end_screen(player)
  local q = storage.q
  SC.close_end(player)
  local frame = player.gui.screen.add({ type = "frame", name = ENDS, direction = "vertical" })
  frame.auto_center = true
  frame.style.width = 560
  frame.style.padding = 16
  local rep = q.report or { n = q.shift, shipped = 0, quota = 0 }
  if q.phase == "fired" then
    G.label(frame, "YOU'RE FIRED", "quota_timer_label", { color = { 1, 0.35, 0.3 } })
    G.label(frame, { "", "Shift ", rep.n, ": you shipped ", U.money(rep.shipped), " of a ", U.money(rep.quota), " quota." },
      "quota_mid_label")
    G.label(frame, "Security will escort you off the island. Please leave your badge at the terminal.", "label",
      { wrap = true, width = 520, color = { 0.8, 0.8, 0.8 } })
  else
    G.label(frame, "PROMOTED", "quota_timer_label", { color = { 1, 0.78, 0.2 } })
    G.label(frame, "You survived The Audit.", "quota_mid_label")
    G.label(frame, "The Company thanks you for your service. Your reward is more work. Keep going in Endless mode (quotas grow 45% a shift, The Audit returns every third shift) or start over.",
      "label", { wrap = true, width = 520, color = { 0.8, 0.8, 0.8 } })
  end
  frame.add({ type = "line" }).style.top_margin = 8
  stat_rows(frame)
  frame.add({ type = "line" }).style.top_margin = 8
  local foot = frame.add({ type = "flow", direction = "horizontal" })
  foot.style.horizontal_spacing = 8
  if q.phase == "promoted" then
    G.button(foot, "Keep working (Endless)", "go_endless", nil, "confirm_button")
    G.pusher(foot)
    G.button(foot, "Retire here", "retire", nil, "button")
    G.button(foot, "New run", "reapply", nil, "button")
  else
    G.button(foot, "Reapply (new run)", "reapply", nil, "confirm_button")
    G.pusher(foot)
    G.button(foot, "Look around", "close_end", nil, "button", { tooltip = "J brings this report back." })
  end
end

return SC
