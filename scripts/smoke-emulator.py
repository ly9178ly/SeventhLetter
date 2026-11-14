"""Operate this app through HarmonyOS uitest; captures are real emulator output.
This starts a NEW investigation and replaces this app's current autosave.
Usage: python scripts/smoke-emulator.py --hdc <path-to-hdc.exe>
"""
import argparse
import json
import re
import subprocess
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--hdc', required=True)
parser.add_argument('--record', action='store_true', help='Continuously capture the real emulator into docs/demo.gif (requires Pillow)')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
scratch = root / 'artifacts'
shots = root / 'docs' / 'screenshots'
scratch.mkdir(exist_ok=True)
shots.mkdir(exist_ok=True)
results = []
recording_stop = threading.Event()
recorded_frames = []
recording_errors = []


def run(*parts):
    output = subprocess.run([args.hdc, *parts], capture_output=True, timeout=20)
    text = output.stdout.decode('utf-8', errors='replace') + output.stderr.decode('utf-8', errors='replace')
    if output.returncode or '[Fail]' in text:
        raise RuntimeError(text)
    return text


def layout():
    run('shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/seventh-smoke.json')
    run('file', 'recv', '/data/local/tmp/seventh-smoke.json', str(scratch / 'layout.json'))
    return json.loads((scratch / 'layout.json').read_text(encoding='utf-8'))


def flatten(node):
    yield node.get('attributes', {})
    for child in node.get('children', []):
        yield from flatten(child)


def wait_text(text, retries=12):
    for _ in range(retries):
        nodes = list(flatten(layout()))
        match = next((n for n in nodes if n.get('text') == text and n.get('visible') != 'false'), None)
        if match:
            return match
        time.sleep(0.25)
    raise AssertionError(f'Expected text absent: {text}; visible texts: {[n.get("text") for n in nodes if n.get("text")]}')


