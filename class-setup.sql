-- ============================================================================
-- 히즈 강의실 · 서버 준비 (한 번만 실행 · 다시 실행해도 됩니다)
--
-- 1) supabase.com 로그인 → 히즈북스 프로젝트 → 왼쪽 «SQL Editor»
-- 2) «New query» → 이 파일 전체(Ctrl+A → Ctrl+C)를 붙여 넣고 «Run»
--    (경고 창이 뜨면 «Run this query»)
-- 3) 아래 결과 칸에 «강의실 준비 끝 · 학생 수 · 강의 수»가 나오면 끝입니다.
--    빨간 오류가 나오면 아무것도 바뀌지 않은 것입니다(통째로 되돌려짐).
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

notify pgrst, 'reload schema';

select '강의실 준비 끝' as "결과",
       (select count(*) from public.lec__roster()) as "학생 수",
       (select count(*) from public.lec_lecture) as "강의 수";
