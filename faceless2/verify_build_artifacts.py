"""Audit unmodified artifacts from the exact standalone FPS source commit.
No gameplay, emulator or graphical runtime is launched here.
"""
import base64,hashlib,json,math,re,shutil,struct,subprocess,time,zipfile
from pathlib import Path
from PIL import Image,ImageDraw

REPO="h1collab/ggme"
SOURCE="637e79095b7b2026dd74d9b02550e21a4ae2aeb2"
APK_RUN=38911613127
PREVIEW_RUN=38911613143
ROOT=Path("artifact-audit")
OUT=Path("faceless2/qa/637e790")
ROOT.mkdir(exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True)

def api(path):
    return json.loads(subprocess.check_output(["gh","api","repos/"+REPO+"/"+path],text=True))
def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):h.update(block)
    return h.hexdigest()
def archive(run,name,folder):
    entries=api("actions/runs/%d/artifacts"%run)["artifacts"]
    a=next(x for x in entries if x["name"]==name and not x["expired"])
    assert a["workflow_run"]["head_sha"]==SOURCE
    target=ROOT/(folder+".zip")
    with target.open("wb") as f:
        subprocess.run(["gh","api","repos/"+REPO+"/actions/artifacts/%d/zip"%a["id"]],stdout=f,check=True)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None
        dest=ROOT/folder
        for n in z.namelist():assert (dest/n).resolve().is_relative_to(dest.resolve())
        z.extractall(dest)
    return {"id":a["id"],"name":name,"zip_bytes":target.stat().st_size,
            "zip_sha256":sha(target),"url":"https://github.com/"+REPO+"/actions/runs/%d/artifacts/%d"%(run,a["id"])}
deadline=time.monotonic()+1200
for run in [APK_RUN,PREVIEW_RUN]:
    while True:
        d=api("actions/runs/%d"%run)
        assert d["head_sha"]==SOURCE
        if d["status"]=="completed":
            assert d["conclusion"]=="success",(run,d["conclusion"])
            break
        assert time.monotonic()<deadline,"Source CI timeout"
        time.sleep(15)
artifacts=[archive(APK_RUN,"faceless2-v035-zorix-apk","apk"),
           archive(APK_RUN,"faceless2-v035-headless-qa","qa"),
           archive(PREVIEW_RUN,"faceless2-godot-desktop-preview","preview")]
q=ROOT/"qa";p=ROOT/"preview";apk=ROOT/"apk/faceless2-v035-zorix.apk"
assert (q/"commit-sha.txt").read_text().strip()==(p/"commit-sha.txt").read_text().strip()==SOURCE
markers={"fps-checks.log":"FACELESS2_FPS_CHECKS_PASS","mobile-controls.log":"FPS_MOBILE_REAL_INPUT_PASS",
"fps-sessions.log":"FPS_REAL_MULTIPROCESS_UDP_PASS","runtime-checks.log":"Faceless 2 runtime checks: PASS",
"network-checks.log":"Faceless 2 P2P checks: PASS","story-checks.log":"Faceless 2 story checks: PASS",
"prologue-checks.log":"Faceless 2 prologue checks: PASS","cinematic-checks.log":"Faceless 2 cinematic checks: PASS",
"extra-levels-checks.log":"Faceless 2 extra levels checks: PASS","room-directory.log":"Faceless 2 room directory: PASS"}
for name,marker in markers.items():
    text=(q/name).read_text();assert marker in text and "ERROR:" not in text and "FAIL" not in text,name
sessions=json.loads((q/"fps-session-results.json").read_text());assert len(sessions)==6
assert {(x["capacity"],x["map_id"]) for x in sessions}=={(n,m) for n in [2,3,4] for m in [0,1]}
for row in sessions:
    assert all(v=="PASS" or str(v).startswith("covered_") for k,v in row.items() if k not in ["capacity","map_id"])
assert sessions[0]["ten_actual_kills"]=="PASS" and sessions[0]["timeout_draw_auto_rematch"]=="PASS"
assert "FPS_REAL_LAN_ROOM_PASS" in (q/"fps-sessions.log").read_text()
with zipfile.ZipFile(apk) as z:
    assert z.testzip() is None
    names=set(z.namelist());references=[]
    for key in ["fps_m4a1.glb","fps_wrad_grip_r.glb","fps_wrad_grip_l.glb","fps_daylight_sky.hdr",
                "wakeup_floor_panel.glb","game_icon.png","team_logo.jpg","ASSET_CREDITS.md","brief_0.ogg"]:
        assert any(n.endswith("/"+key) or n.endswith("/"+key+".import") or n.endswith("/"+key+".remap") for n in names),key
    for arch in ["arm64-v8a","x86_64"]:assert any(n.startswith("lib/"+arch+"/libgodot") for n in names)
    for n in sorted(names):
        if not n.endswith((".import",".remap")):continue
        for section in re.findall(r"(?:path(?:\.\w+)?|dest_files)\s*=\s*(.*)",z.read(n).decode()):
            for target in re.findall(r'res://([^"\],)]+)',section):
                assert "assets/"+target in names,(n,target)
                references.append(target)
    raw=z.read("AndroidManifest.xml");strings=[];manifest={};off=8
    def u16(i):return struct.unpack_from("<H",raw,i)[0]
    def u32(i):return struct.unpack_from("<I",raw,i)[0]
    def l8(i):
        v=raw[i];return ((((v&127)<<8)|raw[i+1],i+2) if v&128 else (v,i+1))
    def l16(i):
        v=u16(i);return ((((v&32767)<<16)|u16(i+2),i+4) if v&32768 else (v,i+2))
    while off<len(raw):
        kind,header,size=struct.unpack_from("<HHI",raw,off);assert size>=8 and off+size<=len(raw)
        if kind==1:
            count,flags,start=u32(off+8),u32(off+16),u32(off+20)
            for j in range(count):
                i=off+start+u32(off+header+j*4)
                if flags&256:
                    _,i=l8(i);length,i=l8(i);strings.append(raw[i:i+length].decode())
                else:
                    length,i=l16(i);strings.append(raw[i:i+length*2].decode("utf-16-le"))
        elif kind==0x102:
            element=strings[u32(off+20)];start=off+16+u16(off+24);count,stride=u16(off+28),u16(off+26);attrs={}
            for j in range(count):
                i=start+j*stride;name,r,value=u32(i+4),u32(i+8),u32(i+16)
                attrs[strings[name]]=strings[r] if r!=0xffffffff else (strings[value] if raw[i+15]==3 else value)
            if element in ["manifest","uses-sdk"]:manifest[element]=attrs
        off+=size
    assert manifest["manifest"]["versionCode"]==35 and manifest["manifest"]["versionName"]=="0.35.0"
