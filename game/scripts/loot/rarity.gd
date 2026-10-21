class_name Rarity
extends RefCounted
## Loot rarity tiers. The colors are the frame colors sampled from the
## concept sheet's loot panel (docs/ART_DIRECTION.md).

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const COLORS: Array[Color] = [
	Color("#838488"), Color("#529b4d"), Color("#259fd2"), Color("#7b4289"), Color("#d9a44c"),
]


static func name_of(tier: Tier) -> String:
	return NAMES[tier]


static func color_of(tier: Tier) -> Color:
	return COLORS[tier]


## A lighter version of the tier's color for text, which stays readable on the
## dark HUD and floor (the sampled epic purple is too dark on its own).
static func text_color_of(tier: Tier) -> Color:
	return COLORS[tier].lightened(0.35)
