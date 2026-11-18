/* 히즈클래스 종이 시험지 판 짜기(선생님 화면 «세트» · 원장님만 · 인쇄 단추를 처음 누를 때 읽음)
   ① 한 시험지: 고른 어휘 · 문법 · 구문 세트를 한 판에 이어 붙임 · 학생마다 이름 찍은 시험지 + 정답지 한 벌(맨 끝)
   ② 쌓인 오답 시험지: 학생마다 히즈클래스에 쌓인 어휘 · 문법 오답만 · 정답지도 학생마다(맨 뒤에 같은 차례)
   정답지 = 시험지와 같은 판(쪽 · 자리 · 높이 같음)에 답만 얹음(1:1) · 해설은 넣지 않음
   A4 한 쪽 794×1123px(96dpi) · 안쪽 10mm · 문항 높이는 숨은 iframe(인쇄 문서와 같은 CSS · 글꼴)에서 잼
   한 판이 2쪽 넘으면 줄 사이를 좁힌 판도 재 보고 장 수가 줄 때만 씀 · 마지막 덩이는 열 높이를 고르게
   11-18 원장님: 머리 = 진짜 로고 그림(assets/his-logo.png 그대로) · 시험지 · 정답지 따로 인쇄(only) · 둘 머리에 같은 «시험 코드» ·
   어휘 4열 · 부분마다 문항 수 n(모음에서 씨앗으로 n개 뽑아 섞은 차례 · 같은 씨앗 = 같은 시험)
   바깥 요청 · 글꼴 내려받기 없음 · ES5 */
