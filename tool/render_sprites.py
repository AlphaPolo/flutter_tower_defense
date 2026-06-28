"""Render KayKit 3D models to isometric 2D sprites (transparent PNG).

Run headless with Blender:

    blender --background --python tool/render_sprites.py -- <manifest.json>

manifest.json:
{
  "res": 512,
  "jobs": [
    {
      "out": "/abs/out.png",
      "ortho_scale": 3.0,
      "models": [
        {"path": "/abs/hex_grass.gltf"},
        {"path": "/abs/building_tower_A_red.gltf", "stack": true}
      ]
    }
  ]
}

- Camera is a fixed true-isometric orthographic camera, so every sprite shares
  the same projection and world-unit scale (relative sizes are correct).
- "stack": true places a model on top of the previously imported model's top
  (e.g. a tower standing on a tile); otherwise it sits on the ground (z=0).
- Background is transparent.
"""

import json
import sys
from math import radians

import bpy
import mathutils


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    manifest = json.load(open(argv[0]))

    scene = bpy.context.scene

    # wipe the default cube / camera / light
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    # ── render settings ──────────────────────────────────────
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.film_transparent = True
    res = manifest.get("res", 512)
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # predictable colours (avoid Filmic washing the flat textures out)
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass

    # ── world ambient fill ───────────────────────────────────
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (1, 1, 1, 1)
        bg.inputs[1].default_value = 0.55

    # ── sun ──────────────────────────────────────────────────
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (radians(50), radians(8), radians(40))

    # ── true-isometric orthographic camera ───────────────────
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cl = manifest.get("cam", [10, -10, 10])
    cam.location = mathutils.Vector((cl[0], cl[1], cl[2]))
    look = mathutils.Vector((0, 0, 0)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    def clear_meshes():
        for o in list(bpy.data.objects):
            if o.type not in ("CAMERA", "LIGHT"):
                bpy.data.objects.remove(o, do_unlink=True)

    def import_gltf(path):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        return [o for o in bpy.data.objects if o not in before]

    def bbox_world(objs):
        mins = [1e9] * 3
        maxs = [-1e9] * 3
        for o in objs:
            if o.type != "MESH":
                continue
            for corner in o.bound_box:
                wv = o.matrix_world @ mathutils.Vector(corner)
                for i in range(3):
                    mins[i] = min(mins[i], wv[i])
                    maxs[i] = max(maxs[i], wv[i])
        return mathutils.Vector(mins), mathutils.Vector(maxs)

    for job in manifest["jobs"]:
        clear_meshes()
        cam_data.ortho_scale = job.get("ortho_scale", 3.0)
        stack_top = 0.0
        for m in job["models"]:
            objs = import_gltf(m["path"])
            sc = m.get("scale", 1.0)
            if sc != 1.0:
                for o in objs:
                    if o.parent is None:
                        o.scale *= sc
                bpy.context.view_layer.update()
            mn, mx = bbox_world(objs)
            cx = (mn.x + mx.x) / 2
            cy = (mn.y + mx.y) / 2
            dz = (stack_top - mn.z) if m.get("stack") else (-mn.z)
            ox, oy = (m.get("offset") or [0, 0])
            for o in objs:
                if o.parent is None:
                    o.location.x -= cx - ox
                    o.location.y -= cy - oy
                    o.location.z += dz
            bpy.context.view_layer.update()
            mn2, mx2 = bbox_world(objs)
            stack_top = mx2.z if m.get("stack") else max(stack_top, mx2.z)
            print("MODEL", m["path"], "dims", tuple(round(v, 3) for v in (mx - mn)))
        scene.render.filepath = job["out"]
        bpy.ops.render.render(write_still=True)
        print("RENDERED", job["out"])


main()
