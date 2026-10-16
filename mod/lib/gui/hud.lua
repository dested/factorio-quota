-- The HUD: a slim panel at the top centre of the screen. Rebuilt when the
-- phase changes, refreshed twice a second.

local C = require("lib.config")
local U = require("lib.util")
local P = require("lib.perks")
local K = require("lib.conditions")
local E = require("lib.events")
local AU = require("lib.auditor")
local H = require("lib.hazards")
local G = require("lib.gui.common")

local HUD = {}

local NAME = "quota_hud"
local WIDTH = 600

local function place(player, frame)
  local res = player.display_resolution
  local scale = player.display_scale
  frame.location = { x = math.floor((res.width - WIDTH * scale) / 2), y = math.floor(6 * scale) }
end

function HUD.destroy(player)
  G.destroy(player, NAME)
  G.ui(player).hud = nil
end

local function shift_title(q)
  if q.phase == "break" then return q.briefing and "BRIEFING" or "ON BREAK" end
  if q.phase == "retired" then return "RETIRED" end
  local n = q.shift or 0
  if q.endless then return "SHIFT " .. n .. "  (ENDLESS)" end
  if q.cond_active and q.cond_active.audit then return "SHIFT " .. n .. ": THE AUDIT" end
  return "SHIFT " .. n .. " / " .. C.FINAL_SHIFT
end

local function hot_row(parent, hot, order)
  parent.clear()
  if not order or #order == 0 then return end
  G.label(parent, "HOT", "quota_gold_label")
  for _, name in ipairs(order) do
    local m = hot[name]
    if m then
      local f = parent.add({ type = "flow", direction = "horizontal" })
      f.style.vertical_align = "center"
      f.style.horizontal_spacing = 2
      m = m + P.hot_bonus()
      G.icon(f, "item/" .. name, 32, { "", "[item=", name, "] sells for ", U.mult(m), " this shift" })
      G.label(f, U.mult(m), "bold_label", { color = { 1, 0.6, 0.15 } })
    end
  end
end

local function cond_row(parent, ids)
  parent.clear()
  if not ids or #ids == 0 then return end
  for _, id in ipairs(ids) do
    local d = K.BY_ID[id]
    if d then
      local f = parent.add({ type = "flow", direction = "horizontal" })
      f.style.vertical_align = "center"
      f.style.horizontal_spacing = 2
      local tip = { "", "[font=default-bold]", d.name, "[/font]\n", d.desc }
      G.icon(f, d.sprite, 32, tip, nil, d.good and "slot_button" or "red_slot_button")
      G.label(f, d.name, "bold_label", { color = d.good and { 0.5, 1, 0.55 } or { 1, 0.55, 0.45 }, tooltip = tip })
    end
  end
end

function HUD.build(player)
  local q = storage.q
  HUD.destroy(player)
  if not (q.phase == "shift" or q.phase == "break" or q.phase == "retired") then return end
  local s = G.ui(player)
  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical", style = "quota_hud_frame" })
  place(player, frame)
  local refs = { frame = frame }

  local top = frame.add({ type = "flow", direction = "horizontal" })
  top.style.vertical_align = "center"
  refs.title = G.label(top, shift_title(q), "quota_mid_label", { color = { 1, 0.78, 0.25 } })
  refs.title.style.width = 190
  G.pusher(top)
  refs.timer = G.label(top, "", "quota_timer_label")
  G.pusher(top)
  local wf = top.add({ type = "flow", direction = "vertical" })
  wf.style.width = 190
  wf.style.horizontal_align = "right"
  refs.wallet = G.label(wf, "", "quota_mid_label", { color = { 1, 0.85, 0.35 } })
  refs.wallet.tooltip = "Your wallet. Spend it in the Catalog (J)."
  refs.warn = G.label(wf, "", "semibold_label")

  if q.phase ~= "retired" then
    refs.bar = frame.add({ type = "progressbar", style = "quota_quota_bar", value = 0 })
    refs.tbar = frame.add({ type = "progressbar", style = "quota_time_bar", value = 1 })

    local info = frame.add({ type = "flow", direction = "horizontal" })
    info.style.vertical_align = "center"
    info.style.top_margin = 4
    refs.hot = info.add({ type = "flow", direction = "horizontal" })
    refs.hot.style.vertical_align = "center"
    refs.hot.style.horizontal_spacing = 6
    G.pusher(info)
    refs.conds = info.add({ type = "flow", direction = "horizontal" })
    refs.conds.style.vertical_align = "center"
    refs.conds.style.horizontal_spacing = 6

    local ev = frame.add({ type = "flow", direction = "horizontal" })
    ev.style.vertical_align = "center"
    refs.ev_flow = ev
    refs.ev_label = ev.add({ type = "label", caption = "" })
    G.pusher(ev)
    refs.ev_bar = ev.add({ type = "progressbar", style = "quota_time_bar", value = 1 })
    refs.ev_bar.style.horizontally_stretchable = false
    refs.ev_bar.style.width = 140

    local au = frame.add({ type = "flow", direction = "horizontal" })
    au.style.vertical_align = "center"
    refs.au_flow = au
    refs.au_label = au.add({ type = "label", caption = "", style = "bold_label" })
    refs.au_label.style.font_color = { 1, 0.4, 0.3 }
    G.pusher(au)
    refs.au_bar = au.add({ type = "progressbar", value = 1 })
    refs.au_bar.style.width = 220
    refs.au_bar.style.color = { 1, 0.3, 0.2 }
  end

  local foot = frame.add({ type = "flow", direction = "horizontal" })
  foot.style.vertical_align = "center"
  foot.style.top_margin = 4
  if q.phase == "break" then
    G.button(foot, q.briefing and "Catalog (J)" or "Break Room (J)", "toggle_catalog", nil, "button")
    refs.extra = G.label(foot, "", "semibold_label")
    refs.extra.style.left_margin = 6
    G.pusher(foot)
    refs.clock = G.button(foot, "CLOCK IN", "clock_in", nil, "confirm_button")
  else
    G.button(foot, "Catalog (J)", "toggle_catalog", nil, "button",
      { tooltip = q.phase == "shift" and "R&D, Supplies and Land, with a 25% rush fee during shifts." or nil })
    refs.extra = G.label(foot, "", "semibold_label")
    G.pusher(foot)
    refs.gremlins = G.label(foot, "", "bold_label", { color = { 0.5, 1, 0.4 } })
    if q.phase == "retired" then G.button(foot, "New run", "reapply", nil, "button") end
  end
  s.hud = refs
  HUD.update(player)
