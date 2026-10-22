class_name SkillTree
extends Resource
## A class's skill tree: three branches (the charter's specializations) of
## SkillNodes. Ranks are kept by Profile; this resource is the rules.

@export var class_id: String = ""
@export var class_title: String = ""
## False for a class whose abilities do not exist yet: shown, not learnable.
@export var playable: bool = false
@export var branches: PackedStringArray = []
@export var nodes: Array[SkillNode] = []


func node(id: String) -> SkillNode:
	for each in nodes:
		if each.id == id:
			return each
	return null


## Every learned rank added up: stat key → value. `ranks` is node id → rank.
func bonus(ranks: Dictionary) -> Dictionary[String, int]:
	var total: Dictionary[String, int] = {}
	for each in nodes:
		var rank := mini(int(ranks.get(each.id, 0)), each.max_rank)
		for stat in each.per_rank:
			total[stat] = total.get(stat, 0) + each.per_rank[stat] * rank
	return total


## Why node `id` cannot take another rank, or "" when it can.
func learn_problem(ranks: Dictionary, id: String, points: int) -> String:
	var each := node(id)
	if each == null:
		return "No such skill."
	if not playable:
		return "%s is not playable yet." % class_title
	if points <= 0:
		return "No skill points left."
	if int(ranks.get(id, 0)) >= each.max_rank:
		return "Fully learned."
	if each.requires != "" and int(ranks.get(each.requires, 0)) <= 0:
		var needed := node(each.requires)
		return "Requires %s." % (needed.display_name if needed else each.requires)
	return ""


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var ids := {}
	for each in nodes:
		if ids.has(each.id):
			problems.append("%s: duplicate node %s" % [class_id, each.id])
		ids[each.id] = each
	for each in nodes:
		if each.requires != "" and not ids.has(each.requires):
			problems.append("%s: %s requires unknown %s" % [class_id, each.id, each.requires])
		if each.requires != "" and ids.has(each.requires) and (ids[each.requires] as SkillNode).branch != each.branch:
			problems.append("%s: %s requires a node of another branch" % [class_id, each.id])
		for stat in each.per_rank:
			if not ItemStats.is_known(stat) and not SkillStats.is_known(stat):
				problems.append("%s: %s uses unknown stat %s" % [class_id, each.id, stat])
	return problems
