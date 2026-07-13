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

function classStart(c: any, w: number): string {
  if (!c) return "";
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
function classEnd(c: any, w: number): string {
  if (!c) return "";
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
const toMin = (hm: string) => {
  const p = String(hm || "").split(":");
  return p.length === 2 ? parseInt(p[0], 10) * 60 + parseInt(p[1], 10) : null;
};
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
  const cd = data.closedDays;
  let closedToday = false;
  if (Array.isArray(cd)) closedToday = cd.indexOf(dateStr) >= 0;
  else if (cd && typeof cd === "object") { const e = cd[dateStr]; closedToday = !!(e && e.v === 1); }
  if (closedToday) {
    return new Response(JSON.stringify({ date: dateStr, closed: true, checked: 0, sent: [], skipped: [] }), { headers: { "Content-Type": "application/json" } });
  }
  const ck = data.checkins || {};
  const excused = data.noShowExcused || {};

  const targets: { sid: string; name: string; phone: string }[] = [];
  for (const c of (data.classes || [])) {
    const start = classStart(c, w);
    if (!start) continue;
    const startM = toMin(start);
    if (startM == null || nowMin <= startM) continue;
    let endM = toMin(classEnd(c, w));
    if (endM == null || endM <= startM) endM = startM + 120;
    if (nowMin > endM) continue;
    for (const stu of (c.students || [])) {
      if (stu && (stu.withdrawn || stu.pending)) continue;
      const key = stu.id + "|" + dateStr;
      const r = ck[key];
      if (r && r.in && !r.del) continue;
      if (excused[key] && !excused[key].del) continue;
      const phone = digits((stu.intake || {}).parentContact || "");
      if (!phone) continue;
      targets.push({ sid: stu.id, name: stu.name, phone });
    }
  }

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
