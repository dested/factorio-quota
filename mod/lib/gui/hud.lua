-- The HUD: a compact fixed-size panel, bottom-right by default (per-player
-- setting quota-hud-position). Rebuilt when the phase changes, refreshed twice
-- a second. Every row has a fixed height so the frame's size is known and it
-- can be pinned to any corner.

local U = require("lib.util")
local P = require("lib.perks")
local K = require("lib.conditions")
local E = require("lib.events")
local AU = require("lib.auditor")
local H = require("lib.hazards")
local R = require("lib.rules")
local G = require("lib.gui.common")

local HUD = {}

local NAME = "quota_hud"
local WIDTH = 330
local HEIGHT = 178        -- shift and break layout
local HEIGHT_SHORT = 84   -- retired: title row and footer only
local MARGIN = 10

local function position(player)
  local ok, value = pcall(function() return player.mod_settings["quota-hud-position"].value end)
  return ok and value or "bottom-right"
end

local function place(player, frame, height)
  local res = player.display_resolution
  local scale = player.display_scale
  local w, h, m = WIDTH * scale, height * scale, MARGIN * scale
  local where = position(player)
  local x, y
  if where == "top-center" then
    x, y = (res.width - w) / 2, m
  elseif where == "top-left" then
    x, y = m, m
  elseif where == "bottom-left" then
    x, y = m, res.height - h - m
  else
    x, y = res.width - w - m, res.height - h - m
  end
  frame.location = { x = math.floor(x), y = math.floor(y) }
end

function HUD.destroy(player)
  G.destroy(player, NAME)
  G.ui(player).hud = nil
end

local function shift_title(q)
  if q.phase == "break" then return q.briefing and "BRIEFING" or "ON BREAK" end
  if q.phase == "retired" then return "RETIRED" end
  local n = q.shift or 0
  if q.endless then return "SHIFT " .. n .. " (ENDLESS)" end
  if q.cond_active and q.cond_active.audit then return "SHIFT " .. n .. ": AUDIT" end
  return "SHIFT " .. n .. " / " .. R.final()
end

local function hot_row(parent, hot, order)
  parent.clear()
  if not order or #order == 0 then
    G.label(parent, "No hot items", "label", { color = { 0.6, 0.6, 0.6 } })
    return
  end
  for _, name in ipairs(order) do
    local m = hot[name]
    if m then
      local f = parent.add({ type = "flow", direction = "horizontal" })
      f.style.vertical_align = "center"
      f.style.horizontal_spacing = 1
      m = m + P.hot_bonus()
      G.item_icon(f, name, 28)
      G.label(f, U.mult(m), "bold_label", {
        color = { 1, 0.6, 0.15 }, tooltip = { "", "[item=", name, "] sells for ", U.mult(m), " this shift" },
      })
    end
  end
end

local function cond_row(parent, ids)
  parent.clear()
  for _, id in ipairs(ids or {}) do
    local d = K.BY_ID[id]
    if d then
      local tip = { "", "[font=default-bold]", d.name, "[/font]\n", d.desc }
      G.icon(parent, d.sprite, 28, tip, nil, d.good and "slot_button" or "red_slot_button")
    end
  end
end

local function row(parent, height)
  local f = parent.add({ type = "flow", direction = "horizontal" })
  f.style.vertical_align = "center"
  f.style.height = height
  f.style.horizontally_stretchable = true
  return f
end

