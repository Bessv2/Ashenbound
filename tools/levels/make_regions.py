#!/usr/bin/env python3
"""Writes the five regions after the catacombs (docs/dungeons/regions.md).

Each region is a chain of KayKit rooms (CryptRoom) like the Forgotten
Catacombs: a stairwell, three fighting rooms and a boss hall, joined by
corridors and gates, with its own colour cast (Level.world_tint), torch
colour, light, props, enemies and boss. From the recipes below it writes:
- game/scenes/dungeon/<id>.tscn, the level;
- game/resources/encounters/<id>_<room>.tres, the waves;
- game/resources/environment/<id>_environment.tres;
- game/scenes/enemies/bosses/<boss>.tscn, the boss: an Ashen Lord or Hollow
  King variant (inherited scene) with its own name, colour, health and adds;
- game/resources/materials/<boss>_model.tres.
Running it again rewrites them from the recipes. The props come from
tools/art/fetch_kaykit_props.py.

Usage: tools/levels/make_regions.py
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"

ENEMIES = {
    "skeleton": "res://scenes/enemies/skeleton_warrior.tscn",
    "cultist": "res://scenes/enemies/dark_cultist.tscn",
    "knight": "res://scenes/enemies/fallen_knight.tscn",
    "ghoul": "res://scenes/enemies/ghoul.tscn",
    "demon": "res://scenes/enemies/demon.tscn",
    "imp": "res://scenes/enemies/imp.tscn",
}

# Prop kinds: model path, scale, collision radius (0 for none), tall (only
# against the far walls, where it cannot hide the hero).
PROPS = {
    "pillar": ("res://assets/third_party/kaykit/dungeon/pillar_decorated.glb", 0.7, 0.7, True),
    "column": ("res://assets/third_party/kaykit/dungeon/column.glb", 1.0, 0.5, True),
    "barrel": ("res://assets/third_party/kaykit/dungeon/barrel_large.glb", 1.0, 0.9, False),
    "banner": ("res://assets/third_party/kaykit/dungeon/banner_red.glb", 1.0, 0.0, True),
    "weaponrack": ("res://assets/third_party/kaykit/hexagon/weaponrack.gltf", 2.2, 0.7, False),
    "crate": ("res://assets/third_party/kaykit/hexagon/crate_A_big.gltf", 2.4, 0.8, False),
    "rock": ("res://assets/third_party/kaykit/hexagon/rock_single_A.gltf", 8.0, 1.1, False),
    "rock_tall": ("res://assets/third_party/kaykit/hexagon/rock_single_C.gltf", 9.0, 1.2, True),
    "boulder": ("res://assets/third_party/kaykit/hexagon/rock_single_E.gltf", 8.0, 1.0, False),
    "dead_tree": ("res://assets/third_party/kaykit/halloween/tree_dead_large.gltf", 1.1, 0.6, True),
    "dead_tree_small": ("res://assets/third_party/kaykit/halloween/tree_dead_medium.gltf", 1.0, 0.5, True),
    "pine": ("res://assets/third_party/kaykit/halloween/tree_pine_orange_large.gltf", 1.0, 0.8, True),
    "pine_small": ("res://assets/third_party/kaykit/halloween/tree_pine_yellow_medium.gltf", 1.0, 0.6, True),
    "gravestone": ("res://assets/third_party/kaykit/halloween/gravestone.gltf", 1.0, 0.6, False),
    "grave": ("res://assets/third_party/kaykit/halloween/grave_A.gltf", 1.0, 0.7, False),
    "grave_b": ("res://assets/third_party/kaykit/halloween/grave_B.gltf", 1.0, 0.7, False),
    "fence": ("res://assets/third_party/kaykit/halloween/fence_broken.gltf", 1.0, 0.0, False),
    "lantern": ("res://assets/third_party/kaykit/halloween/lantern_standing.gltf", 1.0, 0.3, False),
    "shrine": ("res://assets/third_party/kaykit/halloween/shrine_candles.gltf", 1.0, 0.8, True),
    "candles": ("res://assets/third_party/kaykit/halloween/candle_triple.gltf", 1.0, 0.0, False),
    "skull": ("res://assets/third_party/kaykit/halloween/skull.gltf", 1.2, 0.0, False),
    "ribcage": ("res://assets/third_party/kaykit/halloween/ribcage.gltf", 1.2, 0.0, False),
    "coffin": ("res://assets/third_party/kaykit/halloween/coffin.gltf", 1.0, 0.8, False),
    "arch": ("res://assets/third_party/kaykit/halloween/arch.gltf", 1.0, 0.0, True),
    "stone_pillar": ("res://assets/third_party/kaykit/halloween/pillar.gltf", 1.0, 0.5, True),
    "post_skull": ("res://assets/third_party/kaykit/halloween/post_skull.gltf", 1.0, 0.3, False),
    "plaque": ("res://assets/third_party/kaykit/halloween/plaque_candles.gltf", 1.0, 0.5, False),
}

REGIONS = [
    {
        "id": "keep", "node": "RuinedKeep", "victory": "The keep stands empty", "item_level": 10,
        "tint": (0.9, 0.88, 0.86), "music": "crypt",
        "torch": ((1.0, 0.55, 0.25), (1.0, 0.85, 0.5), (1.0, 0.35, 0.1)),
        "moon": ((0.62, 0.66, 0.82), 0.55),
        "env": {"background": (0.03, 0.025, 0.03), "ambient": (0.46, 0.42, 0.44), "energy": 0.36},
        "far_props": ["pillar", "banner", "weaponrack"], "near_props": ["barrel", "crate", "skull"],
        "basic": ["skeleton", "skeleton", "knight"], "ranged": "cultist", "elite": "knight",
        "rooms": [
            ("Barracks", (20, 16), "The Barracks", "The garrison never left"),
            ("Courtyard", (24, 24), "The Broken Courtyard", "Ash falls where banners flew"),
            ("Armoury", (16, 20), "The Armoury", "Every blade remembers a hand"),
        ],
        "hall": ("Hall", (28, 28), "The Great Hall", "The Iron Castellan holds the keep"),
        "boss": {"file": "iron_castellan", "base": "ashen_lord", "title": "THE IRON CASTELLAN", "health": 900,
                 "ash": 70, "xp": 700, "gold": 140, "add": "knight", "summons": 2,
                 "albedo": (0.55, 0.58, 0.66), "emission": (0.55, 0.75, 1.0), "glow": 0.35,
                 "texture": "res://assets/third_party/kaykit/characters/warden_texture.png"},
    },
    {
        "id": "forest", "node": "CursedForest", "victory": "The forest falls still", "item_level": 14,
        "tint": (0.62, 0.76, 0.58), "music": "catacombs",
        "torch": ((0.45, 1.0, 0.55), (0.8, 1.0, 0.7), (0.2, 0.75, 0.3)),
        "moon": ((0.55, 0.85, 0.65), 0.5),
        "env": {"background": (0.01, 0.03, 0.02), "ambient": (0.32, 0.48, 0.36), "energy": 0.38},
        "far_props": ["dead_tree", "pine", "dead_tree_small"], "near_props": ["gravestone", "grave", "fence", "lantern"],
        "basic": ["ghoul", "ghoul", "skeleton"], "ranged": "cultist", "elite": "knight",
        "rooms": [
            ("Thicket", (20, 20), "The Thorn Thicket", "The trees lean closer"),
            ("Graveyard", (24, 20), "The Drowned Graveyard", "Moss over every name"),
            ("Hollow", (20, 24), "The Witch's Hollow", "Lanterns where no one walks"),
        ],
        "hall": ("Grove", (28, 28), "The Rotwood Grove", "The Rotwood Witch is waiting"),
        "boss": {"file": "rotwood_witch", "base": "hollow_king", "title": "THE ROTWOOD WITCH", "health": 1000,
                 "ash": 80, "xp": 800, "gold": 160, "add": "ghoul", "summons": 4,
                 "albedo": (0.45, 0.62, 0.4), "emission": (0.45, 1.0, 0.4), "glow": 0.4,
                 "texture": "res://assets/third_party/kaykit/characters/Skeleton_Mage_skeleton_texture.png"},
    },
    {
        "id": "volcano", "node": "VolcanicDepths", "victory": "The fires gutter out", "item_level": 18,
        "tint": (0.62, 0.42, 0.38), "music": "crypt",
        "torch": ((1.0, 0.35, 0.1), (1.0, 0.75, 0.3), (1.0, 0.2, 0.05)),
        "moon": ((1.0, 0.45, 0.25), 0.55),
        "env": {"background": (0.05, 0.012, 0.005), "ambient": (0.55, 0.3, 0.22), "energy": 0.4},
        "far_props": ["rock_tall", "pillar", "rock_tall"], "near_props": ["boulder", "rock", "ribcage", "skull"],
        "basic": ["demon", "imp", "demon"], "ranged": "imp", "elite": "demon",
        "rooms": [
            ("Forge", (20, 16), "The Slag Forge", "The anvils still ring"),
            ("Rift", (24, 24), "The Burning Rift", "Something climbs from below"),
            ("Pits", (16, 20), "The Brimstone Pits", "The air itself bites"),
        ],
        "hall": ("Throne", (28, 28), "The Molten Throne", "The Cinder Tyrant wakes"),
        "boss": {"file": "cinder_tyrant", "base": "ashen_lord", "title": "THE CINDER TYRANT", "health": 1150,
                 "ash": 90, "xp": 900, "gold": 180, "add": "imp", "summons": 4,
                 "albedo": (0.42, 0.1, 0.08), "emission": (1.0, 0.35, 0.05), "glow": 0.6,
                 "texture": "res://assets/third_party/kaykit/characters/Knight_knight_texture.png", "horns": True},
    },
    {
        "id": "temple", "node": "AncientTemple", "victory": "The temple is silent", "item_level": 22,
        "tint": (1.08, 0.95, 0.72), "music": "crypt",
        "torch": ((1.0, 0.8, 0.4), (1.0, 0.95, 0.7), (1.0, 0.6, 0.2)),
        "moon": ((1.0, 0.9, 0.7), 0.6),
        "env": {"background": (0.04, 0.03, 0.015), "ambient": (0.55, 0.48, 0.36), "energy": 0.38},
        "far_props": ["column", "shrine", "stone_pillar"], "near_props": ["plaque", "candles", "coffin", "skull"],
        "basic": ["skeleton", "imp", "skeleton"], "ranged": "cultist", "elite": "knight",
        "rooms": [
            ("Vestibule", (20, 16), "The Sunken Vestibule", "Sand in the prayers"),
            ("Colonnade", (24, 24), "The Colonnade of Oaths", "Each pillar a broken vow"),
            ("Sanctum", (16, 20), "The Inner Sanctum", "The candles never burn down"),
        ],
        "hall": ("Altar", (28, 28), "The Sunless Altar", "The Oracle sees you"),
        "boss": {"file": "sunless_oracle", "base": "hollow_king", "title": "THE SUNLESS ORACLE", "health": 1300,
                 "ash": 100, "xp": 1000, "gold": 200, "add": "skeleton", "summons": 4,
                 "albedo": (0.8, 0.68, 0.4), "emission": (1.0, 0.8, 0.3), "glow": 0.45,
                 "texture": "res://assets/third_party/kaykit/characters/Skeleton_Mage_skeleton_texture.png"},
    },
    {
        "id": "ice", "node": "IceWastes", "victory": "The wind dies down", "item_level": 26,
        "tint": (0.82, 0.92, 1.12), "music": "catacombs",
        "torch": ((0.6, 0.85, 1.0), (0.9, 1.0, 1.0), (0.35, 0.6, 1.0)),
        "moon": ((0.75, 0.88, 1.0), 0.7),
        "env": {"background": (0.02, 0.03, 0.05), "ambient": (0.5, 0.58, 0.7), "energy": 0.42},
        "far_props": ["pine_small", "rock_tall", "pine"], "near_props": ["boulder", "rock", "bone", "gravestone"],
        "basic": ["ghoul", "skeleton", "demon"], "ranged": "cultist", "elite": "knight",
        "rooms": [
            ("Pass", (20, 16), "The Frozen Pass", "The cold has teeth"),
            ("Field", (24, 24), "The Field of the Fallen", "They froze where they fought"),
            ("Barrow", (16, 20), "The Rime Barrow", "Breath hangs and does not fade"),
        ],
        "hall": ("Throne", (28, 28), "The Rime Throne", "The Rime King stirs"),
        "boss": {"file": "rime_king", "base": "hollow_king", "title": "THE RIME KING", "health": 1450,
                 "ash": 110, "xp": 1100, "gold": 220, "add": "ghoul", "summons": 4,
                 "albedo": (0.72, 0.85, 1.0), "emission": (0.6, 0.85, 1.0), "glow": 0.5,
                 "texture": "res://assets/third_party/kaykit/characters/Skeleton_Mage_skeleton_texture.png"},
    },
]
PROPS["bone"] = ("res://assets/third_party/kaykit/halloween/ribcage.gltf", 1.0, 0.0, False)

CORRIDOR = (4, 8)
MARKERS = ["North", "NorthEast", "NorthWest", "East", "West", "SouthEast", "SouthWest"]


def col(c) -> str:
    return "Color(%s, %s, %s, 1)" % tuple(round(x, 3) for x in c)


def xform(x: float, y: float, z: float, s: float = 1.0, turn: int = 0) -> str:
    import math
    c, n = math.cos(turn * math.pi / 2) * s, math.sin(turn * math.pi / 2) * s
    def f(v: float) -> str:
        v = round(v, 4)
        return "0" if v == 0 else str(v)
    return f"Transform3D({f(c)}, 0, {f(-n)}, 0, {f(s)}, 0, {f(n)}, 0, {f(c)}, {f(x)}, {f(y)}, {f(z)})"


def markers(w: int, h: int) -> dict:
    hx, hz = w / 2 - 3, h / 2 - 3
    return {"North": (0, -hz), "NorthEast": (hx, -hz + 1), "NorthWest": (-hx, -hz + 1), "East": (hx, 0),
            "West": (-hx, 0), "SouthEast": (hx - 1, hz), "SouthWest": (-hx + 1, hz)}


def waves(region: dict, room: int) -> list:
    b, r, e = region["basic"], region["ranged"], region["elite"]
    if room == 0:
        return [[(b[0], "NorthEast"), (b[1], "NorthWest"), (b[0], "East"), (b[1], "West")],
                [(b[2], "North"), (r, "NorthEast"), (b[0], "SouthEast"), (b[1], "SouthWest")]]
    if room == 1:
        return [[(b[0], "North"), (b[1], "East"), (b[0], "West"), (r, "NorthEast"), (r, "NorthWest")],
                [(b[1], "NorthEast"), (b[0], "NorthWest"), (b[2], "East"), (b[1], "West")],
                [(e, "North"), (r, "NorthEast"), (r, "NorthWest")]]
    return [[(b[0], "North"), (b[1], "NorthEast"), (b[0], "NorthWest"), (b[1], "East"), (b[2], "West")],
            [(e, "NorthEast"), (b[0], "NorthWest"), (b[1], "SouthEast"), (b[0], "SouthWest")],
            [(e, "North"), (r, "East"), (r, "West"), (b[2], "NorthEast")]]


def encounter_tres(wave_list: list) -> str:
    kinds = sorted({kind for wave in wave_list for kind, _ in wave})
    ids = {kind: f"{i + 3}_{kind}" for i, kind in enumerate(kinds)}
    out = ['[gd_resource type="Resource" script_class="EncounterData" format=3]', "",
           '[ext_resource type="Script" path="res://scripts/encounters/encounter_data.gd" id="1_encounter"]',
           '[ext_resource type="Script" path="res://scripts/encounters/wave_data.gd" id="2_wave"]']
    for kind in kinds:
        path = ENEMIES[kind] if kind in ENEMIES else kind
        out.append(f'[ext_resource type="PackedScene" path="{path}" id="{ids[kind]}"]')
    for i, wave in enumerate(wave_list):
        enemies = ", ".join(f'ExtResource("{ids[k]}")' for k, _ in wave)
        marks = ", ".join(f'"{m}"' for _, m in wave)
        out += ["", f'[sub_resource type="Resource" id="Resource_wave{i + 1}"]', 'script = ExtResource("2_wave")',
                f"enemies = Array[PackedScene]([{enemies}])", f"markers = PackedStringArray({marks})"]
    subs = ", ".join(f'SubResource("Resource_wave{i + 1}")' for i in range(len(wave_list)))
    out += ["", "[resource]", 'script = ExtResource("1_encounter")',
            f'waves = Array[ExtResource("2_wave")]([{subs}])']
    if len(wave_list) == 1:
        out.append("rise_time = 2.0")
    return "\n".join(out) + "\n"


def environment_tres(env: dict) -> str:
    return f"""[gd_resource type="Environment" format=3]

