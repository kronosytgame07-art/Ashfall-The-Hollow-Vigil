import bpy
import math
import os
import random
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
random.seed(1707)

COLORS = {
    "stone": (0.20, 0.18, 0.19, 1), "stone_light": (0.34, 0.31, 0.30, 1),
    "wood": (0.24, 0.105, 0.045, 1), "wood_dark": (0.075, 0.035, 0.022, 1),
    "iron": (0.115, 0.12, 0.14, 1), "cloth": (0.25, 0.025, 0.035, 1),
    "gold": (0.72, 0.32, 0.035, 1), "ember": (1.0, 0.08, 0.005, 1),
    "soul": (0.34, 0.035, 0.78, 1), "bone": (0.55, 0.49, 0.38, 1),
    "skin": (0.42, 0.22, 0.12, 1), "leather": (0.17, 0.075, 0.035, 1),
}
MATS = {}


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)


def mat(name, emission=0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.diffuse_color = COLORS[name]
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = COLORS[name]
    bsdf.inputs["Roughness"].default_value = 0.82 if name not in ("iron", "gold") else 0.38
    bsdf.inputs["Metallic"].default_value = 0.72 if name == "iron" else 0.38 if name == "gold" else 0
    if emission:
        bsdf.inputs["Emission Color"].default_value = COLORS[name]
        bsdf.inputs["Emission Strength"].default_value = emission
    MATS[name] = m
    return m


def finish(obj, material, bevel=0.08):
    obj.data.materials.append(mat(material, 5 if material in ("ember", "soul") else 0))
    if bevel:
        mod = obj.modifiers.new("Hand-worked bevels", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth_by_angle()
    obj.select_set(False)
    return obj


def cube(name, loc, scale, material, bevel=0.08, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = Vector(scale) * 0.5
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, bevel)


def cyl(name, loc, radius, depth, material, vertices=16, rot=(0, 0, 0), bevel=0.05):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, material, bevel)


def sphere(name, loc, scale, material, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, 0.035)


def organic_rock(name, loc, scale, material="stone", seed=0):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    for v in o.data.vertices:
        n = v.co.normalized()
        v.co *= 0.76 + rng.random() * 0.42 + abs(n.z) * 0.08
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, 0.025)


def curve_beam(name, points, radius, material):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, point in zip(spline.bezier_points, points):
        bp.co = point
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat(material))
    return obj


