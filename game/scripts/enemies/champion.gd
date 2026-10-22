class_name Champion
extends Node
## A champion: an ordinary enemy risen stronger, with one or more affixes
## (docs/CHAMPIONS.md). promote() adds it to the enemy as its child
## "Champion", before or after the enemy enters the tree.
##
## A champion has more health, hits harder and is worth more: XP, gold and Ash,
## plus `bonus_drops`, a guaranteed Rare-or-better item that LootDropper rolls
## as well as the enemy's own table. Its affixes:
## - Hasted: moves and attacks faster.
## - Stoneskin: takes less damage.
## - Vampiric: heals for each hit it lands (melee enemies only).
## - Ember-wreathed: burns the hero standing close, once a second.
## - Vengeful: when it dies, the ground under it erupts a moment later.
##
## The name and bar, the ring under its feet and its glow are presentation.
## The aura's damage comes from this node's ticks and the eruption's from its
## VengefulBlast, both through Health.

enum Affix { HASTED, STONESKIN, VAMPIRIC, EMBER_WREATHED, VENGEFUL }

const AFFIX_NAMES: Dictionary[Affix, String] = {
	Affix.HASTED: "Hasted",
	Affix.STONESKIN: "Stoneskin",
	Affix.VAMPIRIC: "Vampiric",
	Affix.EMBER_WREATHED: "Ember-wreathed",
	Affix.VENGEFUL: "Vengeful",
}
const AFFIX_COLORS: Dictionary[Affix, Color] = {
	Affix.HASTED: Color(0.45, 0.85, 1.0),
	Affix.STONESKIN: Color(0.75, 0.72, 0.65),
	Affix.VAMPIRIC: Color(0.9, 0.1, 0.2),
	Affix.EMBER_WREATHED: Color(1.0, 0.45, 0.1),
	Affix.VENGEFUL: Color(0.75, 0.35, 1.0),
}

const HEALTH_SCALE := 2.5
const DAMAGE_SCALE := 1.2
## XP and gold.
const REWARD_SCALE := 4.0
const ASH_SCALE := 3.0
## Bigger, so it stands out in a crowd.
const SIZE_SCALE := 1.15

const HASTE_SPEED := 1.35
## Hasted windups and recoveries take this share of their time.
const HASTE_ATTACK := 0.75
## Stoneskin takes this share of each hit.
const STONESKIN_TAKEN := 0.6
## Vampiric heals this share of its health per target hit.
const VAMPIRIC_HEAL := 0.1
const EMBER_RADIUS := 2.6
const EMBER_INTERVAL := 1.0
## Per tick, before the enemy's damage scale (crypt tier and champion).
const EMBER_DAMAGE := 4

var affixes: Array[Affix] = []
## The name over its bar: its affixes, then what it is.
var title: String = ""
## Rolled on its death on top of the enemy's own drop table.
var bonus_drops: DropTable

var _enemy: EnemyController
var _ember_left: float = EMBER_INTERVAL
var _aura: MeshInstance3D


## The Champion on `enemy`, or null when it is an ordinary enemy.
static func of(enemy: Node) -> Champion:
	return enemy.get_node_or_null(^"Champion") as Champion


## Up to `count` different affixes for `enemy`, at random. Vampiric only for
## enemies that strike in melee: a ranged hit lands too late to heal from.
static func roll(enemy: EnemyController, count: int, rng: RandomNumberGenerator) -> Array[Affix]:
	var pool: Array[Affix] = [Affix.HASTED, Affix.STONESKIN, Affix.EMBER_WREATHED, Affix.VENGEFUL]
	if not enemy.attack is RangedAttack:
		pool.append(Affix.VAMPIRIC)
	var chosen: Array[Affix] = []
	for i in mini(count, pool.size()):
		chosen.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return chosen


## Makes `enemy` a champion with `chosen` affixes. Call once, after the crypt
## tier is applied, so the champion's scaling multiplies the tier's.
static func promote(enemy: EnemyController, chosen: Array[Affix]) -> Champion:
	var champion := Champion.new()
	champion.name = "Champion"
	champion._enemy = enemy
	champion.affixes = chosen.duplicate()
	var words: PackedStringArray = []
	for affix in chosen:
		words.append(AFFIX_NAMES[affix])
	words.append(String(enemy.name).capitalize())
	champion.title = " ".join(words)
	champion.bonus_drops = DropTable.new()
	champion.bonus_drops.chance = 1.0
	champion.bonus_drops.min_rarity = Rarity.Tier.RARE
	enemy.add_child(champion)
	champion._strengthen()
	champion._dress()
	return champion


func has_affix(affix: Affix) -> bool:
	return affixes.has(affix)


