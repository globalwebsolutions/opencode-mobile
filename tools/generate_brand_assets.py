#!/usr/bin/env python3
"""Generates OpenCode Mobile's brand assets.

Everything is derived from one source of truth — the `>_` prompt mark on the
brand gradient — so the launcher icon, the notification icon, the Play Store
icon and the feature graphic stay in sync.

Usage:  python3 tools/generate_brand_assets.py
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "store")

# Brand colors (same seed as the Flutter theme).
BRAND_TOP = (246, 152, 48)
BRAND_BOTTOM = (194, 65, 12)
BRAND_FLAT = (232, 113, 10)  # 0xFFE8710A — ColorScheme seed

SS = 4  # supersampling factor for anti-aliasing


def gradient(size: int) -> Image.Image:
    strip = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        strip.putpixel(
            (0, y),
            tuple(round(BRAND_TOP[i] + (BRAND_BOTTOM[i] - BRAND_TOP[i]) * t) for i in range(3)),
        )
    return strip.resize((size, size), Image.BILINEAR)


def thick_line(draw: ImageDraw.ImageDraw, p1, p2, width: float, fill) -> None:
    """Line with round caps (PIL has no cap styles)."""
    draw.line([p1, p2], fill=fill, width=max(1, int(round(width))))
    r = width / 2
    for x, y in (p1, p2):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def draw_prompt_mark(draw: ImageDraw.ImageDraw, box, fill, thickness_ratio=0.30) -> None:
    """Draws the `>_` terminal prompt inside [box] = (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    t = h * thickness_ratio
    inset = t * 0.55

    apex = (x0 + w * 0.44, y0 + h / 2)
    thick_line(draw, apex, (x0 + inset, y0 + inset), t, fill)
    thick_line(draw, apex, (x0 + inset, y1 - inset), t, fill)

    baseline = y1 - inset
    thick_line(draw, (x0 + w * 0.60, baseline), (x1 - inset, baseline), t, fill)


def launcher_icon(size: int, round_: bool = False) -> Image.Image:
    """Full-bleed legacy launcher icon (pre-Android 8)."""
    s = size * SS
    mask = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(mask)
    if round_:
        md.ellipse([0, 0, s - 1, s - 1], fill=255)
    else:
        md.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)

    icon = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    icon.paste(gradient(s), (0, 0), mask)
    draw_prompt_mark(
        ImageDraw.Draw(icon),
        (s * 0.26, s * 0.30, s * 0.74, s * 0.70),
        (255, 255, 255, 255),
    )
    return icon.resize((size, size), Image.LANCZOS)


def mark_only(size: int, padding: float = 0.16, flat_background=None) -> Image.Image:
    """The mark alone (for the splash / store icon)."""
    s = size * SS
    if flat_background is None:
        # Full-bleed gradient square (Play applies its own masking).
        icon = gradient(s).convert("RGBA")
    else:
        icon = Image.new("RGBA", (s, s), flat_background)
    inner = s * (1 - 2 * padding)
    off = (s - inner) / 2
    draw_prompt_mark(
        ImageDraw.Draw(icon),
        (off + inner * 0.10, off + inner * 0.18, off + inner * 0.90, off + inner * 0.82),
        (255, 255, 255, 255),
    )
    return icon.resize((size, size), Image.LANCZOS)


def feature_graphic(width: int = 1024, height: int = 500) -> Image.Image:
    """Play Store feature graphic (1024x500)."""
    img = gradient(height).resize((width, height), Image.BILINEAR).convert("RGBA")
    draw = ImageDraw.Draw(img)

    # Mark on the left.
    draw_prompt_mark(draw, (86, height * 0.30, 86 + height * 0.40, height * 0.70),
                     (255, 255, 255, 255), 0.30)

    bold = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 62)
    light = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 30)
    tiny = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)

    x = 86 + height * 0.40 + 56
    draw.text((x, height * 0.28), "OpenCode Mobile", font=bold, fill=(255, 255, 255, 255))
    draw.text((x, height * 0.47), "Your OpenCode sessions, live, from your phone",
              font=light, fill=(255, 236, 224, 255))
    draw.text((x, height * 0.63), "by Global Web Solutions", font=tiny,
              fill=(255, 220, 200, 235))
    return img


