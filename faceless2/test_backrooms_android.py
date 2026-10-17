"""Install exported APK, operate actual Android touch UI, and join desktop ENet host."""
import argparse
import io
from pathlib import Path
import xml.etree.ElementTree as ET
import subprocess
import time
from PIL import Image
from test_backrooms_visual import check_monitor

p = argparse.ArgumentParser()
p.add_argument('--godot', default='godot')
p.add_argument('--project', default='app')
p.add_argument('--apk', required=True)
p.add_argument('--output', default='qa')
args = p.parse_args()
out = Path(args.output)
out.mkdir(parents=True, exist_ok=True)
manifest = ET.fromstring((out / 'android-manifest.xml').read_text())
ns = '{http://schemas.android.com/apk/res/android}'
package = manifest.get('package')
activity = None
for candidate in manifest.findall('application/activity') + manifest.findall('application/activity-alias'):
    for intent in candidate.findall('intent-filter'):
        if any(a.get(ns + 'name') == 'android.intent.action.MAIN' for a in intent.findall('action')):
            activity = candidate.get(ns + 'name')
assert package and activity, 'APK launcher activity missing'
if activity.startswith('.'): activity = package + activity

def adb(*params, binary=False):
    return subprocess.check_output(['adb', *params], timeout=40, text=not binary)

def logs():
    return adb('logcat', '-d', '-s', 'godot', 'Godot', 'AndroidRuntime')

def wait_marker(marker, limit=45):
    deadline = time.monotonic() + limit
    while time.monotonic() < deadline:
        text = logs()
        if any(x in text for x in ['FATAL EXCEPTION', 'SCRIPT ERROR', 'Parse Error', 'ERROR:', 'Fatal signal']):
            raise RuntimeError(text)
        if marker in text: return
        time.sleep(.5)
    raise RuntimeError('Android marker missing: ' + marker + '\n' + logs())

width, height = 1920, 1080

def capture(name):
    global width, height
    image = Image.open(io.BytesIO(adb('exec-out', 'screencap', '-p', binary=True))).convert('RGB')
    width, height = image.size
    assert width > height, 'APK must run landscape'
    colors = image.resize((128, 72)).getcolors(128 * 72)
    assert colors is None or len(colors) > 100, 'Blank Android frame'
    image.save(out / (name + '.png'))
    if 'monitor' in name: check_monitor(out / (name + '.png'))

def tap(x, y):
    adb('shell', 'input', 'tap', str(int(width * x)), str(int(height * y)))
    time.sleep(.7)

def walk_to_console():
    adb('shell', 'input', 'swipe', str(int(width * .105)), str(int(height * .823)), str(int(width * .105)), str(int(height * .745)), '2000')
    time.sleep(.8)
    tap(.90, .79)
    wait_marker('UI_SCREEN / monitor', 20)

host = None
host_log = None
solo_text = ''
try:
    # AOSP's own device tests preconfirm the first-fullscreen system tutorial.
    # Use a 720p device surface to keep CPU Vulkan rendering practical in CI.
    adb('shell', 'settings', 'put', 'secure', 'immersive_mode_confirmations', 'confirmed')
    adb('shell', 'wm', 'size', '720x1280')
    adb('install', '--no-streaming', '-r', args.apk)
    adb('logcat', '-c')
    adb('shell', 'am', 'start', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-n', package + '/' + activity)
    wait_marker('UI_SCREEN / menu', 90)
    time.sleep(2)
    capture('android-01-menu')
    tap(.225, .639)
    wait_marker('UI_SCREEN / play')
    time.sleep(2)
    capture('android-02-level-zero')
    walk_to_console()
    capture('android-03-live-monitor')
    tap(.88, .064)
    tap(.925, .075)
    wait_marker('UI_SCREEN / pause')
    tap(.235, .761)
    time.sleep(1)
    host_log = (out / 'android-p2p-host.log').open('w')
    host = subprocess.Popen([args.godot, '--headless', '--path', args.project, '--script', 'scripts/backrooms_network_checks.gd', '--', '--role=androidhost', '--port=24711'], stdout=host_log, stderr=subprocess.STDOUT)
    deadline = time.monotonic() + 8
    while 'ANDROID_HOST_READY' not in (out / 'android-p2p-host.log').read_text():
        assert time.monotonic() < deadline and host.poll() is None, 'Integration host failed'
        time.sleep(.1)
    tap(.225, .745)
    wait_marker('UI_SCREEN / lobby')
    capture('android-04-lobby')
    tap(.24, .419)
    adb('shell', 'input', 'text', '10.0.2.2')
    adb('shell', 'input', 'keyevent', '66')
    time.sleep(.5)
    # Hide an IME if one appeared, preserving the Godot lobby.
    if 'mInputShown=true' in adb('shell', 'dumpsys', 'input_method'):
        adb('shell', 'input', 'keyevent', '4')
    solo_text = logs()
    (out / 'android-solo-logcat.log').write_text(solo_text)
    (out / 'android-solo-system-logcat.log').write_text(adb('logcat', '-d'))
    assert 'ERROR:' not in solo_text, solo_text
    adb('logcat', '-c')
    tap(.356, .746)
    wait_marker('UI_SCREEN / play', 35)
    assert 'ANDROID_PEER_JOINED' in (out / 'android-p2p-host.log').read_text(), 'APK did not join actual ENet host'
    time.sleep(1)
    capture('android-05-p2p-connected')
    walk_to_console()
    time.sleep(1)
    tap(.825, .365)
    deadline = time.monotonic() + 10
    while 'ANDROID_ACTION_RECEIVED' not in (out / 'android-p2p-host.log').read_text():
        assert time.monotonic() < deadline, 'Android shutter input did not replicate'
        time.sleep(.2)
    capture('android-06-p2p-monitor')
    adb('shell', 'am', 'force-stop', package)
    code = host.wait(timeout=25)
    assert code == 0 and 'P2P androidhost: PASS' in (out / 'android-p2p-host.log').read_text()
    text = solo_text + '\n' + logs()
    assert not any(x in text for x in ['FATAL EXCEPTION', 'SCRIPT ERROR', 'Parse Error', 'ERROR:', 'Fatal signal']), text
    print('Android APK checks: PASS / install, launch, landscape, touch movement, live monitor, actual P2P join, shutter replication, disconnect')
except Exception:
    try:
        (out / 'android-failure.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
        (out / 'android-window.txt').write_text(adb('shell', 'dumpsys', 'window'))
    except Exception: pass
    raise
finally:
    (out / 'android-logcat.log').write_text(logs())
    (out / 'android-system-logcat.log').write_text(adb('logcat', '-d'))
    if host is not None and host.poll() is None:
        host.terminate()
        try: host.wait(timeout=3)
        except subprocess.TimeoutExpired: host.kill()
    if host_log is not None: host_log.close()
