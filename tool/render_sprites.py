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
- "dz": optional z offset applied after placement (e.g. negative to sink a
  weapon down onto a platform floor below the crenellation top).
- "rz": optional rotation (degrees) around the model's own vertical axis,
  applied before placement (e.g. turn a weapon to face the camera).
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
            # 選擇性排除子網格（依名稱子字串）：例如只留 spikes、去掉 floor_tile。
            # 先把保留物件解除父子關係並保留世界座標，再刪除排除物件，避免位移。
            excl = [e.lower() for e in (m.get("exclude") or [])]
            if excl:
                to_remove = [o for o in objs
                             if any(e in o.name.lower() for e in excl)]
                keep = [o for o in objs if o not in to_remove]
                for o in keep:
                    mw = o.matrix_world.copy()
                    o.parent = None
                    o.matrix_world = mw
                for o in to_remove:
                    bpy.data.objects.remove(o, do_unlink=True)
                objs = keep
                bpy.context.view_layer.update()
            # 選擇性刪除「接近水平」的面（世界法線 |z|>threshold）：可去掉平板地面，
            # 只留下垂直的圓孔內壁（保留原素材的圓孔），尖刺為錐面不受影響。
            drop = m.get("dropFlatFaces")
            if drop:
                import bmesh
                for o in objs:
                    if o.type != "MESH":
                        continue
                    rot = o.matrix_world.to_3x3()
                    bm = bmesh.new()
                    bm.from_mesh(o.data)
                    to_del = [f for f in bm.faces
                              if abs((rot @ f.normal).normalized().z) > drop]
                    bmesh.ops.delete(bm, geom=to_del, context="FACES")
                    bm.to_mesh(o.data)
                    bm.free()
                bpy.context.view_layer.update()
            # 選擇性刪除「靠外緣」的面（面中心 xy 超過 bbox 半徑 threshold）：
            # 用來去掉方塊四周的外框，只留中央的圓孔內壁 + 尖刺。
            outer = m.get("dropOuterFaces")
            if outer:
                import bmesh
                mn0, mx0 = bbox_world(objs)
                ocx = (mn0.x + mx0.x) / 2
                ocy = (mn0.y + mx0.y) / 2
                ohx = max((mx0.x - mn0.x) / 2, 1e-6)
                ohy = max((mx0.y - mn0.y) / 2, 1e-6)
                for o in objs:
                    if o.type != "MESH":
                        continue
                    wm = o.matrix_world
                    bm = bmesh.new()
                    bm.from_mesh(o.data)
                    to_del = []
                    for f in bm.faces:
                        c = wm @ f.calc_center_median()
                        if max(abs(c.x - ocx) / ohx,
                               abs(c.y - ocy) / ohy) > outer:
                            to_del.append(f)
                    bmesh.ops.delete(bm, geom=to_del, context="FACES")
                    bm.to_mesh(o.data)
                    bm.free()
                bpy.context.view_layer.update()
            sc = m.get("scale", 1.0)
            if sc != 1.0:
                for o in objs:
                    if o.parent is None:
                        o.scale *= sc
                bpy.context.view_layer.update()
            rz = m.get("rz", 0.0)
            if rz:
                for o in objs:
                    if o.parent is None:
                        o.rotation_euler.rotate_axis("Z", radians(rz))
                bpy.context.view_layer.update()
            mn, mx = bbox_world(objs)
            cx = (mn.x + mx.x) / 2
            cy = (mn.y + mx.y) / 2
            dz = (stack_top - mn.z) if m.get("stack") else (-mn.z)
            dz += m.get("dz", 0.0)
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
