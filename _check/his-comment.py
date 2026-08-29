# -*- coding: utf-8 -*-
"""
히즈북스 일간일지 코멘트(감성 한 줄) 검사 (his-comment)
--------------------------------------------------------
코멘트는 성장일지의 «A Note for You» 자리에 그대로 실려 매일 나갑니다.
원장 지시(2026-08-30): 학습평가는 하지 않고, 인생을 통찰하는 감성 한 줄을 매번 다르게.
원장 정정: 이 말은 **스승이 학생에게 건네는 말**이지 부모에게 하는 말이 아니다.

이 검사는 index.html 의 실제 문구 엔진(_cmtDraft)을 그대로 돌려서 확인합니다.
  · 한 줄인가
  · 출결·과제·점수에 따라 달라지지 않는가 (학습평가를 하지 않는가)
  · 학생에게 건네는 말인가 (부모를 향한 표현·존댓말 종결이 없는가)
  · 매번 다른가 (다시 누를 때, 학생마다, 수업이 쌓일수록)
  · 책 문장을 그대로 담지 않았는가 (저작권)

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

SEED = """()=>{const L=window.__L;
  const d=JSON.parse(JSON.stringify(L.state.data)); d.staff={};
  d.classes=[{id:'C1',name:'고2 A반',owner:'관리자',schedule:{days:[],times:{}},students:[
    {id:'s1',name:'김민준',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-03-14'}},
    {id:'s2',name:'이지혜',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-07-22'}},
    {id:'s3',name:'박서준',registeredAt:'2025.03.02',school:'한울고',intake:{birth:'2009-09-09'}}]}];
  d.records=[{id:'r1',classId:'C1',studentId:'s1',date:'2026.08.20',attendance:'출석',homework:'완료',gS:'70',gT:'100'}];
  d.exams=[]; d.checkins={}; d.counsels=[]; d.reports=[];
  d.examSchool={}; d.examSchoolG={}; d.suneung={};
  L.setState({data:d,currentUser:'관리자',activeClassId:'C1'});
  const g=document.getElementById('cloud-gate'); if(g)g.remove();
  try{localStorage.setItem('his-fix932','1');}catch(e){}
  return 'ok';}"""

RUN = """()=>{const L=window.__L; const D=L.state.data; const dt='2026.08.30';
  const base=()=>({attendance:'출석',homework:'완료',gOn:true,stOn:true,rOn:true,hOn:true});
  const mk=(sid,nm,patch,n)=>L._cmtDraft(nm, Object.assign(base(),patch||{}), D, sid, dt, n||1);
  const pool=L._cmtLines();
  const NLc=String.fromCharCode(10);

  const same=[ mk('s1','김민준',{}), mk('s1','김민준',{attendance:'결석'}),
               mk('s1','김민준',{attendance:'지각'}), mk('s1','김민준',{homework:'미완료'}),
               mk('s1','김민준',{gS:'10',gT:'100'}), mk('s1','김민준',{gS:'100',gT:'100'}) ];
  const again=[]; for(let n=1;n<=10;n++) again.push(mk('s1','김민준',{},n));
  const three=[ mk('s1','김민준',{}), mk('s2','이지혜',{}), mk('s3','박서준',{}) ];

  const cyc={}; let dup=0; const D2=JSON.parse(JSON.stringify(D));
  for(let i=0;i<pool.length;i++){
    D2.records=[]; for(let k=0;k<i;k++) D2.records.push({id:'x'+k,classId:'C1',studentId:'s1',date:'2026.01.01',attendance:'출석'});
    const t=L._cmtDraft('김민준', base(), D2, 's1', dt, 1);
    if(cyc[t]) dup++; cyc[t]=1; }

  const uniqPool={}; let poolDup=0;
  pool.forEach(function(x){ if(uniqPool[x]) poolDup++; uniqPool[x]=1; });

  return { n:pool.length, pool:pool, same:same, again:again, three:three,
           cycUniq:Object.keys(cyc).length, cycDup:dup, poolDup:poolDup,
           maxLen:Math.max.apply(null,pool.map(function(x){return x.length;})),
           minLen:Math.min.apply(null,pool.map(function(x){return x.length;})),
           withNL:pool.filter(function(x){return x.indexOf(NLc)>=0;}).length,
           withCite:pool.filter(function(x){return x.indexOf(' — ')>=0;}),
           evalWords:pool.filter(function(x){
             return /(점수|등급|성적표|출결|정답률|평균)/.test(x); }),
           toParent:pool.filter(function(x){
             return /(아이|부모|학부모|주세요|주시면)/.test(x); }),
           polite:pool.filter(function(x){
             return /(습니다|입니다|해요|세요|십시오|랍니다)/.test(x); }),
           split1:L._cmtSplit(mk('s1','김민준',{})) };}"""

NL = chr(10)


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
    print(' 히즈북스 일간일지 코멘트(감성 한 줄) 검사')
    print('=' * 62)
    fails = []

    def ck(name, ok, extra=''):
        print(('  OK  ' if ok else '  실패 ') + name + (('   ' + str(extra)) if (extra and not ok) else ''))
        if not ok:
            fails.append(name)

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

        ck('문장이 넉넉히 준비되어 있음 (120편 이상)', r['n'] >= 120, r['n'])
        ck('문장 풀에 중복이 없음', r['poolDup'] == 0, r['poolDup'])
        ck('모든 코멘트가 한 줄임', r['withNL'] == 0, r['withNL'])
        ck('길이가 카드에 맞음 (10~60자)',
           r['minLen'] >= 10 and r['maxLen'] <= 60, '%d~%d' % (r['minLen'], r['maxLen']))
        ck('학습평가를 하지 않음 — 출결·과제·점수가 달라도 같은 문장',
           len(set(r['same'])) == 1, r['same'][:2])
        ck('점수·등급 같은 평가 낱말이 없음', not r['evalWords'], r['evalWords'][:2])
        ck('학생에게 건네는 말임 — 부모를 향한 표현이 없음',
           not r['toParent'], r['toParent'][:2])
        ck('학생에게 건네는 말투 — 존댓말 종결이 없음',
           not r['polite'], r['polite'][:2])
        ck('같은 날 다시 누르면 매번 다름 (10회 전부)',
           len(set(r['again'])) == 10, len(set(r['again'])))
        ck('같은 날이어도 학생마다 다름', len(set(r['three'])) == 3, r['three'])
        ck('수업이 쌓이는 한 바퀴 동안 한 번도 겹치지 않음',
           r['cycDup'] == 0 and r['cycUniq'] == r['n'], '중복 %d' % r['cycDup'])
        # 저작권: 책 문장을 출처와 함께 그대로 담지 않는다 (원장 설명 원칙)
        ck('출처를 붙인 인용문이 섞이지 않음 (책 문장 그대로 담기 금지)',
           not r['withCite'], r['withCite'][:2])
        ck('한 줄 코멘트는 인용문으로 갈라지지 않음',
           r['split1']['quote'] == '' and r['split1']['main'] != '', r['split1'])

        print()
        print('  [참고] 문장 %d편 · 길이 %d~%d자 · 한 바퀴 %d회 무중복'
              % (r['n'], r['minLen'], r['maxLen'], r['cycUniq']))
        for x in r['again'][:3]:
            print('  [본보기] ' + x)
        if errs:
            fails.append('JS 오류 %d건' % len(errs))
            print('  실패 JS 오류: %s' % errs[:2])
        b.close()
    srv.shutdown()

    print('-' * 62)
    if fails:
        print('  실패 %d건 — 배포 금지' % len(fails))
        return 1
    print('  13항목 전부 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
