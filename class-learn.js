/* ===================================================================== V2-3 화면(11-20 · 묶음 ③b) 학습 흐름 Lec.v2l
   class.html 이 class-v2.js 를 읽은 뒤(v2Get 참) 홈 _v2 의 eval 과 ③ 스위치(spell · guw · gram · review) 하나가 켜졌을 때만 늦게 읽음
   (한 번만 · 못 읽으면 조용히 지금 길) · 스위치가 꺼진 화면은 지금 판 그대로(이 파일의 pg · row · open 이 손대지 않음)
   - 단어 «써 보기»(spell): 뜻 → 영어 쓰기 · 첫 시도(빈 답 포함) 뒤 «힌트»(첫 글자 · 글자 수) → «바른 답 보기» · 뜻 화면 소리 0(답 뒤 «발음 듣기»)
   - 구문 «써 보기»(guw): 문장마다 ① 낱말 배열(줄 f 'ar' · 첫 답 · 자판 닫힘) → ② 통째 쓰기(줄 f 'se' · 힌트 = 낱말 첫 글자)
   - 문법 연습(gram): 서버 차례 · 한 번 답 · 틀리면 내 답 · 바른 답 · 규칙 한 줄(세트 해설 · 없으면 줄 없음)
   - 오늘 볼 것(review): 목록 줄(지금 «쌓인 오답» 자리 · 같은 data-act) · 누름 = 새로 받기 · 한 판 한 종류 · 구문은 통째 쓰기만(힌트 = 배열 조각)
   - 틀린 것 · 힌트 본 것 = 판 끝에 «힌트 없이 한 번 더»(저절로 · 틀리면 바로 바른 답 · 그날 한 번 맞힐 때까지 · «그만»으로 언제든 나감) · 판 끝 카드(점수 · 통과 0) «이어서 …» 하나
   기록 = ①a 보관함만(v2Add · 판 끝 v2End · 숨길 때 · 다음 열기) · 문항마다 서버 0 · 타이머 0
     첫 판 답마다 한 줄(빈 답 포함 · h = 힌트를 본 뒤 답 = 맞힌 날 · 외움에 안 넣음) · «한 번 더» 답은 적지 않음(①b 쌓인 오답 «끝 한 번 더»와 같음)
   ES5 · 바깥 라이브러리 0 · 바른 답은 판을 연 응답(q.a)에서만 읽고 보관함 · 기록 줄에 넣지 않음 */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec || !Lec.v2u || typeof Lec.setOpenV2 !== 'function' || typeof Lec.setCheckV2 !== 'function') return;

  var KW = { voc: '단어', gu: '구문', gram: '문법' }, UN = { voc: '개', gu: '문장', gram: '문제' }, KO = ['voc', 'gu', 'gram'], GAP = 350;
  /* 디자인 회의 2차(11-20 · 결론안2 3절): qar · arAll · pool · clear · done · go 단위(구문 문장 · 문법 문제) · K1 «시작» 장 · R2 off 줄 · 읽을 글(sr) */
  var TX = {
    first: '먼저 떠올려 보고 눌러요', firstSr: ', 먼저 떠올려 보고 눌러요',
    spell: '써 보기', gpr: '연습',
    qsp: '뜻을 보고 영어로 써요', qar: '차례대로 눌러 문장을 만들어요', qse: '해석을 보고 영어로 써요',
    qc: '알맞은 말을 골라요', qr: '밑줄 친 말을 바르게 고쳐 써요',
    empty: '먼저 영어를 써요', emptyR: '먼저 고쳐 쓴 말을 써요', again: '다시 써 봐요', arAll: '남은 것도 모두 놓아요',
    hint: '힌트', show: '바른 답 보기', ok: '맞아요', chk: '확인', next: '다음',
    rep: '힌트 없이 한 번 더 · ', today: '오늘 볼 것', cont: '이어서 하기', incl: '쌓인 오답 {n}개 포함', dueN: '쌓인 오답 {n}개', dueT: '내일부터 나와요',
    done: '{k} {n} 다 봤어요', go: '이어서 {k} {n}', goSet: '이어서 써 보기', goG: '이어서 연습',
    test: '시험 보기', drill: '문제 풀기', list: '목록으로', clear: '오늘 볼 것이 없어요.', busy: '하던 시험을 마치면 할 수 있어요.',
    gate: '이제 영어로 써요', gateR: '이제 고쳐 써요', go1: '시작',
    mine: '내 답', right: '바른 답', say: '발음 듣기', put: '놓기: ', out: '빼기: ', made: '만든 문장', pool: '고를 말',
    srA: '바른 답 ', srOk: ' · 바른 답', srNo: ' · 내 답', srW: '낱말 · 첫 글자 '
  };
  /* 2차: C1 .lqs 왼쪽 · .lqt 카드 밖 · C3 피드백 때 여백 그대로 · C4 상태 줄 15/600 · 이름 칸 56 · C6 구문 칸 = 원안 .sin + 높이만 · C7 구문 밑줄 힌트 400
     C8 «힌트» 누르는 폭 · A1 칩 누름(원안 .btn-fill) · A2 답 줄 틈 8 · 답 뒤 실선 */
  var CSS = '.lq{position:relative;padding:12px 16px}.lq .sqm{margin:0}.lq .sqg{margin:0}.lq .vsay{top:2px;right:2px}' +
    '.lqt{margin:0 0 6px;font-size:12px;font-weight:600;color:var(--ink2);text-align:left;word-break:keep-all}' +
    '.lqs{margin:0 0 8px;font-size:13px;font-weight:600;line-height:18px;color:var(--ink2);text-align:left}' +
    '.lgt{margin:0;font-size:15px;line-height:1.5;color:var(--ink);text-align:justify;word-break:keep-all;overflow-wrap:break-word}' +
    '.lnb{display:flex;align-items:flex-start;gap:8px;font-size:15px;font-weight:600}.lnb .lst{flex:1 1 auto;min-width:0}' +
    '.lhint{font-size:15px;font-weight:600;color:var(--ink2);font-variant-numeric:tabular-nums;word-break:keep-all;overflow-wrap:anywhere}.lhint.lm{font-weight:400;letter-spacing:.06em}' +
    '.ltx{flex:0 0 auto;min-height:44px;margin:-11px -10px -11px auto;padding:0 10px;border:0;background:none;color:var(--ink2);font-size:13px;font-weight:600;' +
    'text-decoration:underline;text-underline-offset:3px;white-space:nowrap}' +
    '.lta{height:72px;padding:10px 14px;font-size:16px;line-height:1.5;resize:none;overflow-y:auto}.lta.fb{height:48px}' +
    '.lans{display:flex;flex-wrap:wrap;align-content:flex-start;gap:8px;min-height:61px;margin:12px 0 0;padding:7px;border:1.5px dashed var(--dash);border-radius:12px}' +
    '.lans.fb{border-style:solid;border-color:var(--line)}' +
    '.lpool{display:flex;flex-wrap:wrap;gap:8px;margin:12px 0 0}' +
    '.lch{display:inline-flex;align-items:center;justify-content:center;min-width:44px;min-height:44px;padding:0 14px;border:1px solid var(--sl);border-radius:999px;background:var(--card);' +
    'color:var(--ink);font-size:15px;font-weight:600;transition:transform 220ms cubic-bezier(.3,1.25,.5,1)}' +
    '.lch:active{transform:scale(.97);transition-duration:90ms;transition-timing-function:var(--e-out)}@media (prefers-reduced-motion:reduce){.lch:active{transform:none}}' +
    '.lch.on{border-color:transparent;background:var(--tile);color:var(--tileT)}' +
    '.lch.gone{border:1.5px dashed var(--dash);background:none;color:transparent}.lch[disabled]{cursor:default}' +
    '.lsd .sdl{padding-left:56px;text-indent:-56px}.lsd .sdl b{min-width:56px;text-indent:0}.lsep{color:var(--ink3)}.lw .sx{font-weight:400;color:var(--ink)}.lw .sx p{display:inline;margin:0}.lw .sx .tag{margin-right:6px}' +
    '#lFb:focus,.sres .sr1[tabindex]:focus{outline:0}';
  var B = null, P = null, LS = null;

  function str(v) { return v == null ? '' : String(v); }
  function esc(s) { return Lec.esc(str(s)); }
  function $(id) { return w.document.getElementById(id); }
  function W() { return B ? B.W() : null; }
  function key() { return B.S.key; }
  function on(f) { var s = B && B.S.set, v = s && s.v2; return !!(v && v['eval'] && v[f]) && !B.pv(); }
  function words(s) { var a = str(s).split(' '), o = [], i; for (i = 0; i < a.length; i += 1) { if (a[i].replace(/^\s+|\s+$/g, '')) o.push(a[i]); } return o; }
  function nz(s) { return Lec.setSNormV2(s); }
  function live(x) { return !!(x && P && W() === x && x.L === P); }
  function cur() { return P && P.list[P.i]; }
  function fresh() { return !!(P && P.at && Date.now() - P.at < GAP); }
  function opsOf(q) { return q.o || (Lec.gramParts(str(q.p)) || {}).o || []; }
  function first(a) { return str(a).split('/')[0].replace(/[(][^()]*[)]/g, ' ').replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, ''); }

  /* ------------------------------------------------------------ 목록 줄 · 원안 화면에 고리 */

  /* «오늘 볼 것» 줄(지금 «쌓인 오답» 자리 · 같은 data-act) · null = 지금 줄 그대로(review 끔 · 옛 꼴 todo) · '' = 줄 없음
     n 0 이고 쌓인 오답(내일부터)만 있으면 «이어서 하기»(누르면 안 끝난 첫 세트) · 둘 다 없으면 줄 없음
     2차 R2: n 0 이고 안 끝난 세트도 없으면 원안 off 줄(누를 수 없음 · setGrpHTML 꼴) · R1: «쌓인 오답 n개 포함»은 n 이 오늘 볼 것 수 이하일 때만 */
  function row(s, due) {
    var t, n, k, v = '', a, i;
    if (!on('review') || !s || !s.todo || typeof s.todo.day !== 'string') return null;
    t = Lec.setTodoV2(s);
    n = t.n;
    if (!n && !due) return '';
    if (!n && !t.skew && !(+due.now > 0)) {
      a = B.rows();
      for (i = 0; i < a.length; i += 1) { if (a[i] && !B.done(a[i])) break; }
      if (i >= a.length) return '<div class="absln sdue off"><span class="k am">' + TX.dueN.replace('{n}', +due.n) + '</span><span class="v">' + TX.dueT + '</span></div>';
    }
    k = t.skew ? TX.today : (n ? TX.today + ' ' + n + '개' : TX.cont);
    if (n && !t.skew && due && +due.now > 0 && +due.now <= n) v = TX.incl.replace('{n}', +due.now);
    return '<button class="absln sdue" type="button" data-act="s1due"><span class="k' + (n || t.skew ? ' am' : '') + '">' + k + '</span><span class="v">' + v + '</span></button>';
  }
  /* setPage 거름: 원안 화면에 들어가는 곳만 더함(스위치를 켠 때만) */
  function pg(h) {
    var x = W(), m = x && x.mode;
    if (!m || m.charAt(0) === 'L') return h;
    if (m === 's2' && x.kind === 'voc' && on('spell')) {
      h = h.replace('<button class="row s2r" type="button" data-act="s1test"><span class="mn"><span class="tt">② 시험',
        '<button class="row s2r" type="button" data-act="s1Lspell"><span class="mn"><span class="tt">② ' + TX.spell + '</span></span></button>' +
        '<button class="row s2r" type="button" data-act="s1test"><span class="mn"><span class="tt">③ 시험');
    } else if (m === 'mem' && !x.nth && on('spell')) {
      /* 2차 V2: 읽는 글(카드 aria-label) 끝에도 같은 말(글은 .vf aria-hidden 안) */
      h = h.replace('>눌러서 뜻 보기<', '>' + TX.first + '<').replace(/(id="vCard"[^>]*? aria-pressed="false" aria-label="[^"]*)"/, '$1' + TX.firstSr + '"');
    }
    else if (m === 'memend' && on('spell')) h = h.replace('data-act="s1test">시험 보기<', 'data-act="s1Lspell">' + TX.spell + '<');
    else if (m === 'gu' && x.g && x.g.allSaid && on('guw')) h += '<div class="stxtw"><button class="stxt" type="button" data-act="s1Lguw">' + TX.spell + '</button></div>';
    else if (m === 'gudone' && on('guw')) {
      h = h.replace('<button class="btn-fill" type="button" data-act="s1back">' + TX.list + '</button>',
        '<button class="btn-fill" type="button" data-act="s1Lguw">' + TX.spell + '</button><button class="stxt" type="button" data-act="s1back">' + TX.list + '</button>');
    }
    return h;
  }
  /* setOpen 고리(W 를 만든 뒤): 쌓인 오답 줄 = 오늘 볼 것(review) · 문법 세트 = ① 연습 ② 문제 풀기(gram) → true = 여기서 그림 */
  function open(s) {
    if (!s) { if (!on('review')) return false; today(); return true; }
    if (s.kind === 'gram' && on('gram')) { g2(''); return true; }
    return false;
  }
  /* 문법 세트 첫 화면(단어 s2Draw 꼴) · 주 단추 = 지금처럼 문제 풀기(이어서 풀기) · 통과했거나 내일 다시면 연습 */
  function g2(err) {
    var x = W(), s = x.s, m = s.me || {}, n = +s.n || 0, tn = +s.test_n || 0, t = m.test || 'none', pct = +m.best || 0, st, btn, act;
    x.mode = 'Lg2';
    if (t === 'pass' || m.next === 'pass') st = '<span class="tag grn">통과</span>';
    else if (t === 'open') st = '<span class="st">이어서 풀기</span>';
    else if (m.next === 'tomorrow') st = '<span class="st">내일 다시' + (pct > 0 ? ' · 최고 ' + pct + '%' : '') + '</span>';   /* 2차: 원안 홈 · s2Draw 말 */
    else if (+m.tn > 0 && pct > 0) st = '<span class="st">아직 · 최고 ' + pct + '%</span>';
    else st = '<span class="st">아직</span>';
    if (t === 'open') { btn = '이어서 풀기'; act = 'test'; }
    else if (t === 'pass' || m.next === 'pass' || m.next === 'tomorrow') { btn = TX.gpr + ' 시작'; act = 'Lgram'; }
    else { btn = TX.drill; act = 'test'; }
    B.page(B.head('목록') + '<h1 class="sh1">' + esc(s.title) + '</h1>' +
      '<p class="smt">' + n + '문제' + (tn ? ' · 한 번에 ' + tn + '문제' : '') + (s.on ? ' · ' + esc(Lec.fmtDay(Lec.isoDay(s.on))) : '') + '</p>' +
      '<div class="rows sst"><button class="row s2r" type="button" data-act="s1Lgram"><span class="mn"><span class="tt">① ' + TX.gpr + '</span></span></button>' +
      '<button class="row s2r" type="button" data-act="s1test"><span class="mn"><span class="tt">② ' + TX.drill + '</span></span>' + st + '</button></div>' +
      '<p class="err" id="sErr" role="alert">' + esc(err || '') + '</p>' +
      '<button class="btn-fill" type="button" data-act="s1' + act + '">' + btn + '</button>');
  }

  /* ------------------------------------------------------------ 판 열기 */

  function loading(x) {
    x.mode = 'Lld';
    x.L = null;
    P = null;
    B.page(B.head('목록') + '<div class="sload"></div>');
  }
  /* 못 엶: 스위치가 그새 꺼짐(off · old) = 이 화면 스위치를 끄고 지금 화면 · 그 밖 = 원안 글 */
  function fail(x, r) {
    var e = (r && r.err) || 'network', msg;
    if (r && B.gone(r)) return;
    if (e === 'off' || e === 'old') { if (B.S.set) B.S.set.v2 = null; e = 'none'; }
    msg = e === 'testing' ? TX.busy : B.tx(e, 'open');
    B.S.setDirty = true;
    if (x.kind === 'voc') B.s2(msg);
    else if (x.kind === 'gram' && on('gram')) g2(msg);
    else B.info(x.kind === 'today' ? TX.today : (x.s ? x.s.title : ''), msg);
  }
  /* 세트 연습 판(spell · guw · gram) · 소리 · 말 알아듣기 멈춤 · 따라 말하기 도중이면 표시를 먼저 저장(guSave) */
  function start(md) {
    var x = W(), op = Date.now();
    if (!x || !x.id || x.mode === 'Lld') return;
    B.hush();
    if (x.mode === 'gu' && x.g && x.g.marks && Object.keys(x.g.marks).length) {
      loading(x);
      B.gs(function () { if (W() === x && x.mode === 'Lld') start2(x, md, op); });
      return;
    }
    start2(x, md, op);
  }
  function start2(x, md, op) {
    var my = B.my();
    loading(x);
    Lec.setOpenV2(key(), x.id, md).then(function (r) {
      if (my !== B.my() || W() !== x) return;
      if (!r || !r.ok) { fail(x, r); return; }
      if (!r.b || !r.q || !r.q.length) { fail(x, { err: 'none' }); return; }
      begin(x, r, md, op);
    }, function () { if (my === B.my() && W() === x) fail(x, null); });
  }
  /* 오늘 볼 것(누름 = 새로 받기) · 볼 것이 없으면 «이어서 하기» = 안 끝난 첫 세트(목록 자리 그대로) */
  function today() {
    var x = W(), my, op = Date.now();
    if (!x) return;
    x.kind = 'today';
    B.hush();
    my = B.my();
    loading(x);
    Lec.setTodayV2(key()).then(function (r) {
      var a, i, y;
      if (my !== B.my() || W() !== x) return;
      if (!r || !r.ok) { fail(x, r); return; }
      if (r.b && r.q && r.q.length) { begin(x, r, 'review', op); return; }
      a = B.rows();
      for (i = 0; i < a.length; i += 1) {
        if (a[i] && !B.done(a[i])) { y = B.S.setY; B.open(a[i].id); B.S.setY = y; return; }
      }
      B.S.setDirty = true;
      B.info(TX.today, TX.clear);
    }, function () { if (my === B.my() && W() === x) fail(x, null); });
  }
  function begin(x, r, md, op) {
    var q = r.q, list = [], i, f;
    for (i = 0; i < q.length; i += 1) {
      f = str(q[i].f);
      list.push({ q: q[i], j: i, f: f, ph: f === 'gw' ? 'ar' : (f === 'c' ? 'c' : 'w'), tries: 0, hint: 0, wr: 0, bad: 0, fb: null, ar: null, msg: '' });
    }
    /* 2차 E1: no = 이 판 번호(서버) · sn = 세트 문항 수(판 끝 «이어서 써 보기»를 숨길지) */
    P = { md: md, b: str(r.b), q: q, seed: +r.seed || 0, kd: r.kd || (q[0] && q[0].kd) || '', left: r.left || null,
          list: list, i: 0, rnd: 1, rep: [], rows: 0, op: op, tap: 0, omd: 0, at: 0, dx: null, end: false,
          no: +r.no || 0, sn: +((x.s && x.s.n) || 0) };
    x.L = P;
    B.S.setDirty = true;
    if (B.touch() && fld(list[0])) { gate(); return; }
    draw();
  }
  /* 2차 K1: 손가락 화면 · 첫 문항에 쓰기 칸 = 원안 «시작» 장(class.html tDraw t.gate 꼴) · 누르면 그 누름 안에서 칸 focus(아이폰 자판) */
  function gate() {
    var x = W(), X = cur();
    x.mode = 'Lkb';
    P.at = Date.now();
    B.page(head() + '<div class="sres"><p class="sr1">' + (X.f === 'r' ? TX.gateR : TX.gate) + '</p>' +
      '<button class="btn-fill" type="button" data-act="s1Lkb">' + TX.go1 + '</button></div>');
  }

  /* ------------------------------------------------------------ 한 문항 그리기 */

  /* 칸: 'i' = 단어 · 고쳐 쓰기(원안 .sin) · 't' = 구문 통째 쓰기(textarea) · '' = 칸 없음(배열 · 고르기 = 자판 닫힘) */
  function fld(X) { return X.ph === 'c' || X.ph === 'ar' ? '' : (X.f === 'sp' || X.f === 'r' ? 'i' : 't'); }
  function head() {
    var n = P.list.length, h = B.head('그만', (P.md === 'review' ? TX.today + ' · ' : '') + Math.min(P.i + 1, n) + ' / ' + n, n ? Math.round(P.i * 100 / n) : 0);
    h = h.replace('data-act="s1back"', 'data-act="s1Lstop"');
    if (P.rnd > 1) h += '<p class="slab">' + TX.rep + n + '개</p>';
    return h;
  }
  /* 2차 C1: 세트 이름 = 카드 밖 위(원안 .sqt 자리) · C3: 소리 단추가 있어도 여백 그대로(.lqs 줄 오른쪽 빈 곳) */
  function card(X) {
    var q = X.q, gp, h = '', t = '', sy = X.f === 'sp' && X.fb && !B.sn();
    if (P.md === 'review' && q.t) t = '<p class="lqt">' + esc(q.t) + '</p>';
    if (X.f === 'sp') h += '<p class="lqs">' + TX.qsp + '</p><p class="sqm" id="lM">' + esc(q.p) + '</p>';
    else if (X.ph === 'ar') h += '<p class="lqs">' + TX.qar + '</p><p class="lgt" id="lM">' + esc(q.p) + '</p>';
    else if (X.f === 'gw' || X.f === 'se') h += '<p class="lqs">' + TX.qse + '</p><p class="lgt" id="lM">' + esc(q.p) + '</p>';
    else {
      gp = Lec.gramParts(str(q.p)) || {};
      if (X.f === 'c') {
        h += '<p class="lqs">' + TX.qc + '</p><p class="sqg" id="lM">' + B.gesc(gp.pre, 1) + '<span class="sslot' + (X.fb ? ' ok' : '') + '">' + (X.fb ? esc(q.a) : '?') + '</span>' + B.gesc(gp.post, 0) + '</p>';
      } else {
        h += '<p class="lqs">' + TX.qr + '</p><p class="sqg" id="lM">' + B.gesc(gp.pre, 1) + '<span class="sund">' + esc(gp.mid || '') + '</span>' +
          (X.fb ? ' <span class="sfix">' + esc(q.a) + '</span>' : '') + B.gesc(gp.post, 0) + '</p>';
      }
    }
    if (sy) h += '<button class="vsay" type="button" data-act="s1Lsay" data-kb="" aria-label="' + TX.say + '">' + B.icon('vol', 22) + '</button>';
    return t + '<div class="sq lq">' + h + '</div>';
  }
  /* 배열 칩: 답 줄(놓인 칩 = 누르면 뺌) · 낱말(누르면 놓음 · 놓은 자리는 점선) · 2차 A2: 답을 낸 뒤 답 줄 실선 · 칩 읽는 글 = 글자 그대로 */
  function chips(X) {
    var A = X.ar, used = {}, h = '<div class="lans' + (X.fb ? ' fb' : '') + '" role="group" aria-label="' + TX.made + '">', i, t, dis = X.fb ? ' disabled' : '';
    for (i = 0; i < A.put.length; i += 1) {
      used[A.put[i]] = 1;
      t = A.toks[A.put[i]];
      h += '<button class="lch on" type="button" data-act="s1Lout" data-i="' + i + '"' + (X.fb ? '' : ' aria-label="' + esc(TX.out + t) + '"') + dis + '>' + esc(t) + '</button>';
    }
    if (X.fb) return h + '</div>';   /* 답을 낸 뒤 = 빈 자리(점선)만 남은 낱말 줄은 그리지 않음 */
    h += '</div><div class="lpool" role="group" aria-label="' + TX.pool + '">';
    for (i = 0; i < A.toks.length; i += 1) {
      t = A.toks[i];
      h += used[i] ? '<span class="lch gone" aria-hidden="true">' + esc(t) + '</span>' :
        '<button class="lch" type="button" data-act="s1Lput" data-i="' + i + '" aria-label="' + esc(TX.put + t) + '"' + dis + '>' + esc(t) + '</button>';
    }
    return h + '</div>';
  }
  function opts(X) {
    var q = X.q, o = opsOf(q), fb = X.fb, h = '<div class="sopts" role="group" aria-label="보기">', i, c;
    for (i = 0; i < o.length; i += 1) {
      c = '';
      if (fb) { if (Lec.setNorm(o[i]) === Lec.setNorm(q.a)) c = ' ok'; else if (i === fb.sel && !fb.ok) c = ' no'; }
      h += '<button class="sopt' + c + '" type="button" data-act="s1Lopt" data-i="' + i + '"' + (fb ? ' disabled' : '') + '>' + esc(o[i]) +
        (c ? '<span class="sr">' + (c === ' ok' ? TX.srOk : TX.srNo) + '</span>' : '') + (c && B.mk ? B.mk[c] : '') + '</button>';   /* 2차 F4: 색만으로 알리지 않음(읽는 글) */
    }
    return h + '</div>';
  }
  /* 힌트 글: 단어 = «a로 시작 · 7글자»(낱말이 여럿이면 낱말 수도) · 구문 쓰기 = 낱말 첫 글자 · 오늘 볼 것 구문 = 배열 조각 */
  function hintTx(X) {
    var q = X.q, H, n;
    if (X.f === 'se') return Lec.setArrV2(q.a, P.seed + X.j).toks.join(' · ');
    H = Lec.setHintV2(q.a, X.f === 'gw' ? 'gw' : 'sp');
    if (X.f === 'gw') return H.m;
    n = words(first(q.a)).length;
    return H.c + (/[mn]/i.test(H.c) ? '으로' : '로') + ' 시작 · ' + (n > 1 ? n + '낱말 · ' : '') + H.n + '글자';
  }
  /* 힌트 줄(상태 글 자리 · id lH = 칸 aria-describedby) · 2차 C7: 구문 밑줄 힌트 = 가는 글(lm) · 밑줄 글은 읽지 않고 «n낱말 · 첫 글자 …»를 읽음 */
  function hintHTML(X) {
    var t = hintTx(X), ws, c = [], i, f;
    if (X.f !== 'gw') return '<span class="lst lhint" id="lH">' + esc(t) + '</span>';
    ws = words(t);
    for (i = 0; i < ws.length; i += 1) { f = (/[A-Za-z]/.exec(ws[i]) || [''])[0]; if (f) c.push(f); }
    return '<span class="lst lhint lm" id="lH"><span aria-hidden="true">' + esc(t) + '</span><span class="sr">' + ws.length + TX.srW + esc(c.join(', ')) + '</span></span>';
  }
  function lcs(A, C) {
    var n = A.length, m = C.length, T = [], fa = [], fc = [], i, j;
    for (i = 0; i <= n; i += 1) { T.push([]); for (j = 0; j <= m; j += 1) T[i].push(0); }
    for (i = n - 1; i >= 0; i -= 1) { for (j = m - 1; j >= 0; j -= 1) T[i][j] = A[i] === C[j] ? T[i + 1][j + 1] + 1 : Math.max(T[i + 1][j], T[i][j + 1]); }
    for (i = 0; i < n; i += 1) fa.push(1);
    for (j = 0; j < m; j += 1) fc.push(1);
    i = 0; j = 0;
    while (i < n && j < m) {
      if (A[i] === C[j]) { fa[i] = 0; fc[j] = 0; i += 1; j += 1; } else if (T[i + 1][j] >= T[i][j + 1]) i += 1; else j += 1;
    }
    return [fa, fc];
  }
  /* 구문은 길어 줄이 넘침 → 둘째 줄부터 글 칸에 맞춤(lsd · 이름 칸 56px = 원안 .sdl b) */
  function two(a, b) { return '<span class="sdf lsd"><span class="sdl"><b>' + TX.mine + '</b>' + a + '</span><span class="sdl"><b>' + TX.right + '</b>' + b + '</span></span>'; }
  /* 밑줄 표시(sp = 사이 글) · 2차 F2: 낱말 사이(빈칸)면 이어진 틀린 낱말을 span 하나로(덩어리 밑줄 · 원안 tDiffHTML 꼴) · «/» 덩어리는 하나씩 */
  function mark(u, f, c, sp) {
    var o = [], i, j;
    for (i = 0; i < u.length; i = j) {
      j = i + 1;
      if (!f[i]) { o.push(esc(u[i])); continue; }
      if (sp === ' ') { while (j < u.length && f[j]) j += 1; }
      o.push('<span class="' + c + '">' + esc(u.slice(i, j).join(' ')) + '</span>');
    }
    return o.join(sp);
  }
  /* 구문 «내 답 / 바른 답»(원안 .sdf): 덩어리(«/» · 없으면 낱말) · 배열 = 조각끼리 · 쓰기 = 낱말로 맞춰 다른 낱말이 든 덩어리에 밑줄 */
  function sdiff(X, v) {
    var a = str(X.q.a), sp = Lec.sayParts(a), sep = sp.length > 1 ? ' <span class="lsep" aria-hidden="true">/</span> ' : ' ', parts = sp, mw, rw = [], ci = [], bad = [], r, i, j, ws;
    if (X.ph === 'ar') {
      mw = X.ar.put.map(function (k) { return X.ar.toks[k]; });
      r = lcs(mw.map(nz), X.ar.parts.map(nz));
      return two(mark(mw, r[0], 'sdm', ' '), mark(X.ar.parts, r[1], 'sdr', sep));
    }
    if (parts.length < 2) parts = words(Lec.sayText(a));
    for (i = 0; i < parts.length; i += 1) { ws = words(parts[i]); for (j = 0; j < ws.length; j += 1) { rw.push(nz(ws[j])); ci.push(i); } bad.push(0); }
    mw = words(v);
    r = lcs(mw.map(nz), rw);
    for (j = 0; j < rw.length; j += 1) { if (r[1][j]) bad[ci[j]] = 1; }
    return two(mark(mw, r[0], 'sdm', ' '), mark(parts, bad, 'sdr', sep));
  }
  /* 2차 F1: 빈 답(바른 답 보기 · 한 번 더 빈 답) = «바른 답» 줄만(원안 .sdf .sdl 꼴 · «내 답» 이름표만 남은 줄 0) */
  function one(X) {
    var a = str(X.q.a), sp, sep;
    if (X.f === 'sp' || X.f === 'r') return '<span class="sdf"><span class="sdl"><b>' + TX.right + '</b> ' + esc(a.replace(/\s*\/\s*/g, ' / ')) + '</span></span>';
    sp = Lec.sayParts(a);
    sep = ' <span class="lsep" aria-hidden="true">/</span> ';
    return '<span class="sdf lsd"><span class="sdl"><b>' + TX.right + '</b>' + (sp.length > 1 ? sp.map(esc).join(sep) : esc(Lec.sayText(a))) + '</span></span>';
  }
  /* 아래(2차 V1 · 판 동안 #lFb 상태 줄 + 주 단추 #lGo 한 벌 · 글 · data-act · class 만 바뀜) → {c 상태 줄 class · h 상태 줄 안 · a 주 단추(없으면 '') · t 글}
     피드백 전 = 상태 글(다시 써 봐요 · 힌트 글) + 글자 단추(힌트 → 바른 답 보기) + «확인» · 뒤 = role=status 안에 맞아요 · 내 답 · 바른 답 · 규칙 + «다음» */
  function bottom(X) {
    var fb = X.fb, h, st = '', tx = '', g = X.f === 'c' || X.f === 'r';
    if (fb) {
      if (fb.ok) h = TX.ok;
      else if (X.ph === 'c') h = '<span class="sr">' + TX.srA + esc(X.q.a) + '</span>';   /* 2차 F4 */
      else if (!str(fb.v).replace(/^\s+|\s+$/g, '')) h = one(X);
      else h = X.f === 'sp' || X.f === 'r' ? B.diff(fb.v, X.q.a) : sdiff(X, fb.v);
      if (!fb.ok && g && (X.q.x || X.q.pt)) h += B.xbox(X.q.pt, X.q.x);
      return { c: 'sfb' + (fb.ok ? ' ok' : ''), h: h, a: 'next', t: TX.next };
    }
    if (X.msg) st = '<span class="lst" id="lH">' + X.msg + '</span>';
    if (X.hint) st = hintHTML(X);
    if (X.tries && P.rnd === 1 && X.ph === 'w' && X.f !== 'r') tx = '<button class="ltx" type="button" data-act="s1L' + (X.hint ? 'show' : 'hint') + '" data-kb="">' + (X.hint ? TX.show : TX.hint) + '</button>';
    return { c: 'sfb lnb', h: st + tx, a: X.ph === 'c' ? '' : 'chk', t: TX.chk };
  }
  /* 2차 K2: «확인»에도 data-kbend(자판이 열린 동안 주 단추 아래 끝 = 보이는 아래 − 8 · class.html kbFit) */
  function bHTML(o) {
    return '<div class="' + o.c + '" id="lFb" role="status" tabindex="-1">' + o.h + '</div>' +
      (o.a ? '<button class="btn-fill" type="button" id="lGo" data-act="s1L' + o.a + '" data-kb="" data-kbend="">' + o.t + '</button>' : '');
  }
  /* 2차 V2: 칸 설명 = 뜻(lM) + 상태 글 · 힌트(lH) */
  function fieldHTML(k) {
    var a = ' id="lIn" data-k="' + k + '" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false" enterkeyhint="done" aria-describedby="lM lH"';
    return k === 'i' ? '<input class="sin" type="text" maxlength="200"' + a + '>' : '<textarea class="sin lta" rows="2" maxlength="400"' + a + '></textarea>';
  }
  /* 구문 칸: 2줄(72)로 시작 · 3줄(96)까지 늘고 그 뒤는 칸 안에서 굴림 · 피드백 때 1줄(48) */
  function grow(t) {
    if (!t || t.tagName !== 'TEXTAREA') return;
    t.style.height = '';
    if (!/ fb/.test(t.className) && t.scrollHeight > t.clientHeight) t.style.height = Math.min(96, t.scrollHeight + 2) + 'px';
  }
  /* 배열 조각은 판 씨앗으로 한 번만 섞음 */
  function prep() {
    var i, X;
    for (i = 0; i < P.list.length; i += 1) {
      X = P.list[i];
      if (X.ph === 'ar' && !X.ar) { X.ar = Lec.setArrV2(X.q.a, P.seed + X.j); X.ar.put = []; }
    }
  }
  /* 그리기: 칸 꼴이 같으면 위(lA) · 아래(lB)만 바꿈 = 쓰기 칸은 같은 것(자판이 닫히지 않음) · 다르면 새로(배열 · 고르기 = 칸 없음)
     keep = 배열 칩 놓기 · 빼기(그린 때를 그대로 = 마지막 칩 바로 뒤 «확인»도 받음 · 줄 ms = 배열 화면부터) */
  function fo(el) { if (el) { try { el.focus({ preventScroll: true }); } catch (e) { /* 없음 */ } } }
  /* 2차 V1: 쓰기 칸 판은 #lFb · #lGo 를 다시 쓰지 않고 글 · data-act · class 만 바꿈(초점 · 읽어 주기가 같은 자리에 남음)
     V2: 칸 없는 화면 피드백 뒤 = 손가락 화면은 #lFb 에 초점(읽어 줌) · PC 는 지금처럼 «다음» */
  function draw(keep) {
    var x = W(), X, k, el, a, b, h, o, fb, go;
    prep();
    X = cur(); k = fld(X); el = $('lIn'); a = $('lA'); b = $('lB'); fb = $('lFb'); go = $('lGo');
    h = head() + card(X);
    if (X.ph === 'ar') h += chips(X);
    if (X.ph === 'c') h += opts(X);
    o = bottom(X);
    x.mode = 'L' + X.ph;
    if (k && el && a && b && fb && go && o.a && el.getAttribute('data-k') === k) {
      a.innerHTML = h;
      fb.className = o.c;
      fb.innerHTML = o.h;
      go.setAttribute('data-act', 's1L' + o.a);
      go.textContent = o.t;
    } else {
      B.page('<div id="lA">' + h + '</div>' + (k ? fieldHTML(k) : '') + '<div id="lB" class="lw">' + bHTML(o) + '</div>');
      el = $('lIn');
    }
    if (!keep) P.at = Date.now();
    if (el) {
      /* 2차 F2: 쓴 것 없는 칸에 분홍 0(틀린 시도 · 빈 답 «바른 답» 표시 둘 다) */
      el.className = (k === 'i' ? 'sin' : 'sin lta') + (X.fb ? (X.fb.ok ? ' ok' : (str(X.fb.v).replace(/\s+/g, '') ? ' no' : '')) + (k === 't' ? ' fb' : '') : (X.wr ? ' no' : ''));
      el.setAttribute('aria-label', X.f === 'r' ? '고쳐 쓴 말' : '영어로 쓰기');
      if (X.fb) el.value = str(X.fb.v);
      else if (P.dx !== X) el.value = '';
      grow(el);
      if (w.document.activeElement !== el) { try { el.focus(); } catch (e) { /* 없음 */ } }
    } else if (X.fb && B.touch()) fo($('lFb'));
    else if (X.fb) {
      b = $('lGo');
      if (b) { try { b.focus(); } catch (e2) { /* 없음 */ } }
    }
    P.dx = X;
    if (el) B.kb(X.fb ? 0 : 1);
  }
  /* 2차 A3: 칩을 놓거나 뺀 뒤 초점 = 놓기 뒤 남은 칩 가운데 그 다음 것(없으면 첫 남은 칩 · 그것도 없으면 «확인») · 빼기 뒤 답 줄 같은 자리(없으면 첫 남은 칩) */
  function arFocus(put, i) {
    var d = w.document, e = null, a, j, n;
    if (put) {
      a = d.querySelectorAll('.lpool button[data-act=s1Lput]');
      for (j = 0; j < a.length; j += 1) { n = +a[j].getAttribute('data-i'); if (n > i) { e = a[j]; break; } }
      if (!e && a.length) e = a[0];
      if (!e) e = $('lGo');
    } else {
      e = d.querySelector('.lans button[data-i="' + i + '"]') || d.querySelector('.lpool button[data-act=s1Lput]');
    }
    fo(e);
  }

  /* ------------------------------------------------------------ 답 · 다음 */

  /* 기록 줄 한 줄(①a 보관함 · 서버 0 · 첫 판만): ms 이 그림 → 답 · nx 앞 답 → 이 그림 · om 판을 연 누름 → 첫 그림 · pr 폰 채점 */
  function add(X, f, v, ok) {
    var t = Date.now(), o;
    if (P.rnd > 1) return;
    o = { s: str(X.q.s), k: str(X.q.k), f: f, v: v, h: !!X.hint, pr: !!ok, ms: Math.max(0, t - P.at) };
    if (P.tap && P.at >= P.tap) o.nx = P.at - P.tap;
    else if (P.op && !P.omd && P.at >= P.op) { o.om = P.at - P.op; P.omd = 1; }
    P.tap = t;
    if (Lec.v2Add(key(), P.b, o)) P.rows += 1;
  }
  function judge(X, f, v) {
    var q = X.q, c = q, y;
    if (f === 'ar') { c = {}; for (y in q) { if (Object.prototype.hasOwnProperty.call(q, y)) c[y] = q[y]; } c.f = 'ar'; }
    return v !== '' && !!Lec.setCheckV2(c, v, P.q);
  }
  /* 쓰기 «확인»(Enter) · 피드백 뒤 Enter = 다음
     첫 판: 빈 답도 시도(줄 · 힌트 열림) · 틀리면 «다시 써 봐요» + «힌트» → 힌트 글 + «바른 답 보기» · 문법 고쳐 쓰기 = 한 번 답(틀리면 바로 바른 답)
     한 번 더 판: 틀리면 바로 바른 답 · 2차 F5: 빈 답도 틀림(바른 답 · 기록 0 · 다시 맨 뒤) · 판 1 고쳐 쓰기 빈 답 = 글만(지금대로) */
  function chk() {
    var X = cur(), el = $('lIn'), raw, v, ok, f;
    if (!X || fresh()) return;
    if (X.fb) { next(); return; }
    if (X.ph === 'ar') { arChk(X); return; }
    if (X.ph !== 'w' || !el) return;
    raw = str(el.value).replace(/[\r\n]+/g, ' ');
    v = raw.replace(/^\s+|\s+$/g, '');
    if (!v && P.rnd > 1) { X.fb = { ok: false, v: '' }; X.bad = 1; X.msg = ''; draw(); return; }
    if (!v && X.f === 'r') { X.msg = TX.emptyR; draw(); return; }
    f = X.f === 'gw' ? 'se' : X.f;
    X.tries += 1;
    ok = judge(X, X.f, v);
    add(X, f, v, ok);
    X.msg = '';
    if (ok) { X.fb = { ok: true, v: raw }; if (X.tries > 1 || X.hint) X.bad = 1; }
    else if (P.rnd > 1 || X.f === 'r') { X.fb = { ok: false, v: raw }; X.bad = 1; }
    else { X.bad = 1; X.wr = v ? 1 : 0; X.msg = v ? TX.again : TX.empty; }   /* 2차 F2: 쓴 것 없는 칸에 분홍 0 */
    draw();
  }
  function arChk(X) {
    var A = X.ar, v, ok;
    if (A.put.length < A.toks.length) { X.msg = TX.arAll; draw(); return; }
    v = A.put.map(function (k) { return A.toks[k]; }).join(' ');
    ok = judge(X, 'ar', v);
    add(X, 'ar', v, ok);
    X.fb = { ok: ok, v: v };
    X.msg = '';
    draw();
  }
  function pick(i) {
    var X = cur(), o, v, ok;
    if (!X || X.ph !== 'c' || X.fb || fresh()) return;
    o = opsOf(X.q);
    if (!(i >= 0 && i < o.length)) return;
    v = str(o[i]);
    ok = judge(X, 'c', v);
    add(X, 'c', v, ok);
    X.fb = { ok: ok, v: v, sel: i };
    if (!ok) X.bad = 1;
    draw();
  }
  /* 다음: 배열 → 같은 문장 통째 쓰기(이 누름 안에서 쓰기 칸에 focus = 자판이 열림) · 판 끝이면 «힌트 없이 한 번 더»(저절로) → 판 끝 카드 */
  function next() {
    var X = cur(), i, Y, a;
    if (!X || !X.fb || fresh()) return;
    if (X.ph === 'ar') { X.ph = 'w'; X.fb = null; X.tries = 0; X.msg = ''; P.dx = null; draw(); return; }
    if (X.bad && !(P.rnd > 1 && X.fb.ok)) P.rep.push(X);
    P.i += 1;
    if (P.i < P.list.length) { draw(); return; }
    if (P.rep.length) {
      a = P.rep; P.rep = [];
      for (i = 0; i < a.length; i += 1) {
        Y = a[i];
        Y.tries = 0; Y.hint = 0; Y.wr = 0; Y.bad = 0; Y.msg = ''; Y.fb = null;
        Y.ph = Y.f === 'c' ? 'c' : 'w';
      }
      P.list = a; P.i = 0; P.rnd += 1; P.dx = null;
      draw();
      return;
    }
    end();
  }
  /* 판 끝: 적은 줄이 있으면 v2End(기다리지 않음 · 목록으로 갈 때 다음 열기가 함께 받음) · 카드 하나(점수 · 통과 0) */
  /* 2차 E1: 써 보기(spell · guw) 판을 틀림 · 힌트 없이 끝냈고(한 번 더 0) 지금까지 판이 세트 문항을 다 덮었으면(문항 수 ≤ 20 × 판 번호)
     «이어서 써 보기»를 숨김(서버는 다 맞혀도 늘 20개 = 같은 것만 끝없이) · 주 단추 = 단어 «시험 보기»(통과면 «목록으로») · 구문 «목록으로» */
  function enough() { return (P.md === 'spell' || P.md === 'guw') && P.rnd === 1 && P.no > 0 && P.sn > 0 && P.sn <= 20 * P.no; }
  function end() {
    var x = W(), kd = P.kd, n = P.q.length, nk = null, i, h, l = P.left, me = (x.s && x.s.me) || {}, el;
    P.end = true;
    x.mode = 'Lend';
    if (P.rows) Lec.v2End(key(), P.b).then(null, function () { return null; });
    B.S.setDirty = true;
    if (P.md === 'review') {
      for (i = 0; i < KO.length && l; i += 1) { if (+l[KO[i]] > 0) { nk = KO[i]; break; } }
    }
    h = '<div class="sres">' + B.icon('check', 36) + '<p class="sr1" tabindex="-1">' + TX.done.replace('{k}', KW[kd] || '').replace('{n}', n + (UN[kd] || '개')) + '</p>';
    if (P.md === 'review') {
      h += nk ? '<button class="btn-fill" type="button" data-act="s1Lgo">' + TX.go.replace('{k}', KW[nk]).replace('{n}', +l[nk] + UN[nk]) + '</button>' +
        '<button class="stxt" type="button" data-act="s1back">' + TX.list + '</button>' :
        '<button class="btn-fill" type="button" data-act="s1back">' + TX.list + '</button>';
    } else if (enough()) {
      h += P.md === 'spell' && me.test !== 'pass' ?
        '<button class="btn-fill" type="button" data-act="s1test">' + TX.test + '</button><button class="stxt" type="button" data-act="s1back">' + TX.list + '</button>' :
        '<button class="btn-fill" type="button" data-act="s1back">' + TX.list + '</button>';
    } else {
      h += '<button class="btn-fill" type="button" data-act="s1Lgo">' + (P.md === 'gram' ? TX.goG : TX.goSet) + '</button>' +
        (P.md === 'spell' ? '<button class="btn-line" type="button" data-act="s1test">' + TX.test + '</button>' : '') +
        (P.md === 'gram' ? '<button class="btn-line" type="button" data-act="s1test">' + TX.drill + '</button>' : '') +
        '<button class="stxt" type="button" data-act="s1back">' + TX.list + '</button>';
    }
    B.page(B.head('목록') + h + '</div>');
    el = w.document.querySelector('.sres .sr1');   /* 2차 V2: 판 끝 글에 초점(읽어 줌) */
    fo(el);
  }
  /* «그만»: 적은 줄이 있으면 판 끝을 보내고(기다리지 않음) 목록으로(목록 숫자 다시 받음 = 다음 열기) */
  function stop() {
    if (P && P.rows && !P.end) { P.end = true; Lec.v2End(key(), P.b).then(null, function () { return null; }); }
    B.back(B.S.setDirty);
  }

  /* ------------------------------------------------------------ 누름 · 자판 */

  function click(a, el) {
    var x = W(), X, i;
    if (!x) return;
    if (a === 'spell' || a === 'guw' || a === 'gram') { start(a); return; }
    if (a === 'go') {
      if (!live(x) || !P.end) return;
      if (P.md === 'review') today(); else start(P.md);
      return;
    }
    if (a === 'stop') { if (live(x)) stop(); else B.back(B.S.setDirty); return; }
    if (!live(x)) return;
    X = cur();
    if (!X || P.end) return;
    if (a === 'kb') { if (x.mode === 'Lkb') { P.op = Date.now(); draw(); } return; }   /* 2차 K1 «시작»: 이 누름 안에서 칸 focus */
    if (x.mode === 'Lkb') return;
    if (a === 'chk') chk();
    else if (a === 'next') next();
    else if (a === 'opt') pick(+el.getAttribute('data-i'));
    else if (a === 'hint') { if (X.tries && !X.fb && !X.hint && P.rnd === 1 && !fresh()) { X.hint = 1; X.msg = ''; draw(); } }
    else if (a === 'show') { if (X.hint && !X.fb && !fresh()) { X.fb = { ok: false, v: str(($('lIn') || {}).value) }; X.bad = 1; draw(); } }
    else if (a === 'put' || a === 'out') {
      if (X.ph !== 'ar' || X.fb) return;
      i = +el.getAttribute('data-i');
      if (a === 'put') { if (X.ar.put.indexOf(i) < 0 && i >= 0 && i < X.ar.toks.length) X.ar.put.push(i); } else X.ar.put.splice(i, 1);
      X.msg = '';
      draw(1);
      arFocus(a === 'put', i);
    } else if (a === 'say') { if (X.fb) B.say(first(X.q.a)); }
  }
  /* 바른 답 표시 동안 쓰기 칸 글자 막음(readOnly 로 바꾸지 않음 = 자판 그대로) · Enter = 확인(한글 조합 중 아님) · 줄바꿈 0 */
  function held() { var X = P && live(W()) ? cur() : null; return X && X.fb ? str(X.fb.v) : null; }
  function keys(d) {
    d.addEventListener('keydown', function (e) {
      var t = e.target, k = e.key || '', c = e.keyCode;
      if (!t || t.id !== 'lIn') return;
      if (held() !== null && !e.ctrlKey && !e.metaKey && !e.altKey && ((k.length === 1 && k !== 'Unidentified') || k === 'Backspace' || k === 'Delete' || c === 8 || c === 46)) { e.preventDefault(); return; }
      if (e.isComposing || c === 229) return;
      if (k === 'Enter' || c === 13) { e.preventDefault(); click('chk', t); }
    });
    d.addEventListener('beforeinput', function (e) { var t = e.target; if (t && t.id === 'lIn' && held() !== null && e.cancelable) e.preventDefault(); }, true);
    d.addEventListener('input', function (e) {
      var t = e.target, hv, X;
      if (!t || t.id !== 'lIn') return;
      hv = held();
      if (hv !== null) { if (t.value !== hv) t.value = hv; return; }
      if (/[\r\n]/.test(t.value)) t.value = t.value.replace(/[\r\n]+/g, ' ');
      X = P && live(W()) ? cur() : null;
      if (X && X.wr) { X.wr = 0; t.className = t.className.replace(' no', ''); }
      hv = t.offsetHeight;
      grow(t);
      if (t.offsetHeight !== hv && B) B.kb(1);   /* 2차 K2: 칸이 늘면 «확인»을 다시 자판 위로 */
    });
  }

  function dbg() {
    var X = P && cur();
    return P ? { md: P.md, b: P.b, i: P.i, n: P.list.length, nq: P.q.length, rnd: P.rnd, rows: P.rows, end: P.end, rep: P.rep.length, fr: fresh(),
      f: X ? X.f : '', ph: X ? X.ph : '', tries: X ? X.tries : 0, hint: X ? X.hint : 0, fb: X && X.fb ? (X.fb.ok ? 'ok' : 'no') : '', j: X ? X.j : -1,
      toks: X && X.ar ? X.ar.toks : null, put: X && X.ar ? X.ar.put.slice() : null, left: P.left } : null;
  }
  function init(b, x) {
    var d = w.document, st, k;
    B = b;
    for (k in x) { if (Object.prototype.hasOwnProperty.call(x, k)) B[k] = x[k]; }
    if (LS) return;
    LS = 1;
    if (d && !d.getElementById('lncss')) {
      st = d.createElement('style');
      st.id = 'lncss';
      st.appendChild(d.createTextNode(CSS));
      d.head.appendChild(st);
    }
    keys(d);
  }

  Lec.v2l = { init: init, row: row, pg: pg, open: open, click: click, dbg: dbg };
})(window);
