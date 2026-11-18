/* 히즈 강의실 · 학생 화면과 선생님 화면이 함께 쓰는 도구 (window.Lec)
   ES5 문법만 씁니다(var · function). 서버 규칙의 기준은 class-setup.sql 입니다.
   - ?demo=1 : class-mock.js 의 가짜 서버(window.LecMock)로 움직임
   - &t=1    : 시험용(길이 0 강의 등)   &fake=1 : 가짜 재생기(화면 쪽에서 사용)
   - window.__lecNow : 함수이면 그 값을 «지금»(ms)으로 씀(시험에서 시간을 빨리 감을 때
   - window.__lecOffline : 참이면 서버 부르기가 Error('network') 로 실패함(시험용) */
(function (w) {
  'use strict';

  var SUPA_URL = 'https://vcfhttzbzgtszpuahibe.supabase.co';
  var SUPA_KEY = 'sb_publishable_d-X3ubJw6n4P1zumfRZgrQ_rWDfhmWj';
  var DAY = 86400000;
  var SEOUL = 9 * 3600000; /* 한국은 일광 절약 시간이 없어 늘 +9시간 */
  var WK = ['일', '월', '화', '수', '목', '금', '토'];

  var Q = '';
  try { Q = String((w.location && w.location.search) || ''); } catch (e0) { Q = ''; }
  function qflag(name) { return new RegExp('[?&]' + name + '=1(?:&|$)').test(Q); }

  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function str(v) { return v == null ? '' : String(v); }
  function pad2(n) { n = Math.floor(Math.abs(n)); return (n < 10 ? '0' : '') + n; }
  function rep(s, n) { var o = ''; while (n > 0) { o += s; n -= 1; } return o; }
  function err(m) { return new Error(m); }

  /* ---------------------------------------------------------------- 시각 */

  function now() {
    var f = w.__lecNow;
    if (typeof f === 'function') {
      var v = +f();
      if (isFinite(v)) return v;
    }
    return new Date().getTime();
  }

  /* 시각 → ms. 서버의 "2026-11-15T07:12:33.123456+00:00" 꼴(소수 6자리)도 읽음 */
  function ts(v) {
    if (v == null || v === '') return NaN;
    if (typeof v === 'number') return v;
    if (v instanceof Date) return v.getTime();
    var s = String(v).replace(/^\s+|\s+$/g, '');
    var m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (m) return Date.UTC(+m[1], +m[2] - 1, +m[3]) - SEOUL; /* 날짜만 = 서울 0시 */
    s = s.replace(/^(\d{4}-\d{2}-\d{2}) (\d)/, '$1T$2');
    s = s.replace(/\.(\d+)/, function (m0, f) { return '.' + (f + '00').slice(0, 3); }); /* 소수 자리를 3자리로 */
    s = s.replace(/([+-]\d{2})$/, '$1:00');
    s = s.replace(/([+-]\d{2})(\d{2})$/, '$1:$2');
    var t = Date.parse(s);
    return isFinite(t) ? t : NaN;
  }

  function seoulParts(ms) {
    var d = new Date(ms + SEOUL);
    return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate(), hh: d.getUTCHours(), mi: d.getUTCMinutes(), wd: d.getUTCDay() };
  }

  /* 서울 날짜 'YYYY-MM-DD' */
  function isoDay(v) {
    var ms;
    if (v === undefined || v === null) ms = now();
    else if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v)) return v;
    else ms = ts(v);
    if (!isFinite(ms)) return '';
    var p = seoulParts(ms);
    return p.y + '-' + pad2(p.m) + '-' + pad2(p.d);
  }

  function dayParts(v) {
    var s = typeof v === 'string' ? v.replace(/^\s+|\s+$/g, '') : '';
    var m = s.match(/^(\d{4})[-.\/](\d{1,2})[-.\/](\d{1,2})$/);
    if (!m) { s = isoDay(v); m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/); }
    if (!m) return null;
    var y = +m[1], mo = +m[2], d = +m[3];
    var wd = new Date(Date.UTC(y, mo - 1, d)).getUTCDay();
    if (!isFinite(wd)) return null;
    return { y: y, m: mo, d: d, wd: wd };
  }

  /* '2026-11-12' → '11.12(목)' */
  function fmtDay(v) {
    var p = dayParts(v);
    if (!p) return '';
    return p.m + '.' + p.d + '(' + WK[p.wd] + ')';
  }

  /* 초 → 'm:ss' 또는 'h:mm:ss' */
  function fmtDur(sec) {
    sec = Math.floor(+sec || 0);
    if (sec < 0) sec = 0;
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    return h > 0 ? h + ':' + pad2(m) + ':' + pad2(s) : m + ':' + pad2(s);
  }

  /* 초 → 'n분' · 60분부터 'n시간 m분'(딱 맞으면 'n시간') */
  function fmtMin(sec) {
    var m = Math.round((+sec || 0) / 60);
    if (m < 0) m = 0;
    if (m < 60) return m + '분';
    var h = Math.floor(m / 60), r = m % 60;
    return r ? h + '시간 ' + r + '분' : h + '시간';
  }

  /* 시각 → '방금' · 'n분 전' · '오늘 14:05' · '어제 14:05' · '11.12(목) 14:05' */
  function fmtWhen(v) {
    var t = ts(v);
    if (!isFinite(t)) return '';
    var n = now(), d = n - t;
    if (d < 60000) return '방금';
    if (d < 3600000) return Math.floor(d / 60000) + '분 전';
    var p = seoulParts(t), hm = pad2(p.hh) + ':' + pad2(p.mi);
    var day = isoDay(t);
    if (day === isoDay(n)) return '오늘 ' + hm;
    if (day === isoDay(n - DAY)) return '어제 ' + hm;
    return fmtDay(day) + ' ' + hm;
  }

  /* ---------------------------------------------------- 서버 도움 함수와 같은 규칙 */

  /* 글자를 코드 포인트로 나눔(서버의 char_length · left 와 같은 셈) */
  function cps(s) {
    s = str(s);
    var out = [], i = 0, c, d;
    while (i < s.length) {
      c = s.charCodeAt(i);
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
        d = s.charCodeAt(i + 1);
        if (d >= 0xDC00 && d <= 0xDFFF) { out.push(s.substr(i, 2)); i += 2; continue; }
      }
      out.push(s.charAt(i));
      i += 1;
    }
    return out;
  }
  function clen(s) { return cps(s).length; }
  function left(s, n) { return cps(s).slice(0, Math.max(0, n)).join(''); }

  /* lec__nows: NFC 로 모은 뒤 띄어쓰기·안 보이는 칸을 모두 뺌 */
  /* 소스에 보이지 않는 글자를 두지 않으려고 문자 번호로 만든다 (SQL lec__nows 와 같은 목록) */
  var WS = (function () {
    var c = [9, 10, 11, 12, 13, 32, 160, 5760], k;
    for (k = 8192; k <= 8203; k += 1) c.push(k);
    c.push(8232, 8233, 8239, 8287, 12288, 65279);
    return new RegExp('[' + String.fromCharCode.apply(null, c) + ']+', 'g');
  }());
  function nfc(s) {
    try { return typeof s.normalize === 'function' ? s.normalize('NFC') : s; } catch (e) { return s; }
  }
  function nows(s) { return nfc(str(s)).replace(WS, ''); }

  /* lec__norm: nows + 영어 대문자 A–Z 만 소문자로 */
  function norm(s) { return nows(s).replace(/[A-Z]+/g, function (m) { return m.toLowerCase(); }); }

  function skey(rid, name) { return str(rid) + '|' + norm(name); }

  /* lec__mask: 김하늘 → 김○○ · 한 글자 이하 → 학생 */
  function mask(name) {
    var a = cps(nows(name));
    if (a.length < 2) return '학생';
    return a[0] + rep('○', a.length - 1);
  }

  /* lec__truthy: 히즈북스 앱의 «참»과 같게 */
  function truthy(v) {
    if (v === true) return true;
    if (typeof v === 'number') return v !== 0 && v === v;
    if (typeof v === 'string') return v !== '';
    if (v && typeof v === 'object') return true;
    return false;
  }

  /* jsonb ->> 처럼 글자로 */
  function jtext(v) {
    if (v === undefined || v === null) return null;
    if (typeof v === 'string') return v;
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    try { return JSON.stringify(v); } catch (e) { return null; }
  }
  function btrim(s) { return str(s).replace(/^ +| +$/g, ''); } /* 서버 btrim 은 보통 칸만 */
  function last4(v) {
    var d = str(v).replace(/[^0-9]/g, '');
    return d.length > 4 ? d.slice(d.length - 4) : d;
  }
  function pathText(o, k) {
    if (!o || typeof o !== 'object' || isArr(o)) return null;
    return jtext(o[k]);
  }

  /* 학생의 등원 번호 4자리들(보호자 · 학생 휴대폰 뒤 4자리) */
  function pinsOf(st) {
    var it = st && typeof st === 'object' && !isArr(st) ? st.intake : null;
    var a = [last4(pathText(it, 'parentContact')), last4(pathText(it, 'studentContact'))];
    var out = [], i;
    for (i = 0; i < a.length; i += 1) {
      if (a[i].length === 4 && out.indexOf(a[i]) < 0) out.push(a[i]);
    }
    out.sort();
    return out;
  }

  /* lec__roster: 퇴원 · 반배정 대기 빼고, 같은 열쇠(skey)는 한 사람으로 */
  function rosterFrom(classes) {
    var map = {}, list = [], i, j;
    if (!isArr(classes)) return list;
    for (i = 0; i < classes.length; i += 1) {
      var c = classes[i];
      var isObj = c && typeof c === 'object' && !isArr(c);
      var studs = isObj && isArr(c.students) ? c.students : [];
      var cid = isObj ? jtext(c.id) : null;
      for (j = 0; j < studs.length; j += 1) {
        var s = studs[j];
        if (!s || typeof s !== 'object' || isArr(s)) continue;
        var rid = jtext(s.id);
        if (rid === null || rid === '') continue;
        var name = jtext(s.name);
        var nn = norm(name);
        if (nn === '') continue;
        if (truthy(s.withdrawn) || truthy(s.pending)) continue;
        var sk = rid + '|' + nn, mk = '#' + sk, sn = btrim(name);
        var e = map[mk];
        if (!e) {
          e = { skey: sk, rid: rid, sname: sn, nname: nn, pins: [], cls: [] };
          map[mk] = e;
          list.push(e);
        } else if (sn > e.sname) {
          e.sname = sn;
        }
        var ps = [last4(pathText(s.intake, 'parentContact')), last4(pathText(s.intake, 'studentContact'))];
        var x;
        for (x = 0; x < ps.length; x += 1) {
          if (ps[x].length === 4 && e.pins.indexOf(ps[x]) < 0) e.pins.push(ps[x]);
        }
        if (cid !== null && cid !== '' && e.cls.indexOf(cid) < 0) e.cls.push(cid);
      }
    }
    for (i = 0; i < list.length; i += 1) { list[i].pins.sort(); list[i].cls.sort(); }
    list.sort(function (a, b) { return a.skey < b.skey ? -1 : (a.skey > b.skey ? 1 : 0); });
    return list;
  }

  /* ---------------------------------------------------------- 본 구간(10초 칸) */

  function bmLen(dur) { dur = +dur || 0; return Math.max(1, Math.ceil(dur / 10)); }

  /* bmOr(a, b) = 두 표시 합치기. bmOr(a, b, cap) = lec__or(새로 켜는 칸은 앞에서부터 cap 개까지) */
  function bmOr(a, b, cap) {
    a = str(a); b = str(b);
    var lim = Infinity;
    if (arguments.length > 2 && cap !== undefined) {
      lim = cap === null ? 0 : +cap;
      if (!isFinite(lim) && lim !== Infinity) lim = 0;
      if (lim < 0) lim = 0;
    }
    var n = Math.max(a.length, b.length), out = [], run = 0, i, was, add;
    for (i = 0; i < n; i += 1) {
      was = a.charAt(i) === '1';
      add = !was && b.charAt(i) === '1';
      if (add) run += 1;
      out.push(was || (add && run <= lim) ? '1' : '0');
    }
    return out.join('');
  }

  /* 앞 n칸 안의 켜진 칸 수(n 을 안 주면 전체) */
  function bmCount(s, n) {
    s = str(s);
    if (n !== undefined && n !== null) s = s.slice(0, Math.max(0, +n || 0));
    var c = 0, i;
    for (i = 0; i < s.length; i += 1) { if (s.charAt(i) === '1') c += 1; }
    return c;
  }

  /* lec__pct 와 같은 값: 길이 0 이하 → 0, 아니면 round(100 × 켜진 칸 / 전체 칸) */
  function bmPct(seen, dur) {
    dur = +dur || 0;
    if (!(dur > 0)) return 0;
    var n = Math.ceil(dur / 10);
    return Math.min(100, Math.round(100 * bmCount(seen, n) / n));
  }

  /* i번째 칸의 길이(마지막 칸은 짧을 수 있음) */
  function bucketLen(i, dur) {
    dur = +dur || 0;
    if (!(dur > 0)) return 10;
    var n = bmLen(dur);
    if (i < n - 1) return 10;
    return Math.max(0, dur - 10 * (n - 1));
  }

  /* 칸마다 인정된 초 [s0, s1, …] → '0101…'(칸 길이의 절반, 최대 5초 이상이면 켬) */
  function bmFromSecs(secs, dur) {
    var n = bmLen(dur), out = [], i, need, v;
    secs = secs || [];
    for (i = 0; i < n; i += 1) {
      need = Math.min(5, bucketLen(i, dur) / 2);
      v = +secs[i] || 0;
      out.push(v > 0 && v >= need ? '1' : '0');
    }
    return out.join('');
  }

  /* 인정된 구간 [a, b](강의 초)를 칸마다 초로 더함 · secs 를 고쳐서 돌려줌 */
  function addSpan(secs, a, b) {
    secs = secs || [];
    a = +a; b = +b;
    if (!isFinite(a) || !isFinite(b) || b <= a) return secs;
    if (a < 0) a = 0;
    var i = Math.floor(a / 10), lo, hi;
    while (i * 10 < b) {
      lo = Math.max(a, i * 10); hi = Math.min(b, i * 10 + 10);
      if (hi > lo) secs[i] = (+secs[i] || 0) + (hi - lo);
      i += 1;
    }
    for (i = 0; i < secs.length; i += 1) { if (secs[i] === undefined) secs[i] = 0; }
    return secs;
  }

  /* [from, to) 구간의 칸 가운데 켜진 칸 → {on, n, pct} (목차별 표시용) */
  function bmRange(seen, from, to) {
    seen = str(seen);
    from = Math.max(0, +from || 0); to = +to || 0;
    if (!(to > from)) return { on: 0, n: 0, pct: 0 };
    var i0 = Math.floor(from / 10), i1 = Math.ceil(to / 10) - 1, on = 0, i;
    for (i = i0; i <= i1; i += 1) { if (seen.charAt(i) === '1') on += 1; }
    var n = i1 - i0 + 1;
    return { on: on, n: n, pct: n ? Math.round(100 * on / n) : 0 };
  }

  /* ---------------------------------------------------------------- 목차 */

  function chapterAt(ch, t) {
    if (!isArr(ch)) return -1;
    t = +t || 0;
    var best = -1, bt = -Infinity, i, ct;
    for (i = 0; i < ch.length; i += 1) {
      ct = ch[i] ? +ch[i].t : NaN;
      if (!isFinite(ct)) continue;
      if (ct <= t && ct >= bt) { best = i; bt = ct; }
    }
    return best;
  }

  function chapterRanges(ch, dur) {
    var a = [], i;
    dur = +dur || 0;
    if (!isArr(ch)) return a;
    for (i = 0; i < ch.length; i += 1) {
      var t = ch[i] ? +ch[i].t : NaN;
      if (!isFinite(t)) continue;
      a.push({ i: i, from: Math.max(0, t), to: 0, title: str(ch[i].title) });
    }
    a.sort(function (x, y) { return x.from - y.from || x.i - y.i; });
    for (i = 0; i < a.length; i += 1) {
      var nx = i + 1 < a.length ? a[i + 1].from : (dur > 0 ? dur : a[i].from);
      if (dur > 0) nx = Math.min(nx, dur);
      a[i].to = Math.max(a[i].from, nx);
    }
    return a;
  }

  /* 지문 이름 앞의 번호 두 자리: '04번 …' · '4번' → '04' · '04~05번' → '04' · 없으면 '' */
  function chapterNo(title) {
    var m = str(title).match(/^\s*(\d{1,3})(?:\s*[~\-]\s*\d{1,3})?\s*번/);
    if (!m) return '';
    var n = parseInt(m[1], 10);
    return n < 10 ? '0' + n : String(n);
  }

  /* 장면 칩: 그 시각이 든 지문 번호 + 시각('04번 · 17:39') · 번호를 모르면 '17:39' */
  function sceneLabel(t, chapters) {
    var i = chapterAt(chapters, t), no = i >= 0 ? chapterNo(chapters[i].title) : '';
    return no ? no + '번 · ' + fmtDur(t) : fmtDur(t);
  }

  /* 지문마다 본 비율(0~1) · chapters 와 같은 차례(시각이 없는 줄은 0) · 길이 0 이하면 모두 0
     칸 세기는 bmRange(목차 표시와 같음) · 길이가 0인 지문은 그 시각이 든 칸 하나로 */
  function chapterSeen(bits, chapters, dur) {
    var out = [], r = chapterRanges(chapters, dur), i, x, k, last;
    dur = +dur || 0;
    if (!isArr(chapters)) return out;
    for (i = 0; i < chapters.length; i += 1) out.push(0);
    if (!(dur > 0)) return out;
    last = bmLen(dur) - 1;
    for (i = 0; i < r.length; i += 1) {
      if (r[i].to > r[i].from) {
        x = bmRange(bits, r[i].from, r[i].to);
        out[r[i].i] = x.n ? x.on / x.n : 0;
      } else {
        k = Math.min(Math.floor(r[i].from / 10), last);
        out[r[i].i] = str(bits).charAt(k) === '1' ? 1 : 0;
      }
    }
    return out;
  }

  /* 학부모 안내의 «NN번부터»: 시각 차례로 본 비율 0.9 미만인 첫 «번호 있는» 지문 · 없으면 '' */
  function nextNo(bits, chapters, dur) {
    var seen = chapterSeen(bits, chapters, dur), r = chapterRanges(chapters, dur), i, no;
    for (i = 0; i < r.length; i += 1) {
      no = chapterNo(r[i].title);
      if (no && seen[r[i].i] < 0.9) return no;
    }
    return '';
  }

  /* ------------------------------------------------------------- 그 밖의 도움 */

  /* 유튜브 주소 → 11자 영상 id(못 찾으면 '') */
  function ytId(v) {
    var s = str(v).replace(/^\s+|\s+$/g, '');
    if (!s) return '';
    if (/^[A-Za-z0-9_-]{11}$/.test(s)) return s;
    if (!/(?:^|[\/.])(?:youtube\.com|youtube-nocookie\.com|youtu\.be)(?:[\/:?#]|$)/i.test(s)) return '';
    var m = s.match(/youtu\.be\/([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])/i) ||
            s.match(/\/(?:embed|shorts|live|v|video)\/([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])/) ||
            s.match(/[?&#]v=([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])/);
    return m ? m[1] : '';
  }

  /* 11-18 썸네일(원장님 «썸네일로 넣어»): 영상 그림 주소(열쇠 · 요금 없음 · 두 앱이 같이 씀)
     size = mqdefault(320×180) · sddefault(640×480 · 위아래 검은 띠라 16:9 로 잘라 씀) · maxresdefault(1280×720 · 없을 수 있음) · 영상 id 를 못 찾으면 '' */
  function ytThumb(v, size) {
    var id = ytId(v);
    return id ? 'https://i.ytimg.com/vi/' + id + '/' + (/^(?:mq|hq|sd|maxres)default$/.test(size || '') ? size : 'mqdefault') + '.jpg' : '';
  }
  /* 그림이 안 뜨면(받기 실패 · 없는 영상 = 120×90 회색 그림) data-thq 의 다음 크기로 · 다 안 되면 그림을 떼어 밑의 크림 칸이 보이게(두 앱 한 곳) */
  function thumbFix(e) {
    var im = e.target, q, nx, p;
    if (!im || im.tagName !== 'IMG' || !im.hasAttribute('data-thq')) return;
    if (e.type === 'load' && im.naturalWidth > 120) return;
    q = im.getAttribute('data-thq').split(' ').filter(function (x) { return !!x; });
    if (q.length) {
      nx = q.shift();
      im.setAttribute('data-thq', q.join(' '));
      im.src = im.src.replace(/[^\/]+\.jpg$/, nx + '.jpg');
      return;
    }
    p = im.parentNode;
    if (p) { p.classList.remove('has-i'); p.removeChild(im); }
  }
  if (typeof document !== 'undefined' && document.addEventListener) {
    document.addEventListener('load', thumbFix, true);
    document.addEventListener('error', thumbFix, true);
  }

  function hms(s) {
    var p = s.split(':'), t = 0, i, v;
    for (i = 0; i < p.length; i += 1) {
      v = parseInt(p[i], 10);
      if (!isFinite(v) || (i > 0 && v > 59)) return NaN;
      t = t * 60 + v;
    }
    return t;
  }

  /* «수업 영상 만들기» 가 쓴 txt → {title, book, lessonOn, chapters} */
  function parseRunner(txt) {
    var out = { title: '', book: '', lessonOn: '', chapters: [] };
    var s = str(txt);
    if (s.charCodeAt(0) === 65279) s = s.slice(1);
    s = s.replace(/\r\n?/g, '\n');
    var hasDesc = /\[\s*설\s*명\s*\]/.test(s);
    var lines = s.split('\n'), blk = '', tline = '', i, ln, h, m, t, list = [];
    for (i = 0; i < lines.length; i += 1) {
      ln = lines[i].replace(/^\s+|\s+$/g, '');
      if (ln.charCodeAt(0) === 65279) ln = ln.slice(1).replace(/^\s+/, '');
      h = ln.match(/^\[([^\]]*)\]\s*(.*)$/);
      if (h) { blk = nows(h[1]); ln = h[2]; }
      if (!ln) continue;
      if (blk === '제목') { if (!tline) tline = ln; continue; }
      if (blk === '설명' || (!hasDesc && blk === '')) {
        m = ln.match(/^(\d{1,3}(?::\d{1,2}){1,2})(?=\s|$)\s*(?:[-–—·|]\s+)?(.*)$/);
        if (m) {
          t = hms(m[1]);
          if (isFinite(t)) list.push({ t: t, title: m[2].replace(/^\s+|\s+$/g, ''), k: list.length });
        }
      }
    }
    list.sort(function (a, b) { return a.t - b.t || a.k - b.k; });
    for (i = 0; i < list.length; i += 1) out.chapters.push({ t: list[i].t, title: list[i].title });

    if (tline) {
      var parts = tline.split(/\s+[·•|]\s+/), last = parts[parts.length - 1], dm;
      dm = parts.length > 1 ? last.match(/^(?:(\d{4})[.\-\/])?(\d{1,2})[.\-\/](\d{1,2})\.?$/) : null;
      if (dm && +dm[2] >= 1 && +dm[2] <= 12 && +dm[3] >= 1 && +dm[3] <= 31) {
        var today = isoDay(now()), y = dm[1] ? +dm[1] : +today.slice(0, 4);
        var day = y + '-' + pad2(+dm[2]) + '-' + pad2(+dm[3]);
        if (!dm[1] && ts(day) > ts(today) + 31 * DAY) day = (y - 1) + day.slice(4); /* 1월에 12월 수업 txt 를 읽을 때 */
        out.lessonOn = day;
        parts.pop();
      }
      out.title = parts.length ? parts[0] : '';
      out.book = parts.slice(1).join(' · ');
    }
    return out;
  }

  /* 실행기 txt 끝의 [온라인 클래스] 묶음(없어도 됨 · 머리줄 [히즈클래스] · [히즈 클래스] · [히즈 온라인] 도 받음 · 띄어쓰기 상관없음) → {has, days, start, items}
       수업일 | 2026-11-10 · 2026-11-11        (교실에서 이 수업을 한 날 · 여러 날 · 2026.11.10 도 받음)
       녹화 시작 | 19:02
       01 | 시작 0:25 | 멈춤 10:25 | 판서 2 | 워크북 01   (칸은 빠져도 됨 · 번호 자리에 ANALYSIS 같은 글도)
     items = [{no, at, stop, board, wb}] · at · stop = 초(m:ss · h:mm:ss) · board = 판서 PDF 쪽(1부터 · 그대로) ·
     wb = 워크북 글자 그대로(«5-6» · «3,5» · «ANALYSIS») · 못 읽은 칸은 null('') */
  function parseOnline(txt) {
    var out = { has: false, days: [], start: '', items: [] };
    var s = str(txt);
    if (s.charCodeAt(0) === 65279) s = s.slice(1);
    s = s.replace(/\r\n?/g, '\n');
    var lines = s.split('\n'), blk = '', i, j, ln, h, parts, k, rest, m, it, kv, key, val, dre, y, mo, d, iso;
    for (i = 0; i < lines.length; i += 1) {
      ln = lines[i].replace(/^\s+|\s+$/g, '');
      if (ln.charCodeAt(0) === 65279) ln = ln.slice(1).replace(/^\s+/, '');
      h = ln.match(/^\[([^\]]*)\]\s*(.*)$/);
      if (h) {
        blk = nows(h[1]);
        ln = h[2];
        if (blk === '히즈온라인' || blk === '히즈클래스') blk = '온라인클래스'; /* 머리줄이 [히즈 온라인] · [히즈 클래스] · [히즈클래스] 로 바뀌어도 같은 묶음(nows 가 띄어쓰기를 뺌) */
        if (blk === '온라인클래스') out.has = true;
      }
      if (blk !== '온라인클래스' || !ln) continue;
      parts = ln.split('|');
      for (j = 0; j < parts.length; j += 1) parts[j] = parts[j].replace(/^\s+|\s+$/g, '');
      k = nows(parts[0]);
      rest = parts.slice(1).join(' ');
      if (k === '수업일') {
        dre = /(\d{4})[.\-\/](\d{1,2})[.\-\/](\d{1,2})/g;
        while ((m = dre.exec(rest))) {
          y = +m[1]; mo = +m[2]; d = +m[3];
          if (mo < 1 || mo > 12 || d < 1 || new Date(Date.UTC(y, mo - 1, d)).getUTCDate() !== d) continue;
          iso = y + '-' + pad2(mo) + '-' + pad2(d);
          if (out.days.indexOf(iso) < 0) out.days.push(iso);
        }
        continue;
      }
      if (k === '녹화시작') {
        m = rest.match(/^(\d{1,2}):(\d{2})(?::\d{2})?$/);
        if (m && +m[1] <= 23 && +m[2] <= 59) out.start = pad2(+m[1]) + ':' + m[2];
        continue;
      }
      if (!parts[0] || parts.length < 2) continue;
      it = { no: parts[0], at: null, stop: null, board: null, wb: '' };
      for (j = 1; j < parts.length; j += 1) {
        kv = parts[j].match(/^(\S+)\s*(.*)$/);
        if (!kv) continue;
        key = kv[1]; val = kv[2].replace(/^\s+|\s+$/g, '');
        if (key === '시작' || key === '멈춤') {
          if (/^\d{1,3}(?::\d{1,2}){1,2}$/.test(val) && isFinite(hms(val))) it[key === '시작' ? 'at' : 'stop'] = hms(val);
        } else if (key === '판서') {
          if (/^\d{1,4}$/.test(val) && +val >= 1) it.board = +val;
        } else if (key === '워크북') {
          it.wb = val;
        }
      }
      out.items.push(it);
    }
    out.days.sort();
    return out;
  }

  /* ---------------------------------------------------------------- C3 · C7 지문 줄(종이 자리 · 멈추고 풀기) */

  /* 번호 글자 → [[from] 또는 [from, to]] · '04' · '04번' · '5-6' · '5~6' · '3,5' · '3·5' · 숫자가 아니면 null */
  function noParts(s) {
    var c = nfc(str(s)).replace(WS, '').replace(/번$/, ''), toks, out = [], i, m;
    if (!c) return null;
    toks = c.split(/[,，、·]/);
    for (i = 0; i < toks.length; i += 1) {
      m = toks[i].match(/^(\d{1,3})(?:[~\-–—〜～](\d{1,3}))?$/);
      if (!m) return null;
      out.push(m[2] != null ? [m[1], m[2]] : [m[1]]);
    }
    return out;
  }
  /* 두 강을 한 영상에 담은 이름 '15강 01' → ['15강', '01'] · '16강 ANALYSIS' → ['16강', 'ANALYSIS'] · 강 머리가 없으면 ['', 이름] (검수 A M3) */
  function noGang(s) {
    var c = nfc(str(s)).replace(/^\s+|\s+$/g, ''), m = c.match(/^(\d{1,3})\s*강(?:\s+|(?=[0-9A-Za-z]))(.+)$/);
    return m ? [(+m[1]) + '강', m[2].replace(/^\s+/, '')] : ['', c];
  }
  function noPartsLabel(p) {
    var out = [], i;
    for (i = 0; i < p.length; i += 1) out.push(p[i].join('~'));
    return out.join('·') + '번';
  }
  function noPartsKey(p) {
    var out = [], i;
    for (i = 0; i < p.length; i += 1) out.push(+p[i][0] + (p[i].length > 1 ? '~' + (+p[i][1]) : ''));
    return out.join('·');
  }
  /* 이름 끝 낱말이 번호면 [앞, 번호 조각] · 아니면 null ('Day 3' → ['Day', [['3']]]) */
  function noTail(c) {
    var m = c.match(/^(.*\S)\s+(\S+)$/), p;
    if (!m) return null;
    p = noParts(m[2]);
    return p ? [m[1], p] : null;
  }
  /* 학생에게 보이는 번호: '04' → '04번' · '5-6' → '5~6번' · '3,5' → '3·5번' · '15강 01' → '15강 01번' · 끝이 번호인 이름도 '번'
     (앞말이 영어 낱말이면 '번' 없이: 'Day 3' · 'Lesson 4' · 'Further Reading 1' · C2 검수 L9)
     · 숫자가 아닌 이름(ANALYSIS)은 적힌 그대로 · 빈 것 '' */
  function noLabel(s) {
    var g = noGang(s), p = noParts(g[1]), c, t;
    if (p) c = noPartsLabel(p);
    else {
      c = g[1].replace(/[–—]/g, '-');
      t = noTail(c);
      if (t) c = t[0] + ' ' + (/[A-Za-z]$/.test(t[0]) ? noPartsLabel(t[1]).replace(/번$/, '') : noPartsLabel(t[1]));
    }
    return g[0] ? (c ? g[0] + ' ' + c : g[0]) : c;
  }
  /* 견주기용: '04' = '4' = '4번' = '15강 01' · 'ANALYSIS' = 'analysis' = '16강 ANALYSIS' (강 머리는 떼고 견줌) */
  function noKey(s) {
    var g = noGang(s), p = noParts(g[1]), t;
    if (p) return noPartsKey(p);
    t = noTail(g[1]);
    if (t) return nows(t[0]).toLowerCase() + ' ' + noPartsKey(t[1]);
    return nows(g[1]).toLowerCase();
  }
  /* 강 머리까지 넣은 열쇠('15강|1') · 머리가 없으면 noKey 와 같음 — 두 강에 같은 번호가 있을 때 목차 짝 찾기에 먼저 씀 */
  function noFullKey(s) {
    var g = noGang(s);
    return g[0] ? g[0] + '|' + noKey(s) : noKey(s);
  }
  /* 워크북 번호가 지문 이름과 다른가(워크북이 비면 다르지 않다고 봄 · 빈 워크북 = 워크북 없음) */
  function wbDiff(no, wb) { return !!nows(wb) && noKey(no) !== noKey(wb); }

  /* 지문 줄 다듬기: [{no, at, stop, wb}] · 이름 없는 줄은 뺌 · 시각은 0 이상 숫자만(아니면 null) · 판서 쪽은 담지 않음 */
  function paperItems(list) {
    var out = [], i, x, at, st;
    if (!isArr(list)) return out;
    for (i = 0; i < list.length; i += 1) {
      x = list[i];
      if (!x || typeof x !== 'object' || !nows(x.no)) continue;
      at = typeof x.at === 'number' && isFinite(x.at) && x.at >= 0 ? x.at : null;
      st = typeof x.stop === 'number' && isFinite(x.stop) && x.stop > 0 ? x.stop : null;
      out.push({ no: left(str(x.no).replace(/^\s+|\s+$/g, ''), 40), at: at, stop: st, wb: left(str(x.wb).replace(/^\s+|\s+$/g, ''), 40) });
    }
    return out;
  }
  /* lec_paper 답 → {강의 id: 지문 줄들} (줄이 없는 강의는 뺌) · 못 읽으면 {} */
  function paperMap(r) {
    var out = {}, i, x, p;
    if (!r || !isArr(r.items)) return out;
    for (i = 0; i < r.items.length; i += 1) {
      x = r.items[i];
      if (!x || !x.id) continue;
      p = paperItems(x.p);
      if (p.length) out[str(x.id)] = p;
    }
    return out;
  }
  /* 목차 줄의 회색 표: 워크북 번호가 다를 때만 '워크북 5~6번' · 같으면 '' */
  function paperTag(it) { return it && wbDiff(it.no, it.wb) ? '워크북 ' + noLabel(it.wb) : ''; }
  /* 영상 위 한 줄(검수 A M2): 워크북이 있는 지문이 없으면 '종이: 판서' · 빈 워크북이나 다른 번호가 하나라도 있으면 괄호 없이
     · 모두 워크북이 있고 번호가 같을 때만 '(지문 번호 그대로)' */
  function paperLine(items) {
    var i, has = 0, odd = 0;
    if (!isArr(items) || !items.length) return '';
    for (i = 0; i < items.length; i += 1) {
      if (!nows(items[i].wb)) odd = 1;
      else { has = 1; if (wbDiff(items[i].no, items[i].wb)) odd = 1; }
    }
    if (!has) return '종이: 판서';
    return odd ? '종이: 판서 · 워크북' : '종이: 판서 · 워크북(지문 번호 그대로)';
  }
  /* 멈춤 판이 서는 지문: 시작 · 멈춤이 다 있고 멈춤 - 시작이 60초 이상 · 워크북이 있는 지문만(빈 워크북 = 워크북 없음 · 검수 A M2) */
  function canStop(it) { return !!it && it.at != null && it.stop != null && it.stop - it.at >= 60 && !!nows(it.wb); }
  /* 옆 판 글: '04번 워크북 풀어 보고 계속 봐요' · 다르면 '04번 · 워크북 5~6번 풀어 보고 계속 봐요' · 워크북이 비면 '04번 풀어 보고 계속 봐요' */
  function stopText(it) {
    if (!it) return '';
    if (!nows(it.wb)) return noLabel(it.no) + ' 풀어 보고 계속 봐요';
    return noLabel(it.no) + (wbDiff(it.no, it.wb) ? ' · 워크북 ' + noLabel(it.wb) : ' 워크북') + ' 풀어 보고 계속 봐요';
  }
  /* 반 공지에 붙는 한 줄(검수 A M1): 워크북 번호가 다른 지문만 '워크북: 03번 → 5~6번 · 07번 → 9번' · 다른 지문이 없으면 '' */
  function paperNotice(items) {
    var out = [], i, it;
    items = paperItems(items);
    for (i = 0; i < items.length; i += 1) {
      it = items[i];
      if (wbDiff(it.no, it.wb)) out.push(noLabel(it.no) + ' → ' + noLabel(it.wb));
    }
    return out.length ? '워크북: ' + out.join(' · ') : '';
  }
  /* 목차(chapters) 줄마다 맞는 지문 줄(없으면 null): 시작 시각이 3초 안이면 먼저 · 아니면 이름 앞부분('01번 · …' → 01)으로
     (이름은 강 머리까지 같은 것 '15강 01번' = '15강 01' 을 먼저 · 없으면 강 머리를 뗀 번호로 · 검수 A L17) */
  function paperMatch(chapters, items) {
    var out = [], used = [], i, j, c, best, bd, d, key, full, head;
    chapters = isArr(chapters) ? chapters : [];
    items = isArr(items) ? items : [];
    for (i = 0; i < chapters.length; i += 1) {
      c = chapters[i] || {};
      best = -1; bd = 3.0001;
      for (j = 0; j < items.length; j += 1) {
        if (used[j] || items[j].at == null || typeof c.t !== 'number' || !isFinite(c.t)) continue;
        d = Math.abs(items[j].at - c.t);
        if (d < bd) { bd = d; best = j; }
      }
      if (best < 0) {
        head = str(c.title).split(/\s*[·•|:]\s*/)[0];
        key = noKey(head); full = noFullKey(head);
        for (j = 0; j < items.length && key; j += 1) {
          if (!used[j] && noFullKey(items[j].no) === full) { best = j; break; }
        }
        for (j = 0; j < items.length && key && best < 0; j += 1) {
          if (!used[j] && noKey(items[j].no) === key) { best = j; break; }
        }
      }
      if (best >= 0) used[best] = true;
      out.push(best >= 0 ? items[best] : null);
    }
    return out;
  }

  /* 'HH:MM' → 분(못 읽으면 NaN) */
  function hmMin(v) {
    var m = str(v).match(/^\s*(\d{1,2}):(\d{2})/);
    return m && +m[1] <= 47 && +m[2] <= 59 ? +m[1] * 60 + +m[2] : NaN;
  }
  /* 반 시간표(히즈북스 classes[].schedule)에서 요일 wd(0 = 일)의 시작(isEnd 거짓)·끝 'HH:MM' · 수업 없는 요일은 ''
     (히즈북스 _classStart · _classEnd 와 같은 차례: days → times[요일] → 숫자 칸 → startTime/endTime · 날짜별 바꿈은 안 봄) */
  function classTime(c, wd, isEnd) {
    var WK = ['일', '월', '화', '수', '목', '금', '토'];
    if (!c || typeof c !== 'object' || !(wd >= 0 && wd <= 6)) return '';
    var dy = WK[wd], sc = c.schedule && typeof c.schedule === 'object' ? c.schedule : {};
    var isA = Object.prototype.toString.call(sc) === '[object Array]';
    var v = isA ? sc[wd] : sc[String(wd)], ds = sc.days, tm;
    if (Object.prototype.toString.call(ds) === '[object Array]' && ds.length) {
      if (ds.indexOf(dy) < 0) return '';
    } else if (typeof ds === 'string' && ds) {
      if (ds.indexOf(dy) < 0) return '';
    } else if (v === undefined || v === null || v === '') {
      return '';
    }
    tm = sc.times && typeof sc.times === 'object' ? sc.times[dy] : null;
    if (isEnd) {
      if (tm && truthy(tm.end)) return jtext(tm.end);
      if (truthy(sc.end)) return jtext(sc.end);
      if (truthy(c.endTime)) return jtext(c.endTime);
    } else {
      if (tm && truthy(tm.start)) return jtext(tm.start);
      if (truthy(v)) return jtext(v);
      if (truthy(c.startTime)) return jtext(c.startTime);
    }
    return '';
  }
  /* 녹화가 어느 반 수업인지: 그 요일에 수업이 있는 반 중 (시작 − 20분, 끝 + 20분) 안에 녹화 시작이 든 반이 꼭 하나일 때만 pick.
     아니면 pick '' · cands = 그 요일에 수업이 있는 반 id(선생님이 고름 · 알림 없음). 새벽 5시 전 녹화는 그 수업일 밤으로 봄 */
  function pickClass(classes, day, start) {
    var out = { pick: '', cands: [] }, p = dayParts(day), sm = hmMin(start), hits = [], i, c, a, b;
    if (!p) return out;
    if (sm < 300) sm += 1440;
    classes = Object.prototype.toString.call(classes) === '[object Array]' ? classes : [];
    for (i = 0; i < classes.length; i += 1) {
      c = classes[i];
      if (!c || typeof c !== 'object' || !truthy(c.id)) continue;
      a = hmMin(classTime(c, p.wd, false));
      if (!isFinite(a)) continue;
      out.cands.push(jtext(c.id));
      b = hmMin(classTime(c, p.wd, true));
      if (!isFinite(b)) b = a;
      if (b < a) b += 1440;
      if (isFinite(sm) && sm > a - 20 && sm < b + 20) hits.push(jtext(c.id));
    }
    if (hits.length === 1) out.pick = hits[0];
    return out;
  }

  /* 유튜브 IFrame API 를 한 번만 불러 옴(이미 있는 onYouTubeIframeAPIReady 는 이어서 부름) */
  var ytP = null;
  function loadYT() {
    if (w.YT && typeof w.YT.Player === 'function') return Promise.resolve(w.YT);
    if (ytP) return ytP;
    ytP = new Promise(function (res, rej) {
      var done = false;
      var prev = w.onYouTubeIframeAPIReady;
      w.onYouTubeIframeAPIReady = function () {
        try { if (typeof prev === 'function') prev.apply(this, arguments); } catch (e) { /* 앞 처리기의 오류는 무시 */ }
        if (!done) { done = true; res(w.YT); }
      };
      function fail() {
        if (done) return;
        done = true; ytP = null; rej(err('yt'));
      }
      var have = null;
      try { have = document.querySelector('script[src*="youtube.com/iframe_api"]'); } catch (e1) { have = null; }
      if (!have) {
        var sc = document.createElement('script');
        sc.src = 'https://www.youtube.com/iframe_api';
        sc.onerror = fail;
        (document.head || document.documentElement).appendChild(sc);
      }
      setTimeout(function () {
        if (!done && w.YT && typeof w.YT.Player === 'function') { done = true; res(w.YT); return; }
        fail();
      }, 20000);
    });
    return ytP;
  }

  function devName() {
    var n = w.navigator || {}, ua = str(n.userAgent), tp = +n.maxTouchPoints || 0;
    if (/iPad/.test(ua) || (/Macintosh/.test(ua) && tp > 1)) return '아이패드';
    if (/iPhone|iPod/.test(ua)) return '아이폰';
    if (/Android/i.test(ua)) return /Mobile/i.test(ua) ? '안드로이드 폰' : '안드로이드 태블릿';
    if (/CrOS/.test(ua)) return '크롬북';
    if (/Windows/i.test(ua)) return '윈도우 PC';
    if (/Macintosh|Mac OS X/.test(ua)) return '맥';
    return '기기';
  }

  function rnd(n) {
    var a = [], i, c = w.crypto || w.msCrypto;
    try {
      if (c && typeof c.getRandomValues === 'function' && typeof Uint8Array !== 'undefined') {
        var u = new Uint8Array(n);
        c.getRandomValues(u);
        for (i = 0; i < n; i += 1) a.push(u[i]);
        return a;
      }
    } catch (e) { a = []; }
    for (i = 0; i < n; i += 1) a.push(Math.floor(Math.random() * 256));
    return a;
  }
  function hx(b) { return (b < 16 ? '0' : '') + b.toString(16); }
  function uuid() {
    var b = rnd(16), s = '', i;
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    for (i = 0; i < 16; i += 1) {
      s += hx(b[i]);
      if (i === 3 || i === 5 || i === 7 || i === 9) s += '-';
    }
    return s;
  }
  function hex64() {
    var b = rnd(32), s = '', i;
    for (i = 0; i < 32; i += 1) s += hx(b[i]);
    return s;
  }

  function lsGet(k, d) {
    try {
      var v = w.localStorage.getItem(k);
      if (v === null || v === undefined) return d;
      return JSON.parse(v);
    } catch (e) { return d; }
  }
  function lsSet(k, v) {
    try { w.localStorage.setItem(k, JSON.stringify(v)); return true; } catch (e) { return false; }
  }
  function lsDel(k) {
    try { w.localStorage.removeItem(k); return true; } catch (e) { return false; }
  }

  var ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  function esc(s) { return str(s).replace(/[&<>"']/g, function (c) { return ESC[c]; }); }

  /* ------------------------------------------------- 화면 문구(학생 · 학부모 · 선생님) */

  var CONSENT_VER = 'v1-2026-11'; /* class-setup.sql lec__consent_ver() 와 같게 */
  var MEMO_CHIPS = ['교실에서 워크북 확인', '기록 오류'];

  /* '2026-11-18' → '11.18' */
  function fmtMD(v) {
    var p = dayParts(v);
    return p ? p.m + '.' + p.d : '';
  }

  /* 부르는 이름: 세 글자면 뒤 두 글자(김민준 → 민준) · 아니면 그대로 */
  function callName(name) {
    var s = str(name).replace(/^\s+|\s+$/g, ''), a = cps(s);
    return a.length === 3 ? a[1] + a[2] : s;
  }
  /* 받침 있으면 '이는'(민준이는) · 없으면 '는'(지우는) */
  function josaNeun(word) {
    var a = cps(str(word).replace(/\s+$/, '')), c = a.length ? a[a.length - 1].charCodeAt(0) : 0;
    return c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 !== 0 ? '이는' : '는';
  }

  /* 학부모 안내 한 문단. o = {name, day:'YYYY.MM.DD', title, pct, nextNo:'07' 또는 '', done, absent}
     done(다 봄 · 선생님 확인) 또는 pct 90 이상 = 끝까지 봄 · pct 0 = 아직 안 엶 */
  function parentMsg(o) {
    o = o || {};
    /* 날짜가 없으면 빼고 씀(fmtDay 는 빈 값이면 오늘을 주므로 오늘로 지어내지 않게) */
    var nm = callName(o.name), dd = o.day ? fmtDay(o.day) : '', pct = Math.round(+o.pct || 0);
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    var head = nm + josaNeun(nm) + ' ' + (dd ? dd + ' ' : '') + (o.absent ? '결석한 ' : '') +
               '수업 영상(' + str(o.title) + ')을 ';
    if (o.done || pct >= 90) return head + '끝까지 봤습니다. 다음 수업에서 이어서 확인하겠습니다.';
    if (pct === 0) return head + '아직 열지 않았습니다. 다음 등원 전까지 볼 수 있도록 말씀 부탁드립니다.';
    return head + pct + '%까지 봤습니다. 다음 등원 전까지 ' + (o.nextNo ? str(o.nextNo) + '번부터' : '남은 부분을') +
           ' 마저 보도록 말씀 부탁드립니다.';
  }

  /* 로그인 잠금 문구(lec_login 이 {err:'locked', day, secs} 를 줄 때) · 아니면 '' */
  function lockMsg(r) {
    if (!r || r.err !== 'locked') return '';
    if (r.day) return '여러 번 틀려서 오늘은 잠겼어요. 선생님께 말씀해 주세요.';
    return '다섯 번 틀려서 잠겼어요. ' + Math.max(1, Math.ceil((+r.secs || 0) / 60)) + '분 뒤 다시 해 보세요.';
  }

  /* 유튜브 재생기 오류 번호 → 문구(staff = 선생님 화면) */
  function ytErr(code, staff) {
    code = +code;
    if (staff) {
      if (code === 100) return '비공개이거나 지워진 영상이에요. 유튜브에서 일부공개인지 확인해 주세요';
      if (code === 101 || code === 150) return '유튜브 스튜디오에서 퍼가기 허용을 켜 주세요';
      if (code === 2) return '링크 모양이 맞지 않아요';
    } else {
      if (code === 100) return '공개 기간이 끝난 영상이에요';
      if (code === 101 || code === 150) return '지금 볼 수 없는 영상이에요. 선생님께 알려 주세요';
    }
    return '영상을 불러오지 못했어요. 다시 열어 보세요';
  }

  /* 선생님 현황의 기록 상태: 동의 표(lec_consent 줄들)에서 그 학생 → 'agree' · 'none'(기록 안 함) · 'pending'(동의 전) */
  function recOf(rows, skey) {
    var i, c = null;
    if (isArr(rows)) {
      for (i = 0; i < rows.length; i += 1) { if (rows[i] && rows[i].sid === skey) { c = rows[i]; break; } }
    }
    if (c && c.choice === 'agree' && c.ver === CONSENT_VER) return 'agree';
    if (c && c.choice === 'none') return 'none';
    return 'pending';
  }

  /* 학생 질문 상태(lec_qna_list 항목) */
  var QSTATE = {
    wait: { k: 'wait', label: '답변 대기', bg: '#FBF0C9', fg: '#7A5410' },
    'new': { k: 'new', label: '답변 완료', bg: '#DDF0E5', fg: '#1E5A3E' },
    read: { k: 'read', label: '읽음', bg: '#F2F1EA', fg: '#6B6E62' }
  };
  function qState(item) {
    if (!item || !item.answered) return QSTATE.wait;
    return item.unread ? QSTATE['new'] : QSTATE.read;
  }

  /* 공개 끝이 오늘부터 7일 안이면 'M.D까지 볼 수 있어요' · 아니면(끝 없음 · 더 남음 · 이미 끝남) '' */
  function untilNote(until) {
    var p = dayParts(until), q = dayParts(isoDay());
    if (!p || !q || typeof until !== 'string' || !until) return '';
    var n = Math.round((Date.UTC(p.y, p.m - 1, p.d) - Date.UTC(q.y, q.m - 1, q.d)) / DAY);
    return n >= 0 && n <= 7 ? p.m + '.' + p.d + '까지 볼 수 있어요' : '';
  }

  /* ------------------------------------------------------------- 서버 부르기 */

  function rpc(fn, args, opt) {
    opt = opt || {};
    args = args || {};
    if (w.__lecOffline) return Promise.reject(err('network'));
    if (Lec.DEMO) {
      /* 시험용(연습 화면에서만): window.__lecSlow = {함수 이름: 더 늦출 ms} · 느린 망에서 답이 늦게 오는 것 흉내 */
      var slow = 0;
      try { slow = w.__lecSlow && typeof w.__lecSlow === 'object' ? Math.max(0, Math.min(10000, +w.__lecSlow[fn] || 0)) : 0; } catch (e0) { slow = 0; }
      return new Promise(function (res, rej) {
        setTimeout(function () {
          if (w.__lecOffline) { rej(err('network')); return; }
          var M = w.LecMock, r, x;
          if (!M || typeof M.rpc !== 'function') { rej(err('network')); return; }
          try {
            r = M.rpc(fn, JSON.parse(JSON.stringify(args)));
          } catch (e) {
            x = err('http');
            x.status = (e && e.status) || 500;
            if (e && e.code) x.code = e.code;
            if (e && e.detail) x.detail = e.detail;
            if (!(e && e.status)) {
              x.cause = e;
              try { if (w.console) w.console.error(e); } catch (e2) { /* 없음 */ }
            }
            rej(x);
            return;
          }
          res(r === undefined ? null : JSON.parse(JSON.stringify(r)));
        }, 120 + slow);
      });
    }
    if (typeof w.fetch !== 'function') return Promise.reject(err('network'));
    var init = {
      method: 'POST',
      headers: { 'apikey': SUPA_KEY, 'Authorization': 'Bearer ' + SUPA_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(args),
      cache: 'no-store'
    };
    if (opt.keepalive) init.keepalive = true;
    var p;
    try { p = w.fetch(SUPA_URL + '/rest/v1/rpc/' + fn, init); } catch (e3) { return Promise.reject(err('network')); }
    return p.then(function (r) {
      return r.text().then(function (t) {
        var x;
        if (!r.ok) { x = err('http'); x.status = r.status; x.body = t; throw x; }
        try { return JSON.parse(t); } catch (e4) { x = err('http'); x.status = r.status; x.body = t; throw x; }
      }, function () {
        var x = err(r.ok ? 'network' : 'http');
        if (!r.ok) x.status = r.status;
        throw x;
      });
    }, function () { throw err('network'); });
  }

  function toInt(v) {
    if (v === null || v === undefined || v === '') return null;
    v = +v;
    return isFinite(v) ? Math.round(v) : null;
  }

  function login(name, pin, dev) {
    return rpc('lec_login', { p_name: str(name), p_pin: str(pin), p_dev: dev == null ? devName() : str(dev) });
  }
  function home(key) { return rpc('lec_home', { p_key: key == null ? null : str(key) }); }

  /* 기록 동의: choice = 'agree'(기록함) · 'none'(기록 없이 보기) · ver 를 안 주면 지금 판 */
  function consent(key, choice, ver) {
    return rpc('lec_consent', {
      p_key: key == null ? null : str(key),
      p_choice: str(choice),
      p_ver: ver == null ? CONSENT_VER : str(ver)
    });
  }

  /* 실제 배속 → 서버가 받는 값(0.25~2 로 자름 · 모르면 1) */
  function rateOf(v) {
    var r = +v;
    if (!isFinite(r) || r <= 0) return 1;
    return Math.min(2, Math.max(0.25, r));
  }

  /* o = {key, lecture, session, seen, total, pos, from, to, dur, dev, rate, scale} · 늘 keepalive
     total = «이번 보기(session)»에서 실제로 튼 누적 초. 서버는 lec_session.watched 와 견줘 늘어난 만큼만 더함
     (강의 전체 누적을 보내면 새 보기마다 최대 120 × 배속 + 30초(1배 150초 · 2배 270초)가 더 붙음 · class-setup.sql lec_beat 기준) */
  function beat(o) {
    o = o || {};
    var a = {
      p_key: o.key == null ? null : str(o.key),
      p_lecture: o.lecture || null,
      p_session: o.session || null,
      p_seen: str(o.seen),
      p_total: toInt(o.total),
      p_pos: toInt(o.pos),
      p_from: toInt(o.from),
      p_to: toInt(o.to),
      p_dur: toInt(o.dur),
      p_dev: o.dev == null ? devName() : str(o.dev),
      p_rate: rateOf(o.rate)
    };
    if (Lec.DEMO) {
      var sc = +o.scale;
      a.p_scale = isFinite(sc) && sc > 0 ? sc : 1;
    }
    return rpc('lec_beat', a, { keepalive: true });
  }
  function qna(key, lecture) {
    return rpc('lec_qna_list', { p_key: key == null ? null : str(key), p_lecture: lecture || null });
  }
  /* kind = 'content'(내용 · 기본) · 'tech'(영상·진도 문제) · 덧붙인 글은 서버가 처음 질문의 종류를 씀 */
  function ask(key, lecture, body, at, priv, parent, kind) {
    return rpc('lec_ask', {
      p_key: key == null ? null : str(key),
      p_lecture: lecture || null,
      p_body: str(body),
      p_at: toInt(at),
      p_private: !!priv,
      p_parent: parent || null,
      p_kind: kind == null ? 'content' : str(kind)
    });
  }
  function qdel(key, id) { return rpc('lec_qdel', { p_key: key == null ? null : str(key), p_id: id || null }); }
  function logout(key) { return rpc('lec_logout', { p_key: key == null ? null : str(key) }, { keepalive: true }); }
  /* C1 결석한 날 수업: {ok, today, items:[{id, att:'abs'|'in', day, days, mk}]} · 실패는 조용히 null
     (서버에 lec_att 가 아직 없으면(404) 이 화면에서는 다시 묻지 않음 · 목록은 전과 같게) */
  var attGone = false;
  function att(key) {
    if (attGone) return Promise.resolve(null);
    return rpc('lec_att', { p_key: key == null ? null : str(key) }).then(function (r) {
      return r && r.ok && Object.prototype.toString.call(r.items) === '[object Array]' ? r : null;
    }, function (e) {
      if (e && e.status === 404) attGone = true;
      return null;
    });
  }
  /* C3 · C7 지문 줄: {ok, items:[{id, p:[{no, at, stop, wb}]}]} · 판서 쪽은 오지 않음 · 실패는 조용히 null
     (서버에 lec_paper 가 아직 없으면(404) 이 화면에서는 다시 묻지 않음 · 종이 줄 · 멈춤 판은 숨김) */
  var paperGone = false;
  function paper(key) {
    if (paperGone) return Promise.resolve(null);
    return rpc('lec_paper', { p_key: key == null ? null : str(key) }).then(function (r) {
      return r && r.ok && isArr(r.items) ? r : null;
    }, function (e) {
      if (e && e.status === 404) paperGone = true;
      return null;
    });
  }

  /* P1 강의 필기 PDF(11-16 · 내용은 필기 없는 원본 판서의 영상 범위 쪽): {ok, items:[{id, f:[{p, b}]}]} · 올린 파일 이름은 오지 않음 · 실패는 조용히 null
     (서버에 lec_pdf 가 없거나(404) 막혀 있으면(401 · 403) 이 화면에서는 다시 묻지 않음 · 단추는 숨김) */
  var pdfGone = false;
  function pdf(key) {
    if (pdfGone) return Promise.resolve(null);
    return rpc('lec_pdf', { p_key: key == null ? null : str(key) }).then(function (r) {
      return r && r.ok && isArr(r.items) ? r : null;
    }, function (e) {
      if (e && (e.status === 404 || e.status === 401 || e.status === 403)) pdfGone = true;
      return null;
    });
  }
  var PDF_P = /^[0-9a-f]{64}\.pdf$/;
  function pdfOk(p) { return typeof p === 'string' && PDF_P.test(p); }
  /* lec_pdf 응답 → {강의 id: [{p, b}]} · 꼴이 틀린 경로는 버림 */
  function pdfMap(r) {
    var out = {}, i, j, it, f, a;
    if (!r || !isArr(r.items)) return out;
    for (i = 0; i < r.items.length; i += 1) {
      it = r.items[i];
      if (!it || it.id == null || !isArr(it.f)) continue;
      a = [];
      for (j = 0; j < it.f.length; j += 1) {
        f = it.f[j];
        if (f && pdfOk(f.p)) a.push({ p: f.p, b: typeof f.b === 'number' && isFinite(f.b) ? f.b : null });
      }
      if (a.length) out[str(it.id)] = a;
    }
    return out;
  }
  /* 학생이 받는 파일 이름 «HIS MM.DD {교재} {제목} 필기.pdf» · 파일 이름에 못 쓰는 글자는 띄어쓰기로 ·
     앞부분은 낱말 끝에서 46자 안으로 자름(올린 파일 이름은 학생에게 가지 않음) */
  var PDF_BAD = /[\\\/:*?"<>|\u0000-\u001f\u007f]+/g;
  function pdfName(l, day) {
    var p = day ? dayParts(day) : null, bits = ['HIS'], base, cut, sp;
    if (p) bits.push(pad2(p.m) + '.' + pad2(p.d));
    if (l && l.book) bits.push(str(l.book));
    if (l && l.title) bits.push(str(l.title));
    base = bits.join(' ').replace(PDF_BAD, ' ').replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, '');
    if (clen(base) > 46) {
      cut = left(base, 47);
      sp = cut.lastIndexOf(' ');
      base = (sp > 12 ? cut.slice(0, sp) : left(base, 46)).replace(/[\s.]+$/, '');
    }
    return base + ' 필기.pdf';
  }
  /* 여는 길: 카카오톡 안(두 폰 모두) · 안드로이드 = 'dl'(같은 창 · 받기) / 아이폰 · 홈 화면 앱 · PC = 'open'(새 창) */
  function pdfWay(ua) {
    ua = str(ua);
    return /KAKAOTALK/i.test(ua) || /Android/i.test(ua) ? 'dl' : 'open';
  }
  function pdfUrl(p, name, way) {
    if (!pdfOk(p)) return '';
    var u = SUPA_URL + '/storage/v1/object/public/lec-pdf/' + p;
    return way === 'dl' ? u + '?download=' + encodeURIComponent(str(name) || 'HIS 필기.pdf') : u;
  }
  /* 누른 뒤 단추 아래 한 줄(os = 'ios' · 'android' · '') · PC 는 없음 */
  function pdfNote(os, kakao) {
    if (os === 'android') return '받기 시작했어요. 다 받으면 알림이나 ‘다운로드’에서 열 수 있어요.';
    if (kakao) return '받기 시작했어요.';
    if (os === 'ios') return '열린 PDF에서 공유 단추를 누르면 ‘파일에 저장’이나 ‘프린트’를 고를 수 있어요.';
    return '';
  }
  /* PDF 쪽 수 · text = 바이트를 한 글자씩 옮긴 글
     ① 트레일러 /Root → 카탈로그 /Pages → 그 묶음의 /Count(덧붙여 고친 PDF 는 뒤에 나온 정의가 이김)
     ② 없으면 /Parent 없는 맨 위 «/Type /Pages» 의 /Count(마지막 것)
     ③ 그래도 없으면 «/Type /Page» 셈 — 쪽 나무 밖에 버려진 쪽까지 세어 많게 나올 수 있다
        (실행기가 원본 판서에서 영상 범위만 자른 «…_필기.pdf» 가 그렇다: 13쪽인데 17개)
     압축 객체(ObjStm)라 셋 다 못 읽으면 0 → 화면은 쪽 칸을 뺌 */
  function pdfPages(text) {
    var t = str(text), re = /(\d+)\s+\d+\s+obj\b/g, objs = {}, top = 0, last = '', m, end, st, body, c, all, rr;
    while ((m = re.exec(t))) {
      end = t.indexOf('endobj', re.lastIndex);
      if (end < 0) end = t.length;
      st = t.indexOf('stream', re.lastIndex);
      body = t.slice(re.lastIndex, st >= 0 && st < end ? st : end);
      objs[m[1]] = body;
      if (/\/Type\s*\/Pages(?![A-Za-z])/.test(body) && !/\/Parent(?![A-Za-z])/.test(body) && (c = /\/Count\s+(\d+)/.exec(body))) top = +c[1];
      re.lastIndex = end;
    }
    rr = /\/Root\s+(\d+)\s+\d+\s+R/g;
    while ((m = rr.exec(t))) last = m[1];
    m = last && has(objs, last) ? /\/Pages\s+(\d+)\s+\d+\s+R/.exec(objs[last]) : null;
    c = m && has(objs, m[1]) ? /\/Count\s+(\d+)/.exec(objs[m[1]]) : null;
    if (c && +c[1] > 0) return +c[1];
    if (top > 0) return top;
    all = t.match(/\/Type\s*\/Page(?![A-Za-z])/g);
    return all ? all.length : 0;
  }
  /* 서랍 코랄 줄(막지 않음): 파일 이름의 날짜가 수업일과 안 맞으면 한 줄 · 아니면 ''
     ① 실행기 이름 «YYYY-MM-DD(요일) …_필기.pdf»(영상 날짜): 수업일 가운데 같은 날이 없으면
     ② 삼성 노트 이름 «…_YYMMDD_…»(내보낸 날): 어느 수업일보다도 앞이거나 3일 넘게 뒤면
     days = 수업일 하나('YYYY-MM-DD') 또는 여럿(배열 · 앞의 것이 글에 나옴) */
  function pdfStamp(fileName, days) {
    var nm = str(fileName), ds = isArr(days) ? days : [days], ps = [], first = '', i, p, m, a, b, g, lead;
    for (i = 0; i < ds.length; i += 1) {
      p = ds[i] ? dayParts(ds[i]) : null;
      if (p) { ps.push(p); if (!first) first = ds[i]; }
    }
    if (!ps.length) return '';
    m = /^(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)/.exec(nm);
    lead = !!m;
    if (m) a = { y: +m[1], m: +m[2], d: +m[3] };
    else {
      m = /_(\d{2})(\d{2})(\d{2})(?=_|\.pdf$|$)/i.exec(nm);
      if (!m) return '';
      a = { y: 2000 + +m[1], m: +m[2], d: +m[3] };
    }
    if (a.m < 1 || a.m > 12 || a.d < 1 || a.d > 31) return '';
    b = Date.UTC(a.y, a.m - 1, a.d);
    if (new Date(b).getUTCDate() !== a.d) return '';
    for (i = 0; i < ps.length; i += 1) {
      g = Math.round((b - Date.UTC(ps[i].y, ps[i].m - 1, ps[i].d)) / DAY);
      if (lead ? g === 0 : (g >= 0 && g <= 3)) return '';
    }
    return '이 PDF 는 ' + a.m + '.' + a.d + (lead ? ' 수업 영상에서 만든 것이에요' : '에 내보낸 것이에요') + ' · 수업일 ' + fmtDay(first) + ' 필기가 맞는지 봐 주세요';
  }
  /* 3342000 → '3.2MB' · 51200 → '50KB' */
  function fmtBytes(n) {
    n = +n;
    if (!isFinite(n) || n < 0) return '';
    if (n < 1024 * 1024) return Math.max(1, Math.round(n / 1024)) + 'KB';
    return (Math.round(n / 104857.6) / 10) + 'MB';
  }

  var Lec = {
    SUPA_URL: SUPA_URL,
    SUPA_KEY: SUPA_KEY,
    DEMO: qflag('demo'),
    TEST: qflag('t'),
    FAKE: qflag('fake'),
    LS: { key: 'lec-key', pend: 'lec-pend', sess: 'lec-sess', rate: 'lec-rate' },
    DONE: 90,
    MAX_BITS: 2160,
    MAX_DUR: 21600,
    CONSENT_VER: CONSENT_VER,
    MEMO_CHIPS: MEMO_CHIPS,

    rpc: rpc,
    login: login,
    home: home,
    consent: consent,
    beat: beat,
    rateOf: rateOf,
    qna: qna,
    ask: ask,
    qdel: qdel,
    logout: logout,
    att: att,
    paper: paper,
    pdf: pdf,

    nows: nows,
    norm: norm,
    skey: skey,
    mask: mask,
    truthy: truthy,
    rosterFrom: rosterFrom,
    pinsOf: pinsOf,
    jtext: jtext,
    btrim: btrim,
    clen: clen,
    left: left,

    now: now,
    ts: ts,
    isoDay: isoDay,
    fmtDay: fmtDay,
    fmtDur: fmtDur,
    fmtMin: fmtMin,
    fmtWhen: fmtWhen,

    bmLen: bmLen,
    bmOr: bmOr,
    bmCount: bmCount,
    bmPct: bmPct,
    bucketLen: bucketLen,
    bmFromSecs: bmFromSecs,
    addSpan: addSpan,
    bmRange: bmRange,

    chapterAt: chapterAt,
    chapterRanges: chapterRanges,
    chapterNo: chapterNo,
    sceneLabel: sceneLabel,
    chapterSeen: chapterSeen,
    nextNo: nextNo,

    fmtMD: fmtMD,
    callName: callName,
    josaNeun: josaNeun,
    parentMsg: parentMsg,
    lockMsg: lockMsg,
    ytErr: ytErr,
    recOf: recOf,
    qState: qState,
    untilNote: untilNote,

    ytId: ytId,
    ytThumb: ytThumb,
    parseRunner: parseRunner,
    parseOnline: parseOnline,
    noLabel: noLabel,
    noKey: noKey,
    noFullKey: noFullKey,
    wbDiff: wbDiff,
    paperItems: paperItems,
    paperMap: paperMap,
    paperTag: paperTag,
    paperLine: paperLine,
    canStop: canStop,
    stopText: stopText,
    paperNotice: paperNotice,
    paperMatch: paperMatch,
    pdfOk: pdfOk,
    pdfMap: pdfMap,
    pdfName: pdfName,
    pdfWay: pdfWay,
    pdfUrl: pdfUrl,
    pdfNote: pdfNote,
    pdfPages: pdfPages,
    pdfStamp: pdfStamp,
    fmtBytes: fmtBytes,
    classTime: classTime,
    pickClass: pickClass,
    hmMin: hmMin,
    loadYT: loadYT,
    devName: devName,
    uuid: uuid,
    hex64: hex64,
    lsGet: lsGet,
    lsSet: lsSet,
    lsDel: lsDel,
    esc: esc
  };

  w.Lec = Lec;
})(window);

/* ======================================================= C2 (11-16) 학교 시험 D-day · 시험 범위 영상
   - 히즈북스 앱(index.html)의 학교 시험 일정 함수를 ES5 로 옮김: _examNorm · _examCalc · _schoolKeyRaw · _schoolDispRaw ·
     _stuSchool · _gradeFromClass · _stuGradeRaw(같은 값을 줌 · _check/class_c2test.js 가 앱 소스를 꺼내 견줌)
     앱의 today() 는 'YYYY.MM.DD' · 여기서는 오늘을 인자로 받음('YYYY-MM-DD' 도 됨 · 없으면 서울 오늘)
   - 학교 시험 일정은 선생님 화면만 읽음(app_state 의 main · pt-etc 줄에서 examSchool · examSchoolG 만) → examMerge 로 앱처럼 합침
     (두 줄을 다 읽었을 때만 값을 줌 · 한 줄만 읽힌 화면은 범위 띠 · 조용히 맞추기를 하지 않음)
   - 시험 고르기 = 앱 _examRecFor 와 같음: 학년 예외(examSchoolG «학교|학년»)가 D-20 안 · 켬(on) · 시험 중일 때만 먼저 →
     학교 일정 → 학년 예외(앞에서 못 쓴 것)
   - RNG_VER = 시험 이름(examName) · 학교 키 · 시험 고르기 · 묶기 규칙의 판 · 규칙을 바꾸면 올림 → 서버는 더 낮은 판 화면의 고침을 받지 않음
   - 범위 줄 = 학교 · 학년 · 시험(term = 학년도-학기-종류) 하나 · 받는 학생 = 명단 학생 id(같은 id 를 두 학생이 쓰면 학생 열쇠)
   - 서버 함수: lec_range_me(학생) · lec_range_staff · lec_range_save · lec_range_sync(선생님) — class-setup.sql C2 절
     서버에 아직 없으면(옛 SQL · 404 · PGRST202) 조용히 넘어감 · 감싼 함수는 모두 실패해도 거절하지 않고 값으로 돌려줌 */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec) return;
  var DAY = 86400000;

  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function str(v) { return v == null ? '' : String(v); }
  function isObj(v) { return !!v && typeof v === 'object' && !isArr(v); }
  function pad2(n) { return (n < 10 ? '0' : '') + n; }
  function cmpS(a, b) { a = str(a); b = str(b); return a < b ? -1 : (a > b ? 1 : 0); }

  /* ------------------------------------------------ 앱 함수 옮김(글자 그대로의 규칙) */

  /* 앱 _examNorm: 여러 꼴의 날짜 글자 → 'YYYY.MM.DD' · 아니면 null */
  function examNorm(rawD) {
    try {
      var pz = String(rawD || '').trim().split(/[^0-9]+/).filter(function (x) { return x.length > 0; });
      var py9, pm9, pd9, t9;
      if (pz.length === 1 && pz[0].length === 8) {
        py9 = pz[0].slice(0, 4); pm9 = pz[0].slice(4, 6); pd9 = pz[0].slice(6, 8);
      } else if (pz.length === 3 && pz[0].length === 4 && pz[1].length <= 2 && pz[2].length <= 2) {
        py9 = pz[0]; pm9 = ('0' + pz[1]).slice(-2); pd9 = ('0' + pz[2]).slice(-2);
      } else {
        return null;
      }
      if (!(+pm9 >= 1 && +pm9 <= 12 && +pd9 >= 1 && +pd9 <= 31)) return null;
      if (!(+py9 >= 2000 && +py9 <= 2100)) return null;
      t9 = new Date(+py9, +pm9 - 1, +pd9);
      if (t9.getFullYear() !== +py9 || (t9.getMonth() + 1) !== +pm9 || t9.getDate() !== +pd9) return null;
      return py9 + '.' + pm9 + '.' + pd9;
    } catch (e) { return null; }
  }

  /* 오늘('YYYY.MM.DD' · 'YYYY-MM-DD' · 없으면 서울 오늘) → 'YYYY.MM.DD' */
  function tdDot(today) { return examNorm(today == null ? Lec.isoDay() : today); }

  /* 앱 _examCalc(v, force) · 앱의 this.today() 대신 today 인자 */
  function examCalc(v, today, force) {
    try {
      if (!v || v.del || !v.date) return null;
      var d = examNorm(v.date);
      if (!d) return null;
      var d2 = (examNorm(v.end) || d);
      if (d2 < d) d2 = d;
      var td = tdDot(today);
      if (!td) return null;
      if (d2 < td) return null;
      var lb = ((v.label || '').trim() || '학교 시험');
      var dtx = (function () {
        try {
          var q9 = String(d).split('.');
          var o9 = new Date(+q9[0], +q9[1] - 1, +q9[2]);
          return ((+q9[1]) + '월 ' + (+q9[2]) + '일(' + '일월화수목금토'.charAt(o9.getDay()) + ')');
        } catch (e9) { return ''; }
      })();
      if (td >= d) {
        return { label: lb, date: d, end: d2, n: 0, during: true, sub: dtx, val: '시험 중', badge: (lb + ' 시험 중') };
      }
      var p1 = d.split('.');
      var p2 = td.split('.');
      var n = Math.round((new Date(+p1[0], +p1[1] - 1, +p1[2]) - new Date(+p2[0], +p2[1] - 1, +p2[2])) / 86400000);
      var armed = !!v.on;
      if (!armed && !force && n > 20) return null;
      return {
        label: lb, date: d, end: d2, n: n, during: false, armed: armed, sub: dtx,
        val: (n === 0 ? 'D-DAY' : ('D-' + n)), badge: (lb + ' ' + (n === 0 ? 'D-DAY' : ('D-' + n)))
      };
    } catch (e) { return null; }
  }

  /* 앱 _schoolKey(_schoolKeyRaw): 띄어쓰기 빼고 «고등학교 → 고» 줄임 · 끝의 숫자 · 학년 · 반 떼기 */
  function schoolKey(s) {
    var k9 = String(s || '');
    if (!k9) return '';
    try {
      var x = String(k9 || '').split(' ').join('');
      if (!x) return '';
      x = x.split('여자고등학교').join('여고').split('여자중학교').join('여중')
        .split('고등학교').join('고').split('중학교').join('중').split('초등학교').join('초');
      var g9 = true, ch, pv, ok9, i9, c9;
      while (g9 && x.length > 1) {
        g9 = false;
        ch = x.charAt(x.length - 1);
        if ((ch >= '0' && ch <= '9') || ch === '-' || ch === '.' || ch === '/' || ch === ',' || ch === '(' || ch === ')' || ch === '[' || ch === ']') {
          x = x.slice(0, -1); g9 = true; continue;
        }
        if (x.length > 2 && x.slice(-2) === '학년') { x = x.slice(0, -2); g9 = true; continue; }
        if (x.length > 2 && ch === '년') {
          pv = x.charAt(x.length - 2);
          if (pv >= '0' && pv <= '9') { x = x.slice(0, -1); g9 = true; continue; }
        }
        if (x.length > 2 && ch === '반') {
          pv = x.charAt(x.length - 2);
          if (pv >= '0' && pv <= '9') { x = x.slice(0, -1); g9 = true; continue; }
          if (x.length > 3 && pv >= '가' && pv <= '하') { x = x.slice(0, -2); g9 = true; continue; }
        }
      }
      ok9 = false;
      for (i9 = 0; i9 < x.length; i9++) {
        c9 = x.charAt(i9);
        if ((c9 >= '가' && c9 <= '힣') || (c9 >= 'A' && c9 <= 'Z') || (c9 >= 'a' && c9 <= 'z')) { ok9 = true; break; }
      }
      if (!ok9 || x.length < 2) return '';
      return x;
    } catch (e) { return ''; }
  }

  /* 앱 _schoolDisp(_schoolDispRaw): 보이는 학교 이름(끝의 숫자 · 학년 · 반만 뗌) */
  function schoolDisp(s) {
    var k9 = String(s || '');
    if (!k9) return '';
    try {
      var x = String(k9 || '').trim();
      if (!x) return '';
      var g9 = true, ch, pv;
      while (g9 && x.length > 1) {
        g9 = false;
        ch = x.charAt(x.length - 1);
        if ((ch >= '0' && ch <= '9') || ch === '-' || ch === '.' || ch === ' ') { x = x.slice(0, -1); g9 = true; continue; }
        if (x.length > 2 && x.slice(-2) === '학년') { x = x.slice(0, -2); g9 = true; continue; }
        if (x.length > 2 && ch === '반') {
          pv = x.charAt(x.length - 2);
          if (pv >= '0' && pv <= '9') { x = x.slice(0, -1); g9 = true; continue; }
        }
      }
      return x.trim();
    } catch (e) { return String(k9 || ''); }
  }
  /* 띠 · 칩 · 서랍 머리에 쓰는 짧은 학교 이름: schoolKey 와 같은 줄임(여자고등학교 → 여고 · 고등학교 → 고 …) 뒤 schoolDisp
     ('바다고등학교' → '바다고' · '한빛여자고등학교' → '한빛여고' · '한빛여고 1학년' → '한빛여고' · 띄어쓰기는 그대로 · C2 검수 L1) */
  function schoolShort(s) {
    var x = String(s || '');
    if (!x) return '';
    x = x.split('여자고등학교').join('여고').split('여자중학교').join('여중')
      .split('고등학교').join('고').split('중학교').join('중').split('초등학교').join('초');
    return schoolDisp(x);
  }

  /* 앱 _stuSchool */
  function stuSchool(stu) {
    try { return String((stu && (stu.school || (stu.intake && stu.intake.school))) || '').trim(); } catch (e) { return ''; }
  }

  /* K1(11-18) 강의마다 볼 학교 — 서버 lec__schs · lec__sch_ok 와 같은 셈(class-setup.sql 맨 앞 K1 · CLAUDE.md 학교 칸 절)
     schMap(classes) = {학생 열쇠(skey): [학교 열쇠 · 겹침 없이 · 차례]} · 명단 거름은 rosterFrom 과 같음 · 빈 목록 = 학교 빈칸
     (같은 학생이 두 반에 다른 학교로 적히면 둘 다 · 학교 열쇠 = schoolKey(stuSchool(학생)))
     schOk(keys, sch) = 강의 칸이 비었거나(반 전체) · 학생 학교가 빈칸이거나 · 겹치면 보임(틀려도 «더 보이는» 쪽)
     schLabel(k) = 칩 · 캡슐 글: 맨 앞 «포항»은 남는 글이 3자 이상일 때만 뗌(포항대동고 → 대동고 · 포항고 · 포항여고는 그대로) */
  function schMap(classes) {
    var out = {}, i, j, c, studs, s, rid, nn, sk, k;
    if (!isArr(classes)) return out;
    for (i = 0; i < classes.length; i += 1) {
      c = classes[i];
      studs = isObj(c) && isArr(c.students) ? c.students : [];
      for (j = 0; j < studs.length; j += 1) {
        s = studs[j];
        if (!isObj(s)) continue;
        rid = Lec.jtext(s.id);
        if (rid === null || rid === '') continue;
        nn = Lec.norm(Lec.jtext(s.name));
        if (nn === '') continue;
        if (Lec.truthy(s.withdrawn) || Lec.truthy(s.pending)) continue;
        sk = rid + '|' + nn;
        if (!has(out, sk)) out[sk] = [];
        k = schoolKey(stuSchool(s));
        if (k && out[sk].indexOf(k) < 0) out[sk].push(k);
      }
    }
    for (sk in out) { if (has(out, sk)) out[sk].sort(cmpS); }
    return out;
  }
  function schOk(keys, sch) {
    var i;
    if (!isArr(keys) || !keys.length || !isArr(sch) || !sch.length) return true;
    for (i = 0; i < keys.length; i += 1) { if (sch.indexOf(keys[i]) >= 0) return true; }
    return false;
  }
  function schLabel(k) {
    k = str(k);
    return k.indexOf('포항') === 0 && k.length - 2 >= 3 ? k.slice(2) : k;
  }

  /* 앱 _gradeFromClass: 반 이름의 H2 · M3 · E5 · «2학년» */
  function gradeFromClass(cls, school) {
    try {
      var nm = String((cls && cls.name) || '');
      if (!nm) return '';
      var k = schoolKey(school || '');
      var last = (k ? k.charAt(k.length - 1) : '');
      var m = nm.match(/([HME])\s*([1-6])/i);
      if (m) {
        var t = m[1].toUpperCase();
        var g = m[2];
        if (t === 'H' && g > '3') return '';
        if (t === 'M' && g > '3') return '';
        if (last) {
          if (t === 'H' && last !== '고') return '';
          if (t === 'M' && last !== '중') return '';
          if (t === 'E' && last !== '초') return '';
        }
        return g;
      }
      var m2 = nm.match(/([1-6])\s*학년/);
      if (m2) return m2[1];
      return '';
    } catch (e) { return ''; }
  }

  /* 앱 _stuGrade(_stuGradeRaw): 학년 칸(접수 학년) 끝 숫자 → 학교 이름 뒤 숫자 → 반 이름 */
  function stuGrade(stu, cls) {
    try {
      var r = String((stu && (stu.grade || (stu.intake && stu.intake.grade))) || '');
      var out = '', i, ch;
      for (i = r.length - 1; i >= 0; i--) {
        ch = r.charAt(i);
        if (ch >= '0' && ch <= '9') { out = ch + out; } else if (out) break;
      }
      var g0 = out.slice(-1);
      if (g0) return g0;
      try {
        var raw = String(stuSchool(stu) || '');
        var disp = String(schoolDisp(raw) || '');
        var tail = ((disp && raw.indexOf(disp) === 0) ? raw.slice(disp.length) : '');
        for (i = 0; i < tail.length; i++) {
          ch = tail.charAt(i);
          if (ch >= '1' && ch <= '6') return ch;
        }
      } catch (e1) { /* 없음 */ }
      try {
        var g9 = gradeFromClass(cls, stuSchool(stu));
        if (g9) return g9;
      } catch (e2) { /* 없음 */ }
      return '';
    } catch (e) { return ''; }
  }

  /* ------------------------------------------------ 학교 시험 일정 합치기 · 고르기 */

  /* 앱 mergeAppData 의 examSchool · examSchoolG 규칙: 같은 학교 칸은 시각 도장(t) 큰 쪽 · 같으면 나중 것(pt-etc) ·
     둘 다 도장이 없으면 main */
  function pickT(b, o) {
    var bt = ((b && b.t) || 0) * 1, ot = ((o && o.t) || 0) * 1;
    if (bt || ot) return (ot >= bt) ? o : b;
    return b || o;
  }
  function mapMerge(base, over) {
    var out = {}, k;
    for (k in base) { if (has(base, k)) out[k] = base[k]; }
    for (k in over) { if (has(over, k)) out[k] = has(out, k) ? pickT(out[k], over[k]) : over[k]; }
    return out;
  }
  /* 앱 _ptJoin 의 'v' 칸: pt-etc 에 없으면 main 것 · main 에 없으면 pt-etc 것 · 둘 다 있으면 칸마다 합침 */
  function joinV(mv, val) {
    if (val === undefined || val === null) return isObj(mv) ? mv : {};
    if (mv === undefined || mv === null) return isObj(val) ? val : {};
    return mapMerge(isObj(mv) ? mv : {}, isObj(val) ? val : {});
  }
  /* rows = [{id:'main'|'pt-etc', es: data->examSchool, eg: data->examSchoolG}] → {es, eg}
     두 줄을 다 읽었을 때만 합침 · 한 줄이라도 못 읽었으면 null(모름 · 조용히 맞추기를 하지 않음) */
  function examMerge(rows) {
    var m = null, e = null, i;
    if (!isArr(rows)) return null;
    for (i = 0; i < rows.length; i += 1) {
      if (!isObj(rows[i])) continue;
      if (rows[i].id === 'main') m = rows[i];
      else if (rows[i].id === 'pt-etc') e = rows[i];
    }
    if (!m || !e) return null;
    return { es: joinV(m ? m.es : undefined, e ? e.es : undefined), eg: joinV(m ? m.eg : undefined, e ? e.eg : undefined) };
  }

  /* 날짜 글자 → 'YYYY-MM-DD'(아니면 '') */
  function isoOf(v) {
    var d = examNorm(v);
    return d ? d.split('.').join('-') : '';
  }
  function dayNum(iso) {
    var p = str(iso).split('-');
    return Math.round(Date.UTC(+p[0], +p[1] - 1, +p[2]) / DAY);
  }
  function addDays(iso, n) {
    var p = str(iso).split('-'), d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + n));
    return d.getUTCFullYear() + '-' + pad2(d.getUTCMonth() + 1) + '-' + pad2(d.getUTCDate());
  }
  function dayDiff(a, b) { return dayNum(a) - dayNum(b); }

  function recDays(rec) {
    var d = examNorm(rec && rec.date), d2;
    if (!d) return null;
    d2 = examNorm(rec.end) || d;
    if (d2 < d) d2 = d;
    return { d: d, d2: d2 };
  }
  function recOk(rec) { return isObj(rec) && !rec.del && !!examNorm(rec.date); }

  /* 범위 규칙 판 번호 · examName · schoolKey · examPick · examGroups 규칙을 바꾸면 올림
     (서버는 이보다 낮은 판이 보낸 날짜 · 이름 · 받는 학생 바꾸기를 받지 않음 · 옛 화면이 새 규칙 줄을 되돌리지 못하게) */
  var RNG_VER = 1;
  /* 일정 한 줄의 고친 시각(ms · 없으면 0) */
  function tOf(rec) {
    var v = isObj(rec) ? +rec.t : 0;
    return isFinite(v) && v > 0 ? Math.min(Math.floor(v), 999999999999999) : 0;
  }
  /* 학교 · 학년 묶음의 일정 시각 = 학교 일정과 학년 예외 중 늦은 것 */
  function grpT(es, eg, k, g) {
    var a = isObj(es) && has(es, k) ? tOf(es[k]) : 0;
    var b = (g && isObj(eg) && has(eg, k + '|' + g)) ? tOf(eg[k + '|' + g]) : 0;
    return Math.max(a, b);
  }

  /* 학교 key · 학년 g 의 시험 한 줄 → {src:'G'|'S', rec} · 없으면 null
     앱 _examRecFor 와 같음: 학년 예외가 배지에 뜨면(D-20 안 · 대비 시작 · 시험 중) 학년 예외
     → 학교 일정(날짜만 맞으면) → 학년 예외(날짜만 맞으면) */
  function examPick(es, eg, k, g, today) {
    var td = tdDot(today), rg = null, rs = null;
    if (!k || !td) return null;
    es = isObj(es) ? es : {};
    eg = isObj(eg) ? eg : {};
    if (g && has(eg, k + '|' + g)) rg = eg[k + '|' + g];
    if (has(es, k)) rs = es[k];
    if (recOk(rg) && examCalc(rg, td)) return { src: 'G', rec: rg };
    if (recOk(rs)) return { src: 'S', rec: rs };
    if (recOk(rg)) return { src: 'G', rec: rg };
    return null;
  }

  /* 시험 이름 → {name:'2학기 기말', term:'2026-2-기말', kind:'기말', sem:'2', year:2026}
     학년도 = 시험 해(1·2월 시험은 앞 해) · 학기를 안 적었으면 시험 달로(중간 3~6월 · 기말 5~8월 = 1학기)
     꼴을 모르면 name = 적은 이름(20자) · term = 시험 해-달-이름(40자) */
  function semOf(kind, mo) {
    if (kind === '중간') return (mo >= 3 && mo <= 6) ? '1' : '2';
    return (mo >= 5 && mo <= 8) ? '1' : '2';
  }
  function examName(label, date) {
    var d = examNorm(date), lb, s, y, mo, sy, sem = '', kind = '', m;
    if (!d) return null;
    lb = str(label).trim();
    s = Lec.nows(lb);
    y = +d.slice(0, 4);
    mo = +d.slice(5, 7);
    sy = mo <= 2 ? y - 1 : y;
    if ((m = s.match(/([12])학기(중간|기말)/))) { sem = m[1]; kind = m[2]; }
    else if ((m = s.match(/(?:^|[^0-9])[1-3]-([12])(중간|기말)/))) { sem = m[1]; kind = m[2]; }
    else if ((m = s.match(/([12])학기([12])차지필/))) { sem = m[1]; kind = m[2] === '1' ? '중간' : '기말'; }
    else if ((m = s.match(/(?:^|[^0-9])([12])차지필/))) { kind = m[1] === '1' ? '중간' : '기말'; sem = semOf(kind, mo); }
    else if ((m = s.match(/(중간|기말)/))) { kind = m[1]; sem = semOf(kind, mo); }
    if (kind) return { name: sem + '학기 ' + kind, term: sy + '-' + sem + '-' + kind, kind: kind, sem: sem, year: sy };
    return {
      name: Lec.left(lb, 20) || '학교 시험',
      term: Lec.left(y + '-' + pad2(mo) + '-' + (s || '시험'), 40),
      kind: '', sem: '', year: sy
    };
  }

  function addUniq(a, v) { if (v != null && v !== '' && a.indexOf(v) < 0) a.push(v); }
  function meets(a, b) {
    var i;
    if (!isArr(a) || !isArr(b)) return false;
    for (i = 0; i < a.length; i += 1) { if (b.indexOf(a[i]) >= 0) return true; }
    return false;
  }

  /* 반 목록 + 학교 시험 일정 → 학교 · 학년 · 시험마다 한 묶음(끝나지 않은 시험만 · 날짜 차례)
     → {groups:[{k, g, src, name, term, kind, label, exam_on, end_on, show_on, school_nm, disp, rids, cids, t}], unknown:{학교: 학년 모름 수}}
     t = 그 학교 · 학년 일정을 마지막으로 고친 시각(grpT) · disp = 띠 · 칩 · 서랍 머리의 짧은 학교 이름(schoolShort · C2 검수 L1)
     학생 거르기는 서버 명단(lec__roster)과 같음(퇴원 · 반배정 대기 · id 나 이름이 빈 학생 뺌) · 학교를 모르는 학생은 빠짐
     rids = 명단 학생 id · 같은 id 를 이름이 다른 두 학생이 쓰면 그 학생의 학생 열쇠(rid|맞춘 이름) */
  function examGroups(classes, es, eg, today) {
    var td = tdDot(today), out = { groups: [], unknown: {} };
    if (!td || !isArr(classes)) return out;
    var ro = Lec.rosterFrom(classes), cnt = {}, by = {}, order = [], unk = {}, i, j;
    for (i = 0; i < ro.length; i += 1) cnt['#' + ro[i].rid] = (cnt['#' + ro[i].rid] || 0) + 1;
    for (i = 0; i < classes.length; i += 1) {
      var c = classes[i];
      if (!isObj(c) || !isArr(c.students)) continue;
      var cid = Lec.jtext(c.id);
      for (j = 0; j < c.students.length; j += 1) {
        var s = c.students[j];
        if (!isObj(s)) continue;
        var rid = Lec.jtext(s.id);
        if (rid === null || rid === '') continue;
        var nn = Lec.norm(Lec.jtext(s.name));
        if (nn === '' || Lec.truthy(s.withdrawn) || Lec.truthy(s.pending)) continue;
        var raw = stuSchool(s), k = schoolKey(raw);
        if (!k) continue;
        var who = (cnt['#' + rid] || 0) > 1 ? rid + '|' + nn : rid;
        var g = stuGrade(s, c);
        if (!/^[1-6]$/.test(g)) {   /* 앱은 학년 칸 끝 숫자를 그대로 씀('0' · '7' 도) · 범위는 1~6학년만 */
          if (!has(unk, k)) unk[k] = [];
          addUniq(unk[k], rid + '|' + nn);
          continue;
        }
        var pk = examPick(es, eg, k, g, td);
        if (!pk) continue;
        var x = recDays(pk.rec);
        if (x.d2 < td) continue;
        var nm = examName(pk.rec.label, x.d);
        var gk = k + '|' + g + '|' + nm.term;
        if (!has(by, gk)) {
          var exi = x.d.split('.').join('-');
          var snm = typeof pk.rec.name === 'string' && pk.rec.name.trim() ? pk.rec.name.trim() : (schoolDisp(raw) || k);
          by[gk] = {
            k: k, g: g, src: pk.src, name: nm.name, term: nm.term, kind: nm.kind, label: str(pk.rec.label).trim(),
            exam_on: exi, end_on: x.d2.split('.').join('-'), show_on: addDays(exi, -20),
            school_nm: Lec.left(snm, 40), disp: Lec.left(schoolShort(snm) || k, 40), rids: [], cids: [], t: grpT(es, eg, k, g)
          };
          order.push(gk);
        }
        addUniq(by[gk].rids, who);
        addUniq(by[gk].cids, cid);
      }
    }
    for (i = 0; i < order.length; i += 1) {
      out.groups.push(by[order[i]]);
      by[order[i]].rids.sort(cmpS);
      by[order[i]].cids.sort(cmpS);
    }
    out.groups.sort(function (a, b) { return cmpS(a.exam_on, b.exam_on) || cmpS(a.k, b.k) || cmpS(a.g, b.g) || cmpS(a.term, b.term); });
    /* 학년 모름은 시험이 있는 학교만(학교 일정이 끝나지 않았거나 그 학교 묶음이 있을 때) */
    for (var uk in unk) {
      if (!has(unk, uk)) continue;
      var live = false, pk2 = examPick(es, eg, uk, '', td);
      if (pk2 && recDays(pk2.rec).d2 >= td) live = true;
      for (i = 0; i < out.groups.length && !live; i += 1) { if (out.groups[i].k === uk) live = true; }
      if (live) out.unknown[uk] = unk[uk].length;
    }
    return out;
  }

  /* 강의의 수업일(가장 늦은 수업일 · 없으면 올린 날) */
  function lecDay(l) {
    var best = '', a = [l.lesson_on].concat(isArr(l.lesson_more) ? l.lesson_more : []), i;
    for (i = 0; i < a.length; i += 1) {
      if (typeof a[i] === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(a[i]) && a[i] > best) best = a[i];
    }
    if (!best && typeof l.posted_on === 'string') best = l.posted_on.slice(0, 10);
    return best;
  }

  /* 범위 고르기 후보: 그 묶음 반의 강의(전체 강의 포함 · 숨김 · 공개 끝 뺌) · 수업일 늦은 차례
     → [{id, title, book, day, all, near, checked, until, at}]
     near = 수업일이 시험 첫날 70일 전 ~ 시험 끝 날 전(endOn 을 주면) · checked = near 이면서 «모든 반»이 아님(처음부터 체크 · C2 검수 L7)
     until = 공개 끝 날(없으면 null · 서랍의 «MM.DD까지») · at = 올린 시각(created_at · 저장 뒤 올린 강의 고르기 · M1)
     row = 저장한 줄(주면 · M2): 공개 끝이 지난 강의도 줄의 시험 끝 날까지(그날 포함)는 남김 — 줄에 든 강의이거나 저장 뒤 올라온
     처음부터 체크 강의(M1 · 서버 lec__ext_to 와 같은 뜻) · 남긴 것은 ext = true(서버가 학생에게 시험 끝 날까지 보여 주는 강의)
     sk = 묶음의 학교 열쇠(주면 · K1 11-18): 볼 학교를 골라 그 학교가 빠진 강의는 후보에서 뺌(그 학교 학생에게 안 보이는 강의 · 서버 M1 과 같은 뜻) */
  function rngCands(lectures, cids, examOn, today, endOn, row, sk) {
    var td = isoOf(today == null ? Lec.isoDay() : today), ex = isoOf(examOn), en = isoOf(endOn), from = ex ? addDays(ex, -70) : '',
      out = [], i, l, ids, all, day, near, ext, keep = {}, rex = '', ren = '', st = NaN, at;
    if (!isArr(lectures)) return out;
    cids = isArr(cids) ? cids : [];
    if (isObj(row) && isArr(row.lecture_ids)) {
      for (i = 0; i < row.lecture_ids.length; i += 1) keep[row.lecture_ids[i]] = 1;
      rex = isoOf(row.exam_on) || ex;
      ren = isoOf(row.end_on) || en || rex;
      st = Lec.ts(row.saved_at);
    }
    for (i = 0; i < lectures.length; i += 1) {
      l = lectures[i];
      if (!isObj(l) || l.hidden || !l.id) continue;
      ids = isArr(l.class_ids) ? l.class_ids : [];
      all = ids.indexOf('*') >= 0;
      if (!all && !meets(ids, cids)) continue;
      if (sk && !schOk(l.school_keys, [str(sk)])) continue;
      day = lecDay(l);
      near = !!(ex && day && day >= from && (!en || day < en));
      ext = false;
      if (l.until != null && td && td > str(l.until)) {
        at = Lec.ts(l.created_at);
        if (!(ren && td <= ren && (has(keep, l.id) ||
            (!all && rex && day && day >= addDays(rex, -70) && day < ren && isFinite(st) && isFinite(at) && at > st)))) continue;
        ext = true;
      }
      out.push({ id: l.id, title: str(l.title), book: str(l.book), day: day, all: all, near: near, checked: near && !all,
        until: isoOf(l.until) || null, at: l.created_at == null ? null : l.created_at, ext: ext });
    }
    out.sort(function (a, b) {
      var ta = Lec.ts(a.at), tb = Lec.ts(b.at);
      ta = isFinite(ta) ? ta : 0; tb = isFinite(tb) ? tb : 0;
      return cmpS(b.day, a.day) || (tb - ta) || cmpS(a.id, b.id);
    });
    return out;
  }
  /* 서랍이 처음 고른 강의(사람이 켜고 끈 것은 그 위에 얹음 · C2 검수 M1 · L6)
     저장한 줄이 없으면 처음부터 체크(checked) 강의 · 있으면 줄의 강의 + 저장 뒤 올라온 처음부터 체크 강의(created_at > saved_at)
     → {강의 id: true} */
  function rngBase(cands, row) {
    var sel = {}, i, c, st;
    cands = isArr(cands) ? cands : [];
    if (isObj(row) && isArr(row.lecture_ids)) {
      for (i = 0; i < row.lecture_ids.length; i += 1) sel[row.lecture_ids[i]] = true;
      st = Lec.ts(row.saved_at);
      for (i = 0; i < cands.length; i += 1) {
        c = cands[i];
        if (c.checked && isFinite(st) && isFinite(Lec.ts(c.at)) && Lec.ts(c.at) > st) sel[c.id] = true;
      }
      return sel;
    }
    for (i = 0; i < cands.length; i += 1) { if (cands[i].checked) sel[cands[i].id] = true; }
    return sel;
  }

  function rowKey(r) { return str(r.school_key) + '|' + str(r.grade) + '|' + str(r.term); }

  /* 선생님 띠: 범위를 아직 저장하지 않은 묶음 · 시험 30일 전 ~ 시험 끝 날
     rows = lec_range_staff 의 items(배열이 아니면 서버에 함수가 없는 것 → 띠 없음) · mine = 반 id 목록(주면 그 반 학생이 든 묶음만)
     → [{g, n, during, val, text}] · 가까운 시험 먼저(시험 중 = 0 · 같은 날이면 학교 · 학년 차례 · C2 검수 M3) */
  /* 묶음 이름: 짧은 학교 이름 + 학년 + 시험(«바다고 1학년 기말» · 시험 이름을 모르면 «바다고 1학년 시험» · C2 검수 L1 · L5) */
  function rngName(g) {
    if (!isObj(g)) return '';
    var nm = str(g.kind) || (str(g.name) && str(g.name) !== '학교 시험' ? str(g.name) : '시험');
    return str(g.disp || g.school_nm || g.k) + ' ' + str(g.g) + '학년 ' + nm;
  }
  function rngBandText(g) {
    return rngName(g) + ' · 범위 고르기';
  }
  function rngBand(groups, rows, today, mine) {
    var td = isoOf(today == null ? Lec.isoDay() : today), out = [], have = {}, i, g, n, dd;
    if (!isArr(groups) || !isArr(rows) || !td) return out;
    for (i = 0; i < rows.length; i += 1) { if (isObj(rows[i])) have[rowKey(rows[i])] = 1; }
    for (i = 0; i < groups.length; i += 1) {
      g = groups[i];
      if (!isObj(g) || has(have, g.k + '|' + g.g + '|' + g.term)) continue;
      if (td > g.end_on) continue;
      n = dayDiff(g.exam_on, td);
      if (n > 30) continue;
      if (isArr(mine) && !meets(g.cids, mine)) continue;
      dd = ddayOf(g.exam_on, g.end_on, td);
      out.push({ g: g, n: dd ? dd.n : 0, during: !!(dd && dd.during), val: dd ? dd.val : '', text: rngBandText(g) });
    }
    out.sort(function (a, b) {
      return (a.n - b.n) || cmpS(a.g.exam_on, b.g.exam_on) || cmpS(a.g.k, b.g.k) || cmpS(a.g.g, b.g.g) || cmpS(a.g.term, b.g.term);
    });
    return out;
  }

  function anyExam(m) {
    var k;
    if (!isObj(m)) return false;
    for (k in m) { if (has(m, k) && recOk(m[k])) return true; }
    return false;
  }
  function sameSet(a, b) {
    var i;
    a = isArr(a) ? a : []; b = isArr(b) ? b : [];
    for (i = 0; i < a.length; i += 1) { if (b.indexOf(a[i]) < 0) return false; }
    for (i = 0; i < b.length; i += 1) { if (a.indexOf(b[i]) < 0) return false; }
    return true;
  }

  /* 조용히 맞추기: 저장한 범위 줄 중 학교 시험 일정 · 받는 학생이 바뀐 줄만 → lec_range_sync 의 p_rows
     [{id, off:true, t}(끄기) | {id, exam, end, name, rids?, t}(고치기 · 다시 켜기)] · t = 그 학교 · 학년 일정의 고친 시각(grpT)
     es · eg = examMerge 결과(main · pt-etc 두 줄을 다 읽은 것)만 넘길 것 · 하나라도 객체가 아니면 아무것도 보내지 않음
     건드리지 않는 줄: 끝난 줄 · 더 새 규칙 판(rule_ver > RNG_VER)이 맞춘 줄 · 그 학교 · 학년 일정이 이 화면에 아예 없는 줄(모름) ·
       이 화면이 본 일정이 줄이 따른 일정보다 옛것인 줄(grpT < src_t) · 날짜를 잘못 적은 채 지우지 않은 일정
     끄는 줄: 일정이 지움 표식(del)만 남은 묶음 · 같은 학교 · 학년이 다른 시험으로 바뀐 묶음
     받는 학생이 없는 묶음(그 학교 · 학년 학생이 다 빠짐 · 시험이 이미 끝남)은 날짜 · 이름만 맞춤(받는 학생은 그대로) */
  function rngSyncRows(rows, classes, es, eg, today) {
    var td = isoOf(today == null ? Lec.isoDay() : today), out = [], by = {}, gs, i, r, g, k, gr, rs, rg, t, pk, x, nm, exi, eni;
    if (!isArr(rows) || !rows.length || !td) return out;
    if (!isObj(es) || !isObj(eg)) return out;
    if (!isArr(classes) || !classes.length) return out;
    if (!anyExam(es) && !anyExam(eg)) return out;
    gs = examGroups(classes, es, eg, td).groups;
    for (i = 0; i < gs.length; i += 1) by[gs[i].k + '|' + gs[i].g + '|' + gs[i].term] = gs[i];
    for (i = 0; i < rows.length; i += 1) {
      r = rows[i];
      if (!isObj(r) || !r.id || str(r.end_on) < td) continue;
      if ((+r.rule_ver || 1) > RNG_VER) continue;
      k = str(r.school_key);
      gr = str(r.grade);
      rs = has(es, k) ? es[k] : null;
      rg = (gr && has(eg, k + '|' + gr)) ? eg[k + '|' + gr] : null;
      if (!isObj(rs) && !isObj(rg)) continue;
      t = grpT(es, eg, k, gr);
      if (t < (+r.src_t || 0)) continue;
      g = has(by, rowKey(r)) ? by[rowKey(r)] : null;
      if (g) {
        if (r.off || str(r.exam_on) !== g.exam_on || str(r.end_on) !== g.end_on || str(r.name) !== g.name || !sameSet(r.rids, g.rids)) {
          out.push({ id: r.id, exam: g.exam_on, end: g.end_on, name: g.name, rids: g.rids.slice(), t: t });
        }
        continue;
      }
      if (r.off) continue;
      pk = examPick(es, eg, k, gr, td);
      if (!pk) {
        if ((!isObj(rs) || rs.del) && (!isObj(rg) || rg.del)) out.push({ id: r.id, off: true, t: t });
        continue;
      }
      x = recDays(pk.rec);
      nm = examName(pk.rec.label, x.d);
      if (nm.term !== str(r.term)) {
        out.push({ id: r.id, off: true, t: t });
        continue;
      }
      exi = x.d.split('.').join('-');
      eni = x.d2.split('.').join('-');
      if (str(r.exam_on) !== exi || str(r.end_on) !== eni || str(r.name) !== nm.name) {
        out.push({ id: r.id, exam: exi, end: eni, name: nm.name, t: t });
      }
    }
    return out;
  }

  /* ------------------------------------------------ 학생 카드 */

  /* 시험까지 → {n, during, val:'D-9'|'시험 중'} · 끝났으면 null(앱 _examCalc 처럼 시험 첫날부터 «시험 중») */
  function ddayOf(examOn, endOn, today) {
    var ex = isoOf(examOn), en = isoOf(endOn) || ex, td = isoOf(today == null ? Lec.isoDay() : today), n;
    if (!ex || !td) return null;
    if (en < ex) en = ex;
    if (td > en) return null;
    if (td >= ex) return { n: 0, during: true, val: '시험 중' };
    n = dayDiff(ex, td);
    return { n: n, during: false, val: n === 0 ? 'D-DAY' : 'D-' + n };
  }

  /* 학생 카드에 띄울 한 시험: 시험 중이 먼저 · 다음은 가까운 시험 */
  function rngPickItem(items, today) {
    var best = null, bd = null, i, it, dd;
    if (!isArr(items)) return null;
    for (i = 0; i < items.length; i += 1) {
      it = items[i];
      if (!isObj(it) || !isArr(it.lectures) || !it.lectures.length) continue;
      dd = ddayOf(it.exam_on, it.end_on, today);
      if (!dd) continue;
      if (!best || (dd.during && !bd.during) || (dd.during === bd.during && (dd.n < bd.n ||
          (dd.n === bd.n && (cmpS(it.exam_on, best.exam_on) || cmpS(it.name, best.name) || cmpS(it.id, best.id)) < 0)))) {
        best = it; bd = dd;
      }
    }
    return best;
  }

  /* 카드 글: title «2학기 기말 D-9 · 11.25(수)» · sub «범위 영상 4편 중 2편 학습완료»(기록 동의 안 했으면 «범위 영상 4편»)
     시험 이름을 모르면(«학교 시험» · 빈 이름) 이름 없이 «D-9 · 11.25(수)» · «시험 중 · 11.28(토)까지»(C2 검수 L5) */
  function rngCard(item, today, agreed) {
    if (!isObj(item) || !isArr(item.lectures)) return null;
    var dd = ddayOf(item.exam_on, item.end_on, today), td = isoOf(today == null ? Lec.isoDay() : today);
    if (!dd) return null;
    var nm = str(item.name).trim(), total = item.lectures.length, done = Math.max(0, Math.min(total, Math.floor(+item.done || 0)));
    var en = isoOf(item.end_on), pre = (nm && nm !== '학교 시험') ? nm + ' ' : '';
    var title = dd.during
      ? pre + '시험 중' + (en && en > td ? ' · ' + Lec.fmtDay(en) + '까지' : '')
      : pre + dd.val + ' · ' + Lec.fmtDay(isoOf(item.exam_on));
    var sub = agreed ? '범위 영상 ' + total + '편 중 ' + done + '편 학습완료' : '범위 영상 ' + total + '편';
    return { title: title, sub: sub, n: dd.n, during: dd.during, val: dd.val, total: total, done: done };
  }

  /* ------------------------------------------------ 서버 부르기(실패해도 거절하지 않음) */

  /* 서버에 함수(또는 표)가 아직 없음: 404 · PGRST202(함수 없음) · PGRST205(표 없음) · 42883 · 42P01 */
  function rngGoneErr(e) {
    return !!e && (e.status === 404 || e.code === 'PGRST202' || e.code === 'PGRST205' || e.code === '42883' || e.code === '42P01');
  }

  /* 학생: 내 시험 범위 {ok, today, items} · 실패 · 열쇠 틀림 · 옛 서버는 null(옛 서버면 이 화면에서는 다시 묻지 않음) */
  var rngGone = false;
  function rngMe(key) {
    var p;
    if (rngGone) return Promise.resolve(null);
    try {
      p = Lec.rpc('lec_range_me', { p_key: key == null ? null : str(key) });
    } catch (e0) { return Promise.resolve(null); }
    return Promise.resolve(p).then(function (r) {
      return r && r.ok && isArr(r.items) ? r : null;
    }, function (e) {
      if (rngGoneErr(e)) rngGone = true;
      return null;
    }).then(null, function () { return null; });
  }

  /* 선생님: call(fn, args) = 선생님 화면의 서버 부르기(Promise) · 늘 {ok, ...} 로 돌려줌
     실패 = {ok:false, err:'old'(서버에 함수 없음) | 'network' | 'error' | 'forbidden' | 'input'} */
  function staffCall(call, fn, args) {
    var p;
    if (typeof call !== 'function') return Promise.resolve({ ok: false, err: 'network' });
    try { p = call(fn, args); } catch (e0) { return Promise.resolve(rngGoneErr(e0) ? { ok: false, err: 'old' } : { ok: false, err: 'error' }); }
    return Promise.resolve(p).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, function (e) {
      if (rngGoneErr(e)) return { ok: false, err: 'old' };
      return { ok: false, err: e && e.message === 'network' ? 'network' : 'error' };
    }).then(null, function () { return { ok: false, err: 'error' }; });
  }
  /* 저장된 범위 줄 모두 → {ok, today, items} */
  function rngStaff(call) {
    return staffCall(call, 'lec_range_staff', {}).then(function (r) {
      return r.ok && !isArr(r.items) ? { ok: false, err: 'error' } : r;
    }).then(null, function () { return { ok: false, err: 'error' }; });
  }
  /* 범위 저장: g = examGroups 의 묶음 · lectures = 고른 강의 id 들 → {ok, id, item, stale}
     p_ver · p_t = 이 화면의 규칙 판 · 본 일정의 고친 시각 → 줄이 더 새 일정을 따르고 있으면(stale) 서버가 날짜 · 이름은 그대로 둠
     seen = rngSeen(화면이 들고 있는 강의 목록) → p_seen(없으면 0) */
  function rngSave(call, g, lectures, seen) {
    if (!isObj(g)) return Promise.resolve({ ok: false, err: 'input' });
    seen = +seen;
    return staffCall(call, 'lec_range_save', {
      p_school: str(g.k), p_grade: str(g.g), p_term: str(g.term), p_name: str(g.name),
      p_exam: isoOf(g.exam_on) || null, p_end: isoOf(g.end_on) || null,
      p_rids: isArr(g.rids) ? g.rids.slice() : [], p_lectures: isArr(lectures) ? lectures.slice() : [],
      p_school_nm: str(g.school_nm), p_ver: RNG_VER, p_t: tOf(g),
      p_seen: isFinite(seen) && seen > 0 ? Math.min(Math.floor(seen), 999999999999999) : 0
    });
  }
  /* 화면이 들고 있는 강의 목록에서 가장 늦은 만든 시각(ms · 없으면 0 · 마지막 검수 L-2)
     → rngSave 의 seen: 서버는 그 뒤에 만든 강의만 «화면이 본 적 없는 강의»로 보고 줄에 남김(체크하지 않아도 학생에게 그대로) */
  function rngSeen(lectures) {
    var best = 0, i, t;
    if (!isArr(lectures)) return 0;
    for (i = 0; i < lectures.length; i += 1) {
      if (!isObj(lectures[i]) || lectures[i].created_at == null) continue;
      t = Lec.ts(lectures[i].created_at);
      if (isFinite(t) && t > best) best = t;
    }
    return Math.floor(best);
  }
  /* 조용히 맞추기: rows = rngSyncRows 결과 · 빈 목록이면 부르지 않음 → {ok, n}
     보내기에 성공한 내용만 «보냄»으로 적고 10분 안에는 다시 보내지 않음(서버와 끝내 안 맞는 줄이 있어도 새로 고칠 때마다 쓰지 않게) ·
     실패하면 적지 않아 다음에 다시 보냄 · 같은 내용을 보내는 중이면 겹쳐 보내지 않음 */
  var syncSent = {}, syncBusy = {};
  function rngSync(call, rows) {
    var sig, t = Lec.now(), k;
    if (!isArr(rows) || !rows.length) return Promise.resolve({ ok: true, n: 0, skip: true });
    rows = rows.slice(0, 500);
    try { sig = JSON.stringify(rows); } catch (e0) { return Promise.resolve({ ok: false, err: 'input' }); }
    for (k in syncSent) { if (has(syncSent, k) && t - syncSent[k] > 600000) delete syncSent[k]; }
    if (has(syncSent, sig) || has(syncBusy, sig)) return Promise.resolve({ ok: true, n: 0, skip: true });
    syncBusy[sig] = 1;
    return staffCall(call, 'lec_range_sync', { p_rows: rows, p_ver: RNG_VER }).then(function (r) {
      delete syncBusy[sig];
      if (r && r.ok) syncSent[sig] = Lec.now();
      return r;
    });
  }
  /* 시험용: 옛 서버 표시 · 보낸 기록 지우기 */
  function rngReset() { rngGone = false; syncSent = {}; syncBusy = {}; }

  var api = {
    examNorm: examNorm, examCalc: examCalc, schoolKey: schoolKey, schoolDisp: schoolDisp, schoolShort: schoolShort, stuSchool: stuSchool,
    schMap: schMap, schOk: schOk, schLabel: schLabel,
    gradeFromClass: gradeFromClass, stuGrade: stuGrade,
    RNG_VER: RNG_VER, grpT: grpT,
    examMerge: examMerge, examPick: examPick, examName: examName, examGroups: examGroups, isoOf: isoOf, addDays: addDays,
    rngCands: rngCands, rngBase: rngBase, rngName: rngName, rngBand: rngBand, rngBandText: rngBandText, rngSyncRows: rngSyncRows,
    ddayOf: ddayOf, rngPickItem: rngPickItem, rngCard: rngCard,
    rngGoneErr: rngGoneErr, rngMe: rngMe, rngStaff: rngStaff, rngSave: rngSave, rngSeen: rngSeen, rngSync: rngSync, rngReset: rngReset
  };
  for (var name in api) { if (has(api, name)) Lec[name] = api[name]; }
})(window);

