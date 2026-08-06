# -*- coding: utf-8 -*-
"""
히즈북스 동기화 전수 검사 (his-sync)
------------------------------------
이번 사고들(등록 확정 되돌아감·퇴원 예정 증발·공지 중복)의 뿌리는 전부 하나 —
«기기 간 합치기»였습니다. 이 검사는 index.html 에서 실제 병합 코드 두 벌
(mergeAppData = 올릴 때 / _absorbFresh = 받을 때)을 그대로 꺼내 실행하며,
등록·퇴원의 전체 수명주기를 다기기 시나리오로 확인합니다.

    py _check/his-sync.py

하나라도 실패하면 배포하지 마세요.
"""
import io, os, re, sys, json

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(os.path.dirname(HERE), 'index.html')

from playwright.sync_api import sync_playwright


def payload():
    h = open(APP, encoding='utf-8').read()
    mark = '<script type="__bundler/template">'
    j = h.find(mark) + len(mark)
    while h[j] in ' \n\r\t':
        j += 1
    v, _ = json.JSONDecoder().raw_decode(h, j)
    return v


def balanced(v, start_kw):
    i = v.find(start_kw)
    assert i >= 0, start_kw
    p = v.find('{', i + len(start_kw) - 1)
    d, q = 0, p
    while q < len(v):
        if v[q] == '{':
            d += 1
        elif v[q] == '}':
            d -= 1
            if d == 0:
                break
        q += 1
    return i, p, q


def build_js(v):
    a, _, b = balanced(v, 'function mergeAppData')
    i0 = v.find('function _hisClone')
    merge = v[i0:b + 1]
    i, p, q = balanced(v, '_absorbFresh(fresh){')
    body = v[p + 1:q]
    absorb = ('const __T={ state:{data:null}, setState:function(f,cb){ const r=f(this.state);'
              ' if(r&&r.data) this.state.data=r.data; } };'
              ' __T._absorbFresh=function(fresh){' + body + '}; window.__T=__T;')
    return merge + ';' + absorb


