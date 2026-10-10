# -*- coding: utf-8 -*-
"""동기화 폭주 검사 (his-storm) — 가만히 둔 기기 두 대가 클라우드에 «전체»를 쓰지 않는지.

    py _check/his-storm.py

왜: 2026-10-10 밤, 기기끼리 «받으면 2초 뒤 전체를 다시 올리기»를 끝없이 주고받아
(화면 켠 기기 2대면 분당 전체 쓰기 5번 · 4대면 20번) 클라우드 DB 가 디스크 한도를 다 쓰고 멈췄다.
이 검사는 진짜 로그인 관문·동기화 코드를 그대로 돌리고, 클라우드만 가짜(이 파일 안의 로컬 서버)로 바꿔
«누가 언제 전체를 쓰고 읽는지»를 센다. 실제 클라우드에는 아무것도 보내지 않는다.

보는 것
  1 가만히 40초 — 전체 보내기 0 · 전체 받기 0 (작은 확인만)
  2 한 기기에서 고치면 — 보내기 딱 1번, 다른 기기는 받기만 하고 다시 올리지 않음
  3 고친 것이 다른 기기 화면에 뜸
동기화(로그인 관문의 보내기·받기)를 고쳤으면 반드시 돌릴 것. 기록: CLAUDE.md 맨 끝 §8-S1.
"""
import io
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)
except Exception:
    pass

from playwright.sync_api import sync_playwright

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(REPO, "index.html")
SEED_TS = "2026-10-10T10:00:00.000Z"

# 가짜 클라우드 라이브러리 — 앱이 쓰는 호출만 흉내 낸다(실제 Supabase 대신 /__cloud 와 말함)
FAKE_LIB = r"""
(function () {
  function dev() { try { return String(localStorage.getItem('__DEV') || '?'); } catch (e) { return '?'; } }
  function call(body) {
    body.dev = dev();
    return fetch('/__cloud', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (r) { return r.text().then(function (t) { var j = null; try { j = JSON.parse(t); } catch (e) { j = null; }
        if (!r.ok) return { data: null, error: { message: (j && j.message) || ('HTTP ' + r.status), code: (j && j.code) || '' }, status: r.status };
        var out = j || { data: null, error: null }; out.status = r.status; return out; }); })
      .catch(function () { return { data: null, error: { message: 'TypeError: Failed to fetch', code: '' }, status: 0 }; });
  }
  function B(t) { this.table = t; this.op = 'select'; this.cols = '*'; this.f = []; this.single = false; this.payload = null; }
  B.prototype.select = function (c) { if (this.op !== 'upsert' && this.op !== 'update' && this.op !== 'delete') this.op = 'select'; this.cols = c || '*'; return this; };
  B.prototype.eq = function (k, v) { this.f.push(['eq', k, v]); return this; };
  B.prototype.like = function (k, v) { this.f.push(['like', k, v]); return this; };
  B.prototype.lt = function (k, v) { this.f.push(['lt', k, v]); return this; };
  B.prototype.order = function () { return this; };
  B.prototype.maybeSingle = function () { this.single = true; return this; };
  B.prototype.upsert = function (p) { this.op = 'upsert'; this.payload = p; return this; };
  B.prototype.update = function (p) { this.op = 'update'; this.payload = p; return this; };
  B.prototype['delete'] = function () { this.op = 'delete'; return this; };
  B.prototype.then = function (ok, bad) { return call({ table: this.table, op: this.op, cols: this.cols, f: this.f, single: this.single, payload: this.payload }).then(ok, bad); };
  window.supabase = { createClient: function () { return {
    from: function (t) { return new B(t); },
    channel: function () { var c = { on: function () { return c; }, subscribe: function () { return c; } }; return c; },
    auth: { getSession: function () { return Promise.resolve({ data: { session: { user: { email: 'benjamin@his.kr', user_metadata: {} } } }, error: null }); },
            signOut: function () { return Promise.resolve({ error: null }); },
            signInWithPassword: function () { return Promise.resolve({ data: { session: null }, error: { message: 'test' } }); } } }; } };
})();
"""

