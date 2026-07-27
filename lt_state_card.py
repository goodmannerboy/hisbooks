# -*- coding: utf-8 -*-
# v32.910 — 신규진단 레벨테스트 카드 상태 기반 재설계 (시안 v2 컨펌) + 주소 기입란 제거
# · 스캔 전: 수기 8칸·버튼들 제거 → 드롭존 하나 (끌어놓기/클릭, 즉시 채점)
# · 스캔 후: 같은 자리가 결과 요약(총점/판정/D지수 칩 + 영역 바 + 약점 강조)으로 전환
#   [문항별 확인·수정](기존 도구) · [다시 스캔]. 기존 수기 데이터(legacy)는 바만 표시.
# · 과목 자동 추론: subject가 기본값(중등)일 때 학교/학년 문자열로 초/고 자동 전환
import json, re, sys
sys.stdout.reconfigure(encoding='utf-8')

with open('index.html', encoding='utf-8') as f:
    raw = f.read()
ts = re.search(r'<script[^>]*type="__bundler/template"[^>]*>', raw).end()
te = raw.find('</script>', ts)
html = json.loads(raw[ts:te])

# ── 1) lt 카드: 스트립+상태줄+수기 8칸 블록 → 상태 기반 마크업 ──────────
S0 = '<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;background:#FBF9F0;border:1px solid var(--gold-300);border-radius:11px;padding:9px 13px;margin-bottom:12px;"><span style="font-size:12.5px;font-weight:800;color:#8a6520;flex:none;">OMR 스캔</span>'
i0 = html.index(S0)
FOR = '<sc-for list="{{ ltRows }}" as="r" hint-placeholder-count="4">'
ifor = html.index(FOR, i0)
iend = html.index('</sc-for>', ifor)
iend = html.index('</div>', iend) + len('</div>')   # rows 컬럼 div 닫힘까지
NEW = (
  '<sc-if value="{{ ltNoResult }}" hint-placeholder-val="{{ false }}">'
  '<label ondragover="{{ onDragOverBind }}" ondrop="{{ onLtOmrDropBind }}" '
  'style="display:block;border:1.5px dashed rgba(12,70,49,.35);border-radius:12px;background:#FBF9F0;'
  'padding:26px 16px;text-align:center;cursor:pointer;position:relative;">'
  '<div style="font-size:14.5px;font-weight:800;color:#0C4631;">OMR 카드를 끌어다 놓거나 눌러서 올리기</div>'
  '<div style="font-size:11.5px;color:#9a9482;margin-top:5px;">이미지·PDF · 올리는 즉시 위 과목 기준으로 자동 채점됩니다</div>'
  '<input type="file" accept="image/*,application/pdf,.pdf" onchange="{{ onLtOmrFilesBind }}" '
  'style="position:absolute;left:0;top:0;width:100%;height:100%;opacity:0;cursor:pointer;">'
  '</label></sc-if>'
  '<sc-if value="{{ ltHasResult }}" hint-placeholder-val="{{ false }}">'
  '<sc-if value="{{ ltResShow }}" hint-placeholder-val="{{ false }}">'
  '<div style="display:flex;gap:8px;margin-bottom:10px;">'
  '<div style="flex:1;background:var(--green-700);border-radius:10px;padding:9px 6px;text-align:center;">'
  '<div style="font-size:10.5px;font-weight:700;color:#9FE1CB;">총점</div>'
  '<div style="font-size:21px;font-weight:800;color:#F4ECD7;line-height:1.25;">{{ ltResTotal }}'
  '<span style="font-size:11px;font-weight:600;color:#9FE1CB;"> /100</span></div></div>'
  '<div style="flex:1;background:#fff;border:1px solid rgba(12,70,49,.2);border-radius:10px;padding:9px 6px;text-align:center;">'
  '<div style="font-size:10.5px;font-weight:700;color:#8a6520;">판정 레벨</div>'
  '<div style="font-size:21px;font-weight:800;color:#0C4631;line-height:1.25;">{{ ltResLevel }}</div></div>'
  '<div style="flex:1;background:#fff;border:1px solid rgba(12,70,49,.2);border-radius:10px;padding:9px 6px;text-align:center;">'
  '<div style="font-size:10.5px;font-weight:700;color:#8a6520;">D지수</div>'
  '<div style="font-size:21px;font-weight:800;color:#0C4631;line-height:1.25;">{{ ltResD }}'
  '<span style="font-size:11px;font-weight:600;color:#9a9482;"> /10</span></div></div>'
  '</div></sc-if>'
  '<div style="display:flex;flex-direction:column;gap:7px;margin-bottom:12px;">'
  '<sc-for list="{{ ltResBars }}" as="b" hint-placeholder-count="4">'
  '<div style="display:flex;align-items:center;gap:8px;">'
  '<span style="width:34px;flex:none;font-size:12.5px;font-weight:700;color:#0C4631;">{{ b.name }}</span>'
  '<div style="flex:1;height:7px;background:#e8e0c9;border-radius:4px;overflow:hidden;">'
  '<div style="height:7px;border-radius:4px;width:{{ b.w }};background:{{ b.color }};"></div></div>'
  '<span style="width:58px;flex:none;text-align:right;font-size:12px;font-weight:700;color:{{ b.tcolor }};">{{ b.label }}</span>'
  '</div></sc-for></div>'
  '<div style="display:flex;gap:8px;">'
  '<button onclick="{{ onLtOpenGradeBind }}" style="flex:1;border:1px solid rgba(12,70,49,.3);background:#fff;'
  'color:#0C4631;border-radius:9px;padding:9px;font-size:12.5px;font-weight:700;cursor:pointer;font-family:inherit;">문항별 확인·수정</button>'
  '<label style="flex:1;border:1.5px solid #C9A227;background:#F4ECD7;color:#8a6a18;border-radius:9px;'
  'padding:9px;font-size:12.5px;font-weight:700;cursor:pointer;font-family:inherit;text-align:center;position:relative;">다시 스캔'
  '<input type="file" accept="image/*,application/pdf,.pdf" onchange="{{ onLtOmrFilesBind }}" '
  'style="position:absolute;left:0;top:0;width:100%;height:100%;opacity:0;cursor:pointer;"></label>'
  '</div></sc-if>'
  '<sc-if value="{{ ltOmrStatus }}" hint-placeholder-val="{{ false }}">'
  '<div style="font-size:12px;font-weight:800;color:#0C4631;margin-top:10px;line-height:1.4;">{{ ltOmrStatus }}</div></sc-if>')
