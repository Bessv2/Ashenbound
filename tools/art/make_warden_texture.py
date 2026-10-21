"""Makes the Warden's texture from the KayKit Knight's palette texture:
steel and white become blackened iron, the gold trim becomes ember orange and
the red cape a deeper crimson (docs/ART_DIRECTION.md). Colours blend by how
close each pixel is to a target, so the palette's gradients stay smooth.

Usage: python3 tools/art/make_warden_texture.py knight_texture.png warden_texture.png
Needs Pillow. The source is in KayKit Character Pack: Adventures 1.0 (CC0),
Characters/gltf/knight_texture.png.
"""
import colorsys
import sys

from PIL import Image


def clamp(x):
    return max(0.0, min(1.0, x))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def recolor(rgb):
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    deg = h * 360
    iron = colorsys.hsv_to_rgb(215 / 360, 0.10, 0.14 + v * 0.48)
    w_iron = clamp((0.32 - s) / 0.14)
    ember = colorsys.hsv_to_rgb(18 / 360, 0.9, min(1.0, v * 1.05))
    w_gold = clamp(1 - abs(deg - 48) / 18) * clamp((s - 0.4) / 0.2)
    crimson = colorsys.hsv_to_rgb(358 / 360, min(1.0, s * 1.1), v * 0.62)
    w_red = clamp(1 - min(abs(deg - 360), deg) / 14) * clamp((s - 0.35) / 0.2)
    out = mix(rgb, iron, w_iron)
    out = mix(out, ember, w_gold)
    return mix(out, crimson, w_red)


def main(source, destination):
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            out = recolor((r / 255, g / 255, b / 255))
            pixels[x, y] = tuple(round(c * 255) for c in out) + (a,)
    image.save(destination)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
