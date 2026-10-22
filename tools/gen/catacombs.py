#!/usr/bin/env python3
"""Writes game/scenes/dungeon/catacombs.tscn and its encounter resources.

The Forgotten Catacombs (docs/dungeons/forgotten_catacombs.md) is laid out
from the table below, so its rooms, gates, combat areas, encounter markers
and props stay consistent with each other. Re-run after changing the layout:

    python3 tools/gen/catacombs.py
"""
from pathlib import Path

GAME = Path(__file__).resolve().parents[2] / "game"

# (name, width, depth, centre z, north edge, south edge); 1 = GAP, 2 = NONE, 0 = WALL.
ROOMS = [
    ("Stairwell", 12, 12, 0, 1, 0),
    ("Corridor1", 4, 8, -10, 2, 2),
    ("Gallery", 24, 20, -24, 1, 1),
    ("Corridor2", 4, 8, -38, 2, 2),
    ("Vault", 20, 24, -54, 1, 1),
    ("Corridor3", 4, 8, -70, 2, 2),
    ("Pit", 16, 16, -82, 1, 1),
    ("Corridor4", 4, 8, -94, 2, 2),
    ("Throne", 28, 28, -112, 0, 1),
]
# Gates sit in the north gap of each room but the Throne.
GATES = {"Stairwell": -6.5, "Gallery": -34.5, "Vault": -66.5, "Pit": -90.5}

# id, title, subtitle, colour, room, waves [(enemy, marker), ...]
ENCOUNTERS = [
    ("Gallery", "The Gallery of Bones", "Something stirs in the niches", None, "Gallery", [
        [("ghoul", "North"), ("ghoul", "NorthEast"), ("ghoul", "NorthWest"), ("ghoul", "East"), ("ghoul", "West")],
        [("skeleton", "NorthEast"), ("skeleton", "NorthWest"), ("ghoul", "East"), ("ghoul", "West"), ("cultist", "North")],
    ]),
    ("Vault", "The Drowned Vault", "The water remembers", None, "Vault", [
        [("cultist", "NorthEast"), ("cultist", "NorthWest"), ("skeleton", "East"), ("skeleton", "West")],
        [("ghoul", "North"), ("ghoul", "East"), ("ghoul", "West"), ("ghoul", "SouthEast")],
        [("knight", "North"), ("cultist", "NorthEast"), ("cultist", "NorthWest")],
    ]),
    ("Pit", "The Bone Pit", "No one climbs out", None, "Pit", [
        [("knight", "North"), ("ghoul", "East"), ("ghoul", "West"), ("ghoul", "NorthEast")],
        [("ghoul", "North"), ("ghoul", "NorthEast"), ("ghoul", "NorthWest"), ("ghoul", "East"), ("ghoul", "West")],
    ]),
    ("Throne", "The Hollow Throne", "The Hollow King remembers his crown", "Color(0.45, 0.9, 1, 1)", "Throne", [
        [("king", "North")],
    ]),
]
ENEMY_SCENES = {
    "skeleton": "res://scenes/enemies/skeleton_warrior.tscn",
    "cultist": "res://scenes/enemies/dark_cultist.tscn",
    "knight": "res://scenes/enemies/fallen_knight.tscn",
    "ghoul": "res://scenes/enemies/ghoul.tscn",
    "king": "res://scenes/enemies/hollow_king.tscn",
}

# Markers, relative to the room's centre, scaled to its size.
def markers(width, depth):
    hx, hz = width / 2 - 3, depth / 2 - 3
    return {
        "North": (0, -hz), "NorthEast": (hx, -hz + 1), "NorthWest": (-hx, -hz + 1),
        "East": (hx, 0), "West": (-hx, 0), "SouthEast": (hx - 1, hz - 1), "SouthWest": (-(hx - 1), hz - 1),
    }

SOUL_LIGHT = "Color(0.4, 0.85, 1, 1)"
# Props: (name, x, z, lit) - pillars with cold soul-fire; lit ones carry a light.
PILLARS = [
    ("GalleryPillarW1", -6, -20, False), ("GalleryPillarW2", -6, -28, True),
    ("GalleryPillarE1", 6, -20, True), ("GalleryPillarE2", 6, -28, False),
    ("VaultPillarW", -5, -50, True), ("VaultPillarE", 5, -50, True),
    ("VaultPillarSW", -5, -59, False), ("VaultPillarSE", 5, -59, False),
    ("PitPillarW", -4, -84, True), ("PitPillarE", 4, -84, True),
    ("BrazierNW", -9, -121, True), ("BrazierNE", 9, -121, True),
    ("BrazierSW", -9, -103, True), ("BrazierSE", 9, -103, True),
]


