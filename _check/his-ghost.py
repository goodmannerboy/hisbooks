# -*- coding: utf-8 -*-
# v33.218 학생 되살아남 구조 수리 — ① 일괄 등록이 퇴원·보관함 이력 학생을 다시 만들지 않음 ③ 시계가 어긋난 기기의 «되살리기» 뒤에도 삭제가 이김(실제 mergeAppData)
import io, sys, os, threading, functools, http.server, socketserver, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
from playwright.sync_api import sync_playwright
ROOT = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\User\Desktop\C\hisbooks'
_H = open(r'C:\Users\User\Desktop\C\hisbooks\_check\his-seed.py', encoding='utf-8').read()
W = _H[_H.find("FIBER = '''") + 11:]; W = W[:W.find("'''")]
fails = []


def ck(name, ok, extra=''):
    print(('  OK  ' if ok else '  실패 ') + name + (('   ' + str(extra)[:500]) if (extra and not ok) else ''))
    if not ok:
        fails.append(name)


class Qh(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


socketserver.TCPServer.allow_reuse_address = True
while True:
    srv = socketserver.TCPServer(('127.0.0.1', 0), functools.partial(Qh, directory=ROOT))
    if srv.server_address[1] > 1024 and srv.server_address[1] not in {2049, 3659, 4045, 5060, 5061, 6000, 6566, 6665, 6666, 6667, 6668, 6669, 6697, 10080}:
        break
    srv.server_close()
threading.Thread(target=srv.serve_forever, daemon=True).start()
SEED = r"""()=>{const L=window.__L; const d=JSON.parse(JSON.stringify(L.state.data)); d.staff={};
  d.classes=[{ id:'C1', name:'히즈동지H2', owner:'Dana', schedule:{days:[],times:{}}, students:[
      { id:'m1', name:'민혜원', school:'포항동지여자고등학교 2학년', registeredAt:'2025.03.02' },
      { id:'w1', name:'최민경', school:'포항동지여자고등학교 2학년', registeredAt:'2025.03.02', withdrawn:true, withdrawnAt:'2026.07.31', wdT:5 } ] },
    { id:'C2', name:'포항동지여고 2학년', owner:'', schedule:{days:[],times:{}}, students:[] }];
  d.leftStudents=[{ id:'x9', name:'소승현', cls:'히즈동지H2', owner:'Dana', withdrawnAt:'2026.08.10', leftAt:'2026.08.20', snap:{ id:'x9', name:'소승현', school:'포항동지여고' } }];
  d.records=[]; d.exams=[]; d.examSets=[]; d.checkins={};
  L.setState({ data:d, currentUser:'관리자', activeClassId:'C2', view:'manage', rosterPaste:'' });
  const g=document.getElementById('cloud-gate'); if(g)g.remove(); try{ localStorage.setItem('his-fix932','1'); }catch(e){} return 1; }"""
with sync_playwright() as p:
    br = p.chromium.launch(args=['--disable-audio-output'])
    pg = br.new_page(viewport={'width': 1440, 'height': 900}); errs = []
    pg.on('pageerror', lambda x: errs.append(str(x)[:200]))
    pg.goto('http://127.0.0.1:%d/index.html' % srv.server_address[1], wait_until='networkidle'); pg.wait_for_timeout(2500)
    for _ in range(20):
        if pg.evaluate(W):
            break
        pg.wait_for_timeout(500)
    pg.evaluate(SEED); pg.wait_for_timeout(1000)
    print('=' * 60); print(' 학생 되살아남 구조 수리 — ' + ROOT[-24:]); print('=' * 60)
    TAB = '\t'
    paste = '\n'.join(['민혜원' + TAB + '포항동지여고' + TAB + '196', '최민경' + TAB + '포항동지여고' + TAB + '29', '소승현' + TAB + '포항동지여고' + TAB + '43', '새학생' + TAB + '포항동지여고' + TAB + '0'])
    rows = pg.evaluate("(t)=>{ const L=window.__L; L.setState({ rosterPaste:t }); return L.parseRoster(t).map(r=>r.name); }", paste); pg.wait_for_timeout(500)
    print('   붙여넣은 명단:', rows)
    pg.evaluate("()=>{ window.__L.renderVals().addRoster(); return 1; }"); pg.wait_for_timeout(1000)
    st = pg.evaluate("()=>{ const L=window.__L; const c=(L.state.data.classes||[]).find(x=>x.id==='C2'); return { names:(c.students||[]).map(s=>s.name), msg:L.state.status }; }")
    print('   결과:', st)
    ck('① 퇴원생 최민경 · 보관함 소승현은 새로 만들어지지 않음', '최민경' not in st['names'] and '소승현' not in st['names'], st)
    ck('① 재원 중인 민혜원도 건너뜀(기존 가드) · 정말 새 학생만 등록', st['names'] == ['새학생'], st)
    ck('① 안내에 «퇴원·보관함 이력이 있어 건너뜀 2명» + 되살리기 안내', '퇴원·보관함 이력이 있어 건너뜀 2명' in st['msg'] and '되살리기' in st['msg'], st['msg'])
    # ③ 실제 mergeAppData 로: 시계가 1시간 빠른 기기에서 되살린 기록이 있어도, 그 뒤의 삭제가 이긴다
    r3 = pg.evaluate(r"""()=>{ const L=window.__L; const M=window.__hisMergeAppData; if(!M) return { err:'no merge' };
      const future=Date.now()+3600000;
      const stale={ classes:[{ id:'C2', name:'포항동지여고 2학년', students:[{ id:'g1', name:'최민경', school:'포항동지여고' }] }], restoredStudents:['g1'], stuResT:{ g1: future }, deletedStudents:[], leftStudents:[] };
      L.setState({ data: Object.assign({}, JSON.parse(JSON.stringify(stale)), { records:[], exams:[], examSets:[], checkins:{} }), activeClassId:'C2' });
      return 1; }"""); pg.wait_for_timeout(600)
    pg.evaluate("()=>{ window.__L.removeStudent('C2','g1'); return 1; }"); pg.wait_for_timeout(800)
    r3 = pg.evaluate(r"""()=>{ const L=window.__L; const M=window.__hisMergeAppData; const mine=JSON.parse(JSON.stringify(L.state.data));
      const future=mine.stuResT ? mine.stuResT.g1 : 0;
      const other={ classes:[{ id:'C2', name:'포항동지여고 2학년', students:[{ id:'g1', name:'최민경', school:'포항동지여고' }] }], restoredStudents:['g1'], stuResT:{ g1: future }, deletedStudents:[], leftStudents:[] };
      const a=M(other, mine), b=M(mine, other);
      const has=(o)=>((o.classes||[]).some(c=>(c.students||[]).some(s=>s.id==='g1')));
      return { delT: mine.stuDelT.g1, resT: future, gt: mine.stuDelT.g1 > future, aHas: has(a), bHas: has(b) }; }""")
    print('   도장:', r3)
    ck('③ 삭제 도장이 (시계가 빠른 기기의) 되살리기 도장보다 큼', r3.get('gt') is True, r3)
    ck('③ 두 방향 합치기 모두에서 삭제가 유지됨(되살아나지 않음)', r3.get('aHas') is False and r3.get('bHas') is False, r3)
    # ④ [뿌리] 저장 데이터가 빈 기기로 열어도 예시 반(포항동지여고 2학년 6명)이 생기지 않는다
    ctx2 = br.new_context(); pg2 = ctx2.new_page(); errs2 = []
    pg2.on('pageerror', lambda x: errs2.append(str(x)[:200]))
    pg2.goto('http://127.0.0.1:%d/index.html' % srv.server_address[1], wait_until='networkidle'); pg2.wait_for_timeout(2500)
    for _ in range(20):
        if pg2.evaluate(W):
            break
        pg2.wait_for_timeout(500)
    fresh = pg2.evaluate("()=>{ const d=window.__L.state.data; return { classes:(d.classes||[]).map(c=>c.name), names:[].concat.apply([], (d.classes||[]).map(c=>(c.students||[]).map(s=>s.name))) }; }")
    print('   빈 기기 첫 실행:', fresh)
    ck('④ 빈 기기로 열어도 예시 반·예시 학생이 만들어지지 않음', not any('포항동지여고' in c for c in fresh['classes']) and '최민경' not in fresh['names'] and '소승현' not in fresh['names'], fresh)
    r4 = pg2.evaluate(r"""()=>{ const M=window.__hisMergeAppData; const SEED=[['민혜원',196],['최민경',29],['박지우',19],['강보경',20],['소승현',43],['김지윤',49]];
      const seedCls=(tag)=>({ id:'seed'+tag, name:'포항동지여고 2학년', students:SEED.map((x,i)=>({ id:'g'+tag+i, name:x[0], school:'포항동지여고', startMileage:x[1] })) });
      const cloud={ classes:[{ id:'R1', name:'히즈 동지여H2_B.T', owner:'Benjamin', students:[{ id:'m1', name:'민혜원', school:'포항동지여자고등학교 2학년', startMileage:194 }] }], records:[{ classId:'R1', studentId:'m1', date:'2026.09.01' }], exams:[] };
      const oldDevice={ classes:[seedCls('A')], records:[], exams:[] };
      const has=(o,nm)=>((o.classes||[]).some(c=>c.name===nm));
      const a=M(cloud, oldDevice), b=M(oldDevice, cloud);
      const realSame={ classes:[{ id:'R9', name:'포항동지여고 2학년', owner:'Joey', students:[{ id:'r1', name:'최민경', school:'포항동지여고', startMileage:29, registeredAt:'2026.09.01' }] }], records:[], exams:[] };
      const c=M(cloud, realSame);
      const usedSeed={ classes:[seedCls('B')], records:[{ classId:'seedB', studentId:'gB1', date:'2026.09.02' }], exams:[] };
      const d2=M(cloud, usedSeed);
      return { aGhost:has(a,'포항동지여고 2학년'), bGhost:has(b,'포항동지여고 2학년'), aReal:has(a,'히즈 동지여H2_B.T'), realKept:has(c,'포항동지여고 2학년'), usedKept:has(d2,'포항동지여고 2학년') }; }""")
    print('   합치기:', r4)
    ck('④ 옛 버전 기기가 예시 반을 올려도 합칠 때 걸러짐(양방향) · 진짜 반은 그대로', r4['aGhost'] is False and r4['bGhost'] is False and r4['aReal'] is True, r4)
    ck('④ 이름만 같은 진짜 반(등록일 있는 학생)은 지우지 않음', r4['realKept'] is True, r4)
    ck('④ 예시 학생에 기록이 연결돼 있으면 지우지 않음(자료 보호)', r4['usedKept'] is True, r4)
    ck('④ 빈 기기 JS오류 없음', not errs2, errs2[:3])
    ctx2.close()
    ck('JS오류 없음', not errs, errs[:3])
    br.close()
srv.shutdown()
print('실패', len(fails), fails)
print('판정:', 'PASS' if not fails else 'FAIL')
