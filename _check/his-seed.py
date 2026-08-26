# -*- coding: utf-8 -*-
"""
히즈북스 경계 상태 회귀 도구 (his-seed)
----------------------------------------
사고는 늘 «경계 상태»에서 납니다 — 등원 시작 전 / 접수 대기 / 퇴원 / 반 삭제 /
결석 예정 / 휴원일 / 휴강 / 보강 / 퇴원 예정.

이 도구는 그 아홉 가지를 **한 벌의 표준 데이터**로 만들어 앱에 넣고,
주요 화면을 전부 돌면서 «이건 반드시 이래야 한다»를 자동으로 확인합니다.

사용법
    py _check/his-seed.py              # 전체 검사
    py _check/his-seed.py --shots      # 화면 스크린샷도 저장 (_check/shots/)

화면을 고친 뒤 이걸 돌려서 «전부 통과»가 나오면, 경계 상태는 안 깨진 것입니다.
"""
import io, os, sys, json, threading, functools, http.server, socketserver

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SHOTS = os.path.join(HERE, 'shots')
WANT_SHOTS = '--shots' in sys.argv
PORT = 9391

try:
    from playwright.sync_api import sync_playwright
except Exception:
    raise SystemExit('playwright 가 필요합니다:  py -m pip install playwright  &&  py -m playwright install chromium')


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


FIBER = '''() => { const seen=new Set();
  const walk=(n,d)=>{ if(!n||d>500||seen.has(n))return null; seen.add(n);
    const s=n.stateNode; if(s&&s.constructor&&s.constructor.name==="StreamableComponent"&&s.logic)return s.logic;
    return walk(n.child,d+1)||walk(n.sibling,d+1); };
  for(const el of document.querySelectorAll("*")){ const k=Object.keys(el).find(x=>x.startsWith("__reactFiber")); if(!k)continue;
    let f=el[k]; while(f.return)f=f.return; const L=walk(f,0); if(L){window.__L=L;return true;} } return false; }'''

