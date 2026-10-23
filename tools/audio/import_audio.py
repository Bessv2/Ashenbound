#!/usr/bin/env python3
"""Builds the game's sound effects and music from their public-domain sources.

Every pack is downloaded from where it is published (Kenney, OpenGameArt),
and each sound the game uses is cut, trimmed, normalised and encoded to Ogg
Vorbis into game/assets/third_party/audio/<author>/. The script also writes
game/scripts/audio/sound_files.gd, the list of files behind each cue, so the
game and its tests know exactly what exists. docs/AUDIO.md lists the sources.

Usage:
    tools/audio/import_audio.py [--cache DIR]

Needs ffmpeg (with libvorbis) and Python 3.10+; .7z packs also need py7zr
(pip install py7zr). Downloads are cached, so a rerun only re-encodes.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/third_party/audio"
FILES_SCRIPT = ROOT / "game/scripts/audio/sound_files.gd"
OGA = "https://opengameart.org/sites/default/files/"
KENNEY = "https://kenney.nl/media/pages/assets/"

# Pack id -> where it comes from. All are CC0 1.0 (public domain).
PACKS: dict[str, dict[str, str]] = {
    "kenney_impact": {"author": "kenney", "url": KENNEY + "impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
                      "page": "https://kenney.nl/assets/impact-sounds", "title": "Impact Sounds"},
    "kenney_rpg": {"author": "kenney", "url": KENNEY + "rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
                   "page": "https://kenney.nl/assets/rpg-audio", "title": "RPG Audio"},
    "kenney_interface": {"author": "kenney", "url": KENNEY + "interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
                         "page": "https://kenney.nl/assets/interface-sounds", "title": "Interface Sounds"},
    "rpg_sfx_80": {"author": "rubberduck", "url": OGA + "80-CC0-RPG-SFX_0.zip",
                   "page": "https://opengameart.org/content/80-cc0-rpg-sfx", "title": "80 CC0 RPG SFX"},
    "breaking_75": {"author": "rubberduck", "url": OGA + "sfx_breaking_and_falling.zip",
                    "page": "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx", "title": "75 CC0 breaking / falling / hit sfx"},
    "rpg_sound_pack": {"author": "artisticdude", "url": OGA + "rpg_sound_pack.zip",
                       "page": "https://opengameart.org/content/rpg-sound-pack", "title": "RPG Sound Pack"},
    "swishes": {"author": "artisticdude", "url": OGA + "swishes.zip",
                "page": "https://opengameart.org/content/swishes-sound-pack", "title": "Swishes Sound Pack"},
    "medieval_1": {"author": "medicinestorm", "url": OGA + "medieval_sfx_textures_1_of_2.7z",
                   "page": "https://opengameart.org/content/medieval-sound-effects-weapon-textures", "title": "Medieval Sound Effects: Weapon Textures (1 of 2)"},
    "medieval_2": {"author": "medicinestorm", "url": OGA + "medieval_sfx_textures_2_of_2.7z",
                   "page": "https://opengameart.org/content/medieval-sound-effects-weapon-textures", "title": "Medieval Sound Effects: Weapon Textures (2 of 2)"},
    "tinysized": {"author": "vehicle", "url": OGA + "tinysized.zip",
                  "page": "https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx", "title": "Tinysized SFX Library"},
    "bones_rattle": {"author": "congusbongus", "url": OGA + "bones_rattle.zip",
                     "page": "https://opengameart.org/content/bones-rattle", "title": "Bones Rattle"},
    "voices": {"author": "arcadeparty", "url": OGA + "Voice%20Effects%20Zombie-Skeleton-Monster%20Human%20Male.zip",
               "page": "https://opengameart.org/content/zombie-skeleton-monster-voice-effects", "title": "Zombie, Skeleton, Monster Voice Effects"},
    "ghost_moans": {"author": "qubodup", "url": OGA + "qubodup-GhostMoans.zip",
                    "page": "https://opengameart.org/content/ghost-monster-voice-moaning-growling", "title": "Ghost Monster Voice"},
    "dark_magic": {"author": "qubodup", "url": OGA + "dark_magic.7z",
                   "page": "https://opengameart.org/content/3-dark-magic-spells", "title": "3 Dark Magic Spells"},
    "power_drain": {"author": "qubodup", "url": OGA + "qubodup-PowerDrain.7z",
                    "page": "https://opengameart.org/content/energy-drain", "title": "Energy Drain"},
    "earth_spell": {"author": "qubodup", "url": OGA + "Earth%20Element%20Magic%20Spell_3.ogg",
                    "page": "https://opengameart.org/content/earth-element-magic-spell", "title": "Earth Element Magic Spell"},
    "ghost_breath": {"author": "qubodup", "url": OGA + "ghostbreath.flac",
                     "page": "https://opengameart.org/content/ghost-breath", "title": "Ghost Breath"},
    "cure_magic": {"author": "someoneman", "url": OGA + "curemagic.zip",
                   "page": "https://opengameart.org/content/cure-magic", "title": "Cure Magic"},
    "ice_spells": {"author": "bart", "url": OGA + "icespells.zip",
                   "page": "https://opengameart.org/content/ice-spells", "title": "Ice Spells"},
    "catching_fire": {"author": "themightyglider", "url": OGA + "flame_0.ogg",
                      "page": "https://opengameart.org/content/catching-fire", "title": "Catching Fire"},
    "crow_caw": {"author": "zeroisnotnull", "url": OGA + "crow_caw.wav",
                 "page": "https://opengameart.org/content/crow-caw", "title": "Crow Caw"},
    "crow": {"author": "fvcalderan", "url": OGA + "crow_0.ogg",
             "page": "https://opengameart.org/content/crow", "title": "Crow"},
    "wings": {"author": "antumdeluge", "url": OGA + "wings_flap_large.zip",
              "page": "https://opengameart.org/content/large-wings-flap", "title": "Large Wings Flap"},
    "dungeon_ambience": {"author": "yd", "url": OGA + "dungeon002_0.ogg",
                         "page": "https://opengameart.org/content/dungeon-ambience", "title": "Dungeon Ambience"},
    "music_dark_intro": {"author": "nikke", "url": OGA + "Dark%20Intro.ogg",
                         "page": "https://opengameart.org/content/dark-intro", "title": "Dark Intro"},
    "music_dark_shrine": {"author": "yd", "url": OGA + "qubodup-yd-DarkShrineLoop-OpenGameArt.ogg",
                          "page": "https://opengameart.org/content/dark-shrine-loop", "title": "Dark Shrine Loop"},
    "music_dark_cavern": {"author": "paul-wortmann", "url": OGA + "dark_cavern_ambient_001.ogg",
                          "page": "https://opengameart.org/content/dark-cavern-ambient", "title": "Dark Cavern Ambient"},
    "music_pursuit": {"author": "emmama", "url": OGA + "determined_pursuit_loop.wav",
                      "page": "https://opengameart.org/content/determined-pursuit-epic-orchestra-loop", "title": "Determined Pursuit (epic orchestra loop)"},
    "music_boss": {"author": "subspaceaudio", "url": OGA + "Juhani%20Junkala%20-%20Epic%20Boss%20Battle%20%5BSeamlessly%20Looping%5D.wav",
                   "page": "https://opengameart.org/content/boss-battle-music", "title": "Epic Boss Battle (Juhani Junkala)"},
}


def k(pack: str, pattern: str, count: int) -> list[tuple[str, str]]:
    """`count` numbered Kenney files, e.g. impactPunch_heavy_00{n}.ogg."""
    return [(pack, "Audio/" + pattern.format(n=n)) for n in range(count)]


def many(pack: str, names: list[str]) -> list[tuple[str, str]]:
    return [(pack, name) for name in names]


RPG = "RPG Sound Pack/"
MED1 = ""
MED2 = ""
VOICE = "Voice Effects Zombie-Skeleton-Monster Human Male/"
TINY = "sfx-cc0/"

# Cue -> its sources, and how to cut them. A source is (pack, path in pack).
# Options: split (cut a long multi-take recording into this many takes),
# max (seconds kept), start (seconds skipped), music (stereo, looped).
CUES: dict[str, dict] = {
    # Swings and shots, played when the blow is struck.
    "swing_heavy": {"src": many("medieval_2", [MED2 + "Axe Swing.wav", MED2 + "Sabre Swing.wav"]), "split": 4, "max": 0.7},
    "swing_light": {"src": many("medieval_2", [MED2 + "Dagger Swing.wav", MED2 + "Seax Swing.wav"]), "split": 3, "max": 0.5},
    "swing_spear": {"src": many("medieval_2", [MED2 + "Spear Swing.wav"]), "split": 4, "max": 0.6},
    "swish": {"src": many("swishes", [f"swishes/swish-{n}.wav" for n in range(1, 9)]), "max": 0.5},
    "claw": {"src": many("swishes", [f"swishes/swish-{n}.wav" for n in range(9, 14)]), "max": 0.4},
    "crossbow_shot": {"src": many("medieval_1", [MED1 + "Crossbow Shoot.wav"]), "split": 3, "max": 0.8},
    # A run of ratchet clicks.
    "crossbow_load": {"src": many("medieval_1", [MED1 + "Crossbow Set Nut Against Sear.wav"]), "start": 0.19, "max": 0.8},
    "blade_draw": {"src": many("medieval_2", [MED2 + "Sabre Draw Fast.wav", MED2 + "Katana Draw Fast.wav"]), "split": 3, "max": 0.7},
    "blade_fan": {"src": many("rpg_sfx_80", ["blade_01.ogg", "blade_02.ogg", "blade_03.ogg"])},
    # What a body sounds like when struck.
    "hit_thud": k("kenney_impact", "impactPunch_medium_00{n}.ogg", 5),
    "hit_flesh": k("kenney_impact", "impactPunch_heavy_00{n}.ogg", 5),
    "hit_bone": {"src": many("bones_rattle", [f"{n}.ogg" for n in range(10)]), "max": 0.5},
    "hit_metal": k("kenney_impact", "impactMetal_heavy_00{n}.ogg", 5) + many("tinysized", [TINY + f"sword-clash-0{n}.wav" for n in (1, 4, 5)]),
    "hit_stone": many("breaking_75", ["bfh1_rock_hit_01.ogg"]) + k("kenney_impact", "impactMining_00{n}.ogg", 5),
    "hit_crit": k("kenney_impact", "impactPlate_heavy_00{n}.ogg", 5),
    # Voices.
    "hero_hurt": many("voices", [VOICE + f"humanYell{n}.wav" for n in range(1, 6)]),
    "hero_death": many("voices", [VOICE + "humanDeath1.wav", VOICE + "humanDeath2.wav"]),
    "undead_growl": many("voices", [VOICE + f"zombieYell{n}.wav" for n in range(1, 11)]),
    "undead_death": many("voices", [VOICE + f"zombieDeath{n}.wav" for n in range(1, 5)]),
    "ghoul_hurt": many("rpg_sfx_80", ["creature_hurt_01.ogg", "creature_hurt_02.ogg"]),
    "ghoul_death": many("rpg_sfx_80", ["creature_die_01.ogg"]),
    "ghoul_snarl": many("rpg_sfx_80", [f"creature_misc_0{n}.ogg" for n in range(1, 9)]),
    "ghost_moan": {"src": many("ghost_moans", [f"qubodup-GhostMoans/wav/qubodup-GhostMoan0{n}.wav" for n in range(1, 6)]), "max": 1.6},
    "beast_roar": many("rpg_sfx_80", ["creature_roar_01.ogg", "creature_roar_02.ogg", "creature_roar_03.ogg"]),
    "giant_roar": many("rpg_sound_pack", [RPG + f"NPC/giant/giant{n}.wav" for n in range(1, 6)]),
    "bones_collapse": many("breaking_75", ["bfh1_breaking_01.ogg", "bfh1_breaking_02.ogg", "bfh1_breaking_03.ogg"]),
    "armor_fall": many("breaking_75", [f"bfh1_metal_falling_0{n}.ogg" for n in range(1, 6)]),
    "stone_break": many("breaking_75", ["bfh1_rock_breaking_01.ogg", "bfh1_rock_breaking_02.ogg", "bfh1_rock_breaking_03.ogg"]),
    "rocks_fall": many("breaking_75", [f"bfh1_rock_falling_0{n}.ogg" for n in range(1, 7)]),
    # Movement.
    "footstep": k("kenney_impact", "footstep_concrete_00{n}.ogg", 5),
    "dodge": many("kenney_rpg", [f"Audio/cloth{n}.ogg" for n in range(1, 5)]),
    # Magic and abilities.
    "spell_cast": many("rpg_sfx_80", ["spell_01.ogg", "spell_02.ogg"]) + many("rpg_sound_pack", [RPG + "battle/magic1.wav"]),
    "fire_cast": many("rpg_sfx_80", [f"spell_fire_0{n}.ogg" for n in range(1, 8)]),
    "ignite": many("catching_fire", ["flame_0.ogg"]),
    "dark_magic": {"src": many("dark_magic", [f"dark_magic/fout-0{n}.flac" for n in range(1, 4)]), "max": 1.6},
    "drain": {"src": many("power_drain", ["qubodup-PowerDrain/ogg/qubodup-PowerDrain.ogg"]), "max": 1.6},
    "earth_rise": {"src": many("earth_spell", ["Earth%20Element%20Magic%20Spell_3.ogg"]), "max": 1.6},
    "ghost_breath": {"src": many("ghost_breath", ["ghostbreath.flac"]), "max": 1.6},
    "frost": {"src": many("ice_spells", ["coldsnap.wav", "ice.wav"]), "max": 1.2},
    "holy_heal": {"src": many("cure_magic", [f"Cure{n}.wav" for n in (2, 4, 5)]), "max": 1.4},
    "bell": k("kenney_impact", "impactBell_heavy_00{n}.ogg", 5),
    "guard_brace": many("rpg_sound_pack", [RPG + "inventory/chainmail1.wav", RPG + "inventory/chainmail2.wav", RPG + "inventory/metal-ringing.wav"]),
    "parry": many("tinysized", [TINY + f"sword-clash-0{n}.wav" for n in (1, 4, 5)]),
    "bleed": many("rpg_sfx_80", [f"creature_slime_0{n}.ogg" for n in range(1, 5)]),
    "trap_snap": many("tinysized", [TINY + "handcuffs-metal-lock-02.wav"]) + many("kenney_rpg", ["Audio/metalLatch.ogg"]),
    "crow": many("crow_caw", ["crow_caw.wav"]) + many("crow", ["crow_0.ogg"]),
    "wings": {"src": many("wings", ["wings_flap_large.ogg"]), "max": 1.0},
    "raise_dead": {"src": many("rpg_sfx_80", ["stones_01.ogg", "stones_02.ogg", "stones_03.ogg"])},
    "explosion": many("breaking_75", ["bfh1_breaking_01.ogg", "bfh1_rock_breaking_02.ogg"]) + many("rpg_sfx_80", ["spell_fire_03.ogg"]),
    # Items and the world.
    "potion_drink": many("rpg_sound_pack", [RPG + "inventory/bubble.wav", RPG + "inventory/bubble2.wav", RPG + "inventory/bubble3.wav"]),
    "potion_refill": many("tinysized", [TINY + "bottle-glass-cork-01.wav", TINY + "vial-glass-open-01.wav"]),
    "loot_drop": many("rpg_sfx_80", ["item_misc_01.ogg", "item_misc_02.ogg", "item_misc_04.ogg"]),
    "loot_rare": many("rpg_sfx_80", ["item_gem_01.ogg", "item_gem_02.ogg", "item_gem_03.ogg", "item_gem_04.ogg"]),
    "pickup_gear": many("rpg_sound_pack", [RPG + "inventory/armor-light.wav", RPG + "inventory/metal-small1.wav", RPG + "inventory/metal-small3.wav"]),
    "pickup_gold": many("rpg_sfx_80", ["item_coins_01.ogg", "item_coins_02.ogg", "item_coins_03.ogg"]),
    "gate_chains": many("rpg_sfx_80", ["chain_01.ogg", "chain_02.ogg", "chain_03.ogg"]),
    "gate_slam": k("kenney_impact", "impactMetal_heavy_00{n}.ogg", 3),
    "anvil": many("tinysized", [TINY + "metal-hammer-hit-01.wav", TINY + "metal-hammer-hit-02.wav"]),
    "salvage": many("breaking_75", [f"bfh1_metal_hit_0{n}.ogg" for n in range(1, 4)]),
    # The interface.
    "ui_click": many("kenney_interface", ["Audio/click_001.ogg", "Audio/toggle_001.ogg", "Audio/toggle_002.ogg", "Audio/toggle_003.ogg"]),
    "ui_back": k("kenney_interface", "back_00{n}.ogg", 5)[1:],
    "ui_open": k("kenney_interface", "open_00{n}.ogg", 5)[1:],
    "ui_close": k("kenney_interface", "close_00{n}.ogg", 5)[1:],
    "ui_confirm": k("kenney_interface", "confirmation_00{n}.ogg", 5)[1:],
    "ui_error": k("kenney_interface", "error_00{n}.ogg", 5)[1:],
    # Beds and music.
    "ambience_dungeon": {"src": many("dungeon_ambience", ["dungeon002_0.ogg"]), "music": True},
    "music_title": {"src": many("music_dark_intro", ["Dark%20Intro.ogg"]), "music": True},
    "music_crypt": {"src": many("music_dark_shrine", ["qubodup-yd-DarkShrineLoop-OpenGameArt.ogg"]), "music": True},
    "music_catacombs": {"src": many("music_dark_cavern", ["dark_cavern_ambient_001.ogg"]), "music": True},
    "music_combat": {"src": many("music_pursuit", ["determined_pursuit_loop.wav"]), "music": True},
    "music_boss": {"src": many("music_boss", ["Juhani%20Junkala%20-%20Epic%20Boss%20Battle%20%5BSeamlessly%20Looping%5D.wav"]), "music": True},
}


def fetch(pack_id: str, cache: Path) -> Path:
    """The pack's folder in the cache, downloaded and unpacked if needed."""
    pack = PACKS[pack_id]
    folder = cache / pack_id
    if folder.exists():
        return folder
    url = pack["url"]
    name = urllib.request.unquote(url.rsplit("/", 1)[1])
    archive = cache / ("_" + name)
    print(f"downloading {pack_id}: {url}")
    request = urllib.request.Request(url, headers={"User-Agent": "ashenbound-asset-import"})
    with urllib.request.urlopen(request, timeout=300) as response, open(archive, "wb") as out:
        shutil.copyfileobj(response, out)
    staging = cache / (pack_id + ".part")
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True)
    if name.endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            z.extractall(staging)
    elif name.endswith(".7z"):
        import py7zr  # Only needed for the .7z packs.
        with py7zr.SevenZipFile(archive) as z:
            z.extractall(staging)
    else:
        # A single file: keep it under its URL-encoded name, as CUES names it.
        shutil.copy(archive, staging / url.rsplit("/", 1)[1])
    staging.rename(folder)
    return folder


