#!/usr/bin/env python3
"""
Generate the Forget Me Note app icon at 1024x1024.

Design: rounded-corner card with two stacked "photo" cards (memory layers),
with a small magnifying-glass accent in the corner. Gradient orange-to-purple
fill matching the app's accent palette.

Run from repo root:
    python3 ios/scripts/generate_app_icon.py
Writes:
    ios/ForgetMeNote/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math

OUT = (Path(__file__).resolve().parent.parent
       / "ForgetMeNote" / "Assets.xcassets" / "AppIcon.appiconset"
       / "AppIcon-1024.png")

SIZE = 1024

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def make_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = lerp(top, bottom, t)
        for x in range(size):
            px[x, y] = c
    return img

def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask

def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)

    # Background: warm orange gradient (top) → deep purple (bottom)
    bg = make_gradient(SIZE, (255, 152, 0), (103, 80, 164))

    # Apple expects square icons; system masks to rounded corners.
    # We still pre-round the visible foreground for any preview contexts.

    # Foreground: two stacked "photo" cards offset slightly.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fg)

    # Back card (sub-space)
    back_rect = (SIZE * 0.20, SIZE * 0.28, SIZE * 0.80, SIZE * 0.68)
    fd.rounded_rectangle(back_rect, radius=SIZE * 0.06,
                         fill=(255, 255, 255, 230),
                         outline=(0, 0, 0, 60), width=4)
    # Sub-space rectangle inside the back card
    sub = (SIZE * 0.30, SIZE * 0.38, SIZE * 0.55, SIZE * 0.54)
    fd.rounded_rectangle(sub, radius=SIZE * 0.015,
                         outline=(124, 106, 247, 255), width=8)

    # Front card (parent space) - offset down-right with subtle shadow
    front_rect = (SIZE * 0.30, SIZE * 0.40, SIZE * 0.92, SIZE * 0.80)
    # Drop shadow for the front card
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(front_rect, radius=SIZE * 0.06, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
    fg = Image.alpha_composite(fg, shadow)
    fd = ImageDraw.Draw(fg)
    fd.rounded_rectangle(front_rect, radius=SIZE * 0.06,
                         fill=(255, 255, 255, 250),
                         outline=(0, 0, 0, 80), width=4)

    # Inside the front card: a stylized "shelf" with three book spines
    shelf_y = front_rect[3] - SIZE * 0.10
    fd.rectangle((front_rect[0] + 24, shelf_y,
                  front_rect[2] - 24, shelf_y + 8),
                 fill=(92, 58, 30, 255))
    book_colors = [(140, 41, 41), (51, 92, 140), (159, 128, 51)]
    bw = (front_rect[2] - front_rect[0] - 80) / 3
    for i, c in enumerate(book_colors):
        bx0 = front_rect[0] + 40 + bw * i
        bx1 = bx0 + bw - 6
        by1 = shelf_y - 4
        by0 = by1 - SIZE * (0.16 + i * 0.02)
        fd.rounded_rectangle((bx0, by0, bx1, by1), radius=4, fill=c)

    # Magnifying glass: top-right corner accent
    mg_cx = SIZE * 0.78
    mg_cy = SIZE * 0.22
    mg_r = SIZE * 0.07
    fd.ellipse((mg_cx - mg_r, mg_cy - mg_r,
                mg_cx + mg_r, mg_cy + mg_r),
               outline=(255, 255, 255, 240), width=12)
    # handle
    h_len = mg_r * 1.2
    angle = math.radians(45)
    hx0 = mg_cx + math.cos(angle) * mg_r
    hy0 = mg_cy + math.sin(angle) * mg_r
    hx1 = hx0 + math.cos(angle) * h_len
    hy1 = hy0 + math.sin(angle) * h_len
    fd.line([(hx0, hy0), (hx1, hy1)],
            fill=(255, 255, 255, 240), width=18)

    # Composite over the gradient
    final = bg.convert("RGBA")
    final = Image.alpha_composite(final, fg)

    # Apple says icons should NOT have transparency. Flatten to RGB.
    final.convert("RGB").save(OUT, "PNG")
    print(f"Wrote {OUT}")

if __name__ == "__main__":
    main()