[resource]
background_mode = 1
background_color = {col(env["background"])}
ambient_light_source = 2
ambient_light_color = {col(env["ambient"])}
ambient_light_energy = {env["energy"]}
tonemap_mode = 4
tonemap_exposure = 1.08
glow_enabled = true
glow_levels/1 = 1.0
glow_levels/2 = 1.0
glow_levels/3 = 0.8
glow_levels/5 = 0.0
glow_intensity = 0.85
glow_strength = 1.1
glow_bloom = 0.08
glow_blend_mode = 1
glow_hdr_threshold = 0.85
fog_enabled = false
adjustment_enabled = true
adjustment_contrast = 1.12
adjustment_saturation = 1.08
"""


def boss_files(boss: dict) -> tuple[str, str]:
    material = f"""[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="{boss["texture"]}" id="1_tex"]

[resource]
albedo_color = {col(boss["albedo"])}
albedo_texture = ExtResource("1_tex")
metallic = 0.3
roughness = 0.6
emission_enabled = true
emission = {col(boss["emission"])}
emission_energy_multiplier = {boss["glow"]}
emission_operator = 1
emission_texture = ExtResource("1_tex")
"""
    horns = ""
    extra_ext = ""
    extra_sub = ""
    if boss.get("horns"):
        extra_ext = '[ext_resource type="Material" path="res://resources/materials/demon_horn.tres" id="5_horn"]\n'
        extra_sub = """