def roof(name, loc, width, depth, height, material="cloth"):
    verts = [
        (-width/2, -depth/2, 0), (width/2, -depth/2, 0),
        (-width/2, depth/2, 0), (width/2, depth/2, 0),
        (0, -depth/2, height), (0, depth/2, height),
    ]
    faces = [(0, 1, 4), (2, 5, 3), (0, 4, 5, 2), (1, 3, 5, 4)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    return finish(obj, material, 0.055)


def stone_foundation(size):
    for i in range(20):
        a = i * math.tau / 20
        r = size * 0.43
        organic_rock(f"FoundationStone_{i}", (math.cos(a)*r, 0.2, math.sin(a)*r),
                     (0.48, 0.25 + (i % 3)*0.05, 0.38), "stone_light", 100+i)


def build_mine():
    reset()
    stone_foundation(4.0)
    for i in range(26):
        a = i * 2.399
        r = 0.45 + (i % 5) * 0.23
        organic_rock(f"MineRock_{i}", (math.cos(a)*r, 0.45 + (i % 4)*0.17, math.sin(a)*r),
                     (0.48, 0.35, 0.45), "stone", i)
    cube("TunnelVoid", (0, 0.85, 1.35), (1.25, 1.5, 0.3), "wood_dark", 0.16)
    curve_beam("LeftBentPost", [(-0.62, 0.2, 1.55), (-0.67, 1.1, 1.5), (-0.55, 1.8, 1.48)], 0.11, "wood")
    curve_beam("RightBentPost", [(0.62, 0.2, 1.55), (0.68, 1.05, 1.5), (0.56, 1.8, 1.48)], 0.11, "wood")
    curve_beam("Lintel", [(-0.68, 1.76, 1.5), (0, 1.9, 1.46), (0.68, 1.76, 1.5)], 0.12, "wood")
    for x in (-0.38, 0.38):
        curve_beam("Rail", [(x, 0.08, 1.2), (x, 0.1, 2.8)], 0.035, "iron")
    cyl("Winch", (1.15, 1.55, 0.2), 0.36, 0.82, "wood", rot=(0, math.pi/2, 0))
    curve_beam("Crane", [(0.9, 0.2, 0), (1.18, 2.6, 0), (0.1, 2.75, 0.2)], 0.09, "iron")
    curve_beam("Rope", [(0.1, 2.75, 0.2), (0.15, 1.05, 0.35)], 0.018, "iron")
    for i in range(9):
        sphere(f"Gold_{i}", (-0.65 + (i % 3)*0.22, 0.34 + (i//3)*0.14, -0.8), (0.14, 0.11, 0.12), "gold")
    return "models/buildings/gold_mine.glb"


def build_barracks():
    reset()
    stone_foundation(4.0)
    cube("BarracksBody", (0, 1.25, 0), (3.05, 2.05, 2.7), "stone", 0.22)
    roof("SaggingRoof", (0, 2.28, 0), 3.65, 3.2, 1.45, "cloth")
    for x in (-1.42, 0, 1.42):
        curve_beam("Timber", [(x, 0.35, 1.38), (x + math.sin(x)*0.08, 2.25, 1.4)], 0.09, "wood")
    cube("HeavyDoor", (0, 1.0, 1.43), (0.9, 1.45, 0.16), "wood_dark", 0.1)
    for y in (0.55, 1.0, 1.45):
        cube("DoorIron", (0, y, 1.53), (0.82, 0.055, 0.05), "iron", 0.02)
    for x in (-1.25, 1.25):
        curve_beam("TrainingPost", [(x, 0.2, -1.55), (x, 1.55, -1.55)], 0.08, "wood")
        cube("TrainingArms", (x, 1.25, -1.55), (0.8, 0.08, 0.08), "iron", 0.03)
        sphere("TrainingHead", (x, 1.72, -1.55), (0.18, 0.22, 0.18), "bone")
    curve_beam("BannerPole", [(-1.65, 0.2, 1.25), (-1.65, 3.6, 1.25)], 0.045, "iron")
    cube("Banner", (-1.36, 2.9, 1.25), (0.5, 1.0, 0.04), "cloth", 0.025)
    return "models/buildings/barracks.glb"


def build_yard():
    reset()
    for i in range(14):
        organic_rock(f"YardStone_{i}", (-1.5 + (i % 5)*0.72, 0.15, -1.5 + (i//5)*1.25),
                     (0.36, 0.18, 0.3), "stone", 300+i)
    for x in (-1.45, 1.45):
        for z in (-1.35, 1.35):
            curve_beam("ScaffoldPost", [(x, 0.1, z), (x + random.uniform(-.08,.08), 2.7, z)], 0.095, "wood")
    for z in (-1.35, 0, 1.35):
        curve_beam("ScaffoldRail", [(-1.5, 1.55, z), (1.5, 1.62, z)], 0.075, "wood")
    roof("WorkshopCanopy", (0, 2.55, 0), 3.4, 3.0, 0.75, "cloth")
    curve_beam("CraneMast", [(1.25, 0.15, -1.2), (1.25, 3.65, -1.2)], 0.11, "wood")
    curve_beam("CraneArm", [(1.25, 3.65, -1.2), (-1.0, 3.55, -1.2)], 0.09, "wood")
    curve_beam("CraneRope", [(-0.9, 3.55, -1.2), (-0.9, 1.35, -1.2)], 0.018, "iron")
    organic_rock("CraneLoad", (-0.9, 1.05, -1.2), (0.42, 0.32, 0.38), "stone_light", 77)
    for i in range(7):
        curve_beam("LooseTimber", [(-1.45, .25+i*.08, .75+i*.08), (-.15, .27+i*.08, .72+i*.08)], .055, "wood")
    return "models/buildings/builders_yard.glb"


def build_obstacle(kind):
    reset()
    if kind == "dead_tree":
        curve_beam("TwistedTrunk", [(0,0,0), (.12,.8,.05), (-.1,1.7,.12), (.18,2.8,0)], .16, "wood_dark")
        for i in range(8):
            a = i * 2.1
            start = (math.sin(a)*.1, 1.0+i*.18, math.cos(a)*.08)
            end = (math.sin(a)*(.8+i*.05), 1.7+i*.2, math.cos(a)*(.7+i*.04))
            curve_beam(f"Branch_{i}", [start, end, (end[0]+math.sin(a+.8)*.35,end[1]+.25,end[2]+math.cos(a+.8)*.3)], .055, "wood")
    elif kind == "corrupted_rocks":
        for i in range(13):
            a=i*2.399
            organic_rock(f"Rock_{i}",(math.cos(a)*(.2+i*.045),.2+i*.04,math.sin(a)*(.2+i*.045)),(.28,.35+i*.025,.25),"stone",400+i)
        for i in range(7):
            a=i*math.tau/7
            cyl(f"Crystal_{i}",(math.cos(a)*.48,.55,math.sin(a)*.48),.09,.8+(i%3)*.22,"soul",vertices=6,rot=(0.12,0,a))
    elif kind == "bones":
        sphere("Skull",(0,.28,0),(.34,.3,.3),"bone")
        for x in (-.13,.13):
            sphere("Eye",(x,.33,-.27),(.08,.09,.05),"iron")
        for i in range(10):
            a=i*.7
            curve_beam(f"Bone_{i}",[(math.cos(a)*.25,.12,math.sin(a)*.25),(math.cos(a)*.8,.1,math.sin(a)*.7)],.045,"bone")
    return f"models/obstacles/{kind}.glb"


def build_dark_fantasy_building(kind):
    reset()
    stone_foundation(3.7 if kind != "wall" else 2.3)
    if kind == "sawmill":
        cube("MillHouse", (0, 1.05, 0), (2.8, 1.8, 2.2), "wood", .18)
        roof("SplitShingleRoof", (0, 1.95, 0), 3.4, 2.7, 1.0, "cloth")
        for i in range(13):
            curve_beam(f"Log_{i}", [(-1.55, .18 + i*.09, -.75), (-.35, .2 + i*.09, -.72)], .075, "wood_dark")
        cyl("SawWheel", (1.45, 1.0, -.15), .78, .16, "iron", 24, rot=(math.pi/2, 0, 0))
        for i in range(12):
            a = i*math.tau/12
            cube(f"SawTooth_{i}", (1.45+math.cos(a)*.84, 1+math.sin(a)*.84, -.15),
                 (.12,.25,.12), "iron", .02, rot=(0,0,a))
    elif kind == "army_camp":
        roof("WarTent", (0, .18, 0), 3.3, 2.8, 2.35, "cloth")
        for x in (-1.55, 1.55):
            curve_beam("TentPole", [(x,.1,-1.3),(x,2.55,-1.3)], .07, "wood")
        for i in range(9):
            a=i*math.tau/9
            cyl(f"Shield_{i}",(math.cos(a)*1.45,.55,math.sin(a)*1.45),.34,.1,"iron",20,rot=(math.pi/2,0,a))
        curve_beam("Banner", [(0,.2,1.3),(0,3.45,1.3)], .055, "iron")
        cube("WarBanner",(0.35,2.75,1.3),(.62,1.1,.05),"cloth",.03)
    elif kind == "soul_altar":
        for i in range(4):
            organic_rock(f"AltarTier_{i}",(0,.18+i*.27,0),(1.55-i*.25,.22,1.4-i*.2),"stone_light",600+i)
        for i in range(8):
            a=i*math.tau/8
            curve_beam(f"Rib_{i}",[(math.cos(a)*1.15,.4,math.sin(a)*1.15),
                                  (math.cos(a)*.75,1.55,math.sin(a)*.75)],.055,"bone")
        sphere("SoulCore",(0,1.45,0),(.42,.62,.42),"soul",3)
    elif kind == "forge":
        cube("ForgeBody",(0,.75,0),(2.9,1.35,2.45),"stone",.2)
        roof("ForgeRoof",(0,1.42,0),3.35,2.8,.85,"cloth")
        cube("FireMouth",(0,.7,1.25),(1.1,.75,.18),"wood_dark",.22)
        sphere("ForgeFire",(0,.65,1.4),(.38,.26,.12),"ember",2)
        curve_beam("Chimney",[(-.85,1.25,-.4),(-.82,3.35,-.35)],.28,"stone")
        cube("Anvil",(1.45,.55,-.5),(.9,.3,.42),"iron",.11)
        cyl("AnvilFoot",(1.45,.25,-.5),.22,.55,"iron",16)
    elif kind == "tower":
        for i in range(5):
            cyl(f"TowerCourse_{i}",(0,.35+i*.55,0),1.18-i*.025,.52,"stone_light",20,bevel=.08)
        for i in range(8):
            a=i*math.tau/8
            cube(f"Battlement_{i}",(math.cos(a)*1.0,3.05,math.sin(a)*1.0),
                 (.45,.65,.45),"stone",.1,rot=(0,a,0))
        curve_beam("WatchBanner",[(0,2.7,0),(0,4.4,0)],.045,"iron")
        cube("WatchCloth",(.35,3.85,0),(.62,.85,.04),"cloth",.02)
    elif kind == "laboratory":
        cube("Laboratory",(0,1.0,0),(2.8,1.8,2.5),"stone",.24)
        roof("LaboratoryRoof",(0,1.9,0),3.3,2.9,1.05,"cloth")
        for i in range(5):
            a=i*math.tau/5
            sphere(f"Vial_{i}",(math.cos(a)*1.45,.72,math.sin(a)*1.3),(.18,.35,.18),"soul",2)
            curve_beam(f"Pipe_{i}",[(math.cos(a)*.65,1.0,math.sin(a)*.65),
                                   (math.cos(a)*1.45,1.5,math.sin(a)*1.3)],.035,"iron")
        cyl("CopperStill",(-.65,2.65,-.25),.38,1.2,"gold",20)
    elif kind == "spell_hall":
        for i in range(16):
            a=i*math.tau/16
            organic_rock(f"RuneStone_{i}",(math.cos(a)*1.55,.25,math.sin(a)*1.55),
                         (.32,.38,.25),"stone",700+i)
        for i in range(5):
            a=i*math.tau/5
            curve_beam(f"Arch_{i}",[(math.cos(a)*1.1,.25,math.sin(a)*1.1),
                                   (math.cos(a)*.65,2.8,math.sin(a)*.65)],.12,"bone")
        sphere("SpellHeart",(0,1.55,0),(.5,.72,.5),"soul",3)
        for i in range(3):
            cyl(f"RuneRing_{i}",(0,1.55,0),.78+i*.16,.035,"gold",32,rot=(math.pi/2+i*.45,0,i*.8))
    elif kind == "wall":
        for i in range(9):
            organic_rock(f"WallStone_{i}",(-1.6+i*.4,.35+(i%2)*.32,0),
                         (.38,.38,.42),"stone_light",800+i)
        for x in (-1.7,1.7):
            cube("IronPost",(x,1.0,0),(.18,2.0,.35),"iron",.06)
            cyl("Spike",(x,2.1,0),.16,.65,"iron",8)
    return f"models/buildings/{kind}.glb"


def parent_object(obj, parent):
    obj.parent = parent
    return obj


def build_unit(kind):
    reset()
    root = bpy.data.objects.new("CharacterVisual", None)
    bpy.context.collection.objects.link(root)
    torso = bpy.data.objects.new("Torso", None)
    bpy.context.collection.objects.link(torso)
    torso.location = (0, 1.55, 0)
    torso.parent = root
    armor_name = "leather" if kind in ("archer", "worker") else "iron"
    parent_object(sphere("TorsoMesh",(0,1.55,0),(.46,.58,.32),armor_name,3),root)
    parent_object(cyl("Belt",(0,1.25,0),.42,.18,"wood_dark",20),root)
    parent_object(sphere("Head",(0,.71,-.02),(.3,.34,.29),"skin",3),torso)
    parent_object(cyl("Hood",(0,.83,0),.36,.34,"cloth",20),torso)
    for i in range(3):
        parent_object(curve_beam(f"ArmorStrap_{i}",[(-.43,1.32+i*.22,-.22),(.43,1.32+i*.22,-.22)],.035,"iron"),root)
    pivots = {}
    for name, x, y, arm in (
        ("LeftLeg",-.22,1.12,False),("RightLeg",.22,1.12,False),
        ("LeftArm",-.53,1.92,True),("RightArm",.53,1.92,True)):
        pivot=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(pivot)
        pivot.location=(x,y,0); pivot.parent=root; pivots[name]=pivot
        limb=cyl(name+"Mesh",(x,y-.37,0),.12 if arm else .15,.72,armor_name,16)
        limb.parent=pivot; limb.location=(0,-.37,0)
        if not arm:
            boot=cube(name+"Boot",(0,-.79,-.08),(.3,.22,.48),"wood_dark",.08)
            boot.parent=pivot
    weapon=bpy.data.objects.new("Weapon",None); bpy.context.collection.objects.link(weapon)
    weapon.location=(0,-.68,0); weapon.parent=pivots["RightArm"]
    parent_object(curve_beam("WeaponHandle",[(0,0,0),(0,-.82,0)],.045,"wood"),weapon)
    if kind == "archer":
        parent_object(curve_beam("Bow",[(-.18,-.15,0),(0,-.55,-.12),(.18,-.95,0)],.055,"wood"),weapon)
    elif kind == "worker":
        parent_object(cube("HammerHead",(0,-.82,0),(.48,.18,.2),"iron",.06),weapon)
        parent_object(cube("Apron",(0,1.5,-.34),(.65,.82,.08),"leather",.08),root)
    else:
        parent_object(cube("Blade",(0,-1.08,0),(.18,.72,.08),"iron",.035),weapon)
        shield=cyl("Shield",(-.53,1.35,-.26),.38,.12,"iron",24,rot=(math.pi/2,0,0))
        shield.parent=pivots["LeftArm"]; shield.location=(0,-.58,-.26)
    if kind == "brute":
        root.scale=(1.2,1.2,1.2)
        for x in (-.25,.25):
            horn=cyl("Horn",(x,1.17,0),.065,.5,"bone",12,rot=(0,0,x*1.5))
            horn.parent=torso
    return f"models/units/{kind}.glb"


def export(relpath):
    path = os.path.join(ROOT, relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for obj in bpy.context.scene.objects:
        if obj.parent is None:
            obj.rotation_euler.x += math.pi / 2
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT",
    )


for builder in (build_mine, build_barracks, build_yard):
    export(builder())
for building in ("sawmill", "army_camp", "soul_altar", "forge", "tower", "laboratory", "spell_hall", "wall"):
    export(build_dark_fantasy_building(building))
for obstacle in ("dead_tree", "corrupted_rocks", "bones"):
    export(build_obstacle(obstacle))
for unit in ("warrior", "archer", "brute", "hero", "worker"):
    export(build_unit(unit))
print("Exported Blender-authored dark-fantasy asset batch")
