-- Sound effects and little celesta jingles, scheduled note by note.

local U = require("lib.util")

local S = {}

-- Celesta is chromatic from F5 = 01. Semitone offsets from F5.
local function note(semis)
  return string.format("quota-celesta-%02d", math.max(1, math.min(36, semis + 1)))
end
-- C6 = F5 + 7.
local C6, E6, F6, G6, C7, E7, G7 = 7, 11, 12, 14, 19, 23, 26

local JINGLES = {
  quota_met = { { 0, note(C6) }, { 6, note(E6) }, { 12, note(G6) }, { 18, note(C7) }, { 18, "quota-crash" } },
  payday = { { 0, "quota-cash" }, { 10, note(G6) }, { 16, note(C7) } },
  buy = { { 0, "quota-cash" } },
  promoted = {
    { 0, note(C6) }, { 8, note(E6) }, { 16, note(G6) }, { 24, note(C7) }, { 24, "quota-crash" },
    { 40, note(G6) }, { 48, note(C7) }, { 56, note(E7) }, { 64, note(G7) }, { 64, "quota-crash" }, { 70, "quota-cash" },
  },
  event_good = { { 0, note(G6) }, { 5, note(C7) } },
  event_bad = { { 0, "quota-buzzer" } },
  whack = { { 0, "quota-kick" }, { 0, "quota-clap" }, { 4, "quota-cowbell" } },
  warn = { { 0, "quota-buzzer" }, { 24, "quota-buzzer" } },
  jackpot = { { 0, "quota-cash" }, { 6, note(C7) }, { 10, note(E7) }, { 14, note(G7) }, { 18, "quota-cash" } },
  land = { { 0, "quota-reverse-cymbal" }, { 50, "quota-crash" } },
  tick = { { 0, note(F6) } },
}

function S.play(path, volume)
  U.sound(path, volume)
end

function S.jingle(name)
  local q = storage.q
  local j = JINGLES[name]
  if not (q and j) then return end
  for _, n in ipairs(j) do
    q.notes[#q.notes + 1] = { at = game.tick + n[1], path = n[2] }
  end
end

function S.tick()
  local q = storage.q
  if not q or #q.notes == 0 then return end
  local keep = {}
  for _, n in ipairs(q.notes) do
    if game.tick >= n.at then U.sound(n.path) else keep[#keep + 1] = n end
  end
  q.notes = keep
end

return S
