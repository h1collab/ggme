import os, sys, trimesh
import numpy as np
from trimesh.visual.material import PBRMaterial

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets"
os.makedirs(OUT, exist_ok=True)

def mat(name, rgb, rough=0.8, metal=0.0, alpha=1.0):
    return PBRMaterial(
        name=name,
        baseColorFactor=[int(c*255) for c in rgb] + [int(alpha*255)],
        roughnessFactor=rough,
        metallicFactor=metal,
    )

WALL=mat("wall",(0.82,0.84,0.82),0.92)
TRIM=mat("trim",(0.15,0.19,0.23),0.65,0.15)
FLOOR=mat("floor",(0.48,0.46,0.42),0.88)
GLASS=mat("glass",(0.42,0.62,0.78),0.15,0.05,0.55)
WHITE=mat("ceiling",(0.94,0.96,0.98),0.72)
BLUE=mat("school_blue",(0.08,0.20,0.33),0.72)

def T(pos):
    m=np.eye(4); m[:3,3]=pos; return m

def add(sc,name,ext,material,pos):
    mesh=trimesh.creation.box(extents=ext)
    mesh.visual=trimesh.visual.TextureVisuals(material=material)
    sc.add_geometry(mesh,node_name=name,geom_name=name,transform=T(pos))

sc=trimesh.Scene()
add(sc,"Floor",(34.0,0.18,26.0),FLOOR,(0,-0.09,0))
for x in range(-16,17,4):
    for z in range(-12,13,4):
        add(sc,f"Ceiling_{x}_{z}",(3.85,0.07,3.85),WHITE,(x,3.26,z))
for x in range(-15,16,3):
    add(sc,f"NorthPanel{x}",(2.85,3.05,0.18),WALL,(x,1.52,-12.9))
    add(sc,f"SouthPanel{x}",(2.85,3.05,0.18),WALL,(x,1.52,12.9))
for z in range(-11,12,3):
    add(sc,f"WestPanel{z}",(0.18,3.05,2.85),WALL,(-16.9,1.52,z))
    add(sc,f"EastPanel{z}",(0.18,3.05,2.85),WALL,(16.9,1.52,z))
for z in (-12.78,12.78):
    add(sc,f"SkirtingZ{z}",(33.4,0.16,0.12),TRIM,(0,0.08,z))
    add(sc,f"CorniceZ{z}",(33.4,0.12,0.12),TRIM,(0,3.03,z))
for x in (-16.78,16.78):
    add(sc,f"SkirtingX{x}",(0.12,0.16,25.4),TRIM,(x,0.08,0))
    add(sc,f"CorniceX{x}",(0.12,0.12,25.4),TRIM,(x,3.03,0))
for x in (-11.0,0.0,11.0):
    for z in (-7.8,0.0,7.8):
        add(sc,f"Column_{x}_{z}",(0.24,3.1,0.24),TRIM,(x,1.55,z))
for x in (-12,-8,-4,0,4,8,12):
    add(sc,f"NorthWindowFrame{x}",(2.35,1.35,0.12),TRIM,(x,2.05,-12.72))
    add(sc,f"NorthWindowGlass{x}",(2.12,1.13,0.035),GLASS,(x,2.05,-12.79))
    add(sc,f"SouthWindowFrame{x}",(2.35,1.35,0.12),TRIM,(x,2.05,12.72))
    add(sc,f"SouthWindowGlass{x}",(2.12,1.13,0.035),GLASS,(x,2.05,12.79))
for z in (-12.55,12.55):
    add(sc,f"BlueStripe{z}",(33.0,0.28,0.04),BLUE,(0,0.95,z))
sc.export(os.path.join(OUT,"classroom_shell_sketchfab_rebuild.glb"))
print("generated classroom_shell_sketchfab_rebuild.glb")
