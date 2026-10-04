import os, math, sys, wave, struct
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets"
AUDIO = sys.argv[2] if len(sys.argv) > 2 else "audio"
os.makedirs(OUT, exist_ok=True)
os.makedirs(AUDIO, exist_ok=True)

def mat(name, rgb, rough=0.75, metal=0.0, emissive=None, alpha=1.0):
    kwargs=dict(
        name=name,
        baseColorFactor=[int(max(0,min(1,c))*255) for c in rgb]+[int(alpha*255)],
        roughnessFactor=rough,
        metallicFactor=metal
    )
    if emissive is not None:
        kwargs["emissiveFactor"]=list(emissive)
    return PBRMaterial(**kwargs)

M={
    "asphalt":mat("asphalt",(0.055,0.06,0.065),0.97),
    "line":mat("line",(0.78,0.72,0.42),0.85),
    "concrete":mat("concrete",(0.28,0.30,0.31),0.95),
    "rust":mat("rust",(0.28,0.10,0.055),0.92,0.15),
    "metal":mat("metal",(0.20,0.24,0.27),0.42,0.75),
    "darkmetal":mat("darkmetal",(0.06,0.075,0.085),0.36,0.82),
    "glass":mat("glass",(0.16,0.30,0.34),0.12,0.05,alpha=0.55),
    "wood":mat("wood",(0.20,0.12,0.07),0.90),
    "wood2":mat("wood2",(0.32,0.21,0.11),0.82),
    "pine":mat("pine",(0.035,0.11,0.07),0.94),
    "bark":mat("bark",(0.12,0.075,0.045),0.96),
    "cloth":mat("cloth",(0.025,0.028,0.032),0.88),
    "skin":mat("skin",(0.74,0.71,0.66),0.86),
    "black":mat("black",(0.01,0.01,0.012),0.88),
    "red":mat("red",(0.42,0.02,0.025),0.56,0.05,emissive=(0.18,0.0,0.0)),
    "cyan":mat("cyan",(0.08,0.42,0.46),0.38,0.10,emissive=(0.0,0.18,0.20)),
    "paper":mat("paper",(0.82,0.80,0.72),0.96),
    "rubber":mat("rubber",(0.025,0.025,0.028),0.98),
    "white":mat("white",(0.80,0.82,0.84),0.7),
}

def T(pos=(0,0,0),rot=(0,0,0),scale=(1,1,1)):
    m=trimesh.transformations.euler_matrix(*rot,axes='sxyz')
    m[:3,3]=pos
    m[:3,:3]=m[:3,:3]@np.diag(scale)
    return m

def add(sc,name,mesh,material,transform=None):
    mesh=mesh.copy()
    mesh.visual=trimesh.visual.TextureVisuals(material=material)
    sc.add_geometry(mesh,node_name=name,geom_name=name,transform=transform if transform is not None else np.eye(4))

def box(ext): return trimesh.creation.box(extents=ext)
def cyl(r,h,sections=28): return trimesh.creation.cylinder(radius=r,height=h,sections=sections)
def sphere(r,sub=3): return trimesh.creation.icosphere(subdivisions=sub,radius=r)
def cone(r,h,sections=24): return trimesh.creation.cone(radius=r,height=h,sections=sections)
def capsule(r,h): return trimesh.creation.capsule(radius=r,height=max(0.01,h-2*r),count=[24,24])

def export(sc,name):
    path=os.path.join(OUT,name)
    sc.export(path)
    print(name,os.path.getsize(path))