(function (G) {
  'use strict';

  var MM = 3.7795, PW = 794, PH = 1123, CT = 37.8, CW = 718.4, H = 277, GAP = 26, LH = 18.9;
  /* 판 높이(mm): n 보통 · f 좁힌 판 · HD 머리 · PH 부분 머리 · FT 바닥글 · END 끝 줄 */
  var KM = {
    n: { HD: 24.8, PH: 10.8, FT: 9.3, END: 6.9, voc: 8.7, c: 11, r: 18.4, gu: { mean: 18.4, write: 18.4, blank: 16.8, scr: 25.5 } },
    f: { HD: 24.8, PH: 10.8, FT: 9.3, END: 6.9, voc: 7.7, c: 9.4, r: 16.8, gu: { mean: 16.8, write: 16.8, blank: 15.2, scr: 23.9 } }
  };
  var RN = ['Ⅰ', 'Ⅱ', 'Ⅲ'];
  var FONT = '"Noto Sans KR","Malgun Gothic",sans-serif';
  var KN = { voc: '어휘', gram: '문법', gu: '구문' };
  var ORD = ['voc', 'gram', 'gu'];
  var FM = {
    voc: [['ko', '뜻 쓰기'], ['en', '영어 쓰기'], ['mix', '섞어서']],
    gram: [['cr', '괄호 고르기 · 고쳐 쓰기']],
    gu: [['mean', '의미 쓰기'], ['write', '영작'], ['blank', '빈칸'], ['scr', '어순 배열']]
  };
  var COLS = { voc: [1, 2, 3, 4], gram: [1, 2], gu: [1, 2] };
  var DEF_COL = { voc: 2, gram: 1, gu: 1 };
  var END = '종이 점수는 히즈클래스에 들어가지 않아요. 히즈클래스에서 다른 날 두 번 맞히면 빠져요.';
  var FISH = '<svg width="16.67" height="8.09" viewBox="0 0 848 412" style="margin-right:7.27px;vertical-align:0" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M314 0l56 0l41 5l37 9l52 20l46 24l53 37l21 19l2 0l8 9l2 0l45 45l2 0l22-22l0-2l36-37l0-2l6-5l0-2l5-4l0-2l5-4l0-2l30-35l23-32l42-2l-16 43l-27 53l-32 50l-3 2l-15 22l-16 17l2 5l8 8l20 29l3 2l32 51l19 37l24 59l-45-1l-10-19l-3-2l-20-29l-5-4l-3-6l-26-29l0-2l-7-6l0-2l-7-6l0-2l-7-6l0-2l-8-7l0-2l-27-28l-6 3l-37 38l-2 0l-23 22l-62 44l-23 12l-1 2l-14 6l-1 2l-35 16l-28 10l-40 10l-35 5l-53 0l-25-3l-33-7l-30-9l-31-12l-30-15l-45-29l-3-4l-22-16l-6-7l-2 0l-40-39l0-2l-9-8l0-2l-7-6l0-2l-23-26l-5-9l-8-9l0-3l27-32l0-2l5-4l0-2l12-12l0-2l17-17l0-2l37-36l2 0l22-20l5-2l18-14l46-25l36-15l40-12zM336 31l-35 3l-36 8l-41 15l-33 17l-46 32l-21 19l-2 0l-6 7l-2 0l-51 50l0 2l-21 22l9 8l0 2l15 15l0 2l48 48l2 0l0 2l2 0l5 6l2 0l5 6l16 11l3 4l32 22l36 19l26 11l37 11l44 7l49 0l35-5l37-10l50-21l1-2l14-6l1-2l21-11l47-34l19-18l2 0l11-12l2 0l50-52l-2-5l-27-28l0-2l-46-43l-2 0l-10-10l-2 0l-19-16l-8-4l-2-3l-38-23l-47-21l-44-13l-36-6zM105 192l9 0l8 7l0 12l-8 7l-10 0l-7-7l0-11l2-4z"/></svg>';
  var PILL = '<div class="lpa" style="left:' + f2(CT + CW - 74) + 'px;top:21px;width:74px;height:15px;background:#1F1F1F;color:#fff;' +
    'border-radius:8px;font-size:10.5px;line-height:15px;text-align:center;font-weight:500">정답지</div>';
  /* 로고 = 저장소 원본 그림 그대로(880×445 투명 PNG · 다시 그리지 않음) · 높이 42 · 인쇄 문서(새 창 · 숨은 틀)에서도 깨지지 않게 이 쪽 주소 기준 절대 주소 */
  var LOGO_P = 'assets/his-logo.png', LOGO_H = 42, LOGO_W = LOGO_H * 880 / 445, LOGO_U = '';
  function logoUrl() {
    var a;
    if (LOGO_U) return LOGO_U;
    try { a = document.createElement('a'); a.href = LOGO_P; LOGO_U = a.href || LOGO_P; } catch (e) { LOGO_U = LOGO_P; }
    return LOGO_U;
  }
  /* 시험 코드: 시험지와 정답지가 같은 판인지 맞춰 보는 넉 자(헷갈리는 0 O 1 I L 2 Z 5 S 8 B 뺌) · 같은 글 = 같은 코드 */
  var CODE_CH = 'ACDEFGHJKMNPQRTUVWXY34679';
  function code(t) {
    var s = str(t), h = 7, g = 3, i, c, o = '';
    for (i = 0; i < s.length; i += 1) {
      c = s.charCodeAt(i);
      h = (h * 31 + c) % 2147483647;
      g = (g * 131 + c + 7) % 1000003;
    }
    h = (h + g * 7919) % 2147483647;
    for (i = 0; i < 4; i += 1) { o += CODE_CH.charAt(h % CODE_CH.length); h = Math.floor(h / CODE_CH.length) + (i + 1) * g; }
    return o;
  }

  function str(v) { return v === null || v === undefined ? '' : String(v); }
  function trim(v) { return str(v).replace(/^\s+|\s+$/g, ''); }
  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function isObj(v) { return !!v && typeof v === 'object' && !isArr(v); }
  function esc(t) { return str(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function f2(v) { return (+v).toFixed(2); }
  function colW(c) { return (CW - (c - 1) * GAP) / c; }
  function shOf(duplex) { return function (p) { return duplex ? Math.ceil(p / 2) : p; }; }
  function sheets(p, duplex) { return shOf(duplex)(p); }
  function fmtName(kd, f) {
    var a = FM[kd] || [], i;
    for (i = 0; i < a.length; i += 1) { if (a[i][0] === f) return a[i][1]; }
    return a.length ? a[0][1] : '';
  }

  /* ---------------------------------------------------------------- CSS */
  /* full = 인쇄 문서(쪽 = A4 · 화면에선 회색 바탕 위 쪽마다 그림자) · 아니면 관리자 화면 미리 보기 */
  function css(full) {
    var c = '.lpP,.lpQ{font-family:' + FONT + ';color:#000;font-size:13.5px;line-height:1.4;text-align:left;font-weight:400;font-style:normal;' +
        'letter-spacing:0;word-spacing:0;word-break:normal;overflow-wrap:normal;white-space:normal;text-transform:none;text-indent:0;font-kerning:auto}' +
      '.lpP,.lpP *,.lpQ,.lpQ *{box-sizing:content-box}' +
      '.lpP{position:relative;width:794px;height:1123px;background:#fff;overflow:hidden}' +
      '.lpQ{position:absolute;left:0;top:0;width:794px;visibility:hidden}' +
      '.lpP b{font-weight:500}' +
      '.lpa{position:absolute}' +
      '.lpi{position:relative;box-sizing:border-box}' +
      '.lpn{position:absolute;left:0;top:4px;font-weight:500}' +
      '.lpt{padding-left:34px}' +
      '.lpv{display:flex;flex-wrap:wrap;align-items:flex-end;column-gap:10px;padding-bottom:6px}' +
      '.lpvn{font-weight:500;min-width:24px}' +
      '.lpvl{height:20px;margin-bottom:3px;border-bottom:1px solid #666;position:relative;min-width:0}' +
      '.lpw{position:absolute;left:34px;right:0;border-bottom:1px solid #666}' +
      '.lpb{display:inline-block;border-bottom:1px solid #000;position:relative}' +
      '.lpc{display:flex;flex-wrap:wrap;gap:4px 5px;margin-top:5px}' +
      '.lpc span{border:1px solid #888;border-radius:3px;padding:0 6px;line-height:18.9px}' +
      '.lpans{position:absolute;font-weight:500;background:#E2E2E2;border-radius:2px;padding:0 5px;white-space:nowrap;font-size:13px;line-height:1.35}' +
      '.lpab{position:absolute;left:34px;right:0;font-weight:500;font-size:13px;line-height:27px}' +
      '.lpab span{background:#E2E2E2;border-radius:2px;padding:1px 5px;-webkit-box-decoration-break:clone;box-decoration-break:clone}' +
      '.lpok{outline:1.6px solid #000;outline-offset:1px;border-radius:3px;background:#E2E2E2}' +
      '.lptag{position:absolute;right:0;font-size:11px;line-height:1;color:#444}';
    if (full) {
      return '@page{size:A4;margin:0}html,body{margin:0;padding:0}' +
        'body{background:#fff;-webkit-print-color-adjust:exact;print-color-adjust:exact}' + c +
        '.lptb{position:sticky;top:0;z-index:3;display:flex;gap:12px;align-items:center;padding:8px 14px;background:#F2F2F2;' +
          'border-bottom:1px solid #CCC;font:13px ' + FONT + ';color:#000}' +
        '.lptb button{margin-left:auto;font:inherit;padding:6px 14px;border:1px solid #000;border-radius:6px;background:#fff;color:#000;cursor:pointer}' +
        '.lpP{width:210mm;height:297mm}' +
        '@media screen{body{background:#E5E5E5}.lpP{margin:12px auto;box-shadow:0 1px 4px rgba(0,0,0,.2)}}' +
        '@media print{.lptb{display:none}.lpP{margin:0;box-shadow:none;break-after:page;page-break-after:always}' +
          '.lpP:last-child{break-after:auto;page-break-after:auto}}';
    }
    return c +
      '.lpth{position:relative;background:#fff;border:1px solid #8A8A8A;overflow:hidden;cursor:pointer;box-sizing:border-box;padding:0}' +
      '.lpth .lpP,.lpbv .lpP{position:absolute;left:0;top:0;transform-origin:0 0}' +
      '.lpth.on{outline:2px solid #1F1F1F;outline-offset:1px}' +
      '.lpbv{position:relative;background:#fff;border:1px solid #8A8A8A;overflow:hidden;box-sizing:border-box;max-width:100%}' +
      '.lpsdv{position:absolute;top:0;bottom:0;border-left:2px solid #1F1F1F}';
  }
  /* 관리자 화면에 미리 보기 CSS 한 번 */
  function ensureCss(doc) {
    var d = doc || document, s;
    if (d.getElementById('lp-css')) return;
    s = d.createElement('style');
    s.id = 'lp-css';
    s.textContent = css(false);
    (d.head || d.documentElement).appendChild(s);
  }

  /* ---------------------------------------------------------------- 재기 */
  /* 숨은 iframe: 인쇄 문서와 같은 CSS · 글꼴(관리자 화면 CSS 가 섞이지 않음) · 한 번 만들어 다시 씀 */
  var MT = null;
  function meter() {
    var ok = false, f, d;
    if (MT) {
      try { ok = !!(MT.f.parentNode && MT.f.contentWindow && MT.f.contentWindow.document === MT.doc && MT.doc.getElementById('lpq')); } catch (e) { ok = false; }
      if (ok) return MT;
      try { if (MT.f.parentNode) MT.f.parentNode.removeChild(MT.f); } catch (e1) {}
    }
    f = document.createElement('iframe');
    f.setAttribute('aria-hidden', 'true');
    f.tabIndex = -1;
    f.style.cssText = 'position:fixed;left:-10000px;top:0;width:820px;height:300px;border:0;visibility:hidden;pointer-events:none';
    document.body.appendChild(f);
    d = f.contentWindow.document;
    d.open();
    d.write('<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8"><style>' + css(true) + '</style></head><body><div class="lpQ" id="lpq"></div></body></html>');
    d.close();
    MT = { f: f, doc: d, Q: d.getElementById('lpq'), cx: null };
    return MT;
  }
  function tw(t, f) {
    var m = meter();
    if (!m.cx) { try { m.cx = m.doc.createElement('canvas').getContext('2d'); } catch (e) { m.cx = null; } }
    if (!m.cx) return str(t).length * 7.5;
    m.cx.font = f + ' ' + FONT;
    return m.cx.measureText(str(t)).width;
  }

  /* ---------------------------------------------------------------- 문항 하나 */
  /* 문항 꼴 k: v 어휘(q 보기 · a 답) · c 괄호 고르기 · r 고쳐 쓰기(tag 문법 포인트) ·
     gm 구문 의미 · gw 영작 · gb 빈칸(ws 낱말 · b 빈칸 · bw 너비 · p 붙은 문장부호) · gs 어순 배열(ch 조각) · aw = 답 너비 */
  function wlines(it, W) { return Math.max(1, Math.ceil(it.aw * 1.35 / (W - 42))); }
  function chooseHTML(q, a, key) {
    var s = str(q), m = /\(([^()]*\/[^()]*)\)/.exec(s), o, i, t, hit = -1, al = trim(a), out = [];
    if (!m) return esc(s);
    o = m[1].split('/');
    for (i = 0; i < o.length; i += 1) o[i] = trim(o[i]);
    if (key) {
      for (i = 0; i < o.length; i += 1) { if (o[i] === al) { hit = i; break; } }
      if (hit < 0) { for (i = 0; i < o.length; i += 1) { if (o[i].toLowerCase() === al.toLowerCase()) { hit = i; break; } } }
    }
    for (i = 0; i < o.length; i += 1) {
      t = '<span' + (i === hit ? ' class="lpok"' : '') + '>' + esc(o[i]) + '</span>';
      out.push(t);
    }
    return esc(s.slice(0, m.index)) + '( ' + out.join(' / ') + ' )' + esc(s.slice(m.index + m[0].length));
  }
  function an(key, t, s) { return key ? '<span class="lpans" style="' + s + '">' + esc(t) + '</span>' : ''; }
  function itemHTML(it, W, mk, key) {
    var w = f2(W), num = '<span class="lpn">' + it.no + '</span>', top = '<div class="lpi" style="width:' + w + 'px;padding:4px 0 ',
      L, ln = '', ab, i, s, x, tg;
    if (it.k === 'v') {
      return '<div class="lpi lpv" style="width:' + w + 'px;min-height:' + f2(mk.voc * MM) + 'px"><span class="lpvn">' + it.no + '</span>' +
        '<span' + (it.qb ? ' style="font-weight:500"' : '') + '>' + esc(it.q) + '</span>' +
        '<span class="lpvl" style="flex:1 1 ' + (it.lb ? '100%' : f2(Math.max(72, it.aw * 1.25 + 12)) + 'px') + '">' + an(key, it.a, 'left:6px;bottom:2px') + '</span></div>';
    }
    if (it.k === 'c') {
      tg = key && it.tag ? '<span class="lptag" style="' + (tw(it.q, '13.5px') + 34 + tw(it.tag, '11px') + 18 <= W ? 'top:9px' : 'bottom:1px') + '">' +
        esc(it.tag) + '</span>' : '';
      return top + f2(mk.c * MM - 4 - LH) + 'px">' + num + '<div class="lpt">' + chooseHTML(it.q, it.a, key) + '</div>' + tg + '</div>';
    }
    if (it.k === 'r') {
      return top + f2(mk.r * MM - 4 - LH) + 'px">' + num + '<div class="lpt">' + esc(it.q) + '</div><span class="lpw" style="bottom:9px"></span>' +
        an(key, it.a, 'left:40px;bottom:11px') + (key && it.tag ? '<span class="lptag" style="bottom:13px">' + esc(it.tag) + '</span>' : '') + '</div>';
    }
    if (it.k === 'gb') {
      s = [];
      for (i = 0; i < it.ws.length; i += 1) {
        x = it.ws[i];
        s.push(x.b ? '<span class="lpb" style="width:' + f2(x.bw) + 'px">' + an(key, x.w, 'left:50%;bottom:1px;transform:translateX(-50%)') + '</span>' + esc(x.p)
                   : esc(x.w));
      }
      return top + f2(mk.gu.blank * MM - 4 - LH) + 'px">' + num + '<div class="lpt">' + s.join(' ') + '</div></div>';
    }
    L = wlines(it, W);
    for (i = 0; i < L; i += 1) ln += '<span class="lpw" style="bottom:' + (9 + i * 27) + 'px"></span>';
    ab = key ? '<div class="lpab" style="bottom:10px;height:' + (L * 27) + 'px"><span>' + esc(it.a) + '</span></div>' : '';
    if (it.k === 'gs') {
      s = '';
      for (i = 0; i < it.ch.length; i += 1) s += '<span>' + esc(it.ch[i]) + '</span>';
      return top + f2(mk.gu.scr * MM - 4 - LH - 5 - 20.9 + (L - 1) * 27) + 'px">' + num + '<div class="lpt">' + esc(it.q) + '<div class="lpc">' + s + '</div></div>' +
        ln + ab + '</div>';
    }
    return top + f2(mk.gu[it.f] * MM - 4 - LH + (L - 1) * 27) + 'px">' + num + '<div class="lpt">' + esc(it.q) + '</div>' + ln + ab + '</div>';
  }
  function baseH(it, mk) {
    if (it.k === 'v') return mk.voc * MM;
    if (it.k === 'c') return mk.c * MM;
    if (it.k === 'r') return mk.r * MM;
    if (it.k === 'gb') return mk.gu.blank * MM;
    return (it.k === 'gs' ? mk.gu.scr : mk.gu[it.f]) * MM;
  }
  function fbH(it, W, mk) { return baseH(it, mk) + (it.aw !== undefined && it.k !== 'v' ? (wlines(it, W) - 1) * 27 : 0); }
  function measure(items, W, mk) {
    var Q = meter().Q, h = [], c, i, v, s = '';
    for (i = 0; i < items.length; i += 1) s += itemHTML(items[i], W, mk, false);
    Q.innerHTML = s;
    c = Q.children;
    if (lbMix(items, c)) {   /* 11-19: 어휘 답 줄이 단어 옆 · 아래로 섞이면 그 부분은 모두 아래(4열에서 짧은 단어만 옆에 붙어 열이 들쭉날쭉하던 것) */
      for (i = 0, s = ''; i < items.length; i += 1) s += itemHTML(items[i], W, mk, false);
      Q.innerHTML = s;
      c = Q.children;
    }
    for (i = 0; i < items.length; i += 1) {
      v = c[i] ? c[i].getBoundingClientRect().height : 0;
      h.push(v > 1 ? v : fbH(items[i], W, mk));
    }
    Q.innerHTML = '';
    return h;
  }
  /* 어휘 칸: 답 줄(맨 끝)이 번호 아래에서 시작하면 «아래» · 옆과 아래가 섞인 부분이면 모두 아래로(it.lb · 그 판 내내 · 좁힌 판도 같음) */
  function lbMix(items, c) {
    var i, n, l, up = 0, dn = 0;
    for (i = 0; i < items.length; i += 1) {
      if (items[i].k !== 'v' || !c[i]) continue;
      n = c[i].firstChild; l = c[i].lastChild;
      if (!n || !l || n === l) continue;
      if (l.getBoundingClientRect().top >= n.getBoundingClientRect().bottom - 0.5) dn += 1; else up += 1;
    }
    if (!dn || !up) return false;
    for (i = 0; i < items.length; i += 1) if (items[i].k === 'v') items[i].lb = 1;
    return true;
  }

  /* ---------------------------------------------------------------- 판 흘리기 */
  /* 부분마다 열 c · 열 먼저 채우고 다음 열 · 남은 것이 이 쪽에 다 들어가면 열 높이를 고르게(반으로 나눠 찾기) ·
     부분 머리 + 첫 문항이 안 들어가면 새 쪽 · brk = 부분마다 새 쪽 · end = 맨 끝 줄(오답 시험지) */
  function flow(parts, hs, mk, brk, end) {
    var hd = mk.HD * MM, ph = mk.PH * MM, av = (H - mk.FT) * MM, P = [[]], used = [], pg = P[0], y = hd,
      pi, p, h, n, W, j, R, r, rh, ci, c, yy, q, eh, lo, hi, t, m;
    function np() { pg = []; P.push(pg); y = 0; }
    function fill(cap) {
      var cols = [], k = j, cc, s, a;
      for (cc = 0; cc < p.c; cc += 1) {
        s = 0; a = k;
        while (k < n && s + h[k] <= cap + 0.01) { s += h[k]; k += 1; }
        cols.push([a, k, s]);
      }
      return { cols: cols, k: k };
    }
    for (pi = 0; pi < parts.length; pi += 1) {
      p = parts[pi]; h = hs[pi]; n = h.length; W = colW(p.c); used[pi] = ph;
      if (brk && pi > 0 && pg.length) np();
      if (y + ph + (n ? h[0] : 0) > av + 0.01 && pg.length) np();
      pg.push({ t: 'ph', y: y, p: p });
      y += ph;
      j = 0;
      while (j < n) {
        R = av - y;
        r = fill(R);
        if (r.k === j) {
          if (y > 0) { np(); continue; }
          r = { cols: [[j, j + 1, h[j]]], k: j + 1 };
        } else if (r.k === n && p.c > 1) {
          lo = 0; hi = R;
          for (t = 0; t < 36; t += 1) { m = (lo + hi) / 2; if (fill(m).k === n) hi = m; else lo = m; }
          r = fill(hi);
        }
        rh = 0;
        for (ci = 0; ci < r.cols.length; ci += 1) rh = Math.max(rh, r.cols[ci][2]);
        for (ci = 0; ci < r.cols.length; ci += 1) {
          c = r.cols[ci]; yy = y;
          for (q = c[0]; q < c[1]; q += 1) { pg.push({ t: 'it', x: ci * (W + GAP), y: yy, w: W, p: p, q: q }); yy += h[q]; }
        }
        y += rh; used[pi] += rh; j = r.k;
        if (j < n) np();
      }
    }
    if (end) {
      eh = mk.END * MM;
      if (y + eh > av + 0.01 && pg.length) np();
      pg.push({ t: 'end', y: y });
    }
    return { P: P, used: used };
  }
  /* 보통 판 → 2쪽 넘으면 좁힌 판도 재서 장 수가 줄 때만 씀(fit = 원래 쪽 수) */
  function layOne(parts, brk, end, sh) {
    var W = [], hn = [], hf = [], A, B, r, i;
    for (i = 0; i < parts.length; i += 1) { W.push(colW(parts[i].c)); hn.push(measure(parts[i].items, W[i], KM.n)); }
    A = flow(parts, hn, KM.n, brk, end);
    r = { mk: KM.n, F: A, fit: 0, hs: hn };
    if (A.P.length > 1) {
      for (i = 0; i < parts.length; i += 1) hf.push(measure(parts[i].items, W[i], KM.f));
      B = flow(parts, hf, KM.f, brk, end);
      if (sh(B.P.length) < sh(A.P.length)) r = { mk: KM.f, F: B, fit: A.P.length, hs: hf };
    }
    return r;
  }
  /* 칸이 좁아 쓰는 줄이 늘어난 문항 수(부분마다) */
  function wraps(lay, parts) {
    var o = [], i, q, n;
    for (i = 0; i < parts.length; i += 1) {
      n = 0;
      for (q = 0; q < parts[i].items.length; q += 1) { if (lay.hs[i][q] > baseH(parts[i].items[q], lay.mk) + 1) n += 1; }
      o.push(n);
    }
    return o;
  }
  /* 부분마다 차지한 쪽(약) */
  function usedPages(lay) {
    var av = (H - lay.mk.FT) * MM, o = [], i;
    for (i = 0; i < lay.F.used.length; i += 1) o.push(lay.F.used[i] / av);
    return o;
  }

  /* ---------------------------------------------------------------- 쪽 그리기 */
  function phHTML(t, p, mk) {
    return '<div class="lpa" style="left:' + CT + 'px;top:' + f2(t) + 'px;width:' + CW + 'px;height:' + f2(mk.PH * MM - 6) + 'px;border-bottom:1px solid #000;' +
      'display:flex;align-items:flex-end;justify-content:space-between;padding-bottom:3px;box-sizing:border-box">' +
      '<span><span style="font-size:15px;font-weight:500">' + RN[p.i] + ' ' + esc(p.nm) + '</span>&nbsp;&nbsp;<span style="font-size:12px">' + esc(p.fn) + '</span></span>' +
      '<span style="font-size:13px"><span style="display:inline-block;width:56px;border-bottom:1px solid #666"></span> / ' + p.n + '</span></div>';
  }
  function foot(right, mk) {
    return '<div class="lpa" style="left:' + CT + 'px;top:' + f2(CT + (H - mk.FT) * MM) + 'px;width:' + CW + 'px;height:' + f2(mk.FT * MM) + 'px;' +
      'border-top:2px solid #000;display:flex;justify-content:space-between;align-items:center;font-size:11px;font-weight:500">' +
      '<span style="color:#3A3A3C;white-space:nowrap">' + FISH + 'Excellence in English, HIS</span>' +
      '<span style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-left:16px">' + esc(right) + '</span></div>';
  }
  function pageHTML(F, pi, mk, key, o) {
    var pg = F.P[pi], h = pi === 0 ? o.head(key) : '', i, e, t;
    for (i = 0; i < pg.length; i += 1) {
      e = pg[i]; t = CT + e.y;
      if (e.t === 'ph') h += phHTML(t, e.p, mk);
      else if (e.t === 'it') h += '<div class="lpa" style="left:' + f2(CT + e.x) + 'px;top:' + f2(t) + 'px">' + itemHTML(e.p.items[e.q], e.w, mk, key) + '</div>';
      else if (e.t === 'end') h += '<div class="lpa" style="left:' + CT + 'px;top:' + f2(t + 9) + 'px;width:' + CW + 'px;font-size:11px;color:#333">' + esc(o.end) + '</div>';
    }
    return h + (key && pi > 0 ? PILL : '') + foot(o.foot(pi, F.P.length, key), mk);
  }
  /* 머리 띠: 로고(흰 상자 안 원본 그림) · 제목 · 작은 줄 · 시험 코드(cd · 시험지와 정답지에 같은 넉 자) · 오른쪽 상자(시험지 = 이름 · 합계 / 정답지 = 검은 상자) */
  function headHTML(title, sub, key, keyLine, nm, tot, cd) {
    var bw = 214, bx = CT + CW - 16 - bw, cx = bx - 10 - 56, tm = f2((cd ? cx - 10 : bx - 12) - 186);
    return '<div class="lpa" style="left:' + CT + 'px;top:' + CT + 'px;width:' + CW + 'px;height:82px;background:#E6E6E6;border-radius:8px"></div>' +
      '<div class="lpa" style="left:50px;top:' + f2(CT + 16) + 'px;width:112px;height:50px;background:#fff;border-radius:6px"></div>' +
      '<img class="lpa lplogo" src="' + esc(logoUrl()) + '" alt="HIS" style="left:' + f2(50 + (112 - LOGO_W) / 2) + 'px;top:' + f2(CT + 20) + 'px;width:' + f2(LOGO_W) + 'px;height:' + LOGO_H +
        'px;max-width:none;max-height:none;margin:0;padding:0;border:0">' +
      '<div class="lpa" style="left:186px;top:55px;width:' + tm + 'px;font-size:21px;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + esc(title) + '</div>' +
      '<div class="lpa" style="left:186px;top:89px;width:' + tm + 'px;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + esc(sub) + '</div>' +
      (cd
        ? '<div class="lpa lpcode" style="left:' + f2(cx) + 'px;top:52px;width:56px;height:56px;background:#fff;border-radius:6px;text-align:center;line-height:1.2">' +
            '<span style="display:block;margin-top:9px;font-size:10.5px;color:#333">시험 코드</span>' +
            '<span class="lpcd" style="display:block;margin-top:3px;font-size:16px;font-weight:500;letter-spacing:1px">' + esc(cd) + '</span></div>'
        : '') +
      (key
        ? '<div class="lpa" style="left:' + f2(bx) + 'px;top:52px;width:' + bw + 'px;height:56px;background:#1F1F1F;color:#fff;border-radius:6px;padding:7px 12px;box-sizing:border-box;line-height:1.3">' +
            '<span style="display:block;font-size:20px;font-weight:500">정답지</span>' +
            '<span style="display:block;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + esc(keyLine) + '</span></div>'
        : '<div class="lpa" style="left:' + f2(bx) + 'px;top:52px;width:' + bw + 'px;height:56px;background:#fff;border-radius:6px;padding:6px 12px;box-sizing:border-box;font-size:13px;line-height:1.65">' +
            '<span style="display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">이름&nbsp; ' +
              (nm ? '<b>' + esc(nm) + '</b>' : '<span style="display:inline-block;width:130px;border-bottom:1px solid #666;vertical-align:-3px"></span>') + '</span>' +
            '<span style="display:block">합계&nbsp; <span style="display:inline-block;width:96px;border-bottom:1px solid #666"></span> / ' + tot + '</span></div>');
  }
  function subOf(parts, tot, pre) {
    var a = [], i;
    for (i = 0; i < parts.length; i += 1) a.push(parts[i].nm);
    return pre + ' · ' + a.join(' · ') + ' · ' + tot + '문항';
  }
  function pagesOf(R, key, o) {
    var out = [], i;
    for (i = 0; i < R.lay.F.P.length; i += 1) out.push(pageHTML(R.lay.F, i, R.lay.mk, key, o));
    return out;
  }
  /* 쪽 안 문항 번호 범위(미리 보기 글): 어휘 1~24 · 문법 25~32 · one 참 = 한 문항이면 번호 하나(② 위젯과 같음) */
  function rangeCap(R, pi, one) {
    var pg = R.lay.F.P[pi] || [], rg = {}, i, e, no, r, out = [];
    for (i = 0; i < pg.length; i += 1) {
      e = pg[i];
      if (e.t !== 'it') continue;
      no = e.p.items[e.q].no;
      r = rg[e.p.kd] || (rg[e.p.kd] = [no, no]);
      r[0] = Math.min(r[0], no); r[1] = Math.max(r[1], no);
    }
    for (i = 0; i < ORD.length; i += 1) { if (rg[ORD[i]]) out.push(KN[ORD[i]] + ' ' + rg[ORD[i]][0] + (one && rg[ORD[i]][1] === rg[ORD[i]][0] ? '' : '~' + rg[ORD[i]][1])); }
    return out.join(' · ');
  }
  function docHTML(title, pages, bar) {
    var s = '', i;
    for (i = 0; i < pages.length; i += 1) s += '<div class="lpP">' + pages[i] + '</div>';
    return '<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8"><title>' + esc(title) + '</title><style>' + css(true) + '</style></head><body>' +
      '<div class="lptb"><b>' + esc(title) + '</b><span>' + esc(bar) + '</span><button type="button" onclick="print()">인쇄 · PDF로 저장</button></div>' +
      s + '</body></html>';
  }

  /* ---------------------------------------------------------------- ① 한 시험지 */
  function vocItem(no, show, ans) { return { k: 'v', no: no, q: show, qb: 1, a: ans, aw: tw(ans, '500 13px') }; }
  /* f = 서버가 정한 꼴('c' 고르기 · 'r' 고쳐 쓰기 · 없으면 괄호로 가림) · 고르기는 괄호가 있어야 그림 */
  function gramItem(no, s, a, p, f) {
    var k = f !== 'r' && /\(([^()]*\/[^()]*)\)/.test(str(s)) ? 'c' : 'r';
    return { k: k, no: no, q: str(s), a: str(a), tag: trim(p) };
  }
  function blankWords(wl) {
    var o = [], i, x, m;
    for (i = 0; i < wl.length; i += 1) {
      x = wl[i];
      m = /^(.*?)([.,!?;:"')\]]*)$/.exec(str(x.w));
      if (x.b && m && m[1]) o.push({ b: 1, w: m[1], p: m[2], bw: Math.max(56, tw(m[1], '13.5px') * 1.3 + 12) });
      else o.push({ w: str(x.w) });
    }
    return o;
  }
  function chips(en) {
    var a = str(en).split(' '), o = [], i, t;
    for (i = 0; i < a.length; i += 1) {
      t = a[i].replace(/^["“”(]+|[.,!?;:"“”)]+$/g, '');
      if (t) o.push(t);
    }
    o.sort(function (x, y) { return x.length - y.length || x.localeCompare(y); });
    return o;
  }
  /* 빈칸 자리를 늘 같게(미리 보기 = 인쇄 · 다시 그려도 그대로): 세트 id 로 씨앗을 정한 작은 난수 */
  function seeded(t) {
    var h = 7, s = str(t), i;
    for (i = 0; i < s.length; i += 1) h = (h * 31 + s.charCodeAt(i)) % 2147483647;
    if (h <= 0) h += 2147483646;
    return function () { h = (h * 16807) % 2147483647; return (h - 1) / 2147483646; };
  }
  /* 0 … n-1 을 씨앗 난수로 섞어 앞 m개(같은 씨앗 = 같은 문항 · 같은 차례 · m 을 줄이면 앞에서 자름) */
  function pickN(n, m, rnd) {
    var o = [], i, j, t;
    for (i = 0; i < n; i += 1) o.push(i);
    for (i = n - 1; i > 0; i -= 1) {
      j = Math.floor(rnd() * (i + 1));
      if (!(j >= 0 && j <= i)) j = i;
      t = o[i]; o[i] = o[j]; o[j] = t;
    }
    return o.slice(0, m);
  }
  /* sel = [{kd, set, fmt, col, a · b(세트 안 차례 번호 1부터 · 없으면 전부), n(문항 수 · 0 · 비움 = 전부), seed}] → 어휘 → 문법 → 구문 차례 · 번호는 이어서(빈 번호 없음)
     n 이 모음(a~b 안 문항)보다 적으면 모음을 씨앗으로 섞어 앞 n개를 섞인 차례로 · n 이 모음 이상이면 전부(지금과 같음 · 거절 안 함) */
  function partsCombined(sel) {
    var Lc = G.Lec, parts = [], no = 1, oi, si, s, kd, set, list, pos, items, i, it, pr, en, ko, f, a, b, all, pool, m, rk, x, l2, p2;
    for (oi = 0; oi < ORD.length; oi += 1) {
      s = null;
      for (si = 0; si < sel.length; si += 1) { if (sel[si] && sel[si].kd === ORD[oi]) { s = sel[si]; break; } }
      if (!s || !isObj(s.set)) continue;
      kd = s.kd; set = s.set; items = [];
      list = []; pos = []; all = [];
      for (i = 0; i < (isArr(set.items) ? set.items.length : 0); i += 1) { if (isObj(set.items[i])) all.push(set.items[i]); }
      a = Math.max(1, Math.floor(+s.a || 1)); b = Math.min(all.length, Math.floor(+s.b || all.length));
      for (i = a - 1; i < b; i += 1) { list.push(all[i]); pos.push(i); }
      pool = list.length; m = Math.floor(+s.n || 0); rk = '';
      if (m > 0 && m < pool) {
        rk = '|' + str(s.seed) + '|' + m;
        x = pickN(pool, m, seeded(str(s.seed) + '|' + kd + '|' + str(set.id) + '|' + a + '|' + b));
        l2 = []; p2 = [];
        for (i = 0; i < x.length; i += 1) { l2.push(list[x[i]]); p2.push(pos[x[i]]); }
        list = l2; pos = p2;
      }
      if (kd === 'voc') {
        /* 섞어서 = 세트 안 차례가 홀수 번째면 뜻 쓰기 · 짝수 번째면 영어 쓰기(범위를 줄여도 같은 문항은 같은 꼴) */
        for (i = 0; i < list.length; i += 1) {
          f = s.fmt === 'mix' ? (pos[i] % 2 === 0 ? 'ko' : 'en') : (s.fmt === 'en' ? 'en' : 'ko');
          items.push(f === 'ko' ? vocItem(no + i, str(list[i].w), str(list[i].m)) : vocItem(no + i, str(list[i].m), str(list[i].w)));
        }
      } else if (kd === 'gram') {
        for (i = 0; i < list.length; i += 1) items.push(gramItem(no + i, list[i].s, list[i].a, list[i].p));
      } else {
        f = has(FM_GU, s.fmt) ? s.fmt : 'mean';
        pr = f === 'blank' && Lc && Lc.setPrint ? Lc.setPrint({ kind: 'gu', items: list }, 'blank', { shuffle: false, rnd: seeded(str(set.id) + '|' + a + '|' + b + rk) }) : null;
        for (i = 0; i < list.length; i += 1) {
          en = Lc && Lc.sayText ? str(Lc.sayText(list[i].e)) : str(list[i].e).replace(/\s*\/\s*/g, ' ');
          ko = str(list[i].t);
          if (f === 'mean') items.push({ k: 'gm', f: f, no: no + i, q: en, a: ko, aw: tw(ko, '13.5px') });
          else if (f === 'write') items.push({ k: 'gw', f: f, no: no + i, q: ko, a: en, aw: tw(en, '13.5px') });
          else if (f === 'blank') items.push({ k: 'gb', f: f, no: no + i, ws: blankWords(pr && pr.q[i] && isArr(pr.q[i].words) ? pr.q[i].words : wordsOnly(en)) });
          else items.push({ k: 'gs', f: f, no: no + i, q: ko, ch: chips(en), a: en, aw: tw(en, '13.5px') });
        }
      }
      if (!items.length) continue;
      parts.push({ kd: kd, i: parts.length, c: colOk(kd, s.col), nm: KN[kd], fn: fmtName(kd, kd === 'gram' ? 'cr' : s.fmt), items: items, n: items.length,
                   title: str(set.title), pool: pool, rnd: !!rk });
      no += items.length;
    }
    return parts;
  }
  var FM_GU = { mean: 1, write: 1, blank: 1, scr: 1 };
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function wordsOnly(en) {
    var a = str(en).split(' '), o = [], i;
    for (i = 0; i < a.length; i += 1) { if (a[i]) o.push({ w: a[i], b: i > 0 && i % 3 === 1 }); }
    return o;
  }
  function colOk(kd, c) {
    var a = COLS[kd] || [1];
    c = Math.floor(+c || 0);
    return a.indexOf(c) >= 0 ? c : (DEF_COL[kd] || 1);
  }
  /* ① 판: opt = {brk 부분마다 새 쪽, duplex 양면} */
  function combined(sel, opt) {
    var o = opt || {}, parts = partsCombined(isArr(sel) ? sel : []), tot = 0, lay, i;
    for (i = 0; i < parts.length; i += 1) tot += parts[i].n;
    if (!tot) return { parts: parts, tot: 0, pn: 0, lay: null };
    lay = layOne(parts, !!o.brk, false, shOf(!!o.duplex));
    return { parts: parts, lay: lay, tot: tot, pn: lay.F.P.length, fit: lay.fit, wraps: wraps(lay, parts), used: usedPages(lay) };
  }
  /* ① 쪽들: cfg = {title, date, code(시험 코드)} · nm = 이름 줄('' = 빈칸) · key = 정답지 */
  function combinedPages(R, cfg, nm, key) {
    var sub = subOf(R.parts, R.tot, '히즈어학원');
    return pagesOf(R, key, {
      head: function (k) { return headHTML(cfg.title, sub, k, '선생님용 · 시험지와 1:1', nm, R.tot, cfg.code); },
      end: '',
      foot: function (pi, pn, k) { return (k ? '정답지 · 선생님용 · ' : (nm ? nm + ' · ' : '')) + cfg.date + (pn > 1 ? ' · ' + (pi + 1) + '/' + pn : ''); }
    });
  }
  /* ① 인쇄 문서: cfg = {title, date, names(이름 줄 · '' = 빈칸), duplex, bar, code, only('test' 시험지만 · 'key' 정답지만 · 없으면 둘 다)} ·
     시험지 = 학생마다(양면이면 홀수 쪽 뒤 빈 면) · 정답지 = 한 벌(반 전체가 같은 시험) */
  function combinedDoc(R, cfg) {
    var pages = [], names = isArr(cfg.names) ? cfg.names : [], mk = R.lay.mk, odd = !!cfg.duplex && R.pn % 2 === 1, only = cfg.only, i, j, tp;
    if (only !== 'key') {
      for (i = 0; i < names.length; i += 1) {
        tp = combinedPages(R, cfg, str(names[i]), false);
        for (j = 0; j < tp.length; j += 1) pages.push(tp[j]);
        if (odd) pages.push(foot((names[i] ? names[i] + ' · ' : '') + '빈 면', mk));
      }
    }
    if (only !== 'test') {
      tp = combinedPages(R, cfg, '', true);
      for (j = 0; j < tp.length; j += 1) pages.push(tp[j]);
      if (odd) pages.push(PILL + foot('정답지 · 빈 면', mk));
    }
    return docHTML(only === 'key' ? cfg.title + ' · 정답지' : cfg.title, pages, cfg.bar || '');
  }
  /* ① 장 수: 시험지 = 학생 n명 · 정답지 = 한 벌 */
  function combinedSheets(R, n, duplex) {
    var s = R && R.pn ? sheets(R.pn, duplex) : 0;
    return { test: n * s, key: s, total: (n + 1) * s };
  }

  /* ---------------------------------------------------------------- ② 쌓인 오답 시험지 */
  function ymdAdd(ymd, d) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str(ymd)), t;
    if (!m) return '';
    t = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]) + d * 86400000);
    return t.getUTCFullYear() + '-' + ('0' + (t.getUTCMonth() + 1)).slice(-2) + '-' + ('0' + t.getUTCDate()).slice(-2);
  }
  /* 범위: rg 'all' 쌓인 오답 전부(기본) · 'd7' 최근 7일에 틀린 것(z = 마지막으로 틀린 날 · 오늘 포함 7일) ·
     d7 에 하나도 없으면 인쇄를 막지 않게 전부(fb 참) */
  function wrongPick(items, rg, today) {
    var all = isArr(items) ? items : [], cut, o = [], i;
    if (rg !== 'd7' || !all.length) return { items: all, fb: false };
    cut = ymdAdd(today, -6);
    for (i = 0; i < all.length; i += 1) { if (cut && str(all[i].z) >= cut) o.push(all[i]); }
    return o.length ? { items: o, fb: false } : { items: all, fb: true };
  }
  function wrongCount(items) {
    var v = 0, g = 0, i;
    for (i = 0; i < items.length; i += 1) { if (items[i].kd === 'voc') v += 1; else g += 1; }
    return { voc: v, gram: g };
  }
  /* items = 서버 줄(오래된 오답 먼저) · 어휘(뜻 보고 영어 쓰기) → 문법(고르기 먼저 · 고쳐 쓰기 다음) */
  function partsWrong(items, col) {
    var vi = [], gc = [], gr = [], parts = [], no = 1, i, it, a;
    col = col || {};
    for (i = 0; i < items.length; i += 1) {
      it = items[i];
      if (!isObj(it)) continue;
      if (it.kd === 'voc') vi.push(it);
      else if (it.f !== 'r' && /\(([^()]*\/[^()]*)\)/.test(str(it.q))) gc.push(it);
      else gr.push(it);
    }
    if (vi.length) {
      a = [];
      for (i = 0; i < vi.length; i += 1) a.push(vocItem(no + i, str(vi[i].q), str(vi[i].a)));
      parts.push({ kd: 'voc', i: parts.length, c: colOk('voc', col.voc), nm: KN.voc, fn: '영어 쓰기', items: a, n: a.length });
      no += a.length;
    }
    gc = gc.concat(gr);
    if (gc.length) {
      a = [];
      for (i = 0; i < gc.length; i += 1) a.push(gramItem(no + i, gc[i].q, gc[i].a, gc[i].pt, gc[i].f));
      parts.push({ kd: 'gram', i: parts.length, c: colOk('gram', col.gram), nm: KN.gram, fn: fmtName('gram', 'cr'), items: a, n: a.length });
    }
    return parts;
  }
  /* ② 학생 한 명 판 */
  function wrong(items, col, duplex) {
    var parts = partsWrong(isArr(items) ? items : [], col), tot = 0, lay, i;
    for (i = 0; i < parts.length; i += 1) tot += parts[i].n;
    if (!tot) return { parts: parts, tot: 0, pn: 0, lay: null };
    lay = layOne(parts, false, true, shOf(!!duplex));
    return { parts: parts, lay: lay, tot: tot, pn: lay.F.P.length, fit: lay.fit, wraps: wraps(lay, parts) };
  }
  /* ② 쪽들: nm = «학생 이름 · 반» · date · cd = 시험 코드 */
  function wrongPages(R, nm, date, key, cd) {
    var sub = subOf(R.parts, R.tot, '히즈어학원 · 히즈클래스');
    return pagesOf(R, key, {
      head: function (k) { return headHTML('쌓인 오답 시험', sub, k, nm, nm, R.tot, cd); },
      end: END,
      foot: function (pi, pn, k) { return nm + (k ? ' · 정답지' : '') + ' · ' + date + (pn > 1 ? ' · ' + (pi + 1) + '/' + pn : ''); }
    });
  }
  /* ② 장 수: 시험지는 학생마다 새 장 · 정답지는 맨 뒤 같은 차례(양면: 1쪽 정답지는 앞뒤로 이어 · 2쪽 넘는 정답지는 앞면부터) */
  function wrongSheets(Rs, duplex) {
    var ts = 0, ks = 0, i, pn;
    for (i = 0; i < Rs.length; i += 1) {
      pn = Rs[i].pn;
      if (!pn) continue;
      ts += sheets(pn, duplex);
      if (duplex && pn > 1 && ks % 2 === 1) ks += 1;
      ks += pn;
    }
    return { test: ts, key: duplex ? Math.ceil(ks / 2) : ks, total: ts + (duplex ? Math.ceil(ks / 2) : ks) };
  }
  /* ② 인쇄 문서: rows = [{nm, R}](체크한 학생 차례) · cfg = {date, duplex, bar, code, only('test' 시험지만 · 'key' 정답지만 · 없으면 둘 다)} ·
     정답지 = 학생마다 이름 찍힘 · 시험지와 같은 차례 */
  function wrongDoc(rows, cfg) {
    var pages = [], ks = 0, duplex = !!cfg.duplex, mk = KM.n, only = cfg.only, i, j, r, tp;
    for (i = 0; i < rows.length; i += 1) {
      r = rows[i];
      if (!r.R || !r.R.pn) continue;
      mk = r.R.lay.mk;
      if (only === 'key') continue;
      tp = wrongPages(r.R, r.nm, cfg.date, false, cfg.code);
      for (j = 0; j < tp.length; j += 1) pages.push(tp[j]);
      if (duplex && r.R.pn % 2 === 1) pages.push(foot(r.nm + ' · 빈 면', r.R.lay.mk));
    }
    for (i = 0; i < rows.length && only !== 'test'; i += 1) {
      r = rows[i];
      if (!r.R || !r.R.pn) continue;
      if (duplex && r.R.pn > 1 && ks % 2 === 1) { pages.push(PILL + foot('정답지 · 빈 면', mk)); ks += 1; }
      tp = wrongPages(r.R, r.nm, cfg.date, true, cfg.code);
      for (j = 0; j < tp.length; j += 1) pages.push(tp[j]);
      ks += tp.length;
    }
    return docHTML(only === 'key' ? '쌓인 오답 시험 · 정답지' : '쌓인 오답 시험', pages, cfg.bar || '');
  }

  /* ---------------------------------------------------------------- 미리 보기(관리자 화면) */
  /* 쪽 하나 작게: html = 쪽 안쪽 · w = 너비(px) · i = 차례 · on = 고름 */
  function thumb(html, w, cap, i, on, tag) {
    var sc = w / PW;
    return '<div class="lp-th-w" style="flex:none;width:' + w + 'px">' +
      '<button type="button" class="lpth' + (on ? ' on' : '') + '" data-lpi="' + i + '" data-lpk="' + tag + '" aria-label="' + esc(cap) + ' 크게 보기" ' +
        'style="display:block;width:' + w + 'px;height:' + Math.round(PH * sc) + 'px">' +
        '<div class="lpP" style="transform:scale(' + sc.toFixed(4) + ')">' + html + '</div></button>' +
      '<div class="lp-cap">' + esc(cap) + '</div></div>';
  }
  /* 쪽마다 시험지 · 정답지 짝: T · KP = 쪽 안쪽들 · CAP = [[시험 글, 정답 글], …] */
  function pairs(T, KP, CAP, w, sel) {
    var s = '', i;
    for (i = 0; i < T.length; i += 1) {
      s += '<div class="lp-pair" style="display:flex;gap:5px;flex:none">' + thumb(T[i], w, CAP[i][0], i, sel === i, 't') + thumb(KP[i], w, CAP[i][1], i, sel === i, 'k') + '</div>';
    }
    return s;
  }
  /* 크게: 시험지 위에 정답지를 겹치고 막대로 견줌(x = 정답지가 보이기 시작하는 자리 %) */
  function big(t, k, cap, W, x) {
    var sc = W / PW, s = sc.toFixed(4);
    return '<div class="lp-big-h" style="display:flex;justify-content:space-between;align-items:baseline;gap:8px;width:' + W + 'px;max-width:100%">' +
        '<span style="flex:none">← 시험지</span><span style="text-align:center">' + esc(cap) + '</span><span style="flex:none">정답지 →</span></div>' +
      '<div class="lpbv" style="width:' + W + 'px;height:' + Math.round(PH * sc) + 'px">' +
        '<div class="lpP" style="transform:scale(' + s + ')">' + t + '</div>' +
        '<div class="lpP lpkl" style="transform:scale(' + s + ');clip-path:inset(0 0 0 ' + x + '%)">' + k + '</div>' +
        '<div class="lpsdv" style="left:' + x + '%"></div></div>' +
      '<input class="lp-rg" type="range" min="0" max="100" step="1" value="' + x + '" aria-label="막대를 밀어 시험지와 정답지 견주기" style="width:' + W + 'px;max-width:100%">';
  }
  /* 막대만 옮김(다시 그리지 않음) */
  function bigX(box, x) {
    var k, d;
    if (!box) return;
    k = box.querySelector('.lpkl'); d = box.querySelector('.lpsdv');
    if (k) k.style.clipPath = 'inset(0 0 0 ' + x + '%)';
    if (k) k.style.webkitClipPath = 'inset(0 0 0 ' + x + '%)';
    if (d) d.style.left = x + '%';
  }

  G.LecPrint = {
    KN: KN, RN: RN, ORD: ORD, FM: FM, COLS: COLS, DEF_COL: DEF_COL, END: END,
    css: css, ensureCss: ensureCss, sheets: sheets, fmtName: fmtName, colOk: colOk, code: code, seeded: seeded, logoUrl: logoUrl,
    combined: combined, combinedPages: combinedPages, combinedDoc: combinedDoc, combinedSheets: combinedSheets,
    wrongPick: wrongPick, wrongCount: wrongCount, wrong: wrong, wrongPages: wrongPages, wrongSheets: wrongSheets, wrongDoc: wrongDoc,
    rangeCap: rangeCap, blankFoot: function (right, R, key) { return (key ? PILL : '') + foot(right, R && R.lay ? R.lay.mk : KM.n); },
    pairs: pairs, big: big, bigX: bigX, ymdAdd: ymdAdd
  };
})(window);
