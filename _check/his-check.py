# -*- coding: utf-8 -*-
"""
히즈북스 구조 검사기 (his-check)
----------------------------------
앱 동작은 건드리지 않고, «구조적 구멍»이 될 수 있는 코드 패턴만 찾아 보고합니다.

사용법
    py _check/his-check.py            # 검사 후 보고
    py _check/his-check.py --save     # 지금 상태를 기준선(baseline)으로 저장
    py _check/his-check.py --all      # 기준선 무시하고 전부 나열

기준선(baseline.json)을 저장해 두면, 그다음부터는 «새로 생긴 위반»만 빨간불로 뜹니다.
기존 것을 한꺼번에 고치지 않아도 새 코드부터 깨끗해집니다.
"""
import io, os, re, sys, json, hashlib, subprocess

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
APP = os.path.join(ROOT, 'index.html')
FN = os.path.join(ROOT, 'supabase', 'functions', 'noshow-alert', 'index.ts')
BASE = os.path.join(HERE, 'baseline.json')

SAVE = '--save' in sys.argv
SHOW_ALL = '--all' in sys.argv


def load_payload():
    h = open(APP, encoding='utf-8').read()
    mark = '<script type="__bundler/template">'
    i = h.find(mark)
    if i < 0:
        raise SystemExit('페이로드를 찾지 못했습니다')
    j = i + len(mark)
    while h[j] in ' \n\r\t':
        j += 1
    payload, end = json.JSONDecoder().raw_decode(h, j)
    return h, payload, h[j:end]


def snippet(s, pos, back=70, fwd=60):
    a = max(0, pos - back)
    return s[a:pos + fwd].replace('\n', ' ')


def fingerprint(prefix, s, pos, span=110):
    """위치가 아니라 «코드 내용»으로 식별 — 다른 곳을 고쳐도 기준선이 흔들리지 않게"""
    a = max(0, pos - span)
    txt = re.sub(r'\s+', ' ', s[a:pos + span])
    return prefix + ':' + hashlib.sha1(txt.encode('utf-8')).hexdigest()[:10]


# 일부러 전체를 읽는 곳 — 검사에서 제외합니다. 새로 넣을 땐 «왜»를 꼭 적으세요.
ALLOW = {
    'homeBdays': '홈 «오늘 생일» 카드는 학원 전체 공유 (원장 지침 2026-07-29) — 담임 스코프 적용 안 함',
    'findByLast4': '키오스크 뒷4자리 매칭은 학원 전체가 대상 (퇴원·접수대기는 자체 제외)',
    'exportAllStudentsCSV': '전체 학생 백업 내보내기 — 전부 포함이 목적',
    '_fixStartGhost': '데이터 수리 규칙 — 전 학생을 훑어야 정확함 (기록과 어긋난 시작일 교정)',
}


def allowed(ctx):
    for k in ALLOW:
        if k in ctx:
            return k
    return None


findings = []   # (rule, severity, key, desc, sample)
exempt = []


def add(rule, sev, key, desc, sample):
    findings.append({'rule': rule, 'sev': sev, 'key': key, 'desc': desc, 'sample': sample})


# ─────────────────────────────────────────────────────────────
def rule_integrity(raw, v, rawpay):
    """R0 · 파일 무결성 — 앱이 통째로 죽는 종류의 사고"""
    bad = []
    esc = re.compile('(?<!' + chr(92) * 2 + ')</script')
    if esc.search(rawpay):
        bad.append('페이로드 안에 이스케이프 안 된 </script — 앱이 통째로 깨집니다')
    vers = set(re.findall(r'v3[0-9]\.[0-9]{3}', raw))
    if len(vers) > 1:
        bad.append('버전 도장이 섞여 있음 ' + ' / '.join(sorted(vers)))
    try:
        m = re.search(r'<script[^>]*data-dc-script[^>]*>([\s\S]*?)</script>', v)
        if m:
            from playwright.sync_api import sync_playwright
            with sync_playwright() as p:
                br = p.chromium.launch()
                pg = br.new_page()
                r = pg.evaluate("(s)=>{try{new Function(s); return 'OK';}catch(e){return String(e);}}",
                                'class DCLogic{}; ' + m.group(1))
                br.close()
            if r != 'OK':
                bad.append('앱 로직 문법 오류 — 화면이 통째로 안 뜹니다: ' + r[:90])
    except Exception:
        pass
    for b in bad:
        add('R0', '높음', 'integrity:' + b[:24], b, '')


