/* 히즈클래스 세트 붙여 넣기 읽기(선생님 화면 «세트» 붙여 넣기 · 미리 보기 · 저장할 문항 · 문법 줄 다듬기)
   class-admin.html 만 읽음(class-api.js 바로 다음 · 학생 화면 · 흉내 서버는 안 읽음) · 11-20 class-api.js 에서 글자 그대로 옮김(학생 첫 화면 파일 줄이기)
   이름은 그대로 window.Lec 에 붙임: SET_RS · setParse · setDetect · setWarn · setItemsFrom · setGramFix · setPt · setCut
   class-api.js 에 남는 것: 채점(setNorm · setAlts · setMatch) · setOpts · gramParts · 종이 낱말 나눔(words) · Lec.clen · Lec.left
   바깥 요청 없음 · ES5 */
(function (w) {
  'use strict';

  var Lec = w.Lec;
  if (!Lec) return;

  function str(v) { return v == null ? '' : String(v); }
  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function sp(s) { return str(s).replace(/^ +| +$/g, ''); }          /* 서버 btrim(보통 칸만) */
  function clen(s) { return Lec.clen ? Lec.clen(str(s)) : str(s).length; }
  /* 붙여 넣은 글을 알아본 까닭(위젯 글 그대로) · forced = 선생님이 종류를 고름 */
  var SET_RS = {
    voc: '한 줄이 한두 낱말이라 어휘로 읽었어요',
    gu: '한 줄이 문장이라 구문으로 읽었어요',
    gram: '괄호 안에 / 보기나 [ ]가 있어 문법으로 읽었어요',
    forced: '선생님이 고른 종류로 읽어요'
  };
  function countRe(re, s) {
    var n = 0, m;
    re.lastIndex = 0;
    while ((m = re.exec(s)) !== null) { n += 1; if (m[0] === '') re.lastIndex += 1; }
    return n;
  }

  /* 엑셀 · 구글 시트 복사 꼴(TSV)로 줄 나누기: 따옴표로 시작하는 칸은 닫는 따옴표(뒤가 탭 · 줄 끝 · 글 끝)까지 줄을 넘어 읽고 "" → " ·
     엑셀이 따옴표로 감싸는 칸(안에 줄바꿈 · 탭 · 따옴표가 있음)만 그렇게 읽음 · 닫는 따옴표가 없거나 뒤에 글이 붙으면 따옴표 그대로(위젯 글)
     → [{s: 줄 글, c: 칸들 | null(탭도 따옴표 칸도 없는 줄), nl: 칸 안 줄바꿈이 있음}] · 칸 안 줄바꿈은 그 칸에 그대로 둠(이을지는 setParse 가 정함 · 11-20) */
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
            v = q.replace(/[ \t]*\n[ \t]*/g, '\n').replace(/\t/g, ' ');
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
  /* 번호 범위(11-20 붙여 넣기 ②): «41~42» «18-19» «41 ~ 42» · 한글 낱말 찾기(한글 음절 · 자모) */
  var SET_RNG = '\\d{1,4}\\s*[~\\u301C\\uFF5E\\-\\u2013]\\s*\\d{1,4}';
  var SET_NUMR = new RegExp('^(' + SET_RNG + ')[.)]?$'),
    SET_NUMW = new RegExp('^(\\d{1,4}|' + SET_RNG + ')[.)]\\s+(\\S.*)$'),
    SET_NUMK = new RegExp('^(\\d{1,4}|' + SET_RNG + ')[.)]?\\s+(\\S.*)$'),
    SET_KO = /[가-힣ㄱ-ㆎ]/,
    SET_KOW = /\s(?=\S*[가-힣ㄱ-ㆎ])/,
    SET_KOEN = /^[A-Za-z '’\-().\/~～]+$/;
  /* 탭 없는 한 칸 줄(trim 한 것) → «영어 | 뜻»(11-20 좁힘): 앞 번호(«001 » «41~42 »)를 떼고 한글이 든 첫 낱말 앞에서 나누되
     영어 쪽이 영문자 · 띄어쓰기 · ' ’ - ( ) . / ~ 만(영문자 하나 이상 · 숫자 없음)이고 첫 한글 글자 앞까지 «| · :»가 없을 때만 · 아니면 null ·
     영어 끝에 따로 떨어진 «~»(«～»)는 뜻이 «~»로 시작하지 않으면 뜻 머리로 옮김(«versus ~ 대(對)» → versus | ~ 대(對)) */
  function setKoSplit(s) {
    var n = '', k = SET_NUMK.exec(s), m, h, a, b;
    if (k) { n = k[1]; s = k[2]; }
    m = SET_KOW.exec(s);
    if (!m) return null;
    a = s.slice(0, m.index).trim();
    b = s.slice(m.index + 1).trim();
    h = s.slice(0, s.search(SET_KO));
    if (h.length <= m.index || /[|·:]/.test(h) || !SET_KOEN.test(a) || !/[A-Za-z]/.test(a)) return null;
    if ((k = / ([~～])$/.exec(a)) && !/^[~～]/.test(b)) { a = a.slice(0, k.index).trim(); b = k[1] + ' ' + b; }
    return { n: n, c: [a, b] };
  }
  /* 빈 줄 뺌 · 탭이 있으면 탭(엑셀 따옴표 칸은 tsvLines) · 없으면 빈칸 둘 이상이나 « | » · 칸 trim ·
     칸이 둘 이상이고 첫 칸이 번호(1~4자리 · «1.» «1)» 꼴도)면 번호 · 칸이 셋 이상이고 첫 칸이 번호 범위(«41~42» «18-19»)여도 번호 ·
     첫 칸이 «1. 낱말» 꼴이면 번호를 떼어 냄 · 칸 안 줄바꿈은 빈칸 하나로 잇고 그 줄은 nl: true ·
     탭도 두 칸 띄움도 없는 줄(PDF 단어장 복사)은 setKoSplit 꼴일 때만 두 칸으로 나눔(그 줄은 ko: true) ·
     다만 탭 없는 줄(빈 줄 뺌) 가운데 70% 이상이 그 꼴일 때만 · 아니면 탭 없는 줄은 모두 예전처럼 한 칸 ·
     opt.raw = 칸만 나눔(줄바꿈 그대로 · 번호 · 한글 나눔 없음 · 칸 이름 줄 읽기용) */
  function setParse(text, opt) {
    var out = [], lines = tsvLines(text), raw = !!(opt && opt.raw), i, s, c, n, j, m, r, ko, tl = 0, tk = 0, useKo;
    for (i = 0; !raw && i < lines.length; i += 1) {
      s = lines[i].s;
      if (!s.trim() || s.indexOf('\t') >= 0) continue;
      tl += 1;
      c = lines[i].c ? null : s.split(/ {2,}| \| /);
      if (c && c.length === 1 && setKoSplit(c[0].trim())) tk += 1;
    }
    useKo = tl > 0 && tk * 10 >= tl * 7;
    for (i = 0; i < lines.length; i += 1) {
      s = lines[i].s;
      if (!s.trim()) continue;
      c = lines[i].c ? lines[i].c.slice() : s.split(/ {2,}| \| /);
      for (j = 0; j < c.length; j += 1) c[j] = raw ? c[j].trim() : c[j].replace(/[ \t]*\n[ \t]*/g, ' ').trim();
      n = '';
      ko = !!(useKo && !lines[i].c && c.length === 1 && (m = setKoSplit(c[0])));
      if (ko) { n = m.n; c = m.c; }
      else if (raw) n = '';
      else if (c.length > 1 && (m = /^(\d{1,4})[.)]?$/.exec(c[0]))) { n = m[1]; c.shift(); }
      else if (c.length > 2 && (m = SET_NUMR.exec(c[0]))) { n = m[1]; c.shift(); }
      else if (c.length > 1 && (m = SET_NUMW.exec(c[0]))) { n = m[1]; c[0] = m[2]; }
      r = { n: n, c: c };
      if (lines[i].nl) r.nl = true;
      if (ko) r.ko = true;
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
    var bad = {}, msgs = [], i, c, n, a, s, o, pg, bk, bs, m, x, lo, seen = {}, key, cnt = {}, ng = 0, am = 0, re;
    rows = isArr(rows) ? rows : [];
    function hit(name) { cnt[name] = (cnt[name] || 0) + 1; }
    for (i = 0; i < rows.length; i += 1) {
      c = cols(rows[i]);
      n = str(rows[i] && rows[i].n);
      if (rows[i] && rows[i].nl) hit('nl');
      if (rows[i] && rows[i].ko) hit('ko');
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
        o = Lec.setOpts(s);
        pg = countRe(/[(]([^()]*\/[^()]*)[)]/g, s);
        re = /\[([^\]]*)\]/g;
        bk = countRe(re, s);
        bs = countRe(/\[[^\]]*\/[^\]]*\]/g, s);
        /* 11-20: 문제 칸이 비면 «문제 빈칸» · 고르기 괄호가 여럿인데 답을 괄호 차례로 못 나눈 줄(setGramFix 가 그대로 둔 줄) = 까닭 따로 */
        if (!s) { bad[i] = 'ng'; hit('gs'); }
        else if (a && pg + bk > 1 && bs === bk) { bad[i] = 'ng'; hit('gm'); }
        else if (!a || (o && o.indexOf(a) < 0)) { bad[i] = 'ng'; hit('ga'); }
        else if (pg + bk === 0) { bad[i] = 'ng'; hit('g0'); }
        else if (pg + bk > 1) { bad[i] = 'ng'; hit('g2'); }
        else if (pg === 1 && (o.length < 2 || o.length > 5 || o.indexOf('') >= 0)) { bad[i] = 'ng'; hit('go'); }
        else if (bk === 1 && (m = /\[([^\]]*)\]/.exec(s)) && sp(m[1]) === '') { bad[i] = 'ng'; hit('gb'); }
        else if (clen(s) > 300 || clen(a) > 100 || clen(x) > 300 || clen(n) > 8) { bad[i] = 'ng'; hit('long'); }
        else {
          /* 포인트 40자 넘음 = 줄은 살리고 그 칸만 40자로(setItemsFrom) · 노란 줄 */
          if (clen(cell(c, 3)) > 40) { bad[i] = 'am'; hit('pc'); }
          if (x.length > 60) { bad[i] = 'am'; hit('gx'); }
        }
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
      msg('gs', 'ng', '문제 빈칸');
      msg('ga', 'ng', '답이 없거나 보기에 없어요');
      msg('gm', 'ng', '괄호가 여럿이면 답도 괄호 차례로 적어요');
      msg('g0', 'ng', '( / )나 [ ]가 없어요');
      msg('g2', 'ng', '( / )나 [ ]는 한 줄에 하나만');
      msg('go', 'ng', '보기는 둘에서 다섯');
      msg('gb', 'ng', '[ ] 안이 비었어요');
    }
    msg('long', 'ng', '너무 긴 칸');
    if (kind === 'gram') msg('pc', 'am', '포인트 40자 넘는 칸은 잘랐어요');
    if (kind === 'gram') msg('gx', 'am', '해설이 폰에서 세 줄 넘어요');
    /* 엑셀 칸 안 줄바꿈(Alt+Enter)은 한 칸으로 읽고 빈칸 하나로 이음(줄은 빼지 않음 · 알려만 줌) */
    msg('nl', 'am', '칸 안 줄바꿈은 한 줄로 이었어요');
    msg('ko', 'am', '탭 없는 줄은 한글 앞에서 나눴어요');
    return { bad: bad, ng: ng, am: am, msgs: msgs };
  }
  /* 칸을 n자(코드 포인트)로 자름 · 끝 빈칸 뺌(서버 btrim 과 같게) */
  function setCut(s, n) {
    s = str(s);
    return clen(s) > n ? (Lec.left ? Lec.left(s, n) : s.slice(0, n)).replace(/\s+$/, '') : s;
  }
  /* 저장할 문항: setWarn 이 'ng' 로 본 줄만 뺌(같은 판정) · 빈 칸은 '' · 문법 포인트는 40자까지(넘는 글은 자름 · 11-20) */
  function setItemsFrom(kind, rows) {
    var w0 = setWarn(kind, rows), out = [], i, c, n;
    rows = isArr(rows) ? rows : [];
    for (i = 0; i < rows.length; i += 1) {
      if (w0.bad[i] === 'ng') continue;
      c = cols(rows[i]);
      n = str(rows[i] && rows[i].n);
      if (kind === 'voc') out.push({ n: n, w: cell(c, 0), m: cell(c, 1) });
      else if (kind === 'gu') out.push({ n: n, e: cell(c, 0), t: cell(c, 1), p: cell(c, 2) });
      else if (kind === 'gram') out.push({ n: n, s: cell(c, 0), a: cell(c, 1), x: cell(c, 2), p: setCut(cell(c, 3), 40) });
    }
    return out;
  }
  /* 문법 포인트 이름: 어법 최빈출 목록과 띄어쓰기 · 빗금 · 가운뎃점만 다르면 목록 이름 · 아니면 칸 글 그대로(문장에서 짐작하지 않음) */
  var SET_PT = ['수일치', '관계사', '분사', '대명사 / 재귀대명사', 'that / those', '대동사', '병렬', '도치', '수동태', '전치사 / 접속사', '형용사 / 부사',
    '5형식 목적격보어 to부정사', '사역동사 / 지각동사 목적격보어', 'to 전치사 / to부정사', '간접의문문 어순', 'if / whether'];
  var SET_PT_ALIAS = { '전치사접속사구분': '전치사 / 접속사', '5형식목적격보어의to부정사': '5형식 목적격보어 to부정사', '사역동사지각동사의목적격보어': '사역동사 / 지각동사 목적격보어' };
  function ptKey(s) { return str(s).toLowerCase().replace(/[\s\/·・,.()]+/g, ''); }
  function setPt(p) {
    var k = ptKey(p), i;
    if (!k) return str(p);
    for (i = 0; i < SET_PT.length; i += 1) { if (ptKey(SET_PT[i]) === k) return SET_PT[i]; }
    return has(SET_PT_ALIAS, k) ? SET_PT_ALIAS[k] : str(p);
  }
  /* 문제 글의 괄호 묶음: ( / ) = 고르기 · [ ] 안에 / 가 있으면 고르기(워크북 꼴) · [ ] 안에 / 가 없으면 고쳐 쓰기 · / 없는 ( ) 는 보통 글 */
  function gramGroups(s) {
    var re = /\(([^()]*)\)|\[([^\]]*)\]/g, out = [], m;
    while ((m = re.exec(s)) !== null) {
      if (m[1] != null) { if (m[1].indexOf('/') >= 0) out.push({ i: m.index, e: m.index + m[0].length, b: false, t: m[1], c: true }); }
      else out.push({ i: m.index, e: m.index + m[0].length, b: true, t: m[2], c: m[2].indexOf('/') >= 0 && !/[()]/.test(m[2]) });
    }
    return out;
  }
  function gramOpts(t) {
    var o = str(t).split('/'), i;
    for (i = 0; i < o.length; i += 1) o[i] = sp(o[i]);
    return o;
  }
  /* 답 칸을 괄호 수대로: «① is ② who» «(A) is (B) who» → 쉼표 → 빗금 → 가운뎃점 · ; · | → 빈칸 · 나눈 답이 그 괄호 보기에 모두 있을 때만 */
  function gramAns(a, ch) {
    var seps = [/\s*(?:[①-⑳]|\([A-Ea-e1-9]\))\s*/, /\s*,\s*/, /\s*\/\s*/, /\s*[·;|]\s*/, /\s+/], i, p, j, ok, q;
    for (i = 0; i < seps.length; i += 1) {
      p = str(a).split(seps[i]);
      q = [];
      for (j = 0; j < p.length; j += 1) { p[j] = sp(p[j].replace(/^(?:\d[.)])\s*/, '')); if (p[j]) q.push(p[j]); }
      if (q.length !== ch.length) continue;
      ok = true;
      for (j = 0; j < q.length; j += 1) { if (gramOpts(ch[j].t).indexOf(q[j]) < 0) { ok = false; break; } }
      if (ok) return q;
    }
    return null;
  }
  function rowWith(r, c) {
    var o = { n: str(r && r.n), c: c };
    if (r && r.nl) o.nl = true;
    if (r && r.ko) o.ko = true;
    return o;
  }
  /* 문법 줄 다듬기(11-20 붙여 넣기 ② · 관리 화면이 문법일 때만): 워크북 꼴 «[ A / B ]» = 고르기 «( A / B )»(괄호 글자만 바꿈) ·
     한 줄에 고르기 괄호가 여럿 = 답(«is, who» · «goes / eats» · «① is ② who»)을 괄호 차례로 나눠 괄호마다 한 줄 · 다른 괄호 자리는 그 답으로 채움 ·
     답을 괄호 수대로 못 나누면 줄 그대로(setWarn 'gm') · 고쳐 쓰기 [낱말] 이 섞인 줄도 그대로 · 포인트 = setPt ·
     서버 · SQL 그대로(서버가 이미 읽는 ( / ) 꼴로 바꿔 보냄 · 문항 칸은 n s a x p 그대로) */
  function setGramFix(rows) {
    var out = [], i, r, c, s, g, ch, rw, j, k, pos, t, nc, a;
    rows = isArr(rows) ? rows : [];
    for (i = 0; i < rows.length; i += 1) {
      r = rows[i];
      c = cols(r).slice();
      if (c.length > 3) c[3] = setPt(c[3]);
      s = cell(c, 0);
      g = gramGroups(s);
      ch = []; rw = 0;
      for (j = 0; j < g.length; j += 1) { if (g[j].c) ch.push(g[j]); else rw += 1; }
      if (rw || !ch.length) { out.push(rowWith(r, c)); continue; }
      if (ch.length === 1) {
        if (ch[0].b) c[0] = s.slice(0, ch[0].i) + '(' + ch[0].t + ')' + s.slice(ch[0].e);
        out.push(rowWith(r, c));
        continue;
      }
      a = gramAns(sp(cell(c, 1)), ch);
      if (!a) { out.push(rowWith(r, c)); continue; }
      for (j = 0; j < ch.length; j += 1) {
        t = ''; pos = 0;
        for (k = 0; k < ch.length; k += 1) {
          t += s.slice(pos, ch[k].i) + (k === j ? '(' + ch[k].t + ')' : a[k]);
          pos = ch[k].e;
        }
        nc = c.slice();
        nc[0] = t + s.slice(pos);
        nc[1] = a[j];
        out.push(rowWith(r, nc));
      }
    }
    return out;
  }

  var api = {
    SET_RS: SET_RS,
    setParse: setParse, setDetect: setDetect, setWarn: setWarn, setItemsFrom: setItemsFrom,
    setGramFix: setGramFix, setPt: setPt, setCut: setCut
  };
  for (var name in api) { if (has(api, name)) Lec[name] = api[name]; }
})(window);
