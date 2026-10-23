#!/usr/bin/env python3
"""Bakes the tileable noise texture look B's surface shader reads.

game/resources/textures/grime_noise.png, 256 x 256 RGBA, repeating seamlessly:
- R, G: a normal map (x, y) of the fine noise, for relief;
- B: fine noise (pitting, colour variation);
- A: coarse noise (where grime gathers).
Before, the shader computed this noise per pixel (about 120 hashes); one
texture read is far cheaper on a phone. Made from random phases in the
frequency domain, so it tiles exactly. Needs numpy and Pillow.

Usage: tools/art/make_grime_noise.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/resources/textures/grime_noise.png"
SIZE = 256


def tileable_noise(rng: np.random.Generator, falloff: float, cutoff: float) -> np.ndarray:
    """Noise in 0..1 whose spectrum falls off as 1/f^falloff, below `cutoff` cycles."""
    fx = np.fft.fftfreq(SIZE)[None, :]
    fy = np.fft.fftfreq(SIZE)[:, None]
    f = np.sqrt(fx * fx + fy * fy) * SIZE
    amplitude = np.where(f > 0, 1.0 / np.maximum(f, 1.0) ** falloff, 0.0) * (f < cutoff)
    phase = rng.uniform(0, 2 * np.pi, (SIZE, SIZE))
    field = np.real(np.fft.ifft2(amplitude * np.exp(1j * phase)))
    field -= field.min()
    return field / field.max()


def main() -> None:
    rng = np.random.default_rng(7)
    fine = tileable_noise(rng, 1.0, 64)
    coarse = tileable_noise(rng, 1.6, 12)
    # Slopes with wrap-around, so the normals tile too.
    dx = (np.roll(fine, -1, axis=1) - np.roll(fine, 1, axis=1)) * 6.0
    dy = (np.roll(fine, -1, axis=0) - np.roll(fine, 1, axis=0)) * 6.0
    length = np.sqrt(dx * dx + dy * dy + 1.0)
    nx, ny = -dx / length, -dy / length
    rgba = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, fine, coarse], axis=-1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(rgba, 0, 1) * 255).round().astype(np.uint8), "RGBA").save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
