// @ts-nocheck
// 히즈 클래스 · 새 영상 알림 보내기(lec-push · 11-17 · CLAUDE.md §8-205)
//   매분 점검(pg_cron «his-lec-push» → lec_push_tick)이 보낼 것이 있을 때만 이 함수를 부릅니다(열쇠 없이).
//   이 함수는 받은 글을 읽지 않고, 서버 열쇠로 lec__push_claim 을 불러 지금 보낼 것만 받아 보낸 뒤 lec__push_done 에 결과를 적습니다.
// 배포(대시보드): Edge Functions › Deploy a new function › Via Editor › 이름 lec-push › 이 파일을 통째로 붙여 넣고 Deploy
//   › 그 함수의 Details(설정)에서 «Verify JWT with legacy secret»(Enforce JWT) 를 끕니다(매분 점검이 열쇠 없이 부르므로 · 끄지 않으면 401).
//   비밀 값(Secrets)은 새로 넣을 것이 없습니다(SUPABASE_URL · 서버 열쇠는 Supabase 가 스스로 넣어 줌).
// 알림 열쇠(VAPID): 처음 돌 때 스스로 만들어 lec_push_cfg 에 넣습니다(먼저 넣은 것이 이김 · 어디에도 따로 적지 않음).
// 표준: RFC 8291(aes128gcm · 기록 크기 4096 · keyid = 보내는 쪽 임시 공개 열쇠 65바이트) · RFC 8292(VAPID ES256) · RFC 8030(TTL · Urgency · Topic)
// 아무것도 import 하지 않습니다(WebCrypto · fetch 만).

const SUB = 'https://goodmannerboy.github.io/hisbooks/';
const HOSTS = /^https:\/\/(fcm\.googleapis\.com|android\.googleapis\.com|[a-z0-9-]+(\.[a-z0-9-]+)*\.push\.apple\.com|updates\.push\.services\.mozilla\.com|[a-z0-9-]+(\.[a-z0-9-]+)*\.notify\.windows\.com)\/[^\s]+$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RS = 4096;
const BATCH = 6;
// 시간 상한: fetch 한 번(푸시 서버 · DB) = 10초 · 보내기 전체 = 25초(매분 점검 pg_net 이 30초 기다림 · 함수 시간 한도 150초보다 훨씬 안쪽)
//   푸시 fetch 가 끊기면 그 폰은 0 · 25초가 지나면 남은 폰은 보내지 않고 0 으로 적음(많아야 한 번 · 다시 보내지 않음)
const LIM = { fetch: 10000, send: 25000 };
const te = new TextEncoder();

function b64u(buf) {
  const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = '';
  for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function unb64u(s) {
  let t = String(s || '').replace(/-/g, '+').replace(/_/g, '/');
  while (t.length % 4) t += '=';
  const bin = atob(t);
  const o = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) o[i] = bin.charCodeAt(i);
  return o;
}

function cat() {
  let n = 0;
  for (let i = 0; i < arguments.length; i++) n += arguments[i].length;
  const o = new Uint8Array(n);
  let p = 0;
  for (let i = 0; i < arguments.length; i++) {
    o.set(arguments[i], p);
    p += arguments[i].length;
  }
  return o;
}

async function hmac(key, data) {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, data));
}

