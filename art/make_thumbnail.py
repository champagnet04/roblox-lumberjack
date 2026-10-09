"""Draws the game thumbnail: the lumberjack running for the campfire with the guardian behind.

Run with the project's Python environment:
    .venv/bin/python art/make_thumbnail.py

Writes art/icon/game_thumbnail.png at 1920 x 1080, the size Roblox asks for. Same style
and colours as the icon (see make_icon.py). There is no title on it because the game's
name is not decided.
"""

import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 1920, 1080
K = 2  # drawn at twice the final size, then shrunk, so edges come out smooth
OUT = os.path.join(os.path.dirname(__file__), "icon", "game_thumbnail.png")

NIGHT_TOP = (12, 30, 44)
NIGHT_BOTTOM = (3, 9, 12)
HAZE = (40, 96, 104)
FAR_PINE = (10, 34, 38)
MID_PINE = (6, 22, 24)
NEAR_PINE = (3, 12, 12)
GUARDIAN = (4, 13, 12)
EYE = (200, 255, 130)
FLAME = (255, 140, 30)
FLAME_CORE = (255, 244, 190)
FLANNEL = (184, 38, 38)
FLANNEL_DARK = (112, 20, 24)
JEANS = (48, 68, 108)
BOOT = (40, 28, 22)
SKIN = (236, 190, 146)
HAIR = (70, 44, 28)
WOOD = (120, 84, 54)
DARK_WOOD = (70, 48, 32)
SAWN = (214, 176, 120)
STEEL = (176, 182, 190)
ROCK = (96, 98, 104)
CLOTH = (150, 128, 96)
CLOTH_DARK = (112, 94, 70)
GROUND = (5, 12, 10)


def k(points):
    return [(x * K, y * K) for x, y in points]


def poly(draw, points, fill):
    draw.polygon(k(points), fill=fill)


def rect(draw, x0, y0, x1, y1, fill, radius=0):
    box = [x0 * K, y0 * K, x1 * K, y1 * K]
    if radius:
        draw.rounded_rectangle(box, radius=radius * K, fill=fill)
    else:
        draw.rectangle(box, fill=fill)


def oval(draw, x0, y0, x1, y1, fill):
    draw.ellipse([x0 * K, y0 * K, x1 * K, y1 * K], fill=fill)


