# The full game loop

The owner's direction (2026-10-23): build what the concept sheet shows (its
HUD, its menus, crafting, more regions and Demons) into "something of a full
game like idle miner, or Diablo 4 style mechanics". The baseline for how
active play and idle time share the game is **Idle Pocket Crafter 2**
(Ruoto Games, Google Play).

This document maps that baseline onto Ashenbound and records what is built.
It does not change the charter's rule: action comes first, and idle progress
farms content the player has already cleared; it never clears new content.

## What Pocket Crafter 2 does

From its store listing:
- **Gather** ore, wood, herbs and game in biomes, by tapping or idle.
- **Craft** gear for digging, hunting and lumberjacking from what was
  gathered; better gear gathers faster.
- **Automate** mining, wood cutting and hunting, so it gathers without a tap.
- **Collect** pets (passive abilities) and rare artifacts.
- **Achievements** with rewards, and **awards** that boost power for good.
- **Spells** bought with mana gems from a daily mine.
- Monthly **events**, daily and weekly **challenges**.
- **Retire** the hero for a prestige currency that buys permanent upgrades.

## How it maps onto Ashenbound

| Pocket Crafter 2 | Ashenbound | State |
|---|---|---|
| Tap to dig | Active dungeon runs: real-time combat | Built |
| Biomes | Regions with dungeons and level ranges: Ashen Crypt, Forgotten Catacombs, then Ruined Keep, Cursed Forest, Volcanic Depths, Ancient Temple, Ice Wastes | Two built; five planned |
| Ores, wood, herbs, hunting | The sheet's six materials: iron ore, wood, leather, herbs, crystal, soul shard. Dropped in runs and gathered while idle | Planned |
| Craft gear | The sheet's chain: upgrade → enchant → craft → legendary | Upgrade built; the rest planned |
| Automate gathering | Gathering camps (mine, lumber, hunt, forage) that work while the player is away, in regions already cleared; upgraded with gold and materials | Planned |
| Offline income | Offline rewards: the highest tier cleared, half a run an hour, 8-hour cap, device clock (provisional) | Built |
| Achievements and awards | Achievements that grant a lasting bonus | Planned |
| Daily and weekly challenges | Daily challenges: optional, never punishing a missed day (charter §2.6) | Planned |
| Quests | The sheet's Quest/Mission panel: a region's story quest with objectives and rewards | Planned |
| Pets, artifacts, spells, events, retire | Not planned yet. Retire (prestige) would be a large design change; it needs the owner's call | Not planned |

## Order of work

1. **HUD** like the sheet: portrait, health and XP bars, minimap, icon
   buttons, red damage numbers, crescent slashes. Built, see
   [UI.md](UI.md#the-hud).
2. **Menus** like the sheet: character stats, an inventory grid with item
   icons, gold and Ash in the header, dungeon cards with level ranges.
   Built, see [UI.md](UI.md#menus-2026-10-23). The Quest window comes with
   step 5.
3. **Materials, crafting and gathering camps**: the idle loop.
4. **New regions and Demons.**
5. **Quests, achievements and daily challenges.**