[sub_resource type="CylinderMesh" id="CylinderMesh_horn"]
material = ExtResource("5_horn")
top_radius = 0.0
bottom_radius = 0.1
height = 0.7
radial_segments = 8
rings = 1
"""
        horns = """
[node name="Head" type="BoneAttachment3D" parent="Visual/Model/Rig/Skeleton3D"]
bone_name = "head"

[node name="HornLeft" type="MeshInstance3D" parent="Visual/Model/Rig/Skeleton3D/Head"]
transform = Transform3D(0.94, -0.34, 0, 0.34, 0.94, 0, 0, 0, 1, -0.34, 0.95, -0.02)
cast_shadow = 0
mesh = SubResource("CylinderMesh_horn")

[node name="HornRight" type="MeshInstance3D" parent="Visual/Model/Rig/Skeleton3D/Head"]
transform = Transform3D(0.94, 0.34, 0, -0.34, 0.94, 0, 0, 0, 1, 0.34, 0.95, -0.02)
cast_shadow = 0
mesh = SubResource("CylinderMesh_horn")
"""
    name = "".join(part.title() for part in boss["file"].split("_"))
    scene = f"""[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/enemies/{boss["base"]}.tscn" id="1_base"]
[ext_resource type="Material" path="res://resources/materials/{boss["file"]}_model.tres" id="2_material"]
[ext_resource type="PackedScene" path="{ENEMIES[boss["add"]]}" id="3_add"]
{extra_ext}{extra_sub}
[node name="{name}" instance=ExtResource("1_base")]
display_title = "{boss["title"]}"
add_scene = ExtResource("3_add")
summon_count = {boss["summons"]}
ash_value = {boss["ash"]}
xp_value = {boss["xp"]}
gold_value = {boss["gold"]}

[node name="Health" parent="."]
max_health = {boss["health"]}

[node name="ModelDressing" parent="."]
material = ExtResource("2_material")
{horns}"""
    return material, scene


class Scene:
    def __init__(self) -> None:
        self.ext: list[str] = []
        self.sub: list[str] = []
        self.nodes: list[str] = []
        self.ids: dict[str, str] = {}

    def ext_id(self, kind: str, path: str) -> str:
        if path not in self.ids:
            self.ids[path] = f"{len(self.ids) + 1}_r"
            self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{self.ids[path]}"]')
        return self.ids[path]

    def node(self, text: str) -> None:
        self.nodes.append(text.strip("\n"))

    def text(self) -> str:
        return "\n".join(["[gd_scene format=3]", ""] + self.ext + [""] + self.sub + [""]
                         + ["\n\n".join(self.nodes)]) + "\n"


def level_tscn(region: dict) -> str:
    rid = region["id"]
    sc = Scene()
    level = sc.ext_id("Script", "res://scripts/world/level.gd")
    env = sc.ext_id("Environment", f"res://resources/environment/{rid}_environment.tres")
    env_compat = sc.ext_id("Environment", "res://resources/environment/arena_environment_compatibility.tres")
    lighting = sc.ext_id("Script", "res://scripts/world/renderer_lighting.gd")
    nav = sc.ext_id("Script", "res://scripts/world/baked_navigation_region.gd")
    navmesh = sc.ext_id("NavigationMesh", "res://resources/navigation/ground_navigation_mesh.tres")
    room_script = sc.ext_id("Script", "res://scripts/dungeon/crypt_room.gd")
    gate = sc.ext_id("PackedScene", "res://scenes/dungeon/crypt_gate.tscn")
    combat = sc.ext_id("Script", "res://scripts/dungeon/combat_room.gd")
    encounter_script = sc.ext_id("Script", "res://scripts/encounters/encounter_controller.gd")
    flame = sc.ext_id("Script", "res://scripts/presentation/flame_fx.gd")

    rooms = [("Stairwell", (12, 12), None, None)] + region["rooms"] + [region["hall"]]
    # Lay the chain out northward: each room's centre and the corridor after it.
    layout = []
    z = 0.0
    for i, (name, (w, h), _title, _sub) in enumerate(rooms):
        if i > 0:
            z -= h / 2.0
        layout.append((name, w, h, z))
        if i < len(rooms) - 1:
            corridor_z = z - h / 2.0 - CORRIDOR[1] / 2.0
            layout.append((f"Corridor{i + 1}", CORRIDOR[0], CORRIDOR[1], corridor_z))
            z = corridor_z - CORRIDOR[1] / 2.0
    fighting = [name for name, *_ in region["rooms"]] + [region["hall"][0]]
    torch_light, torch_core, torch_edge = region["torch"]

    sc.node(f"""[node name="{region['node']}" type="Node3D" node_paths=PackedStringArray("player_start", "encounters")]
script = ExtResource("{level}")
player_start = NodePath("PlayerStart")
encounters = [{", ".join(f'NodePath("Encounters/{n}")' for n in fighting)}]
victory_title = "{region['victory']}"
item_level = {region['item_level']}
world_tint = {col(region['tint'])}""")
    sc.node(f"""[node name="PlayerStart" type="Marker3D" parent="."]
transform = {xform(0, 0, 3)}""")
    sc.node(f"""[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = ExtResource("{env}")""")
    moon_color, moon_energy = region["moon"]
    sc.node(f"""[node name="Moonlight" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.7880108, 0.48514786, -0.37903908, 0, 0.6156615, 0.7880107, 0.6156615, -0.62096095, 0.4851479, 0, 12, 0)
light_color = {col(moon_color)}
light_energy = {moon_energy}
shadow_enabled = true
directional_shadow_mode = 0
directional_shadow_max_distance = 60.0""")
    sc.node(f"""[node name="RendererLighting" type="Node" parent="." node_paths=PackedStringArray("world_environment", "moonlight")]
script = ExtResource("{lighting}")
world_environment = NodePath("../WorldEnvironment")
moonlight = NodePath("../Moonlight")
compatibility_environment = ExtResource("{env_compat}")
compatibility_moonlight_energy = 0.45""")
    sc.node(f"""[node name="Navigation" type="NavigationRegion3D" parent="."]
navigation_mesh = ExtResource("{navmesh}")
script = ExtResource("{nav}")""")
    sc.node('[node name="Rooms" type="Node3D" parent="Navigation"]')
    seed = sum(ord(c) for c in rid)
    last = len(layout) - 1
    for i, (name, w, h, rz) in enumerate(layout):
        corridor = name.startswith("Corridor")
        north = 2 if corridor else (1 if i < last else 0)
        south = 2 if corridor else (1 if i > 0 else 0)
        lines = [f'[node name="{name}" type="Node3D" parent="Navigation/Rooms"]', f"transform = {xform(0, 0, rz)}",
                 f'script = ExtResource("{room_script}")', f"size = Vector2i({w}, {h})"]
        if north:
            lines.append(f"north = {north}")
        if south:
            lines.append(f"south = {south}")
        lines += [f"seed = {seed + i}", f"torch_light_color = {col(torch_light)}",
                  f"torch_core_color = {col(torch_core)}", f"torch_edge_color = {col(torch_edge)}"]
        sc.node("\n".join(lines))
    sc.node('[node name="Gates" type="Node3D" parent="Navigation"]')
    rooms_only = [(n, w, h, rz) for n, w, h, rz in layout if not n.startswith("Corridor")]
    for i, (name, w, h, rz) in enumerate(rooms_only[:-1]):
        lines = [f'[node name="{name}" parent="Navigation/Gates" instance=ExtResource("{gate}")]',
                 f"transform = {xform(0, 0, rz - h / 2.0 - 0.5)}"]
        if i == 0:
            lines.append("open = true")
        sc.node("\n".join(lines))
    # Props: tall ones against the far (north and west) walls, short ones by
    # the near walls, clear of the doorways in the middle of the north and
    # south sides.
    sc.node('[node name="Props" type="Node3D" parent="Navigation"]')
    shapes = {}
    count = 0
    for r_index, (name, w, h, rz) in enumerate(rooms_only[1:]):
        hx, hz = w / 2.0, h / 2.0
        spots = [((-hx + 2.0, -hz + 2.0), True), ((hx - 2.0, -hz + 2.0), True), ((-6.0 if w > 16 else -4.5, -hz + 1.6), True),
                 ((-hx + 1.6, -2.0), True), ((-hx + 1.6, hz - 4.0), True),
                 ((hx - 1.6, -hz / 2.0), False), ((hx - 1.8, hz - 2.0), False), ((-hx + 2.4, hz - 1.6), False),
                 ((6.0 if w > 16 else 4.5, hz - 1.6), False)]
        for s_index, ((px, pz), far) in enumerate(spots):
            pool = region["far_props"] if far else region["near_props"]
            kind = pool[(s_index + r_index) % len(pool)]
            path, scale, radius, _tall = PROPS[kind]
            model = sc.ext_id("PackedScene", path)
            count += 1
            node_name = f"{name}Prop{s_index + 1}"
            turn = (s_index * 3 + r_index) % 4
            if radius > 0:
                shape_id = f"CylinderShape3D_{str(radius).replace('.', '_')}"
                if shape_id not in shapes:
                    shapes[shape_id] = True
                    sc.sub.append(f'[sub_resource type="CylinderShape3D" id="{shape_id}"]\nheight = 3.0\nradius = {radius}\n')
                sc.node(f"""[node name="{node_name}" type="StaticBody3D" parent="Navigation/Props"]
transform = {xform(px, 0, rz + pz)}

[node name="CollisionShape3D" type="CollisionShape3D" parent="Navigation/Props/{node_name}"]
transform = {xform(0, 1.5, 0)}
shape = SubResource("{shape_id}")

[node name="Model" parent="Navigation/Props/{node_name}" instance=ExtResource("{model}")]
transform = {xform(0, 0, 0, scale, turn)}""")
            else:
                sc.node(f"""[node name="{node_name}" parent="Navigation/Props" instance=ExtResource("{model}")]
transform = {xform(px, 0, rz + pz, scale, turn)}""")
    # A brazier fire in each fighting room's far corners, without lights (the
    # torches light the room).
    sc.node('[node name="Fires" type="Node3D" parent="."]')
    for name, w, h, rz in rooms_only[1:]:
        for side, x in (("W", -w / 2.0 + 2.0), ("E", w / 2.0 - 2.0)):
            sc.node(f"""[node name="{name}{side}" type="Node3D" parent="Fires"]
transform = {xform(x, 2.2, rz - h / 2.0 + 2.0)}
script = ExtResource("{flame}")
size = 0.6
core_color = {col(torch_core)}
edge_color = {col(torch_edge)}
ember_count = 8""")
    # Encounters, at each fighting room's centre.
    sc.node('[node name="Encounters" type="Node3D" parent="."]')
    titles = {name: (title, sub) for name, _size, title, sub in region["rooms"] + [region["hall"]]}
    for e_index, (name, w, h, rz) in enumerate(rooms_only[1:]):
        data = sc.ext_id("Resource", f"res://resources/encounters/{rid}_{name.lower()}.tres")
        title, sub = titles[name]
        boss = e_index == len(rooms_only) - 2
        lines = [f'[node name="{name}" type="Node3D" parent="Encounters"]', f"transform = {xform(0, 0, rz)}",
                 f'script = ExtResource("{encounter_script}")', f'data = ExtResource("{data}")',
                 f'title = "{title}"', f'subtitle = "{sub}"']
        if boss:
            lines.append(f"title_color = {col(region['boss']['emission'])}")
        sc.node("\n".join(lines))
        points = markers(w, h)
        for marker in MARKERS:
            mx, mz = points[marker]
            sc.node(f"""[node name="{marker}" type="Marker3D" parent="Encounters/{name}"]
transform = {xform(mx, 0, mz)}""")
        if boss:
            reach = w / 2.0 - 6.5
            for corner, (sx, sz) in {"SummonNW": (-1, -1), "SummonNE": (1, -1), "SummonSW": (-1, 1), "SummonSE": (1, 1)}.items():
                sc.node(f"""[node name="{corner}" type="Marker3D" parent="Encounters/{name}"]
transform = {xform(sx * reach, 0, sz * reach)}""")
    # The rooms that seal while their fight lasts.
    sc.node('[node name="CombatRooms" type="Node3D" parent="."]')
    for index, (name, w, h, rz) in enumerate(rooms_only[1:]):
        shape_id = f"BoxShape3D_{name}"
        sc.sub.append(f'[sub_resource type="BoxShape3D" id="{shape_id}"]\nsize = Vector3({w}, 3, {h - 2})\n')
        previous = rooms_only[index][0]
        paths = ["encounter", "seal_gates"] + (["exit_gates"] if index < len(rooms_only) - 2 else [])
        lines = [f'[node name="{name}" type="Area3D" parent="CombatRooms" node_paths=PackedStringArray({", ".join(chr(34) + p + chr(34) for p in paths)})]',
                 f"transform = {xform(0, 1.5, rz - 1)}", f'script = ExtResource("{combat}")',
                 f'encounter = NodePath("../../Encounters/{name}")',
                 f'seal_gates = [NodePath("../../Navigation/Gates/{previous}")]']
        if "exit_gates" in paths:
            lines.append(f'exit_gates = [NodePath("../../Navigation/Gates/{name}")]')
        sc.node("\n".join(lines) + f"""

[node name="CollisionShape3D" type="CollisionShape3D" parent="CombatRooms/{name}"]
shape = SubResource("{shape_id}")""")
    return sc.text()


def main() -> None:
    (GAME / "scenes/enemies/bosses").mkdir(parents=True, exist_ok=True)
    for region in REGIONS:
        rid = region["id"]
        (GAME / f"resources/environment/{rid}_environment.tres").write_text(environment_tres(region["env"]))
        for index, (name, *_rest) in enumerate(region["rooms"]):
            (GAME / f"resources/encounters/{rid}_{name.lower()}.tres").write_text(encounter_tres(waves(region, index)))
        boss = region["boss"]
        boss_scene = f"res://scenes/enemies/bosses/{boss['file']}.tscn"
        ENEMIES[boss["file"]] = boss_scene
        hall = region["hall"][0]
        (GAME / f"resources/encounters/{rid}_{hall.lower()}.tres").write_text(encounter_tres([[(boss["file"], "North")]]))
        material, scene = boss_files(boss)
        (GAME / f"resources/materials/{boss['file']}_model.tres").write_text(material)
        (GAME / f"scenes/enemies/bosses/{boss['file']}.tscn").write_text(scene)
        (GAME / f"scenes/dungeon/{rid}.tscn").write_text(level_tscn(region))
        print(f"{rid}: written")


if __name__ == "__main__":
    main()
