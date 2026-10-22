class_name Rarity
extends RefCounted
## The six rarities (charter), their colours (docs/ART_DIRECTION.md, Mythic
## chosen in docs/LOOT.md), affix counts and drop weights.

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const COLORS := [
	Color("#838488"), Color("#529B4D"), Color("#259FD2"),
	Color("#7B4289"), Color("#D9A44C"), Color("#C8342E"),
]
## [fewest, most] affixes.
const AFFIX_COUNTS := [[0, 0], [1, 1], [2, 3], [3, 4], [4, 4], [5, 5]]
## Relative chance of each tier for a drop.
const WEIGHTS := [60.0, 25.0, 11.0, 3.5, 0.45, 0.05]
## Base stats are multiplied by this.
const BASE_BONUS := [1.0, 1.0, 1.0, 1.1, 1.15, 1.2]


static func name_of(tier: int) -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]


static func color_of(tier: int) -> Color:
	return COLORS[clampi(tier, 0, COLORS.size() - 1)]


## A random tier, at least `minimum`. Tiers above Uncommon are `boost` times
## as likely (elites and bosses drop better items).
static func roll(rng: RandomNumberGenerator, minimum: int = Tier.COMMON, boost: float = 1.0) -> int:
	var weights := PackedFloat32Array()
	for tier in WEIGHTS.size():
		var weight: float = WEIGHTS[tier] if tier >= minimum else 0.0
		if tier > Tier.UNCOMMON:
			weight *= boost
		weights.append(weight)
	return rng.rand_weighted(weights)
