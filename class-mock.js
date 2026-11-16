/* 히즈 강의실 · 연습용 가짜 서버 (window.LecMock)
   ?demo=1 일 때 class-api.js 의 Lec.rpc 가 이 파일을 부릅니다. 서버 없이 화면을 시험하는 용도입니다.
   ES5 문법만 씁니다. 규칙(검사 순서 · 오류 이름 · 한도 · 가림 · 보이는 범위 · 돌려주는 모양)은
   class-setup.sql 과 똑같이 맞췄습니다. 둘이 다르면 SQL 이 기준입니다.
   - 저장: localStorage 'lec-demo-v1'(안 되면 메모리 · 자료 판 VER 이 다르면 처음 상태로) · LecMock.reset() = 처음 상태로
   - 이 파일은 class-api.js 보다 먼저 불러도 됩니다(Lec 은 부를 때 찾습니다)
   - 학생 이름은 모두 지어낸 이름입니다(저장소가 공개라 실제 학생 정보를 넣지 않습니다)
   - 시연 자료: 김하늘 = 동의 전(첫 화면이 동의 화면) · 박구름 = 기록 안 함 · 이바다 13강 = 선생님 확인 ·
     12강 = 공개 끝 · 14강 ANALYSIS~06번 = 사흘 뒤 공개 끝 · 질문 세 상태 × 두 종류 · 오가을 = 명단에서 빠진 학생 ·
     강노을 = 로그인이 하루 잠긴 학생(선생님 «잠금 풀기»)
   - 선생님 판정은 SQL lec__staff 처럼 로그인 이메일만 봅니다(staff.setMe({email}) · user_metadata 는 보지 않음).
     선생님이 아닌 로그인(setMe(null) 또는 다른 주소)은 강의실 표가 빈 것처럼 보이고(읽기 []) 쓰면 막히며,
     선생님 함수는 'forbidden'. 학생 기기 열쇠는 sha256 해시(kh)로만 저장 · 기기 목록은 lec_keys 함수로만 */
