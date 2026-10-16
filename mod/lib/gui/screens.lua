-- Full-screen moments: orientation, corporate offers, fired and promoted.

local C = require("lib.config")
local U = require("lib.util")
local P = require("lib.perks")
local W = require("lib.world")
local SH = require("lib.shop")
local G = require("lib.gui.common")

local SC = {}

local ORIENT = "quota_orientation"
local CORP = "quota_corporate"
local ENDS = "quota_end"

-- -------------------------------------------------------- orientation ---

local RULES = {
  { "item/quota-terminal", "Every shift has a timer and a quota. Put products in the Shipping Terminal at the centre of your island. It pays market price, live." },
  { "virtual-signal/signal-white-flag", "Miss a quota and you get a written warning. Miss one with no warnings left and you're fired." },
  { "virtual-signal/signal-clock", "Between shifts you get a 90 second break. Shop: Contracts (perks that bend the rules), R&D (instant tech), Supplies (machines by drop pod) and Land." },
  { "virtual-signal/signal-fire", "Crafted goods are worth more than their ingredients. Hot items sell for x2 to x3. Sell too much of one thing and its price floods." },
  { "virtual-signal/signal-skull", "From shift 2 every shift has a Condition: gremlins, strikes, earthquakes, meteors, raids. Shift 8 is The Audit." },
  { "virtual-signal/signal-info", "Machinery sells for scrap, and the starter kit is Company property. Press J for the Catalog any time (25% rush fee mid-shift)." },
}

function SC.close_orientation(player)
  G.destroy(player, ORIENT)
end

function SC.orientation(player)
  SC.close_orientation(player)
  local s = G.ui(player)
  local frame = player.gui.screen.add({ type = "frame", name = ORIENT, direction = "vertical" })
  frame.auto_center = true
  frame.style.width = 680
  frame.style.padding = 16
  local title = G.label(frame, "QUOTA", "quota_timer_label", { color = { 1, 0.78, 0.2 } })
  title.style.font = "quota-huge"
  G.label(frame, "The Factory Must Grow (Or Else)", "quota_mid_label")
  frame.add({ type = "line" }).style.top_margin = 6
  G.label(frame, "Welcome to The Company, contractor. Here is the deal.", "bold_label").style.top_margin = 4

  local list = frame.add({ type = "flow", direction = "vertical" })
  list.style.vertical_spacing = 6
  list.style.top_margin = 6
  for _, r in ipairs(RULES) do
    local row = list.add({ type = "flow", direction = "horizontal" })
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 10
    G.icon(row, r[1], 36, nil, nil, "transparent_slot")
    G.label(row, r[2], "label", { wrap = true, width = 590 })
  end

  frame.add({ type = "line" }).style.top_margin = 8
  G.label(frame, "Pick your contract", "heading_2_label")
  local df = frame.add({ type = "flow", direction = "horizontal" })
  df.style.horizontal_spacing = 8
  for _, id in ipairs(C.DIFFICULTY_ORDER) do
    local d = C.DIFFICULTIES[id]
    local b = G.button(df, d.name, "difficulty", { id = id }, "button")
    b.style.width = 200
    b.toggled = s.difficulty == id
  end
  local d = C.DIFFICULTIES[s.difficulty]
  G.label(frame, { "", d.blurb, "  Quotas x", d.quota, "." }, "label", { color = { 0.8, 0.8, 0.8 } })

  local foot = frame.add({ type = "flow", direction = "horizontal" })
  foot.style.top_margin = 10
  foot.style.vertical_align = "center"
  G.label(foot, { "", "A starter kit drops from orbit, then you get ", C.BRIEFING_SECONDS, " seconds to look around." }, "label",
    { color = { 0.7, 0.85, 1 } })
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
    { "Difficulty", C.DIFFICULTIES[q.difficulty].name },
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
