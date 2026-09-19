import json
import getpass
import os
from pathlib import Path
import shutil
import subprocess
import time

home=Path.home()
base=home/'.local/state/omarchy-media-layout/native-test'
base.mkdir(parents=True,exist_ok=True)
source=home/'.config/omarchy/plugins'/(getpass.getuser()+'.media')
for name in ['Commons','Ui','services','plugins']:
    link=base/name
    if not link.exists():link.symlink_to(Path('/usr/share/omarchy/shell')/name,target_is_directory=True)
for name in ['FlexibleMediaWidth.qml','MediaWidthAllocator.js']:
    shutil.copy2(source/name,base/name)
shutil.copy2(source/'BarWidget.qml',base/'NativeMedia.qml')
shutil.copy2(Path(__file__).with_name('native-width-test.qml'),base/'shell.qml')
env=dict(os.environ,WAYLAND_DISPLAY='wayland-1',OMARCHY_PATH='/usr/share/omarchy')
log=base/'run.log'
with log.open('w') as output:
    proc=subprocess.Popen(['qs','-p',str(base/'shell.qml')],env=env,stdout=output,stderr=subprocess.STDOUT)
    def call(*args):
        result=subprocess.run(['qs','ipc','-p',str(base/'shell.qml'),'call','width-test',*args],env=env,text=True,capture_output=True,timeout=5)
        if result.returncode:raise RuntimeError(result.stderr)
        return result.stdout.strip()
    def snapshot():return json.loads(call('snapshot'))
    try:
        deadline=time.monotonic()+12
        while True:
            try:initial=snapshot();break
            except Exception:
                if proc.poll() is not None or time.monotonic()>deadline:raise
                time.sleep(.15)
        time.sleep(.3)
        assert initial['needsScroll'] and abs(initial['width']-434)<2,initial
        call('metadata','Short','Artist');time.sleep(.3)
        short=snapshot();assert not short['needsScroll'] and short['labelX']==0 and abs(short['width']-434)<2,short
        call('resize','1200');time.sleep(.3)
        resized=snapshot();assert abs(resized['width']-534)<2 and resized['labelX']==0,resized
        call('metadata','','Only Artist');time.sleep(.3)
        artist=snapshot();assert artist['clipVisible'] and abs(artist['width']-534)<2,artist
        call('fill','false');time.sleep(.3)
        disabled=snapshot();assert disabled['width']<50 and not disabled['clipVisible'],disabled
        call('fill','true');time.sleep(.3)
        restored=snapshot();assert restored['clipVisible'] and abs(restored['width']-534)<2,restored
        call('metadata','','');time.sleep(.3)
        hidden=snapshot();assert not hidden['widgetVisible'] and hidden['width']==0,hidden
        call('metadata','Short','Artist');time.sleep(.3)
        shown=snapshot();assert shown['widgetVisible'] and abs(shown['width']-534)<2 and shown['labelX']==0,shown
        print('PASS native QML: long-to-short marquee reset, resize, artist-only, fill toggle, hide/reappear')
    except Exception:
        print(log.read_text()[-4500:]);raise
    finally:
        proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
text=log.read_text()
assert not any(s in text for s in ['Binding loop','ReferenceError','TypeError','Error loading']),text[-4000:]
print('PASS native fixture logs clean; test process removed; no audio backend used')
