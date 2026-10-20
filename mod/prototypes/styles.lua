-- GUI styles. Everything inherits from vanilla styles so the screens look like
-- Factorio, just louder.

local styles = data.raw["gui-style"].default

local GOLD = { 255, 200, 70 }
local CREAM = { 255, 230, 192 }

styles.quota_timer_label = { type = "label_style", parent = "label", font = "quota-huge", font_color = { 1, 1, 1 } }
styles.quota_title_label = { type = "label_style", parent = "label", font = "quota-title", font_color = GOLD }
styles.quota_big_label = { type = "label_style", parent = "label", font = "quota-big", font_color = CREAM }
styles.quota_mid_label = { type = "label_style", parent = "label", font = "quota-mid", font_color = CREAM }
styles.quota_gold_label = { type = "label_style", parent = "label", font = "default-large-bold", font_color = GOLD }

styles.quota_wrap_label = {
  type = "label_style",
  parent = "label",
  single_line = false,
  horizontally_stretchable = "on",
}

styles.quota_card_desc = {
  type = "label_style",
  parent = "label",
  single_line = false,
  font = "default",
  font_color = { 0.9, 0.9, 0.9 },
  maximal_width = 180,
  horizontally_stretchable = "on",
}

styles.quota_card_name = {
  type = "label_style",
  parent = "label",
  single_line = false,
  font = "default-large-bold",
  font_color = CREAM,
  maximal_width = 180,
}

styles.quota_quota_bar = {
  type = "progressbar_style",
  parent = "progressbar",
  bar_width = 24,
  height = 24,
  horizontally_stretchable = "on",
  color = { 1, 0.75, 0.1 },
  font = "default-large-bold",
  font_color = { 1, 1, 1 },
  embed_text_in_bar = true,
}

styles.quota_time_bar = {
  type = "progressbar_style",
  parent = "progressbar",
  bar_width = 6,
  height = 6,
  horizontally_stretchable = "on",
  color = { 0.55, 0.75, 1 },
}

styles.quota_card_frame = {
  type = "frame_style",
  parent = "bonus_card_frame",
  width = 200,
  height = 270,
  padding = 8,
  vertical_flow_style = { type = "vertical_flow_style", vertical_spacing = 4 },
}

styles.quota_small_card_frame = {
  type = "frame_style",
  parent = "bonus_card_frame",
  width = 214,
  minimal_height = 92,
  padding = 6,
  vertical_flow_style = { type = "vertical_flow_style", vertical_spacing = 2 },
}

styles.quota_row_frame = {
  type = "frame_style",
  parent = "bonus_card_frame",
  minimal_width = 0,
  minimal_height = 0,
  horizontally_stretchable = "on",
  padding = 6,
}

styles.quota_buy_button = {
  type = "button_style",
  parent = "green_button",
  horizontally_stretchable = "on",
  font = "default-bold",
}

styles.quota_wide_button = {
  type = "button_style",
  parent = "button",
  horizontally_stretchable = "on",
  font = "default-bold",
}

styles.quota_clockin_button = {
  type = "button_style",
  parent = "confirm_button",
  minimal_width = 220,
  height = 40,
  font = "quota-mid",
}

styles.quota_plot_button = {
  type = "button_style",
  parent = "slot_button",
  size = 52,
}

styles.quota_plot_buy = {
  type = "button_style",
  parent = "slot_sized_button_green",
  size = 52,
}

styles.quota_plot_owned = {
  type = "button_style",
  parent = "yellow_slot_button",
  size = 52,
}

styles.quota_plot_selected = {
  type = "button_style",
  parent = "red_slot_button",
  size = 52,
}

styles.quota_hud_frame = {
  type = "frame_style",
  parent = "frame",
  width = 330,
  padding = 6,
}

styles.quota_hud_timer = { type = "label_style", parent = "label", font = "quota-timer", font_color = { 1, 1, 1 } }

styles.quota_hud_bar = {
  type = "progressbar_style",
  parent = "progressbar",
  bar_width = 20,
  height = 20,
  horizontally_stretchable = "on",
  color = { 1, 0.75, 0.1 },
  font = "default-bold",
  font_color = { 1, 1, 1 },
  embed_text_in_bar = true,
}

styles.quota_thin_bar = {
  type = "progressbar_style",
  parent = "progressbar",
  bar_width = 4,
  height = 4,
  horizontally_stretchable = "on",
  color = { 0.55, 0.75, 1 },
}

styles.quota_hud_button = {
  type = "button_style",
  parent = "button",
  height = 28,
  minimal_width = 0,
  left_padding = 8,
  right_padding = 8,
  font = "default-bold",
}

styles.quota_hud_confirm = {
  type = "button_style",
  parent = "confirm_button",
  height = 28,
  minimal_width = 0,
  left_padding = 8,
  right_padding = 8,
  font = "default-bold",
}

styles.quota_mode_card = {
  type = "frame_style",
  parent = "bonus_card_frame",
  width = 200,
  minimal_height = 118,
  padding = 8,
  vertical_flow_style = { type = "vertical_flow_style", vertical_spacing = 2 },
}

styles.quota_section_frame = {
  type = "frame_style",
  parent = "inside_shallow_frame_with_padding",
  horizontally_stretchable = "on",
  vertical_flow_style = { type = "vertical_flow_style", vertical_spacing = 4 },
}
