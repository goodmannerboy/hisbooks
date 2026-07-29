import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SB_SERVICE_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const SOLAPI_KEY = Deno.env.get("SOLAPI_API_KEY") ?? "";
const SOLAPI_SECRET = Deno.env.get("SOLAPI_API_SECRET") ?? "";
const SENDER = Deno.env.get("SOLAPI_SENDER") ?? "";
const PFID = Deno.env.get("SOLAPI_PFID") ?? "";
const TEMPLATE_ID = Deno.env.get("SOLAPI_TEMPLATE_ID") ?? "";

const KDAY = ["일", "월", "화", "수", "목", "금", "토"];
const digits = (s: string) => String(s || "").replace(/[^0-9]/g, "");

// ════════════════════════════════════════════════════════════════
//  발송 판정 규칙 — 앱(index.html)과 반드시 같아야 하는 부분
//  ⚠ 앱에서 이 규칙을 바꾸면 여기도 같이 바꿔야 합니다.
//    _check/his-check.py 의 R6 규칙이 누락을 잡아 줍니다.
//
//  이중 안전망: 앱이 매일 data.alertBlock[날짜] 에 «오늘 보내면 안 되는 학생»을
//  미리 적어 둡니다. 서버는 자기 판정에 더해 이 명부를 추가로 뺍니다.
//  명부는 «빼기»만 하므로, 앱이 안 돌았어도 과발송 방향으로는 절대 가지 않습니다.
// ════════════════════════════════════════════════════════════════

const toMin = (hm: string) => {
  const p = String(hm || "").split(":");
  return p.length === 2 ? parseInt(p[0], 10) * 60 + parseInt(p[1], 10) : null;
};

// 날짜 표기 정규화 — 구분자(. - /) 통일 + 월·일 0 채움
function normDate(s: string): string {
  const p = String(s || "").replace(/[-/]/g, ".").trim().split(".");
  if (p.length < 3) return "";
  const y = parseInt(p[0], 10), m = parseInt(p[1], 10), d = parseInt(p[2], 10);
  if (!(y > 0) || !(m > 0) || !(d > 0)) return "";
  return y + "." + String(m).padStart(2, "0") + "." + String(d).padStart(2, "0");
}

// 등원 시작 전 학생(접수대기 / 시작일이 아직 안 온 신규 등록생) — 앱 _notStarted
function notStarted(stu: any, todayStr: string): boolean {
  if (!stu) return false;
  if (stu.pending) return true;
  const sd = normDate(stu.startPlan || stu.registeredAt || "");
  if (!sd) return false;
  const td = normDate(todayStr);
  if (!td) return false;
  return sd > td;
}

// 날짜별 수업 오버레이 — 앱 _sessOv (휴강 off / 보강 start·end)
function sessOv(data: any, cid: string, dateStr: string): any {
  const m = (data && data.sessions) || {};
  const e = m[cid + "|" + dateStr];
  if (!e || e.del) return null;
  return e;
}

// 그 학생만 다른 날·다른 시간으로 잡힌 보강 — 앱 _mkupOf
function hasMakeup(data: any, sid: string, dateStr: string): boolean {
  const m = (data && data.mkup) || {};
  const e = m[sid + "|" + dateStr];
  return !!(e && !e.del);
}

function classStart(data: any, c: any, w: number, dateStr: string): string {
  if (!c) return "";
  const ov = sessOv(data, c.id, dateStr);
  if (ov) {
    if (ov.off) return "";          // 이번만 휴강 → 수업 없음
    if (ov.start) return ov.start;  // 보강으로 시간 이동
  }
  const day = KDAY[w];
  const sc = c.schedule || {};
  const days = (sc.days && sc.days.length) ? sc.days : null;
  const hasNum = (sc[w] != null && sc[w] !== "");
  if (days) { if (days.indexOf(day) < 0) return ""; } else if (!hasNum) { return ""; }
  if (sc.times && sc.times[day] && sc.times[day].start) return sc.times[day].start;
  if (sc[w]) return sc[w];
  if (c.startTime) return c.startTime;
  return "";
}

function classEnd(data: any, c: any, w: number, dateStr: string): string {
  if (!c) return "";
  const ov = sessOv(data, c.id, dateStr);
  if (ov) {
    if (ov.off) return "";
    if (ov.end) return ov.end;
  }
  const day = KDAY[w];
  const sc = c.schedule || {};
  const days = (sc.days && sc.days.length) ? sc.days : null;
  const hasNum = (sc[w] != null && sc[w] !== "");
  if (days) { if (days.indexOf(day) < 0) return ""; } else if (!hasNum) { return ""; }
  if (sc.times && sc.times[day] && sc.times[day].end) return sc.times[day].end;
  if (sc.end) return sc.end;
  if (c.endTime) return c.endTime;
  return "";
}

// 휴원일 — 앱 _cdClosed (배열·객체 두 형식 모두)
function closedOn(data: any, dateStr: string): boolean {
  const cd = data && data.closedDays;
  if (Array.isArray(cd)) return cd.indexOf(dateStr) >= 0;
  if (cd && typeof cd === "object") { const e = cd[dateStr]; return !!(e && e.v === 1); }
  return false;
}

// 앱이 미리 적어 둔 «오늘 보내면 안 되는» 명부
function alertBlock(data: any, dateStr: string): { closed: boolean; sids: Record<string, number> } {
  const out = { closed: false, sids: {} as Record<string, number> };
  const ab = ((data && data.alertBlock) || {})[dateStr];
  if (!ab) return out;
  if (ab.closed) out.closed = true;
  if (Array.isArray(ab.sids)) ab.sids.forEach((s: string) => { out.sids[s] = 1; });
  return out;
}