# ── 표준 시드 ─────────────────────────────────────────────────────────
# 날짜는 모두 «오늘»에서 계산 — 시간이 지나도 낡지 않습니다.
SEED = """(closed)=>{
  const L=window.__L; const td=L.today(); const w=L._weekday(td);
  const KD=['일','월','화','수','목','금','토'];
  const shift=(n)=>{const p=td.split('.').map(Number); const t=new Date(p[0],p[1]-1,p[2]); t.setDate(t.getDate()+n);
    return t.getFullYear()+'.'+String(t.getMonth()+1).padStart(2,'0')+'.'+String(t.getDate()).padStart(2,'0');};
  const sch=(s,e)=>({days:[KD[w]], times:{[KD[w]]:{start:s,end:e}}, start:s, end:e});
  const nowM=(new Date()).getHours()*60+(new Date()).getMinutes();
  const hm=(m)=>{m=((m%1440)+1440)%1440; return String(Math.floor(m/60)).padStart(2,'0')+':'+String(m%60).padStart(2,'0');};
  const NOW_S=hm(nowM-60), NOW_E=hm(Math.min(nowM+60,1438));        // 지금이 수업 중 = 미등원 판정이 살아 있음
  let _ls=nowM+180, _le=nowM+270;                    // 아직 시작 전 — 자정을 넘기면 안 됨(넘기면 «새벽=이미 지남»으로 오판)
  if(_le>1435){ _ls=Math.min(nowM+10,1420); _le=Math.min(nowM+30,1435); }
  const LATER_S=hm(_ls), LATER_E=hm(_le);
  const d=JSON.parse(JSON.stringify(L.state.data));
  d.staff={}; d.notices={}; d.reports=[]; d.records=[]; d.exams=[]; d.monthlyComments={};
  d.checkins={}; d.noShowExcused={}; d.sessions={}; d.mkup={}; d.closedDays={};
  d.leftStudents=[]; d.deletedStudents=[]; d.counsels=[]; d.alertBlock={};

  const S=(id,nm,extra)=>Object.assign({id:id,name:nm,registeredAt:'2025.03.02',
    intake:{parentContact:'010-0000-'+id.slice(1).padStart(4,'0')}}, extra||{});

  d.classes=[
    {id:'C1',name:'경계 A반',owner:'관리자',schedule:sch(NOW_S,NOW_E),students:[
      S('s1','정상재원'),
      S('s2','미등원'),
      S('s3','시작전', {startPlan: shift(6)}),
      S('s4','접수대기', {pending:true}),
      S('s5','결석예정'),
      S('s6','퇴원', {withdrawn:true, withdrawnAt: td, withdrawReason:'이사'}),
      S('s7','퇴원예정', {withdrawPlanned:{date: shift(9), reason:'전학'}}),
      S('s8','개인보강'),
      S('s13','원장반생일', {intake:{parentContact:'010-0000-0013', birth: ('2011.'+td.split('.')[1]+'.'+td.split('.')[2])}})
    ]},
    {id:'C2',name:'경계 B반(휴강)',owner:'관리자',schedule:sch(NOW_S,NOW_E),students:[ S('s9','휴강반학생') ]},
    {id:'C3',name:'경계 C반(보강이동)',owner:'관리자',schedule:sch(LATER_S,LATER_E),students:[ S('s10','보강반학생') ]},
    {id:'C4',name:'경계 D반(남의반)',owner:'다른쌤',schedule:sch(NOW_S,NOW_E),students:[
      S('s12','남의반생일', {intake:{parentContact:'010-0000-0012', birth: ('2012.'+td.split('.')[1]+'.'+td.split('.')[2])}}) ]}
  ];

  d.checkins['s1|'+td]={in:NOW_S, t:Date.now()};
  d.checkins['s13|'+td]={in:NOW_S, t:Date.now()};
  d.noShowExcused['s5|'+td]={reason:'병원', t:Date.now()};
  d.sessions['C2|'+td]={off:1, to: shift(3), t:Date.now()};
  d.sessions['C3|'+td]={start:LATER_S, end:LATER_E, from: shift(-7), t:Date.now()};
  d.mkup['s8|'+td]={cid:'C1', start:LATER_S, end:LATER_E, from: td, t:Date.now()};

  d.leftStudents=[{id:'s11', name:'반삭제퇴원', cls:'사라진 반', owner:'관리자',
    registeredAt:'2025.03.02', withdrawnAt: td, reason:'반 해체', leftAt: td}];

  d.counsels=[{id:'k1', studentId:'s1', date: shift(-3), note:'정상 상담', who:'student', by:'관리자'},
              {id:'k2', studentId:'s13', date: shift(-3), note:'정상 상담', who:'student', by:'관리자'}];

  if(closed) d.closedDays[td]={v:1, t:Date.now()};

  L.setState({data:d, currentUser:'관리자', schedTeacher:'', activeClassId:'C1',
    boardFilter:'all', view:'home'});
  L.persist(d);
  try{ L._writeAlertBlock(d, td); L.persist(d); }catch(e){}
  const g=document.getElementById('cloud-gate'); if(g)g.remove();
  try{localStorage.setItem('his-fix932','1');}catch(e){}
  return {today:td, block:((d.alertBlock||{})[td]||{}), nearMid:(nowM>1400||nowM<300)};
}"""

TXT = "()=>document.body.innerText"

# ── 화면 목록 ─────────────────────────────────────────────────────────
SCREENS = [
    ('오늘',            {'view': 'home'}),
    ('학생관리(선생님)',  {'view': 'schedule', 'scheduleSeg': 'stu', 'schedTop': 'board'}),
    ('일정(선생님)',     {'view': 'schedule', 'scheduleSeg': 'stu', 'schedTop': 'cal'}),
    ('등하원 관제',      {'view': 'admin', 'adminSeg': 'checkin'}),
    ('학생관리(학원)',    {'view': 'admin', 'adminSeg': 'student'}),
    ('한눈에',          {'view': 'admin', 'adminSeg': 'overview'}),
    ('데이터·퇴원생',    {'view': 'admin', 'adminSeg': 'data'}),
]

