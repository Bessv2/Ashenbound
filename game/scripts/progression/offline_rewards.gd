class_name OfflineRewards
extends RefCounted
## What time away earns (docs/OFFLINE_REWARDS.md): the hero keeps farming the
## highest crypt tier cleared, at a fraction of the active pace, for at most
## eight hours. New tiers, bosses and items still need active play.
##
## Provisional: until the Milestone 5 server gives trusted time, the device
## clock is used, so these rewards are local only and will be validated by
## the server once it exists.

## Longest time away that counts, in seconds (charter: 8 hours).
const CAP_SECONDS := 8 * 3600
## Shorter absences earn nothing (switching apps, a phone call).
const MIN_SECONDS := 5 * 60
## Crypt runs' worth of rewards per hour away. Active play clears a run in
## about six minutes, so this is a twentieth of the active pace.
const RUNS_PER_HOUR := 0.5
## One full tier 1 crypt run: what its kills give.
const RUN_XP := 790
const RUN_GOLD := 170
const RUN_ASH := 76


## The rewards for `seconds` away farming `tier`: {"xp", "gold", "ash"}.
## Nothing below MIN_SECONDS or without a cleared tier; capped at CAP_SECONDS.
static func earned(seconds: int, tier: int) -> Dictionary:
	if tier < 1 or seconds < MIN_SECONDS:
		return {"xp": 0, "gold": 0, "ash": 0}
	var runs := RUNS_PER_HOUR * mini(seconds, CAP_SECONDS) / 3600.0 * Difficulty.new(tier).reward_scale()
	return {"xp": floori(RUN_XP * runs), "gold": floori(RUN_GOLD * runs), "ash": floori(RUN_ASH * runs)}


## "2 h 15 min", "45 min".
static func describe_time(seconds: int) -> String:
	var minutes := seconds / 60
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60]
