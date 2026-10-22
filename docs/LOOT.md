# Loot and equipment: Milestone 4 design

Milestone 4 in the charter: item definitions and instances, rarity and
affixes, equipment slots, equip and unequip, a comparison UI, stats that
affect combat, a drop table, and save/load. Upgrade and salvage come after
persistence works.

**Gate (charter):** inventory and equipment restore after a restart, and stat
changes are verified in combat.

**Status:** built (all five steps). Numbers are first-pass tuning. Decisions marked
**(owner)** are defaults chosen so work can continue; they are easy to change.

The long-term target is the owner's: Diablo 4-style loot with Torchlight-like
class variety, and offline progress that keeps earning XP, gold and
materials. This milestone builds the core that all of that stands on: one
item model, one stat pipeline, one save file.

## Items

Three layers, as the charter asks: what an item *can* be, what one drop *is*,
and where it *sits*.

| Layer | What | Where it lives |
|---|---|---|
| **ItemBase** | A kind of item: name, slot, icon, model, base stat ranges, minimum item level. Hand-made data. | `game/resources/items/*.tres` |
| **ItemInstance** | One drop: base id, rarity, item level, rolled base stats, rolled affixes, a unique id. Plain data, saved as JSON. | Inventory or equipment |
| **Equipment / Inventory** | Nine slots, and a bag of 30. | `Profile` |

An instance stores its rolled numbers, not just a seed, so later balance
changes to a base never rewrite items players already own.

### Slots

Weapon, helmet, chest, gloves, boots, ring (two slots), amulet, relic. The
Warden's weapon is a two-handed greatsword; one-handed weapons and off-hands
wait for other classes.

### Rarity

| Rarity | Colour | Affixes | Extra | Drop weight |
|---|---|---|---|---|
| Common | `#838488` gray | 0 | | 60 |
| Uncommon | `#529B4D` green | 1 | | 25 |
| Rare | `#259FD2` blue | 2 or 3 | | 11 |
| Epic | `#7B4289` purple | 3 or 4 | base stats +10% | 3.5 |
| Legendary | `#D9A44C` amber | 4 | a unique effect (later) | 0.45 |
| Mythic | `#C8342E` ember red **(owner)** | 5 | a unique effect, always top rolls (later) | 0.05 |

