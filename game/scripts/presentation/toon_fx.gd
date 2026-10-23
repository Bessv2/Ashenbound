class_name ToonFx
extends RefCounted
## Look B's effects (ArtStyle.Look.GRIM): cartoon hits in a realistic world,
## in the spirit of Castle Crashers. A comic star pops at the impact, fat
## outlined blobs (blood or bone) bounce away, the dead vanish in round
## outlined puffs, and swings are thick, bold, outlined arcs. Visual only:
## nothing here touches Health. Each effect frees itself and runs on the
## physics clock.

const INK := Color(0.03, 0.02, 0.03)
const STAR := Color(1.0, 0.93, 0.35)
const BLOOD := Color(0.9, 0.08, 0.1)
const BONE := Color(0.98, 0.95, 0.85)
const PUFF := Color(0.95, 0.93, 0.9)

static var _star_mesh: ArrayMesh


## A hit at `at`: a star that pops and fades, and a spray of fat blobs.
static func impact(parent: Node, at: Vector3, flesh: bool) -> void:
	star(parent, at + Vector3.UP * 0.2, 0.9)
	for i in 5:
		_blob(parent, at, BLOOD if flesh else BONE, 0.16 + 0.05 * (i % 3))


## A body vanishing at `at`: a ring of round outlined puffs and a big star.
static func death(parent: Node, at: Vector3, flesh: bool) -> void:
	star(parent, at + Vector3.UP * 0.4, 1.6)
	for i in 7:
		var angle := TAU * i / 7.0
		_puff(parent, at + Vector3(cos(angle), 0.15 * (i % 2), sin(angle)) * 0.5, 0.45 + 0.1 * (i % 3))
	for i in 6:
		_blob(parent, at, BLOOD if flesh else BONE, 0.2)


## A thick, bold arc with an ink outline along the swing: solid colour, not
## glow, so it reads like a drawn smear.
##
## Drawn as a crescent like the concept sheet's slash: a band near the end
## of the reach, thin and faint where the blade started and thick and bright
## where it finished.
static func swing(owner: Node3D, direction: Vector3, reach: float, arc_degrees: float, color: Color) -> void:
	_smear(owner, direction, reach * 1.08, arc_degrees + 10.0, INK, 0.0, 0.5)
	_smear(owner, direction, reach, arc_degrees, color.lightened(0.3), 0.03, 0.58)


