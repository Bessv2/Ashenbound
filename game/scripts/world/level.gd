class_name Level
extends Node3D
## The root of a playable level: where the player starts and which
## encounters must be cleared to win the run. Main instances one level per
## run (see main.gd), so levels can be swapped without touching the HUD,
## the player or the run rules.

@export var player_start: Marker3D
## Clearing every one of these wins the run.
@export var encounters: Array[EncounterController] = []
## Fights the hero may skip (a generated dungeon's vaults): their kills count,
## and clearing one lays out a hoard.
@export var optional_encounters: Array[EncounterController] = []
## Shown when the run is won.
@export var victory_title: String = "The hall is cleared"
## Item level of the loot found here.
@export_range(1, 100, 1) var item_level: int = 1
## A colour cast over the level's stone and props (ArtStyle.tint_world): each
## region its own, from the same KayKit pieces.
@export var world_tint: Color = Color.WHITE