def tf(x=0.0, y=0.0, z=0.0, s=1.0):
    return f"Transform3D({s}, 0, 0, 0, {s}, 0, 0, 0, {s}, {x}, {y}, {z})"


def write_encounter(enc_id, waves):
    used = sorted({e for wave in waves for e, _ in wave})
    ids = {e: f"{i + 3}_{e}" for i, e in enumerate(used)}
    out = ['[gd_resource type="Resource" script_class="EncounterData" format=3]', "",
           '[ext_resource type="Script" path="res://scripts/encounters/encounter_data.gd" id="1_encounter"]',
           '[ext_resource type="Script" path="res://scripts/encounters/wave_data.gd" id="2_wave"]']
    for e in used:
        out.append(f'[ext_resource type="PackedScene" path="{ENEMY_SCENES[e]}" id="{ids[e]}"]')
    out.append("")
    for w, wave in enumerate(waves):
        enemies = ", ".join(f'ExtResource("{ids[e]}")' for e, _ in wave)
        names = ", ".join(f'"{m}"' for _, m in wave)
        out += [f'[sub_resource type="Resource" id="Resource_wave{w + 1}"]', 'script = ExtResource("2_wave")',
                f"enemies = Array[PackedScene]([{enemies}])", f"markers = PackedStringArray({names})", ""]
    subs = ", ".join(f'SubResource("Resource_wave{w + 1}")' for w in range(len(waves)))
    out += ["[resource]", 'script = ExtResource("1_encounter")',
            f'waves = Array[ExtResource("2_wave")]([{subs}])']
    if enc_id == "Throne":
        out.append("rise_time = 2.0")
    path = GAME / "resources" / "encounters" / f"catacombs_{enc_id.lower()}.tres"
    path.write_text("\n".join(out) + "\n")


