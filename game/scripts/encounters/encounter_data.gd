class_name EncounterData
extends Resource
## An encounter's waves, fought in order.

@export var waves: Array[WaveData] = []
## Pause between the last enemy of a wave dying and the next wave appearing.
@export_range(0.0, 10.0, 0.1, "suffix:s") var wave_delay: float = 1.5
## How long a spawned enemy takes to rise out of the ground. It cannot act or
## be damaged meanwhile.
@export_range(0.0, 5.0, 0.05, "suffix:s") var rise_time: float = 0.8