end

function HUD.update(player)
  local q = storage.q
  local s = G.ui(player)
  local r = s.hud
  if not (r and r.frame and r.frame.valid) then return end
  r.wallet.caption = U.money(q.wallet)
  r.title.caption = shift_title(q)
  local diff = C.DIFFICULTIES[q.difficulty or "associate"]
  if q.phase == "retired" then
    r.timer.caption = ""
    r.warn.caption = ""
    return
  end
  r.warn.caption = { "", "Warnings left: ", q.warnings_left, " / ", diff.warnings }
  r.warn.style.font_color = q.warnings_left == 0 and { 1, 0.45, 0.4 } or { 0.85, 0.85, 0.85 }

  if q.phase == "shift" then
    local left = math.max(0, q.shift_end - game.tick)
    r.timer.caption = U.time(left)
    r.timer.style.font_color = left < 30 * 60 and { 1, 0.35, 0.3 } or { 1, 1, 1 }
    local frac = q.quota > 0 and q.shipped / q.quota or 0
    r.bar.value = math.min(1, frac)
    if q.quota_met then
      r.bar.caption = { "", "QUOTA MET  ", U.money(q.shipped), " / ", U.money(q.quota), "  (", U.pct(frac), ")" }
      r.bar.style.color = { 0.35, 0.95, 0.4 }
    else
      r.bar.caption = { "", U.money(q.shipped), " / ", U.money(q.quota), "  (", U.pct(frac), ")" }
      r.bar.style.color = { 1, 0.75, 0.1 }
    end
    r.tbar.value = q.shift_len > 0 and left / q.shift_len or 0
    local sig = q.hot_sig .. ":" .. P.hot_bonus()
    if r.hot_sig ~= sig then
      hot_row(r.hot, q.hot, q.hot_order)
      cond_row(r.conds, q.conditions)
      r.hot_sig = sig
    end
    local text, eleft, elen = E.describe()
    r.ev_flow.visible = text ~= nil
    if text then
      r.ev_label.caption = text
      r.ev_bar.value = elen and elen > 0 and eleft / elen or 0
    end
    local st, wait = AU.status()
    r.au_flow.visible = st == "incoming" or st == "active"
    if st == "incoming" then
      r.au_label.caption = { "", "THE AUDITOR lands in ", U.time(wait) }
      r.au_bar.value = 1
    elseif st == "active" then
      r.au_label.caption = "THE AUDITOR"
      r.au_bar.value = AU.health() or 0
    end
    local g = H.gremlin_count()
    r.gremlins.caption = g > 0 and ("Gremlins loose: " .. g) or ""
    local bits = {}
    if P.has("workaholic") and (q.perk_state.workaholic or 0) > 0 then
      bits[#bits + 1] = "Workaholic +" .. (6 * q.perk_state.workaholic) .. "%"
    end
    r.extra.caption = table.concat(bits, "   ")
  elseif q.phase == "break" then
    local left = math.max(0, q.break_end - game.tick)
    r.timer.caption = U.time(left)
    r.timer.style.font_color = left < 15 * 60 and { 1, 0.6, 0.2 } or { 0.75, 0.85, 1 }
    local nx = q.next
    if nx then
      r.bar.value = 0
      r.bar.caption = { "", "NEXT: SHIFT ", nx.n, "   QUOTA ", U.money(nx.quota), "   ", U.time(nx.len * 60) }
      r.bar.style.color = { 1, 0.75, 0.1 }
      local sig = "next" .. nx.n .. table.concat(nx.hot_order, ",") .. table.concat(nx.conditions, ",") .. P.hot_bonus()
      if r.hot_sig ~= sig then
        hot_row(r.hot, nx.hot, nx.hot_order)
        cond_row(r.conds, nx.conditions)
        r.hot_sig = sig
      end
    end
    r.tbar.value = left / math.max(1, q.break_len or C.BREAK_SECONDS * 60)
    r.ev_flow.visible = false
    r.au_flow.visible = false
    local bonus = HUD.early_bonus and HUD.early_bonus() or 0
    r.clock.caption = bonus > 0 and { "", "CLOCK IN EARLY  +", U.money(bonus) } or "CLOCK IN"
    r.extra.caption = q.corporate and "[color=255,200,70]Corporate Offer waiting[/color]" or ""
  end
end

-- Set by shift.lua (avoids a require cycle).
HUD.early_bonus = nil

function HUD.reposition(player)
  local el = player.gui.screen[NAME]
  if el and el.valid then place(player, el) end
end

return HUD
