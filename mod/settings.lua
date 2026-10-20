-- Mod settings. Map settings (runtime-global) are the run's rules: set defaults from the main
-- menu, pick them for real in Run Setup, change them mid-run (switches and knobs apply from the
-- next shift). The HUD position is per player.

local settings_list = {
  { type = "string-setting", name = "quota-mode", setting_type = "runtime-global", order = "a-a",
    default_value = "simple", allowed_values = { "simple", "complex" } },
  { type = "string-setting", name = "quota-difficulty", setting_type = "runtime-global", order = "a-b",
    default_value = "associate", allowed_values = { "intern", "associate", "crunch" } },
  { type = "string-setting", name = "quota-shifts", setting_type = "runtime-global", order = "a-c",
    default_value = "auto", allowed_values = { "auto", "5", "6", "8", "10", "12", "15" } },
  { type = "string-setting", name = "quota-warnings", setting_type = "runtime-global", order = "a-d",
    default_value = "auto", allowed_values = { "auto", "0", "1", "2", "3", "5" } },
  { type = "double-setting", name = "quota-quota-scale", setting_type = "runtime-global", order = "b-a",
    default_value = 1, minimum_value = 0.25, maximum_value = 4 },
  { type = "double-setting", name = "quota-shift-length", setting_type = "runtime-global", order = "b-b",
    default_value = 1, minimum_value = 0.5, maximum_value = 3 },
  { type = "int-setting", name = "quota-break-length", setting_type = "runtime-global", order = "b-c",
    default_value = 90, minimum_value = 15, maximum_value = 600 },
  { type = "string-setting", name = "quota-hud-position", setting_type = "runtime-per-user", order = "z-a",
    default_value = "bottom-right", allowed_values = { "bottom-right", "bottom-left", "top-left", "top-center" } },
}

-- One switch per threat, condition and event (keys match lib/rules.lua R.SWITCHES).
local switches = {
  "meteors", "gremlins", "quakes", "strike", "raids", "nests", "audit",
  "eclipse", "hotpotato", "picky", "volatile", "rush", "mandate", "lowgrav", "golden",
  "flash", "bounty", "supply", "rally", "crash",
}
for i, key in ipairs(switches) do
  settings_list[#settings_list + 1] = {
    type = "bool-setting", name = "quota-s-" .. key, setting_type = "runtime-global",
    order = string.format("c-%02d", i), default_value = true,
  }
end

data:extend(settings_list)
