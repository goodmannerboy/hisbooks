# -*- coding: utf-8 -*-
"""
히즈북스 일간일지 코멘트 문구 검사 (his-comment)
--------------------------------------------------
코멘트는 학부모가 매일 받는 성장일지에 그대로 실립니다.
조사가 틀리거나(문법는), 매일 같은 문장이 나오거나, 상황과 어긋난 말이 나가면
리포트 전체의 값이 떨어집니다. 이 검사는 index.html 의 실제 문구 엔진(_cmtDraft)을
그대로 돌려서 그 세 가지를 확인합니다.

    py _check/his-comment.py

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

# 김민준(받침 있음) · 이지혜(받침 없음). 직전 기록은 둘 다 70점.
SEED = """()=>{const L=window.__L;
  const d=JSON.parse(JSON.stringify(L.state.data)); d.staff={};
  d.classes=[{id:'C1',name:'고2 A반',owner:'관리자',schedule:{days:[],times:{}},students:[
    {id:'s1',name:'김민준',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-03-14'}},
    {id:'s2',name:'이지혜',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-07-22'}}]}];
  d.records=[
    {id:'r1',classId:'C1',studentId:'s1',date:'2026.08.20',attendance:'출석',homework:'완료',gS:'70',gT:'100'},
    {id:'r2',classId:'C1',studentId:'s2',date:'2026.08.20',attendance:'출석',homework:'완료',gS:'70',gT:'100'}];
  d.exams=[]; d.checkins={}; d.counsels=[]; d.reports=[];
  d.examSchool={}; d.examSchoolG={}; d.suneung={};
  L.setState({data:d,currentUser:'관리자',activeClassId:'C1'});
  const g=document.getElementById('cloud-gate'); if(g)g.remove();
  try{localStorage.setItem('his-fix932','1');}catch(e){}
  return 'ok';}"""

RUN = """()=>{const L=window.__L; const D=L.state.data; const dt='2026.08.29';
  const base=()=>({attendance:'출석',homework:'완료',gOn:true,stOn:true,rOn:true,hOn:true});
  const mk=(sid,nm,patch,n)=>L._cmtDraft(nm, Object.assign(base(),patch||{}), D, sid, dt, n||1);
  const D0=JSON.parse(JSON.stringify(D)); D0.records=[];

  // 조사 전수: 4과목 × 우수/저조 × 8변주
  const josa=[];
  ['g','st','r','h'].forEach((k)=>{ for(let n=1;n<=8;n++){
    const a={}; a[k+'S']='95'; a[k+'T']='100'; josa.push(mk('s1','김민준',a,n));
    const b={}; b[k+'S']='40'; b[k+'T']='100'; josa.push(mk('s1','김민준',b,n)); } });
  const badJosa=josa.filter(t=>t.indexOf('문법는')>=0||t.indexOf('구문는')>=0
    ||t.indexOf('어휘은')>=0||t.indexOf('이는는')>=0);

  // 60일 반복
  const seen={}; for(let i=1;i<=60;i++){ seen[mk('s1','김민준',{},1)+''.repeat(0)]=1; }
  const seen2={}; for(let i=1;i<=60;i++){
    const t=L._cmtDraft('김민준', base(), D, 's1', '2026.09.'+i, 1); seen2[t]=1; }

  // 다시 누르기
  const again={}; for(let n=1;n<=6;n++) again[mk('s1','김민준',{},n)]=1;

  return {
    badJosaN: badJosa.length, badJosa: badJosa.slice(0,2),
    uniq60: Object.keys(seen2).length,
    againN: Object.keys(again).length,
    steady:  mk('s1','김민준',{}),
    absent:  mk('s1','김민준',{attendance:'결석'}),
    late:    mk('s1','김민준',{attendance:'지각',gS:'80',gT:'100'}),
    miss:    mk('s1','김민준',{homework:'미완료',gS:'80',gT:'100'}),
    down:    mk('s1','김민준',{gS:'40',gT:'100'}),
    up:      mk('s1','김민준',{gS:'95',gT:'100'}),
    first:   L._cmtDraft('김민준', base(), D0, 's1', dt, 1),
    noBatchim: mk('s2','이지혜',{}),
    split1: L._cmtSplit(mk('s1','김민준',{})),
    split2: L._cmtSplit('오늘 수업에서 모르는 것을 먼저 물어봤습니다.')
  };}"""

NL = chr(10)


def has_any(txt, words):
    return any(w in txt for w in words)


CHECKS = [
    ('조사가 틀린 문장 없음 (4과목 × 우수·저조 × 8변주)', lambda r: r['badJosaN'] == 0),
    ('받침 있는 이름은 이 를 붙여 부름 (민준이는)', lambda r: '민준이' in r['steady']),
    ('받침 없는 이름은 그대로 부름 (지혜는)',
     lambda r: ('지혜' in r['noBatchim']) and ('지혜이' not in r['noBatchim'])),
    ('결석이면 결석에 맞는 말',
     lambda r: has_any(r['absent'], ['결석', '만나지 못했', '자리가 비었', '못 봤'])),
    ('지각이면 늦은 것을 다룸', lambda r: has_any(r['late'], ['늦', '조금 늦'])),
    ('과제 미완이면 과제를 다룸', lambda r: has_any(r['miss'], ['과제'])),
    ('점수가 내려가면 그 사실을 다룸',
     lambda r: has_any(r['down'], ['내려갔', '아쉽', '잘 풀리지', '어려운 구간'])),
    ('점수가 오르면 그 사실을 다룸',
     lambda r: has_any(r['up'], ['올랐', '넘어갔', '뒤늦게 도착'])),
    ('첫 수업이면 첫날로 말함', lambda r: has_any(r['first'], ['첫', '처음'])),
    ('모든 초안에 출처 붙은 한 줄 문구가 붙음',
     lambda r: all((NL in r[k]) and ('—' in r[k].split(NL)[-1])
                   for k in ['steady', 'absent', 'late', 'miss', 'down', 'up', 'first'])),
    ('같은 날 다시 누르면 매번 다른 문장 (6회 전부)', lambda r: r['againN'] == 6),
    ('60일 연속에서 서로 다른 문장 50개 이상', lambda r: r['uniq60'] >= 50),
    ('카드가 문구를 인용문으로 갈라냄',
     lambda r: r['split1']['quote'].endswith(('속담', '노자', '공자', '괴테', '루소', '에디슨',
                                              '유클리드', '안중근', '맹자', '피카소', '아인슈타인',
                                              '헬렌 켈러', '헨리 포드', '마리 퀴리', '존 셰드',
                                              '제임스 볼드윈', '마틴 루서 킹', '아리스토텔레스'))
               and (r['split1']['quote'] not in r['split1']['main'])),
    ('손으로 쓴 한 줄 코멘트는 가르지 않음',
     lambda r: r['split2']['quote'] == '' and r['split2']['main'] != ''),
]


def main():
    socketserver.TCPServer.allow_reuse_address = True
    srv = None
    for cand in [9393, 0]:
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
    print(' 히즈북스 일간일지 코멘트 문구 검사 (실제 문구 엔진으로 실행)')
    print('=' * 62)
    fails = []
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={'width': 1300, 'height': 900})
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)[:120]))
        pg.goto('http://127.0.0.1:%d/index.html' % port, wait_until='networkidle')
        pg.wait_for_timeout(3000)
        for _ in range(12):
            if pg.evaluate(FIBER):
                break
            pg.wait_for_timeout(700)
        pg.evaluate(SEED)
        pg.wait_for_timeout(1500)
        r = pg.evaluate(RUN)
        for name, fn in CHECKS:
            try:
                ok = bool(fn(r))
            except Exception:
                ok = False
            print(('  OK  ' if ok else '  실패 ') + name)
            if not ok:
                fails.append(name)
        print()
        print('  [참고] 60일 중 서로 다른 문장 %d개 · 조사 오류 %d건 %s'
              % (r['uniq60'], r['badJosaN'], (r['badJosa'] or '')))
        print('  [본보기] ' + r['steady'].replace(NL, '  //  '))
        if errs:
            fails.append('JS 오류 %d건' % len(errs))
            print('  실패 JS 오류: %s' % errs[:2])
        b.close()
    srv.shutdown()

    print('-' * 62)
    if fails:
        print('  실패 %d건 — 배포 금지' % len(fails))
        return 1
    print('  %d항목 전부 통과' % len(CHECKS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
