-- Big display fonts. Vanilla tops out around 20px, which is too small for a
-- shift timer you read from the corner of your eye while building.
data:extend({
  { type = "font", name = "quota-huge", from = "default-bold", size = 40, border = true, border_color = { 0, 0, 0 } },
  { type = "font", name = "quota-title", from = "default-bold", size = 30, border = true, border_color = { 0, 0, 0 } },
  { type = "font", name = "quota-big", from = "default-bold", size = 24 },
  { type = "font", name = "quota-timer", from = "default-bold", size = 26, border = true, border_color = { 0, 0, 0 } },
  { type = "font", name = "quota-mid", from = "default-bold", size = 18 },
  { type = "font", name = "quota-small-bold", from = "default-bold", size = 13 },
})
