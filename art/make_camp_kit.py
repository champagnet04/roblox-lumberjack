"""Sculpts the camp pieces that plain Roblox parts cannot do well (rocks, a stump, a log, the cooking
sticks and the meat) and writes them as one 3D model (art/models/camp_kit.obj) to import into Studio.

Each shape is described as a field of distances, turned into a surface, and thinned. The script also
draws pictures of the pieces, and of a camp put together from them, so the look can be judged without
opening Studio.

Needs numpy, scikit-image, pillow and fast-simplification:
    python3 -m venv .venv && .venv/bin/pip install numpy scikit-image pillow fast-simplification
    .venv/bin/python art/make_camp_kit.py [folder for the pictures]

Sizes are in studs. Rocks, the stump and the forked stick stand on y = 0. The log, the crossbar and
the meat lie along X, centred on their own axis.
"""

import os
import sys

import fast_simplification
import numpy as np
from PIL import Image
from skimage import measure

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

BARK = (92, 66, 44)
STONE = (120, 118, 112)
STICK = (122, 92, 60)
MEAT = (134, 70, 44)
CHARRED = (48, 40, 36)
CUT_WOOD = (196, 160, 110)
GROUND = (74, 62, 46)


# ---- Building blocks -------------------------------------------------------------------------


def points(low, high, cell):
    axes = [np.arange(low[i], high[i] + cell, cell, dtype=np.float32) for i in range(3)]
    return np.meshgrid(*axes, indexing="ij")


def oval(P, centre, radii):
    X, Y, Z = P
    k = np.sqrt(
        ((X - centre[0]) / radii[0]) ** 2
        + ((Y - centre[1]) / radii[1]) ** 2
        + ((Z - centre[2]) / radii[2]) ** 2
    )
    return (k - 1.0) * min(radii)


def capsule(P, a, b, ra, rb):
    """A rounded stick from a to b, ra thick at a and rb thick at b."""
    X, Y, Z = P
    ab = np.array(b, dtype=np.float32) - np.array(a, dtype=np.float32)
    px, py, pz = X - a[0], Y - a[1], Z - a[2]
    h = np.clip((px * ab[0] + py * ab[1] + pz * ab[2]) / float(ab @ ab), 0, 1)
    distance = np.sqrt((px - ab[0] * h) ** 2 + (py - ab[1] * h) ** 2 + (pz - ab[2] * h) ** 2)
    return distance - (ra + (rb - ra) * h)


