"""Render a rolling log (Kenney tree-log.glb) as iso sprites.

blender --background --python tool/render_log.py -- <manifest.json>

manifest.json:
{
  "glb": "/abs/tree-log.glb",
  "res": 128,
  "cam": [10, -10, 15],
  "ortho_scale": 4.9,
  "scale": 1.0,
  "frames": 8,                 # 滾動幀數（一整圈）
  "dirs": [0, 60, 120, ...],   # 每個方向：繞世界 Z 轉的角度（度）
  "out_dir": "/abs/out",       # 輸出 log_<dirIndex>_<frame>.png
  "prefix": "log"
}

流程：匯入 → 把最長軸轉成沿世界 X（滾動軸）→ 底面貼地 → xy 置中；
每個方向繞 Z 轉 dir 度；每幀繞「該方向下的滾動軸」轉 frame/frames*360 度。
"""

import json
import sys
from math import radians

import bpy
import mathutils


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    m = json.load(open(argv[0]))

    scene = bpy.context.scene
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.film_transparent = True
    res = m.get("res", 128)
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
    cam_data.ortho_scale = m.get("ortho_scale", 4.9)
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cl = m.get("cam", [10, -10, 15])
    cam.location = mathutils.Vector((cl[0], cl[1], cl[2]))
    look = mathutils.Vector((0, 0, 0)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()

    # ── 匯入原木 ──
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=m["glb"])
    objs = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in objs if o.type == "MESH"]

    # 全部併到一個父 Empty 好整體轉動
    pivot = bpy.data.objects.new("Pivot", None)
    scene.collection.objects.link(pivot)

    def bbox():
        mins = [1e9] * 3
        maxs = [-1e9] * 3
        for o in meshes:
            for c in o.bound_box:
                w = o.matrix_world @ mathutils.Vector(c)
                for i in range(3):
                    mins[i] = min(mins[i], w[i])
                    maxs[i] = max(maxs[i], w[i])
        return mathutils.Vector(mins), mathutils.Vector(maxs)

    mn, mx = bbox()
    dims = mx - mn
    print("LOG dims", tuple(round(v, 3) for v in dims))

    # 最長軸 = 原木長度軸 = 滾動軸（繞它轉才是「原地滾動」）
    longest = max(range(3), key=lambda i: dims[i])
    roll_axis = ["X", "Y", "Z"][longest]
    print("roll axis =", roll_axis)
    scale = m.get("scale", 1.0)
    if scale != 1.0:
        for o in meshes:
            if o.parent is None:
                o.scale *= scale
        bpy.context.view_layer.update()

    # 置中 xy、底面貼地(z=0)
    mn, mx = bbox()
    cx = (mn.x + mx.x) / 2
    cy = (mn.y + mx.y) / 2
    for o in meshes:
        if o.parent is None:
            o.location.x -= cx
            o.location.y -= cy
            o.location.z -= mn.z
    bpy.context.view_layer.update()
    mn, mx = bbox()
    print("LOG after normalize dims", tuple(round(v, 3) for v in (mx - mn)),
          "z0", round(mn.z, 3))

    # 把所有 mesh 掛到 pivot（保留世界變換）
    for o in meshes:
        if o.parent is None:
            o.parent = pivot

    # 滾動軸中心高度（繞這條線滾）
    axis_z = (mn.z + mx.z) / 2

    frames = m.get("frames", 8)
    dirs = m.get("dirs", [0])
    out_dir = m["out_dir"]
    prefix = m.get("prefix", "log")

    for di, deg in enumerate(dirs):
        for f in range(frames):
            # 先重置 pivot，再套用「方向(繞Z)」+「滾動(繞世界X，於軸心高度)」
            pivot.rotation_euler = (0, 0, 0)
            pivot.location = (0, 0, 0)
            bpy.context.view_layer.update()

            # 滾動：繞通過 (0,0,axis_z) 的「長度軸」旋轉（原地滾動）
            roll = radians(f / frames * 360.0)
            Rroll = mathutils.Matrix.Rotation(roll, 4, roll_axis)
            T1 = mathutils.Matrix.Translation((0, 0, -axis_z))
            T2 = mathutils.Matrix.Translation((0, 0, axis_z))
            Rz = mathutils.Matrix.Rotation(radians(deg), 4, "Z")
            pivot.matrix_world = Rz @ T2 @ Rroll @ T1
            bpy.context.view_layer.update()

            scene.render.filepath = f"{out_dir}/{prefix}_{di}_{f}.png"
            bpy.ops.render.render(write_still=True)
    print("DONE", len(dirs) * frames, "frames")


main()