SC = """
const cls=(s)=>({classes:[{id:'C1',name:'A반',students:[JSON.parse(JSON.stringify(s))]}]});
const stu=(m)=>m.classes[0].students[0];
const pull=(cloud, local)=>{ __T.state.data=JSON.parse(JSON.stringify(local));
  __T._absorbFresh(JSON.parse(JSON.stringify(cloud))); return __T.state.data; };
const Y={id:'y1',name:'최윤영',intake:{date:'2026.07.28',classPick:'CX'}};
const mk=(ex)=>Object.assign(JSON.parse(JSON.stringify(Y)), ex);
const R=[];
const T=(name, ok)=>R.push([name, !!ok]);

// ① 확정(도장 있음) vs 옛 대기(도장 없음) — 양방향
{ const c=cls(mk({pending:true})), m=cls(mk({registeredAt:'2026.08.04',startPlan:'2026.08.04',enrT:5000}));
  T('확정이 옛 대기를 이김 (올릴 때)', !stu(mergeAppData(c,m)).pending);
  T('확정이 옛 대기를 이김 (반대 방향)', !stu(mergeAppData(m,c)).pending); }

// ② 실제 사고: 대기 사본의 상담 도장이 더 최신이어도 확정 유지
{ const c=cls(mk({pending:true,intakeT:9999})), m=cls(mk({registeredAt:'2026.08.04',startPlan:'2026.08.04',intakeT:1000,enrT:5000}));
  T('상담 도장이 더 최신인 대기 사본에도 확정 유지', !stu(mergeAppData(c,m)).pending && stu(mergeAppData(c,m)).startPlan==='2026.08.04'); }

// ③ 시작일 수정(새 도장) vs 깨진 옛 날짜
{ const c=cls(mk({registeredAt:'2026.08.29',startPlan:'2026.08.29',enrT:5000})),
        m=cls(mk({registeredAt:'2026.08.04',startPlan:'2026.08.04',enrT:7000}));
  T('시작일 수정이 옛 날짜(8/29)를 이김', stu(mergeAppData(c,m)).startPlan==='2026.08.04');
  T('반대 방향도 동일', stu(mergeAppData(m,c)).startPlan==='2026.08.04'); }

// ④ 정당한 «접수대기로 되돌리기»(더 새 도장)는 이겨야 함
{ const c=cls(mk({registeredAt:'2026.08.04',enrT:5000})), m=cls(mk({pending:true,enrT:9000}));
  T('되돌리기(새 도장)는 확정을 이김', !!stu(mergeAppData(c,m)).pending); }

// ⑤ 퇴원 예정 왕복 생존
{ const c=cls(mk({})), m=cls(mk({withdrawPlanned:{date:'2026.08.20',reason:'전학'},wdT:5000}));
  T('퇴원 예정 생존 (올릴 때)', !!stu(mergeAppData(c,m)).withdrawPlanned);
  T('퇴원 예정 생존 (반대 방향)', !!stu(mergeAppData(m,c)).withdrawPlanned); }

// ⑥ 되살리기(새 도장)가 옛 퇴원을 이김
{ const c=cls(mk({withdrawn:true,withdrawnAt:'2026.07.01',wdT:5000})), m=cls(mk({withdrawn:false,wdT:9000}));
  T('되살리기가 옛 퇴원 기록을 이김', stu(mergeAppData(c,m)).withdrawn===false);
  T('반대 방향도 동일', stu(mergeAppData(m,c)).withdrawn===false); }

// ⑦ 구버전 기기 오염: 도장까지 복사된 대기 사본(동률) — 확정 유지
{ const c=cls(mk({pending:true,enrT:5000})), m=cls(mk({registeredAt:'2026.08.04',enrT:5000}));
  T('도장 동률 오염 사본에도 확정 유지 (올릴 때)', !stu(mergeAppData(c,m)).pending);
  T('받을 때도 이 기기 상태 유지', !stu(pull(c,m)).pending); }

// ⑧ 받을 때: 옛 대기 클라우드가 확정을 못 덮음
{ const got=pull(cls(mk({pending:true})), cls(mk({registeredAt:'2026.08.04',startPlan:'2026.08.04',enrT:5000})));
  T('받을 때 확정 유지 + 시작일 보존', !stu(got).pending && stu(got).startPlan==='2026.08.04'); }

// ⑨ 받을 때: 다른 기기의 정당한 되돌리기(새 도장)는 받아들임
{ const got=pull(cls(mk({pending:true,enrT:9000})), cls(mk({registeredAt:'2026.08.04',enrT:5000})));
  T('다른 기기의 최신 되돌리기는 수용', !!stu(got).pending); }

// ⑩ 전체 왕복: A 확정 → 올림 → B 받음
{ const cloud0=cls(mk({pending:true}));
  const afterPush=mergeAppData(cloud0, cls(mk({registeredAt:'2026.08.04',startPlan:'2026.08.04',enrT:5000})));
  const b=pull(afterPush, cls(mk({pending:true})));
  T('왕복: B 기기에서도 확정으로 보임', !stu(b).pending && stu(b).startPlan==='2026.08.04'); }


// ⑪ 반 이동 유령 — 실제 최윤영 사고 재현
{ const cloud={classes:[
    {id:'CW',name:'미배정',students:[mk({pending:true})]},
    {id:'CX',name:'히즈 M2C',students:[]}]};
  const mine={classes:[
    {id:'CW',name:'미배정',students:[]},
    {id:'CX',name:'히즈 M2C',students:[mk({registeredAt:'2026.08.04',startPlan:'2026.08.04',enrT:5000})]}]};
  mine.stuClass={y1:{cid:'CX',t:5000}};
  const m=mergeAppData(JSON.parse(JSON.stringify(cloud)), JSON.parse(JSON.stringify(mine)));
  const ghost=(m.classes[0].students||[]).filter(s=>s.id==='y1');
  const real=(m.classes[1].students||[]).filter(s=>s.id==='y1');
  T('반 이동 후 옛 반에 유령이 안 남음 (올릴 때)', ghost.length===0 && real.length===1 && !real[0].pending);
  const m2=mergeAppData(JSON.parse(JSON.stringify(mine)), JSON.parse(JSON.stringify(cloud)));
  T('반대 방향도 유령 없음', (m2.classes[0].students||[]).filter(s=>s.id==='y1').length===0);
  __T.state.data=JSON.parse(JSON.stringify(mine));
  __T._absorbFresh(JSON.parse(JSON.stringify(cloud)));
  const g3=__T.state.data;
  T('받을 때도 유령 없음 + 확정 유지',
    (g3.classes[0].students||[]).filter(s=>s.id==='y1').length===0 &&
    (g3.classes[1].students||[]).filter(s=>s.id==='y1').length===1 &&
    !((g3.classes[1].students||[]).filter(s=>s.id==='y1')[0].pending)); }

// ⑫ 정당한 반 이동(더 새 도장)은 반영
{ const a={classes:[{id:'CX',name:'X',students:[mk({registeredAt:'2026.08.04',enrT:1})]},{id:'CY',name:'Y',students:[]}],stuClass:{y1:{cid:'CX',t:1000}}};
  const b={classes:[{id:'CX',name:'X',students:[]},{id:'CY',name:'Y',students:[mk({registeredAt:'2026.08.04',enrT:1})]}],stuClass:{y1:{cid:'CY',t:9000}}};
  const m=mergeAppData(a,b);
  T('나중에 옮긴 반이 이김', (m.classes[1].students||[]).filter(s=>s.id==='y1').length===1 && (m.classes[0].students||[]).filter(s=>s.id==='y1').length===0); }

// ⑬ 도장 없는 옛 데이터: 유령(대기 사본)이 확정 사본과 공존 → 확정만 남아야
{ const cloud={classes:[
    {id:'CW',name:'미배정',students:[mk({pending:true})]},
    {id:'CX',name:'히즈 M2C',students:[mk({registeredAt:'2026.08.04'})]}]};
  const m=mergeAppData(JSON.parse(JSON.stringify(cloud)), JSON.parse(JSON.stringify(cloud)));
  const g=(m.classes[0].students||[]).filter(s=>s.id==='y1');
  const r=(m.classes[1].students||[]).filter(s=>s.id==='y1');
  T('도장 없어도 유령 자동 정리', g.length===0 && r.length===1 && !r[0].pending); }

// ⑭ [실제 8/3 사고] 같은 내부번호를 «다른 학생»이 공유 — 필드가 섞이면 안 됨
{ const cloud={classes:[{id:'CA',name:'동지반',students:[{id:'dup1',name:'민혜원',registeredAt:'2025.03.02'}]}]};
  const mine ={classes:[{id:'CA',name:'동지반',students:[{id:'dup1',name:'민혜원',registeredAt:'2025.03.02'}]},
    {id:'CX',name:'히즈 M2C',students:[{id:'dup1',name:'최영서',registeredAt:'2026.08.04',startPlan:'2026.08.04',enrT:9000}]}]};
  mine.stuClass={dup1:{cid:'CX',t:9000,nm:'최영서'}};
  const m=mergeAppData(JSON.parse(JSON.stringify(cloud)), JSON.parse(JSON.stringify(mine)));
  const old1=(m.classes[0].students||[]).filter(s=>s.id==='dup1')[0];
  const new1=((m.classes[1]||{}).students||[]).filter(s=>s.id==='dup1')[0];
  T('기존 학생에게 남의 시작일이 안 옮겨붙음', old1 && old1.name==='민혜원' && !old1.startPlan);
  T('신규 학생(다른 이름)은 지워지지 않음', !!new1 && new1.name==='최영서' && new1.startPlan==='2026.08.04');
  __T.state.data=JSON.parse(JSON.stringify(mine));
  __T._absorbFresh(JSON.parse(JSON.stringify(cloud)));
  const g=__T.state.data; const o2=(g.classes[0].students||[]).filter(s=>s.id==='dup1')[0];
  T('받을 때도 기존 학생이 오염 안 됨', o2 && o2.name==='민혜원' && !o2.startPlan); }

// ⑮ 유령 반 — 삭제한 반이 «학생을 담은 옛 사본»으로 되살아나면 안 된다 (v33.059)
{ const gone={classes:[{id:'GH',name:'포항동지여고 2학년',students:[
      {id:'g1',name:'민혜원',registeredAt:'2025.03.02'},{id:'g2',name:'최민경',registeredAt:'2025.03.02'}]},
    {id:'OK1',name:'현재반',students:[{id:'k1',name:'홍길동',registeredAt:'2025.03.02'}]}]};
  const mine={classes:[{id:'OK1',name:'현재반',students:[{id:'k1',name:'홍길동',registeredAt:'2025.03.02'}]}],
    deletedClasses:['GH'], leftStudents:[]};
  const m=mergeAppData(JSON.parse(JSON.stringify(gone)), JSON.parse(JSON.stringify(mine)));
  const ids=(m.classes||[]).map(c=>c.id);
  T('올릴 때 — 삭제한 반이 학생을 담고 있어도 되살아나지 않음', ids.indexOf('GH')<0);
  T('올릴 때 — 다른 반은 그대로', ids.indexOf('OK1')>=0);
  T('올릴 때 — 안에 있던 학생은 보관함에 보존(되살리기 가능)',
    ((m.leftStudents||[]).filter(x=>x&&(x.id==='g1'||x.id==='g2')).length)===2);
  // 반대 방향(내가 옛 사본, 클라우드가 삭제 표식) 도 동일해야
  const m2=mergeAppData(JSON.parse(JSON.stringify(mine)), JSON.parse(JSON.stringify(gone)));
  T('순서 무관 — 반대로 합쳐도 되살아나지 않음', (m2.classes||[]).map(c=>c.id).indexOf('GH')<0);
  // 받을 때(12초 폴링)도 표식이 지켜져야
  __T.state.data=JSON.parse(JSON.stringify(mine));
  __T._absorbFresh(JSON.parse(JSON.stringify(gone)));
  const g3=__T.state.data;
  T('받을 때 — 삭제한 반이 되살아나지 않음', (g3.classes||[]).map(c=>c.id).indexOf('GH')<0);
  T('받을 때 — 안에 있던 학생은 보관함에 보존',
    ((g3.leftStudents||[]).filter(x=>x&&(x.id==='g1'||x.id==='g2')).length)===2); }

return R;
"""


def main():
    v = payload()
    js = build_js(v)
    print('=' * 62)
    print(' 히즈북스 동기화 전수 검사 (실제 병합 코드로 실행)')
    print('=' * 62)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()
        pg.set_content('<html><body></body></html>')
        pg.add_script_tag(content=js)
        rows = pg.evaluate('()=>{' + SC + '}')
        b.close()
    fails = 0
    for name, ok in rows:
        print(('  OK  ' if ok else '  실패 ') + name)
        if not ok:
            fails += 1
    print('-' * 62)
    if fails:
        print('  실패 %d건 — 배포 금지' % fails)
        return 1
    print('  %d항목 전부 통과' % len(rows))
    return 0


if __name__ == '__main__':
    sys.exit(main())
