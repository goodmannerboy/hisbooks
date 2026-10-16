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

# ── 3부: 시험 이름은 같은 모양으로(고르면 조립 · 읽어서 통일) ──
#   이름의 모양: [연도] [학교] [학년] [학기·시험] [자료] [N차] (덧붙임) / [연도] [월] [고N] 전국연합학력평가 / [연도] [학년] [시험] [월]
XN_MADE = ['2026 한울고 2학년 2학기 중간고사 모의평가 2차', '2026 한울고 2학년 2학기 중간고사',
           '2026 9월 고1 전국연합학력평가', '2026 고2 진단평가 10월']
XN_CANON = XN_MADE + ['2026 동지여고 1학년 1학기 기말고사 쪽집게 2차 재시험', '2026 6월 고3 평가원 모의평가',
                      '2026 11월 고3 대학수학능력시험', '2026 고2 10월 단어 시험', '2026 새빛중 3학년 2학기 기말고사 파이널']
XN_READ = [('26년 9월 고1 전국연합학력평가', '2026 9월 고1 전국연합학력평가'),
           ('한울고2 2학기 중간 모의평가 2차', '2026 한울고 2학년 2학기 중간고사 모의평가 2차'),
           ('한울고 2학년 2학기 중간고사 대비 모의평가', '2026 한울고 2학년 2학기 중간고사 모의평가'),
           ('2026 새빛고 2-2 중간 쪽집게', '2026 새빛고 2학년 2학기 중간고사 쪽집게'),
           ('새빛고 1학년 2학기 중간고사', '2026 새빛고 1학년 2학기 중간고사'),
           ('고2 진단평가 10월', '2026 고2 진단평가 10월')]
XN_NOPE = ['단어 시험', '2학기 중간고사 대비 모의평가', '기초 1단원 테스트']
XN_CAT = [('2026 한울고 2학년 2학기 중간고사 모의평가 2차', '학원시험'), ('2026 한울고 2학년 2학기 중간고사 3차', '학원시험'),
          ('2026 한울고 2학년 2학기 중간고사', '학교시험'), ('2026 9월 고1 전국연합학력평가', '모의고사'),
          ('2026 고2 진단평가 10월', '학원시험')]
READ3 = """(a)=>{ const L=window.__L; const D='2026.10.14';
  const made=[L._xnMake({k:'prep',y:'2026',s:'한울고',n:'2',t:'2학기 중간고사',m:'모의평가',r:'2',x:''}),
              L._xnMake({k:'school',y:'2026',s:'한울고',n:'2',t:'2학기 중간고사',m:'모의평가',r:'2',x:''}),
              L._xnMake({k:'mock',y:'2026',mo:'9',g:'고1',w:'전국연합학력평가',x:''}),
              L._xnMake({k:'acad',y:'2026',g:'고2',w:'진단평가',mo:'10',x:''})];
  const dd={ exams:[{examSetId:'E',category:'옛 이름'},{examSetId:'E',category:'학원시험'},{examSetId:'F',category:'옛 이름'}] };
  L._xnRecNames(dd,'E','새 이름'); const es={ name:'새 이름' }; L._xnAlias(es,'옛 이름'); L._xnAlias(es,'옛 이름');
  return { made:made, canon:a.canon.map((n)=>L._xnCanon(n,D)), read:a.read.map((n)=>L._xnCanon(n,D)),
           nope:a.nope.map((n)=>L._xnCanon(n,D)), cat:a.cat.map((n)=>L._examCat({category:n})),
           rec:dd.exams.map((r)=>r.category), alias:es.alias }; }"""
CHECKS3 = [
    ('시험 이름 조립: 내신 대비 · 학교 시험 · 모의고사 · 학원 시험의 모양', lambda r: r['made'] == XN_MADE),
    ('조립된 이름은 다시 읽어도 그대로(같은 모양이 고정)', lambda r: r['canon'] == XN_CANON),
    ('여러 모양으로 친 이름이 같은 이름으로 읽힘 · 학교를 모르는 이름은 지어내지 않음',
     lambda r: r['read'] == [b for a, b in XN_READ] and r['nope'] == ['', '', '']),
    ('같은 모양의 이름은 구분을 이름에서 바로(«대비»가 없어도 내신 대비 시험 = 학원시험)',
     lambda r: r['cat'] == [b for a, b in XN_CAT]),
    ('시험 이름을 바꾸면 성적 기록의 이름이 따라가고(구분을 고른 기록 · 다른 시험은 그대로) 옛 이름이 남음',
     lambda r: r['rec'] == ['새 이름', '학원시험', '옛 이름'] and r['alias'] == '옛 이름'),
]

