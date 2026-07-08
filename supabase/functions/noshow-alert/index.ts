// ─────────────────────────────────────────────────────────────
// HIS 미등원 자동 알림톡 — Supabase Edge Function (Deno)
//
// 하는 일: 10분마다 호출되면 → app_state 데이터를 읽어 "수업 시작(정시)이
// 지났는데 아직 등원 체크인이 없는 학생"을 찾아 → (결석예정 제외, 중복 제외)
// 솔라피로 카카오 알림톡 발송(문자 자동 대체). 한 학생당 하루 1회만.
//
// 배포 후 필요한 환경변수(Supabase Secrets):
//   SOLAPI_API_KEY, SOLAPI_API_SECRET  (솔라피 API 키/시크릿)
//   SOLAPI_SENDER      (등록한 발신번호, 예: 0541234567)
//   SOLAPI_PFID        (카카오 채널 발신프로필 ID)
//   SOLAPI_TEMPLATE_ID (승인된 미등원 알림톡 템플릿 ID)
// (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 는 Supabase가 자동 주입)
// ─────────────────────────────────────────────────────────────
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SOLAPI_KEY = Deno.env.get("SOLAPI_API_KEY") ?? "";
const SOLAPI_SECRET = Deno.env.get("SOLAPI_API_SECRET") ?? "";
const SENDER = Deno.env.get("SOLAPI_SENDER") ?? "";
const PFID = Deno.env.get("SOLAPI_PFID") ?? "";
const TEMPLATE_ID = Deno.env.get("SOLAPI_TEMPLATE_ID") ?? "";

const KDAY = ["일", "월", "화", "수", "목", "금", "토"];
const digits = (s: string) => String(s || "").replace(/[^0-9]/g, "");

// 앱의 _classStart 와 동일: 시간표(times[요일].start) 우선 → 숫자키 → startTime
function classStart(c: any, w: number): string {
  if (!c) return "";
  const day = KDAY[w];
  if (c.schedule) {
    if (c.schedule.times && c.schedule.times[day] && c.schedule.times[day].start) return c.schedule.times[day].start;
    if (c.schedule[w]) return c.schedule[w];
  }
  if (c.startTime) return c.startTime;
  return "";
}
const toMin = (hm: string) => {
  const p = String(hm || "").split(":");
  return p.length === 2 ? parseInt(p[0], 10) * 60 + parseInt(p[1], 10) : null;
};

// 한국시간(KST) 기준 날짜/요일/분
function kstNow() {
  const t = new Date(Date.now() + 9 * 3600 * 1000);
  const y = t.getUTCFullYear(), m = t.getUTCMonth() + 1, d = t.getUTCDate();
  return {
    dateStr: `${y}.${String(m).padStart(2, "0")}.${String(d).padStart(2, "0")}`,
    w: t.getUTCDay(),
    nowMin: t.getUTCHours() * 60 + t.getUTCMinutes(),
  };
}

// 솔라피 알림톡 발송 (HMAC-SHA256 인증)
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
  // 카톡 실패 시 문자로 대체발송될 내용 (알림톡과 동일)
  const smsText = `[히즈어학원] ${studentName} 학생이 수업 시간이 지났는데 아직 등원하지 않았습니다. 확인 부탁드립니다.`;
  const body = {
    message: {
      to,
      from: SENDER,
      text: smsText, // 대체발송(문자) 내용
      kakaoOptions: {
        pfId: PFID,
        templateId: TEMPLATE_ID,
        variables: { "#{학생이름}": studentName },
        disableSms: false, // 카톡 실패 시 문자 자동 대체
      },
    },
  };
  const res = await fetch("https://api.solapi.com/messages/v4/send", {
    method: "POST",
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return { ok: res.ok, status: res.status, text: await res.text() };
}

Deno.serve(async () => {
  const sb = createClient(SB_URL, SB_KEY);
  const { data: row, error } = await sb.from("app_state").select("data").eq("id", "main").single();
  if (error || !row) return new Response(JSON.stringify({ error: "no app_state" }), { status: 500 });
  const data = row.data || {};
  const { dateStr, w, nowMin } = kstNow();
  const ck = data.checkins || {};
  const excused = data.noShowExcused || {};

  // 미등원 학생 수집 (앱 noShowList 와 동일 규칙, 지각기준=정시=0)
  const targets: { sid: string; name: string; phone: string }[] = [];
  for (const c of (data.classes || [])) {
    const start = classStart(c, w);
    if (!start) continue;                       // 오늘 수업 없는 반
    const startM = toMin(start);
    if (startM == null || nowMin <= startM) continue; // 정시 안 지남
    for (const stu of (c.students || [])) {
      if (stu && (stu.withdrawn || stu.pending)) continue; // 퇴원생·미확정 신규생 제외
      const key = stu.id + "|" + dateStr;
      const r = ck[key];
      if (r && r.in) continue;                  // 이미 등원
      if (excused[key]) continue;               // 결석 예정
      const phone = digits((stu.intake || {}).parentContact || "");
      if (!phone) continue;
      targets.push({ sid: stu.id, name: stu.name, phone });
    }
  }

  // 중복 방지: 오늘 이미 보낸 건 제외 (noshow_alerts 테이블)
  const sent: string[] = [];
  const skipped: string[] = [];
  for (const t of targets) {
    const alertKey = t.sid + "|" + dateStr;
    const ins = await sb.from("noshow_alerts").insert({ alert_key: alertKey }).select();
    if (ins.error) { skipped.push(alertKey); continue; } // 이미 존재(unique) → 이미 보냄
    if (SOLAPI_KEY) {
      const r = await sendAlimtalk(t.phone, t.name);
      sent.push(alertKey + (r.ok ? " ✓" : " ✗" + r.status));
    } else {
      sent.push(alertKey + " (DRY-RUN: 솔라피 키 미설정)");
    }
  }
  return new Response(JSON.stringify({ date: dateStr, checked: targets.length, sent, skipped }), {
    headers: { "Content-Type": "application/json" },
  });
});