function HUD.build(player)
  local q = storage.q
  HUD.destroy(player)
  if not (q.phase == "shift" or q.phase == "break" or q.phase == "retired") then return end
  local s = G.ui(player)
  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical", style = "quota_hud_frame" })
  local height = q.phase == "retired" and HEIGHT_SHORT or HEIGHT
  frame.style.height = height
  place(player, frame, height)
  local refs = { frame = frame, height = height }
  local body = frame.add({ type = "flow", direction = "vertical" })
  body.style.vertical_spacing = 4

  local top = row(body, 34)
  refs.title = G.label(top, shift_title(q), "bold_label", { color = { 1, 0.78, 0.25 } })
  refs.title.style.width = 112
  G.pusher(top)
  refs.timer = G.label(top, "", "quota_hud_timer")
  G.pusher(top)
  refs.wallet = G.label(top, "", "quota_gold_label", { align = "right" })
  refs.wallet.style.width = 96
  refs.wallet.tooltip = "Your wallet. Spend it in the Catalog (J)."

  if q.phase ~= "retired" then
    refs.bar = body.add({ type = "progressbar", style = "quota_hud_bar", value = 0 })
    refs.tbar = body.add({ type = "progressbar", style = "quota_thin_bar", value = 1 })

    local info = row(body, 30)
    refs.hot = info.add({ type = "flow", direction = "horizontal" })
    refs.hot.style.vertical_align = "center"
    refs.hot.style.horizontal_spacing = 4
    G.pusher(info)
    refs.conds = info.add({ type = "flow", direction = "horizontal" })
    refs.conds.style.horizontal_spacing = 2

    -- One status line: the auditor, else the live event, else a hint.
    local st = row(body, 22)
    refs.st_icon = st.add({ type = "sprite-button", style = "transparent_slot", sprite = "utility/questionmark" })
    refs.st_icon.style.size = 20
    refs.st_label = st.add({ type = "label", caption = "", style = "label" })
    refs.st_label.style.maximal_width = 220
    G.pusher(st)
    refs.st_bar = st.add({ type = "progressbar", style = "quota_thin_bar", value = 1 })
    refs.st_bar.style.horizontally_stretchable = false
    refs.st_bar.style.width = 60
  end

  local foot = row(body, 28)
  local cat_caption = (q.phase == "break" and not q.briefing) and "Break Room" or "Catalog"
  G.button(foot, cat_caption, "toggle_catalog", nil, "quota_hud_button",
    { tooltip = q.phase == "shift" and "Catalog (J): Tech, Supplies and Land, with a 25% rush fee during shifts." or "Catalog (J)" })
  refs.warn = G.label(foot, "", "semibold_label")
  refs.warn.style.left_margin = 6
  G.pusher(foot)
  if q.phase == "break" then
    refs.clock = G.button(foot, "CLOCK IN", "clock_in", nil, "quota_hud_confirm")
  elseif q.phase == "retired" then
    G.button(foot, "New run", "reapply", nil, "quota_hud_button")
  elseif q.phase == "shift" then
    refs.clockout = G.button(foot, "CLOCK OUT", "clock_out", nil, "quota_hud_confirm",
      { tooltip = "Quota met: end the shift now and get paid for the time left. You stop selling for the rest of the shift. Click twice." })
    refs.clockout.visible = false
  end
  s.hud = refs
  HUD.update(player)
end

local function set_status(r, sprite, text, color, frac)
  r.st_icon.visible = sprite ~= nil
  if sprite then
    r.st_icon.sprite = G.sprite(sprite)
    local item = sprite:match("^item/(.+)$")
    r.st_icon.elem_tooltip = item and G.elem_for(item) or nil
  end
  r.st_label.caption = text or ""
  r.st_label.style.font_color = color or { 0.75, 0.75, 0.75 }
  r.st_bar.visible = frac ~= nil
  if frac then r.st_bar.value = math.max(0, math.min(1, frac)) end
end