def limb(draw, points, width, colour):
    """A thick line with round ends and joints."""
    draw.line(k(points), fill=colour, width=width * K, joint="curve")
    for px, py in points:
        oval(draw, px - width / 2, py - width / 2, px + width / 2, py + width / 2, colour)


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (W * K, H * K))
    draw = ImageDraw.Draw(img)
    for y in range(H * K):
        t = y / (H * K - 1)
        draw.line(
            [(0, y), (W * K, y)],
            fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return img


def add_glow(img, centre, radius, colour):
    """Lightens the picture with a soft round glow that fades to nothing at its edge."""
    size = radius * 2 * K
    falloff = (
        Image.radial_gradient("L")
        .point(lambda v: round(255 * max(0.0, 1 - v / 178) ** 1.6))
        .resize((size, size))
    )
    layer = Image.new("RGB", img.size, (0, 0, 0))
    layer.paste(
        Image.new("RGB", falloff.size, colour),
        ((centre[0] - radius) * K, (centre[1] - radius) * K),
        falloff,
    )
    return ImageChops.screen(img, layer)


def pine(draw, x, base_y, height, width, colour, tiers=5):
    rect(draw, x - width * 0.06, base_y - height * 0.3, x + width * 0.06, base_y, colour)
    for i in range(tiers):
        t = i / tiers
        tier_width = width * (1 - t * 0.78)
        bottom = base_y - height * (0.12 + t * 0.72)
        top = bottom - height * 0.34
        poly(draw, [(x - tier_width / 2, bottom), (x + tier_width / 2, bottom), (x, top)], colour)


def flame_glow(img, x, y, glow):
    img = add_glow(img, (x, y + 10), glow, (255, 120, 30))
    return add_glow(img, (x, y), round(glow * 0.4), (200, 110, 40))


def flame(img, x, y, size=1.0, glow=470):
    if glow:
        img = flame_glow(img, x, y, glow)
    draw = ImageDraw.Draw(img)

    def shape(points):
        return [(x + dx * size, y + dy * size) for dx, dy in points]

    poly(
        draw,
        shape([(0, -105), (30, -45), (46, 5), (30, 46), (0, 58), (-32, 44), (-46, 0), (-22, -40), (-26, -78)]),
        FLAME,
    )
    poly(draw, shape([(2, -50), (22, 0), (14, 36), (0, 44), (-18, 32), (-22, -2)]), FLAME_CORE)
    return img


def guardian(img, cx, scale):
    """The antlered guardian, looming out of the trees and reaching after the lumberjack."""

    def at(dx, y):
        return (cx + dx * scale, y * scale - 70)

    draw = ImageDraw.Draw(img)
    poly(
        draw,
        [at(-402, 1024), at(-342, 640), at(-212, 505), at(-82, 455), at(82, 455), at(212, 505),
         at(342, 640), at(402, 1024)],
        GUARDIAN,
    )
    for side in (-1, 1):
        x0, y0 = at(side * 202 - 160, 470)
        x1, y1 = at(side * 202 + 160, 790)
        oval(draw, x0, y0, x1, y1, GUARDIAN)
    poly(draw, [at(-100, 300), at(100, 300), at(54, 500), at(-54, 500)], GUARDIAN)
    x0, y0 = at(-100, 215)
    x1, y1 = at(100, 395)
    oval(draw, x0, y0, x1, y1, GUARDIAN)

    for side in (-1, 1):
        limb(draw, [at(side * 60, 290), at(side * 120, 210), at(side * 205, 150), at(side * 250, 60)], 30, GUARDIAN)
        limb(draw, [at(side * 120, 210), at(side * 110, 110), at(side * 140, 50)], 20, GUARDIAN)
        limb(draw, [at(side * 205, 150), at(side * 300, 150), at(side * 360, 95)], 20, GUARDIAN)
        limb(draw, [at(side * 160, 180), at(side * 250, 235), at(side * 330, 225)], 18, GUARDIAN)

    eyes = Image.new("RGB", img.size, (0, 0, 0))
    eye_draw = ImageDraw.Draw(eyes)
    for side in (-1, 1):
        poly(
            eye_draw,
            [at(side * 50 - side * 34, 352), at(side * 50, 322), at(side * 50 + side * 36, 318), at(side * 50 + side * 6, 362)],
            EYE,
        )
    glow = eyes.filter(ImageFilter.GaussianBlur(30 * K))
    img = ImageChops.screen(img, glow)
    img = ImageChops.screen(img, glow)
    return ImageChops.lighter(img, eyes)


def guardian_arm(img, cx, scale):
    """A long arm reaching after the lumberjack, ending in three claws. Drawn after the
    torch's glow so that it shows dark against the light."""

    def at(dx, y):
        return (cx + dx * scale, y * scale - 70)

    draw = ImageDraw.Draw(img)
    hand = at(-290, 640)
    limb(draw, [at(-150, 560), at(-215, 690), hand], 44, GUARDIAN)
    for dx, dy in ((-70, -52), (-92, -6), (-76, 40)):
        limb(draw, [hand, (hand[0] + dx, hand[1] + dy)], 15, GUARDIAN)
    return img


def camp(img):
    """The safe place on the left: a lean-to, stump stools and the campfire."""
    draw = ImageDraw.Draw(img)

    # Lean-to: two posts, a ridge pole and a patched cloth cover sloping to the ground.
    limb(draw, [(150, 920), (160, 690)], 14, DARK_WOOD)
    limb(draw, [(430, 920), (424, 676)], 14, DARK_WOOD)
    poly(draw, [(120, 700), (460, 676), (500, 870), (60, 900)], CLOTH)
    poly(draw, [(230, 692), (300, 687), (322, 880), (240, 886)], CLOTH_DARK)
    poly(draw, [(370, 760), (430, 756), (440, 820), (378, 824)], CLOTH_DARK)
    limb(draw, [(100, 702), (480, 672)], 14, DARK_WOOD)

    # Stump stools with pale sawn tops.
    for x in (560, 250):
        rect(draw, x - 34, 880, x + 34, 940, DARK_WOOD)
        oval(draw, x - 36, 866, x + 36, 894, SAWN)

    img = flame(img, 400, 850, size=1.25, glow=620)
    draw = ImageDraw.Draw(img)
    limb(draw, [(340, 930), (440, 900)], 20, (44, 30, 22))
    limb(draw, [(460, 930), (372, 898)], 20, (58, 40, 28))
    for i, x in enumerate((300, 336, 380, 424, 466, 500)):
        shade = ROCK if i % 2 == 0 else (70, 72, 78)
        oval(draw, x - 26, 916, x + 26, 954, shade)
    return img


def lumberjack(img, fx):
    """A blocky lumberjack in red flannel, running left for the fire with his torch held high."""
    img = flame(img, fx + 136, 440, glow=0)  # its glow is added in main, before the arm
    draw = ImageDraw.Draw(img)

    # Back leg kicked up behind, front leg stretched ahead.
    limb(draw, [(fx + 40, 836), (fx + 110, 880), (fx + 176, 850)], 50, JEANS)
    limb(draw, [(fx + 176, 850), (fx + 206, 836)], 46, BOOT)
    limb(draw, [(fx - 30, 836), (fx - 96, 890), (fx - 120, 944)], 50, JEANS)
    limb(draw, [(fx - 120, 944), (fx - 160, 948)], 44, BOOT)

    # Torch in the trailing hand, held up behind his head.
    limb(draw, [(fx + 118, 640), (fx + 134, 520)], 16, (96, 66, 44))
    oval(draw, fx + 114, 488, fx + 158, 532, (40, 30, 26))

    # Torso, leaning into the run, with a plaid of darker lines.
    poly(draw, [(fx - 92, 700), (fx + 56, 692), (fx + 84, 836), (fx - 64, 846)], FLANNEL)
    for dx in (-52, -10, 34):
        poly(draw, [(fx + dx - 5, 698), (fx + dx + 5, 697), (fx + dx + 33, 842), (fx + dx + 23, 843)], FLANNEL_DARK)
    for dy in (734, 780, 824):
        poly(draw, [(fx - 90, dy - 3), (fx + 66, dy - 11), (fx + 68, dy - 1), (fx - 88, dy + 7)], FLANNEL_DARK)

    limb(draw, [(fx + 52, 716), (fx + 114, 624)], 46, FLANNEL)
    oval(draw, fx + 94, 600, fx + 142, 648, SKIN)

    # Axe swung forward in the leading hand.
    limb(draw, [(fx - 150, 792), (fx - 268, 668)], 16, WOOD)
    poly(draw, [(fx - 300, 690), (fx - 232, 630), (fx - 262, 588), (fx - 348, 632), (fx - 342, 676)], STEEL)
    poly(draw, [(fx - 348, 632), (fx - 342, 676), (fx - 362, 664), (fx - 364, 644)], (226, 230, 236))
    limb(draw, [(fx - 86, 720), (fx - 148, 790)], 46, FLANNEL)
    oval(draw, fx - 174, 768, fx - 126, 816, SKIN)

    # Head, turned to look back over his shoulder, with a frightened face.
    rect(draw, fx - 76, 606, fx + 12, 694, SKIN, radius=14)
    rect(draw, fx - 82, 594, fx + 18, 634, HAIR, radius=14)
    oval(draw, fx - 40, 642, fx - 26, 660, (30, 22, 20))
    oval(draw, fx - 6, 642, fx + 8, 660, (30, 22, 20))
    oval(draw, fx - 28, 670, fx - 6, 688, (96, 44, 40))
    return img


def main():
    random.seed(11)
    img = vertical_gradient(NIGHT_TOP, NIGHT_BOTTOM)
    img = add_glow(img, (1400, 340), 760, HAZE)  # pale mist behind the guardian, so it shows

    draw = ImageDraw.Draw(img)
    for i in range(20):
        x = 30 + i * 100 + random.randint(-26, 26)
        pine(draw, x, 860, random.randint(430, 640), random.randint(170, 240), FAR_PINE)
    for x in (640, 760, 1010, 1130):
        pine(draw, x + random.randint(-20, 20), 900, random.randint(600, 760), 270, MID_PINE)

    img = guardian(img, 1440, 1.1)
    img = camp(img)

    draw = ImageDraw.Draw(img)
    rect(draw, 0, 936, W, H, GROUND)
    img = flame_glow(img, 1036, 440, 430)
    img = guardian_arm(img, 1440, 1.1)
    img = lumberjack(img, 900)

    # Big dark pines at the edges frame the picture.
    draw = ImageDraw.Draw(img)
    pine(draw, -70, 1120, 1080, 400, NEAR_PINE, tiers=6)
    pine(draw, 1900, 1120, 1100, 460, NEAR_PINE, tiers=6)
    pine(draw, 1690, 1130, 820, 340, NEAR_PINE, tiers=6)

    # Darken the corners a little.
    edges = Image.radial_gradient("L").resize(img.size).point(lambda v: int(max(0, v - 130) * 1.2))
    img = Image.composite(Image.new("RGB", img.size, (0, 0, 0)), img, edges)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.resize((W, H), Image.LANCZOS).save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
