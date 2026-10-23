class_name ArtStyle
extends RefCounted
## The game's look, chosen on the title screen (docs/ART_STYLE_TEST.md). The
## owner asked to compare two directions before committing:
##
## - CLASSIC: the look as built so far.
## - HEROIC (look A): bold cel-shaded characters with a hard rim and a thick
##   outline, and realistic effects: hot sparks, blood or bone dust, smoke,
##   impact light, motion-blur swings.
## - GRIM (look B): a realistic, worn world (muted colour, relief, grime,
##   metal) under a heavier grade, with cartoon effects: comic stars,
##   bouncing blobs, round puffs, bold outlined swings, big squash.
##
## Both new looks also add attack weight: hit-stop, lunges and flinches.
## Everything here is presentation: it never changes a number in combat.
## The look is read when a scene builds, so a change applies to the next run.

enum Look { CLASSIC, HEROIC, GRIM }

const NAMES: Dictionary[Look, String] = {
	Look.CLASSIC: "Classic",
	Look.HEROIC: "Look A",
	Look.GRIM: "Look B",
}
const LINES: Dictionary[Look, String] = {
	Look.CLASSIC: "The look so far.",
	Look.HEROIC: "Bold cartoon heroes, realistic sparks, blood, smoke and light.",
	Look.GRIM: "A grim, realistic world with cartoon hits, stars and puffs.",
}

const ToonShader := preload("res://resources/shaders/toon_character.gdshader")
const GrimShader := preload("res://resources/shaders/grim_surface.gdshader")
## Look B's relief and grime, baked by tools/art/make_grime_noise.py.
const GrimeNoise := preload("res://resources/textures/grime_noise.png")
const OutlineShader := preload("res://resources/shaders/outline.gdshader")
const CutoutShader := preload("res://resources/shaders/occluder_cutout.gdshader")

## Look B's photographed stone (Poly Haven, CC0; tools/art/fetch_polyhaven.py):
## flagstones on floors, rock blocks on walls.
const FLOOR_PHOTO := "res://assets/third_party/polyhaven/stone_tiles_02/stone_tiles_02_%s_1k.jpg"
const WALL_PHOTO := "res://assets/third_party/polyhaven/rock_wall_08/rock_wall_08_%s_1k.jpg"

## Outline width given to every character in look A, in model units.
const HEROIC_OUTLINE := 0.03

## Restyled materials by look and source material, so a hundred skeletons
## share one shader material each.
static var _cache: Dictionary = {}
## Set by tests to force a look without touching the saved settings; -1
## follows the settings.
static var override_look: int = -1


## The look in use.
static func current() -> Look:
	if override_look >= 0:
		return override_look as Look
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null(^"Settings") if tree else null
	if settings == null or settings.current == null:
		return Look.CLASSIC
	return clampi(settings.current.art_style, 0, Look.size() - 1) as Look


## `source` restyled for a character in `look` (unchanged in CLASSIC, or when
## it is not a textured material). `outline` adds look A's outline pass.
static func character_material(source: Material, look: Look, outline: bool = true) -> Material:
	if look == Look.CLASSIC or source == null:
		return source
	var key := "char:%d:%d:%s" % [look, source.get_instance_id(), outline]
	if _cache.has(key):
		return _cache[key]
	var texture := _albedo_texture_of(source)
	if texture == null:
		return source
	var styled := ShaderMaterial.new()
	if look == Look.HEROIC:
		styled.shader = ToonShader
		if outline:
			var pass_material := ShaderMaterial.new()
			pass_material.shader = OutlineShader
			pass_material.set_shader_parameter(&"width", HEROIC_OUTLINE)
			pass_material.set_shader_parameter(&"outline_color", Color(0.02, 0.015, 0.02))
			styled.next_pass = pass_material
	else:
		styled.shader = GrimShader
		styled.set_shader_parameter(&"grime_noise", GrimeNoise)
		styled.set_shader_parameter(&"noise_scale", 4.0)
		styled.set_shader_parameter(&"relief", 0.25)
		styled.set_shader_parameter(&"grain", 0.4)
		styled.set_shader_parameter(&"desaturate", 0.3)
		styled.set_shader_parameter(&"darken", 1.15)
		styled.set_shader_parameter(&"grime_amount", 0.35)
	styled.set_shader_parameter(&"albedo_texture", texture)
	_copy_colors(source, styled)
	_cache[key] = styled
	return styled


