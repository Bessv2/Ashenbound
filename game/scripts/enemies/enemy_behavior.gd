class_name EnemyBehavior
extends Resource
## How an enemy decides what to do, kept as data so enemy types can share code.

## The enemy starts chasing when the player comes this close.
@export_range(1.0, 50.0, 0.5, "suffix:m") var aggro_radius: float = 9.0
## The enemy gives up when the player gets this far away.
@export_range(1.0, 100.0, 0.5, "suffix:m") var leash_radius: float = 15.0
## The enemy stops and attacks when the player is this close (center to center).
@export_range(0.5, 10.0, 0.05, "suffix:m") var attack_range: float = 1.4
## How long the body stays after death before it is removed.
@export_range(0.0, 10.0, 0.1, "suffix:s") var corpse_time: float = 1.2
## Backs away from the player when it is closer than this (ranged enemies);
## 0 never backs away. A cornered enemy attacks instead.
@export_range(0.0, 20.0, 0.5, "suffix:m") var retreat_distance: float = 0.0
## Attacks only with a clear line to the player (no wall between), and walks
## closer otherwise.
@export var needs_line_of_sight: bool = false
