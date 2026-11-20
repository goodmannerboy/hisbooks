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

  var KW = { voc: '단어', gu: '구문', gram: '문법' }, KO = ['voc', 'gu', 'gram'], GAP = 350;
  var TX = {
    first: '먼저 떠올려 보고 뒤집어요',
    spell: '써 보기', gpr: '연습',
    qsp: '뜻을 보고 영어로 써요', qar: '낱말을 눌러 문장을 만들어요', qse: '해석을 보고 영어로 써요',
    qc: '알맞은 말을 골라요', qr: '밑줄 친 말을 바르게 고쳐 써요',
    empty: '먼저 영어를 써요', emptyR: '먼저 고쳐 쓴 말을 써요', again: '다시 써 봐요', arAll: '낱말을 모두 놓아요',
    hint: '힌트', show: '바른 답 보기', ok: '맞아요', chk: '확인', next: '다음',
    rep: '힌트 없이 한 번 더 · ', today: '오늘 볼 것', cont: '이어서 하기', incl: '쌓인 오답 {n}개 포함',
    done: '{k} {n}개 다 봤어요', go: '이어서 {k} {n}개', goSet: '이어서 써 보기', goG: '이어서 연습',
    test: '시험 보기', drill: '문제 풀기', list: '목록으로', clear: '오늘 볼 것을 다 봤어요', busy: '하던 시험을 마치면 할 수 있어요.',
    mine: '내 답', right: '바른 답', say: '발음 듣기', put: '놓기: ', out: '빼기: ', made: '만든 문장', pool: '낱말'
  };
  var CSS = '.lq{position:relative;padding:12px 16px}.lq.sy{padding:12px 48px}.lq .sqm{margin:0}.lq .sqg{margin:0}.lq .vsay{top:2px;right:2px}' +
    '.lqt{margin:0 0 2px;font-size:12px;font-weight:600;color:var(--ink2);text-align:center;word-break:keep-all}' +
    '.lqs{margin:0 0 4px;font-size:13px;font-weight:600;line-height:18px;color:var(--ink2);text-align:center}' +
    '.lgt{margin:0;font-size:15px;line-height:1.5;color:var(--ink);text-align:justify;word-break:keep-all;overflow-wrap:break-word}' +
    '.lnb{display:flex;align-items:center;gap:8px}.lnb .lst{flex:1 1 auto;min-width:0}' +
    '.lhint{font-size:15px;font-weight:600;color:var(--ink2);font-variant-numeric:tabular-nums;word-break:keep-all;overflow-wrap:anywhere}' +
    '.ltx{flex:0 0 auto;min-height:44px;margin:-11px -8px -11px auto;padding:0 8px;border:0;background:none;color:var(--ink2);font-size:13px;font-weight:600;' +
    'text-decoration:underline;text-underline-offset:3px;white-space:nowrap}' +
    '.lta{display:block;width:100%;height:72px;margin:12px 0 0;padding:10px 14px;border:1px solid var(--inL);border-radius:12px;background:var(--card);' +
    'color:var(--ink);font:inherit;font-size:16px;line-height:1.5;resize:none;overflow-y:auto}' +
    '.lta:focus{border-color:var(--focus);outline:none}.lta.fb{height:48px}' +
    '.lta.ok{border-color:#9FCFB3;background:var(--gB);color:var(--gT)}.lta.no{border-color:#E5B5A9;background:var(--cB);color:var(--cT)}' +
    '.lans{display:flex;flex-wrap:wrap;align-content:flex-start;gap:8px;min-height:52px;margin:12px 0 0;padding:3px;border:1.5px dashed var(--dash);border-radius:12px}' +
    '.lpool{display:flex;flex-wrap:wrap;gap:8px;margin:12px 0 0}' +
    '.lch{display:inline-flex;align-items:center;min-height:44px;padding:0 14px;border:1px solid var(--sl);border-radius:999px;background:var(--card);' +
    'color:var(--ink);font-size:15px;font-weight:600;transition:transform 90ms}' +
    '.lch:active{transform:scale(.97)}.lch.on{border-color:transparent;background:var(--tile);color:var(--tileT)}' +
    '.lch.gone{border:1.5px dashed var(--dash);background:none;color:transparent}.lch[disabled]{cursor:default}' +
    '.lsd .sdl{padding-left:60px;text-indent:-60px}.lsd .sdl b{min-width:60px;text-indent:0}.lsep{color:var(--ink3)}.lw .sx{font-weight:400;color:var(--ink)}.lw .sx p{display:inline;margin:0}.lw .sx .tag{margin-right:6px}';
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
     n 0 이고 쌓인 오답(내일부터)만 있으면 «이어서 하기»(누르면 안 끝난 첫 세트) · 둘 다 없으면 줄 없음 */
  function row(s, due) {
    var t, n, k, v = '';
    if (!on('review') || !s || !s.todo || typeof s.todo.day !== 'string') return null;
    t = Lec.setTodoV2(s);
    n = t.n;
    if (!n && !due) return '';
    k = t.skew ? TX.today : (n ? TX.today + ' ' + n + '개' : TX.cont);
    if (n && !t.skew && due && +due.now > 0) v = TX.incl.replace('{n}', +due.now);
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
    } else if (m === 'mem' && !x.nth && on('spell')) h = h.replace('>눌러서 뜻 보기<', '>' + TX.first + '<');
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
    else if (m.next === 'tomorrow') st = '<span class="st">내일 다시</span>';
    else if (+m.tn > 0 && pct > 0) st = '<span class="st">최고 ' + pct + '%</span>';
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
    P = { md: md, b: str(r.b), q: q, seed: +r.seed || 0, kd: r.kd || (q[0] && q[0].kd) || '', left: r.left || null,
          list: list, i: 0, rnd: 1, rep: [], rows: 0, op: op, tap: 0, omd: 0, at: 0, dx: null, end: false };
    x.L = P;
    B.S.setDirty = true;
    draw();
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
  function card(X) {
    var q = X.q, gp, h = '', sy = X.f === 'sp' && X.fb && !B.sn();
    if (P.md === 'review' && q.t) h += '<p class="lqt">' + esc(q.t) + '</p>';
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
    return '<div class="sq lq' + (sy ? ' sy' : '') + '">' + h + '</div>';
  }
  /* 배열 칩: 답 줄(놓인 칩 = 누르면 뺌) · 낱말(누르면 놓음 · 놓은 자리는 점선) */
  function chips(X) {
    var A = X.ar, used = {}, h = '<div class="lans" role="group" aria-label="' + TX.made + '">', i, t, dis = X.fb ? ' disabled' : '';
    for (i = 0; i < A.put.length; i += 1) {
      used[A.put[i]] = 1;
      t = A.toks[A.put[i]];
      h += '<button class="lch on" type="button" data-act="s1Lout" data-i="' + i + '" aria-label="' + esc(TX.out + t) + '"' + dis + '>' + esc(t) + '</button>';
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
      h += '<button class="sopt' + c + '" type="button" data-act="s1Lopt" data-i="' + i + '"' + (fb ? ' disabled' : '') + '>' + esc(o[i]) + (c && B.mk ? B.mk[c] : '') + '</button>';
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
  /* 구문은 길어 줄이 넘침 → 둘째 줄부터 글 칸에 맞춤(lsd · 이름 칸 60px) */
  function two(a, b) { return '<span class="sdf lsd"><span class="sdl"><b>' + TX.mine + '</b>' + a + '</span><span class="sdl"><b>' + TX.right + '</b>' + b + '</span></span>'; }
  function mark(u, f, c) { var o = [], i; for (i = 0; i < u.length; i += 1) o.push(f[i] ? '<span class="' + c + '">' + esc(u[i]) + '</span>' : esc(u[i])); return o; }
  /* 구문 «내 답 / 바른 답»(원안 .sdf): 덩어리(«/» · 없으면 낱말) · 배열 = 조각끼리 · 쓰기 = 낱말로 맞춰 다른 낱말이 든 덩어리에 밑줄 */
  function sdiff(X, v) {
    var a = str(X.q.a), sp = Lec.sayParts(a), sep = sp.length > 1 ? ' <span class="lsep" aria-hidden="true">/</span> ' : ' ', parts = sp, mw, rw = [], ci = [], bad = [], r, i, j, ws;
    if (X.ph === 'ar') {
      mw = X.ar.put.map(function (k) { return X.ar.toks[k]; });
      r = lcs(mw.map(nz), X.ar.parts.map(nz));
      return two(mark(mw, r[0], 'sdm').join(' '), mark(X.ar.parts, r[1], 'sdr').join(sep));
    }
    if (parts.length < 2) parts = words(Lec.sayText(a));
    for (i = 0; i < parts.length; i += 1) { ws = words(parts[i]); for (j = 0; j < ws.length; j += 1) { rw.push(nz(ws[j])); ci.push(i); } bad.push(0); }
    mw = words(v);
    r = lcs(mw.map(nz), rw);
    for (j = 0; j < rw.length; j += 1) { if (r[1][j]) bad[ci[j]] = 1; }
    return two(mark(mw, r[0], 'sdm').join(' '), mark(parts, bad, 'sdr').join(sep));
  }
  /* 아래: 피드백 전 = 상태 줄(다시 써 봐요 · 힌트 글) + 글자 단추(힌트 → 바른 답 보기) + «확인» · 뒤 = role=status 안에 맞아요 · 내 답 · 바른 답 · 규칙 + «다음» */
  function bottom(X) {
    var fb = X.fb, h, st = '', tx = '', g = X.f === 'c' || X.f === 'r';
    if (fb) {
      if (fb.ok) h = TX.ok;
      else if (X.ph === 'c') h = '';
      else h = X.f === 'sp' || X.f === 'r' ? B.diff(fb.v, X.q.a) : sdiff(X, fb.v);
      if (!fb.ok && g && (X.q.x || X.q.pt)) h += B.xbox(X.q.pt, X.q.x);
      return '<div class="sfb' + (fb.ok ? ' ok' : '') + '" id="lFb" role="status">' + h + '</div>' +
        '<button class="btn-fill" type="button" data-act="s1Lnext" data-kb="" data-kbend="">' + TX.next + '</button>';
    }
    if (X.msg) st = '<span class="lst">' + X.msg + '</span>';
    if (X.hint) st = '<span class="lst lhint">' + esc(hintTx(X)) + '</span>';
    if (X.tries && P.rnd === 1 && X.ph === 'w' && X.f !== 'r') tx = '<button class="ltx" type="button" data-act="s1L' + (X.hint ? 'show' : 'hint') + '" data-kb="">' + (X.hint ? TX.show : TX.hint) + '</button>';
    h = '<div class="sfb lnb" id="lFb" role="status">' + st + tx + '</div>';
    return X.ph === 'c' ? h : h + '<button class="btn-fill" type="button" data-act="s1Lchk" data-kb="">' + TX.chk + '</button>';
  }
  function fieldHTML(k) {
    var a = ' id="lIn" data-k="' + k + '" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false" enterkeyhint="done" aria-describedby="lM lFb"';
    return k === 'i' ? '<input class="sin" type="text" maxlength="200"' + a + '>' : '<textarea class="lta" rows="2" maxlength="400"' + a + '></textarea>';
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
  function draw(keep) {
    var x = W(), X, k, el, a, b, h, hb;
    prep();
    X = cur(); k = fld(X); el = $('lIn'); a = $('lA'); b = $('lB');
    h = head() + card(X);
    if (X.ph === 'ar') h += chips(X);
    if (X.ph === 'c') h += opts(X);
    hb = bottom(X);
    x.mode = 'L' + X.ph;
    if (k && el && a && b && el.getAttribute('data-k') === k) { a.innerHTML = h; b.innerHTML = hb; }
    else {
      B.page('<div id="lA">' + h + '</div>' + (k ? fieldHTML(k) : '') + '<div id="lB" class="lw">' + hb + '</div>');
      el = $('lIn');
    }
    if (!keep) P.at = Date.now();
    if (el) {
      el.className = (k === 'i' ? 'sin' : 'lta') + (X.fb ? (X.fb.ok ? ' ok' : ' no') + (k === 't' ? ' fb' : '') : (X.wr ? ' no' : ''));
      el.setAttribute('aria-label', X.f === 'r' ? '고쳐 쓴 말' : '영어로 쓰기');
      if (X.fb) el.value = str(X.fb.v);
      else if (P.dx !== X) el.value = '';
      grow(el);
      if (w.document.activeElement !== el) { try { el.focus(); } catch (e) { /* 없음 */ } }
    } else if (X.fb && !B.touch()) {
      b = w.document.querySelector('[data-act=s1Lnext]');
      if (b) { try { b.focus(); } catch (e2) { /* 없음 */ } }
    }
    P.dx = X;
    if (el) B.kb(X.fb ? 0 : 1);
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
     한 번 더 판: 틀리면 바로 바른 답 · 빈 답 = 글만 */
  function chk() {
    var X = cur(), el = $('lIn'), raw, v, ok, f;
    if (!X || fresh()) return;
    if (X.fb) { next(); return; }
    if (X.ph === 'ar') { arChk(X); return; }
    if (X.ph !== 'w' || !el) return;
    raw = str(el.value).replace(/[\r\n]+/g, ' ');
    v = raw.replace(/^\s+|\s+$/g, '');
    if (!v && (P.rnd > 1 || X.f === 'r')) { X.msg = X.f === 'r' ? TX.emptyR : TX.empty; draw(); return; }
    f = X.f === 'gw' ? 'se' : X.f;
    X.tries += 1;
    ok = judge(X, X.f, v);
    add(X, f, v, ok);
    X.msg = '';
    if (ok) { X.fb = { ok: true, v: raw }; if (X.tries > 1 || X.hint) X.bad = 1; }
    else if (P.rnd > 1 || X.f === 'r') { X.fb = { ok: false, v: raw }; X.bad = 1; }
    else { X.bad = 1; X.wr = 1; X.msg = v ? TX.again : TX.empty; }
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
  function end() {
    var x = W(), kd = P.kd, n = P.q.length, nk = null, i, h, l = P.left;
    P.end = true;
    x.mode = 'Lend';
    if (P.rows) Lec.v2End(key(), P.b).then(null, function () { return null; });
    B.S.setDirty = true;
    if (P.md === 'review') {
      for (i = 0; i < KO.length && l; i += 1) { if (+l[KO[i]] > 0) { nk = KO[i]; break; } }
    }
    h = '<div class="sres">' + B.icon('check', 36) + '<p class="sr1">' + TX.done.replace('{k}', KW[kd] || '').replace('{n}', n) + '</p>';
    if (P.md === 'review') {
      h += nk ? '<button class="btn-fill" type="button" data-act="s1Lgo">' + TX.go.replace('{k}', KW[nk]).replace('{n}', +l[nk]) + '</button>' +
        '<button class="stxt" type="button" data-act="s1back">' + TX.list + '</button>' :
        '<button class="btn-fill" type="button" data-act="s1back">' + TX.list + '</button>';
    } else {
      h += '<button class="btn-fill" type="button" data-act="s1Lgo">' + (P.md === 'gram' ? TX.goG : TX.goSet) + '</button>' +
        (P.md === 'spell' ? '<button class="btn-line" type="button" data-act="s1test">' + TX.test + '</button>' : '') +
        (P.md === 'gram' ? '<button class="btn-line" type="button" data-act="s1test">' + TX.drill + '</button>' : '') +
        '<button class="stxt" type="button" data-act="s1back">' + TX.list + '</button>';
    }
    B.page(B.head('목록') + h + '</div>');
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
      grow(t);
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
