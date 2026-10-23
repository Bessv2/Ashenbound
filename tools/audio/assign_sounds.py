#!/usr/bin/env python3
"""Writes the sound cues into the game's scenes and resources.

Each attack resource gets its windup and swing sounds, each ability its
sound, each projectile its impact, and each character scene a CharacterSounds
node. Running it again changes nothing that is already set, so it is the
record of which object makes which sound; docs/AUDIO.md explains the choices.

Usage: tools/audio/assign_sounds.py
"""

from __future__ import annotations

import re
from pathlib import Path

GAME = Path(__file__).resolve().parents[2] / "game"

# Attack resource -> (windup sound, swing sound, pitch).
ATTACKS = {
    "combat/player_basic_attack": ("", "swing_heavy", 0.95),
    "combat/warden_cleave": ("", "swing_heavy", 0.78),
    "combat/warden_guard_counter": ("", "parry", 1.0),
    "combat/reaver_twin_slash": ("", "swing_light", 1.0),
    "combat/reaver_fan": ("", "blade_fan", 1.0),
    "combat/reliquary_flail": ("", "swing_spear", 0.8),
    "combat/hexbinder_bolt": ("", "spell_cast", 0.85),
    "combat/dreadhunter_bolt": ("", "crossbow_shot", 1.0),
    "combat/gravecaller_bolt": ("", "spell_cast", 0.7),
    "combat/forsaken_claw": ("", "claw", 1.1),
    "enemies/skeleton_warrior_attack": ("", "swing_heavy", 1.1),
    "enemies/ghoul_claw": ("", "claw", 1.0),
    "enemies/dark_cultist_bolt": ("ghost_breath", "spell_cast", 0.75),
    "enemies/fallen_knight_cleave": ("blade_draw", "swing_heavy", 0.8),
    "enemies/fallen_knight_bash": ("guard_brace", "swing_heavy", 0.7),
    "enemies/ashen_lord_cinder_cleave": ("blade_draw", "swing_heavy", 0.65),
    "enemies/ashen_lord_ash_slam": ("fire_cast", "stone_break", 0.8),
    "enemies/ashen_lord_ember_ring": ("fire_cast", "explosion", 0.8),
    "enemies/hollow_king_soul_volley": ("ghost_moan", "spell_cast", 0.6),
    "enemies/hollow_king_grave_spikes": ("earth_rise", "stone_break", 0.9),
    "enemies/hollow_king_soul_nova": ("ghost_breath", "explosion", 0.7),
}

# Scene -> node name -> sound (abilities).
ABILITIES = {
    "player/warden": {"Guard": "guard_brace", "Brand": "fire_cast"},
    "player/reaver": {"VeilRend": "dark_magic", "Hemorrhage": "bleed"},
    "player/hexbinder": {"BlackTestament": "dark_magic", "Grasp": "earth_rise", "Unmake": "drain"},
    "player/dreadhunter": {"Deadfall": "crossbow_load", "ChargedShot": "crossbow_load", "Raven": "crow"},
    "player/reliquary": {"Benediction": "holy_heal", "Lantern": "bell", "Judgment": "stone_break"},
    "player/gravecaller": {"RaiseForsaken": "raise_dead", "WraithSwarm": "ghost_moan", "SoulHarvest": "drain"},
}

PROJECTILES = {
    "combat/crossbow_bolt": "hit_stone",
    "combat/hex_bolt": "frost",
    "combat/shadow_bolt": "dark_magic",
    "combat/soul_bolt": "frost",
}

