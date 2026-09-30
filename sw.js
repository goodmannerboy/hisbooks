// 히즈어학원 앱 서비스워커 — 인터넷이 끊겨도 앱이 열리게 (2026-09-30, 2차 검수 제안 R1)
// · 인터넷이 되면 늘 새로 받는다(network-first). 보관본은 «끊겼을 때만 여는 사본»이라 새 버전이 늦게 보이는 일이 없다.
// · 보관하는 것: 앱 화면(index.html) · 로그인 라이브러리 · 로고 · 아이콘 · 엠블럼. 다른 페이지(home.html 등)와 바깥 주소는 손대지 않는다.
// · 되돌리기(모든 기기에서 끄기): 이 파일 내용을 아래 두 줄로 바꿔 올리면 다음 접속 때 보관본을 지우고 스스로 빠진다.
//     self.addEventListener('install', () => self.skipWaiting());
//     self.addEventListener('activate', (e) => e.waitUntil(caches.keys().then((ks) => Promise.all(ks.map((k) => caches.delete(k)))).then(() => self.registration.unregister())));
const CACHE = 'his-shell-v1';
const SCOPE = self.registration.scope;
const SCOPE_PATH = new URL(SCOPE).pathname;
const INDEX = SCOPE + 'index.html';
const SHELL = ['index.html', 'vendor-supabase-2.49.4.js', 'manifest.webmanifest', 'favicon.ico',
  'icon-192.png', 'icon-512.png', 'icon-maskable-512.png', 'his-icon-180.png', 'his-icon-32.png',
  'his_fish_green.png', 'his_fish_cream.png',
  'assets/his-logo.png', 'assets/his-logo-sm.png', 'assets/his-logo-light.png']
  .concat(Array.from({ length: 16 }, (_, i) => 'assets/emblem-' + String(i + 1).padStart(2, '0') + '.png'));

// 보관 대상인가 — 주소의 ? 뒤는 무시. 'index' | 'file' | ''
function kindOf(rel) {
  if (rel === '' || rel === 'index.html') return 'index';
  if (rel === 'vendor-supabase-2.49.4.js' || rel === 'manifest.webmanifest' || rel === 'favicon.ico') return 'file';
  if (rel.slice(-4) === '.png') {
    if (rel.indexOf('/') < 0) return 'file';
    const p = rel.split('/');
    if (p.length === 2 && p[0] === 'assets') return 'file';
  }
  return '';
}

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => Promise.all(SHELL.map((rel) =>
    fetch(new Request(SCOPE + rel, { cache: 'no-cache' }))
      .then((res) => ((res && res.status === 200 && !res.redirected) ? c.put(SCOPE + rel, res) : null))
      .catch(() => null)))));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k.indexOf('his-shell-') === 0 && k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const r = e.request;
  if (r.method !== 'GET' || r.headers.has('range')) return;
  if (r.url.indexOf(SCOPE) !== 0) return;
  let rel = '';
  try { rel = new URL(r.url).pathname.slice(SCOPE_PATH.length); } catch (x) { return; }
  const kind = kindOf(rel);
  if (!kind) return;
  const key = (kind === 'index') ? INDEX : (SCOPE + rel);
  e.respondWith(
    fetch(r).then((res) => {
      if (res && res.status === 200 && res.type === 'basic' && !res.redirected) {
        const cp = res.clone();
        const put = caches.open(CACHE).then((c) => c.put(key, cp)).catch(() => null);
        try { e.waitUntil(put); } catch (x) {}
      }
      return res;
    }).catch((err) => caches.open(CACHE)
      .then((c) => c.match(key, { ignoreVary: true }))
      .then((m) => m || Promise.reject(err)))
  );
});