# ── 4부: 점수 직접 입력(성적 탭) · 시험 채점 선반 ──
#   시험은 반에 한 번만 고르고 학교 · 학년은 학생마다 — 만들어지는 이름은 모두 «같은 모양»이어야 하고,
#   같은 시험을 두 번 저장해도 기록은 하나(고치기) · 자동 채점된 같은 이름의 시험은 건드리지 않는다.
#   보던 학생이 퇴원하면 성장일지 카드 · 고른 줄은 반의 첫 학생으로(퇴원생 카드가 남지 않음).
SEED4 = """()=>{ const L=window.__L; const d=JSON.parse(JSON.stringify(L.state.data));
  const S=(id,nm,sch)=>({ id:id, name:nm, registeredAt:'2025.03.02', school:sch, intake:{} });
  d.classes=[{ id:'K1', name:'직접입력반', owner:'관리자', schedule:{days:[],times:{}},
      students:[S('k1','가온','한울고 2학년'), S('k2','나래','포항새빛고등학교 1학년'), S('k3','다솜','새빛중 3학년'), S('k4','라온','새빛고 1학년')] },
    { id:'K2', name:'다른반', owner:'관리자', schedule:{days:[],times:{}}, students:[S('k9','마루','한울고 2학년')] }];
  const qs=[]; for(let i=1;i<=10;i++) qs.push({ no:i, key:String((i%5)+1), pt:10, group:'', type:'' });
  const sub=(t)=>({ answers:{ 1:'2' }, t:t });
  d.examSets=[{ id:'ES1', kind:'academy', name:'2026 새빛중 3학년 2학기 중간고사', date:L.today(), grade:'중3', questions:qs, submissions:{ k3:sub(Date.now()) }, createdT:1, keyT:1 },
              { id:'ES2', kind:'academy', name:'2026 한울고 2학년 2학기 중간고사 모의평가 1차', date:L.today(), grade:'고2', questions:qs, submissions:{ k1:sub(Date.now()), k9:sub(Date.now()) }, createdT:2, keyT:2 },
              { id:'ES3', kind:'academy', name:'2026 한울고 2학년 2학기 중간고사 모의평가 2차', date:L.today(), grade:'고2', questions:qs, submissions:{ k9:sub(Date.now()) }, createdT:3, keyT:3 }];
  d.exams=[{ id:'o1', examSetId:'ES1', studentId:'k3', classId:'K1', category:'2026 새빛중 3학년 2학기 중간고사', date:L.today(), score:'70', total:'100', grade:'3', wrongTypes:[] }];
  d.deletedExams=[]; d.capSent={ 'acad|ES2|k1':true };
  L._sxD={}; L.setState({ data:d, currentUser:'관리자', view:'exams', activeClassId:'K1', examStudentId:'k1', sxP:{ k:'school', y:'2026', t:'2학기 중간고사' }, sxDate:'2026.10.14', sxTot:'100', sxOpen:false });
  return 1; }"""
ROWS4 = """()=>{ const L=window.__L; const R=L._sxRows(L.state, true); const sh=L._shelfVals(L.state);
  return { rows:R.rows.map((r)=>({ sid:r.sid, exam:r.exam, canon:(L._xnCanon(r.exam, '2026.10.14')===r.exam), auto:!!r.autoId, g:r.gShow, pend:r.pend })), cat:R.cat,
           shelf:sh.cards.map((c)=>[c.id, c.gT, c.sT, c.mode]) }; }"""
EX4 = """()=>{ const d=window.__L.state.data; return { ex:(d.exams||[]).map((e)=>[e.id, e.studentId, e.category, e.title||'', String(e.score), String(e.total), String(e.grade||''), e.classId||'', e.examSetId||'']), del:(d.deletedExams||[]) }; }"""
DRAFT4 = """(a)=>{ const L=window.__L; const D=L._sxDraft('K1'); Object.keys(a.d).forEach((k)=>{ D[k]={ v:a.d[k], g:'', dv:true, dg:false, gm:false }; }); if(a.p) L.setState({ sxP:a.p }); return 1; }"""
T4 = '2026 한울고 2학년 2학기 중간고사'
T4B = '2026 새빛고 1학년 2학기 중간고사'
WD4 = """()=>{ const L=window.__L; const S=L.state; const t=[...document.querySelectorAll('body *')].filter((d)=>d.tagName!=='SCRIPT' && d.children.length===0 && /의 성장일지$/.test((d.textContent||'').trim()) && d.getBoundingClientRect().width>0).map((d)=>d.textContent.trim());
  const tt=(sid)=>{ try{ return L.examAgg(S.data, S.activeClassId, sid).studentTitle; }catch(e){ return '?'; } };
  return { sid:(S.examStudentId||null), eff:(L._exSid ? L._exSid(S) : null), rows:L._sxRows(S, true).rows.map((r)=>r.sid), title:[...new Set(t)], t2:tt('k2'), t1:tt('k1') }; }"""
