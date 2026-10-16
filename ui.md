# QUOTA — UI / Visual Language

> How QUOTA looks and feels in game. Follow it for any GUI, rendering or copy change.

## North star

**Corporate dread, arcade readability.** The Company is a cheerful, ruthless employer; the UI is
its paperwork. Everything sits on vanilla Factorio frames so it feels native, with big gold numbers
for the things you glance at mid-build (timer, quota, wallet) and terse, dry copy.

1. **Glanceable first.** The HUD answers "how long, how much, what's hot" without reading a word.
2. **Vanilla chrome, custom type.** Vanilla frame/button styles; our own display fonts for numbers.
3. **Color means one thing.** Gold = money, green = good/yours/for sale, red-orange = danger, blue = time.
4. **The Company voice.** Short, deadpan, slightly menacing ("Please leave your badge at the terminal.").

## Tokens

### Color (Lua RGB 0–1)

| Token | Value | Use |
| --- | --- | --- |
| Gold | `{1, 0.78, 0.2}` (`U.COLORS.gold`), labels `{1, 0.85, 0.35}` | Money, wallet, titles, HOT label |
| Cream | `{1, 0.9, 0.75}` | Big/mid label default, chat |
| Green | `{0.4, 1, 0.45}`, bar `{0.35, 0.95, 0.4}` | Quota met, good conditions, bonuses |
| Red-orange | `{1, 0.35, 0.3}` / `{1, 0.55, 0.45}` | Bad conditions, warnings at 0, last 30 s, raids |
| Orange | `{1, 0.6, 0.15}` | Hot multipliers (`x2.5`), crater text |
| Blue | `{0.55, 0.75, 1}` / `{0.75, 0.85, 1}` | Time bars, break timer, pod labels |
| Grey | `{0.7, 0.7, 0.7}` | Secondary copy, hints, legends |
| Rarity | `C.RARITY[r].color` | Contract rarity names |

### Type (`prototypes/fonts.lua`, all from default-bold)

| Font | Size | Use |
| --- | --- | --- |
| `quota-huge` (bordered) | 40 | Shift timer (`quota_timer_label`) |
| `quota-title` (bordered) | 30 | Screen titles, quota amount (`quota_title_label`) |
| `quota-big` | 24 | Wallet, report headline (`quota_big_label`) |
| `quota-mid` | 18 | Section titles, clock-in button (`quota_mid_label`) |
| vanilla `default-large-bold` | | Prices (`quota_gold_label`), card names |

## Components

| Component | Where | Notes |
| --- | --- | --- |
| HUD | `gui/hud.lua` | Title ON BREAK / BRIEFING (pre-shift 1, footer says Catalog not Break Room). 600 px `quota_hud_frame`, top centre. Rows: title/timer/wallet+warnings, quota bar (`quota_quota_bar`, 24 px, caption inside), time bar (`quota_time_bar`, 6 px), HOT + conditions, event row, auditor row, footer (Catalog/Break Room button, notes, CLOCK IN EARLY) |
| Catalog / Break Room | `gui/catalog.lua` | `G.window` with wallet header; break adds a 320 px left panel (report, next shift, timer + `quota_clockin_button`). Right side 860×600 tabbed pane |
| Contract card | `contract_card` | `quota_card_frame` 200×270, 52 px icon, name, rarity, desc, price, `quota_buy_button` |
| Owned contract | `owned_card` | `quota_small_card_frame` 162 wide, Sell button |
| Supply card | `tab_supplies` | 3-column grid, contents as numbered item icons, price in gold or red when unaffordable (`G.price_color`) |
| Land grid | `tab_land` | 9×9 of 52 px buttons: `quota_plot_buy` green (for sale), `quota_plot_owned` yellow, `quota_plot_selected` red, plain slot otherwise; legend under the grid |
| Market table | `tab_market` | `bordered_table`, item column 400 px |
| End screen | `gui/screens.lua` | Title in `quota-title` gold or red, two-column stat table, primary action `confirm_button` |
| World text | `rendering.draw_text` | Terminal label + state (OPEN green / CLOSED grey / UNDER AUDIT / TERMINATED red), FOR SALE signs, pod labels, flying "+$" |
| World markers | `rendering.draw_circle` | Red rings for meteor impact (solid ring + blinking fill), quake damage, auditor freeze radius; cyan ring for pod landing |

## Patterns

- Every clickable element carries `tags = { qa = "<action>", … }`; `control.lua` routes on it.
- `opening` refresh pops windows (break → Break Room on Contracts, Corporate Offer modal on top);
  later refreshes rebuild in place so the player's tab and scroll survive.
- Prices the player can't afford render red (`G.price_color`).
- Mid-shift catalog shows the rush-fee note in the header; Black Market shows its discount there.

## Don'ts

- No eyebrows/kicker labels above headings; no trailing periods in titles or headings.
- No `utility/*_modifier_icon` sprites for bonuses (they're the red "+" placeholder); use `technology/*`.
- Don't let a fixed-width child sit in a stretchable flow without `horizontally_stretchable = false`
  on the child: it renders left-aligned in an oversized slot.
- Don't add rows to the break left panel without shrinking its scroll pane (`RIGHT_H - 84/124`).
- Don't put world labels where they can overlap the terminal sprite (pods land ≥ 9 tiles from a terminal).
- Night is not ambience: the surface is always day; only the Eclipse condition is dark.
