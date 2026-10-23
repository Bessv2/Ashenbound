# Materials, crafting and camps

Step 3 of [GAME_LOOP.md](GAME_LOOP.md): the concept sheet's "Resources &
Crafting" panel, with Idle Pocket Crafter 2's automated gathering as the idle
half. Numbers are first-pass tuning, in `game/scripts/items/crafting.gd`,
`game/scripts/progression/camps.gd` and `Dungeons.INFO`.

## Materials

The sheet's six, each with its own job (charter §7: no currency without a
distinct purpose):

| Material | Comes from | Used for |
|---|---|---|
| Iron Ore | Crypt kills (35%), the Mine, salvaging weapons, helms and chests | Weapons and armour; the Lumber Camp's upgrades |
| Wood | Crypt kills (25%), the Lumber Camp | Weapons; the Mine's and Hunting Lodge's upgrades |
| Leather | Catacomb kills (30%), the Hunting Lodge, salvaging gloves and boots | Armour, gloves, boots; the Herb Garden's upgrades |
| Herbs | Catacomb kills (30%), the Herb Garden | Amulets, relics, enchanting |
| Crystal | Kills (6 to 8%), bosses (3), the Mine (half an hour), salvaging jewellery | Jewellery, relics, enchanting, ascending |
| Soul Shard | Champions (50%), elites (1), bosses (3) | Ascending; relics |

- **Soul shards** come only from fighting champions, elites and bosses. The
  rarest step of the chain needs active play; the camps never make them.
- **Drop chances** rise with the crypt tier (the drop-chance scale). A
  Champion drops two of each material it rolls.
- **In a run**, materials are counted like Ash and gold and paid once at its
  end, kept on a fall and lost on leaving. A toast shows each find, and the
  summary lists them.

## The crafting chain

Upgrade → Enchant → Craft → Legendary, as on the sheet:

- **Upgrade** (already built, [LOOT.md](LOOT.md#gold-salvage-and-upgrades)):
  +1 rank, up to +5, for gold and Ash.
- **Enchant:** reroll one affix into a stat the item does not have, with a
  fresh value at its item level.
  - Tap an affix on the item's card to choose it.
  - Costs `1 + rarity` crystal, 2 herbs and `25 × (1 + rarity)` gold.
- **Craft:** in the Forge, choose a kind of item and craft it at the hero's
  level, Uncommon or better (rarer tiers twice as likely as from a drop).
  - Each kind has its own recipe, for example a weapon is 12 ore, 8 wood,
    1 crystal and 60 gold at level 1.
  - Materials grow 10% and gold 15% per level.
  - A full bag refuses before anything is paid.
- **Legendary (Ascend):** raise an item one rarity, up to Legendary.
  - Its base stats grow by the new rarity's bonus, and it gains affixes up
    to the new rarity's fewest.
  - Costs 1, 2, 4 or 8 soul shards (to Uncommon, Rare, Epic, Legendary),
    plus crystal and gold.
  - Mythic stays a drop only.
- **Salvage** now also gives materials back: ore from weapons, helms and
  chests, leather from gloves and boots, crystal from jewellery and relics,
  more for rarer items.

Every step goes through `Profile`. It checks the whole price first, pays it
once, and never loses or duplicates an item. A worn item's changes reach the
hero's stats at once.

## Gathering camps

The idle half. The camps open when the Ashen Crypt is first cleared, like
offline rewards. Time before that earns nothing.

| Camp | Gathers per hour at level 1 | Its upgrades take |
|---|---|---|
| Mine | 8 Iron Ore, 0.5 Crystal | Wood |
| Lumber Camp | 8 Wood | Iron Ore |
| Hunting Lodge | 5 Leather | Wood |
| Herb Garden | 6 Herbs | Leather |

- **Gathering:** each camp gathers on the device clock, whether the game is
  open or not.
  - It stops when its store holds **8 hours** of work: the charter's
    offline cap, so checking in twice a day is enough.
  - The player collects one camp or all of them.
- **Upgrades:** a camp rises to level 10.
  - Each level adds 40% to the hourly yield.
  - Each upgrade costs `120 × level^1.5` gold plus `12 × level` of another
    camp's material, so the camps feed each other.
  - Upgrading collects the store first, so nothing gathered at the old rate
    is lost or recounted.
- **Clock:** time on a clock turned back counts as nothing.
- **Provisional:** the device clock is not trustworthy. Like offline
  rewards, the camps will be validated by the Milestone 5 server's time.
  They are not exploit-proof before then.

## Screens

- **Forge** (title screen):
  - The materials and gold in the header.
  - The chain drawn as four steps with arrows.
  - A grid of every kind of item; the chosen one's recipe shows each part's
    icon and amount, red when short.
  - A Craft button.
- **Camps** (title screen): a card per camp with its level, its hourly
  yield, what it holds, a bar filling toward the 8-hour cap, Collect, and
  Upgrade with its price. There is also Collect all.
- **Item card** (the bag): Enchant and Ascend under Equip, Upgrade and
  Salvage. The prices are in the card's text.

## Saves

`Profile` save version 4 adds:
- `materials` (id → amount);
- `camps` (id → level and the time its store was last emptied).

Older saves load with no materials. When their crypt was cleared, their
camps start working on load.

## Tests

`game/tests/test_crafting.gd` checks:
- every material and camp has an icon;
- crafting pays exactly once, puts an Uncommon-or-better item of the chosen
  kind in the bag, and refuses a full bag without paying;
- enchanting rerolls only the chosen affix, into a new stat;
- ascending stops at Legendary, grows the base stats, adds affixes, and
  never repeats a stat;
- salvage gives materials back;
- the camps open with the crypt, gather 8 ore an hour, stop at 8 hours,
  ignore a clock turned back, and pay a collection once;
- upgrades collect first, cost the right material, and yield 40% more;
- saves keep materials and camps, and an older save starts its camps;
- kills drop the dungeon's materials; bosses always give shards and
  crystal;
- a run pays its materials once and lists them in the summary;
- the Forge crafts, and Collect all collects, from the title screen.
