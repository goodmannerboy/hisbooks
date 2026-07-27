# -*- coding: utf-8 -*-
# v32.909 — 레벨테스트를 기존 정답키 시험 도구(examSets)에 통합 (4단계 본구현)
# · 초/중/고 3세트가 기존 도구 목록에 프리셋으로 자동 존재 (정답키·배점·영역 세팅 완료)
# · 기존 채점 경로(applyOmr/setExamAnswer)가 lt 세트면 신규진단 intake.lt 를 자동 동기화
# · 신규진단 스트립: OMR 결과를 lt 세트 submission 으로도 기록(문항별 보존) +
#   [문항별 확인·수정] 버튼 = 기존 모달을 해당 세트·학생·답입력 단계로 바로 열기
import json, re, sys
sys.stdout.reconfigure(encoding='utf-8')

with open('index.html', encoding='utf-8') as f:
    raw = f.read()
ts = re.search(r'<script[^>]*type="__bundler/template"[^>]*>', raw).end()
te = raw.find('</script>', ts)
html = json.loads(raw[ts:te])
xdc = html.find('<script type="text/x-dc"')
assert xdc > 0

# ── 1) 메서드 추가 (기존 v32.908 메서드들과 같은 자리: onOmrPick 앞) ──
M_ANCHOR = "onOmrPick() { let inp = document.getElementById('__omrInput');"
assert html.count(M_ANCHOR) == 1
METHODS = (
  "_ltSetIdOf(subj) { return 'lt2026' + ({ '초등': 'E', '중등': 'M', '고등': 'H' }[subj] || 'M'); } "
  "_ltGroupKo(n) { return n <= 12 ? '듣기' : n <= 20 ? '어휘' : n <= 31 ? '문법' : '독해'; } "
  "_ltExamSetDefs() { const KS = this._ltOmrKeys(); return ['초등', '중등', '고등'].map((subj) => { "
  "const K = KS[subj]; const qs = []; for (let n = 1; n <= 45; n++) { "
  "qs.push({ no: n, key: K.key[n - 1], pt: (K.p3.indexOf(n) >= 0 ? 3 : 2), "
  "group: this._ltGroupKo(n), type: this._ltGroupKo(n) }); } "
  "return { id: this._ltSetIdOf(subj), name: '레벨테스트 2026 · ' + subj, date: '', grade: subj, "
  "questions: qs, submissions: {} }; }); } "
  "_ensureLtExamSets(dd) { if (!dd.examSets) dd.examSets = []; let added = false; "
  "this._ltExamSetDefs().forEach((def) => { if (!dd.examSets.find((x) => x.id === def.id)) { "
  "dd.examSets.push(def); added = true; } }); return added; } "
  "_ltSyncIntakeFromSub(dd, es, sid) { try { "
  "if (!es || !sid || !/^lt2026/.test(es.id || '')) return; "
  "const sub = (es.submissions || {})[sid]; if (!sub || !sub.answers) return; "
  "const subj = es.grade || '중등'; const K = this._ltOmrKeys()[subj]; if (!K) return; "
  "const AT = { listen: 12, vocab: 8, grammar: 11, read: 14 }; "
  "const cnt = { listen: 0, vocab: 0, grammar: 0, read: 0 }; "
  "const pts = { listen: 0, vocab: 0, grammar: 0, read: 0 }; "
  "let total = 0, d = 0, anc = 0; "
  "for (let n = 1; n <= 45; n++) { const pt = K.p3.indexOf(n) >= 0 ? 3 : 2; "
  "if (sub.answers[n] === K.key[n - 1]) { const a = this._ltAreaOf(n); cnt[a]++; pts[a] += pt; "
  "total += pt; if (pt === 3) d++; if (K.anchor.indexOf(n) >= 0) anc++; } } "
  "const rows = K.cuts; let idx = -1; rows.forEach((r, i) => { if (idx < 0 && total >= r[1] && total <= r[2]) idx = i; }); "
  "if (idx < 0) idx = 0; "
  "const meets = (r) => (r[3] == null || pts.grammar >= r[3]) && (r[4] == null || pts.read >= r[4]) && (r[5] == null || d >= r[5]); "
  "let level = rows[idx][0], note = ''; "
  "if (!meets(rows[idx])) { level = rows[Math.max(idx - 1, 0)][0]; note = ' · 영역 최소요건 미달로 한 단계 하향'; } "
  "else if (idx + 1 < rows.length) { const nx = rows[idx + 1]; "
  "if (total >= nx[1] - 2 && nx[5] != null && d >= nx[5] + 2 && meets(nx)) { level = nx[0]; note = ' · 경계 구간 D지수 충족으로 상위 확정'; } } "
  "let st = null; (dd.classes || []).forEach((c) => (c.students || []).forEach((x) => { if (x.id === sid) st = x; })); "
  "if (st) { if (!st.intake) st.intake = this.blankIntake ? this.blankIntake() : { lt: {} }; "
  "if (!st.intake.lt) st.intake.lt = {}; const lt = st.intake.lt; lt.subject = subj; "
  "lt.listenC = String(cnt.listen); lt.listenT = String(AT.listen); "
  "lt.vocabC = String(cnt.vocab); lt.vocabT = String(AT.vocab); "
  "lt.grammarC = String(cnt.grammar); lt.grammarT = String(AT.grammar); "
  "lt.readC = String(cnt.read); lt.readT = String(AT.read); "
  "if (!(lt.diagnosis || '').trim()) { lt.diagnosis = '레벨테스트 자동 채점 — 총점 ' + total + '/100 · 판정 레벨 ' + level + ' · D지수 ' + d + '/10 · 앵커 ' + anc + '/6' + note; } } "
  "} catch (err) {} } "
  "_ltRecordSub(subj, ans, sid) { this.setState((s) => { "
  "const dd = JSON.parse(JSON.stringify(s.data)); this._ensureLtExamSets(dd); "
  "const es = dd.examSets.find((x) => x.id === this._ltSetIdOf(subj)); if (!es || !sid) return {}; "
  "if (!es.submissions) es.submissions = {}; "
  "const sub = es.submissions[sid] || (es.submissions[sid] = { answers: {} }); "
  "sub.answers = {}; Object.keys(ans).forEach((q) => { sub.answers[q] = ans[q]; }); "
  "const totalPt = es.questions.reduce((a, q) => a + (parseInt(q.pt, 10) || 0), 0); "
  "let score = 0; es.questions.forEach((q) => { if (sub.answers[q.no] != null && sub.answers[q.no] === q.key) score += (parseInt(q.pt, 10) || 0); }); "
  "sub.score = score; sub.pct = totalPt ? Math.round(score / totalPt * 100) : 0; sub.grade = this._gradeOf(sub.pct); "
  "this._ltSyncIntakeFromSub(dd, es, sid); this.persist(dd); return { data: dd }; }); } "
  "onLtOpenGrade() { this.setState((s) => { "
  "const dd = JSON.parse(JSON.stringify(s.data)); this._ensureLtExamSets(dd); "
  "const subj = (((s.intakeDraft || {}).lt || {}).subject) || '중등'; this.persist(dd); "
  "return { data: dd, examGradeOpen: true, activeExamSetId: this._ltSetIdOf(subj), "
  "examStep: 'grade', examGradeStudentId: (s.intakeStudentId || null) }; }); } "
)
html = html.replace(M_ANCHOR, METHODS + M_ANCHOR, 1)

