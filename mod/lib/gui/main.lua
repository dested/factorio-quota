-- Which windows each phase shows, for every player.

local U = require("lib.util")
local G = require("lib.gui.common")
local HUD = require("lib.gui.hud")
local CAT = require("lib.gui.catalog")
local SC = require("lib.gui.screens")
local MP = require("lib.gui.market_panel")
local HB = require("lib.gui.handbook")

local GM = {}

-- Rebuild a player's GUI for the current phase. `opening` = the phase just
-- started, so pop the windows that phase opens.
function GM.refresh(player, opening)
  local q = storage.q
  local phase = q.phase
  if phase == "orientation" then
    HUD.destroy(player)
    MP.destroy(player)
    CAT.close(player)
    SC.close_end(player)
    SC.close_corporate(player)
    SC.orientation(player)
    return
  end
  SC.close_orientation(player)
  -- A Handbook opened from Run Setup closes when the run starts.
  if opening and q.briefing then HB.close(player) end
  if phase == "shift" then
    SC.close_end(player)
    SC.close_corporate(player)
    if opening then CAT.close(player) else CAT.rebuild(player) end
    HUD.build(player)
    MP.build(player)
  elseif phase == "break" then
    SC.close_end(player)
    HUD.build(player)
    MP.build(player)
    if q.briefing then
      -- Before shift 1 the island is the point: no window in the way.
      if not opening then CAT.rebuild(player) end
    elseif opening then
      -- Every break opens on the fresh contract offers.
      G.ui(player).tab = 1
      CAT.open(player)
      if q.corporate then SC.corporate(player) end
    else
      CAT.rebuild(player)
    end
  elseif phase == "fired" or phase == "promoted" then
    HUD.destroy(player)
    MP.destroy(player)
    HB.close(player)
    CAT.close(player)
    SC.close_corporate(player)
    SC.end_screen(player)
  elseif phase == "retired" then
    SC.close_end(player)
    HUD.build(player)
    MP.build(player)
    CAT.rebuild(player)
  end
end

function GM.refresh_all(opening)
  for _, p in pairs(U.players()) do GM.refresh(p, opening) end
end

function GM.update_all()
  for _, p in pairs(U.players()) do
    HUD.update(p)
    MP.update(p)
    CAT.update(p)
  end
end

function GM.destroy_all(player)
  HUD.destroy(player)
  MP.destroy(player)
  HB.close(player)
  CAT.close(player)
  SC.close_end(player)
  SC.close_corporate(player)
  SC.close_orientation(player)
end

return GM
