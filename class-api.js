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
        }, 120);
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
    parseRunner: parseRunner,
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
