import os, math, sys
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
AS = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, 'assets')
os.makedirs(AS, exist_ok=True)

def mat(name, rgb, rough=0.7, metal=0.0, emissive=None):
    rgba = [int(max(0, min(1, c)) * 255) for c in rgb] + [255]
    kwargs = dict(name=name, baseColorFactor=rgba, roughnessFactor=rough, metallicFactor=metal)
    if emissive is not None:
        kwargs['emissiveFactor'] = list(emissive)
    return PBRMaterial(**kwargs)

M = {
    'teacher_cloth': mat('teacher_cloth', (0.14, 0.18, 0.28), 0.84),
    'teacher_shirt': mat('teacher_shirt', (0.90, 0.91, 0.93), 0.66),
    'teacher_tie': mat('teacher_tie', (0.58, 0.08, 0.10), 0.54),
    'teacher_skin': mat('teacher_skin', (0.74, 0.58, 0.45), 0.82),
    'teacher_hair': mat('teacher_hair', (0.18, 0.11, 0.07), 0.65),
    'teacher_shoe': mat('teacher_shoe', (0.06, 0.06, 0.07), 0.42),
    'desk_wood': mat('desk_wood', (0.49, 0.33, 0.18), 0.73),
    'desk_frame': mat('desk_frame', (0.18, 0.22, 0.27), 0.44, 0.65),
    'desk_trim': mat('desk_trim', (0.63, 0.49, 0.30), 0.64),
    'chair_seat': mat('chair_seat', (0.10, 0.22, 0.34), 0.74),
    'paper': mat('paper', (0.96, 0.95, 0.90), 0.96),
    'metal': mat('metal', (0.76, 0.79, 0.84), 0.34, 0.72),
}

def add(scene, name, mesh, material, transform=None):
    mesh = mesh.copy()
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    scene.add_geometry(mesh, node_name=name, geom_name=name, transform=transform if transform is not None else np.eye(4))

def T(pos=(0,0,0), rot=(0,0,0), scale=(1,1,1)):
    m = trimesh.transformations.euler_matrix(*rot, axes='sxyz')
    m[:3,3] = pos
    m[:3,:3] = m[:3,:3] @ np.diag(scale)
    return m

def box(ext): return trimesh.creation.box(extents=ext)
def cyl(radius, height, sections=24): return trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
def sphere(r, sub=3): return trimesh.creation.icosphere(subdivisions=sub, radius=r)
def capsule(r, h, sections=24): return trimesh.creation.capsule(radius=r, height=max(0.01, h - 2*r), count=[sections, sections])

sc = trimesh.Scene()
add(sc,'Torso',capsule(.22,.92,28),M['teacher_shirt'],T((0,1.38,0),rot=(math.pi/2,0,0),scale=(1.3,1,.8)))
add(sc,'Jacket',box((.86,.84,.34)),M['teacher_cloth'],T((0,1.34,.01)))
add(sc,'Hem',box((.78,.16,.28)),M['teacher_cloth'],T((0,.96,.01)))
add(sc,'CollarL',box((.12,.14,.03)),M['teacher_shirt'],T((-.08,1.71,-.16),rot=(.15,0,.55)))
add(sc,'CollarR',box((.12,.14,.03)),M['teacher_shirt'],T((.08,1.71,-.16),rot=(.15,0,-.55)))
add(sc,'Tie',box((.10,.36,.03)),M['teacher_tie'],T((0,1.51,-.165),rot=(.08,0,0)))
add(sc,'Neck',cyl(.08,.12,20),M['teacher_skin'],T((0,1.78,0),rot=(math.pi/2,0,0)))
add(sc,'Head',sphere(.22,4),M['teacher_skin'],T((0,2.04,0),scale=(.92,1.05,.92)))
add(sc,'HairCap',sphere(.225,3),M['teacher_hair'],T((0,2.12,.01),scale=(.94,.76,.95)))
add(sc,'HairBack',box((.26,.12,.18)),M['teacher_hair'],T((0,2.02,.11)))
add(sc,'Nose',box((.06,.09,.05)),M['teacher_skin'],T((0,2.03,-.20),rot=(.20,0,0)))
add(sc,'Mouth',box((.11,.015,.02)),M['teacher_hair'],T((0,1.95,-.205)))
for sx in (-.075,.075):
    add(sc,f'Eye_{sx}',sphere(.018,2),M['metal'],T((sx,2.05,-.20),scale=(1,.7,.4)))
