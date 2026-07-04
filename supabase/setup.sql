-- ─────────────────────────────────────────────────────────────
-- HIS 미등원 자동 알림톡 — DB 셋업 (Supabase SQL Editor에서 실행)
-- ─────────────────────────────────────────────────────────────

-- 1) 중복방지 테이블: 한 학생당 하루 1회만 발송 (alert_key = 'studentId|YYYY.MM.DD')
create table if not exists public.noshow_alerts (
  alert_key text primary key,
  sent_at   timestamptz default now()
);

-- 2) 자동 트리거에 필요한 확장
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 3) 10분마다 함수 호출 (운영시간대만: KST 13:00~22:59 = UTC 04~13시)
--    ⚠️ <PROJECT_REF> 와 <SERVICE_ROLE_KEY> 를 실제 값으로 바꿔서 실행하세요.
--    (이 SQL은 Supabase 대시보드 SQL Editor에서 실행 — 실제 키는 저장소에 올리지 마세요)
select cron.schedule(
  'his-noshow-alert',
  '*/10 4-13 * * *',
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/noshow-alert',
    headers := jsonb_build_object(
                 'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
                 'Content-Type',  'application/json'),
    body    := '{}'::jsonb
  );
  $$
);

-- (참고) 스케줄 해제:  select cron.unschedule('his-noshow-alert');
-- (참고) 오래된 발송기록 정리(선택, 30일):
--   delete from public.noshow_alerts where sent_at < now() - interval '30 days';