# Faceless entity
sc=trimesh.Scene()
add(sc,"Torso",capsule(.23,1.05),M["cloth"],T((0,1.38,0),rot=(math.pi/2,0,0),scale=(1.18,1,0.78)))
add(sc,"CoatFront",box((.72,.92,.08)),M["cloth"],T((0,1.34,-.17)))
add(sc,"CoatTailL",box((.30,.55,.11)),M["cloth"],T((-.19,.77,.02),rot=(0,0,.05)))
add(sc,"CoatTailR",box((.30,.55,.11)),M["cloth"],T((.19,.77,.02),rot=(0,0,-.05)))
add(sc,"Neck",cyl(.07,.13),M["skin"],T((0,1.91,0),rot=(math.pi/2,0,0)))
add(sc,"Head",sphere(.22,4),M["skin"],T((0,2.15,0),scale=(.88,1.06,.92)))
add(sc,"FaceBlank",sphere(.19,4),M["white"],T((0,2.14,-.08),scale=(.86,1.02,.35)))
for side,sx in [("L",-.47),("R",.47)]:
    add(sc,"UpperArm"+side,capsule(.065,.72),M["cloth"],T((sx,1.48,0),rot=(math.pi/2,0,.08 if sx<0 else -.08)))
    add(sc,"ForeArm"+side,capsule(.055,.72),M["cloth"],T((sx*1.02,.91,.0),rot=(math.pi/2,0,0)))
    add(sc,"Hand"+side,sphere(.065,2),M["skin"],T((sx*1.02,.52,-.01),scale=(.8,1.1,.72)))
for side,sx in [("L",-.15),("R",.15)]:
    add(sc,"Leg"+side,capsule(.085,.92),M["cloth"],T((sx,.43,.02),rot=(math.pi/2,0,0)))
    add(sc,"Shoe"+side,box((.18,.10,.32)),M["black"],T((sx,.035,-.06)))
export(sc,"faceless_entity.glb")

# Road
sc=trimesh.Scene()
add(sc,"Road",box((8.0,.12,130.0)),M["asphalt"],T((0,-.02,-40)))
add(sc,"ShoulderL",box((2.4,.09,130)),M["concrete"],T((-5.2,-.03,-40)))
add(sc,"ShoulderR",box((2.4,.09,130)),M["concrete"],T((5.2,-.03,-40)))
for z in range(20,-111,-5):
    add(sc,f"Dash{z}",box((.12,.015,2.4)),M["line"],T((0,.05,z)))
for x in (-3.75,3.75):
    add(sc,f"Edge{x}",box((.08,.015,129.0)),M["white"],T((x,.05,-40)))
export(sc,"blackwood_road.glb")

# checkpoint gate
sc=trimesh.Scene()
add(sc,"Booth",box((2.4,2.5,2.2)),M["concrete"],T((-5.1,1.25,0)))
add(sc,"BoothRoof",box((2.8,.18,2.6)),M["darkmetal"],T((-5.1,2.6,0)))
add(sc,"Window",box((1.45,.95,.05)),M["glass"],T((-5.1,1.6,-1.12)))
for x in (-3.8,3.8):
    add(sc,f"Post{x}",box((.22,3.2,.22)),M["metal"],T((x,1.6,0)))
add(sc,"Crossbar",box((8.0,.22,.22)),M["metal"],T((0,3.05,0)))
add(sc,"Barrier",box((6.8,.12,.18)),M["white"],T((.5,1.05,-.65),rot=(0,0,.06)))
for x in (-1.6,1.6):
    add(sc,f"Stripe{x}",box((.65,.13,.19)),M["red"],T((x,1.05,-.66),rot=(0,0,.06)))
add(sc,"CameraPole",cyl(.055,2.8),M["metal"],T((3.2,1.4,-.6),rot=(math.pi/2,0,0)))
add(sc,"Camera",box((.38,.22,.52)),M["darkmetal"],T((3.2,2.78,-.75),rot=(0,.2,0)))
export(sc,"checkpoint_gate.glb")

# tower
sc=trimesh.Scene()
for sx in (-1.1,1.1):
    for sz in (-1.1,1.1):
        add(sc,f"Leg{sx}{sz}",cyl(.07,6.0),M["metal"],T((sx,3,sz),rot=(math.pi/2,0,0)))