# ── 반드시 지켜져야 하는 것 ────────────────────────────────────────────
#   (화면, 설명, 판정식)   판정식은 true 면 통과
RULES = [
    ('학생관리(학원)', '접수대기 학생은 반 명단에 없음 (접수 대기 패널에만)',
     "()=>{const t=document.body.innerText; const i=t.indexOf('반별 일정'); return i>=0 && t.slice(i).indexOf('접수대기')<0;}"),
    ('학생관리(학원)', '전체 원생 10명 (접수대기·퇴원 제외 / 시작 전·퇴원 예정은 포함)',
     "()=>/전체 원생\s*10명/.test(document.body.innerText)"),
    ('학생관리(학원)', '이번 달 퇴원 2명 (반 안 1 + 반 삭제 보관함 1)',
     "()=>/이번 달 퇴원\s*2명/.test(document.body.innerText)"),
    ('학생관리(학원)', '퇴원 예정 1명',
     "()=>/퇴원 예정\s*1명/.test(document.body.innerText)"),
    ('학생관리(학원)', '퇴원 예정 배지가 명단에 보임',
     "()=>/퇴원 예정 [0-9]+\/[0-9]+/.test(document.body.innerText)"),
    ('학생관리(학원)', '8주+ 미상담 8명 (상담 있는 1명만 제외)',
     "()=>/8주\+ 미상담\s*8명/.test(document.body.innerText)"),

    ('등하원 관제', '관제판에 휴강 반이 없음',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 등하원 관제'); const j=t.indexOf('오늘 등하원 현황');"
     " return i>=0 && j>i && t.slice(i,j).indexOf('휴강반학생')<0;}"),
    ('등하원 관제', '관제판에 등원 시작 전 학생이 없음',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 등하원 관제'); const j=t.indexOf('오늘 등하원 현황');"
     " return i>=0 && j>i && t.slice(i,j).indexOf('시작전')<0;}"),
    ('등하원 관제', '관제판에 퇴원생이 없음',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 등하원 관제'); const j=t.indexOf('오늘 등하원 현황');"
     " return i>=0 && j>i && !/(^|[^예])퇴원(?!예정)/.test(t.slice(i,j).split('퇴원예정').join(''));}"),
    ('등하원 관제', '개인 보강 학생은 «보강 예정»으로 표시 (미등원 아님)',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 등하원 관제'); const j=t.indexOf('오늘 등하원 현황');"
     " return i>=0 && t.slice(i,j).indexOf('보강 예정')>=0;}"),
    ('등하원 관제', '미등원 3명 (결석 예정·개인 보강·시작 전·퇴원 제외)',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 수업 대상');"
     " return i>=0 && /미등원\s*3/.test(t.slice(i,i+120));}"),
    ('등하원 관제', '안전망 목록에 개인 보강 학생이 없음',
     "()=>{const t=document.body.innerText; const i=t.indexOf('미등원 확인');"
     " return i<0 || t.slice(i,i+500).indexOf('개인보강')<0;}"),
    ('등하원 관제', '결석 예정 학생은 미등원으로 안 셈 (수업 시작 후엔 «결석 · 사유»)',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 등하원 관제'); const j=t.indexOf('오늘 등하원 현황');"
     " return i>=0 && t.slice(i,j).indexOf('결석 · 병원')>=0;}"),

    ('일정(선생님)', '주간 일정 명단에 등원 시작 전 학생이 없음',
     "()=>{const t=document.body.innerText; const i=t.indexOf('주간 일정'); const j=t.indexOf('월간 일정');"
     " return i>=0 && j>i && t.slice(i,j).indexOf('시작전')<0;}"),
    ('일정(선생님)', '휴강 블록은 취소선 · 설명 글자는 그리드에 안 넣음',
     "()=>{const sp=[...document.querySelectorAll('span')].filter(e=>getComputedStyle(e).textDecorationLine==='line-through');"
     " const t=document.body.innerText; const i=t.indexOf('주간 일정'); const j=t.indexOf('월간 일정');"
     " return sp.length>0 && i>=0 && t.slice(i,j).indexOf('로 이동')<0;}"),
    ('일정(선생님)', '보강으로 옮겨간 수업이 «보강»으로 표시됨',
     "()=>{const t=document.body.innerText; const i=t.indexOf('주간 일정'); const j=t.indexOf('월간 일정');"
     " return i>=0 && t.slice(i,j).indexOf('보강')>=0;}"),
    ('일정(선생님)', '개인 보강 학생 칩이 보임',
     "()=>{const t=document.body.innerText; const i=t.indexOf('주간 일정'); const j=t.indexOf('월간 일정');"
     " return i>=0 && t.slice(i,j).indexOf('개인보강')>=0;}"),
    ('일정(선생님)', '주간 헤더에 «휴강 N · 보강 N» 요약',
     "()=>/이번 주 휴강 [0-9]+ · 보강 [0-9]+/.test(document.body.innerText)"),
    ('일정(선생님)', '주간 일정 명단에 퇴원생이 없음',
     "()=>{const t=document.body.innerText; const i=t.indexOf('주간 일정'); const j=t.indexOf('월간 일정');"
     " return i>=0 && j>i && t.slice(i,j).split('퇴원예정').join('').indexOf('퇴원')<0;}"),
    ('오늘', '원장은 남의 반 학생 생일도 보임',
     "()=>document.body.innerText.indexOf('남의반생일')>=0"),
    ('오늘', '휴강 반이 «휴강»으로 표시됨',
     "()=>{const t=document.body.innerText; return t.indexOf('경계 B반')<0 || t.indexOf('휴강')>=0;}"),
]

