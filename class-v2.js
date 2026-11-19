/* ===================================================================== V2-1 (11-20) 세트 학습 v2: 폰 보관함 · 보내기 · 서버 함수 감싸기(묶음 ①a)
   서버 = class-setup.sql V2-1 절 · 연습 = class-mock.js V2-1 절 · 화면(class.html)은 이 파일을 늦게 읽어 아래 V2-UI 로 부름(①b · class-api.js 옛 함수는 그대로)
   보관함: localStorage 'lec-v2b:' + 열쇠 지문(8) + ':' + 판 id 한 칸 = {b, md, st, hide, rows: [{id, i, s, k, f, v, h, ms, nx, om, pr, t, n}]}
     내 답과 순번만(바른 답 · 문항 글 없음) · 다른 학생 칸은 건드리지 않음 · 저장이 막히거나 차면 이 화면 메모리에 두고 바로 보냄
   보내는 때: 판 끝(v2End) · 숨길 때(보이지 않게 된 때 · pagehide · 판마다 두 번까지 · keepalive · 60KB 까지) · 다음에 열 때(남은 줄이 있을 때만)
     한 번에 하나 · 8초 넘으면 끊음 · 두 번 잇달아 실패하면 다음에 열 때까지 쉼 · 다시 보내는 타이머 0 · 화면 표시 0
   평가(시험 · 드릴): 50 문항마다 중간 저장(lec_set_save_v2) · 숨길 때 · 내기(lec_set_send_v2 · 실패하면 줄은 보관함에 남아 다음에 열 때 보냄)
   줄 = {id(32 글자 16진 · getRandomValues), b, i, s, k, f, v, h, ms, nx, om, pr, ago(보낼 때 폰 시각 − 답한 때), pt(답한 폰 시각), st(판을 열 때 받은 서버 오늘), n(판 끝)} */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec) return;

  var PRE = 'lec-v2b:';
  var LOG_ROWS = 100, LOG_BYTES = 61440, EV_ROWS = 300, EV_BYTES = 262144;
  var HIDE_MAX = 2, CUT_MS = 8000, FAIL_MAX = 2, SAVE_EVERY = 50, V_MAX = 401, I_MAX = 1000, OLD_MS = 2592000000, AGO_MAX = 1209600000;
  var SP2 = ',.?!;:"' + String.fromCharCode(8230);

  function str(v) { return v == null ? '' : String(v); }
  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function isObj(v) { return !!v && typeof v === 'object' && !isArr(v); }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function now() { var t = typeof Lec.now === 'function' ? +Lec.now() : Date.now(); return isFinite(t) ? Math.floor(t) : Date.now(); }
  function clen(s) { return typeof Lec.clen === 'function' ? Lec.clen(str(s)) : str(s).length; }
  function k0(key) { return key == null ? null : str(key); }
  /* 앞에서 n 글자(짝 서로게이트는 한 글자 · SQL left 와 같음) */
  function cpLeft(s, n) {
    var t = str(s), o = '', i = 0, c = 0, h;
    while (i < t.length && c < n) {
      h = t.charCodeAt(i);
      if (h >= 0xD800 && h <= 0xDBFF && i + 1 < t.length) { o += t.substr(i, 2); i += 2; } else { o += t.charAt(i); i += 1; }
      c += 1;
    }
    return o;
  }
  function nat(v, max) {
    if (v === null || v === undefined || v === '') return null;
    v = Math.floor(+v);
    return isFinite(v) && v >= 0 ? Math.min(v, max) : null;
  }

  /* ------------------------------------------------------------- 판정(SQL lec__set_snorm_v2 · lec__set_sent_v2 · lec__set_spell_v2 와 같은 셈) */

  /* 구문 쓰기 맞추기 글: «/» → 빈칸 · setNorm · 부호 여덟(, . ? ! ; : " …) 지움 · 빈칸 하나로 · 앞뒤 빈칸 */
  function setSNormV2(t) {
    var s = Lec.setNorm(str(t).replace(/\//g, ' ')), o = '', i, c;
    for (i = 0; i < s.length; i += 1) {
      c = s.charAt(i);
      if (SP2.indexOf(c) < 0) o += c;
    }
    return o.replace(/ +/g, ' ').replace(/^ +| +$/g, '');
  }
  /* 구문 쓰기 채점: 답 1~400 글자 · 맞추기 글이 비지 않고 바른 답과 통째로 같음 */
  function setSentV2(v, ans) {
    var n, a;
    if (v == null) return false;
    n = clen(v);
    if (n < 1 || n > 400) return false;
    a = setSNormV2(v);
    return a !== '' && a === setSNormV2(ans);
  }
  /* jsonb ->> 글 */
  function txt(x) {
    if (x === null || x === undefined) return null;
    if (typeof x === 'string') return x;
    if (typeof x === 'number' || typeof x === 'boolean') return String(x);
    return JSON.stringify(x);
  }
  /* 단어 쓰기 «뜻 여럿»: 이 문항 영어와 맞거나 · 같은 묶음에 뜻(맞추기 글 · 빈 뜻 빼고)이 같은 문항 영어와 맞으면 맞음 · 답 1~200 글자 */
  function setSpellV2(v, items, k) {
    var n, tgt = null, nm, i, e;
    if (v == null || k == null || !isArr(items)) return false;
    n = clen(v);
    if (n < 1 || n > 200) return false;
    k = str(k);
    for (i = 0; i < items.length; i += 1) {
      if (isObj(items[i]) && txt(items[i].k) === k) { tgt = items[i]; break; }
    }
    if (!tgt) return false;
    nm = Lec.setNorm(str(txt(tgt.m)));
    for (i = 0; i < items.length; i += 1) {
      e = items[i];
      if (!isObj(e)) continue;
      if ((txt(e.k) === k || (nm !== '' && Lec.setNorm(str(txt(e.m))) === nm)) && Lec.setMatch(str(v), str(txt(e.w)))) return true;
    }
    return false;
  }

  /* ------------------------------------------------------------- 크기 · id */

  /* jsonb::text 꼴(쉼표 · 쌍점 뒤 빈칸) · 서버 octet_length 와 같은 바이트 */
  function pgText(v) {
    var o = [], k;
    if (v === null || v === undefined) return 'null';
    if (typeof v === 'string') return JSON.stringify(v);
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    if (isArr(v)) { for (k = 0; k < v.length; k += 1) o.push(pgText(v[k])); return '[' + o.join(', ') + ']'; }
    for (k in v) { if (has(v, k) && v[k] !== undefined) o.push(JSON.stringify(k) + ': ' + pgText(v[k])); }
    return '{' + o.join(', ') + '}';
  }
  function bytes(s) {
    try { return unescape(encodeURIComponent(s)).length; } catch (e) { return str(s).length * 3; }
  }
  function rid() {
    var a = [], s = '', i, c, b;
    try {
      c = w.crypto || w.msCrypto;
      if (c && typeof c.getRandomValues === 'function') {
        b = new Uint8Array(16);
        c.getRandomValues(b);
        for (i = 0; i < 16; i += 1) a.push(b[i]);
      }
    } catch (e) { a = []; }
    for (i = a.length; i < 16; i += 1) a.push(Math.floor(Math.random() * 256));
    for (i = 0; i < 16; i += 1) s += (a[i] < 16 ? '0' : '') + a[i].toString(16);
    return s;
  }
  /* 열쇠 지문(FNV-1a 32 비트 · 16진 8 글자 · 열쇠 글자는 보관함 이름에 안 씀) */
  function fp(key) {
    var t = str(key), h = 0x811c9dc5, i, x;
    for (i = 0; i < t.length; i += 1) {
      h ^= t.charCodeAt(i);
      h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) >>> 0;
    }
    x = h.toString(16);
    return '00000000'.slice(x.length) + x;
  }

  /* ------------------------------------------------------------- 보관함 */

  var MEM = {};            /* 저장이 막히거나 찼을 때(이 화면 안에서만) */
  var memOnly = false;
  var CUR = {};            /* 이 화면에서 연 판 {b: {fp, b, md, st, next, n50, last, hide, end}} */
  var Q = { tail: Promise.resolve(), queued: null, qkey: null, fails: 0, paused: false, gone: false, key: null, today: '', swept: false, hooked: false };

  function ls() { try { return w.localStorage || null; } catch (e) { return null; } }
  function lk(f, b) { return PRE + f + ':' + b; }
  function boxKeys(f) {
    var out = [], s = ls(), i, k, n, pre = f ? PRE + f + ':' : PRE;
    if (s) {
      try {
        n = s.length;
        for (i = 0; i < n; i += 1) { k = s.key(i); if (k && k.indexOf(pre) === 0) out.push(k); }
      } catch (e) { /* 막힘 */ }
    }
    for (k in MEM) { if (has(MEM, k) && k.indexOf(pre) === 0 && out.indexOf(k) < 0) out.push(k); }
    return out.sort();
  }
  function boxDel(k) {
    var s = ls();
    delete MEM[k];
    if (s) { try { s.removeItem(k); } catch (e) { /* 막힘 */ } }
  }
  function boxGet(k) {
    var raw = null, s, o;
    if (has(MEM, k)) return MEM[k];
    s = ls();
    if (!s) return null;
    try { raw = s.getItem(k); } catch (e) { raw = null; }
    if (!raw) return null;
    try { o = JSON.parse(raw); } catch (e2) { o = null; }
    if (!isObj(o) || !isArr(o.rows) || typeof o.b !== 'string') { boxDel(k); return null; }
    return o;
  }
  /* 적음 → true(폰에 남음) · false(메모리에만 = 바로 보냄) */
  function boxPut(k, o) {
    var s;
    if (!o.rows.length) { boxDel(k); return true; }
    if (!memOnly) {
      s = ls();
      if (s) {
        try { s.setItem(k, JSON.stringify(o)); delete MEM[k]; return true; } catch (e) { /* 참 · 막힘 */ }
      }
      memOnly = true;
    }
    MEM[k] = o;
    return false;
  }
  /* 이 학생의 남은 줄(판 · 순번 차례 · b · st 붙임) */
  function pending(f, b) {
    var ks = boxKeys(f), out = [], i, j, o, r, x, y;
    for (i = 0; i < ks.length; i += 1) {
      o = boxGet(ks[i]);
      if (!o || (b && o.b !== b)) continue;
      for (j = 0; j < o.rows.length; j += 1) {
        r = o.rows[j];
        x = {};
        for (y in r) { if (has(r, y)) x[y] = r[y]; }
        x.b = o.b;
        x.st = str(o.st);
        out.push(x);
      }
    }
    out.sort(function (m, n) { return m.b === n.b ? m.i - n.i : (m.b < n.b ? -1 : 1); });
    return out;
  }
  function boxSum(f) {
    var rows = pending(f), t = now(), old = t, i;
    for (i = 0; i < rows.length; i += 1) { if (typeof rows[i].t === 'number' && rows[i].t < old) old = rows[i].t; }
    return { n: rows.length, age: Math.max(0, t - old) };
  }
  /* 받은 줄(got) · 꼴 틀린 줄(bad)을 이 학생 칸에서 뺌 */
  function drop(f, r) {
    var ids = {}, a = (isArr(r.got) ? r.got : []).concat(isArr(r.bad) ? r.bad : []), ks, i, o, keep;
    if (!a.length) return;
    for (i = 0; i < a.length; i += 1) ids['#' + a[i]] = 1;
    ks = boxKeys(f);
    for (i = 0; i < ks.length; i += 1) {
      o = boxGet(ks[i]);
      if (!o) continue;
      keep = o.rows.filter(function (x) { return !ids['#' + x.id]; });
      if (keep.length !== o.rows.length) { o.rows = keep; boxPut(ks[i], o); }
    }
  }
  /* 한 달 넘은 칸(모든 학생 · 가장 늦은 줄 기준)은 지움(서버도 14일 넘은 답은 14일 전으로 셈) · 화면마다 한 번 */
  function sweep() {
    var ks, i, o, j, t = now(), late;
    if (Q.swept) return;
    Q.swept = true;
    ks = boxKeys('');
    for (i = 0; i < ks.length; i += 1) {
      o = boxGet(ks[i]);
      if (!o) continue;
      late = 0;
      for (j = 0; j < o.rows.length; j += 1) { if (typeof o.rows[j].t === 'number' && o.rows[j].t > late) late = o.rows[j].t; }
      if (t - late > OLD_MS) boxDel(ks[i]);
    }
  }

  /* ------------------------------------------------------------- 보내기 */

  function wire(r, t) {
    var o = { id: str(r.id), b: str(r.b), i: r.i, v: str(r.v), h: !!r.h, st: str(r.st) }, a;
    a = typeof r.t === 'number' && isFinite(r.t) ? t - r.t : 0;
    o.ago = Math.floor(Math.max(0, Math.min(a, AGO_MAX)));
    if (typeof r.t === 'number' && isFinite(r.t) && r.t >= 0) o.pt = Math.floor(r.t);
    if (r.s) o.s = str(r.s);
    if (r.k != null && r.k !== '') o.k = str(r.k);
    if (r.f) o.f = str(r.f);
    if (r.n != null) o.n = r.n;
    if (r.ms != null) o.ms = r.ms;
    if (r.nx != null) o.nx = r.nx;
    if (r.om != null) o.om = r.om;
    if (typeof r.pr === 'boolean') o.pr = r.pr;
    return o;
  }
  /* 앞에서부터 maxN 줄 · maxB 바이트(서버 셈)까지 */
  function chunk(rows, maxN, maxB, extra) {
    var out = [], size = 2 + (extra || 0), i, s;
    for (i = 0; i < rows.length && out.length < maxN; i += 1) {
      s = bytes(pgText(rows[i])) + (out.length ? 2 : 0);
      if (out.length && size + s > maxB) break;
      out.push(rows[i]);
      size += s;
    }
    return out;
  }
  function fail(e) {
    if (e && (e.status === 404 || e.status === 401 || e.status === 403 || e.code === 'PGRST202' || e.code === '42883')) {
      Q.gone = true;
      return { ok: false, err: 'old' };
    }
    return { ok: false, err: e && e.message === 'network' ? 'network' : 'error' };
  }
  /* 8초 넘으면 끊음(답이 늦게 와도 줄은 보관함에 남아 다음에 다시 · 서버는 같은 id 를 한 번만 받음) */
  function cut(p) {
    return new Promise(function (res) {
      var done = false, tm = setTimeout(function () {
        if (done) return;
        done = true;
        res({ ok: false, err: 'network', cut: true });
      }, CUT_MS);
      p.then(function (r) {
        if (done) return;
        done = true;
        clearTimeout(tm);
        res(r);
      }, function () {
        if (done) return;
        done = true;
        clearTimeout(tm);
        res({ ok: false, err: 'network' });
      });
    });
  }
  function call(fn, args, opt) {
    var p;
    if (w.__lecPvIn) return Promise.resolve({ ok: false, err: 'preview' });   /* 미리 보기 안쪽 = 부르지 않음 */
    if (Q.gone) return Promise.resolve({ ok: false, err: 'old' });            /* v2 함수가 없는 서버 = 이 화면에서는 다시 안 부름 */
    try { p = Lec.rpc(fn, args, opt); } catch (e0) { return Promise.resolve(fail(e0)); }
    return cut(Promise.resolve(p).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, fail).then(null, function () { return { ok: false, err: 'error' }; }));
  }
  /* 응답 셈: ok = 받은 줄을 뺌 · 실패 = 잇단 실패 수(둘이면 다음에 열 때까지 쉼) */
  function took(f, r) {
    if (r && r.ok) { drop(f, r); Q.fails = 0; return true; }
    Q.fails += 1;
    if (Q.fails >= FAIL_MAX) Q.paused = true;
    return false;
  }
  /* 한 번에 하나(앞 보내기가 끝난 뒤) */
  function enqueue(task) {
    var p = Q.tail.then(task, task);
    Q.tail = p.then(null, function () { return null; });
    return p;
  }
  function flushNow(key) {
    var f = fp(key), prev = -1, last = { ok: true, n: 0 };
    function step() {
      var rows, part, t;
      if (Q.paused) return Promise.resolve({ ok: false, err: 'pause' });
      rows = pending(f);
      if (!rows.length || rows.length === prev) return Promise.resolve(last);
      prev = rows.length;
      t = now();
      part = chunk(rows.map(function (r) { return wire(r, t); }), LOG_ROWS, LOG_BYTES, bytes(str(key)) + 32);
      return call('lec_set_log_v2', { p_key: str(key), p_rows: part }).then(function (r) {
        if (!took(f, r)) return r;
        last = r;
        return step();
      });
    }
    return step();
  }
  /* 남은 줄 보내기(이미 줄 선 같은 학생 보내기가 있으면 거기에 합침) */
  function flush(key) {
    var p;
    key = str(key);
    if (Q.queued && Q.qkey === key) return Q.queued;
    p = enqueue(function () {
      if (Q.queued === p) Q.queued = null;
      return flushNow(key);
    });
    Q.queued = p;
    Q.qkey = key;
    return p;
  }
  /* 평가 중간 저장(50 문항마다) */
  function saveEv(key, b) {
    return enqueue(function () {
      var f = fp(key), t = now(), part;
      if (Q.paused) return { ok: false, err: 'pause' };
      part = chunk(pending(f, b).map(function (r) { return wire(r, t); }), EV_ROWS, EV_BYTES, 0);
      if (!part.length) return { ok: true, n: 0 };
      return call('lec_set_save_v2', { p_key: str(key), p_try: b, p_rows: part }).then(function (r) {
        took(f, r);
        return r;
      });
    });
  }
  /* 숨길 때(보이지 않게 된 때 · pagehide): 지금 학생 줄을 keepalive 로 한 번(판마다 두 번까지 · 60KB 까지 · 쉬는 중이면 안 보냄 ·
     앞 숨김에서 아직 답이 안 온 줄은 다시 안 실음) */
  var FLY = {};
  function onHide() {
    var key = Q.key, f, ks, list = [], rows = [], t = now(), part, bs = {}, ids = [], i, j, o, c, hd;
    if (!key || Q.paused || Q.gone || w.__lecPvIn) return;
    f = fp(key);
    ks = boxKeys(f);
    for (i = 0; i < ks.length; i += 1) {
      o = boxGet(ks[i]);
      if (!o || !o.rows.length) continue;
      c = CUR[o.b];
      hd = Math.max(+o.hide || 0, c && c.fp === f ? c.hide : 0);
      if (hd >= HIDE_MAX) continue;
      list.push({ k: ks[i], o: o, hd: hd });
      for (j = 0; j < o.rows.length; j += 1) {
        if (FLY['#' + o.rows[j].id]) continue;
        rows.push(wire({ id: o.rows[j].id, b: o.b, i: o.rows[j].i, s: o.rows[j].s, k: o.rows[j].k, f: o.rows[j].f, v: o.rows[j].v,
                         h: o.rows[j].h, ms: o.rows[j].ms, nx: o.rows[j].nx, om: o.rows[j].om, pr: o.rows[j].pr, t: o.rows[j].t,
                         n: o.rows[j].n, st: o.st }, t));
      }
    }
    part = chunk(rows, LOG_ROWS, LOG_BYTES, bytes(key) + 32);
    if (!part.length) return;
    for (i = 0; i < part.length; i += 1) {
      bs['#' + part[i].b] = 1;
      FLY['#' + part[i].id] = 1;
      ids.push(part[i].id);
    }
    for (i = 0; i < list.length; i += 1) {
      if (!bs['#' + list[i].o.b]) continue;
      list[i].o.hide = list[i].hd + 1;
      boxPut(list[i].k, list[i].o);
      c = CUR[list[i].o.b];
      if (c && c.fp === f) c.hide = list[i].o.hide;
    }
    call('lec_set_log_v2', { p_key: key, p_rows: part }, { keepalive: true }).then(function (r) {
      for (i = 0; i < ids.length; i += 1) delete FLY['#' + ids[i]];
      if (r && r.ok) drop(f, r);
    });
  }
  function hook() {
    if (Q.hooked) return;
    Q.hooked = true;
    try {
      if (w.document && w.document.addEventListener) {
        w.document.addEventListener('visibilitychange', function () {
          if (w.document.visibilityState === 'hidden') onHide();
        });
      }
      if (w.addEventListener) w.addEventListener('pagehide', onHide);
    } catch (e) { /* 없음 */ }
  }
  /* 다음에 열 때: 쉼을 풀고 · 남은 줄이 있을 때만 먼저 보냄 */
  function opened(key) {
    Q.key = str(key);
    Q.paused = false;
    Q.fails = 0;
    sweep();
  }
  function before(key) {
    opened(key);
    if (!pending(fp(key)).length) return Promise.resolve(null);
    return flush(key).then(null, function () { return null; });
  }
  /* 판 적어 둠(이 화면 안 · 다음 순번 = 서버가 받은 가장 큰 순번 · 보관함 줄 가운데 큰 것 + 1) */
  function reg(key, b, md, st, last) {
    var f = fp(key), o = boxGet(lk(f, b)), mx = Math.max(0, Math.floor(+last) || 0), c = CUR[b], i;
    if (o) { for (i = 0; i < o.rows.length; i += 1) mx = Math.max(mx, +o.rows[i].i || 0); }
    c = c && c.fp === f ? c : null;
    CUR[b] = { fp: f, b: b, md: md, st: str(st), next: Math.max(c ? c.next : 1, mx + 1), n50: 0, last: c ? c.last : null,
               hide: c ? c.hide : 0, end: null };
    hook();
    return CUR[b];
  }

  /* ------------------------------------------------------------- 학생: 화면이 부르는 손잡이 */

  /* 목록(옛 lec_set_home 그대로 + v2 스위치 · ts · todo) · 남은 줄이 있으면 먼저 보냄 · 보관함 남은 줄 수 · 나이를 서버에 알림 */
  function setHomeV2(key) {
    if (key == null || key === '') return Promise.resolve({ ok: false, err: 'key' });
    return before(key).then(function () {
      var s = boxSum(fp(key));
      return call('lec_set_home_v2', { p_key: str(key), p_box: { n: s.n, age: s.age } });
    }).then(function (r) {
      if (r.ok && typeof r.today === 'string') Q.today = r.today;
      return r;
    });
  }
  /* 연습 판 열기(md = 'mem' 외우기 · 'due' 쌓인 오답) · 'off' · 'old' = 옛 함수로 · ok = r.b 판에 v2Add 로 답을 적음 */
  function setOpenV2(key, id, md) {
    return before(key).then(function () {
      return call('lec_set_open_v2', { p_key: k0(key), p_set: id || null, p_md: str(md) });
    }).then(function (r) {
      if (r.ok && typeof r.b === 'string' && r.b) reg(key, r.b, str(r.md || md), r.today, r.last);
      return r;
    });
  }
  /* 폰이 만든 판(log 단계 · 옛 함수가 카드를 바꾸고 v2 줄은 기록만) → 판 id */
  function v2Local(key) {
    var b = typeof Lec.uuid === 'function' ? Lec.uuid() : null;
    if (!b || key == null || key === '') return null;
    Q.key = str(key);
    reg(key, b, 'log', Q.today || (typeof Lec.isoDay === 'function' ? Lec.isoDay(now()) : ''), 0);
    return b;
  }
  /* 답 한 줄 적기(동기) · o = {s, k, f, v, h, ms, nx, om, pr} · 평가 판은 o.i = 문항 차례(0부터) → {id, i} · 못 적음 = null */
  function v2Add(key, b, o) {
    var c = CUR[str(b)], f = fp(key), k, e, i, j, mx, r, kept;
    if (!c || c.fp !== f || !isObj(o)) return null;
    k = lk(f, c.b);
    e = boxGet(k) || { b: c.b, md: c.md, st: c.st, hide: c.hide, rows: [] };
    if (c.md === 'ev') {
      i = Math.floor(+o.i) + 1;
      if (!(i >= 1 && i <= I_MAX)) return null;
    } else {
      mx = 0;
      for (j = 0; j < e.rows.length; j += 1) mx = Math.max(mx, +e.rows[j].i || 0);
      i = Math.max(c.next, mx + 1);
      if (i > I_MAX) return null;
      c.next = i + 1;
    }
    r = { id: rid(), i: i, v: cpLeft(str(o.v), V_MAX), h: !!o.h, t: now() };
    if (o.s) r.s = str(o.s);
    if (o.k != null && o.k !== '') r.k = str(o.k);
    if (o.f) r.f = str(o.f);
    if (nat(o.ms, 3600000) !== null) r.ms = nat(o.ms, 3600000);
    if (nat(o.nx, 600000) !== null) r.nx = nat(o.nx, 600000);
    if (nat(o.om, 600000) !== null) r.om = nat(o.om, 600000);
    if (typeof o.pr === 'boolean') r.pr = o.pr;
    if (c.end != null) r.n = c.end;
    e.rows.push(r);
    kept = boxPut(k, e);
    c.last = r;
    Q.key = str(key);
    if (!kept) flush(key);   /* 저장이 막히거나 참 = 바로 보냄 */
    else if (c.md === 'ev' && !o.end) {   /* ①b 마지막 문항(바로 뒤 내기)은 중간 저장을 안 부름 = 50문항 2번 · 300문항 7번 */
      c.n50 += 1;
      if (c.n50 >= SAVE_EVERY) { c.n50 = 0; saveEv(str(key), c.b); }
    }
    return { id: r.id, i: i };
  }
  /* 판 끝(n = 판 끝 줄 수 · 없으면 마지막 순번) → 남은 줄 보냄 · 응답(me · due = 목록 숫자) */
  function v2End(key, b, n, lr) {   /* ①b lr = 다시 연 판에서 이 화면이 줄을 아직 안 적었을 때 마지막 줄(같은 id · 쌓인 오답 이어 하기) */
    var c = CUR[str(b)], f = fp(key), k, e, j, nn, r, cl;   /* ①b */
    if (!c || c.fp !== f) return Promise.resolve({ ok: false, err: 'board' });
    nn = Math.floor(+n);
    if (!(nn >= 1 && nn <= I_MAX)) nn = c.next - 1 >= 1 ? Math.min(c.next - 1, I_MAX) : null;
    c.end = nn;
    k = lk(f, c.b);
    e = boxGet(k);
    if (nn !== null && e && e.rows.length) {
      for (j = 0; j < e.rows.length; j += 1) e.rows[j].n = nn;
      boxPut(k, e);
    } else if (nn !== null && (cl = c.last || (isObj(lr) && typeof lr.id === 'string' ? lr : null)) && c.md !== 'ev') {   /* ①b */
      /* 줄이 다 갔으면 마지막 줄을 같은 id 로 한 번 더(서버는 줄을 다시 넣지 않고 판 끝만 적음) */
      r = {};
      for (j in cl) { if (has(cl, j)) r[j] = cl[j]; }   /* ①b */
      r.n = nn;
      boxPut(k, { b: c.b, md: c.md, st: c.st, hide: c.hide, rows: [r] });
    }
    Q.key = str(key);
    return flush(key);
  }
  /* 평가 열기(단어 시험 · 문법 드릴) · 바른 답 0 · sv = 서버에 저장된 내 답 · box = 이 폰 보관함에만 있는 내 답 [{i(0부터), v}] */
  function setTestV2(key, id) {
    return before(key).then(function () {
      return call('lec_set_test_v2', { p_key: k0(key), p_set: id || null });
    }).then(function (r) {
      var e, j, mine = [];
      if (r.ok && typeof r['try'] === 'string' && r['try']) {
        reg(key, r['try'], 'ev', typeof Lec.isoDay === 'function' && r.ts != null ? Lec.isoDay(+r.ts) : '', 0);
        e = boxGet(lk(fp(key), r['try']));
        if (e) { for (j = 0; j < e.rows.length; j += 1) mine.push({ i: e.rows[j].i - 1, v: str(e.rows[j].v) }); }
        r.box = mine;
      }
      return r;
    });
  }
  /* 평가 내기: 이 판 남은 줄을 보내고 채점(300 줄 · 256KB 넘으면 앞은 중간 저장으로) → done · end · ans(바른 답) · me · due 또는 done false · miss */
  function setSendV2(key, tryId) {
    var b = str(tryId);
    opened(key);   /* 내기 = 학생이 누름 → 쉼을 풂 */
    return enqueue(function () {
      var f = fp(key), t = now(), all = pending(f, b).map(function (r) { return wire(r, t); }), parts = [], p;
      while (all.length) {
        p = chunk(all, EV_ROWS, EV_BYTES, 0);
        parts.push(p);
        all = all.slice(p.length);
      }
      if (!parts.length) parts.push([]);
      function step(j) {
        var last = j === parts.length - 1;
        return call(last ? 'lec_set_send_v2' : 'lec_set_save_v2', { p_key: k0(key), p_try: b || null, p_rows: parts[j] }).then(function (r) {
          if (!took(f, r) || last) return r;
          return step(j + 1);
        });
      }
      return step(0);
    });
  }

  /* ------------------------------------------------------------- 선생님: 지켜보기(원장님 · 선생님 · 읽기만) */

  function staffGone(e) {
    if (typeof Lec.rngGoneErr === 'function') return Lec.rngGoneErr(e);
    return !!e && (e.status === 404 || e.code === 'PGRST202' || e.code === 'PGRST205' || e.code === '42883' || e.code === '42P01');
  }
  /* call(fn, args) = 선생님 화면의 서버 부르기 · days = 1~60(비면 14) → {ok, from, to, sw, days, calls, box} · 옛 서버 = 'old' */
  function v2Watch(callFn, days) {
    var p, d = days == null || days === '' ? null : Math.floor(+days);
    if (d !== null && !(d >= 1 && d <= 60)) d = null;
    if (typeof callFn !== 'function') return Promise.resolve({ ok: false, err: 'network' });
    try { p = callFn('lec_v2_watch', { p_days: d }); } catch (e0) { return Promise.resolve(staffGone(e0) ? { ok: false, err: 'old' } : { ok: false, err: 'error' }); }
    return Promise.resolve(p).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, function (e) {
      if (staffGone(e)) return { ok: false, err: 'old' };
      return { ok: false, err: e && e.message === 'network' ? 'network' : 'error' };
    }).then(null, function () { return { ok: false, err: 'error' }; });
  }

  var api = {
    setSNormV2: setSNormV2, setSentV2: setSentV2, setSpellV2: setSpellV2,
    setHomeV2: setHomeV2, setOpenV2: setOpenV2, setTestV2: setTestV2, setSendV2: setSendV2,
    v2Add: v2Add, v2End: v2End, v2Local: v2Local, v2Watch: v2Watch
  };
  for (var name in api) { if (has(api, name)) Lec[name] = api[name]; }
})(window);