// RFC 8291 §3.4 · RFC 8188: 받는 폰의 공개 열쇠(p256dh) · auth 로 한 기록짜리 aes128gcm 본문
//   opt = { salt, keyPair } 는 표준 시험 값을 맞출 때만(보통은 매번 새로 만듦)
async function encrypt(plain, uaPubB64, authB64, opt) {
  const uaPub = unb64u(uaPubB64);
  const auth = unb64u(authB64);
  if (uaPub.length !== 65 || uaPub[0] !== 4 || auth.length !== 16) throw new Error('key');
  if (plain.length + 1 + 16 > RS) throw new Error('size');
  const salt = (opt && opt.salt) || crypto.getRandomValues(new Uint8Array(16));
  const kp = (opt && opt.keyPair) || (await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']));
  const asPub = new Uint8Array(await crypto.subtle.exportKey('raw', kp.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPub, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, kp.privateKey, 256));
  const prkKey = await hmac(auth, ecdh);
  const ikm = await hmac(prkKey, cat(te.encode('WebPush: info\0'), uaPub, asPub, new Uint8Array([1])));
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(prk, cat(te.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, cat(te.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12);
  const key = await crypto.subtle.importKey('raw', cek, { name: 'AES-GCM' }, false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce, tagLength: 128 }, key, cat(plain, new Uint8Array([2]))));
  const head = new Uint8Array(21 + asPub.length);
  head.set(salt, 0);
  new DataView(head.buffer).setUint32(16, RS);
  head[20] = asPub.length;
  head.set(asPub, 21);
  return cat(head, ct);
}

// RFC 8292: aud = 푸시 주소의 origin · exp = 12시간 · sub = 앱 주소
async function vapidJwt(aud, pubB64, privB64, nowMs) {
  const pub = unb64u(pubB64);
  const jwk = { kty: 'EC', crv: 'P-256', x: b64u(pub.slice(1, 33)), y: b64u(pub.slice(33, 65)), d: privB64, ext: true };
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const exp = Math.floor(nowMs / 1000) + 12 * 3600;
  const h = b64u(te.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const p = b64u(te.encode(JSON.stringify({ aud: aud, exp: exp, sub: SUB })));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, te.encode(h + '.' + p)));
  return { t: h + '.' + p + '.' + b64u(sig), exp: exp };
}

// 알림 열쇠 한 쌍(P-256): 공개 = raw 65바이트(87자) · 비밀 = d 32바이트(43자)
async function makeKeys() {
  const kp = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const pub = new Uint8Array(await crypto.subtle.exportKey('raw', kp.publicKey));
  const jwk = await crypto.subtle.exportKey('jwk', kp.privateKey);
  return { pub: b64u(pub), priv: jwk.d };
}

function env(n) {
  return (typeof Deno !== 'undefined' && Deno.env.get(n)) || '';
}

// 서버 열쇠: 새 열쇠(SUPABASE_SECRET_KEYS 의 default) → 예전 서버 열쇠 · 값은 어디에도 적지 않음
function dbKey() {
  try {
    const j = JSON.parse(env('SUPABASE_SECRET_KEYS') || '{}');
    if (j && typeof j.default === 'string' && j.default) return j.default;
  } catch (e) {}
  return env('SB_SERVICE_KEY') || env('SUPABASE_SERVICE_ROLE_KEY');
}

// PostgREST RPC 만 씀(오류 글에는 함수 이름과 상태 번호만)
async function rpc(fn, args) {
  const key = dbKey();
  const h = { 'Content-Type': 'application/json', apikey: key };
  if (!/^sb_/.test(key)) h.Authorization = 'Bearer ' + key;
  const r = await fetch(env('SUPABASE_URL') + '/rest/v1/rpc/' + fn, {
    method: 'POST', headers: h, body: JSON.stringify(args || {}), signal: AbortSignal.timeout(LIM.fetch),
  });
  if (!r.ok) {
    try { await r.arrayBuffer(); } catch (e) {}
    throw new Error(fn + ' ' + r.status);
  }
  return await r.json();
}

// 폰 하나에 알림 하나: 돌려줌 = 푸시 서버의 상태 번호(201 · 404 · 410 …) · 못 보냄 · ms 안에 대답 없음 = 0
async function sendOne(it, k, jwt, changed, ms) {
  try {
    const ep = String(it.endpoint || '');
    if (!HOSTS.test(ep)) return 0;
    const ids = (Array.isArray(it.ids) ? it.ids : []).filter(function (x) { return UUID.test(String(x)); }).slice(0, 10);
    const body = te.encode(JSON.stringify({ t: String(it.t || ''), b: String(it.b || ''), ids: ids }));
    if (body.length > 3000) return 0;
    const aud = new URL(ep).origin;
    const now = Date.now();
    let c = jwt[aud];
    if (!c || c.k !== k.pub || typeof c.t !== 'string' || !(c.exp - now / 1000 > 3600)) {
      const v = await vapidJwt(aud, k.pub, k.priv, now);
      c = jwt[aud] = { t: v.t, exp: v.exp, k: k.pub };
      changed();
    }
    const enc = await encrypt(body, it.p256dh, it.auth);
    const r = await fetch(ep, {
      method: 'POST',
      headers: {
        TTL: '86400',
        Urgency: 'high', // 11-17 «안 떴어»: normal 은 잠든 폰(안드로이드 절전 · 아이폰 우선순위 5)에서 늦게 옴 → high = 바로
        Topic: String(ids[0] || 'new').replace(/[^A-Za-z0-9_]/g, '').slice(0, 32),
        'Content-Encoding': 'aes128gcm',
        'Content-Type': 'application/octet-stream',
        Authorization: 'vapid t=' + c.t + ', k=' + k.pub,
      },
      body: enc,
      signal: AbortSignal.timeout(Math.max(1, Math.min(LIM.fetch, +ms || LIM.fetch))),
    });
    try { await r.arrayBuffer(); } catch (e) {}
    return r.status;
  } catch (e) {
    return 0;
  }
}