FIBER = '''() => { const seen=new Set();
  const walk=(n,d)=>{ if(!n||d>500||seen.has(n))return null; seen.add(n);
    const s=n.stateNode; if(s&&s.constructor&&s.constructor.name==="StreamableComponent"&&s.logic&&s.logic.state&&s.logic.state.data)return s.logic;
    return walk(n.child,d+1)||walk(n.sibling,d+1); };
  for(const el of document.querySelectorAll("*")){ const k=Object.keys(el).find(x=>x.startsWith("__reactFiber")); if(!k)continue;
    let f=el[k]; while(f.return)f=f.return; const L=walk(f,0); if(L){window.__L=L;return true;} } return false; }'''

CT = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".png": "image/png",
      ".ico": "image/x-icon", ".webmanifest": "application/manifest+json", ".json": "application/json"}


def jsonb_norm(x):
    """실제 클라우드(JSONB)처럼 키 순서를 바꿔 보관한다 — «같은가»를 글자 비교로 하면 여기서 걸린다"""
    if isinstance(x, dict):
        ks = sorted(x.keys(), key=lambda k: (len(k.encode("utf-8")), k.encode("utf-8")))
        return {k: jsonb_norm(x[k]) for k in ks}
    if isinstance(x, list):
        return [jsonb_norm(v) for v in x]
    return x


class Cloud(object):
    def __init__(self):
        self.rows = {}
        self.log = []          # (초, 기기, 종류)  종류 = push | pull | check | etc
        self.lock = threading.Lock()
        self.t0 = time.time()

    def match(self, rid, row, f):
        for kind, k, v in f:
            val = rid if k == "id" else row.get(k)
            if kind == "eq" and val != v:
                return False
            if kind == "like" and not str(val).startswith(str(v).rstrip("%")):
                return False
            if kind == "lt" and not (str(val) < str(v)):
                return False
        return True

    def handle(self, b):
        op, f, cols, p = b.get("op"), (b.get("f") or []), (b.get("cols") or "*"), b.get("payload")
        main = any(k == "id" and v == "main" for _, k, v in f)
        kind = "etc"
        if op == "upsert" and isinstance(p, dict) and p.get("id") == "main":
            kind = "push"
        elif op == "update" and main:
            kind = "push"
        elif op == "select" and main and cols.strip() == "updated_at":
            kind = "check"
        elif op == "select" and main and "data" in cols:
            kind = "pull"
        with self.lock:
            self.log.append((time.time() - self.t0, b.get("dev", "?"), kind))
            if op == "upsert":
                row = dict(self.rows.get(p.get("id")) or {})
                for k, v in p.items():
                    if k != "id":
                        row[k] = jsonb_norm(v) if k == "data" else v
                self.rows[p.get("id")] = row
                return {"data": None, "error": None}
            if op == "update":
                for rid, row in self.rows.items():
                    if self.match(rid, row, f):
                        for k, v in p.items():
                            row[k] = jsonb_norm(v) if k == "data" else v
                return {"data": None, "error": None}
            if op == "delete":
                for rid in [r for r, row in self.rows.items() if self.match(r, row, f)]:
                    del self.rows[rid]
                return {"data": None, "error": None}
            want = [c.strip() for c in cols.split(",")] if cols != "*" else None
            out = []
            for rid, row in self.rows.items():
                if self.match(rid, row, f):
                    full = dict(row)
                    full["id"] = rid
                    out.append({k: full.get(k) for k in want} if want else full)
            return {"data": (out[0] if out else None) if b.get("single") else out, "error": None}

    def count(self, kind, since, dev=None):
        with self.lock:
            return len([1 for t, d, k in self.log if k == kind and t >= since and (dev is None or d == dev)])

    def now(self):
        return time.time() - self.t0