def rule_classes(v):
    """R1 · 학생 명단을 정본 함수(visibleClasses/_schedClasses) 없이 직접 읽는 곳"""
    for m in re.finditer(r'(S\.data|data|sd)\.classes\s*\|\|\s*\[\]', v):
        seg = v[m.end():m.end() + 260]
        # 학생을 실제로 훑는 경우만 (단순 반 목록 조회는 제외)
        if not re.search(r'students\s*\|\|\s*\[\]', seg):
            continue
        ctx = snippet(v, m.start(), back=260, fwd=80)
        if 'visibleClasses' in ctx or '_schedClasses' in ctx:
            continue
        why = allowed(ctx)
        if why:
            if why not in [e[0] for e in exempt]:
                exempt.append((why, ALLOW[why]))
            continue
        ctx = snippet(v, m.start())
        add('R1', '중', fingerprint('classes', v, m.start()),
            '학생 명단을 직접 읽음 — 보관함(퇴원생)·담임 스코프·접수대기 제외가 자동 적용되지 않습니다',
            ctx)


def fn_ranges(v, names):
    """지정한 메서드들의 본문 구간 (중괄호 균형)"""
    out = []
    for nm in names:
        for m in re.finditer(re.escape(nm) + r'\s*\(', v):
            i = v.find('{', m.end())
            if i < 0:
                continue
            d, k = 0, i
            while k < len(v) and k < i + 4000:
                if v[k] == '{':
                    d += 1
                elif v[k] == '}':
                    d -= 1
                    if d == 0:
                        break
                k += 1
            out.append((i, k))
    return out


def rule_schedule(v):
    """R2 · 시간표를 정본 함수(_classStart/_classEnd) 없이 직접 읽는 곳"""
    safe = fn_ranges(v, ['_classStart', '_classEnd', '_sessOv', 'classStart', 'classEnd'])

    def inside(p):
        return any(a <= p <= b for a, b in safe)

    for pat, why in [(r'\bsc\.days\b', 'schedule.days 직접 읽기'),
                     (r'\.times\[', 'schedule.times 직접 읽기'),
                     (r'schedule\[\s*[wW]', 'schedule[요일번호] 직접 읽기')]:
        for m in re.finditer(pat, v):
            if inside(m.start()):
                continue
            after = v[m.end():m.end() + 60]
            before = v[max(0, m.start() - 40):m.start()]
            # 저장(쓰기) 경로는 대상이 아님 — 읽어서 화면에 쓰는 곳만 문제
            if re.match(r'^\s*(\[[^\]]{0,40}\])?\s*=[^=]', after):
                continue
            if 'if (!' in before or 'if(!' in before:
                continue
            add('R2', '중', fingerprint('sched', v, m.start()),
                why + ' — 구형식·보강/휴강 오버레이가 반영되지 않아 화면마다 시간이 다르게 보일 수 있습니다',
                snippet(v, m.start()))


def rule_merge(v):
    """R3 · 저장은 하는데 기기 간 «합치기»(merge)에 빠진 데이터"""
    i = v.find('function mergeAppData')
    if i < 0:
        return
    k = v.find('catch-all', i)
    mg = v[i:i + 16000]
    keys = set()
    for m in re.finditer(r'\bdd\.([A-Za-z][A-Za-z0-9]{2,})\s*(?:\[|=\s*(?!=)|\.push)', v):
        keys.add(m.group(1))
    skip = {'classes', 'students', 'data'}
    for kk in sorted(keys):
        if kk in skip:
            continue
        if kk not in mg:
            add('R3', '중', 'merge:' + kk,
                '«%s» 데이터가 기기 간 합치기 규칙에 없습니다 — 두 기기가 동시에 쓰면 한쪽이 통째로 사라질 수 있습니다' % kk,
                '')


def rule_dup_markup(v):
    """R4 · 복제된 화면 블록이 서로 어긋났는지 (블록의 시작·끝을 잡아 비교)"""
    anchors = [('{{ board.total }}', '{{ board.outCount }}', '학생관리 KPI'),
               ('{{ st.onCounselNote }}', '>저장<', '상담 입력'),
               ('{{ st.counselTimeline }}', '</sc-for>', '상담 이력'),
               ('{{ schedMonthCal.dayNames }}', '</sc-for>', '월간 캘린더')]
    for a, endmark, lab in anchors:
        pos = [m.start() for m in re.finditer(re.escape(a), v)]
        if len(pos) < 2:
            continue
        blocks = []
        for p in pos:
            e = v.find(endmark, p)
            if e < 0:
                e = p + 1500
            blocks.append(v[p:e + len(endmark)])
        if len(set(blocks)) > 1:
            add('R4', '중', 'dup:' + lab,
                '«%s» 화면이 %d벌 복제돼 있는데 서로 내용이 다릅니다 — 화면마다 다르게 보입니다' % (lab, len(pos)),
                '')