for y in (1.0,2.5,4.0,5.5):
    add(sc,f"BraceX{y}",box((2.4,.07,.07)),M["metal"],T((0,y,-1.05)))
    add(sc,f"BraceZ{y}",box((.07,.07,2.4)),M["metal"],T((1.05,y,0)))
add(sc,"Cabin",box((3.0,1.7,3.0)),M["darkmetal"],T((0,6.25,0)))
for x in (-.85,.0,.85):
    add(sc,"Glass"+str(x),box((.65,.7,.04)),M["glass"],T((x,6.35,-1.52)))
add(sc,"Roof",box((3.4,.18,3.4)),M["metal"],T((0,7.18,0)))
add(sc,"Dish",cyl(.62,.08,32),M["metal"],T((0,7.62,0),rot=(0,0,0)))
add(sc,"Mast",cyl(.04,1.3),M["metal"],T((0,7.65,0),rot=(math.pi/2,0,0)))
export(sc,"surveillance_tower.glb")

# bus stop
sc=trimesh.Scene()
add(sc,"Roof",box((4.4,.18,2.2)),M["metal"],T((0,2.3,0)))
for x in (-2.0,2.0):
    add(sc,"Post"+str(x),box((.12,2.3,.12)),M["metal"],T((x,1.15,.75)))
add(sc,"Back",box((4.0,1.8,.08)),M["glass"],T((0,1.2,.95)))
add(sc,"BenchSeat",box((2.8,.12,.55)),M["wood2"],T((0,.72,.3)))
add(sc,"BenchBack",box((2.8,.65,.09)),M["wood2"],T((0,1.05,.55),rot=(.15,0,0)))
export(sc,"abandoned_bus_stop.glb")

# cabin
sc=trimesh.Scene()
add(sc,"Body",box((5.8,2.7,4.6)),M["wood"],T((0,1.35,0)))
add(sc,"RoofL",box((3.6,.18,5.0)),M["rust"],T((-1.45,3.05,0),rot=(0,0,.38)))
add(sc,"RoofR",box((3.6,.18,5.0)),M["rust"],T((1.45,3.05,0),rot=(0,0,-.38)))
add(sc,"Door",box((1.2,2.2,.12)),M["darkmetal"],T((0,1.1,-2.35)))
for x in (-1.8,1.8):
    add(sc,"Window"+str(x),box((1.1,1.0,.06)),M["glass"],T((x,1.55,-2.36)))
add(sc,"Porch",box((4.5,.15,1.6)),M["wood2"],T((0,.08,-3.0)))
export(sc,"ranger_cabin.glb")

# fence
sc=trimesh.Scene()
for x in range(-6,7,2):
    add(sc,"Post"+str(x),box((.12,2.8,.12)),M["metal"],T((x,1.4,0)))
for y in (.4,.9,1.4,1.9,2.4):
    add(sc,"Rail"+str(y),box((12.0,.04,.04)),M["metal"],T((0,y,0)))
add(sc,"GateL",box((2.6,2.2,.10)),M["darkmetal"],T((-1.45,1.1,-.1),rot=(0,.18,0)))
add(sc,"GateR",box((2.6,2.2,.10)),M["darkmetal"],T((1.45,1.1,-.1),rot=(0,-.18,0)))
add(sc,"Warning",box((1.6,.8,.05)),M["red"],T((0,1.75,-.18)))
export(sc,"dead_zone_fence.glb")

# pine cluster
sc=trimesh.Scene()
for i,(x,z,s) in enumerate([(-2.2,-1.0,1.0),(0,0,1.25),(2.0,.7,.9),(-.6,2.2,.75)]):
    add(sc,f"Trunk{i}",cyl(.16*s,2.5*s),M["bark"],T((x,1.25*s,z),rot=(math.pi/2,0,0)))
    for j,(yy,rr,hh) in enumerate([(2.0,1.3,2.2),(2.8,1.0,1.9),(3.5,.7,1.5)]):
        add(sc,f"Needle{i}_{j}",cone(rr*s,hh*s,28),M["pine"],T((x,yy*s,z)))
