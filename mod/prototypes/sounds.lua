-- Sound prototypes. Three are synthesised (tools/make-sounds.ts); the rest are
-- vanilla programmable-speaker samples given names we can play from script.

local SPEAKER = "__base__/sound/programmable-speaker/"

local function snd(name, filename, volume)
  return {
    type = "sound",
    name = name,
    filename = filename,
    volume = volume or 0.7,
    category = "game-effect",
    audible_distance_modifier = 4,
  }
end

local list = {
  snd("quota-whistle", "__quota__/sound/whistle.wav", 0.75),
  snd("quota-cash", "__quota__/sound/cash.wav", 0.6),
  snd("quota-trombone", "__quota__/sound/trombone.wav", 0.8),
  snd("quota-siren", SPEAKER .. "siren.ogg", 0.55),
  snd("quota-alarm", SPEAKER .. "alarm-1.ogg", 0.55),
  snd("quota-buzzer", SPEAKER .. "buzzer-1.ogg", 0.6),
  snd("quota-ring", SPEAKER .. "ring.ogg", 0.6),
  snd("quota-kick", SPEAKER .. "kit-01.ogg", 0.9),
  snd("quota-snare", SPEAKER .. "kit-03.ogg", 0.8),
  snd("quota-crash", SPEAKER .. "kit-12.ogg", 0.6),
  snd("quota-clap", SPEAKER .. "kit-14.ogg", 0.8),
  snd("quota-cowbell", SPEAKER .. "kit-16.ogg", 0.8),
  snd("quota-reverse-cymbal", SPEAKER .. "kit-13.ogg", 0.6),
}

-- Celesta, chromatic from F5 (01) upwards. Jingles are scheduled note by note.
for i = 1, 36 do
  local n = string.format("%02d", i)
  list[#list + 1] = snd("quota-celesta-" .. n, SPEAKER .. "celesta-" .. n .. ".ogg", 0.55)
end

data:extend(list)
