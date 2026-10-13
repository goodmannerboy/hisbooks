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

둘째 부분(월말 종합 코멘트 — 월간 탭): 명단에서 쓰는 학생 줄만 펼쳐지고, «전송 완료하고 다음»(Ctrl+Enter)이
  · 지금 칸의 글을 저장하고 전송 완료로 표시한 뒤 아직 안 보낸 다음 학생으로 가는가
  · 빈 코멘트는 막지 않고 한 번만 묻는가 · 방금 한 표시를 되돌릴 수 있는가
  · 수업 기록이 없는 학생은 전송 표시를 하지 않는가 · 새 자료 칸을 만들지 않는가

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

  // 한 바퀴 = 한 학생이 한 번도 겹치지 않는 수업 횟수(_cmtHorizon — 통째로 쓴 문장 수 × 4). 문장은 통째로 쓴 것 + 엮어 만드는 것(묶음마다 앞 × 뒤)
  const HZ=(L._cmtHorizon ? L._cmtHorizon() : pool.length);
  const cyc={}; let dup=0; const D2=JSON.parse(JSON.stringify(D)); const first40=[];
  for(let i=0;i<HZ;i++){
    D2.records=[]; for(let k=0;k<i;k++) D2.records.push({id:'x'+k,classId:'C1',studentId:'s1',date:'2026.01.01',attendance:'출석'});
    const t=L._cmtDraft('김민준', base(), D2, 's1', dt, 1);
    if(cyc[t]) dup++; cyc[t]=1; if(i<40) first40.push(t); }
  const B=(L._cmtBank ? L._cmtBank() : { W:pool, G:[] }); const isW={}; B.W.forEach(function(x){ isW[x]=1; });
  const gOk=(B.G.length>0 && B.G.every(function(g){ return g[0].length===B.G[0][0].length && g[1].length===B.G[0][1].length && g[0].length>=10 && g[1].length>=10; }));
  const wIn40=first40.filter(function(x){ return !!isW[x]; }).length;

  // 이미 저장된 적 있는 문장은 건너뛴다 — 어제 «다시 눌러» 고른 문장(= 오늘 첫 추천이 될 문장)이 오늘 또 나오지 않게
  const D3=JSON.parse(JSON.stringify(D)); D3.records.push({id:'u1',classId:'C1',studentId:'s1',date:'2026.08.27',attendance:'출석',comment:''});
  const tA=L._cmtDraft('김민준', base(), D3, 's1', dt, 1); const tB=L._cmtDraft('김민준', base(), D3, 's1', dt, 2);
  const D4=JSON.parse(JSON.stringify(D3)); D4.records[D4.records.length-1].comment=tA+' 오늘도 애썼어.';
  const tC=L._cmtDraft('김민준', base(), D4, 's1', dt, 1); const tD=L._cmtDraft('김민준', base(), D4, 's1', dt, 2);
  const skipOk=(!!tA && tC!==tA && tC===tB && tD!==tC && tD!==tA);

  const uniqPool={}; let poolDup=0;
  pool.forEach(function(x){ if(uniqPool[x]) poolDup++; uniqPool[x]=1; });

  return { n:pool.length, pool:pool, same:same, again:again, three:three,
           cycUniq:Object.keys(cyc).length, cycDup:dup, poolDup:poolDup, hz:HZ, nW:B.W.length, nG:B.G.length, gOk:gOk, wIn40:wIn40, skipOk:skipOk, skip:[tA, tB, tC, tD],
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

# ── 둘째 부분: 월말 종합 코멘트(월간 탭) ────────────────────────────────
#   학생 셋(가나다: 김민준 s1 · 박서준 s3 · 이지혜 s2) — s2 는 이 달 수업 기록이 없다
SEED2 = """()=>{const L=window.__L; const d=JSON.parse(JSON.stringify(L.state.data));
  d.records=[]; const mk=(sid,day,g)=>({id:'m'+sid+day,classId:'C1',studentId:sid,date:'2026.08.'+day,attendance:'출석',homework:'완료',gS:String(g),gT:'100'});
  ['04','11','18'].forEach((dy)=>{ d.records.push(mk('s1',dy,70)); d.records.push(mk('s3',dy,90)); });
  d.monthlyComments={}; d.capSent={};
  window.__keys0=Object.keys(d).sort().join(',');
  L.setState({data:d,view:'monthly',activeClassId:'C1',monthlyMonth:'2026-08',monthlyActiveStudentId:null,moLeft:false,moMsg:null,_mDrafts:{},status:''});
  return 'ok';}"""
MO = """()=>{const L=window.__L; const S=L.state; const d=S.data; const m=(S.moMsg||{});
  return { order:(L._moL||[]).map((x)=>x.sid), has:(L._moL||[]).map((x)=>!!x.has), tas:document.querySelectorAll('textarea[data-monthly-comment]').length,
    act:String(L._mcapEff||''), cm:Object.assign({}, d.monthlyComments||{}), cap:Object.assign({}, d.capSent||{}), msg:String(m.t||''), bad:!!m.bad, undo:String(m.undo||''),
    keys:Object.keys(d).sort().join(','), keys0:String(window.__keys0||''), rows:document.querySelectorAll('[data-mo-row]').length }; }"""
MO_TYPE = """(t)=>{ const ta=document.querySelector('textarea[data-monthly-comment]'); if(!ta) return false; ta.value=t; window.__L.moNext(); return true; }"""

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
    print(' 히즈북스 코멘트 검사 — 일간 감성 한 줄 · 월말 종합 코멘트')
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
        pg.goto('http://127.0.0.1:%d/%s' % (port, os.environ.get('HIS_PAGE', 'index.html')), wait_until='networkidle')
        pg.wait_for_timeout(3000)
        for _ in range(12):
            if pg.evaluate(FIBER):
                break
            pg.wait_for_timeout(700)
        pg.evaluate(SEED)
        pg.wait_for_timeout(1500)
        r = pg.evaluate(RUN)

        ck('문장이 넉넉히 준비되어 있음 (3,000줄 이상 — 통째로 쓴 문장 240편 이상)', r['n'] >= 3000 and r['nW'] >= 240, (r['n'], r['nW']))
        ck('엮어 만드는 묶음마다 앞 문장·뒤 문장 수가 같음 (어느 묶음도 덜 돌지 않음)', r['gOk'], r['nG'])
        ck('네 번에 한 번은 통째로 쓴 문장 (처음 40번 중 10번)', r['wIn40'] == 10, r['wIn40'])
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
        ck('수업이 쌓이는 한 바퀴(%d번) 동안 한 번도 겹치지 않음 — 1,000번 이상' % r['hz'],
           r['cycDup'] == 0 and r['cycUniq'] == r['hz'] and r['hz'] >= 1000, '중복 %d · %d번' % (r['cycDup'], r['hz']))
        ck('그 학생에게 이미 저장된 문장은 다시 추천하지 않음 (다음 문장으로 넘어감)', r['skipOk'], r['skip'])
        # 저작권: 책 문장을 출처와 함께 그대로 담지 않는다 (원장 설명 원칙)
        ck('출처를 붙인 인용문이 섞이지 않음 (책 문장 그대로 담기 금지)',
           not r['withCite'], r['withCite'][:2])
        ck('한 줄 코멘트는 인용문으로 갈라지지 않음',
           r['split1']['quote'] == '' and r['split1']['main'] != '', r['split1'])

        # ── 둘째 부분: 월말 종합 코멘트(월간 탭)
        print()
        pg.evaluate(SEED2); pg.wait_for_timeout(1800); m = pg.evaluate(MO)
        ck('[월간] 명단은 가나다 차례 · 기록 없는 학생을 구분 · 코멘트 칸은 펼친 줄 하나(기록 있는 첫 학생)',
           m['order'] == ['s1', 's3', 's2'] and m['has'] == [True, True, False] and m['rows'] == 3 and m['tas'] == 1 and m['act'] == 's1', m)
        T9 = '이번 달도 성실하게 참여했습니다.'
        pg.evaluate(MO_TYPE, T9); pg.wait_for_timeout(900); m = pg.evaluate(MO)
        ck('[월간] «전송 완료하고 다음» = 지금 칸의 글 저장 + 전송 완료 표시 + 아직 안 보낸 다음 학생으로',
           m['cm'].get('s1|2026-08') == T9 and m['cap'].get('monthly|s1|2026-08') is True and m['act'] == 's3' and m['undo'] == 's1' and m['tas'] == 1, m)
        pg.evaluate("()=>{ window.__L.moNext(); return 1; }"); pg.wait_for_timeout(600); m1 = pg.evaluate(MO)
        pg.evaluate("()=>{ window.__L.moNext(); return 1; }"); pg.wait_for_timeout(900); m2 = pg.evaluate(MO)
        ck('[월간] 빈 코멘트는 막지 않고 한 번만 물음(처음엔 표시 안 함 → 한 번 더 누르면 넘어감)',
           m1['bad'] and (not m1['cap'].get('monthly|s3|2026-08')) and m1['act'] == 's3' and m2['cap'].get('monthly|s3|2026-08') is True and (not m2['bad']) and m2['undo'] == 's3', (m1, m2))
        pg.evaluate("()=>{ window.__L.moUndo(); return 1; }"); pg.wait_for_timeout(900); m = pg.evaluate(MO)
        ck('[월간] 방금 한 전송 완료 표시는 되돌릴 수 있음(그 학생으로 돌아감 · 앞 학생의 표시와 글은 그대로)',
           m['cap'].get('monthly|s3|2026-08') is False and m['cap'].get('monthly|s1|2026-08') is True and m['cm'].get('s1|2026-08') == T9 and m['act'] == 's3', m)
        pg.evaluate("()=>{ window.__L.moPick('s2'); return 1; }"); pg.wait_for_timeout(800)
        pg.evaluate(MO_TYPE, '미리 써 둔 글'); pg.wait_for_timeout(900); m = pg.evaluate(MO)
        ck('[월간] 수업 기록이 없는 학생은 글만 저장하고 전송 표시는 하지 않음 · 다음 안 보낸 학생으로',
           m['cm'].get('s2|2026-08') == '미리 써 둔 글' and ('monthly|s2|2026-08' not in m['cap']) and m['act'] == 's3', m)
        ck('[월간] 새 자료 칸을 만들지 않음(월말 코멘트 monthlyComments · 전송 표시 capSent 그대로)',
           m['keys'] == m['keys0'] and bool(m['keys0']), (m['keys'], m['keys0']))

        print()
        print('  [참고] 문장 %d줄(통째로 쓴 %d + 엮은 %d) · 길이 %d~%d자 · 한 바퀴 %d회 무중복'
              % (r['n'], r['nW'], r['n'] - r['nW'], r['minLen'], r['maxLen'], r['cycUniq']))
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
    print('  22항목 전부 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