CLOSED_RULES = [
    ('등하원 관제', '휴원일이면 «오늘은 휴원일» 안내가 뜸',
     "()=>document.body.innerText.indexOf('휴원일')>=0"),
    ('등하원 관제', '휴원일이면 미등원 0명',
     "()=>{const t=document.body.innerText; const i=t.indexOf('오늘 수업 대상');"
     " return i<0 || /미등원\s*0/.test(t.slice(i,i+120));}"),
]

# 아직 안 고친 것 — 실패로 세지 않고 «알려진 문제»로만 알립니다.
KNOWN = []

BLOCK_EXPECT = ['s3', 's4', 's6', 's8', 's9']   # 시작전·접수대기·퇴원·개인보강·휴강반


def run():
    Handler = functools.partial(Quiet, directory=ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    srv = socketserver.TCPServer(('127.0.0.1', PORT), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    if WANT_SHOTS and not os.path.isdir(SHOTS):
        os.makedirs(SHOTS)

    fails, warns, checked = [], [], 0
    with sync_playwright() as p:
        b = p.chromium.launch(args=['--disable-audio-output'])
        pg = b.new_page(viewport={'width': 1500, 'height': 1100})
        errs, bad = [], []
        pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.on('response', lambda r: bad.append(r.url) if r.status >= 400 else None)
        pg.goto('http://127.0.0.1:%d/index.html' % PORT, wait_until='networkidle')
        pg.wait_for_timeout(2400)
        for _ in range(10):
            if pg.evaluate(FIBER) and pg.evaluate("()=>!!(window.__L.state&&window.__L.state.data)"):
                break
            pg.wait_for_timeout(600)
        ver = pg.evaluate("()=>{const m=document.body.innerText.match(/v3[0-9][.][0-9]+/);return m?m[0]:'?'}")
        print('=' * 62)
        print(' 히즈북스 경계 상태 회귀 검사   (앱 %s)' % ver)
        print('=' * 62)

        for closed, rules, tag in [(False, RULES, '평상시'), (True, CLOSED_RULES, '휴원일')]:
            info = pg.evaluate(SEED, closed)
            pg.wait_for_timeout(2200)
            print()
            print('── %s ── (기준일 %s)' % (tag, info['today']))
            if not closed:
                got = sorted((info.get('block') or {}).get('sids') or [])
                ok = (got == sorted(BLOCK_EXPECT))
                checked += 1
                mark = 'OK ' if ok else '실패'
                if not ok:
                    fails.append('알림 제외 명부: %s (기대 %s)' % (got, sorted(BLOCK_EXPECT)))
                print('  %s 알림 제외 명부 = %s' % (mark, got))

            for name, state in SCREENS:
                pg.evaluate("(s)=>window.__L.setState(s)", state)
                pg.wait_for_timeout(1500)
                txt = pg.evaluate(TXT)
                blank = (len(txt.strip()) < 40)
                checked += 1
                if blank:
                    fails.append('%s 화면이 비어 있음' % name)
                    print('  실패 %-14s 화면이 비어 있음' % name)
                else:
                    print('  OK  %-14s (%d자)' % (name, len(txt)))
                if WANT_SHOTS:
                    fn = ('closed_' if closed else '') + name.replace('·', '_').replace('(', '_').replace(')', '')
                    pg.screenshot(path=os.path.join(SHOTS, fn + '.png'))

                for rn, desc, expr in (KNOWN if not closed else []):
                    if rn != name:
                        continue
                    try:
                        good = bool(pg.evaluate(expr))
                    except Exception:
                        good = False
                    if not good:
                        warns.append('%s · %s' % (name, desc))
                        print('       주의 ' + desc)

                _skipMid = {'개인 보강 학생은 «보강 예정»으로 표시 (미등원 아님)',
                            '미등원 3명 (결석 예정·개인 보강·시작 전·퇴원 제외)',
                            '안전망 목록에 개인 보강 학생이 없음',
                            '결석 예정 학생은 미등원으로 안 셈 (수업 시작 후엔 «결석 · 사유»)',
                            '관제판에 휴강 반이 없음',
                            '관제판에 등원 시작 전 학생이 없음',
                            '관제판에 퇴원생이 없음'}
                for rn, desc, expr in rules:
                    if rn != name:
                        continue
                    if info.get('nearMid') and desc in _skipMid:
                        print('       주의 ' + desc + ' — 자정 인접이라 «오늘 미래 수업» 시드 불가, 검사 생략')
                        continue
                    checked += 1
                    try:
                        good = bool(pg.evaluate(expr))
                    except Exception as e:
                        good = False
                        desc += ' (판정 오류 %s)' % e
                    if good:
                        print('       OK  ' + desc)
                    else:
                        fails.append('%s · %s' % (name, desc))
                        print('       실패 ' + desc)

        # 휴강 말풍선 — 눌러야 상세가 뜨는지
        pg.evaluate("(s)=>window.__L.setState(s)", {'view': 'schedule', 'scheduleSeg': 'stu', 'schedTop': 'cal'})
        pg.wait_for_timeout(1500)
        clicked = pg.evaluate("""()=>{const sp=[...document.querySelectorAll('span')].filter(e=>getComputedStyle(e).textDecorationLine==='line-through')[0];
          if(!sp) return false; let n=sp; while(n && !(n.getAttribute&&(n.getAttribute('style')||'').indexOf('border-left')>=0)) n=n.parentElement;
          if(!n) return false; n.click(); return true;}""")
        pg.wait_for_timeout(1400)
        t3 = pg.evaluate(TXT)
        print()
        print('── 휴강 말풍선 ──')
        for desc, ok in [
            ('휴강 블록을 누를 수 있음', clicked),
            ('말풍선에 원래 수업·보강 일자가 뜸', ('원래 수업' in t3) and ('보강' in t3)),
            ('말풍선에 되돌리기 버튼이 있음', '원래대로 되돌리기' in t3),
        ]:
            checked += 1
            if ok:
                print('  OK  ' + desc)
            else:
                fails.append('휴강 말풍선 · ' + desc)
                print('  실패 ' + desc)

        # 담임 스코프 — 선생님은 자기 반만 보여야
        pg.evaluate(SEED, False)
        pg.wait_for_timeout(2000)
        pg.evaluate("()=>window.__L.setState({currentUser:'다른쌤', view:'home'})")
        pg.wait_for_timeout(1800)
        t2 = pg.evaluate(TXT)
        print()
        print('── 담임 스코프 (다른쌤으로 로그인) ──')
        for desc, ok in [
            ('생일 카드는 학원 전체 공유 — 원장 반 학생 생일도 보임', t2.find('원장반생일') >= 0),
            ('자기 반 학생 생일도 보임', t2.find('남의반생일') >= 0),
            ('남의 반 수업 목록은 안 보임 (정상재원)', t2.find('정상재원') < 0),
        ]:
            checked += 1
            if ok:
                print('  OK  ' + desc)
            else:
                fails.append('담임 스코프 · ' + desc)
                print('  실패 ' + desc)

        checked += 1
        if errs:
            fails.append('자바스크립트 오류 %d건: %s' % (len(errs), errs[0][:90]))
        checked += 1
        real_bad = [u for u in bad if ('favicon' not in u and 'supabase.co' not in u)]  # 클라우드는 테스트에서 로그인이 없어 정상적으로 거부됨
        if real_bad:
            fails.append('불러오기 실패 %d건: %s' % (len(real_bad), real_bad[0][:90]))
        b.close()
    srv.shutdown()

    print()
    print('-' * 62)
    print('  확인 %d항목' % checked)
    if warns:
        print('  알려진 문제 %d건 (실패 아님)' % len(warns))
        for x in warns:
            print('   ~ ' + x)
    if fails:
        print('  실패 %d건' % len(fails))
        for f in fails:
            print('   - ' + f)
        return 1
    print('  전부 통과 — 경계 상태 이상 없습니다.')
    return 0


if __name__ == '__main__':
    sys.exit(run())
