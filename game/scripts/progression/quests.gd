class_name Quests
extends RefCounted
## The goals of docs/QUESTS.md, as data (Profile tracks and pays them):
## - story quests, one per dungeon: clear its fights and defeat its boss, for
##   gold, materials and a guaranteed item;
## - achievements: lifetime milestones, each paid once;
## - daily challenges: three a day from a pool, picked by the date. Optional
##   and never punishing: a missed day costs nothing and nothing chains.
##
## Progress is counted in Profile.stats (lifetime counters, by key below).

## Profile.stats keys.
const KILLS := "kills"
const CHAMPIONS := "champions"
const BOSSES := "bosses"
const RUNS_WON := "runs_won"
const DEEP_RUNS := "deep_runs"
const CRAFTED := "crafted"
const ENCHANTED := "enchanted"
const ASCENDED := "ascended"
const CAMP_COLLECTS := "camp_collects"
const CAMP_UPGRADES := "camp_upgrades"
const SALVAGED := "salvaged"
const POTIONS := "potions"

## Dungeon id → its story quest. Objectives name the dungeon's fights by
## their EncounterController title; the last is the boss's.
const STORY := {
	"crypt": {
		"title": "The Ashen Crypt",
		"line": "The dead of the Marches will not rest. Find out why.",
		"objectives": ["The Ossuary", "The Ruined Chapel", "The Ashen Throne"],
		"texts": ["Clear the Ossuary", "Cleanse the Ruined Chapel", "Defeat the Ashen Lord"],
		"reward": {"gold": 300, "iron_ore": 10, "wood": 6},
		"item_rarity": Rarity.Tier.RARE,
	},
	"catacombs": {
		"title": "Below the Crypt",
		"line": "The Ashen Lord answered to someone older.",
		"objectives": ["The Gallery of Bones", "The Drowned Vault", "The Bone Pit", "The Hollow Throne"],
		"texts": ["Cross the Gallery of Bones", "Drain the Drowned Vault", "Climb out of the Bone Pit", "Defeat the Hollow King"],
		"reward": {"gold": 600, "leather": 10, "herbs": 10, "crystal": 2},
		"item_rarity": Rarity.Tier.RARE,
	},
	"keep": {
		"title": "The Iron Oath",
		"line": "The keep's garrison swore to hold it forever. They meant it.",
		"objectives": ["The Barracks", "The Broken Courtyard", "The Armoury", "The Great Hall"],
		"texts": ["Clear the Barracks", "Take the Broken Courtyard", "Break into the Armoury", "Defeat the Iron Castellan"],
		"reward": {"gold": 1000, "iron_ore": 20, "crystal": 3},
		"item_rarity": Rarity.Tier.EPIC,
	},
	"forest": {
		"title": "Rot at the Roots",
		"line": "Where the Blight touched the forest, the forest touched back.",
		"objectives": ["The Thorn Thicket", "The Drowned Graveyard", "The Witch's Hollow", "The Rotwood Grove"],
		"texts": ["Cut through the Thorn Thicket", "Silence the Drowned Graveyard", "Find the Witch's Hollow", "Defeat the Rotwood Witch"],
		"reward": {"gold": 1400, "herbs": 20, "wood": 15, "soul_shard": 1},
		"item_rarity": Rarity.Tier.EPIC,
	},
	"volcano": {
		"title": "The Burning Gate",
		"line": "Something opened beneath the mountain. Close it.",
		"objectives": ["The Slag Forge", "The Burning Rift", "The Brimstone Pits", "The Molten Throne"],
		"texts": ["Quench the Slag Forge", "Cross the Burning Rift", "Survive the Brimstone Pits", "Defeat the Cinder Tyrant"],
		"reward": {"gold": 1800, "iron_ore": 25, "crystal": 5, "soul_shard": 2},
		"item_rarity": Rarity.Tier.EPIC,
	},
	"temple": {
		"title": "The Lost Sanctum",
		"line": "The temple kept a secret about the bonds. Its oracle still does.",
		"objectives": ["The Sunken Vestibule", "The Colonnade of Oaths", "The Inner Sanctum", "The Sunless Altar"],
		"texts": ["Enter the Sunken Vestibule", "Walk the Colonnade of Oaths", "Open the Inner Sanctum", "Defeat the Sunless Oracle"],
		"reward": {"gold": 2500, "crystal": 8, "herbs": 20, "soul_shard": 2},
		"item_rarity": Rarity.Tier.LEGENDARY,
	},
	"ice": {
		"title": "The Last Bond",
		"line": "At the edge of the world, the oldest bond is frozen in place.",
		"objectives": ["The Frozen Pass", "The Field of the Fallen", "The Rime Barrow", "The Rime Throne"],
		"texts": ["Cross the Frozen Pass", "Walk the Field of the Fallen", "Open the Rime Barrow", "Defeat the Rime King"],
		"reward": {"gold": 3500, "crystal": 10, "leather": 25, "soul_shard": 4},
		"item_rarity": Rarity.Tier.LEGENDARY,
	},
}