def join(a, b, k):
    """The two shapes together, with the crease between them smoothed over a distance k."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def keep(a, b, k):
    """Only the part of shape a that is also inside shape b."""
    return -join(-a, -b, k)


def noise(P, scale, seed):
    """A gentle, wandering unevenness between about -1 and 1."""
    X, Y, Z = P
    rng = np.random.default_rng(seed)
    total = np.zeros_like(X)
    for _ in range(5):
        k = rng.normal(size=3) / scale
        total += np.sin(X * k[0] + Y * k[1] + Z * k[2] + rng.uniform(0, 6.28))
    return total / 2.5


# ---- The pieces ------------------------------------------------------------------------------


def rock(radii, seed):
    """A lumpy boulder with a few flat, chipped faces and a flat underside."""
    rx, ry, rz = radii
    low, high = (-rx - 0.3, 0.0, -rz - 0.3), (rx + 0.3, ry * 1.6 + 0.3, rz + 0.3)
    P = points(low, high, 0.05)
    X, Y, Z = P
    centre_y = ry * 0.55
    field = oval(P, (0, centre_y, 0), radii) + noise(P, 0.8, seed) * 0.1
    rng = np.random.default_rng(seed)
    for _ in range(8):
        n = rng.normal(size=3)
        n /= np.linalg.norm(n)
        reach = np.sqrt((n[0] * rx) ** 2 + (n[1] * ry) ** 2 + (n[2] * rz) ** 2)
        face = X * n[0] + (Y - centre_y) * n[1] + Z * n[2] - reach * rng.uniform(0.66, 0.92)
        field = keep(field, face, 0.07)
    return field, low, 0.05


def stump():
    """An upright stump: roots flaring at the ground, furrowed bark, a flat sawn top."""
    low, high = (-1.9, 0.0, -1.9), (1.9, 2.45, 1.9)
    P = points(low, high, 0.05)
    X, Y, Z = P
    r, angle = np.sqrt(X**2 + Z**2), np.arctan2(Z, X)
    radius = 1.0 + 0.06 * noise(P, 1.2, 11)
    roots = 0.55 + 0.45 * np.cos(5 * angle + 0.8 + 0.6 * np.sin(2 * angle))
    radius += 0.6 * np.exp(-Y / 0.42) * roots
    furrow = np.abs(np.sin(9 * angle + 1.4 * noise(P, 0.8, 12) + 0.4 * Y))
    radius += 0.075 * (furrow - 0.6)
    return keep(r - radius, Y - 2.1, 0.05), low, 0.05


def log():
    """A felled log lying along X: furrowed bark, a slight bend, a knot, and sawn ends."""
    low, high = (-3.1, -0.95, -0.95), (3.1, 0.95, 0.95)
    P = points(low, high, 0.05)
    X, Y, Z = P
    z = Z - 0.1 * np.cos(np.pi * X / 6.0)
    r, angle = np.sqrt(Y**2 + z**2), np.arctan2(z, Y)
    radius = 0.6 + 0.04 * noise(P, 1.5, 21) - 0.012 * X
    furrow = np.abs(np.sin(7 * angle + 1.5 * noise(P, 0.9, 22) + 0.25 * X))
    radius += 0.06 * (furrow - 0.6)
    side = join(r - radius, oval(P, (1.1, 0.45, 0.4), (0.24, 0.24, 0.24)), 0.12)
    return keep(side, np.abs(X) - 3.0, 0.04), low, 0.05


def forked_stick():
    """An upright stick ending in a fork, to hold the crossbar over the fire."""
    low, high = (-1.1, 0.0, -0.5), (1.1, 5.15, 0.5)
    P = points(low, high, 0.035)
    field = capsule(P, (0, 0, 0), (0.07, 1.9, 0.05), 0.27, 0.25)
    field = join(field, capsule(P, (0.07, 1.9, 0.05), (0, 3.7, 0), 0.25, 0.23), 0.1)
    field = join(field, capsule(P, (0, 3.6, 0), (-0.75, 4.9, 0.05), 0.2, 0.13), 0.14)
    field = join(field, capsule(P, (0, 3.6, 0), (0.68, 4.75, -0.05), 0.19, 0.13), 0.14)
    field = join(field, oval(P, (0.2, 2.6, 0.12), (0.15, 0.18, 0.15)), 0.08)  # a knot
    return field + noise(P, 0.35, 31) * 0.02, low, 0.035


def crossbar():
    """A long, slightly crooked stick lying along X."""
    low, high = (-4.95, -0.4, -0.45), (4.95, 0.65, 0.45)
    P = points(low, high, 0.035)
    spine = [(-4.7, 0, 0), (-2.2, 0.1, 0.08), (0.3, -0.05, -0.06), (2.6, 0.09, 0.05), (4.7, -0.02, 0)]
    thick = [0.17, 0.17, 0.16, 0.14, 0.12]
    field = capsule(P, spine[0], spine[1], thick[0], thick[1])
    for i in range(1, 4):
        field = join(field, capsule(P, spine[i], spine[i + 1], thick[i], thick[i + 1]), 0.08)
    field = join(field, capsule(P, (2.6, 0.09, 0.05), (3.05, 0.45, 0.2), 0.08, 0.05), 0.06)  # a twig stub
    return field + noise(P, 0.35, 41) * 0.015, low, 0.035


def meat():
    """A joint of meat tied with string, skewered along X, hanging a little below the stick."""
    low, high = (-1.3, -1.0, -0.85), (1.65, 0.65, 0.85)
    P = points(low, high, 0.04)
    field = join(oval(P, (0, -0.15, 0), (0.95, 0.62, 0.6)), oval(P, (0.9, -0.05, 0), (0.5, 0.38, 0.38)), 0.3)
    field += noise(P, 0.45, 51) * 0.045
    for along in (-0.5, 0.0, 0.5, 0.95):  # the string bites in
        field += 0.05 * np.exp(-(((P[0] - along) / 0.06) ** 2))
    return field, low, 0.04


# name, shape, triangles to thin it to, colour in the pictures
PIECES = [
    ("RockA", lambda: rock((1.1, 0.8, 0.9), 1), 900, STONE),
    ("RockB", lambda: rock((0.9, 0.65, 1.15), 2), 900, STONE),
    ("RockC", lambda: rock((1.25, 0.6, 0.8), 3), 900, STONE),
    ("Stump", stump, 4000, BARK),
    ("Log", log, 2500, BARK),
    ("ForkedStick", forked_stick, 1500, STICK),
    ("Crossbar", crossbar, 1200, STICK),
    ("Meat", meat, 1200, MEAT),
]


# ---- Turning the shapes into a model ---------------------------------------------------------


def surface(field, low, cell, target):
    # Close every side, so each piece is a solid.
    field = field.copy()
    for axis in range(3):
        edge = [slice(None)] * 3
        for index in (0, -1):
            edge[axis] = index
            field[tuple(edge)] = 1
    verts, faces, _, _ = measure.marching_cubes(field, level=0, spacing=(cell, cell, cell))
    verts = verts + np.array(low)
    if len(faces) > target:
        verts, faces = fast_simplification.simplify(
            verts.astype(np.float32), faces.astype(np.int32), target_count=target, agg=4
        )
    return np.asarray(verts, dtype=np.float64), np.asarray(faces)


def normals_of(verts, faces):
    tri = verts[faces]
    face_normals = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    normals = np.zeros_like(verts)
    for corner in range(3):
        np.add.at(normals, faces[:, corner], face_normals)
    length = np.linalg.norm(normals, axis=1, keepdims=True)
    return normals / np.maximum(length, 1e-9)


def write_obj(kit, path):
    """Writes the pieces side by side in a row, so they can be told apart in Studio's import window."""
    with open(path, "w") as out:
        out.write("# Camp kit for One More Tree: Forest Escape. Made by art/make_camp_kit.py.\n")
        offset, along = 1, 0.0
        for name, _, _, _ in PIECES:
            verts, faces = kit[name]
            width = verts[:, 0].max() - verts[:, 0].min()
            shifted = verts + np.array([along - verts[:, 0].min(), 0, 0])
            along += width + 1.5
            normals = normals_of(verts, faces)
            # Studio splits the file into meshes by group ("g"); with only "o" it merges them all.
            out.write(f"o {name}\ng {name}\n")
            for v in shifted:
                out.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
            for n in normals:
                out.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
            for f in faces + offset:
                out.write(f"f {f[0]}//{f[0]} {f[1]}//{f[1]} {f[2]}//{f[2]}\n")
            offset += len(verts)