def click(text):
    node = wait_text(text)
    coordinates = [int(value) for value in re.findall(r'-?\d+', node['bounds'])]
    left, top, right, bottom = coordinates
    assert right > left and bottom > top, (text, node['bounds'])
    run('shell', 'uitest', 'uiInput', 'click', str((left + right) // 2), str((top + bottom) // 2))
    time.sleep(0.25)


def button_enabled(text):
    nodes = list(flatten(layout()))
    label = next(n for n in nodes if n.get('text') == text)
    ancestors = [n for n in nodes if n.get('type') == 'Button' and
                 label['hierarchy'].startswith(n.get('hierarchy', '') + ',')]
    assert ancestors, 'Missing parent button for ' + text
    return max(ancestors, key=lambda n: len(n['hierarchy']))['enabled'] == 'true'


def shot(name):
    # Layout becomes available before the first rendered frame. Allow rendering to settle.
    time.sleep(0.6)
    device_path = '/data/local/tmp/seventh-' + name + '.png'
    destination = shots / (name + '.png')
    for _ in range(6):
        run('shell', 'uitest', 'screenCap', '-p', device_path)
        run('file', 'recv', device_path, str(destination))
        if not args.record:
            return
        from PIL import Image
        with Image.open(destination) as frame:
            if frame.convert('RGB').getbbox() is not None:
                return
        time.sleep(0.5)
    raise AssertionError('Emulator returned only black frames for ' + name)


def passed(name):
    results.append({'test': name, 'result': 'PASS'})
    print('PASS ' + name, flush=True)


def record_screen():
    # Capture at actual wall-clock times, independently of test milestones.
    # This is a low-frame-rate screen recording, not a slideshow of milestone screenshots.
    from PIL import Image
    while not recording_stop.is_set():
        try:
            stamp = time.monotonic()
            run('shell', 'snapshot_display', '-f', '/data/local/tmp/seventh-record.jpeg', '-w', '360', '-h', '777')
            run('file', 'recv', '/data/local/tmp/seventh-record.jpeg', str(scratch / 'record-frame.jpeg'))
            with Image.open(scratch / 'record-frame.jpeg') as frame:
                recorded_frames.append((stamp, frame.convert('RGB').quantize(colors=96)))
        except Exception as error:
            recording_errors.append(str(error))
        recording_stop.wait(0.75)


recorder = None
try:
    run('shell', 'aa', 'force-stop', 'com.lvyang.seventhletter')
    time.sleep(1)
    run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.lvyang.seventhletter')
    wait_text('开始新的调查')
    shot('home')
    if args.record:
        from PIL import Image  # fail early if the optional recording dependency is absent
        recorder = threading.Thread(target=record_screen, daemon=True)
        recorder.start()
    click('开始新的调查')
    nodes = list(flatten(layout()))
    if any(n.get('text') == '开始新调查' for n in nodes):
        click('开始新调查')
    wait_text('灯还亮着')
    passed('主页可新开调查并进入原生叙事页面')
    click('推门，进入旧馆')
    wait_text('空着的第七张桌子')
    wait_text('需要先读到第一封信的署名')
    assert not button_enabled('轻声念出「林知秋」')
    click('轻声念出「林知秋」')
    wait_text('空着的第七张桌子')
    shot('reading-locked')
    passed('未取得第一封信时关键提问锁定')
    click('拆开桌上的信')
    wait_text('写给明天的你')
    wait_text('证据 1 / 13')
    shot('first-letter')
    click('收好信，回到桌边')
    wait_text('轻声念出「林知秋」')
    assert button_enabled('轻声念出「林知秋」')
    passed('获得第一封信后提问解锁')
    click('拆开桌上的信')
    wait_text('写给明天的你')
    wait_text('证据 1 / 13')
    passed('重复调查不会重复增加线索')
    click('证据档案')
    wait_text('第一封信')
    click('第一封信')
    wait_text('收起 −')
    shot('evidence')
    passed('证据档案可展开实际收集到的信件全文')
    run('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
    wait_text('写给明天的你')
    run('shell', 'aa', 'force-stop', 'com.lvyang.seventhletter')
    time.sleep(1)
    run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.lvyang.seventhletter')
    wait_text('继续调查    →')
    click('继续调查    →')
    wait_text('写给明天的你')
    wait_text('证据 1 / 13')
    shot('restored')
    passed('强制结束进程后恢复剧情节点与证据')
    click('按信里的提示寻找合影')
    wait_text('相同的闭馆时间')
    click('翻过那张合影')
    wait_text('第四道影子')
    click('带着合影询问周启明')
    wait_text('他早就知道你的名字')
    click('核对今晚的入馆登记')
    wait_text('尚未发生的登记')
    click('把登记页与合影放在一起')
    wait_text('有人在安排重演')
    click('记录可证实的事实，保留所有证据')
    wait_text('第七个收件人')
    wait_text('证据 4 / 13')
    shot('chapter-end')
    passed('四项证据支持事实推理并到达第一章结尾')
    click('保存')
    wait_text('已手动保存，可放心退出应用')
    passed('手动保存提供明确成功反馈')
    click('调查记录')
    wait_text('从最近一次选择开始，回看你留下的路径。')
    wait_text('记录可证实的事实，保留所有证据')
    shot('journal')
    passed('真实选择写入调查记录')
    run('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
    wait_text('第七个收件人')
    run('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
    wait_text('继续调查    →')
    click('开始新的调查')
    wait_text('保留当前调查')
    shot('restart-confirm')
    click('保留当前调查')
    click('继续调查    →')
    wait_text('第七个收件人')
    passed('取消重开保留原存档')
except Exception as error:
    results.append({'test': 'smoke execution', 'result': 'FAIL', 'error': str(error)})
    raise
finally:
    recording_stop.set()
    if recorder:
        recorder.join(timeout=25)
        if recorded_frames:
            durations = [max(100, round((b[0] - a[0]) * 1000)) for a, b in zip(recorded_frames, recorded_frames[1:])]
            durations.append(1000)
            recorded_frames[0][1].save(root / 'docs' / 'demo.gif', save_all=True,
                append_images=[frame for _, frame in recorded_frames[1:]], duration=durations, loop=0, optimize=True)
            print(f'Recorded {len(recorded_frames)} real frames to docs/demo.gif', flush=True)
    report = {'at': datetime.now(timezone.utc).isoformat(), 'device': 'Huawei_Phone API 17',
              'mechanism': 'hdc + uitest + force-stop/relaunch; native Preferences', 'results': results}
    if args.record:
        report['recording'] = {'frames': len(recorded_frames), 'errors': recording_errors, 'format': 'GIF, low frame rate, real-time captures'}
    (root / 'docs' / 'emulator-smoke.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
