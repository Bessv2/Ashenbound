#!/usr/bin/env python3
"""Copies the KayKit props the new regions use into the game (CC0).

From two packs by Kay Lousberg, cloned at a pinned commit (cached):
- Halloween Bits 1.0: dead and pine trees, graves, fences, lanterns, shrines,
  candles, bones;
- Medieval Hexagon Pack 1.0: rocks, a weapon rack, crates.
Each model is a .gltf with its .bin, sharing the pack's palette texture;
they go to game/assets/third_party/kaykit/halloween/ and .../hexagon/ with
the pack's licence. Only the files listed here are copied.

Usage: tools/art/fetch_kaykit_props.py [--cache DIR]
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/third_party/kaykit"

PACKS = {
    "halloween": {
        "repo": "https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0",
        "commit": "6dc69bf",
        "folder": "addons/kaykit_halloween_bits/Assets/gltf",
        "texture": "halloweenbits_texture.png",
        "models": ["tree_dead_large", "tree_dead_medium", "tree_pine_orange_large", "tree_pine_yellow_medium",
                   "gravestone", "grave_A", "grave_B", "fence_broken", "lantern_standing", "shrine_candles",
                   "candle_triple", "skull", "ribcage", "bone_A", "coffin", "arch", "pillar", "post_skull",
                   "plaque_candles"],
    },
    "hexagon": {
        "repo": "https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0",
        "commit": "84fa4e9",
        "folder": "addons/kaykit_medieval_hexagon_pack/Assets/gltf",
        "texture": "hexagons_medieval.png",
        "models": ["rock_single_A", "rock_single_C", "rock_single_E", "weaponrack", "crate_A_big"],
    },
}


def checkout(cache: Path, repo: str, commit: str) -> Path:
    folder = cache / repo.rsplit("/", 1)[1]
    if not folder.exists():
        subprocess.run(["git", "clone", "-q", repo, str(folder)], check=True)
    subprocess.run(["git", "-C", str(folder), "checkout", "-q", commit], check=True)
    return folder


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/ashenbound-art/kaykit")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    for name, pack in PACKS.items():
        source = checkout(args.cache, pack["repo"], pack["commit"])
        out = OUT / name
        out.mkdir(parents=True, exist_ok=True)
        files = {path.name: path for path in (source / pack["folder"]).rglob("*") if path.is_file()}
        for model in pack["models"]:
            for suffix in (".gltf", ".bin"):
                shutil.copy(files[model + suffix], out / (model + suffix))
        shutil.copy(files[pack["texture"]], out / pack["texture"])
        shutil.copy(source / "LICENSE.txt", out / "LICENSE.txt")
        print(f"{name}: {len(pack['models'])} models")


if __name__ == "__main__":
    main()