#   점수 ▲▼ 는 같은 종류(모의고사 · 학교시험 · 학원시험)의 바로 앞 시험과 견준다.
SK4 = """()=>{ const L=window.__L; if(!L._sameKindPrev) return null; const E=(c,t,d)=>({ category:c, title:t, date:d });
  const a=[E('모의고사','','2026.09.01'), E('학교시험','','2026.09.15'), E('모의고사','','2026.10.01')];
  const b=[E('학원시험','','2026.09.01'), E('모의고사','','2026.10.01')];
  const c=[E('','2학기 중간고사','2026.06.01'), E('모의고사','','2026.09.01'), E('','2학기 기말고사','2026.10.01')];
  return [a.indexOf(L._sameKindPrev(a)), b.indexOf(L._sameKindPrev(b)), c.indexOf(L._sameKindPrev(c)), (L._sameKindPrev([a[0]]) === null)]; }"""

def _man(x):
    return sorted([e for e in x['ex'] if not e[8]], key=lambda e: e[1])


CHECKS4 = [
    ('점수 직접 입력: 이름은 학생마다 학교 · 학년으로, 모두 같은 모양(«포항새빛고등학교» → 등록된 이름 «새빛고»)',
     lambda r: [(x['sid'], x['exam']) for x in r['rows']['rows']] == [('k1', T4), ('k2', T4B), ('k3', '2026 새빛중 3학년 2학기 중간고사'), ('k4', T4B)]
     and all(x['canon'] for x in r['rows']['rows']) and r['rows']['cat'] == '학교시험'),
    ('저장: 구분 · 시험명 · 점수 · 반이 기록되고, 자동 채점된 같은 이름의 시험(다솜)은 건드리지 않음',
     lambda r: [x['auto'] for x in r['rows']['rows']] == [False, False, True, False]
     and [(e[1], e[2], e[3], e[4], e[5], e[7]) for e in _man(r['a'])] == [('k1', '학교시험', T4, '88', '100', 'K1'), ('k2', '학교시험', T4B, '91.5', '100', 'K1')]
     and [e for e in r['a']['ex'] if e[8]] == [['o1', 'k3', '2026 새빛중 3학년 2학기 중간고사', '', '70', '100', '3', 'K1', 'ES1']]),
    ('같은 시험을 다시 저장하면 새 기록이 아니라 같은 기록을 고침(88 → 90)',
     lambda r: len(_man(r['b'])) == 2 and _man(r['b'])[0][0] == _man(r['a'])[0][0] and _man(r['b'])[0][4] == '90'),
    ('되돌리기: 고친 것은 전 점수로(기록은 그대로) · 새로 만든 것은 삭제 표식과 함께 사라짐',
     lambda r: _man(r['c'])[0][4] == '88' and len(_man(r['c'])) == 2 and r['c']['del'] == []
     and len(_man(r['d'])) == 3 and len(_man(r['e'])) == 2
     and r['e']['del'] == [[e for e in _man(r['d']) if e[1] == 'k4'][0][0]]),
    ('등급: 모의고사는 점수에서 저절로(88점 → 2등급) · 학교 시험은 지어내지 않음',
     lambda r: [x['g'] for x in r['mock']['rows'] if x['sid'] == 'k4'] == ['2'] and [x['exam'] for x in r['mock']['rows'] if x['sid'] == 'k4'] == ['2026 9월 고1 전국연합학력평가']
     and [x['g'] for x in r['sch']['rows'] if x['sid'] == 'k4'] == ['']),
    ('시험 채점 선반: 이 반 학생이 채점된 시험만 · 채점 n/N · 통지서 n/N (다른 반만 본 시험은 안 올라옴)',
     lambda r: sorted(r['rows']['shelf']) == [['ES1', '채점 1/4', '통지서 0/4', 'grade'], ['ES2', '채점 1/4', '통지서 1/4', 'grade']]),
    ('보던 학생이 퇴원하면 성장일지 카드 · 고른 줄은 반의 첫 학생으로(퇴원생 카드가 남지 않음)',
     lambda r: r['wd']['sid'] == 'k2' and r['wd']['eff'] == 'k2' and r['wd']['rows'] == ['k2', 'k3', 'k4']
     and r['wd']['title'] == [r['wd']['t2']] and r['wd']['t1'] not in r['wd']['title']),
    ('점수 ▲▼ 는 같은 종류의 바로 앞 시험과(모의 → 학교 → 모의 = 첫 모의 · 앞에 같은 종류가 없으면 비교 없음)',
     lambda r: r['sk'] == [0, -1, 0, True]),
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

        # ── 3부: 시험 이름은 같은 모양으로 ──
        print()
        print(' 시험 이름은 같은 모양으로 (고르면 조립 · 읽어서 통일)')
        print('-' * 62)
        try:
            r3 = pg.evaluate(READ3, {'canon': XN_CANON, 'read': [a for a, b in XN_READ], 'nope': XN_NOPE,
                                     'cat': [a for a, b in XN_CAT]})
        except Exception as e3:
            r3 = None
            print('       실행 오류: %s' % str(e3)[:160])
        for name, fn in CHECKS3:
            try:
                ok = bool(r3) and bool(fn(r3))
            except Exception:
                ok = False
            print(('  OK  ' if ok else '  실패 ') + name)
            if not ok:
                fails.append(name)
                if r3:
                    print('       실제: %s' % {k: r3[k] for k in ('made', 'read', 'nope', 'cat', 'rec', 'alias')})

        # ── 4부: 점수 직접 입력 · 시험 채점 선반 ──
        print()
        print(' 점수 직접 입력 · 시험 채점 선반 (성적 탭)')
        print('-' * 62)
        r4 = {}
        try:
            pg.evaluate(SEED4); pg.wait_for_timeout(900)
            r4['rows'] = pg.evaluate(ROWS4)
            pg.evaluate(DRAFT4, {'d': {'k1': '88', 'k2': '91.5', 'k3': '55'}}); pg.evaluate("()=>{ window.__L.sxSave(); return 1; }"); pg.wait_for_timeout(700)
            r4['a'] = pg.evaluate(EX4)
            pg.evaluate(DRAFT4, {'d': {'k1': '90'}}); pg.evaluate("()=>{ window.__L.sxSave(); return 1; }"); pg.wait_for_timeout(700)
            r4['b'] = pg.evaluate(EX4)
            pg.evaluate("()=>{ window.__L._undoRun(); return 1; }"); pg.wait_for_timeout(700)
            r4['c'] = pg.evaluate(EX4)
            pg.evaluate(DRAFT4, {'d': {'k4': '77'}}); pg.evaluate("()=>{ window.__L.sxSave(); return 1; }"); pg.wait_for_timeout(700)
            r4['d'] = pg.evaluate(EX4)
            pg.evaluate("()=>{ window.__L._undoRun(); return 1; }"); pg.wait_for_timeout(700)
            r4['e'] = pg.evaluate(EX4)
            pg.evaluate(DRAFT4, {'d': {'k4': '88'}, 'p': {'k': 'mock', 'y': '2026', 'mm': '9', 'mw': '전국연합학력평가'}}); pg.wait_for_timeout(500)
            r4['mock'] = pg.evaluate(ROWS4)
            pg.evaluate(DRAFT4, {'d': {'k4': '88'}, 'p': {'k': 'school', 'y': '2026', 't': '1학기 기말고사'}}); pg.wait_for_timeout(500)
            r4['sch'] = pg.evaluate(ROWS4)
            pg.evaluate("()=>{ const L=window.__L; L._sxD={}; try{ L._undoDrop(); }catch(e){} return 1; }")
            pg.evaluate("()=>{ window.__L.setState({ view:'exams', activeClassId:'K1', examStudentId:'k1', editingExamId:null, exEdNew:false }); return 1; }"); pg.wait_for_timeout(700)
            pg.evaluate("()=>{ window.__L.withdrawStudent('k1', '', ''); return 1; }"); pg.wait_for_timeout(1100)
            r4['wd'] = pg.evaluate(WD4)
            r4['sk'] = pg.evaluate(SK4)
        except Exception as e4:
            print('       실행 오류: %s' % str(e4)[:200])
        for name, fn in CHECKS4:
            try:
                ok = bool(fn(r4))
            except Exception:
                ok = False
            print(('  OK  ' if ok else '  실패 ') + name)
            if not ok:
                fails.append(name)
                print('       실제: %s' % str(r4)[:900])

        if errs:
            fails.append('JS 오류 %d건' % len(errs))
            print('  실패 JS 오류: %s' % errs[:2])
        b.close()
    srv.shutdown()

    print('-' * 62)
    if fails:
        print('  실패 %d건 — 배포 금지' % len(fails))
        return 1
    print('  %d항목 전부 통과' % (len(CHECKS) + len(CHECKS2) + len(CHECKS3) + len(CHECKS4) + 2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
