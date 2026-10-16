# QUOTA: design

- **Date:** 2026-10-15
- **Status:** done
- **Type:** plan
- **What:** the game design for QUOTA, a ~1 hour single-player Factorio roguelite, and the build plan

## Pitch

Lethal Company's quota loop, Balatro's shop, Factorio's factory. You are a contractor
for The Company on a small island in an endless ocean. Every **shift** has a timer and a
**quota** in credits; you hit it by feeding products into a **Shipping Terminal**. Between
shifts you get a short **break** and a shop: **Contracts** (jokers that bend the rules),
**R&D** (buy technologies outright), **Supplies** (drop-pod crates of machines), and
**Land** (buy the next plot of island, which rises out of the sea). Each shift after the
first carries a **Condition** (gremlins, earthquakes, meteor storms, union strikes,
eclipse, raids...) and random **events** (flash sales, bounties, supply drops). Miss a
quota and you get a written warning; miss again and you're fired (sad trombone). Survive
8 shifts and you face **The Audit**: a boss walks to your terminal while you chase the
last quota.

Target: ~60 minutes. 8 shifts (50 min of shifts, 75 s breaks). Endless mode after.

## Why this is fun for a veteran

- No bootstrap grind: a starter kit drops from orbit at clock-in; tech is bought.
- Every run is different: plot layout, offered contracts, conditions, hot items.
- Constant decisions: cash on contracts vs land vs machines vs tech.
- Conditions force building differently (night, strikes, rotations, picky clients).
- A market that floods pushes a diverse factory instead of one gear line.

## Economy

- **Item value** computed at init from recipes: raws seeded (ore 1, crude 0.05 per unit),
  crafted = (sum of inputs + recipe seconds x 0.4) x 1.2, split across products.
  Placeable items (machinery) sell at 10% scrap value, so starter kit and shop crates
  can't be flipped for profit.
- **Price** = value x hot multiplier x flood x global (contracts, conditions, events).
- **Flood:** per item, `1 / (1 + sold_base_value / (1.25 x quota))`, decays 75% between shifts.
- **Hot items:** 3 per shift (4 from shift 5), x2 to x3, drawn from products the player can
  currently craft. Shown in the break preview and on the HUD.
- **Wallet:** everything shipped is credited live; quota progress is separate from spending.
- **Payday:** overtime bonus 20% of the excess; early clock-in bonus per remaining break second.

## Shift table (Associate)

| # | Length | Quota | Conditions |
| --- | --- | --- | --- |
| 1 | 5:00 | 400 | none |
| 2 | 5:00 | 1,100 | 1 mild |
| 3 | 6:00 | 2,400 | 1 |
| 4 | 6:00 | 4,200 | 1 |
| 5 | 6:30 | 6,800 | 1 |
| 6 | 7:00 | 10,500 | 1 |
| 7 | 7:00 | 15,500 | 2 |
| 8 | 8:00 | 22,000 | The Audit + 1 |

Difficulty: Intern (x0.6 quotas, 2 warnings), Associate (x1, 1 warning), Crunch Time
(x1.4, no warnings, nastier conditions earlier). Endless: x1.45 per shift, 2 conditions.

## World

- Custom surface, everything ocean. Plot grid 9x9 of 64x64 plots; HQ plot at the center.
- Owned plots are land with noisy coastlines toward unowned neighbours.
- HQ: terminal pad at the center, small rich iron/copper/coal/stone patches, a lake.
- Neighbouring plots are FOR SALE (in-world signs over the water). Types: Iron Seam,
  Copper Seam, Coal Bed, Quarry, Mixed Ores, Lakeside, Forest, Flatland, Oil Field, Ruins
  (loot crates), Infested (cheap, rich, nests), Bonanza, Uranium Crater.
- Buying a plot raises it from the sea in a wave, then places its resources.

## Shop

- **Contracts** (max 5): 3 offered per break, reroll for cash, sell for half.
  About 24 perks: productivity on recipes, prices, interest, Golden Parachute, Monopoly,
  Golden Gear jackpots, Danger Pay, Meteor Insurance, and more.
- **R&D:** curated tech catalog; buying researches the vanilla tech plus its prerequisites.
  Repeatable upgrades: mining productivity, inserter capacity, turret damage.
- **Supplies:** crates delivered by drop pod (belts, smelting, assemblers, power, oil rig,
  defense, robots, mystery crate, extra terminal).
- **Land:** the plot map.
- Supplies, R&D and Land also open mid-shift through the HUD catalog button, at a 25% rush fee.
- **Corporate Offers** after shifts 3 and 6: Faustian bargains (cash now for higher quotas, etc).

## Conditions

Solar Eclipse, Union Strike, Gremlin Infestation, Seismic Activity, Meteor Shower,
Hostile Takeover (raids), Picky Client, Volatile Market, Low Gravity, Golden Hour,
Rush Order, Overtime Mandate, Hot Potato. Mild ones early, nasty ones later.

## Events (mid-shift, from shift 2)

Flash Sale (an item you already ship, x4 for 60 s), Bounty (ship N of X in 90 s), Supply
Drop, Market Rally, single meteor, single gremlin, raid (shift 4+).

## The Audit (shift 8)

A scaled, tinted behemoth biter walks from the far coast to the nearest terminal. While it
stands within 8 tiles of a terminal, that terminal is frozen. Kill it for a big bonus.

## Build plan

1. Data stage: terminal (container with cargo-hub art), supply pod, meteor projectile,
   auditor unit, sounds, GUI styles, custom input.
2. Control: world/plots, valuation, market, terminals, shift machine, shop, perks,
   conditions, events, hazards, HUD, break room, orientation, end screens, reset.
3. Verify: dump-data, `--create`, benchmark-mode autotest that drives a whole run,
   then a real-client run that screenshots every GUI.
4. Install script, launcher, cliffnotes kit.
