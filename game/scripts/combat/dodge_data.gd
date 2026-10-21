class_name DodgeData
extends Resource
## Tuning for a dodge, kept as data so characters can share it.

## Distance covered by the dash, unless something blocks it.
@export_range(0.5, 20.0, 0.1, "suffix:m") var distance: float = 4.0
## How long the dash takes.
@export_range(0.05, 2.0, 0.01, "suffix:s") var duration: float = 0.3
## How long from the start of the dash damage is ignored.
@export_range(0.0, 2.0, 0.01, "suffix:s") var invulnerable_time: float = 0.25
## Time from the start of one dodge to the earliest next one.
@export_range(0.0, 10.0, 0.05, "suffix:s") var cooldown: float = 0.9
## A press this long before the dodge is ready still counts once it is.
@export_range(0.0, 1.0, 0.01, "suffix:s") var input_buffer: float = 0.2