## A crescent band from `inner` times `radius` out to `radius`, across
## `arc_degrees` around -Z. Its vertex alpha and width grow from the start of
## the swing (left, -arc/2) to its end.
static func crescent(radius: float, arc_degrees: float, inner: float, segments: int = 20) -> ArrayMesh:
	var half := deg_to_rad(minf(arc_degrees, 359.0)) * 0.5
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for i in segments + 1:
		var t := float(i) / segments
		var angle := lerpf(-half, half, t)
		# Thin at the start, full width at the end; a soft tip at the very end.
		var width := (1.0 - inner) * (0.25 + 0.75 * t)
		var alpha := smoothstep(0.0, 0.6, t) * (1.0 - smoothstep(0.92, 1.0, t) * 0.5)
		var along := Vector3(-sin(angle), 0.0, -cos(angle))
		vertices.append(along * radius * (1.0 - width))
		vertices.append(along * radius)
		colors.append(Color(1, 1, 1, alpha * 0.55))
		colors.append(Color(1, 1, 1, alpha))
	var strip := PackedVector3Array()
	var strip_colors := PackedColorArray()
	for i in segments:
		for k in [0, 1, 2, 1, 3, 2]:
			strip.append(vertices[i * 2 + k])
			strip_colors.append(colors[i * 2 + k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = strip
	arrays[Mesh.ARRAY_COLOR] = strip_colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _smear(owner: Node3D, direction: Vector3, reach: float, arc_degrees: float, color: Color, lift: float, inner: float) -> void:
	var arc := MeshInstance3D.new()
	arc.mesh = crescent(reach, arc_degrees, inner)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.render_priority = 1 if lift > 0.0 else 0
	arc.material_override = material
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(arc)
	arc.top_level = true
	arc.global_position = owner.global_position + Vector3(0, 0.55 + lift, 0)
	arc.rotation = Vector3(0, MovementStats.yaw_of(direction), 0)
	arc.scale = Vector3.ONE * 0.6
	var tween := arc.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(arc, "scale", Vector3.ONE, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.06)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(arc.queue_free)


## A cartoon knock-out (look B): `visual` (a body's model holder, at
## `base_scale`) is flung up and away along `away`, tumbling end over end,
## lands with a squash and shrinks to nothing in a puff. Visual only: the body
## itself stays where it fell until it is removed.
static func launch(visual: Node3D, away: Vector3, base_scale: Vector3 = Vector3.ONE) -> void:
	var flat := Vector2(away.x, away.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector2(0, 1)
	var start := visual.position
	var land := start + Vector3(dir.x, 0.0, dir.y) * 2.6
	var spin := Vector3(dir.y, 0.0, -dir.x) * TAU * 1.5
	var tween := visual.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_parallel()
	# The arc: across in one smooth move, up and down as a hop.
	tween.tween_property(visual, "position:x", land.x, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:z", land.z, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", start.y + 2.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", start.y, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.tween_property(visual, "rotation", visual.rotation + spin, 0.62).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(visual, "scale", base_scale * Vector3(1.5, 0.45, 1.5), 0.06)
	tween.chain().tween_property(visual, "scale", base_scale * 0.01, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if visual.is_inside_tree():
			var at := visual.global_position + Vector3.UP * 0.3
			for i in 6:
				var angle := TAU * i / 6.0
				_puff(visual.get_parent().get_parent(), at + Vector3(cos(angle), 0.1 * (i % 2), sin(angle)) * 0.45, 0.4 + 0.08 * (i % 3)))


## A comic star of `size` at `at`, billboarded, that pops in and fades.
static func star(parent: Node, at: Vector3, size: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "ComicStar"
	node.mesh = _star()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 3
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = at
	node.scale = Vector3.ONE * size * 0.2
	node.rotation.z = randf() * TAU
	var tween := node.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(node, "scale", Vector3.ONE * size, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.06)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(node.queue_free)
	return node


## A fat, outlined blob thrown up and out that bounces once, squashing.
static func _blob(parent: Node, at: Vector3, color: Color, radius: float) -> void:
	var blob := Node3D.new()
	blob.name = "ToonBlob"
	blob.add_child(_inked_sphere(color, radius))
	parent.add_child(blob)
	blob.global_position = at + Vector3.UP * 0.5
	var out := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.8, 1.8)
	var peak := blob.global_position + out * 0.5 + Vector3.UP * randf_range(0.6, 1.2)
	var land := Vector3(at.x, radius * 0.5, at.z) + out
	var tween := blob.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(blob, "global_position", peak, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(blob, "global_position", land, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(blob, "scale", Vector3(1.5, 0.45, 1.5), 0.06)
	tween.tween_property(blob, "scale", Vector3(1.0, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_interval(0.4)
	tween.tween_property(blob, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(blob.queue_free)


## A round outlined puff of smoke that swells and pops.
static func _puff(parent: Node, at: Vector3, radius: float) -> void:
	var puff := _inked_sphere(PUFF, radius)
	parent.add_child(puff)
	puff.global_position = at + Vector3.UP * 0.6
	puff.scale = Vector3.ONE * 0.2
	var tween := puff.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(puff, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(puff, "global_position", at + Vector3.UP * 1.1, 0.5)
	tween.tween_property(puff, "scale", Vector3.ZERO, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(puff.queue_free)


## A flat-shaded sphere with a thick ink outline.
static func _inked_sphere(color: Color, radius: float) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = sphere
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.albedo_color = color
	var ink := ShaderMaterial.new()
	ink.shader = ArtStyle.OutlineShader
	ink.set_shader_parameter(&"width", radius * 0.18)
	ink.set_shader_parameter(&"outline_color", INK)
	fill.next_pass = ink
	node.material_override = fill
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## An eight-pointed star: a yellow body over a slightly larger ink star.
static func _star() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for layer in 2:
		var scale := 1.18 if layer == 0 else 1.0
		var color := INK if layer == 0 else STAR
		var z := -0.01 if layer == 0 else 0.0
		for i in 16:
			var a0 := TAU * i / 16.0
			var a1 := TAU * (i + 1) / 16.0
			var r0 := (0.5 if i % 2 == 0 else 0.22) * scale
			var r1 := (0.5 if (i + 1) % 2 == 0 else 0.22) * scale
			vertices.append_array([Vector3(0, 0, z), Vector3(cos(a0) * r0, sin(a0) * r0, z), Vector3(cos(a1) * r1, sin(a1) * r1, z)])
			colors.append_array([color, color, color])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	_star_mesh = ArrayMesh.new()
	_star_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _star_mesh
