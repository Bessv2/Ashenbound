#!/usr/bin/env python3
"""Builds the effect textures from Kenney's Particle Pack (CC0).

Downloads the pack from kenney.nl (cached), then packs the sprites the game
uses into small atlases in game/assets/third_party/kenney_particles/:
- smoke.png: 8 smoke puffs, 4 x 2 frames;
- flame.png: 6 fire tongues, 3 x 2 frames;
- debris.png: 3 sprays of grit and chips, 3 x 1 frames;
- glint.png: a soft four-pointed spark;
- ring.png: a clean shockwave ring;
- scorch.png: a burst-shaped mark, for scorch decals.
The sprites are white on transparent, tinted in the game.

Usage: tools/art/make_particle_atlases.py [--cache DIR]   (needs Pillow)
"""

from __future__ import annotations

import argparse
import shutil
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/third_party/kenney_particles"
URL = "https://kenney.nl/media/pages/assets/particle-pack/f8fe0f8cb8-1677578741/kenney_particle-pack.zip"
PAGE = "https://kenney.nl/assets/particle-pack"

# Output -> (frames, columns, rows, frame size in pixels).
ATLASES = {
    "smoke.png": ([f"smoke_0{n}.png" for n in range(1, 9)], 4, 2, 128),
    "flame.png": (["muzzle_01.png", "muzzle_02.png", "muzzle_03.png", "muzzle_04.png", "muzzle_05.png", "flame_06.png"], 3, 2, 128),
    "debris.png": (["dirt_01.png", "dirt_02.png", "dirt_03.png"], 3, 1, 128),
    "glint.png": (["star_04.png"], 1, 1, 64),
    "ring.png": (["circle_02.png"], 1, 1, 256),
    "scorch.png": (["scorch_02.png"], 1, 1, 256),
}


def fetch(cache: Path) -> Path:
    folder = cache / "kenney_particle-pack"
    if folder.exists():
        return folder
    archive = cache / "kenney_particle-pack.zip"
    print(f"downloading {URL}")
    request = urllib.request.Request(URL, headers={"User-Agent": "ashenbound-asset-import"})
    with urllib.request.urlopen(request, timeout=300) as response, open(archive, "wb") as out:
        shutil.copyfileobj(response, out)
    with zipfile.ZipFile(archive) as z:
        z.extractall(folder)
    return folder


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/ashenbound-art")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    pack = fetch(args.cache)
    sprites = pack / "PNG (Transparent)"
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (frames, columns, rows, size) in ATLASES.items():
        atlas = Image.new("RGBA", (columns * size, rows * size), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            image = Image.open(sprites / frame).convert("RGBA").resize((size, size), Image.LANCZOS)
            atlas.paste(image, ((i % columns) * size, (i // columns) * size))
        atlas.save(OUT / name, optimize=True)
        print(f"{name}: {len(frames)} frames")
    shutil.copy(pack / "License.txt", OUT / "LICENSE-kenney.txt")
    (OUT / "README.md").write_text(
        "# Kenney Particle Pack (effect textures)\n\n"
        f"By Kenney ({PAGE}), CC0 1.0: see `LICENSE-kenney.txt`. The atlases here are\n"
        "packed from the pack's transparent sprites by `tools/art/make_particle_atlases.py`;\n"
        "do not edit them by hand. `docs/ART_ASSET_PIPELINE.md` lists what each is for.\n")


if __name__ == "__main__":
    main()
