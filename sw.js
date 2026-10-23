// 히즈어학원 앱 서비스워커 — 뺐다(2026-10-23, 원장 «인터넷 없이 열기» 기능 빼기 · CLAUDE.md §8-171)
// 예전(2026-09-30 ~ 10-23)에 설치된 기기가 이 파일을 받으면 보관본을 지우고 스스로 빠진다.
// 이 파일은 지우지 말 것 — 지우면(404) 예전 서비스워커가 기기에 그대로 남는다. 앱은 더 이상 서비스워커를 등록하지 않는다.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(
  caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => String(k).indexOf('his-shell') === 0).map((k) => caches.delete(k))))
    .then(() => self.registration.unregister())
));