/* ======================================================= N1 (11-17) 새 영상 알림(CLAUDE.md §8-205)
   - 학생(홈 화면 앱에서만 부름): pushOn(key) = {ok, on, show, key(알림 공개 열쇠), ep(이 열쇠에 저장된 푸시 주소), at('8시')}
     서버에 없거나(옛 SQL) 실패하면 null = 카드 · 첫 로그인 단계 안 보임 · pushSave(key, sub) · pushOff(key) 는 실패해도 값으로
   - 선생님: pushState(call, id) = lec_push_state 답(줄이 없거나 실패 · 옛 서버 = null) ·
     pushLine(r, names) = 올린 뒤 카드 한 줄 {cls, b, t, m} · pushEditLine(r) = 고치기 서랍 숨김 칩 아래 한 줄(글)
     시각 글은 서버가 준 값(due_day · due_hm · sent_day · sent_hm)만 씀(화면 시계 안 씀)
   - 글: 학생 카드 = pushCardText(at) · 켠 순간 한 번 = PUSH_ON_TOAST */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec) return;

  function str(v) { return v == null ? '' : String(v); }
  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function isObj(v) { return !!v && typeof v === 'object' && !isArr(v); }
  /* 서버에 함수가 아직 없거나 막힘: 404 · 401 · 403 · PGRST202 · 42883 → 이 화면에서는 다시 묻지 않음 */
  function gone(e) {
    return !!e && (e.status === 404 || e.status === 401 || e.status === 403 || e.code === 'PGRST202' || e.code === '42883');
  }
  function b64u(buf) {
    var b = new Uint8Array(buf), s = '', i;
    for (i = 0; i < b.length; i += 1) s += String.fromCharCode(b[i]);
    return w.btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function unb64u(s) {
    var t = str(s).replace(/-/g, '+').replace(/_/g, '/'), bin, o, i;
    while (t.length % 4) t += '=';
    bin = w.atob(t);
    o = new Uint8Array(bin.length);
    for (i = 0; i < bin.length; i += 1) o[i] = bin.charCodeAt(i);
    return o;
  }
  function call(fn, args) {
    var p;
    try { p = Lec.rpc(fn, args); } catch (e0) { return Promise.reject(e0); }
    return Promise.resolve(p);
  }

  var onGone = false;
  function pushOn(key) {
    if (w.__lecPvIn) return Promise.resolve(null); /* 미리 보기 안쪽 = 부르지 않음 */
    if (onGone || !key) return Promise.resolve(null);
    return call('lec_push_on', { p_key: str(key) }).then(function (r) {
      return isObj(r) && r.ok === true ? r : null;
    }, function (e) {
      if (gone(e)) onGone = true;
      return null;
    }).then(null, function () { return null; });
  }
  function pushSave(key, sub) {
    if (w.__lecPvIn) return Promise.resolve({ ok: false, err: 'preview' });
    var ep, p, a;
    try {
      ep = str(sub.endpoint);
      p = b64u(sub.getKey('p256dh'));
      a = b64u(sub.getKey('auth'));
    } catch (e0) { return Promise.resolve({ ok: false, err: 'sub' }); }
    return call('lec_push_save', { p_key: str(key), p_ep: ep, p_p256dh: p, p_auth: a }).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, function () { return { ok: false, err: 'network' }; });
  }
  function pushOff(key) {
    if (w.__lecPvIn) return Promise.resolve({ ok: false, err: 'preview' });
    if (!key) return Promise.resolve({ ok: false, err: 'key' });
    return call('lec_push_off', { p_key: str(key) }).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, function () { return { ok: false, err: 'network' }; });
  }

  var stGone = false;
  function pushState(dcall, id) {
    var p;
    if (stGone || typeof dcall !== 'function' || !id) return Promise.resolve(null);
    try { p = dcall('lec_push_state', { p_lecture: str(id) }); } catch (e0) { return Promise.resolve(null); }
    return Promise.resolve(p).then(function (r) {
      return isObj(r) && r.ok === true && r.show === true ? r : null;
    }, function (e) {
      if (gone(e)) stGone = true;
      return null;
    }).then(null, function () { return null; });
  }
  /* 올린 뒤 카드 한 줄 · names(ids) = 반 이름(«·» 로 이은 글) · 보일 줄이 없으면 null
     바로 «1분 안에 {반} 학생 폰으로 알림이 가요.» + «알림을 켠 학생 N명» ·
     아침 «오늘 아침 8:00에 …» / 앞날 «11.20(금) 아침 8:00에 …» + «… · 그 전에 숨기거나 지우면 안 가요.» ·
     숨김 «숨김 강의라 알림이 가지 않아요. 숨김을 풀면 그때 한 번 가요.»(again 거짓 = «숨김을 풀어도 알림은 가지 않아요.») · 0명 «알림을 켠 학생이 아직 없어요. 반 공지는 지금처럼 붙여 주세요.» ·
     시험 중(관리자만 줄이 옴) = 회색 «시험 중 · 알림을 켠 시험 학생 N명» */
  function pushLine(r, names) {
    var who, n, test, m;
    if (!isObj(r) || r.show !== true) return null;
    test = r.mode === 'test';
    if (r.hidden === true || r.status === 'hold') {
      /* 풀면 가는지는 서버의 again(pushEditLine 과 같음 · 공개일 4일 넘음 · 끝난 강의 · 남은 반 없음 = 거짓) */
      return { cls: 'off', b: '숨김 강의라 알림이 가지 않아요.', t: '', m: r.again === true ? '숨김을 풀면 그때 한 번 가요.' : '숨김을 풀어도 알림은 가지 않아요.' };
    }
    if (r.status !== 'wait') return null;
    n = Math.max(0, Math.floor(+r.n || 0));
    if (!test && n === 0) return { cls: 'off', b: '', t: '알림을 켠 학생이 아직 없어요. 반 공지는 지금처럼 붙여 주세요.', m: '' };
    who = typeof names === 'function' ? str(names(isArr(r.cls) ? r.cls : [])) : '';
    who = (who ? who + ' ' : '') + '학생 폰으로 알림이 가요.';
    m = (test ? '시험 중 · 알림을 켠 시험 학생 ' : '알림을 켠 학생 ') + n + '명';
    if (r.when === 'now' || !r.due_hm) return { cls: '', b: '1분 안에', t: ' ' + who, m: m };
    return { cls: '', b: (r.when === 'today' ? '오늘' : str(r.due_day)) + ' 아침 ' + str(r.due_hm), t: '에 ' + who, m: m + ' · 그 전에 숨기거나 지우면 안 가요.' };
  }
  /* 고치기 서랍 숨김 칩 아래 한 줄: 보냄 · 아침 대기 · 숨김(풀면 감 / 안 감) · 그 밖은 '' */
  function pushEditLine(r) {
    var pre;
    if (!isObj(r) || r.show !== true) return '';
    pre = r.mode === 'test' ? '시험 중 · ' : '';
    if (r.hidden === true) return pre + (r.again === true ? '숨김을 풀면 그때 한 번 알림이 가요' : '숨김을 풀어도 알림은 가지 않아요');
    if (r.status === 'wait') {
      return pre + (r.when === 'now' || !r.due_hm ? '알림이 1분 안에 가요'
        : '알림 ' + str(r.due_day) + ' 아침 ' + str(r.due_hm) + '에 가요 · 그 전에 숨기거나 지우면 안 가요');
    }
    if (r.sent_day && r.sent_hm) return pre + '알림 ' + str(r.sent_day) + ' ' + str(r.sent_hm) + '에 보냄 · 고쳐 저장해도 다시 안 가요';
    return '';
  }
  /* 학생 카드 · 첫 로그인 단계 글(at = 서버가 준 «8시» · 없으면 «아침 8시») */
  function pushCardText(at) {
    var a = str(at);
    if (!/^\d{1,2}시( \d{1,2}분)?$/.test(a)) a = '8시';
    return '수업 영상이 올라오면 이 폰으로 바로 알려 드려요. 새벽에 올라오면 아침 ' + a + '에 알려 드려요.';
  }

  Lec.LS.seen = 'lec-seen';
  Lec.LS.alstep = 'lec-alstep';   /* 첫 로그인 «새 영상 알림» 단계를 이 기기에서 띄웠음(기기당 한 번 · 나가기에도 안 지움) */
  var api = {
    pushOn: pushOn, pushSave: pushSave, pushOff: pushOff, pushState: pushState, pushLine: pushLine, pushEditLine: pushEditLine,
    pushCardText: pushCardText, b64u: b64u, unb64u: unb64u,
    PUSH_TITLE: '새 수업 영상 알림', PUSH_ON_TOAST: '새 영상이 올라오면 알려 드릴게요.'
  };
  for (var name in api) { if (Object.prototype.hasOwnProperty.call(api, name)) Lec[name] = api[name]; }
})(window);

