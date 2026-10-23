#!/usr/bin/env python3
"""Fetches the game's icons from game-icons.net (CC BY 3.0).

The icons come from the @iconify-json/game-icons package on npm (the same
SVGs, one file for all); each is written white on transparent to
game/assets/third_party/game_icons/<key>.svg, to be tinted in the game. The
author of each icon is looked up on game-icons.net, and CREDITS.md lists
them all, as the licence requires.

Usage: tools/art/fetch_icons.py [--cache DIR]
"""

from __future__ import annotations

import argparse
import io
import json
import re
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/third_party/game_icons"
PACKAGE = "https://registry.npmjs.org/@iconify-json/game-icons/-/game-icons-1.2.4.tgz"
SITEMAP = "https://game-icons.net/sitemap.xml"

# Our key -> game-icons name. Keys are what the game asks for (Icons.get).
ICONS = {
    # Interface.
    "idle": "hourglass",
    "bag": "backpack",
    "skills": "upgrade",
    "character": "visored-helm",
    "quests": "scroll-unfurled",
    "map": "treasure-map",
    "close": "cross-mark",
    "gold": "two-coins",
    "ash": "gems",
    "dodge": "dodge",
    "potion": "health-potion",
    "level": "laurel-crown",
    "trophy": "trophy",
    # Basic attacks, by class.
    "attack_warden": "broadsword",
    "attack_reaver": "daggers",
    "attack_hexbinder": "skull-staff",
    "attack_dreadhunter": "bow-arrow",
    "attack_reliquary": "flail",
    "attack_gravecaller": "reaper-scythe",
    # Abilities, by their HUD label.
    "ability_cleave": "axe-swing",
    "ability_guard": "checked-shield",
    "ability_brand": "fire-silhouette",
    "ability_veil": "cloak-dagger",
    "ability_fan": "thrown-daggers",
    "ability_bleed": "bleeding-wound",
    "ability_curse": "evil-book",
    "ability_grasp": "grasping-claws",
    "ability_unmake": "death-zone",
    "ability_snare": "wolf-trap",
    "ability_shot": "arrowhead",
    "ability_raven": "raven",
    "ability_bless": "holy-symbol",
    "ability_lantern": "old-lantern",
    "ability_judge": "thor-hammer",
    "ability_raise": "raise-skeleton",
    "ability_wraiths": "ghost",
    "ability_harvest": "scythe",
    # Equipment slots.
    "slot_weapon": "broadsword",
    "slot_helmet": "visored-helm",
    "slot_chest": "chest-armor",
    "slot_gloves": "gauntlet",
    "slot_boots": "metal-boot",
    "slot_ring": "diamond-ring",
    "slot_amulet": "gem-pendant",
    "slot_relic": "holy-grail",
    # Item kinds (ItemBase.icon); a base without one shows its slot's.
    "item_cleaver": "meat-cleaver",
    "item_axe": "battle-axe",
    "item_dagger": "plain-dagger",
    "item_staff": "wizard-staff",
    "item_bow": "pocket-bow",
    "item_flail": "flail",
    "item_scythe": "scythe",
    "item_wand": "crystal-wand",
    "item_leather": "leather-armor",
    "item_robe": "robe",
    "item_breastplate": "breastplate",
    "item_barbute": "closed-barbute",
    "item_skull_ring": "skull-ring",
    "item_necklace": "emerald-necklace",
    "item_tome": "spell-book",
    # Menus.
    "locked": "padlock",
    "chest": "open-treasure-chest",
    "time": "sands-of-time",
    "daily": "calendar",
    "check": "check-mark",
    # Stats.
    "stat_health": "hearts",
    "stat_damage": "sword-wound",
    "stat_armor": "checked-shield",
    "stat_crit": "target-dummy",
    "stat_speed": "running-shoe",
    # Materials.
    "iron_ore": "stone-block",
    "wood": "log",
    "leather": "animal-hide",
    "herbs": "herbs-bundle",
    "crystal": "crystal-cluster",
    "soul_shard": "crystal-shine",
    # Crafting.
    "upgrade": "anvil",
    "enchant": "magic-swirl",
    "craft": "sword-smithing",
    "legendary": "laurels-trophy",
    "salvage": "hammer-break",
    # Gathering.
    "mine": "mining",
    "lumber": "wood-axe",
    "hunt": "hunting-horn",
    "forage": "herbs-bundle",
    # Regions.
    "region_crypt": "tombstone",
    "region_catacombs": "crypt-entrance",
    "region_keep": "castle-ruins",
    "region_forest": "evil-tree",
    "region_volcano": "volcano",
    "region_temple": "greek-temple",
    "region_ice": "snowflake-2",
    # Enemies.
    "enemy_skeleton": "skeleton",
    "enemy_demon": "imp-laugh",
    "boss": "crowned-skull",
}


def fetch_package(cache: Path) -> dict:
    target = cache / "game-icons-icons.json"
    if not target.exists():
        print(f"downloading {PACKAGE}")
        with urllib.request.urlopen(PACKAGE, timeout=300) as response:
            data = response.read()
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
            target.write_bytes(tar.extractfile("package/icons.json").read())
    return json.loads(target.read_text())


def author_map(cache: Path) -> dict:
    """Icon name -> author, from the site's per-author sitemaps."""
    target = cache / "game-icons-authors.json"
    if target.exists():
        return json.loads(target.read_text())
    def get(url: str) -> str:
        with urllib.request.urlopen(url, timeout=60) as response:
            return response.read().decode()
    authors = {}
    for sitemap in re.findall(r"<loc>(https://game-icons.net/sitemaps/1x1/[^<]+)</loc>", get(SITEMAP)):
        for author, name in re.findall(r"/1x1/([^/]+)/([^/.<]+)\.html", get(sitemap)):
            authors.setdefault(name, author)
    target.write_text(json.dumps(authors, indent=1))
    return authors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/ashenbound-art")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    icons = fetch_package(args.cache)
    size = icons.get("width", 512)
    authors = author_map(args.cache)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for key, name in ICONS.items():
        body = icons["icons"][name]["body"].replace("currentColor", "#ffffff")
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" '
               f'viewBox="0 0 {size} {size}">{body}</svg>\n')
        (OUT / f"{key}.svg").write_text(svg)
        # Imported at twice the size with mipmaps, sharp on a phone's dense
        # screen; Godot fills in the rest of the file on import.
        settings = OUT / f"{key}.svg.import"
        if not settings.exists():
            settings.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
                                '[params]\n\nmipmaps/generate=true\nsvg/scale=2.0\n')
        if name not in authors:
            raise SystemExit(f"no author found for {name}")
        author = authors[name]
        rows.append(f"| `{key}.svg` | [{name}](https://game-icons.net/1x1/{author}/{name}.html) | {author} |")
    (OUT / "CREDITS.md").write_text(
        "# Game icons\n\n"
        "From [game-icons.net](https://game-icons.net), licensed\n"
        "[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/): credit the authors below.\n"
        "Written by `tools/art/fetch_icons.py` (white, recoloured in the game); do not\n"
        "edit by hand.\n\n"
        "| File | Icon | Author |\n|---|---|---|\n" + "\n".join(rows) + "\n")
    print(f"{len(rows)} icons")


if __name__ == "__main__":
    main()