for side,sx,sign in [('L',-.52,1),('R',.52,-1)]:
    add(sc,f'UpperArm_{side}',capsule(.07,.60,20),M['teacher_cloth'],T((sx,1.45,0),rot=(math.pi/2,0,.14*sign)))
    add(sc,f'ForeArm_{side}',capsule(.06,.52,20),M['teacher_shirt'],T((sx*1.02,1.00,0),rot=(math.pi/2,0,.03*sign)))
    add(sc,f'Hand_{side}',sphere(.075,2),M['teacher_skin'],T((sx*1.02,.71,-.01),scale=(.9,1.1,.7)))
for side,sx in [('L',-.17),('R',.17)]:
    add(sc,f'Thigh_{side}',capsule(.09,.68,20),M['teacher_cloth'],T((sx,.72,0),rot=(math.pi/2,0,0)))
    add(sc,f'Calf_{side}',capsule(.08,.66,20),M['teacher_cloth'],T((sx,.30,.02),rot=(math.pi/2,0,0)))
    add(sc,f'Shoe_{side}',box((.18,.10,.34)),M['teacher_shoe'],T((sx,.05,-.06)))
add(sc,'Book',box((.20,.28,.05)),M['paper'],T((.30,1.23,-.19),rot=(0,0,.15)))
add(sc,'Pointer',cyl(.014,.78,16),M['desk_trim'],T((-.42,1.13,.02),rot=(.1,0,-1.1)))
sc.export(os.path.join(AS,'school_teacher.glb'))

sc = trimesh.Scene()
add(sc,'DeskTop',box((1.25,.07,.70)),M['desk_wood'],T((0,.72,0)))
add(sc,'TopTrimFront',box((1.28,.06,.05)),M['desk_trim'],T((0,.69,-.33)))
add(sc,'StorageBody',box((1.10,.48,.58)),M['desk_wood'],T((0,.44,.02)))
add(sc,'StorageFront',box((1.06,.42,.04)),M['desk_trim'],T((0,.45,-.27)))
add(sc,'Shelf',box((1.00,.03,.48)),M['desk_trim'],T((0,.47,.02)))
for sx in (-.56,.56):
    for sz in (-.28,.28):
        add(sc,f'Leg_{sx}_{sz}',cyl(.028,.72,18),M['desk_frame'],T((sx,.36,sz),rot=(math.pi/2,0,0)))
for sx in (-.56,.56):
    add(sc,f'SideBarTop_{sx}',box((.04,.04,.60)),M['desk_frame'],T((sx,.64,0)))
    add(sc,f'SideBarBottom_{sx}',box((.04,.04,.60)),M['desk_frame'],T((sx,.14,0)))
add(sc,'FrontBar',box((1.12,.04,.04)),M['desk_frame'],T((0,.14,-.22)))
add(sc,'BackBar',box((1.12,.04,.04)),M['desk_frame'],T((0,.14,.22)))
add(sc,'Seat',box((.48,.05,.42)),M['chair_seat'],T((0,.44,.72)))
add(sc,'BackRest',box((.50,.30,.05)),M['chair_seat'],T((0,.67,.90)))
for sx in (-.20,.20):
    add(sc,f'ChairLegFront_{sx}',cyl(.022,.44,18),M['desk_frame'],T((sx,.22,.57),rot=(math.pi/2,0,0)))
    add(sc,f'ChairLegBack_{sx}',cyl(.022,.84,18),M['desk_frame'],T((sx,.42,.87),rot=(math.pi/2,0,0)))
add(sc,'Notebook',box((.26,.02,.20)),M['paper'],T((.24,.765,-.10),rot=(0,.28,0)))
add(sc,'Pencil',cyl(.008,.22,12),M['desk_trim'],T((-.15,.78,.10),rot=(0,1.15,0)))
sc.export(os.path.join(AS,'school_desk.glb'))

print('created', os.path.join(AS,'school_teacher.glb'), os.path.join(AS,'school_desk.glb'))