# ---- Pictures --------------------------------------------------------------------------------


def turned(yaw=0.0, pitch=0.0, roll=0.0):
    a, b, c = np.radians(yaw), np.radians(pitch), np.radians(roll)
    about_y = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    about_x = np.array([[1, 0, 0], [0, np.cos(b), -np.sin(b)], [0, np.sin(b), np.cos(b)]])
    about_z = np.array([[np.cos(c), -np.sin(c), 0], [np.sin(c), np.cos(c), 0], [0, 0, 1]])
    return about_y @ about_x @ about_z


def placed(kit, name, at, colour, yaw=0.0, pitch=0.0, roll=0.0, scale=1.0):
    verts, faces = kit[name]
    return (verts * np.array(scale)) @ turned(yaw, pitch, roll).T + np.array(at), faces, colour


def disc(at, radius, colour, rotation=None):
    """A flat round patch facing up, or turned by `rotation`."""
    angles = np.linspace(0, 2 * np.pi, 40, endpoint=False)
    rim = np.stack([np.cos(angles) * radius, np.zeros(40), np.sin(angles) * radius], axis=1)
    verts = np.concatenate([[[0, 0, 0]], rim])
    if rotation is not None:
        verts = verts @ rotation.T
    verts = verts + np.array(at)
    faces = np.array([[0, 1 + (i + 1) % 40, 1 + i] for i in range(40)])
    return verts, faces, colour


