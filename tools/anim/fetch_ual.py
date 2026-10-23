#!/usr/bin/env python3
"""Downloads Quaternius's Universal Animation Library 1 and 2 (Standard, CC0).

Both are "name your own price" on itch.io; the Standard editions can be
downloaded for nothing through itch's own "No thanks, just take me to the
downloads" path, which this script follows. (Quaternius takes donations:
https://www.patreon.com/quaternius.) The Godot .glb files are unpacked into
the cache, where tools/anim/retarget_ual.gd reads them.

Usage: tools/anim/fetch_ual.py [--cache DIR]   (default ~/.cache/ashenbound-anim)
"""

from __future__ import annotations

import argparse
import http.cookiejar
import io
import json
import re
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

GAMES = {
    "UAL1_Standard.glb": "https://quaternius.itch.io/universal-animation-library",
    "UAL2_Standard.glb": "https://quaternius.itch.io/universal-animation-library-2",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/ashenbound-anim")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    for glb, page in GAMES.items():
        if (args.cache / glb).exists():
            print(f"{glb}: cached")
            continue
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        opener.addheaders = [("User-Agent", "ashenbound-asset-import")]

        def csrf(html: str) -> str:
            return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)

        def post(url: str, token: str) -> dict:
            data = urllib.parse.urlencode({"csrf_token": token}).encode()
            return json.load(opener.open(url, data, timeout=60))

        html = opener.open(page, timeout=60).read().decode()
        downloads = opener.open(post(f"{page}/download_url", csrf(html))["url"], timeout=60).read().decode()
        uploads = re.findall(r'data-upload_id="(\d+)".{0,800}?title="([^"]+)"', downloads, re.S)
        upload = next(uid for uid, title in uploads if "[Standard]" in title)
        file_url = post(f"{page}/file/{upload}?source=game_download&as_props=1", csrf(downloads))["url"]
        archive = zipfile.ZipFile(io.BytesIO(opener.open(file_url, timeout=600).read()))
        member = next(n for n in archive.namelist() if n.endswith("/Unreal-Godot/" + glb))
        (args.cache / glb).write_bytes(archive.read(member))
        licence = next(n for n in archive.namelist() if n.endswith("License.txt"))
        (args.cache / glb.replace(".glb", "_License.txt")).write_bytes(archive.read(licence))
        print(f"{glb}: downloaded")


if __name__ == "__main__":
    main()
