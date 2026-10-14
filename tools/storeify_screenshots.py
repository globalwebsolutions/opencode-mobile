#!/usr/bin/env python3
"""Turns raw phone screenshots into Play Store–ready images.

Google Play phone screenshots must be 320–3840 px and no wider/taller than a
2:1 ratio. Raw Android captures are usually taller than that and include the
status/navigation bars, so each shot is trimmed, scaled and centred on the
brand background at 1080x2160 (exactly 2:1).

Usage:  python3 tools/storeify_screenshots.py store/screenshots/raw/*.png
"""
from __future__ import annotations

import os
import sys

from PIL import Image

TARGET_W, TARGET_H = 1080, 2160
# Trimmed from the raw capture: status bar on top, navigation bar at the bottom.
CROP_TOP = 80
CROP_BOTTOM = 100


def background_color(img: Image.Image) -> tuple[int, int, int]:
    """Samples the app background near the top-left below the status bar."""
    width, height = img.size
    return img.getpixel((int(width * 0.05), int(height * 0.18)))[:3]


def storeify(path: str, out_dir: str) -> str:
    raw = Image.open(path).convert("RGB")
    width, height = raw.size

    top = min(CROP_TOP, height // 4)
    bottom = min(CROP_BOTTOM, height // 4)
    shot = raw.crop((0, top, width, height - bottom))

    # Scale to the target width.
    scale = TARGET_W / shot.width
    shot = shot.resize((TARGET_W, max(1, round(shot.height * scale))), Image.LANCZOS)

    canvas = Image.new("RGB", (TARGET_W, TARGET_H), background_color(raw))
    if shot.height >= TARGET_H:
        # Too tall even after trimming: centre-crop.
        offset = (shot.height - TARGET_H) // 2
        shot = shot.crop((0, offset, TARGET_W, offset + TARGET_H))
        canvas.paste(shot, (0, 0))
    else:
        canvas.paste(shot, (0, (TARGET_H - shot.height) // 2))

    os.makedirs(out_dir, exist_ok=True)
    name = os.path.splitext(os.path.basename(path))[0]
    out = os.path.join(out_dir, f"store_{name}.png")
    canvas.save(out, optimize=True)
    return out


def main() -> None:
    args = sys.argv[1:]
    out_dir = "store/screenshots"
    if "--out" in args:
        i = args.index("--out")
        out_dir = args[i + 1]
        del args[i:i + 2]
    if not args:
        print(__doc__)
        raise SystemExit(2)

    for path in args:
        print(f"  {path} -> {storeify(path, out_dir)}")
    print(f"done: {TARGET_W}x{TARGET_H} (2:1) in {out_dir}/")


if __name__ == "__main__":
    main()