export(sc,"pine_cluster.glb")

# power relay
sc=trimesh.Scene()
add(sc,"Cabinet",box((1.35,1.75,.65)),M["darkmetal"],T((0,.88,0)))
add(sc,"Door",box((1.18,1.52,.05)),M["metal"],T((0,.9,-.35)))
for y in (.5,.9,1.3):
    add(sc,"Vent"+str(y),box((.65,.035,.03)),M["black"],T((0,y,-.39)))
add(sc,"Screen",box((.42,.25,.025)),M["cyan"],T((0,1.42,-.39)))
add(sc,"Handle",cyl(.025,.3,18),M["white"],T((.43,.95,-.41),rot=(math.pi/2,0,0)))
export(sc,"power_relay.glb")

# evidence case
sc=trimesh.Scene()
add(sc,"Case",box((.62,.12,.45)),M["darkmetal"],T((0,.08,0)))
add(sc,"Lid",box((.62,.06,.45)),M["metal"],T((0,.18,.02),rot=(-.18,0,0)))
add(sc,"Paper",box((.38,.015,.25)),M["paper"],T((0,.225,-.02)))
add(sc,"Seal",box((.11,.015,.11)),M["red"],T((.12,.236,-.03)))
export(sc,"evidence_case.glb")

# terminal
sc=trimesh.Scene()
add(sc,"Desk",box((1.6,.75,.8)),M["metal"],T((0,.38,0)))
add(sc,"Monitor",box((1.15,.7,.16)),M["darkmetal"],T((0,1.18,-.08),rot=(-.1,0,0)))
add(sc,"Screen",box((.92,.52,.025)),M["cyan"],T((0,1.18,-.17),rot=(-.1,0,0)))
add(sc,"Keyboard",box((.85,.06,.3)),M["darkmetal"],T((0,.82,-.28),rot=(.08,0,0)))
for x in (-.48,-.16,.16,.48):
    add(sc,"Key"+str(x),box((.08,.025,.08)),M["red"] if x==.48 else M["white"],T((x,.86,-.31)))
export(sc,"security_terminal.glb")

# extraction gate
sc=trimesh.Scene()
for x in (-3.8,3.8):
    add(sc,"Pillar"+str(x),box((.55,4.2,.55)),M["concrete"],T((x,2.1,0)))
add(sc,"Header",box((8.2,.6,.7)),M["concrete"],T((0,4.0,0)))
add(sc,"GateL",box((3.5,3.2,.18)),M["darkmetal"],T((-1.85,1.6,0)))
add(sc,"GateR",box((3.5,3.2,.18)),M["darkmetal"],T((1.85,1.6,0)))
for x in (-2.8,-1.8,-.8,.8,1.8,2.8):
    add(sc,"Bar"+str(x),box((.08,2.8,.12)),M["metal"],T((x,1.6,-.12)))
add(sc,"Light",box((1.6,.25,.18)),M["red"],T((0,3.72,-.4)))
export(sc,"extraction_gate.glb")

def wav(path, seconds, kind):
    rate=22050
    n=int(rate*seconds)
    rng=np.random.default_rng(7)
    data=[]
    for i in range(n):
        t=i/rate
        if kind=="amb":
            v=0.10*math.sin(2*math.pi*48*t)+0.05*math.sin(2*math.pi*73*t)+0.02*rng.normal()
        elif kind=="static":
            env=max(0.0,1.0-t/seconds)
            v=0.22*rng.normal()*env + 0.06*math.sin(2*math.pi*180*t)*env
        else:
            v=0.11*math.sin(2*math.pi*(72+22*math.sin(t*1.8))*t)+0.035*rng.normal()
        data.append(max(-1,min(1,v)))
    with wave.open(path,"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h",int(v*32767)) for v in data))