def ffmpeg(*args: str) -> str:
    result = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-y", *args], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"ffmpeg failed: {' '.join(args)}\n{result.stderr[-2000:]}")
    return result.stderr


def takes(source: Path, count: int, max_len: float) -> list[tuple[float, float]]:
    """The `count` loudest separate takes in a multi-take recording, in order.

    Each take is found by its peak (a loud moment at least 0.3 s from any
    louder one); it starts where the level last rose out of the room noise
    before the peak and ends where it sinks back into it, or after `max_len`
    seconds, so whooshes keep their swell and shots keep their tail.
    """
    rate, hop = 8000, 80  # 10 ms steps.
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(source), "-ac", "1", "-ar", str(rate), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    signal = array("f")
    signal.frombytes(raw)
    level = []
    for i in range(0, len(signal) - hop, hop):
        window = signal[i:i + hop]
        level.append(10 * math.log10(max(sum(x * x for x in window) / hop, 1e-12)))
    noise = sorted(level)[len(level) // 2] + 4.0
    peaks: list[int] = []
    for i in sorted(range(len(level)), key=lambda j: level[j], reverse=True):
        if level[i] < noise + 12 or len(peaks) == count:
            break
        if all(abs(i - p) >= 30 for p in peaks):
            peaks.append(i)
    cuts = []
    for peak in sorted(peaks):
        start = peak
        while start > 0 and peak - start < 40 and level[start - 1] > noise:
            start -= 1
        stop = peak
        while stop < len(level) and stop - start < max_len * 100 and level[stop] > noise:
            stop += 1
        cuts.append((max(start - 1, 0) / 100.0, (stop - start + 2) / 100.0))
    return cuts


def peak_db(path: Path, start: float, length: float | None) -> float:
    span = ["-ss", f"{start:.3f}"] + (["-t", f"{length:.3f}"] if length else [])
    log = ffmpeg(*span, "-i", str(path), "-af", "volumedetect", "-f", "null", "-")
    return float(re.search(r"max_volume: (-?[\d.]+) dB", log).group(1))


def encode(source: Path, target: Path, start: float, length: float | None, music: bool) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    span = ["-ss", f"{start:.3f}"] + (["-t", f"{length:.3f}"] if length else [])
    gain = -1.0 - peak_db(source, start, length)
    if music:
        # Loops keep their full length and stereo, all at the same loudness
        # (-18 LUFS), so SoundBank.TRACKS sets only intended differences.
        ffmpeg(*span, "-i", str(source), "-af", "loudnorm=I=-18:TP=-1.5:LRA=11", "-ac", "2", "-ar", "44100",
               "-c:a", "libvorbis", "-q:a", "3", "-map_metadata", "-1", str(target))
        return
    # Effects: mono, leading silence trimmed, a 15 ms fade out, peak at -1 dBFS.
    fade_at = max((length or 30.0) - 0.015, 0.0)
    filters = (f"silenceremove=start_periods=1:start_threshold=-50dB,volume={gain:.2f}dB,"
               f"afade=t=out:st={fade_at:.3f}:d=0.015" if length else
               f"silenceremove=start_periods=1:start_threshold=-50dB:stop_periods=1:stop_threshold=-55dB:stop_silence=0.05,volume={gain:.2f}dB")
    ffmpeg(*span, "-i", str(source), "-af", filters, "-ac", "1", "-ar", "44100",
           "-c:a", "libvorbis", "-q:a", "4", "-map_metadata", "-1", str(target))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/ashenbound-audio")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        for old in OUT.rglob("*.ogg"):
            old.unlink()
    files: dict[str, list[str]] = {}
    for cue, spec in CUES.items():
        spec = spec if isinstance(spec, dict) else {"src": spec}
        outputs: list[str] = []
        for pack_id, member in spec["src"]:
            source = fetch(pack_id, args.cache) / member
            if not source.exists():
                sys.exit(f"{cue}: {member} is not in {pack_id}")
            author = PACKS[pack_id]["author"]
            if spec.get("split"):
                cuts = takes(source, spec["split"], spec.get("max", 1.0))
            else:
                cuts = [(spec.get("start", 0.0), spec.get("max"))]
            for start, length in cuts:
                name = f"{cue}_{len(outputs) + 1}.ogg"
                encode(source, OUT / author / name, start, length, spec.get("music", False))
                outputs.append(f"res://assets/third_party/audio/{author}/{name}")
        files[cue] = outputs
        print(f"{cue}: {len(outputs)}")
    write_files_script(files)
    (OUT / "packs.json").write_text(json.dumps(
        {pid: PACKS[pid] | {"license": "CC0 1.0"} for pid in sorted({p for s in CUES.values()
         for p, _ in (s["src"] if isinstance(s, dict) else s)})}, indent=2) + "\n")


def write_files_script(files: dict[str, list[str]]) -> None:
    lines = [
        "class_name SoundFiles",
        "extends RefCounted",
        "## The files behind each sound cue. GENERATED by tools/audio/import_audio.py:",
        "## do not edit by hand; change the script and run it again. How each cue is",
        "## played (volume, pitch, bus) is in SoundBank.",
        "",
        "const FILES: Dictionary[StringName, Array] = {",
    ]
    for cue, paths in files.items():
        lines.append(f"\t&\"{cue}\": [")
        lines += [f"\t\t\"{p}\"," for p in paths]
        lines.append("\t],")
    lines.append("}")
    FILES_SCRIPT.parent.mkdir(parents=True, exist_ok=True)
    FILES_SCRIPT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