/* ===================================================================== V2-UI (11-20 · 묶음 ①b) 세트 학습 v2 화면 손잡이 Lec.v2u
   class.html 이 이 파일을 늦게 읽은 뒤(세트 칸을 열 때 · 판에 들어갈 때 · 보관함에 남은 줄이 있을 때 한가할 때) Lec.v2u.init(다리)로 이음
   스위치 = 홈 _v2 의 v2(S.set.v2) · 끔 · v2 없는 서버 = 옛 함수 그대로(부르는 횟수 같음) · log = 옛 길 + 기록 줄(카드는 옛 함수가 바꿈 · 두 번 세지 않음)
   eval = 평가(단어 시험 · 문법 드릴) 열기 1 + 50 문항마다 1 + 내기 1 · 문항마다 서버 0 · 칸 잠금 0 · 맞음 · 틀림은 끝에 모아
          연습(외우기 · 쌓인 오답) 열기 1 + 판 끝 1 · 쌓인 오답은 받은 바른 답으로 폰에서 바로 채점(서버와 같은 셈)
          쌓인 오답을 풀다 닫으면 같은 서버 날 같은 판은 남은 문항부터(폰 'lec-v2d:' · 서버 그대로 · 아래 dueMine)
   재기(기록 줄): om 판을 연 누름 → 첫 문항 그림 · nx 앞 답 누름 → 이 문항 그림 · ms 이 문항 그림 → 답
   TX = 새 화면 글(디자인 회의 전 자리 글) */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec || typeof Lec.v2Add !== 'function') return;

  var OLD_K = 'lec-v2-old', OLD_MS = 43200000;   /* v2 없는 서버를 이 폰에 기억(12시간 · 그동안 홈 _v2 · 이 파일을 안 부름) */
  var TX = {
    send: '다 풀었어요. 답은 모두 남아 있어요. 조금 뒤 다시 열어 봐요.',
    note: '다 풀면 바른 답을 한 번에 보여 줘요',
    noteG: '다 풀면 바른 답과 해설을 한 번에 보여 줘요',
    wrong: '틀린 문제 ',
    wsub: '한 번 더 풀어도 점수에는 안 들어가요',
    aq: '틀린 것 한 번 더 풀기',
    mine: '내 답', right: '바른 답'
  };
  var CSS = '.v2w{margin:12px 0 0;padding:16px 16px 6px;border:1px solid var(--line);border-radius:16px;background:var(--card)}' +
    '.v2h{margin:0;font-size:15px;font-weight:700;line-height:1.4}' +
    '.v2u{margin:2px 0 0;font-size:13px;font-weight:600;line-height:1.5;color:var(--ink2)}' +
    '.v2w>.btn-line{margin:12px 0 4px}' +
    '.v2l{margin:0;padding:0;list-style:none}' +
    '.v2i{padding:12px 0;border-top:1px solid var(--line);font-size:15px;line-height:1.55}' +
    '.v2q{margin:0 0 4px;text-align:justify;word-break:keep-all;overflow-wrap:break-word}' +
    '.v2n{display:inline-block;min-width:24px;margin-right:4px;font-size:13px;font-weight:600;color:var(--ink2);font-variant-numeric:tabular-nums}' +
    '.v2s{display:inline-block;min-width:36px;padding:0 6px;border:1.5px dashed var(--dash);border-radius:6px;line-height:1.4;text-align:center;color:var(--ink2)}' +
    '.v2i .sx{margin-top:8px}';
  var B = null;

  function str(v) { return v == null ? '' : String(v); }
  function esc(s) { return Lec.esc(str(s)); }
  function W() { return B.W(); }
  function key() { return B.S.key; }
  function on(f) { var s = B && B.S.set; return !!(s && s.v2 && s.v2[f]) && !B.pv(); }
  function oldNow() { return +Lec.lsGet(OLD_K, 0) > Date.now() - OLD_MS; }
  /* 쌓인 오답 이어 하기(eval · 폰만 · 서버 그대로): 'lec-v2d:' + 열쇠 지문 = {day: 서버 날, b: 판, a: {'s|k': [내 답, 맞음]}, l: 마지막 줄(같은 id)}
     같은 날 같은 판을 다시 열면 답한 문항은 답한 채로 두고 남은 문항부터 · 다른 날 · 다른 판 = 지움 · 판 끝을 서버가 받으면 지움 */
  function dk(k) {
    var t = str(k == null ? key() : k), h = 0x811c9dc5, i;
    for (i = 0; i < t.length; i += 1) { h ^= t.charCodeAt(i); h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) >>> 0; }
    return 'lec-v2d:' + h.toString(16);
  }
  function dueMine(x, r) {
    var m = Lec.lsGet(dk(), null), o = [], q = r.q || [], i, a;
    if (m && (typeof m !== 'object' || m.day !== str(r.today) || m.b !== str(r.b) || !m.a || typeof m.a !== 'object')) { Lec.lsDel(dk()); m = null; }
    x.dm = m || { day: str(r.today), b: str(r.b), a: {}, l: null };
    for (i = 0; m && i < q.length; i += 1) {
      a = m.a[str(q[i].s) + '|' + str(q[i].k)];
      if (a) o.push({ i: i, v: str(a[0]), r: !!a[1], a: str(q[i].a), x: str(q[i].x), pt: str(q[i].pt) });
    }
    return o;
  }

  /* 목록 묶음: 홈 _v2(스위치 · 서버 오늘 · 남은 줄 먼저 보냄) · v2 없는 서버(old) · 서버 오류 = 옛 lec_set_home 그대로 ·
     끊김 · 열쇠 · 기록 동의 = 그 답 그대로(옛 길에서 실패한 것과 같은 결과 · 더 부르지 않음) */
  function home(k) {
    if (oldNow()) return Lec.setHome(k);
    return Lec.setHomeV2(k).then(function (r) {
      var e = r && r.err, m;
      if (r && r.ok) {
        m = Lec.lsGet(dk(k), null);   /* 쌓인 오답 이어 하기 기억 · 서버 날이 지났으면 지움 */
        if (m && r.ts != null && typeof Lec.isoDay === 'function' && (typeof m !== 'object' || m.day !== Lec.isoDay(+r.ts))) Lec.lsDel(dk(k));
        return r;
      }
      if (e === 'old') Lec.lsSet(OLD_K, Date.now());
      return e === 'old' || e === 'error' ? Lec.setHome(k) : r;
    });
  }
  function tm(at) {
    var x = W(), t = Date.now(), o = {};
    if (at) o.ms = Math.max(0, t - at);
    if (x.tap && at >= x.tap) o.nx = at - x.tap;
    else if (x.op && !x.omd && at >= x.op) { o.om = at - x.op; x.omd = 1; }
    x.tap = t;
    return o;
  }
  function row(q, v, pr) {
    var o = tm(B.W().t ? B.W().t.at : 0), s = str(q.s || W().id);
    o.v = v;
    o.f = str(q.f);
    if (s) o.s = s;
    if (q.k != null && q.k !== '') o.k = str(q.k);
    if (pr !== null) o.pr = pr;
    return o;
  }
  /* 다시 열기: 서버 임시 답(sv · 옛 화면에서 쓴 답 포함) + 이 폰 보관함(box) → 옛 done 꼴(맞음 · 틀림은 내기 뒤에 받음) */
  function mine(r) {
    var o = [], seen = {}, a = (r.sv || []).concat(r.box || []), i, e;
    for (i = 0; i < a.length; i += 1) {
      e = a[i];
      if (e && e.i >= 0 && !seen['#' + e.i] && str(e.v) !== '') { seen['#' + e.i] = 1; o.push({ i: +e.i, v: str(e.v), r: false }); }
    }
    return o;
  }
  /* 시험 · 드릴 · 쌓인 오답 열기(tStart): eval = 평가 열기 _v2 · 연습 열기 _v2(due) · 스위치가 그새 꺼짐(off) · v2 없음(old) = 옛 함수로 한 번 */
  function open(due, k, id) {
    var x = W();
    function old() { return due ? Lec.setDue(k) : Lec.setTest(k, id); }
    x.ev = ''; x.lb = null; x.dm = null; x.op = Date.now(); x.tap = 0; x.omd = 0;
    if (!on('eval')) {
      if (on('log')) x.lb = Lec.v2Local(k);
      return old();
    }
    x.ev = due ? 'due' : 'ev';
    return (due ? Lec.setOpenV2(k, null, 'due') : Lec.setTestV2(k, id)).then(function (r) {
      var e = r && r.err;
      if (e === 'off' || e === 'old') {
        if (B.S.set) B.S.set.v2 = null;
        x.ev = '';
        return old();
      }
      if (r && r.ok) {
        if (due) { r['try'] = r.b || null; r.done = dueMine(x, r); }
        else r.done = mine(r);
      }
      return r;
    });
  }
  /* 답 하나(tSend · 처음 풀기) → true = 여기서 다룸 · false = 옛 길 그대로(log 는 기록 줄만 적고 옛 setAns) */
  function ans(t, v, sel) {
    var x = W(), k = key(), idx = t.i, q = t.q[idx] || {}, o, j, left, ok, a;
    if (!x.ev) {
      if (x.lb) Lec.v2Add(k, x.lb, row(q, v, null));
      return false;
    }
    t.step += 1;
    if (x.ev === 'due') {
      a = str(q.a);
      ok = q.f === 'c' ? Lec.setNorm(v) === Lec.setNorm(a) : !!Lec.setMatch(v, a);
      j = Lec.v2Add(k, t.id, row(q, v, ok));
      if (j && x.dm) {
        o = { id: j.id, i: j.i, v: str(v).slice(0, 400), h: false, t: Date.now(), f: str(q.f), pr: ok };
        if (q.s) o.s = str(q.s);
        if (q.k != null && q.k !== '') o.k = str(q.k);
        x.dm.a[str(q.s) + '|' + str(q.k)] = [o.v, ok];
        x.dm.l = o;
        Lec.lsSet(dk(), x.dm);
      }
      t.ans[idx] = { v: v, r: ok, a: a, x: str(q.x), pt: str(q.pt) };
      t.ph = 'shown';
      t.fb = { ok: ok, a: a, x: str(q.x), pt: str(q.pt), v: v, sel: sel };
      t.fbNew = true;
      B.draw(); B.auto();
      return true;
    }
    left = 0;
    for (j = 0; j < t.n; j += 1) { if (j !== idx && !t.ans[j]) left += 1; }
    o = row(q, v, null);
    o.i = idx;
    o.end = !left;
    Lec.v2Add(k, t.id, o);
    t.ans[idx] = { v: v, r: false, a: '', x: '', pt: '' };
    B.S.setDirty = true;
    j = t.pos + 1;
    while (j < t.n && t.ans[t.ord[j]]) j += 1;
    if (j >= t.n) { j = 0; while (j < t.n && t.ans[t.ord[j]]) j += 1; }
    if (j < t.n) { t.pos = j; t.i = t.ord[j]; B.draw(); return true; }
    B.after();
    return true;
  }
  /* 처음 풀기를 다 함(tAfter) → true = 내기로 감 · false = 옛 길(틀린 것 한 번 더 · 결과) */
  function after(t) {
    var x = W(), k = key();
    if (x.lb && !t.lbE) { t.lbE = 1; Lec.v2End(k, x.lb); }
    if (x.ev === 'due' && !t.vp0) {
      t.vp0 = 1;
      t.vp = Lec.v2End(k, t.id, null, x.dm && x.dm.l).then(function (r) {
        var s = B.S.set, n;
        t.vp = null;
        if (r && r.ok) { Lec.lsDel(dk()); x.dm = null; }
        if (r && r.ok && r.due && r.due.n != null) {
          n = +r.due.n || 0;
          t.end = { out: Math.max(0, (s && s.due ? +s.due.n || 0 : 0) - n), due: n };
          apply(r.me, r.due);
        }
      });
    }
    if (x.ev !== 'ev' || t.sent) return false;
    send(t, 0);
    return true;
  }
  /* 내기(확인 창 0): done = 바른 답 · 결과 · 목록 숫자를 받아 결과로 · miss = 서버에 없는 문항부터 다시 · 못 받음 = 한 번 조용히 다시 → 자리 글
     (줄은 보관함에 남아 다음에 열 때 · 숨길 때 다시 감 · 서버는 같은 줄을 한 번만 받음) */
  function send(t, n) {
    var x = W(), k = key(), my = B.my();
    if (t.sending) return;
    t.sending = 1;
    x.mode = 'tsend';
    B.page(B.head('목록') + '<div class="sload"></div>');
    Lec.setSendV2(k, t.id).then(function (r) {
      var i, a, j, m;
      t.sending = 0;
      if (my !== B.my() || W() !== x || x.t !== t) return;
      if (r && r.ok && r.done) {
        a = r.ans || [];
        for (i = 0; i < a.length; i += 1) {
          if (a[i] && a[i].i >= 0 && a[i].i < t.n) t.ans[a[i].i] = { v: str(a[i].v), r: !!a[i].r, a: str(a[i].a), x: str(a[i].x), pt: str(a[i].pt) };
        }
        t.end = r.end || null;
        t.sent = 1;
        x.mode = 't';
        m = {};
        m[x.id] = r.me;
        apply(m, r.due);
        B.res();
        return;
      }
      if (r && r.ok && r.miss && r.miss.length) {
        for (i = 0; i < r.miss.length; i += 1) { j = +r.miss[i]; if (j >= 0 && j < t.n) t.ans[j] = undefined; }
        t.pos = 0;
        while (t.pos < t.n && t.ans[t.ord[t.pos]]) t.pos += 1;
        if (t.pos < t.n) { t.i = t.ord[t.pos]; t.ph = 'q'; x.mode = 't'; B.draw(); return; }
      }
      if (r && (r.err === 'key' || r.err === 'consent') && B.gone(r)) return;
      if (r && (r.err === 'try' || r.err === 'done')) { B.info(t.title, B.tx(r.err)); return; }
      if (!n && !(r && r.cut)) { send(t, 1); return; }
      B.info(t.title, TX.send);
    });
  }
  /* 받은 목록 숫자를 묶음에 넣음(목록으로 돌아갈 때 다시 받지 않음) · me = {세트 id: me} */
  function apply(me, due) {
    var s = B.S.set, a = s && s.sets, i;
    if (!s) return;
    for (i = 0; a && i < a.length; i += 1) { if (a[i] && me && me[a[i].id]) a[i].me = me[a[i].id]; }
    if (due && due.n != null) s.due = due;
    B.S.setDirty = false;
  }
  /* 결과 아래: 틀린 것 전부 펼침(화면 차례) · 쓰기 = 다른 글자 밑줄(tDiffHTML) · 고르기 = 두 줄 · 문법 = 해설 · 포인트 + «한 번 더»(점수 0 · 서버 0) */
  function wrong(t) {
    var h = '', n = 0, j, i, q, a, gp, p, g;
    for (j = 0; j < t.n; j += 1) {
      i = t.ord[j]; a = t.ans[i]; q = t.q[i] || {};
      if (!a || a.r) continue;
      n += 1;
      g = B.gram(t, q);
      if (g) {
        gp = Lec.gramParts(str(q.p)) || {};
        p = B.gesc(gp.pre, 1) + (q.f === 'c' ? '<span class="v2s">?</span>' : '<span class="sund">' + esc(gp.mid) + '</span>') + B.gesc(gp.post, 0);
      } else p = esc(q.p);
      h += '<li class="v2i"><p class="v2q"><span class="v2n">' + (j + 1) + '</span>' + p + '</p>' +
        (q.f === 'c' ? '<span class="sdf"><span class="sdl"><b>' + TX.mine + '</b> <span class="sdm">' + esc(a.v) + '</span></span>' +
          '<span class="sdl"><b>' + TX.right + '</b> <span class="sdr">' + esc(a.a) + '</span></span></span>' : B.diff(a.v, a.a)) +
        (g ? B.xbox(a.pt, a.x) : '') + '</li>';
    }
    if (!n) return '';
    return '<section class="v2w" aria-label="' + TX.wrong + n + '개"><h2 class="v2h">' + TX.wrong + n + '개</h2><p class="v2u">' + TX.wsub + '</p>' +
      '<button class="btn-line" type="button" data-act="s1aq">' + TX.aq + '</button><ol class="v2l">' + h + '</ol></section>';
  }
  /* 평가 첫 문항 위 안내(tNote · 자리 글) */
  function note(t) {
    var g = W().kind === 'gram', nc = 0, nw = 0, dr = t.draw && t.all > t.n, i, l1;
    if (g) {
      for (i = 0; i < t.n; i += 1) { if ((t.q[i] || {}).f === 'c') nc += 1; else nw += 1; }
      l1 = nc && nw ? '괄호 고르기가 먼저, 고쳐 쓰기가 뒤에 나와요' : (nc ? '괄호 안에서 알맞은 말을 골라요' : '밑줄 친 말을 바르게 고쳐 써요');
      return '<p class="snote">' + l1 + '<br>' + (dr ? t.all + '문제 가운데 ' : '') + t.n + '문제 · ' + t.need + '개 맞히면 통과<br>' + TX.noteG + '</p>';
    }
    if (t.round > 1 && !dr) return '';
    return '<p class="snote">' + (dr ? t.all + '개 가운데 ' : '') + t.n + '문제 · ' + t.need + '개 맞히면 통과<br>' + TX.note +
      (dr ? '<br>다시 볼 때는 문제를 새로 뽑아요' : '') + '</p>';
  }
  /* 외우기 열기(memLoad): eval = 연습 열기 _v2(mem) · log = 폰이 만든 판 + 옛 setItems · 끔 = 옛 setItems */
  function mem(k, id) {
    var x = W();
    x.ev = ''; x.vb = null; x.op = Date.now(); x.tap = 0; x.omd = 0;
    if (!on('eval')) {
      if (on('log')) x.vb = Lec.v2Local(k);
      return Lec.setItems(k, id);
    }
    return Lec.setOpenV2(k, id, 'mem').then(function (r) {
      var e = r && r.err;
      if (e === 'off' || e === 'old') { if (B.S.set) B.S.set.v2 = null; return mem(k, id); }
      if (r && r.ok && r.b) { x.ev = 'mem'; x.vb = r.b; }
      return r;
    });
  }
  /* 외우기 한 판 더(memLoad · 들고 있는 단어로) → true = 옛 길로 바로 그림(log = 폰이 새 판 id) · false = eval 새 판을 서버에서 엶 */
  function again(k) {
    var x = W();
    if (x.ev === 'mem') return false;
    x.op = Date.now(); x.tap = 0; x.omd = 0;
    if (x.vb) x.vb = Lec.v2Local(k);
    return true;
  }
  /* «알아요 · 다시» 한 번 = 줄 하나(f 'k' · v '1' / '0' · 서버 카드 셈 = 옛 판 끝 묶음과 같음) */
  function mark(c, ok) {
    var x = W(), o;
    if (!x.vb) return;
    o = tm(x.at);
    o.s = str(x.id); o.k = str(c); o.f = 'k'; o.v = ok ? '1' : '0';
    Lec.v2Add(key(), x.vb, o);
  }
  /* 외우기 판 끝(memSave · eval): 남은 줄 보냄 → 목록 숫자 · then(답) */
  function end(then) {
    var x = W();
    x.tap = 0;
    Lec.v2End(key(), x.vb).then(function (r) {
      if (r && r.ok) apply(r.me, r.due);
      then(r);
    });
  }
  function init(b) {
    var d = w.document, st;
    B = b;
    if (d && !d.getElementById('v2css')) {
      st = d.createElement('style');
      st.id = 'v2css';
      st.appendChild(d.createTextNode(CSS));
      d.head.appendChild(st);
    }
  }

  Lec.v2u = { init: init, on: on, home: home, open: open, ans: ans, after: after, wrong: wrong, note: note, mem: mem, again: again, mark: mark, end: end };
})(window);