def main():
    room = {r[0]: r for r in ROOMS}
    for enc_id, _, _, _, _, waves in ENCOUNTERS:
        write_encounter(enc_id, waves)

    ext = [
        ("Script", "res://scripts/world/level.gd", "1_level"),
        ("Environment", "res://resources/environment/catacombs_environment.tres", "2_env"),
        ("Environment", "res://resources/environment/arena_environment_compatibility.tres", "3_env_compat"),
        ("Script", "res://scripts/world/renderer_lighting.gd", "4_renderer_lighting"),
        ("Script", "res://scripts/world/baked_navigation_region.gd", "5_navigation"),
        ("NavigationMesh", "res://resources/navigation/ground_navigation_mesh.tres", "6_navmesh"),
        ("Script", "res://scripts/dungeon/crypt_room.gd", "7_room"),
        ("PackedScene", "res://scenes/dungeon/crypt_gate.tscn", "8_gate"),
        ("Script", "res://scripts/dungeon/combat_room.gd", "9_combat_room"),
        ("Script", "res://scripts/encounters/encounter_controller.gd", "10_encounter"),
        ("PackedScene", "res://assets/third_party/kaykit/dungeon/pillar_decorated.glb", "15_pillar"),
        ("PackedScene", "res://assets/third_party/kaykit/dungeon/barrel_large.glb", "16_barrel"),
        ("PackedScene", "res://assets/third_party/kaykit/dungeon/banner_red.glb", "17_banner"),
        ("Material", "res://resources/materials/soul_fire_ember.tres", "18_ember"),
        ("Script", "res://scripts/presentation/model_dressing.gd", "19_dressing"),
        ("Material", "res://resources/materials/dungeon_cutout.tres", "20_cutout"),
        ("PackedScene", "res://assets/third_party/kaykit/dungeon/chair.glb", "21_chair"),
        ("Script", "res://scripts/presentation/flame_fx.gd", "22_flame"),
    ]
    for i, (enc_id, *_rest) in enumerate(ENCOUNTERS):
        ext.append(("Resource", f"res://resources/encounters/catacombs_{enc_id.lower()}.tres", f"{30 + i}_enc"))
    o = ["[gd_scene format=3]", ""]
    o += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext]
    o += ["", '[sub_resource type="CylinderShape3D" id="CylinderShape3D_pillar"]', "height = 4.0", "radius = 0.7", "",
          '[sub_resource type="CylinderShape3D" id="CylinderShape3D_barrel"]', "height = 2.0", "radius = 0.9", "",
          '[sub_resource type="SphereMesh" id="SphereMesh_ember"]', 'material = ExtResource("18_ember")',
          "radius = 0.28", "height = 0.56", "radial_segments = 12", "rings = 6", ""]
    for enc_id, *_r, room_name, _w in ENCOUNTERS:
        _, w, d, z, *_x = room[room_name]
        o += [f'[sub_resource type="BoxShape3D" id="BoxShape3D_{enc_id}"]', f"size = Vector3({w}, 3, {d - 2})", ""]
    enc_paths = ", ".join(f'NodePath("Encounters/{e[0]}")' for e in ENCOUNTERS)
    o += ['[node name="ForgottenCatacombs" type="Node3D" node_paths=PackedStringArray("player_start", "encounters")]',
          'script = ExtResource("1_level")', 'player_start = NodePath("PlayerStart")',
          f"encounters = [{enc_paths}]", 'victory_title = "The catacombs fall silent"', "item_level = 6", "",
          '[node name="PlayerStart" type="Marker3D" parent="."]', f"transform = {tf(0, 0, 3)}", "",
          '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = ExtResource("2_env")', "",
          '[node name="Moonlight" type="DirectionalLight3D" parent="."]',
          "transform = Transform3D(0.7880108, 0.48514786, -0.37903908, 0, 0.6156615, 0.7880107, 0.6156615, -0.62096095, 0.4851479, 0, 12, 0)",
          "light_color = Color(0.45, 0.7, 0.95, 1)", "light_energy = 0.6", "shadow_enabled = true",
          "directional_shadow_mode = 0", "directional_shadow_max_distance = 60.0", "",
          '[node name="RendererLighting" type="Node" parent="." node_paths=PackedStringArray("world_environment", "moonlight")]',
          'script = ExtResource("4_renderer_lighting")', 'world_environment = NodePath("../WorldEnvironment")',
          'moonlight = NodePath("../Moonlight")', 'compatibility_environment = ExtResource("3_env_compat")',
          "compatibility_moonlight_energy = 0.4", "",
          '[node name="Navigation" type="NavigationRegion3D" parent="."]', 'navigation_mesh = ExtResource("6_navmesh")',
          'script = ExtResource("5_navigation")', "", '[node name="Rooms" type="Node3D" parent="Navigation"]', ""]
    for i, (name, w, d, z, north, south) in enumerate(ROOMS):
        o += [f'[node name="{name}" type="Node3D" parent="Navigation/Rooms"]', f"transform = {tf(0, 0, z)}",
              'script = ExtResource("7_room")', f"size = Vector2i({w}, {d})"]
        if north:
            o.append(f"north = {north}")
        if south:
            o.append(f"south = {south}")
        o += [f"seed = {i + 21}", f"torch_light_color = {SOUL_LIGHT}",
              "torch_core_color = Color(0.75, 1, 1, 1)", "torch_edge_color = Color(0.15, 0.6, 1, 1)", ""]
    o += ['[node name="Gates" type="Node3D" parent="Navigation"]', ""]
    for name, z in GATES.items():
        o += [f'[node name="{name}" parent="Navigation/Gates" instance=ExtResource("8_gate")]', f"transform = {tf(0, 0, z)}"]
        if name == "Stairwell":
            o.append("open = true")
        o.append("")
    o += ['[node name="Props" type="Node3D" parent="Navigation"]', ""]
    for name, x, z, lit in PILLARS:
        base = f"Navigation/Props/{name}"
        o += [f'[node name="{name}" type="StaticBody3D" parent="Navigation/Props"]', f"transform = {tf(x, 2, z)}", "",
              f'[node name="CollisionShape3D" type="CollisionShape3D" parent="{base}"]',
              'shape = SubResource("CylinderShape3D_pillar")', "",
              f'[node name="Model" parent="{base}" instance=ExtResource("15_pillar")]',
              "transform = Transform3D(0.7, 0, 0, 0, 0.75, 0, 0, 0, 0.7, 0, -2, 0)", "",
              f'[node name="Dressing" type="Node" parent="{base}" node_paths=PackedStringArray("model")]',
              'script = ExtResource("19_dressing")', 'model = NodePath("../Model")', 'material = ExtResource("20_cutout")', "",
              f'[node name="Ember" type="MeshInstance3D" parent="{base}"]', f"transform = {tf(0, 1.25, 0)}",
              "cast_shadow = 0", 'mesh = SubResource("SphereMesh_ember")', ""]
        if lit:
            o += [f'[node name="Light" type="OmniLight3D" parent="{base}"]', f"transform = {tf(0, 1.7, 0)}",
                  f"light_color = {SOUL_LIGHT}", "light_energy = 2.2", "omni_range = 10.0", "",
                  f'[node name="Fire" type="Node3D" parent="{base}" node_paths=PackedStringArray("light")]',
                  f"transform = {tf(0, 1.3, 0)}", 'script = ExtResource("22_flame")', 'light = NodePath("../Light")']
        else:
            o += [f'[node name="Fire" type="Node3D" parent="{base}"]', f"transform = {tf(0, 1.3, 0)}",
                  'script = ExtResource("22_flame")']
        o += ["size = 0.75", "core_color = Color(0.75, 1, 1, 1)", "edge_color = Color(0.15, 0.6, 1, 1)", "ember_count = 12", ""]
    for name, x, z in [("VaultBarrelW", -8.6, -64.6), ("VaultBarrelE", 8.6, -64.6), ("GalleryBarrel", 10.2, -16.2)]:
        o += [f'[node name="{name}" type="StaticBody3D" parent="Navigation/Props"]', f"transform = {tf(x, 0, z)}", "",
              f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Navigation/Props/{name}"]',
              f"transform = {tf(0, 1, 0)}", 'shape = SubResource("CylinderShape3D_barrel")', "",
              f'[node name="Model" parent="Navigation/Props/{name}" instance=ExtResource("16_barrel")]', ""]
    o += ['[node name="Banners" type="Node3D" parent="."]', ""]
    for name, x in [("ThroneWest", -4), ("ThroneCenter", 0), ("ThroneEast", 4)]:
        o += [f'[node name="{name}" parent="Banners" instance=ExtResource("17_banner")]', f"transform = {tf(x, 0, -126.5)}", ""]
    o += ['[node name="ThroneSeat" parent="." instance=ExtResource("21_chair")]',
          "transform = Transform3D(2.2, 0, 0, 0, 2.2, 0, 0, 0, 2.2, 0, 0, -124.2)", "",
          '[node name="Encounters" type="Node3D" parent="."]', ""]
    for i, (enc_id, title, subtitle, color, room_name, waves) in enumerate(ENCOUNTERS):
        _, w, d, z, *_x = room[room_name]
        o += [f'[node name="{enc_id}" type="Node3D" parent="Encounters"]', f"transform = {tf(0, 0, z)}",
              'script = ExtResource("10_encounter")', f'data = ExtResource("{30 + i}_enc")',
              f'title = "{title}"', f'subtitle = "{subtitle}"']
        if color:
            o.append(f"title_color = {color}")
        o.append("")
        spots = markers(w, d)
        if enc_id == "Throne":
            spots = {"North": (0, -10)}
            spots.update({"SummonNW": (-7.5, -7.5), "SummonNE": (7.5, -7.5), "SummonSW": (-7.5, 7.5), "SummonSE": (7.5, 7.5)})
        for marker, (mx, mz) in spots.items():
            o += [f'[node name="{marker}" type="Marker3D" parent="Encounters/{enc_id}"]', f"transform = {tf(mx, 0, mz)}", ""]
    o += ['[node name="CombatRooms" type="Node3D" parent="."]', ""]
    order = [e[0] for e in ENCOUNTERS]
    previous_gate = {"Gallery": "Stairwell", "Vault": "Gallery", "Pit": "Vault", "Throne": "Pit"}
    for enc_id in order:
        _, w, d, z, *_x = room[enc_id]
        exits = f', "exit_gates"' if enc_id in GATES else ""
        o += [f'[node name="{enc_id}" type="Area3D" parent="CombatRooms" node_paths=PackedStringArray("encounter", "seal_gates"{exits})]',
              f"transform = {tf(0, 1.5, z - 1)}", 'script = ExtResource("9_combat_room")',
              f'encounter = NodePath("../../Encounters/{enc_id}")',
              f'seal_gates = [NodePath("../../Navigation/Gates/{previous_gate[enc_id]}")]']
        if enc_id in GATES:
            o.append(f'exit_gates = [NodePath("../../Navigation/Gates/{enc_id}")]')
        o += ["", f'[node name="CollisionShape3D" type="CollisionShape3D" parent="CombatRooms/{enc_id}"]',
              f'shape = SubResource("BoxShape3D_{enc_id}")', ""]
    (GAME / "scenes" / "dungeon" / "catacombs.tscn").write_text("\n".join(o).rstrip("\n") + "\n")


if __name__ == "__main__":
    main()
