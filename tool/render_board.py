"""Render the whole hex board as ONE isometric image + export per-cell screen
coordinates, using the same fixed iso camera as render_sprites.py.

    blender --background --python tool/render_board.py -- <config.json>

config.json:
{
  "tile": "/abs/hex_grass.gltf",
  "radius": 5,
  "res": 1600,
  "out_png": "/abs/board.png",
  "out_json": "/abs/board.json"
}

board.json output:
{
  "res": [w, h],
  "ortho_scale": <float>,
  "px_per_unit": <float>,            # render px per Blender world unit
  "cells": [ {"q":q, "r":r, "x":px, "y":px} ... ]   # tile-top centre, in image pixels
}
Pixel origin is top-left (y down), matching Flutter/Flame.
"""

import json
import sys
from math import radians, sqrt

import bpy
import mathutils
from bpy_extras.object_utils import world_to_camera_view

# pointy-top hex (matches the game): flat-to-flat = 2.0, so circumradius:
R3D = 2.0 / sqrt(3)          # ~1.1547
X_STEP_Q = sqrt(3) * R3D     # 2.0   (east neighbour, +q)
X_STEP_R = sqrt(3) / 2 * R3D # 1.0   (+r horizontal shift)
Y_STEP_R = 1.5 * R3D         # ~1.732 (+r vertical)


def cell_pos(q, r):
    return (X_STEP_Q * q + X_STEP_R * r, Y_STEP_R * r)


def main():
    cfg = json.load(open(sys.argv[sys.argv.index("--") + 1:][0]))
    radius = cfg.get("radius", 5)
    res = cfg.get("res", 1600)

    scene = bpy.context.scene
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.film_transparent = True
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass

    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (1, 1, 1, 1)
        bg.inputs[1].default_value = 0.55

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (radians(50), radians(8), radians(40))

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cl = cfg.get("cam", [10, -10, 10])
    cam.location = mathutils.Vector((cl[0], cl[1], cl[2]))
    cam.rotation_euler = (
        (mathutils.Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    )

    # import the tile once, recenter to xy=0 / base z=0, then duplicate per cell
    bpy.ops.import_scene.gltf(filepath=cfg["tile"])
    template = [o for o in bpy.data.objects if o.type not in ("CAMERA", "LIGHT")]

    def bbox(objs):
        mn = [1e9] * 3
        mx = [-1e9] * 3
        for o in objs:
            if o.type != "MESH":
                continue
            for c in o.bound_box:
                w = o.matrix_world @ mathutils.Vector(c)
                for i in range(3):
                    mn[i] = min(mn[i], w[i])
                    mx[i] = max(mx[i], w[i])
        return mathutils.Vector(mn), mathutils.Vector(mx)

    mn, mx = bbox(template)
    for o in template:
        if o.parent is None:
            o.location.x -= (mn.x + mx.x) / 2
            o.location.y -= (mn.y + mx.y) / 2
            o.location.z -= mn.z
    bpy.context.view_layer.update()
    tile_h = (mx.z - mn.z)

    cells = []
    for q in range(-radius, radius + 1):
        for r in range(-radius, radius + 1):
            if abs(q) + abs(r) + abs(q + r) > 2 * radius:
                continue
            x, y = cell_pos(q, r)
            for o in template:
                o.select_set(True)
            bpy.context.view_layer.objects.active = template[0]
            bpy.ops.object.duplicate(linked=True)
            dup = list(bpy.context.selected_objects)
            for o in dup:
                if o.parent is None:
                    o.location.x += x
                    o.location.y += y
            for o in bpy.data.objects:
                o.select_set(False)
            cells.append((q, r, x, y))

    # remove the template (keep only duplicates) so it isn't doubled at origin-ish
    for o in template:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()

    # fit the orthographic camera to all tiles
    q3 = cam.matrix_world.to_quaternion()
    right = q3 @ mathutils.Vector((1, 0, 0))
    up = q3 @ mathutils.Vector((0, 1, 0))
    o_u = (mathutils.Vector((0, 0, 0)) - cam.location).dot(right)
    o_v = (mathutils.Vector((0, 0, 0)) - cam.location).dot(up)
    half_u = half_v = 0.0
    allmn, allmx = bbox([o for o in bpy.data.objects if o.type == "MESH"])
    for cx in (allmn.x, allmx.x):
        for cy in (allmn.y, allmx.y):
            for cz in (allmn.z, allmx.z):
                p = mathutils.Vector((cx, cy, cz))
                u = (p - cam.location).dot(right) - o_u
                v = (p - cam.location).dot(up) - o_v
                half_u = max(half_u, abs(u))
                half_v = max(half_v, abs(v))
    cam_data.ortho_scale = 2 * max(half_u, half_v) * 1.04

    scene.render.filepath = cfg["out_png"]
    bpy.ops.render.render(write_still=True)

    # export per-cell tile-top centre in image pixels
    out_cells = []
    for (q, r, x, y) in cells:
        top = mathutils.Vector((x, y, tile_h))
        co = world_to_camera_view(scene, cam, top)
        px = co.x * res
        py = (1.0 - co.y) * res  # flip to top-left origin
        out_cells.append({"q": q, "r": r, "x": round(px, 2), "y": round(py, 2)})

    json.dump(
        {
            "res": [res, res],
            "ortho_scale": cam_data.ortho_scale,
            "px_per_unit": res / cam_data.ortho_scale,
            "cells": out_cells,
        },
        open(cfg["out_json"], "w"),
        indent=0,
    )
    print("RENDERED_BOARD", cfg["out_png"], "cells", len(out_cells))


main()