def ios_icon(size: int) -> Image.Image:
    """iOS masks the icon itself, so the artwork is a full-bleed opaque square
    (App Store rejects icons with an alpha channel)."""
    s = size * SS
    icon = gradient(s).convert("RGBA")
    draw_prompt_mark(
        ImageDraw.Draw(icon),
        (s * 0.26, s * 0.30, s * 0.74, s * 0.70),
        (255, 255, 255, 255),
    )
    return icon.resize((size, size), Image.LANCZOS).convert("RGB")


# Every slot Flutter's AppIcon.appiconset declares (name -> pixels).
IOS_ICON_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def adaptive_foreground(size: int = 432, fill=(255, 255, 255, 255)) -> Image.Image:
    """Foreground layer of the adaptive icon (108dp canvas, content inside the
    central safe zone so no launcher mask can clip the mark)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_prompt_mark(
        ImageDraw.Draw(img),
        (size * 0.23, size * 0.36, size * 0.77, size * 0.64),
        fill,
    )
    return img


ADAPTIVE_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/generate_brand_assets.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
"""

ADAPTIVE_BACKGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/generate_brand_assets.py -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="270"
        android:startColor="#F69830"
        android:endColor="#C2410C"
        android:type="linear" />
</shape>
"""


def write_notification_icon(path: str) -> None:
    """Vector `>_` notification icon (white on transparent, 24dp)."""
    xml = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/generate_brand_assets.py — the `>_` brand mark. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:pathData="M8.4,5.6 L15.4,12 L8.4,18.4"
        android:strokeColor="#FFFFFF"
        android:strokeWidth="2.6"
        android:strokeLineCap="round"
        android:strokeLineJoin="round" />
    <path
        android:pathData="M16,18.4 L21,18.4"
        android:strokeColor="#FFFFFF"
        android:strokeWidth="2.6"
        android:strokeLineCap="round" />
</vector>
"""
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(xml)


def main() -> None:
    # 1) Legacy launcher icons + round variant.
    for folder, size in (
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ):
        out = os.path.join(RES, folder)
        os.makedirs(out, exist_ok=True)
        launcher_icon(size).save(os.path.join(out, "ic_launcher.png"))
        launcher_icon(size, round_=True).save(os.path.join(out, "ic_launcher_round.png"))

    # 2) Splash logo (shown on the native launch background).
    splash_dir = os.path.join(RES, "drawable-xxhdpi")
    os.makedirs(splash_dir, exist_ok=True)
    launcher_icon(288).save(os.path.join(splash_dir, "splash_logo.png"))

    # 3) Adaptive icon layers (Android 8+) + themed monochrome layer.
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w", encoding="utf-8") as handle:
            handle.write(ADAPTIVE_ICON_XML)
    with open(os.path.join(RES, "drawable", "ic_launcher_background.xml"), "w",
              encoding="utf-8") as handle:
        handle.write(ADAPTIVE_BACKGROUND_XML)
    adaptive_dir = os.path.join(RES, "drawable-xxxhdpi")
    os.makedirs(adaptive_dir, exist_ok=True)
    adaptive_foreground().save(os.path.join(adaptive_dir, "ic_launcher_foreground.png"))
    adaptive_foreground(fill=(0, 0, 0, 255)).save(
        os.path.join(adaptive_dir, "ic_launcher_monochrome.png")
    )

    # 4) Notification status icon.
    write_notification_icon(os.path.join(RES, "drawable", "ic_stat_ic_notification.xml"))

    # 5) iOS app icon set (full-bleed, no alpha).
    ios_set = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets",
                           "AppIcon.appiconset")
    if os.path.isdir(ios_set):
        for name, pixels in IOS_ICON_SIZES.items():
            ios_icon(pixels).save(os.path.join(ios_set, name))

    # 6) Play Store assets.
    os.makedirs(STORE, exist_ok=True)
    mark_only(512).convert("RGB").save(os.path.join(STORE, "play_icon_512.png"))
    # Transparent mark for press kits / README.
    launcher_icon(512).save(os.path.join(STORE, "logo_mark_512.png"))
    feature_graphic().convert("RGB").save(
        os.path.join(STORE, "feature_graphic_1024x500.png")
    )

    print("brand assets written:")
    print(f"  {RES}/mipmap-*/ (ic_launcher, ic_launcher_round)")
    print(f"  {RES}/drawable-xxhdpi/splash_logo.png")
    print(f"  {RES}/drawable/ic_stat_ic_notification.xml")
    print(f"  {STORE}/play_icon_512.png")
    print(f"  {STORE}/logo_mark_512.png")
    print(f"  {STORE}/feature_graphic_1024x500.png")


if __name__ == "__main__":
    main()