def log_with_ends(kit, at, colour, ends, yaw=0.0, pitch=0.0, roll=0.0, scale=1.0):
    """A log, with a pale sawn face at each end (in the game these are plain discs added in code)."""
    spin = turned(yaw, pitch, roll)
    things = [placed(kit, "Log", at, colour, yaw, pitch, roll, scale)]
    for side in (-1, 1):
        end = np.array(at) + spin @ np.array([side * 3.01 * scale, 0, 0])
        things.append(disc(end, 0.5 * scale, ends, spin @ turned(roll=-90 * side)))
    return things


def draw(things, path, turn, tilt, focus, pixels_per_stud, size=(1200, 800)):
    """A picture of the things, turned by `turn` degrees about the upright and tipped by `tilt`."""
    a, b = np.radians(turn), np.radians(tilt)
    spin = np.array([[np.cos(a), 0, -np.sin(a)], [0, 1, 0], [np.sin(a), 0, np.cos(a)]])
    tip = np.array([[1, 0, 0], [0, np.cos(b), -np.sin(b)], [0, np.sin(b), np.cos(b)]])
    view = tip @ spin
    light = np.array([-0.45, 0.65, 0.6])
    light /= np.linalg.norm(light)

    width, height = size
    picture = np.full((height, width, 3), (34, 40, 48), dtype=np.uint8)
    depth = np.full((height, width), -np.inf)
    for verts, faces, colour in things:
        tri = ((verts - np.array(focus, dtype=float)) @ view.T)[faces]
        normal = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-9)
        shade = np.clip(normal @ light, 0, 1) * 0.65 + 0.35
        px = width / 2 + tri[:, :, 0] * pixels_per_stud
        py = height / 2 - tri[:, :, 1] * pixels_per_stud
        for index in np.nonzero(normal[:, 2] > 0)[0]:
            xs, ys, zs = px[index], py[index], tri[index, :, 2]
            x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, width - 1)
            y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, height - 1)
            if x0 > x1 or y0 > y1:
                continue
            area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
            if abs(area) < 1e-9:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            w0 = ((xs[1] - gx) * (ys[2] - gy) - (xs[2] - gx) * (ys[1] - gy)) / area
            w1 = ((xs[2] - gx) * (ys[0] - gy) - (xs[0] - gx) * (ys[2] - gy)) / area
            w2 = 1 - w0 - w1
            z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
            window = depth[y0 : y1 + 1, x0 : x1 + 1]
            hit = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6) & (z > window)
            window[hit] = z[hit]
            picture[y0 : y1 + 1, x0 : x1 + 1][hit] = (np.array(colour) * shade[index]).astype(np.uint8)
    Image.fromarray(picture).save(path)


def kit_sheet(kit):
    """Every piece once, in a row."""
    things, along = [], 0.0
    for name, _, _, colour in PIECES:
        verts, _ = kit[name]
        lift = -min(verts[:, 1].min(), 0)
        things.append(placed(kit, name, (along - verts[:, 0].min(), lift, 0), colour))
        along += verts[:, 0].max() - verts[:, 0].min() + 1.0
    return things, along


