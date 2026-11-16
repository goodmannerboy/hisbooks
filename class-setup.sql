-- ============================================================================
-- 히즈 강의실 · 서버 준비 (한 번만 실행 · 다시 실행해도 됩니다)
--
-- 1) supabase.com 로그인 → 히즈북스 프로젝트 → 왼쪽 «SQL Editor»
-- 2) «New query» → 이 파일 전체(Ctrl+A → Ctrl+C)를 붙여 넣고 «Run»
--    (경고 창이 뜨면 «Run this query»)
-- 3) 빨간 오류 없이 맨 아래 결과 칸에 «강의실 준비 끝 · 점검 4/4 통과 · 학생 수 · 강의 수» 표가 나오면 통과입니다.
--    (스스로 점검 넷은 통과하면 아무것도 안 보이고, 하나라도 틀리면 그 자리에서 빨간 오류로 멈춥니다)
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
       where (c.cid = any (lday.class_ids) or '*' = any (lday.class_ids))
         and (lday.lc is null or c.cid = any (lday.lc))
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
       where lday.lc is null or lday.lc && v_cls
       group by lday.id
    ), per as (
      select lday.id, lday.day,
             case when bool_or(a.o_att = 'in') then 'in' when bool_or(a.o_att = 'abs') then 'abs' else '' end as att,
             bool_or(a.o_mk) as mk
        from lday
        join a on a.o_day = lday.day
              and (a.o_cid = any (lday.class_ids) or '*' = any (lday.class_ids))
              and (lday.lc is null or a.o_cid = any (lday.lc))
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
        join pc on (pc.cid = any (lday.class_ids) or '*' = any (lday.class_ids))
               and (lday.lc is null or pc.cid = any (lday.lc))
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
              and (a.o_cid = any (lday.class_ids) or '*' = any (lday.class_ids))
              and (lday.lc is null or a.o_cid = any (lday.lc))
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
        join cl on cl.id = any (ro.cls) and (cl.id = any (l.class_ids) or '*' = any (l.class_ids))
               and (z.lc is null or cl.id = any (z.lc))
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
    -- 속 함수 전부(파일 맨 끝이라 C1 · C3 · C2 의 lec__ 함수를 처음 설치 때도 모두 봄 · 표 정책이 부르는 lec__is_staff 와 트리거 함수는 빼고):
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

notify pgrst, 'reload schema';

select '강의실 준비 끝' as "결과",
       '점검 4/4 통과' as "점검",
       (select count(*) from public.lec__roster()) as "학생 수",
       (select count(*) from public.lec_lecture) as "강의 수";