## `source` restyled for the world (floors, walls, props) in `look`. Look B
## turns the dungeon heavy and worn; look A and CLASSIC keep it.
static func world_material(source: Material, look: Look) -> Material:
	if look != Look.GRIM or source == null:
		return source
	var key := "world:%d" % source.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var texture := _albedo_texture_of(source)
	if texture == null:
		return source
	var styled := ShaderMaterial.new()
	styled.shader = GrimShader
	styled.set_shader_parameter(&"albedo_texture", texture)
	styled.set_shader_parameter(&"grime_noise", GrimeNoise)
	styled.set_shader_parameter(&"metal_bias", 0.25)
	# Softened on the owner's word ("too sharp and grainy", 2026-10-23): gentle
	# relief, faint grain, the photographs at half strength and depth, damp
	# rather than glittering hollows. The darkness stays.
	styled.set_shader_parameter(&"relief", 0.45)
	styled.set_shader_parameter(&"noise_scale", 1.0)
	styled.set_shader_parameter(&"grain", 0.45)
	styled.set_shader_parameter(&"wet_shine", 0.6)
	styled.set_shader_parameter(&"desaturate", 0.55)
	styled.set_shader_parameter(&"use_detail", true)
	styled.set_shader_parameter(&"detail_strength", 0.55)
	styled.set_shader_parameter(&"detail_relief", 0.45)
	for part in ["albedo", "normal", "roughness"]:
		var file: String = {"albedo": "diff", "normal": "nor_gl", "roughness": "rough"}[part]
		styled.set_shader_parameter(StringName("detail_top_" + part), load(FLOOR_PHOTO % file))
		styled.set_shader_parameter(StringName("detail_side_" + part), load(WALL_PHOTO % file))
	styled.set_shader_parameter(&"detail_top_scale", 1.0 / 2.0)
	styled.set_shader_parameter(&"detail_side_scale", 1.0 / 1.8)
	if source is ShaderMaterial and (source as ShaderMaterial).shader == CutoutShader:
		styled.set_shader_parameter(&"cutout", true)
	_copy_colors(source, styled)
	_cache[key] = styled
	return styled


## Restyles every visible mesh under `root` for the world in the current
## look (look B only), the tiled floors and walls (MultiMeshes) included.
## Glowing and transparent effects are left alone.
static func dress_world(root: Node) -> void:
	var look := current()
	if look != Look.GRIM:
		return
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var tiles := node as MultiMeshInstance3D
		if tiles.multimesh == null or tiles.multimesh.mesh == null or _is_effect(tiles):
			continue
		var source := tiles.material_override if tiles.material_override else tiles.multimesh.mesh.surface_get_material(0)
		var styled := world_material(source, look)
		if styled != source:
			tiles.material_override = styled
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or _is_effect(mesh_node):
			continue
		if mesh_node.material_override:
			mesh_node.material_override = world_material(mesh_node.material_override, look)
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(surface)
			var styled := world_material(source, look)
			if styled != source:
				mesh_node.set_surface_override_material(surface, styled)


## The environment for the current look, made from `base` (a copy; the
## resource is shared).
static func environment_for(base: Environment) -> Environment:
	var look := current()
	if look == Look.CLASSIC or base == null:
		return base
	var environment := base.duplicate() as Environment
	if look == Look.HEROIC:
		environment.adjustment_saturation = base.adjustment_saturation * 1.15
		environment.adjustment_contrast = base.adjustment_contrast * 1.05
		environment.glow_intensity = base.glow_intensity * 1.1
	else:
		# Dark and muted, but not harsh: a softer contrast than before and a
		# little more glow, so lights bloom instead of cutting.
		environment.adjustment_saturation = base.adjustment_saturation * 0.78
		environment.adjustment_contrast = base.adjustment_contrast * 1.03
		environment.glow_bloom = base.glow_bloom * 0.9
		environment.tonemap_exposure = base.tonemap_exposure * 1.02
	return environment


static func _is_effect(mesh_node: GeometryInstance3D) -> bool:
	var material := mesh_node.material_override
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or standard.emission_enabled
	if material is ShaderMaterial:
		return (material as ShaderMaterial).shader != CutoutShader
	return false


static func _albedo_texture_of(source: Material) -> Texture2D:
	if source is BaseMaterial3D:
		return (source as BaseMaterial3D).albedo_texture
	if source is ShaderMaterial:
		return (source as ShaderMaterial).get_shader_parameter(&"albedo_texture") as Texture2D
	return null


static func _copy_colors(source: Material, styled: ShaderMaterial) -> void:
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		styled.set_shader_parameter(&"tint", base.albedo_color)
		if base.emission_enabled:
			styled.set_shader_parameter(&"emission_color", base.emission)
			styled.set_shader_parameter(&"emission_energy", base.emission_energy_multiplier * 0.6)


## Casts `tint` over every surface under `root` (a region's stone: the
## temple's sand, the wastes' frost), whatever the look. Each material is
## copied once per call and the copy shared, so tiles stay batched. Effects
## (glowing, transparent) are left alone.
static func tint_world(root: Node, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	var copies := {}
	var tinted := func(source: Material) -> Material:
		if source == null:
			return null
		if copies.has(source):
			return copies[source]
		var copy: Material = source.duplicate()
		if copy is BaseMaterial3D:
			(copy as BaseMaterial3D).albedo_color *= tint
		elif copy is ShaderMaterial:
			var shader_copy := copy as ShaderMaterial
			var current: Variant = shader_copy.get_shader_parameter(&"tint")
			shader_copy.set_shader_parameter(&"tint", (current as Color if current is Color else Color.WHITE) * tint)
		copies[source] = copy
		return copy
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if _is_effect(geometry):
			continue
		if geometry.material_override:
			geometry.material_override = tinted.call(geometry.material_override)
		elif geometry is MultiMeshInstance3D:
			var tiles := geometry as MultiMeshInstance3D
			if tiles.multimesh and tiles.multimesh.mesh:
				tiles.material_override = tinted.call(tiles.multimesh.mesh.surface_get_material(0))
		elif geometry is MeshInstance3D:
			var mesh_node := geometry as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			for surface in mesh_node.mesh.get_surface_count():
				mesh_node.set_surface_override_material(surface, tinted.call(mesh_node.get_active_material(surface)))


## Forgets restyled materials (tests switching looks).
static func clear_cache() -> void:
	_cache.clear()