// 발송 대상 산출 — 순수 함수(테스트 가능)
function pickTargets(data: any, dateStr: string, w: number, nowMin: number) {
  if (closedOn(data, dateStr)) return { closed: true, targets: [] as any[] };
  const blk = alertBlock(data, dateStr);
  if (blk.closed) return { closed: true, targets: [] as any[] };
  const ck = data.checkins || {};
  const excused = data.noShowExcused || {};
  const targets: { sid: string; name: string; phone: string }[] = [];
  for (const c of (data.classes || [])) {
    const start = classStart(data, c, w, dateStr);
    if (!start) continue;                       // 수업 없음 · 휴강
    const startM = toMin(start);
    if (startM == null || nowMin <= startM) continue;
    let endM = toMin(classEnd(data, c, w, dateStr));
    if (endM == null || endM <= startM) endM = startM + 120;
    if (nowMin > endM) continue;
    for (const stu of (c.students || [])) {
      if (!stu || !stu.id) continue;
      if (stu.withdrawn || stu.pending) continue;
      if (notStarted(stu, dateStr)) continue;
      if (blk.sids[stu.id]) continue;           // 앱이 미리 뺀 학생
      if (hasMakeup(data, stu.id, dateStr)) continue;  // 그날 개인 보강
      const key = stu.id + "|" + dateStr;
      const r = ck[key];
      if (r && r.in && !r.del) continue;        // 이미 등원
      if (excused[key] && !excused[key].del) continue;  // 결석 예정
      const phone = digits((stu.intake || {}).parentContact || "");
      if (!phone) continue;
      targets.push({ sid: stu.id, name: stu.name, phone });
    }
  }
  return { closed: false, targets };
}

// ════════════════════════════════════════════════════════════════

function kstNow() {
  const t = new Date(Date.now() + 9 * 3600 * 1000);
  const y = t.getUTCFullYear(), m = t.getUTCMonth() + 1, d = t.getUTCDate();
  return { dateStr: `${y}.${String(m).padStart(2, "0")}.${String(d).padStart(2, "0")}`, w: t.getUTCDay(), nowMin: t.getUTCHours() * 60 + t.getUTCMinutes() };
}
async function hmac(msg: string, secret: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(msg));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function sendAlimtalk(to: string, studentName: string) {
  const date = new Date().toISOString();
  const salt = crypto.randomUUID();
  const signature = await hmac(date + salt, SOLAPI_SECRET);
  const auth = `HMAC-SHA256 apiKey=${SOLAPI_KEY}, date=${date}, salt=${salt}, signature=${signature}`;
  const smsText = `[히즈어학원] ${studentName} 학생이 수업 시간이 지났는데 아직 등원하지 않았습니다. 확인 부탁드립니다.`;
  const body = { message: { to, from: SENDER, text: smsText, kakaoOptions: { pfId: PFID, templateId: TEMPLATE_ID, variables: { "#{학생이름}": studentName }, disableSms: false } } };
  const res = await fetch("https://api.solapi.com/messages/v4/send", { method: "POST", headers: { Authorization: auth, "Content-Type": "application/json" }, body: JSON.stringify(body) });
  return { ok: res.ok, status: res.status, text: await res.text() };
}

Deno.serve(async (req) => {
  try {
    const u = new URL(req.url);
    const tp = u.searchParams.get("test");
    if (tp) {
      const p = digits(tp);
      if (!p) return new Response(JSON.stringify({ error: "no test phone" }), { status: 400, headers: { "Content-Type": "application/json" } });
      if (!SOLAPI_KEY) return new Response(JSON.stringify({ error: "no SOLAPI key" }), { status: 400, headers: { "Content-Type": "application/json" } });
      const r = await sendAlimtalk(p, "테스트");
      return new Response(JSON.stringify({ test: true, to: p, solapi_ok: r.ok, solapi_status: r.status, solapi_response: r.text }), { headers: { "Content-Type": "application/json" } });
    }
  } catch (_e) { /* ignore */ }

  const sb = createClient(SB_URL, SB_KEY);
  const { data: row, error } = await sb.from("app_state").select("data").eq("id", "main").single();
  if (error || !row) return new Response(JSON.stringify({ error: "app_state read fail", detail: (error && error.message) || "no row", hint: SB_KEY ? "check service_role key" : "set SB_SERVICE_KEY secret" }), { status: 500 });
  const data = row.data || {};
  const { dateStr, w, nowMin } = kstNow();

  const picked = pickTargets(data, dateStr, w, nowMin);
  if (picked.closed) {
    return new Response(JSON.stringify({ date: dateStr, closed: true, checked: 0, sent: [], skipped: [] }), { headers: { "Content-Type": "application/json" } });
  }
  const targets = picked.targets;

  const sent: string[] = [];
  const skipped: string[] = [];
  for (const t of targets) {
    const alertKey = t.sid + "|" + dateStr;
    const ins = await sb.from("noshow_alerts").insert({ alert_key: alertKey }).select();
    if (ins.error) { skipped.push(alertKey); continue; }
    if (SOLAPI_KEY) {
      const r = await sendAlimtalk(t.phone, t.name);
      sent.push(alertKey + (r.ok ? " ok" : " fail" + r.status));
    } else {
      sent.push(alertKey + " (dry-run)");
    }
  }
  return new Response(JSON.stringify({ date: dateStr, checked: targets.length, sent, skipped }), { headers: { "Content-Type": "application/json" } });
});
