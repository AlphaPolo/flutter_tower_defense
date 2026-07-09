"""OBJ + 分離 PBR 貼圖 → GLB（給 render_sprites.py 用，它只吃 glTF）。

用法：
  blender --background --python tool/obj_to_glb.py -- <base.obj> <out.glb>

貼圖約定（AI 生成模型常見輸出，與 obj 同資料夾）：
  texture_diffuse.png / texture_normal.png / texture_roughness.png /
  texture_metallic.png——有哪張接哪張。
"""
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
obj_path, out_path = argv[0], argv[1]
tex_dir = os.path.dirname(obj_path)

# 清空場景
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

# 匯入 OBJ（Blender 4.x 新版 operator）
bpy.ops.wm.obj_import(filepath=obj_path)
objs = [o for o in bpy.data.objects if o.type == "MESH"]
assert objs, "OBJ 匯入後沒有 mesh"

# 建 PBR 材質並接貼圖
mat = bpy.data.materials.new("dummy_pbr")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]


def tex_node(fname, non_color=False):
    p = os.path.join(tex_dir, fname)
    if not os.path.exists(p):
        return None
    img = bpy.data.images.load(p)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    return node


d = tex_node("texture_diffuse.png")
if d:
    mat.node_tree.links.new(bsdf.inputs["Base Color"], d.outputs["Color"])
r = tex_node("texture_roughness.png", non_color=True)
if r:
    mat.node_tree.links.new(bsdf.inputs["Roughness"], r.outputs["Color"])
m = tex_node("texture_metallic.png", non_color=True)
if m:
    mat.node_tree.links.new(bsdf.inputs["Metallic"], m.outputs["Color"])
n = tex_node("texture_normal.png", non_color=True)
if n:
    nm = mat.node_tree.nodes.new("ShaderNodeNormalMap")
    mat.node_tree.links.new(nm.inputs["Color"], n.outputs["Color"])
    mat.node_tree.links.new(bsdf.inputs["Normal"], nm.outputs["Normal"])

for o in objs:
    o.data.materials.clear()
    o.data.materials.append(mat)

# 匯出 GLB（貼圖內嵌）
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB")
print("exported:", out_path)
