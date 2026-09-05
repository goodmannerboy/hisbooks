# -*- coding: utf-8 -*-
"""
히즈북스 일간일지 «이전 과제 확인» 검사 (his-homework)
--------------------------------------------------------
과제 확인은 학부모 카드에 «○ △ ✕» 로 그대로 나갑니다.
안 해온 과제가 «완료»로 나가거나, 선생님이 매긴 표시가 사라지면 바로 신뢰를 잃습니다.
이 검사는 index.html 의 실제 코드로 그 두 가지를 확인합니다.

    py _check/his-homework.py

하나라도 실패하면 배포하지 마세요.
"""
import io, os, sys, threading, functools, http.server, socketserver

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

try:
    from playwright.sync_api import sync_playwright
except Exception:
    raise SystemExit('playwright 가 필요합니다:  py -m pip install playwright')


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


FIBER = '''() => { const seen=new Set();
  const walk=(n,d)=>{ if(!n||d>500||seen.has(n))return null; seen.add(n);
    const s=n.stateNode; if(s&&s.constructor&&s.constructor.name==="StreamableComponent"&&s.logic&&s.logic.state&&s.logic.state.data)return s.logic;
    return walk(n.child,d+1)||walk(n.sibling,d+1); };
  for(const el of document.querySelectorAll("*")){ const k=Object.keys(el).find(x=>x.startsWith("__reactFiber")); if(!k)continue;
    let f=el[k]; while(f.return)f=f.return; const L=walk(f,0); if(L){window.__L=L;return true;} } return false; }'''

# 직전 회차 과제 3줄. «단어 50개 암기»는 시험으로 확인하는 항목이라 걸러져야 한다.
NL2 = chr(92) + 'n'
PREP = ('1. 오답노트 정리' + NL2 + '2. 교재 p.88~91 문제 풀기' + NL2
        + '3. 주요구문 필기 정리' + NL2 + '4. Unit 12 단어 50개 암기')

SEED = ("""()=>{const L=window.__L;
  const d=JSON.parse(JSON.stringify(L.state.data)); d.staff={};
  d.classes=[{id:'C1',name:'고2 A반',owner:'관리자',schedule:{days:[],times:{}},students:[
    {id:'s1',name:'김민준',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-03-14'}},
    {id:'s2',name:'이지혜',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-07-22'}},
    {id:'s3',name:'박서준',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-09-09'}}]}];
  d.records=[
   {id:'r1',classId:'C1',studentId:'s1',date:'2026.08.27',attendance:'출석',homework:'완료',
    gS:'70',gT:'100',lesson:'Unit 11',nextPrep:'%PREP%'},
   {id:'r2',classId:'C1',studentId:'s2',date:'2026.08.27',attendance:'출석',homework:'완료',
    gS:'70',gT:'100',lesson:'Unit 11',nextPrep:'%PREP%'},
   {id:'r3',classId:'C1',studentId:'s3',date:'2026.08.27',attendance:'출석',homework:'완료',
    gS:'70',gT:'100',lesson:'Unit 11',nextPrep:'%PREP%'}];
  d.exams=[]; d.checkins={}; d.counsels=[]; d.reports=[];
  d.examSchool={}; d.examSchoolG={}; d.suneung={};
  L.persist(d);
  try{localStorage.setItem('his-fix932','1');}catch(e){}
  return 'ok';}""").replace('%PREP%', PREP)

TXT = lambda a: [((x.get('text') or '') + ':' + (x.get('status') or '')) for x in a]

LOGIC = """()=>{const L=window.__L; const dt=L.state.bulk.date; const out={};
  const draft=(sid)=>L.loadDraft(L.state.data,'C1',sid,dt);

  // ① 기록 없는 날 — 열자마자 채워져 있어야 한다
  out.fresh = draft('s1').hwCheck || null;

  // ② 결석이면 자동으로 채우지 않는다
  const dAbs = Object.assign({}, draft('s1'), {attendance:'결석', hwCheck:undefined});
  out.absent = L._autoHwCheck(L.state.data,'C1','s1',dt,dAbs);

  // ③ 손으로 매긴 표시를 저장 → 다시 열어도 유지 → 다시 저장해도 안 덮인다
  L.setBulk('s2','attendance','출석');
  L.setBulk('s2','hwCheck',[{text:'오답노트 정리',status:'완료'},
    {text:'교재 p.88~91 문제 풀기',status:'미완'},{text:'주요구문 필기 정리',status:'일부'}]);
  return out;}"""