function json(o, status) {
  return new Response(JSON.stringify(o), { status: status || 200, headers: { 'Content-Type': 'application/json' } });
}

// 한 번 부를 때: 꺼짐이면 끝 · 열쇠가 없으면 만들어 넣음 · 보낼 것을 받아 6개씩 보냄 · 묶음마다 결과를 적음(중간에 끊겨도 앞 묶음은 남음) · 대답은 개수만
async function handler(req) {
  if (req.method !== 'POST') return json({ lecPush: true, ok: false }, 405);
  const t0 = Date.now();
  try {
    let k = await rpc('lec__push_keys', {});
    if (!k || k.mode === 'off') return json({ lecPush: true, ok: true, mode: 'off', items: 0 });
    if (!k.pub || !k.priv) {
      const nk = await makeKeys();
      k = await rpc('lec__push_setkeys', { p_pub: nk.pub, p_priv: nk.priv });
      if (!k || !k.pub || !k.priv) return json({ lecPush: true, ok: false, err: 'keys' }, 500);
    }
    const c = await rpc('lec__push_claim', {});
    const items = c && Array.isArray(c.items) ? c.items : [];
    const jwt = k.jwt && typeof k.jwt === 'object' && !Array.isArray(k.jwt) ? k.jwt : {};
    let jwtChanged = false;
    let pend = [];   // 아직 lec__push_done 에 못 적은 결과(적기가 실패하면 다음 묶음 때 같이 다시)
    let nRes = 0, nSent = 0, nGone = 0, nLate = 0;
    const flush = async function () {
      if (!pend.length && !jwtChanged) return true;
      const part = pend, jw = jwtChanged;
      try {
        const d = await rpc('lec__push_done', { p_res: part, p_jwt: jw ? jwt : null });
        pend = pend.slice(part.length);
        if (jw) jwtChanged = false;
        nSent += (d && d.sent) || 0;
        nGone += (d && d.gone) || 0;
        return true;
      } catch (e) {
        return false;
      }
    };
    let i = 0;
    for (; i < items.length; i += BATCH) {
      const left = LIM.send - (Date.now() - t0);
      if (left < 1000) break;
      const part = await Promise.all(items.slice(i, i + BATCH).map(async function (it) {
        const code = await sendOne(it, k, jwt, function () { jwtChanged = true; }, Math.min(LIM.fetch, left));
        return { sub: it.sub, code: code, ids: it.ids };
      }));
      for (let j = 0; j < part.length; j++) pend.push(part[j]);
      nRes += part.length;
      await flush();
    }
    // 시간이 다 됨: 남은 폰은 보내지 않고 0 으로 적음
    for (; i < items.length; i++) {
      pend.push({ sub: items[i].sub, code: 0, ids: items[i].ids });
      nRes += 1;
      nLate += 1;
    }
    if (!(await flush())) return json({ lecPush: true, ok: false, err: 'lec__push_done', items: nRes }, 500);
    return json({ lecPush: true, ok: true, mode: k.mode, items: nRes, sent: nSent, gone: nGone, late: nLate });
  } catch (e) {
    return json({ lecPush: true, ok: false, err: String((e && e.message) || e).slice(0, 80) }, 500);
  }
}

if (typeof Deno === 'undefined') {
  globalThis.LecPush = { b64u: b64u, unb64u: unb64u, cat: cat, hmac: hmac, encrypt: encrypt, vapidJwt: vapidJwt, makeKeys: makeKeys, sendOne: sendOne, handler: handler, HOSTS: HOSTS, LIM: LIM };
} else {
  Deno.serve(handler);
}