func _strengthen() -> void:
	var enemy := _enemy
	enemy.health.max_health = roundi(enemy.health.max_health * HEALTH_SCALE)
	enemy.health.current = enemy.health.max_health
	enemy.xp_value = roundi(enemy.xp_value * REWARD_SCALE)
	enemy.gold_value = roundi(enemy.gold_value * REWARD_SCALE)
	enemy.ash_value = roundi(enemy.ash_value * ASH_SCALE)
	for attack in _attacks():
		attack.damage_scale *= DAMAGE_SCALE
		if has_affix(Affix.HASTED):
			attack.windup_scale *= HASTE_ATTACK
			attack.recovery_scale *= HASTE_ATTACK
		if has_affix(Affix.VAMPIRIC):
			attack.struck.connect(_on_struck)
	if has_affix(Affix.HASTED):
		enemy.speed_multiplier *= HASTE_SPEED
	if has_affix(Affix.STONESKIN):
		enemy.health.damage_multiplier *= STONESKIN_TAKEN
	if has_affix(Affix.VENGEFUL):
		enemy.health.died.connect(_on_died)


func _attacks() -> Array[MeleeAttack]:
	var list: Array[MeleeAttack] = []
	for node in _enemy.find_children("*", "", true, false):
		if node is MeleeAttack:
			list.append(node)
	return list


## The scale on this champion's hits: the crypt tier's and its own.
func damage_scale() -> float:
	return _enemy.attack.damage_scale if _enemy.attack else DAMAGE_SCALE


## Damage each Ember-wreathed tick deals.
func ember_damage() -> int:
	return maxi(roundi(EMBER_DAMAGE * damage_scale()), 1)


func _physics_process(delta: float) -> void:
	if not has_affix(Affix.EMBER_WREATHED) or _enemy.state == EnemyController.State.DEAD \
			or _enemy.state == EnemyController.State.RISING:
		return
	_ember_left -= delta
	if _ember_left > 0.0:
		return
	_ember_left += EMBER_INTERVAL
	for target in Targeting.living_within(_enemy, EMBER_RADIUS, _enemy.attack.target_mask):
		target.apply_damage(ember_damage(), _enemy.global_position)
	if _aura:
		_aura.scale = Vector3.ONE * 1.12
		_aura.create_tween().tween_property(_aura, "scale", Vector3.ONE, 0.35)


func _on_struck(targets: Array[Health]) -> void:
	if not targets.is_empty():
		_enemy.health.heal(roundi(_enemy.health.max_health * VAMPIRIC_HEAL * targets.size()))


func _on_died() -> void:
	var level := _enemy.get_parent()
	if level == null:
		return
	VengefulBlast.erupt(level, _enemy.global_position, damage_scale(), _enemy.attack.target_mask)


## The name and bar above it, a ring in its first affix's colour under its
## feet, a glow, and for Ember-wreathed the edge of its aura.
func _dress() -> void:
	var color := AFFIX_COLORS[affixes[0]] if not affixes.is_empty() else Color.WHITE
	if _enemy.visual:
		_enemy.visual.scale *= SIZE_SCALE
	var bar := EliteBar.new()
	bar.name = "ChampionBar"
	bar.health = _enemy.health
	bar.title = title.to_upper()
	bar.title_color = color.lerp(Color.WHITE, 0.35)
	bar.position = Vector3(0, 2.55, 0)
	_enemy.add_child(bar)
	_enemy.add_child(ring_mesh("Ring", 0.75, color, 0.85))
	var light := OmniLight3D.new()
	light.name = "ChampionLight"
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.5
	light.position = Vector3(0, 1.2, 0)
	_enemy.add_child(light)
	if has_affix(Affix.EMBER_WREATHED):
		_aura = ring_mesh("EmberAura", EMBER_RADIUS, AFFIX_COLORS[Affix.EMBER_WREATHED], 0.45)
		_enemy.add_child(_aura)
	_enemy.health.died.connect(_undress)


## A flat glowing ring of `radius` on the floor.
static func ring_mesh(node_name: String, radius: float, color: Color, alpha: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.9
	mesh.outer_radius = radius
	mesh.rings = 40
	mesh.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.name = node_name
	ring.mesh = mesh
	ring.position.y = 0.06
	ring.scale = Vector3(1.0, 0.1, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	ring.material_override = material
	return ring


## The rings and glow go with the champion's life; the corpse is ordinary.
func _undress() -> void:
	for node_name: String in ["Ring", "EmberAura", "ChampionLight"]:
		var node := _enemy.get_node_or_null(node_name)
		if node:
			node.queue_free()
	_aura = null
