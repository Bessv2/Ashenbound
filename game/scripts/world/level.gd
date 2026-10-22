class_name Level
extends Node3D
## The root of a playable level: where the player starts and which
## encounters must be cleared to win the run. Main instances one level per
## run (see main.gd), so levels can be swapped without touching the HUD,
## the player or the run rules.

@export var player_start: Marker3D
## Clearing every one of these wins the run.
@export var encounters: Array[EncounterController] = []
## Shown when the run is won.
@export var victory_title: String = "The hall is cleared"
