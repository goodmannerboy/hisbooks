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
    ck('JS오류 없음', not errs, errs[:3])
    br.close()
srv.shutdown()
print('실패', len(fails), fails)
print('판정:', 'PASS' if not fails else 'FAIL')
