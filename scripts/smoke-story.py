"""Verify the four-chapter native app using hdc/uitest.
The current single autosave is backed up before testing and restored in finally.
Requires Pillow for screenshot validation; only this application's save is touched.
"""
import argparse
import json
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--hdc', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
work = root / 'artifacts' / 'story-smoke'
work.mkdir(parents=True, exist_ok=True)
shots = root / 'docs' / 'screenshots-v02'
shots.mkdir(parents=True, exist_ok=True)
pref = '/data/app/el2/100/base/com.lvyang.seventhletter/haps/entry/preferences/seventh_letter_v1'
backup = work / 'preference-before.xml'
results = []
backed_up = False


def run(*parts):
    process = subprocess.run([args.hdc, *parts], capture_output=True, timeout=25)
    output = process.stdout.decode('utf-8', errors='replace') + process.stderr.decode('utf-8', errors='replace')
    if process.returncode or '[Fail]' in output or 'error:' in output.lower():
        raise RuntimeError(output)
    return output


def flatten(node):
    yield node.get('attributes', {})
    for child in node.get('children', []):
        yield from flatten(child)


def layout():
    run('shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/story-test-layout.json')
    run('file', 'recv', '/data/local/tmp/story-test-layout.json', str(work / 'layout.json'))
    return list(flatten(json.loads((work / 'layout.json').read_text(encoding='utf-8'))))


def wait(value, by='text'):
    for _ in range(18):
        all_nodes = layout()
        matches = [node for node in all_nodes if node.get(by) == value]
        if matches:
            return matches[0]
        time.sleep(.25)
    raise AssertionError('Missing ' + by + ': ' + value + '; texts=' + str([n['text'] for n in all_nodes if n.get('text')]))


def click(value, by='text'):
    # Offscreen ArkUI nodes can expose nonzero bounds; require a visible center.
    previous_bounds = None
    for attempt in range(16):
        node = next((n for n in layout() if n.get(by) == value), None)
        if node is None:
            if attempt < 2:
                run('shell', 'uitest', 'uiInput', 'swipe', '630', '700', '630', '2100', '1400')
            else:
                run('shell', 'uitest', 'uiInput', 'swipe', '630', '1900', '630', '700', '1400')
            time.sleep(.15)
            continue
        bounds = list(map(int, re.findall(r'-?\d+', node.get('bounds', ''))))
        if len(bounds) == 4:
            x = (bounds[0] + bounds[2]) // 2
            y = (bounds[1] + bounds[3]) // 2
            upper_limit = 2620 if value == 'submit-deduction' else 2390
            if bounds[2] > bounds[0] and bounds[3] > bounds[1] and 140 < y < upper_limit:
                run('shell', 'uitest', 'uiInput', 'click', str(x), str(y))
                time.sleep(.25)
                return
        if bounds == previous_bounds and bounds == [0, 0, 0, 0]:
            pass
        previous_bounds = bounds
        upward = len(bounds) == 4 and bounds[1] < 140 and bounds[3] > 0
        coords = ('630', '700', '630', '1850') if upward else ('630', '1850', '630', '700')
        run('shell', 'uitest', 'uiInput', 'swipe', *coords, '1600')
        time.sleep(.15)
    raise AssertionError('Could not scroll target into view: ' + value)


def choice(identifier, title):
    click('choice-' + identifier, 'id')
    wait(title)
    print('STEP ' + identifier, flush=True)


def back():
    run('shell', 'uitest', 'uiInput', 'keyEvent', 'Back')


def passed(name):
    results.append({'test': name, 'result': 'PASS'})
    print('PASS ' + name, flush=True)


def snapshot(name):
    time.sleep(.8)
    remote = '/data/local/tmp/story-test-' + name + '.jpeg'
    for _ in range(6):
        run('shell', 'snapshot_display', '-f', remote)
        run('file', 'recv', remote, str(work / (name + '.jpeg')))
        with Image.open(work / (name + '.jpeg')) as image:
            if image.getbbox():
                image.save(shots / (name + '.png'))
                return
        time.sleep(.5)
    raise AssertionError('Only black frames returned: ' + name)


def disk_state(destination):
    run('file', 'recv', pref, str(destination))
    tree = ET.fromstring(destination.read_bytes())
    node = next(child for child in tree if child.attrib.get('key') == 'autosave')
    return json.loads(node.text)


def check_case(case, evidence, answer):
    click('case-' + case, 'id')
    for clue in evidence:
        click('evidence-' + clue, 'id')
    click('answer-' + answer, 'id')
    click('submit-deduction', 'id')
    for _ in range(12):
        if any(n.get('text', '').startswith('核对成立并已保存。') for n in layout()):
            return
        time.sleep(.25)
    raise AssertionError('Deduction was not saved: ' + case)