The first five colours come from the concept art
([ART_DIRECTION.md](ART_DIRECTION.md#loot-rarity)); the board has no Mythic
tile. The first build has no unique effects, so Legendary and Mythic items
are just stronger. Their effects get their own design pass.

### Stats

Every stat shown on an item changes combat (charter). The first set:

| Stat | Effect | Where it acts |
|---|---|---|
| Weapon damage | Base damage of the basic attack and Cleave | `MeleeAttack` damage |
| Damage % | All damage dealt | attacks, Brand's burn |
| Attack speed % | Shorter windup and recovery of the basic attack | `MeleeAttack` timing |
| Critical chance % / critical damage % | Chance to deal extra damage | attacks |
| Max health | | `Health.max_health` |
| Armour | Damage taken × 100 / (100 + armour) | `Health` |
| Move speed % | Capped at +30% | `PlayerController` |
| Cooldown reduction % | Capped at 40% | `Ability` cooldowns |
| Health on kill | | `RunController` kill hook |

Bases roll their own stats (a weapon rolls weapon damage, armour rolls armour
and some max health). Affixes come from a per-slot pool with ranges that grow
with item level.

### Item level and drops

- Each enemy has a drop table: a chance to drop anything, and a level. The
  first dungeon is item level 1 to 5: Skeleton 8% chance, Cultist 12%,
  Knight two guaranteed rolls with rarity rolled at 3× weight above Uncommon,
  Lord three guaranteed rolls at least Rare **(owner)**.
- Drops land on the floor with a light beam in the rarity colour and a name
  label, and are picked up by walking over them (no tap needed on a phone).
- A full bag leaves drops on the floor.

## Character stats

`CharacterStats` adds the base character values, the equipped items and
later the skill tree into one set of final numbers. Combat code reads the
final numbers only. The current resources (`player_movement.tres`, attack
data) stay the base values, and equipping never changes them.

## UI

- An **Inventory** button on the HUD (and the pause menu) opens a panel: the
  nine slots around the hero, the bag grid, and Ash/gold.
- Tapping an item shows its card: name in its rarity colour, item level, base
  stats, affixes, and **the difference against the equipped item** in green
  or red, per stat. Buttons: Equip / Unequip, and later Salvage.
- Touch first: cards and buttons at least 88 px, no hover-only information.

## Persistence

- One save file, `user://profile.json`, with a `version` field and a
  migration step per version.
- Writes go to a temporary file first, then replace the old one, so a crash
  mid-write never leaves a broken save. The previous good file is kept as
  `profile.backup.json`.
- Saved: Ash (later gold, XP, level), inventory, equipment, claimed run ids
  (recent ones only).
- Saved after every run's end, and after every equip or unequip.
- A broken or unreadable save loads the backup; if both fail, the game starts
  fresh and keeps the broken file aside for diagnosis. It never deletes the
  player's data on its own.
- Offline-first: this is the local save. Milestone 5 adds the server copy and
  validated claims; `Profile` stays the one place rewards and items enter.

## Gold, salvage and upgrades

**Status:** built (owner's vision: "gold and loot resources"). Numbers are
first-pass tuning, in `game/scripts/items/forge.gd`.

- **Gold** comes from kills: Skeleton Warrior 3, Dark Cultist 5, Fallen
  Knight 25, Ashen Lord 100 (about 170 for a full tier 1 run), more at higher
  crypt tiers. Like Ash, it is counted during the run and paid once at its
  end, kept on a fall.
- **Salvage** (bag items only; take a worn item off first) turns an item
  into gold: `(4 + 2 × item level) × rarity value × (1 + 0.5 × upgrade)`,
  rarity value 1, 2, 4, 8, 16, 32 from Common to Mythic. It asks for a
  second tap (**Confirm**), so a stray tap never destroys an item.
- **Upgrade** raises an item one rank, up to **+5**, for
  `(10 + 3 × item level) × rarity value × next rank` gold and
  `2 × next rank` Ash. Each rank adds 10% to every stat on the item, at least
  1. The rolled numbers are kept as rolled; the rank is applied when stats
  are read, so the bonus can be retuned later. Worn items can be upgraded and
  the hero's numbers follow at once.
- The item card shows the upgrade price and the salvage value; the bag shows
  Ash and gold. Items saved before upgrades load at +0.

## After the loot loop

In order, each with its own small design note:

1. **XP and levels**: built, see [SKILL_TREES.md](SKILL_TREES.md).
2. **Gold, salvage and upgrades**: built, above.
3. **Offline rewards**: built (provisional), see
   [OFFLINE_REWARDS.md](OFFLINE_REWARDS.md). Originally planned as: (Milestone 6): XP, gold and materials for the time
   away, for content already cleared, capped (charter default 8 hours). They
   use the local clock until the server exists, and are marked as provisional
   until Milestone 5 validates them with trusted time.

## Build order

Each step is its own branch and PR, tested, and published to the web preview.

1. **Item model:** ItemBase and affix data, ItemInstance with rolling, rarity
   rules, JSON round trip. No UI.
2. **CharacterStats and combat:** final stats from equipment, used by
   attacks, health, armour, movement and cooldowns. Tests for each stat.
3. **Drops:** drop tables, floor drops with beams and labels, walk-over
   pickup into the bag.
4. **Inventory UI:** slots, bag, item card with comparison, equip and unequip.
5. **Save and load:** the profile file, atomic writes, backup, version; the
   Milestone 4 gate.

## Acceptance checks

1. Rolled affixes are inside their ranges and their count matches the rarity.
2. An item survives a save and load with identical numbers.
3. Every stat shown on an item changes the matching combat number, and
   removing the item restores it.
4. Equip and unequip never lose or duplicate an item.
5. A drop is picked up once; a full bag leaves it on the floor.
6. Restarting the game restores the bag, the equipment and the Ash.
7. A corrupt save does not crash the game and does not delete data.