def camp_scene(kit):
    """Builds 1 to 4 put together: fire pit, stump stools, cooking frame, woodpile."""
    rng = np.random.default_rng(7)
    things = [disc((0, -0.01, 0), 16, GROUND)]

    # Fire pit: a ring of rocks, no two alike, around a small stack of burning logs.
    count = 11
    for i in range(count):
        angle = 2 * np.pi * i / count + rng.uniform(-0.08, 0.08)
        size = rng.uniform(0.6, 0.85)
        at = (np.cos(angle) * 2.6, -0.08, np.sin(angle) * 2.6)
        name = ("RockA", "RockB", "RockC")[i % 3]
        things.append(placed(kit, name, at, STONE, yaw=rng.uniform(0, 360), scale=size))
    for i in range(4):
        spin = turned(yaw=90 * i + 20)
        at = spin @ np.array([0.62, 0.95, 0])
        things += log_with_ends(kit, at, CHARRED, CHARRED, yaw=90 * i + 20, roll=122, scale=0.4)

    # Cooking frame: a forked stick either side of the fire, a crossbar in the forks, meat on the bar.
    for side in (-1, 1):
        things.append(placed(kit, "ForkedStick", (0, -0.35, side * 3.9), STICK, yaw=8 * side))
    things.append(placed(kit, "Crossbar", (0, 3.62, 0), STICK, yaw=90))
    things.append(placed(kit, "Meat", (0, 3.62, 0.2), MEAT, yaw=90))

    # Stump stools in an arc on the spawn side of the fire.
    for angle, size, turn in ((-38, 1.0, 20), (0, 0.9, 140), (38, 1.05, 260)):
        at = (np.cos(np.radians(angle)) * 7.0, 0, np.sin(np.radians(angle)) * 7.0)
        things.append(placed(kit, "Stump", at, BARK, yaw=turn, scale=(size, size * 0.85, size)))
        things.append(disc((at[0], 2.1 * size * 0.85 + 0.02, at[2]), 0.9 * size, CUT_WOOD))

    # Woodpile: logs stacked three, two, one, held by an upright stake at each side.
    base = np.array([-8.0, 0, -6.5])
    rows = [(-1.3, 0.0, 1.3), (-0.65, 0.65), (0.0,)]
    for row, offsets in enumerate(rows):
        for offset in offsets:
            at = base + np.array([0, 0.58 + row * 1.08, offset])
            flip = 180 if rng.uniform() < 0.5 else 0
            things += log_with_ends(kit, at, BARK, CUT_WOOD, yaw=flip, pitch=rng.uniform(0, 360))
    for side in (-1, 1):
        at = base + np.array([0, 1.5, side * 2.15])
        things.append(placed(kit, "Crossbar", at, STICK, roll=90, scale=(0.4, 1.2, 1.2)))
    return things


def main():
    pictures = sys.argv[1] if len(sys.argv) > 1 else OUT
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(pictures, exist_ok=True)

    kit = {}
    for name, shape, target, _ in PIECES:
        verts, faces = surface(*shape(), target)
        kit[name] = (verts, faces)
        size = verts.max(axis=0) - verts.min(axis=0)
        middle = (verts.max(axis=0) + verts.min(axis=0)) / 2
        print(
            f"{name}: {len(faces)} triangles, size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f},"
            f" middle at {middle[0]:.2f}, {middle[1]:.2f}, {middle[2]:.2f}"
        )
    write_obj(kit, os.path.join(OUT, "camp_kit.obj"))

    sheet, length = kit_sheet(kit)
    draw(sheet, os.path.join(pictures, "kit_pieces.png"), 20, 22, (length / 2, 1.6, 0), 1150 / length, (1200, 500))
    scene = camp_scene(kit)
    draw(scene, os.path.join(pictures, "camp_from_spawn.png"), 60, 24, (-1, 1.6, -1), 44)
    draw(scene, os.path.join(pictures, "camp_fire_close.png"), 35, 18, (0, 2.0, 0), 95)
    draw(scene, os.path.join(pictures, "camp_stools_woodpile.png"), 150, 20, (-1, 1.4, -2), 50)


if __name__ == "__main__":
    main()