wav(os.path.join(AUDIO,"blackwood_ambience.wav"),8.0,"amb")
wav(os.path.join(AUDIO,"signal_static.wav"),1.2,"static")
wav(os.path.join(AUDIO,"chase_pulse.wav"),6.0,"chase")
print("audio generated")


# --- v2 combat assets ---
sc=trimesh.Scene()
add(sc,"Slide",box((.28,.16,.72)),M["darkmetal"],T((0,.06,0)))
add(sc,"Grip",box((.18,.42,.22)),M["rubber"],T((0,-.20,.18),rot=(.18,0,0)))
add(sc,"Barrel",cyl(.035,.48,20),M["metal"],T((0,.06,-.46),rot=(0,0,0)))
add(sc,"FrontSight",box((.025,.05,.04)),M["white"],T((0,.17,-.32)))
export(sc,"pistol.glb")

sc=trimesh.Scene()
add(sc,"Receiver",box((.24,.20,.92)),M["darkmetal"],T((0,.04,-.08)))
add(sc,"Barrel",cyl(.028,1.05,22),M["metal"],T((0,.05,-.94)))
add(sc,"Stock",box((.22,.30,.58)),M["wood"],T((0,-.03,.68),rot=(0.05,0,0)))
add(sc,"Grip",box((.14,.34,.20)),M["rubber"],T((0,-.24,.18),rot=(.22,0,0)))
add(sc,"Magazine",box((.14,.38,.24)),M["darkmetal"],T((0,-.24,-.10),rot=(.25,0,0)))
add(sc,"Sight",box((.06,.07,.10)),M["white"],T((0,.18,-.52)))
export(sc,"rifle.glb")

sc=trimesh.Scene()
add(sc,"Torso",capsule(.22,1.0),M["darkmetal"],T((0,1.35,0),rot=(math.pi/2,0,0),scale=(1.2,1,.8)))
add(sc,"Vest",box((.78,.68,.30)),M["metal"],T((0,1.38,-.04)))
add(sc,"Head",sphere(.21,3),M["skin"],T((0,2.02,0),scale=(.95,1.0,.92)))
add(sc,"Helmet",sphere(.23,2),M["darkmetal"],T((0,2.13,.02),scale=(1.02,.70,1.02)))
for side,sx in [("L",-.46),("R",.46)]:
    add(sc,"Arm"+side,capsule(.07,.70),M["darkmetal"],T((sx,1.34,0),rot=(math.pi/2,0,0)))
for side,sx in [("L",-.16),("R",.16)]:
    add(sc,"Leg"+side,capsule(.09,.90),M["darkmetal"],T((sx,.47,0),rot=(math.pi/2,0,0)))
add(sc,"Weapon",box((.15,.14,1.0)),M["metal"],T((.27,1.16,-.34),rot=(0,.25,-.22)))
export(sc,"blackwood_soldier.glb")

sc=trimesh.Scene()
add(sc,"AmmoCrate",box((.75,.32,.52)),M["darkmetal"],T((0,.16,0)))
add(sc,"Lid",box((.78,.06,.55)),M["metal"],T((0,.35,0)))
for x in (-.22,0,.22):
    add(sc,"Round"+str(x),cyl(.025,.28,12),M["line"],T((x,.41,0),rot=(math.pi/2,0,0)))
export(sc,"ammo_box.glb")

sc=trimesh.Scene()
add(sc,"Case",box((.52,.18,.40)),M["white"],T((0,.10,0)))
add(sc,"CrossV",box((.10,.025,.28)),M["red"],T((0,.205,0)))
add(sc,"CrossH",box((.28,.025,.10)),M["red"],T((0,.205,0)))
export(sc,"medkit.glb")

sc=trimesh.Scene()
add(sc,"Pole",cyl(.055,3.8,18),M["metal"],T((0,1.9,0),rot=(math.pi/2,0,0)))
add(sc,"Arm",box((.55,.06,.06)),M["metal"],T((.24,3.75,0)))
add(sc,"Lamp",box((.48,.18,.28)),M["white"],T((.52,3.62,0)))
export(sc,"street_lamp.glb")