AFTER = """()=>{const L=window.__L; const dt=L.state.bulk.date; const out={};
  out.reopened = L.loadDraft(L.state.data,'C1','s2',dt).hwCheck || null;
  const r=(L.state.data.records||[]).find(x=>x.date===dt&&x.studentId==='s2');
  out.saved = (r&&r.hwCheck) || null;
  // v33.154: 학부모 카드(#cap-)는 미리보기·복사·전송 때만 렌더되므로 미리보기를 연 뒤 읽는다
  return new Promise((res)=>{ L.setState({ previewStudentId:'s2', previewStudentName:'' }); setTimeout(()=>{
    const e=document.getElementById('cap-s2');
    out.card = e ? { p1:(e.innerText.indexOf('오답노트 정리')>=0),
                     p2:(e.innerText.indexOf('교재 p.88~91 문제 풀기')>=0) } : null;
    L.setState({ previewStudentId:null }); res(out); }, 700); });}"""

# 항목을 다 지우고 저장한 것은 뜻으로 존중해야 한다
CLEARED = """()=>{const L=window.__L; const dt=L.state.bulk.date;
  L.setBulk('s3','attendance','출석'); L.setBulk('s3','hwCheck',[]); return 1;}"""
CLEARED2 = """()=>{const L=window.__L; const dt=L.state.bulk.date;
  const r=(L.state.data.records||[]).find(x=>x.date===dt&&x.studentId==='s3');
  return { saved:((r&&r.hwCheck)||null), reopened:(L.loadDraft(L.state.data,'C1','s3',dt).hwCheck||null) };}"""

PAIRS = """()=>{const out=[];
  document.querySelectorAll('button').forEach((b)=>{
    if(!b.offsetParent) return;
    if((b.textContent||'').trim()!=='미완') return;
    const row=b.parentElement;
    const inp=row?row.querySelector('input'):null;
    out.push((inp&&inp.placeholder==='과제 항목')?inp.value:'');
  });
  return out;}"""