## Lifetime milestones: [id, title, stat, goal, reward].
const ACHIEVEMENTS := [
	["slayer_1", "First Blood", KILLS, 50, {"gold": 100}],
	["slayer_2", "Ashwalker", KILLS, 500, {"gold": 500, "crystal": 2}],
	["slayer_3", "Bane of the Dead", KILLS, 2500, {"gold": 2000, "soul_shard": 2}],
	["champions_1", "Champion Hunter", CHAMPIONS, 10, {"ash": 40, "soul_shard": 1}],
	["champions_2", "Kingslayer's Apprentice", CHAMPIONS, 50, {"ash": 150, "soul_shard": 3}],
	["bosses_1", "Crownbreaker", BOSSES, 3, {"gold": 400, "crystal": 3}],
	["bosses_2", "Tyrant's End", BOSSES, 15, {"gold": 1500, "soul_shard": 3}],
	["runs_1", "Survivor", RUNS_WON, 5, {"gold": 300}],
	["deep_1", "Into the Deep", DEEP_RUNS, 5, {"ash": 60, "crystal": 2}],
	["craft_1", "Smith", CRAFTED, 5, {"iron_ore": 20, "wood": 10}],
	["enchant_1", "Spellwright", ENCHANTED, 10, {"crystal": 5, "herbs": 10}],
	["ascend_1", "Legend in the Making", ASCENDED, 4, {"soul_shard": 2, "crystal": 4}],
	["camps_1", "Quartermaster", CAMP_UPGRADES, 8, {"gold": 800}],
	["collect_1", "Steady Hands", CAMP_COLLECTS, 25, {"wood": 20, "leather": 15}],
	["salvage_1", "Scrapper", SALVAGED, 25, {"iron_ore": 25}],
]

## The daily pool: [id, text, stat, goal, reward]. Three are drawn each day.
const DAILY_POOL := [
	["d_kills", "Slay 60 enemies", KILLS, 60, {"ash": 20, "iron_ore": 6}],
	["d_champions", "Defeat 2 Champions", CHAMPIONS, 2, {"ash": 25, "soul_shard": 1}],
	["d_boss", "Defeat a boss", BOSSES, 1, {"gold": 250, "crystal": 2}],
	["d_win", "Win a run", RUNS_WON, 1, {"gold": 200, "herbs": 6}],
	["d_deep", "Win a run at tier 2 or higher", DEEP_RUNS, 1, {"ash": 30, "crystal": 2}],
	["d_craft", "Craft an item", CRAFTED, 1, {"wood": 10, "leather": 6}],
	["d_enchant", "Enchant an item", ENCHANTED, 1, {"crystal": 2, "herbs": 4}],
	["d_collect", "Collect from your camps 3 times", CAMP_COLLECTS, 3, {"gold": 150, "leather": 6}],
	["d_salvage", "Salvage 5 items", SALVAGED, 5, {"iron_ore": 10, "gold": 100}],
	["d_potions", "Drink 3 potions", POTIONS, 3, {"herbs": 8, "gold": 100}],
]
const DAILY_COUNT := 3


## The day number of unix time `now` (device clock, provisional).
static func day_of(now: int) -> int:
	return floori(now / 86400.0)


## The daily challenges of `day`: DAILY_COUNT entries of DAILY_POOL, the same
## for everyone on that day, different from one day to the next.
static func dailies_of(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day) ^ 0x5eed
	var pool := DAILY_POOL.duplicate()
	var picked := []
	while picked.size() < DAILY_COUNT and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## "Slay 500 enemies": what reaching `goal` on `stat` means.
static func describe(stat: String, goal: int) -> String:
	var forms := {
		KILLS: "Slay %d enemies", CHAMPIONS: "Defeat %d Champions", BOSSES: "Defeat %d bosses",
		RUNS_WON: "Win %d runs", DEEP_RUNS: "Win %d runs at tier 2 or higher", CRAFTED: "Craft %d items",
		ENCHANTED: "Enchant %d times", ASCENDED: "Ascend %d items", CAMP_COLLECTS: "Collect from camps %d times",
		CAMP_UPGRADES: "Upgrade camps %d times", SALVAGED: "Salvage %d items", POTIONS: "Drink %d potions",
	}
	return (forms.get(stat, "%s: %%d" % stat) as String) % goal


static func achievement(id: String) -> Array:
	for entry: Array in ACHIEVEMENTS:
		if entry[0] == id:
			return entry
	return []


static func daily(id: String) -> Array:
	for entry: Array in DAILY_POOL:
		if entry[0] == id:
			return entry
	return []