def serve(cloud):
    class H(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):
            pass

        def out(self, code, body, ctype="application/json; charset=utf-8", extra=None):
            if isinstance(body, (dict, list)):
                body = json.dumps(body, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            for k, v in (extra or {}).items():
                self.send_header(k, v)
            self.end_headers()
            try:
                self.wfile.write(body)
            except Exception:
                pass

        def do_HEAD(self):
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(n) if n else b""
            try:
                body = json.loads(raw.decode("utf-8"))
            except Exception:
                body = {}
            self.out(200, cloud.handle(body))

        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/vendor-supabase-2.49.4.js":
                self.out(200, FAKE_LIB.encode("utf-8"), CT[".js"])
                return
            if path == "/sw.js":
                self.out(404, b"no", "text/plain")
                return
            fp = INDEX if path in ("/", "/index.html") else os.path.join(REPO, path.lstrip("/").replace("/", os.sep))
            if not os.path.isfile(fp):
                self.out(404, b"not found", "text/plain")
                return
            data = open(fp, "rb").read()
            ext = os.path.splitext(fp)[1].lower()
            rng = self.headers.get("Range")
            if rng and rng.startswith("bytes="):
                a, b = rng[6:].split("-")
                a = int(a or 0)
                b = int(b) if b else len(data) - 1
                part = data[a:b + 1]
                self.out(206, part, CT.get(ext, "application/octet-stream"),
                         {"Content-Range": "bytes %d-%d/%d" % (a, a + len(part) - 1, len(data))})
                return
            self.out(200, data, CT.get(ext, "application/octet-stream"))

    httpd = ThreadingHTTPServer(("127.0.0.1", 0), H)
    httpd.daemon_threads = True
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def seed():
    studs = [{"id": "s%d" % i, "name": "학생%d" % i, "school": "검사고",
              "intake": {"parentContact": "010-0000-%04d" % (1000 + i)}} for i in range(1, 7)]
    sch = {"days": ["월", "화", "수", "목", "금", "토", "일"], "start": "20:00", "end": "22:00"}
    return {"classes": [{"id": "C1", "name": "검사 1반", "owner": "Dana", "students": studs[:3], "schedule": sch},
                        {"id": "C2", "name": "검사 2반", "owner": "Joey", "students": studs[3:], "schedule": sch}],
            "records": [], "exams": [], "counsels": [], "checkins": {}, "kioskPin": "0000"}


def device(br, port, label, data, kiosk):
    ctx = br.new_context(viewport=({"width": 1080, "height": 1920} if kiosk else {"width": 1440, "height": 900}),
                         service_workers="block")
    ls = {"__DEV": label, "his-user-v1": "관리자", "__cloud_at": SEED_TS, "__his_remember": "1",
          "sb-test-auth-token": json.dumps({"user": {"email": "benjamin@his.kr", "user_metadata": {}}}),
          "his-sys-v4": json.dumps(data, ensure_ascii=False)}
    if kiosk:
        ls["__his_kiosk"] = "1"
    ctx.add_init_script("(function(){try{if(localStorage.getItem('__seeded')==='1')return;var m=%s;for(var k in m){localStorage.setItem(k,m[k]);}localStorage.setItem('__seeded','1');}catch(e){}})();"
                        % json.dumps(ls, ensure_ascii=False))
    host = "127.0.0.1:%d" % port

    def route(r):
        u = r.request.url
        if host in u or u.startswith("data:") or u.startswith("blob:"):
            r.continue_()
        elif "unpkg.com/react" in u:
            r.continue_()                      # 앱이 React 를 여기서 받는다(이것만 실제로 나감)
        else:
            r.fulfill(status=200, body="", content_type=("text/css" if (".css" in u or "css2" in u) else "text/javascript"))

    ctx.route("**/*", route)
    pg = ctx.new_page()
    pg._errs = []
    pg.on("pageerror", lambda e: pg._errs.append(str(e)[:200]))
    pg.goto("http://%s/" % host, wait_until="domcontentloaded")
    return ctx, pg


def until(pg, js, timeout):
    t = time.time() + timeout
    while time.time() < t:
        try:
            if pg.evaluate(js):
                return True
        except Exception:
            pass
        pg.wait_for_timeout(500)
    return False


def spin(pages, secs):
    t = time.time() + secs
    while time.time() < t:
        for pg in pages:
            pg.wait_for_timeout(250)


def main():
    cloud = Cloud()
    data = seed()
    cloud.rows["main"] = {"data": jsonb_norm(data), "updated_at": SEED_TS, "client_id": "seed"}
    httpd = serve(cloud)
    port = httpd.server_address[1]
    res = []

    def ck(name, ok, extra=""):
        res.append(ok)
        print("  %s  %s%s" % ("OK " if ok else "실패", name, (" — " + str(extra)) if extra != "" else ""))

    print("=" * 62)
    print(" 동기화 폭주 검사 — 가만히 둔 기기 두 대 (가짜 클라우드)")
    print("=" * 62)
    with sync_playwright() as p:
        br = p.chromium.launch()
        ca, a = device(br, port, "PC", data, False)
        cb, b = device(br, port, "KIOSK", data, True)
        booted = True
        for pg in (a, b):
            if not until(pg, "() => { var g=document.getElementById('cloud-gate'); return !!document.querySelector('.sc-host') && (!g || g.style.display==='none'); }", 70):
                booted = False
        if not booted:
            print("  앱이 뜨지 않았습니다 — 인터넷(React 받기)을 확인하세요.", (a._errs + b._errs)[:2])
            br.close()
            return 2
        for pg in (a, b):
            until(pg, FIBER, 15)
            # 하루 한 번 만드는 «오늘 알림 제외 명부»가 생길 때까지(켠 뒤 30초쯤)
            until(pg, "() => { const L=window.__L; return !!(L && ((L.state.data.alertBlock||{})[L.today()])); }", 55)
        # 부팅 때의 쓰기가 가라앉을 때까지: 16초 동안 보내기가 없으면 시작
        last_n, last_t, cap = -1, time.time(), time.time() + 100
        while time.time() < cap:
            n = cloud.count("push", 0)
            if n != last_n:
                last_n, last_t = n, time.time()
            if time.time() - last_t >= 16:
                break
            spin([a, b], 1)
        t0 = cloud.now()
        spin([a, b], 40)
        ck("가만히 40초 — 전체 보내기 0번", cloud.count("push", t0) == 0, "%d번" % cloud.count("push", t0))
        ck("가만히 40초 — 전체 받기 0번", cloud.count("pull", t0) == 0, "%d번" % cloud.count("pull", t0))
        ck("작은 확인(날짜 도장)은 계속 함", cloud.count("check", t0) >= 4, "%d번" % cloud.count("check", t0))
        t1 = cloud.now()
        a.evaluate("() => window.__L.setKioskNote('폭주 검사 문구')")
        got = until(b, "() => (window.__L && window.__L.state.data.kioskNote) === '폭주 검사 문구'", 35)
        ck("PC 에서 고친 것이 키오스크 화면에 뜸", got, "%.0f초" % (cloud.now() - t1))
        spin([a, b], 30)
        ck("보내기는 고친 기기 1번뿐", cloud.count("push", t1, "PC") == 1 and cloud.count("push", t1, "KIOSK") == 0,
           "PC %d · 키오스크 %d" % (cloud.count("push", t1, "PC"), cloud.count("push", t1, "KIOSK")))
        ck("받은 기기는 전체 받기 1번", cloud.count("pull", t1, "KIOSK") == 1, "%d번" % cloud.count("pull", t1, "KIOSK"))
        t2 = cloud.now()
        spin([a, b], 26)
        ck("그 뒤 다시 조용함", cloud.count("push", t2) == 0 and cloud.count("pull", t2) == 0,
           "보내기 %d · 받기 %d" % (cloud.count("push", t2), cloud.count("pull", t2)))
        ck("JS 오류 없음", not (a._errs + b._errs), (a._errs + b._errs)[:2])
        br.close()
    httpd.shutdown()
    print("-" * 62)
    if all(res):
        print("  %d항목 전부 통과" % len(res))
        return 0
    print("  실패 %d건 — 기기끼리 다시 주고받고 있을 수 있습니다. CLAUDE.md 맨 끝 §8-S1 을 보세요." % res.count(False))
    return 1


if __name__ == "__main__":
    sys.exit(main())