html = html[:i0] + NEW + html[iend:]

# ── 2) 주소 기입란 제거 ────────────────────────────────────────────────
ADDR = ('<x-import component-from-global-scope="HISLanguageInstituteDesignSystem_25592e.Input" '
        'label="주소" value="{{ iAddress }}" on-input="{{ oIAddress }}" placeholder="동 / 아파트" '
        'hint-size="100%,68px"></x-import>')
assert html.count(ADDR) == 1, '주소 필드 앵커'
html = html.replace(ADDR, '', 1)

# ── 3) rv 추가 ────────────────────────────────────────────────────────
RV = "onLtOpenGradeBind: (() => this.onLtOpenGrade()), ltOmrStatus: (S.ltOmrStatus || ''),"
assert html.count(RV) == 1, 'rv 앵커'
html = html.replace(RV, RV +
  " onLtOmrDropBind: ((e) => { try { e.preventDefault(); } catch (_e) {} this.onLtOmrFiles(e); }),"
  " ltHasResult: !!(liveLt && liveLt.hasData), ltNoResult: !(liveLt && liveLt.hasData),"
  " ltResShow: !!S.ltOmrRes,"
  " ltResTotal: (S.ltOmrRes ? String(S.ltOmrRes.total) : ''),"
  " ltResLevel: (S.ltOmrRes ? S.ltOmrRes.level : ''),"
  " ltResD: (S.ltOmrRes ? String(S.ltOmrRes.d) : ''),"
  " ltResBars: [['듣기', 'listen'], ['어휘', 'vocab'], ['문법', 'grammar'], ['독해', 'read']].map(([nm, k]) => {"
  " const c = this.num(iD.lt[k + 'C']), t = this.num(iD.lt[k + 'T']);"
  " const p = (c != null && t) ? Math.round(c / t * 100) : 0; const weak = p < 50;"
  " return { name: nm, w: p + '%', color: (weak ? '#D85A30' : '#1F8A5B'),"
  " tcolor: (weak ? '#993C1D' : '#5F5E5A'), label: (c == null ? '–' : c) + '/' + (t == null ? '–' : t) + (weak ? ' 약점' : '') }; }),", 1)

# ── 4) 메서드 보강: 과목 자동 추론 + 결과 상태 저장 ────────────────────
A1 = "const subj = (((this.state.intakeDraft || {}).lt || {}).subject) || '중등'; "
assert html.count(A1) == 1, '_ltApplyOmr subj 앵커'
html = html.replace(A1,
  "let subj = (((this.state.intakeDraft || {}).lt || {}).subject) || '중등'; "
  "const _sg = ((this.state.intakeDraft || {}).schoolGrade) || ''; "
  "if (subj === '중등') { if (/초/.test(_sg)) subj = '초등'; else if (/고/.test(_sg)) subj = '고등'; } "
  "this.setIntakeLt('subject', subj); ", 1)

A2 = "this.setState({ ltOmrStatus: '자동 입력 완료 — 총점 '"
assert html.count(A2) == 1, '결과 상태 앵커'
html = html.replace(A2,
  "this.setState({ ltOmrRes: { total: total, level: level, d: d }, ltOmrStatus: '자동 입력 완료 — 총점 '", 1)

new_json = json.dumps(html, ensure_ascii=False).replace('</', '<\\/')
assert new_json.count('</script') == 0
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(raw[:ts] + new_json + raw[te:])
print('DONE v32.910 — 상태 기반 레벨테스트 카드 + 주소 기입란 제거')
