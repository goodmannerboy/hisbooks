/* 히즈클래스 · 새 영상 알림 일꾼(class-sw.js · 11-17 · CLAUDE.md §8-205)
   홈 화면 앱(class.html)이 «알림 받기»를 눌렀을 때만 등록합니다(범위 ./class.html · 히즈북스 앱과 상관없음).
   하는 일은 셋뿐: 알림 띄우기(push) · 알림을 누르면 강의 열기(notificationclick) · 푸시 주소가 바뀌면 다시 구독(pushsubscriptionchange)
   캐시 · fetch 처리 없음(화면은 늘 네트워크에서 그대로 받음) */
'use strict';

var LEC_T = '새 수업 영상이 올라왔어요';
var LEC_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function lecIds(v) {
  var o = [];
  if (Object.prototype.toString.call(v) !== '[object Array]') return o;
  for (var i = 0; i < v.length && o.length < 10; i++) {
    if (typeof v[i] === 'string' && LEC_UUID.test(v[i])) o.push(v[i]);
  }
  return o;
}

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (e) {
  e.waitUntil(self.clients.claim());
});

// 알림은 늘 띄움(조용한 푸시 없음) · 글이 비거나 깨져도 기본 제목으로
self.addEventListener('push', function (e) {
  var d = {};
  try {
    d = e.data ? e.data.json() : {};
  } catch (x) {
    d = {};
  }
  if (!d || typeof d !== 'object') d = {};
  var ids = lecIds(d.ids);
  var t = typeof d.t === 'string' && d.t ? d.t.slice(0, 80) : LEC_T;
  var b = typeof d.b === 'string' ? d.b.slice(0, 200) : '';
  e.waitUntil(self.registration.showNotification(t, {
    body: b,
    icon: 'app-icon-192.png',
    badge: 'class-badge.png',
    tag: 'lec-' + (ids[0] || 'new'),
    lang: 'ko',
    data: { ids: ids }
  }));
});

// 누르면: 강의 하나 = 그 강의(#v=) · 둘 이상 = 목록(#n= · 그 줄을 잠깐 칠함) · 열린 창이 있으면 그 창에 알리고 앞으로
self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var ids = lecIds(e.notification.data && e.notification.data.ids);
  var url = new URL('class.html?n=1' + (ids.length === 1 ? '#v=' + ids[0] : (ids.length ? '#n=' + ids.join(',') : '')), self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) {
      var c = list[i];
      if (c.url.indexOf('/class.html') >= 0 && 'focus' in c) {
        try {
          c.postMessage({ type: 'lec-open', ids: ids });
        } catch (x) {}
        return c.focus();
      }
    }
    if (self.clients.openWindow) return self.clients.openWindow(url);
  }));
});

// 푸시 서버가 주소를 바꾸면 같은 열쇠로 다시 구독(저장은 다음에 앱을 열 때 화면이 함)
self.addEventListener('pushsubscriptionchange', function (e) {
  var old = e.oldSubscription;
  var key = old && old.options && old.options.applicationServerKey;
  if (!key) return;
  e.waitUntil(self.registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key }).catch(function () {}));
});