# --- v3 first-person realistic-ish viewmodel assets ---
HAND_SKIN = mat("hand_skin",(0.71,0.50,0.37),0.78)
HAND_NAIL = mat("hand_nail",(0.78,0.61,0.52),0.64)
SLEEVE = mat("sleeve",(0.07,0.09,0.11),0.88)
GUN_BLACK = mat("gun_black",(0.055,0.065,0.075),0.30,0.82)
GUN_STEEL = mat("gun_steel",(0.20,0.23,0.26),0.28,0.92)
GUN_GRIP = mat("gun_grip",(0.035,0.035,0.038),0.88,0.06)
BRASS = mat("brass",(0.55,0.36,0.12),0.38,0.78)
RED_DOT = mat("red_dot",(0.22,0.02,0.02),0.25,0.15,emissive=(0.30,0.0,0.0))

def make_hand(name, mirror=1.0):
    sc=trimesh.Scene()
    add(sc,"Forearm",capsule(.075,.46),SLEEVE,T((0,-.18,.22),rot=(math.pi/2,0,0),scale=(1.05,1,.88)))
    add(sc,"Wrist",cyl(.065,.11,24),HAND_SKIN,T((0,.05,.02),rot=(math.pi/2,0,0)))
    add(sc,"Palm",box((.18,.085,.24)),HAND_SKIN,T((0,.12,-.08),rot=(-.08,0,0)))
    finger_x=[-.075,-.025,.025,.075]
    lengths=[.15,.17,.165,.145]
    for i,(x,l) in enumerate(zip(finger_x,lengths)):
        add(sc,f"Finger{i}_1",capsule(.019,l),HAND_SKIN,T((x,.16,-.215),rot=(math.pi/2+.18,0,.02*x)))
        add(sc,f"Finger{i}_2",capsule(.017,l*.72),HAND_SKIN,T((x,.145,-.335),rot=(math.pi/2+.55,0,0)))
        add(sc,f"Nail{i}",box((.028,.010,.045)),HAND_NAIL,T((x,.115,-.385),rot=(.35,0,0)))
    add(sc,"Thumb1",capsule(.023,.13),HAND_SKIN,T((-.115*mirror,.11,-.10),rot=(1.20,0,.85*mirror)))
    add(sc,"Thumb2",capsule(.021,.10),HAND_SKIN,T((-.155*mirror,.075,-.17),rot=(1.35,0,.55*mirror)))
    return sc

make_hand("Right",1.0).export(os.path.join(OUT,"fp_right_hand.glb"))
make_hand("Left",-1.0).export(os.path.join(OUT,"fp_left_hand.glb"))

# More detailed pistol, overwrites v2 pistol.glb
sc=trimesh.Scene()
add(sc,"Slide",box((.30,.16,.78)),GUN_STEEL,T((0,.085,-.08)))
add(sc,"SlideCutL",box((.035,.07,.26)),GUN_BLACK,T((-.145,.09,-.19)))
add(sc,"SlideCutR",box((.035,.07,.26)),GUN_BLACK,T((.145,.09,-.19)))
add(sc,"Frame",box((.27,.16,.56)),GUN_BLACK,T((0,-.045,.03)))
add(sc,"Grip",box((.21,.46,.24)),GUN_GRIP,T((0,-.27,.18),rot=(.18,0,0)))
add(sc,"GripBack",box((.12,.38,.06)),GUN_BLACK,T((0,-.27,.32),rot=(.18,0,0)))
add(sc,"Barrel",cyl(.034,.54,24),GUN_STEEL,T((0,.08,-.55)))
add(sc,"Muzzle",cyl(.047,.05,24),GUN_BLACK,T((0,.08,-.82)))
add(sc,"TriggerGuard",trimesh.creation.torus(major_radius=.075,minor_radius=.012,major_sections=24,minor_sections=10),GUN_BLACK,T((0,-.12,-.02),rot=(math.pi/2,0,0),scale=(1.2,1,.72)))
add(sc,"Trigger",box((.025,.10,.025)),GUN_STEEL,T((0,-.115,.02),rot=(0,0,.20)))
add(sc,"RearSight",box((.11,.055,.06)),GUN_BLACK,T((0,.19,.20)))
add(sc,"FrontSight",box((.035,.06,.05)),GUN_BLACK,T((0,.19,-.41)))
add(sc,"Rail",box((.18,.035,.34)),GUN_BLACK,T((0,-.15,-.25)))
export(sc,"pistol.glb")

