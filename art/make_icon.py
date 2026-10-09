"""Draws the game icon: a lumberjack with a torch and axe, and the guardian's eyes behind.

Run with the project's Python environment:
    .venv/bin/python art/make_icon.py

Writes art/icon/game_icon.png at 512 x 512, the size Roblox asks for. There is no title
on it because the game's name is not decided.
"""

import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024  # drawn at twice the final size, then shrunk, so edges come out smooth
OUT = os.path.join(os.path.dirname(__file__), "icon", "game_icon.png")

NIGHT_TOP = (12, 30, 44)
NIGHT_BOTTOM = (3, 9, 12)
HAZE = (40, 96, 104)
FAR_PINE = (10, 34, 38)
NEAR_PINE = (3, 12, 12)
GUARDIAN = (4, 13, 12)
EYE = (200, 255, 130)
FLAME = (255, 140, 30)
FLAME_CORE = (255, 244, 190)
FLANNEL = (184, 38, 38)
FLANNEL_DARK = (112, 20, 24)
JEANS = (48, 68, 108)
SKIN = (236, 190, 146)
HAIR = (70, 44, 28)
WOOD = (120, 84, 54)
STEEL = (176, 182, 190)


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    draw = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        draw.line(
            [(0, y), (S, y)],
            fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return img


def add_glow(img, centre, radius, colour):
    """Lightens the picture with a soft round glow."""
    # The built-in gradient is still bright at the edges of its square, which showed as a
    # hard box. This makes it reach zero at the circle's edge and fade gently.
    falloff = (
        Image.radial_gradient("L")
        .point(lambda v: round(255 * max(0.0, 1 - v / 178) ** 1.6))
        .resize((radius * 2, radius * 2))
    )
    layer = Image.new("RGB", (S, S), (0, 0, 0))
    layer.paste(
        Image.new("RGB", falloff.size, colour),
        (centre[0] - radius, centre[1] - radius),
        falloff,
    )
    return ImageChops.screen(img, layer)


def pine(draw, x, base_y, height, width, colour, tiers=5):
    draw.rectangle([x - width * 0.06, base_y - height * 0.3, x + width * 0.06, base_y], fill=colour)
    for i in range(tiers):
        t = i / tiers
        tier_width = width * (1 - t * 0.78)
        bottom = base_y - height * (0.12 + t * 0.72)
        top = bottom - height * 0.34
        draw.polygon([(x - tier_width / 2, bottom), (x + tier_width / 2, bottom), (x, top)], fill=colour)


def limb(draw, points, width, colour):
    """A thick line with round ends and joints."""
    draw.line(points, fill=colour, width=width, joint="curve")
    for px, py in points:
        draw.ellipse([px - width / 2, py - width / 2, px + width / 2, py + width / 2], fill=colour)


def antler(draw, side):
    """One antler; side is -1 for the left and 1 for the right."""

    def at(dx, dy):
        return (512 + side * dx, dy)

    limb(draw, [at(60, 290), at(120, 210), at(205, 150), at(250, 60)], 26, GUARDIAN)
    limb(draw, [at(120, 210), at(110, 110), at(140, 50)], 18, GUARDIAN)
    limb(draw, [at(205, 150), at(300, 150), at(360, 95)], 18, GUARDIAN)
    limb(draw, [at(160, 180), at(250, 235), at(330, 225)], 16, GUARDIAN)


def guardian(img):
    draw = ImageDraw.Draw(img)
    # Hulking shoulders and body, rising out of the bottom of the picture.
    draw.polygon(
        [(110, S), (170, 640), (300, 505), (430, 455), (594, 455), (724, 505), (854, 640), (914, S)],
        fill=GUARDIAN,
    )
    draw.ellipse([150, 470, 470, 790], fill=GUARDIAN)
    draw.ellipse([554, 470, 874, 790], fill=GUARDIAN)
    # Long head, narrower at the jaw.
    draw.polygon([(412, 300), (612, 300), (566, 500), (458, 500)], fill=GUARDIAN)
    draw.ellipse([412, 215, 612, 395], fill=GUARDIAN)
    antler(draw, -1)
    antler(draw, 1)

    # Glowing slanted eyes: a blurred copy underneath for the glow, then the sharp eyes.
    eyes = Image.new("RGB", (S, S), (0, 0, 0))
    eye_draw = ImageDraw.Draw(eyes)
    for side in (-1, 1):
        cx = 512 + side * 50
        eye_draw.polygon(
            [(cx - side * 34, 352), (cx, 322), (cx + side * 36, 318), (cx + side * 6, 362)],
            fill=EYE,
        )
    glow = eyes.filter(ImageFilter.GaussianBlur(26))
    img = ImageChops.screen(img, glow)
    img = ImageChops.screen(img, glow)
    return ImageChops.lighter(img, eyes)


def flame(img, x, y):
    img = add_glow(img, (x, y + 10), 470, (255, 120, 30))
    img = add_glow(img, (x, y), 190, (200, 110, 40))
    draw = ImageDraw.Draw(img)
    draw.polygon(
        [(x, y - 105), (x + 30, y - 45), (x + 46, y + 5), (x + 30, y + 46), (x, y + 58),
         (x - 32, y + 44), (x - 46, y), (x - 22, y - 40), (x - 26, y - 78)],
        fill=FLAME,
    )
    draw.polygon(
        [(x + 2, y - 50), (x + 22, y), (x + 14, y + 36), (x, y + 44), (x - 18, y + 32), (x - 22, y - 2)],
        fill=FLAME_CORE,
    )
    return img


def lumberjack(img):
    """A blocky Roblox-style lumberjack: red flannel, jeans, axe on one shoulder, torch held up."""
    draw = ImageDraw.Draw(img)
    # Axe over the shoulder: handle first so the arm and body cover its lower end.
    limb(draw, [(408, 822), (322, 612)], 16, WOOD)
    draw.polygon([(296, 566), (368, 590), (352, 650), (262, 640), (250, 596)], fill=STEEL)
    draw.polygon([(250, 596), (262, 640), (244, 630), (238, 606)], fill=(226, 230, 236))

    # Legs and boots.
    draw.rectangle([450, 830, 506, 950], fill=JEANS)
    draw.rectangle([518, 830, 574, 950], fill=JEANS)
    draw.rectangle([444, 930, 508, 962], fill=(40, 28, 22))
    draw.rectangle([516, 930, 580, 962], fill=(40, 28, 22))

    # Torso in red flannel with a plaid of darker lines.
    draw.rectangle([438, 700, 586, 836], fill=FLANNEL)
    for x in (468, 512, 556):
        draw.rectangle([x - 5, 700, x + 5, 836], fill=FLANNEL_DARK)
    for y in (734, 780, 822):
        draw.rectangle([438, y - 5, 586, y + 5], fill=FLANNEL_DARK)

    # Arm holding the axe.
    limb(draw, [(440, 722), (408, 812)], 46, FLANNEL)
    draw.ellipse([384, 796, 432, 844], fill=SKIN)

    # Torch: handle, charred head, then the raised arm and hand over the handle.
    limb(draw, [(650, 650), (668, 520)], 16, (96, 66, 44))
    draw.ellipse([648, 488, 692, 532], fill=(40, 30, 26))
    limb(draw, [(586, 722), (646, 628)], 46, FLANNEL)
    draw.ellipse([626, 604, 674, 652], fill=SKIN)

    # Head, hair and a simple worried face.
    draw.rounded_rectangle([468, 612, 556, 700], radius=14, fill=SKIN)
    draw.rounded_rectangle([462, 600, 562, 640], radius=14, fill=HAIR)
    draw.ellipse([488, 650, 500, 666], fill=(30, 22, 20))
    draw.ellipse([524, 650, 536, 666], fill=(30, 22, 20))
    draw.rectangle([498, 680, 526, 685], fill=(120, 70, 56))
    return img


def main():
    random.seed(7)
    img = vertical_gradient(NIGHT_TOP, NIGHT_BOTTOM)
    img = add_glow(img, (512, 330), 640, HAZE)  # pale mist behind the guardian, so it shows

    draw = ImageDraw.Draw(img)
    for i in range(11):
        x = 40 + i * 96 + random.randint(-24, 24)
        pine(draw, x, 800, random.randint(440, 620), random.randint(170, 230), FAR_PINE)

    img = guardian(img)
    img = flame(img, 670, 440)

    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 944, S, S], fill=(5, 12, 10))  # ground
    img = lumberjack(img)

    # Big dark pines at both edges frame the picture.
    draw = ImageDraw.Draw(img)
    pine(draw, 40, 1060, 1000, 420, NEAR_PINE, tiers=6)
    pine(draw, 990, 1060, 940, 400, NEAR_PINE, tiers=6)

    # Darken the corners a little.
    edges = Image.radial_gradient("L").resize((S, S)).point(lambda v: int(max(0, v - 120) * 1.3))
    img = Image.composite(Image.new("RGB", (S, S), (0, 0, 0)), img, edges)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.resize((512, 512), Image.LANCZOS).save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
