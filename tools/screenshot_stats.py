"""Prints, for each screenshot a device test took, how bright it is and how much
of it changed since the previous one. A blank or frozen game shows up as a
black screenshot or as 0% change where something should have moved.

Usage: python3 tools/screenshot_stats.py build/device-test/<run>/
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops


def main(folder: str) -> None:
    previous = None
    print(f"{'screenshot':<18}{'size':>11}{'brightness':>12}{'changed':>9}")
    for path in sorted(Path(folder).glob("*.png")):
        image = Image.open(path).convert("RGB")
        small = image.resize((160, 90))
        pixels = small.convert("L").tobytes()
        brightness = sum(pixels) / len(pixels)
        changed = "-"
        if previous is not None:
            diff = ImageChops.difference(small, previous).convert("L")
            moved = sum(1 for value in diff.tobytes() if value > 24)
            changed = f"{100.0 * moved / len(pixels):.1f}%"
        print(f"{path.name:<18}{image.width}x{image.height:<5}{brightness:>12.1f}{changed:>9}")
        previous = small


if __name__ == "__main__":
    main(sys.argv[1])
