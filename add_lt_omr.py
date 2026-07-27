# -*- coding: utf-8 -*-
# v32.408 — 신규진단 레벨테스트에 OMR 스캔 자동 입력 (EXAM-GRADING-SPEC 4단계 1차)
# 스캔 업로드 → 판독(_omrReadCanvas 재사용) → 45문항 자동 채점(정답키 내장)
# → 영역별 정답수/문항수 8필드 setIntakeLt → 기존 통지서(#intakecap) 즉시 갱신.
import json, re, sys, io, os
sys.stdout.reconfigure(encoding='utf-8')

with open('index.html', encoding='utf-8') as f:
    raw = f.read()
ts = re.search(r'<script[^>]*type="__bundler/template"[^>]*>', raw).end()
te = raw.find('</script>', ts)
html = json.loads(raw[ts:te])

# ── 정답키 로드 (레벨테스트 소스에서 생성된 _keys.js) ─────────────────
keys_src = io.open(r'C:\Users\User\Desktop\히즈문서\레벨테스트\2026리뉴얼\src\_keys.js',
                   encoding='utf-8').read()
keys = json.loads(keys_src[keys_src.index('{'):keys_src.rindex('}') + 1])
LT_KEYS = {}
for form, subj in [('E', '초등'), ('M', '중등'), ('H', '고등')]:
    k = keys[form]
    LT_KEYS[subj] = {'key': k['key'], 'p3': k['p3'], 'anchor': k['anchor'], 'cuts': k['cuts']}
KEYS_JSON = json.dumps(LT_KEYS, ensure_ascii=False, separators=(',', ':'))

# ── 1) 메서드 추가 (onOmrPick 정의 바로 앞) ──────────────────────────
M_ANCHOR = "onOmrPick() { let inp = document.getElementById('__omrInput');"
assert html.count(M_ANCHOR) == 1, 'onOmrPick 앵커'
METHODS = (
  "_ltOmrKeys() { return " + KEYS_JSON + "; } "
  "_ltAreaOf(n) { return n <= 12 ? 'listen' : n <= 20 ? 'vocab' : n <= 31 ? 'grammar' : 'read'; } "
  "onLtOmrFiles(e) { "
  "const files = [].slice.call(this._evFiles(e)); if (!files.length) return; const self = this; "
  "self.setState({ ltOmrStatus: 'OMR 판독 중…' }); const f = files[0]; "
  "const finish = (cvs) => { let ok = false; (cvs || []).forEach((cv) => { if (ok || !cv) return; "
  "let r; try { r = self._omrReadCanvas(cv); } catch (err) { r = { bd: '', ans: {} }; } "
  "if (Object.keys(r.ans).length >= 10) { self._ltApplyOmr(r.ans, r.bd); ok = true; } }); "
  "if (!ok) self.setState({ ltOmrStatus: '카드를 읽지 못했습니다. 스캔을 확인하고 다시 올려 주세요.' }); }; "
  "const isPdf = ((f.type || '').indexOf('pdf') >= 0) || (/pdf$/i.test(f.name || '')); "
  "if (isPdf) { self._loadPdfLib().then((lib) => lib.getDocument({ url: URL.createObjectURL(f) }).promise)"
  ".then((pdf) => { const ps = []; for (let p = 1; p <= Math.min(pdf.numPages, 3); p++) { "
  "ps.push(pdf.getPage(p).then((page) => { const v1 = page.getViewport({ scale: 1 }); "
  "const vp = page.getViewport({ scale: Math.min(2.5, 1500 / v1.width) }); "
  "const cv = document.createElement('canvas'); cv.width = vp.width; cv.height = vp.height; "
  "return page.render({ canvasContext: cv.getContext('2d'), viewport: vp }).promise.then(() => cv).catch(() => null); "
  "}).catch(() => null)); } return Promise.all(ps); }).then(finish).catch(() => finish([])); } "
  "else { const img = new Image(); img.onload = () => { const MAXW = 1500, sc = Math.min(1, MAXW / img.width); "
  "const cv = document.createElement('canvas'); cv.width = Math.round(img.width * sc); cv.height = Math.round(img.height * sc); "
  "cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height); finish([cv]); }; "
  "img.onerror = () => finish([]); img.src = URL.createObjectURL(f); } } "
  "_ltApplyOmr(ans, bd) { "
  "const subj = (((this.state.intakeDraft || {}).lt || {}).subject) || '중등'; "
  "const K = this._ltOmrKeys()[subj] || this._ltOmrKeys()['중등']; "
  "const AT = { listen: 12, vocab: 8, grammar: 11, read: 14 }; "
  "const cnt = { listen: 0, vocab: 0, grammar: 0, read: 0 }; "
  "const pts = { listen: 0, vocab: 0, grammar: 0, read: 0 }; "
  "let total = 0, d = 0, anc = 0; "
  "for (let n = 1; n <= 45; n++) { const pt = K.p3.indexOf(n) >= 0 ? 3 : 2; "
  "if (ans[n] === K.key[n - 1]) { const a = this._ltAreaOf(n); cnt[a]++; pts[a] += pt; total += pt; "
  "if (pt === 3) d++; if (K.anchor.indexOf(n) >= 0) anc++; } } "
  "const rows = K.cuts; let idx = -1; rows.forEach((r, i) => { if (idx < 0 && total >= r[1] && total <= r[2]) idx = i; }); "
  "if (idx < 0) idx = 0; "
  "const meets = (r) => (r[3] == null || pts.grammar >= r[3]) && (r[4] == null || pts.read >= r[4]) && (r[5] == null || d >= r[5]); "
  "let level = rows[idx][0], note = ''; "
  "if (!meets(rows[idx])) { level = rows[Math.max(idx - 1, 0)][0]; note = ' · 영역 최소요건 미달로 한 단계 하향'; } "
  "else if (idx + 1 < rows.length) { const nx = rows[idx + 1]; "
  "if (total >= nx[1] - 2 && nx[5] != null && d >= nx[5] + 2 && meets(nx)) { level = nx[0]; note = ' · 경계 구간 D지수 충족으로 상위 확정'; } } "
  "['listen', 'vocab', 'grammar', 'read'].forEach((k) => { "
  "this.setIntakeLt(k + 'C', String(cnt[k])); this.setIntakeLt(k + 'T', String(AT[k])); }); "
  "const iD = this.state.intakeDraft || {}; "
  "if (!((iD.lt || {}).diagnosis || '').trim()) { "
  "this.setIntakeLt('diagnosis', 'OMR 자동 채점 — 총점 ' + total + '/100 · 판정 레벨 ' + level + ' · D지수 ' + d + '/10 · 앵커 ' + anc + '/6' + note); } "
  "this.setState({ ltOmrStatus: '자동 입력 완료 — 총점 ' + total + '/100 · 판정 ' + level + ' · D지수 ' + d + '/10' + (bd ? ' · 카드 생년월일 ' + bd : '') + note }); } "
)
html = html.replace(M_ANCHOR, METHODS + M_ANCHOR, 1)

