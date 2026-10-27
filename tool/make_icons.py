#!/usr/bin/env python3
"""Draws the web2apk icon (white globe on a blue rounded square) and writes
every platform's icon files. Run from the repo root: python3 tool/make_icons.py
Needs Pillow. After changing it, rebuild assets/template.apk."""

from PIL import Image, ImageDraw

BLUE = (0x21, 0x96, 0xF3, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling factor


def draw(size, margin=0.0, radius=0.22, globe=0.56, rounded=True):
    """Icon of [size] px. [margin], [radius] and [globe] (globe diameter) are
    fractions of the size; rounded=False fills the whole square (maskable)."""
    s = size * SS
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = s * margin
    box = (m, m, s - m - 1, s - m - 1)
    if rounded:
        d.rounded_rectangle(box, radius=(s - 2 * m) * radius, fill=BLUE)
    else:
        d.rectangle((0, 0, s, s), fill=BLUE)

    c = s / 2
    r = s * globe / 2
    small = size <= 32  # tiny icons: thicker lines, no latitudes
    w = max(1, round(s * (0.06 if small else 0.035)))
    # Grid lines on their own layer, clipped to the globe so no line end
    # sticks out of the outline.
    grid = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    g = ImageDraw.Draw(grid)
    g.line((c - r, c, c + r, c), fill=WHITE, width=w)  # equator
    g.line((c, c - r, c, c + r), fill=WHITE, width=w)  # central meridian
    e = r * 0.5
    g.ellipse((c - e, c - r, c + e, c + r), outline=WHITE, width=w)  # meridians
    for y in () if small else (c - r / 2, c + r / 2):  # latitudes
        g.line((c - r, y, c + r, y), fill=WHITE, width=w)
    clip = Image.new("L", (s, s), 0)
    inner = r - w / 2
    ImageDraw.Draw(clip).ellipse((c - inner, c - inner, c + inner, c + inner), fill=255)
    im.paste(grid, (0, 0), Image.composite(grid, Image.new("RGBA", (s, s)), clip))
    d.ellipse((c - r, c - r, c + r, c + r), outline=WHITE, width=w)  # outline
    return im.resize((size, size), Image.LANCZOS)


def save(im, path):
    im.save(path, optimize=True)


def main():
    master = draw(1024)
    save(master, "docs/icon.png")

    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for res in ("android/app/src/main/res", "template/app/src/main/res"):
        for dens, px in densities.items():
            save(draw(px, margin=0.04), f"{res}/mipmap-{dens}/ic_launcher.png")

    save(draw(192), "web/icons/Icon-192.png")
    save(draw(512), "web/icons/Icon-512.png")
    # maskable: full bleed, globe inside the 80 % safe zone
    save(draw(192, rounded=False, globe=0.5), "web/icons/Icon-maskable-192.png")
    save(draw(512, rounded=False, globe=0.5), "web/icons/Icon-maskable-512.png")
    save(draw(32), "web/favicon.png")

    # macOS: Apple's grid leaves ~10 % transparent margin around the shape.
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(
            draw(px, margin=0.1, radius=0.225, globe=0.45),
            f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png",
        )

    # iOS: full-bleed opaque square (iOS rounds the corners; no alpha allowed).
    ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for pt, scales in ((20, (1, 2, 3)), (29, (1, 2, 3)), (40, (1, 2, 3)),
                       (60, (2, 3)), (76, (1, 2)), (83.5, (2,)), (1024, (1,))):
        for k in scales:
            name = f"{pt:g}x{pt:g}@{k}x"
            save(
                draw(round(pt * k), rounded=False, globe=0.56).convert("RGB"),
                f"{ios}/Icon-App-{name}.png",
            )

    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    draw(256).save(
        "windows/runner/resources/app_icon.ico",
        sizes=[(p, p) for p in ico_sizes],
        append_images=[draw(p) for p in ico_sizes[:-1]],
    )


if __name__ == "__main__":
    main()