def rule_binding(v):
    """R5 · 프레임워크 함정 — 버튼이 조용히 먹통이 되는 패턴"""
    for m in re.finditer(r'on[a-z]+=\\?"\{\{\s*\(', v):
        add('R5', '높음', fingerprint('bind', v, m.start()),
            'onclick에 인라인 화살표함수 — 이 버튼은 눌러도 아무 일이 없습니다(핸들러 참조를 쓰세요)',
            snippet(v, m.start()))
    for m in re.finditer(r'<img[^>]{0,120}src=\\?"\{\{', v):
        add('R5', '중', fingerprint('img', v, m.start()),
            'img src에 값 보간 — 부팅 때 404가 나고 진단 배너가 뜹니다(data-속성+배경주입 패턴을 쓰세요)',
            snippet(v, m.start()))


def rule_server(v):
    """R6 · 앱 밖(알림톡 서버)에 같은 규칙이 복사돼 있는지"""
    if not os.path.exists(FN):
        return
    ts = open(FN, encoding='utf-8').read()
    checks = [('notStarted', '등원 시작 전 학생 제외'),
              ('closedOn', '휴원일 제외'),
              ('noShowExcused', '결석 예정 제외'),
              ('withdrawn', '퇴원생 제외'),
              ('sessOv', '휴강·보강 반영'),
              ('hasMakeup', '개인 보강 제외'),
              ('alertBlock', '앱이 미리 뺀 명부 반영')]
    for tok, lab in checks:
        if tok not in ts:
            add('R6', '높음', 'server:' + tok,
                '알림톡 서버에 «%s» 규칙이 없습니다 — 앱에서만 막혀 있고 실제 발송은 나갑니다' % lab, '')
    try:
        a = subprocess.run(['git', 'log', '-1', '--format=%ct', '--', 'index.html'],
                           cwd=ROOT, capture_output=True, text=True).stdout.strip()
        b = subprocess.run(['git', 'log', '-1', '--format=%ct', '--',
                            'supabase/functions/noshow-alert/index.ts'],
                           cwd=ROOT, capture_output=True, text=True).stdout.strip()
        if a and b and int(a) - int(b) > 14 * 86400:
            days = (int(a) - int(b)) // 86400
            add('R6', '중', 'server:stale',
                '알림톡 서버 코드가 앱보다 %d일 뒤처져 있습니다 — 그동안 바뀐 규칙이 서버엔 없을 수 있습니다' % days, '')
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────
RULES = {
    'R0': '파일 무결성',
    'R1': '학생 명단 직접 읽기',
    'R2': '시간표 직접 읽기',
    'R3': '기기 간 합치기 누락',
    'R4': '복제 화면 불일치',
    'R5': '프레임워크 함정',
    'R6': '앱 밖 서버 규칙',
}


def main():
    raw, v, rawpay = load_payload()
    rule_integrity(raw, v, rawpay)
    rule_classes(v)
    rule_schedule(v)
    rule_merge(v)
    rule_dup_markup(v)
    rule_binding(v)
    rule_server(v)

    cur = {}
    for f in findings:
        cur.setdefault(f['rule'], []).append(f['key'])

    old = {}
    if os.path.exists(BASE):
        try:
            old = json.load(open(BASE, encoding='utf-8'))
        except Exception:
            old = {}

    print('=' * 62)
    print(' 히즈북스 구조 검사 결과')
    print('=' * 62)
    total_new = 0
    for r in sorted(RULES):
        got = cur.get(r, [])
        was = set(old.get(r, []))
        new = [k for k in got if k not in was]
        fixed = [k for k in was if k not in got]
        if not got and not fixed:
            print('  [%s] %-16s 이상 없음' % (r, RULES[r]))
            continue
        flag = '새로 %d건' % len(new) if new else '유지'
        print('  [%s] %-16s %3d건  (%s%s)' % (
            r, RULES[r], len(got), flag,
            (' · 해결 %d건' % len(fixed)) if fixed else ''))
        total_new += len(new)

        show = [f for f in findings if f['rule'] == r and (SHOW_ALL or f['key'] in new or not old)]
        for f in show[:12]:
            print('       - ' + f['desc'])
            if f['sample']:
                print('         ' + f['sample'][:130])
        if len(show) > 12:
            print('       … 외 %d건 (--all 로 전체 보기)' % (len(show) - 12))
    if exempt:
        print('  [예외] 일부러 전체를 읽는 곳 %d곳' % len(exempt))
        for k, why in exempt:
            print('       · %s — %s' % (k, why))
    print('-' * 62)
    if old:
        print('  기준선 대비 새로 생긴 위반: %d건' % total_new)
        if total_new == 0:
            print('  통과 — 새 코드는 깨끗합니다.')
    else:
        print('  기준선이 없습니다. --save 로 지금 상태를 기준선으로 저장하세요.')

    if SAVE:
        json.dump(cur, open(BASE, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print('  기준선 저장됨: _check/baseline.json')
    return 1 if (old and total_new) else 0


if __name__ == '__main__':
    sys.exit(main())
