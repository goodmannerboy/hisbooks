/* 히즈클래스 · 선생님 «학생 화면 미리 보기»(11-17 · ES5)
   class.html 이 주소에 preview=<강의 id> 가 있을 때만 읽음(그 밖의 학생 화면은 이 파일을 아예 안 읽음).
   - 바깥(class.html?preview=<id>): 선생님 세션(@his.kr)을 확인한 뒤에만 위 띠 · 기기 틀(폰 · 태블릿 · PC)을 그리고,
     안쪽 학생 화면을 iframe 으로 띄움. 세션이 없거나 선생님이 아니면 preview 를 버리고 보통 학생 화면(로그인)으로.
   - 안쪽(class.html?preview=<id>&in=1): 학생 화면 코드 그대로 · 자료만 바깥이 읽어 둔 강의로 바꿈(읽기만).
     기록 0: 서버에 쓰지 않음(진도 · 질문 · 동의 · 알림) · 학생 localStorage 키는 건드리지 않음(메모리에만).
   연습 화면(&demo=1)은 LecMock 자료로 같은 흐름. 학생용 «기록 없이 보기» 길은 없음(동의 판은 선생님 세션의 미리 보기에서만 건너뜀). */
(function (w) {
  'use strict';
  var d = w.document;
  var DEV_KEY = 'his-class-pv-dev';   /* 선생님이 마지막에 고른 기기(학생 키 아님) */
  var NARROW = 1000;                  /* 창이 이보다 좁으면 기기 단추 없이 띠 + 화면만 */
  var BAND = 44;
  var DEVS = {
    phone: { w: 390, h: 844, bz: 12, R: 50, r: 38 },
    'tab-p': { w: 820, h: 1180, bz: 22, R: 38, r: 18 },
    'tab-l': { w: 1180, h: 820, bz: 22, R: 38, r: 18 }
  };

  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function str(v) { return v == null ? '' : String(v); }
  function esc(s) { return str(s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function flag(n) { return new RegExp('[?&]' + n + '=1(?:&|$)').test(w.location.search); }
  /* preview · in 을 주소에서 뺌(새 기록 없이) → 보통 학생 화면이 그 주소로 시작 */
  function strip() {
    var q = String(w.location.search || '').replace(/^\?/, '').split('&'), out = [], i;
    for (i = 0; i < q.length; i += 1) { if (q[i] && !/^(preview|in)=/.test(q[i])) out.push(q[i]); }
    try { w.history.replaceState(null, '', w.location.pathname + (out.length ? '?' + out.join('&') : '') + w.location.hash); } catch (e) { /* 없음 */ }
  }
  function plain() { strip(); if (w.__lecStart) w.__lecStart(); }
  function css(id, t) {
    if (d.getElementById(id)) return;
    var s = d.createElement('style');
    s.id = id;
    s.appendChild(d.createTextNode(t));
    d.head.appendChild(s);
  }
  function json(x) { return JSON.parse(JSON.stringify(x)); }   /* 이 창의 객체로 다시 만듦(창끼리 같은 객체를 나눠 쓰지 않게) */

  /* ================================================================ 자료(바깥에서 한 번 만듦) */
  function runnerItems(v) {
    if (typeof v === 'string') { try { v = JSON.parse(v); } catch (e) { v = null; } }
    return v && isArr(v.items) ? v.items : [];
  }
  function filesOf(v) {
    if (typeof v === 'string') { try { v = JSON.parse(v); } catch (e) { v = null; } }
    return isArr(v) ? v : [];
  }
  var PDF_P = /^[0-9a-f]{64}\.pdf$/;
  /* lecs = lec_lecture 줄(SQL 칸 그대로) · classes = 히즈북스 반 [{id, name}] · id = 보려는 강의 */
  function build(L, lecs, classes, id) {
    var t = L.isoDay(), tgt = null, known = {}, i, j, x;
    for (i = 0; i < lecs.length; i += 1) { if (lecs[i] && str(lecs[i].id) === id) { tgt = lecs[i]; break; } }
    if (!tgt) return null;
    for (i = 0; i < classes.length; i += 1) { if (classes[i] && classes[i].id != null) known[str(classes[i].id)] = classes[i]; }
    var ids = isArr(tgt.class_ids) ? tgt.class_ids : [], cid = '', star = ids.indexOf('*') >= 0;
    /* 목록 기준 반 = 이 강의의 반 중 히즈북스에 있는 첫 반(여러 반이면 첫 반) · «전체»만이면 반 없이 «전체» 강의만 */
    for (i = 0; i < ids.length && !cid; i += 1) { if (ids[i] !== '*' && has(known, str(ids[i]))) cid = str(ids[i]); }
    for (i = 0; i < ids.length && !cid; i += 1) { if (ids[i] !== '*') cid = str(ids[i]); }
    var cname = cid ? str(has(known, cid) ? known[cid].name : '') : (star ? '전체 반' : '');
    function open(l) {   /* 서버 lec__open 과 같은 셈(학생 반 = cid) */
      if (!l || l.hidden) return false;
      var po = str(l.posted_on) || t, cs = isArr(l.class_ids) ? l.class_ids : [];
      if (po > t || !cs.length) return false;
      if (cs.indexOf('*') >= 0) return true;
      return !!cid && cs.indexOf(cid) >= 0;
    }
    function ended(l) { return !!l.until && t > str(l.until); }
    function shape(l) {
      return {
        id: l.id, title: l.title, book: l.book, yt: l.yt, dur: l.dur, chapters: isArr(l.chapters) ? l.chapters : [],
        lesson_on: l.lesson_on || null, posted_on: l.posted_on || null, until: l.until || null, ended: ended(l),
        pct: 0, pos: 0, watched: 0, seen: '', first_at: null, last_at: null, done_at: null, confirmed: false, ans_new: 0
      };
    }
    var pick = [];
    for (i = 0; i < lecs.length; i += 1) { if (open(lecs[i])) pick.push({ l: lecs[i], o: i }); }
    pick.sort(function (A, B) {   /* SQL 차례: coalesce(lesson_on, posted_on) → created_at */
      var a = str(A.l.lesson_on || A.l.posted_on), b = str(B.l.lesson_on || B.l.posted_on), ca = str(A.l.created_at), cb = str(B.l.created_at);
      if (a !== b) return a < b ? -1 : 1;
      if (ca !== cb) return ca < cb ? -1 : 1;
      return A.o - B.o;
    });
    var out = [], inList = false, src = [];
    for (i = 0; i < pick.length; i += 1) { out.push(shape(pick[i].l)); src.push(pick[i].l); if (pick[i].l === tgt) inList = true; }
    if (!inList) { x = shape(tgt); x.__pv = 1; out.push(x); src.push(tgt); }   /* 학생에게 아직 안 보이는 강의 = 영상만(목록에는 안 나옴) */
    var paper = [], pdf = [], ri, p, fs, f, e;
    for (i = 0; i < src.length; i += 1) {
      if (ended(src[i])) continue;   /* 끝난 강의는 영상을 열지 않음(서버와 같음) */
      ri = runnerItems(src[i].runner); p = [];
      for (j = 0; j < ri.length; j += 1) {
        e = ri[j];
        if (!e || typeof e !== 'object' || isArr(e)) continue;
        p.push({
          no: str(e.no).slice(0, 40),
          at: typeof e.at === 'number' && isFinite(e.at) ? e.at : null,
          stop: typeof e.stop === 'number' && isFinite(e.stop) ? e.stop : null,
          wb: str(e.wb).slice(0, 40)
        });
      }
      if (p.length) paper.push({ id: src[i].id, p: p });
      fs = filesOf(src[i].files); f = [];
      for (j = 0; j < fs.length; j += 1) {
        e = fs[j];
        if (e && typeof e === 'object' && typeof e.p === 'string' && PDF_P.test(e.p)) f.push({ p: e.p, b: typeof e.b === 'number' && isFinite(e.b) ? e.b : null });
      }
      if (f.length) pdf.push({ id: src[i].id, f: f });
    }
    return {
      ok: true, id: id, title: str(tgt.title), cname: cname,
      chip: !open(tgt) ? '학생에게 아직 안 보여요' : (ended(tgt) ? '공개 끝' : ''),
      lectures: out, paper: { ok: true, items: paper }, pdf: { ok: true, items: pdf }
    };
  }

  /* ================================================================ 바깥: 띠 · 기기 틀 */
  var SHELL_CSS =
    'html.pvs,html.pvs body{height:100%;overflow:hidden;background:#E6E2D7}' +
    'html.pvs #app{display:none}' +
    '.pvb{position:fixed;left:0;right:0;top:0;height:44px;z-index:10;display:flex;align-items:center;gap:12px;padding:0 8px 0 16px;background:#1E2420;color:#F4ECD7;font-size:14px;line-height:20px;white-space:nowrap}' +
    '.pvt{display:flex;align-items:center;gap:10px;flex:1 1 auto;min-width:0;overflow:hidden}' +
    '.pvt b{flex:0 0 auto;font-weight:700}' +
    '.pvs2{flex:0 1 auto;min-width:0;overflow:hidden;text-overflow:ellipsis;font-size:12px;color:#B8B4A6}' +
    '.pvc{flex:0 1 auto;min-width:0;overflow:hidden;text-overflow:ellipsis;font-size:12px;font-weight:700;line-height:18px;border-radius:999px;padding:1px 10px;background:#FBF0C9;color:#7A5410}' +
    '.pvc.end{background:#EFEDE5;color:#5F6256}' +
    '.pvg{flex:0 0 auto;display:flex;padding:3px;border-radius:999px;background:#343B36}' +
    '.pvb button{position:relative;border:0;margin:0;font:inherit;font-weight:700;cursor:pointer;-webkit-tap-highlight-color:transparent}' +
    '.pvb button:after{content:"";position:absolute;left:0;right:0;top:-8px;bottom:-8px}' +
    '.pvb button:focus-visible{outline:2px solid #E9C46A;outline-offset:2px}' +
    '.pvg button{min-width:44px;height:28px;padding:0 14px;border-radius:999px;background:transparent;color:#F4ECD7;font-size:13px}' +
    '.pvg button[aria-pressed=true]{background:#F4ECD7;color:#0C4631}' +
    '.pvr{flex:0 0 auto;height:28px;padding:0 12px;border-radius:999px;background:transparent;color:#F4ECD7;font-size:13px;box-shadow:inset 0 0 0 1px #5A635C}' +
    '.pvx{flex:0 0 auto;display:inline-flex;align-items:center;gap:4px;height:28px;padding:0 10px;border-radius:999px;background:transparent;color:#F4ECD7;font-size:14px}' +
    '.pvx svg{width:16px;height:16px}' +
    '.pvx:hover,.pvr:hover{background:#343B36}' +
    '.pvb.nar .pvg,.pvb.nar .pvr{display:none}' +
    /* 좁은 창(1000 아래): 높이 44 그대로 · 1줄 = 제목 + 칩 · 2줄 = 반 · 기록 안내(긴 반 이름은 말줄임) */
    '.pvb.nar .pvt{flex-wrap:wrap;align-content:center;row-gap:0;column-gap:6px}' +
    '.pvb.nar .pvt b{line-height:18px}' +
    '.pvb.nar .pvc{order:1;flex:1 1 0;max-width:max-content;line-height:14px;padding:1px 8px}' +
    '.pvb.nar .pvs2{order:2;flex:0 0 100%;line-height:16px}' +
    /* 폰 폭(480 아래): «닫기» 글자를 숨기고 × 만(aria-label · 누르는 곳 44×44) → 칩이 잘리지 않게 */
    '@media (max-width:479px){.pvb.nar{gap:6px}.pvb.nar .pvx{width:44px;padding:0;justify-content:center}.pvb.nar .pvx span{display:none}}' +
    '.pvst{position:fixed;left:0;right:0;top:44px;bottom:0;overflow:hidden;background:#E6E2D7}' +
    '.pvd{position:absolute;left:0;top:0;transform-origin:0 0;background:#141614;box-shadow:0 18px 48px rgba(20,22,20,.22)}' +
    '.pvf{position:absolute;left:0;top:0;border:0;margin:0;display:block;transform-origin:0 0;background:#F4ECD7}' +
    '.pvcap{position:absolute;left:0;right:0;margin:0;text-align:center;font-size:12px;line-height:18px;color:#6B6A62}' +
    '.pvm{position:absolute;left:16px;right:16px;top:38%;text-align:center;font-size:15px;line-height:22px;color:#3A3F3B}' +
    '.pvm button{margin-top:14px;min-height:44px;padding:0 20px;border:1px solid #CBBF9A;border-radius:12px;background:#FFFDF7;color:#0C4631;font:inherit;font-weight:700;cursor:pointer}' +
    '[hidden]{display:none !important}';

  function shellStart(id) {
    var demo = flag('demo'), L = w.Lec;
    if (!L) { plain(); return; }
    if (demo) {
      var M = w.LecMock, db = null;
      try { db = M && typeof M.db === 'function' ? M.db() : null; } catch (e0) { db = null; }
      if (!db) { plain(); return; }
      shell(id, true, function (cb) { cb({ lectures: db.lecture || [], classes: db.classes || [] }); });
      return;
    }
    if (!w.supabase || !w.supabase.createClient) { plain(); return; }
    var sb = null;
    try { sb = w.supabase.createClient(L.SUPA_URL, L.SUPA_KEY); } catch (e1) { plain(); return; }
    sb.auth.getSession().then(function (r) {
      var ses = r && r.data ? r.data.session : null, em = ses && ses.user ? str(ses.user.email).toLowerCase() : '';
      if (!/@his\.kr$/.test(em)) { plain(); return; }   /* 선생님 세션이 아님 = 미리 보기 흔적 없이 보통 학생 화면 */
      shell(id, false, function (cb) { realLoad(sb, cb); });
    }, plain);
  }
  /* lec_lecture 전부(1000줄씩 · 선생님 화면과 같음) + 히즈북스 반 이름 · 읽기만(GET) */
  function realLoad(sb, cb) {
    var all = [], size = 1000;
    function fail() { cb(null); }
    function page(from) {
      sb.from('lec_lecture').select('*').order('created_at', { ascending: true }).order('id', { ascending: true }).range(from, from + size - 1).then(function (r) {
        if (!r || r.error) { fail(); return; }
        var a = r.data || [];
        all = all.concat(a);
        if (a.length === size) page(from + size); else cls();
      }, fail);
    }
    function cls() {
      sb.from('app_state').select('classes:data->classes').eq('id', 'main').then(function (r) {
        var row = r && !r.error && r.data ? r.data[0] : null, c = row && isArr(row.classes) ? row.classes : [], out = [], i;
        for (i = 0; i < c.length; i += 1) { if (c[i] && c[i].id != null) out.push({ id: c[i].id, name: str(c[i].name) }); }   /* 반 이름만 남김 */
        cb({ lectures: all, classes: out });
      }, function () { cb({ lectures: all, classes: [] }); });
    }
    page(0);
  }

  function shell(id, demo, load) {
    var L = w.Lec, cur = 'phone', fr = null, P = null;
    try { var sv = w.localStorage.getItem(DEV_KEY); if (sv && (sv === 'pc' || has(DEVS, sv))) cur = sv; } catch (e) { /* 없음 */ }
    css('pvs-css', SHELL_CSS);
    d.documentElement.className += ' pvs';
    d.title = '학생 화면 미리 보기 · 히즈클래스';
    var band = d.createElement('div'), st = d.createElement('div');
    band.className = 'pvb';
    band.innerHTML = '<div class="pvt"><b>학생 화면 미리 보기</b><span class="pvs2" id="pvSub">기록은 남지 않아요</span><span class="pvc" id="pvChip" hidden></span></div>' +
      '<div class="pvg" role="group" aria-label="기기 고르기">' +
      '<button type="button" data-pv="phone" aria-pressed="false">폰</button><button type="button" data-pv="tab" aria-pressed="false">태블릿</button><button type="button" data-pv="pc" aria-pressed="false">PC</button></div>' +
      '<button type="button" class="pvr" id="pvRot" data-pv="rot" hidden>가로로</button>' +
      '<button type="button" class="pvx" data-pv="close" aria-label="닫기"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true" focusable="false"><path d="M6 6l12 12M18 6L6 18"/></svg><span>닫기</span></button>';
    st.className = 'pvst';
    st.innerHTML = '<div class="pvd" id="pvDev" hidden></div><p class="pvcap" id="pvCap" hidden></p><div class="pvm" id="pvMsg" role="status"></div>';
    d.body.appendChild(band);
    d.body.appendChild(st);
    function $(x) { return d.getElementById(x); }

    function msg(t, retry) {
      var m = $('pvMsg');
      m.innerHTML = t ? esc(t) + (retry ? '<br><button type="button" data-pv="retry">다시 시도</button>' : '') : '';
    }
    function paintBand() {
      var b, i, bs = band.querySelectorAll('.pvg button'), tab = cur === 'tab-p' || cur === 'tab-l', k;
      for (i = 0; i < bs.length; i += 1) {
        k = bs[i].getAttribute('data-pv');
        bs[i].setAttribute('aria-pressed', (k === 'tab' ? tab : k === cur) ? 'true' : 'false');
      }
      b = $('pvRot');
      b.hidden = !tab;
      b.textContent = cur === 'tab-l' ? '세로로' : '가로로';
    }
    function lay() {
      var W = w.innerWidth || d.documentElement.clientWidth, H = (w.innerHeight || d.documentElement.clientHeight) - BAND;
      var nar = W < NARROW, dv = $('pvDev'), cap = $('pvCap'), fs;
      band.className = 'pvb' + (nar ? ' nar' : '');
      if (!fr) return;
      fs = fr.style;
      if (nar || cur === 'pc') {
        dv.hidden = true; cap.hidden = true;
        fs.left = '0'; fs.top = '0'; fs.width = '100%'; fs.height = '100%';
        fs.transform = 'none'; fs.webkitTransform = 'none'; fs.borderRadius = '0';
        return;
      }
      var g = DEVS[cur], ow = g.w + 2 * g.bz, oh = g.h + 2 * g.bz, PAD = 20, CAPH = 30;
      var s = Math.min(1, (W - 2 * PAD) / ow, (H - 2 * PAD - CAPH) / oh);
      if (!(s > 0.15)) s = 0.15;
      var vw = ow * s, vh = oh * s, x = Math.round((W - vw) / 2), y = Math.round(Math.max(PAD, (H - CAPH - vh) / 2)), pc;
      var tr = 'scale(' + s + ')';
      dv.hidden = false;
      dv.style.left = x + 'px'; dv.style.top = y + 'px'; dv.style.width = ow + 'px'; dv.style.height = oh + 'px';
      dv.style.borderRadius = g.R + 'px'; dv.style.transform = tr; dv.style.webkitTransform = tr;
      fs.left = (x + g.bz * s) + 'px'; fs.top = (y + g.bz * s) + 'px'; fs.width = g.w + 'px'; fs.height = g.h + 'px';
      fs.borderRadius = g.r + 'px'; fs.transform = tr; fs.webkitTransform = tr;
      pc = Math.round(s * 100);
      if (s < 1 && pc >= 100) pc = 99;
      cap.hidden = false;
      cap.style.top = Math.round(y + vh + 10) + 'px';
      cap.textContent = g.w + ' × ' + g.h + ' · ' + (s >= 1 ? '실제 크기' : pc + '%로 줄여 보임');
    }
    function pick(k) {
      if (k === 'tab') k = (cur === 'tab-l') ? 'tab-l' : 'tab-p';
      if (k === 'rot') k = cur === 'tab-l' ? 'tab-p' : 'tab-l';
      if (k !== 'pc' && !has(DEVS, k)) return;
      cur = k;
      try { w.localStorage.setItem(DEV_KEY, cur); } catch (e) { /* 저장이 막혀도 그대로 */ }
      paintBand();
      lay();
    }
    function close() {
      try { w.close(); } catch (e) { /* 없음 */ }
      /* 스크립트로 닫을 수 없는 창(주소를 직접 친 탭 따위) = 선생님 화면으로 */
      var as = demo ? /[?&]as=([A-Za-z0-9_]+)/.exec(w.location.search) : null;   /* 연습 화면: 보던 사람으로 */
      setTimeout(function () { w.location.replace('class-admin.html' + (demo ? '?demo=1' + (as ? '&as=' + as[1] : '') : '')); }, 200);
    }
    band.addEventListener('click', function (e) {
      var n = e.target;
      while (n && n !== band && !(n.getAttribute && n.getAttribute('data-pv'))) n = n.parentNode;
      if (!n || n === band) return;
      var k = n.getAttribute('data-pv');
      if (k === 'close') close(); else pick(k);
    });
    st.addEventListener('click', function (e) {
      var n = e.target;
      if (n && n.getAttribute && n.getAttribute('data-pv') === 'retry') go();
    });
    w.addEventListener('resize', lay);

    function go() {
      msg('불러오는 중이에요.');
      load(function (r) {
        if (!r) { msg('강의를 열지 못했어요.', true); return; }   /* 못 읽음(권한 오류 포함) · 연결 상태를 말하지 않고 할 일(다시 시도)만 */
        P = build(L, r.lectures || [], r.classes || [], id);
        if (!P) { msg('강의를 찾을 수 없어요. 지워졌거나 주소가 바뀌었어요.'); return; }
        msg('');
        var sub = $('pvSub'), chip = $('pvChip');
        sub.textContent = (P.cname ? P.cname + ' · ' : '') + '기록은 남지 않아요';
        sub.title = P.title;
        chip.hidden = !P.chip;
        chip.textContent = P.chip;
        chip.className = 'pvc' + (P.chip === '공개 끝' ? ' end' : '');
        w.__lecPv = P;
        if (fr) return;
        fr = d.createElement('iframe');
        fr.className = 'pvf';
        fr.title = '학생 화면 미리 보기';
        fr.setAttribute('allow', 'autoplay; fullscreen; encrypted-media; picture-in-picture; clipboard-write');
        fr.setAttribute('allowfullscreen', '');
        fr.src = 'class.html?preview=' + encodeURIComponent(id) + '&in=1' + (demo ? '&demo=1' : '') +
          (flag('fake') ? '&fake=1' : '') + (flag('t') ? '&t=1' : '') + '#v=' + encodeURIComponent(id);
        st.appendChild(fr);
        lay();
      });
    }
    paintBand();
    lay();
    go();
  }

  /* ================================================================ 안쪽: 학생 화면 코드 그대로 · 자료만 바꿈 */
  var INNER_CSS =
    '.pvtoast{position:fixed;left:50%;bottom:24px;z-index:99999;max-width:calc(100% - 32px);padding:10px 18px;border-radius:999px;background:#1E2420;color:#F4ECD7;' +
    'font-size:14px;font-weight:700;line-height:20px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;pointer-events:none;opacity:0;' +
    '-webkit-transform:translate(-50%,8px);transform:translate(-50%,8px);transition:opacity .2s,transform .2s}' +
    '.pvtoast.on{opacity:1;-webkit-transform:translate(-50%,0);transform:translate(-50%,0)}' +
    '@media (prefers-reduced-motion:reduce){.pvtoast{transition:none}}' +
    '.pch{min-height:49px}';   /* PC 보기 머리줄: «나가기»가 없어도 학생 화면과 같은 높이(49) */

  function innerStart(id) {
    var P = null, L0 = w.Lec, A = {}, k, mem = {};
    try { P = w.parent && w.parent !== w ? w.parent.__lecPv : null; } catch (e) { P = null; }
    if (!P || !P.ok || P.id !== id || !L0) { plain(); return; }
    P = json(P);
    for (k in L0) { if (has(L0, k)) A[k] = L0[k]; }
    function ok(v) { return Promise.resolve(v); }
    function no() { return Promise.resolve({ ok: false, err: 'preview' }); }
    function nowIso() { return new Date(L0.now()).toISOString(); }
    /* 저장: 이 화면 안 메모리만(학생 열쇠 · 대기 기록 · 배속 · 설치 안내 표시 모두) */
    mem[L0.LS.key] = JSON.stringify('preview');
    A.lsGet = function (key, dv) {
      if (!has(mem, key)) return dv;
      try { return JSON.parse(mem[key]); } catch (e) { return dv; }
    };
    A.lsSet = function (key, v) { try { mem[key] = JSON.stringify(v); return true; } catch (e) { return false; } };
    A.lsDel = function (key) { delete mem[key]; return true; };
    /* 서버: 읽을 것은 바깥이 읽어 둔 강의로 · 쓰는 것은 모두 보내지 않음 */
    A.rpc = function () { return Promise.reject(new Error('preview')); };
    A.home = function () {
      return ok({ ok: true, me: { name: '미리 보기' }, consent: { choice: 'agree', ver: L0.CONSENT_VER, at: nowIso() }, consent_ver: L0.CONSENT_VER, lectures: json(P.lectures) });
    };
    A.att = function () { return ok(null); };
    A.rngMe = function () { return ok(null); };
    A.paper = function () { return ok(json(P.paper)); };
    A.pdf = function () { return ok(json(P.pdf)); };
    A.qna = function () { return ok({ ok: true, items: [] }); };
    A.ask = no; A.qdel = no; A.beat = no; A.login = no; A.consent = no;
    /* 새 영상 알림(§8-205): pushOn = null(서버 없음과 같음 → 단계 · 카드 · 켜는 법 줄 없음) · 저장 · 끄기 = 보내지 않음 */
    A.pushOn = function () { return ok(null); };
    A.pushSave = no; A.pushOff = no;
    /* 단어 · 구문 · 문법(S1 · §10): setHome = null(묶음 없음 · 픽셀 0) · 나머지 읽기 · 쓰기 · 녹음 · 올리기 = 보내지 않음 */
    A.setHome = function () { return ok(null); };
    A.setItems = no; A.setCard = no; A.setTest = no; A.setDue = no; A.setAns = no;
    A.recBegin = no; A.recDone = no; A.recPut = no; A.recSend = no;
    A.logout = function () { return ok({ ok: true }); };
    w.Lec = A;
    w.__lecPvIn = true;
    if (w.__hisPwa) w.__hisPwa.done = true;   /* 설치 단추 · 설치 안내 없음 */

    /* 한 겹 더: 이 화면에서는 서버 주소로 아무것도 보내지 않음(나중에 생길 함수도) · 알림 권한도 묻지 않음 */
    var of = w.fetch, SU = str(L0.SUPA_URL);
    if (typeof of === 'function') {
      w.fetch = function (u) {
        var s = '';
        try { s = String(u && (u.url || u.href) || u); } catch (e) { s = ''; }   /* 글 · Request · URL 모두 */
        if (SU && s.indexOf(SU) === 0) return Promise.reject(new Error('preview'));
        return of.apply(w, arguments);
      };
    }
    try { if (w.navigator && w.navigator.sendBeacon) w.navigator.sendBeacon = function () { return true; }; } catch (e1) { /* 없음 */ }
    try {
      if (w.Notification) {
        w.Notification.requestPermission = function (cb) {
          try { if (typeof cb === 'function') cb('default'); } catch (e) { /* 없음 */ }
          return Promise.resolve('default');
        };
      }
    } catch (e2) { /* 없음 */ }
    try { if (w.PushManager && w.PushManager.prototype) w.PushManager.prototype.subscribe = function () { return Promise.reject(new Error('preview')); }; } catch (e3) { /* 없음 */ }
    /* 마이크도 켜지 않음(S1 녹음 · class.html 의 __lecPvIn 막음과 두 겹) */
    try {
      if (w.navigator && w.navigator.mediaDevices) {
        w.navigator.mediaDevices.getUserMedia = function () {
          var er = new Error('preview');
          try { er.name = 'NotAllowedError'; } catch (e6) { /* 없음 */ }
          return Promise.reject(er);
        };
      }
    } catch (e5) { /* 없음 */ }
    /* 말하기 확인(음성 인식 · 11-18)도 끔 = 미리 보기는 «말해 본 뒤 영어 보기»(class.html 의 spkCan 'preview' 와 두 겹) · 말 빠르기 칩은 그대로 */
    try { w.SpeechRecognition = undefined; } catch (e7) { /* 없음 */ }
    try { w.webkitSpeechRecognition = undefined; } catch (e8) { /* 없음 */ }

    /* 안쪽 주소(#v= · #rng)로 가는 링크는 기록 없이 바꿔치기(바깥 탭의 뒤로 가기 기록이 늘지 않게) */
    d.addEventListener('click', function (e) {
      var n = e.target, h, act;
      while (n && n !== d && !(n.tagName === 'A')) n = n.parentNode;
      if (!n || n === d) return;
      h = n.getAttribute('href') || '';
      act = n.getAttribute('data-act');
      if (h.charAt(0) !== '#' || (act && act !== 'go') || n.getAttribute('target')) return;
      e.preventDefault();
      try { w.location.replace(h); } catch (e4) { /* 없음 */ }
    }, true);

    css('pvi-css', INNER_CSS);
    var tt = 0;
    w.__lecPvToast = function (t) {
      var el = d.getElementById('pvToast');
      if (!el) {
        el = d.createElement('div');
        el.id = 'pvToast';
        el.className = 'pvtoast';
        el.setAttribute('role', 'status');
        el.setAttribute('aria-live', 'polite');
        d.body.appendChild(el);
      }
      el.textContent = t;
      void el.offsetWidth;
      el.className = 'pvtoast on';
      clearTimeout(tt);
      tt = setTimeout(function () { el.className = 'pvtoast'; }, 2400);
    };
    if (w.__lecStart) w.__lecStart();
  }

  w.__lecPv0 = function (inner, id) {
    id = str(id);
    if (!id) { plain(); return; }
    if (inner) innerStart(id); else shellStart(id);
  };
  if (w.__lecPvTest) w.__lecPvTest.build = build;   /* 시험용(?t=1 시험 파일이 미리 걸어 둔 때만) */
})(window);
