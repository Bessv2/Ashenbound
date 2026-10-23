#!/usr/bin/env python3
"""Writes which motion-captured clip each character plays in looks A and B.

Sets the `mocap_*` exports on the Animator node of each hero and enemy scene
(see CharacterAnimator). "A|B" alternates clips blow by blow; "" keeps the
KayKit clip. Running it again changes nothing. The clips are the "mocap"
library made by tools/anim/retarget_ual.gd; docs/ANIMATION.md explains the
choices.

Usage: tools/anim/assign_mocap.py
"""

from __future__ import annotations

import re
from pathlib import Path

GAME = Path(__file__).resolve().parents[2] / "game"

SWORD_COMBO = "Sword_Regular_A|Sword_Regular_B"
HIT = "Hit_Chest|Hit_Head"
CAST = "Spell_Simple_Shoot"

# Scene -> exports. Lists follow the Animator's attacks and abilities order.
CHARACTERS = {
    "player/warden": {"attacks": [SWORD_COMBO, "Sword_Attack"], "abilities": ["Sword_Block", CAST],
                      "hit": HIT, "death": "Death01"},
    "player/reaver": {"attacks": ["Sword_Regular_A|Melee_Hook|Sword_Regular_B", "OverhandThrow"],
                      "abilities": ["Sword_Dash", "Sword_Regular_B"], "hit": HIT, "death": "Death01"},
    "player/hexbinder": {"attacks": [CAST], "abilities": ["Spell_Simple_Enter", "Spell_Simple_Enter", CAST],
                         "hit": HIT, "death": "Death01"},
    # The crossbow keeps its KayKit clips: the library has no crossbow.
    "player/dreadhunter": {"attacks": [""], "abilities": ["OverhandThrow", "", "Spell_Simple_Enter"],
                           "hit": HIT, "death": "Death01"},
    "player/reliquary": {"attacks": [SWORD_COMBO], "abilities": ["Spell_Simple_Enter", "Spell_Simple_Enter", "Sword_Attack"],
                         "hit": HIT, "death": "Death01"},
    "player/gravecaller": {"attacks": [CAST], "abilities": ["Spell_Simple_Enter", CAST, "Spell_Simple_Enter"],
                           "hit": HIT, "death": "Death01"},
    "player/forsaken_skeleton": {"attacks": [SWORD_COMBO]},
    "enemies/skeleton_warrior": {"attacks": [SWORD_COMBO], "hit": HIT},
    "enemies/ghoul": {"attacks": ["Zombie_Scratch"], "idle": "Zombie_Idle_Loop", "run": "Zombie_Walk_Fwd_Loop",
                      "hit": "Hit_Knockback"},
    "enemies/dark_cultist": {"attacks": [CAST], "hit": HIT},
    "enemies/fallen_knight": {"attacks": ["Sword_Attack", "Shield_OneShot"], "idle": "Idle_Shield_Loop", "hit": HIT},
    "enemies/ashen_lord": {"attacks": ["Sword_Attack", "Sword_Regular_C", ""]},
    "enemies/hollow_king": {"attacks": [CAST, "", ""]},
    "enemies/demon": {"attacks": ["Zombie_Scratch|Punch_Cross", "Sword_Attack"], "hit": HIT},
    "enemies/imp": {"attacks": [CAST], "hit": HIT},
}


def value(v) -> str:
    if isinstance(v, list):
        return "Array[String]([" + ", ".join(f'"{x}"' for x in v) + "])"
    return f'"{v}"'


def main() -> None:
    for name, props in CHARACTERS.items():
        path = GAME / f"scenes/{name}.tscn"
        text = path.read_text()
        header = re.search(r'^\[node name="Animator" [^\n]*\]$', text, re.M)
        if not header:
            raise SystemExit(f"{name}: no Animator")
        start = header.end()
        end = text.find("\n[", start)
        end = len(text) if end < 0 else end
        body = text[start:end]
        for key, val in props.items():
            line = f"mocap_{key} = {value(val)}"
            pattern = re.compile(rf"^mocap_{key} = .*$", re.M)
            if pattern.search(body):
                body = pattern.sub(line, body)
            else:
                script = re.search(r"^script = .*$", body, re.M)
                at = script.end() if script else 0
                body = body[:at] + "\n" + line + body[at:]
        path.write_text(text[:start] + body + text[end:])
    print("mocap assigned")


if __name__ == "__main__":
    main()