movie=p/"faceless2-v035-godot-real-gameplay.mp4"
probe=json.loads(subprocess.check_output(["ffprobe","-v","error","-show_streams","-of","json",str(movie)]))
v=probe["streams"][0]
assert len(probe["streams"])==1 and v["codec_name"]=="h264" and v["width"]==960 and v["height"]==540
assert v["avg_frame_rate"]=="20/1" and int(v["nb_frames"])==520 and float(v["duration"])==26
subprocess.run(["ffmpeg","-v","error","-i",str(movie),"-f","null","-"],check=True)
rows=[x for x in subprocess.check_output(["ffmpeg","-v","error","-i",str(movie),"-f","framemd5","-"]).decode().splitlines() if x and not x.startswith("#")]
assert len(rows)==520 and len({x.rsplit(",",1)[-1] for x in rows})==520
for name,marker in [("preview.log","GODOT_PREVIEW_PASS"),("video.log","GODOT_CONTINUOUS_VIDEO_FRAMES_PASS 520")]:
    text=(p/name).read_text();assert marker in text and "ERROR:" not in text and "FAIL:" not in text
assert "NATIVE_RESULT_ACTUAL_ENET_PEERS 2" in (p/"preview.log").read_text()
stills=sorted(p.glob("map*.png"));assert len(stills)==27
for f in stills:
    with Image.open(f) as im:assert im.size==(1600,900);im.verify()
def sheets(files,prefix):
    for index in range(0,len(files),9):
        group=files[index:index+9];canvas=Image.new("RGB",(1600,math.ceil(len(group)/3)*320),(18,18,18));draw=ImageDraw.Draw(canvas)
        for k,f in enumerate(group):
            im=Image.open(f).convert("RGB");im.thumbnail((533,300))
            x=k%3*533;y=k//3*320;canvas.paste(im,(x,y));draw.text((x+6,y+302),f.name,fill="white")
        canvas.save(OUT/("%s-%02d.jpg"%(prefix,index//9)),quality=88)
sheets(stills,"stills")
sample=ROOT/"movie-samples";sample.mkdir(exist_ok=True)
subprocess.run(["ffmpeg","-v","error","-i",str(movie),"-vf","fps=2","-q:v","2",str(sample/"%03d.jpg")],check=True)
samples=sorted(sample.glob("*.jpg"));assert len(samples)==52
sheets(samples,"movie")
for src,dest in [("map1_00_overview.png","Hangar.png"),("map0_05_near_shipped_wall.png","CloseWall.png"),
                 ("map0_13_reload_actual_magazine_contact.png","ReloadContact.png"),("map0_02_ads.png","ADS.png"),
                 ("map0_12_real_two_peer_result.png","RoundResult.png")]:
    shutil.copyfile(p/src,OUT/dest)
    Image.open(p/src).convert("RGB").save(OUT/(Path(dest).stem+"-review.jpg"),quality=95)
shutil.copyfile("faceless2/ASSET_CREDITS.md",OUT/"ASSET_CREDITS.md")
report={"source_sha":SOURCE,"version":"0.35.0","protocol":21,"apk_run":APK_RUN,"preview_run":PREVIEW_RUN,
"artifacts":artifacts,"apk":{"bytes":apk.stat().st_size,"sha256":sha(apk),"crc":"PASS","manifest":manifest,
"resource_references":len(references)},"video":{"bytes":movie.stat().st_size,"sha256":sha(movie),"codec":"h264",
"width":960,"height":540,"fps":20,"frames":520,"seconds":26,"audio":False,"distinct_frames":520,"decode":"PASS"},
"headless":{name:"PASS" for name in markers},"sessions":sessions,"lan":"PASS","native_stills":27,
"movie_review_samples":52,"manual_review":"pending root visual review","device_fps_public_nat":"unverified"}
(OUT/"Verification.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
(OUT/"SHA256SUMS.txt").write_text("".join(sha(f)+"  "+f.name+"\n" for f in sorted(OUT.iterdir()) if f.is_file() and f.name!="SHA256SUMS.txt"))
print("ARTIFACT_AUDIT_REPORT "+json.dumps(report,separators=(",",":")))
print("ARTIFACT_AUDIT_PASS same original source SHA, APK itself, CRC/resource closure, continuous native video, 27 PNGs and all real headless UDP cases")