/* ======================================================= S1 (11-17) 단어 · 구문 · 문법
   - 학생(첫 인자 key · 모두 Promise · throw 없음): setHome(key) = 공부 묶음 목록(서버에 함수가 없거나 실패 = null ·
     함수가 없으면 이 화면에서 다시 안 부름) · setItems · setCard · setTest · setDue · setAns ·
     recBegin · recDone · recPut · recSend(실패 = {ok:false, err})
   - 선생님(관리자 · 첫 인자 call = 화면의 서버 부르기): setListStaff · setGet · setPut · setHide · setDel · setStaff ·
     setWrongStaff(종이 «쌓인 오답 시험» · 11-18) · recMark · recClean
   - S1-b(11-17 원장님 «동의서 필요없어»): 세트 동의 · 녹음 동의 · 학교급 갈래 없음(setAgree · recAgree · recOff · recGuard · recLvl ·
     SET_NOTE · REC_NOTE · stuLevel · levelsFrom 뺌) · 히즈클래스 기록 동의(lec_consent)는 그대로
   - 판정(class-setup.sql S1 절과 같은 셈 · 같은 값 표 _check/class_set_vectors.json): setNorm · setMatch · setNeed · setMark …
   - 미리 보기 안쪽(w.__lecPvIn) = 학생 함수는 서버도 가짜 서버도 부르지 않음(setHome null · 나머지 {ok:false, err:'preview'}) */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec) return;

  var SET_LIM = { voc: 300, gu: 30, gram: 50 };
  var REC_MAX_BYTES = 1048576, REC_MAX_MS = 45000;
  var REC_TYPES = ['audio/webm', 'audio/mp4', 'audio/ogg'];
  var REC_PATH = /^[0-9a-f-]{36}\/[0-9a-f]{32}\.(webm|m4a|ogg)$/;
  var REC_WHY = ['', '끊어 읽기', '강세 · 억양', '빠진 말 · 틀린 말', '소리'];
  /* 붙여 넣은 글을 알아본 까닭(위젯 글 그대로) · forced = 선생님이 종류를 고름 */
  var SET_RS = {
    voc: '한 줄이 한두 낱말이라 어휘로 읽었어요',
    gu: '한 줄이 문장이라 주요구문으로 읽었어요',
    gram: '괄호 안에 / 보기나 [ ]가 있어 문법으로 읽었어요',
    forced: '선생님이 고른 종류로 읽어요'
  };
  /* 학생 오류 → 학생 화면 한 줄(계약서 §4-13 · 녹음 limit 은 화면이 따로 «오늘은 녹음을 더 보낼 수 없어요.») */
  var SET_ERR = {
    testing: '시험을 마치면 외우기를 볼 수 있어요.',
    limit: '오늘은 여기까지예요. 내일 다시 해요.',
    rec_limit: '오늘은 녹음을 더 보낼 수 없어요.',
    tomorrow: '내일 다시 볼 수 있어요.',
    pass: '이미 통과했어요.',
    none: '지금은 열 수 없어요.',
    kind: '지금은 열 수 없어요.',
    'try': '지금은 열 수 없어요.',
    done: '지금은 열 수 없어요.',
    size: '45초 안으로 다시 녹음해 주세요.',
    mime: '이 폰에서는 녹음을 보낼 수 없어요.',
    upload: '보내지 못했어요.',
    file: '보내지 못했어요.',
    late: '보내지 못했어요.',
    network: '보내지 못했어요.',
    other: '잠시 뒤 다시 해 주세요.'
  };

  function str(v) { return v == null ? '' : String(v); }
  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function isObj(v) { return !!v && typeof v === 'object' && !isArr(v); }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function sp(s) { return str(s).replace(/^ +| +$/g, ''); }          /* 서버 btrim(보통 칸만) */
  function clen(s) { return Lec.clen ? Lec.clen(str(s)) : str(s).length; }
  function copy(o) { var r = {}, k; for (k in o) { if (has(o, k)) r[k] = o[k]; } return r; }
  function rndOf(r) { return typeof r === 'function' ? r : Math.random; }
  function shuffle(a, rnd) {
    var i, j, t;
    rnd = rndOf(rnd);
    for (i = a.length - 1; i > 0; i -= 1) {
      j = Math.floor(rnd() * (i + 1));
      if (!(j >= 0 && j <= i)) j = i;
      t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }

  /* ------------------------------------------------------------- 판정(서버와 같은 셈) */

  function nfc(t) {
    var s = str(t);
    try { return s.normalize ? s.normalize('NFC') : s; } catch (e) { return s; }
  }
  /* 둥근 따옴표 · 프라임 → ' " · 붙는 빈칸(NBSP · 전각) → 빈칸 · 물결 셋 지움(SQL translate 와 같은 목록) */
  var NQ = {};
  NQ[String.fromCharCode(8217)] = "'"; NQ[String.fromCharCode(8216)] = "'"; NQ[String.fromCharCode(700)] = "'";
  NQ[String.fromCharCode(8242)] = "'"; NQ[String.fromCharCode(8220)] = '"'; NQ[String.fromCharCode(8221)] = '"';
  NQ[String.fromCharCode(8243)] = '"'; NQ[String.fromCharCode(160)] = ' '; NQ[String.fromCharCode(12288)] = ' ';
  NQ['~'] = ''; NQ[String.fromCharCode(8764)] = ''; NQ[String.fromCharCode(12316)] = '';
  /* 쓰기 답 맞추기 글: NFC → 따옴표 · 빈칸 · 물결 → A~Z 만 소문자 → 빈칸 무리(여섯 글자) 하나로 → 앞뒤 빈칸 → 끝 마침표 → 앞뒤 빈칸 */
  function setNorm(t) {
    var s = nfc(t), o = '', i, c, n;
    for (i = 0; i < s.length; i += 1) {
      c = s.charAt(i);
      if (has(NQ, c)) { o += NQ[c]; continue; }
      n = s.charCodeAt(i);
      o += n >= 65 && n <= 90 ? String.fromCharCode(n + 32) : c;
    }
    o = o.replace(/[ \t\n\u000B\f\r]+/g, ' ').replace(/^ +| +$/g, '');
    return o.replace(/\.+$/, '').replace(/^ +| +$/g, '');
  }
  /* 한 답의 꼴: 괄호와 그 안을 뺀 것 · 괄호 글자만 뺀 것(빈 것 뺌) */
  function setVars(t) {
    var s = str(t), a = setNorm(s.replace(/[(][^()]*[)]/g, ' ')), b = setNorm(s.replace(/[()]/g, '')), o = [];
    if (a !== '') o.push(a);
    if (b !== '' && b !== a) o.push(b);
    return o;
  }
  /* 정답 글의 모든 꼴(«/» 로 나눈 조각마다) */
  function setAlts(ans) {
    var parts = str(ans).split('/'), o = [], i, v, j;
    for (i = 0; i < parts.length; i += 1) {
      v = setVars(parts[i]);
      for (j = 0; j < v.length; j += 1) { if (o.indexOf(v[j]) < 0) o.push(v[j]); }
    }
    return o;
  }
  /* 학생 답(나누지 않음)의 꼴 하나가 정답 꼴 하나와 같으면 맞음 */
  function setMatch(v, ans) {
    var a = setVars(v), b = setAlts(ans), i;
    for (i = 0; i < a.length; i += 1) { if (b.indexOf(a[i]) >= 0) return true; }
    return false;
  }
  /* 통과 수 = 90% 올림(정수 셈) */
  function setNeed(n) {
    n = Math.floor(+n || 0);
    return n <= 0 ? 0 : Math.floor((n * 9 + 9) / 10);
  }
  /* 문법 고르기 보기: 첫 ( a / b ) 묶음을 «/» 로 나눔 · 없으면 null */
  function setOpts(s) {
    var m = /[(]([^()]*\/[^()]*)[)]/.exec(str(s)), o, i;
    if (!m) return null;
    o = m[1].split('/');
    for (i = 0; i < o.length; i += 1) o[i] = sp(o[i]);
    return o;
  }
  /* 화면 칸 그리기: 고르기 = ( / ) 묶음 자리(o 보기) · 고쳐 쓰기 = [낱말] 자리(mid) · 둘 다 없으면 f '' */
  function gramParts(s) {
    var t = str(s), m = /[(]([^()]*\/[^()]*)[)]/.exec(t), b;
    if (m) return { f: 'c', pre: t.slice(0, m.index), mid: m[1], post: t.slice(m.index + m[0].length), o: setOpts(t) };
    b = /\[([^\]]*)\]/.exec(t);
    if (b) return { f: 'r', pre: t.slice(0, b.index), mid: sp(b[1]), post: t.slice(b.index + b[0].length), o: null };
    return { f: '', pre: t, mid: '', post: '', o: null };
  }
  function countRe(re, s) {
    var n = 0, m;
    re.lastIndex = 0;
    while ((m = re.exec(s)) !== null) { n += 1; if (m[0] === '') re.lastIndex += 1; }
    return n;
  }

  /* 쓰기 답 · 고르기 문항의 꼴: 세트 안 문항 차례 i(0부터) 짝수 = 'c'(뜻 고르기) · 홀수 = 'w'(영어 쓰기) */
  function setFm(i) { return (Math.floor(+i || 0) % 2 === 0) ? 'c' : 'w'; }
  /* 첫 시도: 모든 문항 · 꼴 fm(i) · 섞음 */
  function setFirst(items, rnd) {
    var o = [], i;
    items = isArr(items) ? items : [];
    for (i = 0; i < items.length; i += 1) o.push({ k: str(items[i] && items[i].k), f: setFm(i) });
    return shuffle(o, rnd);
  }
  /* 다시 보기: 틀린 것(kn 에 없는 것) 전부 'w' + 맞힌 것 가운데 무작위 min(틀린 수, 맞힌 수)개(꼴 fm(i)) · 섞음 */
  function setRetake(items, kn, rnd) {
    var ks = {}, wr = [], kk = [], i, k;
    items = isArr(items) ? items : [];
    kn = isArr(kn) ? kn : [];
    for (i = 0; i < kn.length; i += 1) ks['#' + str(kn[i])] = 1;
    for (i = 0; i < items.length; i += 1) {
      k = str(items[i] && items[i].k);
      if (ks['#' + k]) kk.push({ k: k, f: setFm(i) }); else wr.push({ k: k, f: 'w' });
    }
    shuffle(kk, rnd);
    return shuffle(wr.concat(kk.slice(0, Math.min(wr.length, kk.length))), rnd);
  }
  /* 시험 문항 수(test_n · 11-18): 1 ~ 문항 수-1 일 때만 그 수 · 비었거나 문항 수 이상이면 null(= 전부 · 예전 그대로) · 서버 lec__set_tq 와 같은 셈 */
  function setTq(n, tn) {
    var t = (tn == null || tn === '') ? NaN : +tn;
    n = Math.floor(+n || 0);
    if (!(t >= 1 && t <= n - 1) || Math.floor(t) !== t) return null;
    return t;
  }
  /* 시험 문항 수만큼 새로 뽑기: 전체에서 무작위 tn 개 · 뽑은 차례 i 의 꼴 fm(i)(고르기 · 쓰기 번갈아) · 다시 볼 때도 새로(다시 보기 규칙 안 씀) */
  function setDraw(items, tn, rnd) {
    var ks = [], o = [], i;
    items = isArr(items) ? items : [];
    for (i = 0; i < items.length; i += 1) ks.push(str(items[i] && items[i].k));
    shuffle(ks, rnd);
    ks = ks.slice(0, Math.max(0, Math.min(ks.length, Math.floor(+tn || 0))));
    for (i = 0; i < ks.length; i += 1) o.push({ k: ks[i], f: setFm(i) });
    return o;
  }
  /* 'c' 보기 넷: 맞는 뜻 + 맞춤 글이 서로 다르고 맞는 뜻과도 다른 뜻 셋(무작위) · 섞음 · 셋이 안 되면 null */
  function setChoices(items, idx, rnd) {
    var it, me, groups = {}, keys = [], i, g, out;
    items = isArr(items) ? items : [];
    it = items[idx];
    if (!isObj(it)) return null;
    me = setNorm(it.m);
    for (i = 0; i < items.length; i += 1) {
      if (!isObj(items[i])) continue;
      g = setNorm(items[i].m);
      if (g === me) continue;
      if (!has(groups, '#' + g)) { groups['#' + g] = []; keys.push('#' + g); }
      groups['#' + g].push(str(items[i].m));
    }
    if (keys.length < 3) return null;
    shuffle(keys, rnd);
    out = [str(it.m)];
    for (i = 0; i < 3; i += 1) {
      g = groups[keys[i]];
      out.push(g[Math.min(g.length - 1, Math.floor(rndOf(rnd)() * g.length))]);
    }
    return shuffle(out, rnd);
  }

  /* 카드 날짜 칸: 날을 더하고 겹침 빼고 오름차순 · 마지막 n 개 */
  function addDay(arr, day, n) {
    var a = isArr(arr) ? arr : [], o = [], i, v;
    for (i = 0; i < a.length; i += 1) { v = str(a[i]); if (o.indexOf(v) < 0) o.push(v); }
    if (o.indexOf(day) < 0) o.push(day);
    o.sort();
    return o.slice(Math.max(0, o.length - n));
  }
  /* 카드 한 칸 고치기(새 객체): card = 외우기 · say = 따라 말하기 · test · drill · due = 시험 · 드릴 · 쌓인 오답 */
  function setMark(card, ok, src, day) {
    var c = copy(isObj(card) ? card : {}), y;
    day = str(day);
    if (src === 'card' || src === 'say') {
      c.s = 1;
      if (ok && src === 'say') c.g = 1;
      else if (ok) c.d = addDay(c.d, day, 3);
      return c;
    }
    if (!ok) {
      delete c.d; delete c.t; delete c.y;
      c.w = (typeof c.w === 'number' && isFinite(c.w) ? Math.floor(c.w) : 0) + 1;
      c.z = day;
      return c;
    }
    c.d = addDay(c.d, day, 3);
    if (src !== 'due') c.t = day;
    if (str(c.z) !== '' && day > str(c.z)) {
      y = addDay(c.y, day, 2);
      if (y.length >= 2) { delete c.z; delete c.y; } else c.y = y;
    }
    return c;
  }
  /* 외움 = 맞힌 날 둘 이상 + 시험 · 드릴에서 맞힌 날 있음 */
  function setMemo(c) { return isObj(c) && isArr(c.d) && c.d.length >= 2 && str(c.t) !== ''; }
  /* 쌓인 오답에 있음 */
  function setInDue(c) { return isObj(c) && str(c.z) !== ''; }
  /* 오늘 쌓인 오답에 나옴 = 들어간 날이 오늘 앞 · 오늘 아직 안 맞힘 */
  function setDueOn(c, day) {
    var z;
    if (!isObj(c)) return false;
    z = str(c.z);
    day = str(day);
    return z !== '' && z < day && !(isArr(c.y) && c.y.indexOf(day) >= 0);
  }

  /* 문항 칸 글(서버 lec__set_txt: 글자 · 숫자만 · 탭 · 줄바꿈 → 빈칸 · 앞뒤 빈칸 지움) */
  function itxt(e, f) {
    var v = isObj(e) ? e[f] : undefined;
    if (typeof v !== 'string' && !(typeof v === 'number' && isFinite(v))) return '';
    return sp(String(v).replace(/[\t\n\u000B\f\r]/g, ' '));
  }
  function guessKind(a) {
    var i;
    a = isArr(a) ? a : [];
    for (i = 0; i < a.length; i += 1) {
      if (isObj(a[i]) && has(a[i], 'w')) return 'voc';
      if (isObj(a[i]) && has(a[i], 'e')) return 'gu';
    }
    return 'gram';
  }
  /* 열쇠 맞춤 글: 단어 = 단어 · 구문 = 영어(«/» 지움) · 문법 = 문제 */
  function ktext(kind, e) {
    if (kind === 'voc') return setNorm(itxt(e, 'w'));
    if (kind === 'gu') return setNorm(itxt(e, 'e').replace(/\//g, ' '));
    return setNorm(itxt(e, 's'));
  }
  /* 문항 열쇠 매기기(서버 lec__set_keys 와 같은 셈): 새 문항마다 아직 안 쓴 옛 문항 가운데 맞춤 글이 같은 첫 것의 열쇠 ·
     없으면 가장 큰 번호 + 1 · kind 를 안 주면 문항 칸으로 짐작 */
  function setKeys(oldItems, newItems, kind) {
    var ok = [], ot = [], used = [], max = 0, out = [], i, j, e, k, t, r;
    oldItems = isArr(oldItems) ? oldItems : [];
    newItems = isArr(newItems) ? newItems : [];
    kind = kind === 'voc' || kind === 'gu' || kind === 'gram' ? kind : guessKind(newItems.length ? newItems : oldItems);
    for (i = 0; i < oldItems.length; i += 1) {
      e = oldItems[i];
      k = isObj(e) ? str(e.k) : '';
      if (/^k[0-9]{1,6}$/.test(k)) {
        max = Math.max(max, parseInt(k.slice(1), 10));
        ok.push(k); ot.push(ktext(kind, e)); used.push(false);
      }
    }
    for (i = 0; i < newItems.length; i += 1) {
      e = newItems[i];
      t = ktext(kind, e);
      k = null;
      for (j = 0; j < ok.length; j += 1) {
        if (!used[j] && ot[j] === t) { k = ok[j]; used[j] = true; break; }
      }
      if (k === null) { max += 1; k = 'k' + max; }
      r = isObj(e) ? copy(e) : {};
      r.k = k;
      out.push(r);
    }
    return out;
  }

  /* ------------------------------------------------------------- 붙여 넣기(위젯 그대로) */

  /* 엑셀 · 구글 시트 복사 꼴(TSV)로 줄 나누기: 따옴표로 시작하는 칸은 닫는 따옴표(뒤가 탭 · 줄 끝 · 글 끝)까지 줄을 넘어 읽고 "" → " ·
     엑셀이 따옴표로 감싸는 칸(안에 줄바꿈 · 탭 · 따옴표가 있음)만 그렇게 읽음 · 닫는 따옴표가 없거나 뒤에 글이 붙으면 따옴표 그대로(위젯 글)
     → [{s: 줄 글, c: 칸들 | null(탭도 따옴표 칸도 없는 줄), nl: 칸 안 줄바꿈을 이었음}] */
  function tsvLines(text) {
    var t = str(text).replace(/\r\n?/g, '\n'), len = t.length, out = [], p = 0, st, cells, nl, qd, v, j, q, dq, ch;
    while (p <= len) {
      st = p; cells = []; nl = false; qd = false;
      for (;;) {
        v = null;
        if (t.charAt(p) === '"') {
          j = p + 1; q = ''; dq = false;
          while (j < len) {
            ch = t.charAt(j);
            if (ch === '"') {
              if (t.charAt(j + 1) === '"') { q += '"'; dq = true; j += 2; continue; }
              break;
            }
            q += ch;
            j += 1;
          }
          if (j < len && (j + 1 === len || t.charAt(j + 1) === '\t' || t.charAt(j + 1) === '\n') &&
              (dq || q.indexOf('\n') >= 0 || q.indexOf('\t') >= 0)) {
            if (q.indexOf('\n') >= 0) nl = true;
            qd = true;
            v = q.replace(/[ \t]*\n[ \t]*/g, ' ').replace(/\t/g, ' ');
            p = j + 1;
          }
        }
        if (v === null) {
          j = p;
          while (j < len && t.charAt(j) !== '\t' && t.charAt(j) !== '\n') j += 1;
          v = t.slice(p, j);
          p = j;
        }
        cells.push(v);
        if (p < len && t.charAt(p) === '\t') { p += 1; continue; }
        break;
      }
      out.push({ s: t.slice(st, p), c: cells.length > 1 || qd ? cells : null, nl: nl });
      p += 1;
    }
    return out;
  }
  /* 빈 줄 뺌 · 탭이 있으면 탭(엑셀 따옴표 칸은 tsvLines) · 없으면 빈칸 둘 이상이나 « | » · 칸 trim ·
     칸이 둘 이상이고 첫 칸이 번호(1~4자리 · «1.» «1)» 꼴도)면 번호 · 첫 칸이 «1. 낱말» 꼴이면 번호를 떼어 냄 · 칸 안 줄바꿈을 이은 줄은 nl: true */
  function setParse(text) {
    var out = [], lines = tsvLines(text), i, s, c, n, j, m, r;
    for (i = 0; i < lines.length; i += 1) {
      s = lines[i].s;
      if (!s.trim()) continue;
      c = lines[i].c ? lines[i].c.slice() : s.split(/ {2,}| \| /);
      for (j = 0; j < c.length; j += 1) c[j] = c[j].trim();
      n = '';
      if (c.length > 1 && (m = /^(\d{1,4})[.)]?$/.exec(c[0]))) { n = m[1]; c.shift(); }
      else if (c.length > 1 && (m = /^(\d{1,4})[.)]\s+(\S.*)$/.exec(c[0]))) { n = m[1]; c[0] = m[2]; }
      r = { n: n, c: c };
      if (lines[i].nl) r.nl = true;
      out.push(r);
    }
    return out;
  }
  /* 문법 = 괄호 안 / 보기나 [ ] 가 반 넘게 · 구문 = 낱말 수 가운데 값 5 이상이거나 문장 끝 줄 60% 이상 · 그 밖 단어 */
  function setDetect(rows) {
    var g = 0, s = 0, wc = [], i, a;
    rows = isArr(rows) ? rows : [];
    if (!rows.length) return '';
    for (i = 0; i < rows.length; i += 1) {
      a = (rows[i] && isArr(rows[i].c) && rows[i].c[0]) || '';
      a = str(a);
      if (/\([^()]*\/[^()]*\)|\[[^\[\]]+\]/.test(a)) g += 1;
      wc.push(a.split(/\s+/).filter(Boolean).length);
      if (/[.?!]["']?$/.test(a)) s += 1;
    }
    if (g >= rows.length / 2) return 'gram';
    wc.sort(function (x, y) { return x - y; });
    if (wc[Math.floor(wc.length / 2)] >= 5 || s >= rows.length * 0.6) return 'gu';
    return 'voc';
  }
  function cols(r) { return r && isArr(r.c) ? r.c : []; }
  function cell(c, i) { return str(c[i]); }
  /* 저장 전 경고: bad[i] = 'ng'(빼고 저장 · 서버가 받지 않는 줄) | 'am'(그대로 저장 · 주의) · msgs = [{c, t}] */
  function setWarn(kind, rows) {
    var bad = {}, msgs = [], i, c, n, a, s, o, pg, bk, m, x, lo, seen = {}, key, cnt = {}, ng = 0, am = 0, re;
    rows = isArr(rows) ? rows : [];
    function hit(name) { cnt[name] = (cnt[name] || 0) + 1; }
    for (i = 0; i < rows.length; i += 1) {
      c = cols(rows[i]);
      n = str(rows[i] && rows[i].n);
      if (rows[i] && rows[i].nl) hit('nl');
      if (kind === 'voc') {
        if (!cell(c, 1)) { bad[i] = 'ng'; hit('vm'); }
        else if (!cell(c, 0)) { bad[i] = 'ng'; hit('vw'); }
        else if (clen(c[0]) > 100 || clen(c[1]) > 200 || clen(n) > 8) { bad[i] = 'ng'; hit('long'); }
        key = cell(c, 0).toLowerCase();
        if (has(seen, '#' + key)) {
          if (!bad[i]) bad[i] = 'am';
          if (!bad[seen['#' + key]]) bad[seen['#' + key]] = 'am';
        } else seen['#' + key] = i;
      } else if (kind === 'gu') {
        if (!cell(c, 1)) { bad[i] = 'ng'; hit('gt'); }
        else if (!cell(c, 0)) { bad[i] = 'ng'; hit('ge'); }
        else if (clen(c[0]) > 300 || clen(c[1]) > 300 || clen(cell(c, 2)) > 60 || clen(n) > 8) { bad[i] = 'ng'; hit('long'); }
      } else if (kind === 'gram') {
        s = cell(c, 0); a = cell(c, 1); x = cell(c, 2);
        o = setOpts(s);
        pg = countRe(/[(]([^()]*\/[^()]*)[)]/g, s);
        re = /\[([^\]]*)\]/g;
        bk = countRe(re, s);
        if (!a || (o && o.indexOf(a) < 0)) { bad[i] = 'ng'; hit('ga'); }
        else if (pg + bk === 0) { bad[i] = 'ng'; hit('g0'); }
        else if (pg + bk > 1) { bad[i] = 'ng'; hit('g2'); }
        else if (pg === 1 && (o.length < 2 || o.length > 5 || o.indexOf('') >= 0)) { bad[i] = 'ng'; hit('go'); }
        else if (bk === 1 && (m = /\[([^\]]*)\]/.exec(s)) && sp(m[1]) === '') { bad[i] = 'ng'; hit('gb'); }
        else if (clen(s) > 300 || clen(a) > 100 || clen(x) > 300 || clen(cell(c, 3)) > 40 || clen(n) > 8) { bad[i] = 'ng'; hit('long'); }
        else if (x.length > 60) { bad[i] = 'am'; hit('gx'); }
      }
    }
    for (lo in bad) {
      if (!has(bad, lo)) continue;
      if (bad[lo] === 'ng') ng += 1; else am += 1;
    }
    function msg(k, cl, t) { if (cnt[k]) msgs.push({ c: cl, t: t + ' ' + cnt[k] }); }
    if (kind === 'voc') {
      msg('vm', 'ng', '뜻 빈칸');
      msg('vw', 'ng', '단어 빈칸');
      if (am) msgs.push({ c: 'am', t: '같은 단어 ' + am });
    }
    if (kind === 'gu') {
      msg('gt', 'ng', '해석 빈칸');
      msg('ge', 'ng', '문장 빈칸');
    }
    if (kind === 'gram') {
      msg('ga', 'ng', '답이 없거나 보기에 없어요');
      msg('g0', 'ng', '( / )나 [ ]가 없어요');
      msg('g2', 'ng', '( / )나 [ ]는 한 줄에 하나만');
      msg('go', 'ng', '보기는 둘에서 다섯');
      msg('gb', 'ng', '[ ] 안이 비었어요');
    }
    msg('long', 'ng', '너무 긴 칸');
    if (kind === 'gram') msg('gx', 'am', '해설이 폰에서 세 줄 넘어요');
    /* 엑셀 칸 안 줄바꿈(Alt+Enter)은 한 칸으로 읽고 빈칸 하나로 이음(줄은 빼지 않음 · 알려만 줌) */
    msg('nl', 'am', '칸 안 줄바꿈은 한 줄로 이었어요');
    return { bad: bad, ng: ng, am: am, msgs: msgs };
  }
  /* 저장할 문항: setWarn 이 'ng' 로 본 줄만 뺌(같은 판정) · 빈 칸은 '' */
  function setItemsFrom(kind, rows) {
    var w0 = setWarn(kind, rows), out = [], i, c, n;
    rows = isArr(rows) ? rows : [];
    for (i = 0; i < rows.length; i += 1) {
      if (w0.bad[i] === 'ng') continue;
      c = cols(rows[i]);
      n = str(rows[i] && rows[i].n);
      if (kind === 'voc') out.push({ n: n, w: cell(c, 0), m: cell(c, 1) });
      else if (kind === 'gu') out.push({ n: n, e: cell(c, 0), t: cell(c, 1), p: cell(c, 2) });
      else if (kind === 'gram') out.push({ n: n, s: cell(c, 0), a: cell(c, 1), x: cell(c, 2), p: cell(c, 3) });
    }
    return out;
  }

  /* ------------------------------------------------------------- 외우기 한 판 */

  /* 안 넘긴 것(차례) → 넘겼으나 외움 아님 → 외움 · 앞 size(기본 20) */
  function setDeck(items, cards, size) {
    var a = [], b = [], c = [], i, k, cd;
    items = isArr(items) ? items : [];
    cards = isObj(cards) ? cards : {};
    size = size == null ? 20 : Math.max(0, Math.floor(+size || 0));
    for (i = 0; i < items.length; i += 1) {
      k = str(items[i] && items[i].k);
      if (!k) continue;
      cd = has(cards, k) ? cards[k] : null;
      if (!isObj(cd) || +cd.s !== 1) a.push(k);
      else if (!setMemo(cd)) b.push(k);
      else c.push(k);
    }
    return a.concat(b, c).slice(0, size);
  }
  /* 판 안 «다시»: 맨 앞을 빼고 · 다시면(이 판 3번 아래) 5장 뒤(남은 것이 적으면 끝)에 다시 넣음 */
  function setNextQ(q, again, times) {
    var rest = isArr(q) ? q.slice(1) : [], t = {}, k = isArr(q) && q.length ? q[0] : null, n, x;
    if (isObj(times)) { for (x in times) { if (has(times, x)) t[x] = times[x]; } }
    if (again && k != null) {
      n = +t[k] || 0;
      if (n < 3) {
        t[k] = n + 1;
        rest.splice(Math.min(5, rest.length), 0, k);
      }
    }
    return { q: rest, times: t };
  }

  /* ------------------------------------------------------------- 인쇄 */

  /* 구문 영어: «/» 를 빈칸으로 · 빈칸 무리 하나로 */
  function sayText(e) { return str(e).replace(/\//g, ' ').replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, ''); }
  /* 따라 말하기 덩어리: «/» 로 나눔(빈 것 뺌) */
  function sayParts(e) {
    var a = str(e).split('/'), o = [], i, v;
    for (i = 0; i < a.length; i += 1) {
      v = a[i].replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, '');
      if (v) o.push(v);
    }
    return o;
  }
  /* 히즈북스 구문 시험지와 같은 낱말 나눔 */
  function words(en) {
    var a = str(en).split(' '), o = [], i;
    for (i = 0; i < a.length; i += 1) { if (a[i].trim().length) o.push(a[i]); }
    return o;
  }
  var PR_LABEL = {
    voc: { ko: '뜻 쓰기', en: '영어 쓰기', mix: '섞어서' },
    gu: { mean: '의미 쓰기', write: '영작 (한글 → 영어)', blank: '빈칸 채우기', scr: '어순 배열' },
    gram: { gram: '괄호 고르기 · 고쳐 쓰기' }
  };
  /* 시험지 문항 · 정답: opt = {keys(기본 전부) · shuffle(기본 참) · rnd} · 섞은 뒤 번호 1부터 */
  function setPrint(set, mode, opt) {
    var kind, items, keys, list = [], q = [], a = [], i, it, no, f, en, ws, nb, idx, mk, wl, j, sw, label;
    set = isObj(set) ? set : {};
    opt = isObj(opt) ? opt : {};
    kind = str(set.kind);
    items = isArr(set.items) ? set.items : [];
    keys = isArr(opt.keys) ? opt.keys : null;
    if (kind === 'voc') { if (!has(PR_LABEL.voc, mode)) mode = 'ko'; }
    else if (kind === 'gu') { if (!has(PR_LABEL.gu, mode)) mode = 'mean'; }
    else { kind = 'gram'; mode = 'gram'; }
    label = PR_LABEL[kind][mode];
    for (i = 0; i < items.length; i += 1) {
      it = items[i];
      if (!isObj(it)) continue;
      if (keys && keys.indexOf(it.k) < 0) continue;
      list.push(it);
    }
    if (opt.shuffle !== false) shuffle(list, opt.rnd);
    for (i = 0; i < list.length; i += 1) {
      it = list[i];
      no = i + 1;
      if (kind === 'voc') {
        f = mode === 'mix' ? (i % 2 === 0 ? 'ko' : 'en') : mode;
        if (f === 'ko') {
          q.push(mode === 'mix' ? { no: no, f: f, show: str(it.w) } : { no: no, show: str(it.w) });
          a.push(mode === 'mix' ? { no: no, f: f, show: str(it.w), ans: str(it.m) } : { no: no, show: str(it.w), ans: str(it.m) });
        } else {
          q.push(mode === 'mix' ? { no: no, f: f, show: str(it.m) } : { no: no, show: str(it.m) });
          a.push(mode === 'mix' ? { no: no, f: f, show: str(it.m), ans: str(it.w) } : { no: no, show: str(it.m), ans: str(it.w) });
        }
      } else if (kind === 'gu') {
        en = sayText(it.e);
        if (mode === 'mean') {
          q.push({ no: no, show: en });
          a.push({ no: no, show: en, ans: str(it.t) });
        } else if (mode === 'write') {
          q.push({ no: no, show: str(it.t) });
          a.push({ no: no, show: str(it.t), ans: en });
        } else if (mode === 'blank') {
          ws = words(en);
          nb = Math.max(1, Math.round(ws.length * 0.4));
          idx = [];
          for (j = 1; j < ws.length; j += 1) idx.push(j);
          shuffle(idx, opt.rnd);
          idx = idx.slice(0, nb);
          mk = {};
          for (j = 0; j < idx.length; j += 1) mk[idx[j]] = 1;
          wl = [];
          for (j = 0; j < ws.length; j += 1) wl.push({ w: ws[j], b: !!mk[j] });
          q.push({ no: no, words: wl, ko: str(it.t) });
          a.push({ no: no, words: wl.map(function (x) { return { w: x.w, b: x.b }; }), ko: str(it.t) });
        } else {
          ws = words(en);
          sw = shuffle(ws.slice(), opt.rnd);
          if (sw.length > 1 && sw.join(' ') === ws.join(' ')) { j = sw[0]; sw[0] = sw[1]; sw[1] = j; }
          q.push({ no: no, ko: str(it.t), toks: sw });
          a.push({ no: no, ans: en });
        }
      } else {
        f = gramParts(it.s).f;
        q.push({ no: no, s: str(it.s), f: f });
        a.push({ no: no, s: str(it.s), f: f, ans: str(it.a), x: str(it.x) });
      }
    }
    return { label: label, count: q.length, q: q, a: a };
  }

  /* ------------------------------------------------------------- 소리 · 녹음 꼴 */

  /* 소리(11-18 점수로 고름): 영어 목소리만 · en-US +40 · 다른 en +20 · 좋은 이름 +15 · 폰 안 목소리 +5 · 기본 +3 ·
     장난 · 기계 목소리(아이폰 · 맥 목록에 en-US 로 들어 있음) -100(다른 영어 목소리가 하나도 없을 때만 걸림) · 같으면 목록 차례 · 없으면 null(소리 단추 숨김)
     말 빠르기는 화면(느리게 0.7 · 보통 0.9 · 빠르게 1.0) */
  var SAY_JOKE = /\b(albert|bad news|bahh|bells|boing|bubbles|cellos|good news|jester|organ|pipe organ|superstar|trinoids|whisper|wobble|zarvox|deranged|hysterical|princess|ralph|fred|junior|kathy|eddy|flo|grandma|grandpa|reed|rocko|sandy|shelley)\b/i;
  var SAY_GOOD = /\b(google|samantha|enhanced|premium|natural|neural|siri|ava|allison|aaron|nicky|susan|zoe|evan|nathan|tom|joelle|noelle)\b/i;
  function sayScore(v) {
    var lang = str(v && v.lang), nm = str(v && v.name), s;
    if (!v || !/^en/i.test(lang)) return null;
    s = /^en[-_]us/i.test(lang) ? 40 : 20;
    if (SAY_GOOD.test(nm)) s += 15;
    if (v.localService) s += 5;
    if (v['default']) s += 3;
    if (SAY_JOKE.test(nm)) s -= 100;
    return s;
  }
  function sayVoice(voices) {
    var best = null, bs = 0, i, s, n;
    n = voices && typeof voices.length === 'number' ? voices.length : 0;
    for (i = 0; i < n; i += 1) {
      s = sayScore(voices[i]);
      if (s === null) continue;
      if (best === null || s > bs) { best = voices[i]; bs = s; }
    }
    return best;
  }
  /* 녹음 꼴: webm(opus) → mp4 → ''(기본) */
  function recMime(MR) {
    var c = ['audio/webm;codecs=opus', 'audio/mp4'], i;
    if (!MR || typeof MR.isTypeSupported !== 'function') return '';
    for (i = 0; i < c.length; i += 1) {
      try { if (MR.isTypeSupported(c[i])) return c[i]; } catch (e) { /* 없음 */ }
    }
    return '';
  }
  /* 올릴 꼴: codecs 뗀 셋 가운데 하나 · 밖이면 ''(못 올림) */
  function recBase(mime) {
    var m = str(mime).split(';')[0].replace(/\s+/g, '').toLowerCase();
    return REC_TYPES.indexOf(m) >= 0 ? m : '';
  }

  /* ------------------------------------------------------------- 말하기 확인(11-18 · 폰 안 음성 인식 · 돈 0 · 우리 셈)
     spkCan(env) = 'ok' 또는 안 되는 까닭 · spkWords(글) = 맞춘 낱말 · spkScore(목표, 들린 후보들, 몇 번째) = 낱말마다 맞음/빠짐 */

  /* env = {api(SpeechRecognition 있음) · pv(미리 보기) · ua · platform · touch(maxTouchPoints) · standalone(홈 화면 앱) · off(이 탭에서 실패함)}
     아이폰 · 아이패드 홈 화면 앱은 애플이 음성 인식을 아직 안 엶(WebKit bug 225298) · 앱 안 브라우저(카톡 · 네이버 · 라인 · 인스타 · 페북 · 다음 · 에브리타임 · 안드로이드 wv) 안 씀 */
  function spkCan(e) {
    var ua, ios;
    e = isObj(e) ? e : {};
    if (!e.api) return 'api';
    if (e.pv) return 'preview';
    ua = str(e.ua);
    if (/KAKAOTALK|NAVER\(inapp|Line\/|Instagram|FBAN|FBAV|DaumApps|everytimeApp/i.test(ua) || (/Android/i.test(ua) && /; wv\)/.test(ua))) return 'inapp';
    ios = /iPhone|iPad|iPod/.test(ua) || (str(e.platform) === 'MacIntel' && (+e.touch || 0) > 1);
    if (ios && e.standalone) return 'pwa';
    if (e.off) return 'off';
    return 'ok';
  }
  var SPK_ONES = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen',
                  'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  var SPK_TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
  var SPK_ORD = { one: 'first', two: 'second', three: 'third', five: 'fifth', eight: 'eighth', nine: 'ninth', twelve: 'twelfth', twenty: 'twentieth', thirty: 'thirtieth' };
  var SPK_IS = { it: 1, he: 1, she: 1, that: 1, what: 1, there: 1, here: 1, who: 1, where: 1, how: 1 };
  /* 같은 소리 묶음(묶음 첫 낱말로 맞춤) */
  var SPK_SAME = 'to too two|for four|there their|hear here|know no|by buy bye|right write|new knew|one won|see sea|be bee|i eye|our hour|wear where|' +
    'weather whether|whole hole|peace piece|week weak|meet meat|would wood|which witch|ate eight|made maid|mail male|flower flour|sun son|blue blew|' +
    'threw through|pair pear|sale sail|tail tale|road rode|allowed aloud|' +
    'steal steel|role roll|dear deer|plain plane|wait weight|waste waist|night knight|cell sell|fair fare|hair hare|heal heel|higher hire|' +
    'peak peek|principal principle|stair stare';
  var SPK_HM = {};
  (function () {
    var g = SPK_SAME.split('|'), i, j, a;
    for (i = 0; i < g.length; i += 1) { a = g[i].split(' '); for (j = 0; j < a.length; j += 1) SPK_HM[a[j]] = a[0]; }
  })();
  /* 0~999 → 낱말 */
  function spkNum(n) {
    var o = [], h = Math.floor(n / 100), r = n % 100;
    if (n === 0) return ['zero'];
    if (h) o.push(SPK_ONES[h], 'hundred');
    if (r >= 20) { o.push(SPK_TENS[Math.floor(r / 10)]); if (r % 10) o.push(SPK_ONES[r % 10]); } else if (r > 0) o.push(SPK_ONES[r]);
    return o;
  }
  /* 1st~31st → 낱말 */
  function spkOrd(n) {
    var o = spkNum(n), l = o[o.length - 1];
    o[o.length - 1] = has(SPK_ORD, l) ? SPK_ORD[l] : l + 'th';
    return o;
  }
  /* 영국 철자 → 미국 철자(양쪽에 똑같이 · 검수 A3): -our → -or(5자 이상 · colour · neighbourhood · favourite) ·
     -tre → -ter(centre · theatre · metre · litre) · grey → gray · -ise → -ize(7자 이상 · realise · organisation · apologising) */
  var SPK_OUR_NO = { flour: 1, scour: 1, devour: 1, detour: 1, contour: 1, velour: 1, amour: 1, paramour: 1, troubadour: 1 };
  var SPK_ISE_NO = { otherwise: 1, likewise: 1, clockwise: 1, exercise: 1, surprise: 1, promise: 1, premise: 1, compromise: 1, enterprise: 1,
                     expertise: 1, franchise: 1, merchandise: 1, paradise: 1, precise: 1, concise: 1, despise: 1, comprise: 1, disguise: 1,
                     chastise: 1, treatise: 1, tortoise: 1, porpoise: 1, turquoise: 1, advertise: 1, supervise: 1, televise: 1, improvise: 1 };
  function spkUs(w) {
    var m = /^([a-z]{2,})our(s|ed|ing|er|ers|ite|ites|able|ably|ful|less|hood|hoods|ist|ists)?$/.exec(w);
    if (m && (m[1] + 'our').length >= 5 && !has(SPK_OUR_NO, m[1] + 'our')) return m[1] + 'or' + (m[2] || '');
    m = /^([a-z]{2,})tre(s|d)?$/.exec(w);
    if (m && (m[1] + 'tre').length >= 5) return m[1] + 'ter' + (m[2] === 'd' ? 'ed' : (m[2] || ''));
    m = /^grey(s|er|est|ish|ness)?$/.exec(w);
    if (m) return 'gray' + (m[1] || '');
    m = /^([a-z]{3,})is(e|ed|es|ing|er|ers|ation|ations)$/.exec(w);
    if (m && (m[1] + 'ise').length >= 7 && !has(SPK_ISE_NO, m[1] + 'ise')) return m[1] + 'iz' + m[2];
    return w;
  }
  /* 소유 's(it's · he's 같은 줄임말 말고): X's = X · Xs(friend's ↔ friends ↔ friend · 검수 A3) · 아포스트로피 없는 복수는 그대로 다름 */
  function spkPos(t) {
    var a = t.split('|'), o = t, i;
    for (i = 0; i < a.length; i += 1) { if (a[i] && o.split('|').indexOf(a[i] + 's') < 0) o += '|' + a[i] + 's'; }
    return o;
  }
  /* 조각 하나(소문자 · a-z 0-9 ') → 낱말들 · 대안은 «|»(’d = would|had · it’s = is|has · Tom’s = tom|toms) */
  function spkOne(w) {
    var m, b;
    w = str(w).replace(/^'+/g, '');
    if (/[a-z0-9]s'+$/.test(w)) w = w.replace(/s'+$/, "'s"); /* 복수 소유 students' = student's */
    w = w.replace(/'+$/g, '');
    if (!w) return [];
    if (w === "can't" || w === 'cannot') return ['can', 'not'];
    if (w === "won't") return ['will', 'not'];
    if (w === "shan't") return ['shall', 'not'];
    if (w === "let's") return ['let', 'us'];
    if (w === 'ok') return ['okay']; /* OK · O.K. = okay */
    if (/n't$/.test(w) && w.length > 3) return spkOne(w.slice(0, -3)).concat(['not']);
    m = /^(.+)'(re|ve|ll|m|d|s)$/.exec(w);
    if (m) {
      b = spkOne(m[1]);
      if (m[2] === 're') return b.concat(['are']);
      if (m[2] === 've') return b.concat(['have']);
      if (m[2] === 'll') return b.concat(['will']);
      if (m[2] === 'm') return b.concat(['am']);
      if (m[2] === 'd') return b.concat(['would|had']);
      if (has(SPK_IS, m[1])) return b.concat(['is|has']);
      if (b.length) b[b.length - 1] = spkPos(b[b.length - 1]); /* 그 밖 's = 소유 · X|Xs */
      return b;
    }
    w = w.replace(/'/g, '');
    if (!w) return [];
    m = /^(\d{1,2})(st|nd|rd|th)$/.exec(w);
    if (m && +m[1] >= 1 && +m[1] <= 31) return spkOrd(+m[1]);
    if (/^\d{1,3}$/.test(w)) return spkNum(+w);
    return [spkUs(w)];
  }
  function spkCanon(t) {
    var a = t.split('|'), i;
    for (i = 0; i < a.length; i += 1) { if (has(SPK_HM, a[i])) a[i] = SPK_HM[a[i]]; }
    return a.join('|');
  }
  /* 겉 낱말 하나 → 맞춘 낱말들: NFC · 둥근 따옴표 → ' · 소문자 · 1,000 → 1000 · 점 약어(U.S. · a.m.) → 붙임 · 한 글자 붙임표(e-mail · T-shirt) → 붙임 ·
     % → percent · «/» 와 붙임표 · 줄표 → 빈칸 · a-z 0-9 ' 빈칸 밖 지움 */
  function spkToks(s) {
    var o = [], a, i, j, b;
    s = nfc(s).replace(/[‘’ʼ′`´]/g, "'").toLowerCase()
      .replace(/(\d),(?=\d{3}(?!\d))/g, '$1')
      .replace(/(^|[^a-z0-9'])((?:[a-z]\.){2,})/g, function (x, p, q) { return p + q.replace(/\./g, ''); })
      .replace(/(^|[^a-z0-9'])([a-z])[\-‐‑](?=[a-z]{2})/g, '$1$2')
      .replace(/%/g, ' percent ').replace(/[\/\-‐-―−]/g, ' ').replace(/[^a-z0-9' ]+/g, ' ');
    a = s.split(' ');
    for (i = 0; i < a.length; i += 1) {
      if (!a[i]) continue;
      b = spkOne(a[i]);
      for (j = 0; j < b.length; j += 1) { if (b[j]) o.push(spkCanon(b[j])); }
    }
    return o;
  }
  /* 글 → 겉 낱말(화면에 보일 것 · «/» 뺀 빈칸 나눔) + 맞춘 낱말마다 어느 겉 낱말인지 */
  function spkSplit(text) {
    var words = sayText(text) ? sayText(text).split(' ') : [], toks = [], i, j, t;
    for (i = 0; i < words.length; i += 1) {
      t = spkToks(words[i]);
      for (j = 0; j < t.length; j += 1) toks.push({ w: t[j], s: i });
    }
    return { words: words, toks: toks };
  }
  function spkWords(text) {
    var a = str(text).replace(/\s+/g, ' ').split(' '), o = [], i;
    for (i = 0; i < a.length; i += 1) { if (a[i]) o = o.concat(spkToks(a[i])); }
    return o;
  }
  /* 편집 거리(cap 넘으면 cap+1) */
  function spkLev(a, b, cap) {
    var n = a.length, m = b.length, p = [], q, i, j, lo, c;
    if (Math.abs(n - m) > cap) return cap + 1;
    for (j = 0; j <= m; j += 1) p.push(j);
    for (i = 1; i <= n; i += 1) {
      q = [i]; lo = i;
      for (j = 1; j <= m; j += 1) {
        c = Math.min(p[j] + 1, q[j - 1] + 1, p[j - 1] + (a.charAt(i - 1) === b.charAt(j - 1) ? 0 : 1));
        q.push(c);
        if (c < lo) lo = c;
      }
      if (lo > cap) return cap + 1;
      p = q;
    }
    return p[m];
  }
  /* 끝 -s · -es · -ed · -d 만 다른 꼴(walk · walks · student · students · remember · remembered)은 문법 차이 = 오타로 봐주지 않음 */
  function spkStems(w) {
    var o = [w];
    if (/s$/.test(w)) o.push(w.slice(0, -1));
    if (/es$/.test(w)) o.push(w.slice(0, -2));
    if (/ed$/.test(w)) o.push(w.slice(0, -2));
    if (/d$/.test(w)) o.push(w.slice(0, -1));
    return o;
  }
  function spkForm(p, q) {
    var a = spkStems(p), b = spkStems(q), i, j;
    for (i = 0; i < a.length; i += 1) { for (j = 0; j < b.length; j += 1) { if (a[i] && a[i] === b[j]) return true; } }
    return false;
  }
  /* 낱말 같음: 같음 · 같은 소리(이미 맞춤) · 대안 하나 · 둘 다 6자 이상이고 편집 거리 1 이하 · 둘 다 9자 이상이고 2 이하
     (숫자 든 낱말 · 끝 -s -es -ed -d 만 다른 꼴은 오타 봐주기 없음 · 5자 이하는 같아야 함: come · came · than · then) */
  /* 이름(검수 A3 · A4): 첫 글자가 같고 로마자 oo → u · ee → i 로 맞춘 뒤 편집 거리로 셈
     nm 1(문장 가운데 대문자 낱말) = 2 이하(짧은 쪽이 3자 이하면 1 이하 · Yeonwoo ↔ Yonu) · nm 2(문장 첫 이름 후보) = 1 이하만(Minsoo ↔ Minsu · Jiwoo ↔ Jiu · Music ↔ Magic 은 다름)
     끝 -s -es -ed -d 만 다른 꼴 · 숫자 든 낱말은 이름이어도 봐주지 않음 */
  function spkNmFold(w) { return w.replace(/oo/g, 'u').replace(/ee/g, 'i'); }
  function spkNameEq(p, q, nm) {
    var a, b, d;
    if (!p || !q || p.charAt(0) !== q.charAt(0) || /\d/.test(p + q) || spkForm(p, q)) return false;
    a = spkNmFold(p); b = spkNmFold(q);
    d = spkLev(a, b, 2);
    if (nm === 2) return d <= 1;
    return d <= 1 || (d <= 2 && Math.min(a.length, b.length) >= 4);
  }
  /* nm = 0 이름 아님 · 1 문장 가운데 이름 · 2 문장 첫 이름 후보(spkNames) */
  function spkEq(a, b, nm) {
    var x = a.split('|'), y = b.split('|'), i, j, p, q, d;
    for (i = 0; i < x.length; i += 1) {
      for (j = 0; j < y.length; j += 1) {
        p = x[i]; q = y[j];
        if (p === q) return true;
        if (p.length >= 6 && q.length >= 6 && !/\d/.test(p + q) && !spkForm(p, q)) {
          d = spkLev(p, q, 2);
          if (d <= 1 || (d <= 2 && p.length >= 9 && q.length >= 9)) return true;
        }
        if (nm && spkNameEq(p, q, nm)) return true;
      }
    }
    return false;
  }
  /* 문장 첫 낱말로 흔한 말(이 말로 시작하면 이름으로 안 봄 · 문장 가운데 대문자 낱말은 목록 상관없이 이름(1)) */
  var SPK_LEAD = {};
  (function () {
    var a = ('the a an i you he she it we they this that these those there here my your his her its our their me him us them ' +
      'what when where why how who whom whose which if because after before as while although though since so but and or nor yet ' +
      'in on at for with to from by of about into onto over under up down out off through during without within between among around ' +
      'across along against toward towards behind beyond near like unlike than until unless whether ' +
      'many most some all every each any both either neither no not none one two three four five ten ' +
      'today yesterday tomorrow tonight last next first second third then now also however therefore instead still even just only once ' +
      'soon later finally again always never often sometimes usually maybe perhaps actually yes yeah oh well wow hey hi hello thanks thank sorry ' +
      'please let do does did can could will would should shall may might must have has had is are was were be been being am ' +
      'go come give take look listen read write make put keep tell ask try think open close turn stop wait walk run sit stand get see say ' +
      'find help bring show call check use choose answer follow imagine remember know want need love such other another more less few much ' +
      'very too everyone everybody everything someone somebody something anyone anybody anything nobody nothing people dear').split(' '), i;
    for (i = 0; i < a.length; i += 1) SPK_LEAD[a[i]] = 1;
  })();
  /* 겉 낱말 → 이름인지: 0 아님 · 1 문장 가운데 대문자 낱말 · 2 문장 첫 이름 후보(검수 A4)
     원래 글에서 대문자로 시작 · I 와 다 대문자인 말(TV · USA) 빼고 · 문장 첫 낱말은 흔한 첫 낱말이 아니고 끝이 s 가 아닐 때만 2(Cats · Dogs · James = 0) */
  function spkNames(words) {
    var o = [], i, w, c, st, k, k0;
    for (i = 0; i < words.length; i += 1) {
      w = nfc(words[i]);
      c = w.replace(/^[^A-Za-z]+/, '');
      st = i === 0 || /[.?!:]['"’”)\]]*$/.test(nfc(words[i - 1])) || /^["“‘']/.test(w);
      if (!/^[A-Z]/.test(c) || /^I(?![A-Za-z])/.test(c) || !/[a-z]/.test(c)) { o.push(0); continue; }
      if (!st) { o.push(1); continue; }
      k0 = c.replace(/[‘’ʼ′`´]/g, "'").toLowerCase().replace(/[^a-z'].*$/, '');
      k = k0 ? (spkOne(k0)[0] || '').split('|')[0] : '';
      o.push(!k || has(SPK_LEAD, k) || /s$/.test(k) || /s'+$/.test(k0) ? 0 : 2); /* Cats' 같은 복수 소유도 0 */
    }
    return o;
  }
  /* 맞춤(LCS · 맞은 수가 가장 많게) → 목표 낱말마다 1/0 · nm = 목표 낱말마다 이름 표시(0 · 1 · 2 · spkNames) */
  function spkAlign(tw, hw, nm) {
    var n = tw.length, m = hw.length, T = [], i, j, mk = [], hit = 0, e;
    nm = nm || [];
    for (i = 0; i <= n; i += 1) { T.push([]); for (j = 0; j <= m; j += 1) T[i].push(0); }
    for (i = n - 1; i >= 0; i -= 1) {
      for (j = m - 1; j >= 0; j -= 1) {
        T[i][j] = Math.max(T[i + 1][j], T[i][j + 1], spkEq(tw[i], hw[j], nm[i]) ? T[i + 1][j + 1] + 1 : 0);
      }
    }
    for (i = 0; i < n; i += 1) mk.push(0);
    i = 0; j = 0;
    while (i < n && j < m) {
      e = spkEq(tw[i], hw[j], nm[i]);
      if (e && T[i][j] === T[i + 1][j + 1] + 1) { mk[i] = 1; hit += 1; i += 1; j += 1; }
      else if (T[i + 1][j] >= T[i][j + 1]) i += 1;
      else j += 1;
    }
    return { mk: mk, hit: hit };
  }
  /* 통과 기준: 낱말 3개 이하면 전부 · 그 위는 80% 올림 · 3번째 시도부터 70% 올림(정수 셈) */
  function spkNeed(n, tryNo) {
    n = Math.max(0, Math.floor(+n || 0));
    if (n <= 3) return n;
    return (Math.floor(+tryNo || 1) >= 3) ? Math.floor((n * 7 + 9) / 10) : Math.floor((n * 8 + 9) / 10);
  }
  /* 목표 글 · 들린 후보(최대 5 · 가장 많이 맞는 것) · 몇 번째 시도(1부터) →
     {n, hit, need, pass, marks(맞춘 낱말마다), words(겉 낱말), wm(겉 낱말마다 · 그 안 낱말이 다 맞아야 1), miss(빠진 겉 낱말 수), heard} */
  function spkScore(target, heard, tryNo) {
    var sp = spkSplit(target), tw = [], nm = [], sn = spkNames(sp.words), alts, best = null, i, r, n, wm = [], miss = 0, need;
    for (i = 0; i < sp.toks.length; i += 1) { tw.push(sp.toks[i].w); nm.push(sn[sp.toks[i].s] || 0); }
    n = tw.length;
    alts = isArr(heard) ? heard : (heard == null ? [] : [heard]);
    for (i = 0; i < alts.length && i < 5; i += 1) {
      r = spkAlign(tw, spkWords(alts[i]), nm);
      if (!best || r.hit > best.hit) { best = r; best.heard = str(alts[i]).replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, ''); }
    }
    if (!best) { best = spkAlign(tw, [], nm); best.heard = ''; }
    for (i = 0; i < sp.words.length; i += 1) wm.push(1);
    for (i = 0; i < n; i += 1) { if (!best.mk[i]) wm[sp.toks[i].s] = 0; }
    for (i = 0; i < wm.length; i += 1) { if (!wm[i]) miss += 1; }
    tryNo = Math.max(1, Math.floor(+tryNo || 1));
    need = spkNeed(n, tryNo);
    /* 맞출 영어 낱말이 없는 문장은 통과 없음(화면은 그 문장을 스스로 확인으로) */
    return { n: n, hit: best.hit, need: need, pass: n > 0 && best.hit >= need, marks: best.mk, words: sp.words, wm: wm, miss: miss, heard: best.heard };
  }

  /* ------------------------------------------------------------- 쓰기 오답 · 문항 차례(11-18) */

  /* 내 답 · 바른 답의 다른 글자(둘 중 하나가 40자 넘으면 낱말) · 대소문자는 같게 봄 · 우리 식 LCS
     → {u: 'c'|'w', same(같은 수), a: [{t, d}](내 답 조각 · d 1 = 다름), b: [{t, d}](바른 답)} */
  function setDiff(mine, right) {
    var A = str(mine), B = str(right), wm = A.length > 40 || B.length > 40, ua, ub, n, m, T = [], i, j, fa = [], fb = [], same = 0;
    function units(s) {
      var a = wm ? s.replace(/\s+/g, ' ').replace(/^ | $/g, '').split(' ') : s.split(''), o = [], k;
      for (k = 0; k < a.length; k += 1) { if (a[k] !== '') o.push(a[k]); }
      return o;
    }
    function low(s) { return s.replace(/[A-Z]/g, function (c) { return c.toLowerCase(); }); }
    function segs(u, f) {
      var o = [], k;
      function put(t, d) { if (o.length && o[o.length - 1].d === d) o[o.length - 1].t += t; else o.push({ t: t, d: d }); }
      for (k = 0; k < u.length; k += 1) {
        if (wm && k) put(' ', 0);
        put(u[k], f[k]);
      }
      return o;
    }
    ua = units(A); ub = units(B); n = ua.length; m = ub.length;
    for (i = 0; i <= n; i += 1) { T.push([]); for (j = 0; j <= m; j += 1) T[i].push(0); }
    for (i = n - 1; i >= 0; i -= 1) {
      for (j = m - 1; j >= 0; j -= 1) T[i][j] = low(ua[i]) === low(ub[j]) ? T[i + 1][j + 1] + 1 : Math.max(T[i + 1][j], T[i][j + 1]);
    }
    for (i = 0; i < n; i += 1) fa.push(1);
    for (j = 0; j < m; j += 1) fb.push(1);
    i = 0; j = 0;
    while (i < n && j < m) {
      if (low(ua[i]) === low(ub[j])) { fa[i] = 0; fb[j] = 0; same += 1; i += 1; j += 1; }
      else if (T[i + 1][j] >= T[i][j + 1]) i += 1;
      else j += 1;
    }
    return { u: wm ? 'w' : 'c', same: same, a: segs(ua, fa), b: segs(ub, fb) };
  }
  /* 화면 차례: 고르기(f 'c') 먼저 → 쓰기('w' · 'r') 나중 · 각 묶음 안은 서버 차례 · 돌려줌 = 서버 번호(p_i) 목록 */
  function setOrder(qs, n) {
    var a = [], b = [], i, len = isArr(qs) ? qs.length : 0;
    n = n == null ? len : Math.min(len, Math.max(0, Math.floor(+n || 0)));
    for (i = 0; i < n; i += 1) { if (isObj(qs[i]) && qs[i].f === 'c') a.push(i); else b.push(i); }
    return a.concat(b);
  }

  /* ------------------------------------------------------------- 학생: 서버 부르기 */

  /* 서버에 함수가 없거나 막힘: 404 · 401 · 403 · PGRST202 · 42883 */
  function gone(e) {
    return !!e && (e.status === 404 || e.status === 401 || e.status === 403 || e.code === 'PGRST202' || e.code === '42883');
  }
  function failOf(e) {
    if (gone(e)) return { ok: false, err: 'old' };
    return { ok: false, err: e && e.message === 'network' ? 'network' : 'error' };
  }
  function pv() { return !!w.__lecPvIn; }
  function stuCall(fn, args) {
    var p;
    if (pv()) return Promise.resolve({ ok: false, err: 'preview' }); /* 미리 보기 안쪽 = 부르지 않음 */
    try { p = Lec.rpc(fn, args); } catch (e0) { return Promise.resolve(failOf(e0)); }
    return Promise.resolve(p).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, failOf).then(null, function () { return { ok: false, err: 'error' }; });
  }
  function k0(key) { return key == null ? null : str(key); }

  var homeGone = false;
  /* 공부 묶음 목록 · 서버에 함수가 없으면(옛 SQL) 이 화면에서는 다시 안 부름 · 실패 = null · ok 아님 = 그 값 */
  function setHome(key) {
    var p;
    if (pv()) return Promise.resolve(null);
    if (homeGone || key == null || key === '') return Promise.resolve(null);
    try { p = Lec.rpc('lec_set_home', { p_key: str(key) }); } catch (e0) { return Promise.resolve(null); }
    return Promise.resolve(p).then(function (r) {
      return isObj(r) ? r : null;
    }, function (e) {
      if (gone(e)) homeGone = true;
      return null;
    }).then(null, function () { return null; });
  }
  function setItems(key, id) { return stuCall('lec_set_items', { p_key: k0(key), p_set: id || null }); }
  /* 표시: 0 다시 · 1 알아요 · 2 알아요 + 말해서 확인(구문 · 11-18) → 옛 서버가 2 를 'input' 으로 거절하면 2 → 1 로 바꿔 한 번 다시 보냄 */
  function setCard(key, id, marks) {
    var m = isObj(marks) ? marks : {};
    return stuCall('lec_set_card', { p_key: k0(key), p_set: id || null, p_marks: m }).then(function (r) {
      var m1 = {}, two = false, k;
      if (!r || r.ok || r.err !== 'input') return r;
      for (k in m) {
        if (!has(m, k)) continue;
        if (m[k] === 2) { two = true; m1[k] = 1; } else m1[k] = m[k];
      }
      if (!two) return r;
      return stuCall('lec_set_card', { p_key: k0(key), p_set: id || null, p_marks: m1 });
    });
  }
  function setTest(key, id) { return stuCall('lec_set_test', { p_key: k0(key), p_set: id || null }); }
  function setDue(key) { return stuCall('lec_set_due', { p_key: k0(key) }); }
  function setAns(key, tryId, i, v) {
    return stuCall('lec_set_ans', { p_key: k0(key), p_try: tryId || null, p_i: Math.floor(+i || 0), p_v: str(v) });
  }
  function recBegin(key, id, k, mime, bytes, ms) {
    return stuCall('lec_rec_begin', {
      p_key: k0(key), p_set: id || null, p_k: str(k), p_mime: str(mime),
      p_bytes: Math.max(0, Math.floor(+bytes || 0)), p_ms: Math.max(0, Math.round(+ms || 0))
    });
  }
  function recDone(key, recId) { return stuCall('lec_rec_done', { p_key: k0(key), p_id: recId || null }); }
  /* 녹음 파일 올리기(Storage · 비공개 버킷 lec-rec · 표가 열린 이름으로 한 번 · 덮어쓰기 없음) */
  function recPut(path, blob, mime) {
    var base = recBase(mime), size = blob && typeof blob.size === 'number' ? blob.size : 0, M = w.LecMock, p;
    if (pv()) return Promise.resolve({ ok: false, err: 'preview' });
    if (!base) return Promise.resolve({ ok: false, err: 'mime' });
    if (!REC_PATH.test(str(path))) return Promise.resolve({ ok: false, err: 'upload', status: 0 });
    if (w.__lecOffline) return Promise.resolve({ ok: false, err: 'network' });
    if (Lec.DEMO) {
      if (!M || typeof M.recPut !== 'function') return Promise.resolve({ ok: false, err: 'upload', status: 0 });
      try { p = M.recPut(str(path), size, base); } catch (e0) { return Promise.resolve({ ok: false, err: 'upload', status: (e0 && e0.status) || 0 }); }
      return Promise.resolve(p).then(function () {
        return w.__lecOffline ? { ok: false, err: 'network' } : { ok: true };
      }, function (e) {
        return { ok: false, err: 'upload', status: (e && e.status) || 0 };
      });
    }
    if (typeof w.fetch !== 'function') return Promise.resolve({ ok: false, err: 'network' });
    try {
      p = w.fetch(Lec.SUPA_URL + '/storage/v1/object/lec-rec/' + str(path), {
        method: 'POST',
        headers: { 'apikey': Lec.SUPA_KEY, 'Authorization': 'Bearer ' + Lec.SUPA_KEY, 'Content-Type': base, 'x-upsert': 'false' },
        body: blob,
        cache: 'no-store'
      });
    } catch (e1) { return Promise.resolve({ ok: false, err: 'network' }); }
    return Promise.resolve(p).then(function (r) {
      return r && r.ok ? { ok: true } : { ok: false, err: 'upload', status: (r && r.status) || 0 };
    }, function () {
      return { ok: false, err: 'network' };
    }).then(null, function () { return { ok: false, err: 'upload', status: 0 }; });
  }
  /* 녹음 보내기 = 표 받기 → 올리기 → 냄(앞 단계 err 그대로) */
  function recSend(key, id, k, blob, mime, ms) {
    var base = recBase(mime), size = blob && typeof blob.size === 'number' ? blob.size : 0;
    if (pv()) return Promise.resolve({ ok: false, err: 'preview' });
    if (!base) return Promise.resolve({ ok: false, err: 'mime' });
    return recBegin(key, id, k, base, size, ms).then(function (b) {
      if (!b || !b.ok) return b || { ok: false, err: 'error' };
      return recPut(b.path, blob, base).then(function (u) {
        if (!u.ok) return u;
        return recDone(key, b.id);
      });
    }).then(null, function () { return { ok: false, err: 'error' }; });
  }

  /* ------------------------------------------------------------- 선생님(관리자): 서버 부르기 */

  function staffGone(e) {
    if (typeof Lec.rngGoneErr === 'function') return Lec.rngGoneErr(e);
    return !!e && (e.status === 404 || e.code === 'PGRST202' || e.code === 'PGRST205' || e.code === '42883' || e.code === '42P01');
  }
  /* call(fn, args) = 선생님 화면의 서버 부르기(Promise) · 늘 {ok, …} · 실패 = 'old' | 'network' | 'error' | 'forbidden' … */
  function staffCall(call, fn, args) {
    var p;
    if (typeof call !== 'function') return Promise.resolve({ ok: false, err: 'network' });
    try { p = call(fn, args); } catch (e0) { return Promise.resolve(staffGone(e0) ? { ok: false, err: 'old' } : { ok: false, err: 'error' }); }
    return Promise.resolve(p).then(function (r) {
      return isObj(r) ? r : { ok: false, err: 'error' };
    }, function (e) {
      if (staffGone(e)) return { ok: false, err: 'old' };
      return { ok: false, err: e && e.message === 'network' ? 'network' : 'error' };
    }).then(null, function () { return { ok: false, err: 'error' }; });
  }
  function setListStaff(call) {
    return staffCall(call, 'lec_set_list_staff', {}).then(function (r) {
      return r.ok && !isArr(r.items) ? { ok: false, err: 'error' } : r;
    });
  }
  function setGet(call, id) { return staffCall(call, 'lec_set_get', { p_set: id || null }); }
  /* o = {id(null = 새로), kind, title, cls, on('YYYY-MM-DD' | null = 오늘 · 고칠 때 null = 그대로), items, pick(0부터 · 구문만)} */
  function setPut(call, o) {
    var cls = [], i;
    o = isObj(o) ? o : {};
    if (isArr(o.cls)) { for (i = 0; i < o.cls.length; i += 1) cls.push(str(o.cls[i])); }
    return staffCall(call, 'lec_set_put', {
      p_id: o.id || null, p_kind: str(o.kind), p_title: str(o.title), p_cls: cls, p_on: o.on || null,
      p_items: isArr(o.items) ? o.items : [], p_pick: isArr(o.pick) ? o.pick : null
    });
  }
  function setHide(call, id, on) { return staffCall(call, 'lec_set_hide', { p_set: id || null, p_hidden: !!on }); }
  /* 시험 문항 수(단어 · 문법 · 11-18): n = 1 ~ 300 · null · '' = 전부 · 옛 서버(함수 없음) = 'old' */
  function setTestN(call, id, n) {
    var v = (n == null || n === '') ? null : Math.floor(+n);
    if (v !== null && !(v >= 1 && v <= 300)) return Promise.resolve({ ok: false, err: 'input' });
    return staffCall(call, 'lec_set_testn', { p_set: id || null, p_n: v });
  }
  function setDel(call, id) { return staffCall(call, 'lec_set_del', { p_set: id || null }); }
  function setStaff(call, id) { return staffCall(call, 'lec_set_staff', { p_set: id || null }); }
  /* 종이 «쌓인 오답 시험»: 반 하나(id)의 학생마다 쌓인 단어 · 문법 오답 · rows = [{sid, sname, n, items:[{k, s, kd, t, f, q, a, pt, z}]}] */
  function setWrongStaff(call, cls) {
    return staffCall(call, 'lec_set_wrong_staff', { p_cls: str(cls) }).then(function (r) {
      return r.ok && !isArr(r.rows) ? { ok: false, err: 'error' } : r;
    });
  }
  function recMark(call, id, mark, why) {
    return staffCall(call, 'lec_rec_mark', { p_id: id || null, p_mark: str(mark), p_why: Math.floor(+why || 0) });
  }
  /* 지난 녹음 정리(원장님이 선생님 화면을 열 때 한 번): 지울 목록 → 파일 100개씩 del → del 이 돌려준 이름(지운 파일)의 줄만 gone ·
     이름이 없거나 f false(파일이 이미 없음) = 지울 파일 없이 줄만 · del 실패(reject) · 빈손([]) = 그 줄은 두고 다음에 ·
     del(paths) = 지운 것 [{name}] 또는 [이름] 으로 풀림 · 오류면 reject(class-admin DA.recDel = rq) · 서버도 파일이 남은 줄은 둠(keep) */
  function recClean(call, del) {
    return staffCall(call, 'lec_rec_expired', {}).then(function (r) {
      var items, groups = [], ids = [], i;
      if (!r.ok) return r;
      items = isArr(r.items) ? r.items : [];
      if (!items.length) return { ok: true, n: 0 };
      if (typeof del !== 'function') return { ok: false, err: 'error' };
      for (i = 0; i < items.length; i += 100) groups.push(items.slice(i, i + 100));
      function step(j) {
        var g, paths = [], pid = {}, x, p, id, pa;
        if (j >= groups.length) return Promise.resolve();
        g = groups[j];
        for (x = 0; x < g.length; x += 1) {
          if (!isObj(g[x]) || !str(g[x].id)) continue;
          id = str(g[x].id);
          pa = str(g[x].path);
          if (!pa || g[x].f === false) { ids.push(id); continue; }
          if (!Object.prototype.hasOwnProperty.call(pid, '#' + pa)) { pid['#' + pa] = []; paths.push(pa); }
          pid['#' + pa].push(id);
        }
        if (!paths.length) return step(j + 1);
        try { p = del(paths); } catch (e0) { p = Promise.reject(e0); }
        return Promise.resolve(p).then(function (res) {
          var y, nm;
          if (!isArr(res)) return;
          for (y = 0; y < res.length; y += 1) {
            nm = typeof res[y] === 'string' ? res[y] : (isObj(res[y]) ? str(res[y].name) : '');
            if (nm && Object.prototype.hasOwnProperty.call(pid, '#' + nm)) {
              ids = ids.concat(pid['#' + nm]);
              delete pid['#' + nm];
            }
          }
        }, function () { /* 이 묶음은 다음에 */ })
          .then(function () { return step(j + 1); });
      }
      return step(0).then(function () {
        if (!ids.length) return { ok: true, n: 0 };
        return staffCall(call, 'lec_rec_gone', { p_ids: ids }).then(function (g) {
          return g.ok ? { ok: true, n: +g.n || 0 } : g;
        });
      });
    }).then(null, function () { return { ok: false, err: 'error' }; });
  }

  var api = {
    SET_LIM: SET_LIM, REC_MAX_BYTES: REC_MAX_BYTES, REC_MAX_MS: REC_MAX_MS, REC_WHY: REC_WHY,
    SET_RS: SET_RS, SET_ERR: SET_ERR,
    setParse: setParse, setDetect: setDetect, setOpts: setOpts, gramParts: gramParts, setWarn: setWarn, setItemsFrom: setItemsFrom,
    setKeys: setKeys, setNeed: setNeed, setNorm: setNorm, setVars: setVars, setAlts: setAlts, setMatch: setMatch,
    setFm: setFm, setFirst: setFirst, setRetake: setRetake, setChoices: setChoices, setTq: setTq, setDraw: setDraw,
    setMark: setMark, setMemo: setMemo, setInDue: setInDue, setDueOn: setDueOn, setDeck: setDeck, setNextQ: setNextQ,
    setPrint: setPrint, sayParts: sayParts, sayText: sayText, sayVoice: sayVoice,
    recMime: recMime, recBase: recBase,
    spkCan: spkCan, spkWords: spkWords, spkScore: spkScore, spkNeed: spkNeed, setDiff: setDiff, setOrder: setOrder,
    setHome: setHome, setItems: setItems, setCard: setCard, setTest: setTest, setDue: setDue, setAns: setAns,
    recBegin: recBegin, recDone: recDone, recPut: recPut, recSend: recSend,
    setListStaff: setListStaff, setGet: setGet, setPut: setPut, setHide: setHide, setTestN: setTestN, setDel: setDel, setStaff: setStaff,
    setWrongStaff: setWrongStaff, recMark: recMark, recClean: recClean
  };
  for (var name in api) { if (has(api, name)) Lec[name] = api[name]; }
})(window);