sc=trimesh.Scene()
add(sc,"MagBody",box((.17,.42,.18)),GUN_BLACK,T((0,-.02,0),rot=(.16,0,0)))
add(sc,"MagBase",box((.19,.05,.20)),GUN_GRIP,T((0,-.25,.03),rot=(.16,0,0)))
add(sc,"FeedLips",box((.14,.04,.14)),GUN_STEEL,T((0,.205,-.02),rot=(.16,0,0)))
export(sc,"pistol_mag.glb")

# More detailed rifle, overwrites v2 rifle.glb
sc=trimesh.Scene()
add(sc,"UpperReceiver",box((.25,.18,.92)),GUN_STEEL,T((0,.08,-.12)))
add(sc,"LowerReceiver",box((.24,.23,.60)),GUN_BLACK,T((0,-.08,.05)))
add(sc,"Handguard",box((.21,.20,.76)),GUN_BLACK,T((0,.06,-.95)))
for z in (-.72,-.95,-1.18):
    add(sc,"Rail"+str(z),box((.22,.025,.18)),GUN_STEEL,T((0,.175,z)))
add(sc,"Barrel",cyl(.026,1.08,24),GUN_STEEL,T((0,.06,-1.58)))
add(sc,"MuzzleBrake",cyl(.048,.18,20),GUN_BLACK,T((0,.06,-2.15)))
add(sc,"StockTube",cyl(.045,.56,20),GUN_STEEL,T((0,.02,.74)))
add(sc,"Stock",box((.26,.34,.65)),GUN_BLACK,T((0,-.02,1.10),rot=(.03,0,0)))
add(sc,"PistolGrip",box((.17,.38,.20)),GUN_GRIP,T((0,-.27,.32),rot=(.22,0,0)))
add(sc,"TriggerGuard",trimesh.creation.torus(major_radius=.07,minor_radius=.011,major_sections=20,minor_sections=8),GUN_BLACK,T((0,-.17,.05),rot=(math.pi/2,0,0),scale=(1.2,1,.7)))
add(sc,"OpticBase",box((.17,.06,.26)),GUN_BLACK,T((0,.21,-.22)))
add(sc,"Optic",cyl(.07,.28,24),GUN_STEEL,T((0,.29,-.20),rot=(math.pi/2,0,0)))
add(sc,"LensF",cyl(.058,.012,24),RED_DOT,T((0,.29,-.35),rot=(math.pi/2,0,0)))
add(sc,"ForeGrip",box((.11,.30,.12)),GUN_GRIP,T((0,-.16,-.93),rot=(.15,0,0)))
export(sc,"rifle.glb")

sc=trimesh.Scene()
add(sc,"MagBody",box((.18,.52,.23)),GUN_BLACK,T((0,-.02,0),rot=(.20,0,0)))
add(sc,"MagCurve",box((.18,.24,.22)),GUN_BLACK,T((0,-.38,.05),rot=(.35,0,0)))
add(sc,"MagBase",box((.20,.05,.24)),GUN_GRIP,T((0,-.53,.10),rot=(.35,0,0)))
for i in range(3):
    add(sc,"Round"+str(i),cyl(.015,.16,12),BRASS,T((-.045+i*.045,.27,-.03),rot=(math.pi/2,0,0)))
export(sc,"rifle_mag.glb")

print("v3 viewmodel GLBs generated")