function HUD.update(player)
  local q = storage.q
  local s = G.ui(player)
  local r = s.hud
  if not (r and r.frame and r.frame.valid) then return end
  r.wallet.caption = U.money(q.wallet)
  r.title.caption = shift_title(q)
  if q.phase == "retired" then
    r.timer.caption = ""
    r.warn.caption = ""
    return
  end
  r.warn.caption = { "", "[img=virtual-signal/signal-white-flag] ", q.warnings_left, "/", R.warnings() }
  r.warn.tooltip = "Written warnings left. Miss a quota with none left and you are fired."
  r.warn.style.font_color = q.warnings_left == 0 and { 1, 0.45, 0.4 } or { 0.8, 0.8, 0.8 }

  if q.phase == "shift" then
    local left = math.max(0, q.shift_end - game.tick)
    r.timer.caption = U.time(left)
    r.timer.style.font_color = left < 30 * 60 and { 1, 0.35, 0.3 } or { 1, 1, 1 }
    local frac = q.quota > 0 and q.shipped / q.quota or 0
    r.bar.value = math.min(1, frac)
    if q.quota_met then
      r.bar.caption = { "", "MET  ", U.money(q.shipped), " / ", U.money(q.quota) }
      r.bar.style.color = { 0.35, 0.95, 0.4 }
    else
      r.bar.caption = { "", U.money(q.shipped), " / ", U.money(q.quota), "  (", U.pct(frac), ")" }
      r.bar.style.color = { 1, 0.75, 0.1 }
    end
    r.tbar.value = q.shift_len > 0 and left / q.shift_len or 0
    if r.clockout and r.clockout.valid then
      local bonus = HUD.clock_out_bonus and HUD.clock_out_bonus() or 0
      r.clockout.visible = bonus > 0
      local armed = s.clockout_armed and game.tick - s.clockout_armed < 5 * 60
      if not armed then s.clockout_armed = nil end
      r.clockout.caption = armed and { "", "SURE? +", U.money(bonus) } or { "", "CLOCK OUT +", U.money(bonus) }
    end
    local sig = q.hot_sig .. ":" .. P.hot_bonus()
    if r.hot_sig ~= sig then
      hot_row(r.hot, q.hot, q.hot_order)
      cond_row(r.conds, q.conditions)
      r.hot_sig = sig
    end

    local st, wait = AU.status()
    local text, eleft, elen = E.describe()
    local g = H.gremlin_count()
    if st == "incoming" then
      set_status(r, "entity/behemoth-biter", { "", "THE AUDITOR lands in ", U.time(wait) }, { 1, 0.4, 0.3 }, nil)
    elseif st == "active" then
      set_status(r, "entity/behemoth-biter", "THE AUDITOR is on site", { 1, 0.4, 0.3 }, AU.health() or 0)
    elseif text then
      local a = q.ev.active
      local sprite = (a.item and ("item/" .. a.item)) or (E.BY_ID[a.id] and E.BY_ID[a.id].sprite)
      set_status(r, sprite, text, { 1, 1, 1 }, elen and elen > 0 and eleft / elen or 0)
    elseif g > 0 then
      set_status(r, "entity/small-biter", "Gremlins loose: " .. g, { 0.5, 1, 0.4 }, nil)
    elseif P.has("workaholic") and (q.perk_state.workaholic or 0) > 0 then
      set_status(r, "virtual-signal/signal-clock", "Workaholic +" .. (6 * q.perk_state.workaholic) .. "%", nil, nil)
    else
      set_status(r, nil, "", nil, nil)
    end
  elseif q.phase == "break" then
    local left = math.max(0, q.break_end - game.tick)
    r.timer.caption = U.time(left)
    r.timer.style.font_color = left < 15 * 60 and { 1, 0.6, 0.2 } or { 0.75, 0.85, 1 }
    local nx = q.next
    if nx then
      r.bar.value = 0
      r.bar.caption = { "", "NEXT ", nx.n, ":  ", U.money(nx.quota), "  in ", U.time(nx.len * 60) }
      r.bar.style.color = { 1, 0.75, 0.1 }
      local sig = "next" .. nx.n .. table.concat(nx.hot_order, ",") .. table.concat(nx.conditions, ",") .. P.hot_bonus()
      if r.hot_sig ~= sig then
        hot_row(r.hot, nx.hot, nx.hot_order)
        cond_row(r.conds, nx.conditions)
        r.hot_sig = sig
      end
    end
    r.tbar.value = left / math.max(1, q.break_len or 1)
    local bonus = HUD.early_bonus and HUD.early_bonus() or 0
    r.clock.caption = bonus > 0 and { "", "CLOCK IN +", U.money(bonus) } or "CLOCK IN"
    if q.corporate then
      set_status(r, "virtual-signal/signal-star", "Corporate Offer waiting", { 1, 0.8, 0.3 }, nil)
    elseif q.briefing then
      set_status(r, "virtual-signal/signal-info", "Grab the starter kit pod, then clock in", nil, nil)
    else
      set_status(r, "virtual-signal/signal-info", "Hot items and conditions for next shift", nil, nil)
    end
  end
end

-- Set by shift.lua (avoids a require cycle).
HUD.early_bonus = nil
HUD.clock_out_bonus = nil

function HUD.reposition(player)
  local s = G.ui(player)
  local r = s.hud
  local el = player.gui.screen[NAME]
  if el and el.valid then place(player, el, (r and r.height) or HEIGHT) end
end

return HUD