# ── 2) 기존 채점 경로에 동기화 훅 (applyOmr · setExamAnswer) ──────────
ia = html.find('applyOmr(sid, ans) {', xdc)
assert ia > 0
pa = html.find('this.persist(dd);', html.find('rec.grade = String(sub.grade);', ia))
assert 0 < pa < ia + 2400
html = html[:pa] + 'this._ltSyncIntakeFromSub(dd, es, sid); ' + html[pa:]

ib = html.find('setExamAnswer(no, val) {', xdc)
assert ib > 0
pb = html.find('this.persist(dd);', html.find('rec.grade = String(sub.grade);', ib))
assert 0 < pb < ib + 3200
html = html[:pb] + 'this._ltSyncIntakeFromSub(dd, es, sid); ' + html[pb:]

# ── 3) 기존 모달 열 때 프리셋 보장 ────────────────────────────────────
OG = "openExamGrade() { this.setState((s) => { const dd = JSON.parse(JSON.stringify(s.data)); if (!dd.examSets) dd.examSets = [];"
assert html.count(OG) == 1
html = html.replace(OG, OG + " this._ensureLtExamSets(dd);", 1)

# ── 4) 스트립 경로도 같은 엔진에 기록 (_ltApplyOmr 끝에 연결) ─────────
TAIL = "' · D지수 ' + d + '/10' + (bd ? ' · 카드 생년월일 ' + bd : '') + note }); }"
assert html.count(TAIL) == 1
html = html.replace(TAIL,
  "' · D지수 ' + d + '/10' + (bd ? ' · 카드 생년월일 ' + bd : '') + note }); "
  "const _sid = this.state.intakeStudentId; if (_sid) this._ltRecordSub(subj, ans, _sid); }", 1)

# ── 5) rv + 스트립에 [문항별 확인·수정] 버튼 ──────────────────────────
RV = "onLtOmrFilesBind: ((e) => this.onLtOmrFiles(e)),"
assert html.count(RV) == 1
html = html.replace(RV, RV + " onLtOpenGradeBind: (() => this.onLtOpenGrade()),", 1)

BTN_ANCHOR = ('<span style="flex:1;min-width:140px;font-size:11px;color:#9a9482;">'
              '카드를 올리면 위 과목 기준으로 자동 채점되어 영역별 정답수가 채워지고, 아래 통지서가 즉시 갱신됩니다.</span>')
assert html.count(BTN_ANCHOR) == 1
html = html.replace(BTN_ANCHOR,
  '<button onclick="{{ onLtOpenGradeBind }}" style="flex:none;border:1.5px solid #C9A227;background:#F4ECD7;'
  'color:#8a6a18;border-radius:9px;padding:8px 13px;font-size:12px;font-weight:700;cursor:pointer;'
  'font-family:inherit;">문항별 확인·수정</button>' + BTN_ANCHOR, 1)

new_json = json.dumps(html, ensure_ascii=False).replace('</', '<\\/')
assert new_json.count('</script') == 0
with open('index.html', 'w', encoding='utf-8') as f:
    f.write(raw[:ts] + new_json + raw[te:])
print('DONE v32.909 — 레벨테스트 3종이 기존 정답키 도구에 프리셋으로 통합, 양방향 동기화 완료')