HERO = {"impact": "hit_flesh", "hurt": "hero_hurt", "hurt_chance": 0.6, "death": "hero_death", "footsteps": "footstep"}
# Scene -> CharacterSounds properties.
CHARACTERS = {
    "player/warden": HERO | {"pitch": 0.95},
    "player/reaver": HERO | {"pitch": 1.05},
    "player/hexbinder": HERO,
    "player/dreadhunter": HERO | {"pitch": 1.05},
    "player/reliquary": HERO | {"pitch": 0.95},
    "player/gravecaller": HERO,
    "player/forsaken_skeleton": {"impact": "hit_bone", "death_layer": "bones_collapse", "pitch": 1.1},
    "enemies/skeleton_warrior": {"impact": "hit_bone", "death": "undead_death", "death_layer": "bones_collapse",
                                 "growl": "undead_growl", "growl_chance": 0.35},
    "enemies/dark_cultist": {"impact": "hit_bone", "death": "ghost_moan", "death_layer": "bones_collapse", "pitch": 1.1},
    "enemies/fallen_knight": {"impact": "hit_metal", "death": "undead_death", "death_layer": "armor_fall",
                              "growl": "undead_growl", "growl_chance": 0.5, "pitch": 0.78},
    "enemies/ghoul": {"impact": "hit_bone", "hurt": "ghoul_hurt", "hurt_chance": 0.4, "death": "ghoul_death",
                      "growl": "ghoul_snarl", "growl_chance": 0.5, "pitch": 1.15},
    "enemies/ashen_lord": {"impact": "hit_metal", "death": "giant_roar", "death_layer": "stone_break", "pitch": 0.7},
    "enemies/hollow_king": {"impact": "hit_bone", "death": "ghost_moan", "death_layer": "stone_break", "pitch": 0.6},
    "enemies/training_dummy": {"impact": "hit_stone", "death": "stone_break"},
}

SCRIPT_PATH = "res://scripts/audio/character_sounds.gd"


def value(v) -> str:
    if isinstance(v, str):
        return f'&"{v}"'
    if isinstance(v, float):
        return repr(v)
    return str(v)


def set_property(text: str, header: re.Pattern, key: str, val: str) -> str:
    """Sets `key = val` in the section whose header matches."""
    match = header.search(text)
    if not match:
        raise SystemExit(f"no section {header.pattern}")
    start = match.end()
    end = text.find("\n[", start)
    end = len(text) if end < 0 else end
    body = text[start:end]
    line = re.compile(rf"^{re.escape(key)} = .*$", re.M)
    if line.search(body):
        body = line.sub(f"{key} = {val}", body)
    else:
        # Under the script line (script exports only exist once it is set),
        # else right under the header.
        script = re.search(r"^script = .*$", body, re.M)
        at = script.end() if script else 0
        body = body[:at] + f"\n{key} = {val}" + body[at:]
    return text[:start] + body + text[end:]


def main() -> None:
    for name, (windup, swing, pitch) in ATTACKS.items():
        path = GAME / f"resources/{name}.tres"
        text = path.read_text()
        resource = re.compile(r"^\[resource\]$", re.M)
        if windup:
            text = set_property(text, resource, "windup_sound", value(windup))
        text = set_property(text, resource, "swing_sound", value(swing))
        if pitch != 1.0:
            text = set_property(text, resource, "sound_pitch", value(pitch))
        path.write_text(text)
    for name, nodes in ABILITIES.items():
        path = GAME / f"scenes/{name}.tscn"
        text = path.read_text()
        for node, sound in nodes.items():
            text = set_property(text, re.compile(rf'^\[node name="{node}" [^\n]*parent="\."[^\n]*\]$', re.M), "sound", value(sound))
        path.write_text(text)
    for name, sound in PROJECTILES.items():
        path = GAME / f"scenes/{name}.tscn"
        text = path.read_text()
        text = set_property(text, re.compile(r'^\[node name="[^"]+" type="Node3D"\]$', re.M), "impact_sound", value(sound))
        path.write_text(text)
    for name, props in CHARACTERS.items():
        path = GAME / f"scenes/{name}.tscn"
        text = path.read_text()
        if SCRIPT_PATH not in text:
            # A new external resource for the script, and the node at the end.
            text = re.sub(r"^(\[gd_scene[^\n]*\])$", r"\1", text, count=1, flags=re.M)
            ext = f'[ext_resource type="Script" path="{SCRIPT_PATH}" id="sounds_script"]\n'
            last_ext = list(re.finditer(r"^\[ext_resource[^\n]*\]$", text, re.M))[-1]
            text = text[:last_ext.end()] + "\n" + ext.rstrip("\n") + text[last_ext.end():]
            text = text.rstrip("\n") + '\n\n[node name="Sounds" type="Node" parent="."]\nscript = ExtResource("sounds_script")\n'
            text = re.sub(r'(\[gd_scene[^\]]*?)load_steps=(\d+)', lambda m: f"{m.group(1)}load_steps={int(m.group(2)) + 1}", text, count=1)
        sounds = re.compile(r'^\[node name="Sounds" type="Node" parent="\."\]$', re.M)
        for key, val in props.items():
            text = set_property(text, sounds, key, value(val))
        path.write_text(text)
    print("sounds assigned")


if __name__ == "__main__":
    main()