# ── 2) rv 추가 (intake rv의 ltSubject 옆) ────────────────────────────
RV_ANCHOR = "ltSubject: iD.lt.subject, oLtSubject:"
assert html.count(RV_ANCHOR) == 1, 'rv 앵커'
html = html.replace(RV_ANCHOR,
  "onLtOmrFilesBind: ((e) => this.onLtOmrFiles(e)), ltOmrStatus: (S.ltOmrStatus || ''), "
  + RV_ANCHOR, 1)

# ── 3) 마크업: lt 카드의 입력 행들 위에 OMR 스트립 삽입 ───────────────
FOR_ANCHOR = '<sc-for list="{{ ltRows }}" as="r" hint-placeholder-count="4">'
assert html.count(FOR_ANCHOR) == 1, 'ltRows 앵커'
pos = html.index(FOR_ANCHOR)
col = html.rfind('<div style="display:flex;flex-direction:column;gap:9px;">', 0, pos)
assert col > 0, 'lt 컬럼 앵커'
STRIP = (
  '<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;background:#FBF9F0;'
  'border:1px solid var(--gold-300);border-radius:11px;padding:9px 13px;margin-bottom:12px;">'
  '<span style="font-size:12.5px;font-weight:800;color:#8a6520;flex:none;">OMR 스캔</span>'
  '<label style="flex:none;background:var(--green-700);color:#fff;border-radius:9px;padding:8px 14px;'
  'font-size:12.5px;font-weight:700;cursor:pointer;font-family:inherit;display:inline-block;position:relative;">'
  '카드 이미지·PDF 불러오기'
  '<input type="file" accept="image/*,application/pdf,.pdf" onchange="{{ onLtOmrFilesBind }}" '
  'style="position:absolute;left:0;top:0;width:100%;height:100%;opacity:0;cursor:pointer;"></label>'
  '<span style="flex:1;min-width:140px;font-size:11px;color:#9a9482;">'
  '카드를 올리면 위 과목 기준으로 자동 채점되어 영역별 정답수가 채워지고, 아래 통지서가 즉시 갱신됩니다.</span>'
  '</div>'
  '<sc-if value="{{ ltOmrStatus }}" hint-placeholder-val="{{ false }}">'
  '<div style="font-size:12px;font-weight:800;color:#0C4631;margin:-4px 0 10px;line-height:1.4;">{{ ltOmrStatus }}</div>'
  '</sc-if>')
html = html[:col] + STRIP + html[col:]

new_json = json.dumps(html, ensure_ascii=False).replace('</', '<\\/')
assert new_json.count('</script') == 0
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(raw[:ts] + new_json + raw[te:])
print('DONE v32.408 — 신규진단 OMR 자동 입력:',
      '메서드 3개 + rv 2개 + OMR 스트립 삽입, 정답키', len(KEYS_JSON), 'bytes 내장')
