class_name SkillNode
extends Resource
## One node of a class's skill tree: what each rank adds, how many ranks it
## has, and the node of the same branch it requires.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 0, 1 or 2: the branch column this node sits in.
@export_range(0, 2, 1) var branch: int = 0
## 0 (top) to 2: its row in the branch.
@export_range(0, 2, 1) var tier: int = 0
@export_range(1, 10, 1) var max_rank: int = 1
## Stat key → amount per rank (item stats, or SkillStats keys).
@export var per_rank: Dictionary[String, int] = {}
## Id of a node that must have a rank first; empty for none.
@export var requires: String = ""
