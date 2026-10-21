class_name MovementStats
extends Resource
## Ground movement tuning, kept as data so other characters can reuse it.

## Top speed in meters per second.
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var move_speed: float = 6.0
## How quickly speed builds up while there is input.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var acceleration: float = 60.0
## How quickly the character stops once input is released.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var deceleration: float = 80.0
## How quickly the visual turns toward the movement direction. Higher is snappier.
@export_range(1.0, 40.0, 0.5) var turn_sharpness: float = 18.0
