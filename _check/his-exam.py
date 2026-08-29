# -*- coding: utf-8 -*-
"""
히즈북스 모의고사 채점 검사 (his-exam)
--------------------------------------
채점은 학부모에게 나가는 숫자입니다. 틀리면 바로 신뢰를 잃습니다.
이 검사는 index.html 의 실제 채점 코드를 그대로 돌려서
«여러 학생을 한 번에 채점했을 때 점수·백분율·등급·틀린 유형이 다 맞는가»를 확인합니다.

    py _check/his-exam.py

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

# 10문항 · 배점 다양(10,10,10,10,10,10,10,10,10,10 = 100) · 유형 10가지
SEED = """()=>{const L=window.__L; const td=L.today();
  const d=JSON.parse(JSON.stringify(L.state.data)); d.staff={};
  const S=(id,nm,birth)=>({id:id,name:nm,registeredAt:'2025.03.02',
    school:'한울고 2학년', intake:{birth:birth}});
  d.classes=[{id:'C1',name:'모의고사반',owner:'관리자',schedule:{days:[],times:{}},
    students:[S('s1','가학생','2009-03-14'), S('s2','나학생','2009-07-22'),
              S('s3','다학생','2009-11-02'), S('s4','라학생','2010-01-05')]}];
  const TY=['듣기','목적파악','주제파악','빈칸추론','어법','어휘','순서배열','삽입','함축의미','내용일치'];
  const qs=[]; for(let i=1;i<=10;i++){ qs.push({no:i, key:String((i%5)+1), pt:10, group:TY[i-1], type:TY[i-1]}); }
  d.examSets=[{id:'X1', name:'9월 모의고사', date:td, grade:'고2', questions:qs, submissions:{}}];
  d.exams=[]; d.records=[]; d.checkins={}; d.counsels=[]; d.reports=[];
  d.examSchool={}; d.examSchoolG={}; d.suneung={};
  L.setState({data:d,currentUser:'관리자',activeClassId:'C1',activeExamSetId:'X1'});
  const g=document.getElementById('cloud-gate'); if(g)g.remove();
  try{localStorage.setItem('his-fix932','1');}catch(e){}
  return 'ok';}"""

# s1: 5·6 틀림(80) / s2: 1·4·9 틀림(70) / s3: 만점(100) / s4: 1~9 틀림 + 10번 미응답(0)
RUN = """()=>{const L=window.__L;
  const key=(i)=>String((i%5)+1);
  const bad=(i)=>String((((i%5)+1)%5)+1);
  const plan={s1:[5,6], s2:[1,4,9], s3:[], s4:[1,2,3,4,5,6,7,8,9]};
  Object.keys(plan).forEach((sid)=>{
    const ans={};
    for(let i=1;i<=10;i++){
      if(sid==='s4' && i===10) continue;            // 미응답 (OMR 이 못 읽은 경우)
      ans[i] = (plan[sid].indexOf(i)>=0) ? bad(i) : key(i);
    }
    L.applyOmr(sid, ans);
  });
  return 'ok';}"""

READ = """()=>{const d=window.__L.state.data; const es=(d.examSets||[])[0]||{};
  const out={};
  ['s1','s2','s3','s4'].forEach((sid)=>{
    const sub=(es.submissions||{})[sid]||{};
    const rec=(d.exams||[]).find(e=>e.studentId===sid)||{};
    out[sid]={score:sub.score, pct:sub.pct, grade:sub.grade,
      recScore:rec.score, recTotal:rec.total, recGrade:rec.grade,
      wrong:(rec.wrongTypes||[])};
  });
  return out;}"""

CHECKS = [
    ('가학생 점수 80', lambda r: r['s1']['score'] == 80),
    ('가학생 등급 2', lambda r: str(r['s1']['recGrade']) == '2'),
    ('가학생 틀린 유형 = 어법·어휘',
     lambda r: sorted(r['s1']['wrong']) == sorted(['어법', '어휘'])),
    ('나학생 점수 70', lambda r: r['s2']['score'] == 70),
    ('나학생 등급 3', lambda r: str(r['s2']['recGrade']) == '3'),
    ('나학생 틀린 유형 3가지',
     lambda r: sorted(r['s2']['wrong']) == sorted(['듣기', '빈칸추론', '함축의미'])),
    ('다학생 만점 100 · 1등급', lambda r: r['s3']['score'] == 100 and str(r['s3']['recGrade']) == '1'),
    ('다학생 틀린 유형 없음', lambda r: len(r['s3']['wrong']) == 0),
    ('라학생 0점', lambda r: r['s4']['score'] == 0),
    ('라학생 등급은 9까지만 (10등급 없음)', lambda r: str(r['s4']['recGrade']) == '9'),
    ('미응답도 틀린 것으로 셈 (유형 10개)', lambda r: len(r['s4']['wrong']) == 10),
    ('기록의 점수·만점이 제출과 일치',
     lambda r: all(str(r[k]['recScore']) == str(r[k]['score']) and str(r[k]['recTotal']) == '100'
                   for k in ['s1', 's2', 's3', 's4'])),
]

# ─────────────────────────────────────────────────────────────
# 2부 : 성적은 «반에 상관없이 · 생년월일 · 등록된 모든 학생» 기준 (원장 지시 v33.107)
#  네 반: 원장 두 반(A·B) + 조이 선생님 두 반. 라학생은 가학생과 생년월일이 같다(겹침).
#  퇴원생은 후보에서 빠져야 하고, 겹치면 조용히 아무에게나 넣지 말고 이름을 알려야 한다.
# ─────────────────────────────────────────────────────────────
SEED2 = """()=>{const L=window.__L; const td=L.today();
  const d=JSON.parse(JSON.stringify(L.state.data)); d.staff={};
  const S=(id,nm,b,ex)=>Object.assign({id:id,name:nm,registeredAt:'2025.03.02',
    school:'한울고 2학년', intake:{birth:b}}, ex||{});
  d.classes=[
   {id:'C1',name:'고2 A반',owner:'관리자',schedule:{days:[],times:{}},students:[
      S('s1','가학생','2009-03-14'), S('s2','나학생','2009-07-22')]},
   {id:'C2',name:'고2 B반',owner:'관리자',schedule:{days:[],times:{}},students:[
      S('s3','다학생','2009-11-02'), S('s4','라학생','2009-03-14')]},
   {id:'C3',name:'조이반1',owner:'조이',schedule:{days:[],times:{}},students:[
      S('s5','마학생','2010-01-05'), S('s6','퇴원생','2008-05-05',{withdrawn:true})]},
   {id:'C4',name:'조이반2',owner:'조이',schedule:{days:[],times:{}},students:[
      S('s7','바학생','2010-02-06')]}];
  const TY=['듣기','목적파악','주제파악','빈칸추론','어법','어휘','순서배열','삽입','함축의미','내용일치'];
  const qs=[]; for(let i=1;i<=10;i++){ qs.push({no:i,key:String((i%5)+1),pt:10,group:TY[i-1],type:TY[i-1]}); }
  d.examSets=[{id:'X1',name:'9월 모의고사',date:td,grade:'고2',questions:qs,submissions:{}}];
  d.exams=[]; d.records=[]; d.checkins={}; d.counsels=[]; d.reports=[];
  d.examSchool={}; d.examSchoolG={}; d.suneung={};
  L.setState({data:d,currentUser:'관리자',activeClassId:'C1',activeExamSetId:'X1',
    view:'exams',examStudentId:'s1'});
  const g=document.getElementById('cloud-gate'); if(g)g.remove();
  try{localStorage.setItem('his-fix932','1');}catch(e){}
  return 'ok';}"""

# 활성 반은 C1 인데, 다른 반(C2)·다른 선생님 반(C3) 학생을 채점한다
RUN2 = """()=>{const L=window.__L;
  const key=(i)=>String((i%5)+1); const bad=(i)=>String((((i%5)+1)%5)+1);
  const plan={s3:[5,6], s5:[1,4,9], s7:[]};
  Object.keys(plan).forEach((sid)=>{ const ans={};
    for(let i=1;i<=10;i++){ ans[i]=(plan[sid].indexOf(i)>=0)?bad(i):key(i); }
    L.applyOmr(sid, ans); });
  return 'ok';}"""

READ2 = """()=>{const L=window.__L; const d=L.state.data; const f=(b)=>L._omrMatch(d,b);
  const out={ m:{ same:f('090722'), other:f('091102'), joey:f('100105'),
                  dup:f('090314'), wd:f('080505'), none:f('991231'), eight:f('20091102') }, r:{} };
  ['s3','s5','s7'].forEach((sid)=>{ const rec=(d.exams||[]).find(e=>e.studentId===sid)||{};
    const a=L.examAgg(d,'C1',sid);
    out.r[sid]={ score:rec.score, grade:rec.grade, wrong:(rec.wrongTypes||[]),
      name:a.studentName, since:a.sinceDate, weak:(a.weakTypes||[]).map(w=>w.name), n:a.examCount }; });
  return out;}"""

OPTS = """()=>{ const sels=[...document.querySelectorAll('select')]; const out=[];
  sels.forEach(s=>{ const o=[...s.options].map(x=>x.textContent.trim());
    if(o.length && o.some(t=>t.indexOf('학생')>=0)) out.push(o); });
  return out.length?out[0]:[];}"""

CHECKS2 = [
    ('같은 반 학생을 생년월일로 찾음', lambda r: r['m']['same']['sid'] == 's2'),
    ('다른 반 학생도 찾음 (반 무관)', lambda r: r['m']['other']['sid'] == 's3'),
    ('다른 선생님 반 학생도 찾음', lambda r: r['m']['joey']['sid'] == 's5'),
    ('8자리 생년월일도 인식', lambda r: r['m']['eight']['sid'] == 's3'),
    ('생년월일이 겹치면 채점 안 함',
     lambda r: r['m']['dup']['sid'] is None and r['m']['dup']['amb'] == 'dup'),
    ('겹친 학생 이름을 알려줌',
     lambda r: sorted(r['m']['dup']['names']) == sorted(['가학생', '라학생'])),
    ('퇴원생은 후보에서 제외',
     lambda r: r['m']['wd']['sid'] is None and r['m']['wd']['amb'] == 'out'),
    ('없는 생년월일은 조용히 미매칭',
     lambda r: r['m']['none']['sid'] is None and not r['m']['none']['amb']),
    ('다른 반 학생 채점 정확 (80점 2등급)',
     lambda r: r['r']['s3']['score'] == '80' and r['r']['s3']['grade'] == '2'),
    ('다른 선생님 반 학생 채점 정확 (70점 3등급)',
     lambda r: r['r']['s5']['score'] == '70' and r['r']['s5']['grade'] == '3'),
    ('다른 반 학생도 틀린 유형이 나옴',
     lambda r: sorted(r['r']['s3']['wrong']) == sorted(['어법', '어휘'])),
    ('다른 반 학생 성적표에 이름·등록일이 채워짐',
     lambda r: r['r']['s5']['name'] == '마학생' and r['r']['s5']['since'] == '2025.03.02'),
    ('다른 반 학생 약점 집계도 이어짐',
     lambda r: sorted(r['r']['s5']['weak']) == sorted(['듣기', '빈칸추론', '함축의미'])
               and r['r']['s5']['n'] == 1),
]


def main():
    socketserver.TCPServer.allow_reuse_address = True
    srv = None
    for cand in [9392, 0]:
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
    print(' 히즈북스 모의고사 채점 검사 (실제 채점 코드로 실행)')
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
        pg.evaluate(RUN)
        pg.wait_for_timeout(1600)
        r = pg.evaluate(READ)
        for name, fn in CHECKS:
            try:
                ok = bool(fn(r))
            except Exception:
                ok = False
            print(('  OK  ' if ok else '  실패 ') + name)
            if not ok:
                fails.append(name)

        # ── 2부: 반 무관 · 생년월일 기준 ──
        print()
        print(' 성적은 반에 상관없이 생년월일 기준 (등록된 모든 학생)')
        print('-' * 62)
        pg.evaluate(SEED2)
        pg.wait_for_timeout(1500)
        pg.evaluate(RUN2)
        pg.wait_for_timeout(1700)
        r2 = pg.evaluate(READ2)
        for name, fn in CHECKS2:
            try:
                ok = bool(fn(r2))
            except Exception:
                ok = False
            print(('  OK  ' if ok else '  실패 ') + name)
            if not ok:
                fails.append(name)

        # 담임 스코프: 선생님 화면에 남의 반 학생이 새면 안 된다
        pg.wait_for_timeout(600)
        adminOpts = pg.evaluate(OPTS)
        okA = ('다학생 · 고2 B반' in adminOpts) and ('마학생 · 조이반1' in adminOpts)
        print(('  OK  ' if okA else '  실패 ') + '원장 성적 탭에 다른 반 학생이 반 이름과 함께 보임')
        if not okA:
            fails.append('원장 성적 탭 목록')
            print('       실제: %s' % adminOpts)
        pg.evaluate("()=>window.__L.setState({currentUser:'조이',activeClassId:'C3',"
                    "examStudentId:'s5',view:'exams'})")
        pg.wait_for_timeout(1700)
        tOpts = pg.evaluate(OPTS)
        okT = ('마학생' in tOpts) and ('바학생 · 조이반2' in tOpts) \
            and not any('가학생' in x or '다학생' in x for x in tOpts)
        print(('  OK  ' if okT else '  실패 ') + '선생님에게는 자기 반 학생만 보임 (담임 스코프)')
        if not okT:
            fails.append('담임 스코프 누출')
            print('       실제: %s' % tOpts)

        if errs:
            fails.append('JS 오류 %d건' % len(errs))
            print('  실패 JS 오류: %s' % errs[:2])
        b.close()
    srv.shutdown()

    print('-' * 62)
    if fails:
        print('  실패 %d건 — 배포 금지' % len(fails))
        return 1
    print('  %d항목 전부 통과' % (len(CHECKS) + len(CHECKS2) + 2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