def main():
    socketserver.TCPServer.allow_reuse_address = True
    srv = None
    for cand in [9394, 0]:
        try:
            srv = socketserver.TCPServer(('127.0.0.1', cand), functools.partial(Quiet, directory=ROOT))
            break
        except OSError:
            srv = None
    if srv is None:
        print('  검사용 서버를 열 수 없습니다')
        return 1
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    print('=' * 62)
    print(' 히즈북스 일간일지 «이전 과제 확인» 검사')
    print('=' * 62)
    fails = []

    def ck(name, ok, extra=''):
        print(('  OK  ' if ok else '  실패 ') + name + (('   ' + extra) if (extra and not ok) else ''))
        if not ok:
            fails.append(name)

    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={'width': 1500, 'height': 1300})
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)[:120]))
        pg.goto('http://127.0.0.1:%d/index.html' % port, wait_until='networkidle')
        pg.wait_for_timeout(3200)
        for _ in range(12):
            if pg.evaluate(FIBER):
                break
            pg.wait_for_timeout(700)
        pg.evaluate(SEED)
        pg.wait_for_timeout(1400)

        # 앱이 저장된 데이터로 스스로 부팅하게 (실사용과 같은 경로)
        pg.reload(wait_until='networkidle')
        pg.wait_for_timeout(3600)
        pg.evaluate("()=>{const g=document.getElementById('cloud-gate'); if(g)g.remove(); return 1;}")
        pg.wait_for_timeout(900)
        for _ in range(12):
            if pg.evaluate(FIBER):
                break
            pg.wait_for_timeout(700)
        pg.evaluate("""()=>{const els=[...document.querySelectorAll('button,div,span,a')]
          .filter(x=>x.offsetParent && (x.textContent||'').trim()==='학생 일지');
          if(els.length) els[els.length-1].click(); return 1;}""")
        pg.wait_for_timeout(2200)

        # ── 화면 ──
        vals = pg.evaluate("""()=>[...document.querySelectorAll('input')]
          .filter(x=>x.offsetParent && x.placeholder==='과제 항목').map(x=>x.value)""")
        ck('열자마자 과제 항목이 화면에 채워져 있음 (버튼 안 눌러도)',
           len(vals) >= 3 and '오답노트 정리' in vals, str(vals[:4]))
        ck('시험으로 확인하는 항목(단어 암기)은 빠짐',
           not any('암기' in x for x in vals), str(vals))

        pairs = pg.evaluate(PAIRS)
        item_pairs = [x for x in pairs if x]
        ck('«미완» 버튼마다 자기 항목이 붙어 있음', len(item_pairs) >= 3, str(pairs))

        # 첫 학생 첫 항목만 미완으로
        pg.evaluate("""()=>{const bs=[...document.querySelectorAll('button')]
          .filter(x=>{ if(!x.offsetParent) return false;
            if((x.textContent||'').trim()!=='미완') return false;
            const r=x.parentElement; const i=r?r.querySelector('input'):null;
            return !!(i && i.placeholder==='과제 항목'); });
          if(bs.length) bs[0].click(); return 1;}""")
        pg.wait_for_timeout(1200)
        st = pg.evaluate("""()=>{const L=window.__L; const dt=L.state.bulk.date; const o={};
          ['s1','s2'].forEach(s=>{ const r=(L.state.bulk.rows||{})[s+'|'+dt];
            o[s]= (r&&r.hwCheck) ? r.hwCheck.map(x=>(x.text||'?')+':'+x.status) : null; });
          o.hw = (((L.state.bulk.rows||{})['s1|'+dt])||{}).homework; return o;}""")
        s1 = st['s1'] or []
        ck('버튼을 눌러도 목록이 날아가지 않음 (예전엔 한 줄로 덮였음)', len(s1) >= 3, str(s1))
        ck('누른 항목만 미완이 됨',
           len(s1) >= 3 and s1[0].endswith(':미완') and s1[1].endswith(':완료'), str(s1))
        ck('전체 과제 상태가 «일부 완료»로 따라감', st['hw'] == '일부 완료', str(st['hw']))
        ck('다른 학생에게 번지지 않음', st['s2'] is None, str(st['s2']))

        # ── 저장·재열기 ──
        r0 = pg.evaluate(LOGIC)
        pg.wait_for_timeout(900)
        fresh = r0['fresh'] or []
        ck('기록 없는 날도 직전 회차에서 자동으로 채움', len(fresh) >= 3, str(TXT(fresh)))
        ck('결석이면 자동으로 채우지 않음', r0['absent'] is None, str(r0['absent']))

        pg.evaluate("()=>{window.__L.saveBulk && window.__L.saveBulk(false); return 1;}")
        pg.wait_for_timeout(2600)
        r1 = pg.evaluate(AFTER)
        saved = TXT(r1['saved'] or [])
        reop = TXT(r1['reopened'] or [])
        ck('손으로 매긴 표시가 그대로 저장됨',
           saved == ['오답노트 정리:완료', '교재 p.88~91 문제 풀기:미완', '주요구문 필기 정리:일부'], str(saved))
        ck('다시 열어도 손으로 매긴 표시가 살아 있음 (예전엔 사라졌음)',
           reop == saved, str(reop))
        ck('학부모 카드에 과제 항목이 나옴',
           bool(r1['card']) and r1['card']['p1'] and r1['card']['p2'], str(r1['card']))

        # 다시 저장해도 안 덮이는지
        pg.evaluate("()=>{window.__L.saveBulk && window.__L.saveBulk(false); return 1;}")
        pg.wait_for_timeout(2400)
        again = TXT((pg.evaluate(AFTER))['saved'] or [])
        ck('다시 저장해도 «완료»로 덮이지 않음 (예전엔 전부 완료로 바뀌었음)',
           again == saved, str(again))

        # 다 지운 것 존중
        pg.evaluate(CLEARED)
        pg.wait_for_timeout(800)
        pg.evaluate("()=>{window.__L.saveBulk && window.__L.saveBulk(false); return 1;}")
        pg.wait_for_timeout(2400)
        r2 = pg.evaluate(CLEARED2)
        ck('항목을 다 지우고 저장하면 다시 생기지 않음',
           (r2['saved'] == [] or r2['saved'] is None) and (r2['reopened'] == [] or r2['reopened'] is None),
           str(r2))

        if errs:
            fails.append('JS 오류 %d건' % len(errs))
            print('  실패 JS 오류: %s' % errs[:2])
        b.close()
    srv.shutdown()

    print('-' * 62)
    if fails:
        print('  실패 %d건 — 배포 금지' % len(fails))
        return 1
    print('  14항목 전부 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
