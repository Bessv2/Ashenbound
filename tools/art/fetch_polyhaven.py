#!/usr/bin/env python3
"""Downloads the photographed surface textures from Poly Haven (CC0).

Each texture set (colour, OpenGL normal and roughness, 1k JPG) goes to
game/assets/third_party/polyhaven/<id>/ with an info.json recording its name,
authors, page and real-world size. Poly Haven's assets are CC0
(https://polyhaven.com/license).

Usage: tools/art/fetch_polyhaven.py
"""

from __future__ import annotations

import json
import shutil
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/third_party/polyhaven"
API = "https://api.polyhaven.com"
# id -> what it is for (docs/ART_STYLE_TEST.md).
SETS = {
    "rock_wall_08": "walls, pillars and gates in look B (side faces)",
    "stone_tiles_02": "floors in look B (upward faces)",
}
MAPS = {"Diffuse": "diff", "nor_gl": "nor_gl", "Rough": "rough"}


def get_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": "ashenbound-asset-import"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def download(url: str, target: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "ashenbound-asset-import"})
    with urllib.request.urlopen(request, timeout=300) as response, open(target, "wb") as out:
        shutil.copyfileobj(response, out)


def main() -> None:
    for asset, use in SETS.items():
        folder = OUT / asset
        folder.mkdir(parents=True, exist_ok=True)
        files = get_json(f"{API}/files/{asset}")
        info = get_json(f"{API}/info/{asset}")
        for key, short in MAPS.items():
            url = files[key]["1k"]["jpg"]["url"]
            download(url, folder / f"{asset}_{short}_1k.jpg")
        (folder / "info.json").write_text(json.dumps({
            "name": info["name"],
            "authors": list(info["authors"]),
            "page": f"https://polyhaven.com/a/{asset}",
            "license": "CC0 1.0 (https://polyhaven.com/license)",
            "size_m": [round(d / 1000, 2) for d in info.get("dimensions", [])],
            "used_for": use,
        }, indent=2) + "\n")
        print(f"{asset}: {info['name']} by {', '.join(info['authors'])}")


if __name__ == "__main__":
    main()
