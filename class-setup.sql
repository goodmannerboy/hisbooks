-- ============================================================================
-- 히즈 강의실 · 서버 준비 (한 번만 실행 · 다시 실행해도 됩니다)
--
-- 1) supabase.com 로그인 → 히즈북스 프로젝트 → 왼쪽 «SQL Editor»
-- 2) «New query» → 이 파일 전체(Ctrl+A → Ctrl+C)를 붙여 넣고 «Run»
--    (경고 창이 뜨면 «Run this query»)
-- 3) 빨간 오류 없이 맨 아래 결과 칸에 «강의실 준비 끝 · 점검 8/8 통과 · 학생 수 · 강의 수 · PDF 저장 곳 · 새 영상 알림 · 녹음 저장 곳 · 30일 지난 녹음» 표가 나오면 통과입니다.
--    (스스로 점검 여덟은 통과하면 아무것도 안 보이고, 하나라도 틀리면 그 자리에서 빨간 오류로 멈춥니다)
--    빨간 오류가 나오면 아무것도 바뀌지 않은 것입니다(통째로 되돌려짐).
--    «PDF 저장 곳» 칸이 «됨»이 아니면 강의 필기 PDF 저장 곳(Storage)만 못 만든 것입니다 · 강의실은 그대로 씁니다
--    (그때는 대시보드 Storage 에서 버킷 · 정책을 만듭니다 · 차례는 맨 아래 P1 절 머리글)
--    «새 영상 알림» 칸은 알림 상태 한 줄입니다(처음은 «꺼짐 · 열쇠 아직 · 매분 점검 됨 · 켠 폰 0 · 아침 8:00» ·
--    «매분 점검 됨»이 아니면 매분 점검만 못 건 것 · 켜는 차례는 맨 아래 N1 절 머리글)
--    «녹음 저장 곳» 칸이 «됨»이 아니면 구문 녹음 저장 곳(Storage)만 못 만든 것입니다 · 차례는 맨 아래 S1 절 머리글
--    «30일 지난 녹음»은 지울 때가 된 녹음 수입니다(관리자가 세트 탭을 열면 지움)
--
-- 만드는 표
--   lec_lecture   강의(유튜브 영상 · 목차 · 볼 수 있는 반)
--   lec_progress  학생별 진도(본 구간 · 본 시간 · 이어 볼 곳)
--   lec_session   한 번 볼 때마다의 기록(언제 · 몇 분 · 어디부터 어디까지 · 기기)
--   lec_qna       질문과 답
--   lec_key       학생 기기 열쇠(이름 + 등원 번호 4자리로 들어오면 생김 · 열쇠는 sha256 해시(kh)만 저장 ·
--                 열쇠와 번호(pin)가 들어 있어 선생님도 표로는 못 읽음 → lec_keys · lec_link · lec_logout_all 함수로만)
--   lec_fail      틀린 번호 기록(번호 맞히기 막기 · 10분 5번 = 10분 잠금 · 24시간 15번 = 24시간 잠금 ·
--                 선생님이 lec_unlock 으로 풀 수 있음)
--   lec_consent   학생마다 기록 동의(agree · none)와 안내문 판
--   (P1) lec_lecture.files = 강의 필기 PDF 칸 · 파일은 Storage 버킷 lec-pdf(누구나 받기 · 목록 보기 없음 · 선생님만 올림)
--   (N1) lec_push_cfg · lec_push_sub · lec_push_queue · lec_push_log = 새 영상 알림(설정 · 학생 폰 · 보낼 차례 · 보낸 기록 ·
--        표로는 아무도 못 읽음 · 함수로만 · 처음은 꺼짐)
--   (S1) lec_set · lec_set_prog · lec_set_try · lec_set_rec · lec_rec_ok = 단어 · 구문 · 문법 묶음(관리자만 만듦 ·
--        표로는 아무도 못 읽음 · 함수로만 · 구문 녹음은 Storage 버킷 lec-rec 비공개)
-- 학생 구분 = 히즈북스 안의 학생 id + 띄어쓰기 뺀 이름.
--   (같은 id 를 쓰는 다른 학생이 있을 수 있어 id 만으로 구분하지 않습니다)
-- 학생은 로그인 계정이 없어서 표를 직접 못 읽습니다. 아래 lec_ 함수로 자기 것만 읽고 씁니다.
-- 선생님(히즈북스 로그인)은 표를 직접 읽고 씁니다(lec_key 빼고). 선생님인지는 로그인 «이메일»만 보고 정합니다
--   (히즈북스 identityForUser 와 같은 규칙 · @his.kr 계정만 · 본인이 바꿀 수 있는 user_metadata 는 보지 않음).
--   선생님이 아닌 로그인 계정은 강의실 표와 선생님 함수 모두 아무것도 못 합니다.
-- 학생 명단은 히즈북스 클라우드(app_state 의 main 줄 · classes)를 그대로 읽습니다.
-- ============================================================================

create table if not exists public.lec_lecture (
  id          uuid primary key default gen_random_uuid(),
  title       text not null default '',
  book        text not null default '',
  yt          text not null default '',
  dur         integer not null default 0,
  chapters    jsonb not null default '[]'::jsonb,
  class_ids   text[] not null default '{}',
  lesson_on   date,
  posted_on   date not null default ((now() at time zone 'Asia/Seoul')::date),
  hidden      boolean not null default false,
  created_by  text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- 공개 끝 날짜(비면 끝 없음 · 한국 시각 오늘이 이 날을 넘으면 끝난 강의)
alter table public.lec_lecture add column if not exists until date;

create table if not exists public.lec_progress (
  sid         text not null,
  lecture_id  uuid not null references public.lec_lecture(id) on delete cascade,
  sname       text not null default '',
  seen        text not null default '',
  watched     integer not null default 0,
  pos         integer not null default 0,
  pct         integer not null default 0,
  sessions    integer not null default 0,
  first_at    timestamptz,
  last_at     timestamptz,
  done_at     timestamptz,
  primary key (sid, lecture_id)
);
-- 선생님이 확인한 완료(자동 완료 done_at 과 따로 · 출결과는 상관없음)
alter table public.lec_progress add column if not exists done_by    text;
alter table public.lec_progress add column if not exists done_note  text not null default '';
alter table public.lec_progress add column if not exists done_by_at timestamptz;

create table if not exists public.lec_session (
  id          uuid primary key,
  sid         text not null,
  sname       text not null default '',
  lecture_id  uuid not null references public.lec_lecture(id) on delete cascade,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz not null default now(),
  watched     integer not null default 0,
  from_s      integer not null default 0,
  to_s        integer not null default 0,
  dev         text not null default ''
);
-- 그 묶음에서 쓴 가장 빠른 배속(0.25~2)
alter table public.lec_session add column if not exists rate numeric not null default 1;

create table if not exists public.lec_qna (
  id          uuid primary key default gen_random_uuid(),
  lecture_id  uuid not null references public.lec_lecture(id) on delete cascade,
  parent      uuid references public.lec_qna(id) on delete cascade,
  sid         text,
  sname       text,
  teacher     text,
  at_s        integer,
  body        text not null,
  private     boolean not null default false,
  stu_seen    boolean not null default false,
  deleted     boolean not null default false,
  created_at  timestamptz not null default now()
);
-- 질문 종류: content(내용) · tech(영상·진도 문제) · 덧붙인 글은 처음 질문의 종류를 따름
alter table public.lec_qna add column if not exists kind text not null default 'content';

create table if not exists public.lec_key (
  kh          text primary key,
  sid         text not null,
  rid         text not null default '',
  pin         text not null default '',
  sname       text not null default '',
  cls         text[] not null default '{}',
  dev         text not null default '',
  made_by     text not null default '',
  created_at  timestamptz not null default now(),
  last_at     timestamptz not null default now()
);
alter table public.lec_key add column if not exists rid text not null default '';
alter table public.lec_key add column if not exists pin text not null default '';
alter table public.lec_key add column if not exists dev text not null default '';
-- 열쇠는 해시만(kh = sha256 16진 64자). 예전 판(열쇠 그대로 key 칸)이면 해시로 바꾸고 key 칸을 지움
--   (학생 기기에 있는 열쇠는 그대로 쓰임 · 함수가 받은 열쇠를 해시해서 찾음)
alter table public.lec_key add column if not exists kh text;
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'lec_key' and column_name = 'key') then
    execute 'update public.lec_key set kh = encode(sha256(convert_to(key, ''UTF8'')), ''hex'') where kh is null';
    execute 'alter table public.lec_key drop column key';
  end if;
  delete from public.lec_key where kh is null;
  if not exists (select 1 from pg_constraint where conrelid = 'public.lec_key'::regclass and contype = 'p') then
    execute 'alter table public.lec_key add primary key (kh)';
  end if;
end
$$;

create table if not exists public.lec_fail (
  who         text not null,
  at          timestamptz not null default now()
);
-- who = 로그인 대상(k:학생 열쇠 · 이름이 한 학생에게 맞을 때 / n:맞춘 이름 · 아니면)
-- lock = 이 실패로 걸린 잠금('' · 'min' 10분 · 'day' 24시간)
alter table public.lec_fail add column if not exists lock text not null default '';

-- 학생마다 기록 동의 한 줄(choice: agree 기록함 · none 기록 안 함 / ver: 동의한 안내문 판)
create table if not exists public.lec_consent (
  sid         text primary key,
  choice      text not null check (choice in ('agree', 'none')),
  ver         text not null default '',
  at          timestamptz not null default now()
);

create index if not exists lec_progress_lecture on public.lec_progress (lecture_id);
create index if not exists lec_session_sid      on public.lec_session (sid, lecture_id, started_at desc);
create index if not exists lec_session_lecture  on public.lec_session (lecture_id, started_at desc);
create index if not exists lec_qna_lecture      on public.lec_qna (lecture_id, created_at);
create index if not exists lec_qna_parent       on public.lec_qna (parent);
create index if not exists lec_qna_sid          on public.lec_qna (sid, created_at);
create index if not exists lec_key_sid          on public.lec_key (sid);
create index if not exists lec_fail_who         on public.lec_fail (who, at);
create index if not exists lec_fail_at          on public.lec_fail (at);

-- 권한: 선생님(로그인한 사람 중 선생님으로 알아보는 계정 · 아래 lec_staff 정책)만 표를 직접 · 학생(로그인 없음)은 함수로만
revoke all on public.lec_lecture, public.lec_progress, public.lec_session, public.lec_qna, public.lec_key, public.lec_fail, public.lec_consent from anon;
grant select, insert, update, delete on public.lec_lecture, public.lec_progress, public.lec_session, public.lec_qna to authenticated;
revoke all on public.lec_fail from authenticated;
-- 학생 기기 열쇠(해시·번호)는 선생님도 표로 못 읽음 · 기기 목록은 lec_keys 함수로
revoke all on public.lec_key from authenticated;
-- 동의는 선생님이 읽기만(바꾸는 것은 학생 함수 lec_consent · 지우는 것은 lec_forget)
revoke all on public.lec_consent from authenticated;
grant select on public.lec_consent to authenticated;

-- 행 보안 켜기(정책은 선생님 판정 함수 lec__is_staff 를 만든 뒤에 붙임)
do $$
declare t text;
begin
  foreach t in array array['lec_lecture', 'lec_progress', 'lec_session', 'lec_qna', 'lec_key', 'lec_consent', 'lec_fail'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- 작은 도움 함수
-- ---------------------------------------------------------------------------

-- 앞선 판에서 모양이 바뀐 함수는 먼저 지우고 새로 만듭니다
drop function if exists public.lec__or(text, text);
drop function if exists public.lec__roster();
drop function if exists public.lec_login(text, text);
drop function if exists public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text);
drop function if exists public.lec_ask(text, uuid, text, integer, boolean, uuid);

-- 히즈북스 앱(자바스크립트)의 «참» 판단과 같게: true · 0 아닌 수 · 빈칸 아닌 글자 · 객체 · 배열
create or replace function public.lec__truthy(v jsonb) returns boolean
language sql immutable set search_path = public as $$
  select case jsonb_typeof(v)
    when 'boolean' then v = 'true'::jsonb
    when 'number'  then (v #>> '{}')::numeric <> 0
    when 'string'  then (v #>> '{}') <> ''
    when 'object'  then true
    when 'array'   then true
    else false
  end
$$;

-- 띄어쓰기 빼기: 한글 자모를 하나로 모은 뒤(NFC) 보통 칸 · 탭 · 줄바꿈 · 전각 칸 · 안 보이는 칸까지 모두
create or replace function public.lec__nows(t text) returns text
language sql immutable set search_path = public as $$
  select regexp_replace(normalize(coalesce(t, ''), NFC),
                        '[\u0009-\u000d    -​    　﻿]+', '', 'g')
$$;

-- 이름 비교용: 띄어쓰기 빼고 영어 대문자만 소문자로(학생 화면과 같은 규칙)
create or replace function public.lec__norm(t text) returns text
language sql immutable set search_path = public as $$
  select translate(public.lec__nows(t), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')
$$;

-- 다른 학생에게 보이는 이름: 김하늘 → 김○○
create or replace function public.lec__mask(n text) returns text
language sql immutable set search_path = public as $$
  select case when char_length(m) < 2 then '학생'
              else left(m, 1) || repeat('○', char_length(m) - 1) end
  from (select public.lec__nows(n) as m) x
$$;

-- 본 구간 표시(10초 칸마다 0/1) 합치기. 새로 켜지는 칸은 cap 개까지만(앞쪽부터)
-- 실제로 튼 시간보다 많은 칸이 한꺼번에 켜지지 않게(2배속까지는 다 들어감)
create or replace function public.lec__or(a text, b text, cap integer) returns text
language sql immutable set search_path = public as $$
  with g as (
    select s.i,
           substr(coalesce(a, ''), s.i, 1) = '1' as was1,
           (substr(coalesce(b, ''), s.i, 1) = '1' and substr(coalesce(a, ''), s.i, 1) <> '1') as add1
      from generate_series(1, greatest(char_length(coalesce(a, '')), char_length(coalesce(b, '')))) as s(i)
  ), h as (
    select g.i, g.was1, g.add1,
           sum(case when g.add1 then 1 else 0 end) over (order by g.i) as run
      from g
  )
  select coalesce(string_agg(case when h.was1 or (h.add1 and h.run <= greatest(coalesce(cap, 0), 0)) then '1' else '0' end,
                             '' order by h.i), '')
    from h
$$;

-- 진도(%) = 영상 길이 안의 켜진 칸 수 ÷ 전체 칸 수
create or replace function public.lec__pct(seen text, dur integer) returns integer
language sql immutable set search_path = public as $$
  select case when coalesce(dur, 0) <= 0 then 0
              else least(100, round(100.0 *
                     (char_length(left(coalesce(seen, ''), ceil(dur / 10.0)::integer))
                      - char_length(replace(left(coalesce(seen, ''), ceil(dur / 10.0)::integer), '1', '')))
                     / ceil(dur / 10.0)))::integer end
$$;

-- 학생이 이 강의를 볼 수 있나: 숨기지 않았고 · 공개일(탑재일)이 지났고 · 학생이 반에 들어 있고 · 내 반 강의이거나 «전체» 강의
-- (명단에서 빠진 학생은 반이 비어 «전체» 강의도 못 봄 · 공개일을 앞날로 두면 그날 0시(한국 시각)부터 보임 = 예약 공개)
create or replace function public.lec__open(l public.lec_lecture, cls text[]) returns boolean
language sql stable set search_path = public as $$
  select not l.hidden
     and coalesce(l.posted_on, (now() at time zone 'Asia/Seoul')::date) <= (now() at time zone 'Asia/Seoul')::date
     and coalesce(cardinality(cls), 0) > 0
     and ((l.class_ids && cls) or '*' = any (l.class_ids))
$$;

-- 학생 명단(퇴원 · 반배정 대기 빼고): 학생 구분 열쇠 · 학생 id · 이름 · 맞춘 이름 · 번호 뒤 4자리들 · 반 id들
create or replace function public.lec__roster()
returns table (skey text, rid text, sname text, nname text, pins text[], cls text[])
language sql stable security definer set search_path = public as $$
  with st as (
    select s ->> 'id'                                                                                 as rid,
           btrim(s ->> 'name')                                                                        as sname,
           public.lec__norm(s ->> 'name')                                                             as nname,
           right(regexp_replace(coalesce(s #>> '{intake,parentContact}', ''), '[^0-9]', '', 'g'), 4)  as p1,
           right(regexp_replace(coalesce(s #>> '{intake,studentContact}', ''), '[^0-9]', '', 'g'), 4) as p2,
           c ->> 'id'                                                                                 as cid
      from public.app_state a
     cross join lateral jsonb_array_elements(case when jsonb_typeof(a.data -> 'classes') = 'array' then a.data -> 'classes' else '[]'::jsonb end) as c
     cross join lateral jsonb_array_elements(case when jsonb_typeof(c -> 'students') = 'array' then c -> 'students' else '[]'::jsonb end) as s
     where a.id = 'main'
       and jsonb_typeof(s) = 'object'
       and coalesce(s ->> 'id', '') <> ''
       and public.lec__norm(s ->> 'name') <> ''
       and not public.lec__truthy(s -> 'withdrawn')
       and not public.lec__truthy(s -> 'pending')
  )
  select st.rid || '|' || st.nname,
         st.rid,
         max(st.sname collate "C"),
         st.nname,
         coalesce(array_agg(distinct p.pin) filter (where char_length(p.pin) = 4), '{}'),
         coalesce(array_agg(distinct st.cid) filter (where coalesce(st.cid, '') <> ''), '{}')
    from st
   cross join lateral (values (st.p1), (st.p2)) as p(pin)
   group by st.rid, st.nname
$$;

-- 이름이 바뀐 학생의 기록을 새 열쇠로 옮기기(겹치는 강의는 합침)
create or replace function public.lec__move(p_old text, p_new text, p_sname text)
returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if p_old is null or p_new is null or p_old = p_new then
    return;
  end if;
  update public.lec_progress p set
    seen     = public.lec__or(q.seen, p.seen, 2160),
    watched  = p.watched + q.watched,
    sessions = p.sessions + q.sessions,
    pos      = case when coalesce(q.last_at, '-infinity'::timestamptz) > coalesce(p.last_at, '-infinity'::timestamptz)
                    then q.pos else p.pos end,
    first_at = least(p.first_at, q.first_at),
    last_at  = greatest(p.last_at, q.last_at),
    done_at  = least(p.done_at, q.done_at),
    done_by    = coalesce(p.done_by, q.done_by),
    done_note  = case when p.done_by is null then q.done_note else p.done_note end,
    done_by_at = case when p.done_by is null then q.done_by_at else p.done_by_at end
    from public.lec_progress q
   where p.sid = p_new and q.sid = p_old and q.lecture_id = p.lecture_id;
  update public.lec_progress p set sid = p_new
   where p.sid = p_old
     and not exists (select 1 from public.lec_progress x where x.sid = p_new and x.lecture_id = p.lecture_id);
  delete from public.lec_progress where sid = p_old;
  update public.lec_progress p set
    sname   = coalesce(p_sname, p.sname),
    pct     = public.lec__pct(p.seen, l.dur),
    done_at = case when public.lec__pct(p.seen, l.dur) >= 90 then coalesce(p.done_at, now()) else p.done_at end
    from public.lec_lecture l
   where p.sid = p_new and l.id = p.lecture_id;
  update public.lec_session set sid = p_new, sname = coalesce(p_sname, sname) where sid = p_old;
  update public.lec_qna     set sid = p_new, sname = coalesce(p_sname, sname) where sid = p_old;
  update public.lec_key     set sid = p_new, sname = coalesce(p_sname, sname) where sid = p_old;
  -- 동의는 새 열쇠에 이미 있으면 그것을 두고, 없으면 옮김
  update public.lec_consent c set sid = p_new
   where c.sid = p_old
     and not exists (select 1 from public.lec_consent x where x.sid = p_new);
  delete from public.lec_consent where sid = p_old;
  update public.lec_fail set who = 'k:' || p_new where who = 'k:' || p_old;
end
$$;

-- 강의 길이를 고치면 그 강의의 진도(%)를 다시 계산
create or replace function public.lec__dur_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.dur is distinct from old.dur then
    update public.lec_progress p set
      pct     = public.lec__pct(p.seen, new.dur),
      done_at = case when public.lec__pct(p.seen, new.dur) >= 90 then coalesce(p.done_at, now()) else null end
     where p.lecture_id = new.id;
  end if;
  return new;
end
$$;

drop trigger if exists lec_lecture_dur on public.lec_lecture;
create trigger lec_lecture_dur after update of dur on public.lec_lecture
  for each row execute function public.lec__dur_changed();

-- 지금 기록 안내문 판(바뀌면 학생이 다시 동의 화면을 봄 · class-api.js 의 CONSENT_VER 와 같아야 함)
create or replace function public.lec__consent_ver() returns text
language sql immutable set search_path = public as $$
  select 'v1-2026-11'::text
$$;

-- 이 학생이 지금 판에 «기록함»으로 동의했나
create or replace function public.lec__agreed(p_sid text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.lec_consent c
                  where c.sid = p_sid and c.choice = 'agree' and c.ver = public.lec__consent_ver())
$$;

-- 공개 끝 날짜가 지난 강의(한국 시각 오늘 > until)
create or replace function public.lec__ended(l public.lec_lecture) returns boolean
language sql stable set search_path = public as $$
  select l.until is not null and (now() at time zone 'Asia/Seoul')::date > l.until
$$;

-- 지금 부른 선생님(히즈북스 로그인)이 누구인지: 로그인 «이메일»만 봅니다(히즈북스 앱 index.html identityForUser 의 이메일 규칙)
--   아이디@his.kr 만 · benjamin = 관리자 · joey · dana · 원장이 넣은 선생님 목록(teacherAccounts)의 이름 · 그 밖은 아이디
--   앱은 가입 때 적은 이름(user_metadata.name)도 쓰지만, 그 칸은 본인이 언제든 바꿀 수 있어 서버는 보지 않습니다
--   (가입 이름으로만 알아보던 선생님은 여기서 아이디로 불림 → 선생님 목록에 넣으면 그 이름)
-- 로그인 안 한 부름(학생) · 다른 주소(@his.kr 아님) 계정은 빈 결과 = 선생님 아님
create or replace function public.lec__staff()
returns table (name text, admin boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  v_claims jsonb;
  v_email  text;
  v_at     integer;
  v_uname  text;
  v_ta     jsonb;
  v_t      jsonb;
begin
  begin
    v_claims := coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
  exception when others then
    v_claims := '{}'::jsonb;
  end;
  if coalesce(v_claims ->> 'role', '') <> 'authenticated' then
    return;
  end if;
  v_email := lower(btrim(coalesce(v_claims ->> 'email', ''), ' ' || chr(9) || chr(10) || chr(11) || chr(12) || chr(13)));
  v_at := position('@' in v_email);
  if v_at < 1 or substr(v_email, v_at) <> '@his.kr' then
    return;
  end if;
  v_uname := substr(v_email, 1, v_at - 1);
  if v_uname = 'benjamin' then name := 'Benjamin'; admin := true;  return next; return; end if;
  if v_uname = 'joey'     then name := 'Joey';     admin := false; return next; return; end if;
  if v_uname = 'dana'     then name := 'Dana';     admin := false; return next; return; end if;
  v_ta := coalesce((select a.data -> 'teacherAccounts' from public.app_state a where a.id = 'pt-etc'),
                   (select a.data -> 'teacherAccounts' from public.app_state a where a.id = 'main'));
  if v_ta is null or jsonb_typeof(v_ta) <> 'object' then v_ta := '{}'::jsonb; end if;
  v_t := v_ta -> v_uname;
  if jsonb_typeof(v_t) = 'object' and not public.lec__truthy(v_t -> 'del') and public.lec__truthy(v_t -> 'name') then
    name := v_t ->> 'name'; admin := false; return next; return;
  end if;
  name := v_uname; admin := false; return next;
end
$$;

-- 지금 부른 사람이 선생님인가(표 정책에서 씀 · 학생·선생님 아닌 계정 = false)
create or replace function public.lec__is_staff()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.lec__staff())
$$;

-- 학생 기기 열쇠의 해시(표에는 이것만 저장 · 받은 열쇠를 이걸로 바꿔 찾음)
create or replace function public.lec__kh(p text)
returns text
language sql immutable set search_path = public as $$
  select encode(sha256(convert_to(p, 'UTF8')), 'hex')
$$;

-- 표 정책: 선생님으로 알아보는 계정만 읽고 씀(반 범위는 화면에서) · lec_key 는 정책 없음 = 표로는 아무도 못 읽음
do $$
declare t text;
begin
  foreach t in array array['lec_lecture', 'lec_progress', 'lec_session', 'lec_qna', 'lec_consent'] loop
    execute format('drop policy if exists lec_staff on public.%I', t);
    execute format('create policy lec_staff on public.%I for all to authenticated '
                   || 'using ((select public.lec__is_staff())) with check ((select public.lec__is_staff()))', t);
  end loop;
  drop policy if exists lec_staff on public.lec_key;
end
$$;

-- 히즈북스 반 목록(반 id · 반 이름 · 담당 선생님 · 앞뒤 칸 뺌)
create or replace function public.lec__classes()
returns table (id text, name text, owner text)
language sql stable security definer set search_path = public as $$
  select c ->> 'id',
         coalesce(c ->> 'name', ''),
         btrim(coalesce(c ->> 'owner', ''), ' ' || chr(9) || chr(10) || chr(11) || chr(12) || chr(13))
    from public.app_state a
   cross join lateral jsonb_array_elements(case when jsonb_typeof(a.data -> 'classes') = 'array' then a.data -> 'classes' else '[]'::jsonb end) as c
   where a.id = 'main'
     and jsonb_typeof(c) = 'object'
     and coalesce(c ->> 'id', '') <> ''
$$;

-- 이 선생님이 이 학생의 이 강의 기록을 다룰 수 있나: 관리자는 모두 ·
-- 선생님은 그 학생이 내 반에 있고 그 반이 이 강의를 보는 반(또는 «전체» 강의)일 때
create or replace function public.lec__can(l public.lec_lecture, p_skey text, p_name text, p_admin boolean)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(p_admin, false) or exists (
    select 1
      from public.lec__roster() r
     cross join lateral unnest(r.cls) as c(cid)
      join public.lec__classes() k on k.id = c.cid
     where r.skey = p_skey and k.owner = p_name
       and (c.cid = any (l.class_ids) or '*' = any (l.class_ids)))
$$;

-- ---------------------------------------------------------------------------
-- 학생 화면이 부르는 함수
-- ---------------------------------------------------------------------------

-- 들어가기: 이름 + 등원 번호 4자리(보호자 또는 학생 휴대폰 뒤 4자리 · 등하원 키오스크와 같음)
-- 잠금은 «로그인 대상»마다 셈: 친 이름(띄어쓰기 빼고 영어 소문자)이 명단의 한 학생에게만 맞으면 그 학생 열쇠(k:),
-- 아니면 친 이름 그대로(n:). 10분 안에 5번 틀리면 10분 · 24시간 안에 15번 틀리면 마지막 시도부터 24시간.
-- 잠긴 동안은 번호를 확인하지 않음 · 맞으면 그 대상의 실패 기록을 지움 · 하루 지난 실패 기록은 부를 때마다 정리
create or replace function public.lec_login(p_name text, p_pin text, p_dev text default '')
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text := public.lec__norm(p_name);
  v_pin   text := regexp_replace(coalesce(p_pin, ''), '[^0-9]', '', 'g');
  v_who   text;
  v_one   text;
  v_cnt   integer;
  v_at    timestamptz;
  v_f10   integer;
  v_f24   integer;
  v_lock  text;
  v_n     integer := 0;
  v_skey  text;
  v_rid   text;
  v_sname text;
  v_cls   text[];
  v_key   text;
  r       record;
begin
  if char_length(v_name) < 1 or char_length(v_name) > 40 or char_length(v_pin) <> 4 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  delete from public.lec_fail where at < now() - interval '1 day';
  delete from public.lec_key where made_by = '' and last_at < now() - interval '365 days';
  select count(*), min(t.skey) into v_cnt, v_one from public.lec__roster() t where t.nname = v_name;
  v_who := case when v_cnt = 1 then 'k:' || v_one else 'n:' || v_name end;
  perform pg_advisory_xact_lock(hashtext('lec_fail|' || v_who));
  select max(at) into v_at from public.lec_fail
   where who = v_who and lock = 'day' and at > now() - interval '24 hours';
  if v_at is not null then
    return jsonb_build_object('ok', false, 'err', 'locked', 'day', true,
      'secs', greatest(1, ceil(extract(epoch from (v_at + interval '24 hours' - now()))))::integer);
  end if;
  select max(at) into v_at from public.lec_fail
   where who = v_who and lock in ('min', 'day') and at > now() - interval '10 minutes';
  if v_at is not null then
    return jsonb_build_object('ok', false, 'err', 'locked', 'day', false,
      'secs', greatest(1, ceil(extract(epoch from (v_at + interval '10 minutes' - now()))))::integer);
  end if;
  for r in
    select t.skey, t.rid, t.sname, t.cls from public.lec__roster() t
     where t.nname = v_name and v_pin = any (t.pins)
  loop
    v_n := v_n + 1; v_skey := r.skey; v_rid := r.rid; v_sname := r.sname; v_cls := r.cls;
  end loop;
  if v_n = 0 then
    select count(*) filter (where at > now() - interval '10 minutes'), count(*) filter (where at > now() - interval '24 hours')
      into v_f10, v_f24
      from public.lec_fail where who = v_who;
    v_lock := case when v_f24 + 1 >= 15 then 'day' when v_f10 + 1 >= 5 then 'min' else '' end;
    insert into public.lec_fail (who, lock) values (v_who, v_lock);
    if v_lock = 'day' then
      return jsonb_build_object('ok', false, 'err', 'locked', 'day', true, 'secs', 86400);
    elsif v_lock = 'min' then
      return jsonb_build_object('ok', false, 'err', 'locked', 'day', false, 'secs', 600);
    end if;
    return jsonb_build_object('ok', false, 'err', 'nomatch');
  elsif v_n > 1 then
    return jsonb_build_object('ok', false, 'err', 'many');
  end if;
  delete from public.lec_fail where who in (v_who, 'k:' || v_skey);
  v_key := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  -- 표에는 해시만 · 열쇠 그대로는 이 기기에 한 번 돌려줄 뿐
  insert into public.lec_key (kh, sid, rid, pin, sname, cls, dev)
  values (public.lec__kh(v_key), v_skey, v_rid, v_pin, v_sname, coalesce(v_cls, '{}'), left(coalesce(p_dev, ''), 40));
  return jsonb_build_object('ok', true, 'key', v_key, 'name', v_sname);
end
$$;

-- 강의 목록(내 반 강의 + 내 진도 + 새 답변 수)
-- 학원 명단에서 이름이 바뀌었으면: 같은 id · 같은 등원 번호인 학생이 딱 한 명일 때만 기록을 옮겨 이어 줌
create or replace function public.lec_home(p_key text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k        public.lec_key;
  x        record;
  v_hit    boolean := false;
  v_sname  text;
  v_cls    text[];
  v_same   integer := 0;
  v_cskey  text;
  v_csname text;
  v_cpins  text[];
  v_ccls   text[];
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  for x in
    select t.skey, t.sname, t.pins, t.cls from public.lec__roster() t
     where t.skey = k.sid or (k.rid <> '' and t.rid = k.rid)
  loop
    if x.skey = k.sid then
      v_hit := true; v_sname := x.sname; v_cls := x.cls;
    else
      v_same := v_same + 1; v_cskey := x.skey; v_csname := x.sname; v_cpins := x.pins; v_ccls := x.cls;
    end if;
  end loop;
  if not v_hit and v_same = 1 then
    if k.pin <> '' and k.pin = any (coalesce(v_cpins, '{}')) then
      perform pg_advisory_xact_lock(hashtext('lec_move|' || k.sid));
      perform public.lec__move(k.sid, v_cskey, v_csname);
      v_hit := true; v_sname := v_csname; v_cls := v_ccls;
      select * into k from public.lec_key where kh = k.kh;
    end if;
  end if;
  if not v_hit then
    update public.lec_key set cls = '{}', last_at = now() where kh = k.kh;
    return jsonb_build_object('ok', false, 'err', 'gone');
  end if;
  update public.lec_key set sname = v_sname, cls = coalesce(v_cls, '{}'), last_at = now() where kh = k.kh;
  return jsonb_build_object(
    'ok', true,
    'me', jsonb_build_object('name', v_sname),
    'consent', (select jsonb_build_object('choice', c.choice, 'ver', c.ver, 'at', c.at)
                  from public.lec_consent c where c.sid = k.sid),
    'consent_ver', public.lec__consent_ver(),
    'lectures', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'title', l.title, 'book', l.book, 'yt', l.yt, 'dur', l.dur,
               'chapters', l.chapters, 'lesson_on', l.lesson_on, 'posted_on', l.posted_on,
               'until', l.until, 'ended', public.lec__ended(l),
               'pct', coalesce(p.pct, 0), 'pos', coalesce(p.pos, 0), 'watched', coalesce(p.watched, 0),
               'seen', coalesce(p.seen, ''), 'first_at', p.first_at, 'last_at', p.last_at, 'done_at', p.done_at,
               'confirmed', coalesce(p.done_by is not null, false),
               'ans_new', (select count(*) from public.lec_qna a join public.lec_qna q on q.id = a.parent
                            where a.lecture_id = l.id and q.sid = k.sid and a.teacher is not null
                              and not a.stu_seen and not a.deleted and not q.deleted)
             ) order by coalesce(l.lesson_on, l.posted_on), l.created_at)
        from public.lec_lecture l
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       where public.lec__open(l, v_cls)
    ), '[]'::jsonb));
end
$$;

-- 기록 동의 고르기(agree 기록함 · none 기록 안 함). 판(p_ver)이 지금 판이 아니면 'ver' + 지금 판
create or replace function public.lec_consent(p_key text, p_choice text, p_ver text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k public.lec_key;
  c public.lec_consent;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  if coalesce(p_choice, '') not in ('agree', 'none') then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  if p_ver is distinct from public.lec__consent_ver() then
    return jsonb_build_object('ok', false, 'err', 'ver', 'ver', public.lec__consent_ver());
  end if;
  insert into public.lec_consent (sid, choice, ver, at) values (k.sid, p_choice, p_ver, now())
  on conflict (sid) do update set choice = excluded.choice, ver = excluded.ver, at = excluded.at
  returning * into c;
  return jsonb_build_object('ok', true, 'choice', c.choice, 'ver', c.ver, 'at', c.at);
end
$$;

-- 보는 중 기록(1분마다 · 멈출 때 · 닫을 때). p_total = 이번 보기에서 실제로 튼 누적 초(같은 값을 다시 보내도 두 번 세지 않음)
-- p_rate = 지금 배속(0.25~2 로 자름 · 없으면 1). 인정 초 상한 = 경과 × 배속(이번 보기에서 가장 빠른 배속 · 1 아래는 1) + 30,
-- 새로 켜지는 칸 상한은 배속과 상관없이 벽시계 2배 그대로(1배일 때는 지난 결과와 같음)
-- 기록에 동의(지금 판 · agree)하지 않았으면 아무것도 쓰지 않고 'no_consent' · 공개 끝 날짜가 지난 강의는 'ended'
create or replace function public.lec_beat(
  p_key text, p_lecture uuid, p_session uuid, p_seen text,
  p_total integer, p_pos integer, p_from integer, p_to integer, p_dur integer, p_dev text,
  p_rate numeric default 1)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k         public.lec_key;
  l         public.lec_lecture;
  s         public.lec_session;
  v_rate    numeric := least(2, greatest(0.25, coalesce(p_rate, 1)));
  v_dur     integer;
  v_n       integer;
  v_in      text;
  v_old     text;
  v_seen    text;
  v_rows    integer;
  v_new     boolean;
  v_cap     integer;
  v_capw    integer;
  v_r       numeric;
  v_delta   integer;
  v_pct     integer;
  v_pos     integer;
  v_watched integer;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  select * into l from public.lec_lecture x
   where x.id = p_lecture and public.lec__open(x, k.cls);
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;
  if public.lec__ended(l) then return jsonb_build_object('ok', false, 'err', 'ended'); end if;
  if not public.lec__agreed(k.sid) then return jsonb_build_object('ok', false, 'err', 'no_consent'); end if;
  if p_session is null then return jsonb_build_object('ok', false, 'err', 'input'); end if;

  v_dur := coalesce(l.dur, 0);
  if v_dur <= 0 and coalesce(p_dur, 0) between 30 and 21600 then
    update public.lec_lecture set dur = p_dur where id = l.id and dur <= 0;
    v_dur := p_dur;
  end if;
  v_n  := case when v_dur > 0 then ceil(v_dur / 10.0)::integer else 0 end;
  v_in := case when coalesce(p_seen, '') ~ '^[01]*$' and char_length(coalesce(p_seen, '')) <= 2160 then coalesce(p_seen, '') else '' end;

  -- 한 번 보기(세션)
  insert into public.lec_session (id, sid, sname, lecture_id, from_s, to_s, dev, rate)
  values (p_session, k.sid, k.sname, l.id,
          greatest(coalesce(p_from, 0), 0), greatest(coalesce(p_from, 0), 0), left(coalesce(p_dev, ''), 40), v_rate)
  on conflict (id) do nothing;
  get diagnostics v_rows = row_count;
  v_new := v_rows > 0;
  select * into s from public.lec_session where id = p_session for update;
  if s.sid <> k.sid or s.lecture_id <> l.id then
    return jsonb_build_object('ok', false, 'err', 'session');
  end if;
  v_r     := greatest(1, coalesce(s.rate, 1), v_rate);
  v_capw  := case when v_new then 150 else greatest(90, (extract(epoch from (now() - s.ended_at)))::integer + 30) end;
  v_cap   := case when v_new then (120 * v_r)::integer + 30
                  else greatest(90, (extract(epoch from (now() - s.ended_at)) * v_r)::integer + 30) end;
  v_delta := least(greatest(coalesce(p_total, 0) - s.watched, 0), v_cap);
  update public.lec_session set
    started_at = case when v_new then now() - make_interval(secs => v_delta) else started_at end,
    ended_at   = now(),
    watched    = s.watched + v_delta,
    from_s     = least(s.from_s, greatest(coalesce(p_from, s.from_s), 0)),
    to_s       = greatest(s.to_s, least(coalesce(p_to, 0), 21600)),
    rate       = greatest(s.rate, v_rate)
  where id = p_session;

  -- 진도: 이번에 새로 켜지는 칸은 벽시계로 실제로 튼 시간만큼만(2배속 기준 + 가장자리 2칸)
  insert into public.lec_progress (sid, lecture_id, sname, first_at, last_at)
  values (k.sid, l.id, k.sname, now(), now())
  on conflict (sid, lecture_id) do nothing;
  select seen into v_old from public.lec_progress where sid = k.sid and lecture_id = l.id for update;
  v_seen := public.lec__or(v_old, v_in, ceil(least(v_delta, v_capw) / 5.0)::integer + 2);
  if v_n > 0 then v_seen := left(v_seen, v_n); end if;
  v_pct := public.lec__pct(v_seen, v_dur);
  v_pos := greatest(0, least(coalesce(p_pos, 0), case when v_dur > 0 then v_dur else 21600 end));
  update public.lec_progress set
    sname    = k.sname,
    seen     = v_seen,
    watched  = watched + v_delta,
    pos      = v_pos,
    pct      = v_pct,
    sessions = sessions + (case when v_new then 1 else 0 end),
    last_at  = now(),
    done_at  = coalesce(done_at, case when v_pct >= 90 then now() end)
  where sid = k.sid and lecture_id = l.id
  returning watched into v_watched;

  return jsonb_build_object('ok', true, 'pct', v_pct, 'watched', v_watched, 'done', v_pct >= 90, 'dur', v_dur, 'seen', v_seen);
end
$$;

-- 질문 목록(다른 학생 이름은 김○○ · «선생님만 보기»는 쓴 학생과 선생님만). 읽으면 내 질문의 새 답변을 읽음으로
create or replace function public.lec_qna_list(p_key text, p_lecture uuid)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k        public.lec_key;
  l        public.lec_lecture;
  v_unread uuid[];
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  select * into l from public.lec_lecture x
   where x.id = p_lecture and public.lec__open(x, k.cls);
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;

  -- 이번에 처음 읽는 답이 달린 내 질문(unread): 읽음 표시 전에 모아 둠
  with u as (
    update public.lec_qna a set stu_seen = true
      from public.lec_qna q
     where a.parent = q.id and q.sid = k.sid and a.lecture_id = l.id
       and a.teacher is not null and not a.stu_seen
    returning a.parent, a.deleted)
  select coalesce(array_agg(distinct u.parent) filter (where not u.deleted), '{}') into v_unread from u;

  -- answered: 처음 질문은 지우지 않은 선생님 답이 하나라도 있으면 · 덧붙인 글은 그 뒤에 선생님 답이 달렸으면
  return jsonb_build_object('ok', true, 'items', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', x.id, 'parent', x.parent, 'at_s', x.at_s, 'body', x.body,
             'private', coalesce(q.private, x.private),
             'kind', coalesce(q.kind, x.kind),
             'created_at', x.created_at,
             'mine', coalesce(x.sid = k.sid, false),
             'teacher', x.teacher is not null,
             'who', case when x.teacher is not null then x.teacher
                         when x.sid = k.sid then '나'
                         else public.lec__mask(x.sname) end,
             'answered', case when x.teacher is not null then false
                              when x.parent is null then exists (
                                select 1 from public.lec_qna t
                                 where t.parent = x.id and t.teacher is not null and not t.deleted)
                              else exists (
                                select 1 from public.lec_qna t
                                 where t.parent = x.parent and t.teacher is not null and not t.deleted
                                   and t.created_at > x.created_at) end,
             'unread', x.parent is null and x.id = any (v_unread)
           ) order by x.created_at)
      from public.lec_qna x
      left join public.lec_qna q on q.id = x.parent
     where x.lecture_id = l.id and not x.deleted
       and (q.id is null or not q.deleted)
       and (case when x.parent is null then (not x.private or x.sid = k.sid)
                 else (not q.private or q.sid = k.sid) end)
  ), '[]'::jsonb));
end
$$;

-- 질문 올리기(내 질문 아래 덧붙이기는 p_parent). 한 시간에 20개까지
-- p_kind = content(내용 · 기본) · tech(영상·진도 문제). 덧붙인 글은 처음 질문의 종류를 따름
-- 질문도 기록이라 기록에 동의(지금 판 · agree)했을 때만 · 공개 끝 날짜가 지난 강의는 'ended'
create or replace function public.lec_ask(
  p_key text, p_lecture uuid, p_body text, p_at integer, p_private boolean, p_parent uuid,
  p_kind text default 'content')
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  l      public.lec_lecture;
  q      public.lec_qna;
  v_body text := btrim(coalesce(p_body, ''));
  v_kind text := coalesce(p_kind, 'content');
  v_cnt  integer;
  v_id   uuid;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  select * into l from public.lec_lecture x
   where x.id = p_lecture and public.lec__open(x, k.cls);
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;
  if public.lec__ended(l) then return jsonb_build_object('ok', false, 'err', 'ended'); end if;
  if not public.lec__agreed(k.sid) then return jsonb_build_object('ok', false, 'err', 'no_consent'); end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 or v_kind not in ('content', 'tech') then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  select count(*) into v_cnt from public.lec_qna where sid = k.sid and created_at > now() - interval '1 hour';
  if v_cnt >= 20 then return jsonb_build_object('ok', false, 'err', 'many'); end if;
  if p_parent is not null then
    select * into q from public.lec_qna where id = p_parent and lecture_id = l.id and parent is null and not deleted;
    if not found or q.sid is distinct from k.sid then
      return jsonb_build_object('ok', false, 'err', 'parent');
    end if;
  end if;
  insert into public.lec_qna (lecture_id, parent, sid, sname, at_s, body, private, kind)
  values (l.id, p_parent, k.sid, k.sname,
          case when p_parent is null and p_at between 0 and 21600 then p_at end,
          v_body,
          case when p_parent is null then coalesce(p_private, false) else coalesce(q.private, false) end,
          case when p_parent is null then v_kind else coalesce(q.kind, 'content') end)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end
$$;

-- 내 글 지우기(선생님 답이 달린 글은 'answered' · 지우지 않음 · 답이 달렸는지는 질문 목록의 answered 와 같은 규칙)
create or replace function public.lec_qdel(p_key text, p_id uuid)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k public.lec_key;
  x public.lec_qna;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  select * into x from public.lec_qna where id = p_id and sid = k.sid and not deleted for update;
  if not found then return jsonb_build_object('ok', false, 'err', 'none'); end if;
  if (x.parent is null and exists (
        select 1 from public.lec_qna t where t.parent = x.id and t.teacher is not null and not t.deleted))
     or (x.parent is not null and exists (
        select 1 from public.lec_qna t where t.parent = x.parent and t.teacher is not null and not t.deleted
                                       and t.created_at > x.created_at)) then
    return jsonb_build_object('ok', false, 'err', 'answered');
  end if;
  update public.lec_qna set deleted = true where id = x.id;
  return jsonb_build_object('ok', true);
end
$$;

-- 나가기(스스로 들어온 열쇠만 지움 · 선생님이 만든 개인 링크는 그대로)
create or replace function public.lec_logout(p_key text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  delete from public.lec_key where kh = public.lec__kh(p_key) and made_by = '';
  return jsonb_build_object('ok', true);
end
$$;

-- ---------------------------------------------------------------------------
-- 선생님 화면이 부르는 함수(히즈북스 로그인한 선생님만 · 아니면 'forbidden')
-- ---------------------------------------------------------------------------

-- 선생님이 확인한 완료(예: 교실에서 워크북 확인). 진도 줄이 없으면 0% 줄을 만들고 확인만 찍음.
-- 자동 완료(done_at)와 출결은 건드리지 않음 · 메모는 60자까지
create or replace function public.lec_confirm(p_lecture uuid, p_skey text, p_note text default '')
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  l       public.lec_lecture;
  p       public.lec_progress;
  v_note  text := left(btrim(coalesce(p_note, '')), 60);
  v_sname text;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  select * into l from public.lec_lecture where id = p_lecture;
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;
  if coalesce(btrim(p_skey), '') = '' then return jsonb_build_object('ok', false, 'err', 'input'); end if;
  if not public.lec__can(l, p_skey, v_name, v_admin) then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select r.sname into v_sname from public.lec__roster() r where r.skey = p_skey;
  insert into public.lec_progress (sid, lecture_id, sname)
  values (p_skey, l.id, coalesce(v_sname, substring(p_skey from '[^|]*$')))
  on conflict (sid, lecture_id) do nothing;
  update public.lec_progress set done_by = v_name, done_note = v_note, done_by_at = now()
   where sid = p_skey and lecture_id = l.id
  returning * into p;
  return jsonb_build_object('ok', true, 'done_by', p.done_by, 'done_note', p.done_note, 'done_by_at', p.done_by_at);
end
$$;

-- 선생님 확인 되돌리기(확인 때 만든 빈 0% 줄은 지움)
create or replace function public.lec_unconfirm(p_lecture uuid, p_skey text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  l       public.lec_lecture;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  select * into l from public.lec_lecture where id = p_lecture;
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;
  if coalesce(btrim(p_skey), '') = '' then return jsonb_build_object('ok', false, 'err', 'input'); end if;
  if not public.lec__can(l, p_skey, v_name, v_admin) then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  update public.lec_progress set done_by = null, done_note = '', done_by_at = null
   where sid = p_skey and lecture_id = l.id;
  delete from public.lec_progress
   where sid = p_skey and lecture_id = l.id and done_by is null
     and sessions = 0 and watched = 0 and position('1' in seen) = 0;
  return jsonb_build_object('ok', true);
end
$$;

-- 한 학생의 강의실 기록 모두 지우기(관리자만): 진도 · 본 칸 · 시청 묶음 · 동의 · 질문(달린 답 포함) · 로그인 실패.
-- 학원 명단에서 빠진 학생이면 기기 열쇠도 지움(재원생은 열쇠를 두고, 동의가 지워져 다음에 동의 화면부터)
-- 돌려주는 수: progress = 진도 줄 · questions = 그 학생이 쓴 처음 질문(덧붙인 글 빼고 · 지운 것 포함)
create or replace function public.lec_forget(p_skey text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  v_n     integer;
  v_m     integer;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null or not v_admin then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if coalesce(btrim(p_skey), '') = '' then return jsonb_build_object('ok', false, 'err', 'input'); end if;
  perform pg_advisory_xact_lock(hashtext('lec_move|' || p_skey));
  with d as (delete from public.lec_progress where sid = p_skey returning 1)
  select count(*) into v_n from d;
  delete from public.lec_session where sid = p_skey;
  delete from public.lec_consent where sid = p_skey;
  select count(*) into v_m from public.lec_qna where sid = p_skey and parent is null;
  delete from public.lec_qna where sid = p_skey;
  delete from public.lec_fail where who = 'k:' || p_skey;
  if not exists (select 1 from public.lec__roster() r where r.skey = p_skey) then
    delete from public.lec_key where sid = p_skey;
  end if;
  return jsonb_build_object('ok', true, 'progress', v_n, 'questions', v_m);
end
$$;

-- 잠금 풀기: 그 학생의 로그인 실패 기록(k:학생키 · n:그 학생 이름)을 지우고 지운 수를 돌려줌.
-- 범위는 강의 목록과 같은 규칙(관리자 = 모두 · 선생님 = 내 반 학생, 아니면 'forbidden').
-- 이름은 명단의 맞춘 이름 · 명단에 없으면 학생키의 마지막 | 뒤
create or replace function public.lec_unlock(p_skey text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  v_nn    text;
  v_n     integer;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if coalesce(btrim(p_skey), '') = '' then return jsonb_build_object('ok', false, 'err', 'input'); end if;
  if not v_admin and not exists (
       select 1
         from public.lec__roster() r
        cross join lateral unnest(r.cls) as c(cid)
         join public.lec__classes() k on k.id = c.cid
        where r.skey = p_skey and k.owner = v_name) then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select r.nname into v_nn from public.lec__roster() r where r.skey = p_skey limit 1;
  v_nn := coalesce(v_nn, substring(p_skey from '[^|]*$'), '');
  perform pg_advisory_xact_lock(hashtext('lec_fail|k:' || p_skey));
  if v_nn <> '' then perform pg_advisory_xact_lock(hashtext('lec_fail|n:' || v_nn)); end if;
  with d as (delete from public.lec_fail where who = 'k:' || p_skey or (v_nn <> '' and who = 'n:' || v_nn) returning 1)
  select count(*) into v_n from d;
  return jsonb_build_object('ok', true, 'cleared', v_n);
end
$$;

-- 학생 기기 목록(선생님만 · 열쇠·해시·번호는 빼고). 반 범위는 화면에서 거름
create or replace function public.lec_keys()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  return jsonb_build_object('ok', true, 'items', coalesce((
    select jsonb_agg(jsonb_build_object(
             'sid', k.sid, 'rid', k.rid, 'sname', k.sname, 'cls', to_jsonb(k.cls), 'dev', k.dev,
             'made_by', k.made_by, 'created_at', k.created_at, 'last_at', k.last_at)
           order by k.sid collate "C", k.created_at, k.kh collate "C")
      from public.lec_key k), '[]'::jsonb));
end
$$;

-- 개인 링크 만들기(선생님만): 학원 명단의 그 학생 열쇠를 하나 새로 만들어 열쇠를 한 번 돌려줌(표에는 해시만)
-- 명단에 없는 학생이면 'nomatch' · 번호는 비워 둠(이름이 바뀌면 이어 주지 않음)
create or replace function public.lec_link(p_skey text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  r       record;
  v_key   text;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if coalesce(btrim(p_skey), '') = '' then return jsonb_build_object('ok', false, 'err', 'input'); end if;
  select t.skey, t.rid, t.sname, t.cls into r from public.lec__roster() t where t.skey = p_skey limit 1;
  if not found then return jsonb_build_object('ok', false, 'err', 'nomatch'); end if;
  v_key := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.lec_key (kh, sid, rid, pin, sname, cls, dev, made_by)
  values (public.lec__kh(v_key), r.skey, r.rid, '', r.sname, coalesce(r.cls, '{}'), '개인 링크', v_name);
  return jsonb_build_object('ok', true, 'key', v_key);
end
$$;

-- 그 학생의 모든 기기에서 로그아웃(선생님만 · 개인 링크도 지움) · 지운 열쇠 수를 돌려줌
create or replace function public.lec_logout_all(p_skey text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  v_n     integer;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if coalesce(btrim(p_skey), '') = '' then return jsonb_build_object('ok', false, 'err', 'input'); end if;
  with d as (delete from public.lec_key where sid = p_skey returning 1)
  select count(*) into v_n from d;
  return jsonb_build_object('ok', true, 'n', v_n);
end
$$;

-- 선생님 첫 화면 «할 일» 띠. 범위는 강의 목록과 같은 규칙(관리자 = 모두 · 선생님 = 내 반 학생)
--   waiting : 답을 기다리는 질문(지우지 않은 학생 질문 중, 그 묶음의 마지막 학생 글 뒤에 선생님 답이 없는 것) 수 + 최근 20개
--   behind  : 수업한 날(없으면 올린 날)이 오늘까지 14일 안인 강의(숨김 · 공개 전 · 공개 끝 빼고)마다, 그 강의를 보는 반의
--             재원생 중 90% 미만이고 선생님 확인도 없는 학생(기록 안 함 none 은 셈하지 않음)
--   left    : (관리자만) 강의실 기록이 남았는데 학원 명단에서 빠졌거나 퇴원한 학생. 같은 학생 id 가 명단에 남아 있으면
--             (이름만 바뀌어 아직 옮겨지지 않았을 수 있어) 넣지 않음
--   locked  : 지금 로그인이 잠긴 학생 {skey, sname, cls(반 id들), cnames(반 이름들), secs(남은 초), day(하루 잠금인지)}.
--             잠금 대상은 로그인과 같게 셈(맞춘 이름이 명단에 한 명뿐이면 k:학생키, 아니면 n:이름 · n: 잠금은
--             그 이름의 범위 안 학생으로 보임). 이름 → 학생키 순
create or replace function public.lec_todo()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_name   text;
  v_admin  boolean;
  v_today  date := (now() at time zone 'Asia/Seoul')::date;
  v_n      integer;
  v_wait   jsonb;
  v_behind jsonb;
  v_left   jsonb := '[]'::jsonb;
  v_locked jsonb;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;

  with ro as (select r.skey, r.cls from public.lec__roster() r),
       mycls as (select k.id from public.lec__classes() k where k.owner = v_name),
       th as (
         select q.id, q.lecture_id, q.sid, q.sname, q.kind, q.body, q.created_at,
                (select max(x.created_at) from public.lec_qna x
                  where (x.id = q.id or x.parent = q.id) and x.teacher is null and not x.deleted) as stu_at,
                (select max(x.created_at) from public.lec_qna x
                  where x.parent = q.id and x.teacher is not null and not x.deleted) as tch_at
           from public.lec_qna q
          where q.parent is null and q.teacher is null and not q.deleted),
       w as (
         select th.*, l.title
           from th join public.lec_lecture l on l.id = th.lecture_id
          where (th.tch_at is null or th.tch_at < th.stu_at)
            and (v_admin or exists (
                  select 1 from ro r cross join lateral unnest(r.cls) as c(cid)
                   where r.skey = th.sid and c.cid in (select id from mycls)
                     and (c.cid = any (l.class_ids) or '*' = any (l.class_ids)))))
  select count(*)::integer,
         coalesce((select jsonb_agg(jsonb_build_object(
                            'id', w2.id, 'lecture', w2.lecture_id, 'title', w2.title, 'sid', w2.sid, 'sname', w2.sname,
                            'kind', w2.kind, 'body', w2.body, 'created_at', w2.created_at, 'at', w2.stu_at)
                          order by w2.stu_at desc, w2.id)
                     from (select * from w order by w.stu_at desc, w.id limit 20) w2), '[]'::jsonb)
    into v_n, v_wait
    from w;

  with ro as (select r.skey, r.sname, r.cls from public.lec__roster() r),
       cl as (select k.id, k.name from public.lec__classes() k where v_admin or k.owner = v_name),
       lec as (select l.id, l.title, l.class_ids, l.created_at, coalesce(l.lesson_on, l.posted_on) as day
                 from public.lec_lecture l
                where not l.hidden
                  and coalesce(l.posted_on, v_today) <= v_today
                  and not public.lec__ended(l)
                  and coalesce(l.lesson_on, l.posted_on) between v_today - 13 and v_today),
       pr as (select lec.id as lid, lec.title, lec.day, lec.created_at as lca, cl.id as cid, cl.name as cname
                from lec join cl on (cl.id = any (lec.class_ids) or '*' = any (lec.class_ids))),
       st as (select pr.lid, pr.cid, r.skey, r.sname
                from pr join ro r on pr.cid = any (r.cls)
                left join public.lec_progress g on g.sid = r.skey and g.lecture_id = pr.lid
                left join public.lec_consent cs on cs.sid = r.skey
               where coalesce(g.pct, 0) < 90 and g.done_by is null
                 and coalesce(cs.choice, '') <> 'none')
  select coalesce(jsonb_agg(jsonb_build_object(
                    'cls', pr.cid, 'cname', pr.cname, 'lecture', pr.lid, 'title', pr.title, 'day', pr.day,
                    'n', x.n, 'names', x.names)
                  order by pr.day desc, pr.lca desc, pr.cname collate "C", pr.cid collate "C", pr.lid), '[]'::jsonb)
    into v_behind
    from pr
   cross join lateral (
     select count(*)::integer as n,
            coalesce(jsonb_agg(s.sname order by s.sname collate "C", s.skey collate "C"), '[]'::jsonb) as names
       from st s where s.lid = pr.lid and s.cid = pr.cid) x
   where x.n > 0;

  if v_admin then
    with ro as (select r.skey, r.rid from public.lec__roster() r),
         rec as (
           select g.sid, g.sname, g.last_at as at from public.lec_progress g
           union all select s.sid, s.sname, s.ended_at from public.lec_session s
           union all select q.sid, q.sname, q.created_at from public.lec_qna q where q.sid is not null
           union all select c.sid, null, c.at from public.lec_consent c),
         who as (select rec.sid, max(rec.at) as last_at from rec group by rec.sid)
    select coalesce(jsonb_agg(jsonb_build_object(
                      'skey', w.sid,
                      'sname', coalesce((select r2.sname from rec r2
                                          where r2.sid = w.sid and coalesce(r2.sname, '') <> ''
                                          order by r2.at desc nulls last, r2.sname collate "C" limit 1),
                                        substring(w.sid from '[^|]*$')),
                      'last_at', w.last_at)
                    order by w.last_at desc nulls last, w.sid collate "C"), '[]'::jsonb)
      into v_left
      from who w
     where not exists (select 1 from ro where ro.skey = w.sid)
       and not exists (select 1 from ro where ro.rid = split_part(w.sid, '|', 1));
  end if;

  with ro as (select r.skey, r.sname, r.nname, r.cls from public.lec__roster() r),
       nc as (select ro.nname, count(*) as n from ro group by ro.nname),
       mycls as (select k.id from public.lec__classes() k where k.owner = v_name),
       st as (select ro.skey, ro.sname, ro.cls,
                     case when nc.n = 1 then 'k:' || ro.skey else 'n:' || ro.nname end as who
                from ro join nc on nc.nname = ro.nname
               where v_admin or exists (select 1 from unnest(ro.cls) as u(cid) where u.cid in (select id from mycls))),
       lk as (select st.*,
                     (select max(f.at) from public.lec_fail f
                       where f.who = st.who and f.lock = 'day' and f.at > now() - interval '24 hours') as day_at,
                     (select max(f.at) from public.lec_fail f
                       where f.who = st.who and f.lock in ('min', 'day') and f.at > now() - interval '10 minutes') as min_at
                from st)
  select coalesce(jsonb_agg(jsonb_build_object(
                    'skey', lk.skey, 'sname', lk.sname, 'cls', cc.ids, 'cnames', cc.names,
                    'secs', case when lk.day_at is not null
                                 then greatest(1, ceil(extract(epoch from (lk.day_at + interval '24 hours' - now()))))::integer
                                 else greatest(1, ceil(extract(epoch from (lk.min_at + interval '10 minutes' - now()))))::integer end,
                    'day', lk.day_at is not null)
                  order by lk.sname collate "C", lk.skey collate "C"), '[]'::jsonb)
    into v_locked
    from lk
   cross join lateral (
     select coalesce(jsonb_agg(x.cid order by x.cname collate "C", x.cid collate "C"), '[]'::jsonb) as ids,
            coalesce(jsonb_agg(x.cname order by x.cname collate "C", x.cid collate "C"), '[]'::jsonb) as names
       from (select u.cid, coalesce((select k.name from public.lec__classes() k where k.id = u.cid limit 1), '') as cname
               from unnest(lk.cls) as u(cid)) x) cc
   where lk.day_at is not null or lk.min_at is not null;

  return jsonb_build_object('ok', true,
    'waiting', jsonb_build_object('count', v_n, 'items', v_wait),
    'behind', v_behind,
    'left', v_left,
    'locked', v_locked);
end
$$;

revoke all on function public.lec__truthy(jsonb), public.lec__nows(text), public.lec__norm(text), public.lec__mask(text),
                       public.lec__or(text, text, integer), public.lec__pct(text, integer), public.lec__roster(),
                       public.lec__open(public.lec_lecture, text[]), public.lec__move(text, text, text),
                       public.lec__consent_ver(), public.lec__agreed(text), public.lec__ended(public.lec_lecture),
                       public.lec__staff(), public.lec__classes(),
                       public.lec__can(public.lec_lecture, text, text, boolean), public.lec__kh(text)
  from public, anon, authenticated;
-- 표 정책이 부르는 선생님 판정은 로그인한 사람이 부를 수 있어야 함(학생·선생님 아닌 계정 = false)
revoke all on function public.lec__is_staff() from public, anon;
grant execute on function public.lec__is_staff() to authenticated;
revoke all on function public.lec__dur_changed() from public, anon;
revoke all on function public.lec_login(text, text, text), public.lec_home(text),
                       public.lec_consent(text, text, text),
                       public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text, numeric),
                       public.lec_qna_list(text, uuid), public.lec_ask(text, uuid, text, integer, boolean, uuid, text),
                       public.lec_qdel(text, uuid), public.lec_logout(text)
  from public;
grant execute on function public.lec_login(text, text, text), public.lec_home(text),
                          public.lec_consent(text, text, text),
                          public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text, numeric),
                          public.lec_qna_list(text, uuid), public.lec_ask(text, uuid, text, integer, boolean, uuid, text),
                          public.lec_qdel(text, uuid), public.lec_logout(text)
  to anon, authenticated;
-- 선생님 함수는 로그인한 선생님만(함수 안에서도 누구인지 다시 확인)
revoke all on function public.lec_confirm(uuid, text, text), public.lec_unconfirm(uuid, text),
                       public.lec_forget(text), public.lec_unlock(text), public.lec_todo(),
                       public.lec_keys(), public.lec_link(text), public.lec_logout_all(text)
  from public, anon;
grant execute on function public.lec_confirm(uuid, text, text), public.lec_unconfirm(uuid, text),
                          public.lec_forget(text), public.lec_unlock(text), public.lec_todo(),
                          public.lec_keys(), public.lec_link(text), public.lec_logout_all(text)
  to authenticated;

-- ===========================================================================
-- C1 결석한 날 수업(2026-11-16 덧붙임 · 있는 함수와 정책은 그대로 두고 새 칸 · 새 함수만)
--   강의의 «수업일»(교실에서 이 수업을 한 날)과 히즈북스 출결을 맞대어
--   학생 화면 «결석한 날 수업» · 선생님 화면 «결석 · 47%» 칸과 «결석한 날 수업 덜 본 학생»을 만듭니다.
--   출결은 히즈북스 앱(index.html)과 같은 규칙으로 «읽기만» 합니다. 영상을 봐도 출결은 바뀌지 않고, 출결에 아무것도 쓰지 않습니다.
--   앱과 같은 규칙(index.html → 여기):
--     그날 출결 = 일지 기록(recordFor).attendance 가 있으면 그것, 없으면 autoAttendance  → lec__att_core
--     autoAttendance: 시작 전 학생(_notYetById) 없음 → 개인 보강(_mkupOf) «보강» → 등원(checkins .in) «출석»
--       → 휴원일(_cdClosed)이고 그 반 보강 수업(_ovHeld)이 아니면 없음 → 결석 예정(noShowExcused) «결석»
--       → 그날 수업(_classStart)이 있고 지난 날(오늘이면 _classEnd 지남) «결석» · 둘 다 2026.07.15 부터
--     _classStart · _classEnd(반 시간표 · 날짜별 휴강/보강 sessions) → lec__ctime · _dnumRaw → lec__dnum
--     _stuById(모든 반에서 마지막) · _notYetOn → lec__stu · lec__notyet · _cdNorm/_cdClosed → lec__closed
--   읽는 줄: main + 달 줄(pt-rec-YYYY-MM 일지 · pt-ck-YYYY-MM 등하원 · pt-old-YYYY-MM 결석 예정 · 휴강 · 보강).
--     같은 열쇠가 두 곳에 있으면 시각 도장(t · 일지는 editT)이 큰 쪽, 같으면 달 줄(앱 _ptJoin 과 같은 쪽)
--   «모름»(출결 표시 없음)은 결석으로 세지 않습니다. pt-etc 는 읽지 않습니다.
-- ===========================================================================
alter table public.lec_lecture add column if not exists lesson_more date[] not null default '{}';
alter table public.lec_lecture add column if not exists runner jsonb not null default '{}'::jsonb;
-- 수업일마다 그날 이 수업을 한 반(11-16 검수 뒤 고침): {"2026-11-11": ["반 id", …]}
--   적힌 날은 그 반 학생만 그날 출결로 봄 · 안 적힌 날(또는 빈 목록)은 강의의 모든 반
--   «전체»(*) 강의는 반이 적힌 날만 그 반의 수업일 · 안 적힌 날은 어느 반의 수업일도 아님
--     («전체»와 실제 반을 함께 고른 강의는 안 적힌 날 그 실제 반 · 11-17 결석 카드 고침)
alter table public.lec_lecture add column if not exists lesson_cls jsonb not null default '{}'::jsonb;

-- C1 · C3C7 에서 새로 만든 함수만 정확한 모양으로 먼저 지우고 새로 만듭니다
--   (모양 · 받는 칸 이름이 바뀌어도 설치가 멈추지 않게 · 예전부터 있던 함수는 지우지 않음 · 권한은 아래에서 다시 줌)
drop function if exists public.lec__num(jsonb);
drop function if exists public.lec__pint(text);
drop function if exists public.lec__dnum(text);
drop function if exists public.lec__closed(jsonb, text);
drop function if exists public.lec__held(jsonb, text, text);
drop function if exists public.lec__ctime(jsonb, integer, text, jsonb, boolean);
drop function if exists public.lec__stu(jsonb, text);
drop function if exists public.lec__notyet(jsonb, text);
drop function if exists public.lec__lcls(jsonb, date);
drop function if exists public.lec__ros(jsonb);
drop function if exists public.lec__cls(jsonb);
drop function if exists public.lec__att_data(text[], date[]);
drop function if exists public.lec__att_data(jsonb, text[], date[]);
drop function if exists public.lec__att_core(jsonb, text[], text[], date[], date, text);
drop function if exists public.lec__att_core(jsonb, text[], text[], jsonb, date, text);
drop function if exists public.lec__att_one(jsonb, text, date, text);
drop function if exists public.lec__att_staff_one(jsonb, text[], jsonb, date, text);
drop function if exists public.lec_att(text);
drop function if exists public.lec_att_staff();

-- 시각 도장 숫자(숫자가 아니면 0)
create or replace function public.lec__num(v jsonb) returns numeric
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(v) = 'number' then (v #>> '{}')::numeric else 0 end
$$;

-- 앱 parseInt 처럼 앞쪽 숫자만(없으면 null)
create or replace function public.lec__pint(t text) returns numeric
language sql immutable set search_path = public as $$
  select substring(coalesce(t, '') from '^[[:space:]]*([+-]?[0-9]+)')::numeric
$$;

-- 날짜 글자 맞추기(앱 _dnumRaw): 2026-11-1 · 2026/11/01 → 2026.11.01 · 못 읽으면 ''
create or replace function public.lec__dnum(p text) returns text
language plpgsql immutable set search_path = public as $$
declare
  a text[];
  y numeric;
  m numeric;
  d numeric;
begin
  a := string_to_array(replace(replace(coalesce(p, ''), '-', '.'), '/', '.'), '.');
  if coalesce(cardinality(a), 0) < 3 then return ''; end if;
  y := public.lec__pint(a[1]);
  m := public.lec__pint(a[2]);
  d := public.lec__pint(a[3]);
  if y is null or m is null or d is null or y <= 0 or m <= 0 or d <= 0 then return ''; end if;
  return y::text || '.' || right('0' || m::text, 2) || '.' || right('0' || d::text, 2);
end
$$;

-- 휴원일인가(앱 _cdClosed: 날짜 목록 또는 날짜 → {v})
create or replace function public.lec__closed(cd jsonb, dk text) returns boolean
language sql immutable set search_path = public as $$
  select case jsonb_typeof(cd)
           when 'array'  then coalesce(cd ? dk, false)
           when 'object' then coalesce(jsonb_typeof(cd -> dk) = 'object' and public.lec__truthy(cd -> dk -> 'v'), false)
           else false end
$$;

-- 그 반 그날 보강 수업이 열리나(앱 _ovHeld: 날짜별 수업 살아 있고 · 휴강 아니고 · 시작 시각 있음)
create or replace function public.lec__held(ses jsonb, cid text, dk text) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(public.lec__truthy(o) and not public.lec__truthy(o -> 'del')
                  and not public.lec__truthy(o -> 'off') and public.lec__truthy(o -> 'start'), false)
    from (select case when jsonb_typeof(ses) = 'object' then ses -> (cid || '|' || dk) end as o) x
$$;

-- 그 반 그날 수업 시작(p_end = false) · 끝(p_end = true) 시각 · 수업 없으면 ''(앱 _classStart · _classEnd)
create or replace function public.lec__ctime(c jsonb, w integer, dk text, ses jsonb, p_end boolean)
returns text
language plpgsql immutable set search_path = public as $$
declare
  ov  jsonb;
  sc  jsonb;
  ds  jsonb;
  tm  jsonb;
  v   jsonb;
  dy  text;
begin
  if jsonb_typeof(c) is distinct from 'object' then return ''; end if;
  if coalesce(dk, '') <> '' and jsonb_typeof(ses) = 'object' and coalesce(c ->> 'id', '') <> '' then
    ov := ses -> ((c ->> 'id') || '|' || dk);
    if public.lec__truthy(ov) and not public.lec__truthy(ov -> 'del') then
      if public.lec__truthy(ov -> 'off') then return ''; end if;
      if p_end then
        if public.lec__truthy(ov -> 'end') then return ov ->> 'end'; end if;
        if public.lec__truthy(ov -> 'start') then return ''; end if;
      elsif public.lec__truthy(ov -> 'start') then
        return ov ->> 'start';
      end if;
    end if;
  end if;
  if w is null or w < 0 or w > 6 then return ''; end if;
  dy := (array['일', '월', '화', '수', '목', '금', '토'])[w + 1];
  sc := case when jsonb_typeof(c -> 'schedule') in ('object', 'array') then c -> 'schedule' else '{}'::jsonb end;
  v := case when jsonb_typeof(sc) = 'array' then sc -> w else sc -> (w::text) end;
  ds := sc -> 'days';
  if (jsonb_typeof(ds) = 'array' and jsonb_array_length(ds) > 0) then
    if not (ds ? dy) then return ''; end if;
  elsif (jsonb_typeof(ds) = 'string' and (ds #>> '{}') <> '') then
    if position(dy in (ds #>> '{}')) = 0 then return ''; end if;
  elsif v is null or jsonb_typeof(v) = 'null' or (jsonb_typeof(v) = 'string' and (v #>> '{}') = '') then
    return '';
  end if;
  tm := sc -> 'times' -> dy;
  if p_end then
    if public.lec__truthy(tm -> 'end') then return tm ->> 'end'; end if;
    if public.lec__truthy(sc -> 'end') then return sc ->> 'end'; end if;
    if public.lec__truthy(c -> 'endTime') then return c ->> 'endTime'; end if;
  else
    if public.lec__truthy(tm -> 'start') then return tm ->> 'start'; end if;
    if public.lec__truthy(v) then return v #>> '{}'; end if;
    if public.lec__truthy(c -> 'startTime') then return c ->> 'startTime'; end if;
  end if;
  return '';
end
$$;

-- 학생 id 로 학생 찾기 — 모든 반에서 마지막 것(앱 _stuById)
create or replace function public.lec__stu(p_classes jsonb, p_rid text) returns jsonb
language sql immutable set search_path = public as $$
  select s.v
    from jsonb_array_elements(case when jsonb_typeof(p_classes) = 'array' then p_classes else '[]'::jsonb end) with ordinality as c(v, n)
   cross join lateral jsonb_array_elements(case when jsonb_typeof(c.v -> 'students') = 'array' then c.v -> 'students' else '[]'::jsonb end) with ordinality as s(v, m)
   where jsonb_typeof(s.v) = 'object' and s.v ->> 'id' = p_rid
   order by c.n desc, s.m desc
   limit 1
$$;

-- 그날 아직 시작 전 학생인가(앱 _notYetOn: 반배정 대기 · 시작일/등록일이 그날보다 뒤)
create or replace function public.lec__notyet(p_stu jsonb, p_dk text) returns boolean
language sql immutable set search_path = public as $$
  select case
           when jsonb_typeof(p_stu) is distinct from 'object' then false
           when public.lec__truthy(p_stu -> 'pending') then true
           else coalesce(x.sd <> '' and x.td <> '' and (x.sd collate "C") > x.td, false)
         end
    from (select public.lec__dnum(coalesce(case when public.lec__truthy(p_stu -> 'startPlan') then p_stu ->> 'startPlan' end,
                                            case when public.lec__truthy(p_stu -> 'registeredAt') then p_stu ->> 'registeredAt' end,
                                            '')) as sd,
                 public.lec__dnum(p_dk) as td) x
$$;

-- 그 수업일에 이 수업을 한 반(lesson_cls 에 적힌 반 · 안 적혔거나 빈 목록이면 null = 강의의 모든 반)
--   null 이면 부르는 쪽이 강의의 실제 반(class_ids)으로 읽음 · «전체»(*)만 고른 강의는 어느 반도 아님(11-17)
create or replace function public.lec__lcls(p_lc jsonb, p_d date) returns text[]
language sql immutable set search_path = public as $$
  select case when cardinality(x.v) > 0 then x.v end
    from (select array(select t.e
                         from jsonb_array_elements_text(
                                case when jsonb_typeof(p_lc -> to_char(p_d, 'YYYY-MM-DD')) = 'array'
                                     then p_lc -> to_char(p_d, 'YYYY-MM-DD') else '[]'::jsonb end) as t(e)
                        where coalesce(t.e, '') <> '') as v) x
$$;

-- 받은 main 묶음에서 학생 명단(lec__roster 와 같은 거름 · 표를 다시 읽지 않음 · 번호 뒤 4자리는 뺌)
--   스스로 점검이 lec__roster() 와 같은 결과인지 맞대어 봄
create or replace function public.lec__ros(p_main jsonb)
returns table (skey text, rid text, sname text, cls text[])
language sql immutable set search_path = public as $$
  select st.rid || '|' || st.nname,
         st.rid,
         max(st.sname collate "C"),
         coalesce(array_agg(distinct st.cid) filter (where coalesce(st.cid, '') <> ''), '{}')
    from (select s ->> 'id'                       as rid,
                 btrim(s ->> 'name')              as sname,
                 public.lec__norm(s ->> 'name')   as nname,
                 c ->> 'id'                       as cid
            from jsonb_array_elements(case when jsonb_typeof(p_main -> 'classes') = 'array' then p_main -> 'classes' else '[]'::jsonb end) as c
           cross join lateral jsonb_array_elements(case when jsonb_typeof(c -> 'students') = 'array' then c -> 'students' else '[]'::jsonb end) as s
           where jsonb_typeof(s) = 'object'
             and coalesce(s ->> 'id', '') <> ''
             and public.lec__norm(s ->> 'name') <> ''
             and not public.lec__truthy(s -> 'withdrawn')
             and not public.lec__truthy(s -> 'pending')) st
   group by st.rid, st.nname
$$;

-- 출결에 필요한 것만 한 묶음으로(학생 · 날짜에 걸리는 것만): 받은 main + 그 달 줄들
--   { classes, rec: {'반|학생|날짜': 일지}, ck: {'학생|날짜': 등하원}, nse: 결석 예정, ses: 날짜별 수업, mk: 개인 보강, cd: 휴원일 }
--   main 은 부른 쪽이 한 번 읽어 넘김. 달 줄은 수업일이 든 달만 풂(일지 · 등하원 · 결석 예정 · 휴강).
--   개인 보강(열쇠 날짜 = 보강 날)은 가장 이른 수업일의 한 달 앞 ~ 이번 달(미리 당긴 보강도 «결석 보강 잡힘»으로)
create or replace function public.lec__att_data(p_main jsonb, p_rids text[], p_days date[])
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_main  jsonb := case when jsonb_typeof(p_main) = 'object' then p_main else '{}'::jsonb end;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_dks   text[];
  v_yms   text[];
  v_mym   text[];
  v_min   date;
  v_rec   jsonb;
  v_ck    jsonb;
  v_nse   jsonb;
  v_ses   jsonb;
  v_mk    jsonb;
begin
  select coalesce(array_agg(distinct to_char(u.d, 'YYYY.MM.DD')), '{}'),
         coalesce(array_agg(distinct to_char(u.d, 'YYYY-MM')), '{}'),
         min(u.d)
    into v_dks, v_yms, v_min
    from unnest(coalesce(p_days, '{}'::date[])) as u(d)
   where u.d is not null;
  select coalesce(array_agg(to_char(g.m, 'YYYY-MM')), '{}') into v_mym
    from generate_series(date_trunc('month', least(coalesce(v_min, v_today), v_today)) - interval '1 month',
                         date_trunc('month', v_today), interval '1 month') as g(m);

  with src as (
    select 0 as pri, r.v
      from jsonb_array_elements(case when jsonb_typeof(v_main -> 'records') = 'array' then v_main -> 'records' else '[]'::jsonb end) as r(v)
    union all
    select 1, r.v
      from public.app_state a
     cross join lateral jsonb_array_elements(case when jsonb_typeof(a.data -> 'records') = 'array' then a.data -> 'records' else '[]'::jsonb end) as r(v)
     where a.id in (select 'pt-rec-' || y from unnest(v_yms) as y)
  ), f as (
    select (s.v ->> 'classId') || '|' || (s.v ->> 'studentId') || '|' || (s.v ->> 'date') as k, s.v, s.pri,
           public.lec__num(s.v -> 'editT') as t
      from src s
     where jsonb_typeof(s.v) = 'object'
       and coalesce(s.v ->> 'classId', '') <> ''
       and (s.v ->> 'studentId') = any (p_rids)
       and (s.v ->> 'date') = any (v_dks)
  )
  select coalesce(jsonb_object_agg(x.k, x.v), '{}'::jsonb) into v_rec
    from (select distinct on (f.k) f.k, f.v from f order by f.k, f.t desc, f.pri desc) x;

  with src as (
    select 0 as pri, e.key, e.value
      from jsonb_each(case when jsonb_typeof(v_main -> 'checkins') = 'object' then v_main -> 'checkins' else '{}'::jsonb end) as e
    union all
    select 1, e.key, e.value
      from public.app_state a
     cross join lateral jsonb_each(case when jsonb_typeof(a.data -> 'checkins') = 'object' then a.data -> 'checkins' else '{}'::jsonb end) as e
     where a.id in (select 'pt-ck-' || y from unnest(v_yms) as y)
  )
  select coalesce(jsonb_object_agg(x.key, x.value), '{}'::jsonb) into v_ck
    from (select distinct on (s.key) s.key, s.value from src s
           where split_part(s.key, '|', 1) = any (p_rids) and split_part(s.key, '|', 2) = any (v_dks)
           order by s.key, public.lec__num(s.value -> 't') desc, s.pri desc) x;

  with src as (
    select 0 as pri, 'nse' as kind, e.key, e.value
      from jsonb_each(case when jsonb_typeof(v_main -> 'noShowExcused') = 'object' then v_main -> 'noShowExcused' else '{}'::jsonb end) as e
    union all
    select 0, 'ses', e.key, e.value
      from jsonb_each(case when jsonb_typeof(v_main -> 'sessions') = 'object' then v_main -> 'sessions' else '{}'::jsonb end) as e
    union all
    select 0, 'mk', e.key, e.value
      from jsonb_each(case when jsonb_typeof(v_main -> 'mkup') = 'object' then v_main -> 'mkup' else '{}'::jsonb end) as e
    union all
    select 1, z.kind, e.key, e.value
      from public.app_state a
     cross join lateral (values ('nse', a.data -> 'noShowExcused'), ('ses', a.data -> 'sessions')) as z(kind, m)
     cross join lateral jsonb_each(case when jsonb_typeof(z.m) = 'object' then z.m else '{}'::jsonb end) as e
     where a.id in (select 'pt-old-' || y from unnest(v_yms) as y)
    union all
    select 1, 'mk', e.key, e.value
      from public.app_state a
     cross join lateral jsonb_each(case when jsonb_typeof(a.data -> 'mkup') = 'object' then a.data -> 'mkup' else '{}'::jsonb end) as e
     where a.id in (select 'pt-old-' || y from unnest(v_mym) as y)
  ), f as (
    select distinct on (s.kind, s.key) s.kind, s.key, s.value
      from src s
     where (s.kind = 'nse' and split_part(s.key, '|', 1) = any (p_rids) and split_part(s.key, '|', 2) = any (v_dks))
        or (s.kind = 'ses' and split_part(s.key, '|', 2) = any (v_dks))
        or (s.kind = 'mk'  and split_part(s.key, '|', 1) = any (p_rids))
     order by s.kind, s.key, public.lec__num(s.value -> 't') desc, s.pri desc
  )
  select coalesce(jsonb_object_agg(f.key, f.value) filter (where f.kind = 'nse'), '{}'::jsonb),
         coalesce(jsonb_object_agg(f.key, f.value) filter (where f.kind = 'ses'), '{}'::jsonb),
         coalesce(jsonb_object_agg(f.key, f.value) filter (where f.kind = 'mk'), '{}'::jsonb)
    into v_nse, v_ses, v_mk
    from f;

  return jsonb_build_object(
    'classes', case when jsonb_typeof(v_main -> 'classes') = 'array' then v_main -> 'classes' else '[]'::jsonb end,
    'rec', v_rec, 'ck', v_ck, 'nse', v_nse, 'ses', v_ses, 'mk', v_mk,
    'cd', coalesce(v_main -> 'closedDays', 'null'::jsonb));
end
$$;

-- 출결 계산(위 묶음 p 하나만 읽음 · 표를 읽지 않아 스스로 점검에서 가짜 묶음으로 확인).
--   (학생 p_rids[i], 반 p_cids[i]) 마다 그 반의 수업일(p_cdays = {반 id: ["YYYY-MM-DD", …]}) 중 오늘까지 날짜마다 한 줄:
--   o_att = 'in'(출석 · 지각) · 'abs'(결석) · 'sub'(그날 개인 보강) · ''(모름) · o_mk = 결석한 그날을 채우는 결석 보강이 잡혀 있음
--   같은 학생이 이어지면 학생 찾기 · 결석 보강 · 시작 전 판단(반배정 대기 · 시작일)은 한 번만 계산(줄은 학생 순으로 넘김)
create or replace function public.lec__att_core(p jsonb, p_rids text[], p_cids text[], p_cdays jsonb, p_today date, p_now text)
returns table (o_rid text, o_cid text, o_day date, o_att text, o_mk boolean)
language plpgsql stable set search_path = public as $$
declare
  v_cls  jsonb := case when jsonb_typeof(p -> 'classes') = 'array' then p -> 'classes' else '[]'::jsonb end;
  v_rec  jsonb := case when jsonb_typeof(p -> 'rec') = 'object' then p -> 'rec' else '{}'::jsonb end;
  v_ck   jsonb := case when jsonb_typeof(p -> 'ck') = 'object' then p -> 'ck' else '{}'::jsonb end;
  v_nse  jsonb := case when jsonb_typeof(p -> 'nse') = 'object' then p -> 'nse' else '{}'::jsonb end;
  v_ses  jsonb := case when jsonb_typeof(p -> 'ses') = 'object' then p -> 'ses' else '{}'::jsonb end;
  v_mk   jsonb := case when jsonb_typeof(p -> 'mk') = 'object' then p -> 'mk' else '{}'::jsonb end;
  v_cd   jsonb := p -> 'cd';
  v_tk   text := to_char(p_today, 'YYYY.MM.DD');
  v_days date[];
  v_i    integer;
  v_d    date;
  v_dk   text;
  v_c    jsonb;
  v_stu  jsonb;
  v_mkf  text[];
  v_a    text;
  v_x    jsonb;
  v_w    integer;
  v_st   text;
  v_en   text;
  v_prev text;
  v_pend boolean;
  v_sd   text;
begin
  for v_i in 1 .. coalesce(cardinality(p_rids), 0) loop
    o_rid := p_rids[v_i];
    o_cid := p_cids[v_i];
    continue when coalesce(o_rid, '') = '' or coalesce(o_cid, '') = '';
    select coalesce(array_agg(distinct u.d order by u.d), '{}') into v_days
      from (select t.e::date as d
              from jsonb_array_elements_text(case when jsonb_typeof(p_cdays -> o_cid) = 'array'
                                                  then p_cdays -> o_cid else '[]'::jsonb end) as t(e)) u
     where u.d is not null and u.d <= p_today;
    continue when cardinality(v_days) = 0;
    v_c := (select c.v from jsonb_array_elements(v_cls) with ordinality as c(v, n)
             where jsonb_typeof(c.v) = 'object' and c.v ->> 'id' = o_cid order by c.n limit 1);
    if v_prev is distinct from o_rid then
      v_prev := o_rid;
      v_stu := public.lec__stu(v_cls, o_rid);
      -- lec__notyet 과 같은 판단을 학생마다 한 번: 반배정 대기 · 시작일(없으면 등록일)
      v_pend := coalesce(jsonb_typeof(v_stu) = 'object' and public.lec__truthy(v_stu -> 'pending'), false);
      v_sd := case when jsonb_typeof(v_stu) = 'object'
                   then public.lec__dnum(coalesce(case when public.lec__truthy(v_stu -> 'startPlan') then v_stu ->> 'startPlan' end,
                                                  case when public.lec__truthy(v_stu -> 'registeredAt') then v_stu ->> 'registeredAt' end,
                                                  ''))
                   else '' end;
      select coalesce(array_agg(distinct e.value ->> 'from'), '{}') into v_mkf
        from jsonb_each(v_mk) as e
       where split_part(e.key, '|', 1) = o_rid
         and jsonb_typeof(e.value) = 'object'
         and not public.lec__truthy(e.value -> 'del')
         and not public.lec__truthy(e.value -> 'free')
         and coalesce(e.value ->> 'from', '') <> '';
    end if;
    foreach v_d in array v_days loop
      v_dk := to_char(v_d, 'YYYY.MM.DD');
      v_a := '';
      v_x := v_rec -> (o_cid || '|' || o_rid || '|' || v_dk);
      if jsonb_typeof(v_x) = 'object' and public.lec__truthy(v_x -> 'attendance') then
        v_a := v_x ->> 'attendance';
      elsif not (v_pend or (coalesce(v_sd, '') <> '' and (v_sd collate "C") > v_dk)) then
        v_x := v_mk -> (o_rid || '|' || v_dk);
        if public.lec__truthy(v_x) and not public.lec__truthy(v_x -> 'del') then
          v_a := '보강';
        else
          v_x := v_ck -> (o_rid || '|' || v_dk);
          if public.lec__truthy(v_x) and not public.lec__truthy(v_x -> 'del') and public.lec__truthy(v_x -> 'in') then
            v_a := '출석';
          elsif public.lec__closed(v_cd, v_dk) and not public.lec__held(v_ses, o_cid, v_dk) then
            v_a := '';
          else
            v_x := v_nse -> (o_rid || '|' || v_dk);
            if public.lec__truthy(v_x) and not public.lec__truthy(v_x -> 'del') and (v_dk collate "C") >= '2026.07.15' then
              v_a := '결석';
            elsif v_c is not null then
              v_w := extract(dow from v_d)::integer;
              v_st := public.lec__ctime(v_c, v_w, v_dk, v_ses, false);
              if v_st <> '' and (v_dk collate "C") >= '2026.07.15' then
                if (v_dk collate "C") < v_tk then
                  v_a := '결석';
                elsif v_dk = v_tk then
                  v_en := public.lec__ctime(v_c, v_w, v_dk, v_ses, true);
                  if v_en <> '' and (coalesce(p_now, '') collate "C") > v_en then v_a := '결석'; end if;
                end if;
              end if;
            end if;
          end if;
        end if;
      end if;
      o_day := v_d;
      o_att := case when v_a in ('출석', '지각') then 'in' when v_a = '결석' then 'abs' when v_a = '보강' then 'sub' else '' end;
      o_mk := (o_att = 'abs' and v_dk = any (v_mkf));
      return next;
    end loop;
  end loop;
end
$$;

-- 받은 main 묶음에서 반 목록(lec__classes 와 같은 거름 · 표를 다시 읽지 않음)
--   스스로 점검이 lec__classes() 와 같은 결과인지 맞대어 봄
create or replace function public.lec__cls(p_main jsonb)
returns table (id text, name text, owner text)
language sql immutable set search_path = public as $$
  select c ->> 'id',
         coalesce(c ->> 'name', ''),
         btrim(coalesce(c ->> 'owner', ''), ' ' || chr(9) || chr(10) || chr(11) || chr(12) || chr(13))
    from jsonb_array_elements(case when jsonb_typeof(p_main -> 'classes') = 'array' then p_main -> 'classes' else '[]'::jsonb end) as c
   where jsonb_typeof(c) = 'object'
     and coalesce(c ->> 'id', '') <> ''
$$;

-- 학생 한 명의 출결(받은 main · 정한 오늘 · 지금 시각으로 계산 · 표는 강의와 달 줄만 읽음)
--   lec_att 이 열쇠를 확인한 뒤 부르고, 스스로 점검이 가짜 main · 정한 날짜로 같은 길을 그대로 돌려 봄
--   items = [{id, att: 'abs' | 'in', day: 그 날(결석이면 가장 늦은 결석한 날), days: 수업일들, mk: 결석 보강이 잡힘}]
--   수업일은 강의의 lesson_on + lesson_more 중 오늘까지 · 62일 안. 여러 날 수업에서 하루라도 결석이면 결석.
--     62일을 14일로 줄이지 않는 까닭: 결석 카드는 13일이지만 «교실에서 들음 · 복습 N%» 줄은 두 달 안 강의에 다 붙음(줄이면
--     2주 넘은 강의가 «교실에서 들음» 없이 보임) · 달 줄은 수업일이 든 달만 풀므로 창을 줄여도 읽는 줄 수는 거의 같음
--   한 날 안에서는 학생의 반(강의 반과 겹치는 반)마다 읽어 «출석» 이 하나라도 있으면 들음. 못 읽으면 목록에서 뺌(= 모름)
--   수업일에 반이 적혀 있으면(lesson_cls) 그날은 그 반으로만 읽음 · 그 반이 아닌 학생에게는 그날이 수업일이 아님
--   «전체»(*) 강의는 반이 적힌 날만 그 반의 수업일 · 안 적힌 날은 강의의 실제 반만(«전체»만이면 아무 반도 아님 · 11-17)
--   계산하는 날은 학생의 반마다 그 반이 수업한 날만(반마다 다른 날을 넘김)
create or replace function public.lec__att_one(p_main jsonb, p_sid text, p_today date, p_now text)
returns jsonb
language plpgsql stable set search_path = public as $$
declare
  v_rid   text;
  v_cls   text[];
  v_cdays jsonb := '{}'::jsonb;
  v_days  date[];
  v_data  jsonb;
  v_items jsonb := '[]'::jsonb;
begin
  select r.rid, r.cls into v_rid, v_cls from public.lec__ros(p_main) r where r.skey = p_sid limit 1;
  if v_rid is not null and coalesce(cardinality(v_cls), 0) > 0 then
    with lday as (
      select l.id, l.class_ids, u.x as day, public.lec__lcls(l.lesson_cls, u.x) as lc
        from public.lec_lecture l
       cross join lateral (select distinct v.x from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)) u
       where public.lec__open(l, v_cls) and u.x between p_today - 62 and p_today
    ), cd as (
      select distinct c.cid, lday.day
        from lday
       cross join lateral unnest(v_cls) as c(cid)
       where c.cid = any (coalesce(lday.lc, lday.class_ids))
         and (c.cid = any (lday.class_ids) or '*' = any (lday.class_ids))
    )
    select coalesce((select jsonb_object_agg(g.cid, g.ds)
                       from (select cd.cid, jsonb_agg(to_char(cd.day, 'YYYY-MM-DD') order by cd.day) as ds
                               from cd group by cd.cid) g), '{}'::jsonb),
           coalesce((select array_agg(distinct cd.day) from cd), '{}')
      into v_cdays, v_days;
  end if;
  if coalesce(cardinality(v_days), 0) > 0 then
    v_data := public.lec__att_data(p_main, array[v_rid], v_days);
    with a as (
      select * from public.lec__att_core(v_data, array_fill(v_rid, array[cardinality(v_cls)]), v_cls, v_cdays, p_today, p_now)
    ), lday as (
      select l.id, l.class_ids, u.x as day, public.lec__lcls(l.lesson_cls, u.x) as lc
        from public.lec_lecture l
       cross join lateral (select distinct v.x from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)) u
       where public.lec__open(l, v_cls) and u.x between p_today - 62 and p_today
    ), lec as (
      select lday.id, array_agg(lday.day order by lday.day) as days
        from lday
       where coalesce(lday.lc, lday.class_ids) && v_cls
       group by lday.id
    ), per as (
      select lday.id, lday.day,
             case when bool_or(a.o_att = 'in') then 'in' when bool_or(a.o_att = 'abs') then 'abs' else '' end as att,
             bool_or(a.o_mk) as mk
        from lday
        join a on a.o_day = lday.day
              and a.o_cid = any (coalesce(lday.lc, lday.class_ids))
              and (a.o_cid = any (lday.class_ids) or '*' = any (lday.class_ids))
       group by lday.id, lday.day
    ), agg as (
      select per.id,
             case when bool_or(per.att = 'abs') then 'abs' when bool_or(per.att = 'in') then 'in' else '' end as att,
             coalesce(max(per.day) filter (where per.att = 'abs'), max(per.day) filter (where per.att = 'in')) as day,
             coalesce(bool_and(per.mk) filter (where per.att = 'abs'), false) as mk
        from per group by per.id
    )
    select coalesce(jsonb_agg(jsonb_build_object('id', agg.id, 'att', agg.att, 'day', agg.day,
                                                 'days', to_jsonb(lec.days), 'mk', agg.mk) order by agg.day desc, agg.id), '[]'::jsonb)
      into v_items
      from agg join lec on lec.id = agg.id
     where agg.att <> '';
  end if;
  return jsonb_build_object('ok', true, 'today', p_today, 'items', v_items);
end
$$;

-- 학생 화면: 내가 볼 수 있는 강의마다 «결석한 날 수업»인지 · «교실에서 들음»인지(계산은 lec__att_one)
--   열쇠 확인 → main 을 한 번만 읽어 넘김
create or replace function public.lec_att(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k      public.lec_key;
  v_main jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select a.data into v_main from public.app_state a where a.id = 'main';
  return public.lec__att_one(v_main, k.sid,
                             (now() at time zone 'Asia/Seoul')::date,
                             to_char(now() at time zone 'Asia/Seoul', 'HH24:MI'));
end
$$;

-- 선생님 화면 계산(받은 main · 내 반들 · 반 이름 · 정한 오늘 · 지금 시각): lec_att_staff 이 선생님을 확인한 뒤 부르고,
--   스스로 점검이 가짜 main · 정한 날짜로 같은 길을 그대로 돌려 봄
--   내 반(관리자는 모든 반) 학생 × 수업일이 62일 안인 강의의 출결 · 시작 전 학생 · «결석한 날 수업 덜 본 학생»
--   lectures = [{l, in: [학생 열쇠], abs: [{s, d: 결석한 날, mk}]}] · notstarted = [학생 열쇠]
--   band = {n: 학생 수(겹침 없이), items: [{cls, cname, lecture, title, day, n, names}]}
--     결석한 날이 오늘~13일 전 · 진도 90% 미만 · 선생님 확인 전 · 기록 안 함 아님 · 시작 전 아님 · 결석 보강이 잡히지 않음 ·
--     숨기지 않았고 공개됐고 공개 끝 전인 강의(lec_todo 의 behind 와 같은 강의 거름)
--   수업일에 반이 적혀 있으면(lesson_cls) 그날은 그 반 학생만 출결로 보고, 띠의 반도 그날 적힌 반으로만 묶음
--   «전체»(*) 강의는 반이 적힌 날만 그 반의 수업일 · 안 적힌 날은 강의의 실제 반만(«전체»만이면 아무 반도 아님 · 11-17)
--   (학생, 반)마다 그 반이 수업한 날만 계산(반마다 다른 날을 넘김)
create or replace function public.lec__att_staff_one(p_main jsonb, p_scope text[], p_cln jsonb, p_today date, p_now text)
returns jsonb
language plpgsql stable set search_path = public as $$
declare
  v_tk    text := to_char(p_today, 'YYYY.MM.DD');
  v_mainc jsonb := case when jsonb_typeof(p_main -> 'classes') = 'array' then p_main -> 'classes' else '[]'::jsonb end;
  v_scope text[] := coalesce(p_scope, '{}'::text[]);
  v_rids  text[];
  v_cids  text[];
  v_cdays jsonb := '{}'::jsonb;
  v_days  date[];
  v_data  jsonb;
  v_cells jsonb := '[]'::jsonb;
  v_lecs  jsonb := '[]'::jsonb;
  v_ns    jsonb := '[]'::jsonb;
  v_items jsonb := '[]'::jsonb;
  v_bn    integer := 0;
begin
  select coalesce(array_agg(p.rid order by p.rid, p.cid), '{}'), coalesce(array_agg(p.cid order by p.rid, p.cid), '{}')
    into v_rids, v_cids
    from (select distinct r.rid, c.cid
            from public.lec__ros(p_main) r cross join lateral unnest(r.cls) as c(cid)
           where r.cls && v_scope) p;

  if cardinality(v_rids) > 0 then
    with lday as (
      select l.id, l.class_ids, u.x as day, public.lec__lcls(l.lesson_cls, u.x) as lc
        from public.lec_lecture l
       cross join lateral (select distinct v.x from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)) u
       where u.x between p_today - 62 and p_today
         and (l.class_ids && v_scope or '*' = any (l.class_ids))
    ), pc as (
      select distinct p.cid from unnest(v_cids) as p(cid)
    ), cd as (
      select distinct pc.cid, lday.day
        from lday
        join pc on pc.cid = any (coalesce(lday.lc, lday.class_ids))
               and (pc.cid = any (lday.class_ids) or '*' = any (lday.class_ids))
    )
    select coalesce((select jsonb_object_agg(g.cid, g.ds)
                       from (select cd.cid, jsonb_agg(to_char(cd.day, 'YYYY-MM-DD') order by cd.day) as ds
                               from cd group by cd.cid) g), '{}'::jsonb),
           coalesce((select array_agg(distinct cd.day) from cd), '{}')
      into v_cdays, v_days;
  end if;

  select coalesce(jsonb_agg(r.skey order by r.skey collate "C"), '[]'::jsonb) into v_ns
    from public.lec__ros(p_main) r
   where r.cls && v_scope and public.lec__notyet(public.lec__stu(v_mainc, r.rid), v_tk);

  if coalesce(cardinality(v_days), 0) > 0 and cardinality(v_rids) > 0 then
    v_data := public.lec__att_data(p_main, v_rids, v_days);
    with a as (
      select * from public.lec__att_core(v_data, v_rids, v_cids, v_cdays, p_today, p_now)
    ), ro as (
      select r.skey, r.rid, r.cls from public.lec__ros(p_main) r where r.cls && v_scope
    ), lday as (
      select l.id, l.class_ids, u.x as day, public.lec__lcls(l.lesson_cls, u.x) as lc
        from public.lec_lecture l
       cross join lateral (select distinct v.x from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)) u
       where u.x between p_today - 62 and p_today
         and (l.class_ids && v_scope or '*' = any (l.class_ids))
    ), per as (
      select lday.id as lid, ro.skey, lday.day,
             case when bool_or(a.o_att = 'in') then 'in' when bool_or(a.o_att = 'abs') then 'abs' else '' end as att,
             bool_or(a.o_mk) as mk
        from lday
        join ro on exists (select 1 from unnest(ro.cls) as c(cid)
                            where c.cid = any (v_scope) and (c.cid = any (lday.class_ids) or '*' = any (lday.class_ids)))
        join a on a.o_rid = ro.rid and a.o_day = lday.day and a.o_cid = any (ro.cls)
              and a.o_cid = any (coalesce(lday.lc, lday.class_ids))
              and (a.o_cid = any (lday.class_ids) or '*' = any (lday.class_ids))
       group by lday.id, ro.skey, lday.day
    ), agg as (
      select per.lid, per.skey,
             case when bool_or(per.att = 'abs') then 'abs' when bool_or(per.att = 'in') then 'in' else '' end as att,
             coalesce(max(per.day) filter (where per.att = 'abs'), max(per.day) filter (where per.att = 'in')) as day,
             coalesce(bool_and(per.mk) filter (where per.att = 'abs'), false) as mk
        from per group by per.lid, per.skey
    )
    select coalesce(jsonb_agg(jsonb_build_object('l', agg.lid, 's', agg.skey, 'a', agg.att, 'd', agg.day, 'mk', agg.mk)), '[]'::jsonb)
      into v_cells
      from agg where agg.att <> '';

    select coalesce(jsonb_agg(jsonb_build_object(
             'l', g.l,
             'in', g.ins,
             'abs', g.abss) order by g.l), '[]'::jsonb)
      into v_lecs
      from (select c.l,
                   coalesce(jsonb_agg(c.s order by c.s collate "C") filter (where c.a = 'in'), '[]'::jsonb) as ins,
                   coalesce(jsonb_agg(jsonb_build_object('s', c.s, 'd', c.d, 'mk', c.mk) order by c.s collate "C")
                            filter (where c.a = 'abs'), '[]'::jsonb) as abss
              from jsonb_to_recordset(v_cells) as c(l uuid, s text, a text, d date, mk boolean)
             group by c.l) g;

    with cell as (
      select c.l, c.s, c.d from jsonb_to_recordset(v_cells) as c(l uuid, s text, a text, d date, mk boolean)
       where c.a = 'abs' and not coalesce(c.mk, false) and c.d between p_today - 13 and p_today
         and not coalesce(v_ns ? c.s, false)
    ), ro as (
      select r.skey, r.sname, r.cls from public.lec__ros(p_main) r where r.cls && v_scope
    ), cl as (
      select e.key as id, e.value as name
        from jsonb_each_text(case when jsonb_typeof(p_cln) = 'object' then p_cln else '{}'::jsonb end) as e
       where e.key = any (v_scope)
    ), st as (
      select l.id as lid, l.title, l.created_at as lca, cell.d, cl.id as cid, cl.name as cname, ro.skey, ro.sname
        from cell
        join public.lec_lecture l on l.id = cell.l
       cross join lateral (select public.lec__lcls(l.lesson_cls, cell.d) as lc) z
        join ro on ro.skey = cell.s
        join cl on cl.id = any (ro.cls) and cl.id = any (coalesce(z.lc, l.class_ids))
               and (cl.id = any (l.class_ids) or '*' = any (l.class_ids))
        left join public.lec_progress g on g.sid = ro.skey and g.lecture_id = l.id
        left join public.lec_consent cs on cs.sid = ro.skey
       where not l.hidden
         and coalesce(l.posted_on, p_today) <= p_today
         and not public.lec__ended(l.*)   -- l 만 쓰면 cell.l(uuid) 칸으로 읽힘(운영 Postgres 11-16 오류)
         and coalesce(g.pct, 0) < 90 and g.done_by is null
         and coalesce(cs.choice, '') <> 'none'
    )
    select coalesce((select count(distinct st.skey)::integer from st), 0),
           coalesce((select jsonb_agg(jsonb_build_object(
                              'cls', x.cid, 'cname', x.cname, 'lecture', x.lid, 'title', x.title, 'day', x.day,
                              'n', x.n, 'names', x.names)
                            order by x.day desc, x.lca desc, x.cname collate "C", x.cid collate "C", x.lid)
                       from (select st.lid, st.title, st.lca, st.cid, st.cname, max(st.d) as day,
                                    count(*)::integer as n,
                                    jsonb_agg(st.sname order by st.sname collate "C", st.skey collate "C") as names
                               from st group by st.lid, st.title, st.lca, st.cid, st.cname) x), '[]'::jsonb)
      into v_bn, v_items;
  end if;

  return jsonb_build_object('ok', true, 'today', p_today, 'lectures', v_lecs, 'notstarted', v_ns,
                            'band', jsonb_build_object('n', v_bn, 'items', v_items));
end
$$;

-- 선생님 화면: 선생님 확인 → main 을 한 번만 읽어 내 반(관리자는 모든 반)과 반 이름을 정해 넘김(계산은 lec__att_staff_one)
create or replace function public.lec_att_staff()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_name  text;
  v_admin boolean;
  v_main  jsonb;
  v_scope text[];
  v_cln   jsonb;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  select a.data into v_main from public.app_state a where a.id = 'main';
  select coalesce(array_agg(c.id), '{}'), coalesce(jsonb_object_agg(c.id, c.name), '{}'::jsonb)
    into v_scope, v_cln
    from public.lec__cls(v_main) c
   where v_admin or c.owner = v_name;
  return public.lec__att_staff_one(v_main, v_scope, v_cln,
                                   (now() at time zone 'Asia/Seoul')::date,
                                   to_char(now() at time zone 'Asia/Seoul', 'HH24:MI'));
end
$$;

revoke all on function public.lec__num(jsonb), public.lec__pint(text), public.lec__dnum(text),
                       public.lec__closed(jsonb, text), public.lec__held(jsonb, text, text),
                       public.lec__ctime(jsonb, integer, text, jsonb, boolean),
                       public.lec__stu(jsonb, text), public.lec__notyet(jsonb, text),
                       public.lec__lcls(jsonb, date), public.lec__ros(jsonb), public.lec__cls(jsonb),
                       public.lec__att_data(jsonb, text[], date[]),
                       public.lec__att_core(jsonb, text[], text[], jsonb, date, text),
                       public.lec__att_one(jsonb, text, date, text),
                       public.lec__att_staff_one(jsonb, text[], jsonb, date, text)
  from public, anon, authenticated;
revoke all on function public.lec_att(text) from public;
grant execute on function public.lec_att(text) to anon, authenticated;
revoke all on function public.lec_att_staff() from public, anon;
grant execute on function public.lec_att_staff() to authenticated;

-- ---------------------------------------------------------------------------
-- 스스로 점검(명단을 읽는지 · 기록이 맞게 쌓이는지 · 이름이 바뀐 학생 기록이 옮겨지는지).
-- 점검용 기록은 바로 되돌려 남지 않습니다
-- ---------------------------------------------------------------------------
do $$
declare
  v_n   integer;
  v_i   integer;
  v_t   text;
  v_l1  uuid;
  v_l2  uuid;
  v_l3  uuid;
  v_l4  uuid;
  v_l5  uuid;
  v_s3  uuid;
  v_rt  numeric;
  v_st  integer;
  v_w   integer;
  v_tot integer;
  v_ts  timestamptz;
  v_cnt integer;
  v_role boolean;
  v_k2  text;
  v_sk  text;
  v_key text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_s1  uuid := gen_random_uuid();
  v_s2  uuid := gen_random_uuid();
  v_old text := 'selftest-rid|김점검';
  v_new text := 'selftest-rid|김점검둘';
  r     jsonb;
begin
  select count(*) into v_n from public.lec__roster();
  if v_n = 0 then
    raise exception '학생 명단을 읽지 못했습니다. app_state 의 main 줄에 classes 가 있는지 확인해 주세요';
  end if;
  begin
    if public.lec__norm(E' Kim　하 늘 \t') <> 'kim하늘' then
      raise exception '점검 실패(이름 맞추기): %', public.lec__norm(E' Kim　하 늘 \t');
    end if;
    if public.lec__mask('김점검') <> '김○○' then
      raise exception '점검 실패(이름 가리기)';
    end if;
    insert into public.lec_lecture (title, yt, dur, class_ids) values ('selftest', 'selftest000', 100, '{*}') returning id into v_l1;
    insert into public.lec_lecture (title, yt, dur, class_ids) values ('selftest', 'selftest000', 100, '{*}') returning id into v_l2;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls) values (public.lec__kh(v_key), v_old, 'selftest-rid', '1234', '김점검', '{c-selftest}');
    -- 열쇠는 해시로만 저장 · 표에서 읽은 해시를 열쇠로 넣으면 들어가지 못함
    if public.lec__kh('abc') <> 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' then
      raise exception '점검 실패(열쇠 해시): %', public.lec__kh('abc');
    end if;
    select count(*) into v_n from public.lec_key where kh = v_key;
    if v_n <> 0 then raise exception '점검 실패(열쇠가 그대로 저장됨)'; end if;
    r := public.lec_home(public.lec__kh(v_key));
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(해시로 들어가기): %', r; end if;

    -- 기록 동의 전에는 아무것도 쓰지 않음 · 옛 판으로는 동의 안 됨
    r := public.lec_beat(v_key, v_l1, v_s1, '11111', 50, 50, 0, 50, 100, 'selftest');
    if (r ->> 'err') is distinct from 'no_consent' then raise exception '점검 실패(동의 전 기록): %', r; end if;
    select count(*) into v_n from public.lec_session where id = v_s1;
    if v_n <> 0 then raise exception '점검 실패(동의 전인데 묶음이 생김)'; end if;
    r := public.lec_consent(v_key, 'agree', 'v0-old');
    if (r ->> 'err') is distinct from 'ver' or (r ->> 'ver') is distinct from public.lec__consent_ver() then
      raise exception '점검 실패(옛 판 동의): %', r;
    end if;
    r := public.lec_consent(v_key, 'agree', public.lec__consent_ver());
    if (r ->> 'choice') is distinct from 'agree' then raise exception '점검 실패(동의): %', r; end if;

    r := public.lec_beat(v_key, v_l1, v_s1, '11111', 50, 50, 0, 50, 100, 'selftest', 2.5);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'pct')::integer <> 50 or (r ->> 'watched')::integer <> 50 then
      raise exception '점검 실패(기록 1): %', r;
    end if;
    select rate into v_t from public.lec_session where id = v_s1;
    if v_t::numeric <> 2 then raise exception '점검 실패(배속 자르기): %', v_t; end if;
    r := public.lec_beat(v_key, v_l1, v_s1, '1111100011', 80, 100, 0, 100, 100, 'selftest');
    if (r ->> 'pct')::integer <> 70 or (r ->> 'watched')::integer <> 80 then
      raise exception '점검 실패(기록 2): %', r;
    end if;
    r := public.lec_beat(v_key, v_l1, v_s1, '1111100011', 80, 100, 0, 100, 100, 'selftest');
    if (r ->> 'watched')::integer <> 80 then
      raise exception '점검 실패(같은 기록 다시): %', r;
    end if;
    r := public.lec_beat(v_key, v_l2, v_s2, '1111111111', 5, 100, 0, 100, 100, 'selftest');
    if (r ->> 'pct')::integer <> 30 then
      raise exception '점검 실패(한 번에 많이 켠 기록): %', r;
    end if;

    r := public.lec_ask(v_key, v_l1, '점검 질문', 12, false, null);
    if not coalesce((r ->> 'ok')::boolean, false) then
      raise exception '점검 실패(질문): %', r;
    end if;
    r := public.lec_qna_list(v_key, v_l1);
    if jsonb_array_length(r -> 'items') <> 1 or (r -> 'items' -> 0 ->> 'who') <> '나'
       or (r -> 'items' -> 0 ->> 'kind') <> 'content' or (r -> 'items' -> 0 ->> 'answered')::boolean then
      raise exception '점검 실패(질문 목록): %', r;
    end if;
    r := public.lec_ask(v_key, v_l1, '영상 문제 점검', 12, false, null, 'tech');
    select kind into v_t from public.lec_qna where id = (r ->> 'id')::uuid;
    if v_t is distinct from 'tech' then raise exception '점검 실패(질문 종류): %', r; end if;
    -- 선생님 답이 달린 질문은 학생이 못 지움
    insert into public.lec_qna (lecture_id, parent, teacher, body) values (v_l1, (r ->> 'id')::uuid, 'selftest', '점검 답');
    r := public.lec_qdel(v_key, (r ->> 'id')::uuid);
    if (r ->> 'err') is distinct from 'answered' then raise exception '점검 실패(답 달린 질문 지우기): %', r; end if;

    -- 이름이 바뀐 학생: 겹치는 강의는 합치고 나머지는 옮김
    insert into public.lec_progress (sid, lecture_id, sname, seen, watched, sessions, first_at, last_at)
    values (v_new, v_l1, '김점검둘', '0000011100', 30, 1, now(), now());
    perform public.lec__move(v_old, v_new, '김점검둘');
    select seen, pct, watched into v_t, v_i, v_n from public.lec_progress where sid = v_new and lecture_id = v_l1;
    if v_t <> '1111111111' or v_i <> 100 or v_n <> 110 then
      raise exception '점검 실패(기록 옮기기): % · % · %', v_t, v_i, v_n;
    end if;
    select count(*) into v_n from public.lec_progress where sid = v_old;
    if v_n <> 0 then raise exception '점검 실패(옛 기록 남음): %', v_n; end if;
    select count(*) into v_n from public.lec_progress where sid = v_new;
    if v_n <> 2 then raise exception '점검 실패(옮긴 기록 수): %', v_n; end if;
    select count(*) into v_n from public.lec_key where kh = public.lec__kh(v_key) and sid = v_new;
    if v_n <> 1 then raise exception '점검 실패(열쇠 옮기기)'; end if;
    select count(*) into v_n from public.lec_qna where sid = v_new;
    if v_n <> 2 then raise exception '점검 실패(질문 옮기기): %', v_n; end if;
    select count(*) into v_n from public.lec_consent where sid = v_new and choice = 'agree';
    select count(*) into v_i from public.lec_consent where sid = v_old;
    if v_n <> 1 or v_i <> 0 then raise exception '점검 실패(동의 옮기기): % · %', v_n, v_i; end if;

    -- «기록 안 함»이면 쓰지 않음 · 공개 끝 날짜가 지난 강의는 'ended'
    r := public.lec_consent(v_key, 'none', public.lec__consent_ver());
    r := public.lec_beat(v_key, v_l2, v_s2, '1111111111', 60, 100, 0, 100, 100, 'selftest');
    if (r ->> 'err') is distinct from 'no_consent' then raise exception '점검 실패(기록 안 함): %', r; end if;
    r := public.lec_ask(v_key, v_l2, '기록 안 함 질문', 1, false, null);
    if (r ->> 'err') is distinct from 'no_consent' then raise exception '점검 실패(기록 안 함 질문): %', r; end if;
    r := public.lec_consent(v_key, 'agree', public.lec__consent_ver());
    update public.lec_lecture set until = (now() at time zone 'Asia/Seoul')::date - 1 where id = v_l2;
    r := public.lec_beat(v_key, v_l2, v_s2, '1111111111', 60, 100, 0, 100, 100, 'selftest');
    if (r ->> 'err') is distinct from 'ended' then raise exception '점검 실패(공개 끝 강의): %', r; end if;
    update public.lec_lecture set until = (now() at time zone 'Asia/Seoul')::date where id = v_l2;
    r := public.lec_beat(v_key, v_l2, v_s2, '1111111111', 60, 100, 0, 100, 100, 'selftest');
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(공개 끝 날 당일): %', r; end if;

    -- 배속: 1.5배 · 2배로 처음부터 끝까지 틀면(벽시계 = 길이 ÷ 배속 · 1분 또는 2분마다 기록) 완료 · 인정 초 = 길이.
    -- 지난 기록 뒤 흐른 시간은 ended_at 을 그만큼 앞으로 당겨 흉내 냄(점검 안에서는 now() 가 멈춰 있음)
    foreach v_rt in array array[1.5, 2]::numeric[] loop
      foreach v_st in array array[60, 120] loop
        insert into public.lec_lecture (title, yt, dur, class_ids) values ('selftest', 'selftest000', 600, '{*}') returning id into v_l5;
        v_s3 := gen_random_uuid();
        r := public.lec_beat(v_key, v_l5, v_s3, '', 0, 0, 0, 0, 600, 'selftest', v_rt);
        v_w := 0;
        while v_w * v_rt < 600 loop
          v_i := least(v_st, ceil((600 - v_w * v_rt) / v_rt)::integer);
          v_w := v_w + v_i;
          v_tot := least(600, (v_w * v_rt)::integer);
          update public.lec_session set ended_at = now() - make_interval(secs => v_i) where id = v_s3;
          r := public.lec_beat(v_key, v_l5, v_s3, repeat('1', ceil(v_tot / 10.0)::integer), v_tot, v_tot, 0, v_tot, 600, 'selftest', v_rt);
        end loop;
        if v_w <> (600 / v_rt)::integer or not coalesce((r ->> 'done')::boolean, false)
           or (r ->> 'pct')::integer <> 100 or (r ->> 'watched')::integer <> 600 then
          raise exception '점검 실패(%배 · %초마다 끝까지): % · 벽시계 %', v_rt, v_st, r, v_w;
        end if;
        delete from public.lec_lecture where id = v_l5;
      end loop;
    end loop;
    -- 배속 3 은 2 로 잘려 넘는 몫은 인정 안 함 · 1배 상한은 전과 같음(새 보기 150초 · 그 뒤 경과 + 30초, 적어도 90초)
    insert into public.lec_lecture (title, yt, dur, class_ids) values ('selftest', 'selftest000', 6000, '{*}') returning id into v_l5;
    v_s3 := gen_random_uuid();
    r := public.lec_beat(v_key, v_l5, v_s3, '', 1000, 0, 0, 0, 6000, 'selftest', 3);
    select rate into v_t from public.lec_session where id = v_s3;
    if (r ->> 'watched')::integer <> 270 or v_t::numeric <> 2 then raise exception '점검 실패(배속 3 새 보기): % · %', r, v_t; end if;
    update public.lec_session set ended_at = now() - interval '100 seconds' where id = v_s3;
    r := public.lec_beat(v_key, v_l5, v_s3, '', 2000, 0, 0, 0, 6000, 'selftest', 3);
    if (r ->> 'watched')::integer <> 500 then raise exception '점검 실패(배속 3 은 2배까지만): %', r; end if;
    v_s3 := gen_random_uuid();
    r := public.lec_beat(v_key, v_l5, v_s3, '', 1000, 0, 0, 0, 6000, 'selftest');
    if (r ->> 'watched')::integer <> 650 then raise exception '점검 실패(1배 새 보기): %', r; end if;
    update public.lec_session set ended_at = now() - interval '100 seconds' where id = v_s3;
    r := public.lec_beat(v_key, v_l5, v_s3, '', 2000, 0, 0, 0, 6000, 'selftest');
    if (r ->> 'watched')::integer <> 780 then raise exception '점검 실패(1배 경과 + 30): %', r; end if;
    update public.lec_session set ended_at = now() - interval '30 seconds' where id = v_s3;
    r := public.lec_beat(v_key, v_l5, v_s3, '', 3000, 0, 0, 0, 6000, 'selftest', 0.5);
    if (r ->> 'watched')::integer <> 870 then raise exception '점검 실패(1배 아래는 1배 · 적어도 90): %', r; end if;
    delete from public.lec_lecture where id = v_l5;

    -- 강의 길이를 고치면 진도(%)를 다시 계산
    update public.lec_lecture set dur = 200 where id = v_l1;
    select pct into v_i from public.lec_progress where sid = v_new and lecture_id = v_l1;
    if v_i <> 50 then raise exception '점검 실패(길이 고친 뒤 진도): %', v_i; end if;

    -- 들어가기: 잘못 넣은 번호 · 명단에 없는 이름
    r := public.lec_login('김', '12', 'selftest');
    if (r ->> 'err') is distinct from 'input' then raise exception '점검 실패(번호 확인): %', r; end if;
    r := public.lec_login('없는학생이름점검', '0000', 'selftest');
    if (r ->> 'err') is distinct from 'nomatch' then raise exception '점검 실패(없는 학생): %', r; end if;
    -- 10분 안에 5번째로 틀리면 10분 잠금 · 잠긴 동안은 번호를 보지 않음
    for v_i in 1 .. 3 loop
      r := public.lec_login('없는학생이름점검', '0000', 'selftest');
    end loop;
    r := public.lec_login('없는학생 이름점검', '0000', 'selftest');
    if (r ->> 'err') is distinct from 'locked' or (r ->> 'secs')::integer <> 600 or (r ->> 'day')::boolean then
      raise exception '점검 실패(10분 잠금): %', r;
    end if;
    r := public.lec_login('없는학생이름점검', '0000', 'selftest');
    if (r ->> 'err') is distinct from 'locked' or (r ->> 'secs')::integer not between 1 and 600 then
      raise exception '점검 실패(잠긴 동안): %', r;
    end if;
    select count(*) into v_n from public.lec_fail where who = 'n:없는학생이름점검';
    if v_n <> 5 then raise exception '점검 실패(잠긴 동안 실패를 셈): %', v_n; end if;

    -- 예약 공개: 공개일이 내일이면 오늘은 안 보이고, 공개일이 되면 보임
    insert into public.lec_lecture (title, yt, dur, class_ids, posted_on)
    values ('selftest', 'selftest000', 100, '{*}', (now() at time zone 'Asia/Seoul')::date + 1) returning id into v_l3;
    r := public.lec_beat(v_key, v_l3, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
    if (r ->> 'err') is distinct from 'lecture' then raise exception '점검 실패(예약 공개 강의가 미리 보임): %', r; end if;
    update public.lec_lecture set posted_on = (now() at time zone 'Asia/Seoul')::date where id = v_l3;
    r := public.lec_beat(v_key, v_l3, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(공개일이 된 강의): %', r; end if;

    -- 명단에서 사라진 학생: 열쇠는 남기고 볼 수 있는 반만 비움(그 뒤로는 «전체» 강의도 못 봄)
    r := public.lec_home(v_key);
    if (r ->> 'err') is distinct from 'gone' then raise exception '점검 실패(명단에 없는 학생): %', r; end if;
    select cardinality(cls) into v_n from public.lec_key where kh = public.lec__kh(v_key);
    if v_n <> 0 then raise exception '점검 실패(반 비우기): %', v_n; end if;
    r := public.lec_beat(v_key, v_l2, v_s2, '1111111111', 60, 100, 0, 100, 100, 'selftest');
    if (r ->> 'err') is distinct from 'lecture' then raise exception '점검 실패(명단에 없는 학생의 «전체» 강의): %', r; end if;

    -- 선생님 함수: 로그인 안 한 부름은 막고, 원장(benjamin@his.kr)은 할 일 · 확인 · 되돌리기 · 기록 지우기
    perform set_config('request.jwt.claims', '', true);
    r := public.lec_todo();
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(로그인 없이 할 일): %', r; end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"joey@his.kr"}', true);
    r := public.lec_forget(v_new);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(관리자 아닌 기록 지우기): %', r; end if;
    r := public.lec_unlock('selftest-rid|없는학생이름점검');
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(내 반 아닌 잠금 풀기): %', r; end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);
    r := public.lec_todo();
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'behind') <> 'array' then
      raise exception '점검 실패(할 일): %', r;
    end if;
    if not exists (select 1 from jsonb_array_elements(r -> 'left') e where e ->> 'skey' = v_new) then
      raise exception '점검 실패(그만둔 학생 기록): %', r -> 'left';
    end if;
    if jsonb_typeof(r -> 'locked') is distinct from 'array' then raise exception '점검 실패(잠긴 학생 묶음): %', r; end if;
    -- 잠금 풀기: 명단에 없는 이름의 잠금(n:)도 관리자는 지울 수 있음
    r := public.lec_unlock('  ');
    if (r ->> 'err') is distinct from 'input' then raise exception '점검 실패(잠금 풀기 입력): %', r; end if;
    r := public.lec_unlock('selftest-rid|없는학생이름점검');
    if (r ->> 'cleared')::integer is distinct from 5 then raise exception '점검 실패(잠금 풀기 개수): %', r; end if;
    select count(*) into v_n from public.lec_fail where who = 'n:없는학생이름점검';
    if v_n <> 0 then raise exception '점검 실패(잠금 풀기 뒤 남음): %', v_n; end if;
    r := public.lec_confirm(v_l3, v_new, '  교실에서 워크북 확인  ');
    if (r ->> 'done_by') is distinct from 'Benjamin' or (r ->> 'done_note') is distinct from '교실에서 워크북 확인' then
      raise exception '점검 실패(선생님 확인): %', r;
    end if;
    select done_at, done_by into v_ts, v_t from public.lec_progress where sid = v_new and lecture_id = v_l3;
    if v_ts is not null or v_t is distinct from 'Benjamin' then raise exception '점검 실패(확인과 자동 완료가 섞임)'; end if;
    insert into public.lec_lecture (title, yt, dur, class_ids) values ('selftest', 'selftest000', 100, '{*}') returning id into v_l4;
    r := public.lec_confirm(v_l4, v_new, '기록 오류');
    select count(*) into v_n from public.lec_progress where sid = v_new and lecture_id = v_l4 and pct = 0 and done_by = 'Benjamin';
    if v_n <> 1 then raise exception '점검 실패(줄 없을 때 0%% 줄): %', r; end if;
    r := public.lec_unconfirm(v_l4, v_new);
    select count(*) into v_n from public.lec_progress where sid = v_new and lecture_id = v_l4;
    if v_n <> 0 then raise exception '점검 실패(되돌리기 뒤 빈 줄 남음)'; end if;

    -- 학생 기기(선생님 함수): 목록에 열쇠·해시·번호 없음 · 개인 링크는 해시만 저장 · 모든 기기에서 로그아웃
    r := public.lec_keys();
    if not coalesce((r ->> 'ok')::boolean, false)
       or not exists (select 1 from jsonb_array_elements(r -> 'items') e where e ->> 'sid' = v_new and e ->> 'sname' = '김점검둘') then
      raise exception '점검 실패(기기 목록): %', r;
    end if;
    if exists (select 1 from jsonb_array_elements(r -> 'items') e where e ? 'kh' or e ? 'key' or e ? 'pin') then
      raise exception '점검 실패(기기 목록에 열쇠·번호가 보임)';
    end if;
    select t.skey into v_sk from public.lec__roster() t order by t.skey collate "C" limit 1;
    r := public.lec_link(v_sk);
    v_k2 := r ->> 'key';
    if not coalesce((r ->> 'ok')::boolean, false) or v_k2 !~ '^[0-9a-f]{64}$' then raise exception '점검 실패(개인 링크): %', r; end if;
    select count(*) into v_n from public.lec_key
     where kh = public.lec__kh(v_k2) and sid = v_sk and made_by = 'Benjamin' and dev = '개인 링크' and pin = '';
    if v_n <> 1 then raise exception '점검 실패(개인 링크 저장)'; end if;
    select count(*) into v_n from public.lec_key where kh = v_k2;
    if v_n <> 0 then raise exception '점검 실패(개인 링크 열쇠가 그대로 저장됨)'; end if;
    r := public.lec_home(v_k2);
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(개인 링크로 들어가기): %', r; end if;
    r := public.lec_home(public.lec__kh(v_k2));
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(개인 링크 해시로 들어가기): %', r; end if;
    r := public.lec_link('selftest-rid|없는학생이름점검');
    if (r ->> 'err') is distinct from 'nomatch' then raise exception '점검 실패(명단에 없는 학생 링크): %', r; end if;
    r := public.lec_link('  ');
    if (r ->> 'err') is distinct from 'input' then raise exception '점검 실패(링크 입력): %', r; end if;
    r := public.lec_logout_all(v_new);
    if (r ->> 'n')::integer is distinct from 1 then raise exception '점검 실패(모든 기기 로그아웃): %', r; end if;
    r := public.lec_home(v_key);
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(로그아웃 뒤 들어가기): %', r; end if;

    -- 선생님이 아닌 로그인 계정(다른 주소) · user_metadata 이름을 «Benjamin» 으로 바꾼 계정은 선생님 함수를 못 씀
    perform set_config('request.jwt.claims',
      '{"role":"authenticated","email":"selftest-outsider@gmail.com","user_metadata":{"name":"Benjamin"}}', true);
    if public.lec__is_staff() then raise exception '점검 실패(다른 주소 계정이 선생님)'; end if;
    r := public.lec_todo();
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(선생님 아닌 할 일): %', r; end if;
    r := public.lec_keys();
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(선생님 아닌 기기 목록): %', r; end if;
    r := public.lec_link(v_sk);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(선생님 아닌 개인 링크): %', r; end if;
    r := public.lec_logout_all(v_sk);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(선생님 아닌 로그아웃): %', r; end if;
    r := public.lec_forget(v_new);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(선생님 아닌 기록 지우기): %', r; end if;
    perform set_config('request.jwt.claims',
      '{"role":"authenticated","email":"selftest-mallory@his.kr","user_metadata":{"name":"Benjamin"}}', true);
    select s.name, s.admin::text into v_t, v_k2 from public.lec__staff() s;
    if v_t is distinct from 'selftest-mallory' or v_k2 is distinct from 'false' then
      raise exception '점검 실패(가입 이름으로 관리자 흉내): % · %', v_t, v_k2;
    end if;
    r := public.lec_forget(v_new);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(가입 이름으로 기록 지우기): %', r; end if;

    -- 표 정책: 실제 로그인 역할(authenticated)로 바꿔 봄(바꿀 수 없는 곳이면 건너뜀)
    select count(*) into v_cnt from public.lec_lecture;
    v_role := false;
    begin
      set local role authenticated;
      v_role := true;
    exception when others then
      v_role := false;
    end;
    if v_role then
      perform set_config('request.jwt.claims', '{"role":"authenticated","email":"selftest-outsider@gmail.com"}', true);
      select count(*) into v_n from public.lec_lecture;
      if v_n <> 0 then raise exception '점검 실패(선생님 아닌 계정이 강의 표를 읽음): %', v_n; end if;
      update public.lec_lecture set title = title where id = v_l1;
      get diagnostics v_n = row_count;
      if v_n <> 0 then raise exception '점검 실패(선생님 아닌 계정이 강의 표를 고침)'; end if;
      begin
        insert into public.lec_lecture (title, yt, dur, class_ids) values ('selftest', 'selftest000', 100, '{*}');
        raise exception '점검 실패(선생님 아닌 계정이 강의를 넣음)';
      exception when insufficient_privilege then null;
      end;
      begin
        select count(*) into v_n from public.lec_key;
        raise exception '점검 실패(선생님 아닌 계정이 열쇠 표를 읽음)';
      exception when insufficient_privilege then null;
      end;
      perform set_config('request.jwt.claims', '{"role":"authenticated","email":"joey@his.kr"}', true);
      select count(*) into v_n from public.lec_lecture;
      if v_n <> v_cnt then raise exception '점검 실패(선생님이 강의 표를 못 읽음): % · %', v_n, v_cnt; end if;
      begin
        select count(*) into v_n from public.lec_key;
        raise exception '점검 실패(선생님이 열쇠 표를 읽음)';
      exception when insufficient_privilege then null;
      end;
      reset role;
    end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);

    r := public.lec_forget(v_new);
    if (r ->> 'progress')::integer <> 3 or (r ->> 'questions')::integer <> 2 then
      raise exception '점검 실패(기록 지우기 개수): %', r;
    end if;
    select (select count(*) from public.lec_progress where sid = v_new) + (select count(*) from public.lec_session where sid = v_new)
         + (select count(*) from public.lec_qna where sid = v_new) + (select count(*) from public.lec_consent where sid = v_new)
         + (select count(*) from public.lec_key where sid = v_new)
      into v_n;
    if v_n <> 0 then raise exception '점검 실패(기록 지우기 뒤 남음): %', v_n; end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- 속 함수(lec__ · 표 정책이 부르는 lec__is_staff 와 트리거 함수는 빼고)는 밖에서 못 부르게 한 번 더 거둠(C2 검수 L-4):
--   예전 설치에 남은 옛 꼴 속 함수 · 기본 권한으로 열린 속 함수가 아래 권한 점검에 걸려 설치를 멈추지 않게
--   routine 으로 거둠 = lec__ 이름의 프로시저가 있어도 멈추지 않음(마지막 검수 L-3 · function 으로 쓰면 프로시저에서 오류)
do $$
declare
  v_f regprocedure;
begin
  for v_f in
    select p.oid::regprocedure
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
  loop
    execute format('revoke all on routine %s from public, anon, authenticated', v_f);
  end loop;
end
$$;

-- 스스로 점검(C1 결석한 날 수업): 출결 규칙을 가짜 묶음으로(실제 히즈북스 데이터는 읽기만) · 열쇠 · 권한.
-- 점검용으로 넣은 강의 · 열쇠는 끝에 되돌려 남지 않습니다
do $$
declare
  r     jsonb;
  v_t   text;
  v_n   integer;
  v_l   uuid;
  v_key text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_c1  jsonb := '{"id":"c1","schedule":{"days":["화","수","금","월"],"times":{"화":{"start":"18:00","end":"19:30"},"수":{"start":"18:00","end":"19:30"},"금":{"start":"18:00","end":"19:30"},"월":{"start":"18:00","end":"19:30"}}},'
                   '"students":[{"id":"s1","name":"가","registeredAt":"2025.03.01"},{"id":"s2","name":"나"},{"id":"s3","name":"다","pending":true},'
                   '{"id":"s4","name":"라","startPlan":"2026-11-12"}]}';
  v_c2  jsonb := '{"id":"c2","schedule":{"3":"16:00","end":"17:30"},"students":[{"id":"s1","name":"가","registeredAt":"2025.03.01"}]}';
  v_p   jsonb;
  v_q   jsonb;
  v_m   jsonb;
  v_main jsonb;
  v_l1  uuid;
  v_l2  uuid;
  v_l3  uuid;
  v_l4  uuid;
  v_l5  uuid;
  v_l6  uuid;
  v_ka  text;
  v_kb  text;
  v_u   text;
  v_key2 text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
begin
  begin
    -- 날짜 글자(앱 _dnumRaw)
    if public.lec__dnum('2026-11-1') <> '2026.11.01' or public.lec__dnum(' 2026/1/05 ') <> '2026.01.05'
       or public.lec__dnum('2026.11') <> '' or public.lec__dnum('0.1.1') <> '' or public.lec__dnum('abc') <> ''
       or public.lec__dnum(null) <> '' or public.lec__dnum('2026.123.4x') <> '2026.23.04' then
      raise exception '점검 실패(날짜 글자)';
    end if;
    -- 반 시간표(앱 _classStart · _classEnd): 요일 목록 · 옛 숫자 칸 · 반 시작 시각 · 날짜별 휴강 · 보강 · 지운 것
    v_t := public.lec__ctime(v_c1, 2, '2026.11.10', '{}', false) || '/' || public.lec__ctime(v_c1, 2, '2026.11.10', '{}', true)
        || '/' || public.lec__ctime(v_c1, 4, '2026.11.12', '{}', false)
        || '/' || public.lec__ctime(v_c2, 3, '2026.11.11', '{}', false) || '/' || public.lec__ctime(v_c2, 3, '2026.11.11', '{}', true)
        || '/' || public.lec__ctime(v_c2, 2, '2026.11.10', '{}', false)
        || '/' || public.lec__ctime('{"id":"c3","schedule":{"days":["화"]},"startTime":"20:00"}', 2, '2026.11.10', '{}', false)
        || '/' || public.lec__ctime(v_c1, 2, '2026.11.10', '{"c1|2026.11.10":{"off":1}}', false)
        || '/' || public.lec__ctime(v_c1, 4, '2026.11.12', '{"c1|2026.11.12":{"start":"15:00","end":"16:00"}}', false)
        || '/' || public.lec__ctime(v_c1, 4, '2026.11.12', '{"c1|2026.11.12":{"start":"15:00","end":"16:00"}}', true)
        || '/' || public.lec__ctime(v_c1, 2, '2026.11.10', '{"c1|2026.11.10":{"off":1,"del":1}}', false);
    if v_t is distinct from '18:00/19:30//16:00/17:30//20:00//15:00/16:00/18:00' then
      raise exception '점검 실패(반 시간표): %', v_t;
    end if;
    if not public.lec__closed('["2026.11.13"]', '2026.11.13') or not public.lec__closed('{"2026.11.13":{"v":1}}', '2026.11.13')
       or public.lec__closed('{"2026.11.13":{"v":0}}', '2026.11.13') or public.lec__closed(null, '2026.11.13') then
      raise exception '점검 실패(휴원일)';
    end if;

    -- 출결(앱 autoAttendance + 일지 기록): 오늘 = 2026-11-16(월) 20:00
    v_p := jsonb_build_object(
      'classes', jsonb_build_array(v_c1, v_c2),
      'rec', '{"c1|s2|2026.11.10":{"attendance":"결석"}}'::jsonb,
      'ck',  '{"s1|2026.11.10":{"in":"17:55"},"s2|2026.11.10":{"in":"17:58"},"s1|2026.11.13":{"in":"18:10","del":1}}'::jsonb,
      'nse', '{"s2|2026.11.12":{"reason":"병원"}}'::jsonb,
      'ses', '{}'::jsonb,
      'mk',  '{"s1|2026.11.14":{"from":"2026.11.11"},"s2|2026.11.11":{"from":"2026.11.05"}}'::jsonb,
      'cd',  '["2026.11.13"]'::jsonb);
    select string_agg(a.o_rid || '@' || a.o_cid || ':' || to_char(a.o_day, 'MMDD') || '=' || a.o_att || case when a.o_mk then '+' else '' end,
                      ' ' order by a.o_rid collate "C", a.o_cid collate "C", a.o_day)
      into v_t
      from public.lec__att_core(v_p, array['s1', 's1', 's2', 's3', 's4'], array['c1', 'c2', 'c1', 'c1', 'c1'],
                                '{"c1":["2026-11-10","2026-11-11","2026-11-12","2026-11-13","2026-11-16","2026-11-17"],
                                  "c2":["2026-11-17","2026-11-16","2026-11-13","2026-11-12","2026-11-11","2026-11-10","2026-11-10"]}'::jsonb,
                                '2026-11-16', '20:00') as a;
    if v_t is distinct from ('s1@c1:1110=in s1@c1:1111=abs+ s1@c1:1112= s1@c1:1113= s1@c1:1116=abs'
           || ' s1@c2:1110=in s1@c2:1111=abs+ s1@c2:1112= s1@c2:1113= s1@c2:1116='
           || ' s2@c1:1110=abs s2@c1:1111=sub s2@c1:1112=abs s2@c1:1113= s2@c1:1116=abs'
           || ' s3@c1:1110= s3@c1:1111= s3@c1:1112= s3@c1:1113= s3@c1:1116='
           || ' s4@c1:1110= s4@c1:1111= s4@c1:1112= s4@c1:1113= s4@c1:1116=abs') then
      raise exception '점검 실패(출결 규칙): %', v_t;
    end if;
    -- 오늘 수업이 아직 안 끝남 · 휴원일이라도 그 반 보강 수업이 열림 · 2026.07.15 앞은 자동 결석 없음 · 일지 기록이 먼저(빈 칸은 자동)
    v_q := v_p || jsonb_build_object('ses', '{"c1|2026.11.13":{"start":"17:00","end":"18:00"}}'::jsonb,
                                     'rec', '{"c1|s1|2026.11.11":{"attendance":""},"c1|s1|2026.11.10":{"attendance":"지각"},"c1|s1|2026.07.15":{"attendance":"출석"}}'::jsonb);
    select string_agg(to_char(a.o_day, 'MMDD') || '=' || a.o_att, ' ' order by a.o_day)
      into v_t
      from public.lec__att_core(v_q, array['s1'], array['c1'],
                                '{"c1":["2026-07-14","2026-07-15","2026-11-10","2026-11-11","2026-11-13","2026-11-16"]}'::jsonb,
                                '2026-11-16', '19:00') as a;
    if v_t is distinct from '0714= 0715=in 1110=in 1111=abs 1113=abs 1116=' then
      raise exception '점검 실패(출결 규칙 2): %', v_t;
    end if;
    -- 반마다 받은 날만 계산(받은 날이 없는 반 · 모양이 틀린 칸은 줄 없음)
    select count(*)::integer into v_n
      from public.lec__att_core(v_p, array['s1', 's1', 's2'], array['c1', 'c2', 'c1'],
                                '{"c1":["2026-11-10"],"c2":"2026-11-10"}'::jsonb, '2026-11-16', '20:00') as a;
    if v_n <> 2 then raise exception '점검 실패(반마다 수업일): %', v_n; end if;

    -- 묶음 읽기는 아무 학생이 없어도 빈 묶음
    r := public.lec__att_data('{}'::jsonb, array['selftest-none'], array[(now() at time zone 'Asia/Seoul')::date]);
    if jsonb_typeof(r -> 'rec') is distinct from 'object' or r -> 'rec' is distinct from '{}'::jsonb
       or r -> 'ck' is distinct from '{}'::jsonb then
      raise exception '점검 실패(출결 묶음): %', left(r::text, 200);
    end if;

    -- 수업일마다 반(lesson_cls): 적힌 날만 그 반 · 빈 목록 · 빈 글자 · 모양이 틀린 칸 · 없음 = null(강의의 모든 반)
    if public.lec__lcls('{"2026-11-11":["cB"]}', '2026-11-11') is distinct from array['cB']
       or public.lec__lcls('{"2026-11-11":["cB"]}', '2026-11-10') is not null
       or public.lec__lcls('{"2026-11-11":[]}', '2026-11-11') is not null
       or public.lec__lcls('{"2026-11-11":[""]}', '2026-11-11') is not null
       or public.lec__lcls('{"2026-11-11":"cB"}', '2026-11-11') is not null
       or public.lec__lcls('{}', '2026-11-11') is not null
       or public.lec__lcls(null, '2026-11-11') is not null then
      raise exception '점검 실패(수업일마다 반)';
    end if;

    -- 받은 main 으로 읽는 명단 · 반 목록이 표를 읽는 lec__roster · lec__classes 와 같은지(실제 데이터로)
    select a.data into v_main from public.app_state a where a.id = 'main';
    if (select coalesce(string_agg(r1.skey || '/' || r1.rid || '/' || coalesce(r1.sname, '') || '/'
                                   || array_to_string(array(select x from unnest(r1.cls) as x order by x collate "C"), ','),
                                   ';' order by r1.skey collate "C", r1.rid collate "C"), '')
          from public.lec__roster() r1)
       is distinct from
       (select coalesce(string_agg(r2.skey || '/' || r2.rid || '/' || coalesce(r2.sname, '') || '/'
                                   || array_to_string(array(select x from unnest(r2.cls) as x order by x collate "C"), ','),
                                   ';' order by r2.skey collate "C", r2.rid collate "C"), '')
          from public.lec__ros(v_main) r2) then
      raise exception '점검 실패(명단 읽기 두 가지가 다름)';
    end if;
    if (select coalesce(string_agg(k1.id || '/' || k1.name || '/' || k1.owner, ';'
                                   order by k1.id collate "C", k1.name collate "C", k1.owner collate "C"), '')
          from public.lec__classes() k1)
       is distinct from
       (select coalesce(string_agg(k2.id || '/' || k2.name || '/' || k2.owner, ';'
                                   order by k2.id collate "C", k2.name collate "C", k2.owner collate "C"), '')
          from public.lec__cls(v_main) k2) then
      raise exception '점검 실패(반 목록 읽기 두 가지가 다름)';
    end if;

    -- 학생 · 선생님 계산을 가짜 main · 정한 날(2026-11-16 월 20:00)로 끝까지(lec_att · lec_att_staff 가 부르는 그 함수)
    --   A반 화·수 · B반 수 · L1 = A반만(11.10 · 11.11) · L2 = A·B반(11.10 은 A반 · 11.11 은 B반이 들음) · L3 = A·B반(반 안 적음)
    --   가 = A반 · 11.10 등원 · 11.11 등원 없음 / 나 = B반 · 등원 없음
    v_m := jsonb_build_object('classes', jsonb_build_array(
             '{"id":"selftest-cA","name":"점검A반","owner":"점검","schedule":{"days":["화","수"],"times":{"화":{"start":"18:00","end":"19:30"},"수":{"start":"18:00","end":"19:30"}}},"students":[{"id":"selftest-sa","name":"점검가","registeredAt":"2025.03.01"}]}'::jsonb,
             '{"id":"selftest-cB","name":"점검B반","owner":"점검","schedule":{"days":["수"],"times":{"수":{"start":"18:00","end":"19:30"}}},"students":[{"id":"selftest-sb","name":"점검나","registeredAt":"2025.03.01"}]}'::jsonb),
           'checkins', '{"selftest-sa|2026.11.10":{"in":"17:55"}}'::jsonb);
    select r1.skey into v_ka from public.lec__ros(v_m) r1 where r1.rid = 'selftest-sa';
    select r1.skey into v_kb from public.lec__ros(v_m) r1 where r1.rid = 'selftest-sb';
    if v_ka is null or v_kb is null then raise exception '점검 실패(가짜 명단)'; end if;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, posted_on)
    values ('selftest-m1', 'selftest000', 100, '{selftest-cA}', '2026-11-10', '{2026-11-11}', '2026-11-01')
    returning id into v_l1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, posted_on, lesson_cls)
    values ('selftest-m2', 'selftest000', 100, '{selftest-cA,selftest-cB}', '2026-11-10', '{2026-11-11}', '2026-11-01',
            '{"2026-11-10":["selftest-cA"],"2026-11-11":["selftest-cB"]}')
    returning id into v_l2;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, posted_on)
    values ('selftest-m3', 'selftest000', 100, '{selftest-cA,selftest-cB}', '2026-11-10', '{2026-11-11}', '2026-11-01')
    returning id into v_l3;

    -- 학생: 가 = L1 결석(11.11) · L2 들음(11.10 만 수업일) · L3 결석 / 나 = L1 없음 · L2 결석(11.11 만) · L3 결석
    v_u := '';
    foreach v_t in array array[v_ka, v_kb] loop
      r := public.lec__att_one(v_m, v_t, '2026-11-16', '20:00');
      if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'items') is distinct from 'array' then
        raise exception '점검 실패(학생 출결 계산): %', left(r::text, 300);
      end if;
      v_u := v_u || '|' || coalesce((select string_agg(y.s, ' ' order by y.s collate "C")
                                       from (select case x.value ->> 'id' when v_l1::text then 'L1' when v_l2::text then 'L2' else 'L3' end
                                                    || '=' || coalesce(x.value ->> 'att', '?') || '@' || coalesce(x.value ->> 'day', '?')
                                                    || coalesce((x.value -> 'days')::text, '?')
                                                    || case when coalesce((x.value ->> 'mk')::boolean, false) then '+' else '' end as s
                                               from jsonb_array_elements(r -> 'items') as x
                                              where x.value ->> 'id' in (v_l1::text, v_l2::text, v_l3::text)) y), '');
    end loop;
    if v_u is distinct from '|L1=abs@2026-11-11["2026-11-10", "2026-11-11"] L2=in@2026-11-10["2026-11-10"] L3=abs@2026-11-11["2026-11-10", "2026-11-11"]'
                         || '|L2=abs@2026-11-11["2026-11-11"] L3=abs@2026-11-11["2026-11-10", "2026-11-11"]' then
      raise exception '점검 실패(학생 출결 · 수업일마다 반): %', v_u;
    end if;
    -- 명단에 없는 학생 = 빈 목록
    r := public.lec__att_one(v_m, 'selftest-none|없음', '2026-11-16', '20:00');
    if not coalesce((r ->> 'ok')::boolean, false) or r -> 'items' is distinct from '[]'::jsonb then
      raise exception '점검 실패(학생 출결 · 명단 밖): %', left(r::text, 200);
    end if;

    -- 선생님: L2 칸 = 가 들음 · 나 결석 / 띠 = L1 A반 가 · L2 B반 나(가는 없음) · L3 A반 가 · B반 나 / 학생 수 2
    r := public.lec__att_staff_one(v_m, array['selftest-cA', 'selftest-cB'],
                                   '{"selftest-cA":"점검A반","selftest-cB":"점검B반"}', '2026-11-16', '20:00');
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'lectures') is distinct from 'array'
       or jsonb_typeof(r -> 'band' -> 'items') is distinct from 'array' or r -> 'notstarted' is distinct from '[]'::jsonb then
      raise exception '점검 실패(선생님 출결 계산): %', left(r::text, 300);
    end if;
    select coalesce(string_agg(y.s, ' ' order by y.s collate "C"), '') into v_t
      from (select case x.value ->> 'l' when v_l1::text then 'L1' when v_l2::text then 'L2' else 'L3' end
                   || ':in=' || coalesce((x.value -> 'in')::text, '?')
                   || ':abs=' || coalesce((select string_agg((z.value ->> 's') || '@' || (z.value ->> 'd')
                                                             || case when coalesce((z.value ->> 'mk')::boolean, false) then '+' else '' end,
                                                             ',' order by z.value ->> 's' collate "C")
                                             from jsonb_array_elements(x.value -> 'abs') as z), '') as s
              from jsonb_array_elements(r -> 'lectures') as x
             where x.value ->> 'l' in (v_l1::text, v_l2::text, v_l3::text)) y;
    v_t := replace(replace(v_t, v_ka, 'ga'), v_kb, 'na');
    if v_t is distinct from 'L1:in=[]:abs=ga@2026-11-11 L2:in=["ga"]:abs=na@2026-11-11 L3:in=[]:abs=ga@2026-11-11,na@2026-11-11' then
      raise exception '점검 실패(선생님 칸 · 수업일마다 반): %', v_t;
    end if;
    select coalesce(string_agg(y.s, ' ' order by y.s collate "C"), '') into v_t
      from (select case x.value ->> 'lecture' when v_l1::text then 'L1' when v_l2::text then 'L2' else 'L3' end
                   || ':' || coalesce(x.value ->> 'cname', '?') || ':' || coalesce(x.value ->> 'day', '?')
                   || ':' || coalesce(x.value ->> 'n', '?') || ':' || coalesce((x.value -> 'names')::text, '?') as s
              from jsonb_array_elements(r -> 'band' -> 'items') as x
             where x.value ->> 'lecture' in (v_l1::text, v_l2::text, v_l3::text)) y;
    if v_t is distinct from 'L1:점검A반:2026-11-11:1:["점검가"] L2:점검B반:2026-11-11:1:["점검나"] L3:점검A반:2026-11-11:1:["점검가"] L3:점검B반:2026-11-11:1:["점검나"]'
       or (r -> 'band' ->> 'n') is distinct from '2' then
      raise exception '점검 실패(선생님 띠 · 수업일마다 반): % / %', v_t, r -> 'band' ->> 'n';
    end if;
    -- 내 반이 없는 선생님 = 빈 결과
    r := public.lec__att_staff_one(v_m, '{}', '{}', '2026-11-16', '20:00');
    if r -> 'lectures' is distinct from '[]'::jsonb or r -> 'band' ->> 'n' is distinct from '0' then
      raise exception '점검 실패(선생님 · 반 없음): %', left(r::text, 200);
    end if;

    -- «전체»(*) 강의(11-17 결석 카드 고침): 학생 카드 · 선생님 칸 · 띠가 같은 규칙
    --   L4 = «전체»만 · 반 안 적음 → 어느 반의 수업일도 아님(가 · 나 · 선생님 칸 · 띠 모두 없음)
    --   L5 = «전체»만 · 11.10 A반 · 11.11 B반 적음 → 적힌 반만 / L6 = «전체» + A반 · 반 안 적음 → 실제 반(A반)만
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, posted_on)
    values ('selftest-m4', 'selftest000', 100, '{*}', '2026-11-10', '{2026-11-11}', '2026-11-01')
    returning id into v_l4;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, posted_on, lesson_cls)
    values ('selftest-m5', 'selftest000', 100, '{*}', '2026-11-10', '{2026-11-11}', '2026-11-01',
            '{"2026-11-10":["selftest-cA"],"2026-11-11":["selftest-cB"]}')
    returning id into v_l5;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, posted_on)
    values ('selftest-m6', 'selftest000', 100, '{*,selftest-cA}', '2026-11-10', '{2026-11-11}', '2026-11-01')
    returning id into v_l6;
    v_u := '';
    foreach v_t in array array[v_ka, v_kb] loop
      r := public.lec__att_one(v_m, v_t, '2026-11-16', '20:00');
      v_u := v_u || '|' || coalesce((select string_agg(y.s, ' ' order by y.s collate "C")
                                       from (select case x.value ->> 'id' when v_l4::text then 'L4' when v_l5::text then 'L5' else 'L6' end
                                                    || '=' || coalesce(x.value ->> 'att', '?') || '@' || coalesce(x.value ->> 'day', '?')
                                                    || coalesce((x.value -> 'days')::text, '?')
                                                    || case when coalesce((x.value ->> 'mk')::boolean, false) then '+' else '' end as s
                                               from jsonb_array_elements(r -> 'items') as x
                                              where x.value ->> 'id' in (v_l4::text, v_l5::text, v_l6::text)) y), '');
    end loop;
    if v_u is distinct from '|L5=in@2026-11-10["2026-11-10"] L6=abs@2026-11-11["2026-11-10", "2026-11-11"]'
                         || '|L5=abs@2026-11-11["2026-11-11"]' then
      raise exception '점검 실패(학생 출결 · «전체» 강의): %', v_u;
    end if;
    r := public.lec__att_staff_one(v_m, array['selftest-cA', 'selftest-cB'],
                                   '{"selftest-cA":"점검A반","selftest-cB":"점검B반"}', '2026-11-16', '20:00');
    select coalesce(string_agg(y.s, ' ' order by y.s collate "C"), '') into v_t
      from (select case x.value ->> 'l' when v_l4::text then 'L4' when v_l5::text then 'L5' else 'L6' end
                   || ':in=' || coalesce((x.value -> 'in')::text, '?')
                   || ':abs=' || coalesce((select string_agg((z.value ->> 's') || '@' || (z.value ->> 'd')
                                                             || case when coalesce((z.value ->> 'mk')::boolean, false) then '+' else '' end,
                                                             ',' order by z.value ->> 's' collate "C")
                                             from jsonb_array_elements(x.value -> 'abs') as z), '') as s
              from jsonb_array_elements(r -> 'lectures') as x
             where x.value ->> 'l' in (v_l4::text, v_l5::text, v_l6::text)) y;
    v_t := replace(replace(v_t, v_ka, 'ga'), v_kb, 'na');
    if v_t is distinct from 'L5:in=["ga"]:abs=na@2026-11-11 L6:in=[]:abs=ga@2026-11-11' then
      raise exception '점검 실패(선생님 칸 · «전체» 강의): %', v_t;
    end if;
    select coalesce(string_agg(y.s, ' ' order by y.s collate "C"), '') into v_t
      from (select case x.value ->> 'lecture' when v_l4::text then 'L4' when v_l5::text then 'L5' else 'L6' end
                   || ':' || coalesce(x.value ->> 'cname', '?') || ':' || coalesce(x.value ->> 'day', '?')
                   || ':' || coalesce(x.value ->> 'n', '?') || ':' || coalesce((x.value -> 'names')::text, '?') as s
              from jsonb_array_elements(r -> 'band' -> 'items') as x
             where x.value ->> 'lecture' in (v_l4::text, v_l5::text, v_l6::text)) y;
    if v_t is distinct from 'L5:점검B반:2026-11-11:1:["점검나"] L6:점검A반:2026-11-11:1:["점검가"]'
       or (r -> 'band' ->> 'n') is distinct from '2' then
      raise exception '점검 실패(선생님 띠 · «전체» 강의): % / %', v_t, r -> 'band' ->> 'n';
    end if;

    -- 새 칸(여러 수업일 · 실행기 묶음)
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more, runner)
    values ('selftest', 'selftest000', 100, '{*}', (now() at time zone 'Asia/Seoul')::date,
            array[(now() at time zone 'Asia/Seoul')::date - 1], '{"days":["2026-11-13"],"items":[]}')
    returning id into v_l;
    select cardinality(lesson_more) into v_n from public.lec_lecture where id = v_l;
    if v_n <> 1 then raise exception '점검 실패(여러 수업일 칸)'; end if;

    -- 학생 함수: 없는 열쇠 = key · 명단에 없는 학생 열쇠 = 빈 목록
    r := public.lec_att(v_key);
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(출결 · 없는 열쇠): %', r; end if;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_key), 'selftest-c1|점검', 'selftest-c1', '1234', '점검', '{c-selftest}');
    r := public.lec_att(v_key);
    if not coalesce((r ->> 'ok')::boolean, false) or r -> 'items' is distinct from '[]'::jsonb then
      raise exception '점검 실패(출결 · 명단 밖 학생): %', r;
    end if;
    -- 실제 명단 첫 학생 열쇠로 lec_att 를 끝까지(실제 강의 · 실제 출결로 계산이 오류 없이 도는지 · 결과 모양)
    select r1.skey into v_t from public.lec__roster() r1 order by r1.skey collate "C" limit 1;
    if v_t is not null then
      insert into public.lec_key (kh, sid, rid, pin, sname, cls)
      values (public.lec__kh(v_key2), v_t, split_part(v_t, '|', 1), '0000', '점검', '{}');
      r := public.lec_att(v_key2);
      if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'items') is distinct from 'array' then
        raise exception '점검 실패(출결 · 실제 학생): %', left(r::text, 300);
      end if;
    end if;

    -- 선생님 함수: 로그인 안 함 = forbidden · 원장 = 실제 명단으로 끝까지 계산
    perform set_config('request.jwt.claims', '', true);
    r := public.lec_att_staff();
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(출결 · 선생님 아님): %', r; end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);
    r := public.lec_att_staff();
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'lectures') is distinct from 'array'
       or jsonb_typeof(r -> 'notstarted') is distinct from 'array' or jsonb_typeof(r -> 'band' -> 'items') is distinct from 'array'
       or (r -> 'band' ->> 'n') is null then
      raise exception '점검 실패(출결 · 원장): %', left(r::text, 300);
    end if;
    perform set_config('request.jwt.claims', '', true);

    -- 권한: 학생 함수는 누구나 · 선생님 함수는 로그인한 사람만
    if not has_function_privilege('anon', 'public.lec_att(text)', 'execute')
       or has_function_privilege('anon', 'public.lec_att_staff()', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_att_staff()', 'execute') then
      raise exception '점검 실패(출결 함수 권한)';
    end if;
    -- 속 함수(public 의 lec__ 로 시작하는 함수 전부 · 표 정책이 부르는 lec__is_staff 와 트리거 함수는 빼고)는
    --   anon · authenticated 가 직접 못 부름(함수 안에서만) · 함수가 늘어도 여기서 걸림
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- C3 · C7 (11-16) 지문 줄 · 종이 자리 · 멈추고 풀기
-- 학생 화면: 내가 볼 수 있는 강의마다 실행기 묶음(runner)의 지문 줄 = [{no, at, stop, wb}]
--   판서 쪽(board)은 학생에게 보이지 않으므로 보내지 않음 · 줄이 없는 강의는 빠짐 · 위 함수들은 그대로
--   (lec_home 이 runner 를 보내지 않아 따로 묻는 함수 · 이 함수가 없는 서버면 학생 화면은 종이 줄 · 멈춤 판을 숨김)
--   새로 만든 함수라 정확한 모양으로 먼저 지우고 새로 만듦(돌려주는 모양이 바뀌어도 설치가 멈추지 않게 · 권한은 바로 아래에서 다시 줌)
drop function if exists public.lec_paper(text);
create or replace function public.lec_paper(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_items jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'p', x.p) order by x.id), '[]'::jsonb)
    into v_items
    from (
      select l.id,
             (select coalesce(jsonb_agg(jsonb_build_object(
                        'no',   left(coalesce(e ->> 'no', ''), 40),
                        'at',   case when jsonb_typeof(e -> 'at') = 'number' then e -> 'at' else 'null'::jsonb end,
                        'stop', case when jsonb_typeof(e -> 'stop') = 'number' then e -> 'stop' else 'null'::jsonb end,
                        'wb',   left(coalesce(e ->> 'wb', ''), 40)) order by e_o), '[]'::jsonb)
                from jsonb_array_elements(case when jsonb_typeof(l.runner -> 'items') = 'array'
                                               then l.runner -> 'items' else '[]'::jsonb end) with ordinality as t(e, e_o)
               where jsonb_typeof(e) = 'object') as p
        from public.lec_lecture l
       where public.lec__open(l, k.cls)
         and not public.lec__ended(l)   -- 끝난 강의는 플레이어를 열지 않으므로 지문 줄도 안 보냄(검수 B2 L-8)
         and (case when jsonb_typeof(l.runner -> 'items') = 'array'
                   then jsonb_array_length(l.runner -> 'items') else 0 end) > 0
    ) x;
  return jsonb_build_object('ok', true, 'items', v_items);
end
$$;

revoke all on function public.lec_paper(text) from public;
grant execute on function public.lec_paper(text) to anon, authenticated;

-- 스스로 점검(C3 · C7 지문 줄): 없는 열쇠 · 열린 강의만 · 판서 쪽 안 보냄 · 멈춤 빈 칸 · 권한.
-- 점검용으로 넣은 강의 · 열쇠는 끝에 되돌려 남지 않습니다
do $$
declare
  r     jsonb;
  v_n   integer;
  v_a   uuid;
  v_b   uuid;
  v_c   uuid;
  v_d   uuid;
  v_e   uuid;
  v_f   uuid;
  v_p   jsonb;
  v_key text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_cls text := 'c-selftest-c3' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_today date := (now() at time zone 'Asia/Seoul')::date;
begin
  begin
    r := public.lec_paper(v_key);
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(지문 줄 · 없는 열쇠): %', r; end if;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_key), 'selftest-c3|점검', 'selftest-c3', '1234', '점검', array[v_cls]);

    -- 줄이 있는 열린 강의(판서 쪽 · 멈춤 빈 칸 · 숫자 아닌 시각 · 글자 줄 섞음)
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, runner)
    values ('selftest-c3a', 'selftest000', 3000, array[v_cls], v_today,
            '{"start":"19:02","days":[],"items":[{"no":"ANALYSIS","at":11,"stop":16,"board":1,"wb":"ANALYSIS"},'
            '{"no":"01","at":25,"stop":625,"board":2,"wb":"01"},{"no":"02","at":634,"stop":null,"board":3,"wb":"5-6"},'
            '{"no":"03","at":"x","stop":1700,"board":4,"wb":"3,5"},"bad"]}')
    returning id into v_a;
    -- 줄 없는 강의 · 숨긴 강의 · 아직 안 올린 강의 · 다른 반 강의 = 빠짐
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, runner)
    values ('selftest-c3b', 'selftest000', 100, array[v_cls], v_today, '{}') returning id into v_b;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, hidden, runner)
    values ('selftest-c3c', 'selftest000', 100, array[v_cls], v_today, true,
            '{"items":[{"no":"01","at":0,"stop":100,"wb":"01"}]}') returning id into v_c;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, runner)
    values ('selftest-c3d', 'selftest000', 100, array[v_cls], v_today, v_today + 1,
            '{"items":[{"no":"01","at":0,"stop":100,"wb":"01"}]}') returning id into v_d;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, runner)
    values ('selftest-c3e', 'selftest000', 100, array[v_cls || '-other'], v_today,
            '{"items":[{"no":"01","at":0,"stop":100,"wb":"01"}]}') returning id into v_e;
    -- 공개 끝 날짜가 지난 강의 = 빠짐(검수 B2 L-8)
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, until, runner)
    values ('selftest-c3f', 'selftest000', 100, array[v_cls], v_today - 3, v_today - 1,
            '{"items":[{"no":"01","at":0,"stop":100,"wb":"01"}]}') returning id into v_f;

    r := public.lec_paper(v_key);
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'items') is distinct from 'array' then
      raise exception '점검 실패(지문 줄 · 열린 강의): %', left(r::text, 300);
    end if;
    select count(*) into v_n from jsonb_array_elements(r -> 'items') as t(x)
     where (x ->> 'id')::uuid in (v_b, v_c, v_d, v_e, v_f);
    if v_n <> 0 then raise exception '점검 실패(지문 줄 · 빠져야 할 강의 %건)', v_n; end if;
    select x -> 'p' into v_p from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'id')::uuid = v_a;
    if v_p is null or jsonb_array_length(v_p) <> 4 then
      raise exception '점검 실패(지문 줄 · 줄 수): %', v_p;
    end if;
    if v_p::text like '%board%' or (r::text) like '%"board"%' then
      raise exception '점검 실패(지문 줄 · 판서 쪽이 나감)';
    end if;
    -- 칸이 빠져 NULL 이 되어도 잡히게 is distinct from(검수 B2 L-7)
    if (v_p -> 0 ->> 'no') is distinct from 'ANALYSIS' or (v_p -> 1 ->> 'at')::numeric is distinct from 25
       or (v_p -> 1 ->> 'stop')::numeric is distinct from 625
       or (v_p -> 1 ->> 'wb') is distinct from '01' or jsonb_typeof(v_p -> 2 -> 'stop') is distinct from 'null'
       or (v_p -> 2 ->> 'wb') is distinct from '5-6'
       or jsonb_typeof(v_p -> 3 -> 'at') is distinct from 'null' or (v_p -> 3 ->> 'wb') is distinct from '3,5' then
      raise exception '점검 실패(지문 줄 · 칸): %', v_p;
    end if;

    -- 반이 빈 열쇠(명단에서 빠진 학생) = 빈 목록
    update public.lec_key set cls = '{}' where kh = public.lec__kh(v_key);
    r := public.lec_paper(v_key);
    if not coalesce((r ->> 'ok')::boolean, false) or (r -> 'items') is distinct from '[]'::jsonb then
      raise exception '점검 실패(지문 줄 · 반 없음): %', left(r::text, 300);
    end if;

    -- 권한: 학생 함수는 누구나(열쇠로만 열림)
    if not has_function_privilege('anon', 'public.lec_paper(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_paper(text)', 'execute') then
      raise exception '점검 실패(지문 줄 함수 권한)';
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- C2 (11-16) 학교 시험 D-day · 시험 범위 영상
-- 학교 · 학년 · 시험마다 한 줄(모든 선생님이 같이 씀): 시험 날짜 · 범위 강의 · 받는 학생(명단 학생 id = rid)
--   시험 날짜는 선생님 화면이 히즈북스 학교 시험 일정(examSchool · examSchoolG)에서 읽어 넘김 → 시험 일정(examSchool)은 서버가 읽지 않음
--   (선생님 함수가 읽는 app_state 는 받는 학생 거르기 명단 lec__roster · 반 lec__classes · 선생님 확인 lec__staff 뿐 ·
--    학생 함수 lec_range_me 는 app_state 를 읽지 않음)
--   학생 화면은 lec_range_me 로 «내 rid(또는 학생 열쇠)가 든 줄 · 보이기 시작한 날(시험 20일 전) ~ 시험 끝 날»만 받음
--   school_key = 앱 _schoolKey · grade = '1'~'6' · term = 학년도-학기-종류(예: 2026-2-기말 · 앱 class-api.js examName)
--   rids = 명단 학생 id(같은 id 를 두 학생이 쓰면 그 학생의 학생 열쇠 rid|맞춘 이름) · off = 학교 시험 일정에서 빠진 줄
--   rule_ver = 이 줄을 마지막으로 맞춘 화면의 규칙 판(class-api.js RNG_VER) · 더 낮은 판 화면은 날짜 · 이름 · 켜고 끄기를 못 바꿈
--   src_t = 이 줄이 따른 학교 시험 일정의 고친 시각(examSchool · examSchoolG 의 t 중 큰 값) · 더 옛 일정을 본 화면은 못 되돌림
create table if not exists public.lec_range (
  id          uuid primary key default gen_random_uuid(),
  school_key  text not null,
  grade       text not null,
  term        text not null,
  name        text not null default '',
  school_nm   text not null default '',
  exam_on     date not null,
  end_on      date not null,
  show_on     date not null,
  rids        text[] not null default '{}',
  lecture_ids uuid[] not null default '{}',
  off         boolean not null default false,
  saved_by    text not null default '',
  saved_at    timestamptz not null default now(),
  synced_at   timestamptz,
  rule_ver    integer not null default 1,
  src_t       bigint not null default 0
);
alter table public.lec_range add column if not exists rule_ver integer not null default 1;
alter table public.lec_range add column if not exists src_t bigint not null default 0;
create unique index if not exists lec_range_key on public.lec_range (school_key, grade, term);
create index if not exists lec_range_end on public.lec_range (end_on);

-- 권한: 선생님은 표를 읽기만(정책 lec_staff) · 쓰기는 함수(lec_range_save · lec_range_sync)로만 · 학생(로그인 없음)은 lec_range_me 로만
revoke all on public.lec_range from public, anon, authenticated;
grant select on public.lec_range to authenticated;
alter table public.lec_range enable row level security;
drop policy if exists lec_staff on public.lec_range;
create policy lec_staff on public.lec_range for all to authenticated
  using ((select public.lec__is_staff())) with check ((select public.lec__is_staff()));

-- 다시 돌려도 되게: 같은 모양으로 먼저 지우고 새로 만듦
drop function if exists public.lec__date(text);
drop function if exists public.lec__range_json(public.lec_range);
drop function if exists public.lec_range_me(text);
drop function if exists public.lec_range_staff();
drop function if exists public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text);
drop function if exists public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint);
drop function if exists public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint);
drop function if exists public.lec_range_sync(jsonb);
drop function if exists public.lec_range_sync(jsonb, integer);
drop function if exists public.lec__range_ok();

-- 'YYYY-MM-DD' 글자 → 날짜(없는 날 · 다른 꼴 · 2000~2100 밖 = 빈 값)
create or replace function public.lec__date(p text) returns date
language plpgsql stable set search_path = public as $$
begin
  if p is null or p !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or left(p, 4)::integer not between 2000 and 2100 then
    return null;
  end if;
  return p::date;
exception when others then
  return null;
end
$$;

-- 선생님 화면에 주는 한 줄
create or replace function public.lec__range_json(r public.lec_range) returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object(
    'id', r.id, 'school_key', r.school_key, 'grade', r.grade, 'term', r.term, 'name', r.name, 'school_nm', r.school_nm,
    'exam_on', r.exam_on, 'end_on', r.end_on, 'show_on', r.show_on,
    'rids', to_jsonb(r.rids), 'lecture_ids', to_jsonb(r.lecture_ids), 'off', r.off,
    'saved_by', r.saved_by, 'saved_at', r.saved_at, 'synced_at', r.synced_at,
    'rule_ver', r.rule_ver, 'src_t', r.src_t)
$$;

-- 받는 학생으로 넣을 수 있는 값: 명단에서 한 학생만 쓰는 rid · 모든 학생 열쇠(rid|맞춘 이름)
--   같은 rid 를 두 학생이 쓰면 그 rid 는 넣지 않음(두 학생 모두 학생 열쇠로만 받음 · 남의 범위가 섞이지 않게)
create or replace function public.lec__range_ok() returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(distinct u.x), '{}')
    from (select r.rid, r.skey, count(*) over (partition by r.rid) as n from public.lec__roster() r) r
   cross join lateral (values (case when r.n = 1 then r.rid end), (r.skey)) as u(x)
   where coalesce(u.x, '') <> ''
$$;

-- 학생 화면: 내 시험 범위 = {ok, today, items:[{id, name, exam_on, end_on, lectures:[강의 id], done}]}
--   내 rid(또는 학생 열쇠)가 든 줄 · 꺼지지 않은 줄 · 한국 시각 오늘이 show_on ~ end_on · 내가 볼 수 있는 강의(lec__open · 공개 끝 아님)만
--   같은 이름 · 시험 날 · 끝 날의 줄이 둘이면 나중에 저장한 줄만(학교 표기가 갈린 두 줄이 같은 시험을 두 번 띄우지 않게 · C2 검수 L-3)
--   저장한 뒤 올린 강의도 넣음(C2 검수 M1): 줄 저장(saved_at) 뒤에 만든 강의 · «모든 반» 강의가 아님 ·
--   수업일(가장 늦은 수업일 · 없으면 올린 날)이 시험 첫날 70일 전 ~ 시험 끝 날 전 · 내가 볼 수 있는 강의(위와 같음)
--   볼 강의가 하나도 없는 줄은 빠짐 · done = 그 강의들 중 다 본(자동 완료 또는 선생님 확인) 수 · 받는 학생 목록(rids)은 보내지 않음
create or replace function public.lec_range_me(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_rid   text;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_items jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  v_rid := coalesce(nullif(k.rid, ''), split_part(k.sid, '|', 1));
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'name', x.name, 'exam_on', x.exam_on, 'end_on', x.end_on,
           'lectures', x.lecs, 'done', x.done) order by x.exam_on, x.id), '[]'::jsonb)
    into v_items
    from (
      select g.id, g.name, g.exam_on, g.end_on,
             to_jsonb(array_agg(l.id order by coalesce(l.lesson_on, l.posted_on), l.created_at, l.id)) as lecs,
             count(p.lecture_id) filter (where p.done_at is not null or p.done_by is not null) as done
        from (select distinct on (r.name, r.exam_on, r.end_on) r.*
                from public.lec_range r
               where not r.off
                 and v_today between r.show_on and r.end_on
                 and ((v_rid <> '' and v_rid = any (r.rids)) or k.sid = any (r.rids))
               order by r.name, r.exam_on, r.end_on, r.saved_at desc, r.id) g
        join public.lec_lecture l
          on l.id = any (g.lecture_ids)
          or (l.created_at > g.saved_at
              and not ('*' = any (l.class_ids))
              and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                           l.posted_on) between g.exam_on - 70 and g.end_on - 1)
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       where public.lec__open(l, k.cls)
         and not public.lec__ended(l)
       group by g.id, g.name, g.exam_on, g.end_on
    ) x;
  return jsonb_build_object('ok', true, 'today', v_today, 'items', v_items);
end
$$;

-- 선생님 화면: 끝난 지 90일이 안 된 줄 모두(꺼진 줄 포함 · 모든 선생님이 같이 봄)
create or replace function public.lec_range_staff()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_name  text;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
begin
  select s.name into v_name from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  return jsonb_build_object('ok', true, 'today', v_today, 'items', coalesce((
    select jsonb_agg(public.lec__range_json(g) order by g.exam_on, g.school_key, g.grade, g.term)
      from public.lec_range g
     where g.end_on >= v_today - 90), '[]'::jsonb));
end
$$;

-- 선생님 화면: 범위 저장(같은 학교 · 학년 · 시험이면 덮어씀) → {ok, id, item, stale} · 'forbidden' · 'input'
--   받는 학생은 lec__range_ok 에 든 값만 남김 · 강의는 있는 강의만
--   관리자가 아닌 선생님의 화면에는 «내가 볼 수 있는 강의»(내가 만든 강의 · 내 반 강의 · 전체 강의)만 넣고 빼며, 나머지는 전에 있던 대로 둠
--   (강의 목록을 정리하는 규칙일 뿐 · 선생님끼리 서로의 범위를 못 고치게 하는 장치는 아님 · 한 줄을 모든 선생님이 같이 씀)
--   시험 끝 날이 비거나 시험 날보다 앞이면 시험 날 · 31일보다 길면 'input' · show_on = 시험 날 20일 전 · 꺼진 줄은 다시 켬
--   p_ver = 화면 규칙 판 · p_t = 화면이 본 학교 시험 일정의 고친 시각 · 줄의 rule_ver · src_t 보다 낮으면(stale)
--   날짜 · 이름 · 학교 이름 · 켜고 끄기는 줄에 있던 대로 두고 강의 · 받는 학생 · 저장한 사람만 고침(C2 검수 L-1)
--   판은 지금 1 뿐이라 1까지만 적힘 · 일정 고친 시각은 «지금 + 5분»까지만 믿음(C2 검수 L-2: 화면 하나가 줄을 오래 묶지 않게)
--   «저장한 뒤 올라와 학생에게 들어가던 강의»(lec_range_me 의 M1 규칙 · 줄에 있던 받는 학생의 반에 든 강의만 · 마지막 검수 L-1)는
--   저장한 선생님이 못 보는 강의면 그대로 두고, 볼 수 있는 강의면 화면이 본 적 없는 강의(만든 시각이 p_seen 뒤)만 그대로 둠
--   p_seen = 화면이 들고 있는 강의 목록에서 가장 늦은 만든 시각(ms · 없으면 0 · 지금보다 뒤면 지금) · 화면이 본 강의는 체크한 대로 넣고 뺌(마지막 검수 L-2)
create or replace function public.lec_range_save(p_school text, p_grade text, p_term text, p_name text,
                                                 p_exam date, p_end date, p_rids text[], p_lectures uuid[],
                                                 p_school_nm text default '', p_ver integer default 1, p_t bigint default 0,
                                                 p_seen bigint default 0)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name   text;
  v_admin  boolean;
  v_school text := btrim(coalesce(p_school, ''));
  v_grade  text := btrim(coalesce(p_grade, ''));
  v_term   text := btrim(coalesce(p_term, ''));
  v_ver    integer := least(greatest(coalesce(p_ver, 1), 1), 1);
  v_t      bigint := least(greatest(coalesce(p_t, 0), 0), (extract(epoch from now()) * 1000)::bigint + 300000);
  v_seen   bigint := least(greatest(coalesce(p_seen, 0), 0), floor(extract(epoch from now()) * 1000)::bigint);
  v_end    date;
  v_ok     text[];
  v_rids   text[];
  v_mine   text[];
  v_old    uuid[];
  v_oldr   text[];
  v_rcls   text[];
  v_oldt   bigint;
  v_oldv   integer;
  v_oldat  timestamptz;
  v_oldex  date;
  v_olden  date;
  v_fresh  boolean;
  v_lecs   uuid[];
  v_row    public.lec_range;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if char_length(v_school) not between 1 and 40 or v_grade !~ '^[1-6]$' or char_length(v_term) not between 1 and 40
     or p_exam is null or p_exam < date '2000-01-01' or p_exam > date '2100-12-31'
     or coalesce(cardinality(p_rids), 0) > 2000 or coalesce(cardinality(p_lectures), 0) > 200 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_end := greatest(coalesce(p_end, p_exam), p_exam);
  if v_end > p_exam + 31 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_ok := public.lec__range_ok();
  select coalesce(array_agg(distinct t.x order by t.x), '{}') into v_rids
    from unnest(coalesce(p_rids, '{}')) as t(x)
   where t.x = any (v_ok);
  select coalesce(array_agg(c.id), '{}') into v_mine from public.lec__classes() c where c.owner = v_name;
  perform pg_advisory_xact_lock(hashtext('lec_range|' || v_school || '|' || v_grade || '|' || v_term));
  select g.lecture_ids, g.src_t, g.rule_ver, g.saved_at, g.exam_on, g.end_on, g.rids
    into v_old, v_oldt, v_oldv, v_oldat, v_oldex, v_olden, v_oldr
    from public.lec_range g
   where g.school_key = v_school and g.grade = v_grade and g.term = v_term
     for update;
  v_fresh := not found or (v_t >= v_oldt and v_ver >= v_oldv);
  -- 줄에 있던 받는 학생(rid · 학생 열쇠)의 반 = M1 강의가 실제로 학생에게 가는지 보는 기준(lec_range_me 의 lec__open 과 같은 뜻)
  select coalesce(array_agg(distinct c.x), '{}') into v_rcls
    from public.lec__roster() r
   cross join lateral unnest(r.cls) as c(x)
   where r.rid = any (coalesce(v_oldr, '{}')) or r.skey = any (coalesce(v_oldr, '{}'));
  select coalesce(array_agg(distinct l.id order by l.id), '{}') into v_lecs
    from public.lec_lecture l
   cross join lateral (
     select (v_admin or l.created_by = v_name or '*' = any (l.class_ids) or l.class_ids && v_mine) as vis,
            (v_oldat is not null and l.created_at > v_oldat
             and not l.hidden and not public.lec__ended(l) and not ('*' = any (l.class_ids))
             and l.class_ids && v_rcls
             and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                          l.posted_on) between v_oldex - 70 and v_olden - 1) as m1) f
   where (l.id = any (coalesce(p_lectures, '{}')) and f.vis)
      or (l.id = any (coalesce(v_old, '{}')) and not f.vis)
      or (f.m1 and (not f.vis or floor(extract(epoch from l.created_at) * 1000)::bigint > v_seen));
  insert into public.lec_range (school_key, grade, term, name, school_nm, exam_on, end_on, show_on,
                                rids, lecture_ids, off, saved_by, saved_at, rule_ver, src_t)
  values (v_school, v_grade, v_term, left(btrim(coalesce(p_name, '')), 40), left(btrim(coalesce(p_school_nm, '')), 40),
          p_exam, v_end, p_exam - 20, v_rids, v_lecs, false, v_name, now(), v_ver, v_t)
  on conflict (school_key, grade, term) do update set
    name     = case when v_fresh then excluded.name else lec_range.name end,
    exam_on  = case when v_fresh then excluded.exam_on else lec_range.exam_on end,
    end_on   = case when v_fresh then excluded.end_on else lec_range.end_on end,
    show_on  = case when v_fresh then excluded.show_on else lec_range.show_on end,
    off      = case when v_fresh then false else lec_range.off end,
    school_nm = case when v_fresh then excluded.school_nm else lec_range.school_nm end,
    rids = excluded.rids, lecture_ids = excluded.lecture_ids,
    saved_by = excluded.saved_by, saved_at = excluded.saved_at,
    rule_ver = case when v_fresh then excluded.rule_ver else lec_range.rule_ver end,
    src_t    = case when v_fresh then excluded.src_t else lec_range.src_t end
  returning * into v_row;
  return jsonb_build_object('ok', true, 'id', v_row.id, 'item', public.lec__range_json(v_row), 'stale', not v_fresh);
end
$$;

-- 선생님 화면이 조용히 맞추기: 학교 시험 일정이 바뀐 줄만 고침 → {ok, n} · 'forbidden' · 'input'
--   p_rows = [{id, off:true, t}(일정에서 지워짐 · 다른 시험으로 바뀜 = 끄기) | {id, exam, end, name, rids, t}(날짜 · 이름 · 받는 학생 고치기 · 다시 켜기)] · 500줄까지
--   t = 화면이 본 학교 시험 일정의 고친 시각 · p_ver = 화면 규칙 판 → 줄의 src_t · rule_ver 보다 낮으면 그 줄은 건너뜀
--   (옛 판 화면 · 옛 일정을 본 화면이 새 일정으로 맞춘 줄을 끄거나 날짜를 되돌리지 못함)
--   있는 줄만 고침(새 줄 · 강의 · 저장한 사람 · 저장 시각은 그대로 · 저장 시각은 «저장 뒤 올린 강의»의 기준이라 맞추기가 안 건드림)
--   꼴이 틀린 줄은 건너뜀 · 받는 학생은 lec__range_ok 에 든 값만 · 판은 1까지 · t 는 «지금 + 5분»까지만 믿음(C2 검수 L-2)
create or replace function public.lec_range_sync(p_rows jsonb, p_ver integer default 1)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name text;
  v_ok   text[];
  v_ver  integer := least(greatest(coalesce(p_ver, 1), 1), 1);
  v_max  bigint := (extract(epoch from now()) * 1000)::bigint + 300000;
  v_t    bigint;
  v_e    jsonb;
  v_id   uuid;
  v_exam date;
  v_end  date;
  v_n    integer := 0;
  v_c    integer;
begin
  select s.name into v_name from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  if jsonb_array_length(p_rows) > 500 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_ok := public.lec__range_ok();
  for v_e in select t.e from jsonb_array_elements(p_rows) as t(e) loop
    continue when jsonb_typeof(v_e) is distinct from 'object';
    continue when coalesce(v_e ->> 'id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    v_id := (v_e ->> 'id')::uuid;
    v_t := case when coalesce(v_e ->> 't', '') ~ '^[0-9]{1,15}$' then least((v_e ->> 't')::bigint, v_max) else 0 end;
    if public.lec__truthy(v_e -> 'off') then
      update public.lec_range set off = true, synced_at = now(),
             src_t = greatest(src_t, v_t), rule_ver = greatest(rule_ver, v_ver)
       where id = v_id and not off and rule_ver <= v_ver and src_t <= v_t;
      get diagnostics v_c = row_count;
      v_n := v_n + v_c;
      continue;
    end if;
    v_exam := public.lec__date(v_e ->> 'exam');
    continue when v_exam is null;
    v_end := greatest(coalesce(public.lec__date(v_e ->> 'end'), v_exam), v_exam);
    continue when v_end > v_exam + 31;
    update public.lec_range g set
      exam_on = v_exam, end_on = v_end, show_on = v_exam - 20,
      name = case when jsonb_typeof(v_e -> 'name') = 'string' and btrim(v_e ->> 'name') <> ''
                  then left(btrim(v_e ->> 'name'), 40) else g.name end,
      rids = case when jsonb_typeof(v_e -> 'rids') = 'array'
                  then array(select distinct t.x from jsonb_array_elements_text(v_e -> 'rids') as t(x)
                              where t.x = any (v_ok) order by t.x)
                  else g.rids end,
      off = false, synced_at = now(),
      src_t = greatest(g.src_t, v_t), rule_ver = greatest(g.rule_ver, v_ver)
     where g.id = v_id and g.rule_ver <= v_ver and g.src_t <= v_t;
    get diagnostics v_c = row_count;
    v_n := v_n + v_c;
  end loop;
  return jsonb_build_object('ok', true, 'n', v_n);
end
$$;

revoke all on function public.lec__date(text), public.lec__range_json(public.lec_range), public.lec__range_ok()
  from public, anon, authenticated;
revoke all on function public.lec_range_me(text) from public, anon, authenticated;
grant execute on function public.lec_range_me(text) to anon, authenticated;
revoke all on function public.lec_range_staff(),
                       public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint),
                       public.lec_range_sync(jsonb, integer)
  from public, anon, authenticated;
grant execute on function public.lec_range_staff(),
                          public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint),
                          public.lec_range_sync(jsonb, integer)
  to authenticated;

-- 속 함수 권한 한 번 더 거둠(위 C1 점검 앞과 같음 · C2 의 속 함수까지 · C2 검수 L-4 · routine = 마지막 검수 L-3)
do $$
declare
  v_f regprocedure;
begin
  for v_f in
    select p.oid::regprocedure
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
  loop
    execute format('revoke all on routine %s from public, anon, authenticated', v_f);
  end loop;
end
$$;

-- 스스로 점검(C2 시험 범위): 가짜 열쇠 · 강의 · 범위 줄로 학생 함수 끝까지(보이는 기간 · 내 줄 · 볼 수 있는 강의 · 다 본 수) ·
-- 선생님 함수(선생님 아님 · 저장 거르기 · 덮어쓰기 · 관리자 아닌 선생님의 강의 · 조용히 맞추기) · 권한 · 표 정책.
-- 비교는 모두 «is distinct from»(빈 값이면 실패) · 점검용으로 넣은 것은 끝에 되돌려 남지 않습니다
do $$
declare
  r      jsonb;
  v_t    text;
  v_n    integer;
  v_key  text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_sk   text := 'selftest-c2-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_cls  text := 'c-selftest-c2' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_rid  text := 'selftest-c2';
  v_sid  text := 'selftest-c2|점검';
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_a    uuid;
  v_b    uuid;
  v_c    uuid;
  v_d    uuid;
  v_e    uuid;
  v_f    uuid;
  v_g    uuid;
  v_h    uuid;
  v_m1   uuid;
  v_m2   uuid;
  v_m3   uuid;
  v_r1   uuid;
  v_r2   uuid;
  v_r8   uuid;
  v_id   uuid;
  v_rr   text;
  v_mr   text;
  v_mc   text;
  v_m4   uuid;
  v_s1   uuid;
  v_s2   uuid;
  v_key2 text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_ms   bigint := floor(extract(epoch from now()) * 1000)::bigint;
  v_row  public.lec_range;
begin
  begin
    -- 날짜 글자
    if public.lec__date('2026-11-25') is distinct from date '2026-11-25'
       or public.lec__date('2026-02-30') is not null or public.lec__date('2026-1-5') is not null
       or public.lec__date('1999-12-31') is not null or public.lec__date('x') is not null or public.lec__date(null) is not null then
      raise exception '점검 실패(C2 날짜 글자)';
    end if;

    -- 학생 함수: 없는 열쇠 = key
    r := public.lec_range_me(v_key);
    if (r ->> 'err') is distinct from 'key' or (r ->> 'ok') is distinct from 'false' then
      raise exception '점검 실패(C2 · 없는 열쇠): %', r;
    end if;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_key), v_sid, v_rid, '1234', '점검', array[v_cls]);

    -- 강의: 열린 둘(a · b) · 숨김(c) · 다른 반(d) · 공개 끝(e) · 아직 안 올림(f) · 전체 강의(g) · Joey 가 만든 강의(h)
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-c2a', 'selftest000', 100, array[v_cls], v_today - 3) returning id into v_a;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-c2b', 'selftest000', 100, array[v_cls], v_today - 2) returning id into v_b;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, hidden)
    values ('selftest-c2c', 'selftest000', 100, array[v_cls], v_today - 2, true) returning id into v_c;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-c2d', 'selftest000', 100, array[v_cls || '-other'], v_today - 2) returning id into v_d;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, until)
    values ('selftest-c2e', 'selftest000', 100, array[v_cls], v_today - 10, v_today - 1) returning id into v_e;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on)
    values ('selftest-c2f', 'selftest000', 100, array[v_cls], v_today + 1, v_today + 1) returning id into v_f;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-c2g', 'selftest000', 100, '{*}', v_today - 1) returning id into v_g;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, created_by)
    values ('selftest-c2h', 'selftest000', 100, array[v_cls], v_today - 1, 'Joey') returning id into v_h;

    -- 범위 줄: 1 보이는 기간(rid) · 2 시험 중(학생 열쇠) · 3 시험 25일 전(아직) · 4 꺼짐 · 5 다른 학생 · 6 끝남 · 7 볼 강의 없음
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-1', '1', 't', '2학기 기말', v_today + 5, v_today + 6, v_today - 15, array[v_rid],
            array[v_b, v_a, v_c, v_d, v_e, v_f]) returning id into v_r1;
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-2', '1', 't', '2학기 중간', v_today, v_today + 1, v_today - 20, array[v_sid], array[v_g])
    returning id into v_r2;
    insert into public.lec_range (school_key, grade, term, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-3', '1', 't', v_today + 25, v_today + 25, v_today + 5, array[v_rid], array[v_a]);
    insert into public.lec_range (school_key, grade, term, exam_on, end_on, show_on, rids, lecture_ids, off)
    values (v_sk || '-4', '1', 't', v_today + 5, v_today + 5, v_today - 15, array[v_rid], array[v_a], true);
    insert into public.lec_range (school_key, grade, term, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-5', '1', 't', v_today + 5, v_today + 5, v_today - 15, array['selftest-c2-other'], array[v_a]);
    insert into public.lec_range (school_key, grade, term, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-6', '1', 't', v_today - 3, v_today - 1, v_today - 23, array[v_rid], array[v_a]);
    insert into public.lec_range (school_key, grade, term, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-7', '1', 't', v_today + 5, v_today + 5, v_today - 15, array[v_rid], array[v_c, v_e]);

    r := public.lec_range_me(v_key);
    if (r ->> 'ok') is distinct from 'true'
       or coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1)
          is distinct from 2 then
      raise exception '점검 실패(C2 · 내 범위 수): %', left(r::text, 400);
    end if;
    if (r -> 'items' -> 0 ->> 'id') is distinct from v_r2::text or (r -> 'items' -> 1 ->> 'id') is distinct from v_r1::text
       or (r -> 'items' -> 1 -> 'lectures') is distinct from jsonb_build_array(v_a, v_b)
       or (r -> 'items' -> 0 -> 'lectures') is distinct from jsonb_build_array(v_g)
       or (r -> 'items' -> 1 ->> 'name') is distinct from '2학기 기말'
       or (r -> 'items' -> 1 ->> 'exam_on') is distinct from (v_today + 5)::text
       or (r -> 'items' -> 1 ->> 'end_on') is distinct from (v_today + 6)::text
       or (r -> 'items' -> 1 ->> 'done') is distinct from '0' or (r -> 'items' -> 0 ->> 'done') is distinct from '0'
       or (r ->> 'today') is distinct from v_today::text then
      raise exception '점검 실패(C2 · 내 범위 칸): %', left(r::text, 400);
    end if;
    if r::text like '%rids%' or r::text like '%saved_by%' or r::text like '%school_key%' then
      raise exception '점검 실패(C2 · 학생에게 남의 칸이 나감)';
    end if;
    -- 다 본 수: 자동 완료(b) · 반쯤(a) · 숨긴 강의 완료(c = 안 셈) · 선생님 확인(g)
    insert into public.lec_progress (sid, lecture_id, sname, pct, done_at) values (v_sid, v_b, '점검', 95, now());
    insert into public.lec_progress (sid, lecture_id, sname, pct) values (v_sid, v_a, '점검', 50);
    insert into public.lec_progress (sid, lecture_id, sname, pct, done_at) values (v_sid, v_c, '점검', 100, now());
    insert into public.lec_progress (sid, lecture_id, sname, pct, done_by, done_by_at) values (v_sid, v_g, '점검', 10, 'Joey', now());
    r := public.lec_range_me(v_key);
    if (r -> 'items' -> 1 ->> 'done') is distinct from '1' or (r -> 'items' -> 0 ->> 'done') is distinct from '1' then
      raise exception '점검 실패(C2 · 다 본 수): %', left(r::text, 400);
    end if;
    -- 저장한 뒤 올린 강의(C2 검수 M1): 줄 1 의 저장 시각을 한 시간 앞으로(점검 강의는 모두 지금 만든 것) →
    --   같은 반 h · 늦은 수업일(lesson_more)이 시험 70일 안인 m1 은 들어감 ·
    --   «모든 반» g · 시험 70일보다 이른 m2 · 시험 끝 날에 수업한 m3 · 숨김 c · 다른 반 d · 공개 끝 e · 아직 안 올린 f 는 안 들어감
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, lesson_more)
    values ('selftest-c2m1', 'selftest000', 100, array[v_cls], v_today - 66, array[v_today - 4]) returning id into v_m1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-c2m2', 'selftest000', 100, array[v_cls], v_today - 66) returning id into v_m2;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on)
    values ('selftest-c2m3', 'selftest000', 100, array[v_cls], v_today + 6, v_today) returning id into v_m3;
    update public.lec_range set saved_at = now() - interval '1 hour' where id = v_r1;
    r := public.lec_range_me(v_key);
    if (r -> 'items' -> 1 ->> 'id') is distinct from v_r1::text
       or (r -> 'items' -> 1 -> 'lectures') is distinct from jsonb_build_array(v_m1, v_a, v_b, v_h)
       or (r -> 'items' -> 0 -> 'lectures') is distinct from jsonb_build_array(v_g) then
      raise exception '점검 실패(C2 · 저장 뒤 올린 강의): %', left(r::text, 500);
    end if;
    -- 같은 이름 · 시험 날 · 끝 날의 줄이 둘(학교 표기가 갈린 두 줄)이면 나중에 저장한 줄 8 만(C2 검수 L-3)
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-8', '1', 't', '2학기 기말', v_today + 5, v_today + 6, v_today - 15, array[v_rid], array[v_a])
    returning id into v_r8;
    r := public.lec_range_me(v_key);
    if coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1) is distinct from 2
       or (r -> 'items' -> 1 ->> 'id') is distinct from v_r8::text
       or (r -> 'items' -> 1 -> 'lectures') is distinct from jsonb_build_array(v_a) then
      raise exception '점검 실패(C2 · 겹친 시험 줄): %', left(r::text, 500);
    end if;
    -- 반이 빈 열쇠(명단에서 빠진 학생) = 빈 목록
    update public.lec_key set cls = '{}' where kh = public.lec__kh(v_key);
    r := public.lec_range_me(v_key);
    if (r ->> 'ok') is distinct from 'true' or (r -> 'items') is distinct from '[]'::jsonb then
      raise exception '점검 실패(C2 · 반 없음): %', left(r::text, 300);
    end if;
    -- 학생 함수는 히즈북스 자료(app_state · pt-etc)를 읽지 않음
    select p.prosrc into v_t from pg_proc p where p.oid = 'public.lec_range_me(text)'::regprocedure;
    if v_t is null or v_t like '%app_state%' or v_t like '%pt-etc%' or v_t like '%roster%' then
      raise exception '점검 실패(C2 · 학생 함수가 히즈북스 자료를 읽음)';
    end if;

    -- 선생님 함수: 로그인 안 함 = forbidden
    perform set_config('request.jwt.claims', '', true);
    if (public.lec_range_staff() ->> 'err') is distinct from 'forbidden'
       or (public.lec_range_save(v_sk, '1', 't', 'x', v_today, null, '{}', '{}') ->> 'err') is distinct from 'forbidden'
       or (public.lec_range_sync('[]'::jsonb) ->> 'err') is distinct from 'forbidden' then
      raise exception '점검 실패(C2 · 선생님 아님)';
    end if;

    -- 원장: 저장(명단에 없는 학생은 빠짐) → 같은 학교 · 학년 · 시험은 덮어씀
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);
    -- 명단에서 한 학생만 쓰는 rid 하나(같은 rid 를 두 학생이 쓰면 그 rid 는 받는 학생으로 못 넣음)
    select t.rid into v_rr from public.lec__roster() t group by t.rid having count(*) = 1 order by t.rid limit 1;
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', ' 2학기 기말 ', v_today + 9, v_today + 11,
                               array[v_rr, 'selftest-none', 'selftest-none'], array[v_a, v_d], '점검고');
    v_id := (r ->> 'id')::uuid;
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'ok') is distinct from 'true' or v_row.id is null
       or v_row.rids is distinct from (case when v_rr is null then '{}'::text[] else array[v_rr] end)
       or v_row.lecture_ids is distinct from (select array_agg(x order by x) from unnest(array[v_a, v_d]) as u(x))
       or v_row.name is distinct from '2학기 기말' or v_row.school_nm is distinct from '점검고'
       or v_row.show_on is distinct from v_today - 11 or v_row.end_on is distinct from v_today + 11
       or v_row.saved_by is distinct from 'Benjamin' or v_row.off is distinct from false
       or (r -> 'item' ->> 'term') is distinct from '2026-2-기말' then
      raise exception '점검 실패(C2 · 저장): %', left(r::text, 400);
    end if;
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '2학기 기말', v_today + 9, v_today + 5, '{}', array[v_a]);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'id') is distinct from v_id::text or v_row.lecture_ids is distinct from array[v_a]
       or v_row.end_on is distinct from v_today + 9 or v_row.rids is distinct from '{}'::text[] then
      raise exception '점검 실패(C2 · 덮어쓰기): %', left(r::text, 400);
    end if;
    if (public.lec_range_save(v_sk, '7', 't', 'x', v_today, null, '{}', '{}') ->> 'err') is distinct from 'input'
       or (public.lec_range_save(v_sk, '1', 't', 'x', null, null, '{}', '{}') ->> 'err') is distinct from 'input'
       or (public.lec_range_save(' ', '1', 't', 'x', v_today, null, '{}', '{}') ->> 'err') is distinct from 'input'
       or (public.lec_range_save(v_sk, '1', 't', 'x', v_today, v_today + 40, '{}', '{}') ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(C2 · 저장 꼴)';
    end if;
    r := public.lec_range_staff();
    select count(*) into v_n from jsonb_array_elements(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' else '[]'::jsonb end) as t(x)
     where (x ->> 'id') = v_id::text and (x ->> 'saved_by') = 'Benjamin' and jsonb_typeof(x -> 'rids') = 'array';
    if (r ->> 'ok') is distinct from 'true' or v_n is distinct from 1 then
      raise exception '점검 실패(C2 · 선생님 목록): %', left(r::text, 300);
    end if;

    -- 관리자 아닌 선생님(Joey): 볼 수 있는 강의(h)만 넣고, 못 보는 강의(a)는 전에 있던 대로 · 못 보는 강의(d)는 못 넣음
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"joey@his.kr"}', true);
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '2학기 기말', v_today + 9, null, '{}', array[v_h, v_d]);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'ok') is distinct from 'true'
       or v_row.lecture_ids is distinct from (select array_agg(x order by x) from unnest(array[v_a, v_h]) as u(x))
       or v_row.saved_by is distinct from 'Joey' then
      raise exception '점검 실패(C2 · 선생님 강의 범위): %', left(r::text, 400);
    end if;

    -- 조용히 맞추기(원장): 꼴 · 끄기 · 다시 켜기 · 날짜 · 이름 · 받는 학생(명단만) · 강의 · 저장한 사람은 그대로
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"benjamin@his.kr"}', true);
    if (public.lec_range_sync('{}'::jsonb) ->> 'err') is distinct from 'input'
       or (public.lec_range_sync(null) ->> 'err') is distinct from 'input'
       or (public.lec_range_sync((select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'off', true))
                                    from generate_series(1, 501))) ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(C2 · 맞추기 꼴)';
    end if;
    r := public.lec_range_sync(jsonb_build_array(jsonb_build_object('id', v_id, 'off', true), 'x',
                                                 jsonb_build_object('id', 'bad', 'off', true),
                                                 jsonb_build_object('id', gen_random_uuid(), 'off', true)));
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '1' or v_row.off is distinct from true or v_row.synced_at is null then
      raise exception '점검 실패(C2 · 끄기): %', r;
    end if;
    -- 저장 시각은 «저장 뒤 올린 강의»의 기준이라 맞추기가 안 건드림(C2 검수 M1 · 한 거래 안에서는 now() 가 같아 한 시간 앞으로 옮겨 봄)
    update public.lec_range set saved_at = now() - interval '1 hour' where id = v_id;
    r := public.lec_range_sync(jsonb_build_array(
           jsonb_build_object('id', v_id, 'exam', (v_today + 10)::text, 'end', (v_today + 9)::text, 'name', '새 이름',
                              'rids', jsonb_build_array(coalesce(v_rr, 'selftest-none'), 'selftest-none')),
           jsonb_build_object('id', v_id, 'exam', '2026-02-30'),
           jsonb_build_object('id', v_id, 'exam', v_today::text, 'end', (v_today + 40)::text)));
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '1' or v_row.off is distinct from false
       or v_row.exam_on is distinct from v_today + 10 or v_row.end_on is distinct from v_today + 10
       or v_row.show_on is distinct from v_today - 10 or v_row.name is distinct from '새 이름'
       or v_row.rids is distinct from (case when v_rr is null then '{}'::text[] else array[v_rr] end)
       or v_row.lecture_ids is distinct from (select array_agg(x order by x) from unnest(array[v_a, v_h]) as u(x))
       or v_row.saved_by is distinct from 'Joey' or v_row.src_t is distinct from 0::bigint
       or v_row.rule_ver is distinct from 1 or v_row.saved_at is distinct from now() - interval '1 hour' then
      raise exception '점검 실패(C2 · 맞추기): %', r;
    end if;

    -- 옛 일정 · 옛 판 화면이 되돌리지 않음: 새 일정(t 1000)으로 맞춘 뒤에는 더 옛 t · t 없음 · 낮은 판이 끄거나 날짜를 되돌리지 못함
    r := public.lec_range_sync(jsonb_build_array(
           jsonb_build_object('id', v_id, 'exam', (v_today + 12)::text, 'end', (v_today + 12)::text, 't', 1000)));
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '1' or v_row.exam_on is distinct from v_today + 12 or v_row.src_t is distinct from 1000::bigint then
      raise exception '점검 실패(C2 · 새 일정 맞추기): %', r;
    end if;
    r := public.lec_range_sync(jsonb_build_array(
           jsonb_build_object('id', v_id, 'off', true, 't', 999),
           jsonb_build_object('id', v_id, 'off', true),
           jsonb_build_object('id', v_id, 'off', true, 't', 'x'),
           jsonb_build_object('id', v_id, 'exam', (v_today + 3)::text, 't', 500),
           jsonb_build_object('id', v_id, 'exam', (v_today + 3)::text)));
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '0' or v_row.off is distinct from false or v_row.exam_on is distinct from v_today + 12
       or v_row.src_t is distinct from 1000::bigint then
      raise exception '점검 실패(C2 · 옛 일정이 되돌림): %', r;
    end if;
    -- 같은 t 는 다시 맞춰도 됨(받는 학생만 바뀐 때) · 판은 지금 1 뿐이라 p_ver 2 로 맞춰도 줄의 판은 1(C2 검수 L-2)
    r := public.lec_range_sync(jsonb_build_array(
           jsonb_build_object('id', v_id, 'exam', (v_today + 12)::text, 'end', (v_today + 13)::text, 't', 1000)), 2);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '1' or v_row.end_on is distinct from v_today + 13 or v_row.rule_ver is distinct from 1 then
      raise exception '점검 실패(C2 · 판 상한 맞추기): %', r;
    end if;
    -- 다음 판(2)이 맞춘 줄이 있다고 치면(점검에서만 표를 바로 고침): 판 1 화면은 그 줄을 못 끄고 날짜를 못 되돌림
    update public.lec_range set rule_ver = 2 where id = v_id;
    r := public.lec_range_sync(jsonb_build_array(
           jsonb_build_object('id', v_id, 'off', true, 't', 5000),
           jsonb_build_object('id', v_id, 'exam', (v_today + 3)::text, 't', 5000)));
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '0' or v_row.off is distinct from false or v_row.exam_on is distinct from v_today + 12 then
      raise exception '점검 실패(C2 · 옛 판이 고침): %', r;
    end if;
    -- 저장도 같음: 옛 판(p_ver 1)으로 저장하면 날짜 · 이름 · 학교 이름은 그대로 · 강의만 바뀜(stale · C2 검수 L-1)
    --   (화면이 지금까지 만든 강의를 다 봄 = p_seen 지금: 한 시간 안에 받는 학생 반에 실제로 올라온 강의가 남지 않게 · 마지막 검수 L-2)
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '옛 이름', v_today + 3, null, '{}', array[v_a], '옛고', 1, 9000, v_ms);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'stale') is distinct from 'true' or v_row.exam_on is distinct from v_today + 12 or v_row.name is distinct from '새 이름'
       or v_row.school_nm is distinct from '' or v_row.lecture_ids is distinct from array[v_a] or v_row.rule_ver is distinct from 2 then
      raise exception '점검 실패(C2 · 옛 판 저장): %', left(r::text, 400);
    end if;
    -- 판을 1 로 되돌린 뒤(점검에서만) 옛 일정(p_t 10)으로 저장해도 날짜는 그대로 · 강의만 바뀜
    update public.lec_range set rule_ver = 1 where id = v_id;
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '옛 이름', v_today + 3, null, '{}', array[v_a, v_b], '옛고', 2, 10);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'stale') is distinct from 'true' or v_row.exam_on is distinct from v_today + 12 or v_row.school_nm is distinct from ''
       or v_row.lecture_ids is distinct from (select array_agg(x order by x) from unnest(array[v_a, v_b]) as u(x)) then
      raise exception '점검 실패(C2 · 옛 일정 저장): %', left(r::text, 400);
    end if;
    -- 새 일정이면 날짜 · 이름 · 학교 이름도 · p_ver 5 를 보내도 판은 1 까지만
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '새 기말', v_today + 14, null, '{}', array[v_a], '점검고', 5, 3000);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'stale') is distinct from 'false' or v_row.exam_on is distinct from v_today + 14 or v_row.name is distinct from '새 기말'
       or v_row.school_nm is distinct from '점검고' or v_row.src_t is distinct from 3000::bigint or v_row.rule_ver is distinct from 1 then
      raise exception '점검 실패(C2 · 새 일정 저장): %', left(r::text, 400);
    end if;
    -- 시계가 앞선 기기: t 는 «지금 + 5분»까지만 적힘(저장 · 맞추기 둘 다 · C2 검수 L-2)
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '새 기말', v_today + 14, null, '{}', array[v_a], '점검고', 1, 999999999999999);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'stale') is distinct from 'false'
       or v_row.src_t > (extract(epoch from now()) * 1000)::bigint + 300000 or v_row.src_t < 3000 then
      raise exception '점검 실패(C2 · 앞선 시계 저장): %', v_row.src_t;
    end if;
    update public.lec_range set src_t = 3000 where id = v_id;
    r := public.lec_range_sync(jsonb_build_array(
           jsonb_build_object('id', v_id, 'exam', (v_today + 14)::text, 't', 999999999999999)), 2);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'n') is distinct from '1'
       or v_row.src_t > (extract(epoch from now()) * 1000)::bigint + 300000 or v_row.src_t < 3000 then
      raise exception '점검 실패(C2 · 앞선 시계): %', v_row.src_t;
    end if;

    -- 관리자 아닌 선생님(Joey)이 다시 저장해도, 못 보는 강의 중 «저장 뒤 올라와 학생에게 들어가던 강의»는 그대로(C2 검수 M1) ·
    --   단 줄에 있던 받는 학생의 반에 든 강의만(마지막 검수 L-1): 명단에서 한 학생만 쓰는 rid v_mr 과 그 학생의 반 v_mc(Joey 반 아님)를 골라
    --   줄의 받는 학생을 v_mr 로 · 저장 시각을 한 시간 앞으로 → v_mc 에 올린 m4 는 남고 · a 는 전에 있던 대로 ·
    --   받는 학생 반이 아닌 점검 반 강의 b · d · f · m1 · m3 과 숨김 c · 공개 끝 e · «모든 반» g · 시험 70일보다 이른 m2 는 안 들어감
    --   (실제 강의가 섞여도 되게 «든다 · 안 든다»만 봄 · 명단이 비면 m4 없이 나머지만 봄)
    select t.rid, c.x into v_mr, v_mc
      from public.lec__roster() t
     cross join lateral unnest(t.cls) as c(x)
     where coalesce(t.rid, '') <> ''
       and t.rid in (select u.rid from public.lec__roster() u group by u.rid having count(*) = 1)
       and not exists (select 1 from public.lec__classes() k where k.id = c.x and k.owner = 'Joey')
     order by t.rid, c.x
     limit 1;
    update public.lec_range set saved_at = now() - interval '1 hour',
                                rids = case when v_mr is null then '{}'::text[] else array[v_mr] end
     where id = v_id;
    if v_mr is not null then
      insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
      values ('selftest-c2m4', 'selftest000', 100, array[v_mc], v_today - 1) returning id into v_m4;
    end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"joey@his.kr"}', true);
    r := public.lec_range_save(v_sk, '1', '2026-2-기말', '새 기말', v_today + 14, null, '{}', array[v_h]);
    select * into v_row from public.lec_range g where g.id = v_id;
    if (r ->> 'ok') is distinct from 'true'
       or not (v_row.lecture_ids @> array[v_a, v_h])
       or (v_mr is not null and not (v_row.lecture_ids @> array[v_m4]))
       or v_row.lecture_ids && array[v_b, v_c, v_d, v_e, v_f, v_g, v_m1, v_m2, v_m3] then
      raise exception '점검 실패(C2 · 선생님 저장 뒤 올린 강의): %', left(r::text, 500);
    end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"benjamin@his.kr"}', true);

    -- 화면을 연 뒤 올라온 강의 · 화면이 본 강의를 끈 저장(마지막 검수 L-2): 받는 학생 v_mr 의 반 v_mc 에
    --   s1(30분 전에 만듦 · 화면이 본 강의) · s2(10분 전에 만듦 · 화면을 연 뒤 올라온 강의)를 넣고
    --   «화면이 20분 전까지 만든 강의를 봄»(p_seen)으로 s1 · s2 를 체크하지 않고 저장 → s2 는 남아 학생에게 그대로 보이고 · s1 은 빠짐
    if v_mr is not null then
      update public.lec_range set saved_at = now() - interval '1 hour', rids = array[v_mr] where id = v_id;
      insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, created_at)
      values ('selftest-c2s1', 'selftest000', 100, array[v_mc], v_today - 1, now() - interval '30 minutes') returning id into v_s1;
      insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, created_at)
      values ('selftest-c2s2', 'selftest000', 100, array[v_mc], v_today - 1, now() - interval '10 minutes') returning id into v_s2;
      r := public.lec_range_save(v_sk, '1', '2026-2-기말', '새 기말', v_today + 14, null, array[v_mr], array[v_a], '점검고', 1, 0,
                                 floor(extract(epoch from now() - interval '20 minutes') * 1000)::bigint);
      select * into v_row from public.lec_range g where g.id = v_id;
      if (r ->> 'ok') is distinct from 'true' or not (v_row.lecture_ids @> array[v_a, v_s2])
         or v_row.lecture_ids && array[v_s1, v_b, v_d, v_f, v_m1, v_m3] then
        raise exception '점검 실패(C2 · 화면 연 뒤 올라온 강의 · 본 강의를 끄고 저장): %', left(r::text, 500);
      end if;
      insert into public.lec_key (kh, sid, rid, pin, sname, cls)
      values (public.lec__kh(v_key2), 'selftest-c2m|점검', v_mr, '1234', '점검', array[v_mc]);
      r := public.lec_range_me(v_key2);
      select count(*) into v_n
        from jsonb_array_elements(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' else '[]'::jsonb end) as t(x)
       where (x ->> 'id') = v_id::text
         and (x -> 'lectures') @> to_jsonb(array[v_s2])
         and not ((x -> 'lectures') @> to_jsonb(array[v_s1]));
      if (r ->> 'ok') is distinct from 'true' or v_n is distinct from 1 then
        raise exception '점검 실패(C2 · 화면 연 뒤 올라온 강의가 학생에게): %', left(r::text, 500);
      end if;
    end if;

    -- 받는 학생으로 넣을 수 있는 값(lec__range_ok): 한 학생만 쓰는 rid 는 모두 · 두 학생이 쓰는 rid 는 없음 · 학생 열쇠는 모두
    select count(*) into v_n
      from (select t.rid from public.lec__roster() t group by t.rid having count(*) > 1) d
     where d.rid = any (public.lec__range_ok());
    if v_n is distinct from 0 then raise exception '점검 실패(C2 · 겹친 rid 가 들어감): %', v_n; end if;
    select count(*) into v_n
      from (select t.rid from public.lec__roster() t group by t.rid having count(*) = 1) d
     where not (d.rid = any (public.lec__range_ok()));
    if v_n is distinct from 0 then raise exception '점검 실패(C2 · 하나뿐인 rid 가 빠짐): %', v_n; end if;
    select count(*) into v_n from public.lec__roster() t where not (t.skey = any (public.lec__range_ok()));
    if v_n is distinct from 0 then raise exception '점검 실패(C2 · 학생 열쇠가 빠짐): %', v_n; end if;
    perform set_config('request.jwt.claims', '', true);

    -- 권한: 학생 함수는 누구나(열쇠로만 열림) · 선생님 함수는 로그인한 사람만 · 속 함수는 아무도 · 표는 선생님 읽기만 · 행 보안
    if not has_function_privilege('anon', 'public.lec_range_me(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_me(text)', 'execute')
       or has_function_privilege('anon', 'public.lec_range_staff()', 'execute')
       or has_function_privilege('anon', 'public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint)', 'execute')
       or has_function_privilege('anon', 'public.lec_range_sync(jsonb, integer)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_staff()', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_sync(jsonb, integer)', 'execute')
       or has_function_privilege('anon', 'public.lec__date(text)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__date(text)', 'execute')
       or has_function_privilege('anon', 'public.lec__range_json(public.lec_range)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__range_json(public.lec_range)', 'execute')
       or has_function_privilege('anon', 'public.lec__range_ok()', 'execute')
       or has_function_privilege('authenticated', 'public.lec__range_ok()', 'execute') then
      raise exception '점검 실패(C2 함수 권한)';
    end if;
    -- 옛 꼴 함수(9칸 · 11칸 저장 · 1칸 맞추기)가 남지 않음
    if to_regprocedure('public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text)') is not null
       or to_regprocedure('public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint)') is not null
       or to_regprocedure('public.lec_range_sync(jsonb)') is not null then
      raise exception '점검 실패(C2 · 옛 꼴 함수가 남음)';
    end if;
    -- 속 함수 전부(C2 끝이라 C1 · C3 · C2 의 lec__ 함수를 처음 설치 때도 모두 봄 · M2 의 둘은 M2 점검이 다시 봄 · 표 정책이 부르는 lec__is_staff 와 트리거 함수는 빼고):
    --   anon · authenticated 가 직접 못 부름
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(C2 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;
    if has_table_privilege('anon', 'public.lec_range', 'select') or has_table_privilege('anon', 'public.lec_range', 'insert')
       or not has_table_privilege('authenticated', 'public.lec_range', 'select')
       or has_table_privilege('authenticated', 'public.lec_range', 'insert')
       or has_table_privilege('authenticated', 'public.lec_range', 'update')
       or has_table_privilege('authenticated', 'public.lec_range', 'delete') then
      raise exception '점검 실패(C2 표 권한)';
    end if;
    if (select c.relrowsecurity from pg_class c where c.oid = 'public.lec_range'::regclass) is distinct from true
       or not exists (select 1 from pg_policies p
                       where p.schemaname = 'public' and p.tablename = 'lec_range' and p.policyname = 'lec_staff') then
      raise exception '점검 실패(C2 표 정책)';
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- M2 (11-16) 시험 범위 강의는 시험 끝 날까지
-- 원장님 11-16 «9 바꿔»: 저장한 시험 범위에 든 강의는 «공개 끝»(until)이 지나도 그 범위의 학생에게 시험 끝 날(end_on · 한국 날짜 · 그날 포함)까지 보임
--   늘어나는 것은 그 강의의 공개 끝 하나뿐 · 숨김 · 지움 · 아직 안 올림 · 다른 반 · 다른 학교/학년(범위 줄에 없는 학생)은 그대로 막힘
--   강의 줄(until)은 안 바꿈 · 범위에서 빼거나 · 줄을 끄거나(off) 지우면 늘어난 것도 끝 · 시험 끝 다음 날 끝
--   «범위에 든 강의» = lec_range_me 와 같은 뜻: 꺼지지 않은 줄 · 내 rid 또는 학생 열쇠 · 같은 이름·시험 날·끝 날이면 나중에 저장한 줄 ·
--   줄의 강의 목록 또는 M1(줄 저장 뒤 올린 강의 · 모든 반 강의 아님 · 수업일이 시험 70일 전 ~ 끝 날 전) · 보이는 기간(show_on) 앞이어도 끝 날까지 이어서 보임
--   학생 쪽 공개 끝 판정은 모두 lec__ended_k 하나로(lec_home · lec_beat · lec_ask · lec_paper · lec_range_me) ·
--   lec_range_save 의 M1 남기기도 끝 날까지는 공개 끝이 지난 강의를 남김(다시 저장해도 학생 목록이 줄지 않게)
--   아래 여섯 함수는 앞의 정의를 글자 그대로 옮기고 공개 끝 판정만 바꾼 것(_check/class_sql_check.py 가 글자로 맞대 봄) · 권한도 같은 모양으로 다시 적음
--   선생님 쪽(lec_todo · 출결 띠 · 강의 표 «공개 끝»)은 강의 줄 그대로 봄
drop function if exists public.lec__ended_k(public.lec_lecture, public.lec_key);
drop function if exists public.lec__ext_to(public.lec_lecture, public.lec_key);

-- 이 학생에게 이 강의가 시험 범위로 늘어나는 끝 날(없으면 null) · 오늘이 그 끝 날 이하인 줄만
create or replace function public.lec__ext_to(l public.lec_lecture, k public.lec_key) returns date
language sql stable security definer set search_path = public as $$
  select max(g.end_on)
    from (select distinct on (r.name, r.exam_on, r.end_on) r.*
            from public.lec_range r
           where not r.off
             and (now() at time zone 'Asia/Seoul')::date <= r.end_on
             and ((coalesce(nullif(k.rid, ''), split_part(k.sid, '|', 1)) <> ''
                   and coalesce(nullif(k.rid, ''), split_part(k.sid, '|', 1)) = any (r.rids))
                  or k.sid = any (r.rids))
           order by r.name, r.exam_on, r.end_on, r.saved_at desc, r.id) g
   where l.id = any (g.lecture_ids)
      or (l.created_at > g.saved_at
          and not ('*' = any (l.class_ids))
          and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                       l.posted_on) between g.exam_on - 70 and g.end_on - 1)
$$;

-- 학생 쪽 공개 끝: 강의 줄의 공개 끝이 지났고 · 시험 범위로 늘어나지도 않을 때만
create or replace function public.lec__ended_k(l public.lec_lecture, k public.lec_key) returns boolean
language sql stable security definer set search_path = public as $$
  select public.lec__ended(l) and public.lec__ext_to(l, k) is null
$$;

-- 새 속 함수 둘은 밖에서 못 부름(새 함수는 처음에 누구나 부를 수 있으므로 꼭 거둠 · 위 «속 함수 권한 한 번 더 거둠»은 이 절보다 앞이라 여기서 다시)
revoke all on function public.lec__ext_to(public.lec_lecture, public.lec_key),
                       public.lec__ended_k(public.lec_lecture, public.lec_key)
  from public, anon, authenticated;

-- 첫 화면(앞 정의 그대로 · 공개 끝 = 시험 범위로 늘어난 끝 날 · 끝 판정 = lec__ended_k)
create or replace function public.lec_home(p_key text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k        public.lec_key;
  x        record;
  v_hit    boolean := false;
  v_sname  text;
  v_cls    text[];
  v_same   integer := 0;
  v_cskey  text;
  v_csname text;
  v_cpins  text[];
  v_ccls   text[];
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  for x in
    select t.skey, t.sname, t.pins, t.cls from public.lec__roster() t
     where t.skey = k.sid or (k.rid <> '' and t.rid = k.rid)
  loop
    if x.skey = k.sid then
      v_hit := true; v_sname := x.sname; v_cls := x.cls;
    else
      v_same := v_same + 1; v_cskey := x.skey; v_csname := x.sname; v_cpins := x.pins; v_ccls := x.cls;
    end if;
  end loop;
  if not v_hit and v_same = 1 then
    if k.pin <> '' and k.pin = any (coalesce(v_cpins, '{}')) then
      perform pg_advisory_xact_lock(hashtext('lec_move|' || k.sid));
      perform public.lec__move(k.sid, v_cskey, v_csname);
      v_hit := true; v_sname := v_csname; v_cls := v_ccls;
      select * into k from public.lec_key where kh = k.kh;
    end if;
  end if;
  if not v_hit then
    update public.lec_key set cls = '{}', last_at = now() where kh = k.kh;
    return jsonb_build_object('ok', false, 'err', 'gone');
  end if;
  update public.lec_key set sname = v_sname, cls = coalesce(v_cls, '{}'), last_at = now() where kh = k.kh;
  return jsonb_build_object(
    'ok', true,
    'me', jsonb_build_object('name', v_sname),
    'consent', (select jsonb_build_object('choice', c.choice, 'ver', c.ver, 'at', c.at)
                  from public.lec_consent c where c.sid = k.sid),
    'consent_ver', public.lec__consent_ver(),
    'lectures', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'title', l.title, 'book', l.book, 'yt', l.yt, 'dur', l.dur,
               'chapters', l.chapters, 'lesson_on', l.lesson_on, 'posted_on', l.posted_on,
               'until', case when e.ext > l.until then e.ext else l.until end, 'ended', public.lec__ended_k(l.*, k),
               'pct', coalesce(p.pct, 0), 'pos', coalesce(p.pos, 0), 'watched', coalesce(p.watched, 0),
               'seen', coalesce(p.seen, ''), 'first_at', p.first_at, 'last_at', p.last_at, 'done_at', p.done_at,
               'confirmed', coalesce(p.done_by is not null, false),
               'ans_new', (select count(*) from public.lec_qna a join public.lec_qna q on q.id = a.parent
                            where a.lecture_id = l.id and q.sid = k.sid and a.teacher is not null
                              and not a.stu_seen and not a.deleted and not q.deleted)
             ) order by coalesce(l.lesson_on, l.posted_on), l.created_at)
        from public.lec_lecture l
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       cross join lateral (select case when l.until is not null then public.lec__ext_to(l.*, k) end as ext) e
       where public.lec__open(l, v_cls)
    ), '[]'::jsonb));
end
$$;

-- 진도 기록(앞 정의 그대로 · 끝 판정만 lec__ended_k)
create or replace function public.lec_beat(
  p_key text, p_lecture uuid, p_session uuid, p_seen text,
  p_total integer, p_pos integer, p_from integer, p_to integer, p_dur integer, p_dev text,
  p_rate numeric default 1)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k         public.lec_key;
  l         public.lec_lecture;
  s         public.lec_session;
  v_rate    numeric := least(2, greatest(0.25, coalesce(p_rate, 1)));
  v_dur     integer;
  v_n       integer;
  v_in      text;
  v_old     text;
  v_seen    text;
  v_rows    integer;
  v_new     boolean;
  v_cap     integer;
  v_capw    integer;
  v_r       numeric;
  v_delta   integer;
  v_pct     integer;
  v_pos     integer;
  v_watched integer;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  select * into l from public.lec_lecture x
   where x.id = p_lecture and public.lec__open(x, k.cls);
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;
  if public.lec__ended_k(l, k) then return jsonb_build_object('ok', false, 'err', 'ended'); end if;
  if not public.lec__agreed(k.sid) then return jsonb_build_object('ok', false, 'err', 'no_consent'); end if;
  if p_session is null then return jsonb_build_object('ok', false, 'err', 'input'); end if;

  v_dur := coalesce(l.dur, 0);
  if v_dur <= 0 and coalesce(p_dur, 0) between 30 and 21600 then
    update public.lec_lecture set dur = p_dur where id = l.id and dur <= 0;
    v_dur := p_dur;
  end if;
  v_n  := case when v_dur > 0 then ceil(v_dur / 10.0)::integer else 0 end;
  v_in := case when coalesce(p_seen, '') ~ '^[01]*$' and char_length(coalesce(p_seen, '')) <= 2160 then coalesce(p_seen, '') else '' end;

  -- 한 번 보기(세션)
  insert into public.lec_session (id, sid, sname, lecture_id, from_s, to_s, dev, rate)
  values (p_session, k.sid, k.sname, l.id,
          greatest(coalesce(p_from, 0), 0), greatest(coalesce(p_from, 0), 0), left(coalesce(p_dev, ''), 40), v_rate)
  on conflict (id) do nothing;
  get diagnostics v_rows = row_count;
  v_new := v_rows > 0;
  select * into s from public.lec_session where id = p_session for update;
  if s.sid <> k.sid or s.lecture_id <> l.id then
    return jsonb_build_object('ok', false, 'err', 'session');
  end if;
  v_r     := greatest(1, coalesce(s.rate, 1), v_rate);
  v_capw  := case when v_new then 150 else greatest(90, (extract(epoch from (now() - s.ended_at)))::integer + 30) end;
  v_cap   := case when v_new then (120 * v_r)::integer + 30
                  else greatest(90, (extract(epoch from (now() - s.ended_at)) * v_r)::integer + 30) end;
  v_delta := least(greatest(coalesce(p_total, 0) - s.watched, 0), v_cap);
  update public.lec_session set
    started_at = case when v_new then now() - make_interval(secs => v_delta) else started_at end,
    ended_at   = now(),
    watched    = s.watched + v_delta,
    from_s     = least(s.from_s, greatest(coalesce(p_from, s.from_s), 0)),
    to_s       = greatest(s.to_s, least(coalesce(p_to, 0), 21600)),
    rate       = greatest(s.rate, v_rate)
  where id = p_session;

  -- 진도: 이번에 새로 켜지는 칸은 벽시계로 실제로 튼 시간만큼만(2배속 기준 + 가장자리 2칸)
  insert into public.lec_progress (sid, lecture_id, sname, first_at, last_at)
  values (k.sid, l.id, k.sname, now(), now())
  on conflict (sid, lecture_id) do nothing;
  select seen into v_old from public.lec_progress where sid = k.sid and lecture_id = l.id for update;
  v_seen := public.lec__or(v_old, v_in, ceil(least(v_delta, v_capw) / 5.0)::integer + 2);
  if v_n > 0 then v_seen := left(v_seen, v_n); end if;
  v_pct := public.lec__pct(v_seen, v_dur);
  v_pos := greatest(0, least(coalesce(p_pos, 0), case when v_dur > 0 then v_dur else 21600 end));
  update public.lec_progress set
    sname    = k.sname,
    seen     = v_seen,
    watched  = watched + v_delta,
    pos      = v_pos,
    pct      = v_pct,
    sessions = sessions + (case when v_new then 1 else 0 end),
    last_at  = now(),
    done_at  = coalesce(done_at, case when v_pct >= 90 then now() end)
  where sid = k.sid and lecture_id = l.id
  returning watched into v_watched;

  return jsonb_build_object('ok', true, 'pct', v_pct, 'watched', v_watched, 'done', v_pct >= 90, 'dur', v_dur, 'seen', v_seen);
end
$$;

-- 질문(앞 정의 그대로 · 끝 판정만 lec__ended_k)
create or replace function public.lec_ask(
  p_key text, p_lecture uuid, p_body text, p_at integer, p_private boolean, p_parent uuid,
  p_kind text default 'content')
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  l      public.lec_lecture;
  q      public.lec_qna;
  v_body text := btrim(coalesce(p_body, ''));
  v_kind text := coalesce(p_kind, 'content');
  v_cnt  integer;
  v_id   uuid;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then return jsonb_build_object('ok', false, 'err', 'key'); end if;
  select * into l from public.lec_lecture x
   where x.id = p_lecture and public.lec__open(x, k.cls);
  if not found then return jsonb_build_object('ok', false, 'err', 'lecture'); end if;
  if public.lec__ended_k(l, k) then return jsonb_build_object('ok', false, 'err', 'ended'); end if;
  if not public.lec__agreed(k.sid) then return jsonb_build_object('ok', false, 'err', 'no_consent'); end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 or v_kind not in ('content', 'tech') then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  select count(*) into v_cnt from public.lec_qna where sid = k.sid and created_at > now() - interval '1 hour';
  if v_cnt >= 20 then return jsonb_build_object('ok', false, 'err', 'many'); end if;
  if p_parent is not null then
    select * into q from public.lec_qna where id = p_parent and lecture_id = l.id and parent is null and not deleted;
    if not found or q.sid is distinct from k.sid then
      return jsonb_build_object('ok', false, 'err', 'parent');
    end if;
  end if;
  insert into public.lec_qna (lecture_id, parent, sid, sname, at_s, body, private, kind)
  values (l.id, p_parent, k.sid, k.sname,
          case when p_parent is null and p_at between 0 and 21600 then p_at end,
          v_body,
          case when p_parent is null then coalesce(p_private, false) else coalesce(q.private, false) end,
          case when p_parent is null then v_kind else coalesce(q.kind, 'content') end)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end
$$;

-- 지문 줄(앞 정의 그대로 · 끝 판정만 lec__ended_k)
create or replace function public.lec_paper(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_items jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'p', x.p) order by x.id), '[]'::jsonb)
    into v_items
    from (
      select l.id,
             (select coalesce(jsonb_agg(jsonb_build_object(
                        'no',   left(coalesce(e ->> 'no', ''), 40),
                        'at',   case when jsonb_typeof(e -> 'at') = 'number' then e -> 'at' else 'null'::jsonb end,
                        'stop', case when jsonb_typeof(e -> 'stop') = 'number' then e -> 'stop' else 'null'::jsonb end,
                        'wb',   left(coalesce(e ->> 'wb', ''), 40)) order by e_o), '[]'::jsonb)
                from jsonb_array_elements(case when jsonb_typeof(l.runner -> 'items') = 'array'
                                               then l.runner -> 'items' else '[]'::jsonb end) with ordinality as t(e, e_o)
               where jsonb_typeof(e) = 'object') as p
        from public.lec_lecture l
       where public.lec__open(l, k.cls)
         and not public.lec__ended_k(l.*, k)   -- 끝난 강의는 플레이어를 열지 않으므로 지문 줄도 안 보냄(검수 B2 L-8) · 시험 범위 강의는 끝 날까지(M2)
         and (case when jsonb_typeof(l.runner -> 'items') = 'array'
                   then jsonb_array_length(l.runner -> 'items') else 0 end) > 0
    ) x;
  return jsonb_build_object('ok', true, 'items', v_items);
end
$$;

-- 내 시험 범위(앞 정의 그대로 · 끝 판정만 lec__ended_k · 범위 영상 수가 공개 끝으로 줄지 않음)
create or replace function public.lec_range_me(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_rid   text;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_items jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  v_rid := coalesce(nullif(k.rid, ''), split_part(k.sid, '|', 1));
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'name', x.name, 'exam_on', x.exam_on, 'end_on', x.end_on,
           'lectures', x.lecs, 'done', x.done) order by x.exam_on, x.id), '[]'::jsonb)
    into v_items
    from (
      select g.id, g.name, g.exam_on, g.end_on,
             to_jsonb(array_agg(l.id order by coalesce(l.lesson_on, l.posted_on), l.created_at, l.id)) as lecs,
             count(p.lecture_id) filter (where p.done_at is not null or p.done_by is not null) as done
        from (select distinct on (r.name, r.exam_on, r.end_on) r.*
                from public.lec_range r
               where not r.off
                 and v_today between r.show_on and r.end_on
                 and ((v_rid <> '' and v_rid = any (r.rids)) or k.sid = any (r.rids))
               order by r.name, r.exam_on, r.end_on, r.saved_at desc, r.id) g
        join public.lec_lecture l
          on l.id = any (g.lecture_ids)
          or (l.created_at > g.saved_at
              and not ('*' = any (l.class_ids))
              and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                           l.posted_on) between g.exam_on - 70 and g.end_on - 1)
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       where public.lec__open(l, k.cls)
         and not public.lec__ended_k(l.*, k)
       group by g.id, g.name, g.exam_on, g.end_on
    ) x;
  return jsonb_build_object('ok', true, 'today', v_today, 'items', v_items);
end
$$;

-- 범위 저장(앞 정의 그대로 · M1 남기기: 공개 끝이 지난 강의도 줄의 시험 끝 날까지는 남김)
create or replace function public.lec_range_save(p_school text, p_grade text, p_term text, p_name text,
                                                 p_exam date, p_end date, p_rids text[], p_lectures uuid[],
                                                 p_school_nm text default '', p_ver integer default 1, p_t bigint default 0,
                                                 p_seen bigint default 0)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_name   text;
  v_admin  boolean;
  v_school text := btrim(coalesce(p_school, ''));
  v_grade  text := btrim(coalesce(p_grade, ''));
  v_term   text := btrim(coalesce(p_term, ''));
  v_ver    integer := least(greatest(coalesce(p_ver, 1), 1), 1);
  v_t      bigint := least(greatest(coalesce(p_t, 0), 0), (extract(epoch from now()) * 1000)::bigint + 300000);
  v_seen   bigint := least(greatest(coalesce(p_seen, 0), 0), floor(extract(epoch from now()) * 1000)::bigint);
  v_end    date;
  v_ok     text[];
  v_rids   text[];
  v_mine   text[];
  v_old    uuid[];
  v_oldr   text[];
  v_rcls   text[];
  v_oldt   bigint;
  v_oldv   integer;
  v_oldat  timestamptz;
  v_oldex  date;
  v_olden  date;
  v_fresh  boolean;
  v_lecs   uuid[];
  v_row    public.lec_range;
begin
  select s.name, s.admin into v_name, v_admin from public.lec__staff() s;
  if v_name is null then return jsonb_build_object('ok', false, 'err', 'forbidden'); end if;
  if char_length(v_school) not between 1 and 40 or v_grade !~ '^[1-6]$' or char_length(v_term) not between 1 and 40
     or p_exam is null or p_exam < date '2000-01-01' or p_exam > date '2100-12-31'
     or coalesce(cardinality(p_rids), 0) > 2000 or coalesce(cardinality(p_lectures), 0) > 200 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_end := greatest(coalesce(p_end, p_exam), p_exam);
  if v_end > p_exam + 31 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_ok := public.lec__range_ok();
  select coalesce(array_agg(distinct t.x order by t.x), '{}') into v_rids
    from unnest(coalesce(p_rids, '{}')) as t(x)
   where t.x = any (v_ok);
  select coalesce(array_agg(c.id), '{}') into v_mine from public.lec__classes() c where c.owner = v_name;
  perform pg_advisory_xact_lock(hashtext('lec_range|' || v_school || '|' || v_grade || '|' || v_term));
  select g.lecture_ids, g.src_t, g.rule_ver, g.saved_at, g.exam_on, g.end_on, g.rids
    into v_old, v_oldt, v_oldv, v_oldat, v_oldex, v_olden, v_oldr
    from public.lec_range g
   where g.school_key = v_school and g.grade = v_grade and g.term = v_term
     for update;
  v_fresh := not found or (v_t >= v_oldt and v_ver >= v_oldv);
  -- 줄에 있던 받는 학생(rid · 학생 열쇠)의 반 = M1 강의가 실제로 학생에게 가는지 보는 기준(lec_range_me 의 lec__open 과 같은 뜻)
  select coalesce(array_agg(distinct c.x), '{}') into v_rcls
    from public.lec__roster() r
   cross join lateral unnest(r.cls) as c(x)
   where r.rid = any (coalesce(v_oldr, '{}')) or r.skey = any (coalesce(v_oldr, '{}'));
  select coalesce(array_agg(distinct l.id order by l.id), '{}') into v_lecs
    from public.lec_lecture l
   cross join lateral (
     select (v_admin or l.created_by = v_name or '*' = any (l.class_ids) or l.class_ids && v_mine) as vis,
            (v_oldat is not null and l.created_at > v_oldat
             and not l.hidden and (not public.lec__ended(l.*) or (now() at time zone 'Asia/Seoul')::date <= v_olden)
             and not ('*' = any (l.class_ids))
             and l.class_ids && v_rcls
             and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                          l.posted_on) between v_oldex - 70 and v_olden - 1) as m1) f
   where (l.id = any (coalesce(p_lectures, '{}')) and f.vis)
      or (l.id = any (coalesce(v_old, '{}')) and not f.vis)
      or (f.m1 and (not f.vis or floor(extract(epoch from l.created_at) * 1000)::bigint > v_seen));
  insert into public.lec_range (school_key, grade, term, name, school_nm, exam_on, end_on, show_on,
                                rids, lecture_ids, off, saved_by, saved_at, rule_ver, src_t)
  values (v_school, v_grade, v_term, left(btrim(coalesce(p_name, '')), 40), left(btrim(coalesce(p_school_nm, '')), 40),
          p_exam, v_end, p_exam - 20, v_rids, v_lecs, false, v_name, now(), v_ver, v_t)
  on conflict (school_key, grade, term) do update set
    name     = case when v_fresh then excluded.name else lec_range.name end,
    exam_on  = case when v_fresh then excluded.exam_on else lec_range.exam_on end,
    end_on   = case when v_fresh then excluded.end_on else lec_range.end_on end,
    show_on  = case when v_fresh then excluded.show_on else lec_range.show_on end,
    off      = case when v_fresh then false else lec_range.off end,
    school_nm = case when v_fresh then excluded.school_nm else lec_range.school_nm end,
    rids = excluded.rids, lecture_ids = excluded.lecture_ids,
    saved_by = excluded.saved_by, saved_at = excluded.saved_at,
    rule_ver = case when v_fresh then excluded.rule_ver else lec_range.rule_ver end,
    src_t    = case when v_fresh then excluded.src_t else lec_range.src_t end
  returning * into v_row;
  return jsonb_build_object('ok', true, 'id', v_row.id, 'item', public.lec__range_json(v_row), 'stale', not v_fresh);
end
$$;

-- 다시 정의한 여섯의 권한(create or replace 라 그대로지만 같은 모양으로 한 번 더)
revoke all on function public.lec_home(text),
                       public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text, numeric),
                       public.lec_ask(text, uuid, text, integer, boolean, uuid, text),
                       public.lec_paper(text),
                       public.lec_range_me(text)
  from public, anon, authenticated;
grant execute on function public.lec_home(text),
                          public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text, numeric),
                          public.lec_ask(text, uuid, text, integer, boolean, uuid, text),
                          public.lec_paper(text),
                          public.lec_range_me(text)
  to anon, authenticated;
revoke all on function public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint)
  to authenticated;

-- 스스로 점검(M2 시험 끝까지 공개): 가짜 열쇠 · 강의 · 범위 줄로 «공개 끝»이 지난 범위 강의가 범위 학생에게 시험 끝 날까지 보이는지
--   (속 함수 · 진도 기록 · 질문 · 지문 줄 · 내 시험 범위 · 첫 화면) · 강의 줄은 안 바뀌는지 · 범위에서 빼거나 · 줄을 끄거나 ·
--   다른 학생 줄이거나 · 시험 다음 날이면 다시 막히는지 · 숨김 · 다른 반 · 아직 안 올림은 그대로 막히는지 · 같은 시험 두 줄이면 나중 줄 ·
--   M1(저장 뒤 올린 강의)도 늘어나고 «모든 반» 강의는 아님 · 다시 저장해도 공개 끝 M1 강의가 남는지 · 권한.
--   비교는 모두 «is distinct from»(빈 값이면 실패) · 점검용으로 넣은 것은 끝에 되돌려 남지 않습니다
do $$
declare
  r       jsonb;
  v_n     integer;
  v_t     text;
  v_mk    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_hk    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_sk    text := 'selftest-m2-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_cls   text := 'c-selftest-m2' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_rid   text := 'selftest-m2';
  v_sid   text := 'selftest-m2|점검';
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_a     uuid;
  v_b     uuid;
  v_c     uuid;
  v_d     uuid;
  v_f     uuid;
  v_g     uuid;
  v_m     uuid;
  v_h     uuid;
  v_m4    uuid;
  v_id    uuid;
  v_r1    uuid;
  v_r2    uuid;
  v_rh    uuid;
  v_rs    text;
  v_rc    text;
  v_mr    text;
  v_mc    text;
  v_l     public.lec_lecture;
  v_k     public.lec_key;
  v_row   public.lec_range;
begin
  begin
    -- 가짜 학생 열쇠(rid · 반) + 기록 동의
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_mk), v_sid, v_rid, '1234', '점검', array[v_cls]);
    r := public.lec_consent(v_mk, 'agree', public.lec__consent_ver());
    if (r ->> 'ok') is distinct from 'true' then
      raise exception '점검 실패(M2 · 동의): %', r;
    end if;

    -- 강의: 범위에 든 a(공개 끝 어제 · 지문 줄 있음) · 범위에 안 든 b(공개 끝 어제 · 지문 줄 있음) · 숨김 c · 다른 반 d · 내일 올림 f ·
    --   «모든 반» g · M1 점검용 m (c · d · g · m 도 공개 끝 어제)
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until, runner)
    values ('selftest-m2a', 'selftest000', 100, array[v_cls], v_today - 10, v_today - 10, v_today - 1,
            '{"items":[{"no":"01","at":5,"stop":20,"wb":"p.1"}]}'::jsonb) returning id into v_a;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until, runner)
    values ('selftest-m2b', 'selftest000', 100, array[v_cls], v_today - 9, v_today - 9, v_today - 1,
            '{"items":[{"no":"02","at":5,"stop":20,"wb":"p.2"}]}'::jsonb) returning id into v_b;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until, hidden)
    values ('selftest-m2c', 'selftest000', 100, array[v_cls], v_today - 8, v_today - 8, v_today - 1, true) returning id into v_c;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until)
    values ('selftest-m2d', 'selftest000', 100, array[v_cls || '-other'], v_today - 8, v_today - 8, v_today - 1) returning id into v_d;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on)
    values ('selftest-m2f', 'selftest000', 100, array[v_cls], v_today + 1, v_today + 1) returning id into v_f;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until)
    values ('selftest-m2g', 'selftest000', 100, '{*}', v_today - 8, v_today - 8, v_today - 1) returning id into v_g;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until)
    values ('selftest-m2m', 'selftest000', 100, array[v_cls], v_today - 8, v_today - 8, v_today - 1) returning id into v_m;

    -- 범위 줄 1: 시험 오늘 하루(끝 날 = 오늘) · 받는 학생 = rid · 강의 a · c · d · f
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-1', '1', 't', '2학기 기말', v_today, v_today, v_today - 20, array[v_rid], array[v_a, v_c, v_d, v_f])
    returning id into v_r1;

    -- 속 함수: a 는 공개 끝이 지났지만 오늘(시험 끝 날)까지 늘어남 · b 는 그대로 끝
    select * into v_k from public.lec_key where kh = public.lec__kh(v_mk);
    select * into v_l from public.lec_lecture where id = v_a;
    if public.lec__ended(v_l) is distinct from true
       or public.lec__ext_to(v_l, v_k) is distinct from v_today
       or public.lec__ended_k(v_l, v_k) is distinct from false then
      raise exception '점검 실패(M2 · 범위 강의가 시험 끝 날까지 안 늘어남)';
    end if;
    select * into v_l from public.lec_lecture where id = v_b;
    if public.lec__ext_to(v_l, v_k) is not null or public.lec__ended_k(v_l, v_k) is distinct from true then
      raise exception '점검 실패(M2 · 범위 밖 강의가 늘어남)';
    end if;

    -- 늘어난 동안 진도 기록 · 질문 됨 · 범위 밖 b 는 «끝» · 숨김 c · 다른 반 d · 내일 올림 f 는 범위에 있어도 «강의 없음»
    r := public.lec_beat(v_mk, v_a, gen_random_uuid(), '11111', 50, 50, 0, 50, 100, 'selftest');
    if (r ->> 'ok') is distinct from 'true' then
      raise exception '점검 실패(M2 · 늘어난 동안 진도 기록): %', r;
    end if;
    select count(*) into v_n from public.lec_progress where sid = v_sid and lecture_id = v_a and watched > 0;
    if v_n is distinct from 1 then
      raise exception '점검 실패(M2 · 진도 줄이 안 생김): %', v_n;
    end if;
    r := public.lec_ask(v_mk, v_a, '점검 질문', 10, true, null);
    if (r ->> 'ok') is distinct from 'true' then
      raise exception '점검 실패(M2 · 늘어난 동안 질문): %', r;
    end if;
    r := public.lec_beat(v_mk, v_b, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
    if (r ->> 'err') is distinct from 'ended' then
      raise exception '점검 실패(M2 · 범위 밖 강의 진도): %', r;
    end if;
    r := public.lec_ask(v_mk, v_b, '점검 질문', 10, true, null);
    if (r ->> 'err') is distinct from 'ended' then
      raise exception '점검 실패(M2 · 범위 밖 강의 질문): %', r;
    end if;
    foreach v_id in array array[v_c, v_d, v_f] loop
      r := public.lec_beat(v_mk, v_id, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
      if (r ->> 'err') is distinct from 'lecture' then
        raise exception '점검 실패(M2 · 숨김 · 다른 반 · 아직 안 올림이 열림): % %', v_id, r;
      end if;
    end loop;

    -- 내 시험 범위: 줄 1 하나 · 강의는 a 만(범위 영상 수가 줄지 않음) · 지문 줄: a 는 보내고 b 는 안 보냄
    r := public.lec_range_me(v_mk);
    if (r ->> 'ok') is distinct from 'true'
       or coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1) is distinct from 1
       or (r -> 'items' -> 0 ->> 'id') is distinct from v_r1::text
       or (r -> 'items' -> 0 -> 'lectures') is distinct from jsonb_build_array(v_a) then
      raise exception '점검 실패(M2 · 내 시험 범위): %', left(r::text, 400);
    end if;
    r := public.lec_paper(v_mk);
    if (r ->> 'ok') is distinct from 'true'
       or not exists (select 1 from jsonb_array_elements(r -> 'items') e where e ->> 'id' = v_a::text)
       or exists (select 1 from jsonb_array_elements(r -> 'items') e where e ->> 'id' = v_b::text) then
      raise exception '점검 실패(M2 · 지문 줄): %', left(r::text, 400);
    end if;

    -- 강의 줄의 공개 끝은 그대로(늘어난 것은 계산만)
    if (select l.until from public.lec_lecture l where l.id = v_a) is distinct from v_today - 1 then
      raise exception '점검 실패(M2 · 강의 줄이 바뀜)';
    end if;

    -- 줄을 끄면 끝 · 다시 켜면 늘어남
    update public.lec_range set off = true where id = v_r1;
    r := public.lec_beat(v_mk, v_a, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
    if (r ->> 'err') is distinct from 'ended' then
      raise exception '점검 실패(M2 · 꺼진 줄): %', r;
    end if;
    update public.lec_range set off = false where id = v_r1;

    -- 다른 학생 줄이면 끝 · 받는 학생이 학생 열쇠여도 늘어남
    update public.lec_range set rids = array['selftest-m2-other'] where id = v_r1;
    select * into v_l from public.lec_lecture where id = v_a;
    if public.lec__ended_k(v_l, v_k) is distinct from true then
      raise exception '점검 실패(M2 · 다른 학생 줄로 늘어남)';
    end if;
    update public.lec_range set rids = array[v_sid] where id = v_r1;
    if public.lec__ext_to(v_l, v_k) is distinct from v_today then
      raise exception '점검 실패(M2 · 학생 열쇠 줄)';
    end if;
    update public.lec_range set rids = array[v_rid] where id = v_r1;

    -- 시험이 더 뒤면 그 끝 날까지(오늘 + 5)
    update public.lec_range set exam_on = v_today + 4, end_on = v_today + 5, show_on = v_today - 16 where id = v_r1;
    if public.lec__ext_to(v_l, v_k) is distinct from v_today + 5 then
      raise exception '점검 실패(M2 · 끝 날)';
    end if;

    -- 같은 이름 · 시험 날 · 끝 날의 줄이 둘이면 나중에 저장한 줄(2 · 강의 b)만: a 는 끝 · b 는 늘어남 · 내 시험 범위도 줄 2 · b
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids, saved_at)
    values (v_sk || '-2', '1', 't', '2학기 기말', v_today + 4, v_today + 5, v_today - 16, array[v_rid], array[v_b],
            now() + interval '1 hour')
    returning id into v_r2;
    if public.lec__ext_to(v_l, v_k) is not null then
      raise exception '점검 실패(M2 · 겹친 줄의 앞 줄로 늘어남)';
    end if;
    select * into v_l from public.lec_lecture where id = v_b;
    if public.lec__ext_to(v_l, v_k) is distinct from v_today + 5 then
      raise exception '점검 실패(M2 · 겹친 줄의 나중 줄)';
    end if;
    r := public.lec_range_me(v_mk);
    if coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1) is distinct from 1
       or (r -> 'items' -> 0 ->> 'id') is distinct from v_r2::text
       or (r -> 'items' -> 0 -> 'lectures') is distinct from jsonb_build_array(v_b) then
      raise exception '점검 실패(M2 · 겹친 줄 내 시험 범위): %', left(r::text, 400);
    end if;
    delete from public.lec_range where id = v_r2;

    -- M1: 줄 저장(한 시간 전) 뒤에 올린 m 도 늘어남 · «모든 반» g 는 아님 · 내 시험 범위에도 m
    update public.lec_range set saved_at = now() - interval '1 hour' where id = v_r1;
    select * into v_l from public.lec_lecture where id = v_m;
    if public.lec__ext_to(v_l, v_k) is distinct from v_today + 5 then
      raise exception '점검 실패(M2 · 저장 뒤 올린 강의)';
    end if;
    select * into v_l from public.lec_lecture where id = v_g;
    if public.lec__ext_to(v_l, v_k) is not null then
      raise exception '점검 실패(M2 · 모든 반 강의가 늘어남)';
    end if;
    r := public.lec_range_me(v_mk);
    if not coalesce((r -> 'items' -> 0 -> 'lectures') @> jsonb_build_array(v_m), false)
       or coalesce((r -> 'items' -> 0 -> 'lectures') @> jsonb_build_array(v_g), true) then
      raise exception '점검 실패(M2 · 저장 뒤 올린 강의 내 시험 범위): %', left(r::text, 400);
    end if;
    update public.lec_range set saved_at = now() where id = v_r1;

    -- 범위에서 빼면 끝 · 볼 강의가 없는 줄은 내 시험 범위에 안 나옴
    update public.lec_range set lecture_ids = array[v_c, v_d, v_f] where id = v_r1;
    r := public.lec_beat(v_mk, v_a, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
    if (r ->> 'err') is distinct from 'ended' then
      raise exception '점검 실패(M2 · 범위에서 뺀 강의): %', r;
    end if;
    r := public.lec_range_me(v_mk);
    if coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1) is distinct from 0 then
      raise exception '점검 실패(M2 · 뺀 뒤 내 시험 범위): %', left(r::text, 400);
    end if;

    -- 시험 다음 날(끝 날 = 어제)이면 끝
    update public.lec_range set lecture_ids = array[v_a], exam_on = v_today - 1, end_on = v_today - 1, show_on = v_today - 21
     where id = v_r1;
    r := public.lec_beat(v_mk, v_a, gen_random_uuid(), '1', 10, 10, 0, 10, 100, 'selftest');
    if (r ->> 'err') is distinct from 'ended' then
      raise exception '점검 실패(M2 · 시험 다음 날): %', r;
    end if;
    r := public.lec_range_me(v_mk);
    if coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1) is distinct from 0 then
      raise exception '점검 실패(M2 · 시험 다음 날 내 시험 범위): %', left(r::text, 400);
    end if;

    -- 첫 화면(lec_home): 명단의 실제 학생 한 명의 열쇠로 · 그 학생 반의 강의 h(공개 끝 어제 · 수업일은 아주 옛날이라 다른 줄의 M1 에 안 걸림) ·
    --   그 학생이 받는 줄(끝 날 = 오늘 + 3) → 끝 아님 · 공개 끝 = 오늘 + 3 / 줄에서 빼면 끝 · 공개 끝 = 어제 (명단이 비면 건너뜀)
    select t.skey, t.cls[1] into v_rs, v_rc
      from public.lec__roster() t
     where coalesce(t.skey, '') <> '' and coalesce(t.cls[1], '') <> ''
     order by t.skey
     limit 1;
    if v_rs is not null then
      insert into public.lec_key (kh, sid, rid, pin, sname, cls)
      values (public.lec__kh(v_hk), v_rs, '', '', '점검', '{}');
      insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until)
      values ('selftest-m2h', 'selftest000', 100, array[v_rc], date '2001-01-01', date '2001-01-01', v_today - 1)
      returning id into v_h;
      insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
      values (v_sk || '-h', '1', 't', '점검 첫 화면', v_today + 2, v_today + 3, v_today - 18, array[v_rs], array[v_h])
      returning id into v_rh;
      r := public.lec_home(v_hk);
      if (r ->> 'ok') is distinct from 'true'
         or (select e ->> 'ended' from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_h::text) is distinct from 'false'
         or (select e ->> 'until' from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_h::text)
            is distinct from to_char(v_today + 3, 'YYYY-MM-DD') then
        raise exception '점검 실패(M2 · 첫 화면 늘어남): %', left(r::text, 400);
      end if;
      update public.lec_range set lecture_ids = '{}' where id = v_rh;
      r := public.lec_home(v_hk);
      if (select e ->> 'ended' from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_h::text) is distinct from 'true'
         or (select e ->> 'until' from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_h::text)
            is distinct from to_char(v_today - 1, 'YYYY-MM-DD') then
        raise exception '점검 실패(M2 · 첫 화면 뺀 뒤): %', left(r::text, 400);
      end if;
    end if;

    -- 다시 저장(관리자): 줄 저장(한 시간 전) 뒤 받는 학생의 반에 올린 m4 가 공개 끝(어제)이 지났어도 시험 끝 날 전이면 남음
    --   (명단에서 한 학생만 쓰는 rid 와 그 반을 고름 · 명단이 비면 건너뜀)
    select t.rid, c.x into v_mr, v_mc
      from public.lec__roster() t
     cross join lateral unnest(t.cls) as c(x)
     where coalesce(t.rid, '') <> ''
       and t.rid in (select u.rid from public.lec__roster() u group by u.rid having count(*) = 1)
     order by t.rid, c.x
     limit 1;
    if v_mr is not null then
      insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids, saved_at)
      values (v_sk || '-s', '1', 't', '점검 저장', v_today + 2, v_today + 3, v_today - 18, array[v_mr], '{}',
              now() - interval '1 hour');
      insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until)
      values ('selftest-m2m4', 'selftest000', 100, array[v_mc], v_today - 1, v_today - 1, v_today - 1) returning id into v_m4;
      perform set_config('request.jwt.claims', '{"role":"authenticated","email":"benjamin@his.kr"}', true);
      r := public.lec_range_save(v_sk || '-s', '1', 't', '점검 저장', v_today + 2, v_today + 3, array[v_mr], '{}');
      perform set_config('request.jwt.claims', '', true);
      select * into v_row from public.lec_range g where g.school_key = v_sk || '-s' and g.grade = '1' and g.term = 't';
      if (r ->> 'ok') is distinct from 'true' or not coalesce(v_m4 = any (v_row.lecture_ids), false) then
        raise exception '점검 실패(M2 · 다시 저장하면 공개 끝 M1 강의가 빠짐): %', left(r::text, 300);
      end if;
    end if;

    -- 권한: 새 속 함수 둘은 밖에서 못 부름 · 학생 함수는 anon · authenticated 가 부름 · 저장은 authenticated 만
    if has_function_privilege('anon', 'public.lec__ext_to(public.lec_lecture, public.lec_key)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__ext_to(public.lec_lecture, public.lec_key)', 'execute')
       or has_function_privilege('anon', 'public.lec__ended_k(public.lec_lecture, public.lec_key)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__ended_k(public.lec_lecture, public.lec_key)', 'execute')
       or not has_function_privilege('anon', 'public.lec_home(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_home(text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text, numeric)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_beat(text, uuid, uuid, text, integer, integer, integer, integer, integer, text, numeric)', 'execute')
       or not has_function_privilege('anon', 'public.lec_ask(text, uuid, text, integer, boolean, uuid, text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_ask(text, uuid, text, integer, boolean, uuid, text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_paper(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_paper(text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_range_me(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_me(text)', 'execute')
       or has_function_privilege('anon', 'public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_save(text, text, text, text, date, date, text[], uuid[], text, integer, bigint, bigint)', 'execute') then
      raise exception '점검 실패(M2 함수 권한)';
    end if;
    -- 속 함수 전부(이 절이 파일 맨 끝이라 M2 의 둘까지): anon · authenticated 가 직접 못 부름
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(M2 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- P1 (11-16) 강의 필기 PDF
-- 원장님 11-16 «PDF 결론안대로 · 단추는 제목 줄 오른쪽» · «필기본은 영상내 범위만»(자르기는 «수업 영상 만들기» 실행기 · 서랍에 끌어 넣음)
--   강의마다 필기 PDF 하나(칸은 둘까지 받음): lec_lecture.files = [{p, n, b}]
--     p = 파일 이름(내용 sha256 64자 + .pdf · 알아맞힐 수 없음 · 같은 파일은 한 번만 저장) · n = 올린 파일 이름(선생님 화면만) · b = 바이트
--   파일은 Storage 버킷 lec-pdf(공개 · 30MB · PDF 만) · 정책은 선생님(lec__is_staff)이 올리고 지우는 것 하나뿐 ·
--     anon 정책은 없음 = 목록을 볼 수 없음 → 주소(p)는 그 반 학생에게 lec_pdf 로만 감
--   학생 함수 lec_pdf: 내가 볼 수 있는 강의(lec_paper 와 같은 판정 · 끝난 강의 뺌)의 {id, f:[{p, b}]} · 올린 파일 이름(n)은 안 보냄
--     (lec_home · lec_paper 는 그대로 · 이 함수가 없는 서버면 학생 화면은 PDF 단추를 숨김)
--   끄개 · 단추 숨김: revoke execute on function public.lec_pdf(text) from anon;
--          주소 막음: update storage.buckets set public = false where id = 'lec-pdf';
--          (이 파일을 다시 넣으면 둘 다 다시 켜짐)
--   SQL Editor 계정이 Storage 표를 못 고치면(42501) 버킷 · 정책 덩어리만 건너뜀 → 맨 아래 표 «PDF 저장 곳»에 까닭이 나옴 · 그때는 대시보드:
--     ① Storage › New bucket › 이름 lec-pdf · Public bucket 켬 · Restrict file size 30 MB · Allowed MIME types application/pdf › Save
--     ② Storage › Policies › lec-pdf 의 New policy › For full customization › 이름 lec_pdf_staff ·
--        Allowed operation 넷(SELECT · INSERT · UPDATE · DELETE) 모두 · Target roles authenticated ·
--        식 bucket_id = 'lec-pdf' and (select public.lec__is_staff()) › Review › Save
--     ③ 이 파일을 다시 넣어 맨 아래 «PDF 저장 곳» 이 «됨» 인지 봄
alter table public.lec_lecture add column if not exists files jsonb not null default '[]'::jsonb;
alter table public.lec_lecture drop constraint if exists lec_lecture_files_ok;
alter table public.lec_lecture add constraint lec_lecture_files_ok check (
  case when jsonb_typeof(files) = 'array'
       then jsonb_array_length(files) <= 2
            and not jsonb_path_exists(files, 'strict $[*] ? (@.type() != "object")')
            and not jsonb_path_exists(files, 'lax $[*] ? (!(@.type() == "object" && @.p.type() == "string" && @.p like_regex "^[0-9a-f]{64}[.]pdf$" && @.n.type() == "string" && @.b.type() == "number"))')
       else false end);

-- 메모 숙제: 선생님 계정이 강의실 표를 통째로 비우거나(TRUNCATE · 정책을 안 거침) 남의 표에 걸 수 없게
revoke truncate, references, trigger on public.lec_lecture, public.lec_progress, public.lec_session, public.lec_qna from authenticated;

-- 학생: 내가 볼 수 있는 강의의 필기 PDF(주소 이름 p · 크기 b)
--   새로 만든 함수라 정확한 모양으로 먼저 지우고 새로 만듦(권한은 바로 아래에서 다시 줌)
drop function if exists public.lec_pdf(text);
create or replace function public.lec_pdf(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_items jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'f', x.f) order by x.id), '[]'::jsonb)
    into v_items
    from (
      select l.id,
             (select coalesce(jsonb_agg(jsonb_build_object(
                        'p', e ->> 'p',
                        'b', case when jsonb_typeof(e -> 'b') = 'number' then e -> 'b' else 'null'::jsonb end) order by e_o), '[]'::jsonb)
                from jsonb_array_elements(case when jsonb_typeof(l.files) = 'array'
                                               then l.files else '[]'::jsonb end) with ordinality as t(e, e_o)
               where jsonb_typeof(e) = 'object'
                 and coalesce(e ->> 'p', '') ~ '^[0-9a-f]{64}[.]pdf$') as f
        from public.lec_lecture l
       where public.lec__open(l.*, k.cls)
         and not public.lec__ended_k(l.*, k)   -- 끝난 강의는 플레이어를 열지 않으므로 PDF 도 안 보냄 · 시험 범위 강의는 끝 날까지(M2)
    ) x
   where jsonb_array_length(x.f) > 0;
  return jsonb_build_object('ok', true, 'items', v_items);
end
$$;

revoke all on function public.lec_pdf(text) from public;
grant execute on function public.lec_pdf(text) to anon, authenticated;

-- PDF 저장 곳 상태(맨 아래 표 · 점검 표 SQL 이 씀): «됨» 또는 모자란 것 · 밖에서 못 부름
drop function if exists public.lec__pdf_store();
create or replace function public.lec__pdf_store()
returns text
language plpgsql stable set search_path = public as $$
declare
  v_out  text := '';
  v_pub  boolean;
  v_lim  bigint;
  v_mime text[];
  v_n    integer;
  v_open text;
  v_err  text := coalesce(current_setting('his.lec_pdf_err', true), '');
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    return 'storage 없음';
  end if;
  begin
    execute 'select public, file_size_limit, allowed_mime_types from storage.buckets where id = $1'
       into v_pub, v_lim, v_mime using 'lec-pdf';
    get diagnostics v_n = row_count;
  exception when others then
    return '버킷을 못 읽음(' || sqlstate || ') → 대시보드';
  end;
  if v_n = 0 then
    v_out := '버킷 없음';
  elsif v_pub is distinct from true or v_lim is distinct from 31457280
        or v_mime is distinct from array['application/pdf'] then
    v_out := '버킷 설정 다름';
  end if;
  select count(*) into v_n
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects' and policyname = 'lec_pdf_staff';
  if v_n = 0 then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '정책 없음';
  end if;
  -- 누구나(anon · public) 목록을 볼 수 있는 정책(대시보드 «모두 허용» 틀 등)이 있으면 파일 이름이 다 보임
  select string_agg(policyname::text, ', ' order by policyname) into v_open
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and roles && array['anon', 'public']::name[]
     and cmd in ('SELECT', 'ALL')
     and (qual is null or qual not like '%bucket_id%' or qual like '%lec-pdf%');
  if v_open is not null then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '누구나 목록 보는 정책: ' || v_open;
  end if;
  if v_err <> '' then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || 'SQL 로 못 만듦(' || v_err || ') → 대시보드';
  end if;
  return case when v_out = '' then '됨' else v_out end;
end
$$;

revoke all on function public.lec__pdf_store() from public, anon, authenticated;

-- PDF 저장 곳 만들기(버킷 · 정책 하나) · 권한이 없으면 이 덩어리만 건너뜀(까닭은 맨 아래 표 «PDF 저장 곳»)
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'P1 · storage 표 없음(PDF 저장 곳은 대시보드에서)';
    return;
  end if;
  begin
    execute 'insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) '
         || 'values (''lec-pdf'', ''lec-pdf'', true, 31457280, array[''application/pdf'']) '
         || 'on conflict (id) do update set public = true, file_size_limit = 31457280, '
         || 'allowed_mime_types = array[''application/pdf'']';
  exception when others then
    perform set_config('his.lec_pdf_err', '버킷 ' || sqlstate, true);
    raise notice 'P1 · 버킷을 SQL 로 못 만듦(% %)', sqlstate, sqlerrm;
  end;
  begin
    execute 'drop policy if exists lec_pdf_staff on storage.objects';
    execute 'create policy lec_pdf_staff on storage.objects for all to authenticated '
         || 'using (bucket_id = ''lec-pdf'' and (select public.lec__is_staff())) '
         || 'with check (bucket_id = ''lec-pdf'' and (select public.lec__is_staff()))';
  exception when others then
    perform set_config('his.lec_pdf_err',
                       coalesce(nullif(current_setting('his.lec_pdf_err', true), '') || ' · ', '') || '정책 ' || sqlstate, true);
    raise notice 'P1 · 정책을 SQL 로 못 만듦(% %)', sqlstate, sqlerrm;
  end;
end
$$;

-- 스스로 점검(P1 필기 PDF): 없는 열쇠 · 열린 강의만 · 올린 파일 이름 안 보냄 · 틀린 files 막음 · 권한.
-- 점검용으로 넣은 강의 · 열쇠는 끝에 되돌려 남지 않습니다
do $$
declare
  r       jsonb;
  v_n     integer;
  v_a     uuid;
  v_b     uuid;
  v_c     uuid;
  v_d     uuid;
  v_e     uuid;
  v_f     uuid;
  v_g     uuid;
  v_ok    boolean;
  v_bad   jsonb;
  v_t     text;
  v_p     text := encode(sha256(convert_to('selftest-p1' || gen_random_uuid()::text, 'UTF8')), 'hex') || '.pdf';
  v_q     text := encode(sha256(convert_to('selftest-p1q' || gen_random_uuid()::text, 'UTF8')), 'hex') || '.pdf';
  v_key   text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_cls   text := 'c-selftest-p1' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_today date := (now() at time zone 'Asia/Seoul')::date;
begin
  begin
    r := public.lec_pdf(v_key);
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(P1 필기 PDF · 없는 열쇠): %', r; end if;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_key), 'selftest-p1|점검', 'selftest-p1', '1234', '점검', array[v_cls]);

    -- PDF 가 붙은 열린 강의 a · 모든 반 강의 g = 나감
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, files)
    values ('selftest-p1a', 'selftest000', 100, array[v_cls], v_today,
            jsonb_build_array(jsonb_build_object('p', v_p, 'n', '수업필기_점검_261116_120000.pdf', 'b', 1234567)))
    returning id into v_a;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, files)
    values ('selftest-p1g', 'selftest000', 100, array['*'], v_today,
            jsonb_build_array(jsonb_build_object('p', v_q, 'n', '점검.pdf', 'b', 10)))
    returning id into v_g;
    -- PDF 없는 강의 · 숨긴 강의 · 아직 안 올린 강의 · 다른 반 강의 · 공개 끝 지난 강의 = 빠짐
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-p1b', 'selftest000', 100, array[v_cls], v_today) returning id into v_b;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, hidden, files)
    values ('selftest-p1c', 'selftest000', 100, array[v_cls], v_today, true,
            jsonb_build_array(jsonb_build_object('p', v_p, 'n', '점검.pdf', 'b', 10))) returning id into v_c;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, files)
    values ('selftest-p1d', 'selftest000', 100, array[v_cls], v_today, v_today + 1,
            jsonb_build_array(jsonb_build_object('p', v_p, 'n', '점검.pdf', 'b', 10))) returning id into v_d;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, files)
    values ('selftest-p1e', 'selftest000', 100, array[v_cls || '-other'], v_today,
            jsonb_build_array(jsonb_build_object('p', v_p, 'n', '점검.pdf', 'b', 10))) returning id into v_e;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, until, files)
    values ('selftest-p1f', 'selftest000', 100, array[v_cls], v_today - 3, v_today - 1,
            jsonb_build_array(jsonb_build_object('p', v_p, 'n', '점검.pdf', 'b', 10))) returning id into v_f;

    r := public.lec_pdf(v_key);
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'items') is distinct from 'array' then
      raise exception '점검 실패(P1 · 열린 강의): %', left(r::text, 300);
    end if;
    select count(*) into v_n from jsonb_array_elements(r -> 'items') as t(x)
     where (x ->> 'id')::uuid in (v_b, v_c, v_d, v_e, v_f);
    if v_n <> 0 then raise exception '점검 실패(P1 · 빠져야 할 강의 %건)', v_n; end if;
    select count(*) into v_n from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'id')::uuid in (v_a, v_g);
    if v_n <> 2 then raise exception '점검 실패(P1 · 나가야 할 강의 %건)', v_n; end if;
    if (select x -> 'f' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'id')::uuid = v_a)
       is distinct from jsonb_build_array(jsonb_build_object('p', v_p, 'b', 1234567)) then
      raise exception '점검 실패(P1 · 칸): %', left(r::text, 300);
    end if;
    if r::text like '%수업필기%' or r::text like '%"n"%' then
      raise exception '점검 실패(P1 · 올린 파일 이름이 학생에게 나감)';
    end if;

    -- 틀린 files 는 표가 막음(주소 끼워 넣기 · 대문자 · 칸 빠짐 · 종류 다름 · 겹친 배열 · 셋 이상 · 배열 아님)
    foreach v_bad in array array[
      jsonb_build_array(jsonb_build_object('p', '../x.pdf', 'n', 'a', 'b', 1)),
      jsonb_build_array(jsonb_build_object('p', upper(v_p), 'n', 'a', 'b', 1)),
      jsonb_build_array(jsonb_build_object('p', v_p || 'x', 'n', 'a', 'b', 1)),
      jsonb_build_array(jsonb_build_object('p', v_p, 'b', 1)),
      jsonb_build_array(jsonb_build_object('p', v_p, 'n', 1, 'b', 1)),
      jsonb_build_array(jsonb_build_object('p', v_p, 'n', 'a', 'b', '1')),
      jsonb_build_array(jsonb_build_object('p', v_p, 'n', 'a')),
      jsonb_build_array('x'),
      jsonb_build_array(jsonb_build_array(jsonb_build_object('p', v_p, 'n', 'a', 'b', 1))),
      jsonb_build_array(jsonb_build_object('p', v_p, 'n', 'a', 'b', 1), jsonb_build_object('p', v_q, 'n', 'b', 'b', 2),
                        jsonb_build_object('p', v_p, 'n', 'c', 'b', 3)),
      jsonb_build_object('p', v_p, 'n', 'a', 'b', 1)
    ] loop
      v_ok := false;
      begin
        update public.lec_lecture set files = v_bad where id = v_b;
      exception when check_violation then
        v_ok := true;
      end;
      if not v_ok then raise exception '점검 실패(P1 · 틀린 files 가 들어감): %', v_bad; end if;
    end loop;
    -- 맞는 것은 들어감(둘 · 빈 배열)
    update public.lec_lecture
       set files = jsonb_build_array(jsonb_build_object('p', v_p, 'n', 'a', 'b', 1), jsonb_build_object('p', v_q, 'n', 'b', 'b', 2))
     where id = v_b;
    update public.lec_lecture set files = '[]'::jsonb where id = v_b;

    -- 반이 빈 열쇠(명단에서 빠진 학생) = 빈 목록
    update public.lec_key set cls = '{}' where kh = public.lec__kh(v_key);
    r := public.lec_pdf(v_key);
    if not coalesce((r ->> 'ok')::boolean, false) or (r -> 'items') is distinct from '[]'::jsonb then
      raise exception '점검 실패(P1 · 반 없음): %', left(r::text, 300);
    end if;

    -- 권한: 학생 함수는 누구나(열쇠로만 열림) · 상태 함수는 밖에서 못 부름 · 선생님 계정은 강의실 표를 통째로 못 비움
    if not has_function_privilege('anon', 'public.lec_pdf(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_pdf(text)', 'execute')
       or has_function_privilege('anon', 'public.lec__pdf_store()', 'execute')
       or has_function_privilege('authenticated', 'public.lec__pdf_store()', 'execute') then
      raise exception '점검 실패(P1 함수 권한)';
    end if;
    select string_agg(c.relname || ' ' || pv.p, ', ') into v_t
      from pg_class c
     cross join unnest(array['truncate', 'references', 'trigger']) as pv(p)
     where c.relnamespace = 'public'::regnamespace
       and c.relname in ('lec_lecture', 'lec_progress', 'lec_session', 'lec_qna')
       and has_table_privilege('authenticated', c.oid, pv.p);
    if v_t is not null then
      raise exception '점검 실패(P1 · 선생님 계정 표 권한): %', v_t;
    end if;
    -- 속 함수 전부(이 절이 파일 맨 끝이라 P1 의 lec__pdf_store 까지): anon · authenticated 가 직접 못 부름
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(P1 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- N1 (11-17) 새 영상 알림
-- 원장님 11-17 «업로드 되는 시간에» · «7:30를 8:00알림으로 변경»: 강의를 올리면 그 반 학생 가운데 «알림 받기»를 켠 폰(홈 화면 앱)에 알림 하나
--   강의 하나당 한 번 · 고쳐 저장해도 다시 안 감 · 숨긴 강의는 안 감(숨김을 풀면 그때 한 번 · 공개일이 3일 안일 때만) ·
--   반을 더하면 더한 반에만(공개일이 3일 안일 때만) · 아침을 기다리는 동안 숨기거나 지우면 안 감
--   때(한국 시각): 학생에게 보이게 된 때가 새벽 1시~8:00 이면 그날 아침 8:00 · 공개일이 앞날이면 그날 아침 8:00 · 그 밖은 바로(1분 안)
--     두 시각은 lec_push_cfg 의 night_from · morning_at 칸(바꿀 때는 아래 «시각 바꿈» 한 줄 · 선생님 서랍 글과 학생 카드 글이 따라 바뀜)
--   아침으로 미룬 알림은 그 전에 이미 연 학생에게는 안 감(first_at) · 같은 때 한 폰에 둘 이상이면 알림 하나로 묶음
--   «전체»(*) 강의는 알림 없음(반이 정해진 강의만 · «전체» + 반이면 그 반만) · 학부모 · 영상 없는 반은 아무것도 없음 · 반 카톡 공지는 그대로
--   알림 글(11-17 원장님 A안): 굵은 첫 줄 «{교재} {제목}»(교재 칸이 비었거나 제목에 이미 들었으면 제목만) · 둘째 줄 «새 수업 영상이 올라왔어요» · 여럿이면 «{첫 편} 외 N-1개» / «새 수업 영상 N개가 올라왔어요» · 날짜 없음(학생 이름 · 결석 말 없음)
-- 표
--   lec_push_cfg    한 줄: mode(off 꺼짐 · test 시험 · on 켬 · 처음은 off) · test_names(시험 학생 이름 · 명단 이름 그대로) ·
--                   night_from(새벽 시작 01:00) · morning_at(아침 시각 08:00) · VAPID 열쇠(함수 lec-push 가 처음 돌 때 스스로 만들어 넣음)
--   lec_push_sub    학생 폰 하나 = 한 줄(기기 열쇠 kh · 푸시 주소 · 암호 열쇠 둘) · 기기 열쇠가 지워지면(나가기 · 모두 나가기) 같이 지워짐
--   lec_push_queue  강의 하나 = 한 줄(wait 기다림 · hold 숨김 · off 꺼진 때 · sent 보냄 · late 늦음 · gone 보낼 반 없음)
--   lec_push_log    강의 × 폰 보낸 기록(같은 폰에 두 번 안 감 · 90일 지나면 지움)
--   표는 모두 행 보안만 켜고 정책 없음 = 학생 · 선생님 모두 표로는 못 읽음(아래 함수로만)
-- 움직임: 강의 표 트리거(lec__push_mark)가 줄을 만들고 고침 · pg_cron «his-lec-push» 가 매분 lec_push_tick 을 부름 →
--   보낼 것이 있을 때만 Edge Function lec-push 를 부름(열쇠 없이) → 함수가 서버 열쇠로 lec__push_claim → 보냄 → lec__push_done
--   Edge Function lec-push 는 «Verify JWT» 를 끄고 배포합니다(매분 점검이 열쇠 없이 부름 · 함수는 받은 글을 읽지 않고 개수만 돌려줌)
-- 끄개 · 바꾸기(SQL Editor 한 줄)
--   바로 끔(기다리던 알림 모두 안 감 · 학생 카드 · 선생님 줄 숨김): update public.lec_push_cfg set mode = 'off';
--   시험(시험 학생 폰에만 · 선생님 줄은 관리자만): update public.lec_push_cfg set mode = 'test', test_names = array['학생이름'];
--   켬: update public.lec_push_cfg set mode = 'on';
--   시각 바꿈: update public.lec_push_cfg set night_from = '01:00', morning_at = '08:00';
--   매분 점검 멈춤: select cron.unschedule('his-lec-push');   (이 파일을 다시 넣으면 다시 걸림 · mode 와 열쇠는 그대로)
create table if not exists public.lec_push_cfg (
  id          integer primary key default 1 check (id = 1),
  mode        text not null default 'off' check (mode in ('off', 'test', 'on')),
  test_names  text[] not null default '{}',
  night_from  time not null default '01:00',
  morning_at  time not null default '08:00',
  vapid_pub   text,
  vapid_priv  text,
  jwt         jsonb not null default '{}'::jsonb,
  mode_at     timestamptz not null default now(),
  constraint lec_push_cfg_times check (night_from < morning_at)
);
insert into public.lec_push_cfg (id) values (1) on conflict (id) do nothing;

create table if not exists public.lec_push_sub (
  id          bigint generated always as identity primary key,
  kh          text not null references public.lec_key(kh) on delete cascade,
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  created_at  timestamptz not null default now(),
  last_ok_at  timestamptz
);
create index if not exists lec_push_sub_kh on public.lec_push_sub (kh);

create table if not exists public.lec_push_queue (
  lecture_id  uuid primary key references public.lec_lecture(id) on delete cascade,
  status      text not null check (status in ('wait', 'hold', 'off', 'sent', 'late', 'gone')),
  due_at      timestamptz,
  cls         text[] not null default '{}',
  done_cls    text[] not null default '{}',
  sent_at     timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint lec_push_queue_due check (status <> 'wait' or due_at is not null)
);
create index if not exists lec_push_queue_wait on public.lec_push_queue (due_at) where status = 'wait';

create table if not exists public.lec_push_log (
  lecture_id  uuid not null references public.lec_lecture(id) on delete cascade,
  sub_id      bigint not null,
  code        integer,
  at          timestamptz not null default now(),
  primary key (lecture_id, sub_id)
);
create index if not exists lec_push_log_at on public.lec_push_log (at);

revoke all on public.lec_push_cfg, public.lec_push_sub, public.lec_push_queue, public.lec_push_log from public, anon, authenticated;
alter table public.lec_push_cfg   enable row level security;
alter table public.lec_push_sub   enable row level security;
alter table public.lec_push_queue enable row level security;
alter table public.lec_push_log   enable row level security;

-- 알림 반: 강의의 반에서 «전체»(*) · 빈칸을 뺌(겹침 없이 · 차례대로)
create or replace function public.lec__push_cls(p text[]) returns text[]
language sql immutable set search_path = public as $$
  select array(select distinct t.c from unnest(coalesce(p, '{}'::text[])) as t(c)
                where coalesce(t.c, '') not in ('', '*') order by t.c)
$$;

-- 반 빼기 · 더하기(겹침 없이 · 차례대로)
create or replace function public.lec__push_minus(a text[], b text[]) returns text[]
language sql immutable set search_path = public as $$
  select array(select distinct t.x from unnest(coalesce(a, '{}'::text[])) as t(x)
                where t.x is not null and not (t.x = any (coalesce(b, '{}'::text[]))) order by t.x)
$$;
create or replace function public.lec__push_union(a text[], b text[]) returns text[]
language sql immutable set search_path = public as $$
  select array(select distinct t.x from unnest(coalesce(a, '{}'::text[]) || coalesce(b, '{}'::text[])) as t(x)
                where t.x is not null order by t.x)
$$;

-- 시험 학생 이름(띄어쓰기 빼고 비교 · 학생 화면과 같은 규칙)
create or replace function public.lec__push_names(p text[]) returns text[]
language sql immutable set search_path = public as $$
  select array(select distinct public.lec__norm(t.x) from unnest(coalesce(p, '{}'::text[])) as t(x)
                where public.lec__norm(t.x) <> '' order by 1)
$$;

-- 날짜 → «11.17(화)»(학생 화면 fmtDay 와 같은 꼴)
create or replace function public.lec__push_day(d date) returns text
language sql immutable set search_path = public as $$
  select case when d is null then '' else
    extract(month from d)::int::text || '.' || extract(day from d)::int::text || '(' ||
    (array['일', '월', '화', '수', '목', '금', '토'])[extract(dow from d)::int + 1] || ')' end
$$;

-- 시각 → «8시» · «7시 30분»(학생 카드 «새벽에 올라오면 아침 8시에 알려 드려요» 의 시각)
create or replace function public.lec__push_hm(t time) returns text
language sql immutable set search_path = public as $$
  select extract(hour from t)::int::text || '시'
      || case when extract(minute from t)::int > 0 then ' ' || extract(minute from t)::int::text || '분' else '' end
$$;

-- 알림 때(순수 함수): 공개일이 앞날 = 그날 아침(p_at) · 한국 시각 p_from 이상 p_at 미만 = 그날 아침(p_at) · 그 밖 = 지금
create or replace function public.lec_push_due(p_now timestamptz, p_posted date, p_from time default '01:00', p_at time default '08:00')
returns timestamptz
language sql immutable set search_path = public as $$
  select case
    when p_posted is not null and p_posted > (p_now at time zone 'Asia/Seoul')::date
      then (p_posted + p_at) at time zone 'Asia/Seoul'
    when (p_now at time zone 'Asia/Seoul')::time >= p_from and (p_now at time zone 'Asia/Seoul')::time < p_at
      then ((p_now at time zone 'Asia/Seoul')::date + p_at) at time zone 'Asia/Seoul'
    else p_now end
$$;

-- 강의 표 트리거: 올림 · 숨김 · 숨김 풀기 · 반 바꿈 · 공개일 · 공개 끝 → 대기 줄
--   이 함수에서 무엇이 틀려도 강의 저장은 막지 않음(경고만 남기고 알림 줄만 그대로)
create or replace function public.lec__push_mark() returns trigger
language plpgsql volatile security definer set search_path = public as $$
declare
  cf       public.lec_push_cfg;
  qq       public.lec_push_queue;
  v_has    boolean;
  v_eff    text[];
  v_done   text[];
  v_tg     text[];
  v_today  date := (now() at time zone 'Asia/Seoul')::date;
  v_end    boolean;
  v_fresh  boolean;
begin
  begin
    select * into cf from public.lec_push_cfg where id = 1;
    if not found then
      return null;
    end if;
    v_eff := public.lec__push_cls(new.class_ids);
    v_end := public.lec__ended(new);

    -- 새로 올림: 숨김 = hold · 꺼짐 = off(뒤에 켜도 안 감) · 공개 끝 지남 = late · 그 밖 = 기다림
    if tg_op = 'INSERT' then
      if cardinality(v_eff) = 0 then
        return null;
      end if;
      insert into public.lec_push_queue (lecture_id, status, due_at, cls)
      values (new.id,
              case when new.hidden then 'hold' when cf.mode = 'off' then 'off' when v_end then 'late' else 'wait' end,
              case when not new.hidden and cf.mode <> 'off' and not v_end
                   then public.lec_push_due(now(), new.posted_on, cf.night_from, cf.morning_at) end,
              v_eff)
      on conflict (lecture_id) do nothing;
      return null;
    end if;

    select * into qq from public.lec_push_queue where lecture_id = new.id for update;
    v_has := found;
    v_done := case when v_has then qq.done_cls else '{}'::text[] end;

    -- 기다리는 줄: 반 = 지금 반 - 이미 보낸 반 · 때를 다시 셈 · 숨김 = hold · 반 없음 = gone
    if v_has and qq.status = 'wait' then
      v_tg := public.lec__push_minus(v_eff, v_done);
      update public.lec_push_queue set
        status     = case when new.hidden then 'hold'
                          when cardinality(v_tg) = 0 then (case when cardinality(v_done) > 0 then 'sent' else 'gone' end)
                          when v_end then 'late' else 'wait' end,
        due_at     = case when new.hidden or cardinality(v_tg) = 0 or v_end then null
                          else public.lec_push_due(now(), new.posted_on, cf.night_from, cf.morning_at) end,
        cls        = v_tg,
        updated_at = now()
       where lecture_id = new.id;
      return null;
    end if;

    -- 숨긴 채 고침: 숨김 줄은 반만 맞춤 · 다른 줄은 그대로
    if new.hidden then
      if v_has and qq.status = 'hold' then
        update public.lec_push_queue set cls = public.lec__push_minus(v_eff, v_done), updated_at = now()
         where lecture_id = new.id;
      end if;
      return null;
    end if;

    -- 보이는 채 고침: 숨김을 풀었으면 아직 안 보낸 반 모두 · 아니면 새로 더한 반만
    if (v_has and qq.status = 'hold') or old.hidden then
      v_tg := public.lec__push_minus(v_eff, v_done);
    else
      v_tg := public.lec__push_minus(public.lec__push_minus(v_eff, public.lec__push_cls(old.class_ids)), v_done);
    end if;
    v_fresh := new.posted_on >= v_today - 3 and not v_end;
    if cardinality(v_tg) = 0 or cf.mode = 'off' or not v_fresh then
      if v_has and qq.status = 'hold' then
        update public.lec_push_queue set
          status     = case when cardinality(v_tg) = 0 then (case when cardinality(v_done) > 0 then 'sent' else 'gone' end)
                            when cf.mode = 'off' then 'off'
                            when cardinality(v_done) > 0 then 'sent' else 'late' end,
          cls        = case when cf.mode = 'off' and cardinality(v_tg) > 0 then v_tg else '{}'::text[] end,
          updated_at = now()
         where lecture_id = new.id;
      end if;
      return null;
    end if;
    insert into public.lec_push_queue (lecture_id, status, due_at, cls)
    values (new.id, 'wait', public.lec_push_due(now(), new.posted_on, cf.night_from, cf.morning_at), v_tg)
    on conflict (lecture_id) do update set
      status = 'wait', due_at = excluded.due_at, cls = excluded.cls, updated_at = now();
    return null;
  exception when others then
    raise warning 'lec__push_mark: % %', sqlstate, sqlerrm;
    return null;
  end;
end
$$;

drop trigger if exists lec_lecture_push on public.lec_lecture;
create trigger lec_lecture_push after insert or update of hidden, class_ids, posted_on, until on public.lec_lecture
  for each row execute function public.lec__push_mark();

-- 설정 바꿈: mode 가 바뀐 때를 적음 · 끄면 기다리던 알림을 모두 off(다시 켜도 그 알림은 안 감)
create or replace function public.lec__push_cfg_set() returns trigger
language plpgsql volatile security definer set search_path = public as $$
begin
  if new.mode is distinct from old.mode then
    new.mode_at := now();
    if new.mode = 'off' then
      update public.lec_push_queue set status = 'off', due_at = null, updated_at = now() where status = 'wait';
    end if;
  end if;
  return new;
end
$$;

drop trigger if exists lec_push_cfg_set on public.lec_push_cfg;
create trigger lec_push_cfg_set before update on public.lec_push_cfg
  for each row execute function public.lec__push_cfg_set();

-- 학생: 알림 카드를 띄울지 · 공개 열쇠 · 이 열쇠에 저장된 푸시 주소 · 아침 시각 글
--   on = 켬(또는 시험 중 시험 학생) · show = on + 열쇠 있음 + 내 반(«전체» 아님) 강의가 하나라도 있음
--   at = «8시»(학생 카드 «새벽에 올라오면 아침 8시에 알려 드려요») · 없는 열쇠 = err key
create or replace function public.lec_push_on(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k     public.lec_key;
  cf    public.lec_push_cfg;
  v_ep  text;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select * into cf from public.lec_push_cfg where id = 1;
  if not found
     or not (cf.mode = 'on' or (cf.mode = 'test' and public.lec__norm(k.sname) = any (public.lec__push_names(cf.test_names)))) then
    return jsonb_build_object('ok', true, 'on', false, 'show', false);
  end if;
  select s.endpoint into v_ep from public.lec_push_sub s where s.kh = k.kh order by s.id desc limit 1;
  return jsonb_build_object(
    'ok', true, 'on', true,
    'show', cf.vapid_pub is not null
            and exists (select 1 from public.lec_lecture l where public.lec__open(l, k.cls) and l.class_ids && k.cls),
    'key', cf.vapid_pub, 'ep', v_ep, 'at', public.lec__push_hm(cf.morning_at));
end
$$;

-- 학생: 이 폰의 푸시 주소 저장(열쇠 하나에 폰 하나 · 같은 주소가 다른 열쇠에 있으면 이 열쇠로 옮김)
--   주소는 알려진 푸시 서버(구글 · 애플 · 모질라 · 마이크로소프트)만 · 암호 열쇠 꼴 검사 · 꺼짐 = err off
create or replace function public.lec_push_save(p_key text, p_ep text, p_p256dh text, p_auth text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k   public.lec_key;
  cf  public.lec_push_cfg;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select * into cf from public.lec_push_cfg where id = 1;
  if not found
     or not (cf.mode = 'on' or (cf.mode = 'test' and public.lec__norm(k.sname) = any (public.lec__push_names(cf.test_names)))) then
    return jsonb_build_object('ok', false, 'err', 'off');
  end if;
  if coalesce(char_length(p_ep), 0) > 1000
     or coalesce(p_ep, '') !~ '^https://(fcm\.googleapis\.com|android\.googleapis\.com|[a-z0-9-]+(\.[a-z0-9-]+)*\.push\.apple\.com|updates\.push\.services\.mozilla\.com|[a-z0-9-]+(\.[a-z0-9-]+)*\.notify\.windows\.com)/[^[:space:]]+$'
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{87}$'
     or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{22}$' then
    return jsonb_build_object('ok', false, 'err', 'bad');
  end if;
  insert into public.lec_push_sub (kh, endpoint, p256dh, auth)
  values (k.kh, p_ep, p_p256dh, p_auth)
  on conflict (endpoint) do update set kh = excluded.kh, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
  delete from public.lec_push_sub where kh = k.kh and endpoint <> p_ep;
  return jsonb_build_object('ok', true);
end
$$;

-- 학생: 이 열쇠의 푸시 주소 지움(폰에서 알림을 막았을 때 · 나가기)
create or replace function public.lec_push_off(p_key text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_n integer;
begin
  delete from public.lec_push_sub where kh = public.lec__kh(p_key);
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'n', v_n);
end
$$;

-- 알림을 켠 학생 수: 받은 main 명단에서 그 반 학생 가운데 폰을 저장한 학생(폰 둘이어도 한 명 · 시험 중이면 시험 학생만)
create or replace function public.lec__push_n(p_main jsonb, p_cls text[], p_names text[])
returns integer
language sql stable security definer set search_path = public as $$
  select count(distinct r.skey)::integer
    from public.lec__ros(p_main) r
    join public.lec_key k on k.sid = r.skey
    join public.lec_push_sub s on s.kh = k.kh
   where r.cls && coalesce(p_cls, '{}'::text[])
     and (p_names is null or public.lec__norm(r.sname) = any (p_names))
$$;

-- 선생님: 이 강의의 알림 상태(서랍 줄) · 꺼짐 · 시험 중 관리자 아닌 선생님 · «전체»만인 강의 = show false(줄 없음)
--   when: now(1분 안) · today(오늘 아침) · day(앞날 아침) · 글은 화면이 due_day · due_hm(서버 시각)으로 씀
--   again: 숨김을 풀면 알림이 갈지(안 보낸 반이 있고 공개일이 3일 안)
create or replace function public.lec_push_state(p_lecture uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  st       record;
  cf       public.lec_push_cfg;
  ll       public.lec_lecture;
  qq       public.lec_push_queue;
  v_has    boolean;
  v_eff    text[];
  v_left   text[];
  v_tg     text[];
  v_today  date := (now() at time zone 'Asia/Seoul')::date;
  v_due    timestamp;
  v_sent   timestamp;
  v_main   jsonb;
begin
  select * into st from public.lec__staff() limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select * into cf from public.lec_push_cfg where id = 1;
  if not found or cf.mode = 'off' or (cf.mode = 'test' and not st.admin) then
    return jsonb_build_object('ok', true, 'mode', coalesce(cf.mode, 'off'), 'show', false);
  end if;
  select * into ll from public.lec_lecture where id = p_lecture;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  v_eff := public.lec__push_cls(ll.class_ids);
  if cardinality(v_eff) = 0 then
    return jsonb_build_object('ok', true, 'mode', cf.mode, 'show', false);
  end if;
  select * into qq from public.lec_push_queue where lecture_id = p_lecture;
  v_has := found;
  v_left := public.lec__push_minus(v_eff, case when v_has then qq.done_cls else '{}'::text[] end);
  v_tg := case when v_has and qq.status = 'wait' then qq.cls else v_left end;
  select a.data into v_main from public.app_state a where a.id = 'main';
  v_due := qq.due_at at time zone 'Asia/Seoul';
  v_sent := qq.sent_at at time zone 'Asia/Seoul';
  return jsonb_build_object(
    'ok', true, 'mode', cf.mode, 'show', true,
    'status', case when v_has then qq.status end,
    'hidden', ll.hidden,
    'when', case when not v_has or qq.status <> 'wait' then null
                 when qq.due_at <= now() + interval '90 seconds' then 'now'
                 when v_due::date = v_today then 'today' else 'day' end,
    'due', qq.due_at,
    'due_day', case when v_due is not null then public.lec__push_day(v_due::date) end,
    'due_hm', case when v_due is not null then to_char(v_due, 'FMHH24:MI') end,
    'sent', qq.sent_at,
    'sent_day', case when v_sent is not null then public.lec__push_day(v_sent::date) end,
    'sent_hm', case when v_sent is not null then to_char(v_sent, 'FMHH24:MI') end,
    'cls', to_jsonb(v_tg),
    'n', public.lec__push_n(coalesce(v_main, '{}'::jsonb), v_tg,
                            case when cf.mode = 'test' then public.lec__push_names(cf.test_names) end),
    'again', cardinality(v_left) > 0 and ll.posted_on >= v_today - 3 and not public.lec__ended(ll));
end
$$;

-- 함수 lec-push(서버 열쇠)만: 설정 · 열쇠 읽기 · 처음 만든 열쇠 넣기(먼저 넣은 것이 이김)
create or replace function public.lec__push_keys()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('mode', c.mode, 'pub', c.vapid_pub, 'priv', c.vapid_priv, 'jwt', c.jwt)
                     from public.lec_push_cfg c where c.id = 1),
                  jsonb_build_object('mode', 'off'))
$$;

create or replace function public.lec__push_setkeys(p_pub text, p_priv text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  if coalesce(p_pub, '') !~ '^[A-Za-z0-9_-]{87}$' or coalesce(p_priv, '') !~ '^[A-Za-z0-9_-]{43}$' then
    return jsonb_build_object('ok', false, 'err', 'bad');
  end if;
  update public.lec_push_cfg set vapid_pub = p_pub, vapid_priv = p_priv, jwt = '{}'::jsonb
   where id = 1 and vapid_pub is null;
  return public.lec__push_keys() || jsonb_build_object('ok', true);
end
$$;

-- 보낼 것 고르기(받은 main · 받은 «지금» · 스스로 점검이 가짜 main 과 시각으로 돌림)
--   12시간 넘게 못 보낸 것 = late · 새벽(night_from~morning_at)에는 그 5분 안에 잡힌 것만(새벽 1시 직전에 올린 것)
--   다시 봄: 숨김 = hold · 공개일 전 = 그대로 · 공개 끝 = late · 반 없음 = gone
--   받는 폰: 그 반 학생(명단) · 시험 중이면 시험 학생만 · 그 강의를 이미 연 학생 빼고 · 같은 폰에 같은 강의 한 번(lec_push_log)
--   돌려줌: 폰마다 {sub, endpoint, p256dh, auth, t 제목, b 본문, ids 강의(10개까지)}
create or replace function public.lec__push_take(p_main jsonb, p_now timestamptz)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  cf       public.lec_push_cfg;
  qq       public.lec_push_queue;
  ll       public.lec_lecture;
  v_names  text[];
  v_t      time := (p_now at time zone 'Asia/Seoul')::time;
  v_day    date := (p_now at time zone 'Asia/Seoul')::date;
  v_cls    text[];
  v_pairs  jsonb := '[]'::jsonb;
  v_one    jsonb;
  v_items  jsonb;
  v_rows   integer := 0;
begin
  select * into cf from public.lec_push_cfg where id = 1;
  if not found or cf.mode = 'off' or cf.vapid_pub is null then
    return jsonb_build_object('ok', true, 'mode', coalesce(cf.mode, 'off'), 'items', '[]'::jsonb, 'rows', 0);
  end if;
  v_names := case when cf.mode = 'test' then public.lec__push_names(cf.test_names) end;
  update public.lec_push_queue set status = 'late', due_at = null, updated_at = now()
   where status = 'wait' and due_at < p_now - interval '12 hours';
  for qq in
    select x.* from public.lec_push_queue x
     where x.status = 'wait' and x.due_at <= p_now
       and (v_t < cf.night_from or v_t >= cf.morning_at or x.due_at >= p_now - interval '5 minutes')
     order by x.due_at, x.lecture_id
     for update skip locked
  loop
    select * into ll from public.lec_lecture where id = qq.lecture_id;
    if not found or ll.posted_on > v_day then
      continue;
    end if;
    if ll.hidden then
      update public.lec_push_queue set status = 'hold', due_at = null, updated_at = now() where lecture_id = qq.lecture_id;
      continue;
    end if;
    v_cls := array(select t.x from unnest(qq.cls) as t(x) where t.x = any (public.lec__push_cls(ll.class_ids)) order by t.x);
    if cardinality(v_cls) = 0 or (ll.until is not null and v_day > ll.until) then
      update public.lec_push_queue set status = case when cardinality(v_cls) = 0 then 'gone' else 'late' end,
             due_at = null, updated_at = now()
       where lecture_id = qq.lecture_id;
      continue;
    end if;
    with ins as (
      insert into public.lec_push_log (lecture_id, sub_id)
      select distinct qq.lecture_id, s.id
        from public.lec_push_sub s
        join public.lec_key k on k.kh = s.kh
        join public.lec__ros(p_main) r on r.skey = k.sid
       where r.cls && v_cls
         and (v_names is null or public.lec__norm(r.sname) = any (v_names))
         and not exists (select 1 from public.lec_progress p
                          where p.sid = k.sid and p.lecture_id = qq.lecture_id and p.first_at is not null)
      on conflict (lecture_id, sub_id) do nothing
      returning lecture_id, sub_id)
    select coalesce(jsonb_agg(jsonb_build_object('lid', ins.lecture_id, 'sub', ins.sub_id)), '[]'::jsonb) into v_one from ins;
    v_pairs := v_pairs || v_one;
    update public.lec_push_queue set status = 'sent', sent_at = p_now, cls = '{}'::text[],
           done_cls = public.lec__push_union(done_cls, v_cls), updated_at = now()
     where lecture_id = qq.lecture_id;
    v_rows := v_rows + 1;
  end loop;
  select coalesce(jsonb_agg(b.o order by b.sid), '[]'::jsonb) into v_items
    from (
      select s.id as sid,
             jsonb_build_object(
               'sub', s.id, 'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth,
               'ids', to_jsonb((array_agg(lt.id order by coalesce(lt.lesson_on, lt.posted_on), lt.created_at, lt.id))[1:10]),
               't', (array_agg(case when btrim(lt.book) <> '' and strpos(lower(btrim(lt.title)), lower(btrim(lt.book))) = 0
                                    then left(btrim(lt.book), 40) || ' ' else '' end
                               || left(coalesce(nullif(btrim(lt.title), ''), '수업 영상'), 80)
                               order by coalesce(lt.lesson_on, lt.posted_on), lt.created_at, lt.id))[1]
                    || case when count(*) > 1 then ' 외 ' || (count(*) - 1)::text || '개' else '' end,
               'b', case when count(*) = 1 then '새 수업 영상이 올라왔어요'
                         else '새 수업 영상 ' || count(*)::text || '개가 올라왔어요' end) as o
        from jsonb_to_recordset(v_pairs) as g(lid uuid, sub bigint)
        join public.lec_push_sub s on s.id = g.sub
        join public.lec_lecture lt on lt.id = g.lid
       group by s.id, s.endpoint, s.p256dh, s.auth
    ) b;
  return jsonb_build_object('ok', true, 'mode', cf.mode, 'items', v_items, 'rows', v_rows);
end
$$;

-- 함수 lec-push 가 부름: 지금 보낼 것(학생 명단 = app_state main)
create or replace function public.lec__push_claim()
returns jsonb
language sql volatile security definer set search_path = public as $$
  select public.lec__push_take(coalesce((select a.data from public.app_state a where a.id = 'main'), '{}'::jsonb), now())
$$;

-- 함수 lec-push 가 보낸 결과를 적음: [{sub, code, ids}] · 404 · 410 = 그 폰 줄 지움 · 2xx = 마지막 성공 · VAPID 토큰 묶음 저장
create or replace function public.lec__push_done(p_res jsonb, p_jwt jsonb default null)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  x       record;
  v_ok    integer := 0;
  v_gone  integer := 0;
begin
  for x in
    select g.sub, g.code, g.ids
      from jsonb_to_recordset(case when jsonb_typeof(p_res) = 'array' then p_res else '[]'::jsonb end)
           as g(sub bigint, code integer, ids jsonb)
  loop
    update public.lec_push_log set code = x.code
     where sub_id = x.sub
       and lecture_id in (select e::uuid
                            from jsonb_array_elements_text(case when jsonb_typeof(x.ids) = 'array' then x.ids else '[]'::jsonb end) as t(e)
                           where e ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
    if x.code in (404, 410) then
      delete from public.lec_push_sub where id = x.sub;
      v_gone := v_gone + 1;
    elsif x.code between 200 and 299 then
      update public.lec_push_sub set last_ok_at = now() where id = x.sub;
      v_ok := v_ok + 1;
    end if;
  end loop;
  if p_jwt is not null and jsonb_typeof(p_jwt) = 'object' then
    update public.lec_push_cfg set jwt = p_jwt where id = 1;
  end if;
  return jsonb_build_object('ok', true, 'sent', v_ok, 'gone', v_gone);
end
$$;

-- 매분 점검(pg_cron «his-lec-push»): 꺼짐이면 아무것도 안 함 · 보낼 것이 있을 때(또는 열쇠가 아직 없을 때)만 함수 lec-push 를 부름(열쇠 없이)
--   열쇠가 아직 없으면 mode 를 바꾼 뒤 30분은 매분 · 그 뒤 10분마다 · 매시 17분에 옛 실행 기록(1일) · 보낸 기록(90일) 정리
create or replace function public.lec_push_tick()
returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  cf   public.lec_push_cfg;
  v_t  time := (now() at time zone 'Asia/Seoul')::time;
begin
  select * into cf from public.lec_push_cfg where id = 1;
  if found and cf.mode <> 'off' then
    update public.lec_push_queue set status = 'late', due_at = null, updated_at = now()
     where status = 'wait' and due_at < now() - interval '12 hours';
    if (cf.vapid_pub is null and (cf.mode_at > now() - interval '30 minutes' or extract(minute from now())::int % 10 = 0))
       or (cf.vapid_pub is not null
           and exists (select 1 from public.lec_push_queue x
                        where x.status = 'wait' and x.due_at <= now()
                          and (v_t < cf.night_from or v_t >= cf.morning_at or x.due_at >= now() - interval '5 minutes'))) then
      begin
        execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := $4)'
          using 'https://vcfhttzbzgtszpuahibe.supabase.co/functions/v1/lec-push', '{}'::jsonb,
                '{"Content-Type": "application/json"}'::jsonb, 30000;
      exception when others then
        raise warning 'lec_push_tick: % %', sqlstate, sqlerrm;
      end;
    end if;
  end if;
  if extract(minute from now())::int = 17 then
    begin
      execute 'delete from cron.job_run_details where jobid in (select jobid from cron.job where jobname = $1) '
           || 'and end_time < now() - interval ''1 day''' using 'his-lec-push';
    exception when others then
      null;
    end;
    delete from public.lec_push_log where at < now() - interval '90 days';
  end if;
end
$$;

-- 알림 상태 한 줄(맨 아래 표 «새 영상 알림» 칸): «꺼짐 · 열쇠 아직 · 매분 점검 됨 · 켠 폰 0 · 아침 8:00»
create or replace function public.lec__push_status()
returns text
language plpgsql stable security definer set search_path = public as $$
declare
  cf     public.lec_push_cfg;
  v_job  text := '없음';
  v_n    integer;
  v_err  text := coalesce(current_setting('his.lec_push_err', true), '');
begin
  select * into cf from public.lec_push_cfg where id = 1;
  if not found then
    return '설정 줄 없음';
  end if;
  begin
    execute 'select case when bool_or(active) then ''됨'' when count(*) > 0 then ''멈춤'' else ''없음'' end '
         || 'from cron.job where jobname = $1' into v_job using 'his-lec-push';
  exception when others then
    v_job := '못 읽음';
  end;
  select count(*) into v_n from public.lec_push_sub;
  return case cf.mode when 'off' then '꺼짐' when 'test' then '시험(' || cardinality(cf.test_names)::text || '명)' else '켜짐' end
      || ' · 열쇠 ' || case when cf.vapid_pub is null then '아직' else '있음' end
      || ' · 매분 점검 ' || coalesce(v_job, '없음')
      || ' · 켠 폰 ' || v_n::text
      || ' · 아침 ' || to_char(cf.morning_at, 'FMHH24:MI')
      || case when v_err <> '' then ' · ' || v_err else '' end;
end
$$;

-- 권한: 학생 함수 셋 = 누구나(열쇠로만 열림) · 선생님 함수 = 로그인한 사람(안에서 선생님만) · 함수 lec-push 용 넷 = 서버 열쇠만 · 나머지 = 밖에서 못 부름
revoke all on function public.lec__push_cls(text[]), public.lec__push_minus(text[], text[]), public.lec__push_union(text[], text[]),
                       public.lec__push_names(text[]), public.lec__push_day(date), public.lec__push_hm(time),
                       public.lec_push_due(timestamptz, date, time, time), public.lec__push_mark(), public.lec__push_cfg_set(),
                       public.lec__push_n(jsonb, text[], text[]), public.lec__push_take(jsonb, timestamptz),
                       public.lec__push_keys(), public.lec__push_setkeys(text, text), public.lec__push_claim(),
                       public.lec__push_done(jsonb, jsonb), public.lec_push_tick(), public.lec__push_status()
  from public, anon, authenticated;
revoke all on function public.lec_push_on(text), public.lec_push_save(text, text, text, text), public.lec_push_off(text),
                       public.lec_push_state(uuid)
  from public;
grant execute on function public.lec_push_on(text), public.lec_push_save(text, text, text, text), public.lec_push_off(text)
  to anon, authenticated;
revoke all on function public.lec_push_state(uuid) from anon;
grant execute on function public.lec_push_state(uuid) to authenticated;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.lec__push_keys(), public.lec__push_setkeys(text, text), public.lec__push_claim(),
                              public.lec__push_done(jsonb, jsonb)
      to service_role;
  end if;
end
$$;

-- 매분 점검 걸기(pg_net · pg_cron) · 못 하면 이 덩어리만 건너뜀(까닭은 맨 아래 표 «새 영상 알림» 칸 · 그때는 대시보드 Integrations › Cron)
do $$
begin
  begin
    create extension if not exists pg_net;
  exception when others then
    perform set_config('his.lec_push_err', 'pg_net ' || sqlstate, true);
    raise notice 'N1 · pg_net 을 못 켬(% %)', sqlstate, sqlerrm;
  end;
  begin
    create extension if not exists pg_cron;
  exception when others then
    perform set_config('his.lec_push_err',
                       coalesce(nullif(current_setting('his.lec_push_err', true), '') || ' · ', '') || 'pg_cron ' || sqlstate, true);
    raise notice 'N1 · pg_cron 을 못 켬(% %)', sqlstate, sqlerrm;
  end;
  if to_regnamespace('cron') is null then
    perform set_config('his.lec_push_err',
                       coalesce(nullif(current_setting('his.lec_push_err', true), '') || ' · ', '') || 'cron 없음', true);
    return;
  end if;
  begin
    execute 'select cron.schedule($1, $2, $3)' using 'his-lec-push', '* * * * *', 'select public.lec_push_tick()';
  exception when others then
    perform set_config('his.lec_push_err',
                       coalesce(nullif(current_setting('his.lec_push_err', true), '') || ' · ', '') || '매분 점검 ' || sqlstate, true);
    raise notice 'N1 · 매분 점검을 못 걺(% %)', sqlstate, sqlerrm;
  end;
end
$$;

-- 스스로 점검(N1 새 영상 알림): 알림 때 표 · 트리거(올림 · 고침 · 숨김 · 풀기 · 반 더함 · 끔/켬) ·
-- 보낼 것 고르기(가짜 main · 묶음 · 이미 연 학생 · 한 번만 · 새벽 막음 · 12시간 · 시험 학생) · 결과 적기 · 학생 · 선생님 함수 · 권한.
-- 점검용으로 바꾼 설정 · 넣은 강의 · 열쇠 · 폰은 끝에 되돌려 남지 않습니다(실제로 알림을 보내지 않음)
do $$
declare
  r        jsonb;
  v_n      integer;
  v_t      text;
  v_d      date := (now() at time zone 'Asia/Seoul')::date;
  v_x      timestamptz;
  v_y      timestamptz;
  v_ks     text := replace(gen_random_uuid()::text, '-', '');
  v_c1     text;
  v_c2     text;
  v_c3     text;
  v_a      uuid;
  v_b      uuid;
  v_c      uuid;
  v_e      uuid;
  v_f      uuid;
  v_g      uuid;
  v_h      uuid;
  v_i      uuid;
  v_j      uuid;
  v_k      uuid;
  v_m      uuid;
  v_w      uuid;
  v_l1     uuid;
  v_l2     uuid;
  v_l3     uuid;
  v_m1     uuid;
  v_m2     uuid;
  v_m3     uuid;
  v_t1     uuid;
  v_ka1    text;
  v_ka2    text;
  v_kb     text;
  v_kc     text;
  v_sa1    bigint;
  v_sa2    bigint;
  v_sb     bigint;
  v_sc     bigint;
  v_main   jsonb;
  v_p      text := 'B' || repeat('A', 86);
  v_au     text := 'B' || repeat('A', 21);
  v_ep     text;
  v_row    public.lec_push_queue;
  v_case   record;
begin
  begin
    -- 1) 알림 때(한국 시각 · 원장님 11-17 표): 00:30 · 00:59 바로 · 01:00 · 07:30 · 07:59 아침 8:00 · 08:00 · 23:50 바로 · 공개일 앞날 = 그날 8:00
    for v_case in
      select * from (values
        ('00:30'::time, 0, false), ('00:59'::time, 0, false), ('01:00'::time, 0, true), ('07:30'::time, 0, true),
        ('07:59'::time, 0, true), ('08:00'::time, 0, false), ('23:50'::time, 0, false), ('15:00'::time, 1, true),
        ('03:00'::time, 1, true), ('12:00'::time, -1, false), ('03:00'::time, -1, true)
      ) as t(hm, dp, morning)
    loop
      v_x := (v_d + v_case.hm) at time zone 'Asia/Seoul';
      if public.lec_push_due(v_x, v_d + v_case.dp, '01:00', '08:00')
         is distinct from (case when v_case.morning then ((v_d + greatest(v_case.dp, 0)) + time '08:00') at time zone 'Asia/Seoul'
                                else v_x end) then
        raise exception '점검 실패(N1 알림 때 % · 공개일 %일)', v_case.hm, v_case.dp;
      end if;
    end loop;
    if public.lec_push_due('2026-11-16 17:30:00+00', date '2026-11-17', '01:00', '08:00') is distinct from '2026-11-17 08:00:00+09'::timestamptz
       or public.lec_push_due('2026-11-20 17:00:00+00', date '2026-11-20', '01:00', '08:00') is distinct from '2026-11-21 08:00:00+09'::timestamptz
       or public.lec_push_due('2026-11-17 03:00:00+00', null, '01:00', '08:00') is distinct from '2026-11-17 03:00:00+00'::timestamptz
       or public.lec_push_due('2026-11-17 07:00:00+09', date '2026-11-17', '00:00', '07:30') is distinct from '2026-11-17 07:30:00+09'::timestamptz
       or public.lec_push_due('2026-11-17 02:00:00+09', date '2026-11-17') is distinct from '2026-11-17 08:00:00+09'::timestamptz then
      raise exception '점검 실패(N1 알림 때 · 세계시 · 주말 · 빈 공개일 · 시각 바꿈 · 기본값)';
    end if;
    if public.lec__push_day(date '2026-11-17') <> '11.17(화)' or public.lec__push_day(date '2027-01-05') <> '1.5(화)'
       or public.lec__push_hm('08:00') <> '8시' or public.lec__push_hm('07:30') <> '7시 30분'
       or public.lec__push_cls(array['*', 'b', '', 'a', 'b']) <> array['a', 'b']
       or public.lec__push_minus(array['a', 'b', 'c'], array['b']) <> array['a', 'c']
       or public.lec__push_union(array['b'], array['a', 'b']) <> array['a', 'b']
       or not (public.lec__push_names(array['점검 나', 'AB', '']) @> array['ab', '점검나']
               and public.lec__push_names(array['점검 나', 'AB', '']) <@ array['ab', '점검나']) then
      raise exception '점검 실패(N1 도움 함수)';
    end if;

    -- 2) 점검 설정: 켬 · 01:00 · 08:00 · 열쇠(없으면 점검용 · 끝에 되돌림)
    update public.lec_push_cfg
       set mode = 'on', test_names = '{}', night_from = '01:00', morning_at = '08:00',
           vapid_pub = coalesce(vapid_pub, v_p), vapid_priv = coalesce(vapid_priv, 'B' || repeat('A', 42))
     where id = 1;
    v_c1 := 'c-selftest-n1-' || left(v_ks, 8);
    v_c2 := v_c1 || 'b';
    v_c3 := v_c1 || 'c';

    -- a) 올림 = 기다림 · 때 = 지금 기준 lec_push_due
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1a', 'selftest000', 100, array[v_c1], v_d) returning id into v_a;
    select * into v_row from public.lec_push_queue where lecture_id = v_a;
    if v_row.status is distinct from 'wait' or v_row.cls is distinct from array[v_c1]
       or v_row.due_at is distinct from public.lec_push_due(now(), v_d, '01:00', '08:00') then
      raise exception '점검 실패(N1 올림): % % %', v_row.status, v_row.cls, v_row.due_at;
    end if;
    -- b) 제목만 고침(저장은 반 · 숨김도 같이 보냄) = 그대로 기다림
    update public.lec_lecture set title = 'selftest-n1a2', class_ids = array[v_c1], hidden = false where id = v_a;
    select * into v_row from public.lec_push_queue where lecture_id = v_a;
    if v_row.status is distinct from 'wait' or v_row.cls is distinct from array[v_c1] then
      raise exception '점검 실패(N1 고침): % %', v_row.status, v_row.cls;
    end if;
    -- c) 숨김 = hold · d) 숨김 풀기 = 다시 기다림
    update public.lec_lecture set hidden = true where id = v_a;
    select * into v_row from public.lec_push_queue where lecture_id = v_a;
    if v_row.status is distinct from 'hold' or v_row.due_at is not null or v_row.cls is distinct from array[v_c1] then
      raise exception '점검 실패(N1 숨김): % %', v_row.status, v_row.due_at;
    end if;
    update public.lec_lecture set hidden = false where id = v_a;
    select * into v_row from public.lec_push_queue where lecture_id = v_a;
    if v_row.status is distinct from 'wait' or v_row.due_at is distinct from public.lec_push_due(now(), v_d, '01:00', '08:00') then
      raise exception '점검 실패(N1 숨김 풀기): % %', v_row.status, v_row.due_at;
    end if;
    -- e) 숨긴 채 올림 = hold · f) 공개일이 앞날 = 그날 아침 8:00
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, hidden)
    values ('selftest-n1b', 'selftest000', 100, array[v_c1], v_d, true) returning id into v_b;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on)
    values ('selftest-n1c', 'selftest000', 100, array[v_c1], v_d + 2, v_d + 2) returning id into v_c;
    if (select status from public.lec_push_queue where lecture_id = v_b) is distinct from 'hold'
       or (select due_at from public.lec_push_queue where lecture_id = v_c) is distinct from ((v_d + 2) + time '08:00') at time zone 'Asia/Seoul' then
      raise exception '점검 실패(N1 숨긴 채 올림 · 앞날 공개)';
    end if;
    -- g) «전체»만 = 줄 없음 · h) «전체» + 반 = 그 반만
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1e', 'selftest000', 100, array['*'], v_d) returning id into v_e;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1f', 'selftest000', 100, array['*', v_c2], v_d) returning id into v_f;
    if exists (select 1 from public.lec_push_queue where lecture_id = v_e)
       or (select cls from public.lec_push_queue where lecture_id = v_f) is distinct from array[v_c2] then
      raise exception '점검 실패(N1 전체 강의)';
    end if;
    -- i) 기다리는 강의에 반 더함 = 두 반 · j) 반을 모두 빼면(전체만) = gone
    update public.lec_lecture set class_ids = array[v_c2, v_c1] where id = v_a;
    update public.lec_lecture set class_ids = array['*'] where id = v_f;
    if (select cls from public.lec_push_queue where lecture_id = v_a) is distinct from array[v_c1, v_c2]
       or (select status from public.lec_push_queue where lecture_id = v_f) is distinct from 'gone' then
      raise exception '점검 실패(N1 반 바꿈)';
    end if;
    -- k) 보낸 강의(공개일 5일 전)에 반 더함 = 안 감 · l) 공개일 3일 안 = 더한 반에만
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on)
    values ('selftest-n1g', 'selftest000', 100, array[v_c1], v_d - 5, v_d - 5) returning id into v_g;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1h', 'selftest000', 100, array[v_c1], v_d) returning id into v_h;
    update public.lec_push_queue set status = 'sent', due_at = null, cls = '{}', done_cls = array[v_c1], sent_at = now()
     where lecture_id in (v_g, v_h);
    update public.lec_lecture set class_ids = array[v_c1, v_c3] where id in (v_g, v_h);
    if (select status from public.lec_push_queue where lecture_id = v_g) is distinct from 'sent'
       or (select status from public.lec_push_queue where lecture_id = v_h) is distinct from 'wait'
       or (select cls from public.lec_push_queue where lecture_id = v_h) is distinct from array[v_c3] then
      raise exception '점검 실패(N1 보낸 뒤 반 더함)';
    end if;
    -- m) 다 보낸 강의를 숨겼다 풀어도 다시 안 감
    update public.lec_push_queue set status = 'sent', due_at = null, cls = '{}', done_cls = array[v_c1, v_c3] where lecture_id = v_h;
    update public.lec_lecture set hidden = true where id = v_h;
    update public.lec_lecture set hidden = false where id = v_h;
    if (select status from public.lec_push_queue where lecture_id = v_h) is distinct from 'sent' then
      raise exception '점검 실패(N1 보낸 뒤 숨김 풀기)';
    end if;
    -- n) 숨긴 채 올린 지 5일 지나 풀기 = 안 감(late) · o) 공개 끝이 지난 강의 = late
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, hidden)
    values ('selftest-n1i', 'selftest000', 100, array[v_c1], v_d - 5, v_d - 5, true) returning id into v_i;
    update public.lec_lecture set hidden = false where id = v_i;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, posted_on, until)
    values ('selftest-n1j', 'selftest000', 100, array[v_c1], v_d - 3, v_d - 3, v_d - 1) returning id into v_j;
    if (select status from public.lec_push_queue where lecture_id = v_i) is distinct from 'late'
       or (select status from public.lec_push_queue where lecture_id = v_j) is distinct from 'late' then
      raise exception '점검 실패(N1 늦은 풀기 · 공개 끝)';
    end if;
    -- p) 끔 = 기다리던 것 모두 off · 끈 채 올림 = off · 끈 채 숨김 풀기 = off · 다시 켜도 그대로(쏟아지지 않음)
    update public.lec_push_cfg set mode = 'off' where id = 1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1k', 'selftest000', 100, array[v_c1], v_d) returning id into v_k;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, hidden)
    values ('selftest-n1m', 'selftest000', 100, array[v_c1], v_d, true) returning id into v_m;
    update public.lec_lecture set hidden = false where id = v_m;
    update public.lec_push_cfg set mode = 'on' where id = 1;
    if (select status from public.lec_push_queue where lecture_id = v_a) is distinct from 'off'
       or (select status from public.lec_push_queue where lecture_id = v_c) is distinct from 'off'
       or (select status from public.lec_push_queue where lecture_id = v_k) is distinct from 'off'
       or (select status from public.lec_push_queue where lecture_id = v_m) is distinct from 'off' then
      raise exception '점검 실패(N1 끔 · 켬)';
    end if;

    -- 3) 보낼 것 고르기: 앞 점검 강의는 모두 gone 으로 두고 · 가짜 main(점검가 폰 둘 · 점검나 · 다른 반 점검다)
    update public.lec_push_queue set status = 'gone', due_at = null
     where lecture_id in (v_a, v_b, v_c, v_f, v_g, v_h, v_i, v_j, v_k, v_m);
    v_main := jsonb_build_object('classes', jsonb_build_array(
      jsonb_build_object('id', v_c1, 'name', '점검1', 'students', jsonb_build_array(
        jsonb_build_object('id', 'selftest-n1a', 'name', '점검가'),
        jsonb_build_object('id', 'selftest-n1b', 'name', '점검나'))),
      jsonb_build_object('id', v_c2, 'name', '점검2', 'students', jsonb_build_array(
        jsonb_build_object('id', 'selftest-n1c', 'name', '점검다')))));
    v_ka1 := 'selftest' || v_ks || 'a1';
    v_ka2 := 'selftest' || v_ks || 'a2';
    v_kb := 'selftest' || v_ks || 'b';
    v_kc := 'selftest' || v_ks || 'c';
    insert into public.lec_key (kh, sid, rid, pin, sname, cls) values
      (public.lec__kh(v_ka1), 'selftest-n1a|점검가', 'selftest-n1a', '', '점검가', array[v_c1]),
      (public.lec__kh(v_ka2), 'selftest-n1a|점검가', 'selftest-n1a', '', '점검가', array[v_c1]),
      (public.lec__kh(v_kb), 'selftest-n1b|점검나', 'selftest-n1b', '', '점검나', array[v_c1]),
      (public.lec__kh(v_kc), 'selftest-n1c|점검다', 'selftest-n1c', '', '점검다', array[v_c2]);
    v_ep := 'https://fcm.googleapis.com/fcm/send/selftest-' || v_ks;
    r := public.lec_push_save(v_ka1, v_ep || '-a1', v_p, v_au);
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(N1 폰 저장): %', r; end if;
    r := public.lec_push_save(v_ka2, v_ep || '-a2', v_p, v_au);
    r := public.lec_push_save(v_kb, 'https://web.push.apple.com/selftest-' || v_ks || '-b', v_p, v_au);
    r := public.lec_push_save(v_kc, v_ep || '-c', v_p, v_au);
    select id into v_sa1 from public.lec_push_sub where endpoint = v_ep || '-a1';
    select id into v_sa2 from public.lec_push_sub where endpoint = v_ep || '-a2';
    select id into v_sb from public.lec_push_sub where endpoint = 'https://web.push.apple.com/selftest-' || v_ks || '-b';
    select id into v_sc from public.lec_push_sub where endpoint = v_ep || '-c';
    if v_sa1 is null or v_sa2 is null or v_sb is null or v_sc is null then
      raise exception '점검 실패(N1 폰 넷 저장)';
    end if;
    if public.lec__push_n(v_main, array[v_c1], null) <> 2 or public.lec__push_n(v_main, array[v_c2], null) <> 1
       or public.lec__push_n(v_main, array[v_c1], array['점검나']) <> 1 then
      raise exception '점검 실패(N1 켠 학생 수)';
    end if;

    insert into public.lec_lecture (title, book, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-L1', ' 점검책 ', 'selftest000', 100, array[v_c1], v_d - 1) returning id into v_l1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-L2', 'selftest000', 100, array[v_c1], v_d) returning id into v_l2;
    insert into public.lec_lecture (title, book, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-L3', 'SELFTEST-N1', 'selftest000', 100, array[v_c2], v_d) returning id into v_l3;
    insert into public.lec_progress (sid, lecture_id, first_at) values ('selftest-n1b|점검나', v_l2, now());
    v_x := ((v_d + 1) + time '12:00') at time zone 'Asia/Seoul';
    update public.lec_push_queue set due_at = v_x - interval '1 minute' where lecture_id in (v_l1, v_l2, v_l3);
    r := public.lec__push_take(v_main, v_x);
    select count(*) into v_n from jsonb_array_elements(r -> 'items') as t(x)
     where (x ->> 'sub')::bigint not in (v_sa1, v_sa2, v_sb, v_sc);
    if v_n <> 0 then raise exception '점검 실패(N1 · 점검 아닌 폰 %개가 골라짐)', v_n; end if;
    if (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1)
         is distinct from jsonb_build_array(v_l1, v_l2)
       or (select x ->> 't' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1)
         is distinct from '점검책 selftest-n1-L1 외 1개'
       or (select x ->> 'b' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1)
         is distinct from '새 수업 영상 2개가 올라왔어요'
       or (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa2)
         is distinct from jsonb_build_array(v_l1, v_l2)
       or (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sb)
         is distinct from jsonb_build_array(v_l1)
       or (select x ->> 't' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sb)
         is distinct from '점검책 selftest-n1-L1'
       or (select x ->> 'b' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sb)
         is distinct from '새 수업 영상이 올라왔어요'
       or (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sc)
         is distinct from jsonb_build_array(v_l3)
       or (select x ->> 't' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sc)
         is distinct from 'selftest-n1-L3' then
      raise exception '점검 실패(N1 묶음 · 이미 연 학생): %', left(r::text, 600);
    end if;
    if r::text ~ '(보세요|점검가|점검나|점검다|결석|보강)' then
      raise exception '점검 실패(N1 알림 글에 학생 이름 · 쓰지 않는 말)';
    end if;
    if (select status from public.lec_push_queue where lecture_id = v_l1) is distinct from 'sent'
       or (select done_cls from public.lec_push_queue where lecture_id = v_l3) is distinct from array[v_c2]
       or (select sent_at from public.lec_push_queue where lecture_id = v_l2) is distinct from v_x
       or (select count(*) from public.lec_push_log where lecture_id in (v_l1, v_l2, v_l3)) <> 6 then
      raise exception '점검 실패(N1 보낸 기록)';
    end if;
    r := public.lec__push_take(v_main, v_x);
    if exists (select 1 from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint in (v_sa1, v_sa2, v_sb, v_sc)) then
      raise exception '점검 실패(N1 두 번 보냄)';
    end if;

    -- 결과 적기: 201 = 성공 · 410 = 폰 줄 지움 · 500 = 그대로 · 토큰 묶음 저장
    r := public.lec__push_done(jsonb_build_array(
           jsonb_build_object('sub', v_sa1, 'code', 201, 'ids', jsonb_build_array(v_l1, v_l2)),
           jsonb_build_object('sub', v_sa2, 'code', 410, 'ids', jsonb_build_array(v_l1, v_l2)),
           jsonb_build_object('sub', v_sb, 'code', 500, 'ids', jsonb_build_array(v_l1))),
         jsonb_build_object('selftest', v_ks));
    if exists (select 1 from public.lec_push_sub where id = v_sa2)
       or (select last_ok_at from public.lec_push_sub where id = v_sa1) is null
       or (select last_ok_at from public.lec_push_sub where id = v_sb) is not null
       or (select code from public.lec_push_log where lecture_id = v_l1 and sub_id = v_sa1) is distinct from 201
       or (select code from public.lec_push_log where lecture_id = v_l1 and sub_id = v_sb) is distinct from 500
       or (select jwt ->> 'selftest' from public.lec_push_cfg where id = 1) is distinct from v_ks
       or (r ->> 'sent')::int <> 1 or (r ->> 'gone')::int <> 1 then
      raise exception '점검 실패(N1 결과 적기): %', r;
    end if;

    -- 보낸 뒤 반 더함(3일 안) = 더한 반에만 · 이미 받은 폰은 안 받음
    update public.lec_lecture set class_ids = array[v_c2, v_c1] where id = v_l3;
    if (select cls from public.lec_push_queue where lecture_id = v_l3) is distinct from array[v_c1] then
      raise exception '점검 실패(N1 보낸 뒤 반 더함 줄)';
    end if;
    update public.lec_push_queue set due_at = v_x - interval '1 minute' where lecture_id = v_l3;
    r := public.lec__push_take(v_main, v_x);
    if (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1)
         is distinct from jsonb_build_array(v_l3)
       or (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sb)
         is distinct from jsonb_build_array(v_l3)
       or exists (select 1 from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint in (v_sa2, v_sc)) then
      raise exception '점검 실패(N1 더한 반에만): %', left(r::text, 600);
    end if;

    -- 새벽 막음: 01:00:30 에는 00:59 에 잡힌 것만 · 00:40 것은 아침 8:00:30 에 · 13시간 지난 것은 late
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-M1', 'selftest000', 100, array[v_c1], v_d) returning id into v_m1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-M2', 'selftest000', 100, array[v_c1], v_d) returning id into v_m2;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-M3', 'selftest000', 100, array[v_c1], v_d) returning id into v_m3;
    v_y := ((v_d + 1) + time '08:00:30') at time zone 'Asia/Seoul';
    update public.lec_push_queue set due_at = ((v_d + 1) + time '00:59') at time zone 'Asia/Seoul' where lecture_id = v_m1;
    update public.lec_push_queue set due_at = ((v_d + 1) + time '00:40') at time zone 'Asia/Seoul' where lecture_id = v_m2;
    update public.lec_push_queue set due_at = v_y - interval '13 hours' where lecture_id = v_m3;
    r := public.lec__push_take(v_main, ((v_d + 1) + time '01:00:30') at time zone 'Asia/Seoul');
    if (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1)
         is distinct from jsonb_build_array(v_m1)
       or (select status from public.lec_push_queue where lecture_id = v_m2) is distinct from 'wait'
       or (select status from public.lec_push_queue where lecture_id = v_m3) is distinct from 'wait' then
      raise exception '점검 실패(N1 새벽 막음): %', left(r::text, 600);
    end if;
    r := public.lec__push_take(v_main, v_y);
    if (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1)
         is distinct from jsonb_build_array(v_m2)
       or (select status from public.lec_push_queue where lecture_id = v_m3) is distinct from 'late' then
      raise exception '점검 실패(N1 아침 8:00 · 12시간): %', left(r::text, 600);
    end if;

    -- 시험: 시험 학생(점검나) 폰에만 · 학생 함수도 시험 학생에게만 켜짐
    update public.lec_push_cfg set mode = 'test', test_names = array['점검 나'] where id = 1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1-T1', 'selftest000', 100, array[v_c1], v_d) returning id into v_t1;
    update public.lec_push_queue set due_at = v_x - interval '1 minute' where lecture_id = v_t1;
    r := public.lec__push_take(v_main, v_x);
    if (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sb)
         is distinct from jsonb_build_array(v_t1)
       or exists (select 1 from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sa1) then
      raise exception '점검 실패(N1 시험 학생에게만): %', left(r::text, 600);
    end if;
    r := public.lec_push_on(v_ka1);
    if coalesce((r ->> 'on')::boolean, true) or coalesce((r ->> 'show')::boolean, true) then
      raise exception '점검 실패(N1 시험 중 다른 학생 카드): %', r;
    end if;
    r := public.lec_push_on(v_kb);
    if not coalesce((r ->> 'on')::boolean, false) or not coalesce((r ->> 'show')::boolean, false) then
      raise exception '점검 실패(N1 시험 학생 카드): %', r;
    end if;
    update public.lec_push_cfg set mode = 'on', test_names = '{}' where id = 1;

    -- 4) 학생 함수: 없는 열쇠 · 카드 · 아침 시각 글 · 틀린 주소 · 열쇠 하나에 폰 하나 · 주소 옮김 · 지움 · 꺼짐
    r := public.lec_push_on('selftest-none-' || v_ks);
    if (r ->> 'err') is distinct from 'key' then raise exception '점검 실패(N1 없는 열쇠): %', r; end if;
    r := public.lec_push_on(v_ka1);
    if not coalesce((r ->> 'show')::boolean, false) or (r ->> 'ep') is distinct from v_ep || '-a1'
       or (r ->> 'key') is distinct from (select vapid_pub from public.lec_push_cfg where id = 1) or (r ->> 'at') is distinct from '8시' then
      raise exception '점검 실패(N1 학생 카드): %', r;
    end if;
    update public.lec_push_cfg set morning_at = '07:30' where id = 1;
    r := public.lec_push_on(v_ka1);
    if (r ->> 'at') is distinct from '7시 30분' then raise exception '점검 실패(N1 아침 시각 글): %', r; end if;
    update public.lec_push_cfg set morning_at = '08:00' where id = 1;
    foreach v_t in array array['https://evil.example.com/x', 'http://fcm.googleapis.com/fcm/send/x',
                               'https://fcm.googleapis.com.evil.example/x', 'https://fcm.googleapis.com/fcm/send/a b',
                               'https://fcm.googleapis.com/' || repeat('x', 1000)] loop
      r := public.lec_push_save(v_ka1, v_t, v_p, v_au);
      if (r ->> 'err') is distinct from 'bad' then raise exception '점검 실패(N1 틀린 주소 받음): %', left(v_t, 60); end if;
    end loop;
    r := public.lec_push_save(v_ka1, v_ep || '-z', 'short', v_au);
    if (r ->> 'err') is distinct from 'bad' then raise exception '점검 실패(N1 틀린 열쇠 p256dh 받음)'; end if;
    r := public.lec_push_save(v_ka1, v_ep || '-z', v_p, v_au || '=');
    if (r ->> 'err') is distinct from 'bad' then raise exception '점검 실패(N1 틀린 열쇠 auth 받음)'; end if;
    r := public.lec_push_save(v_ka1, v_ep || '-a1b', v_p, v_au);
    if (select count(*) from public.lec_push_sub where kh = public.lec__kh(v_ka1)) <> 1
       or (select endpoint from public.lec_push_sub where kh = public.lec__kh(v_ka1)) is distinct from v_ep || '-a1b' then
      raise exception '점검 실패(N1 열쇠 하나에 폰 하나)';
    end if;
    r := public.lec_push_save(v_kb, v_ep || '-a1b', v_p, v_au);
    if (select count(*) from public.lec_push_sub where kh = public.lec__kh(v_ka1)) <> 0
       or (select count(*) from public.lec_push_sub where kh = public.lec__kh(v_kb)) <> 1 then
      raise exception '점검 실패(N1 주소 옮김)';
    end if;
    r := public.lec_push_off(v_kb);
    if (r ->> 'n')::int <> 1 or exists (select 1 from public.lec_push_sub where kh = public.lec__kh(v_kb)) then
      raise exception '점검 실패(N1 지움): %', r;
    end if;
    update public.lec_push_cfg set mode = 'off' where id = 1;
    r := public.lec_push_on(v_ka1);
    if coalesce((r ->> 'on')::boolean, true) then raise exception '점검 실패(N1 꺼짐 카드): %', r; end if;
    r := public.lec_push_save(v_ka1, v_ep || '-q', v_p, v_au);
    if (r ->> 'err') is distinct from 'off' then raise exception '점검 실패(N1 꺼짐 저장): %', r; end if;
    update public.lec_push_cfg set mode = 'on' where id = 1;

    -- 5) 선생님 함수: 로그인 안 함 = 막힘 · 기다림 · 숨김 · «전체»만 · 보냄 · 시험 중 관리자만
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-n1w', 'selftest000', 100, array[v_c1], v_d) returning id into v_w;
    perform set_config('request.jwt.claims', '', true);
    r := public.lec_push_state(v_w);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(N1 선생님 함수 · 학생): %', r; end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"joey@his.kr"}', true);
    r := public.lec_push_state(v_w);
    select * into v_row from public.lec_push_queue where lecture_id = v_w;
    if not coalesce((r ->> 'show')::boolean, false) or (r ->> 'status') is distinct from 'wait'
       or (r -> 'cls') is distinct from jsonb_build_array(v_c1) or jsonb_typeof(r -> 'n') is distinct from 'number'
       or (r ->> 'when') is distinct from (case when v_row.due_at <= now() + interval '90 seconds' then 'now'
                                                when (v_row.due_at at time zone 'Asia/Seoul')::date = v_d then 'today' else 'day' end)
       or (r ->> 'due_hm') is distinct from to_char(v_row.due_at at time zone 'Asia/Seoul', 'FMHH24:MI')
       or (r ->> 'due_day') is distinct from public.lec__push_day((v_row.due_at at time zone 'Asia/Seoul')::date) then
      raise exception '점검 실패(N1 선생님 함수 · 기다림): %', r;
    end if;
    update public.lec_lecture set hidden = true where id = v_w;
    r := public.lec_push_state(v_w);
    if (r ->> 'status') is distinct from 'hold' or not coalesce((r ->> 'hidden')::boolean, false)
       or not coalesce((r ->> 'again')::boolean, false) then
      raise exception '점검 실패(N1 선생님 함수 · 숨김): %', r;
    end if;
    r := public.lec_push_state(v_i);
    if coalesce((r ->> 'again')::boolean, true) then raise exception '점검 실패(N1 선생님 함수 · 3일 지남): %', r; end if;
    r := public.lec_push_state(v_e);
    if coalesce((r ->> 'show')::boolean, true) then raise exception '점검 실패(N1 선생님 함수 · 전체 강의): %', r; end if;
    r := public.lec_push_state(v_l1);
    if (r ->> 'status') is distinct from 'sent' or (r ->> 'sent_day') is distinct from public.lec__push_day(v_d + 1)
       or (r ->> 'sent_hm') is distinct from '12:00' then
      raise exception '점검 실패(N1 선생님 함수 · 보냄): %', r;
    end if;
    update public.lec_push_cfg set mode = 'test' where id = 1;
    r := public.lec_push_state(v_w);
    if coalesce((r ->> 'show')::boolean, true) then raise exception '점검 실패(N1 시험 중 선생님 줄): %', r; end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"benjamin@his.kr"}', true);
    r := public.lec_push_state(v_w);
    if not coalesce((r ->> 'show')::boolean, false) then raise exception '점검 실패(N1 시험 중 관리자 줄): %', r; end if;
    update public.lec_push_cfg set mode = 'off' where id = 1;
    r := public.lec_push_state(v_w);
    if coalesce((r ->> 'show')::boolean, true) then raise exception '점검 실패(N1 꺼짐 선생님 줄): %', r; end if;
    perform set_config('request.jwt.claims', '', true);

    -- 6) 권한: 학생 함수 = 누구나 · 선생님 함수 = 로그인한 사람만 · 서버 함수 = 서버 열쇠만 · 표 = 아무도 직접 못 읽음
    if not has_function_privilege('anon', 'public.lec_push_on(text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_push_save(text, text, text, text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_push_off(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_push_on(text)', 'execute')
       or has_function_privilege('anon', 'public.lec_push_state(uuid)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_push_state(uuid)', 'execute')
       or has_function_privilege('anon', 'public.lec_push_tick()', 'execute')
       or has_function_privilege('authenticated', 'public.lec_push_tick()', 'execute')
       or has_function_privilege('anon', 'public.lec_push_due(timestamptz, date, time, time)', 'execute')
       or has_function_privilege('authenticated', 'public.lec_push_due(timestamptz, date, time, time)', 'execute') then
      raise exception '점검 실패(N1 함수 권한)';
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role')
       and (not has_function_privilege('service_role', 'public.lec__push_claim()', 'execute')
            or not has_function_privilege('service_role', 'public.lec__push_done(jsonb, jsonb)', 'execute')
            or not has_function_privilege('service_role', 'public.lec__push_keys()', 'execute')
            or not has_function_privilege('service_role', 'public.lec__push_setkeys(text, text)', 'execute')) then
      raise exception '점검 실패(N1 서버 함수 권한)';
    end if;
    select string_agg(c.relname || ' ' || u.rl, ', ') into v_t
      from pg_class c
     cross join unnest(array['anon', 'authenticated']) as u(rl)
     where c.relnamespace = 'public'::regnamespace
       and c.relname in ('lec_push_cfg', 'lec_push_sub', 'lec_push_queue', 'lec_push_log')
       and (has_table_privilege(u.rl, c.oid, 'select,insert,update,delete') or not c.relrowsecurity);
    if v_t is not null then
      raise exception '점검 실패(N1 표 권한): %', v_t;
    end if;
    -- 속 함수 전부(이 절이 파일 맨 끝이라 N1 의 lec__push_* 까지): anon · authenticated 가 직접 못 부름
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(N1 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- S1 (11-17) 단어 · 구문 · 문법
-- 원장님 11-17 결론안(덧붙임 2 · 위젯 cc8): 히즈클래스 안에서 단어(voc) · 구문(gu) · 문법(gram) 공부 묶음을 «세트»로 올림
--   «세트»는 선생님 화면과 코드에서만 쓰는 말(학생 화면에는 안 나옴) · 세트 만들기 · 결과 보기 · 녹음 듣기는 관리자(원장님)만
--   lec_set       세트 한 줄(종류 · 이름 · 볼 반 · 공개일 · 숨김 · 문항 · ★ 녹음 문장)
--   lec_set_prog  학생 × 세트 진도(카드 · 누적 맞힘 · 첫 시도 % · 최고 % · 통과 · 카드 저장 횟수)
--   lec_set_try   시험 · 드릴 · 쌓인 오답 한 판(문항과 정답은 서버에만 · 답은 문항마다 lec_set_ans 로 한 번)
--   lec_set_rec   구문 녹음 한 개(파일은 Storage 버킷 lec-rec · 비공개 · 30일 뒤 지움)
--   lec_rec_ok    S1-b 부터 안 씀(옛 녹음 동의 · 학교급 줄 · 표와 줄은 그대로 둠 · 읽고 쓰는 함수 없음)
--   lec_consent.sv · sv_at  S1-b 부터 안 씀(옛 세트 기록 동의 판 · 칸은 그대로 둠)
--   S1-b(11-17 원장님 «동의서 필요없어 오바쫌 하지마 클래스카드도 그냥 다 하는데»): 세트 동의 · 녹음 동의 · 학교급 갈래를 뺌
--     히즈클래스 기록 동의(lec__agreed)만 보고 세트가 바로 열림 · ★ 녹음도 모든 학생이 바로(lec_rec_begin · lec_rec_slot 은 녹음 동의를 안 봄 · 기록 동의는 lec_rec_begin 이 그대로 봄)
--     지킴은 그대로: 듣기 · 지우기는 원장님 계정만(lec_set_is_admin) · 한 개 45초 · ★ 두 문장 · 30일 뒤 지움
--     옛 화면을 위해 lec_set_home 은 'agree' true · 'rec' {ok true}, lec_set_items 는 'rec' {ok true} 를 그대로 돌려줌
--   다섯 표는 행 보안 켬 · 정책 0 = 표로는 아무도 못 읽음 · 함수로만 · 새 함수는 app_state 를 읽지 않음(반은 lec_key.cls)
--   이름 바뀜(lec__move) · 학생 지움(lec_forget · 동의 지움)은 트리거 셋이 세트 기록을 따라 옮기거나 지움(기존 함수 몸통 그대로)
--   끄개 · 학생 묶음 숨김: revoke execute on function public.lec_set_home(text) from anon, authenticated;
--          녹음 올리기 막음: drop policy if exists lec_rec_put on storage.objects;
--          (이 파일을 다시 넣으면 둘 다 다시 켜짐)
--   SQL Editor 계정이 Storage 표를 못 고치면(42501) 버킷 · 정책 덩어리만 건너뜀 → 맨 아래 표 «녹음 저장 곳»에 까닭이 나옴 · 그때는 대시보드:
--     ① Storage › New bucket › 이름 lec-rec · Public bucket 끔 · Restrict file size 1 MB ·
--        Allowed MIME types audio/webm, audio/mp4, audio/ogg › Save
--     ② Storage › Policies › lec-rec 의 New policy › For full customization › 셋을 만듦
--        lec_rec_put  · INSERT · Target roles anon, authenticated · 식 bucket_id = 'lec-rec' and public.lec_rec_slot(name)
--        lec_rec_read · SELECT · Target roles authenticated · 식 bucket_id = 'lec-rec' and (select public.lec_set_is_admin())
--        lec_rec_del  · DELETE · Target roles authenticated · 식 bucket_id = 'lec-rec' and (select public.lec_set_is_admin())
--     ③ 이 파일을 다시 넣어 맨 아래 «녹음 저장 곳» 이 «됨» 인지 봄
--   30일 지난 녹음 파일은 원장님이 선생님 화면을 열 때 지움(lec_rec_expired → 파일 지움 → lec_rec_gone) · 맨 아래 표 «30일 지난 녹음» = 아직 남은 수
create table if not exists public.lec_set (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,
  title       text not null,
  class_ids   text[] not null,
  posted_on   date not null default ((now() at time zone 'Asia/Seoul')::date),
  hidden      boolean not null default false,
  items       jsonb not null,
  n           integer not null,
  pick        text[] not null default '{}',
  made_by     text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint lec_set_kind_ok  check (kind in ('voc', 'gu', 'gram')),
  constraint lec_set_title_ok check (char_length(btrim(title)) between 1 and 60),
  constraint lec_set_cls_ok   check (cardinality(class_ids) between 1 and 30 and array_position(class_ids, null) is null
                                     and not ('*' = any (class_ids)) and not ('' = any (class_ids))),
  constraint lec_set_pick_ok  check (cardinality(pick) <= 2),
  constraint lec_set_items_ok check (case when jsonb_typeof(items) = 'array'
                                          then jsonb_array_length(items) = n
                                               and n between 1 and (case kind when 'voc' then 300 when 'gu' then 30 else 50 end)
                                          else false end)
);
create index if not exists lec_set_cls on public.lec_set using gin (class_ids);
create index if not exists lec_set_on  on public.lec_set (posted_on desc, created_at desc);

create table if not exists public.lec_set_prog (
  sid         text not null,
  set_id      uuid not null references public.lec_set (id) on delete cascade,
  cards       jsonb not null default '{}'::jsonb,
  kn          text[] not null default '{}',
  tn          integer not null default 0,
  f1          integer,
  last_sc     integer,
  best        integer not null default 0,
  pass_at     timestamptz,
  sv_day      date,
  sv_n        integer not null default 0,
  first_at    timestamptz not null default now(),
  last_at     timestamptz not null default now(),
  primary key (sid, set_id),
  constraint lec_set_prog_cards_ok check (jsonb_typeof(cards) = 'object')
);
create index if not exists lec_set_prog_set on public.lec_set_prog (set_id);

create table if not exists public.lec_set_try (
  id          uuid primary key default gen_random_uuid(),
  sid         text not null,
  set_id      uuid references public.lec_set (id) on delete cascade,
  kind        text not null,
  day         date not null,
  n           integer not null,
  qs          jsonb not null,
  ans         jsonb not null default '[]'::jsonb,
  got         integer not null default 0,
  sc          integer not null default 0,
  created_at  timestamptz not null default now(),
  done_at     timestamptz,
  constraint lec_set_try_kind_ok check (kind in ('test', 'drill', 'due')),
  constraint lec_set_try_n_ok    check (n between 1 and 300)
);
create index if not exists lec_set_try_sid on public.lec_set_try (sid, set_id, created_at desc);
create index if not exists lec_set_try_day on public.lec_set_try (sid, kind, day);

create table if not exists public.lec_set_rec (
  id          uuid primary key default gen_random_uuid(),
  sid         text not null,
  set_id      uuid not null,
  k           text not null,
  path        text not null unique,
  mime        text not null,
  bytes       integer not null,
  ms          integer not null default 0,
  st          text not null default 'wait',
  exp_at      timestamptz not null,
  at          timestamptz not null default now(),
  done_at     timestamptz,
  mark        text not null default '',
  why         smallint not null default 0,
  heard_by    text not null default '',
  heard_at    timestamptz,
  constraint lec_set_rec_path_ok  check (path ~ '^[0-9a-f-]{36}/[0-9a-f]{32}[.](webm|m4a|ogg)$'),
  constraint lec_set_rec_mime_ok  check (mime in ('audio/webm', 'audio/mp4', 'audio/ogg')),
  constraint lec_set_rec_bytes_ok check (bytes between 1 and 1048576),
  constraint lec_set_rec_ms_ok    check (ms between 0 and 46000),
  constraint lec_set_rec_st_ok    check (st in ('wait', 'done', 'old', 'gone')),
  constraint lec_set_rec_mark_ok  check (mark in ('', 'ok', 'again')),
  constraint lec_set_rec_why_ok   check (why between 0 and 4 and (mark <> 'ok' or why = 0))
);
create index if not exists lec_set_rec_set on public.lec_set_rec (set_id, k);
create index if not exists lec_set_rec_sid on public.lec_set_rec (sid);
create index if not exists lec_set_rec_st  on public.lec_set_rec (st, at);

-- lec_rec_ok: S1-b 부터 안 씀(옛 녹음 동의 · 학교급 · 표와 줄은 그대로 · 읽고 쓰는 함수 없음 · 이름 바뀜 · 학생 지움 트리거만 옛 줄을 옮기거나 지움)
create table if not exists public.lec_rec_ok (
  sid         text primary key,
  lvl         text not null default '',
  lvl_at      timestamptz,
  how         text not null default '',
  ver         text not null default '',
  ok_at       timestamptz,
  ok_by       text not null default '',
  constraint lec_rec_ok_lvl_ok check (lvl in ('', 'e', 'm', 'h')),
  constraint lec_rec_ok_how_ok check (how in ('', 'self', 'paper', 'sms', 'phone'))
);

-- sv · sv_at: S1-b 부터 안 씀(옛 세트 기록 동의 판 · 칸은 그대로 둠 · 아무 함수도 읽거나 쓰지 않음)
alter table public.lec_consent add column if not exists sv text not null default '';
alter table public.lec_consent add column if not exists sv_at timestamptz;

-- 다섯 표: 표로는 아무도 못 읽고 못 씀(함수로만 · 정책 0)
revoke all on public.lec_set, public.lec_set_prog, public.lec_set_try, public.lec_set_rec, public.lec_rec_ok from public, anon, authenticated;
revoke truncate, references, trigger on public.lec_set, public.lec_set_prog, public.lec_set_try, public.lec_set_rec, public.lec_rec_ok from authenticated;
alter table public.lec_set      enable row level security;
alter table public.lec_set_prog enable row level security;
alter table public.lec_set_try  enable row level security;
alter table public.lec_set_rec  enable row level security;
alter table public.lec_rec_ok   enable row level security;

-- 새로 만든 함수 · 트리거라 정확한 모양으로 먼저 지우고 새로 만듦(권한은 아래 한곳에서 다시 줌)
--   트리거를 먼저 지워야 트리거 함수를 지울 수 있음 · lec_rec_slot · lec_set_is_admin 은 Storage 정책이 걸려 있어 지우지 않고 바꿔 씀
--   S1-b 에서 없앰 · 다시 안 만듦(아래 drop 만 남김 · 운영에서 지우고 빈 DB 에서는 할 일 없음 · 부르는 곳 0):
--     lec__set_ver · lec__rec_ver · lec__set_ok · lec__rec_can · lec_set_agree · lec_rec_agree · lec_rec_off · lec_rec_guard · lec_rec_lvl
drop trigger if exists lec_key_set_mv on public.lec_key;
drop trigger if exists lec_consent_set_mv on public.lec_consent;
drop trigger if exists lec_consent_set_gone on public.lec_consent;
drop function if exists public.lec__set_ver();
drop function if exists public.lec__rec_ver();
drop function if exists public.lec__set_today();
drop function if exists public.lec__set_ok(text);
drop function if exists public.lec__rec_can(text);
drop function if exists public.lec__set_open(public.lec_set, text[]);
drop function if exists public.lec__set_need(integer);
drop function if exists public.lec__set_norm(text);
drop function if exists public.lec__set_vars(text);
drop function if exists public.lec__set_alts(text);
drop function if exists public.lec__set_match(text, text);
drop function if exists public.lec__set_opts(text);
drop function if exists public.lec__set_txt(jsonb, text);
drop function if exists public.lec__set_ktext(text, jsonb);
drop function if exists public.lec__set_mark(jsonb, boolean, text, date);
drop function if exists public.lec__set_memo(jsonb);
drop function if exists public.lec__set_due_on(jsonb, date);
drop function if exists public.lec__set_keys(text, jsonb, jsonb);
drop function if exists public.lec__set_check(text, jsonb);
drop function if exists public.lec__set_qs(public.lec_set, text[], boolean);
drop function if exists public.lec__set_view(public.lec_set_try, jsonb);
drop function if exists public.lec__set_me(public.lec_set, text, date);
drop function if exists public.lec__set_end(public.lec_set_try, text, text[]);
drop function if exists public.lec__set_move(text, text);
drop function if exists public.lec__set_mv();
drop function if exists public.lec__set_gone();
drop function if exists public.lec__rec_store();
drop function if exists public.lec__set_busy(text, uuid);
drop function if exists public.lec__rec_exp(public.lec_set_rec);
drop function if exists public.lec__rec_has(text);
drop function if exists public.lec__rec_fcheck();
drop function if exists public.lec__rec_pol_ok(name, text, text, text);
drop function if exists public.lec__rec_open();
drop function if exists public.lec_set_home(text);
drop function if exists public.lec_set_agree(text, text);
drop function if exists public.lec_set_items(text, uuid);
drop function if exists public.lec_set_card(text, uuid, jsonb);
drop function if exists public.lec_set_test(text, uuid);
drop function if exists public.lec_set_due(text);
drop function if exists public.lec_set_ans(text, uuid, integer, text);
drop function if exists public.lec_rec_agree(text, text);
drop function if exists public.lec_rec_off(text);
drop function if exists public.lec_rec_begin(text, uuid, text, text, integer, integer);
drop function if exists public.lec_rec_done(text, uuid);
drop function if exists public.lec_set_list_staff();
drop function if exists public.lec_set_get(uuid);
drop function if exists public.lec_set_put(uuid, text, text, text[], date, jsonb, integer[]);
drop function if exists public.lec_set_hide(uuid, boolean);
drop function if exists public.lec_set_del(uuid);
drop function if exists public.lec_set_staff(uuid);
drop function if exists public.lec_set_wrong_staff(text);
drop function if exists public.lec_rec_mark(uuid, text, integer);
drop function if exists public.lec_rec_guard(text, text, boolean);
drop function if exists public.lec_rec_lvl(jsonb);
drop function if exists public.lec_rec_expired();
drop function if exists public.lec_rec_gone(uuid[]);

-- 오늘(서울 날짜)
create or replace function public.lec__set_today() returns date
language sql stable set search_path = public as $$
  select (now() at time zone 'Asia/Seoul')::date
$$;

-- 이 학생(반 목록)에게 보이는 세트: 숨김 아님 · 공개일 지남 · 반이 겹침
create or replace function public.lec__set_open(s public.lec_set, p_cls text[]) returns boolean
language sql stable set search_path = public as $$
  select not s.hidden and s.posted_on <= public.lec__set_today()
         and coalesce(cardinality(p_cls) > 0 and s.class_ids && p_cls, false)
$$;

-- 이 학생이 이 세트의 시험 · 드릴 판을 열어 둠(끝나기 전) → 쌓인 오답 판에서 그 세트 문항을 빼고 답도 받지 않음(정답 엿보기 막기)
create or replace function public.lec__set_busy(p_sid text, p_set uuid) returns boolean
language sql stable set search_path = public as $$
  select exists (select 1 from public.lec_set_try xt
                  where xt.sid = p_sid and xt.set_id = p_set and xt.kind in ('test', 'drill') and xt.done_at is null)
$$;

-- 통과 수 = 90% 올림(정수 셈)
create or replace function public.lec__set_need(p_n integer) returns integer
language sql immutable set search_path = public as $$
  select case when coalesce(p_n, 0) <= 0 then 0 else (p_n * 9 + 9) / 10 end
$$;

-- 쓰기 답 맞추기 글(class-api.js Lec.setNorm 과 같은 셈 · 소문자는 A~Z 만 · 빈칸 무리는 여섯 글자만)
create or replace function public.lec__set_norm(p_t text) returns text
language sql immutable set search_path = public as $$
  select btrim(regexp_replace(
           btrim(regexp_replace(
             translate(
               translate(normalize(coalesce(p_t, ''), NFC),
                         chr(8217) || chr(8216) || chr(700) || chr(8242) || chr(8220) || chr(8221) || chr(8243)
                           || chr(160) || chr(12288) || '~' || chr(8764) || chr(12316),
                         '''''''''"""  '),
               'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'),
             '[' || chr(32) || chr(9) || chr(10) || chr(11) || chr(12) || chr(13) || ']+', ' ', 'g'), ' '),
           '[.]+$', ''), ' ')
$$;

-- 한 답의 꼴들: 괄호와 그 안을 뺀 것 · 괄호 글자만 뺀 것
create or replace function public.lec__set_vars(p_t text) returns text[]
language sql immutable set search_path = public as $$
  select coalesce(array_agg(distinct x.v), '{}'::text[])
    from unnest(array[public.lec__set_norm(regexp_replace(coalesce(p_t, ''), '[(][^()]*[)]', ' ', 'g')),
                      public.lec__set_norm(translate(coalesce(p_t, ''), '()', ''))]) as x(v)
   where x.v <> ''
$$;

-- 정답 글의 모든 꼴(«/» 로 나눈 조각마다)
create or replace function public.lec__set_alts(p_ans text) returns text[]
language sql immutable set search_path = public as $$
  select coalesce(array_agg(distinct y.v), '{}'::text[])
    from unnest(string_to_array(coalesce(p_ans, ''), '/')) as x(part)
   cross join lateral unnest(public.lec__set_vars(x.part)) as y(v)
$$;

-- 학생 답(나누지 않음)이 정답 꼴 하나와 같으면 맞음
create or replace function public.lec__set_match(p_v text, p_ans text) returns boolean
language sql immutable set search_path = public as $$
  select public.lec__set_vars(p_v) && public.lec__set_alts(p_ans)
$$;

-- 문법 고르기 보기: 첫 ( a / b ) 묶음을 «/» 로 나눈 것 · 없으면 null
create or replace function public.lec__set_opts(p_s text) returns text[]
language sql immutable set search_path = public as $$
  select case when x.m is null then null
              else array(select btrim(o.v) from unnest(string_to_array(x.m[1], '/')) with ordinality as o(v, i) order by o.i) end
    from (select regexp_match(coalesce(p_s, ''), '[(]([^()]*/[^()]*)[)]') as m) x
$$;

-- 문항 칸 글(글자 · 숫자만 · 줄바꿈 · 탭은 빈칸 · 앞뒤 빈칸 지움)
create or replace function public.lec__set_txt(p_e jsonb, p_f text) returns text
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(p_e -> p_f) in ('string', 'number')
              then btrim(translate(p_e ->> p_f, chr(9) || chr(10) || chr(11) || chr(12) || chr(13), '     '))
              else '' end
$$;

-- 열쇠 맞춤 글: 단어 = 단어 · 구문 = 영어(«/» 지움) · 문법 = 문제
create or replace function public.lec__set_ktext(p_kind text, p_e jsonb) returns text
language sql immutable set search_path = public as $$
  select public.lec__set_norm(case p_kind when 'voc' then public.lec__set_txt(p_e, 'w')
                                          when 'gu' then replace(public.lec__set_txt(p_e, 'e'), '/', ' ')
                                          else public.lec__set_txt(p_e, 's') end)
$$;

-- 카드 한 칸 고치기(s 넘겨 봄 · g 알아요 · d 맞힌 날 셋 · t 시험 맞힌 날 · z 쌓인 오답 날 · y z 뒤 맞힌 날 둘 · w 틀린 수)
create or replace function public.lec__set_mark(p_c jsonb, p_ok boolean, p_src text, p_day date) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_c   jsonb := case when jsonb_typeof(p_c) = 'object' then p_c else '{}'::jsonb end;
  v_day text := to_char(p_day, 'YYYY-MM-DD');
  v_d   jsonb;
  v_y   jsonb;
begin
  if p_src in ('card', 'say') then
    v_c := v_c || jsonb_build_object('s', 1);
    if p_ok and p_src = 'say' then
      v_c := v_c || jsonb_build_object('g', 1);
    elsif p_ok then
      select coalesce(jsonb_agg(b.x order by b.x), '[]'::jsonb) into v_d
        from (select a.x from (select jsonb_array_elements_text(case when jsonb_typeof(v_c -> 'd') = 'array' then v_c -> 'd' else '[]'::jsonb end) as x
                               union select v_day) a
               order by a.x desc limit 3) b;
      v_c := v_c || jsonb_build_object('d', v_d);
    end if;
    return v_c;
  end if;
  if not coalesce(p_ok, false) then
    return (v_c - 'd' - 't' - 'y')
           || jsonb_build_object('w', (case when jsonb_typeof(v_c -> 'w') = 'number' then (v_c ->> 'w')::integer else 0 end) + 1, 'z', v_day);
  end if;
  select coalesce(jsonb_agg(b.x order by b.x), '[]'::jsonb) into v_d
    from (select a.x from (select jsonb_array_elements_text(case when jsonb_typeof(v_c -> 'd') = 'array' then v_c -> 'd' else '[]'::jsonb end) as x
                           union select v_day) a
           order by a.x desc limit 3) b;
  v_c := v_c || jsonb_build_object('d', v_d);
  if p_src <> 'due' then
    v_c := v_c || jsonb_build_object('t', v_day);
  end if;
  if coalesce(v_c ->> 'z', '') <> '' and v_day > (v_c ->> 'z') then
    select coalesce(jsonb_agg(b.x order by b.x), '[]'::jsonb) into v_y
      from (select a.x from (select jsonb_array_elements_text(case when jsonb_typeof(v_c -> 'y') = 'array' then v_c -> 'y' else '[]'::jsonb end) as x
                             union select v_day) a
             order by a.x desc limit 2) b;
    if jsonb_array_length(v_y) >= 2 then
      v_c := v_c - 'z' - 'y';
    else
      v_c := v_c || jsonb_build_object('y', v_y);
    end if;
  end if;
  return v_c;
end
$$;

-- 외움 = 맞힌 날 둘 이상 + 시험 · 드릴에서 맞힌 날 있음
create or replace function public.lec__set_memo(p_c jsonb) returns boolean
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(p_c -> 'd') = 'array'
              then jsonb_array_length(p_c -> 'd') >= 2 and coalesce(p_c ->> 't', '') <> ''
              else false end
$$;

-- 오늘 쌓인 오답에 나옴 = z 가 오늘 앞 · 오늘 아직 안 맞힘
create or replace function public.lec__set_due_on(p_c jsonb, p_day date) returns boolean
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(p_c) = 'object' and coalesce(p_c ->> 'z', '') <> ''
              then (p_c ->> 'z') < to_char(p_day, 'YYYY-MM-DD')
                   and not (case when jsonb_typeof(p_c -> 'y') = 'array'
                                 then (p_c -> 'y') @> to_jsonb(to_char(p_day, 'YYYY-MM-DD'))
                                 else false end)
              else false end
$$;

-- 문항 열쇠 매기기: 새 문항마다 아직 안 쓴 옛 문항 가운데 맞춤 글이 같은 첫 것의 열쇠 · 없으면 가장 큰 번호 + 1
create or replace function public.lec__set_keys(p_kind text, p_old jsonb, p_new jsonb) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_ok   text[] := '{}';
  v_ot   text[] := '{}';
  v_used boolean[] := '{}';
  v_max  integer := 0;
  v_out  jsonb := '[]'::jsonb;
  v_e    jsonb;
  v_t    text;
  v_k    text;
begin
  for v_e in select u.e from jsonb_array_elements(case when jsonb_typeof(p_old) = 'array' then p_old else '[]'::jsonb end)
                        with ordinality as u(e, o) order by u.o loop
    v_k := coalesce(v_e ->> 'k', '');
    if v_k ~ '^k[0-9]{1,6}$' then
      v_max := greatest(v_max, substr(v_k, 2)::integer);
      v_ok := v_ok || v_k;
      v_ot := v_ot || public.lec__set_ktext(p_kind, v_e);
      v_used := v_used || false;
    end if;
  end loop;
  for v_e in select u.e from jsonb_array_elements(case when jsonb_typeof(p_new) = 'array' then p_new else '[]'::jsonb end)
                        with ordinality as u(e, o) order by u.o loop
    v_t := public.lec__set_ktext(p_kind, v_e);
    v_k := null;
    for i in 1 .. coalesce(array_length(v_ok, 1), 0) loop
      if not v_used[i] and v_ot[i] = v_t then
        v_k := v_ok[i];
        v_used[i] := true;
        exit;
      end if;
    end loop;
    if v_k is null then
      v_max := v_max + 1;
      v_k := 'k' || v_max::text;
    end if;
    v_out := v_out || jsonb_build_array((case when jsonb_typeof(v_e) = 'object' then v_e else '{}'::jsonb end)
                                        || jsonb_build_object('k', v_k));
  end loop;
  return v_out;
end
$$;

-- 문항 검사 · 고른 칸만 글자로: 맞으면 {ok, items} · 틀리면 {ok:false, err:'items', at:차례(0부터), why}
--   why: w m e t s a = 그 칸이 비거나 너무 김 · len = 번호 · 포인트 · 해설이 너무 김 · opt = 문법 ( / ) 규칙 · blank = 문법 [ ] 가 빔
create or replace function public.lec__set_check(p_kind text, p_items jsonb) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_e   jsonb;
  v_i   integer := -1;
  v_why text;
  v_n   text;
  v_a   text;
  v_b   text;
  v_c   text;
  v_d   text;
  v_pg  integer;
  v_bk  text[];
  v_op  text[];
begin
  if jsonb_typeof(p_items) is distinct from 'array' then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  for v_e in select u.e from jsonb_array_elements(p_items) with ordinality as u(e, o) order by u.o loop
    v_i := v_i + 1;
    v_why := '';
    v_n := public.lec__set_txt(v_e, 'n');
    if p_kind = 'voc' then
      v_a := public.lec__set_txt(v_e, 'w');
      v_b := public.lec__set_txt(v_e, 'm');
      if jsonb_typeof(v_e) is distinct from 'object' or char_length(v_a) not between 1 and 100 then
        v_why := 'w';
      elsif char_length(v_b) not between 1 and 200 then
        v_why := 'm';
      elsif char_length(v_n) > 8 then
        v_why := 'len';
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('n', v_n, 'w', v_a, 'm', v_b));
    elsif p_kind = 'gu' then
      v_a := public.lec__set_txt(v_e, 'e');
      v_b := public.lec__set_txt(v_e, 't');
      v_c := public.lec__set_txt(v_e, 'p');
      if jsonb_typeof(v_e) is distinct from 'object' or char_length(v_a) not between 1 and 300 then
        v_why := 'e';
      elsif char_length(v_b) not between 1 and 300 then
        v_why := 't';
      elsif char_length(v_n) > 8 or char_length(v_c) > 60 then
        v_why := 'len';
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('n', v_n, 'e', v_a, 't', v_b, 'p', v_c));
    else
      v_a := public.lec__set_txt(v_e, 's');
      v_b := public.lec__set_txt(v_e, 'a');
      v_c := public.lec__set_txt(v_e, 'x');
      v_d := public.lec__set_txt(v_e, 'p');
      select count(*) into v_pg from regexp_matches(v_a, '[(]([^()]*/[^()]*)[)]', 'g') as g(m);
      select array_agg(g.m[1]) into v_bk from regexp_matches(v_a, '[[]([^]]*)[]]', 'g') as g(m);
      if jsonb_typeof(v_e) is distinct from 'object' or char_length(v_a) not between 1 and 300 then
        v_why := 's';
      elsif char_length(v_b) not between 1 and 100 then
        v_why := 'a';
      elsif v_pg + coalesce(cardinality(v_bk), 0) <> 1 then
        v_why := 'opt';
      elsif v_pg = 1 then
        v_op := public.lec__set_opts(v_a);
        if cardinality(v_op) not between 2 and 5 or '' = any (v_op) or not (v_b = any (v_op)) then
          v_why := 'opt';
        end if;
      elsif btrim(v_bk[1]) = '' then
        v_why := 'blank';
      end if;
      if v_why = '' and (char_length(v_n) > 8 or char_length(v_c) > 300 or char_length(v_d) > 40) then
        v_why := 'len';
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('n', v_n, 's', v_a, 'a', v_b, 'x', v_c, 'p', v_d));
    end if;
    if v_why <> '' then
      return jsonb_build_object('ok', false, 'err', 'items', 'at', v_i, 'why', v_why);
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'items', v_out);
end
$$;

-- 시험 · 드릴 문항 짜기(서버만 · 정답 a 해설 x 포인트 pt 열쇠 k 가 들어 있음 · 학생에게는 lec__set_view 로 뺀 것만)
--   단어 첫 시도 = 모든 문항(차례 짝수 c 뜻 고르기 · 홀수 w 영어 쓰기) · 다시 보기 = 틀린 것 전부 w + 맞힌 것 같은 수(무작위)
--   c 보기 = 맞는 뜻 + 다른 뜻 셋(맞춤 글이 서로 다른 것) · 셋이 안 되면 w · 문법 = 모든 문항 · ( / ) 는 c · [ ] 는 r
create or replace function public.lec__set_qs(s public.lec_set, p_kn text[], p_retake boolean) returns jsonb
language plpgsql volatile set search_path = public as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_e   record;
  v_f   text;
  v_o   jsonb;
  v_wr  integer;
  v_ms  jsonb;
  v_nm  text;
begin
  if s.kind = 'gram' then
    for v_e in select u.e from jsonb_array_elements(s.items) as u(e) order by random() loop
      v_o := to_jsonb(public.lec__set_opts(v_e.e ->> 's'));
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'k', v_e.e ->> 'k', 'f', case when v_o is null then 'r' else 'c' end, 'p', v_e.e ->> 's', 'o', v_o,
        'a', v_e.e ->> 'a', 'x', coalesce(v_e.e ->> 'x', ''), 'pt', coalesce(v_e.e ->> 'p', '')));
    end loop;
    return v_out;
  end if;
  select count(*) into v_wr
    from jsonb_array_elements(s.items) as u(e)
   where not ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[])));
  -- 보기 후보: 뜻을 한 번만 정규화(정규화 값마다 하나 · 같은 값 가운데 무작위 하나)
  select coalesce(jsonb_agg(jsonb_build_object('m', d.m, 'nm', d.nm)), '[]'::jsonb) into v_ms
    from (select distinct on (y.nm) y.m, y.nm
            from (select o2.e ->> 'm' as m, public.lec__set_norm(o2.e ->> 'm') as nm
                    from jsonb_array_elements(s.items) as o2(e)) y
           order by y.nm, random()) d;
  for v_e in
    select x.e, x.f from (
      select u.e,
             case when coalesce(p_retake, false) and not ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[]))) then 'w'
                  when u.o % 2 = 1 then 'c' else 'w' end as f,
             coalesce(p_retake, false) and ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[]))) as kn,
             row_number() over (partition by coalesce(p_retake, false) and ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[])))
                                order by random()) as rk
        from jsonb_array_elements(s.items) with ordinality as u(e, o)) x
     where not x.kn or x.rk <= v_wr
     order by random()
  loop
    v_f := v_e.f;
    v_o := null;
    if v_f = 'c' then
      v_nm := public.lec__set_norm(v_e.e ->> 'm');
      select jsonb_agg(c.m order by random()) into v_o
        from (select v_e.e ->> 'm' as m
              union all
              (select d.e ->> 'm' from jsonb_array_elements(v_ms) as d(e)
                where d.e ->> 'nm' <> v_nm
                order by random() limit 3)) c;
      if jsonb_array_length(coalesce(v_o, '[]'::jsonb)) < 4 then
        v_f := 'w';
        v_o := null;
      end if;
    end if;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'k', v_e.e ->> 'k', 'f', v_f, 'p', case when v_f = 'c' then v_e.e ->> 'w' else v_e.e ->> 'm' end, 'o', v_o,
      'a', case when v_f = 'c' then v_e.e ->> 'm' else v_e.e ->> 'w' end, 'x', '', 'pt', ''));
  end loop;
  return v_out;
end
$$;

-- 학생에게 보내는 한 판(정답 · 해설 · 열쇠 뺌 · 이미 답한 문항만 결과와 함께)
create or replace function public.lec__set_view(t public.lec_set_try, p_head jsonb) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('ok', true, 'try', t.id, 'kind', t.kind, 'n', t.n) || coalesce(p_head, '{}'::jsonb)
         || jsonb_build_object(
              'q', (select coalesce(jsonb_agg(case when t.kind = 'due'
                                                   then jsonb_build_object('f', u.q ->> 'f', 'p', u.q ->> 'p', 'o', u.q -> 'o',
                                                                           'kd', u.q ->> 'kd', 't', u.q ->> 't')
                                                   else jsonb_build_object('f', u.q ->> 'f', 'p', u.q ->> 'p', 'o', u.q -> 'o') end
                                              order by u.i), '[]'::jsonb)
                      from jsonb_array_elements(t.qs) with ordinality as u(q, i)),
              'done', (select coalesce(jsonb_agg(jsonb_build_object(
                                 'i', v.i - 1, 'v', v.a ->> 'v', 'r', (v.a ->> 'r')::boolean,
                                 'a', t.qs -> (v.i::integer - 1) ->> 'a',
                                 'x', coalesce(t.qs -> (v.i::integer - 1) ->> 'x', ''),
                                 'pt', coalesce(t.qs -> (v.i::integer - 1) ->> 'pt', '')) order by v.i), '[]'::jsonb)
                         from jsonb_array_elements(t.ans) with ordinality as v(a, i)
                        where jsonb_typeof(v.a) = 'object'))
$$;

-- 학생 × 세트 요약(학생 목록 · 선생님 결과 표가 같이 씀 · 지금 문항 열쇠만 셈 · 구문 spk = 말해서 확인한 문장 수(카드 v 1))
create or replace function public.lec__set_me(s public.lec_set, p_sid text, p_day date) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  p       public.lec_set_prog;
  v_cards jsonb;
  v_keys  text[];
  v_seen  integer;
  v_known integer;
  v_said  integer;
  v_spk   integer;
  v_due   integer;
  v_kn    integer;
  v_open  integer;
  v_day   integer;
  v_test  text;
  v_recs  jsonb;
begin
  select * into p from public.lec_set_prog xp where xp.sid = p_sid and xp.set_id = s.id;
  v_cards := coalesce(p.cards, '{}'::jsonb);
  select coalesce(array_agg(u.e ->> 'k'), '{}'::text[]) into v_keys from jsonb_array_elements(s.items) as u(e);
  select count(*) filter (where (v_cards -> y.kk ->> 's') = '1'),
         count(*) filter (where public.lec__set_memo(v_cards -> y.kk)),
         count(*) filter (where (v_cards -> y.kk ->> 'g') = '1'),
         count(*) filter (where (v_cards -> y.kk ->> 'v') = '1'),
         count(*) filter (where coalesce(v_cards -> y.kk ->> 'z', '') <> '')
    into v_seen, v_known, v_said, v_spk, v_due
    from unnest(v_keys) as y(kk);
  select count(*) into v_kn from unnest(coalesce(p.kn, '{}'::text[])) as y(kk) where y.kk = any (v_keys);
  select coalesce(max(xt.got), -1) into v_open
    from public.lec_set_try xt where xt.sid = p_sid and xt.set_id = s.id and xt.done_at is null;
  select count(*) into v_day
    from public.lec_set_try xt where xt.sid = p_sid and xt.set_id = s.id and xt.day = p_day and xt.kind in ('test', 'drill');
  v_test := case when p.pass_at is not null then 'pass' when v_open >= 0 then 'open'
                 when coalesce(p.tn, 0) > 0 then 'fail' else 'none' end;
  if s.kind = 'voc' then
    return jsonb_build_object('seen', v_seen, 'known', v_known, 'due', v_due, 'test', v_test, 'tn', coalesce(p.tn, 0),
                              'kn', v_kn, 'best', coalesce(p.best, 0), 'f1', p.f1, 'left', greatest(0, 5 - v_day),
                              'got', greatest(v_open, 0));
  elsif s.kind = 'gram' then
    return jsonb_build_object('due', v_due, 'test', v_test, 'tn', coalesce(p.tn, 0), 'best', coalesce(p.best, 0), 'f1', p.f1,
                              'last_sc', p.last_sc,
                              'next', case when p.pass_at is not null then 'pass' when v_open < 0 and v_day > 0 then 'tomorrow' else 'now' end,
                              'got', greatest(v_open, 0));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'k', pk.kk,
           'st', case when lr.id is null then '' when lr.mark = 'again' then 'again' when lr.mark = 'ok' then 'ok' else 'sent' end,
           'why', coalesce(lr.why, 0), 'at', lr.done_at) order by pk.o), '[]'::jsonb)
    into v_recs
    from unnest(s.pick) with ordinality as pk(kk, o)
    left join lateral (select xr.id, xr.mark, xr.why, xr.done_at from public.lec_set_rec xr
                        where xr.sid = p_sid and xr.set_id = s.id and xr.k = pk.kk and xr.st in ('done', 'gone')
                        order by xr.done_at desc nulls last limit 1) lr on true;
  return jsonb_build_object('seen', v_seen, 'said', v_said, 'spk', v_spk, 'recs', v_recs);
end
$$;

-- 끝난 판의 결과(같은 문항을 다시 보낼 때도 같은 셈 · 다음 = retake 오늘 남음 · tomorrow · pass · none 쌓인 오답)
--   쌓인 오답 판은 out(이 판 문항 가운데 이제 z 없는 수) · due(보이는 세트에 남은 쌓인 오답 수 = 목록 due.n)를 더 줌
create or replace function public.lec__set_end(t public.lec_set_try, p_sid text, p_cls text[]) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  s      public.lec_set;
  p      public.lec_set_prog;
  v_kn   integer := 0;
  v_need integer;
  v_tot  integer;
  v_pass boolean;
  v_cnt  integer;
  v_next text;
  v_out  integer;
  v_due  integer;
begin
  if t.done_at is null then
    return null;
  end if;
  if t.kind = 'due' then
    select count(*) into v_out
      from jsonb_array_elements(t.qs) as u(e)
      join public.lec_set_prog xp on xp.sid = p_sid and xp.set_id = (u.e ->> 's')::uuid
     where coalesce(xp.cards -> (u.e ->> 'k') ->> 'z', '') = '';
    select count(*) into v_due
      from public.lec_set xs
      join public.lec_set_prog xp on xp.set_id = xs.id and xp.sid = p_sid
     cross join lateral jsonb_array_elements(xs.items) as u(e)
     where xs.kind in ('voc', 'gram') and public.lec__set_open(xs, p_cls)
       and coalesce(xp.cards -> (u.e ->> 'k') ->> 'z', '') <> '';
    return jsonb_build_object('sc', t.sc, 'n', t.n, 'total', t.n, 'need', 0, 'kn', 0, 'pass', false,
                              'ever', t.n - t.sc, 'f1', null, 'next', 'none', 'out', v_out, 'due', v_due);
  end if;
  select * into s from public.lec_set xs where xs.id = t.set_id;
  select * into p from public.lec_set_prog xp where xp.sid = p_sid and xp.set_id = t.set_id;
  v_tot := coalesce(s.n, t.n);
  if t.kind = 'test' then
    v_need := public.lec__set_need(v_tot);
    select count(*) into v_kn from unnest(coalesce(p.kn, '{}'::text[])) as y(kk)
     where y.kk in (select u.e ->> 'k' from jsonb_array_elements(coalesce(s.items, '[]'::jsonb)) as u(e));
    v_pass := p.pass_at is not null;
    select count(*) into v_cnt from public.lec_set_try xt
     where xt.sid = p_sid and xt.set_id = t.set_id and xt.kind = 'test' and xt.day = public.lec__set_today();
    v_next := case when v_pass then 'pass' when v_cnt < 5 then 'retake' else 'tomorrow' end;
  else
    v_need := public.lec__set_need(t.n);
    v_pass := t.sc >= v_need;
    v_next := case when v_pass then 'pass' else 'tomorrow' end;
  end if;
  return jsonb_build_object('sc', t.sc, 'n', t.n, 'total', v_tot, 'need', v_need, 'kn', v_kn, 'pass', v_pass,
                            'ever', t.n - t.sc, 'f1', p.f1, 'next', v_next);
end
$$;

-- 이름 바뀐 학생의 세트 기록 옮기기(트리거가 부름 · 새 열쇠에 같은 세트 진도가 있으면 새 것을 둠)
create or replace function public.lec__set_move(p_old text, p_new text) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if p_old is null or p_new is null or p_old = p_new or p_old = '' or p_new = '' then
    return;
  end if;
  delete from public.lec_set_prog xp
   where xp.sid = p_old and exists (select 1 from public.lec_set_prog y where y.sid = p_new and y.set_id = xp.set_id);
  update public.lec_set_prog xp set sid = p_new where xp.sid = p_old;
  update public.lec_set_try xt set sid = p_new where xt.sid = p_old;
  update public.lec_set_rec xr set sid = p_new where xr.sid = p_old;
  if exists (select 1 from public.lec_rec_ok xo where xo.sid = p_new) then
    delete from public.lec_rec_ok xo where xo.sid = p_old;
  else
    update public.lec_rec_ok xo set sid = p_new where xo.sid = p_old;
  end if;
end
$$;

-- 트리거: 학생 열쇠 · 동의 줄의 sid 가 바뀌면 옮김(lec__move 안에서)
create or replace function public.lec__set_mv() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.sid is distinct from new.sid then
    perform public.lec__set_move(old.sid, new.sid);
  end if;
  return null;
end
$$;

-- 트리거: 동의 줄이 지워지면(lec_forget · 이름 바뀜 때 옛 줄) 세트 기록 지움 · 녹음은 다음 정리 때 파일까지 지움
create or replace function public.lec__set_gone() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.lec_set_prog xp where xp.sid = old.sid;
  delete from public.lec_set_try xt where xt.sid = old.sid;
  delete from public.lec_set_rec xr where xr.sid = old.sid and xr.st = 'gone';
  update public.lec_set_rec xr set st = case when xr.st in ('wait', 'done') then 'old' else xr.st end, sid = ''
   where xr.sid = old.sid;
  delete from public.lec_rec_ok xo where xo.sid = old.sid;
  return null;
end
$$;

create trigger lec_key_set_mv after update of sid on public.lec_key
  for each row execute function public.lec__set_mv();
create trigger lec_consent_set_mv after update of sid on public.lec_consent
  for each row execute function public.lec__set_mv();
create trigger lec_consent_set_gone after delete on public.lec_consent
  for each row execute function public.lec__set_gone();

-- 학생: 공부 묶음 목록(보이는 세트 40개 · 내 진도 · 쌓인 오답 수) · 히즈클래스 기록 동의만 봄(세트 동의 · 녹음 동의는 S1-b 에서 뺌)
--   'agree' true · 'rec' {ok true} 는 옛 화면(동의 카드 · 녹음 동의 길이 있던 판)이 바로 열리게 그대로 돌려줌 · 새 화면은 안 읽음
create or replace function public.lec_set_home(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_day   date := public.lec__set_today();
  v_sets  jsonb;
  v_due   jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', xs.id, 'kind', xs.kind, 'title', xs.title, 'n', xs.n, 'need', public.lec__set_need(xs.n),
           'on', xs.posted_on, 'pick', cardinality(xs.pick),
           'me', public.lec__set_me(xs, k.sid, v_day))
           order by xs.posted_on desc, xs.created_at desc), '[]'::jsonb)
    into v_sets
    from public.lec_set xs
   where xs.id in (select y.id from public.lec_set y
                    where public.lec__set_open(y, k.cls)
                    order by y.posted_on desc, y.created_at desc limit 40);
  -- 숨김 · 공개 전 · 다른 반 세트는 문항을 풀기 전에 거름(lec__set_open 은 xs 한 표 조건) ·
  -- 시험 · 드릴 판이 열린 세트는 now 에서 뺌(lec__set_busy 는 세트마다 한 번)
  select jsonb_build_object('n', coalesce(sum(y.n), 0)::integer,
                            'now', coalesce(sum(y.nw) filter (where not public.lec__set_busy(k.sid, y.id)), 0)::integer)
    into v_due
    from (select xs.id, count(*) as n, count(*) filter (where public.lec__set_due_on(c.card, v_day)) as nw
            from public.lec_set xs
            join public.lec_set_prog xp on xp.set_id = xs.id and xp.sid = k.sid
           cross join lateral (select xp.cards -> (u.e ->> 'k') as card from jsonb_array_elements(xs.items) as u(e)) c
           where xs.kind in ('voc', 'gram') and public.lec__set_open(xs, k.cls)
             and coalesce(c.card ->> 'z', '') <> ''
           group by xs.id) y;
  return jsonb_build_object('ok', true, 'today', to_char(v_day, 'YYYY-MM-DD'), 'agree', true,
                            'sets', v_sets, 'due', v_due, 'rec', jsonb_build_object('ok', true));
end
$$;

-- 학생: 외우기 · 따라 말하기 문항(단어 · 구문만 · 단어 시험이 열려 있으면 안 줌 · 문법은 안 줌)
create or replace function public.lec_set_items(p_key text, p_set uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  s       public.lec_set;
  v_cards jsonb;
  v_items jsonb;
  v_me    jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found or not public.lec__set_open(s, k.cls) then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if s.kind = 'gram' then
    return jsonb_build_object('ok', false, 'err', 'kind');
  end if;
  if s.kind = 'voc' and exists (select 1 from public.lec_set_try xt
                                 where xt.sid = k.sid and xt.set_id = s.id and xt.kind = 'test' and xt.done_at is null) then
    return jsonb_build_object('ok', false, 'err', 'testing');
  end if;
  select coalesce(xp.cards, '{}'::jsonb) into v_cards from public.lec_set_prog xp where xp.sid = k.sid and xp.set_id = s.id;
  v_cards := coalesce(v_cards, '{}'::jsonb);
  select coalesce(jsonb_agg(case when s.kind = 'voc'
                                 then jsonb_build_object('k', u.e ->> 'k', 'n', coalesce(u.e ->> 'n', ''), 'w', u.e ->> 'w', 'm', u.e ->> 'm')
                                 else jsonb_build_object('k', u.e ->> 'k', 'n', coalesce(u.e ->> 'n', ''), 'e', u.e ->> 'e',
                                                         't', u.e ->> 't', 'p', coalesce(u.e ->> 'p', '')) end
                            order by u.o), '[]'::jsonb)
    into v_items
    from jsonb_array_elements(s.items) with ordinality as u(e, o);
  if s.kind = 'voc' then
    return jsonb_build_object('ok', true, 'id', s.id, 'kind', s.kind, 'title', s.title, 'n', s.n, 'items', v_items, 'cards', v_cards);
  end if;
  v_me := public.lec__set_me(s, k.sid, public.lec__set_today());
  return jsonb_build_object('ok', true, 'id', s.id, 'kind', s.kind, 'title', s.title, 'n', s.n, 'items', v_items,
                            'pick', to_jsonb(s.pick), 'cards', v_cards, 'recs', v_me -> 'recs',
                            'rec', jsonb_build_object('ok', true));   -- 옛 화면이 ★ 녹음을 바로 열게(S1-b · 녹음 동의 없음)
end
$$;

-- 학생: 외우기 한 판 · 따라 말하기 결과 저장(한 판에 한 번 · {열쇠: 1 알아요 | 0 다시} · 하루 200번)
--   구문만 2 = 알아요 + 말해서 확인(폰 음성 인식으로 통과) → 1 과 같게 적고 카드에 v 1(한 번 생기면 남음 · 0 · 1 은 v 를 안 건드림)
--   단어에 2 · 그 밖 값 = 'input'
create or replace function public.lec_set_card(p_key text, p_set uuid, p_marks jsonb)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k     public.lec_key;
  s     public.lec_set;
  p     public.lec_set_prog;
  v_day date := public.lec__set_today();
  v_c   jsonb;
  v_kk  text;
  v_v   jsonb;
  v_me  jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found or not public.lec__set_open(s, k.cls) then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if s.kind = 'gram' then
    return jsonb_build_object('ok', false, 'err', 'kind');
  end if;
  if jsonb_typeof(p_marks) is distinct from 'object' or octet_length(p_marks::text) > 4096 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  if (select count(*) from jsonb_object_keys(p_marks)) > 40
     or exists (select 1 from jsonb_each(p_marks) as u(kk, v)
                 where u.v not in ('0'::jsonb, '1'::jsonb) and not (s.kind = 'gu' and u.v = '2'::jsonb)) then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  insert into public.lec_set_prog (sid, set_id) values (k.sid, s.id) on conflict (sid, set_id) do nothing;
  select * into p from public.lec_set_prog xp where xp.sid = k.sid and xp.set_id = s.id for update;
  if p.sv_day = v_day and p.sv_n >= 200 then
    return jsonb_build_object('ok', false, 'err', 'limit');
  end if;
  v_c := p.cards;
  for v_kk, v_v in select u.kk, u.v from jsonb_each(p_marks) as u(kk, v) loop
    if exists (select 1 from jsonb_array_elements(s.items) as y(e) where y.e ->> 'k' = v_kk) then
      v_c := jsonb_set(v_c, array[v_kk],
                       public.lec__set_mark(v_c -> v_kk, v_v in ('1'::jsonb, '2'::jsonb), case when s.kind = 'voc' then 'card' else 'say' end, v_day));
      if v_v = '2'::jsonb then
        v_c := jsonb_set(v_c, array[v_kk], (v_c -> v_kk) || jsonb_build_object('v', 1));
      end if;
    end if;
  end loop;
  update public.lec_set_prog xp
     set cards = v_c, sv_n = case when xp.sv_day = v_day then xp.sv_n + 1 else 1 end, sv_day = v_day, last_at = now()
   where xp.sid = k.sid and xp.set_id = s.id;
  v_me := public.lec__set_me(s, k.sid, v_day);
  if s.kind = 'voc' then
    return jsonb_build_object('ok', true, 'seen', v_me -> 'seen', 'known', v_me -> 'known');
  end if;
  return jsonb_build_object('ok', true, 'seen', v_me -> 'seen', 'said', v_me -> 'said');
end
$$;

-- 학생: 단어 시험 · 문법 드릴 열기(열린 판이 있으면 이어서 · 단어 하루 5번 · 문법 하루 1번 · 통과 뒤 없음)
create or replace function public.lec_set_test(p_key text, p_set uuid)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k     public.lec_key;
  s     public.lec_set;
  p     public.lec_set_prog;
  t     public.lec_set_try;
  v_day date := public.lec__set_today();
  v_qs  jsonb;
  v_kn  integer;
  v_cnt integer;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found or not public.lec__set_open(s, k.cls) then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if s.kind = 'gu' then
    return jsonb_build_object('ok', false, 'err', 'kind');
  end if;
  insert into public.lec_set_prog (sid, set_id) values (k.sid, s.id) on conflict (sid, set_id) do nothing;
  select * into p from public.lec_set_prog xp where xp.sid = k.sid and xp.set_id = s.id for update;
  select count(*) into v_kn from unnest(p.kn) as y(kk)
   where y.kk in (select u.e ->> 'k' from jsonb_array_elements(s.items) as u(e));
  select * into t from public.lec_set_try xt
   where xt.sid = k.sid and xt.set_id = s.id and xt.done_at is null
   order by xt.created_at desc limit 1;
  if not found then
    if p.pass_at is not null then
      return jsonb_build_object('ok', false, 'err', 'pass');
    end if;
    -- 고쳐서 남은 문항을 이미 다 맞혔으면 바로 통과
    if s.kind = 'voc' and p.tn > 0 and v_kn >= public.lec__set_need(s.n) then
      update public.lec_set_prog xp set pass_at = now(), best = greatest(xp.best, (v_kn * 100) / s.n)
       where xp.sid = k.sid and xp.set_id = s.id;
      return jsonb_build_object('ok', false, 'err', 'pass');
    end if;
    select count(*) into v_cnt from public.lec_set_try xt
     where xt.sid = k.sid and xt.set_id = s.id and xt.day = v_day and xt.kind in ('test', 'drill');
    if s.kind = 'voc' and v_cnt >= 5 then
      return jsonb_build_object('ok', false, 'err', 'limit');
    end if;
    if s.kind = 'gram' and v_cnt >= 1 then
      return jsonb_build_object('ok', false, 'err', 'tomorrow');
    end if;
    v_qs := public.lec__set_qs(s, p.kn, s.kind = 'voc' and p.tn > 0);
    if jsonb_array_length(v_qs) = 0 then
      return jsonb_build_object('ok', false, 'err', 'none');
    end if;
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs, ans)
    values (k.sid, s.id, case when s.kind = 'voc' then 'test' else 'drill' end, v_day, jsonb_array_length(v_qs), v_qs,
            (select jsonb_agg(null::jsonb) from generate_series(1, jsonb_array_length(v_qs))))
    returning * into t;
    update public.lec_set_prog xp set tn = xp.tn + 1, last_at = now() where xp.sid = k.sid and xp.set_id = s.id
    returning * into p;
  end if;
  return public.lec__set_view(t, jsonb_build_object(
           'set', s.id, 'title', s.title, 'total', s.n, 'need', public.lec__set_need(s.n),
           'kn', case when s.kind = 'voc' then v_kn else 0 end, 'round', p.tn));
end
$$;

-- 학생: 쌓인 오답 한 판(열린 voc · gram 세트에서 오늘 나올 것 20개 · 하루 10판)
create or replace function public.lec_set_due(p_key text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k     public.lec_key;
  t     public.lec_set_try;
  v_day date := public.lec__set_today();
  v_qs  jsonb;
  v_cnt integer;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  perform pg_advisory_xact_lock(hashtext('lec_set_due|' || k.sid));
  select * into t from public.lec_set_try xt
   where xt.sid = k.sid and xt.kind = 'due' and xt.done_at is null
   order by xt.created_at desc limit 1;
  if not found then
    select count(*) into v_cnt from public.lec_set_try xt where xt.sid = k.sid and xt.kind = 'due' and xt.day = v_day;
    if v_cnt >= 10 then
      return jsonb_build_object('ok', false, 'err', 'limit');
    end if;
    select coalesce(jsonb_agg(z.q order by z.zz, z.on_ desc, z.cr desc, z.o), '[]'::jsonb) into v_qs
      from (select jsonb_build_object(
                     'k', u.e ->> 'k', 's', xs.id, 'kd', xs.kind, 't', xs.title,
                     'f', case when xs.kind = 'voc' then 'w' when public.lec__set_opts(u.e ->> 's') is null then 'r' else 'c' end,
                     'p', case when xs.kind = 'voc' then u.e ->> 'm' else u.e ->> 's' end,
                     'o', case when xs.kind = 'voc' then null else to_jsonb(public.lec__set_opts(u.e ->> 's')) end,
                     'a', case when xs.kind = 'voc' then u.e ->> 'w' else u.e ->> 'a' end,
                     'x', case when xs.kind = 'voc' then '' else coalesce(u.e ->> 'x', '') end,
                     'pt', case when xs.kind = 'voc' then '' else coalesce(u.e ->> 'p', '') end) as q,
                   xp.cards -> (u.e ->> 'k') ->> 'z' as zz, xs.posted_on as on_, xs.created_at as cr, u.o
              from public.lec_set xs
              join public.lec_set_prog xp on xp.set_id = xs.id and xp.sid = k.sid
             cross join lateral jsonb_array_elements(xs.items) with ordinality as u(e, o)
             where xs.kind in ('voc', 'gram') and public.lec__set_open(xs, k.cls)
               and not public.lec__set_busy(k.sid, xs.id)
               and public.lec__set_due_on(xp.cards -> (u.e ->> 'k'), v_day)
             order by 2, 3 desc, 4 desc, 5
             limit 20) z;
    if jsonb_array_length(v_qs) = 0 then
      return jsonb_build_object('ok', true, 'try', null, 'n', 0);
    end if;
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs, ans)
    values (k.sid, null, 'due', v_day, jsonb_array_length(v_qs), v_qs,
            (select jsonb_agg(null::jsonb) from generate_series(1, jsonb_array_length(v_qs))))
    returning * into t;
  end if;
  return public.lec__set_view(t, jsonb_build_object('set', null, 'title', '쌓인 오답', 'total', t.n, 'need', 0, 'kn', 0, 'round', 0));
end
$$;

-- 학생: 한 문항 답(서버가 채점 · 정답 · 해설은 이 문항 것만 · 같은 문항 두 번 = 처음 결과 그대로)
create or replace function public.lec_set_ans(p_key text, p_try uuid, p_i integer, p_v text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k     public.lec_key;
  t     public.lec_set_try;
  s     public.lec_set;
  v_day date := public.lec__set_today();
  v_q   jsonb;
  v_a   jsonb;
  v_r   boolean;
  v_sid uuid;
  v_k   text;
  v_kn  integer;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into t from public.lec_set_try xt where xt.id = p_try and xt.sid = k.sid for update;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'try');
  end if;
  if p_i is null or p_i < 0 or p_i >= t.n or p_v is null or btrim(p_v) = '' or char_length(p_v) > 200 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_q := t.qs -> p_i;
  v_a := t.ans -> p_i;
  if jsonb_typeof(v_a) = 'object' then
    return jsonb_build_object('ok', true, 'i', p_i, 'r', (v_a ->> 'r')::boolean, 'a', v_q ->> 'a',
                              'x', coalesce(v_q ->> 'x', ''), 'pt', coalesce(v_q ->> 'pt', ''), 'again', true,
                              'left', t.n - t.got, 'end', public.lec__set_end(t, k.sid, k.cls));
  end if;
  if t.done_at is not null then
    return jsonb_build_object('ok', false, 'err', 'done');
  end if;
  -- 쌓인 오답 판을 연 뒤 같은 세트의 시험 · 드릴을 열었으면 그 문항은 시험이 끝날 때까지 답(과 정답 보기)을 받지 않음
  if t.kind = 'due' and public.lec__set_busy(k.sid, (v_q ->> 's')::uuid) then
    return jsonb_build_object('ok', false, 'err', 'testing');
  end if;
  if v_q ->> 'f' = 'c' then
    v_r := public.lec__set_norm(p_v) = public.lec__set_norm(v_q ->> 'a');
  else
    v_r := public.lec__set_match(p_v, v_q ->> 'a');
  end if;
  update public.lec_set_try xt
     set ans = jsonb_set(xt.ans, array[p_i::text], jsonb_build_object('v', p_v, 'r', v_r, 'at', now())),
         got = xt.got + 1,
         sc = xt.sc + case when v_r then 1 else 0 end,
         done_at = case when xt.got + 1 >= xt.n then now() else null end
   where xt.id = t.id
  returning * into t;
  v_sid := case when t.kind = 'due' then (v_q ->> 's')::uuid else t.set_id end;
  v_k := v_q ->> 'k';
  update public.lec_set_prog xp
     set cards = jsonb_set(xp.cards, array[v_k], public.lec__set_mark(xp.cards -> v_k, v_r, t.kind, v_day)),
         kn = case when t.kind <> 'test' then xp.kn
                   when v_r then (case when v_k = any (xp.kn) then xp.kn else xp.kn || v_k end)
                   else array_remove(xp.kn, v_k) end,
         last_at = now()
   where xp.sid = k.sid and xp.set_id = v_sid;
  if t.done_at is not null and t.kind <> 'due' then
    select * into s from public.lec_set xs where xs.id = t.set_id;
    select count(*) into v_kn
      from public.lec_set_prog xp cross join lateral unnest(xp.kn) as y(kk)
     where xp.sid = k.sid and xp.set_id = t.set_id
       and y.kk in (select u.e ->> 'k' from jsonb_array_elements(s.items) as u(e));
    update public.lec_set_prog xp
       set f1 = coalesce(xp.f1, (t.sc * 100) / t.n),
           last_sc = t.sc,
           best = greatest(xp.best, case when t.kind = 'test' then (v_kn * 100) / greatest(s.n, 1) else (t.sc * 100) / t.n end),
           pass_at = case when xp.pass_at is null
                               and (case when t.kind = 'test' then v_kn >= public.lec__set_need(s.n)
                                         else t.sc >= public.lec__set_need(t.n) end)
                          then now() else xp.pass_at end
     where xp.sid = k.sid and xp.set_id = t.set_id;
  end if;
  return jsonb_build_object('ok', true, 'i', p_i, 'r', v_r, 'a', v_q ->> 'a', 'x', coalesce(v_q ->> 'x', ''),
                            'pt', coalesce(v_q ->> 'pt', ''), 'again', false, 'left', t.n - t.got,
                            'end', public.lec__set_end(t, k.sid, k.cls));
end
$$;

-- 학생: 녹음 올리기 표(10분 · 이 이름으로만 Storage 에 한 번 올릴 수 있음 · 하루 10개)
create or replace function public.lec_rec_begin(p_key text, p_set uuid, p_k text, p_mime text, p_bytes integer, p_ms integer)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  s      public.lec_set;
  v_n    integer;
  v_path text;
  v_id   uuid;
  v_exp  timestamptz;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found or s.kind <> 'gu' or not public.lec__set_open(s, k.cls) then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if p_k is null or not (p_k = any (s.pick)) then
    return jsonb_build_object('ok', false, 'err', 'pick');
  end if;
  if p_mime is null or p_mime not in ('audio/webm', 'audio/mp4', 'audio/ogg') then
    return jsonb_build_object('ok', false, 'err', 'mime');
  end if;
  if p_bytes is null or p_bytes not between 1 and 1048576 or p_ms is null or p_ms not between 0 and 46000 then
    return jsonb_build_object('ok', false, 'err', 'size');
  end if;
  perform pg_advisory_xact_lock(hashtext('lec_rec_begin|' || k.sid));
  select count(*) into v_n from public.lec_set_rec xr
   where xr.sid = k.sid and xr.at >= (public.lec__set_today()::timestamp at time zone 'Asia/Seoul');
  if v_n >= 10 then
    return jsonb_build_object('ok', false, 'err', 'limit');
  end if;
  -- 같은 문장을 다시 보내면(올리기 실패 뒤 다시 보내기) 앞 올리기 표는 지울 것(old) · 다음 정리에서 파일까지 지움
  update public.lec_set_rec xr set st = 'old' where xr.sid = k.sid and xr.set_id = s.id and xr.k = p_k and xr.st = 'wait';
  v_path := s.id::text || '/' || replace(gen_random_uuid()::text, '-', '')
            || case p_mime when 'audio/webm' then '.webm' when 'audio/mp4' then '.m4a' else '.ogg' end;
  insert into public.lec_set_rec (sid, set_id, k, path, mime, bytes, ms, st, exp_at, at)
  values (k.sid, s.id, p_k, v_path, p_mime, p_bytes, p_ms, 'wait', now() + interval '10 minutes', now())
  returning id, exp_at into v_id, v_exp;
  return jsonb_build_object('ok', true, 'id', v_id, 'path', v_path, 'exp_at', v_exp);
end
$$;

-- 학생: 녹음 냄(파일이 올라왔는지 봄 · Storage 표를 못 읽는 서버면 그 검사만 건너뜀 · 같은 문장의 앞 녹음은 지울 것으로)
create or replace function public.lec_rec_done(p_key text, p_id uuid)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k     public.lec_key;
  rr    public.lec_set_rec;
  v_has boolean;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  select * into rr from public.lec_set_rec xr where xr.id = p_id and xr.sid = k.sid for update;
  if not found or rr.st <> 'wait' then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if now() > rr.exp_at + interval '5 minutes' then
    return jsonb_build_object('ok', false, 'err', 'late');
  end if;
  begin
    execute 'select exists (select 1 from storage.objects where bucket_id = $1 and name = $2)' into v_has using 'lec-rec', rr.path;
  exception when others then
    v_has := true;
  end;
  if not coalesce(v_has, true) then
    return jsonb_build_object('ok', false, 'err', 'file');
  end if;
  update public.lec_set_rec xr set st = 'old'
   where xr.sid = rr.sid and xr.set_id = rr.set_id and xr.k = rr.k and xr.st = 'done' and xr.id <> rr.id;
  update public.lec_set_rec xr set st = 'done', done_at = now(), mark = '', why = 0, heard_by = '', heard_at = null
   where xr.id = rr.id;
  return jsonb_build_object('ok', true, 'st', 'sent');
end
$$;

-- Storage 정책 전용: 이 이름이 지금 열린 올리기 표인가(참 · 거짓만)
create or replace function public.lec_rec_slot(p_name text)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.lec_set_rec xr where xr.path = p_name and xr.st = 'wait' and xr.exp_at > now())
$$;

-- 선생님: 지금 부른 사람이 관리자(원장님 benjamin@his.kr)인가 · lec__staff 와 같은 이메일 규칙 · app_state 는 안 읽음
--   Storage 정책(lec_rec_read · lec_rec_del)이 이 함수를 써서 지우지 않고 바꿔 씀(모양 그대로)
create or replace function public.lec_set_is_admin()
returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  v_claims jsonb;
begin
  begin
    v_claims := coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
  exception when others then
    v_claims := '{}'::jsonb;
  end;
  return coalesce(v_claims ->> 'role', '') = 'authenticated'
         and lower(btrim(coalesce(v_claims ->> 'email', ''), ' ' || chr(9) || chr(10) || chr(11) || chr(12) || chr(13))) = 'benjamin@his.kr';
end
$$;

-- 선생님(관리자): 세트 목록과 세트마다 학생 수(문항 없음)
create or replace function public.lec_set_list_staff()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_items jsonb;
  v_n     integer;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', xs.id, 'kind', xs.kind, 'title', xs.title, 'class_ids', to_jsonb(xs.class_ids), 'posted_on', xs.posted_on,
           'hidden', xs.hidden, 'n', xs.n, 'need', public.lec__set_need(xs.n), 'pick', to_jsonb(xs.pick), 'made_by', xs.made_by,
           'created_at', xs.created_at, 'updated_at', xs.updated_at,
           'cnt', jsonb_build_object(
             'did', (select count(*) from (select xp.sid from public.lec_set_prog xp
                                            where xp.set_id = xs.id and (xp.tn > 0 or xp.cards <> '{}'::jsonb)
                                           union select xt.sid from public.lec_set_try xt where xt.set_id = xs.id
                                           union select xr.sid from public.lec_set_rec xr
                                            where xr.set_id = xs.id and xr.st in ('done', 'gone') and xr.sid <> '') w),
             'pass', (select count(*) from public.lec_set_prog xp where xp.set_id = xs.id and xp.pass_at is not null),
             'open', (select count(distinct xt.sid) from public.lec_set_try xt where xt.set_id = xs.id and xt.done_at is null),
             'fail', (select count(*) from public.lec_set_prog xp where xp.set_id = xs.id and xp.tn > 0 and xp.pass_at is null),
             'recs', (select count(distinct xr.sid) from public.lec_set_rec xr
                       where xr.set_id = xs.id and xr.st in ('done', 'gone') and xr.sid <> ''),
             'unheard', (select count(*) from (select distinct on (xr.sid, xr.k) xr.mark from public.lec_set_rec xr
                                                where xr.set_id = xs.id and xr.st = 'done' and xr.sid <> '' and xr.k = any (xs.pick)
                                                order by xr.sid, xr.k, xr.done_at desc nulls last) z
                          where z.mark = '')))
           order by xs.posted_on desc, xs.created_at desc), '[]'::jsonb)
    into v_items
    from public.lec_set xs;
  -- 안 들은 녹음 = (세트 · 학생 · 문장)마다 가장 새 냄의 표시가 빈 것(밀린 옛 줄 · 세트 없는 줄 · ★ 아닌 문장은 안 셈)
  select count(*) into v_n
    from (select distinct on (xr.set_id, xr.sid, xr.k) xr.mark
            from public.lec_set_rec xr join public.lec_set xs on xs.id = xr.set_id and xr.k = any (xs.pick)
           where xr.st = 'done' and xr.sid <> ''
           order by xr.set_id, xr.sid, xr.k, xr.done_at desc nulls last) z
   where z.mark = '';
  return jsonb_build_object('ok', true, 'today', to_char(public.lec__set_today(), 'YYYY-MM-DD'), 'unheard', v_n, 'items', v_items);
end
$$;

-- 선생님(관리자): 세트 하나 통째(고치기 · 인쇄 · 녹음 서랍 원래 소리)
create or replace function public.lec_set_get(p_set uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s public.lec_set;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  return jsonb_build_object('ok', true, 'set', jsonb_build_object(
           'id', s.id, 'kind', s.kind, 'title', s.title, 'class_ids', to_jsonb(s.class_ids), 'posted_on', s.posted_on,
           'hidden', s.hidden, 'n', s.n, 'need', public.lec__set_need(s.n), 'pick', to_jsonb(s.pick), 'items', s.items,
           'made_by', s.made_by, 'created_at', s.created_at, 'updated_at', s.updated_at));
end
$$;

-- 선생님(관리자): 세트 저장(p_id null = 새로 · 있으면 고침 · 종류는 못 바꿈 · 문항 열쇠는 서버가 매김 · 고칠 때 공개일 null = 그대로)
create or replace function public.lec_set_put(p_id uuid, p_kind text, p_title text, p_cls text[], p_on date, p_items jsonb, p_pick integer[])
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  s       public.lec_set;
  v_title text := btrim(coalesce(p_title, ''));
  v_cls   text[];
  v_chk   jsonb;
  v_items jsonb;
  v_n     integer;
  v_pick  text[] := '{}';
  v_id    uuid;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  if p_id is not null then
    select * into s from public.lec_set xs where xs.id = p_id for update;
    if not found then
      return jsonb_build_object('ok', false, 'err', 'none');
    end if;
    if s.kind is distinct from p_kind then
      return jsonb_build_object('ok', false, 'err', 'kind');
    end if;
  end if;
  if p_kind is null or p_kind not in ('voc', 'gu', 'gram') then
    return jsonb_build_object('ok', false, 'err', 'kind');
  end if;
  if char_length(v_title) not between 1 and 60 then
    return jsonb_build_object('ok', false, 'err', 'title');
  end if;
  select coalesce(array_agg(w.c order by w.o), '{}'::text[]) into v_cls
    from (select btrim(u.c) as c, min(u.o) as o
            from unnest(coalesce(p_cls, '{}'::text[])) with ordinality as u(c, o)
           where btrim(coalesce(u.c, '')) not in ('', '*')
           group by btrim(u.c)) w;
  if array_position(coalesce(p_cls, '{}'::text[]), '*') is not null or cardinality(v_cls) not between 1 and 30 then
    return jsonb_build_object('ok', false, 'err', 'cls');
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or octet_length(p_items::text) > 262144 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_n := jsonb_array_length(p_items);
  if v_n = 0 then
    return jsonb_build_object('ok', false, 'err', 'items');
  end if;
  if v_n > (case p_kind when 'voc' then 300 when 'gu' then 30 else 50 end) then
    return jsonb_build_object('ok', false, 'err', 'limit');
  end if;
  v_chk := public.lec__set_check(p_kind, p_items);
  if not coalesce((v_chk ->> 'ok')::boolean, false) then
    return v_chk;
  end if;
  v_items := public.lec__set_keys(p_kind, case when p_id is null then '[]'::jsonb else s.items end, v_chk -> 'items');
  if p_kind = 'gu' then
    if p_pick is null or cardinality(p_pick) = 0 then
      v_pick := array(select v_items -> g.i ->> 'k' from generate_series(0, least(v_n, 2) - 1) as g(i) order by g.i);
    else
      if cardinality(p_pick) > 2 or array_position(p_pick, null) is not null
         or exists (select 1 from unnest(p_pick) as u(i) where u.i < 0 or u.i >= v_n)
         or (select count(distinct u.i) from unnest(p_pick) as u(i)) <> cardinality(p_pick) then
        return jsonb_build_object('ok', false, 'err', 'pick');
      end if;
      v_pick := array(select v_items -> u.i ->> 'k' from unnest(p_pick) with ordinality as u(i, o) order by u.o);
    end if;
  end if;
  if p_id is null then
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n, pick, made_by)
    values (p_kind, v_title, v_cls, coalesce(p_on, public.lec__set_today()), v_items, v_n, v_pick, 'Benjamin')
    returning id into v_id;
  else
    update public.lec_set xs
       set title = v_title, class_ids = v_cls, posted_on = coalesce(p_on, xs.posted_on), items = v_items, n = v_n,
           pick = v_pick, updated_at = now()
     where xs.id = p_id;
    v_id := p_id;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'n', v_n, 'pick', to_jsonb(v_pick), 'items', v_items);
end
$$;

-- 선생님(관리자): 숨기기 · 다시 보이기
create or replace function public.lec_set_hide(p_set uuid, p_hidden boolean)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_h boolean;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  update public.lec_set xs set hidden = coalesce(p_hidden, true), updated_at = now() where xs.id = p_set
  returning xs.hidden into v_h;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  return jsonb_build_object('ok', true, 'hidden', v_h);
end
$$;

-- 선생님(관리자): 세트 지움(진도 · 판은 같이 지워짐 · 녹음은 지울 것으로 · 파일은 다음 정리 때)
create or replace function public.lec_set_del(p_set uuid)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_n integer;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  if not exists (select 1 from public.lec_set xs where xs.id = p_set) then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  with u as (update public.lec_set_rec xr set st = 'old' where xr.set_id = p_set and xr.st in ('wait', 'done') returning 1)
  select count(*) into v_n from u;
  delete from public.lec_set_rec xr where xr.set_id = p_set and xr.st = 'gone';
  delete from public.lec_set xs where xs.id = p_set;
  return jsonb_build_object('ok', true, 'recs', v_n);
end
$$;

-- 선생님(관리자): 세트 결과 표(학생마다 진도 · 녹음 · 자주 틀린 것 다섯)
create or replace function public.lec_set_staff(p_set uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s       public.lec_set;
  v_day   date := public.lec__set_today();
  v_rows  jsonb;
  v_often jsonb := '[]'::jsonb;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'sid', w.sid,
           'sname', coalesce((select xk.sname from public.lec_key xk where xk.sid = w.sid order by xk.last_at desc limit 1),
                             substr(w.sid, strpos(w.sid, '|') + 1)),
           'last', (select max(z.at) from (select xp.last_at as at from public.lec_set_prog xp where xp.set_id = s.id and xp.sid = w.sid
                                           union all select xt.created_at from public.lec_set_try xt where xt.set_id = s.id and xt.sid = w.sid
                                           union all select xr.at from public.lec_set_rec xr where xr.set_id = s.id and xr.sid = w.sid) z),
           s.kind, case when s.kind = 'gu'
                        then public.lec__set_me(s, w.sid, v_day) || jsonb_build_object('recs',
                               (select coalesce(jsonb_agg(jsonb_build_object(
                                         'id', lr.id, 'k', lr.k, 'path', case when lr.st = 'gone' or lr.done_at < now() - interval '30 days' then '' else lr.path end,
                                         'mime', lr.mime, 'ms', lr.ms, 'at', lr.done_at,
                                         'st', lr.st, 'mark', lr.mark, 'why', lr.why, 'heard_at', lr.heard_at) order by po.o), '[]'::jsonb)
                                  from unnest(s.pick) with ordinality as po(kk, o)
                                  join lateral (select xr.id, xr.k, xr.path, xr.mime, xr.ms, xr.done_at, xr.st, xr.mark, xr.why, xr.heard_at
                                                  from public.lec_set_rec xr
                                                 where xr.set_id = s.id and xr.sid = w.sid and xr.k = po.kk and xr.st in ('done', 'gone')
                                                 order by xr.done_at desc nulls last limit 1) lr on true))
                        else public.lec__set_me(s, w.sid, v_day) end)
           order by w.sid), '[]'::jsonb)
    into v_rows
    from (select xp.sid from public.lec_set_prog xp where xp.set_id = s.id
          union select xt.sid from public.lec_set_try xt where xt.set_id = s.id
          union select xr.sid from public.lec_set_rec xr where xr.set_id = s.id and xr.sid <> '') w;
  if s.kind in ('voc', 'gram') then
    select coalesce(jsonb_agg(jsonb_build_object('k', y.kk, 'w', y.w, 'n', y.cnt) order by y.cnt desc, y.o), '[]'::jsonb)
      into v_often
      from (select u.e ->> 'k' as kk, left(case when s.kind = 'voc' then u.e ->> 'w' else u.e ->> 's' end, 40) as w, u.o,
                   (select count(*) from public.lec_set_prog xp where xp.set_id = s.id and (xp.cards -> (u.e ->> 'k')) ? 'w') as cnt
              from jsonb_array_elements(s.items) with ordinality as u(e, o)
             order by 4 desc, 3
             limit 5) y
     where y.cnt > 0;
  end if;
  return jsonb_build_object('ok', true, 'today', to_char(v_day, 'YYYY-MM-DD'),
                            'set', jsonb_build_object('id', s.id, 'kind', s.kind, 'title', s.title, 'class_ids', to_jsonb(s.class_ids),
                                                      'posted_on', s.posted_on, 'hidden', s.hidden, 'n', s.n,
                                                      'need', public.lec__set_need(s.n), 'pick', to_jsonb(s.pick),
                                                      'items', case when s.kind = 'gu' then s.items else null end),
                            'rows', v_rows, 'often', v_often);
end
$$;

-- 선생님(관리자): 반 하나에 낸 단어 · 문법 세트에서 학생마다 쌓인 오답(종이 «쌓인 오답 시험»용 · 읽기만 · 카드는 안 고침)
--   쌓인 오답 = 카드에 z(마지막으로 틀린 날)가 있는 문항(학생 «쌓인 오답»과 같은 규칙 · 시험 중인 세트도 넣음) ·
--   숨김 · 앞날 공개 세트는 뺌 · 문항 차례 = 학생 «쌓인 오답» 판과 같음(오래전에 틀린 것 먼저) · 오답이 없는 학생은 줄이 없음 ·
--   지금 이 반 학생인지(퇴원 · 반 옮김)는 화면이 히즈북스 명단으로 거름
create or replace function public.lec_set_wrong_staff(p_cls text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_day  date := public.lec__set_today();
  v_cls  text := btrim(coalesce(p_cls, ''));
  v_rows jsonb;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  if v_cls = '' or v_cls = '*' then
    return jsonb_build_object('ok', false, 'err', 'cls');
  end if;
  with q as (
    select xp.sid,
           jsonb_build_object(
             'k', u.e ->> 'k', 's', xs.id, 'kd', xs.kind, 't', xs.title,
             'f', case when xs.kind = 'voc' then 'w' when public.lec__set_opts(u.e ->> 's') is null then 'r' else 'c' end,
             'q', case when xs.kind = 'voc' then u.e ->> 'm' else u.e ->> 's' end,
             'a', case when xs.kind = 'voc' then u.e ->> 'w' else u.e ->> 'a' end,
             'pt', case when xs.kind = 'voc' then '' else coalesce(u.e ->> 'p', '') end,
             'z', xp.cards -> (u.e ->> 'k') ->> 'z') as j,
           xp.cards -> (u.e ->> 'k') ->> 'z' as zz, xs.posted_on as on_, xs.created_at as cr, u.o
      from public.lec_set xs
      join public.lec_set_prog xp on xp.set_id = xs.id
     cross join lateral jsonb_array_elements(xs.items) with ordinality as u(e, o)
     where xs.kind in ('voc', 'gram') and v_cls = any (xs.class_ids)
       and not xs.hidden and xs.posted_on <= v_day
       and coalesce(xp.cards -> (u.e ->> 'k') ->> 'z', '') <> ''
  ), g as (
    select q.sid, count(*) as n, jsonb_agg(q.j order by q.zz, q.on_ desc, q.cr desc, q.o) as items
      from q
     group by q.sid
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'sid', g.sid,
           'sname', coalesce((select xk.sname from public.lec_key xk where xk.sid = g.sid order by xk.last_at desc limit 1),
                             substr(g.sid, strpos(g.sid, '|') + 1)),
           'n', g.n, 'items', g.items) order by g.sid), '[]'::jsonb)
    into v_rows
    from g;
  return jsonb_build_object('ok', true, 'today', to_char(v_day, 'YYYY-MM-DD'), 'cls', v_cls, 'rows', v_rows);
end
$$;

-- 선생님(관리자): 녹음 들은 표시(ok 좋아요 · again 다시 + 까닭 1~4 · '' 표시 지움)
create or replace function public.lec_rec_mark(p_id uuid, p_mark text, p_why integer)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  if p_mark is null or p_mark not in ('', 'ok', 'again') then
    return jsonb_build_object('ok', false, 'err', 'mark');
  end if;
  if p_why is null or p_why not between 0 and 4 or (p_mark = 'ok' and p_why <> 0) then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  update public.lec_set_rec xr
     set mark = p_mark, why = p_why,
         heard_by = case when p_mark = '' then '' else 'Benjamin' end,
         heard_at = case when p_mark = '' then null else now() end
   where xr.id = p_id and xr.st in ('done', 'gone');
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  return jsonb_build_object('ok', true, 'mark', p_mark, 'why', p_why);
end
$$;

-- 지울 때가 된 녹음 줄인가(지울 것 · 10분 넘게 지난 올리기 표 · 30일 지난 녹음 · 세트가 없는 녹음) · lec_rec_expired 와 점검이 같이 씀
create or replace function public.lec__rec_exp(r public.lec_set_rec) returns boolean
language sql stable set search_path = public as $$
  select coalesce(r.st = 'old'
                  or (r.st = 'wait' and r.exp_at < now() - interval '10 minutes')
                  or (r.st = 'done' and r.done_at < now() - interval '30 days')
                  or (r.st in ('wait', 'done') and not exists (select 1 from public.lec_set xs where xs.id = r.set_id)), false)
$$;

-- 녹음 파일이 저장 곳(lec-rec)에 아직 있나: 있음 true · 없음 false · 못 읽음 null(Storage 표 권한이 없는 서버)
create or replace function public.lec__rec_has(p_path text) returns boolean
language plpgsql stable set search_path = public as $$
declare
  v_has boolean;
begin
  if coalesce(p_path, '') = '' or to_regclass('storage.objects') is null then
    return false;
  end if;
  begin
    execute 'select exists (select 1 from storage.objects where bucket_id = $1 and name = $2)' into v_has using 'lec-rec', p_path;
  exception when others then
    return null;
  end;
  return v_has;
end
$$;

-- 선생님(관리자): 지울 녹음 파일(500개 · 오래된 것부터) · f = 파일이 아직 있음(모르면 true · false 면 지울 파일 없이 줄만 정리)
create or replace function public.lec_rec_expired()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_items jsonb;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', y.id, 'path', y.path, 'f', coalesce(public.lec__rec_has(y.path), true))
                            order by y.at), '[]'::jsonb) into v_items
    from (select xr.id, xr.path, xr.at from public.lec_set_rec xr
           where public.lec__rec_exp(xr)
           order by xr.at
           limit 500) y;
  return jsonb_build_object('ok', true, 'items', v_items);
end
$$;

-- 선생님(관리자): 파일을 지운 녹음 줄 정리(지울 것 · 올리기 표 · 지운 학생 · 세트 없음 = 줄 지움 · 30일 지난 녹음 = gone 표시만 남김)
-- 파일이 저장 곳에 아직 남아 있으면(지우기가 조용히 빈손이었던 것) 줄을 그대로 두어 다음 정리에서 다시 지움 · keep = 그렇게 남긴 수
create or replace function public.lec_rec_gone(p_ids uuid[])
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_n    integer;
  v_m    integer;
  v_keep integer;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  if p_ids is null or cardinality(p_ids) > 1000 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  select count(*) into v_keep from public.lec_set_rec xr
   where xr.id = any (p_ids) and xr.st in ('old', 'wait', 'done') and coalesce(public.lec__rec_has(xr.path), false);
  with d as (delete from public.lec_set_rec xr
              where xr.id = any (p_ids)
                and (xr.st in ('old', 'wait') or xr.sid = ''
                     or not exists (select 1 from public.lec_set xs where xs.id = xr.set_id))
                and not coalesce(public.lec__rec_has(xr.path), false)
             returning 1)
  select count(*) into v_n from d;
  with g as (update public.lec_set_rec xr set st = 'gone'
              where xr.id = any (p_ids) and xr.st = 'done' and not coalesce(public.lec__rec_has(xr.path), false)
             returning 1)
  select count(*) into v_m from g;
  return jsonb_build_object('ok', true, 'n', v_n + v_m, 'keep', v_keep);
end
$$;

-- 권한: 속 함수 = 밖에서 못 부름 · 학생 함수 아홉 = 누구나(열쇠로 확인) · 선생님 함수 = 로그인한 사람만(안에서 관리자 확인)
revoke all on function public.lec__set_today(),
  public.lec__set_open(public.lec_set, text[]), public.lec__set_need(integer), public.lec__set_norm(text),
  public.lec__set_vars(text), public.lec__set_alts(text), public.lec__set_match(text, text), public.lec__set_opts(text),
  public.lec__set_txt(jsonb, text), public.lec__set_ktext(text, jsonb), public.lec__set_mark(jsonb, boolean, text, date),
  public.lec__set_memo(jsonb), public.lec__set_due_on(jsonb, date), public.lec__set_keys(text, jsonb, jsonb),
  public.lec__set_check(text, jsonb), public.lec__set_qs(public.lec_set, text[], boolean),
  public.lec__set_view(public.lec_set_try, jsonb), public.lec__set_me(public.lec_set, text, date),
  public.lec__set_end(public.lec_set_try, text, text[]), public.lec__set_move(text, text), public.lec__set_mv(), public.lec__set_gone(),
  public.lec__set_busy(text, uuid), public.lec__rec_exp(public.lec_set_rec), public.lec__rec_has(text)
  from public, anon, authenticated;
revoke all on function public.lec_set_home(text), public.lec_set_items(text, uuid),
  public.lec_set_card(text, uuid, jsonb), public.lec_set_test(text, uuid), public.lec_set_due(text),
  public.lec_set_ans(text, uuid, integer, text),
  public.lec_rec_begin(text, uuid, text, text, integer, integer), public.lec_rec_done(text, uuid), public.lec_rec_slot(text)
  from public;
grant execute on function public.lec_set_home(text), public.lec_set_items(text, uuid),
  public.lec_set_card(text, uuid, jsonb), public.lec_set_test(text, uuid), public.lec_set_due(text),
  public.lec_set_ans(text, uuid, integer, text),
  public.lec_rec_begin(text, uuid, text, text, integer, integer), public.lec_rec_done(text, uuid), public.lec_rec_slot(text)
  to anon, authenticated;
revoke all on function public.lec_set_is_admin(), public.lec_set_list_staff(), public.lec_set_get(uuid),
  public.lec_set_put(uuid, text, text, text[], date, jsonb, integer[]), public.lec_set_hide(uuid, boolean), public.lec_set_del(uuid),
  public.lec_set_staff(uuid), public.lec_set_wrong_staff(text), public.lec_rec_mark(uuid, text, integer),
  public.lec_rec_expired(), public.lec_rec_gone(uuid[])
  from public, anon;
grant execute on function public.lec_set_is_admin(), public.lec_set_list_staff(), public.lec_set_get(uuid),
  public.lec_set_put(uuid, text, text, text[], date, jsonb, integer[]), public.lec_set_hide(uuid, boolean), public.lec_set_del(uuid),
  public.lec_set_staff(uuid), public.lec_set_wrong_staff(text), public.lec_rec_mark(uuid, text, integer),
  public.lec_rec_expired(), public.lec_rec_gone(uuid[])
  to authenticated;

-- 녹음 «냄»의 파일 확인(lec_rec_done 은 주인 권한으로 storage.objects 를 읽음)이 되는가:
--   '' = 됨(주인이 행 보안을 넘어 읽음) · 'priv' = 읽을 권한 없음(확인을 건너뛰어 파일 없이도 냄) ·
--   'rls' = 권한은 있으나 행 보안에 걸림(늘 «파일 없음» → 모든 녹음이 «보내지 못했어요») · 'none' = storage 표 없음
create or replace function public.lec__rec_fcheck()
returns text
language plpgsql stable set search_path = public as $$
declare
  v_own oid;
  v_tab oid := to_regclass('storage.objects');
  v_rls boolean;
  v_frc boolean;
  v_tow oid;
begin
  if v_tab is null then
    return 'none';
  end if;
  select p.proowner into v_own from pg_proc p where p.oid = to_regprocedure('public.lec_rec_done(text, uuid)')::oid;
  if v_own is null then
    return 'none';
  end if;
  select c.relrowsecurity, c.relforcerowsecurity, c.relowner into v_rls, v_frc, v_tow from pg_class c where c.oid = v_tab;
  if not (has_schema_privilege(v_own, 'storage', 'USAGE') and has_table_privilege(v_own, v_tab, 'SELECT')) then
    return 'priv';
  end if;
  if not v_rls
     or exists (select 1 from pg_roles ro where ro.oid = v_own and (ro.rolsuper or ro.rolbypassrls))
     or (not v_frc and pg_has_role(v_own, v_tow, 'USAGE')) then
    return '';
  end if;
  return 'rls';
end
$$;

revoke all on function public.lec__rec_fcheck() from public, anon, authenticated;

-- 녹음 저장 곳 상태(맨 아래 표): «됨» 또는 모자란 것 · 밖에서 못 부름
--   정책은 이름이 아니라 실제 조건으로 봄(듣기 · 지우기 = lec-rec + 관리자 · 올리기 = lec-rec + 열린 표)
--   우리 것 말고 lec-rec 에 닿는(버킷 조건 없음 또는 lec-rec 포함) anon · authenticated · public 의 읽기 · 고치기 · 지우기 정책이 있으면 이름을 띄움
--   «냄» 파일 확인이 안 되거나(lec__rec_fcheck) 스스로 점검이 파일 확인을 못 쟀으면(his.lec_rec_fput = 'no') «됨»이 아님
create or replace function public.lec__rec_store()
returns text
language plpgsql stable set search_path = public as $$
declare
  v_out  text := '';
  v_pub  boolean;
  v_lim  bigint;
  v_mime text[];
  v_n    integer;
  v_miss text;
  v_bad  text;
  v_open text;
  v_fc   text;
  v_err  text := coalesce(current_setting('his.lec_rec_err', true), '');
  v_put  text := coalesce(current_setting('his.lec_rec_fput', true), '');
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    return 'storage 없음';
  end if;
  begin
    execute 'select public, file_size_limit, allowed_mime_types from storage.buckets where id = $1'
       into v_pub, v_lim, v_mime using 'lec-rec';
    get diagnostics v_n = row_count;
  exception when others then
    return '버킷을 못 읽음(' || sqlstate || ') → 대시보드';
  end;
  if v_n = 0 then
    v_out := '버킷 없음';
  elsif v_pub is distinct from false or v_lim is distinct from 1048576
        or not coalesce(v_mime @> array['audio/webm', 'audio/mp4', 'audio/ogg'] and v_mime <@ array['audio/webm', 'audio/mp4', 'audio/ogg'], false) then
    v_out := '버킷 설정 다름';
  end if;
  select string_agg(u.x, ', ' order by u.x) into v_miss
    from unnest(array['lec_rec_put', 'lec_rec_read', 'lec_rec_del']) as u(x)
   where not exists (select 1 from pg_policies pp
                      where pp.schemaname = 'storage' and pp.tablename = 'objects' and pp.policyname = u.x);
  if v_miss is not null then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '정책 없음(' || v_miss || ')';
  end if;
  -- 이름은 있으나 조건이 다름(대시보드에서 손으로 만들다 관리자 조건을 빠뜨린 것 등)
  select string_agg(pp.policyname::text, ', ' order by pp.policyname) into v_bad
    from pg_policies pp
   where pp.schemaname = 'storage' and pp.tablename = 'objects'
     and pp.policyname in ('lec_rec_put', 'lec_rec_read', 'lec_rec_del')
     and not public.lec__rec_pol_ok(pp.policyname, pp.cmd, pp.qual, pp.with_check);
  if v_bad is not null then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '정책 조건 다름(' || v_bad || ')';
  end if;
  v_open := public.lec__rec_open();
  if v_open is not null then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '녹음에 닿는 다른 정책: ' || v_open;
  end if;
  v_fc := public.lec__rec_fcheck();
  if v_fc = 'rls' then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '파일 확인 안 됨(행 보안) → 녹음이 모두 실패';
  elsif v_fc = 'priv' or v_put = 'no' then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || '파일 확인 못 함';
  end if;
  if v_err <> '' then
    v_out := v_out || case when v_out = '' then '' else ' · ' end || 'SQL 로 못 만듦(' || v_err || ') → 대시보드';
  end if;
  return case when v_out = '' then '됨' else v_out end;
end
$$;

revoke all on function public.lec__rec_store() from public, anon, authenticated;

-- 녹음 정책 하나의 조건이 맞나(이름 · 명령 · 조건 글)
create or replace function public.lec__rec_pol_ok(p_name name, p_cmd text, p_qual text, p_check text)
returns boolean
language sql immutable set search_path = public as $$
  select case p_name
           when 'lec_rec_put' then p_cmd = 'INSERT'
                                   and coalesce(p_check, '') like '%lec-rec%' and coalesce(p_check, '') like '%lec_rec_slot%'
           when 'lec_rec_read' then p_cmd = 'SELECT'
                                    and coalesce(p_qual, '') like '%lec-rec%' and coalesce(p_qual, '') like '%lec_set_is_admin%'
           when 'lec_rec_del' then p_cmd = 'DELETE'
                                   and coalesce(p_qual, '') like '%lec-rec%' and coalesce(p_qual, '') like '%lec_set_is_admin%'
           else false end
$$;

-- 우리 정책 셋 말고 lec-rec 파일을 읽거나 고치거나 지울 수 있는 정책 이름(없으면 null)
--   anon · authenticated · public 에게 열린 허용 정책 가운데 읽기 · 고치기 · 지우기 · 전부 · 버킷 조건이 없거나 lec-rec 를 담은 것
create or replace function public.lec__rec_open()
returns text
language sql stable set search_path = public as $$
  select string_agg(pp.policyname::text, ', ' order by pp.policyname)
    from pg_policies pp
   where pp.schemaname = 'storage' and pp.tablename = 'objects'
     and pp.policyname not in ('lec_rec_put', 'lec_rec_read', 'lec_rec_del')
     and pp.permissive = 'PERMISSIVE'
     and pp.roles && array['anon', 'authenticated', 'public']::name[]
     and pp.cmd in ('SELECT', 'UPDATE', 'DELETE', 'ALL')
     and (pp.qual is null or pp.qual not like '%bucket_id%' or pp.qual like '%lec-rec%')
$$;

revoke all on function public.lec__rec_pol_ok(name, text, text, text), public.lec__rec_open() from public, anon, authenticated;

-- 녹음 저장 곳 만들기(비공개 버킷 · 정책 셋) · 권한이 없으면 이 덩어리만 건너뜀(까닭은 맨 아래 표 «녹음 저장 곳»)
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'S1 · storage 표 없음(녹음 저장 곳은 대시보드에서)';
    return;
  end if;
  begin
    execute 'insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) '
         || 'values (''lec-rec'', ''lec-rec'', false, 1048576, array[''audio/webm'', ''audio/mp4'', ''audio/ogg'']) '
         || 'on conflict (id) do update set public = false, file_size_limit = 1048576, '
         || 'allowed_mime_types = array[''audio/webm'', ''audio/mp4'', ''audio/ogg'']';
  exception when others then
    perform set_config('his.lec_rec_err', '버킷 ' || sqlstate, true);
    raise notice 'S1 · 버킷을 SQL 로 못 만듦(% %)', sqlstate, sqlerrm;
  end;
  begin
    execute 'drop policy if exists lec_rec_put on storage.objects';
    execute 'create policy lec_rec_put on storage.objects for insert to anon, authenticated '
         || 'with check (bucket_id = ''lec-rec'' and public.lec_rec_slot(name))';
    execute 'drop policy if exists lec_rec_read on storage.objects';
    execute 'create policy lec_rec_read on storage.objects for select to authenticated '
         || 'using (bucket_id = ''lec-rec'' and (select public.lec_set_is_admin()))';
    execute 'drop policy if exists lec_rec_del on storage.objects';
    execute 'create policy lec_rec_del on storage.objects for delete to authenticated '
         || 'using (bucket_id = ''lec-rec'' and (select public.lec_set_is_admin()))';
  exception when others then
    perform set_config('his.lec_rec_err',
                       coalesce(nullif(current_setting('his.lec_rec_err', true), '') || ' · ', '') || '정책 ' || sqlstate, true);
    raise notice 'S1 · 정책을 SQL 로 못 만듦(% %)', sqlstate, sqlerrm;
  end;
end
$$;

-- 스스로 점검(S1 단어 · 구문 · 문법): 판정 표(_check/class_set_vectors.json) · 없는 열쇠 · 기록 동의만으로 열림(S1-b) · 관리자만 · 세트 저장 검사 ·
-- 열쇠 다시 매김 · 보임 · 단어 시험(정답이 폰에 안 감 · 채점 · 같은 문항 다시 · 끝 · 다시 보기 · 하루 한도 · 통과) · 문법 드릴 ·
-- 쌓인 오답 · 카드 · 녹음(동의 · 학교급 없이 바로 표 · 냄 · 듣기 표시 · 다시 냄 · 하루 한도) · 정리 · 이름 바뀜 · 지움 · 권한 ·
-- 없앤 동의 함수 없음 · 끄개 두 줄.
-- 점검용으로 넣은 세트 · 열쇠 · 동의 · 녹음 줄은 끝에 되돌려 남지 않습니다(Storage 에 올린 파일도 없음)
do $$
declare
  r       jsonb;
  v_n     integer;
  v_t     text;
  v_d     date := (now() at time zone 'Asia/Seoul')::date;
  v_ks    text := replace(gen_random_uuid()::text, '-', '');
  v_c1    text;
  v_c2    text;
  v_ka    text;
  v_kb    text;
  v_kc    text;
  v_ke    text;
  v_sa    text := 'selftest-s1a|점검가';
  v_sa2   text := 'selftest-s1a2|점검가';
  v_voc   uuid;
  v_v2    uuid;
  v_kset  uuid;
  v_gu    uuid;
  v_gram  uuid;
  v_hid   uuid;
  v_fut   uuid;
  v_oth   uuid;
  v_try   uuid;
  v_q     jsonb;
  v_kn    text[];
  v_ta    text[];
  v_card  jsonb;
  v_case  record;
  v_rec   uuid;
  v_rec2  uuid;
  v_path  text;
  v_st    boolean;
  v_put   boolean;
  v_ids   uuid[];
  v_busy  uuid;
  v_kept  uuid[];
  v_w     uuid;
  v_off   boolean;
begin
  begin
    -- 8) 판정 표(_check/class_set_vectors.json 과 같은 값 · class_set_vec_sql.py 가 만든 글)
    for v_case in select * from (values
        (0, 0),
        (1, 1),
        (5, 5),
        (9, 9),
        (10, 9),
        (11, 10),
        (12, 11),
        (15, 14),
        (20, 18),
        (42, 38),
        (50, 45),
        (300, 270)
      ) as x(a, b) loop
      if public.lec__set_need(v_case.a) is distinct from v_case.b then raise exception '점검 실패(S1 판정 need %)', v_case.a; end if;
    end loop;
    for v_case in select * from (values
        ('  Hello   World. ', 'hello world'),
        ('don' || chr(8217) || 't', 'don''t'),
        (chr(8216) || 'quote' || chr(8217), '''quote'''),
        (chr(8220) || 'Yes' || chr(8221), '"yes"'),
        ('say ' || chr(8243) || 'hi' || chr(8243), 'say "hi"'),
        ('rock' || chr(700) || 'n' || chr(8242) || 'roll', 'rock''n''roll'),
        ('a' || chr(160) || 'b' || chr(12288) || 'c', 'a b c'),
        ('look ~ up', 'look up'),
        ('e' || chr(12316) || 'f' || chr(8764) || 'g', 'efg'),
        (chr(9) || 'Go' || chr(10) || 'on...', 'go on'),
        ('U.S.', 'u.s'),
        ('ABC def', 'abc def'),
        ('', ''),
        (' . ', ''),
        ('a b ~', 'a b'),
        (chr(201) || 'T' || chr(201), chr(201) || 't' || chr(201)),
        ('cafe' || chr(769), 'caf' || chr(233)),
        ('One' || chr(13) || chr(10) || 'Two', 'one two')
      ) as x(a, b) loop
      if public.lec__set_norm(v_case.a) is distinct from v_case.b then raise exception '점검 실패(S1 판정 norm «%»)', v_case.a; end if;
    end loop;
    for v_case in select * from (values
        ('is', 'is', true),
        (' Is. ', 'is', true),
        ('are', 'is', false),
        ('look up', 'look up / look up to', true),
        ('look up to', 'look up / look up to', true),
        ('look', 'look up / look up to', false),
        ('give up', 'give (it) up', true),
        ('give it up', 'give (it) up', true),
        ('give (it) up', 'give (it) up', true),
        ('work', '(to) work', true),
        ('to work', '(to) work', true),
        ('a / b', 'a', false),
        ('a', 'a / b', true),
        ('', 'a', false),
        ('', '', false),
        ('dont', 'don''t', false),
        ('don' || chr(8217) || 't', 'don''t', true),
        ('acustomed', 'accustomed', false),
        ('ACCUSTOMED', 'accustomed', true)
      ) as x(a, b, c) loop
      if public.lec__set_match(v_case.a, v_case.b) is distinct from v_case.c then raise exception '점검 실패(S1 판정 match «%» «%»)', v_case.a, v_case.b; end if;
    end loop;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-10');
    if v_card is distinct from '{"s": 1, "d": ["2026-11-10"]}'::jsonb then raise exception '점검 실패(S1 판정 mark 1): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, false, 'card', date '2026-11-10');
    if v_card is distinct from '{"s": 1}'::jsonb then raise exception '점검 실패(S1 판정 mark 2): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'say', date '2026-11-10');
    if v_card is distinct from '{"s": 1, "g": 1}'::jsonb then raise exception '점검 실패(S1 판정 mark 3): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, false, 'say', date '2026-11-10');
    if v_card is distinct from '{"s": 1}'::jsonb then raise exception '점검 실패(S1 판정 mark 4): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-10');
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-10');
    v_card := public.lec__set_mark(v_card, true, 'test', date '2026-11-11');
    if v_card is distinct from '{"s": 1, "d": ["2026-11-10", "2026-11-11"], "t": "2026-11-11"}'::jsonb then raise exception '점검 실패(S1 판정 mark 5): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'test', date '2026-11-10');
    v_card := public.lec__set_mark(v_card, false, 'test', date '2026-11-11');
    if v_card is distinct from '{"w": 1, "z": "2026-11-11"}'::jsonb then raise exception '점검 실패(S1 판정 mark 6): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'test', date '2026-11-10');
    v_card := public.lec__set_mark(v_card, false, 'test', date '2026-11-11');
    v_card := public.lec__set_mark(v_card, true, 'due', date '2026-11-12');
    if v_card is distinct from '{"w": 1, "z": "2026-11-11", "d": ["2026-11-12"], "y": ["2026-11-12"]}'::jsonb then raise exception '점검 실패(S1 판정 mark 7): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'test', date '2026-11-10');
    v_card := public.lec__set_mark(v_card, false, 'test', date '2026-11-11');
    v_card := public.lec__set_mark(v_card, true, 'due', date '2026-11-12');
    v_card := public.lec__set_mark(v_card, true, 'test', date '2026-11-13');
    if v_card is distinct from '{"w": 1, "d": ["2026-11-12", "2026-11-13"], "t": "2026-11-13"}'::jsonb then raise exception '점검 실패(S1 판정 mark 8): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, false, 'drill', date '2026-11-11');
    v_card := public.lec__set_mark(v_card, true, 'drill', date '2026-11-11');
    if v_card is distinct from '{"w": 1, "z": "2026-11-11", "d": ["2026-11-11"], "t": "2026-11-11"}'::jsonb then raise exception '점검 실패(S1 판정 mark 9): %', v_card; end if;
    v_card := '{}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-01');
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-02');
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-03');
    v_card := public.lec__set_mark(v_card, true, 'card', date '2026-11-04');
    if v_card is distinct from '{"s": 1, "d": ["2026-11-02", "2026-11-03", "2026-11-04"]}'::jsonb then raise exception '점검 실패(S1 판정 mark 10): %', v_card; end if;
    v_card := '{"d": ["2026-11-01"], "t": "2026-11-01"}'::jsonb;
    v_card := public.lec__set_mark(v_card, false, 'due', date '2026-11-05');
    if v_card is distinct from '{"w": 1, "z": "2026-11-05"}'::jsonb then raise exception '점검 실패(S1 판정 mark 11): %', v_card; end if;
    v_card := '{"w": 1, "z": "2026-11-01"}'::jsonb;
    v_card := public.lec__set_mark(v_card, true, 'due', date '2026-11-02');
    v_card := public.lec__set_mark(v_card, true, 'drill', date '2026-11-02');
    if v_card is distinct from '{"w": 1, "z": "2026-11-01", "d": ["2026-11-02"], "y": ["2026-11-02"], "t": "2026-11-02"}'::jsonb then raise exception '점검 실패(S1 판정 mark 12): %', v_card; end if;
    v_card := '{"w": 2, "z": "2026-11-01", "y": ["2026-11-02"]}'::jsonb;
    v_card := public.lec__set_mark(v_card, false, 'test', date '2026-11-03');
    if v_card is distinct from '{"w": 3, "z": "2026-11-03"}'::jsonb then raise exception '점검 실패(S1 판정 mark 13): %', v_card; end if;
    for v_case in select * from (values
        ('{"z": "2026-11-10"}'::jsonb, date '2026-11-10', false),
        ('{"z": "2026-11-10"}'::jsonb, date '2026-11-11', true),
        ('{"z": "2026-11-10", "y": ["2026-11-11"]}'::jsonb, date '2026-11-11', false),
        ('{"z": "2026-11-10", "y": ["2026-11-11"]}'::jsonb, date '2026-11-12', true),
        ('{}'::jsonb, date '2026-11-12', false)
      ) as x(a, b, c) loop
      if public.lec__set_due_on(v_case.a, v_case.b) is distinct from v_case.c then raise exception '점검 실패(S1 판정 dueOn % %)', v_case.a, v_case.b; end if;
    end loop;
    for v_case in select * from (values
        ('{"d": ["2026-11-10", "2026-11-11"], "t": "2026-11-11"}'::jsonb, true),
        ('{"d": ["2026-11-10", "2026-11-11"]}'::jsonb, false),
        ('{"d": ["2026-11-10"], "t": "2026-11-10"}'::jsonb, false),
        ('{}'::jsonb, false)
      ) as x(a, b) loop
      if public.lec__set_memo(v_case.a) is distinct from v_case.b then raise exception '점검 실패(S1 판정 memo %)', v_case.a; end if;
    end loop;
    select array_agg(e ->> 'k' order by o) into v_ta
      from jsonb_array_elements(public.lec__set_keys('voc', '[{"w": "a", "k": "k1"}, {"w": "b", "k": "k2"}, {"w": "a", "k": "k3"}]'::jsonb, '[{"w": "b"}, {"w": "a"}, {"w": "c"}, {"w": "a"}, {"w": "a"}]'::jsonb)) with ordinality as u(e, o);
    if v_ta is distinct from array['k2', 'k1', 'k4', 'k3', 'k5'] then raise exception '점검 실패(S1 판정 keys 1): %', v_ta; end if;
    select array_agg(e ->> 'k' order by o) into v_ta
      from jsonb_array_elements(public.lec__set_keys('voc', '[]'::jsonb, '[{"w": "x"}, {"w": "y"}, {"w": "x"}]'::jsonb)) with ordinality as u(e, o);
    if v_ta is distinct from array['k1', 'k2', 'k3'] then raise exception '점검 실패(S1 판정 keys 2): %', v_ta; end if;
    select array_agg(e ->> 'k' order by o) into v_ta
      from jsonb_array_elements(public.lec__set_keys('voc', '[{"w": "Apple", "k": "k1"}, {"w": "pear", "k": "k9"}]'::jsonb, '[{"w": "apple."}, {"w": "plum"}]'::jsonb)) with ordinality as u(e, o);
    if v_ta is distinct from array['k1', 'k10'] then raise exception '점검 실패(S1 판정 keys 3): %', v_ta; end if;
    select array_agg(e ->> 'k' order by o) into v_ta
      from jsonb_array_elements(public.lec__set_keys('gu', '[{"e": "I go / home.", "k": "k1"}]'::jsonb, '[{"e": "I go home."}, {"e": "We go / home."}]'::jsonb)) with ordinality as u(e, o);
    if v_ta is distinct from array['k1', 'k2'] then raise exception '점검 실패(S1 판정 keys 4): %', v_ta; end if;
    select array_agg(e ->> 'k' order by o) into v_ta
      from jsonb_array_elements(public.lec__set_keys('gram', '[{"s": "A ( b / c )", "k": "k7"}]'::jsonb, '[{"s": "a ( B / C )."}, {"s": "x [y]"}]'::jsonb)) with ordinality as u(e, o);
    if v_ta is distinct from array['k7', 'k8'] then raise exception '점검 실패(S1 판정 keys 5): %', v_ta; end if;

    -- 1) 없는 열쇠 → 학생 함수 모두 'key'
    v_t := 'selftest-none-' || v_ks;
    if (public.lec_set_home(v_t) ->> 'err') is distinct from 'key'
       or (public.lec_set_items(v_t, gen_random_uuid()) ->> 'err') is distinct from 'key'
       or (public.lec_set_card(v_t, gen_random_uuid(), '{}'::jsonb) ->> 'err') is distinct from 'key'
       or (public.lec_set_test(v_t, gen_random_uuid()) ->> 'err') is distinct from 'key'
       or (public.lec_set_due(v_t) ->> 'err') is distinct from 'key'
       or (public.lec_set_ans(v_t, gen_random_uuid(), 0, 'a') ->> 'err') is distinct from 'key'
       or (public.lec_rec_begin(v_t, gen_random_uuid(), 'k1', 'audio/webm', 10, 1000) ->> 'err') is distinct from 'key'
       or (public.lec_rec_done(v_t, gen_random_uuid()) ->> 'err') is distinct from 'key' then
      raise exception '점검 실패(S1 없는 열쇠)';
    end if;

    -- 학생 넷(가 · 나 = 히즈클래스 기록 동의만 · S1-b 부터 세트 동의 · 녹음 동의 없음 · 다 = 동의 없음 · 마 = 반 없는 열쇠) · 반 둘
    v_c1 := 'selftest-s1-' || v_ks || '-a';
    v_c2 := 'selftest-s1-' || v_ks || '-b';
    v_ka := 'selftest' || v_ks || 's1a';
    v_kb := 'selftest' || v_ks || 's1b';
    v_kc := 'selftest' || v_ks || 's1c';
    v_ke := 'selftest' || v_ks || 's1e';
    insert into public.lec_key (kh, sid, rid, pin, sname, cls) values
      (public.lec__kh(v_ka), v_sa, 'selftest-s1a', '', '점검가', array[v_c1]),
      (public.lec__kh(v_kb), 'selftest-s1b|점검나', 'selftest-s1b', '', '점검나', array[v_c1]),
      (public.lec__kh(v_kc), 'selftest-s1c|점검다', 'selftest-s1c', '', '점검다', array[v_c1]),
      (public.lec__kh(v_ke), 'selftest-s1e|점검마', 'selftest-s1e', '', '점검마', '{}');
    insert into public.lec_consent (sid, choice, ver) values
      (v_sa, 'agree', public.lec__consent_ver()),
      ('selftest-s1b|점검나', 'agree', public.lec__consent_ver()),
      ('selftest-s1e|점검마', 'agree', public.lec__consent_ver());

    -- 3) 선생님 함수: 로그인 없음 · anon · 관리자 아닌 선생님 = forbidden
    foreach v_t in array array['', '{"role":"anon"}', '{"role":"authenticated","email":"joey@his.kr"}'] loop
      perform set_config('request.jwt.claims', v_t, true);
      if public.lec_set_is_admin()
         or (public.lec_set_list_staff() ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_get(gen_random_uuid()) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_put(null, 'voc', 't', array[v_c1], null, '[{"w":"a","m":"b"}]'::jsonb, null) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_hide(gen_random_uuid(), true) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_del(gen_random_uuid()) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_staff(gen_random_uuid()) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_wrong_staff(v_c1) ->> 'err') is distinct from 'forbidden'
         or (public.lec_rec_mark(gen_random_uuid(), 'ok', 0) ->> 'err') is distinct from 'forbidden'
         or (public.lec_rec_expired() ->> 'err') is distinct from 'forbidden'
         or (public.lec_rec_gone('{}'::uuid[]) ->> 'err') is distinct from 'forbidden' then
        raise exception '점검 실패(S1 관리자 아님 막기 «%»)', v_t;
      end if;
    end loop;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);
    if not public.lec_set_is_admin() or not coalesce((public.lec_set_list_staff() ->> 'ok')::boolean, false) then
      raise exception '점검 실패(S1 관리자 알아봄)';
    end if;

    -- 4) 세트 저장 검사(종류 · 이름 · 반 · 꼴 · 한도 · 문항마다 · 문법 괄호 · ★ 차례)
    for v_case in select * from (values
        ('xx'::text, 't'::text, array[v_c1]::text[], '[{"w":"a","m":"b"}]'::jsonb, null::integer[], 'kind'::text, null::integer, null::text),
        ('voc', '  ', array[v_c1], '[{"w":"a","m":"b"}]', null, 'title', null, null),
        ('voc', repeat('가', 61), array[v_c1], '[{"w":"a","m":"b"}]', null, 'title', null, null),
        ('voc', 't', array['*', v_c1], '[{"w":"a","m":"b"}]', null, 'cls', null, null),
        ('voc', 't', array['', ' '], '[{"w":"a","m":"b"}]', null, 'cls', null, null),
        ('voc', 't', array[v_c1], '{"w":"a"}', null, 'input', null, null),
        ('voc', 't', array[v_c1], '[]', null, 'items', null, null),
        ('voc', 't', array[v_c1], (select jsonb_agg(jsonb_build_object('w', 'a' || g, 'm', 'b')) from generate_series(1, 301) g), null, 'limit', null, null),
        ('gu', 't', array[v_c1], (select jsonb_agg(jsonb_build_object('e', 'a' || g, 't', 'b')) from generate_series(1, 31) g), null, 'limit', null, null),
        ('gram', 't', array[v_c1], (select jsonb_agg(jsonb_build_object('s', 'a (b / c)', 'a', 'b')) from generate_series(1, 51) g), null, 'limit', null, null),
        ('voc', 't', array[v_c1], '[{"w":"a","m":""}]', null, 'items', 0, 'm'),
        ('voc', 't', array[v_c1], '[{"w":"a","m":"b"},{"w":"","m":"c"}]', null, 'items', 1, 'w'),
        ('voc', 't', array[v_c1], '[{"w":"a","m":"b","n":"123456789"}]', null, 'items', 0, 'len'),
        ('voc', 't', array[v_c1], '[1]', null, 'items', 0, 'w'),
        ('gu', 't', array[v_c1], '[{"e":"a","t":""}]', null, 'items', 0, 't'),
        ('gu', 't', array[v_c1], '[{"e":" ","t":"x"}]', null, 'items', 0, 'e'),
        ('gu', 't', array[v_c1], jsonb_build_array(jsonb_build_object('e', 'a', 't', 'b', 'p', repeat('x', 61))), null, 'items', 0, 'len'),
        ('gram', 't', array[v_c1], '[{"s":"no bracket","a":"x"}]', null, 'items', 0, 'opt'),
        ('gram', 't', array[v_c1], '[{"s":"I (am / is) [b]","a":"am"}]', null, 'items', 0, 'opt'),
        ('gram', 't', array[v_c1], '[{"s":"I (am / is) a (b / c)","a":"am"}]', null, 'items', 0, 'opt'),
        ('gram', 't', array[v_c1], '[{"s":"I (am / is)","a":"are"}]', null, 'items', 0, 'opt'),
        ('gram', 't', array[v_c1], '[{"s":"I (am / )","a":"am"}]', null, 'items', 0, 'opt'),
        ('gram', 't', array[v_c1], '[{"s":"I (a / b / c / d / e / f)","a":"a"}]', null, 'items', 0, 'opt'),
        ('gram', 't', array[v_c1], '[{"s":"I [ ] go","a":"x"}]', null, 'items', 0, 'blank'),
        ('gram', 't', array[v_c1], '[{"s":"I [go]","a":""}]', null, 'items', 0, 'a'),
        ('gram', 't', array[v_c1], '[{"s":"","a":"x"}]', null, 'items', 0, 's'),
        ('gram', 't', array[v_c1], jsonb_build_array(jsonb_build_object('s', 'I [go]', 'a', 'went', 'x', repeat('x', 301))), null, 'items', 0, 'len'),
        ('gu', 't', array[v_c1], '[{"e":"a","t":"b"},{"e":"c","t":"d"}]', array[5], 'pick', null, null),
        ('gu', 't', array[v_c1], '[{"e":"a","t":"b"},{"e":"c","t":"d"}]', array[0, 0], 'pick', null, null),
        ('gu', 't', array[v_c1], '[{"e":"a","t":"b"},{"e":"c","t":"d"}]', array[0, 1, 1], 'pick', null, null),
        ('gu', 't', array[v_c1], '[{"e":"a","t":"b"},{"e":"c","t":"d"}]', array[-1], 'pick', null, null)
      ) as x(kind, title, cls, items, pick, err, at, why) loop
      r := public.lec_set_put(null, v_case.kind, v_case.title, v_case.cls, null, v_case.items, v_case.pick);
      if (r ->> 'err') is distinct from v_case.err
         or (v_case.at is not null and ((r ->> 'at')::integer is distinct from v_case.at or (r ->> 'why') is distinct from v_case.why)) then
        raise exception '점검 실패(S1 저장 검사 % % %): %', v_case.kind, v_case.err, v_case.why, r;
      end if;
    end loop;
    -- 고쳐 다시 넣기 → 열쇠 그대로(옛 [a b a] → 새 [b a c a a] = k2 k1 k4 k3 k5) · 종류는 못 바꿈 · 없는 세트 · 공개일 null = 그대로
    r := public.lec_set_put(null, 'voc', '점검 열쇠', array[v_c2], null,
                            '[{"w":"a","m":"가"},{"w":"b","m":"나"},{"w":"a","m":"다"}]'::jsonb, null);
    v_kset := (r ->> 'id')::uuid;
    if not coalesce((r ->> 'ok')::boolean, false) or (r -> 'items' -> 2 ->> 'k') is distinct from 'k3' then
      raise exception '점검 실패(S1 처음 열쇠): %', r;
    end if;
    r := public.lec_set_put(v_kset, 'voc', '점검 열쇠', array[v_c2], null,
                            '[{"w":"b","m":"나"},{"w":"a","m":"가"},{"w":"c","m":"라"},{"w":"a","m":"다"},{"w":"a","m":"마"}]'::jsonb, null);
    select array_agg(u.e ->> 'k' order by u.o) into v_ta from jsonb_array_elements(r -> 'items') with ordinality as u(e, o);
    if v_ta is distinct from array['k2', 'k1', 'k4', 'k3', 'k5'] then
      raise exception '점검 실패(S1 고친 열쇠): %', r;
    end if;
    if (public.lec_set_put(v_kset, 'gu', '점검 열쇠', array[v_c2], null, '[{"e":"a","t":"b"}]'::jsonb, null) ->> 'err') is distinct from 'kind'
       or (public.lec_set_put(gen_random_uuid(), 'voc', 't', array[v_c2], null, '[{"w":"a","m":"b"}]'::jsonb, null) ->> 'err') is distinct from 'none' then
      raise exception '점검 실패(S1 고칠 때 종류 · 없는 세트)';
    end if;
    update public.lec_set set posted_on = v_d - 3 where id = v_kset;
    r := public.lec_set_put(v_kset, 'voc', '점검 열쇠', array[v_c2], null, '[{"w":"b","m":"나"}]'::jsonb, null);
    if (select xs.posted_on from public.lec_set xs where xs.id = v_kset) is distinct from v_d - 3 then
      raise exception '점검 실패(S1 고칠 때 공개일 그대로)';
    end if;

    -- 쓸 세트: 단어 10(반 겹침 · 빈 반 지움) · 구문 3(★ 기본 k1 k2) · 문법 2(고르기 · 고쳐 쓰기) · 단어 한도용 · 숨김 · 앞날 · 다른 반
    r := public.lec_set_put(null, 'voc', '점검 단어', array[v_c1, ' ', v_c1], null, '[
      {"n":"1","w":"apple","m":"사과"},{"n":"2","w":"bread","m":"빵"},{"n":"3","w":"chair","m":"의자"},
      {"n":"4","w":"dance","m":"춤추다"},{"n":"5","w":"eagle","m":"독수리"},{"n":"6","w":"fresh","m":"신선한"},
      {"n":"7","w":"green","m":"초록색"},{"n":"8","w":"house","m":"집"},{"n":"9","w":"juice","m":"주스"},
      {"n":"10","w":"knife","m":"칼"}]'::jsonb, null);
    v_voc := (r ->> 'id')::uuid;
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'n')::integer <> 10
       or (select xs.class_ids from public.lec_set xs where xs.id = v_voc) is distinct from array[v_c1] then
      raise exception '점검 실패(S1 단어 세트 저장): %', r;
    end if;
    r := public.lec_set_put(null, 'gu', '점검 구문', array[v_c1], null, '[
      {"e":"I go / to school.","t":"나는 학교에 간다.","p":"부사구"},
      {"e":"She reads / a book.","t":"그녀는 책을 읽는다.","p":""},
      {"e":"We play / soccer.","t":"우리는 축구를 한다."}]'::jsonb, null);
    v_gu := (r ->> 'id')::uuid;
    if (r -> 'pick') is distinct from '["k1", "k2"]'::jsonb then
      raise exception '점검 실패(S1 구문 ★ 기본): %', r;
    end if;
    r := public.lec_set_put(null, 'gram', '점검 문법', array[v_c1], null, '[
      {"s":"She (go / goes) to school.","a":"goes","x":"주어가 3인칭 단수예요.","p":"수일치"},
      {"s":"He [play] soccer yesterday.","a":"played","x":"어제 = 과거","p":"시제"}]'::jsonb, null);
    v_gram := (r ->> 'id')::uuid;
    if not coalesce((r ->> 'ok')::boolean, false) or (r -> 'pick') is distinct from '[]'::jsonb then
      raise exception '점검 실패(S1 문법 세트 저장): %', r;
    end if;
    r := public.lec_set_put(null, 'voc', '점검 한도', array[v_c1], null, '[{"w":"one","m":"하나"},{"w":"two","m":"둘"}]'::jsonb, null);
    v_v2 := (r ->> 'id')::uuid;
    r := public.lec_set_put(null, 'voc', '점검 숨김', array[v_c1], null, '[{"w":"hid","m":"숨김"}]'::jsonb, null);
    v_hid := (r ->> 'id')::uuid;
    r := public.lec_set_put(null, 'voc', '점검 앞날', array[v_c1], v_d + 1, '[{"w":"fut","m":"앞날"}]'::jsonb, null);
    v_fut := (r ->> 'id')::uuid;
    r := public.lec_set_put(null, 'voc', '점검 다른 반', array[v_c2], null, '[{"w":"oth","m":"다른"}]'::jsonb, null);
    v_oth := (r ->> 'id')::uuid;
    if (public.lec_set_hide(v_hid, true) ->> 'hidden')::boolean is distinct from true
       or (public.lec_set_hide(gen_random_uuid(), true) ->> 'err') is distinct from 'none'
       or (public.lec_set_get(v_gram) -> 'set' ->> 'need')::integer <> 2
       or jsonb_array_length(public.lec_set_get(v_gram) -> 'set' -> 'items') <> 2
       or (public.lec_set_get(gen_random_uuid()) ->> 'err') is distinct from 'none' then
      raise exception '점검 실패(S1 숨기기 · 가져오기)';
    end if;

    -- 2) 동의: 히즈클래스 기록 동의 없음 = consent · 기록 동의만 있으면 세트가 바로 열림(S1-b · 세트 동의 · 녹음 동의 없음)
    --    옛 화면용 'agree' true · 'rec' {ok true} · 내 진도(me) · 쌓인 오답(due)이 바로 옴 · 'ver' 없음 · 열기 · 오답 판도 'agree' 로 안 막힘
    if (public.lec_set_home(v_kc) ->> 'err') is distinct from 'consent'
       or (public.lec_set_items(v_kc, v_voc) ->> 'err') is distinct from 'consent'
       or (public.lec_set_due(v_kc) ->> 'err') is distinct from 'consent'
       or (public.lec_set_card(v_kc, v_voc, '{}'::jsonb) ->> 'err') is distinct from 'consent'
       or (public.lec_set_test(v_kc, v_voc) ->> 'err') is distinct from 'consent'
       or (public.lec_set_ans(v_kc, gen_random_uuid(), 0, 'a') ->> 'err') is distinct from 'consent'
       or (public.lec_rec_begin(v_kc, v_gu, 'k1', 'audio/webm', 1000, 3000) ->> 'err') is distinct from 'consent' then
      raise exception '점검 실패(S1 기록 동의 없음)';
    end if;
    r := public.lec_set_home(v_kb);
    if not coalesce((r ->> 'ok')::boolean, false) or not coalesce((r ->> 'agree')::boolean, false)
       or not coalesce((r -> 'rec' ->> 'ok')::boolean, false) or r ? 'ver'
       or jsonb_typeof(r -> 'due') is distinct from 'object' or (r -> 'due' ->> 'n')::integer <> 0
       or jsonb_array_length(r -> 'sets') <> 4
       or exists (select 1 from jsonb_array_elements(r -> 'sets') as u(e) where jsonb_typeof(u.e -> 'me') is distinct from 'object') then
      raise exception '점검 실패(S1 기록 동의만으로 목록): %', r;
    end if;
    r := public.lec_set_items(v_kb, v_gu);
    if not coalesce((r ->> 'ok')::boolean, false) or not coalesce((r -> 'rec' ->> 'ok')::boolean, false)
       or not coalesce((public.lec_set_items(v_kb, v_voc) ->> 'ok')::boolean, false)
       or not coalesce((public.lec_set_due(v_kb) ->> 'ok')::boolean, false) then
      raise exception '점검 실패(S1 기록 동의만으로 열기): %', r;
    end if;
    r := public.lec_set_home(v_ka);
    if not coalesce((r ->> 'agree')::boolean, false) or (r -> 'due' ->> 'n')::integer <> 0
       or ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_voc::text) -> 'me' ->> 'test') is distinct from 'none'
       or ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_gu::text) ->> 'pick')::integer <> 2 then
      raise exception '점검 실패(S1 목록): %', r;
    end if;

    -- 5) 보임: 숨김 · 앞날 공개 · 다른 반 · 없는 세트 · 반 없는 열쇠 = none · 종류 다름 = kind
    if (public.lec_set_items(v_ka, v_hid) ->> 'err') is distinct from 'none'
       or (public.lec_set_test(v_ka, v_fut) ->> 'err') is distinct from 'none'
       or (public.lec_set_items(v_ka, v_oth) ->> 'err') is distinct from 'none'
       or (public.lec_set_test(v_ka, gen_random_uuid()) ->> 'err') is distinct from 'none'
       or jsonb_array_length(public.lec_set_home(v_ke) -> 'sets') <> 0
       or (public.lec_set_items(v_ke, v_voc) ->> 'err') is distinct from 'none'
       or (public.lec_set_items(v_ka, v_gram) ->> 'err') is distinct from 'kind'
       or (public.lec_set_test(v_ka, v_gu) ->> 'err') is distinct from 'kind'
       or (public.lec_set_card(v_ka, v_gram, '{}'::jsonb) ->> 'err') is distinct from 'kind' then
      raise exception '점검 실패(S1 보임)';
    end if;

    -- 6) 단어 시험(10문항 · 통과 9): 정답 · 해설 · 열쇠가 폰에 안 감 · 고르기 5(보기 4) · 쓰기 5 · 짝홀 꼴
    r := public.lec_set_test(v_ka, v_voc);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'kind') <> 'test' or (r ->> 'n')::integer <> 10
       or (r ->> 'total')::integer <> 10 or (r ->> 'need')::integer <> 9 or (r ->> 'round')::integer <> 1
       or (r ->> 'kn')::integer <> 0 or jsonb_array_length(r -> 'done') <> 0 then
      raise exception '점검 실패(S1 단어 시험 열기): %', r;
    end if;
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if exists (select 1 from jsonb_array_elements(r -> 'q') as u(e) where u.e ? 'a' or u.e ? 'x' or u.e ? 'k' or u.e ? 'pt')
       or (select count(*) from jsonb_array_elements(r -> 'q') as u(e)
            where case when u.e ->> 'f' = 'c' then jsonb_array_length(u.e -> 'o') = 4 else false end) <> 5
       or (select count(*) from jsonb_array_elements(r -> 'q') as u(e) where u.e ->> 'f' = 'w' and jsonb_typeof(u.e -> 'o') = 'null') <> 5
       or r::text ~ '(bread|dance|fresh|house|knife)'
       or exists (select 1 from jsonb_array_elements(v_q) as u(e)
                   where (u.e ->> 'f' = 'c') is distinct from (substr(u.e ->> 'k', 2)::integer % 2 = 1)) then
      raise exception '점검 실패(S1 단어 시험 문항 꼴 · 정답이 폰에 감): %', r;
    end if;
    if (public.lec_set_items(v_ka, v_voc) ->> 'err') is distinct from 'testing'
       or (public.lec_set_test(v_ka, v_voc) ->> 'try')::uuid is distinct from v_try then
      raise exception '점검 실패(S1 시험 중 외우기 막음 · 이어서)';
    end if;
    r := public.lec_set_ans(v_ka, v_try, 0, 'zzz');
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'r')::boolean or (r ->> 'again')::boolean
       or (r ->> 'a') is distinct from (v_q -> 0 ->> 'a') or (r ->> 'left')::integer <> 9 or jsonb_typeof(r -> 'end') <> 'null' then
      raise exception '점검 실패(S1 첫 답): %', r;
    end if;
    r := public.lec_set_ans(v_ka, v_try, 0, v_q -> 0 ->> 'a');
    if not coalesce((r ->> 'again')::boolean, false) or (r ->> 'r')::boolean then
      raise exception '점검 실패(S1 같은 문항 다시 = 처음 결과): %', r;
    end if;
    if (public.lec_set_ans(v_ka, v_try, 10, 'a') ->> 'err') is distinct from 'input'
       or (public.lec_set_ans(v_ka, v_try, -1, 'a') ->> 'err') is distinct from 'input'
       or (public.lec_set_ans(v_ka, v_try, 1, ' ') ->> 'err') is distinct from 'input'
       or (public.lec_set_ans(v_ka, v_try, 1, repeat('a', 201)) ->> 'err') is distinct from 'input'
       or (public.lec_set_ans(v_ke, v_try, 1, 'a') ->> 'err') is distinct from 'try'
       or (public.lec_set_ans(v_ka, gen_random_uuid(), 1, 'a') ->> 'err') is distinct from 'try' then
      raise exception '점검 실패(S1 답 막기)';
    end if;
    for i in 1 .. 9 loop
      r := public.lec_set_ans(v_ka, v_try, i, case when i < 3 then 'zzz' else v_q -> i ->> 'a' end);
      if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'r')::boolean is distinct from (i >= 3) then
        raise exception '점검 실패(S1 단어 채점 %): %', i, r;
      end if;
    end loop;
    if jsonb_typeof(r -> 'end') is distinct from 'object'
       or (r -> 'end' ->> 'sc')::integer <> 7 or (r -> 'end' ->> 'kn')::integer <> 7 or (r -> 'end' ->> 'pass')::boolean
       or (r -> 'end' ->> 'ever')::integer <> 3 or (r -> 'end' ->> 'f1')::integer <> 70 or (r -> 'end' ->> 'next') <> 'retake'
       or (r -> 'end' ->> 'need')::integer <> 9 or (r -> 'end' ->> 'total')::integer <> 10 then
      raise exception '점검 실패(S1 단어 시험 끝): %', r;
    end if;
    select xp.kn into v_kn from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc;
    if cardinality(v_kn) <> 7
       or (select xp.f1 from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc) <> 70
       or (select xp.best from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc) <> 70
       or (select xp.tn from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc) <> 1 then
      raise exception '점검 실패(S1 단어 진도)';
    end if;
    r := public.lec_set_ans(v_ka, v_try, 9, 'x');
    if not coalesce((r ->> 'again')::boolean, false) or (r -> 'end' ->> 'next') is distinct from 'retake' then
      raise exception '점검 실패(S1 끝난 판 다시): %', r;
    end if;
    -- 다시 보기: 틀린 셋 전부 w + 맞힌 것 셋
    r := public.lec_set_test(v_ka, v_voc);
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if (r ->> 'n')::integer <> 6 or (r ->> 'round')::integer <> 2 or (r ->> 'kn')::integer <> 7
       or (select count(*) from jsonb_array_elements(v_q) as u(e) where not ((u.e ->> 'k') = any (v_kn)) and u.e ->> 'f' = 'w') <> 3
       or (select count(*) from jsonb_array_elements(v_q) as u(e) where (u.e ->> 'k') = any (v_kn)) <> 3 then
      raise exception '점검 실패(S1 다시 보기 짜기): %', v_q;
    end if;
    for i in 0 .. 5 loop
      r := public.lec_set_ans(v_ka, v_try, i, v_q -> i ->> 'a');
    end loop;
    if (r -> 'end' ->> 'pass')::boolean is distinct from true or (r -> 'end' ->> 'next') is distinct from 'pass'
       or (r -> 'end' ->> 'kn')::integer <> 10 or (r -> 'end' ->> 'f1')::integer <> 70 then
      raise exception '점검 실패(S1 통과): %', r;
    end if;
    if (public.lec_set_test(v_ka, v_voc) ->> 'err') is distinct from 'pass'
       or (select xp.best from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc) <> 100
       or (select xp.pass_at from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc) is null then
      raise exception '점검 실패(S1 통과 뒤)';
    end if;
    -- 하루 다섯 번 뒤 여섯째 = limit
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs, ans, got, done_at)
    select v_sa, v_v2, 'test', v_d, 1, '[{}]'::jsonb, '[null]'::jsonb, 1, now() from generate_series(1, 5);
    if (public.lec_set_test(v_ka, v_v2) ->> 'err') is distinct from 'limit'
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_ka) -> 'sets') as u(e) where u.e ->> 'id' = v_v2::text)
           -> 'me' ->> 'left')::integer <> 0 then
      raise exception '점검 실패(S1 하루 한도)';
    end if;

    -- 7) 문법 드릴: 고르기(보기 차례 그대로) · 고쳐 쓰기 · 해설 · 포인트는 답한 뒤에만 · 떨어지면 내일 · 날이 바뀌면 다시
    r := public.lec_set_test(v_ka, v_gram);
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if (r ->> 'kind') is distinct from 'drill' or (r ->> 'n')::integer <> 2 or (r ->> 'need')::integer <> 2
       or (select count(*) from jsonb_array_elements(r -> 'q') as u(e) where u.e ->> 'f' = 'c' and u.e -> 'o' = '["go", "goes"]'::jsonb) <> 1
       or (select count(*) from jsonb_array_elements(r -> 'q') as u(e) where u.e ->> 'f' = 'r') <> 1
       or r::text like '%played%' or r::text like '%수일치%' or r::text like '%과거%' then
      raise exception '점검 실패(S1 드릴 열기): %', r;
    end if;
    for i in 0 .. 1 loop
      r := public.lec_set_ans(v_ka, v_try, i, case when v_q -> i ->> 'f' = 'c' then 'goes' else 'playd' end);
      if ((v_q -> i ->> 'f') = 'c' and ((r ->> 'r')::boolean is distinct from true or (r ->> 'x') is distinct from '주어가 3인칭 단수예요.'
                                        or (r ->> 'pt') is distinct from '수일치'))
         or ((v_q -> i ->> 'f') = 'r' and ((r ->> 'r')::boolean is distinct from false or (r ->> 'a') is distinct from 'played')) then
        raise exception '점검 실패(S1 드릴 채점 %): %', i, r;
      end if;
    end loop;
    if (r -> 'end' ->> 'pass')::boolean or (r -> 'end' ->> 'next') is distinct from 'tomorrow' or (r -> 'end' ->> 'sc')::integer <> 1 then
      raise exception '점검 실패(S1 드릴 끝): %', r;
    end if;
    if (public.lec_set_test(v_ka, v_gram) ->> 'err') is distinct from 'tomorrow'
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_ka) -> 'sets') as u(e) where u.e ->> 'id' = v_gram::text)
           -> 'me' ->> 'next') is distinct from 'tomorrow'
       or (select xp.last_sc from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_gram) <> 1
       or (select xp.f1 from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_gram) <> 50 then
      raise exception '점검 실패(S1 드릴 내일)';
    end if;
    update public.lec_set_try set day = v_d - 1 where sid = v_sa and set_id = v_gram;
    r := public.lec_set_test(v_ka, v_gram);
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'round')::integer <> 2 then
      raise exception '점검 실패(S1 드릴 다음 날): %', r;
    end if;
    for i in 0 .. 1 loop
      r := public.lec_set_ans(v_ka, v_try, i, case when v_q -> i ->> 'f' = 'c' then 'Goes' else ' Played. ' end);
    end loop;
    if (r -> 'end' ->> 'pass')::boolean is distinct from true or (r -> 'end' ->> 'next') is distinct from 'pass' then
      raise exception '점검 실패(S1 드릴 통과): %', r;
    end if;

    -- 9) 쌓인 오답: z 를 어제로 넣은 카드 하나 = 오늘 나옴 · 답이 그 세트 카드를 고침 · 다 하면 없음
    v_t := (select y.kk from unnest(array['k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8', 'k9', 'k10']) with ordinality as y(kk, o)
             where not (y.kk = any (v_kn)) order by y.o limit 1);
    update public.lec_set_prog xp
       set cards = jsonb_set(xp.cards, array[v_t], jsonb_build_object('w', 1, 'z', to_char(v_d - 1, 'YYYY-MM-DD')))
     where xp.sid = v_sa and xp.set_id = v_voc;
    -- 그 세트에 시험 판이 열려 있으면 쌓인 오답에서 빠짐(시험 중 정답 엿보기 막기 · 수는 n 에 남고 now 에서 빠짐)
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs, ans)
    values (v_sa, v_voc, 'test', v_d, 1, '[{}]'::jsonb, '[null]'::jsonb)
    returning id into v_busy;
    r := public.lec_set_home(v_ka);
    if (r -> 'due' ->> 'n')::integer <> 4 or (r -> 'due' ->> 'now')::integer <> 0
       or jsonb_typeof(public.lec_set_due(v_ka) -> 'try') is distinct from 'null' then
      raise exception '점검 실패(S1 시험 중 쌓인 오답 뺌): %', r -> 'due';
    end if;
    delete from public.lec_set_try xt where xt.id = v_busy;
    r := public.lec_set_home(v_ka);
    if (r -> 'due' ->> 'n')::integer <> 4 or (r -> 'due' ->> 'now')::integer <> 1 then
      raise exception '점검 실패(S1 쌓인 오답 수): %', r -> 'due';
    end if;
    -- 선생님 종이 «쌓인 오답 시험»(관리자 · 이 반에 낸 단어 · 문법 세트만 · 읽기만): 가 = 4 · 어제 틀린 단어가 맨 앞(뜻 → 영어) ·
    -- 구문 · 숨김 · 앞날 · 다른 반 세트 없음 · 빈 반 · 모든 반(*) = cls · 아무도 없는 반 = 빈 줄
    r := public.lec_set_wrong_staff(' ' || v_c1 || ' ');
    v_q := (select y.e from jsonb_array_elements(r -> 'rows') as y(e) where y.e ->> 'sid' = v_sa);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'cls') is distinct from v_c1
       or (r ->> 'today') is distinct from to_char(v_d, 'YYYY-MM-DD')
       or (v_q ->> 'n')::integer is distinct from 4 or jsonb_array_length(v_q -> 'items') is distinct from 4
       or (v_q ->> 'sname') is distinct from '점검가'
       or (v_q -> 'items' -> 0 ->> 'k') is distinct from v_t or (v_q -> 'items' -> 0 ->> 'kd') is distinct from 'voc'
       or (v_q -> 'items' -> 0 ->> 's') is distinct from v_voc::text
       or (v_q -> 'items' -> 0 ->> 'z') is distinct from to_char(v_d - 1, 'YYYY-MM-DD')
       or (v_q -> 'items' -> 0 ->> 'q') is distinct from (select y.e ->> 'm' from public.lec_set xs cross join jsonb_array_elements(xs.items) as y(e)
                                                            where xs.id = v_voc and y.e ->> 'k' = v_t)
       or (v_q -> 'items' -> 0 ->> 'a') is distinct from (select y.e ->> 'w' from public.lec_set xs cross join jsonb_array_elements(xs.items) as y(e)
                                                            where xs.id = v_voc and y.e ->> 'k' = v_t)
       or exists (select 1 from jsonb_array_elements(r -> 'rows') as y(e) cross join jsonb_array_elements(y.e -> 'items') as x(i)
                   where x.i ->> 'kd' not in ('voc', 'gram') or x.i ->> 's' in (v_gu::text, v_hid::text, v_fut::text, v_oth::text))
       or (public.lec_set_wrong_staff(' ') ->> 'err') is distinct from 'cls'
       or (public.lec_set_wrong_staff('*') ->> 'err') is distinct from 'cls'
       or (public.lec_set_wrong_staff(null) ->> 'err') is distinct from 'cls'
       or jsonb_array_length(public.lec_set_wrong_staff(v_c1 || '-none') -> 'rows') is distinct from 0 then
      raise exception '점검 실패(S1 선생님 쌓인 오답 시험): %', r;
    end if;
    r := public.lec_set_due(v_ka);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'kind') is distinct from 'due' or (r ->> 'n')::integer <> 1
       or (r ->> 'title') is distinct from '쌓인 오답' or (r -> 'q' -> 0 ->> 'kd') is distinct from 'voc'
       or (r -> 'q' -> 0 ->> 't') is distinct from '점검 단어' or (r -> 'q' -> 0 ->> 'f') is distinct from 'w'
       or (r -> 'q' -> 0) ? 'a' or (r -> 'q' -> 0) ? 's' then
      raise exception '점검 실패(S1 쌓인 오답 판): %', r;
    end if;
    v_try := (r ->> 'try')::uuid;
    if (public.lec_set_due(v_ka) ->> 'try')::uuid is distinct from v_try then
      raise exception '점검 실패(S1 쌓인 오답 이어서)';
    end if;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    -- 판을 연 뒤 같은 세트 시험을 열면 그 문항은 답(과 정답)을 받지 않음
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs, ans)
    values (v_sa, v_voc, 'test', v_d, 1, '[{}]'::jsonb, '[null]'::jsonb)
    returning id into v_busy;
    r := public.lec_set_ans(v_ka, v_try, 0, v_q -> 0 ->> 'a');
    if (r ->> 'err') is distinct from 'testing' or r ? 'a'
       or (select xt.got from public.lec_set_try xt where xt.id = v_try) <> 0 then
      raise exception '점검 실패(S1 시험 중 쌓인 오답 답 막음): %', r;
    end if;
    delete from public.lec_set_try xt where xt.id = v_busy;
    r := public.lec_set_ans(v_ka, v_try, 0, v_q -> 0 ->> 'a');
    if not coalesce((r ->> 'r')::boolean, false) or (r -> 'end' ->> 'next') is distinct from 'none'
       or (r -> 'end' ->> 'out')::integer is distinct from 0 or (r -> 'end' ->> 'due')::integer is distinct from 4
       or (select xp.cards -> v_t from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_voc)
          is distinct from jsonb_build_object('w', 1, 'z', to_char(v_d - 1, 'YYYY-MM-DD'),
                                              'd', jsonb_build_array(to_char(v_d, 'YYYY-MM-DD')),
                                              'y', jsonb_build_array(to_char(v_d, 'YYYY-MM-DD'))) then
      raise exception '점검 실패(S1 쌓인 오답 답): %', r;
    end if;
    r := public.lec_set_due(v_ka);
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'try') is distinct from 'null' or (r ->> 'n')::integer <> 0 then
      raise exception '점검 실패(S1 쌓인 오답 다 함): %', r;
    end if;

    -- 10) 카드 저장(구문 따라 말하기 · 단어 외우기 · 모르는 열쇠 건너뜀 · 꼴 · 하루 200번)
    r := public.lec_set_card(v_ka, v_gu, '{"k1":1,"k2":0,"k9":1}'::jsonb);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'seen')::integer <> 2 or (r ->> 'said')::integer <> 1 then
      raise exception '점검 실패(S1 따라 말하기 저장): %', r;
    end if;
    r := public.lec_set_card(v_ka, v_voc, '{"k1":1}'::jsonb);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'seen')::integer <> 1 then
      raise exception '점검 실패(S1 외우기 저장): %', r;
    end if;
    -- 구문 2 = 알아요 + 말해서 확인(카드 v 1 · 학생 요약 spk) · 뒤에 0 · 1 을 보내도 v 는 남음
    r := public.lec_set_card(v_ka, v_gu, '{"k3":2}'::jsonb);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'seen')::integer <> 3 or (r ->> 'said')::integer <> 2
       or (select xp.cards -> 'k3' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_gu)
          is distinct from '{"s":1,"g":1,"v":1}'::jsonb then
      raise exception '점검 실패(S1 말해서 확인 저장): %', r;
    end if;
    r := public.lec_set_card(v_ka, v_gu, '{"k3":0,"k1":1}'::jsonb);
    if not coalesce((r ->> 'ok')::boolean, false)
       or (select xp.cards -> 'k3' ->> 'v' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_gu) is distinct from '1'
       or coalesce((select (xp.cards -> 'k1') ? 'v' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_gu), true)
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_ka) -> 'sets') as u(e) where u.e ->> 'id' = v_gu::text)
           -> 'me' ->> 'spk') is distinct from '1' then
      raise exception '점검 실패(S1 말해서 확인 남음 · spk): %', r;
    end if;
    if (public.lec_set_card(v_ka, v_gu, '[1]'::jsonb) ->> 'err') is distinct from 'input'
       or (public.lec_set_card(v_ka, v_gu, '{"k1":3}'::jsonb) ->> 'err') is distinct from 'input'
       or (public.lec_set_card(v_ka, v_gu, '{"k1":"2"}'::jsonb) ->> 'err') is distinct from 'input'
       or (public.lec_set_card(v_ka, v_voc, '{"k1":2}'::jsonb) ->> 'err') is distinct from 'input'
       or (public.lec_set_card(v_ka, v_gu, (select jsonb_object_agg('k' || g, 1) from generate_series(1, 41) g)) ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(S1 카드 꼴 막기)';
    end if;
    update public.lec_set_prog xp set sv_day = v_d, sv_n = 200 where xp.sid = v_sa and xp.set_id = v_gu;
    if (public.lec_set_card(v_ka, v_gu, '{"k1":1}'::jsonb) ->> 'err') is distinct from 'limit' then
      raise exception '점검 실패(S1 카드 하루 한도)';
    end if;
    r := public.lec_set_items(v_ka, v_gu);
    if not coalesce((r ->> 'ok')::boolean, false) or (r -> 'pick') is distinct from '["k1", "k2"]'::jsonb
       or jsonb_array_length(r -> 'items') <> 3 or (r -> 'cards' -> 'k1' ->> 'g') is distinct from '1'
       or jsonb_array_length(public.lec_set_items(v_ka, v_voc) -> 'items') <> 10 then
      raise exception '점검 실패(S1 문항 받기): %', r;
    end if;

    -- 11) 녹음: 녹음 동의 · 학교급 없이 바로 표(S1-b) · 표 · 이름 · 지난 표 · 늦음 · 파일 · 들음 표시 · 다시 냄 · 하루 10개
    v_st := to_regclass('storage.objects') is not null;
    if v_st then
      begin
        execute 'select count(*) from storage.objects where false' into v_n;
      exception when others then
        v_st := false;
      end;
    end if;
    -- «냄»의 파일 확인은 lec_rec_done 주인 권한으로 storage.objects 를 읽음 → 주인이 행 보안에 걸리면 모든 녹음이 «파일 없음»
    if public.lec__rec_fcheck() = 'rls' then
      raise exception '점검 실패(S1 · 녹음 파일 확인 안 됨: lec_rec_done 주인 %(이)가 storage.objects 를 행 보안 때문에 못 읽음 → 녹음이 모두 실패 · 주인을 postgres 로 바꾸거나 BYPASSRLS)',
        (select p.proowner::regrole::text from pg_proc p where p.oid = 'public.lec_rec_done(text, uuid)'::regprocedure);
    end if;
    -- S1-b: 녹음 동의 · 학교급 없음 → 녹음 동의 줄이 없는 학생(나)도 · 옛 줄(lec_rec_ok · 중학생 m · 동의 없음)이 남은 학생(가)도 바로 표
    --   (표는 바로 지울 것(old)으로 돌려 아래 셈에 안 걸리게 · 옛 «거둠» 자리) · lec_set_home · lec_set_items 의 rec.ok 는 늘 true(옛 화면)
    r := public.lec_rec_begin(v_kb, v_gu, 'k1', 'audio/webm', 1000, 3000);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'path') !~ ('^' || v_gu::text || '/[0-9a-f]{32}[.]webm$') then
      raise exception '점검 실패(S1 녹음 동의 줄 없이 표): %', r;
    end if;
    update public.lec_set_rec xr set st = 'old' where xr.id = (r ->> 'id')::uuid;
    insert into public.lec_rec_ok (sid, lvl, lvl_at) values (v_sa, 'm', now());
    r := public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/mp4', 1000, 3000);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'path') !~ ('^' || v_gu::text || '/[0-9a-f]{32}[.]m4a$') then
      raise exception '점검 실패(S1 중학생 · 동의 없이 녹음 표): %', r;
    end if;
    update public.lec_set_rec xr set st = 'old' where xr.id = (r ->> 'id')::uuid;
    if not coalesce((public.lec_set_home(v_ka) -> 'rec' ->> 'ok')::boolean, false)
       or not coalesce((public.lec_set_home(v_kb) -> 'rec' ->> 'ok')::boolean, false)
       or not coalesce((public.lec_set_items(v_ka, v_gu) -> 'rec' ->> 'ok')::boolean, false) then
      raise exception '점검 실패(S1 옛 화면용 rec.ok)';
    end if;
    if (public.lec_rec_begin(v_ka, v_gu, 'k3', 'audio/webm', 1000, 3000) ->> 'err') is distinct from 'pick'
       or (public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/wav', 1000, 3000) ->> 'err') is distinct from 'mime'
       or (public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/webm', 0, 3000) ->> 'err') is distinct from 'size'
       or (public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/webm', 1048577, 3000) ->> 'err') is distinct from 'size'
       or (public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/webm', 1000, 46001) ->> 'err') is distinct from 'size'
       or (public.lec_rec_begin(v_ka, v_voc, 'k1', 'audio/webm', 1000, 3000) ->> 'err') is distinct from 'none' then
      raise exception '점검 실패(S1 녹음 표 막기)';
    end if;
    r := public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/webm', 1000, 3000);
    v_rec := (r ->> 'id')::uuid;
    v_path := r ->> 'path';
    if coalesce(v_path, '') !~ ('^' || v_gu::text || '/[0-9a-f]{32}[.]webm$') or not public.lec_rec_slot(v_path)
       or public.lec_rec_slot(v_gu::text || '/' || repeat('0', 32) || '.webm') or public.lec_rec_slot('x') then
      raise exception '점검 실패(S1 녹음 표 · 올리기 이름): %', r;
    end if;
    update public.lec_set_rec xr set exp_at = now() - interval '1 minute' where xr.id = v_rec;
    if public.lec_rec_slot(v_path) then
      raise exception '점검 실패(S1 지난 표로 올림)';
    end if;
    update public.lec_set_rec xr set exp_at = now() - interval '6 minutes' where xr.id = v_rec;
    if (public.lec_rec_done(v_ka, v_rec) ->> 'err') is distinct from 'late' then
      raise exception '점검 실패(S1 늦은 냄)';
    end if;
    update public.lec_set_rec xr set exp_at = now() + interval '10 minutes' where xr.id = v_rec;
    if (public.lec_rec_done(v_kb, v_rec) ->> 'err') is distinct from 'none'
       or (v_st and (public.lec_rec_done(v_ka, v_rec) ->> 'err') is distinct from 'file') then
      raise exception '점검 실패(S1 남의 녹음 · 파일 없음)';
    end if;
    v_put := false;
    if v_st then
      begin
        execute 'insert into storage.objects (bucket_id, name) values ($1, $2)' using 'lec-rec', v_path;
        v_put := true;
      exception when others then
        v_put := false;
      end;
    end if;
    if v_put or not v_st then
      r := public.lec_rec_done(v_ka, v_rec);
      if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'st') is distinct from 'sent' then
        raise exception '점검 실패(S1 녹음 냄): %', r;
      end if;
    else
      update public.lec_set_rec xr set st = 'done', done_at = now() where xr.id = v_rec;
    end if;
    if (public.lec_rec_done(v_ka, v_rec) ->> 'err') is distinct from 'none' then
      raise exception '점검 실패(S1 낸 녹음 다시 냄)';
    end if;
    r := (select u.e from jsonb_array_elements(public.lec_set_home(v_ka) -> 'sets') as u(e) where u.e ->> 'id' = v_gu::text) -> 'me' -> 'recs';
    if (r -> 0 ->> 'k') is distinct from 'k1' or (r -> 0 ->> 'st') is distinct from 'sent' or (r -> 1 ->> 'st') is distinct from '' then
      raise exception '점검 실패(S1 학생 녹음 표시): %', r;
    end if;
    r := (select u.e from jsonb_array_elements(public.lec_set_list_staff() -> 'items') as u(e) where u.e ->> 'id' = v_gu::text) -> 'cnt';
    if (r ->> 'unheard')::integer is distinct from 1 or (r ->> 'recs')::integer is distinct from 1 or (r ->> 'did')::integer is distinct from 1 then
      raise exception '점검 실패(S1 선생님 목록 수): %', r;
    end if;
    r := public.lec_set_staff(v_gu);
    if ((select u.e from jsonb_array_elements(r -> 'rows') as u(e) where u.e ->> 'sid' = v_sa) -> 'gu' -> 'recs' -> 0 ->> 'path') is distinct from v_path
       or ((select u.e from jsonb_array_elements(r -> 'rows') as u(e) where u.e ->> 'sid' = v_sa) ->> 'sname') is distinct from '점검가'
       or ((select u.e from jsonb_array_elements(r -> 'rows') as u(e) where u.e ->> 'sid' = v_sa) -> 'gu' ->> 'spk') is distinct from '1'
       or jsonb_typeof(r -> 'set' -> 'items') is distinct from 'array'
       or r ? 'recok' then   -- S1-b: 녹음 동의 칸 없음
      raise exception '점검 실패(S1 선생님 결과 표): %', r;
    end if;
    if (public.lec_rec_mark(v_rec, 'zz', 0) ->> 'err') is distinct from 'mark'
       or (public.lec_rec_mark(v_rec, 'ok', 2) ->> 'err') is distinct from 'input'
       or (public.lec_rec_mark(v_rec, 'again', 5) ->> 'err') is distinct from 'input'
       or (public.lec_rec_mark(gen_random_uuid(), 'ok', 0) ->> 'err') is distinct from 'none' then
      raise exception '점검 실패(S1 들음 표시 막기)';
    end if;
    r := public.lec_rec_mark(v_rec, 'again', 1);
    if not coalesce((r ->> 'ok')::boolean, false)
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_ka) -> 'sets') as u(e) where u.e ->> 'id' = v_gu::text)
           -> 'me' -> 'recs' -> 0 ->> 'st') is distinct from 'again'
       or ((select u.e from jsonb_array_elements(public.lec_set_list_staff() -> 'items') as u(e) where u.e ->> 'id' = v_gu::text)
           -> 'cnt' ->> 'unheard')::integer is distinct from 0 then
      raise exception '점검 실패(S1 들음 표시): %', r;
    end if;
    -- 올리기 실패 뒤 다시 보내기: 같은 문장에 새 표 → 앞 올리기 표(wait)는 지울 것(old) · 새 표만 열림
    v_w := (public.lec_rec_begin(v_ka, v_gu, 'k2', 'audio/webm', 1000, 3000) ->> 'id')::uuid;
    r := public.lec_rec_begin(v_ka, v_gu, 'k2', 'audio/webm', 1000, 3000);
    if not coalesce((r ->> 'ok')::boolean, false)
       or (select xr.st from public.lec_set_rec xr where xr.id = v_w) is distinct from 'old'
       or (select xr.st from public.lec_set_rec xr where xr.id = (r ->> 'id')::uuid) is distinct from 'wait'
       or (select xr.st from public.lec_set_rec xr where xr.id = v_rec) is distinct from 'done' then
      raise exception '점검 실패(S1 다시 보내기 · 앞 올리기 표 old): %', r;
    end if;
    -- 다시 냄 → 앞 녹음은 지울 것(old)
    r := public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/ogg', 2000, 4000);
    v_rec2 := (r ->> 'id')::uuid;
    if v_put then
      begin
        execute 'insert into storage.objects (bucket_id, name) values ($1, $2)' using 'lec-rec', r ->> 'path';
      exception when others then
        v_put := false;
      end;
    end if;
    if v_put or not v_st then
      r := public.lec_rec_done(v_ka, v_rec2);
      if (select xr.st from public.lec_set_rec xr where xr.id = v_rec) is distinct from 'old'
         or (select xr.st from public.lec_set_rec xr where xr.id = v_rec2) is distinct from 'done' then
        raise exception '점검 실패(S1 다시 냄): %', r;
      end if;
    end if;
    select count(*) into v_n from public.lec_set_rec xr where xr.sid = v_sa and xr.at >= (v_d::timestamp at time zone 'Asia/Seoul');
    insert into public.lec_set_rec (sid, set_id, k, path, mime, bytes, st, exp_at)
    select v_sa, v_gu, 'k1', v_gu::text || '/' || replace(gen_random_uuid()::text, '-', '') || '.webm', 'audio/webm', 1, 'old', now()
      from generate_series(1, greatest(10 - v_n, 0));
    if (public.lec_rec_begin(v_ka, v_gu, 'k1', 'audio/webm', 1000, 3000) ->> 'err') is distinct from 'limit' then
      raise exception '점검 실패(S1 녹음 하루 한도)';
    end if;

    -- 12) 정리: 지울 것 · 지난 올리기 표 · 30일 지난 녹음을 고름(id 로 바로 봄 · 목록 500개 한도와 무관)
    --     파일이 저장 곳에 남은 줄은 그대로 두고(keep) · 파일이 없는 줄만 지움 또는 gone
    insert into public.lec_set_rec (sid, set_id, k, path, mime, bytes, st, exp_at, at, done_at)
    values (v_sa, v_gu, 'k2', v_gu::text || '/' || replace(gen_random_uuid()::text, '-', '') || '.webm', 'audio/webm', 1, 'done',
            now() - interval '40 days', now() - interval '40 days', now() - interval '31 days')
    returning id into v_rec;
    -- 30일 지난 녹음은 지우기 전에도 선생님 표에서 들을 길(path)이 없음
    select u.e into v_card
      from jsonb_array_elements((select y.e from jsonb_array_elements(public.lec_set_staff(v_gu) -> 'rows') as y(e)
                                  where y.e ->> 'sid' = v_sa) -> 'gu' -> 'recs') as u(e)
     where u.e ->> 'k' = 'k2';
    if (v_card ->> 'st') is distinct from 'done' or (v_card ->> 'path') is distinct from '' then
      raise exception '점검 실패(S1 30일 지난 녹음 듣기 막음): %', v_card;
    end if;
    insert into public.lec_set_rec (sid, set_id, k, path, mime, bytes, st, exp_at, at)
    values (v_sa, v_gu, 'k2', v_gu::text || '/' || replace(gen_random_uuid()::text, '-', '') || '.webm', 'audio/webm', 1, 'wait',
            now() - interval '11 minutes', now() - interval '21 minutes')
    returning id into v_rec2;
    v_ids := array(select xr.id from public.lec_set_rec xr where xr.sid = v_sa and public.lec__rec_exp(xr));
    if not (v_rec = any (v_ids)) or not (v_rec2 = any (v_ids))
       or exists (select 1 from public.lec_set_rec xr where xr.sid = v_sa and xr.st = 'old' and not (xr.id = any (v_ids)))
       or exists (select 1 from public.lec_set_rec xr where xr.sid = v_sa and xr.st = 'done' and xr.id <> v_rec and xr.id = any (v_ids)) then
      raise exception '점검 실패(S1 지울 녹음 고르기)';
    end if;
    r := public.lec_rec_expired();
    if not coalesce((r ->> 'ok')::boolean, false) or jsonb_typeof(r -> 'items') is distinct from 'array'
       or jsonb_array_length(r -> 'items') > 500
       or exists (select 1 from jsonb_array_elements(r -> 'items') as u(e)
                   where not (u.e ? 'id' and u.e ? 'path') or jsonb_typeof(u.e -> 'f') is distinct from 'boolean')
       or (jsonb_array_length(r -> 'items') < 500
           and (select count(*) from jsonb_array_elements(r -> 'items') as u(e) where (u.e ->> 'id')::uuid = any (v_ids)) <> cardinality(v_ids)) then
      raise exception '점검 실패(S1 지울 녹음 목록): %', left(r::text, 300);
    end if;
    v_kept := array(select xr.id from public.lec_set_rec xr where xr.id = any (v_ids) and coalesce(public.lec__rec_has(xr.path), false));
    if v_put and (cardinality(v_kept) = 0
                  or (jsonb_array_length(r -> 'items') < 500 and public.lec__rec_fcheck() = ''
                      and exists (select 1 from jsonb_array_elements(r -> 'items') as u(e)
                                   where (u.e ->> 'id')::uuid = any (v_ids)
                                     and (u.e ->> 'f')::boolean is distinct from ((u.e ->> 'id')::uuid = any (v_kept))))) then
      raise exception '점검 실패(S1 · 지울 녹음 파일 있음 표시 f): %', v_kept;
    end if;
    r := public.lec_rec_gone(v_ids);
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'keep')::integer is distinct from cardinality(v_kept)
       or (select count(*) from public.lec_set_rec xr where xr.id = any (v_kept) and xr.st <> 'gone') <> cardinality(v_kept)
       or exists (select 1 from public.lec_set_rec xr where xr.id = any (v_ids) and not (xr.id = any (v_kept)) and xr.st <> 'gone')
       or (select xr.st from public.lec_set_rec xr where xr.id = v_rec) is distinct from 'gone'
       or exists (select 1 from public.lec_set_rec xr where xr.id = v_rec2)
       or (public.lec_rec_gone(array(select gen_random_uuid() from generate_series(1, 1001))) ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(S1 녹음 줄 정리 · 파일 남은 줄 둠): %', r;
    end if;
    -- 남긴 줄의 파일을 지우고(Supabase 가 SQL 지우기를 막으면 그대로 남음) 다시 정리 → 파일이 사라진 줄만 지움 또는 gone
    if cardinality(v_kept) > 0 then
      begin
        perform set_config('storage.allow_delete_query', 'true', true);
        execute 'delete from storage.objects where bucket_id = $1 and name = any ($2)'
          using 'lec-rec', array(select xr.path from public.lec_set_rec xr where xr.id = any (v_kept));
      exception when others then
        null;
      end;
      r := public.lec_rec_gone(v_kept);
      if not coalesce((r ->> 'ok')::boolean, false)
         or (r ->> 'keep')::integer is distinct from
            (select count(*) from public.lec_set_rec xr where xr.id = any (v_kept) and coalesce(public.lec__rec_has(xr.path), false))::integer
         or exists (select 1 from public.lec_set_rec xr where xr.id = any (v_kept)
                     and not coalesce(public.lec__rec_has(xr.path), false) and xr.st <> 'gone') then
        raise exception '점검 실패(S1 파일 지운 뒤 줄 정리): %', r;
      end if;
    end if;
    -- 지운 녹음은 선생님 표에 st gone · path '' 로
    select u.e into v_card
      from jsonb_array_elements((select y.e from jsonb_array_elements(public.lec_set_staff(v_gu) -> 'rows') as y(e)
                                  where y.e ->> 'sid' = v_sa) -> 'gu' -> 'recs') as u(e)
     where u.e ->> 'k' = 'k2';
    if (v_card ->> 'st') is distinct from 'gone' or (v_card ->> 'path') is distinct from '' then
      raise exception '점검 실패(S1 지운 녹음 표시): %', v_card;
    end if;

    -- 13) 이름 바뀜(lec__move · 트리거) → 진도 · 판 · 녹음 · 옛 녹음 동의 줄(S1-b 부터 안 씀 · 남은 줄)이 따라감 · 동의 지움(lec_forget 과 같은 줄) → 세트 기록 · 옛 줄 지움
    perform public.lec__move(v_sa, v_sa2, '점검가');
    if exists (select 1 from public.lec_set_prog xp where xp.sid = v_sa)
       or exists (select 1 from public.lec_set_try xt where xt.sid = v_sa)
       or exists (select 1 from public.lec_set_rec xr where xr.sid = v_sa)
       or exists (select 1 from public.lec_rec_ok xo where xo.sid = v_sa)
       or (select count(*) from public.lec_set_prog xp where xp.sid = v_sa2) <> 4
       or not exists (select 1 from public.lec_set_try xt where xt.sid = v_sa2)
       or not exists (select 1 from public.lec_set_rec xr where xr.sid = v_sa2)
       or not exists (select 1 from public.lec_rec_ok xo where xo.sid = v_sa2 and xo.lvl = 'm')
       or not public.lec__agreed(v_sa2) then
      raise exception '점검 실패(S1 이름 바뀜 따라감)';
    end if;
    delete from public.lec_consent where sid = v_sa2;
    if exists (select 1 from public.lec_set_prog xp where xp.sid = v_sa2)
       or exists (select 1 from public.lec_set_try xt where xt.sid = v_sa2)
       or exists (select 1 from public.lec_set_rec xr where xr.sid = v_sa2)
       or exists (select 1 from public.lec_rec_ok xo where xo.sid = v_sa2)
       or exists (select 1 from public.lec_set_rec xr where xr.sid = '' and xr.set_id = v_gu and xr.st in ('wait', 'done', 'gone')) then
      raise exception '점검 실패(S1 학생 지움)';
    end if;
    r := public.lec_set_del(v_gu);
    if not coalesce((r ->> 'ok')::boolean, false) or exists (select 1 from public.lec_set xs where xs.id = v_gu)
       or exists (select 1 from public.lec_set_rec xr where xr.set_id = v_gu and xr.st <> 'old')
       or (public.lec_set_del(v_gu) ->> 'err') is distinct from 'none' then
      raise exception '점검 실패(S1 세트 지움): %', r;
    end if;
    perform set_config('request.jwt.claims', '', true);

    -- 14) 권한: 학생 함수 = 누구나 · 선생님 함수 = 로그인한 사람만 · 다섯 표 = 행 보안 · 권한 0 · 정책 0 · 녹음 파일을 누구나 듣는 정책 0
    if not has_function_privilege('anon', 'public.lec_set_home(text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_items(text, uuid)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_card(text, uuid, jsonb)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_test(text, uuid)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_due(text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_ans(text, uuid, integer, text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_rec_begin(text, uuid, text, text, integer, integer)', 'execute')
       or not has_function_privilege('anon', 'public.lec_rec_done(text, uuid)', 'execute')
       or not has_function_privilege('anon', 'public.lec_rec_slot(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_set_home(text)', 'execute') then
      raise exception '점검 실패(S1 학생 함수 권한)';
    end if;
    select string_agg(f, ', ') into v_t
      from unnest(array['public.lec_set_is_admin()', 'public.lec_set_list_staff()', 'public.lec_set_get(uuid)',
                        'public.lec_set_put(uuid, text, text, text[], date, jsonb, integer[])', 'public.lec_set_hide(uuid, boolean)',
                        'public.lec_set_del(uuid)', 'public.lec_set_staff(uuid)', 'public.lec_set_wrong_staff(text)',
                        'public.lec_rec_mark(uuid, text, integer)',
                        'public.lec_rec_expired()', 'public.lec_rec_gone(uuid[])']) as u(f)
     where has_function_privilege('anon', u.f, 'execute') or not has_function_privilege('authenticated', u.f, 'execute');
    if v_t is not null then
      raise exception '점검 실패(S1 선생님 함수 권한): %', v_t;
    end if;
    -- S1-b 에서 없앤 동의 함수 아홉은 정말 없음(운영에 남은 S1 판도 이 파일의 drop 이 지움)
    select string_agg(u.f, ', ') into v_t
      from unnest(array['public.lec_set_agree(text, text)', 'public.lec_rec_agree(text, text)', 'public.lec_rec_off(text)',
                        'public.lec_rec_guard(text, text, boolean)', 'public.lec_rec_lvl(jsonb)', 'public.lec__set_ok(text)',
                        'public.lec__rec_can(text)', 'public.lec__set_ver()', 'public.lec__rec_ver()']) as u(f)
     where to_regprocedure(u.f) is not null;
    if v_t is not null then
      raise exception '점검 실패(S1-b · 없앤 동의 함수가 남음): %', v_t;
    end if;
    select string_agg(c.relname || ' ' || u.rl, ', ') into v_t
      from pg_class c
     cross join unnest(array['anon', 'authenticated']) as u(rl)
     where c.relnamespace = 'public'::regnamespace
       and c.relname in ('lec_set', 'lec_set_prog', 'lec_set_try', 'lec_set_rec', 'lec_rec_ok')
       and (has_table_privilege(u.rl, c.oid, 'select,insert,update,delete') or not c.relrowsecurity);
    if v_t is not null then
      raise exception '점검 실패(S1 표 권한): %', v_t;
    end if;
    if exists (select 1 from pg_policies pp
                where pp.schemaname = 'public' and pp.tablename in ('lec_set', 'lec_set_prog', 'lec_set_try', 'lec_set_rec', 'lec_rec_ok')) then
      raise exception '점검 실패(S1 표 정책이 있음)';
    end if;
    -- 녹음 파일 정책은 이름이 아니라 실제 조건으로: 우리 셋 말고 lec-rec 에 닿는 anon · authenticated · public 의
    -- 읽기 · 고치기 · 지우기 · 전부 정책 0(lec__rec_open) · 이름이 같은 정책은 조건까지 맞음(듣기 · 지우기 = 관리자만)
    if to_regclass('storage.objects') is not null then
      v_t := public.lec__rec_open();
      if v_t is not null then
        raise exception '점검 실패(S1 · 녹음 파일을 다른 사람이 듣거나 고치거나 지울 수 있는 Storage 정책): %', v_t;
      end if;
      select string_agg(pp.policyname::text, ', ' order by pp.policyname) into v_t
        from pg_policies pp
       where pp.schemaname = 'storage' and pp.tablename = 'objects'
         and pp.policyname in ('lec_rec_put', 'lec_rec_read', 'lec_rec_del')
         and not public.lec__rec_pol_ok(pp.policyname, pp.cmd, pp.qual, pp.with_check);
      if v_t is not null then
        raise exception '점검 실패(S1 · 녹음 정책 조건 다름 · 듣기 · 지우기는 lec-rec + lec_set_is_admin · 올리기는 lec-rec + lec_rec_slot): %', v_t;
      end if;
    end if;
    -- 속 함수 전부(S1 의 lec__set_* · lec__rec_* 까지): anon · authenticated 가 직접 못 부름
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(S1 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;
    -- 끄개 두 줄(머리글)이 아직 듣는지(S1-b 뒤에도 · 이 점검 안에서만 하고 끝에 함께 되돌림)
    --   ① 학생 묶음 숨김: lec_set_home 권한 거둠 → anon · authenticated 가 못 부름
    revoke execute on function public.lec_set_home(text) from anon, authenticated;
    if has_function_privilege('anon', 'public.lec_set_home(text)', 'execute')
       or has_function_privilege('authenticated', 'public.lec_set_home(text)', 'execute') then
      raise exception '점검 실패(S1 끄개 · 학생 묶음 숨김이 안 들음)';
    end if;
    --   ② 녹음 올리기 막음: 올리기 정책 이름이 lec_rec_put 하나 · 지우면 lec-rec 에 올리는 정책 0
    --      (SQL 로 Storage 정책을 못 고치는 서버는 건너뜀 · 그때는 대시보드에서 lec_rec_put 을 지움)
    if to_regclass('storage.objects') is not null
       and exists (select 1 from pg_policies pp where pp.schemaname = 'storage' and pp.tablename = 'objects' and pp.policyname = 'lec_rec_put') then
      v_off := true;
      begin
        execute 'drop policy if exists lec_rec_put on storage.objects';
      exception when others then
        v_off := false;
      end;
      --      남은 올리기 허용 정책: anon · authenticated · public 에게 열린 올리기 · 전부 가운데 버킷 조건이 없거나 lec-rec 를 담은 것(lec__rec_open 과 같은 꼴)
      if v_off then
        select string_agg(pp.policyname::text, ', ' order by pp.policyname) into v_t
          from pg_policies pp
         where pp.schemaname = 'storage' and pp.tablename = 'objects'
           and pp.permissive = 'PERMISSIVE'
           and pp.roles && array['anon', 'authenticated', 'public']::name[]
           and pp.cmd in ('INSERT', 'ALL')
           and (coalesce(pp.with_check, pp.qual) is null
                or coalesce(pp.with_check, pp.qual) not like '%bucket_id%'
                or coalesce(pp.with_check, pp.qual) like '%lec-rec%');
        if v_t is not null then
          raise exception '점검 실패(S1 끄개 · lec_rec_put 을 지워도 lec-rec 에 올릴 수 있는 정책이 남음): %', v_t;
        end if;
      end if;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
  -- 점검이 파일을 올려 «냄»의 파일 확인을 실제로 재지 못했으면(storage 표는 있으나 넣기 실패) 맨 아래 표 «녹음 저장 곳»에 «파일 확인 못 함»
  -- (되돌린 점검 안에서 set_config 하면 함께 사라지므로 점검 덩어리 밖에서 · 이 트랜잭션 안에서만)
  perform set_config('his.lec_rec_fput', case when coalesce(v_put, false) or not coalesce(v_st, false) then '' else 'no' end, true);
end
$$;

notify pgrst, 'reload schema';

select '강의실 준비 끝' as "결과",
       '점검 8/8 통과' as "점검",
       (select count(*) from public.lec__roster()) as "학생 수",
       (select count(*) from public.lec_lecture) as "강의 수",
       public.lec__pdf_store() as "PDF 저장 곳",
       public.lec__push_status() as "새 영상 알림",
       public.lec__rec_store() as "녹음 저장 곳",
       (select count(*) from public.lec_set_rec where st = 'done' and done_at < now() - interval '30 days') as "30일 지난 녹음";