try:
    run('shell', 'aa', 'force-stop', 'com.lvyang.seventhletter')
    original = disk_state(backup)
    backed_up = True
    time.sleep(1)
    run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.lvyang.seventhletter')
    wait('继续调查    →')
    click('继续调查    →')
    # Inspect current raw save: loading v1 must not rewrite its disk representation.
    assert disk_state(work / 'load-only.xml') == original
    passed('覆盖安装后可继续原存档，仅读取不覆写旧记录')
    back()
    click('开始新的调查')
    click('开始新调查')
    wait('灯还亮着')
    for identifier, title in [
        ('enter', '空着的第七张桌子'), ('open_letter', '写给明天的你'),
        ('follow_photo', '相同的闭馆时间'), ('turn_photo', '第四道影子'),
        ('ask_photo', '他早就知道你的名字'), ('ask_register', '尚未发生的登记'),
        ('compare_photo', '有人在安排重演'), ('record_facts', '第七个收件人'),
        ('meet_shen', '留过位置的人'), ('to_archive', '三份没有对齐的记录'),
        ('door_docs', '不是第一次卡住'), ('maintenance_back', '三份没有对齐的记录'),
        ('photo_docs', '你一直在画面里'), ('original_back', '三份没有对齐的记录'),
        ('report_docs', '她没有等到第二天')]:
        choice(identifier, title)
    snapshot('aftermath')
    passed('从第一章进入第二章，并在事故通报明确确认林知秋遇难')
    choice('aftermath_back', '三份没有对齐的记录')
    click('证据推理')
    wait('你与三年前的清场有什么关系？')
    # A wrong pair/claim must not silently unlock a conclusion.
    click('evidence-original', 'id'); click('evidence-photo', 'id')
    click('answer-volunteer', 'id'); click('submit-deduction', 'id')
    wait('这两份材料还不足以相互印证。请重读来源，再换一组证据。')
    assert 'identity' not in disk_state(work / 'wrong-pair.xml')['flags']
    click('case-cause', 'id')
    check_case('identity', ['original', 'clearance'], 'volunteer')
    check_case('cause', ['letter2', 'incident'], 'fault')
    snapshot('deduction')
    passed('错误组合不解锁；身份与事故原因可用正确组合核对')
    back(); wait('三份没有对齐的记录')
    choice('confront_shen', '她安排了多少')
    choice('to_apology', '没有邮票的道歉')
    choice('read_self', '你从来没有忘干净')
    snapshot('sixth-letter')
    choice('to_writing', '现在轮到你写')
    assert len(disk_state(work / 'six-letters.xml')['evidenceIds']) == 13
    passed('六封信和十三项证据收集齐全，第三章接入写信阶段')
    click('证据推理')
    check_case('witness', ['letter6', 'recording'], 'unchecked')
    snapshot('witness')
    back(); wait('现在轮到你写')
    # The flag is only useful if it survives actual process termination.
    before = disk_state(work / 'before-stop.xml')
    run('shell', 'aa', 'force-stop', 'com.lvyang.seventhletter'); time.sleep(1)
    run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.lvyang.seventhletter')
    wait('继续调查    →'); click('继续调查    →'); wait('现在轮到你写')
    assert disk_state(work / 'after-stop.xml') == before
    passed('强制结束后恢复后续章节、六封信和三项推理')
    choice('sign_letter', '把名字写完整')
    snapshot('signed-draft')
    choice('cancel_seventh', '现在轮到你写')
    assert not disk_state(work / 'cancel.xml')['endingIds']
    passed('最终署名前可以取消，不提前解锁结局')
    for enter, confirm, title, replay in [
        ('sign_letter', 'seal_seventh', '第七封信', 'reconsider_seventh'),
        ('return_papers', 'seal_return', '归还', 'reconsider_return'),
        ('keep_draft', 'seal_unsent', '未寄出', 'reconsider_unsent'),
        ('deny_papers', 'seal_blank', '空白收件人', 'reconsider_blank')]:
        click('choice-' + enter, 'id')
        click('choice-' + confirm, 'id'); wait(title)
        snapshot(title)
        click('choice-' + replay, 'id'); wait('现在轮到你写')
        passed('真实到达结局：' + title)
    click('结局图鉴'); wait('已收录 4 / 4'); snapshot('gallery')
    click('ending-seventh', 'id'); wait('收起结尾')
    passed('图鉴收录四个结局且可回看正文')
    back(); wait('现在轮到你写')
    back(); wait('开始新的调查')
    click('开始新的调查'); click('开始新调查'); wait('灯还亮着')
    fresh = disk_state(work / 'restart.xml')
    assert fresh['nodeId'] == 'arrival' and not fresh['history'] and not fresh['evidenceIds'] and len(fresh['endingIds']) == 4
    passed('新调查清空进度但保留四个结局')
except Exception as error:
    results.append({'test': 'native story smoke', 'result': 'FAIL', 'error': str(error)})
    raise
finally:
    restored = False
    if backed_up:
        run('shell', 'aa', 'force-stop', 'com.lvyang.seventhletter')
        run('file', 'send', str(backup), pref)
        disk_state(work / 'restored-original.xml')
        restored = backup.read_bytes() == (work / 'restored-original.xml').read_bytes()
        print('Restored pre-test autosave:', restored, flush=True)
        run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.lvyang.seventhletter')
    report = {'at': datetime.now(timezone.utc).isoformat(), 'version': '0.2.0',
              'mechanism': 'native hdc/uitest, real Preferences, force-stop and relaunch',
              'originalAutosaveRestored': restored, 'results': results}
    (root / 'docs' / 'emulator-story-v02.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