(function (w) {
  'use strict';

  var STORE = 'lec-demo-v1';
  var VER = 5;
  var CONSENT_VER = 'v1-2026-11';   /* class-setup.sql lec__consent_ver() 와 같게 */
  var SEOUL = 9 * 3600000;
  var MINUTE = 60000, HOUR = 3600000, DAY = 86400000;
  var MAX_DUR = 21600, MAX_BITS = 2160;
  var ME = { name: 'Benjamin', admin: true };

  var ID = {
    L1: '5eed0000-0000-4000-8000-000000000001',
    L2: '5eed0000-0000-4000-8000-000000000002',
    L3: '5eed0000-0000-4000-8000-000000000003',
    L4: '5eed0000-0000-4000-8000-000000000004',
    L5: '5eed0000-0000-4000-8000-000000000005',
    L6: '5eed0000-0000-4000-8000-000000000006',
    L7: '5eed0000-0000-4000-8000-000000000007',
    TEST: '5eed0000-0000-4000-8000-000000000099',
    Q1: '5eedc0de-0000-4000-8000-000000000001',
    A1: '5eedc0de-0000-4000-8000-000000000002',
    Q2: '5eedc0de-0000-4000-8000-000000000003',
    Q3: '5eedc0de-0000-4000-8000-000000000004',
    A3: '5eedc0de-0000-4000-8000-000000000005',
    Q4: '5eedc0de-0000-4000-8000-000000000006',
    A4: '5eedc0de-0000-4000-8000-000000000007',
    Q5: '5eedc0de-0000-4000-8000-000000000008',
    Q6: '5eedc0de-0000-4000-8000-000000000009',
    A6: '5eedc0de-0000-4000-8000-000000000010'
  };

  var mem = null;
  var memOnly = false;

  function L() {
    var x = w.Lec;
    if (!x) throw new Error('Lec missing');
    return x;
  }
  function isArr(v) { return Object.prototype.toString.call(v) === '[object Array]'; }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }
  function pad(n, k) { var s = String(n); while (s.length < k) s = '0' + s; return s; }
  function str(v) { return v == null ? '' : String(v); }

  /* ---------------------------------------------- 열쇠 해시(SQL lec__kh = sha256(UTF-8) 16진 64자) */

  var SHA_K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];
  var SHA_H = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

  function utf8(s) {
    var out = [], i, c, c2;
    for (i = 0; i < s.length; i += 1) {
      c = s.charCodeAt(i);
      if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
        c2 = s.charCodeAt(i + 1);
        if (c2 >= 0xdc00 && c2 <= 0xdfff) { c = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00); i += 1; }
      }
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return out;
  }
  function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }
  function sha256hex(s) {
    var b = utf8(s), n = b.length, h = SHA_H.slice(), wv = [], i, j, o;
    var a, bb, c, dd, e, f, g, hh, s0, s1, t1, t2, hi, lo, out = '', x;
    b.push(0x80);
    while (b.length % 64 !== 56) b.push(0);
    hi = Math.floor(n / 0x20000000); lo = (n * 8) >>> 0;
    b.push((hi >>> 24) & 255, (hi >>> 16) & 255, (hi >>> 8) & 255, hi & 255,
           (lo >>> 24) & 255, (lo >>> 16) & 255, (lo >>> 8) & 255, lo & 255);
    for (i = 0; i < b.length; i += 64) {
      for (j = 0; j < 16; j += 1) {
        o = i + 4 * j;
        wv[j] = (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
      }
      for (j = 16; j < 64; j += 1) {
        s0 = rotr(wv[j - 15], 7) ^ rotr(wv[j - 15], 18) ^ (wv[j - 15] >>> 3);
        s1 = rotr(wv[j - 2], 17) ^ rotr(wv[j - 2], 19) ^ (wv[j - 2] >>> 10);
        wv[j] = (wv[j - 16] + s0 + wv[j - 7] + s1) | 0;
      }
      a = h[0]; bb = h[1]; c = h[2]; dd = h[3]; e = h[4]; f = h[5]; g = h[6]; hh = h[7];
      for (j = 0; j < 64; j += 1) {
        s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        t1 = (hh + s1 + ((e & f) ^ (~e & g)) + SHA_K[j] + wv[j]) | 0;
        s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        t2 = (s0 + ((a & bb) ^ (a & c) ^ (bb & c))) | 0;
        hh = g; g = f; f = e; e = (dd + t1) | 0; dd = c; c = bb; bb = a; a = (t1 + t2) | 0;
      }
      h[0] = (h[0] + a) | 0; h[1] = (h[1] + bb) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + dd) | 0;
      h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
    }
    for (i = 0; i < 8; i += 1) {
      x = (h[i] >>> 0).toString(16);
      out += '00000000'.slice(x.length) + x;
    }
    return out;
  }
  /* lec__kh(null) = null */
  function kh(s) { return s == null ? null : sha256hex(String(s)); }

  /* Postgres 의 round(반올림은 0에서 먼 쪽) */
  function rhaz(x) { return x < 0 ? -Math.round(-x) : Math.round(x); }

  /* ---------------------------------------------------------------- 시각 */

  function nowMs() { return Math.floor(L().now()); }
  function today() { return L().isoDay(nowMs()); }

  /* 서버(PostgREST)가 주는 timestamptz 꼴: 2026-11-15T07:12:33.123+00:00 (소수 끝 0 은 뺌) */
  function pgts(ms) {
    var d = new Date(Math.floor(ms));
    var s = d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1, 2) + '-' + pad(d.getUTCDate(), 2) +
            'T' + pad(d.getUTCHours(), 2) + ':' + pad(d.getUTCMinutes(), 2) + ':' + pad(d.getUTCSeconds(), 2);
    var f = d.getUTCMilliseconds();
    if (f) s += '.' + pad(f, 3).replace(/0+$/, '');
    return s + '+00:00';
  }
  function tms(v) {
    var t = L().ts(v);
    return isFinite(t) ? t : NaN;
  }
  /* 오늘(서울)에서 off 일 뒤의 날짜 */
  function dayStr(off) {
    var p = today().split('-');
    var d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + off));
    return d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1, 2) + '-' + pad(d.getUTCDate(), 2);
  }
  /* 오늘에서 off 일 뒤, 서울 hh:mm 의 ms */
  function atMs(off, hh, mm) {
    var p = dayStr(off).split('-');
    return Date.UTC(+p[0], +p[1] - 1, +p[2], hh, mm) - SEOUL;
  }

  /* ---------------------------------------------------------- 저장소 */

  /* 열쇠 줄은 해시(kh)만 둠: 누가 열쇠 글자(key)로 줄을 넣어도 저장할 때 해시로 바꾸고 key 는 뺌
     (class-setup.sql 의 옛 key 열 → kh 옮기기와 같음 · 연습 화면이 직접 넣는 줄도 이 길로) */
  function hashKeys(d) {
    var i, k;
    if (!d || !isArr(d.key)) return;
    for (i = 0; i < d.key.length; i += 1) {
      k = d.key[i];
      if (k && typeof k === 'object' && has(k, 'key')) {
        if (k.kh == null) k.kh = kh(k.key);
        delete k.key;
      }
    }
    d.key = d.key.filter(function (x) { return x && x.kh != null; });
  }

  function save(d) {
    hashKeys(d);
    mem = d;
    if (memOnly) return;
    try { w.localStorage.setItem(STORE, JSON.stringify(d)); } catch (e) { memOnly = true; }
  }

  function load() {
    var d = null, raw = null;
    if (!memOnly) {
      try { raw = w.localStorage.getItem(STORE); } catch (e) { memOnly = true; }
    }
    if (memOnly) d = mem;
    else if (raw) {
      try { d = JSON.parse(raw); } catch (e2) { d = null; }
    }
    if (!d || d.v !== VER) { d = seed(); save(d); }
    if (ensureTest(d)) save(d);
    if (c2Ensure(d)) save(d);   /* C2 시연 자료(아래 C2 절) */
    if (c2Many(d)) save(d);     /* ?manyexams=1 = 시험 여럿(아래 C2 절) · 아니면 넣었던 것을 걷어 냄 */
    return d;
  }

  /* &t=1 이면 길이 0 강의가 있게(없을 때만 넣음) · t=1 이 아니면 그 강의와 딸린 기록을 걷어 냄
     (같은 브라우저에서 t=1 을 한 번 열었더라도 그냥 ?demo=1 목록에 «길이 0 시험 강의»가 보이지 않게) */
  function ensureTest(d) {
    var i;
    if (!L().TEST) {
      var n0 = d.lecture.length + d.progress.length + d.session.length + d.qna.length;
      var keep = function (x) { return x.id !== ID.TEST && x.lecture_id !== ID.TEST; };
      d.lecture = d.lecture.filter(keep);
      d.progress = d.progress.filter(keep);
      d.session = d.session.filter(keep);
      d.qna = d.qna.filter(keep);
      return d.lecture.length + d.progress.length + d.session.length + d.qna.length !== n0;
    }
    for (i = 0; i < d.lecture.length; i += 1) { if (d.lecture[i].id === ID.TEST) return false; }
    d.lecture.push(lectureRow({
      id: ID.TEST, title: '길이 0 시험 강의', book: '시험용', yt: 'Tloen4cudDo', dur: 0,
      chapters: [{ t: 0, title: '처음' }, { t: 20, title: '중간' }],
      class_ids: ['*'], lesson_on: dayStr(-1), posted_on: dayStr(-1), created_by: 'Benjamin',
      created_at: pgts(atMs(-1, 17, 30)), updated_at: pgts(atMs(-1, 17, 30))
    }));
    return true;
  }

  /* ---------------------------------------------------------- 처음 자료 */

  function lectureRow(o) {
    var t = pgts(nowMs());
    return {
      id: o.id, title: str(o.title), book: str(o.book), yt: str(o.yt), dur: o.dur | 0,
      chapters: o.chapters || [], class_ids: o.class_ids || [],
      lesson_on: o.lesson_on || null, posted_on: o.posted_on || today(), until: o.until || null,
      hidden: !!o.hidden, created_by: str(o.created_by),
      created_at: o.created_at || t, updated_at: o.updated_at || t,
      lesson_more: o.lesson_more || [], runner: o.runner || {}, lesson_cls: o.lesson_cls || {}
    };
  }

  function stu(id, name, tel) { return { id: id, name: name, intake: { parentContact: '010-0000-' + tel } }; }

  function seed() {
    var X = L();
    var d = { v: VER, seededAt: pgts(nowMs()), classes: [], lecture: [], progress: [], session: [], qna: [], key: [], fail: [], consent: [] };

    d.classes = [
      { id: 'c-g1a', name: '고1 A반', owner: 'Joey', students: [
        stu('s1001', '김하늘', '1234'), stu('s1002', '이바다', '2345'), stu('s1003', '박구름', '3456'),
        stu('s1004', '최새봄', '4567'), stu('s1005', '정단비', '5678')
      ] },
      /* 서은별은 일부러 정단비와 같은 id(s1005): 학원 자료에 실제로 있는 «같은 번호 다른 학생»을 시험하려고 */
      { id: 'c-g2b', name: '고2 B반', owner: 'Dana', students: [
        stu('s2001', '한겨울', '1111'), stu('s2002', '윤가람', '2222'), stu('s1005', '서은별', '3333'),
        stu('s2003', '강노을', '4444')
      ] }
    ];
    /* 강노을 = 지금 로그인이 하루 잠긴 학생(선생님 «잠금 풀기» 시연): 3분 간격으로 15번 틀림 · 마지막이 40분 전 */
    (function () {
      var i, t0 = nowMs() - 40 * MINUTE;
      for (i = 0; i < 15; i += 1) {
        d.fail.push({ who: 'k:s2003|강노을', at: pgts(t0 - (14 - i) * 3 * MINUTE), lock: i === 14 ? 'day' : '' });
      }
    })();

    function lec(id, off, title, book, dur, cls, by, chs, until) {
      var ch = [], i;
      for (i = 0; i < chs.length; i += 1) ch.push({ t: chs[i][0], title: chs[i][1] });
      var made = pgts(atMs(off >= 0 ? -1 : off, off >= 0 ? 21 : 17, 0));
      d.lecture.push(lectureRow({
        id: id, title: title, book: book, yt: 'Tloen4cudDo', dur: dur, chapters: ch, class_ids: cls,
        lesson_on: dayStr(off), posted_on: dayStr(off), until: until == null ? null : dayStr(until),
        created_by: by, created_at: made, updated_at: made
      }));
    }
    lec(ID.L1, -5, '4과 01~06번', '공통영어2 YBM(박) 교과서 본문', 2820, ['c-g1a'], 'Benjamin', [
      [0, '오늘 볼 지문'], [11, '01번 · 과학을 모두에게: 1달러 미만 종이 현미경'],
      [612, '02번 · 현미경이 방치된 이유와 새로운 만남'], [1213, '03번 · 최소 요구 사항과 가격·성능 사이의 선택'],
      [1707, '04번 · 종이로 만든 현미경의 뛰어난 장점'], [2163, '05번 · 진단 외의 쓰임과 과학의 역할'],
      [2567, '06번 · 공동체를 위한 기술: 3D 프린팅 인공 팔다리']
    ]);
    lec(ID.L2, -5, '13강 04~16번', '올림포스 기출 고1', 6064, ['c-g1a'], 'Benjamin', [
      [0, '오늘 볼 지문'], [11, '04번 · 착시를 만들어 다른 생물로 변신하는 문어'],
      [541, '05번 · 당대엔 낯설었던 위대한 작곡가들의 독창성'], [914, '06~07번 · 미완성 작품과 생산성 · 뇌의 재구조화'],
      [1841, '08~09번 · 살 곳을 찾아 이동하는 생물 종 · 반전 안경 실험'], [2624, '10~11번 · 관심사에 열정적인 독자들 · 탁월함의 연결'],
      [3680, '12~13번 · 도시의 경제 같은 뇌 · 시간에 과제 맞추기'], [4742, '14~15번 · 마감일 실험 · 판단력까지 빼앗는 로봇'],
      [5644, '16번 · 가상 회의의 제약과 창의성']
    ]);
    lec(ID.L3, -3, '4회 33~40번', '능수능란 실력', 4757, ['c-g2b'], 'Dana', [
      [0, '오늘 볼 지문'], [11, '33번 · 자연에서 영감을 얻은 혁신적인 설계'],
      [514, '34번 · 시민 저널리즘에 관한 비판과 옹호'], [1080, '35번 · 성공적인 관리자의 주요 역량'],
      [1548, '36번 · 차용어가 받아들여지는 과정'], [2224, '37번 · 윤년의 도입 이유와 역법의 변천'],
      [3008, '38번 · 주제를 섞어 배우는 학습법의 이점'], [3562, '39번 · 법 집행의 정부 감독에 관한 관점들'],
      [4206, '40번 · 기후 변화 교육의 효과를 높이는 방법']
    ]);
    lec(ID.L4, -2, '18~32번', '고1 10월 전국연합학력평가', 4502, ['*'], 'Benjamin', [
      [0, '오늘 볼 지문'], [11, '18번 · 연수 비용 지원 요청'],
      [407, '19번 · 방학 직전 나의 심경 변화'], [774, '20~21번 · 세계 시민 정체성 · 경력을 바꾸는 새 접근'],
      [1673, '22번 · 전통과 문화가 만든 시간 인식'], [2057, '23~24번 · 내부 고발자 보호 · 미래에 대한 환상'],
      [2927, '29~30번 · 불멸 생물 연구 · 발전소 보조금'], [3772, '31번 · 생성형 AI 가 열 수 있는 미래'],
      [4193, '32번 · 귀 기울였음을 보여 주기']
    ]);
    lec(ID.L5, -2, '14강 ANALYSIS~06번', '올림포스 기출 고1', 3131, ['c-g1a'], 'Joey', [
      [0, '오늘 볼 지문'], [11, 'ANALYSIS · 더 천천히 번식하는 인간의 전략'],
      [25, '01번 · 재생 가능 에너지 시설에 필요한 화석 연료'], [634, '02번 · 과학적 발견의 공유와 의존'],
      [1091, '03번 · 냄새와 소리로 하는 식물의 의사소통'], [1712, '04번 · 세 가지 버전 가격 전략'],
      [2234, '05번 · 없는 것을 보게 하는 개념'], [2692, '06번 · 경쟁과 갈등 속 인간 생각의 진화']
    ], 3);   /* 사흘 뒤 공개 끝(«M.D까지 볼 수 있어요») */
    /* 공개 예정(모레): 학생에게는 안 보임 */
    lec(ID.L6, 2, '14강 07~12번', '올림포스 기출 고1', 3420, ['c-g1a'], 'Benjamin', [
      [0, '오늘 볼 지문'], [11, '07번'], [590, '08번'], [1160, '09번'], [1730, '10번'], [2300, '11번'], [2870, '12번']
    ]);
    /* 공개 끝(어제까지): 목록에는 남고 볼 수는 없음 */
    lec(ID.L7, -20, '12강 01~08번', '올림포스 기출 고1', 3900, ['c-g1a'], 'Benjamin', [
      [0, '오늘 볼 지문'], [11, '01번'], [480, '02번'], [960, '03번'], [1450, '04번'], [1980, '05번'],
      [2520, '06~07번'], [3300, '08번']
    ], -1);
    if (X.TEST) ensureTest(d);

    /* C1 · 출결(히즈북스 자료를 흉내 · 읽기만): 두 반 모두 날마다 수업(고1 A 18:00~19:30 · 고2 B 19:00~20:30) */
    (function () {
      var wk = ['일', '월', '화', '수', '목', '금', '토'];
      function sched(st, en) {
        var tm = {}, i;
        for (i = 0; i < wk.length; i += 1) tm[wk[i]] = { start: st, end: en };
        return { days: wk.slice(), times: tm };
      }
      d.classes[0].schedule = sched('18:00', '19:30');
      d.classes[1].schedule = sched('19:00', '20:30');
      function dk(off) { return dayStr(off).replace(/-/g, '.'); }
      function ym(off) { return dayStr(off).slice(0, 7); }
      function cin(off, hh, mm) { return { 'in': pad(hh, 2) + ':' + pad(mm, 2), t: atMs(off, hh, mm) }; }
      function row(id, k) { if (!d.app[id]) d.app[id] = {}; if (!d.app[id][k]) d.app[id][k] = (k === 'records' ? [] : {}); return d.app[id][k]; }
      var main, ck, i, sid;
      d.app = { main: { records: [], checkins: {}, noShowExcused: {}, sessions: {}, mkup: {}, closedDays: [dk(-1)] } };
      main = d.app.main;
      /* 20일 전(L7 · 공개 끝): 고1 A 다섯 모두 등원(달 줄 pt-ck) */
      ck = row('pt-ck-' + ym(-20), 'checkins');
      for (i = 1; i <= 5; i += 1) ck['s100' + i + '|' + dk(-20)] = cin(-20, 17, 50);
      /* 5일 전(L1 · L2): 김하늘 · 이바다 · 최새봄 등원 · 박구름 안 옴 · 정단비 결석 예정(달 줄 pt-old) */
      ['s1001', 's1002', 's1004'].forEach(function (s) { main.checkins[s + '|' + dk(-5)] = cin(-5, 17, 55); });
      row('pt-old-' + ym(-5), 'noShowExcused')['s1005|' + dk(-5)] = { reason: '병원', t: atMs(-6, 20, 0) };
      /* 4일 전(L2 의 둘째 수업일): 이바다만 안 옴 */
      ['s1001', 's1003', 's1004', 's1005'].forEach(function (s) { main.checkins[s + '|' + dk(-4)] = cin(-4, 17, 52); });
      /* 3일 전(L3): 윤가람만 안 옴 */
      ['s2001', 's1005', 's2003'].forEach(function (s) { main.checkins[s + '|' + dk(-3)] = cin(-3, 18, 50); });
      /* 2일 전(L4 · L5): 최새봄은 등원을 찍었다가 지움(달 줄의 지움 표식이 더 늦음) · 한겨울은 안 왔지만 보강이 잡힘 ·
         강노을은 등원 기록 없이 일지에 «지각» */
      ['s1001', 's1002', 's1003', 's1005', 's2002'].forEach(function (s) { main.checkins[s + '|' + dk(-2)] = cin(-2, 17, 55); });
      main.checkins['s1004|' + dk(-2)] = cin(-2, 17, 50);
      row('pt-ck-' + ym(-2), 'checkins')['s1004|' + dk(-2)] = { del: 1, t: atMs(-2, 18, 5) };
      main.mkup['s2001|' + dk(1)] = { cid: 'c-g2b', start: '16:00', end: '17:30', from: dk(-2), t: atMs(-1, 12, 0) };
      row('pt-rec-' + ym(-2), 'records').push({
        classId: 'c-g2b', studentId: 's2003', date: dk(-2), attendance: '지각', editT: atMs(-2, 20, 40)
      });
      for (i = 0; i < d.lecture.length; i += 1) {
        sid = d.lecture[i].id;
        /* L2 는 이틀에 나눠 한 수업(5일 전 · 4일 전) */
        if (sid === ID.L2) d.lecture[i].lesson_more = [dayStr(-4)];
        /* L1 은 워크북 번호가 지문 이름과 다른 지문이 있는 강의(C3 회색 표 · C7 멈춤 · 보기용 값) */
        if (sid === ID.L1) {
          d.lecture[i].runner = {
            days: [dayStr(-5)], start: '19:02', items: [
              { no: '01', at: 11, stop: 600, board: 1, wb: '01' },
              { no: '02', at: 612, stop: 1200, board: 2, wb: '02' },
              { no: '03', at: 1213, stop: 1695, board: 3, wb: '5-6' },
              { no: '04', at: 1707, stop: 2150, board: 4, wb: '3,5' },
              { no: '05', at: 2163, stop: 2555, board: 5, wb: '' },
              { no: '06', at: 2567, stop: 2810, board: 6, wb: '06' }
            ]
          };
        }
        /* L5 는 실행기 txt 의 [온라인 클래스] 묶음이 들어온 강의(보기용 값) */
        if (sid === ID.L5) {
          d.lecture[i].runner = {
            days: [dayStr(-2)], start: '22:52', items: [
              { no: 'ANALYSIS', at: 11, stop: 16, board: 1, wb: 'ANALYSIS' },
              { no: '01', at: 25, stop: 625, board: 2, wb: '01' },
              { no: '02', at: 634, stop: 1082, board: 3, wb: '02' },
              { no: '03', at: 1091, stop: 1703, board: 4, wb: '03' },
              { no: '04', at: 1712, stop: 2225, board: 5, wb: '04' },
              { no: '05', at: 2234, stop: 2683, board: 6, wb: '05' },
              { no: '06', at: 2692, stop: 3122, board: 7, wb: '06' }
            ]
          };
        }
      }
    })();

    /* 진도 · 보기 기록: [며칠 전, 시, 분, 시작 비율, 끝 비율, 배속, 기기] */
    var sn = 0;
    function watch(sid, sname, lid, list) {
      var l = null, i, dur, secs = [], watched = 0, first = null, last = null, done = null, pos = 0, bits, pct;
      for (i = 0; i < d.lecture.length; i += 1) { if (d.lecture[i].id === lid) l = d.lecture[i]; }
      dur = l.dur;
      for (i = 0; i < list.length; i += 1) {
        var s = list[i];
        var a = Math.round(s[3] * dur), b = Math.round(s[4] * dur);
        var real = Math.round((b - a) / s[5]);
        var t0 = atMs(s[0], s[1], s[2]), t1 = t0 + real * 1000;
        secs = X.addSpan(secs, a, b);
        watched += real;
        first = first === null ? t0 : Math.min(first, t0);
        last = last === null ? t1 : Math.max(last, t1);
        pos = b;
        bits = X.bmFromSecs(secs, dur);
        pct = X.bmPct(bits, dur);
        if (done === null && pct >= 90) done = t1;
        sn += 1;
        d.session.push({
          id: '5eed5e55-0000-4000-8000-' + pad(sn, 12), sid: sid, sname: sname, lecture_id: lid,
          started_at: pgts(t0), ended_at: pgts(t1), watched: real, from_s: a, to_s: b, dev: s[6], rate: s[5]
        });
      }
      bits = X.bmFromSecs(secs, dur);
      d.progress.push({
        sid: sid, lecture_id: lid, sname: sname, seen: bits, watched: watched, pos: pos,
        pct: X.bmPct(bits, dur), sessions: list.length,
        first_at: pgts(first), last_at: pgts(last), done_at: done === null ? null : pgts(done),
        done_by: null, done_note: '', done_by_at: null
      });
    }
    var HN = 's1001|김하늘', BD = 's1002|이바다', GR = 's1003|박구름', SB = 's1004|최새봄', GW = 's2001|한겨울', GR2 = 's2002|윤가람';
    watch(HN, '김하늘', ID.L1, [[-4, 20, 10, 0, 0.55, 1, '아이폰'], [-3, 21, 0, 0.55, 0.96, 1, '윈도우 PC']]);
    watch(HN, '김하늘', ID.L2, [[-1, 19, 30, 0, 0.45, 1, '아이폰']]);
    watch(BD, '이바다', ID.L1, [[-4, 21, 0, 0, 1, 1.5, '안드로이드 폰']]);
    watch(BD, '이바다', ID.L2, [[-3, 20, 0, 0, 0.30, 1, '안드로이드 폰']]);
    watch(BD, '이바다', ID.L4, [[-1, 18, 40, 0, 0.62, 1.25, '안드로이드 폰']]);
    watch(GR, '박구름', ID.L1, [[-2, 22, 0, 0, 0.30, 1, '아이패드'], [-1, 21, 30, 0.45, 0.70, 1, '아이패드']]);
    watch(SB, '최새봄', ID.L1, [[-3, 19, 0, 0, 0.92, 1, '윈도우 PC']]);
    watch(SB, '최새봄', ID.L2, [[-2, 18, 30, 0, 0.90, 1.25, '윈도우 PC']]);
    watch(SB, '최새봄', ID.L5, [[-1, 20, 0, 0, 0.25, 1, '윈도우 PC']]);
    watch(GW, '한겨울', ID.L3, [[-2, 21, 0, 0, 0.60, 1, '윈도우 PC'], [-1, 20, 30, 0.60, 0.97, 1, '아이폰']]);
    watch(GW, '한겨울', ID.L4, [[-1, 22, 0, 0, 0.48, 1, '아이폰']]);
    watch(GR2, '윤가람', ID.L3, [[-2, 19, 30, 0, 0.35, 1, '안드로이드 태블릿']]);
    /* 명단에서 빠진 학생(할 일 띠 «그만둔 학생 기록»): 다른 줄 뒤에 넣어 위 보기 기록 id 가 그대로 */
    var GA = 's0901|오가을';
    watch(GA, '오가을', ID.L4, [[-4, 19, 0, 0, 0.40, 1, '아이폰']]);

    /* 이바다 13강 = 선생님 확인(교실에서 워크북 확인) · 자동 완료와 따로 */
    var pi;
    for (pi = 0; pi < d.progress.length; pi += 1) {
      if (d.progress[pi].sid === BD && d.progress[pi].lecture_id === ID.L2) {
        d.progress[pi].done_by = 'Joey';
        d.progress[pi].done_note = '교실에서 워크북 확인';
        d.progress[pi].done_by_at = pgts(atMs(-2, 15, 0));
      }
    }

    /* 기록 동의: 김하늘 · 정단비 · 서은별 = 동의 전 · 박구름 = 기록 안 함 · 나머지 = 기록함(지금 판) */
    function agree(sid, choice, off, hh, mm) {
      d.consent.push({ sid: sid, choice: choice, ver: CONSENT_VER, at: pgts(atMs(off, hh, mm)) });
    }
    agree(BD, 'agree', -4, 20, 52);
    agree(GR, 'none', -2, 21, 58);
    agree(SB, 'agree', -3, 18, 56);
    agree(GW, 'agree', -3, 9, 5);
    agree(GR2, 'agree', -2, 19, 25);
    agree(GA, 'agree', -4, 18, 58);

    /* 질문 · 답변: 세 상태(답변 대기 · 답 있음 안 읽음 · 읽음) × 두 종류(content · tech) */
    function qa(o) {
      d.qna.push({
        id: o.id, lecture_id: o.l, parent: o.p || null, sid: o.sid || null, sname: o.sn || null,
        teacher: o.t || null, at_s: o.at == null ? null : o.at, body: o.b,
        private: !!o.pv, kind: o.k || 'content', stu_seen: !!o.seen, deleted: false, created_at: pgts(o.c)
      });
    }
    qa({ id: ID.Q1, l: ID.L1, sid: BD, sn: '이바다', at: 560, c: atMs(-4, 21, 20),
         b: '01번에서 which 앞에 쉼표가 있을 때와 없을 때 해석이 어떻게 달라지나요?' });
    qa({ id: ID.A1, l: ID.L1, p: ID.Q1, t: 'Joey', seen: true, c: atMs(-3, 10, 30),
         b: '쉼표가 있으면 앞 내용을 덧붙여 설명하는 쓰임이라 «그리고 그것은»처럼 이어서 해석해요. 쉼표가 없으면 바로 앞 명사를 꾸며 줍니다.' });
    qa({ id: ID.Q2, l: ID.L1, sid: HN, sn: '김하늘', at: 1265, pv: true, c: atMs(-3, 22, 5),
         b: '03번 마지막 문장에서 it 이 가리키는 것이 무엇인지 잘 모르겠어요.' });
    qa({ id: ID.Q3, l: ID.L2, sid: BD, sn: '이바다', at: 1900, k: 'tech', c: atMs(-3, 20, 40),
         b: '08번에서 영상이 자꾸 멈춰요. 다시 열어도 같아요.' });
    qa({ id: ID.A3, l: ID.L2, p: ID.Q3, t: 'Joey', c: atMs(-2, 9, 0),
         b: '영상 파일을 다시 올려 두었어요. 지금은 끊기지 않으니 다시 열어 보세요.' });
    qa({ id: ID.Q4, l: ID.L2, sid: SB, sn: '최새봄', at: 3700, pv: true, c: atMs(-2, 19, 10),
         b: '12번에서 뇌를 도시의 경제에 빗댄 부분이 무슨 뜻인지 다시 설명해 주실 수 있나요?' });
    qa({ id: ID.A4, l: ID.L2, p: ID.Q4, t: 'Joey', pv: true, c: atMs(-1, 10, 0),
         b: '뇌가 쓸 수 있는 에너지를 도시의 예산처럼 나눠 쓴다는 비유예요. 다음 수업에서 그림으로 다시 볼게요.' });
    qa({ id: ID.Q5, l: ID.L5, sid: SB, sn: '최새봄', at: 780, k: 'tech', c: atMs(-1, 20, 30),
         b: '끝까지 봤는데 진도가 25%에서 더 올라가지 않아요.' });
    qa({ id: ID.Q6, l: ID.L3, sid: GW, sn: '한겨울', at: 1500, k: 'tech', c: atMs(-2, 21, 50),
         b: '35번부터 소리가 작아요. 제 기기 문제일까요?' });
    qa({ id: ID.A6, l: ID.L3, p: ID.Q6, t: 'Dana', seen: true, c: atMs(-1, 9, 30),
         b: '영상 소리를 조금 키워 두었어요. 그래도 작으면 수업 때 말해 주세요.' });

    /* 들어가기 열쇠(가짜 값 · 표에는 해시만 · 시험은 'dede' + 60자리 번호를 열쇠로 씀) */
    function dkey(n) { return 'dede' + pad(n, 60); }
    function key(n, sid, rid, pin, sname, cls, dev, by, c0, l0) {
      d.key.push({ kh: kh(dkey(n)), sid: sid, rid: rid, pin: pin, sname: sname, cls: cls, dev: dev, made_by: by, created_at: pgts(c0), last_at: pgts(l0) });
    }
    key(1, HN, 's1001', '1234', '김하늘', ['c-g1a'], '아이폰', '', atMs(-4, 20, 5), atMs(-1, 19, 30));
    key(2, HN, 's1001', '1234', '김하늘', ['c-g1a'], '윈도우 PC', '', atMs(-3, 20, 55), atMs(-3, 22, 10));
    key(3, BD, 's1002', '2345', '이바다', ['c-g1a'], '안드로이드 폰', '', atMs(-4, 20, 50), atMs(-1, 18, 40));
    key(4, SB, 's1004', '4567', '최새봄', ['c-g1a'], '윈도우 PC', '', atMs(-3, 18, 55), atMs(-1, 20, 0));
    key(5, GW, 's2001', '', '한겨울', ['c-g2b'], '개인 링크', 'Dana', atMs(-3, 9, 0), atMs(-1, 22, 0));
    return d;
  }

  /* ---------------------------------------------------------- 서버 도움 함수 */

  function roster(d) { return L().rosterFrom(d.classes); }

  /* 받은 열쇠를 해시해서 찾음(SQL: where kh = lec__kh(p_key)) */
  function findKey(d, k) {
    var i, h;
    if (k == null) return null;
    h = kh(k);
    for (i = 0; i < d.key.length; i += 1) { if (d.key[i].kh === h) return d.key[i]; }
    return null;
  }
  function findLecture(d, id) {
    var i;
    for (i = 0; i < d.lecture.length; i += 1) { if (d.lecture[i].id === id) return d.lecture[i]; }
    return null;
  }
  function findProgress(d, sid, lid) {
    var i;
    for (i = 0; i < d.progress.length; i += 1) {
      if (d.progress[i].sid === sid && d.progress[i].lecture_id === lid) return d.progress[i];
    }
    return null;
  }
  function findQna(d, id) {
    var i;
    if (id == null) return null;
    for (i = 0; i < d.qna.length; i += 1) { if (d.qna[i].id === id) return d.qna[i]; }
    return null;
  }

  /* lec__open */
  function isOpen(l, cls) {
    if (!l || l.hidden) return false;
    var t = today(), po = l.posted_on || t, ids = l.class_ids || [], i;
    if (po > t) return false;
    if (!cls || !cls.length) return false;
    if (ids.indexOf('*') >= 0) return true;
    for (i = 0; i < cls.length; i += 1) { if (ids.indexOf(cls[i]) >= 0) return true; }
    return false;
  }

  /* 기록 동의 한 줄(학생 열쇠마다 하나) */
  function findConsent(d, sid) {
    var c = d.consent || [], i;
    for (i = 0; i < c.length; i += 1) { if (c[i].sid === sid) return c[i]; }
    return null;
  }
  /* lec__agreed: 지금 판에 «기록함» */
  function agreed(d, sid) {
    var c = findConsent(d, sid);
    return !!c && c.choice === 'agree' && c.ver === CONSENT_VER;
  }
  /* lec__ended: 한국 시각 오늘 > until */
  function ended(l) { return !!l && l.until != null && today() > l.until; }

  /* 답이 달렸나(질문 목록 answered · lec_qdel 과 같은 규칙):
     처음 질문 = 지우지 않은 선생님 답이 하나라도 · 덧붙인 글 = 그 뒤에 달린 선생님 답이 있으면 */
  function answered(d, x) {
    var i, t;
    if (x.teacher != null) return false;
    for (i = 0; i < d.qna.length; i += 1) {
      t = d.qna[i];
      if (t.teacher == null || t.deleted) continue;
      if (x.parent == null) {
        if (t.parent === x.id) return true;
      } else if (t.parent === x.parent && tms(t.created_at) > tms(x.created_at)) {
        return true;
      }
    }
    return false;
  }

  /* lec__classes 의 담당 선생님 칸처럼 앞뒤 빈칸(띄어쓰기 · 탭 · 줄바꿈)을 뺌 */
  function trimWs(s) { return str(s).replace(/^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g, ''); }
  function myClassIds(d, name) {
    var out = [], i, c, id;
    for (i = 0; i < d.classes.length; i += 1) {
      c = d.classes[i];
      if (!c || typeof c !== 'object' || isArr(c)) continue;
      id = L().jtext(c.id);
      if (id == null || id === '') continue;
      if (trimWs(L().jtext(c.owner)) === name && out.indexOf(id) < 0) out.push(id);
    }
    return out;
  }
  /* lec__can: 관리자는 모두 · 선생님은 그 학생이 내 반에 있고 그 반이 이 강의를 보는 반(또는 «전체»)일 때 */
  function can(d, l, skey) {
    if (!ME) return false;
    if (ME.admin) return true;
    var mine = myClassIds(d, ME.name), rs = roster(d), ids = l.class_ids || [], i, j, cid;
    for (i = 0; i < rs.length; i += 1) {
      if (rs[i].skey !== skey) continue;
      for (j = 0; j < rs[i].cls.length; j += 1) {
        cid = rs[i].cls[j];
        if (mine.indexOf(cid) >= 0 && (ids.indexOf(cid) >= 0 || ids.indexOf('*') >= 0)) return true;
      }
    }
    return false;
  }

  /* Postgres least/greatest 는 null 을 건너뜀 */
  function tsPick(a, b, wantMin) {
    if (a == null) return b == null ? null : b;
    if (b == null) return a;
    var x = tms(a), y = tms(b);
    if (wantMin) return y < x ? b : a;
    return y > x ? b : a;
  }

  /* 강의 길이가 바뀌면 그 강의 진도를 다시 계산(lec__dur_changed) */
  function durChanged(d, lid, dur) {
    var X = L(), i, p, pc, now = pgts(nowMs());
    for (i = 0; i < d.progress.length; i += 1) {
      p = d.progress[i];
      if (p.lecture_id !== lid) continue;
      pc = X.bmPct(p.seen, dur);
      p.pct = pc;
      p.done_at = pc >= 90 ? (p.done_at || now) : null;
    }
  }

  /* lec__move: 이름이 바뀐 학생의 기록을 새 열쇠로 */
  function move(d, oldSid, newSid, sname) {
    var X = L(), i, j, p, q, now = pgts(nowMs());
    if (oldSid == null || newSid == null || oldSid === newSid) return;
    for (i = 0; i < d.progress.length; i += 1) {
      p = d.progress[i];
      if (p.sid !== newSid) continue;
      q = null;
      for (j = 0; j < d.progress.length; j += 1) {
        if (d.progress[j].sid === oldSid && d.progress[j].lecture_id === p.lecture_id) q = d.progress[j];
      }
      if (!q) continue;
      var ql = q.last_at == null ? -Infinity : tms(q.last_at), pl = p.last_at == null ? -Infinity : tms(p.last_at);
      var nv = {
        seen: X.bmOr(q.seen, p.seen, MAX_BITS),
        watched: p.watched + q.watched,
        sessions: p.sessions + q.sessions,
        pos: ql > pl ? q.pos : p.pos,
        first_at: tsPick(p.first_at, q.first_at, true),
        last_at: tsPick(p.last_at, q.last_at, false),
        done_at: tsPick(p.done_at, q.done_at, true),
        done_by: p.done_by != null ? p.done_by : (q.done_by == null ? null : q.done_by),
        done_note: p.done_by == null ? (q.done_note == null ? '' : q.done_note) : p.done_note,
        done_by_at: p.done_by == null ? (q.done_by_at == null ? null : q.done_by_at) : p.done_by_at
      };
      p.seen = nv.seen; p.watched = nv.watched; p.sessions = nv.sessions; p.pos = nv.pos;
      p.first_at = nv.first_at; p.last_at = nv.last_at; p.done_at = nv.done_at;
      p.done_by = nv.done_by; p.done_note = nv.done_note; p.done_by_at = nv.done_by_at;
    }
    for (i = 0; i < d.progress.length; i += 1) {
      p = d.progress[i];
      if (p.sid === oldSid && !findProgress(d, newSid, p.lecture_id)) p.sid = newSid;
    }
    d.progress = d.progress.filter(function (x) { return x.sid !== oldSid; });
    for (i = 0; i < d.progress.length; i += 1) {
      p = d.progress[i];
      if (p.sid !== newSid) continue;
      var l = findLecture(d, p.lecture_id), pc = X.bmPct(p.seen, l ? l.dur : 0);
      p.sname = sname == null ? p.sname : sname;
      p.pct = pc;
      p.done_at = pc >= 90 ? (p.done_at || now) : p.done_at;
    }
    var tabs = [d.session, d.qna, d.key], t;
    for (t = 0; t < tabs.length; t += 1) {
      for (i = 0; i < tabs[t].length; i += 1) {
        if (tabs[t][i].sid === oldSid) {
          tabs[t][i].sid = newSid;
          tabs[t][i].sname = sname == null ? tabs[t][i].sname : sname;
        }
      }
    }
    /* 동의는 새 열쇠에 이미 있으면 그것을 두고, 없으면 옮김 */
    var cs = d.consent || [];
    if (!findConsent(d, newSid)) {
      for (i = 0; i < cs.length; i += 1) { if (cs[i].sid === oldSid) cs[i].sid = newSid; }
    }
    d.consent = cs.filter(function (c) { return c.sid !== oldSid; });
    for (i = 0; i < d.fail.length; i += 1) {
      if (d.fail[i].who === 'k:' + oldSid) d.fail[i].who = 'k:' + newSid;
    }
  }

  /* ---------------------------------------------------------- 학생 화면 함수(SQL 과 같은 차례) */

  function lec_login(d, a) {
    var X = L();
    var name = X.norm(a.p_name), pin = str(a.p_pin).replace(/[^0-9]/g, '');
    var n = X.clen(name);
    if (n < 1 || n > 40 || X.clen(pin) !== 4) return { ok: false, err: 'input' };
    var now = nowMs(), i;
    d.fail = d.fail.filter(function (f) { return !(tms(f.at) < now - DAY); });
    d.key = d.key.filter(function (k) { return !(k.made_by === '' && tms(k.last_at) < now - 365 * DAY); });
    /* 잠금을 세는 대상: 친 이름이 명단의 한 학생에게만 맞으면 그 학생 열쇠(k:), 아니면 친 이름(n:) */
    var rs = roster(d), cnt = 0, one = null;
    for (i = 0; i < rs.length; i += 1) {
      if (rs[i].nname === name) { cnt += 1; one = rs[i].skey; }
    }
    var who = cnt === 1 ? 'k:' + one : 'n:' + name;
    var dayAt = null, minAt = null, f10 = 0, f24 = 0, f, t;
    for (i = 0; i < d.fail.length; i += 1) {
      f = d.fail[i];
      if (f.who !== who) continue;
      t = tms(f.at);
      if (t > now - 10 * MINUTE) f10 += 1;
      if (t > now - DAY) f24 += 1;
      if (f.lock === 'day' && t > now - DAY) dayAt = dayAt === null ? t : Math.max(dayAt, t);
      if ((f.lock === 'min' || f.lock === 'day') && t > now - 10 * MINUTE) minAt = minAt === null ? t : Math.max(minAt, t);
    }
    if (dayAt !== null) return { ok: false, err: 'locked', day: true, secs: Math.max(1, Math.ceil((dayAt + DAY - now) / 1000)) };
    if (minAt !== null) return { ok: false, err: 'locked', day: false, secs: Math.max(1, Math.ceil((minAt + 10 * MINUTE - now) / 1000)) };
    var hit = [], r;
    for (i = 0; i < rs.length; i += 1) {
      if (rs[i].nname === name && rs[i].pins.indexOf(pin) >= 0) hit.push(rs[i]);
    }
    if (hit.length === 0) {
      var lock = f24 + 1 >= 15 ? 'day' : (f10 + 1 >= 5 ? 'min' : '');
      d.fail.push({ who: who, at: pgts(now), lock: lock });
      if (lock === 'day') return { ok: false, err: 'locked', day: true, secs: 86400 };
      if (lock === 'min') return { ok: false, err: 'locked', day: false, secs: 600 };
      return { ok: false, err: 'nomatch' };
    }
    if (hit.length > 1) return { ok: false, err: 'many' };
    r = hit[0];
    d.fail = d.fail.filter(function (x) { return x.who !== who && x.who !== 'k:' + r.skey; });
    var key = X.hex64();
    d.key.push({
      kh: kh(key), sid: r.skey, rid: r.rid, pin: pin, sname: r.sname, cls: (r.cls || []).slice(),
      dev: X.left(str(a.p_dev), 40), made_by: '', created_at: pgts(now), last_at: pgts(now)
    });
    return { ok: true, key: key, name: r.sname };
  }

  function lec_home(d, a) {
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var rs = roster(d), i, x, hit = false, sname = null, cls = null, same = 0, c = null;
    for (i = 0; i < rs.length; i += 1) {
      x = rs[i];
      if (!(x.skey === k.sid || (k.rid !== '' && x.rid === k.rid))) continue;
      if (x.skey === k.sid) { hit = true; sname = x.sname; cls = x.cls; }
      else { same += 1; c = x; }
    }
    if (!hit && same === 1) {
      if (k.pin !== '' && c.pins.indexOf(k.pin) >= 0) {
        move(d, k.sid, c.skey, c.sname);
        hit = true; sname = c.sname; cls = c.cls;
      }
    }
    var now = pgts(nowMs());
    if (!hit) {
      k.cls = [];
      k.last_at = now;
      return { ok: false, err: 'gone' };
    }
    k.sname = sname;
    k.cls = (cls || []).slice();
    k.last_at = now;

    var list = [], l, p, n, j, q;
    for (i = 0; i < d.lecture.length; i += 1) {
      l = d.lecture[i];
      if (!isOpen(l, cls)) continue;
      p = findProgress(d, k.sid, l.id);
      n = 0;
      for (j = 0; j < d.qna.length; j += 1) {
        x = d.qna[j];
        if (x.lecture_id !== l.id || x.teacher == null || x.stu_seen || x.deleted || x.parent == null) continue;
        q = findQna(d, x.parent);
        if (q && q.sid === k.sid && !q.deleted) n += 1;
      }
      list.push({
        o: i, ord: l.lesson_on || l.posted_on, ca: tms(l.created_at),
        v: {
          id: l.id, title: l.title, book: l.book, yt: l.yt, dur: l.dur, chapters: l.chapters,
          lesson_on: l.lesson_on, posted_on: l.posted_on,
          until: l.until == null ? null : l.until, ended: ended(l),
          pct: p ? p.pct : 0, pos: p ? p.pos : 0, watched: p ? p.watched : 0, seen: p ? p.seen : '',
          first_at: p ? p.first_at : null, last_at: p ? p.last_at : null, done_at: p ? p.done_at : null,
          confirmed: !!p && p.done_by != null,
          ans_new: n
        }
      });
    }
    /* SQL 차례: coalesce(lesson_on, posted_on) 오름차순 → created_at 오름차순 */
    list.sort(function (A, B) {
      if (A.ord !== B.ord) return A.ord < B.ord ? -1 : 1;
      if (A.ca !== B.ca) return A.ca - B.ca;
      return A.o - B.o;
    });
    var out = [];
    for (i = 0; i < list.length; i += 1) out.push(list[i].v);
    var cs = findConsent(d, k.sid);
    return {
      ok: true, me: { name: sname },
      consent: cs ? { choice: cs.choice, ver: cs.ver, at: cs.at } : null,
      consent_ver: CONSENT_VER,
      lectures: out
    };
  }

  function lec_consent(d, a) {
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var ch = a.p_choice == null ? '' : a.p_choice;
    if (ch !== 'agree' && ch !== 'none') return { ok: false, err: 'input' };
    if (a.p_ver !== CONSENT_VER) return { ok: false, err: 'ver', ver: CONSENT_VER };
    if (!d.consent) d.consent = [];
    var c = findConsent(d, k.sid), now = pgts(nowMs());
    if (!c) {
      c = { sid: k.sid, choice: ch, ver: a.p_ver, at: now };
      d.consent.push(c);
    } else {
      c.choice = ch; c.ver = a.p_ver; c.at = now;
    }
    return { ok: true, choice: c.choice, ver: c.ver, at: c.at };
  }

  function lec_beat(d, a) {
    var X = L();
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var l = findLecture(d, a.p_lecture);
    if (!l || !isOpen(l, k.cls)) return { ok: false, err: 'lecture' };
    if (ended(l)) return { ok: false, err: 'ended' };
    if (!agreed(d, k.sid)) return { ok: false, err: 'no_consent' };
    if (a.p_session == null) return { ok: false, err: 'input' };

    /* 배속은 0.25~2 로 자름. 인정 초 상한 = 경과 × 배속(이번 보기에서 가장 빠른 배속 · 1 아래는 1) + 30,
       새로 켜지는 칸 상한은 배속과 상관없이 벽시계 2배 그대로(1배일 때는 지난 결과와 같음) */
    var rate = a.p_rate == null ? 1 : +a.p_rate;
    rate = Math.min(2, Math.max(0.25, rate));
    var nowN = nowMs(), now = pgts(nowN);
    var dur = l.dur || 0, pd = a.p_dur == null ? 0 : a.p_dur;
    if (dur <= 0 && pd >= 30 && pd <= MAX_DUR) {
      l.dur = pd;               /* updated_at 은 그대로(SQL 에 갱신 장치가 없음) */
      durChanged(d, l.id, pd);  /* 길이 바뀜 처리는 아래 «session» 오류가 나도 남음 */
      dur = pd;
    }
    var n = dur > 0 ? Math.ceil(dur / 10) : 0;
    var seenIn = str(a.p_seen);
    var vin = /^[01]{0,2160}$/.test(seenIn) ? seenIn : '';

    var s = null, i, isNew = false;
    for (i = 0; i < d.session.length; i += 1) { if (d.session[i].id === a.p_session) s = d.session[i]; }
    if (!s) {
      var f0 = Math.max(a.p_from == null ? 0 : a.p_from, 0);
      s = {
        id: a.p_session, sid: k.sid, sname: k.sname, lecture_id: l.id, started_at: now, ended_at: now,
        watched: 0, from_s: f0, to_s: f0, dev: X.left(str(a.p_dev), 40), rate: rate
      };
      d.session.push(s);
      isNew = true;
    }
    if (s.sid !== k.sid || s.lecture_id !== l.id) return { ok: false, err: 'session' };
    s.rate = Math.max(s.rate == null ? 1 : s.rate, rate);

    var r = Math.max(1, s.rate);
    var ela = (nowN - tms(s.ended_at)) / 1000;
    var capW = isNew ? 150 : Math.max(90, rhaz(ela) + 30);
    var cap = isNew ? rhaz(120 * r) + 30 : Math.max(90, rhaz(ela * r) + 30);
    var scale = a.p_scale == null ? 1 : +a.p_scale;
    if (!(isFinite(scale) && scale > 0)) scale = 1;
    if (scale !== 1) { /* 연습용만: 빨리 도는 가짜 재생기 */
      cap = Math.max(0, Math.round(cap * scale));
      capW = Math.max(0, Math.round(capW * scale));
    }
    var delta = Math.min(Math.max((a.p_total == null ? 0 : a.p_total) - s.watched, 0), cap);

    var old = { watched: s.watched, from_s: s.from_s, to_s: s.to_s };
    if (isNew) s.started_at = pgts(nowN - delta * 1000);
    s.ended_at = now;
    s.watched = old.watched + delta;
    s.from_s = Math.min(old.from_s, Math.max(a.p_from == null ? old.from_s : a.p_from, 0));
    s.to_s = Math.max(old.to_s, Math.min(a.p_to == null ? 0 : a.p_to, MAX_DUR));

    var p = findProgress(d, k.sid, l.id);
    if (!p) {
      p = {
        sid: k.sid, lecture_id: l.id, sname: k.sname, seen: '', watched: 0, pos: 0, pct: 0, sessions: 0,
        first_at: now, last_at: now, done_at: null, done_by: null, done_note: '', done_by_at: null
      };
      d.progress.push(p);
    }
    var seen = X.bmOr(p.seen, vin, Math.ceil(Math.min(delta, capW) / 5) + 2);
    if (n > 0) seen = seen.slice(0, n);
    var pct = X.bmPct(seen, dur);
    var pos = Math.max(0, Math.min(a.p_pos == null ? 0 : a.p_pos, dur > 0 ? dur : MAX_DUR));
    p.sname = k.sname;
    p.seen = seen;
    p.watched = p.watched + delta;
    p.pos = pos;
    p.pct = pct;
    p.sessions = p.sessions + (isNew ? 1 : 0);
    p.last_at = now;
    p.done_at = p.done_at || (pct >= 90 ? now : null);
    return { ok: true, pct: pct, watched: p.watched, done: pct >= 90, dur: dur, seen: seen };
  }

  function lec_qna_list(d, a) {
    var X = L();
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var l = findLecture(d, a.p_lecture);
    if (!l || !isOpen(l, k.cls)) return { ok: false, err: 'lecture' };
    var i, x, q, unread = [];
    /* 이번에 처음 읽는 답이 달린 내 질문(unread): 읽음 표시와 함께 모음 */
    for (i = 0; i < d.qna.length; i += 1) {
      x = d.qna[i];
      if (x.parent == null || x.lecture_id !== l.id || x.teacher == null || x.stu_seen) continue;
      q = findQna(d, x.parent);
      if (q && q.sid === k.sid) {
        x.stu_seen = true;
        if (!x.deleted && unread.indexOf(x.parent) < 0) unread.push(x.parent);
      }
    }
    var rows = [];
    for (i = 0; i < d.qna.length; i += 1) {
      x = d.qna[i];
      if (x.lecture_id !== l.id || x.deleted) continue;
      q = x.parent == null ? null : findQna(d, x.parent);
      if (q && q.deleted) continue;
      var mine = x.sid != null && x.sid === k.sid;
      var vis;
      if (x.parent == null) vis = !x.private || mine;
      else vis = !!q && (!q.private || (q.sid != null && q.sid === k.sid));
      if (!vis) continue;
      rows.push({
        o: i, ca: tms(x.created_at),
        v: {
          id: x.id, parent: x.parent, at_s: x.at_s, body: x.body,
          private: q ? q.private : x.private,
          kind: q && q.kind != null ? q.kind : (x.kind != null ? x.kind : 'content'),
          created_at: x.created_at, mine: mine, teacher: x.teacher != null,
          who: x.teacher != null ? x.teacher : (mine ? '나' : X.mask(x.sname)),
          answered: answered(d, x),
          unread: x.parent == null && unread.indexOf(x.id) >= 0
        }
      });
    }
    rows.sort(function (A, B) { return (A.ca - B.ca) || (A.o - B.o); });
    var out = [];
    for (i = 0; i < rows.length; i += 1) out.push(rows[i].v);
    return { ok: true, items: out };
  }

  function lec_ask(d, a) {
    var X = L();
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var l = findLecture(d, a.p_lecture);
    if (!l || !isOpen(l, k.cls)) return { ok: false, err: 'lecture' };
    if (ended(l)) return { ok: false, err: 'ended' };
    if (!agreed(d, k.sid)) return { ok: false, err: 'no_consent' };
    var body = X.btrim(str(a.p_body)), bn = X.clen(body);
    var kind = a.p_kind == null ? 'content' : a.p_kind;
    if (bn < 1 || bn > 1000 || (kind !== 'content' && kind !== 'tech')) return { ok: false, err: 'input' };
    var nowN = nowMs(), cnt = 0, i;
    for (i = 0; i < d.qna.length; i += 1) {
      if (d.qna[i].sid === k.sid && tms(d.qna[i].created_at) > nowN - HOUR) cnt += 1;
    }
    if (cnt >= 20) return { ok: false, err: 'many' };
    var q = null;
    if (a.p_parent != null) {
      q = findQna(d, a.p_parent);
      if (q && !(q.lecture_id === l.id && q.parent == null && !q.deleted)) q = null;
      if (!q || q.sid !== k.sid) return { ok: false, err: 'parent' };
    }
    var top = a.p_parent == null;
    var id = X.uuid();
    d.qna.push({
      id: id, lecture_id: l.id, parent: top ? null : a.p_parent, sid: k.sid, sname: k.sname, teacher: null,
      at_s: top && a.p_at != null && a.p_at >= 0 && a.p_at <= MAX_DUR ? a.p_at : null,
      body: body,
      private: top ? (a.p_private == null ? false : a.p_private) : !!q.private,
      kind: top ? kind : (q.kind == null ? 'content' : q.kind),
      stu_seen: false, deleted: false, created_at: pgts(nowN)
    });
    return { ok: true, id: id };
  }

  function lec_qdel(d, a) {
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var i, x = null, y;
    for (i = 0; i < d.qna.length; i += 1) {
      y = d.qna[i];
      if (a.p_id != null && y.id === a.p_id && y.sid === k.sid && !y.deleted) x = y;
    }
    if (!x) return { ok: false, err: 'none' };
    if (answered(d, x)) return { ok: false, err: 'answered' };
    x.deleted = true;
    return { ok: true };
  }

  function lec_logout(d, a) {
    var h = kh(a.p_key);
    d.key = d.key.filter(function (k) { return !(h != null && k.kh === h && k.made_by === ''); });
    return { ok: true };
  }

  /* ------------------------------------- C1 결석한 날 수업(class-setup.sql 의 C1 묶음과 같은 규칙)
     출결은 히즈북스 자료를 읽기만 합니다(영상을 봐도 출결은 그대로 · 아무것도 쓰지 않음).
     연습 자료 d.app = { main: {records, checkins, noShowExcused, sessions, mkup, closedDays},
                         'pt-rec-YYYY-MM': {records}, 'pt-ck-YYYY-MM': {checkins}, 'pt-old-YYYY-MM': {noShowExcused, sessions, mkup} }
     반 · 학생 명단은 main.classes 자리에 d.classes 를 씁니다(lec__roster 와 같은 자료) */

  var ATT_FROM = '2026.07.15';
  var ATT_WK = ['일', '월', '화', '수', '목', '금', '토'];

  function isObj(v) { return !!v && typeof v === 'object' && !isArr(v); }
  /* jsonb -> 'k' : 객체가 아니거나 열쇠가 없으면 undefined(= SQL null) */
  function jget(o, k) { return isObj(o) && has(o, k) ? o[k] : undefined; }
  function objOr(v) { return isObj(v) ? v : {}; }
  function arrOr(v) { return isArr(v) ? v : []; }
  /* lec__num: 숫자면 그 값 · 아니면 0 */
  function attNum(v) { return typeof v === 'number' && isFinite(v) ? v : 0; }
  /* lec__pint: 앞쪽 숫자만(없으면 null) */
  function attPint(t) {
    var m = str(t).match(/^[ \t\n\v\f\r]*([+\-]?[0-9]+)/);
    return m ? Number(m[1]) : null;
  }
  /* lec__dnum: 2026-11-1 · 2026/11/01 → 2026.11.01 · 못 읽으면 '' */
  function attDnum(p) {
    var a = str(p).replace(/-/g, '.').replace(/\//g, '.').split('.'), y, m, dd;
    if (a.length < 3) return '';
    y = attPint(a[0]); m = attPint(a[1]); dd = attPint(a[2]);
    if (y == null || m == null || dd == null || y <= 0 || m <= 0 || dd <= 0) return '';
    return String(y) + '.' + ('0' + m).slice(-2) + '.' + ('0' + dd).slice(-2);
  }
  /* lec__closed: 휴원일(날짜 목록 또는 날짜 → {v}) */
  function attClosed(cd, dk) {
    if (isArr(cd)) return cd.indexOf(dk) >= 0;
    if (isObj(cd)) { var o = jget(cd, dk); return isObj(o) && L().truthy(o.v); }
    return false;
  }
  /* lec__held: 그 반 그날 보강 수업이 열림 */
  function attHeld(ses, cid, dk) {
    var X = L(), o = jget(ses, cid + '|' + dk);
    return X.truthy(o) && !X.truthy(jget(o, 'del')) && !X.truthy(jget(o, 'off')) && X.truthy(jget(o, 'start'));
  }
  /* lec__ctime: 그 반 그날 수업 시작(isEnd 거짓) · 끝(참) · 수업 없으면 '' */
  function attCtime(c, wd, dk, ses, isEnd) {
    var X = L(), cid, ov, sc, ds, tm, v, dy;
    if (!isObj(c)) return '';
    cid = X.jtext(jget(c, 'id'));
    if (str(dk) !== '' && isObj(ses) && cid != null && cid !== '') {
      ov = jget(ses, cid + '|' + dk);
      if (X.truthy(ov) && !X.truthy(jget(ov, 'del'))) {
        if (X.truthy(jget(ov, 'off'))) return '';
        if (isEnd) {
          if (X.truthy(jget(ov, 'end'))) return X.jtext(ov.end);
          if (X.truthy(jget(ov, 'start'))) return '';
        } else if (X.truthy(jget(ov, 'start'))) {
          return X.jtext(ov.start);
        }
      }
    }
    if (wd == null || wd < 0 || wd > 6) return '';
    dy = ATT_WK[wd];
    sc = jget(c, 'schedule');
    if (!sc || typeof sc !== 'object') sc = {};
    v = isArr(sc) ? sc[wd] : jget(sc, String(wd));
    ds = jget(sc, 'days');
    if (isArr(ds) && ds.length > 0) {
      if (ds.indexOf(dy) < 0) return '';
    } else if (typeof ds === 'string' && ds !== '') {
      if (ds.indexOf(dy) < 0) return '';
    } else if (v === undefined || v === null || v === '') {
      return '';
    }
    tm = jget(jget(sc, 'times'), dy);
    if (isEnd) {
      if (X.truthy(jget(tm, 'end'))) return X.jtext(tm.end);
      if (X.truthy(jget(sc, 'end'))) return X.jtext(sc.end);
      if (X.truthy(jget(c, 'endTime'))) return X.jtext(c.endTime);
    } else {
      if (X.truthy(jget(tm, 'start'))) return X.jtext(tm.start);
      if (X.truthy(v)) return X.jtext(v);
      if (X.truthy(jget(c, 'startTime'))) return X.jtext(c.startTime);
    }
    return '';
  }
  /* lec__stu: 학생 id 로 학생 찾기 — 모든 반에서 마지막 것 */
  function attStu(classes, rid) {
    var i, j, ss;
    classes = arrOr(classes);
    for (i = classes.length - 1; i >= 0; i -= 1) {
      ss = arrOr(jget(classes[i], 'students'));
      for (j = ss.length - 1; j >= 0; j -= 1) {
        if (isObj(ss[j]) && L().jtext(ss[j].id) === rid) return ss[j];
      }
    }
    return undefined;
  }
  /* lec__notyet: 그날 아직 시작 전 학생(반배정 대기 · 시작일/등록일이 그날보다 뒤) */
  function attNotYet(stu, dk) {
    var X = L(), sd, td;
    if (!isObj(stu)) return false;
    if (X.truthy(stu.pending)) return true;
    sd = attDnum(X.truthy(stu.startPlan) ? X.jtext(stu.startPlan) : (X.truthy(stu.registeredAt) ? X.jtext(stu.registeredAt) : ''));
    td = attDnum(dk);
    return sd !== '' && td !== '' && sd > td;
  }
  function dotDay(iso) { return str(iso).replace(/-/g, '.'); }
  function nextYm(ym) {
    var y = +ym.slice(0, 4), m = +ym.slice(5, 7) + 1;
    if (m > 12) { m = 1; y += 1; }
    return y + '-' + pad(m, 2);
  }
  /* 서울 지금 HH:MM */
  function nowHM() {
    var t = new Date(nowMs() + SEOUL);
    return pad(t.getUTCHours(), 2) + ':' + pad(t.getUTCMinutes(), 2);
  }
  /* 강의의 수업일(lesson_on + lesson_more) 중 lo..hi 안 · 겹침 없이 오름차순 */
  function attWin(l, lo, hi) {
    var a = arrOr(l.lesson_more).concat([l.lesson_on]), out = [], i;
    for (i = 0; i < a.length; i += 1) {
      if (a[i] && a[i] >= lo && a[i] <= hi && out.indexOf(a[i]) < 0) out.push(a[i]);
    }
    out.sort();
    return out;
  }
  /* lec__lcls: 그 수업일에 든 반(lesson_cls 의 'YYYY-MM-DD' 줄 · 빈 글자는 뺌) · 없거나 비면 null(= 강의의 모든 반) */
  function lcls(l, dISO) {
    var m = l && isObj(l.lesson_cls) ? l.lesson_cls : null, a, out = [], i, v;
    if (!m || !has(m, dISO) || !isArr(m[dISO])) return null;
    a = m[dISO];
    for (i = 0; i < a.length; i += 1) {
      v = a[i];
      if (v == null) continue;
      v = typeof v === 'string' ? v : (typeof v === 'object' ? JSON.stringify(v) : String(v));
      if (v !== '') out.push(v);
    }
    return out.length ? out : null;
  }
  function lcOk(lc, cid) { return lc == null || lc.indexOf(cid) >= 0; }
  /* 학생에게 보이는 강의 수업일: 그날 반이 정해져 있으면 내 반이 든 날만(SQL lec 의 lc && v_cls) */
  function lecDays(l, dd, cls) {
    var out = [], i, j, lc, ok;
    for (i = 0; i < dd.length; i += 1) {
      lc = LEGACY ? null : lcls(l, dd[i]);
      ok = lc == null;
      for (j = 0; !ok && j < cls.length; j += 1) { if (lc.indexOf(cls[j]) >= 0) ok = true; }
      if (ok) out.push(dd[i]);
    }
    return out;
  }
  function covers(ids, cid) { return ids.indexOf(cid) >= 0 || ids.indexOf('*') >= 0; }
  /* 반마다 수업일(SQL 의 cd → p_cdays): 반이 강의에 들고 그날 반이 정해져 있으면 그 반일 때만 · 옛 셈(LEGACY)은 모든 반에 모든 날 */
  function attCdays(lecs, cids) {
    var o = {}, i, j, q, l, ids, dd, lc, c;
    for (q = 0; q < cids.length; q += 1) {
      c = cids[q];
      if (has(o, c)) continue;
      o[c] = [];
      for (i = 0; i < lecs.length; i += 1) {
        l = lecs[i].l; ids = l.class_ids || []; dd = lecs[i].days;
        if (!covers(ids, c)) continue;
        for (j = 0; j < dd.length; j += 1) {
          lc = LEGACY ? null : lcls(l, dd[j]);
          if (lcOk(lc, c) && o[c].indexOf(dd[j]) < 0) o[c].push(dd[j]);
        }
      }
      o[c].sort();
      if (!o[c].length) delete o[c];
    }
    return o;
  }

  /* lec__att_data: 출결에 필요한 것만 한 묶음으로(학생 · 날짜에 걸리는 것만) · 같은 열쇠는 시각 도장 큰 쪽 · 같으면 달 줄
     달 줄: 일지 · 등하원 · 결석 예정 · 날짜별 수업 = 수업일이 든 달만 / 개인 보강 = 가장 이른 수업일 한 달 앞 ~ 이번 달(C1 고침 L-3) */
  function attData(d, rids, days) {
    var app = objOr(d.app), main = objOr(app.main), t = today();
    var dks = [], yms = [], mym = [], minD = null, i, x, ym, k, id;
    for (i = 0; i < days.length; i += 1) {
      x = days[i];
      if (!x) continue;
      if (dks.indexOf(dotDay(x)) < 0) dks.push(dotDay(x));
      if (yms.indexOf(x.slice(0, 7)) < 0) yms.push(x.slice(0, 7));
      if (minD == null || x < minD) minD = x;
    }
    ym = (minD == null || minD > t ? t : minD).slice(0, 7);
    ym = (+ym.slice(5, 7) === 1) ? (+ym.slice(0, 4) - 1) + '-12' : ym.slice(0, 5) + pad(+ym.slice(5, 7) - 1, 2);
    while (ym <= t.slice(0, 7)) { mym.push(ym); ym = nextYm(ym); }

    function pick(best, key, val, tt, pri) {
      var b = best[key];
      if (!b || tt > b.t || (tt === b.t && pri > b.pri)) best[key] = { v: val, t: tt, pri: pri };
    }
    function flat(best) { var o = {}, kk; for (kk in best) { if (has(best, kk)) o[kk] = best[kk].v; } return o; }

    /* 일지: '반|학생|날짜' */
    var rb = {}, rsrc = [{ pri: 0, a: arrOr(main.records) }];
    for (i = 0; i < yms.length; i += 1) {
      id = 'pt-rec-' + yms[i];
      if (has(app, id)) rsrc.push({ pri: 1, a: arrOr(jget(app[id], 'records')) });
    }
    rsrc.forEach(function (s) {
      var j, v, cid, sid, dt;
      for (j = 0; j < s.a.length; j += 1) {
        v = s.a[j];
        if (!isObj(v)) continue;
        cid = L().jtext(v.classId); sid = L().jtext(v.studentId); dt = L().jtext(v.date);
        if (cid == null || cid === '' || rids.indexOf(sid) < 0 || dks.indexOf(dt) < 0) continue;
        pick(rb, cid + '|' + sid + '|' + dt, v, attNum(v.editT), s.pri);
      }
    });

    /* 등하원: '학생|날짜' */
    var cb = {}, csrc = [{ pri: 0, o: objOr(main.checkins) }];
    for (i = 0; i < yms.length; i += 1) {
      id = 'pt-ck-' + yms[i];
      if (has(app, id)) csrc.push({ pri: 1, o: objOr(jget(app[id], 'checkins')) });
    }
    csrc.forEach(function (s) {
      var kk, p;
      for (kk in s.o) {
        if (!has(s.o, kk)) continue;
        p = kk.split('|');
        if (rids.indexOf(p[0]) < 0 || dks.indexOf(p.length > 1 ? p[1] : '') < 0) continue;
        pick(cb, kk, s.o[kk], attNum(jget(s.o[kk], 't')), s.pri);
      }
    });

    /* 결석 예정 · 날짜별 수업 · 개인 보강 */
    var nb = {}, sb = {}, mb = {}, osrc = [{ pri: 0, o: main, q: [0, 1, 2] }], ol = [], qs;
    for (i = 0; i < yms.length; i += 1) { if (ol.indexOf(yms[i]) < 0) ol.push(yms[i]); }
    for (i = 0; i < mym.length; i += 1) { if (ol.indexOf(mym[i]) < 0) ol.push(mym[i]); }
    for (i = 0; i < ol.length; i += 1) {
      id = 'pt-old-' + ol[i];
      if (!has(app, id)) continue;
      qs = [];
      if (yms.indexOf(ol[i]) >= 0) { qs.push(0); qs.push(1); }
      if (mym.indexOf(ol[i]) >= 0) qs.push(2);
      osrc.push({ pri: 1, o: objOr(app[id]), q: qs });
    }
    osrc.forEach(function (s) {
      var parts = [['noShowExcused', nb], ['sessions', sb], ['mkup', mb]], q, m, kk, p, ok;
      for (q = 0; q < parts.length; q += 1) {
        if (s.q.indexOf(q) < 0) continue;
        m = objOr(jget(s.o, parts[q][0]));
        for (kk in m) {
          if (!has(m, kk)) continue;
          p = kk.split('|');
          if (q === 0) ok = rids.indexOf(p[0]) >= 0 && dks.indexOf(p.length > 1 ? p[1] : '') >= 0;
          else if (q === 1) ok = dks.indexOf(p.length > 1 ? p[1] : '') >= 0;
          else ok = rids.indexOf(p[0]) >= 0;
          if (ok) pick(parts[q][1], kk, m[kk], attNum(jget(m[kk], 't')), s.pri);
        }
      }
    });
    k = has(main, 'closedDays') ? main.closedDays : null;
    return { classes: arrOr(d.classes), rec: flat(rb), ck: flat(cb), nse: flat(nb), ses: flat(sb), mk: flat(mb), cd: k === undefined ? null : k };
  }

  /* lec__att_core: (학생 rids[i], 반 cids[i]) 마다 그 반의 수업일(cdays[반] · 오늘까지)마다 {rid, cid, day, att: in|abs|sub|'', mk}
     cdays 가 배열이면 모든 반에 같은 날들(옛 셈) */
  function attCore(p, rids, cids, cdays, tISO, now) {
    var X = L(), cls = arrOr(p.classes), rec = objOr(p.rec), ck = objOr(p.ck), nse = objOr(p.nse),
        ses = objOr(p.ses), mk = objOr(p.mk), cd = p.cd, tk = dotDay(tISO), ds, out = [];
    var i, j, rid, cid, c, stu, mkf, kk, e, dISO, dk, a, x, wd, st, en, att, pp, src;
    for (i = 0; i < rids.length; i += 1) {
      rid = rids[i]; cid = cids[i];
      if (str(rid) === '' || str(cid) === '') continue;
      src = isArr(cdays) ? cdays : (isObj(cdays) && isArr(cdays[cid]) ? cdays[cid] : []);
      ds = [];
      for (j = 0; j < src.length; j += 1) {
        if (typeof src[j] === 'string' && src[j] && src[j] <= tISO && ds.indexOf(src[j]) < 0) ds.push(src[j]);
      }
      ds.sort();
      if (!ds.length) continue;
      c = null;
      for (j = 0; j < cls.length; j += 1) {
        if (isObj(cls[j]) && X.jtext(cls[j].id) === cid) { c = cls[j]; break; }
      }
      stu = attStu(cls, rid);
      mkf = [];
      for (kk in mk) {
        if (!has(mk, kk)) continue;
        e = mk[kk];
        if (kk.split('|')[0] !== rid || !isObj(e) || X.truthy(e.del) || X.truthy(e.free)) continue;
        x = X.jtext(e.from);
        if (x != null && x !== '' && mkf.indexOf(x) < 0) mkf.push(x);
      }
      for (j = 0; j < ds.length; j += 1) {
        dISO = ds[j]; dk = dotDay(dISO); a = '';
        x = jget(rec, cid + '|' + rid + '|' + dk);
        if (isObj(x) && X.truthy(x.attendance)) {
          a = X.jtext(x.attendance);
        } else if (!attNotYet(stu, dk)) {
          x = jget(mk, rid + '|' + dk);
          if (X.truthy(x) && !X.truthy(jget(x, 'del'))) {
            a = '보강';
          } else {
            x = jget(ck, rid + '|' + dk);
            if (X.truthy(x) && !X.truthy(jget(x, 'del')) && X.truthy(jget(x, 'in'))) {
              a = '출석';
            } else if (attClosed(cd, dk) && !attHeld(ses, cid, dk)) {
              a = '';
            } else {
              x = jget(nse, rid + '|' + dk);
              if (X.truthy(x) && !X.truthy(jget(x, 'del')) && dk >= ATT_FROM) {
                a = '결석';
              } else if (c) {
                pp = dISO.split('-');
                wd = new Date(Date.UTC(+pp[0], +pp[1] - 1, +pp[2])).getUTCDay();
                st = attCtime(c, wd, dk, ses, false);
                if (st !== '' && dk >= ATT_FROM) {
                  if (dk < tk) {
                    a = '결석';
                  } else if (dk === tk) {
                    en = attCtime(c, wd, dk, ses, true);
                    if (en !== '' && str(now) > en) a = '결석';
                  }
                }
              }
            }
          }
        }
        att = (a === '출석' || a === '지각') ? 'in' : (a === '결석' ? 'abs' : (a === '보강' ? 'sub' : ''));
        out.push({ rid: rid, cid: cid, day: dISO, att: att, mk: att === 'abs' && mkf.indexOf(dk) >= 0 });
      }
    }
    return out;
  }

  /* 한 강의 · 한 학생(또는 학생 하나의 줄들)을 날짜별로 모아 강의 하나의 판정으로(SQL per → agg) */
  function attAgg(rows, ldays, ids, rowOk, l) {
    var per = [], i, j, r, ins, abs, mkd, n, out, lc;
    for (i = 0; i < ldays.length; i += 1) {
      ins = false; abs = false; mkd = false; n = 0;
      lc = (l && !LEGACY) ? lcls(l, ldays[i]) : null;
      for (j = 0; j < rows.length; j += 1) {
        r = rows[j];
        if (r.day !== ldays[i] || !(ids.indexOf(r.cid) >= 0 || ids.indexOf('*') >= 0) || !lcOk(lc, r.cid) || (rowOk && !rowOk(r))) continue;
        n += 1;
        if (r.att === 'in') ins = true;
        if (r.att === 'abs') abs = true;
        if (r.mk) mkd = true;
      }
      if (n) per.push({ day: ldays[i], att: ins ? 'in' : (abs ? 'abs' : ''), mk: mkd });
    }
    if (!per.length) return null;
    out = { att: '', day: null, mk: false };
    var anyAbs = false, anyIn = false, maxAbs = null, maxIn = null, allMk = true;
    for (i = 0; i < per.length; i += 1) {
      if (per[i].att === 'abs') { anyAbs = true; if (maxAbs == null || per[i].day > maxAbs) maxAbs = per[i].day; if (!per[i].mk) allMk = false; }
      if (per[i].att === 'in') { anyIn = true; if (maxIn == null || per[i].day > maxIn) maxIn = per[i].day; }
    }
    out.att = anyAbs ? 'abs' : (anyIn ? 'in' : '');
    out.day = maxAbs != null ? maxAbs : maxIn;
    out.mk = anyAbs ? allMk : false;
    return out;
  }

  /* lec_att: 학생 화면 · 내가 볼 수 있는 강의마다 «결석한 날 수업»(abs) · «교실에서 들음»(in) · 모름은 뺌 */
  function lec_att(d, a) {
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var t = today(), lo = dayStr(-62), rs = roster(d), r = null, i, j, l, opens = [], days = [], items = [], rows, g, rids;
    for (i = 0; i < rs.length; i += 1) { if (rs[i].skey === k.sid) r = rs[i]; }
    if (r && r.cls.length) {
      for (i = 0; i < d.lecture.length; i += 1) {
        l = d.lecture[i];
        if (!isOpen(l, r.cls)) continue;
        opens.push({ l: l, days: attWin(l, lo, t) });
        for (j = 0; j < opens[opens.length - 1].days.length; j += 1) {
          if (days.indexOf(opens[opens.length - 1].days[j]) < 0) days.push(opens[opens.length - 1].days[j]);
        }
      }
    }
    /* C1 고침(11-16): 반마다 그 반의 수업일만(수업일마다 반이 정해져 있으면 그 반일 때만) */
    var cdays = LEGACY ? days : attCdays(opens, r ? r.cls : []), ad = [], kk;
    if (!LEGACY) {
      for (kk in cdays) { if (has(cdays, kk)) { for (j = 0; j < cdays[kk].length; j += 1) { if (ad.indexOf(cdays[kk][j]) < 0) ad.push(cdays[kk][j]); } } }
      days = ad;
    }
    if (days.length) {
      rids = [];
      for (i = 0; i < r.cls.length; i += 1) rids.push(r.rid);
      rows = attCore(attData(d, [r.rid], days), rids, r.cls, cdays, t, nowHM());
      for (i = 0; i < opens.length; i += 1) {
        g = attAgg(rows, opens[i].days, opens[i].l.class_ids || [], null, opens[i].l);
        if (!g || g.att === '') continue;
        items.push({ id: opens[i].l.id, att: g.att, day: g.day, days: lecDays(opens[i].l, opens[i].days, r.cls), mk: g.mk });
      }
      items.sort(function (x, y) { return cmpC(y.day, x.day) || cmpC(x.id, y.id); });
    }
    return { ok: true, today: t, items: items };
  }

  /* lec_paper (C3 · C7): 열린 강의마다 실행기 묶음의 지문 줄 [{no, at, stop, wb}] · 판서 쪽은 안 보냄 · 줄 없는 강의는 뺌 */
  function lec_paper(d, a) {
    var k = findKey(d, a.p_key);
    if (!k) return { ok: false, err: 'key' };
    var items = [], i, j, l, ri, e, p;
    for (i = 0; i < d.lecture.length; i += 1) {
      l = d.lecture[i];
      if (!isOpen(l, k.cls)) continue;
      if (ended(l)) continue;   // 끝난 강의는 플레이어를 열지 않으므로 지문 줄도 안 보냄(검수 B2 L-8 · SQL 과 같음)
      ri = l.runner && isArr(l.runner.items) ? l.runner.items : [];
      if (!ri.length) continue;
      p = [];
      for (j = 0; j < ri.length; j += 1) {
        e = ri[j];
        if (!e || typeof e !== 'object' || isArr(e)) continue;
        p.push({
          no: L().left(e.no == null ? '' : String(e.no), 40),
          at: typeof e.at === 'number' && isFinite(e.at) ? e.at : null,
          stop: typeof e.stop === 'number' && isFinite(e.stop) ? e.stop : null,
          wb: L().left(e.wb == null ? '' : String(e.wb), 40)
        });
      }
      items.push({ id: l.id, p: p });
    }
    items.sort(function (x, y) { return cmpC(x.id, y.id); });
    return { ok: true, items: items };
  }

  /* lec_att_staff: 선생님 화면 · 내 반(관리자는 모든 반) 학생 × 수업일이 62일 안인 강의의 출결 ·
     시작 전 학생 · «결석한 날 수업 덜 본 학생» 띠 */
  function lec_att_staff(d) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var name = ME.name, admin = !!ME.admin, t = today(), lo = dayStr(-62), b13 = dayStr(-13), tk = dotDay(t);
    var cl = classRows(d).filter(function (c) { return admin || c.owner === name; });
    var scope = cl.map(function (c) { return c.id; });
    function inScope(cs) { for (var q = 0; q < cs.length; q += 1) { if (scope.indexOf(cs[q]) >= 0) return true; } return false; }
    function covers(ids, cid) { return ids.indexOf(cid) >= 0 || ids.indexOf('*') >= 0; }
    var ro = roster(d).filter(function (r) { return inScope(r.cls); });
    var pairs = [], seen = {}, i, j, l, ids, days = [], lecs = [], ns = [], cells = [], lectures = [], bandN = 0, items = [];
    for (i = 0; i < ro.length; i += 1) {
      for (j = 0; j < ro[i].cls.length; j += 1) {
        if (has(seen, ro[i].rid + '\u0001' + ro[i].cls[j])) continue;
        seen[ro[i].rid + '\u0001' + ro[i].cls[j]] = 1;
        pairs.push({ rid: ro[i].rid, cid: ro[i].cls[j] });
      }
    }
    pairs.sort(function (x, y) { return cmpC(x.rid, y.rid) || cmpC(x.cid, y.cid); });
    for (i = 0; i < d.lecture.length; i += 1) {
      l = d.lecture[i];
      ids = l.class_ids || [];
      if (!(inScope(ids) || ids.indexOf('*') >= 0)) continue;
      lecs.push({ l: l, days: attWin(l, lo, t) });
      for (j = 0; j < lecs[lecs.length - 1].days.length; j += 1) {
        if (days.indexOf(lecs[lecs.length - 1].days[j]) < 0) days.push(lecs[lecs.length - 1].days[j]);
      }
    }
    for (i = 0; i < ro.length; i += 1) {
      if (attNotYet(attStu(d.classes, ro[i].rid), tk)) ns.push(ro[i].skey);
    }
    ns.sort(cmpC);

    /* C1 고침(11-16): 학생 · 반 짝마다 그 반의 수업일만 */
    var cdays = LEGACY ? days : attCdays(lecs, pairs.map(function (p) { return p.cid; })), kd;
    if (!LEGACY) {
      days = [];
      for (kd in cdays) { if (has(cdays, kd)) { for (j = 0; j < cdays[kd].length; j += 1) { if (days.indexOf(cdays[kd][j]) < 0) days.push(cdays[kd][j]); } } }
    }
    if (days.length && pairs.length) {
      var rows = attCore(attData(d, pairs.map(function (p) { return p.rid; }), days),
        pairs.map(function (p) { return p.rid; }), pairs.map(function (p) { return p.cid; }), cdays, t, nowHM());
      lecs.forEach(function (L1) {
        var lids = L1.l.class_ids || [];
        ro.forEach(function (s) {
          var hit = false, q;
          for (q = 0; q < s.cls.length; q += 1) { if (scope.indexOf(s.cls[q]) >= 0 && covers(lids, s.cls[q])) hit = true; }
          if (!hit) return;
          var g = attAgg(rows, L1.days, lids, function (r) { return r.rid === s.rid && s.cls.indexOf(r.cid) >= 0; }, L1.l);
          if (g && g.att !== '') cells.push({ l: L1.l.id, s: s.skey, a: g.att, d: g.day, mk: g.mk });
        });
      });
      var by = {}, order = [];
      cells.forEach(function (c) {
        if (!has(by, c.l)) { by[c.l] = { l: c.l, ins: [], abss: [] }; order.push(c.l); }
        if (c.a === 'in') by[c.l].ins.push(c.s);
        if (c.a === 'abs') by[c.l].abss.push({ s: c.s, d: c.d, mk: c.mk });
      });
      order.sort(cmpC);
      lectures = order.map(function (id) {
        var g = by[id];
        g.ins.sort(cmpC);
        g.abss.sort(function (x, y) { return cmpC(x.s, y.s); });
        return { l: id, 'in': g.ins, abs: g.abss };
      });

      var st = [];
      cells.forEach(function (c) {
        if (c.a !== 'abs' || c.mk || !(c.d >= b13 && c.d <= t) || ns.indexOf(c.s) >= 0) return;
        var lec = findLecture(d, c.l), s = null, q;
        if (!lec) return;
        for (q = 0; q < ro.length; q += 1) { if (ro[q].skey === c.s) s = ro[q]; }
        if (!s) return;
        if (lec.hidden || (lec.posted_on || t) > t || ended(lec)) return;
        var p = findProgress(d, s.skey, lec.id), cs = findConsent(d, s.skey);
        if (!((p ? p.pct || 0 : 0) < 90) || (p && p.done_by != null)) return;
        if (cs && cs.choice === 'none') return;
        var blc = LEGACY ? null : lcls(lec, c.d);
        cl.forEach(function (k) {
          if (s.cls.indexOf(k.id) < 0 || !covers(lec.class_ids || [], k.id) || !lcOk(blc, k.id)) return;
          st.push({ lid: lec.id, title: lec.title, lca: lec.created_at, d: c.d, cid: k.id, cname: k.name, skey: s.skey, sname: s.sname });
        });
      });
      var stu = {}, gb = {}, gk = [];
      st.forEach(function (x) {
        stu[x.skey] = 1;
        var key = [x.lid, x.title, x.lca, x.cid, x.cname].join('\u0001');
        if (!has(gb, key)) { gb[key] = { lid: x.lid, title: x.title, lca: x.lca, cid: x.cid, cname: x.cname, day: x.d, rows: [] }; gk.push(key); }
        if (x.d > gb[key].day) gb[key].day = x.d;
        gb[key].rows.push(x);
      });
      for (var sk in stu) { if (has(stu, sk)) bandN += 1; }
      var grp = gk.map(function (key) { return gb[key]; });
      grp.sort(function (x, y) {
        return cmpC(y.day, x.day) || cmpAtDesc(x.lca, y.lca) || cmpC(x.cname, y.cname) || cmpC(x.cid, y.cid) || cmpC(x.lid, y.lid);
      });
      items = grp.map(function (g) {
        g.rows.sort(function (x, y) { return cmpC(x.sname, y.sname) || cmpC(x.skey, y.skey); });
        return {
          cls: g.cid, cname: g.cname, lecture: g.lid, title: g.title, day: g.day, n: g.rows.length,
          names: g.rows.map(function (x) { return x.sname; })
        };
      });
    }
    return { ok: true, today: t, lectures: lectures, notstarted: ns, band: { n: bandN, items: items } };
  }

  var IMPL = {
    lec_login: lec_login, lec_home: lec_home, lec_consent: lec_consent, lec_beat: lec_beat, lec_qna_list: lec_qna_list,
    lec_ask: lec_ask, lec_qdel: lec_qdel, lec_logout: lec_logout, lec_att: lec_att, lec_paper: lec_paper
  };

  /* 함수 모양(PostgREST 와 같게: 이름이 모자라거나 남으면 404 PGRST202 · 값 꼴이 틀리면 400) */
  var SIG = {
    lec_login: { p_name: 'text', p_pin: 'text', p_dev: 'text?' },
    lec_home: { p_key: 'text' },
    lec_consent: { p_key: 'text', p_choice: 'text', p_ver: 'text' },
    lec_beat: {
      p_key: 'text', p_lecture: 'uuid', p_session: 'uuid', p_seen: 'text', p_total: 'int', p_pos: 'int',
      p_from: 'int', p_to: 'int', p_dur: 'int', p_dev: 'text', p_rate: 'num?', p_scale: 'num?'
    },
    lec_qna_list: { p_key: 'text', p_lecture: 'uuid' },
    lec_ask: {
      p_key: 'text', p_lecture: 'uuid', p_body: 'text', p_at: 'int', p_private: 'bool', p_parent: 'uuid', p_kind: 'text?'
    },
    lec_qdel: { p_key: 'text', p_id: 'uuid' },
    lec_logout: { p_key: 'text' },
    lec_att: { p_key: 'text' },
    lec_paper: { p_key: 'text' },
    /* 선생님 함수(로그인한 선생님만 · LecMock.staff.rpc 로) */
    lec_todo: {},
    lec_att_staff: {},
    lec_confirm: { p_lecture: 'uuid', p_skey: 'text', p_note: 'text?' },
    lec_unconfirm: { p_lecture: 'uuid', p_skey: 'text' },
    lec_forget: { p_skey: 'text' },
    lec_unlock: { p_skey: 'text' },
    lec_keys: {},
    lec_link: { p_skey: 'text' },
    lec_logout_all: { p_skey: 'text' }
  };

  function httpErr(status, code, msg) {
    var e = new Error('http');
    e.status = status;
    e.code = code;
    e.detail = msg;
    return e;
  }

  var UUID = /^\{?([0-9a-fA-F]{8})-?([0-9a-fA-F]{4})-?([0-9a-fA-F]{4})-?([0-9a-fA-F]{4})-?([0-9a-fA-F]{12})\}?$/;
  var BOOLS = { 't': true, 'true': true, 'y': true, 'yes': true, 'on': true, '1': true, 'f': false, 'false': false, 'n': false, 'no': false, 'off': false, '0': false };

  function coerce(type, v, name) {
    if (v === null || v === undefined) return null;
    var s, m;
    if (type === 'text') {
      if (typeof v === 'string') return v;
      if (typeof v === 'number' || typeof v === 'boolean') return String(v);
      return JSON.stringify(v);
    }
    if (type === 'int') {
      if (typeof v === 'number') {
        if (!isFinite(v) || Math.floor(v) !== v) throw httpErr(400, '22P02', 'invalid input syntax for type integer: ' + name);
      } else if (typeof v === 'string' && /^\s*[+\-]?\d+\s*$/.test(v)) {
        v = parseInt(v, 10);
      } else {
        throw httpErr(400, '22P02', 'invalid input syntax for type integer: ' + name);
      }
      if (v > 2147483647 || v < -2147483648) throw httpErr(400, '22003', 'integer out of range: ' + name);
      return v;
    }
    if (type === 'big') {   /* bigint · 화면이 보내는 값(밀리초 시각)은 2^53 안 */
      if (typeof v === 'number') {
        if (!isFinite(v) || Math.floor(v) !== v) throw httpErr(400, '22P02', 'invalid input syntax for type bigint: ' + name);
      } else if (typeof v === 'string' && /^\s*[+\-]?\d{1,18}\s*$/.test(v)) {
        v = parseInt(v, 10);
      } else {
        throw httpErr(400, '22P02', 'invalid input syntax for type bigint: ' + name);
      }
      if (Math.abs(v) > 9007199254740991) throw httpErr(400, '22003', 'bigint out of range: ' + name);
      return v;
    }
    if (type === 'num') {
      s = typeof v === 'number' ? v : (typeof v === 'string' && /^\s*[+\-]?(\d+\.?\d*|\.\d+)([eE][+\-]?\d+)?\s*$/.test(v) ? parseFloat(v) : NaN);
      if (!isFinite(s)) throw httpErr(400, '22P02', 'invalid input syntax for type numeric: ' + name);
      return s;
    }
    if (type === 'uuid') {
      m = typeof v === 'string' ? v.match(UUID) : null;
      if (!m) throw httpErr(400, '22P02', 'invalid input syntax for type uuid: ' + name);
      return (m[1] + '-' + m[2] + '-' + m[3] + '-' + m[4] + '-' + m[5]).toLowerCase();
    }
    if (type === 'bool') {
      if (typeof v === 'boolean') return v;
      s = String(v).replace(/^\s+|\s+$/g, '').toLowerCase();
      if (typeof v !== 'object' && has(BOOLS, s)) return BOOLS[s];
      throw httpErr(400, '22P02', 'invalid input syntax for type boolean: ' + name);
    }
    return v;
  }

  function checkArgs(fn, args) {
    var sig = SIG[fn], k, t, out = {};
    if (OLD && (fn === 'lec_att' || fn === 'lec_att_staff')) sig = null;
    if ((OLD || NOPAPER) && fn === 'lec_paper') sig = null;
    if ((OLD || NORANGE) && /^lec_range_/.test(fn)) sig = null;   /* C2 함수가 없는 서버(아래 C2 절) */
    if (!sig) throw httpErr(404, 'PGRST202', 'Could not find the function public.' + fn);
    args = args && typeof args === 'object' && !isArr(args) ? args : {};
    for (k in args) {
      if (has(args, k) && args[k] !== undefined && !has(sig, k)) {
        throw httpErr(404, 'PGRST202', 'Could not find the function public.' + fn + ' with argument ' + k);
      }
    }
    for (k in sig) {
      if (!has(sig, k)) continue;
      t = sig[k];
      var opt = t.charAt(t.length - 1) === '?';
      if (opt) t = t.slice(0, -1);
      if (!has(args, k) || args[k] === undefined) {
        if (!opt) throw httpErr(404, 'PGRST202', 'Could not find the function public.' + fn + ' without argument ' + k);
        out[k] = fn === 'lec_login' && k === 'p_dev' ? '' : null;
        continue;
      }
      out[k] = coerce(t, args[k], k);
    }
    return out;
  }

  function rpc(fn, args) {
    var a = checkArgs(fn, args);
    /* 선생님 함수는 로그인 없는 부름(anon)에 열려 있지 않음(PostgREST: 42501 → 401) */
    if (has(STAFF, fn)) throw httpErr(401, '42501', 'permission denied for function ' + fn);
    var d = load();
    var r = IMPL[fn](d, a);
    save(d);
    return clone(r);
  }

  /* ---------------------------------------------------------- 선생님 화면(연습용) */

  var COLS = {
    id: 'uuid', title: 'text', book: 'text', yt: 'text', dur: 'int', chapters: 'json', class_ids: 'textarr',
    lesson_on: 'date?', posted_on: 'date', until: 'date?', hidden: 'bool', created_by: 'text', created_at: 'ts', updated_at: 'ts',
    /* C1(덧붙인 칸): 더 있는 수업일 · 실행기 txt 의 [온라인 클래스] 묶음 */
    lesson_more: 'datearr', runner: 'json',
    /* C1 고침(11-16): 수업일마다 반 {"YYYY-MM-DD": [반 id]} · 없거나 빈 날 = 강의의 모든 반 */
    lesson_cls: 'json'
  };

  /* 옛 SQL 흉내(?oldsql=1 또는 LecMock.oldSql(true)): 새 칸 · 새 함수가 없는 서버 */
  var OLD = false;
  try { OLD = /[?&]oldsql=1(&|$)/.test(w.location.search); } catch (e) { OLD = false; }
  /* C1 SQL 은 있고 C3 · C7 함수(lec_paper)만 없는 서버(?nopaper=1 또는 LecMock.noPaper(true)) */
  var NOPAPER = false;
  try { NOPAPER = /[?&]nopaper=1(&|$)/.test(w.location.search); } catch (e) { NOPAPER = false; }
  /* 수업일마다 반 칸(lesson_cls)만 없는 서버(11-16 고치기 전 C1 SQL · ?nolcls=1 또는 LecMock.noLcls(true)) */
  var NOLCLS = false;
  try { NOLCLS = /[?&]nolcls=1(&|$)/.test(w.location.search); } catch (e) { NOLCLS = false; }
  /* 시험용(M-2 맞대기): 고치기 전 셈(모든 짝에 모든 날 · 수업일마다 반 안 봄) · LecMock.legacyAtt(true) */
  var LEGACY = false;
  function isNewCol(k) { return k === 'lesson_more' || k === 'runner' || k === 'lesson_cls'; }
  function noCol(k) { return (OLD && isNewCol(k)) || (NOLCLS && k === 'lesson_cls'); }
  function stripNew(l) {
    if (!(OLD || NOLCLS) || !l) return l;
    var o = {}, k;
    for (k in l) { if (has(l, k) && !noCol(k)) o[k] = l[k]; }
    return o;
  }

  function colVal(c, v) {
    var t = COLS[c], opt = t.charAt(t.length - 1) === '?';
    if (opt) t = t.slice(0, -1);
    if (v === null) {
      if (opt) return null;
      throw httpErr(400, '23502', 'null value in column "' + c + '" violates not-null constraint');
    }
    if (t === 'text' || t === 'int' || t === 'uuid' || t === 'bool') return coerce(t, v, c);
    if (t === 'json') return clone(v);
    if (t === 'textarr') {
      if (!isArr(v)) throw httpErr(400, '22P02', 'malformed array literal: ' + c);
      var o = [], i;
      for (i = 0; i < v.length; i += 1) o.push(v[i] == null ? null : coerce('text', v[i], c));
      return o;
    }
    if (t === 'datearr') {
      if (!isArr(v)) throw httpErr(400, '22P02', 'malformed array literal: ' + c);
      var da = [], j, mm, okd;
      for (j = 0; j < v.length; j += 1) {
        if (v[j] == null) { da.push(null); continue; }
        mm = typeof v[j] === 'string' ? v[j].match(/^(\d{4})-(\d{2})-(\d{2})$/) : null;
        okd = mm && new Date(Date.UTC(+mm[1], +mm[2] - 1, +mm[3])).getUTCDate() === +mm[3] && +mm[2] >= 1 && +mm[2] <= 12;
        if (!okd) throw httpErr(400, '22007', 'invalid input syntax for type date: ' + c);
        da.push(v[j]);
      }
      return da;
    }
    if (t === 'date') {
      var m = typeof v === 'string' ? v.match(/^(\d{4})-(\d{2})-(\d{2})$/) : null;
      var ok = m && new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])).getUTCDate() === +m[3] && +m[2] >= 1 && +m[2] <= 12;
      if (!ok) throw httpErr(400, '22007', 'invalid input syntax for type date: ' + c);
      return v;
    }
    if (t === 'ts') {
      var x = tms(v);
      if (!isFinite(x)) throw httpErr(400, '22007', 'invalid input syntax for type timestamp: ' + c);
      return pgts(x);
    }
    return v;
  }

  function later(fn) {
    return new Promise(function (res, rej) {
      setTimeout(function () {
        try { res(clone(fn())); } catch (e) { rej(e); }
      }, 120);
    });
  }

  function withDb(fn) {
    return later(function () {
      var d = load();
      var r = fn(d);
      save(d);
      return r;
    });
  }

  function dropLecture(d, id) {
    var keep = function (x) { return x.lecture_id !== id; };
    d.lecture = d.lecture.filter(function (x) { return x.id !== id; });
    d.progress = d.progress.filter(keep);
    d.session = d.session.filter(keep);
    d.qna = d.qna.filter(keep);
  }

  /* ------------------------------------------- 선생님 함수(class-setup.sql 과 같은 규칙) */

  /* collate "C" 정렬(글자 번호 순) */
  function cmpC(a, b) { a = str(a); b = str(b); return a < b ? -1 : (a > b ? 1 : 0); }
  /* 시각 내림차순 · 빈 값은 뒤(desc nulls last) */
  function cmpAtDesc(a, b) {
    var x = a == null ? NaN : tms(a), y = b == null ? NaN : tms(b);
    if (!isFinite(x)) return isFinite(y) ? 1 : 0;
    if (!isFinite(y)) return -1;
    return y - x;
  }
  /* substring(sid from '[^|]*$') = 마지막 | 뒤 */
  function tailName(sid) { var s = str(sid), i = s.lastIndexOf('|'); return i < 0 ? s : s.slice(i + 1); }
  function rosterName(d, skey) {
    var rs = roster(d), i;
    for (i = 0; i < rs.length; i += 1) { if (rs[i].skey === skey) return rs[i].sname; }
    return null;
  }
  /* lec__classes(): 반 id 가 있는 줄마다 {id, name, owner} */
  function classRows(d) {
    var out = [], i, c, id, X = L();
    for (i = 0; i < d.classes.length; i += 1) {
      c = d.classes[i];
      if (!c || typeof c !== 'object' || isArr(c)) continue;
      id = X.jtext(c.id);
      if (id == null || id === '') continue;
      out.push({ id: id, name: str(X.jtext(c.name)), owner: trimWs(X.jtext(c.owner)) });
    }
    return out;
  }

  function lec_confirm(d, a) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var l = findLecture(d, a.p_lecture);
    if (!l) return { ok: false, err: 'lecture' };
    var sk = a.p_skey, X = L();
    if (X.btrim(sk) === '') return { ok: false, err: 'input' };
    if (!can(d, l, sk)) return { ok: false, err: 'forbidden' };
    var note = X.left(X.btrim(a.p_note == null ? '' : a.p_note), 60);
    var p = findProgress(d, sk, l.id);
    if (!p) {
      var nm = rosterName(d, sk);
      p = {
        sid: sk, lecture_id: l.id, sname: nm == null ? tailName(sk) : nm, seen: '', watched: 0, pos: 0, pct: 0,
        sessions: 0, first_at: null, last_at: null, done_at: null, done_by: null, done_note: '', done_by_at: null
      };
      d.progress.push(p);
    }
    p.done_by = ME.name;
    p.done_note = note;
    p.done_by_at = pgts(nowMs());
    return { ok: true, done_by: p.done_by, done_note: p.done_note, done_by_at: p.done_by_at };
  }

  function lec_unconfirm(d, a) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var l = findLecture(d, a.p_lecture);
    if (!l) return { ok: false, err: 'lecture' };
    var sk = a.p_skey;
    if (L().btrim(sk) === '') return { ok: false, err: 'input' };
    if (!can(d, l, sk)) return { ok: false, err: 'forbidden' };
    var p = findProgress(d, sk, l.id);
    if (p) {
      p.done_by = null;
      p.done_note = '';
      p.done_by_at = null;
      if (!(p.sessions > 0) && !(p.watched > 0) && str(p.seen).indexOf('1') < 0) {
        d.progress = d.progress.filter(function (x) { return x !== p; });
      }
    }
    return { ok: true };
  }

  /* 관리자만 · 질문을 지우면 그 아래 선생님 답도(on delete cascade) */
  function lec_forget(d, a) {
    if (!ME || !ME.admin) return { ok: false, err: 'forbidden' };
    var sk = a.p_skey, i, n = 0, m = 0, gone = {}, more;
    if (L().btrim(sk) === '') return { ok: false, err: 'input' };
    d.progress = d.progress.filter(function (x) { if (x.sid === sk) { n += 1; return false; } return true; });
    d.session = d.session.filter(function (x) { return x.sid !== sk; });
    d.consent = (d.consent || []).filter(function (x) { return x.sid !== sk; });
    for (i = 0; i < d.qna.length; i += 1) {
      if (d.qna[i].sid === sk) {
        if (d.qna[i].parent == null) m += 1;
        gone[d.qna[i].id] = true;
      }
    }
    do {
      more = false;
      for (i = 0; i < d.qna.length; i += 1) {
        if (!gone[d.qna[i].id] && d.qna[i].parent != null && gone[d.qna[i].parent]) { gone[d.qna[i].id] = true; more = true; }
      }
    } while (more);
    d.qna = d.qna.filter(function (x) { return !gone[x.id]; });
    d.fail = (d.fail || []).filter(function (x) { return x.who !== 'k:' + sk; });
    if (rosterName(d, sk) == null) d.key = d.key.filter(function (k) { return k.sid !== sk; });
    return { ok: true, progress: n, questions: m };
  }

  /* 로그인 잠금 상태(lec_login 과 같은 셈): 하루 잠금이 먼저 · 없으면 null */
  function lockOf(d, who, now) {
    var dayAt = null, minAt = null, i, f, t, fs = d.fail || [];
    for (i = 0; i < fs.length; i += 1) {
      f = fs[i];
      if (f.who !== who) continue;
      t = tms(f.at);
      if (f.lock === 'day' && t > now - DAY) dayAt = dayAt === null ? t : Math.max(dayAt, t);
      if ((f.lock === 'min' || f.lock === 'day') && t > now - 10 * MINUTE) minAt = minAt === null ? t : Math.max(minAt, t);
    }
    if (dayAt !== null) return { day: true, secs: Math.max(1, Math.ceil((dayAt + DAY - now) / 1000)) };
    if (minAt !== null) return { day: false, secs: Math.max(1, Math.ceil((minAt + 10 * MINUTE - now) / 1000)) };
    return null;
  }
  /* 선생님 범위: 그 학생(명단 줄)이 내 반에 있나 */
  function inMine(r, mine) {
    var j;
    for (j = 0; j < r.cls.length; j += 1) { if (mine.indexOf(r.cls[j]) >= 0) return true; }
    return false;
  }

  /* 잠금 풀기: 그 학생의 로그인 실패 기록(k:학생키 · n:그 학생 이름)을 지우고 지운 수를 돌려줌.
     관리자는 모두 · 선생님은 내 반 학생만(명단에 없으면 'forbidden') */
  function lec_unlock(d, a) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var sk = a.p_skey, rs = roster(d), i, r = null, nn, n = 0;
    if (L().btrim(sk) === '') return { ok: false, err: 'input' };
    for (i = 0; i < rs.length; i += 1) { if (rs[i].skey === sk) { r = rs[i]; break; } }
    if (!ME.admin && !(r && inMine(r, myClassIds(d, ME.name)))) return { ok: false, err: 'forbidden' };
    nn = r ? r.nname : tailName(sk);
    d.fail = (d.fail || []).filter(function (f) {
      if (f.who === 'k:' + sk || (nn !== '' && f.who === 'n:' + nn)) { n += 1; return false; }
      return true;
    });
    return { ok: true, cleared: n };
  }

  function lec_todo(d) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var name = ME.name, admin = !!ME.admin, rs = roster(d), t = today(), from = dayStr(-13);
    var i, j, k, q, x, l, w = [], stuAt, tchAt;

    /* waiting */
    for (i = 0; i < d.qna.length; i += 1) {
      q = d.qna[i];
      if (q.parent != null || q.teacher != null || q.deleted) continue;
      stuAt = null; tchAt = null;
      for (j = 0; j < d.qna.length; j += 1) {
        x = d.qna[j];
        if (x.deleted) continue;
        if (x.teacher == null && (x.id === q.id || x.parent === q.id)) {
          if (stuAt == null || tms(x.created_at) > tms(stuAt)) stuAt = x.created_at;
        } else if (x.teacher != null && x.parent === q.id) {
          if (tchAt == null || tms(x.created_at) > tms(tchAt)) tchAt = x.created_at;
        }
      }
      if (tchAt != null && !(tms(tchAt) < tms(stuAt))) continue;
      l = findLecture(d, q.lecture_id);
      if (!l) continue;
      if (!admin && !can(d, l, q.sid)) continue;
      w.push({
        id: q.id, lecture: q.lecture_id, title: l.title, sid: q.sid, sname: q.sname,
        kind: q.kind == null ? 'content' : q.kind, body: q.body, created_at: q.created_at, at: stuAt
      });
    }
    w.sort(function (a, b) { return cmpAtDesc(a.at, b.at) || cmpC(a.id, b.id); });

    /* behind */
    var cl = classRows(d).filter(function (c) { return admin || c.owner === name; });
    var pr = [], behind = [], day, ids, cons, p, c, names, list;
    for (i = 0; i < d.lecture.length; i += 1) {
      l = d.lecture[i];
      if (l.hidden || (l.posted_on || t) > t || ended(l)) continue;
      day = l.lesson_on || l.posted_on;
      if (day == null || day < from || day > t) continue;
      ids = l.class_ids || [];
      for (j = 0; j < cl.length; j += 1) {
        if (ids.indexOf(cl[j].id) >= 0 || ids.indexOf('*') >= 0) pr.push({ l: l, day: day, c: cl[j] });
      }
    }
    for (i = 0; i < pr.length; i += 1) {
      list = [];
      for (j = 0; j < rs.length; j += 1) {
        if (rs[j].cls.indexOf(pr[i].c.id) < 0) continue;
        p = findProgress(d, rs[j].skey, pr[i].l.id);
        cons = findConsent(d, rs[j].skey);
        if (p && (p.pct || 0) >= 90) continue;
        if (p && p.done_by != null) continue;
        if (cons && cons.choice === 'none') continue;
        list.push(rs[j]);
      }
      if (!list.length) continue;
      list.sort(function (a, b) { return cmpC(a.sname, b.sname) || cmpC(a.skey, b.skey); });
      names = [];
      for (k = 0; k < list.length; k += 1) names.push(list[k].sname);
      c = pr[i].c;
      behind.push({
        cls: c.id, cname: c.name, lecture: pr[i].l.id, title: pr[i].l.title, day: pr[i].day, n: list.length, names: names,
        _lca: pr[i].l.created_at
      });
    }
    behind.sort(function (a, b) {
      return cmpC(b.day, a.day) || cmpAtDesc(a._lca, b._lca) || cmpC(a.cname, b.cname) || cmpC(a.cls, b.cls) ||
        cmpC(a.lecture, b.lecture);
    });
    for (i = 0; i < behind.length; i += 1) delete behind[i]._lca;

    /* left(관리자만) */
    var left = [];
    if (admin) {
      var rec = [], by = {}, order = [], s, r;
      for (i = 0; i < d.progress.length; i += 1) rec.push({ sid: d.progress[i].sid, sname: d.progress[i].sname, at: d.progress[i].last_at });
      for (i = 0; i < d.session.length; i += 1) rec.push({ sid: d.session[i].sid, sname: d.session[i].sname, at: d.session[i].ended_at });
      for (i = 0; i < d.qna.length; i += 1) {
        if (d.qna[i].sid != null) rec.push({ sid: d.qna[i].sid, sname: d.qna[i].sname, at: d.qna[i].created_at });
      }
      cons = d.consent || [];
      for (i = 0; i < cons.length; i += 1) rec.push({ sid: cons[i].sid, sname: null, at: cons[i].at });
      for (i = 0; i < rec.length; i += 1) {
        r = rec[i];
        if (!has(by, r.sid)) { by[r.sid] = []; order.push(r.sid); }
        by[r.sid].push(r);
      }
      for (i = 0; i < order.length; i += 1) {
        s = order[i];
        var inRoster = false, rid = s.split('|')[0], last = null, best = null, rows = by[s];
        for (j = 0; j < rs.length; j += 1) { if (rs[j].skey === s || rs[j].rid === rid) inRoster = true; }
        if (inRoster) continue;
        for (j = 0; j < rows.length; j += 1) {
          if (rows[j].at != null && (last == null || tms(rows[j].at) > tms(last))) last = rows[j].at;
        }
        rows = rows.filter(function (y) { return str(y.sname) !== ''; });
        rows.sort(function (a, b) { return cmpAtDesc(a.at, b.at) || cmpC(a.sname, b.sname); });
        best = rows.length ? rows[0].sname : tailName(s);
        left.push({ skey: s, sname: best, last_at: last });
      }
      left.sort(function (a, b) { return cmpAtDesc(a.last_at, b.last_at) || cmpC(a.skey, b.skey); });
    }

    /* locked: 지금 로그인이 잠긴 학생. 잠금 대상은 로그인과 같게 셈(이름이 명단에 한 명뿐이면 k:학생키, 아니면 n:이름) */
    var locked = [], nowN = nowMs(), mine = admin ? null : myClassIds(d, name), cnt = {}, crow = classRows(d), st, cs, ci, cn, r;
    for (i = 0; i < rs.length; i += 1) cnt[' ' + rs[i].nname] = (cnt[' ' + rs[i].nname] || 0) + 1;
    for (i = 0; i < rs.length; i += 1) {
      r = rs[i];
      if (!admin && !inMine(r, mine)) continue;
      st = lockOf(d, cnt[' ' + r.nname] === 1 ? 'k:' + r.skey : 'n:' + r.nname, nowN);
      if (!st) continue;
      cs = [];
      for (j = 0; j < r.cls.length; j += 1) {
        cn = '';
        for (ci = 0; ci < crow.length; ci += 1) { if (crow[ci].id === r.cls[j]) { cn = crow[ci].name; break; } }
        cs.push({ id: r.cls[j], name: cn });
      }
      cs.sort(function (a, b) { return cmpC(a.name, b.name) || cmpC(a.id, b.id); });
      locked.push({
        skey: r.skey, sname: r.sname, cls: cs.map(function (x) { return x.id; }), cnames: cs.map(function (x) { return x.name; }),
        secs: st.secs, day: st.day
      });
    }
    locked.sort(function (a, b) { return cmpC(a.sname, b.sname) || cmpC(a.skey, b.skey); });

    return { ok: true, waiting: { count: w.length, items: w.slice(0, 20) }, behind: behind, left: left, locked: locked };
  }

  /* 학생 기기 목록(선생님만 · 열쇠·해시·번호 빼고) · 학생키 → 만든 때 → 해시 순 */
  function lec_keys(d) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var rows = d.key.slice().sort(function (x, y) {
      var ta = tms(x.created_at), tb = tms(y.created_at);
      return cmpC(x.sid, y.sid) || (ta < tb ? -1 : (ta > tb ? 1 : 0)) || cmpC(x.kh, y.kh);
    });
    return {
      ok: true,
      items: rows.map(function (k) {
        return {
          sid: k.sid, rid: k.rid, sname: k.sname, cls: (k.cls || []).slice(), dev: k.dev,
          made_by: k.made_by, created_at: k.created_at, last_at: k.last_at
        };
      })
    };
  }

  /* 개인 링크 만들기(선생님만): 명단의 그 학생 열쇠를 새로 만들어 한 번 돌려줌(표에는 해시만) */
  function lec_link(d, a) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var X = L(), sk = a.p_skey, rs, i, r = null;
    if (X.btrim(sk) === '') return { ok: false, err: 'input' };
    rs = roster(d);
    for (i = 0; i < rs.length; i += 1) { if (rs[i].skey === sk) { r = rs[i]; break; } }
    if (!r) return { ok: false, err: 'nomatch' };
    var key = X.hex64(), now = pgts(nowMs());
    d.key.push({
      kh: kh(key), sid: r.skey, rid: r.rid, pin: '', sname: r.sname, cls: (r.cls || []).slice(),
      dev: '개인 링크', made_by: ME.name, created_at: now, last_at: now
    });
    return { ok: true, key: key };
  }

  /* 그 학생의 모든 기기에서 로그아웃(선생님만 · 개인 링크도) · 지운 수 */
  function lec_logout_all(d, a) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var sk = a.p_skey;
    if (L().btrim(sk) === '') return { ok: false, err: 'input' };
    var before = d.key.length;
    d.key = d.key.filter(function (k) { return k.sid !== sk; });
    return { ok: true, n: before - d.key.length };
  }

  var STAFF = {
    lec_todo: lec_todo, lec_confirm: lec_confirm, lec_unconfirm: lec_unconfirm, lec_forget: lec_forget, lec_unlock: lec_unlock,
    lec_keys: lec_keys, lec_link: lec_link, lec_logout_all: lec_logout_all, lec_att_staff: lec_att_staff
  };

  /* 선생님 판정(class-setup.sql lec__staff 와 같게): 로그인 이메일만 · user_metadata 는 보지 않음.
     아이디@his.kr 만 · benjamin = 관리자 · joey · dana · 선생님 목록(teacherAccounts)의 이름 · 그 밖은 아이디 */
  function staffByEmail(d, email) {
    var X = L(), e = trimWs(email).toLowerCase(), at = e.indexOf('@'), un, ta, t;
    if (at < 0 || e.slice(at) !== '@his.kr') return null;
    un = e.slice(0, at);
    if (un === 'benjamin') return { name: 'Benjamin', admin: true };
    if (un === 'joey') return { name: 'Joey', admin: false };
    if (un === 'dana') return { name: 'Dana', admin: false };
    ta = d && d.teacherAccounts && typeof d.teacherAccounts === 'object' && !isArr(d.teacherAccounts) ? d.teacherAccounts : {};
    t = has(ta, un) ? ta[un] : null;
    if (t && typeof t === 'object' && !isArr(t) && !X.truthy(t.del) && X.truthy(t.name)) return { name: str(t.name), admin: false };
    return { name: un, admin: false };
  }
  /* 선생님이 아닌 로그인: 표는 읽어도 빈 것처럼([]) · 넣기는 403(행 보안) · 고치기·지우기는 0줄 */
  function denyInsert() { return httpErr(403, '42501', 'new row violates row-level security policy'); }

  /* 선생님 함수 부르기(진짜 화면의 sb.rpc 와 같은 꼴 · 값 꼴 검사 포함) */
  function staffRpc(fn, args) {
    return withDb(function (d) {
      var a = checkArgs(fn, args);
      if (!has(STAFF, fn)) throw httpErr(404, 'PGRST202', 'Could not find the function public.' + fn);
      return clone(STAFF[fn](d, a));
    });
  }

  var staff = {
    me: function () { return later(function () { return ME; }); },
    /* 시험용: 지금 로그인 바꾸기
       - {email, user_metadata} = 진짜 서버처럼 이메일만 보고 정함(선생님이 아니면 null · user_metadata 는 무시)
       - {name, admin} = 이미 정해진 선생님(연습 화면이 쓰는 꼴) · null = 히즈북스 선생님이 아닌 로그인 */
    setMe: function (o) {
      if (o && has(o, 'email')) ME = staffByEmail(load(), o.email);
      else ME = o ? { name: str(o.name), admin: !!o.admin } : null;
      return ME ? clone(ME) : null;
    },
    rpc: staffRpc,
    todo: function () { return staffRpc('lec_todo', {}); },
    /* C1: 결석한 날 수업 · 교실에서 들음 · 덜 본 학생 띠 */
    att: function () { return staffRpc('lec_att_staff', {}); },
    confirm: function (lecture, skey, note) {
      var a = { p_lecture: lecture, p_skey: skey };
      if (note !== undefined) a.p_note = note;
      return staffRpc('lec_confirm', a);
    },
    unconfirm: function (lecture, skey) { return staffRpc('lec_unconfirm', { p_lecture: lecture, p_skey: skey }); },
    forget: function (skey) { return staffRpc('lec_forget', { p_skey: skey }); },
    /* 잠금 풀기 → {ok, cleared} */
    unlock: function (skey) { return staffRpc('lec_unlock', { p_skey: skey }); },
    /* 기록 동의 표(선생님은 읽기만) */
    consents: function () { return withDb(function (d) { return ME ? (d.consent || []) : []; }); },
    classes: function () { return withDb(function (d) { return d.classes; }); },
    lectures: function () { return withDb(function (d) { return ME ? d.lecture.map(stripNew) : []; }); },

    /* 새 강의(id 가 없거나 처음 보는 id) = 넣기 · 있는 id = 고치기. 고친 줄을 돌려줌
       (선생님이 아니면: 넣기 403 · 고치기는 고칠 줄이 안 보여 406 PGRST116 — .update().select().single() 과 같게) */
    saveLecture: function (o) {
      return withDb(function (d) {
        o = o || {};
        if (!ME) {
          if (o.id && findLecture(d, o.id)) throw httpErr(406, 'PGRST116', 'JSON object requested, multiple (or no) rows returned');
          throw denyInsert();
        }
        var k, v = {};
        for (k in o) {
          if (!has(o, k) || o[k] === undefined) continue;
          if (!has(COLS, k) || noCol(k)) throw httpErr(400, 'PGRST204', 'Could not find the \'' + k + '\' column of \'lec_lecture\'');
          v[k] = colVal(k, o[k]);
        }
        var l = v.id ? findLecture(d, v.id) : null, now = pgts(nowMs());
        if (!l) {
          l = {
            id: v.id || L().uuid(), title: '', book: '', yt: '', dur: 0, chapters: [], class_ids: [],
            lesson_on: null, posted_on: today(), until: null, hidden: false, created_by: '', created_at: now, updated_at: now,
            lesson_more: [], runner: {}, lesson_cls: {}
          };
          for (k in v) { if (has(v, k)) l[k] = v[k]; }
          d.lecture.push(l);
          return stripNew(l);
        }
        var oldDur = l.dur;
        for (k in v) { if (has(v, k) && k !== 'id') l[k] = v[k]; }
        if (!has(v, 'updated_at')) l.updated_at = now; /* 진짜 화면도 updated_at 을 직접 넣어야 함(SQL 에 갱신 장치 없음) */
        if (has(v, 'dur') && l.dur !== oldDur) durChanged(d, l.id, l.dur);
        return stripNew(l);
      });
    },

    /* 지우면 진도 · 보기 기록 · 질문도 함께(SQL 의 on delete cascade) */
    deleteLecture: function (id) {
      return withDb(function (d) {
        if (!ME) return false;
        var had = !!findLecture(d, id);
        dropLecture(d, id);
        return had;
      });
    },

    progress: function () { return withDb(function (d) { return ME ? d.progress : []; }); },
    sessions: function () { return withDb(function (d) { return ME ? d.session : []; }); },
    qna: function () { return withDb(function (d) { return ME ? d.qna : []; }); },

    /* 답변: 질문(q = 줄 또는 id) 아래에 선생님 이름으로 · 공개 여부는 질문을 따름 */
    answer: function (q, body) {
      return withDb(function (d) {
        if (!ME) throw denyInsert();
        var row = findQna(d, q && typeof q === 'object' ? q.id : q);
        if (!row) throw httpErr(400, '23503', 'parent question not found');
        if (body == null) throw httpErr(400, '23502', 'null value in column "body" violates not-null constraint');
        var x = {
          id: L().uuid(), lecture_id: row.lecture_id, parent: row.id, sid: null, sname: null, teacher: ME.name, at_s: null,
          body: str(body), private: !!row.private, stu_seen: false, deleted: false, created_at: pgts(nowMs()),
          kind: row.kind || 'content'
        };
        d.qna.push(x);
        return x;
      });
    },

    /* 질문 · 답변 지우기 = deleted 표시 */
    qdelete: function (id) {
      return withDb(function (d) {
        if (!ME) return false;
        var x = findQna(d, id);
        if (!x) return false;
        x.deleted = true;
        return true;
      });
    },

    /* 학생 기기 목록 → {ok, items}(열쇠·해시·번호 없음) · sid 를 주면 그 학생 것만.
       기기 표(lec_key)는 선생님도 표로 못 읽음 → 함수(lec_keys)로만 */
    keys: function (sid) {
      return staffRpc('lec_keys', {}).then(function (r) {
        if (r && r.ok && sid != null) r.items = r.items.filter(function (k) { return k.sid === sid; });
        return r;
      });
    },

    /* 개인 링크 열쇠 만들기 → {ok, key} · 명단에 없으면 {ok:false, err:'nomatch'}.
       student = 명단 줄({skey}) · 학생({id, name}) · skey 글자 */
    makeLink: function (student) {
      var sk = null;
      if (typeof student === 'string') sk = student;
      else if (student && student.skey) sk = student.skey;
      else if (student) sk = L().skey(student.id, student.name);
      return staffRpc('lec_link', { p_skey: sk });
    },

    /* 모든 기기 로그아웃 = 그 학생의 열쇠를 모두 지움(개인 링크 포함) → {ok, n} */
    logoutAll: function (sid) { return staffRpc('lec_logout_all', { p_skey: sid }); }
  };

  function reset() {
    var d = seed();
    save(d);
    ME = { name: 'Benjamin', admin: true };
    return true;
  }

  w.LecMock = {
    rpc: rpc,
    staff: staff,
    reset: reset,
    CONSENT_VER: CONSENT_VER,
    /* 열쇠 해시(SQL lec__kh 와 같음) */
    kh: kh,
    /* 시험용: 지금 상태(살아 있는 객체 · 고친 뒤 save 로 저장) */
    db: function () { return load(); },
    save: function (d) { save(d); },
    ids: ID,
    STORE: STORE,
    /* 시험용: 옛 SQL 흉내 켜기·끄기(새 칸 lesson_more · runner 와 새 함수 lec_att · lec_att_staff 가 없는 서버) */
    oldSql: function (on) { if (on !== undefined) OLD = !!on; return OLD; },
    /* 시험용: lec_paper 만 없는 서버 켜기·끄기 */
    noPaper: function (on) { if (on !== undefined) NOPAPER = !!on; return NOPAPER; },
    /* 시험용: 고치기 전 출결 셈 켜기·끄기(M-2 결과 맞대기) */
    legacyAtt: function (on) { if (on !== undefined) LEGACY = !!on; return LEGACY; },
    noLcls: function (on) { if (on !== undefined) NOLCLS = !!on; return NOLCLS; }
  };

  /* ======================================================= C2 (11-16) 학교 시험 D-day · 시험 범위 영상
     class-setup.sql C2 절(lec_range 표 · lec_range_me · lec_range_staff · lec_range_save · lec_range_sync)과 같은 규칙.
     ?norange=1 또는 LecMock.noRange(true) = C2 함수만 없는 서버(?oldsql=1 도 없음) · 위 checkArgs 의 한 줄이 404 PGRST202 로.
     시연 자료(c2Ensure · 저장소에 한 번만 · d.c2 표시): 학생 학교 · 학년, 히즈북스 학교 시험 일정(app 'pt-etc' 줄 · main 에 옛 값),
     저장된 범위 두 줄. 오늘을 D 라 하면
       한빛여고 1학년 = 학교 일정 «2학기 기말고사» D+9~D+12 · 범위 저장됨(Joey · L1 L2 L5 L7) → 김하늘 · 최새봄 · 정단비 카드
         (정단비는 학년 칸 없이 학교 칸 «한빛여고 1학년» · 같은 id s1005 를 서은별도 써서 학생 열쇠로 들어감)
       바다고 1학년(이바다) = «2학기 기말» D+12 · 저장 안 됨 → 선생님 띠 · 학생 카드 없음
       푸른고(박구름) = 일정 지움 → 시험 없음 · 강노을 = 학교 없음 · 서은별 = 한빛여고 학년 모름
       새솔고 2학년(한겨울) = «기말고사» D+25 · 범위 저장됨(Dana · L3 L4) → 아직 D-20 밖이라 카드 없음
       한빛여고 2학년(윤가람) = 학년 예외 D+26(켬) · 저장 안 됨 → 선생님 띠(D-30 안)
     'pt-etc' 줄의 급여 · 금전 칸은 학생 쪽으로 새지 않는지 보려는 가짜 값
     ?manyexams=1 = 위에 더해 시험 다섯(c2Many · 띠가 여럿일 때) · 그냥 ?demo=1 은 위 그대로 */
  var NORANGE = false;
  try { NORANGE = /[?&]norange=1(&|$)/.test(w.location.search); } catch (e) { NORANGE = false; }
  var C2ID = {
    R1: '5eedc2a0-0000-4000-8000-000000000001',
    R2: '5eedc2a0-0000-4000-8000-000000000002'
  };

  /* lec__date: 'YYYY-MM-DD' · 있는 날 · 2000~2100 → 그 글자 · 아니면 null */
  function c2Date(v) {
    var m = typeof v === 'string' ? v.match(/^(\d{4})-(\d{2})-(\d{2})$/) : null, dt;
    if (!m || +m[1] < 2000 || +m[1] > 2100) return null;
    dt = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
    if (dt.getUTCFullYear() !== +m[1] || dt.getUTCMonth() + 1 !== +m[2] || dt.getUTCDate() !== +m[3]) return null;
    return v;
  }
  function c2Add(iso, n) {
    var p = str(iso).split('-'), dt = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + n));
    return dt.getUTCFullYear() + '-' + pad(dt.getUTCMonth() + 1, 2) + '-' + pad(dt.getUTCDate(), 2);
  }
  /* 서버가 받는 date 인자(PostgREST): null · 'YYYY-MM-DD' 만(그 밖은 400 · 화면은 늘 이 꼴로 보냄) */
  function c2DateArg(v, name) {
    var m, dt;
    if (v === null || v === undefined) return null;
    m = typeof v === 'string' ? v.match(/^(\d{4})-(\d{2})-(\d{2})$/) : null;
    dt = m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])) : null;
    if (!m || dt.getUTCMonth() + 1 !== +m[2] || dt.getUTCDate() !== +m[3]) {
      throw httpErr(400, '22007', 'invalid input syntax for type date: ' + name);
    }
    return v;
  }
  /* 서버가 받는 배열 인자(text[] · uuid[]): null · 배열만(칸마다 꼴 검사 · 빈 칸은 그대로) */
  function c2ArrArg(v, type, name) {
    var o = [], i;
    if (v === null || v === undefined) return null;
    if (!isArr(v)) throw httpErr(400, '22P02', 'malformed array literal: ' + name);
    for (i = 0; i < v.length; i += 1) o.push(v[i] == null ? null : coerce(type, v[i], name));
    return o;
  }
  function c2Uniq(a) {
    var o = [], i;
    for (i = 0; i < a.length; i += 1) { if (a[i] != null && o.indexOf(a[i]) < 0) o.push(a[i]); }
    o.sort(cmpC);
    return o;
  }
  /* lec__range_ok: 명단에서 한 학생만 쓰는 rid · 모든 학생 열쇠(같은 rid 를 두 학생이 쓰면 그 rid 는 빠짐) */
  function c2Ids(d) {
    var rs = roster(d), o = {}, n = {}, i;
    for (i = 0; i < rs.length; i += 1) n['#' + rs[i].rid] = (n['#' + rs[i].rid] || 0) + 1;
    for (i = 0; i < rs.length; i += 1) {
      if (n['#' + rs[i].rid] === 1 && str(rs[i].rid) !== '') o['#' + rs[i].rid] = 1;
      o['#' + rs[i].skey] = 1;
    }
    return o;
  }
  /* 규칙 판 · 일정 시각: 서버와 같은 범위(판은 지금 1 뿐 · 시각 0 ~ 지금 + 5분 · C2 검수 L-2) */
  function c2Ver(v) { v = +v || 1; return Math.min(Math.max(Math.floor(v), 1), 1); }
  function c2T(v) { v = +v || 0; return Math.min(Math.max(Math.floor(v), 0), nowMs() + 5 * MINUTE); }
  /* 화면이 본 강의의 가장 늦은 만든 시각(ms · 0 ~ 지금 · 마지막 검수 L-2) */
  function c2Seen(v) { v = +v || 0; return Math.min(Math.max(Math.floor(v), 0), nowMs()); }
  /* 줄에 있던 받는 학생(rid · 학생 열쇠)의 반(마지막 검수 L-1 · M1 강의가 실제로 학생에게 가는지 보는 기준) */
  function c2RCls(d, ids) {
    var rs = roster(d), o = [], i, j;
    ids = isArr(ids) ? ids : [];
    for (i = 0; i < rs.length; i += 1) {
      if (ids.indexOf(rs[i].rid) < 0 && ids.indexOf(rs[i].skey) < 0) continue;
      for (j = 0; j < rs[i].cls.length; j += 1) { if (o.indexOf(rs[i].cls[j]) < 0) o.push(rs[i].cls[j]); }
    }
    return o;
  }
  /* 강의의 수업일(가장 늦은 수업일 · 없으면 올린 날) */
  function c2Day(l) {
    var a = arrOr(l.lesson_more).concat([l.lesson_on]), best = '', i;
    for (i = 0; i < a.length; i += 1) { if (typeof a[i] === 'string' && a[i] > best) best = a[i]; }
    return best || str(l.posted_on).slice(0, 10);
  }
  /* 저장한 뒤 올린 강의(C2 검수 M1 · 서버 lec_range_me 와 같음): 줄 저장(saved_at) 뒤에 만듦 · «모든 반» 아님 ·
     수업일이 시험 첫날 70일 전 ~ 시험 끝 날 전(볼 수 있는지 · 숨김 · 공개 끝은 부르는 쪽이 봄) */
  function c2New(g, l) {
    var day = c2Day(l);
    return !!(g && g.saved_at && isFinite(tms(l.created_at)) && isFinite(tms(g.saved_at)) && tms(l.created_at) > tms(g.saved_at) &&
      (l.class_ids || []).indexOf('*') < 0 && day && day >= c2Add(g.exam_on, -70) && day < g.end_on);
  }
  function c2Meets(a, b) {
    var i;
    a = isArr(a) ? a : []; b = isArr(b) ? b : [];
    for (i = 0; i < a.length; i += 1) { if (b.indexOf(a[i]) >= 0) return true; }
    return false;
  }
  /* lec__range_json 과 같은 칸 · 같은 차례 */
  function c2Row(o) {
    return {
      id: o.id, school_key: str(o.school_key), grade: str(o.grade), term: str(o.term), name: str(o.name),
      school_nm: str(o.school_nm), exam_on: o.exam_on, end_on: o.end_on, show_on: o.show_on || c2Add(o.exam_on, -20),
      rids: o.rids || [], lecture_ids: o.lecture_ids || [], off: !!o.off,
      saved_by: str(o.saved_by), saved_at: o.saved_at || pgts(nowMs()), synced_at: o.synced_at || null,
      rule_ver: o.rule_ver || 1, src_t: o.src_t || 0
    };
  }
  function c2Ts(a, b) {
    var x = tms(a), y = tms(b);
    x = isFinite(x) ? x : 0; y = isFinite(y) ? y : 0;
    return x - y;
  }

  function c2Ensure(d) {
    if (!d || d.c2 === 1) return false;
    var X = w.Lec;
    if (!X || typeof X.examName !== 'function') return false;
    var info = {
      's1001|김하늘': { school: '한빛여고', grade: '1' },
      's1002|이바다': { school: '바다고등학교', grade: '1' },
      's1003|박구름': { school: '푸른고', grade: '1' },
      's1004|최새봄': { intake: { school: '한빛여자고등학교', grade: '1학년' } },
      's1005|정단비': { school: '한빛여고 1학년' },
      's2001|한겨울': { school: '새솔고', grade: '2' },
      's2002|윤가람': { school: '한빛여고', grade: '2' },
      's1005|서은별': { school: '한빛여고' }
    };
    var i, j, s, x, k, t0 = nowMs() - DAY;
    for (i = 0; i < (d.classes || []).length; i += 1) {
      for (j = 0; j < ((d.classes[i] && d.classes[i].students) || []).length; j += 1) {
        s = d.classes[i].students[j];
        x = s ? info[s.id + '|' + s.name] : null;
        if (!x) continue;
        if (x.school != null) s.school = x.school;
        if (x.grade != null) s.grade = x.grade;
        if (x.intake) {
          if (!s.intake || typeof s.intake !== 'object') s.intake = {};
          for (k in x.intake) { if (has(x.intake, k)) s.intake[k] = x.intake[k]; }
        }
      }
    }
    function dk(off) { return dayStr(off).replace(/-/g, '.'); }
    if (!d.app || typeof d.app !== 'object') d.app = {};
    if (!d.app.main || typeof d.app.main !== 'object') d.app.main = {};
    /* 줄 나누기 전에 main 에 남은 옛 값(시각 도장이 더 작아 pt-etc 것이 이김 · 옛길고는 끝난 시험) */
    d.app.main.examSchool = {
      '한빛여고': { label: '2학기 중간고사', date: dk(-40), t: t0 - HOUR },
      '옛길고': { label: '기말고사', date: dk(-100), end: dk(-98) }
    };
    d.app['pt-etc'] = {
      examSchool: {
        '한빛여고': { label: '2학기 기말고사', date: dk(9), end: dayStr(12), name: '한빛여고', by: 'Joey', t: t0 },
        '새솔고': { label: '기말고사', date: dayStr(25), by: 'Dana', t: t0 },
        '바다고': { label: '2학기 기말', date: dk(12), end: dk(13), t: t0 },
        '푸른고': { del: 1, t: t0 }
      },
      examSchoolG: {
        '한빛여고|2': { label: '2학기 기말고사', date: dk(26), end: dk(27), on: 1, by: 'Dana', t: t0 }
      },
      payroll: { 'Joey|C2-FAKE': { amount: 1234567, note: 'C2-FAKE-PAYROLL' } },
      cash: { 'C2-FAKE': { amount: 7654321, note: 'C2-FAKE-CASH' } }
    };
    var n1 = X.examName('2학기 기말고사', dayStr(9)), n2 = X.examName('기말고사', dayStr(25));
    d.range = [
      c2Row({
        id: C2ID.R1, school_key: '한빛여고', grade: '1', term: n1.term, name: n1.name, school_nm: '한빛여고',
        exam_on: dayStr(9), end_on: dayStr(12), rids: ['s1001', 's1004', 's1005|정단비'],
        lecture_ids: [ID.L1, ID.L2, ID.L5, ID.L7], saved_by: 'Joey', saved_at: pgts(atMs(-1, 21, 10)), src_t: t0
      }),
      c2Row({
        id: C2ID.R2, school_key: '새솔고', grade: '2', term: n2.term, name: n2.name, school_nm: '새솔고',
        exam_on: dayStr(25), end_on: dayStr(25), rids: ['s2001'],
        lecture_ids: [ID.L3, ID.L4], saved_by: 'Dana', saved_at: pgts(atMs(-1, 22, 0)), src_t: t0
      })
    ];
    d.c2 = 1;
    return true;
  }

  /* ?manyexams=1 = 시험이 여럿 몰린 때(C2 검수 M3 · L1 · L5 화면 확인용): 고1 A반(Joey)에 학생 다섯 + 학교 시험 일정 다섯
       동해고 «2학기 기말고사» D+5 · 솔빛여자고등학교(솔빛여고) «기말고사» D+7(긴 이름) · 한결고 시험 이름 없음 D+15 ·
       가람중학교 3학년 «2학기 기말고사» D+20 · 은하고 «2학기 기말고사» D-1 ~ D+2(시험 중)
     → 바다고까지 Joey 띠 여섯(셋만 보이고 «시험 범위 3개 더 고르기») · 그냥 ?demo=1 로 돌아가면 넣은 것을 걷어 냄 */
  var MANY = false;
  try { MANY = /[?&]manyexams=1(&|$)/.test(w.location.search); } catch (e) { MANY = false; }
  var C2MANY = [
    { id: 's1101', name: '남동해', tel: '6101', school: '동해고', grade: '1', key: '동해고', rec: { label: '2학기 기말고사', d: 5 } },
    { id: 's1102', name: '오솔빛', tel: '6102', school: '솔빛여자고등학교', grade: '1', key: '솔빛여고',
      rec: { label: '기말고사', d: 7, name: '솔빛여자고등학교' } },
    { id: 's1103', name: '문한결', tel: '6103', school: '한결고', grade: '1', key: '한결고', rec: { label: '', d: 15 } },
    { id: 's1104', name: '장가람', tel: '6104', school: '가람중학교', grade: '3', key: '가람중', rec: { label: '2학기 기말고사', d: 20 } },
    { id: 's1105', name: '하은하', tel: '6105', school: '은하고', grade: '1', key: '은하고', rec: { label: '2학기 기말고사', d: -1, e: 2 } }
  ];
  function c2Many(d) {
    var cls = null, es, ids = {}, keys = {}, i, x, s, t0 = nowMs() - DAY, ch = false;
    if (!d || d.c2 !== 1) return false;
    for (i = 0; i < (d.classes || []).length; i += 1) { if (d.classes[i] && d.classes[i].id === 'c-g1a') cls = d.classes[i]; }
    if (!d.app || typeof d.app !== 'object') d.app = {};
    if (!d.app['pt-etc'] || typeof d.app['pt-etc'] !== 'object') d.app['pt-etc'] = {};
    if (!d.app['pt-etc'].examSchool || typeof d.app['pt-etc'].examSchool !== 'object') d.app['pt-etc'].examSchool = {};
    es = d.app['pt-etc'].examSchool;
    for (i = 0; i < C2MANY.length; i += 1) { ids[C2MANY[i].id] = 1; keys[C2MANY[i].key] = 1; }
    if (MANY && d.c2many !== 1) {
      for (i = 0; i < C2MANY.length; i += 1) {
        x = C2MANY[i];
        if (cls) {
          s = stu(x.id, x.name, x.tel);
          s.school = x.school; s.grade = x.grade;
          cls.students.push(s);
        }
        es[x.key] = { label: x.rec.label, date: dayStr(x.rec.d).replace(/-/g, '.'), t: t0 };
        if (x.rec.e != null) es[x.key].end = dayStr(x.rec.e).replace(/-/g, '.');
        if (x.rec.name) es[x.key].name = x.rec.name;
      }
      d.c2many = 1;
      return true;
    }
    if (!MANY && d.c2many === 1) {
      if (cls) cls.students = cls.students.filter(function (q) { return !(q && ids[q.id]); });
      for (x in keys) { if (has(keys, x)) delete es[x]; }
      d.range = (d.range || []).filter(function (g) { return !(g && keys[g.school_key]); });
      if (isArr(d.key)) d.key = d.key.filter(function (k) { return !(k && ids[str(k.sid).split('|')[0]]); });
      delete d.c2many;
      ch = true;
    }
    return ch;
  }

  /* lec_range_me: 내 rid(또는 학생 열쇠)가 든 줄 · 꺼지지 않음 · 오늘이 show_on ~ end_on · 볼 수 있는 강의만 · 빈 줄 뺌
     같은 이름 · 같은 날짜 줄이 둘이면 나중에 저장한 줄 하나(C2 검수 L-3) · 저장한 뒤 올린 강의도 들어감(M1 · c2New) */
  function lec_range_me(d, a) {
    var k = findKey(d, a.p_key), t = today(), items = [], pick = {}, order = [];
    if (!k) return { ok: false, err: 'key' };
    var rid = str(k.rid) !== '' ? str(k.rid) : str(k.sid).split('|')[0];
    (d.range || []).forEach(function (g) {
      var rids = g.rids || [], key, cur;
      if (g.off || !(t >= g.show_on && t <= g.end_on)) return;
      if (!((rid !== '' && rids.indexOf(rid) >= 0) || rids.indexOf(k.sid) >= 0)) return;
      key = str(g.name) + '|' + g.exam_on + '|' + g.end_on;
      cur = pick[key];
      if (!cur) { pick[key] = g; order.push(key); return; }
      if (c2Ts(g.saved_at, cur.saved_at) > 0 || (c2Ts(g.saved_at, cur.saved_at) === 0 && cmpC(g.id, cur.id) < 0)) pick[key] = g;
    });
    order.forEach(function (key) {
      var g = pick[key], ls = [], done = 0;
      d.lecture.forEach(function (l) {
        if (((g.lecture_ids || []).indexOf(l.id) >= 0 || c2New(g, l)) && isOpen(l, k.cls) && !ended(l)) ls.push(l);
      });
      if (!ls.length) return;
      ls.sort(function (x, y) {
        return cmpC(x.lesson_on || x.posted_on, y.lesson_on || y.posted_on) || c2Ts(x.created_at, y.created_at) || cmpC(x.id, y.id);
      });
      ls.forEach(function (l) {
        var p = findProgress(d, k.sid, l.id);
        if (p && (p.done_at != null || p.done_by != null)) done += 1;
      });
      items.push({ id: g.id, name: g.name, exam_on: g.exam_on, end_on: g.end_on, lectures: ls.map(function (l) { return l.id; }), done: done });
    });
    items.sort(function (x, y) { return cmpC(x.exam_on, y.exam_on) || cmpC(x.id, y.id); });
    return { ok: true, today: t, items: items };
  }

  /* lec_range_staff: 끝난 지 90일이 안 된 줄(꺼진 줄 포함) */
  function lec_range_staff(d) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var t = today(), from = c2Add(t, -90);
    var items = (d.range || []).filter(function (g) { return g.end_on >= from; }).map(function (g) { return clone(g); });
    items.sort(function (x, y) {
      return cmpC(x.exam_on, y.exam_on) || cmpC(x.school_key, y.school_key) || cmpC(x.grade, y.grade) || cmpC(x.term, y.term);
    });
    return { ok: true, today: t, items: items };
  }

  /* lec_range_save: 같은 학교 · 학년 · 시험이면 덮어씀 · 받는 학생은 명단만 · 관리자 아닌 선생님은 볼 수 있는 강의만 바꿈 */
  function lec_range_save(d, a) {
    var X = L();
    var ex = c2DateArg(a.p_exam, 'p_exam'), en = c2DateArg(a.p_end, 'p_end');
    var rids = c2ArrArg(a.p_rids, 'text', 'p_rids'), lecs = c2ArrArg(a.p_lectures, 'uuid', 'p_lectures');
    if (!ME) return { ok: false, err: 'forbidden' };
    var school = X.btrim(str(a.p_school)), grade = X.btrim(str(a.p_grade)), term = X.btrim(str(a.p_term));
    if (X.clen(school) < 1 || X.clen(school) > 40 || !/^[1-6]$/.test(grade) || X.clen(term) < 1 || X.clen(term) > 40 ||
        ex == null || ex < '2000-01-01' || ex > '2100-12-31' || (rids ? rids.length : 0) > 2000 || (lecs ? lecs.length : 0) > 200) {
      return { ok: false, err: 'input' };
    }
    var end = en == null || en < ex ? ex : en;
    if (end > c2Add(ex, 31)) return { ok: false, err: 'input' };
    var ok = c2Ids(d);
    var rr = c2Uniq((rids || []).filter(function (x) { return x != null && has(ok, '#' + x); }));
    var mine = myClassIds(d, ME.name), row = null, i;
    for (i = 0; i < (d.range || []).length; i += 1) {
      if (d.range[i].school_key === school && d.range[i].grade === grade && d.range[i].term === term) row = d.range[i];
    }
    var old = row ? (row.lecture_ids || []) : [];
    var ver = c2Ver(a.p_ver), tt = c2T(a.p_t);
    /* 옛 판(p_ver) · 옛 일정(p_t) 화면 = 날짜 · 이름 · 켜고 끄기는 줄에 있던 대로 */
    var fresh = !row || (tt >= (+row.src_t || 0) && ver >= (+row.rule_ver || 1));
    var vis = function (l) {
      return ME.admin || l.created_by === ME.name || (l.class_ids || []).indexOf('*') >= 0 || c2Meets(l.class_ids, mine);
    };
    var lv = [], rc = row ? c2RCls(d, row.rids) : [], seen = c2Seen(a.p_seen);
    /* 이 선생님이 못 보는 강의는 줄에 있던 대로 · 줄 저장 뒤 올라와 받는 학생에게 저절로 들어가던 강의(M1 · L-1)는
       못 보는 강의면 그대로 · 볼 수 있는 강의면 화면이 본 적 없는 강의(만든 시각이 p_seen 뒤)만 그대로(L-2) */
    d.lecture.forEach(function (l) {
      var m1 = !!row && !l.hidden && !ended(l) && c2New(row, l) && c2Meets(l.class_ids, rc);
      if (((lecs || []).indexOf(l.id) >= 0 && vis(l)) || (old.indexOf(l.id) >= 0 && !vis(l)) ||
          (m1 && (!vis(l) || Math.floor(tms(l.created_at)) > seen))) lv.push(l.id);
    });
    var o = c2Row({
      id: row ? row.id : X.uuid(), school_key: school, grade: grade, term: term,
      name: fresh ? X.left(X.btrim(str(a.p_name)), 40) : row.name,
      school_nm: fresh ? X.left(X.btrim(str(a.p_school_nm)), 40) : str(row.school_nm),
      exam_on: fresh ? ex : row.exam_on, end_on: fresh ? end : row.end_on,
      show_on: fresh ? c2Add(ex, -20) : row.show_on, rids: rr, lecture_ids: c2Uniq(lv), off: fresh ? false : !!row.off,
      saved_by: ME.name, saved_at: pgts(nowMs()), synced_at: row ? row.synced_at : null,
      rule_ver: fresh ? ver : (+row.rule_ver || 1), src_t: fresh ? tt : (+row.src_t || 0)
    });
    if (!d.range) d.range = [];
    if (row) d.range[d.range.indexOf(row)] = o;
    else d.range.push(o);
    return { ok: true, id: o.id, item: clone(o), stale: !fresh };
  }

  /* lec_range_sync: 있는 줄만 · 끄기 · 날짜 · 이름 · 받는 학생(명단만) · 강의 · 저장한 사람은 그대로
     t(일정 고친 시각) · p_ver(규칙 판)가 줄의 src_t · rule_ver 보다 낮으면 그 줄은 건너뜀 */
  var C2UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
  function lec_range_sync(d, a) {
    if (!ME) return { ok: false, err: 'forbidden' };
    var rows = a.p_rows, X = L(), n = 0, ok, now = pgts(nowMs()), ver = c2Ver(a.p_ver);
    if (!isArr(rows) || rows.length > 500) return { ok: false, err: 'input' };
    ok = c2Ids(d);
    rows.forEach(function (e) {
      var id, row = null, i, ex, en, tx, tt;
      if (!e || typeof e !== 'object' || isArr(e)) return;
      id = X.jtext(e.id);
      if (!C2UUID.test(str(id))) return;
      id = id.toLowerCase();
      for (i = 0; i < (d.range || []).length; i += 1) { if (d.range[i].id === id) row = d.range[i]; }
      tx = X.jtext(e.t);
      tt = /^[0-9]{1,15}$/.test(str(tx)) ? c2T(+tx) : 0;
      var can = function () { return row && (+row.rule_ver || 1) <= ver && (+row.src_t || 0) <= tt; };
      var bump = function () {
        row.src_t = Math.max(+row.src_t || 0, tt); row.rule_ver = Math.max(+row.rule_ver || 1, ver);
      };
      if (X.truthy(e.off)) {
        if (can() && !row.off) { row.off = true; row.synced_at = now; bump(); n += 1; }
        return;
      }
      ex = c2Date(X.jtext(e.exam));
      if (!ex) return;
      en = c2Date(X.jtext(e.end));
      en = en && en > ex ? en : ex;
      if (en > c2Add(ex, 31) || !can()) return;
      row.exam_on = ex; row.end_on = en; row.show_on = c2Add(ex, -20);
      if (typeof e.name === 'string' && X.btrim(e.name) !== '') row.name = X.left(X.btrim(e.name), 40);
      if (isArr(e.rids)) {
        row.rids = c2Uniq(e.rids.map(function (x) { return X.jtext(x); }).filter(function (x) { return x != null && has(ok, '#' + x); }));
      }
      row.off = false; row.synced_at = now; bump(); n += 1;
    });
    return { ok: true, n: n };
  }

  IMPL.lec_range_me = lec_range_me;
  SIG.lec_range_me = { p_key: 'text' };
  SIG.lec_range_staff = {};
  SIG.lec_range_save = {
    p_school: 'text', p_grade: 'text', p_term: 'text', p_name: 'text', p_exam: 'date', p_end: 'date',
    p_rids: 'textarr', p_lectures: 'uuidarr', p_school_nm: 'text?', p_ver: 'int?', p_t: 'big?', p_seen: 'big?'
  };
  SIG.lec_range_sync = { p_rows: 'json', p_ver: 'int?' };
  STAFF.lec_range_staff = lec_range_staff;
  STAFF.lec_range_save = lec_range_save;
  STAFF.lec_range_sync = lec_range_sync;

  /* 선생님 화면(연습용): 저장된 범위 · 저장 · 조용히 맞추기 · 히즈북스 학교 시험 일정 줄
     exams() = 진짜 화면의 app_state 읽기(id in (pt-etc, main) · id · data->examSchool · data->examSchoolG 만)와 같은 꼴 */
  staff.ranges = function () { return staffRpc('lec_range_staff', {}); };
  staff.saveRange = function (args) { return staffRpc('lec_range_save', args); };
  staff.syncRange = function (rows, ver) {
    var a = { p_rows: rows };
    if (ver !== undefined) a.p_ver = ver;
    return staffRpc('lec_range_sync', a);
  };
  staff.exams = function () {
    return withDb(function (d) {
      var out = [], ids = ['pt-etc', 'main'], i, r;
      if (!ME) return out;
      for (i = 0; i < ids.length; i += 1) {
        r = d.app && d.app[ids[i]];
        if (!r || typeof r !== 'object') continue;
        out.push({
          id: ids[i],
          es: r.examSchool === undefined ? null : r.examSchool,
          eg: r.examSchoolG === undefined ? null : r.examSchoolG
        });
      }
      return out;
    });
  };
  w.LecMock.c2ids = C2ID;
  /* 시험용: C2 함수만 없는 서버 켜기·끄기 */
  w.LecMock.noRange = function (on) { if (on !== undefined) NORANGE = !!on; return NORANGE; };
})(window);
