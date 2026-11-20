-- ============================================================================
-- 히즈 강의실 · 서버 준비 (한 번만 실행 · 다시 실행해도 됩니다)
--
-- 1) supabase.com 로그인 → 히즈북스 프로젝트 → 왼쪽 «SQL Editor»
-- 2) «New query» → 이 파일 전체(Ctrl+A → Ctrl+C)를 붙여 넣고 «Run»
--    (경고 창이 뜨면 «Run this query»)
-- 3) 빨간 오류 없이 맨 아래 결과 칸에 «강의실 준비 끝 · 점검 14/14 통과 · 학생 수 · 강의 수 · PDF 저장 곳 · 새 영상 알림 · 녹음 저장 곳 · 30일 지난 녹음» 표가 나오면 통과입니다.
--    (스스로 점검 열은 통과하면 아무것도 안 보이고, 하나라도 틀리면 그 자리에서 빨간 오류로 멈춥니다)
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
-- 볼 학교(11-18 K1): 반 안에서 이 강의를 볼 학교 열쇠(앱 schoolKey) · 빈 목록 = 반 전체(지금과 같음 · 맨 앞 K1 속 함수 머리글)
alter table public.lec_lecture add column if not exists school_keys text[] not null default '{}';

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
-- 학생 학교 열쇠(11-18 K1 · cls 처럼 첫 화면 lec_home 이 열 때마다 맞춤 · 빈 목록 = 학교 빈칸 = 모든 강의)
alter table public.lec_key add column if not exists sch text[] not null default '{}';
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

-- ---- K1 (11-18) 강의마다 볼 학교(원장님 «썸네일로 넣어» 다음 학교 칸 · 결론안 P1 · CLAUDE.md §8 학교 칸 절)
--   같은 반 안에서 학교로 나눔: 강의 school_keys(빈 목록 = 반 전체 = 지금과 같음) · 학생 학교 열쇠 = 앱 schoolKey 와 글자 그대로(lec__skey)
--   보이는 규칙 하나(lec__sch_ok): 강의 칸이 비었거나 · 학생 학교가 빈칸이거나 · 학생 학교 열쇠가 칸 안에 있으면 보임(틀려도 «더 보이는» 쪽)
--   학생 쪽은 lec__open 대신 lec__open_s(옛 lec__open 은 그대로 둠) · 선생님 쪽 셈(덜 본 학생 · 결석 띠 · 알림 받는 사람 · 알림 수 ·
--   시험 범위 M1)도 같은 규칙 · 학생 열쇠의 sch 는 cls 처럼 첫 화면(lec_home)이 열 때마다 맞춤 · 스스로 점검은 맨 끝 K1
drop function if exists public.lec__skey(text);
drop function if exists public.lec__stu_school(jsonb);
drop function if exists public.lec__schs(jsonb);
drop function if exists public.lec__sch_of(text);
drop function if exists public.lec__sch_ok(text[], text[]);
drop function if exists public.lec__open_s(public.lec_lecture, text[], text[]);
drop function if exists public.lec__push_n_s(jsonb, text[], text[], text[]);   -- 만드는 곳은 N1 절(알림 표 뒤)
drop function if exists public.lec_push_count(text[], text[]);                 -- 만드는 곳은 N1 절(lec_push_state 뒤)

-- 학교 열쇠(앱 _schoolKey · class-api.js schoolKey 를 글자 그대로): 보통 칸만 빼고 «고등학교 → 고» 줄임 · 끝의 숫자 · 학년 · 반 떼기
--   길이는 JS 처럼 UTF-16 칸으로 셈(U+10000 넘는 글자 = 2칸 · 떼는 글자는 모두 한 칸 글자라 그 수는 그대로)
create or replace function public.lec__skey(s text) returns text
language plpgsql immutable set search_path = public as $$
declare
  x    text := replace(coalesce(s, ''), ' ', '');
  sup  integer := 0;
  n    integer;
  ch   integer;
  pv   integer;
  g    boolean := true;
  ok   boolean := false;
begin
  if x = '' then
    return '';
  end if;
  x := replace(replace(replace(replace(replace(x, '여자고등학교', '여고'), '여자중학교', '여중'),
               '고등학교', '고'), '중학교', '중'), '초등학교', '초');
  for i in 1 .. char_length(x) loop
    if ascii(substr(x, i, 1)) > 65535 then
      sup := sup + 1;
    end if;
  end loop;
  while g and char_length(x) + sup > 1 loop
    g := false;
    n := char_length(x) + sup;
    ch := ascii(right(x, 1));
    if ch between 48 and 57 or ch in (40, 41, 44, 45, 46, 47, 91, 93) then
      x := left(x, -1); g := true; continue;
    end if;
    if n > 2 and right(x, 2) = '학년' then
      x := left(x, -2); g := true; continue;
    end if;
    pv := ascii(substr(x, char_length(x) - 1, 1));
    if n > 2 and ch = ascii('년') and pv between 48 and 57 then
      x := left(x, -1); g := true; continue;
    end if;
    if n > 2 and ch = ascii('반') then
      if pv between 48 and 57 then
        x := left(x, -1); g := true; continue;
      end if;
      if n > 3 and pv between ascii('가') and ascii('하') then
        x := left(x, -2); g := true; continue;
      end if;
    end if;
  end loop;
  for i in 1 .. char_length(x) loop
    ch := ascii(substr(x, i, 1));
    if ch between ascii('가') and ascii('힣') or ch between 65 and 90 or ch between 97 and 122 then
      ok := true;
      exit;
    end if;
  end loop;
  if not ok or char_length(x) + sup < 2 then
    return '';
  end if;
  return x;
end
$$;

-- 학생의 학교 글(앱 _stuSchool): school 이 «참»이면 그것 · 아니면 intake.school · 앞뒤 빈칸 떼기(JS trim 과 같은 글자)
create or replace function public.lec__stu_school(p_stu jsonb) returns text
language sql immutable set search_path = public as $$
  select btrim(case when public.lec__truthy(p_stu -> 'school') then coalesce(p_stu ->> 'school', '')
                    when public.lec__truthy(p_stu #> '{intake,school}') then coalesce(p_stu #>> '{intake,school}', '')
                    else '' end,
               chr(9) || chr(10) || chr(11) || chr(12) || chr(13) || chr(32) || chr(160) || chr(5760) ||
               chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197) || chr(8198) || chr(8199) ||
               chr(8200) || chr(8201) || chr(8202) || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279))
$$;

-- 받은 main 묶음에서 학생마다 학교 열쇠들(lec__ros 와 같은 거름 · 같은 학생이 여러 반이면 모두 모음 · 빈 열쇠는 뺌 · 빈 목록 = 학교 빈칸)
create or replace function public.lec__schs(p_main jsonb)
returns table (skey text, sch text[])
language sql immutable set search_path = public as $$
  select st.rid || '|' || st.nname,
         coalesce(array_agg(distinct st.k) filter (where st.k <> ''), '{}')
    from (select s ->> 'id'                                    as rid,
                 public.lec__norm(s ->> 'name')                as nname,
                 public.lec__skey(public.lec__stu_school(s))   as k
            from jsonb_array_elements(case when jsonb_typeof(p_main -> 'classes') = 'array' then p_main -> 'classes' else '[]'::jsonb end) as c
           cross join lateral jsonb_array_elements(case when jsonb_typeof(c -> 'students') = 'array' then c -> 'students' else '[]'::jsonb end) as s
           where jsonb_typeof(s) = 'object'
             and coalesce(s ->> 'id', '') <> ''
             and public.lec__norm(s ->> 'name') <> ''
             and not public.lec__truthy(s -> 'withdrawn')
             and not public.lec__truthy(s -> 'pending')) st
   group by st.rid, st.nname
$$;

-- 학생 열쇠(skey) 하나의 학교 열쇠들(app_state main 을 읽음 · 명단에 없으면 빈 목록)
create or replace function public.lec__sch_of(p_sid text) returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce((select h.sch
                     from public.app_state a
                    cross join lateral public.lec__schs(a.data) h
                    where a.id = 'main' and h.skey = p_sid
                    limit 1), '{}'::text[])
$$;

-- 보이는 규칙 하나: 강의 칸이 비었거나(반 전체) · 학생 학교가 빈칸이거나 · 겹치면 보임
create or replace function public.lec__sch_ok(keys text[], sch text[]) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(cardinality(keys), 0) = 0 or coalesce(cardinality(sch), 0) = 0 or keys && sch
$$;

-- 학생이 이 강의를 볼 수 있나(lec__open + 볼 학교) · 학생 함수는 모두 이것으로
create or replace function public.lec__open_s(l public.lec_lecture, cls text[], sch text[]) returns boolean
language sql stable set search_path = public as $$
  select public.lec__open(l, cls) and public.lec__sch_ok(l.school_keys, sch)
$$;

revoke all on function public.lec__skey(text), public.lec__stu_school(jsonb), public.lec__schs(jsonb), public.lec__sch_of(text),
                       public.lec__sch_ok(text[], text[]), public.lec__open_s(public.lec_lecture, text[], text[])
  from public, anon, authenticated;

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
  insert into public.lec_key (kh, sid, rid, pin, sname, cls, sch, dev)
  values (public.lec__kh(v_key), v_skey, v_rid, v_pin, v_sname, coalesce(v_cls, '{}'), public.lec__sch_of(v_skey), left(coalesce(p_dev, ''), 40));
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
  v_sch    text[];
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
  v_sch := public.lec__sch_of(k.sid);
  update public.lec_key set sname = v_sname, cls = coalesce(v_cls, '{}'), sch = v_sch, last_at = now() where kh = k.kh;
  return jsonb_build_object(
    'ok', true,
    'me', jsonb_build_object('name', v_sname),
    'consent', (select jsonb_build_object('choice', c.choice, 'ver', c.ver, 'at', c.at)
                  from public.lec_consent c where c.sid = k.sid),
    'consent_ver', public.lec__consent_ver(),
    'al_mine', exists (select 1 from public.lec_lecture l where public.lec__open_s(l, v_cls, v_sch) and l.class_ids && coalesce(v_cls, '{}')),
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
       where public.lec__open_s(l, v_cls, v_sch)
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
   where x.id = p_lecture and public.lec__open_s(x, k.cls, k.sch);
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
   where x.id = p_lecture and public.lec__open_s(x, k.cls, k.sch);
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
   where x.id = p_lecture and public.lec__open_s(x, k.cls, k.sch);
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
  insert into public.lec_key (kh, sid, rid, pin, sname, cls, sch, dev, made_by)
  values (public.lec__kh(v_key), r.skey, r.rid, '', r.sname, coalesce(r.cls, '{}'), public.lec__sch_of(r.skey), '개인 링크', v_name);
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
       sc as (select h.skey, h.sch from public.app_state a cross join lateral public.lec__schs(a.data) h where a.id = 'main'),
       cl as (select k.id, k.name from public.lec__classes() k where v_admin or k.owner = v_name),
       lec as (select l.id, l.title, l.class_ids, l.school_keys, l.created_at, coalesce(l.lesson_on, l.posted_on) as day
                 from public.lec_lecture l
                where not l.hidden
                  and coalesce(l.posted_on, v_today) <= v_today
                  and not public.lec__ended(l)
                  and coalesce(l.lesson_on, l.posted_on) between v_today - 13 and v_today),
       pr as (select lec.id as lid, lec.title, lec.day, lec.created_at as lca, cl.id as cid, cl.name as cname, lec.school_keys as sk
                from lec join cl on (cl.id = any (lec.class_ids) or '*' = any (lec.class_ids))),
       st as (select pr.lid, pr.cid, r.skey, r.sname
                from pr join ro r on pr.cid = any (r.cls)
                left join sc on sc.skey = r.skey
                left join public.lec_progress g on g.sid = r.skey and g.lecture_id = pr.lid
                left join public.lec_consent cs on cs.sid = r.skey
               where coalesce(g.pct, 0) < 90 and g.done_by is null
                 and coalesce(cs.choice, '') <> 'none'
                 and public.lec__sch_ok(pr.sk, sc.sch))
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
  v_sch   text[];
  v_cdays jsonb := '{}'::jsonb;
  v_days  date[];
  v_data  jsonb;
  v_items jsonb := '[]'::jsonb;
begin
  select r.rid, r.cls into v_rid, v_cls from public.lec__ros(p_main) r where r.skey = p_sid limit 1;
  select h.sch into v_sch from public.lec__schs(p_main) h where h.skey = p_sid limit 1;
  if v_rid is not null and coalesce(cardinality(v_cls), 0) > 0 then
    with lday as (
      select l.id, l.class_ids, u.x as day, public.lec__lcls(l.lesson_cls, u.x) as lc
        from public.lec_lecture l
       cross join lateral (select distinct v.x from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)) u
       where public.lec__open_s(l, v_cls, v_sch) and u.x between p_today - 62 and p_today
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
       where public.lec__open_s(l, v_cls, v_sch) and u.x between p_today - 62 and p_today
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
      select r.skey, r.rid, r.cls, coalesce(h.sch, '{}'::text[]) as sch
        from public.lec__ros(p_main) r left join public.lec__schs(p_main) h on h.skey = r.skey
       where r.cls && v_scope
    ), lday as (
      select l.id, l.class_ids, l.school_keys as sk, u.x as day, public.lec__lcls(l.lesson_cls, u.x) as lc
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
               and public.lec__sch_ok(lday.sk, ro.sch)
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
       where public.lec__open_s(l, k.cls, k.sch)
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
              and (cardinality(l.school_keys) = 0 or g.school_key = any (l.school_keys))
              and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                           l.posted_on) between g.exam_on - 70 and g.end_on - 1)
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       where public.lec__open_s(l, k.cls, k.sch)
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
             and (cardinality(l.school_keys) = 0 or v_school = any (l.school_keys))
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
          and (cardinality(l.school_keys) = 0 or g.school_key = any (l.school_keys))
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
  v_sch    text[];
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
  v_sch := public.lec__sch_of(k.sid);
  update public.lec_key set sname = v_sname, cls = coalesce(v_cls, '{}'), sch = v_sch, last_at = now() where kh = k.kh;
  return jsonb_build_object(
    'ok', true,
    'me', jsonb_build_object('name', v_sname),
    'consent', (select jsonb_build_object('choice', c.choice, 'ver', c.ver, 'at', c.at)
                  from public.lec_consent c where c.sid = k.sid),
    'consent_ver', public.lec__consent_ver(),
    'al_mine', exists (select 1 from public.lec_lecture l where public.lec__open_s(l, v_cls, v_sch) and l.class_ids && coalesce(v_cls, '{}')),
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
       where public.lec__open_s(l, v_cls, v_sch)
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
   where x.id = p_lecture and public.lec__open_s(x, k.cls, k.sch);
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
   where x.id = p_lecture and public.lec__open_s(x, k.cls, k.sch);
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
       where public.lec__open_s(l, k.cls, k.sch)
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
              and (cardinality(l.school_keys) = 0 or g.school_key = any (l.school_keys))
              and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                           l.posted_on) between g.exam_on - 70 and g.end_on - 1)
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       where public.lec__open_s(l, k.cls, k.sch)
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
             and (cardinality(l.school_keys) = 0 or v_school = any (l.school_keys))
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
  v_ak    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
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
  v_as    text;
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
      -- AL(11-19): 내 반을 겨눈 열린 강의(h)가 있으면 al_mine = 참(lec_push_on 의 show 와 같은 셈 · 학생 앱이 알림 답을 기다릴지)
      if (r ->> 'al_mine') is distinct from 'true' then
        raise exception '점검 실패(AL · 내 반 강의 학생 al_mine): %', coalesce(r ->> 'al_mine', '없음');
      end if;
      update public.lec_range set lecture_ids = '{}' where id = v_rh;
      r := public.lec_home(v_hk);
      if (select e ->> 'ended' from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_h::text) is distinct from 'true'
         or (select e ->> 'until' from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_h::text)
            is distinct from to_char(v_today - 1, 'YYYY-MM-DD') then
        raise exception '점검 실패(M2 · 첫 화면 뺀 뒤): %', left(r::text, 400);
      end if;
    end if;

    -- AL(11-19): «전체('*')» 강의만 있는 학생(반을 겨눈 강의가 하나도 없는 실제 학생 · 없으면 건너뜀) →
    --   «전체» 강의 g 는 보이지만 al_mine = 거짓(학생 앱이 알림 답을 기다리지 않음)
    select t.skey into v_as
      from public.lec__roster() t
     where coalesce(t.skey, '') <> '' and coalesce(cardinality(t.cls), 0) > 0
       and not exists (select 1 from public.lec_lecture l where l.class_ids && t.cls)
     order by t.skey
     limit 1;
    if v_as is not null then
      insert into public.lec_key (kh, sid, rid, pin, sname, cls)
      values (public.lec__kh(v_ak), v_as, '', '', '점검', '{}');
      r := public.lec_home(v_ak);
      if (r ->> 'ok') is distinct from 'true' or (r ->> 'al_mine') is distinct from 'false'
         or not exists (select 1 from jsonb_array_elements(r -> 'lectures') e where e ->> 'id' = v_g::text) then
        raise exception '점검 실패(AL · 전체 강의만 있는 학생 al_mine): % · %', coalesce(r ->> 'ok', '없음'), coalesce(r ->> 'al_mine', '없음');
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
       where public.lec__open_s(l.*, k.cls, k.sch)
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
  v_wide   boolean;
  v_skip   text[];
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
    -- 볼 학교를 넓힘(11-18 K1 · 빈 목록 = 반 전체): 이미 보낸 반도 다시 줄에 넣음 · 이미 받은 폰(lec_push_log)과 이미 연 학생은
    --   lec__push_take 가 빼므로 새로 든 학생에게만 감 · 좁히면 그대로
    v_wide := cardinality(old.school_keys) > 0
              and (cardinality(new.school_keys) = 0 or not (new.school_keys <@ old.school_keys));
    v_skip := case when v_wide then '{}'::text[] else v_done end;

    -- 기다리는 줄: 반 = 지금 반 - 이미 보낸 반 · 때를 다시 셈 · 숨김 = hold · 반 없음 = gone
    if v_has and qq.status = 'wait' then
      v_tg := public.lec__push_minus(v_eff, v_skip);
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
        update public.lec_push_queue set cls = public.lec__push_minus(v_eff, v_skip), updated_at = now()
         where lecture_id = new.id;
      end if;
      return null;
    end if;

    -- 보이는 채 고침: 숨김을 풀었으면 아직 안 보낸 반 모두 · 아니면 새로 더한 반만
    if (v_has and qq.status = 'hold') or old.hidden or v_wide then
      v_tg := public.lec__push_minus(v_eff, v_skip);
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
create trigger lec_lecture_push after insert or update of hidden, class_ids, posted_on, until, school_keys on public.lec_lecture
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
            and exists (select 1 from public.lec_lecture l where public.lec__open_s(l, k.cls, k.sch) and l.class_ids && k.cls),
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

-- 알림을 켠 학생 수 · 강의의 볼 학교까지(11-18 K1 · lec_push_state 가 씀 · lec__push_n 은 그대로 둠 · 같은 모양 drop 은 맨 앞 K1)
create or replace function public.lec__push_n_s(p_main jsonb, p_cls text[], p_names text[], p_sk text[])
returns integer
language sql stable security definer set search_path = public as $$
  select count(distinct r.skey)::integer
    from public.lec__ros(p_main) r
    left join public.lec__schs(p_main) h on h.skey = r.skey
    join public.lec_key k on k.sid = r.skey
    join public.lec_push_sub s on s.kh = k.kh
   where r.cls && coalesce(p_cls, '{}'::text[])
     and (p_names is null or public.lec__norm(r.sname) = any (p_names))
     and public.lec__sch_ok(p_sk, h.sch)
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
    'n', public.lec__push_n_s(coalesce(v_main, '{}'::jsonb), v_tg,
                              case when cf.mode = 'test' then public.lec__push_names(cf.test_names) end, ll.school_keys),
    'again', cardinality(v_left) > 0 and ll.posted_on >= v_today - 3 and not public.lec__ended(ll));
end
$$;

-- 선생님(11-18 K1): 새 강의 서랍 저장 옆 «보이는 학생 N명 · 알림 N명» 의 알림 수 · 저장 전 고른 반 · 볼 학교로
--   lec_push_state 의 n 과 같은 셈(알림을 켠 학생 · 시험 중이면 시험 학생만) · 꺼짐 · 시험 중 관리자 아님 = show 거짓(서랍은 알림 수를 안 씀)
create or replace function public.lec_push_count(p_cls text[], p_sk text[])
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  st      record;
  cf      public.lec_push_cfg;
  v_main  jsonb;
begin
  select * into st from public.lec__staff() limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select * into cf from public.lec_push_cfg where id = 1;
  if not found or cf.mode = 'off' or (cf.mode = 'test' and not st.admin) then
    return jsonb_build_object('ok', true, 'mode', coalesce(cf.mode, 'off'), 'show', false);
  end if;
  select a.data into v_main from public.app_state a where a.id = 'main';
  return jsonb_build_object(
    'ok', true, 'mode', cf.mode, 'show', true,
    'n', public.lec__push_n_s(coalesce(v_main, '{}'::jsonb), public.lec__push_cls(p_cls),
                              case when cf.mode = 'test' then public.lec__push_names(cf.test_names) end,
                              coalesce(p_sk, '{}'::text[])));
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
        left join public.lec__schs(p_main) h on h.skey = r.skey
       where r.cls && v_cls
         and public.lec__sch_ok(ll.school_keys, h.sch)
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
                       public.lec__push_n(jsonb, text[], text[]), public.lec__push_n_s(jsonb, text[], text[], text[]),
                       public.lec__push_take(jsonb, timestamptz),
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
revoke all on function public.lec_push_count(text[], text[]) from public, anon;
grant execute on function public.lec_push_count(text[], text[]) to authenticated;
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

-- test_n(11-18 원장님 «선생님이 50개와 같이 설정하면 그중으로 50개가 랜덤으로»): 시험 문항 수 · 비면 전부(예전 그대로)
--   어휘 시험 · 문법 연습만 씀 · 문항 수 이상이면 전부와 같음(lec__set_tq) · 바꾸는 곳은 관리자 lec_set_testn 하나
alter table public.lec_set add column if not exists test_n integer;
alter table public.lec_set drop constraint if exists lec_set_testn_ok;
alter table public.lec_set add constraint lec_set_testn_ok check (test_n is null or test_n between 1 and 300);
-- drawn: 이 판을 test_n 으로 뽑아서 냈는지 · 연 판은 설정을 바꿔도 만든 그대로 이어 감(통과 · 점수 셈도 이 칸을 봄)
alter table public.lec_set_try add column if not exists drawn boolean not null default false;

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
drop function if exists public.lec__set_tq(integer, integer);
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
drop function if exists public.lec_set_testn(uuid, integer);
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

-- 한 번에 낼 문항 수(test_n · 11-18): 1 ~ 문항 수-1 일 때만 그 수 · 비었거나 문항 수 이상이면 null(= 전부 · 예전 그대로)
create or replace function public.lec__set_tq(p_n integer, p_tn integer) returns integer
language sql immutable set search_path = public as $$
  select case when p_tn between 1 and coalesce(p_n, 0) - 1 then p_tn end
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
--   시험 문항 수(test_n · 11-18 · lec__set_tq 가 null 아닐 때): 전체에서 그 수만큼 새로 뽑음(다시 볼 때도 새로 · 다시 보기 규칙 안 씀)
--     단어는 뽑은 차례 홀수 c · 짝수 w(첫 시도와 같은 번갈음) · 문법은 보기 모양대로 · null 이면 위 그대로(limit null = 전부)
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
  v_tq  integer;
begin
  v_tq := public.lec__set_tq(s.n, s.test_n);
  if s.kind = 'gram' then
    for v_e in select u.e from jsonb_array_elements(s.items) as u(e) order by random() limit v_tq loop
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
    select x.e, case when v_tq is null then x.f when x.r % 2 = 1 then 'c' else 'w' end as f from (
      select u.e,
             case when coalesce(p_retake, false) and not ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[]))) then 'w'
                  when u.o % 2 = 1 then 'c' else 'w' end as f,
             coalesce(p_retake, false) and ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[]))) as kn,
             row_number() over (partition by coalesce(p_retake, false) and ((u.e ->> 'k') = any (coalesce(p_kn, '{}'::text[])))
                                order by random()) as rk,
             row_number() over (order by random()) as r
        from jsonb_array_elements(s.items) with ordinality as u(e, o)) x
     where case when v_tq is null then not x.kn or x.rk <= v_wr else x.r <= v_tq end
     order by case when v_tq is null then null else x.r end, random()
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
  -- 뽑아서 낸 판(drawn · test_n)은 이 판 문항 수가 전체 · 통과 수도 그 수로(다시 보기 = 새로 뽑은 판)
  v_tot := case when t.drawn then t.n else coalesce(s.n, t.n) end;
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
                            'ever', t.n - t.sc, 'f1', p.f1, 'next', v_next)
         || case when t.drawn then jsonb_build_object('draw', true, 'all', coalesce(s.n, t.n)) else '{}'::jsonb end;
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
  -- 시험 문항 수(test_n · 11-18)를 정한 단어 · 문법 세트만 test_n(한 번에 낼 수)을 더 주고 통과 수도 그 수로(정하지 않은 세트는 예전 그대로)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', xs.id, 'kind', xs.kind, 'title', xs.title, 'n', xs.n,
           'need', public.lec__set_need(coalesce(case when xs.kind in ('voc', 'gram') then public.lec__set_tq(xs.n, xs.test_n) end, xs.n)),
           'on', xs.posted_on, 'pick', cardinality(xs.pick),
           'me', public.lec__set_me(xs, k.sid, v_day))
           || case when xs.kind in ('voc', 'gram') and public.lec__set_tq(xs.n, xs.test_n) is not null
                   then jsonb_build_object('test_n', public.lec__set_tq(xs.n, xs.test_n)) else '{}'::jsonb end
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
  v_tq  integer;
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
  v_tq := public.lec__set_tq(s.n, s.test_n);   -- 시험 문항 수(11-18 · null = 전부 · 예전 그대로)
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
    -- 고쳐서 남은 문항을 이미 다 맞혔으면 바로 통과(시험 문항 수를 정한 세트는 안 함 · 뽑은 판을 쳐야 통과)
    if s.kind = 'voc' and v_tq is null and p.tn > 0 and v_kn >= public.lec__set_need(s.n) then
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
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs, ans, drawn)
    values (k.sid, s.id, case when s.kind = 'voc' then 'test' else 'drill' end, v_day, jsonb_array_length(v_qs), v_qs,
            (select jsonb_agg(null::jsonb) from generate_series(1, jsonb_array_length(v_qs))), v_tq is not null)
    returning * into t;
    update public.lec_set_prog xp set tn = xp.tn + 1, last_at = now() where xp.sid = k.sid and xp.set_id = s.id
    returning * into p;
  end if;
  -- 뽑아서 낸 판(drawn)은 이 판 문항 수가 전체 · draw · all(세트 문항 수)을 더 줌(연 판은 만든 그대로 이어 감)
  return public.lec__set_view(t, jsonb_build_object(
           'set', s.id, 'title', s.title, 'total', case when t.drawn then t.n else s.n end,
           'need', public.lec__set_need(case when t.drawn then t.n else s.n end),
           'kn', case when s.kind = 'voc' then v_kn else 0 end, 'round', p.tn)
         || case when t.drawn then jsonb_build_object('draw', true, 'all', s.n) else '{}'::jsonb end);
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
    -- 뽑아서 낸 판(drawn · test_n)은 단어도 이 판 첫 답 맞힌 수로 셈(누적 kn 은 위에서 그대로 쌓기만)
    update public.lec_set_prog xp
       set f1 = coalesce(xp.f1, (t.sc * 100) / t.n),
           last_sc = t.sc,
           best = greatest(xp.best, case when t.kind = 'test' and not t.drawn then (v_kn * 100) / greatest(s.n, 1)
                                         else (t.sc * 100) / t.n end),
           pass_at = case when xp.pass_at is null
                               and (case when t.kind = 'test' and not t.drawn then v_kn >= public.lec__set_need(s.n)
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
           'test_n', xs.test_n,
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
           'test_n', s.test_n, 'made_by', s.made_by, 'created_at', s.created_at, 'updated_at', s.updated_at));
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

-- 선생님(관리자): 시험 문항 수(test_n · 11-18 · 단어 · 문법만 · null = 전부 · 문항 수 이상도 받아 둠 = 전부와 같음)
--   새로 여는 판부터 씀(연 판은 만든 그대로) · 세트 고치기(lec_set_put)는 이 칸을 안 건드림
create or replace function public.lec_set_testn(p_set uuid, p_n integer)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_kind text;
  v_tn   integer;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  if p_n is not null and (p_n < 1 or p_n > 300) then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  select xs.kind into v_kind from public.lec_set xs where xs.id = p_set for update;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if v_kind = 'gu' then
    return jsonb_build_object('ok', false, 'err', 'kind');
  end if;
  update public.lec_set xs set test_n = p_n, updated_at = now() where xs.id = p_set
  returning xs.test_n into v_tn;
  return jsonb_build_object('ok', true, 'test_n', v_tn);
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
                                                      'test_n', s.test_n,
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
  public.lec__set_busy(text, uuid), public.lec__rec_exp(public.lec_set_rec), public.lec__rec_has(text),
  public.lec__set_tq(integer, integer)
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
  public.lec_rec_expired(), public.lec_rec_gone(uuid[]), public.lec_set_testn(uuid, integer)
  from public, anon;
grant execute on function public.lec_set_is_admin(), public.lec_set_list_staff(), public.lec_set_get(uuid),
  public.lec_set_put(uuid, text, text, text[], date, jsonb, integer[]), public.lec_set_hide(uuid, boolean), public.lec_set_del(uuid),
  public.lec_set_staff(uuid), public.lec_set_wrong_staff(text), public.lec_rec_mark(uuid, text, integer),
  public.lec_rec_expired(), public.lec_rec_gone(uuid[]), public.lec_set_testn(uuid, integer)
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
  v_c3    text;
  v_kf    text;
  v_tn    uuid;
  v_gtn   uuid;
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
        (300::integer, null::integer, null::integer),
        (300::integer, 50::integer, 50::integer),
        (300::integer, 299::integer, 299::integer),
        (300::integer, 300::integer, null::integer),
        (300::integer, 301::integer, null::integer),
        (50::integer, 50::integer, null::integer),
        (40::integer, 50::integer, null::integer),
        (10::integer, 4::integer, 4::integer),
        (10::integer, 9::integer, 9::integer),
        (10::integer, 10::integer, null::integer),
        (10::integer, 0::integer, null::integer),
        (10::integer, -1::integer, null::integer),
        (2::integer, 1::integer, 1::integer),
        (1::integer, 1::integer, null::integer),
        (0::integer, 1::integer, null::integer),
        (null::integer, 5::integer, null::integer)
      ) as x(a, b, c) loop
      if public.lec__set_tq(v_case.a, v_case.b) is distinct from v_case.c then raise exception '점검 실패(S1 판정 tq % %)', v_case.a, v_case.b; end if;
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
         or (public.lec_rec_gone('{}'::uuid[]) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_testn(gen_random_uuid(), 5) ->> 'err') is distinct from 'forbidden' then
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

    -- 7-2) 시험 문항 수(test_n · 11-18): 단어 10 가운데 4 · 문법 3 가운데 2 를 새로 뽑아 냄 · 통과 = 이 판 첫 답 맞힌 수가 90%(4 → 4 · 2 → 2)
    --      정하기 전에 연 판은 그대로 이어 감 · 다 맞힌 것 같아도(kn) 바로 통과 안 함 · 문항 수 이상 = 전부 · 고치기(lec_set_put)는 test_n 을 안 건드림
    --      (학생 바 · 반 셋째는 이 점검만 씀 · 위 학생 · 세트 수에 안 닿음)
    v_c3 := 'selftest-s1-' || v_ks || '-c';
    v_kf := 'selftest' || v_ks || 's1f';
    insert into public.lec_key (kh, sid, rid, pin, sname, cls) values
      (public.lec__kh(v_kf), 'selftest-s1f|점검바', 'selftest-s1f', '', '점검바', array[v_c3]);
    insert into public.lec_consent (sid, choice, ver) values ('selftest-s1f|점검바', 'agree', public.lec__consent_ver());
    r := public.lec_set_put(null, 'voc', '점검 뽑기', array[v_c3], null, '[
      {"n":"1","w":"apple","m":"사과"},{"n":"2","w":"bread","m":"빵"},{"n":"3","w":"chair","m":"의자"},
      {"n":"4","w":"dance","m":"춤추다"},{"n":"5","w":"eagle","m":"독수리"},{"n":"6","w":"fresh","m":"신선한"},
      {"n":"7","w":"green","m":"초록색"},{"n":"8","w":"house","m":"집"},{"n":"9","w":"juice","m":"주스"},
      {"n":"10","w":"knife","m":"칼"}]'::jsonb, null);
    v_tn := (r ->> 'id')::uuid;
    r := public.lec_set_put(null, 'gram', '점검 문법 뽑기', array[v_c3], null, '[
      {"s":"She (go / goes) to school.","a":"goes","x":"주어가 3인칭 단수예요.","p":"수일치"},
      {"s":"He [play] soccer yesterday.","a":"played","x":"어제 = 과거","p":"시제"},
      {"s":"They (is / are) happy.","a":"are","x":"주어가 여럿이에요.","p":"수일치"}]'::jsonb, null);
    v_gtn := (r ->> 'id')::uuid;
    if v_tn is null or v_gtn is null
       or (public.lec_set_get(v_tn) -> 'set' -> 'test_n') is distinct from 'null'::jsonb
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_kf) -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ->> 'need') is distinct from '9'
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_kf) -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ? 'test_n') then
      raise exception '점검 실패(S1 문항 수 · 정하기 전): %', r;
    end if;
    -- 정하기 전에 연 판(10문항)
    r := public.lec_set_test(v_kf, v_tn);
    v_try := (r ->> 'try')::uuid;
    if (r ->> 'n')::integer is distinct from 10 or (r ->> 'total')::integer is distinct from 10 or (r ->> 'need')::integer is distinct from 9
       or r ? 'draw' or r ? 'all' then
      raise exception '점검 실패(S1 문항 수 · 정하기 전 판): %', r;
    end if;
    -- 정하기: 1 ~ 300 · 비우기 = 전부 · 없는 세트 · 구문 세트 = 안 됨 · 가져오기 · 목록 · 결과 표에 보임 · 세트 고치기는 그대로 둠
    if (public.lec_set_testn(v_tn, 0) ->> 'err') is distinct from 'input'
       or (public.lec_set_testn(v_tn, 301) ->> 'err') is distinct from 'input'
       or (public.lec_set_testn(gen_random_uuid(), 5) ->> 'err') is distinct from 'none'
       or (public.lec_set_testn(v_gu, 5) ->> 'err') is distinct from 'kind'
       or (public.lec_set_testn(v_tn, 4) ->> 'test_n') is distinct from '4'
       or (public.lec_set_testn(v_gtn, 2) ->> 'test_n') is distinct from '2' then
      raise exception '점검 실패(S1 문항 수 정하기)';
    end if;
    -- 정한 값 읽기는 다음 문장에서(stable 함수 · 표 읽기는 같은 문장 안에서 바뀐 값을 못 봄 · 11-19 운영 시험 실행에서 걸림)
    if (public.lec_set_get(v_tn) -> 'set' ->> 'test_n') is distinct from '4'
       or (public.lec_set_staff(v_tn) -> 'set' ->> 'test_n') is distinct from '4'
       or ((select u.e from jsonb_array_elements(public.lec_set_list_staff() -> 'items') as u(e) where u.e ->> 'id' = v_tn::text) ->> 'test_n') is distinct from '4' then
      raise exception '점검 실패(S1 문항 수 · 정한 값 보임)';
    end if;
    r := public.lec_set_put(v_gtn, 'gram', '점검 문법 뽑기', array[v_c3], null, '[
      {"s":"She (go / goes) to school.","a":"goes","x":"주어가 3인칭 단수예요.","p":"수일치"},
      {"s":"He [play] soccer yesterday.","a":"played","x":"어제 = 과거","p":"시제"},
      {"s":"They (is / are) happy.","a":"are","x":"주어가 여럿이에요.","p":"수일치"}]'::jsonb, null);
    if not coalesce((r ->> 'ok')::boolean, false) or (public.lec_set_get(v_gtn) -> 'set' ->> 'test_n') is distinct from '2' then
      raise exception '점검 실패(S1 문항 수 · 세트 고치기가 지움): %', r;
    end if;
    r := public.lec_set_home(v_kf);
    if ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ->> 'test_n') is distinct from '4'
       or ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ->> 'need') is distinct from '4'
       or ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ->> 'n') is distinct from '10'
       or ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_gtn::text) ->> 'test_n') is distinct from '2'
       or ((select u.e from jsonb_array_elements(r -> 'sets') as u(e) where u.e ->> 'id' = v_gtn::text) ->> 'need') is distinct from '2' then
      raise exception '점검 실패(S1 문항 수 · 목록): %', r;
    end if;
    -- 연 판은 만든 그대로(10문항 · 통과 9 · kn 셈)
    r := public.lec_set_test(v_kf, v_tn);
    if (r ->> 'try')::uuid is distinct from v_try or (r ->> 'n')::integer is distinct from 10 or (r ->> 'total')::integer is distinct from 10
       or (r ->> 'need')::integer is distinct from 9 or r ? 'draw' then
      raise exception '점검 실패(S1 문항 수 · 연 판은 그대로): %', r;
    end if;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    for i in 0 .. 9 loop
      r := public.lec_set_ans(v_kf, v_try, i, case when i < 5 then v_q -> i ->> 'a' else 'zzz' end);
    end loop;
    if (r -> 'end' ->> 'sc')::integer is distinct from 5 or (r -> 'end' ->> 'total')::integer is distinct from 10
       or (r -> 'end' ->> 'need')::integer is distinct from 9 or (r -> 'end' ->> 'kn')::integer is distinct from 5
       or (r -> 'end' ->> 'pass')::boolean or (r -> 'end' ->> 'next') is distinct from 'retake' or (r -> 'end') ? 'draw'
       or (select xp.best from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn) is distinct from 50 then
      raise exception '점검 실패(S1 문항 수 · 연 판 끝): %', r;
    end if;
    -- 다 맞힌 것 같아도(kn 10 ≥ 9) 바로 통과 안 함 · 전체 10 에서 새로 4 개(다시 보기 규칙이면 0 개) · 고르기 · 쓰기 번갈아
    update public.lec_set_prog xp set kn = array['k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8', 'k9', 'k10']
     where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn;
    r := public.lec_set_test(v_kf, v_tn);
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if not coalesce((r ->> 'ok')::boolean, false) or (r ->> 'n')::integer is distinct from 4 or (r ->> 'total')::integer is distinct from 4
       or (r ->> 'need')::integer is distinct from 4 or (r ->> 'draw')::boolean is distinct from true or (r ->> 'all')::integer is distinct from 10
       or (r ->> 'round')::integer is distinct from 2 or (r ->> 'kn')::integer is distinct from 10
       or (select xt.drawn from public.lec_set_try xt where xt.id = v_try) is distinct from true
       or (select count(distinct u.e ->> 'k') from jsonb_array_elements(v_q) as u(e)) <> 4
       or exists (select 1 from jsonb_array_elements(v_q) with ordinality as u(e, o) where (u.e ->> 'f' = 'c') is distinct from (u.o % 2 = 1))
       or (select count(*) from jsonb_array_elements(r -> 'q') as u(e)
            where case when u.e ->> 'f' = 'c' then jsonb_array_length(u.e -> 'o') = 4 else false end) <> 2
       or exists (select 1 from jsonb_array_elements(r -> 'q') as u(e) where u.e ? 'a' or u.e ? 'k' or u.e ? 'x') then
      raise exception '점검 실패(S1 문항 수 · 뽑은 판): %', r;
    end if;
    -- 첫 답 셋 맞힘(3 < 4) = 통과 아님(kn 은 9 로 쌓임 · 예전 셈이면 통과)
    for i in 0 .. 3 loop
      r := public.lec_set_ans(v_kf, v_try, i, case when i = 0 then 'zzz' else v_q -> i ->> 'a' end);
    end loop;
    if (r -> 'end' ->> 'sc')::integer is distinct from 3 or (r -> 'end' ->> 'n')::integer is distinct from 4
       or (r -> 'end' ->> 'total')::integer is distinct from 4 or (r -> 'end' ->> 'need')::integer is distinct from 4
       or (r -> 'end' ->> 'pass')::boolean or (r -> 'end' ->> 'next') is distinct from 'retake'
       or (r -> 'end' ->> 'draw')::boolean is distinct from true or (r -> 'end' ->> 'all')::integer is distinct from 10
       or (r -> 'end' ->> 'kn')::integer is distinct from 9 or (r -> 'end' ->> 'ever')::integer is distinct from 1
       or (select xp.best from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn) is distinct from 75
       or (select xp.f1 from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn) is distinct from 50
       or (select xp.pass_at from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn) is not null then
      raise exception '점검 실패(S1 문항 수 · 뽑은 판 끝): %', r;
    end if;
    -- 다시(새로 뽑은 4) · 다 맞힘 = 통과 · 통과 뒤 없음
    r := public.lec_set_test(v_kf, v_tn);
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if (r ->> 'n')::integer is distinct from 4 or (r ->> 'round')::integer is distinct from 3 or (r ->> 'draw')::boolean is distinct from true then
      raise exception '점검 실패(S1 문항 수 · 다시 뽑기): %', r;
    end if;
    for i in 0 .. 3 loop
      r := public.lec_set_ans(v_kf, v_try, i, v_q -> i ->> 'a');
    end loop;
    if (r -> 'end' ->> 'pass')::boolean is distinct from true or (r -> 'end' ->> 'next') is distinct from 'pass'
       or (r -> 'end' ->> 'sc')::integer is distinct from 4
       or (public.lec_set_test(v_kf, v_tn) ->> 'err') is distinct from 'pass'
       or (select xp.best from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn) is distinct from 100
       or (select xp.tn from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_tn) is distinct from 3 then
      raise exception '점검 실패(S1 문항 수 · 통과): %', r;
    end if;
    -- 문항 수 이상 = 전부(목록에 test_n 안 감 · 통과 수 9) · 비우기
    if (public.lec_set_testn(v_tn, 10) ->> 'test_n') is distinct from '10' then
      raise exception '점검 실패(S1 문항 수 · 문항 수 이상 정하기)';
    end if;
    if ((select u.e from jsonb_array_elements(public.lec_set_home(v_kf) -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ? 'test_n')
       or ((select u.e from jsonb_array_elements(public.lec_set_home(v_kf) -> 'sets') as u(e) where u.e ->> 'id' = v_tn::text) ->> 'need') is distinct from '9' then
      raise exception '점검 실패(S1 문항 수 · 문항 수 이상 = 전부)';
    end if;
    if (public.lec_set_testn(v_tn, null) -> 'test_n') is distinct from 'null'::jsonb then
      raise exception '점검 실패(S1 문항 수 · 비우기)';
    end if;
    if (select xs.test_n from public.lec_set xs where xs.id = v_tn) is not null then
      raise exception '점검 실패(S1 문항 수 · 비운 값)';
    end if;
    -- 문법 드릴: 3 가운데 2 · 보기 꼴 그대로 · 다 맞힘 = 통과
    r := public.lec_set_test(v_kf, v_gtn);
    v_try := (r ->> 'try')::uuid;
    select xt.qs into v_q from public.lec_set_try xt where xt.id = v_try;
    if (r ->> 'kind') is distinct from 'drill' or (r ->> 'n')::integer is distinct from 2 or (r ->> 'total')::integer is distinct from 2
       or (r ->> 'need')::integer is distinct from 2 or (r ->> 'draw')::boolean is distinct from true or (r ->> 'all')::integer is distinct from 3
       or (select count(distinct u.e ->> 'k') from jsonb_array_elements(v_q) as u(e)) <> 2
       or exists (select 1 from jsonb_array_elements(v_q) as u(e)
                   where (u.e ->> 'f') is distinct from (case when strpos(u.e ->> 'p', '[') > 0 then 'r' else 'c' end)) then
      raise exception '점검 실패(S1 문항 수 · 문법 뽑은 판): %', r;
    end if;
    for i in 0 .. 1 loop
      r := public.lec_set_ans(v_kf, v_try, i, v_q -> i ->> 'a');
    end loop;
    if (r -> 'end' ->> 'pass')::boolean is distinct from true or (r -> 'end' ->> 'next') is distinct from 'pass'
       or (r -> 'end' ->> 'total')::integer is distinct from 2 or (r -> 'end' ->> 'need')::integer is distinct from 2
       or (r -> 'end' ->> 'draw')::boolean is distinct from true
       or (select xp.best from public.lec_set_prog xp where xp.sid = 'selftest-s1f|점검바' and xp.set_id = v_gtn) is distinct from 100 then
      raise exception '점검 실패(S1 문항 수 · 문법 통과): %', r;
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
                        'public.lec_rec_expired()', 'public.lec_rec_gone(uuid[])', 'public.lec_set_testn(uuid, integer)']) as u(f)
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

-- ---------------------------------------------------------------- K1 (11-18) 강의마다 볼 학교 · 아홉째 스스로 점검
-- 칸 · 함수는 제자리에서 고침(맨 앞 «K1» 속 함수 · 학생 함수 · 선생님 셈 · 알림 · 시험 범위 M1) · 이 절은 스스로 점검 하나뿐
--   학교 열쇠 표의 답 = class-api.js schoolKey 를 Chromium 에서 부른 답(JS 길이 = UTF-16 칸 · U+10000 넘는 글자 줄 포함)
--   가짜 main(대동고 · 영신고 · 학교 빈칸 · 두 반에 다른 학교로 적힌 학생 · 퇴원) · 학생 함수(질문 목록) · 알림(받는 사람 · 켠 학생 수 ·
--   학교를 넓히면 새로 든 학생에게만 · 좁히면 그대로) · 끝에 모두 되돌림
do $$
declare
  r       jsonb;
  v_t     text;
  v_n     integer;
  v_main  jsonb;
  v_c     text := 'c-selftest-k1' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_ka    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_kb    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_kc    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_ep    text := 'https://fcm.googleapis.com/fcm/send/selftest-k1-' || replace(gen_random_uuid()::text, '-', '');
  v_sa    bigint;
  v_sb    bigint;
  v_sc    bigint;
  v_l0    uuid;
  v_l1    uuid;
  v_row   public.lec_push_queue;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_x     timestamptz;
begin
  begin
    -- 1) 학교 열쇠 = 앱 schoolKey 와 같은 답
    select string_agg(format('%s → %s(앱 %s)', t.a, public.lec__skey(t.a), t.b), ' · ') into v_t
      from (values
        ('대동고등학교', '대동고'),
        ('포항대동고등학교 2학년', '포항대동고'),
        ('포항 영신고 1-3', '포항영신고'),
        ('영신고2학년3반', '영신고'),
        ('한빛여자고등학교', '한빛여고'),
        ('한빛여자중학교 3학년', '한빛여중'),
        ('포항중앙고 가반', '포항중앙고'),
        ('중앙고가반', '중앙고'),
        ('포항고', '포항고'),
        ('항도중학교', '항도중'),
        ('대도초등학교 5학년', '대도초'),
        ('세명고(1)', '세명고'),
        ('동지고[2]', '동지고'),
        ('동지여고 1.', '동지여고'),
        ('A고', 'A고'),
        ('ab', 'ab'),
        ('a', ''),
        ('1학년', ''),
        ('12', ''),
        ('', ''),
        (' ', ''),
        ('  대 동 고  ', '대동고'),
        ('고1', ''),
        ('포항제철고3년', '포항제철고'),
        ('가반', '가반'),
        ('대동고 2-1반', '대동고'),
        ('포항여자고등학교', '포항여고'),
        ('중앙고/2', '중앙고'),
        ('중앙고,3', '중앙고'),
        ('대동고' || chr(12288) || '1', '대동고' || chr(12288)),
        (chr(128512) || '반', chr(128512) || '반'),
        (chr(128512) || '1', ''),
        ('a' || chr(128512), 'a' || chr(128512)),
        ('가' || chr(128512) || '반', '가' || chr(128512) || '반'),
        ('대동고2학년', '대동고'),
        ('대동고 학년', '대동고'),
        ('반', ''),
        ('1반', '1반'),
        ('대동고3-2', '대동고'),
        ('HIS고 1학년', 'HIS고')
      ) as t(a, b)
     where public.lec__skey(t.a) is distinct from t.b;
    if v_t is not null then
      raise exception '점검 실패(K1 학교 열쇠): %', v_t;
    end if;
    if public.lec__skey(null) is distinct from '' then
      raise exception '점검 실패(K1 학교 열쇠 · 빈 값)';
    end if;

    -- 2) 학생 학교 글(앱 _stuSchool): school 이 «참»이면 그것(빈칸만 있어도 intake 는 안 봄) · 아니면 intake.school · 앞뒤 빈칸 뗌
    if public.lec__stu_school(jsonb_build_object('school', ' 대동고 ')) is distinct from '대동고'
       or public.lec__stu_school(jsonb_build_object('school', '', 'intake', jsonb_build_object('school', '영신고'))) is distinct from '영신고'
       or public.lec__stu_school(jsonb_build_object('school', '   ', 'intake', jsonb_build_object('school', '영신고'))) is distinct from ''
       or public.lec__stu_school(jsonb_build_object('intake', '영신고')) is distinct from ''
       or public.lec__stu_school('{}'::jsonb) is distinct from ''
       or public.lec__stu_school(jsonb_build_object('school', chr(12288) || '중앙고' || chr(160))) is distinct from '중앙고' then
      raise exception '점검 실패(K1 학생 학교 글)';
    end if;

    -- 3) 보이는 규칙: 강의 칸 빔 · 학생 학교 빈칸 · 겹침 = 보임
    if not public.lec__sch_ok('{}', array['a']) or not public.lec__sch_ok(array['a'], '{}') or not public.lec__sch_ok(null, null)
       or not public.lec__sch_ok(array['a'], array['b', 'a']) or public.lec__sch_ok(array['a'], array['b']) then
      raise exception '점검 실패(K1 보이는 규칙)';
    end if;
    if public.lec__sch_of('selftest-k1-none|없음') is distinct from '{}'::text[] then
      raise exception '점검 실패(K1 명단에 없는 학생의 학교)';
    end if;

    -- 4) 가짜 main: 대동고(intake 만 적힌 학생 · 다른 반엔 영신고로 적힘) · 영신고 · 학교 빈칸 · 퇴원(빠짐)
    v_main := jsonb_build_object('classes', jsonb_build_array(
      jsonb_build_object('id', v_c, 'name', '점검K1', 'students', jsonb_build_array(
        jsonb_build_object('id', 'selftest-k1a', 'name', '점검가', 'school', '포항대동고등학교 1학년'),
        jsonb_build_object('id', 'selftest-k1b', 'name', '점검나', 'school', '포항영신고 1-2'),
        jsonb_build_object('id', 'selftest-k1c', 'name', '점검다', 'school', ''),
        jsonb_build_object('id', 'selftest-k1d', 'name', '점검라', 'intake', jsonb_build_object('school', '포항대동고')),
        jsonb_build_object('id', 'selftest-k1e', 'name', '점검마', 'school', '포항중앙고', 'withdrawn', true))),
      jsonb_build_object('id', v_c || 'x', 'name', '점검K1x', 'students', jsonb_build_array(
        jsonb_build_object('id', 'selftest-k1d', 'name', '점검라', 'school', '포항영신고')))));
    select string_agg(h.skey || '=' || coalesce((select string_agg(u.k, '+' order by u.k collate "C") from unnest(h.sch) as u(k)), ''),
                      ' ' order by h.skey collate "C") into v_t
      from public.lec__schs(v_main) h;
    if v_t is distinct from 'selftest-k1a|점검가=포항대동고 selftest-k1b|점검나=포항영신고 selftest-k1c|점검다= selftest-k1d|점검라=포항대동고+포항영신고'
       or (select count(*) from public.lec__schs(v_main)) <> (select count(*) from public.lec__ros(v_main)) then
      raise exception '점검 실패(K1 가짜 main 학교): %', v_t;
    end if;

    -- 5) 학생 함수: 반 전체 강의 l0 · 대동고만 강의 l1 · 열쇠 셋(대동고 · 영신고 · 학교 빈칸)
    update public.lec_push_cfg
       set mode = 'on', test_names = '{}', night_from = '01:00', morning_at = '08:00',
           vapid_pub = coalesce(vapid_pub, 'B' || repeat('A', 86)), vapid_priv = coalesce(vapid_priv, 'B' || repeat('A', 42))
     where id = 1;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-k1-l0', 'selftest000', 100, array[v_c], v_today) returning id into v_l0;
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on, school_keys)
    values ('selftest-k1-l1', 'selftest000', 100, array[v_c], v_today, array['포항대동고']) returning id into v_l1;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls, sch) values
      (public.lec__kh(v_ka), 'selftest-k1a|점검가', 'selftest-k1a', '', '점검가', array[v_c], array['포항대동고']),
      (public.lec__kh(v_kb), 'selftest-k1b|점검나', 'selftest-k1b', '', '점검나', array[v_c], array['포항영신고']),
      (public.lec__kh(v_kc), 'selftest-k1c|점검다', 'selftest-k1c', '', '점검다', array[v_c], '{}');
    r := public.lec_qna_list(v_ka, v_l1);
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(K1 대동고 학생 · 대동고 강의): %', r; end if;
    r := public.lec_qna_list(v_kb, v_l1);
    if (r ->> 'err') is distinct from 'lecture' then raise exception '점검 실패(K1 영신고 학생에게 대동고 강의가 열림): %', r; end if;
    r := public.lec_qna_list(v_kb, v_l0);
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(K1 영신고 학생 · 반 전체 강의): %', r; end if;
    r := public.lec_qna_list(v_kc, v_l1);
    if not coalesce((r ->> 'ok')::boolean, false) then raise exception '점검 실패(K1 학교 빈칸 학생 · 대동고 강의): %', r; end if;

    -- 6) 알림 켠 학생 수(폰 셋 · 넣는 길은 표에 바로)
    insert into public.lec_push_sub (kh, endpoint, p256dh, auth) values (public.lec__kh(v_ka), v_ep || '-a', 'B' || repeat('A', 86), 'B' || repeat('A', 21))
      returning id into v_sa;
    insert into public.lec_push_sub (kh, endpoint, p256dh, auth) values (public.lec__kh(v_kb), v_ep || '-b', 'B' || repeat('A', 86), 'B' || repeat('A', 21))
      returning id into v_sb;
    insert into public.lec_push_sub (kh, endpoint, p256dh, auth) values (public.lec__kh(v_kc), v_ep || '-c', 'B' || repeat('A', 86), 'B' || repeat('A', 21))
      returning id into v_sc;
    if public.lec__push_n_s(v_main, array[v_c], null, '{}') <> 3
       or public.lec__push_n_s(v_main, array[v_c], null, array['포항대동고']) <> 2
       or public.lec__push_n_s(v_main, array[v_c], null, array['포항중앙고']) <> 1
       or public.lec__push_n_s(v_main, array[v_c], array['점검나'], array['포항대동고']) <> 0 then
      raise exception '점검 실패(K1 켠 학생 수)';
    end if;

    -- 7) 받는 사람: 대동고 강의 = 대동고 · 학교 빈칸 학생만(영신고 빠짐)
    update public.lec_push_queue set status = 'gone', due_at = null where lecture_id = v_l0;
    v_x := ((v_today + 1) + time '12:00') at time zone 'Asia/Seoul';
    update public.lec_push_queue set due_at = v_x - interval '1 minute' where lecture_id = v_l1 and status = 'wait';
    select * into v_row from public.lec_push_queue where lecture_id = v_l1;
    if v_row.status is distinct from 'wait' or v_row.cls is distinct from array[v_c] then
      raise exception '점검 실패(K1 올림 = 기다림): % %', v_row.status, v_row.cls;
    end if;
    r := public.lec__push_take(v_main, v_x);
    if (select count(*) from public.lec_push_log where lecture_id = v_l1) <> 2
       or exists (select 1 from public.lec_push_log where lecture_id = v_l1 and sub_id = v_sb)
       or (select status from public.lec_push_queue where lecture_id = v_l1) is distinct from 'sent' then
      raise exception '점검 실패(K1 받는 사람): %', left(r::text, 400);
    end if;

    -- 8) 학교를 넓힘(대동고 → 대동고 · 영신고) = 다시 기다림 · 보내면 새로 든 영신고 폰에만
    update public.lec_lecture set school_keys = array['포항대동고', '포항영신고'] where id = v_l1;
    select * into v_row from public.lec_push_queue where lecture_id = v_l1;
    if v_row.status is distinct from 'wait' or v_row.cls is distinct from array[v_c] then
      raise exception '점검 실패(K1 넓힘 = 다시 기다림): % %', v_row.status, v_row.cls;
    end if;
    update public.lec_push_queue set due_at = v_x + interval '59 minutes' where lecture_id = v_l1;
    r := public.lec__push_take(v_main, v_x + interval '1 hour');
    select count(*) into v_n from jsonb_array_elements(r -> 'items') as t(x)
     where (x ->> 'sub')::bigint in (v_sa, v_sc);
    if v_n <> 0
       or (select x -> 'ids' from jsonb_array_elements(r -> 'items') as t(x) where (x ->> 'sub')::bigint = v_sb)
            is distinct from jsonb_build_array(v_l1)
       or (select count(*) from public.lec_push_log where lecture_id = v_l1) <> 3 then
      raise exception '점검 실패(K1 넓힘 · 새로 든 학생에게만): %', left(r::text, 400);
    end if;

    -- 9) 학교를 좁힘 · 그대로 저장 = 알림 줄 그대로(보냄)
    update public.lec_lecture set school_keys = array['포항대동고'] where id = v_l1;
    update public.lec_lecture set title = 'selftest-k1-l1b', class_ids = array[v_c], hidden = false, school_keys = array['포항대동고'] where id = v_l1;
    if (select status from public.lec_push_queue where lecture_id = v_l1) is distinct from 'sent' then
      raise exception '점검 실패(K1 좁힘 · 그대로 = 알림 줄 그대로)';
    end if;

    -- 10) 서랍 알림 수(선생님 함수): 로그인 없으면 막음 · 원장님은 수(진짜 명단이라 값은 안 견줌)
    perform set_config('request.jwt.claims', '', true);
    r := public.lec_push_count(array[v_c], array['포항대동고']);
    if (r ->> 'err') is distinct from 'forbidden' then raise exception '점검 실패(K1 로그인 없이 알림 수): %', r; end if;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);
    r := public.lec_push_count(array[v_c], array['포항대동고']);
    if not coalesce((r ->> 'ok')::boolean, false) or not coalesce((r ->> 'show')::boolean, false)
       or jsonb_typeof(r -> 'n') is distinct from 'number' then
      raise exception '점검 실패(K1 알림 수): %', r;
    end if;
    perform set_config('request.jwt.claims', '', true);
    if has_function_privilege('anon', 'public.lec_push_count(text[], text[])', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_push_count(text[], text[])', 'execute') then
      raise exception '점검 실패(K1 알림 수 권한)';
    end if;

    -- 11) 속 함수 전부(K1 새 속 함수 포함): anon · authenticated 가 직접 못 부름
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(K1 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- D1 (11-19) 학생 홈 시험 D-day = 히즈북스 학교 시험 일정 · 열째 스스로 점검
-- 원장님(11-19) «D-day는 시험의 범위 관리 저장하지 않아도 나오도록 하고 시험 전 20일이 아니라 히즈북스에 학교 시험 일정 저장되어서
--   켜져있으면 바로 같이 보이게 해» → 학생 홈 시험 카드가 보이는 때 = 히즈북스 _examChipRaw 와 같음(셈은 앱 class-api.js examMine)
-- 앞 절은 그대로 두고 이 절에서만 덧댐(운영에 따로 넣을 때도 이 절 글만 · CLAUDE.md §8-231):
--   1) 속 함수 lec__sched(main, pt-etc, 학생 열쇠) = 내 학교 시험 일정 칸만 골라 줌(남의 학교 칸 · 적은 사람 칸 없음)
--   2) lec_range_me 다시 정의(M2 정의를 글자 그대로 옮기고 정한 곳만 바꿈): 범위 줄을 보이기 시작한 날(show_on) 전에도 줌(시험 끝 날까지) ·
--      줄마다 show_on 을 같이 줌 · 답에 sched(내 학교 시험 일정) 더함
--      (C2 절 머리의 «학생 함수 lec_range_me 는 app_state 를 읽지 않음»은 이 절부터 «main · pt-etc 를 읽어 내 학교 일정 칸만 줌»)
--      옛 화면 + 이 서버 = 옛 화면이 D-20 넘은 줄을 스스로 숨김(화면 그대로) · 새 화면 + 옛 서버 = sched 없음(범위 카드만 · 지금과 같음)
--   3) 열째 스스로 점검(가짜 main · 가짜 열쇠 · 범위 줄 · 끝에 모두 되돌림 · app_state 는 안 바꿈)
-- 운영에 넣은 뒤 확인(SQL Editor 에서 · 바꾸는 것 없음):
--   select to_regprocedure('public.lec__sched(jsonb, jsonb, text)') is not null as "속 함수 있음";
--   select has_function_privilege('anon', 'public.lec_range_me(text)', 'execute') as "학생 부름 됨(true)",
--          has_function_privilege('anon', 'public.lec__sched(jsonb, jsonb, text)', 'execute') as "속 함수 밖에서 부름(false)";
--   select public.lec_range_me('selftest-wrong-key');   -- {"ok": false, "err": "key"}
drop function if exists public.lec__sched(jsonb, jsonb, text);

-- 내 학교 시험 일정: p_main · p_etc = app_state main · pt-etc 의 data · p_sid = 학생 열쇠(rid|맞춘 이름)
--   → {rows:[{id:'main', es, eg}, {id:'pt-etc', es, eg}], me:[{g, ig, s, is, cn}]}
--   me = main 명단에서 내가 나오는 반마다 한 줄(lec__roster 와 같은 거름) · g · ig · s · is = 학생 grade · intake.grade · school · intake.school ·
--   cn = 반 이름(모두 적힌 그대로) · rows 는 늘 두 줄(줄이 없어도 id 만)
--   es = examSchool 중 내 학교 열쇠 칸만 · eg = examSchoolG 중 «내 학교 열쇠|» 로 시작하는 칸만 · 고른 칸이 없으면 null
--   칸 값 = label · date · end · del · on · t 만(by · name 따위는 안 줌 · 빈 칸은 뺌) · 칸 값이 묶음이 아니면 null
create or replace function public.lec__sched(p_main jsonb, p_etc jsonb, p_sid text)
returns jsonb
language sql immutable set search_path = public as $$
  with me as (
    select c.ci, s.si, c.v as cls, s.v as stu
      from jsonb_array_elements(case when jsonb_typeof(p_main -> 'classes') = 'array' then p_main -> 'classes' else '[]'::jsonb end)
           with ordinality as c(v, ci)
     cross join lateral jsonb_array_elements(case when jsonb_typeof(c.v -> 'students') = 'array' then c.v -> 'students' else '[]'::jsonb end)
           with ordinality as s(v, si)
     where jsonb_typeof(s.v) = 'object'
       and coalesce(s.v ->> 'id', '') <> ''
       and public.lec__norm(s.v ->> 'name') <> ''
       and not public.lec__truthy(s.v -> 'withdrawn')
       and not public.lec__truthy(s.v -> 'pending')
       and (s.v ->> 'id') || '|' || public.lec__norm(s.v ->> 'name') = p_sid
  ),
  ks as (
    select distinct public.lec__skey(public.lec__stu_school(me.stu)) as k from me
  ),
  src (id, o, d) as (
    values ('main', 1, p_main), ('pt-etc', 2, p_etc)
  ),
  rw as (
    select src.o, jsonb_build_object('id', src.id, 'es', es.v, 'eg', eg.v) as r
      from src
     cross join lateral (
       select jsonb_object_agg(e.key, case when jsonb_typeof(e.value) = 'object' then jsonb_strip_nulls(jsonb_build_object(
                'label', e.value -> 'label', 'date', e.value -> 'date', 'end', e.value -> 'end',
                'del', e.value -> 'del', 'on', e.value -> 'on', 't', e.value -> 't')) else 'null'::jsonb end) as v
         from jsonb_each(case when jsonb_typeof(src.d -> 'examSchool') = 'object' then src.d -> 'examSchool' else '{}'::jsonb end) as e
        where e.key in (select ks.k from ks where ks.k <> '')) es
     cross join lateral (
       select jsonb_object_agg(e.key, case when jsonb_typeof(e.value) = 'object' then jsonb_strip_nulls(jsonb_build_object(
                'label', e.value -> 'label', 'date', e.value -> 'date', 'end', e.value -> 'end',
                'del', e.value -> 'del', 'on', e.value -> 'on', 't', e.value -> 't')) else 'null'::jsonb end) as v
         from jsonb_each(case when jsonb_typeof(src.d -> 'examSchoolG') = 'object' then src.d -> 'examSchoolG' else '{}'::jsonb end) as e
        where exists (select 1 from ks where ks.k <> '' and left(e.key, char_length(ks.k) + 1) = ks.k || '|')) eg
  )
  select jsonb_build_object(
    'rows', (select jsonb_agg(rw.r order by rw.o) from rw),
    'me', coalesce((select jsonb_agg(jsonb_build_object(
                             'g', me.stu -> 'grade', 'ig', me.stu #> '{intake,grade}',
                             's', me.stu -> 'school', 'is', me.stu #> '{intake,school}', 'cn', me.cls -> 'name') order by me.ci, me.si)
                      from me), '[]'::jsonb))
$$;

revoke all on function public.lec__sched(jsonb, jsonb, text) from public, anon, authenticated;

-- 내 시험 범위(M2 정의 그대로 · 보이기 시작한 날 전 줄도 시험 끝 날까지 줌 · 줄마다 show_on · 답에 sched)
create or replace function public.lec_range_me(p_key text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  k       public.lec_key;
  v_rid   text;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_items jsonb;
  v_main  jsonb;
  v_etc   jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  v_rid := coalesce(nullif(k.rid, ''), split_part(k.sid, '|', 1));
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'name', x.name, 'exam_on', x.exam_on, 'end_on', x.end_on, 'show_on', x.show_on,
           'lectures', x.lecs, 'done', x.done) order by x.exam_on, x.id), '[]'::jsonb)
    into v_items
    from (
      select g.id, g.name, g.exam_on, g.end_on, g.show_on,
             to_jsonb(array_agg(l.id order by coalesce(l.lesson_on, l.posted_on), l.created_at, l.id)) as lecs,
             count(p.lecture_id) filter (where p.done_at is not null or p.done_by is not null) as done
        from (select distinct on (r.name, r.exam_on, r.end_on) r.*
                from public.lec_range r
               where not r.off
                 and v_today <= r.end_on
                 and ((v_rid <> '' and v_rid = any (r.rids)) or k.sid = any (r.rids))
               order by r.name, r.exam_on, r.end_on, r.saved_at desc, r.id) g
        join public.lec_lecture l
          on l.id = any (g.lecture_ids)
          or (l.created_at > g.saved_at
              and not ('*' = any (l.class_ids))
              and (cardinality(l.school_keys) = 0 or g.school_key = any (l.school_keys))
              and coalesce((select max(v.x) from unnest(array_append(coalesce(l.lesson_more, '{}'::date[]), l.lesson_on)) as v(x)),
                           l.posted_on) between g.exam_on - 70 and g.end_on - 1)
        left join public.lec_progress p on p.lecture_id = l.id and p.sid = k.sid
       where public.lec__open_s(l, k.cls, k.sch)
         and not public.lec__ended_k(l.*, k)
       group by g.id, g.name, g.exam_on, g.end_on, g.show_on
    ) x;
  select a.data into v_main from public.app_state a where a.id = 'main';
  select a.data into v_etc from public.app_state a where a.id = 'pt-etc';
  return jsonb_build_object('ok', true, 'today', v_today, 'items', v_items,
                            'sched', public.lec__sched(v_main, v_etc, k.sid));
end
$$;

revoke all on function public.lec_range_me(text) from public, anon, authenticated;
grant execute on function public.lec_range_me(text) to anon, authenticated;

-- 스스로 점검(D1): 내 학교 일정만(다른 학교 칸 · 적은 사람 칸 안 줌 · 학년 예외는 내 학교 것만 · 두 줄 늘 · 퇴원 · 대기 빠짐 ·
--   같은 id 다른 이름 안 섞임) · 학생 함수(틀린 열쇠 · 보이기 시작 전 줄도 줌 + show_on · 끝난 줄 안 줌 · 답에 sched) · 권한
--   비교는 모두 «is distinct from»(빈 값이면 실패) · 점검용으로 넣은 것은 끝에 되돌려 남지 않습니다(app_state 는 읽기만)
do $$
declare
  r       jsonb;
  v_t     text;
  v_m     jsonb;
  v_e     jsonb;
  v_dk    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_sk    text := 'selftest-d1-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_cls   text := 'c-selftest-d1' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_rid   text := 'selftest-d1';
  v_sid   text := 'selftest-d1|점검';
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_a     uuid;
  v_r1    uuid;
  v_r3    uuid;
begin
  begin
    -- 1) 내 학교 일정만: 가짜 main(두 반 · 같은 id 다른 이름 · 다른 학생 · 퇴원 · 반배정 대기 · 글자뿐인 학생) · 가짜 pt-etc
    v_m := '{"classes": [
       {"id": "c-d1a", "name": "고1 A반", "students": [
         {"id": "d1-s1", "name": "점검가", "school": "포항대동고등학교", "grade": "1"},
         {"id": "d1-s1", "name": "다른이", "school": "포항영신고"},
         {"id": "d1-s2", "name": "점검가", "school": "세명고"},
         {"id": "d1-s1", "name": " 점검가 ", "withdrawn": true, "school": "포항이동고"}]},
       {"id": "c-d1b", "name": "고2 B반", "students": [
         {"id": "d1-s1", "name": "점검가", "intake": {"school": "포항중앙고", "grade": "고2"}},
         {"id": "d1-s1", "name": "점검가", "pending": true, "school": "포항제철고"},
         "d1-s1"]}],
     "examSchool": {
       "포항대동고": {"label": "2학기 기말", "date": "2026.12.01", "end": "2026.12.03", "on": true, "t": 5,
                      "by": "점검 선생님", "name": "포항대동고등학교", "memo": "점검"},
       "포항영신고": {"label": "영신 시험", "date": "2026.12.02"},
       "세명고": {"label": "세명 시험", "date": "2026.12.02"},
       "포항이동고": {"label": "퇴원 학교", "date": "2026.12.02"},
       "포항제철고": {"label": "대기 학교", "date": "2026.12.02"}},
     "examSchoolG": {
       "포항대동고|1": {"label": "1학년 시험", "date": "2026.12.04", "end": null, "by": "점검 선생님"},
       "포항대동고x|1": {"label": "다른 학교", "date": "2026.12.04"},
       "세명고|1": {"label": "세명 학년", "date": "2026.12.04"},
       "포항중앙고|2": "글자"}}'::jsonb;
    v_e := '{"examSchool": {"포항중앙고": {"label": "중앙 시험", "date": "2026.12.05", "t": 9, "by": "점검 선생님"},
                            "세명고": {"label": "세명 시험", "date": "2026.12.05"}},
             "examSchoolG": {"세명고|1": {"label": "세명 학년", "date": "2026.12.06"}}}'::jsonb;
    r := public.lec__sched(v_m, v_e, 'd1-s1|점검가');
    if (r -> 'rows') is distinct from jsonb_build_array(
         jsonb_build_object('id', 'main',
           'es', '{"포항대동고": {"label": "2학기 기말", "date": "2026.12.01", "end": "2026.12.03", "on": true, "t": 5}}'::jsonb,
           'eg', '{"포항대동고|1": {"label": "1학년 시험", "date": "2026.12.04"}, "포항중앙고|2": null}'::jsonb),
         jsonb_build_object('id', 'pt-etc',
           'es', '{"포항중앙고": {"label": "중앙 시험", "date": "2026.12.05", "t": 9}}'::jsonb,
           'eg', 'null'::jsonb)) then
      raise exception '점검 실패(D1 · 내 학교 일정 칸만): %', left(r::text, 600);
    end if;
    if (r -> 'me') is distinct from '[{"g": "1", "ig": null, "s": "포항대동고등학교", "is": null, "cn": "고1 A반"},
                                     {"g": null, "ig": "고2", "s": null, "is": "포항중앙고", "cn": "고2 B반"}]'::jsonb then
      raise exception '점검 실패(D1 · 내 반 줄(퇴원 · 대기 · 다른 이름 뺌)): %', left(r::text, 600);
    end if;
    if r::text like '%점검 선생님%' or r::text like '%"memo"%' or r::text like '%"name"%' or r::text like '%다른 학교%'
       or r::text like '%세명%' or r::text like '%영신%' or r::text like '%퇴원 학교%' or r::text like '%대기 학교%' then
      raise exception '점검 실패(D1 · 남의 칸이 나감): %', left(r::text, 600);
    end if;
    -- 같은 id 를 이름이 다른 학생이 씀 = 그 학생 것만
    r := public.lec__sched(v_m, v_e, 'd1-s1|다른이');
    if (r -> 'me') is distinct from '[{"g": null, "ig": null, "s": "포항영신고", "is": null, "cn": "고1 A반"}]'::jsonb
       or (r #> '{rows,0,es}') is distinct from '{"포항영신고": {"label": "영신 시험", "date": "2026.12.02"}}'::jsonb
       or (r #> '{rows,0,eg}') is distinct from 'null'::jsonb
       or (r #> '{rows,1,es}') is distinct from 'null'::jsonb
       or (r #> '{rows,1,eg}') is distinct from 'null'::jsonb then
      raise exception '점검 실패(D1 · 같은 id 다른 이름이 섞임): %', left(r::text, 600);
    end if;
    -- 명단에 없음 · 빈 자료 = 두 줄(id 만) · 일정 없음 · 반 줄 없음
    v_t := '{"rows": [{"id": "main", "es": null, "eg": null}, {"id": "pt-etc", "es": null, "eg": null}], "me": []}';
    if public.lec__sched(v_m, v_e, 'd1-none|없음') is distinct from v_t::jsonb
       or public.lec__sched(null, null, 'd1-s1|점검가') is distinct from v_t::jsonb
       or public.lec__sched('[]'::jsonb, '"x"'::jsonb, null) is distinct from v_t::jsonb then
      raise exception '점검 실패(D1 · 명단에 없음 · 빈 자료)';
    end if;

    -- 2) 학생 함수: 틀린 열쇠 = key · 보이기 시작 전 줄도 줌(show_on 같이) · 끝난 줄은 안 줌 · 답에 sched 두 줄
    r := public.lec_range_me(v_dk);
    if (r ->> 'err') is distinct from 'key' or (r ->> 'ok') is distinct from 'false' then
      raise exception '점검 실패(D1 · 없는 열쇠): %', r;
    end if;
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_dk), v_sid, v_rid, '1234', '점검', array[v_cls]);
    insert into public.lec_lecture (title, yt, dur, class_ids, lesson_on)
    values ('selftest-d1a', 'selftest000', 100, array[v_cls], v_today - 3) returning id into v_a;
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-1', '1', 't', '2학기 기말', v_today + 25, v_today + 26, v_today + 5, array[v_rid], array[v_a])
    returning id into v_r1;
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-2', '1', 't', '2학기 중간', v_today - 3, v_today - 1, v_today - 23, array[v_rid], array[v_a]);
    insert into public.lec_range (school_key, grade, term, name, exam_on, end_on, show_on, rids, lecture_ids)
    values (v_sk || '-3', '1', 't', '학년 시험', v_today, v_today, v_today - 20, array[v_sid], array[v_a])
    returning id into v_r3;
    r := public.lec_range_me(v_dk);
    if (r ->> 'ok') is distinct from 'true'
       or coalesce(jsonb_array_length(case when jsonb_typeof(r -> 'items') = 'array' then r -> 'items' end), -1) is distinct from 2
       or (r #>> '{items,0,id}') is distinct from v_r3::text or (r #>> '{items,1,id}') is distinct from v_r1::text
       or (r #>> '{items,0,show_on}') is distinct from (v_today - 20)::text
       or (r #>> '{items,1,show_on}') is distinct from (v_today + 5)::text
       or (r #>> '{items,1,exam_on}') is distinct from (v_today + 25)::text
       or (r #> '{items,1,lectures}') is distinct from jsonb_build_array(v_a) then
      raise exception '점검 실패(D1 · 내 범위(보이기 전 줄 · show_on · 끝난 줄 뺌)): %', left(r::text, 600);
    end if;
    if jsonb_typeof(r -> 'sched') is distinct from 'object'
       or coalesce(jsonb_array_length(case when jsonb_typeof(r #> '{sched,rows}') = 'array' then r #> '{sched,rows}' end), -1) is distinct from 2
       or (r #>> '{sched,rows,0,id}') is distinct from 'main' or (r #>> '{sched,rows,1,id}') is distinct from 'pt-etc'
       or (r #> '{sched,me}') is distinct from '[]'::jsonb then
      raise exception '점검 실패(D1 · 답의 sched): %', left(r::text, 600);
    end if;
    if r::text like '%rids%' or r::text like '%saved_by%' or r::text like '%school_key%' then
      raise exception '점검 실패(D1 · 학생에게 남의 칸이 나감)';
    end if;

    -- 3) 권한: 학생 함수는 누구나(열쇠로 확인) · 새 속 함수와 속 함수 전부는 밖에서 못 부름
    if has_function_privilege('anon', 'public.lec__sched(jsonb, jsonb, text)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__sched(jsonb, jsonb, text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_range_me(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_me(text)', 'execute') then
      raise exception '점검 실패(D1 권한)';
    end if;
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(D1 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- D2 (11-19) 학생 홈 시험 D-day = 히즈북스 D-day 목록(모의고사 · 수능 · 반 D-day) · 열한째 스스로 점검
-- 원장님(11-19) «모의고사나 직접 넣은 D-day도 들어가도록 해 히즈북스랑 똑같이» → 학생 홈 시험 카드의 시험 = 히즈북스 _examDdayList 의 첫째
--   (학교 시험 · 모의고사 · 수능 · 반 D-day · 셈은 앱 class-api.js examList)
-- 앞 절은 그대로 두고 이 절에서만 덧댐(운영에 따로 넣을 때도 이 절 글만 · CLAUDE.md §8-234):
--   1) 속 함수 lec__sched 다시 정의(D1 정의를 글자 그대로 옮기고 정한 곳만 바꿈): 줄마다 nat(모의고사 examNat) · sn(옛 수능 칸 suneung) ·
--      dd(반 D-day examDday 중 내 반 칸만) 더함 · me 줄마다 cid(반 id) 더함
--      nat · sn 은 내 반 줄에 고등학교(학교 열쇠 끝 «고»)가 있을 때만 · 지운 모의고사 · 반 D-day 는 del · t 만(합칠 때 고른 차례에만 씀) ·
--      칸 값 = label · date · end · g · on · t 만(by · memo 따위는 안 줌) · 칸 값이 묶음이 아니면 참 = true · 거짓 = null ·
--      sn = date · on · del 만 · 묶음이 아닌 값은 false(앱처럼 main 값이 있으면 pt-etc 를 안 봄 · 수능 없음)
--   2) lec_range_me 는 그대로(답의 sched = 이 함수 값)
--      옛 화면 + 이 서버 = 옛 화면은 nat · sn · dd · cid 를 안 읽음(화면 그대로) · 새 화면 + D1 서버 = 학교 시험만(D1 과 같음)
--   3) 열한째 스스로 점검(가짜 main · pt-etc · 가짜 열쇠 · 끝에 모두 되돌림 · app_state 는 안 바꿈)
-- 운영에 넣은 뒤 확인(SQL Editor 에서 · 바꾸는 것 없음):
--   select has_function_privilege('anon', 'public.lec__sched(jsonb, jsonb, text)', 'execute') as "속 함수 밖에서 부름(false)";
--   select public.lec_range_me('selftest-wrong-key');   -- {"ok": false, "err": "key"}

-- 내 시험 일정: p_main · p_etc = app_state main · pt-etc 의 data · p_sid = 학생 열쇠(rid|맞춘 이름)
--   → {rows:[{id:'main', es, eg, nat, sn, dd}, {id:'pt-etc', es, eg, nat, sn, dd}], me:[{g, ig, s, is, cn, cid}]}
--   es · eg · me 의 g · ig · s · is · cn = D1 과 같음 · cid = 반 id(적힌 그대로)
--   nat = examNat 칸 전부(고등학교 학생만) · sn = suneung(고등학교 학생만) · dd = examDday 중 내 반 id 칸만 · 고른 칸이 없으면 null
create or replace function public.lec__sched(p_main jsonb, p_etc jsonb, p_sid text)
returns jsonb
language sql immutable set search_path = public as $$
  with me as (
    select c.ci, s.si, c.v as cls, s.v as stu
      from jsonb_array_elements(case when jsonb_typeof(p_main -> 'classes') = 'array' then p_main -> 'classes' else '[]'::jsonb end)
           with ordinality as c(v, ci)
     cross join lateral jsonb_array_elements(case when jsonb_typeof(c.v -> 'students') = 'array' then c.v -> 'students' else '[]'::jsonb end)
           with ordinality as s(v, si)
     where jsonb_typeof(s.v) = 'object'
       and coalesce(s.v ->> 'id', '') <> ''
       and public.lec__norm(s.v ->> 'name') <> ''
       and not public.lec__truthy(s.v -> 'withdrawn')
       and not public.lec__truthy(s.v -> 'pending')
       and (s.v ->> 'id') || '|' || public.lec__norm(s.v ->> 'name') = p_sid
  ),
  ks as (
    select distinct public.lec__skey(public.lec__stu_school(me.stu)) as k from me
  ),
  hs as (
    select exists (select 1 from ks where right(ks.k, 1) = '고') as y
  ),
  mc as (
    select distinct me.cls ->> 'id' as id from me where coalesce(me.cls ->> 'id', '') <> ''
  ),
  src (id, o, d) as (
    values ('main', 1, p_main), ('pt-etc', 2, p_etc)
  ),
  rw as (
    select src.o, jsonb_build_object('id', src.id, 'es', es.v, 'eg', eg.v, 'nat', nat.v, 'sn', sn.v, 'dd', dd.v) as r
      from src
     cross join lateral (
       select jsonb_object_agg(e.key, case when jsonb_typeof(e.value) = 'object' then jsonb_strip_nulls(jsonb_build_object(
                'label', e.value -> 'label', 'date', e.value -> 'date', 'end', e.value -> 'end',
                'del', e.value -> 'del', 'on', e.value -> 'on', 't', e.value -> 't')) else 'null'::jsonb end) as v
         from jsonb_each(case when jsonb_typeof(src.d -> 'examSchool') = 'object' then src.d -> 'examSchool' else '{}'::jsonb end) as e
        where e.key in (select ks.k from ks where ks.k <> '')) es
     cross join lateral (
       select jsonb_object_agg(e.key, case when jsonb_typeof(e.value) = 'object' then jsonb_strip_nulls(jsonb_build_object(
                'label', e.value -> 'label', 'date', e.value -> 'date', 'end', e.value -> 'end',
                'del', e.value -> 'del', 'on', e.value -> 'on', 't', e.value -> 't')) else 'null'::jsonb end) as v
         from jsonb_each(case when jsonb_typeof(src.d -> 'examSchoolG') = 'object' then src.d -> 'examSchoolG' else '{}'::jsonb end) as e
        where exists (select 1 from ks where ks.k <> '' and left(e.key, char_length(ks.k) + 1) = ks.k || '|')) eg
     cross join lateral (
       select jsonb_object_agg(e.key, case
                when jsonb_typeof(e.value) = 'object' and public.lec__truthy(e.value -> 'del')
                  then jsonb_strip_nulls(jsonb_build_object('del', true, 't', e.value -> 't'))
                when jsonb_typeof(e.value) = 'object' then jsonb_strip_nulls(jsonb_build_object(
                  'label', e.value -> 'label', 'date', e.value -> 'date', 'end', e.value -> 'end',
                  'g', e.value -> 'g', 'on', e.value -> 'on', 't', e.value -> 't'))
                when public.lec__truthy(e.value) then 'true'::jsonb else 'null'::jsonb end) as v
         from jsonb_each(case when jsonb_typeof(src.d -> 'examNat') = 'object' then src.d -> 'examNat' else '{}'::jsonb end) as e
        where (select hs.y from hs)) nat
     cross join lateral (
       select case when not (select hs.y from hs) then null
                   when jsonb_typeof(src.d -> 'suneung') = 'object' then jsonb_strip_nulls(jsonb_build_object(
                     'date', src.d #> '{suneung,date}', 'on', src.d #> '{suneung,on}', 'del', src.d #> '{suneung,del}'))
                   when jsonb_typeof(src.d -> 'suneung') in ('string', 'number', 'boolean', 'array') then 'false'::jsonb
                   else null end as v) sn
     cross join lateral (
       select jsonb_object_agg(e.key, case
                when jsonb_typeof(e.value) = 'object' and public.lec__truthy(e.value -> 'del')
                  then jsonb_strip_nulls(jsonb_build_object('del', true, 't', e.value -> 't'))
                when jsonb_typeof(e.value) = 'object' then jsonb_strip_nulls(jsonb_build_object(
                  'label', e.value -> 'label', 'date', e.value -> 'date', 'end', e.value -> 'end',
                  'on', e.value -> 'on', 't', e.value -> 't'))
                when public.lec__truthy(e.value) then 'true'::jsonb else 'null'::jsonb end) as v
         from jsonb_each(case when jsonb_typeof(src.d -> 'examDday') = 'object' then src.d -> 'examDday' else '{}'::jsonb end) as e
        where e.key in (select mc.id from mc)) dd
  )
  select jsonb_build_object(
    'rows', (select jsonb_agg(rw.r order by rw.o) from rw),
    'me', coalesce((select jsonb_agg(jsonb_build_object(
                             'g', me.stu -> 'grade', 'ig', me.stu #> '{intake,grade}',
                             's', me.stu -> 'school', 'is', me.stu #> '{intake,school}', 'cn', me.cls -> 'name',
                             'cid', me.cls -> 'id') order by me.ci, me.si)
                      from me), '[]'::jsonb))
$$;

revoke all on function public.lec__sched(jsonb, jsonb, text) from public, anon, authenticated;

-- 스스로 점검(D2): 모의고사(고등학교 학생만 · 지운 칸 = del · t 만 · 글자 칸 = true · 거짓 칸 = null) · 옛 수능 칸(묶음 아님 = false) ·
--   반 D-day(내 반 칸만 · 남의 반 · pt-etc 의 남의 반 안 줌) · me 의 cid · 중학생 = nat · sn 없음 · 학생 함수 답의 sched 칸 · 권한
--   비교는 모두 «is distinct from»(빈 값이면 실패) · 점검용으로 넣은 것은 끝에 되돌려 남지 않습니다(app_state 는 읽기만)
do $$
declare
  r       jsonb;
  v_t     text;
  v_m     jsonb;
  v_e     jsonb;
  v_dk    text := 'selftest' || replace(gen_random_uuid()::text, '-', '');
  v_cls   text := 'c-selftest-d2' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
begin
  begin
    -- 1) 고등학생(두 반): 모의고사 · 수능 · 내 반 D-day · 학교 일정(D1 그대로)
    v_m := '{"classes": [
       {"id": "c-d2a", "name": "고3 A반", "students": [
         {"id": "d2-s1", "name": "점검가", "school": "포항대동고등학교", "grade": "3"}]},
       {"id": "c-d2b", "name": "고3 B반", "students": [
         {"id": "d2-s1", "name": "점검가", "school": "포항대동고등학교", "grade": "3"},
         {"id": "d2-s1", "name": "점검가", "withdrawn": true, "school": "포항이동고"}]},
       {"id": "c-d2c", "name": "중3 C반", "students": [
         {"id": "d2-s2", "name": "중학생", "school": "포항제철중학교", "grade": "3"}]}],
     "examSchool": {"포항대동고": {"label": "2학기 기말", "date": "2026.12.01", "by": "점검 선생님"}},
     "examNat": {
       "m11": {"label": "11월 모의고사", "date": "2026.11.20", "g": "1,2", "on": true, "t": 3, "by": "점검 선생님"},
       "m12": {"label": "지운 모의", "date": "2026.12.10", "del": true, "t": 7, "by": "점검 선생님"},
       "csat": {"label": "수능", "date": "2026.11.19", "end": null, "t": 2},
       "x": "글자", "z": 0},
     "suneung": {"date": "2026.11.19", "on": true, "t": 4, "by": "점검 선생님"},
     "examDday": {
       "c-d2a": {"label": "반 시험", "date": "2026.12.01", "on": 1, "t": 1, "memo": "점검"},
       "c-d2b": {"label": "지운 반 시험", "date": "2026.12.02", "del": 1},
       "c-d2c": {"label": "다른 반 시험", "date": "2026.12.03"}}}'::jsonb;
    v_e := '{"examNat": {"m11": {"label": "11월 모의 고침", "date": "2026.11.21", "t": 5}},
             "suneung": "글자",
             "examDday": {"c-d2a": {"label": "반 시험 고침", "date": "2026.12.05", "t": 9},
                          "c-zz": {"label": "남의 반", "date": "2026.12.06"}}}'::jsonb;
    r := public.lec__sched(v_m, v_e, 'd2-s1|점검가');
    if (r -> 'rows') is distinct from jsonb_build_array(
         jsonb_build_object('id', 'main',
           'es', '{"포항대동고": {"label": "2학기 기말", "date": "2026.12.01"}}'::jsonb, 'eg', 'null'::jsonb,
           'nat', '{"m11": {"label": "11월 모의고사", "date": "2026.11.20", "g": "1,2", "on": true, "t": 3},
                    "m12": {"del": true, "t": 7}, "csat": {"label": "수능", "date": "2026.11.19", "t": 2},
                    "x": true, "z": null}'::jsonb,
           'sn', '{"date": "2026.11.19", "on": true}'::jsonb,
           'dd', '{"c-d2a": {"label": "반 시험", "date": "2026.12.01", "on": 1, "t": 1}, "c-d2b": {"del": true}}'::jsonb),
         jsonb_build_object('id', 'pt-etc', 'es', 'null'::jsonb, 'eg', 'null'::jsonb,
           'nat', '{"m11": {"label": "11월 모의 고침", "date": "2026.11.21", "t": 5}}'::jsonb,
           'sn', 'false'::jsonb,
           'dd', '{"c-d2a": {"label": "반 시험 고침", "date": "2026.12.05", "t": 9}}'::jsonb)) then
      raise exception '점검 실패(D2 · 모의고사 · 수능 · 내 반 D-day 칸): %', left(r::text, 900);
    end if;
    if (r -> 'me') is distinct from '[{"g": "3", "ig": null, "s": "포항대동고등학교", "is": null, "cn": "고3 A반", "cid": "c-d2a"},
                                     {"g": "3", "ig": null, "s": "포항대동고등학교", "is": null, "cn": "고3 B반", "cid": "c-d2b"}]'::jsonb then
      raise exception '점검 실패(D2 · 내 반 줄의 cid): %', left(r::text, 900);
    end if;
    if r::text like '%점검 선생님%' or r::text like '%"memo"%' or r::text like '%"by"%' or r::text like '%지운 모의%'
       or r::text like '%지운 반 시험%' or r::text like '%다른 반 시험%' or r::text like '%남의 반%' then
      raise exception '점검 실패(D2 · 남의 칸이 나감): %', left(r::text, 900);
    end if;
    -- 2) 중학생 = 모의고사 · 수능 없음 · 제 반 D-day 만
    r := public.lec__sched(v_m, v_e, 'd2-s2|중학생');
    if (r -> 'rows') is distinct from jsonb_build_array(
         jsonb_build_object('id', 'main', 'es', 'null'::jsonb, 'eg', 'null'::jsonb, 'nat', 'null'::jsonb, 'sn', 'null'::jsonb,
           'dd', '{"c-d2c": {"label": "다른 반 시험", "date": "2026.12.03"}}'::jsonb),
         jsonb_build_object('id', 'pt-etc', 'es', 'null'::jsonb, 'eg', 'null'::jsonb, 'nat', 'null'::jsonb, 'sn', 'null'::jsonb,
           'dd', 'null'::jsonb))
       or (r -> 'me') is distinct from '[{"g": "3", "ig": null, "s": "포항제철중학교", "is": null, "cn": "중3 C반", "cid": "c-d2c"}]'::jsonb then
      raise exception '점검 실패(D2 · 중학생): %', left(r::text, 900);
    end if;
    -- 명단에 없음 · 빈 자료 = 두 줄(id 만) · 반 줄 없음 · 수능 칸이 숫자 · 배열이면 false · 비었으면 null
    v_t := '{"rows": [{"id": "main", "es": null, "eg": null, "nat": null, "sn": null, "dd": null},
                      {"id": "pt-etc", "es": null, "eg": null, "nat": null, "sn": null, "dd": null}], "me": []}';
    if public.lec__sched(v_m, v_e, 'd2-none|없음') is distinct from v_t::jsonb
       or public.lec__sched(null, null, 'd2-s1|점검가') is distinct from v_t::jsonb
       or public.lec__sched('[]'::jsonb, '"x"'::jsonb, null) is distinct from v_t::jsonb then
      raise exception '점검 실패(D2 · 명단에 없음 · 빈 자료)';
    end if;
    r := public.lec__sched(v_m - 'suneung' || '{"suneung": 0}'::jsonb, '{"suneung": [1]}'::jsonb, 'd2-s1|점검가');
    if (r #> '{rows,0,sn}') is distinct from 'false'::jsonb or (r #> '{rows,1,sn}') is distinct from 'false'::jsonb then
      raise exception '점검 실패(D2 · 수능 칸이 묶음이 아님): %', left(r::text, 900);
    end if;
    r := public.lec__sched(v_m - 'suneung' - 'examNat' || '{"suneung": null}'::jsonb, '{}'::jsonb, 'd2-s1|점검가');
    if (r #> '{rows,0,sn}') is distinct from 'null'::jsonb or (r #> '{rows,0,nat}') is distinct from 'null'::jsonb then
      raise exception '점검 실패(D2 · 수능 · 모의고사 칸 없음): %', left(r::text, 900);
    end if;

    -- 3) 학생 함수: 답의 sched 두 줄마다 nat · sn · dd 칸(명단에 없는 열쇠 = 모두 null · 남의 모의고사 · 반 D-day 안 나감)
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_dk), 'selftest-d2|점검', 'selftest-d2', '1234', '점검', array[v_cls]);
    r := public.lec_range_me(v_dk);
    if (r ->> 'ok') is distinct from 'true'
       or jsonb_typeof(r #> '{sched,rows,0}') is distinct from 'object' or jsonb_typeof(r #> '{sched,rows,1}') is distinct from 'object'
       or not ((r #> '{sched,rows,0}') ?& array['id', 'es', 'eg', 'nat', 'sn', 'dd'])
       or not ((r #> '{sched,rows,1}') ?& array['id', 'es', 'eg', 'nat', 'sn', 'dd'])
       or (r #> '{sched,rows,0,nat}') is distinct from 'null'::jsonb or (r #> '{sched,rows,1,nat}') is distinct from 'null'::jsonb
       or (r #> '{sched,rows,0,sn}') is distinct from 'null'::jsonb or (r #> '{sched,rows,1,sn}') is distinct from 'null'::jsonb
       or (r #> '{sched,rows,0,dd}') is distinct from 'null'::jsonb or (r #> '{sched,rows,1,dd}') is distinct from 'null'::jsonb
       or (r #> '{sched,me}') is distinct from '[]'::jsonb then
      raise exception '점검 실패(D2 · 답의 sched): %', left(r::text, 900);
    end if;

    -- 4) 권한: 학생 함수는 누구나(열쇠로 확인) · 다시 정의한 속 함수와 속 함수 전부는 밖에서 못 부름
    if has_function_privilege('anon', 'public.lec__sched(jsonb, jsonb, text)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__sched(jsonb, jsonb, text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_range_me(text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_range_me(text)', 'execute') then
      raise exception '점검 실패(D2 권한)';
    end if;
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(D2 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- V2-1 (11-20) 세트 학습 v2 저장 · 채점 바탕 · 열두째 스스로 점검
-- 결론안 v2(11-20) 묶음 ①a: 폰 보관함의 답 줄 → 서버 한 줄 표(lec_set_log) · 서버가 다시 채점해 카드에 반영 · 평가를 여는 응답에 바른 답 0
-- 앞 절은 그대로 두고 더하기만(지금 함수 몸 · 표 칸 바꿈 0 · DROP 0 · 운영에 따로 넣을 때도 이 절 글만):
--   1) 표 넷(행 보안 · 표로는 아무도 못 읽고 못 씀 · 함수로만): lec_v2_cfg(기능 스위치 한 줄 · 처음 모두 끔) · lec_set_run(v2 연습 판) ·
--      lec_set_log(답 한 줄 · 반영함 칸 done) · lec_v2_box(폰 보관함 남은 줄) · 이름 바뀜 · 지움 트리거 셋
--   2) 속 함수: 스위치 · 줄 꼴 검사 · 답한 때 · 카드 반영(같은 날 앞 순번이 늦게 오면 그 카드만 다시 셈) · 평가 칸 채우기 ·
--      구문 쓰기 채점(lec__set_snorm_v2 · lec__set_sent_v2) · 단어 쓰기 «뜻 여럿»(lec__set_spell_v2) · 목록 쌓인 오답 수
--   3) 학생 함수 여섯(열쇠 · 동의 확인은 옛 함수와 같은 꼴): lec_set_home_v2 · lec_set_open_v2 · lec_set_log_v2 · lec_set_test_v2 ·
--      lec_set_save_v2 · lec_set_send_v2 · 선생님 함수 하나 lec_v2_watch(원장님 · 선생님만 · 읽기만)
--   4) 열두째 스스로 점검(가짜 세트 · 열쇠 · 스위치 · 끝에 모두 되돌림)
-- 스위치는 «새 판 열기»만 막음: 끄면 화면이 옛 함수로 돎(지금 판 그대로) · 이미 연 v2 판 · 평가의 줄은 끈 뒤에도 받아 반영(잃은 답 0)
--   update public.lec_v2_cfg set eval = false, updated_at = now();   -- 칸: log · eval · spell · guw · gram · review · lim(하루 반영 한도)
-- 운영에 넣은 뒤 확인(바꾸는 것 없음):
--   select * from public.lec_v2_cfg;                                  -- 한 줄 · 스위치 모두 false · lim 3000
--   select public.lec_set_log_v2('selftest-wrong-key', '[]'::jsonb);  -- {"ok": false, "err": "key"}

create table if not exists public.lec_v2_cfg (
  id          smallint primary key default 1,
  log         boolean not null default false,
  eval        boolean not null default false,
  spell       boolean not null default false,
  guw         boolean not null default false,
  gram        boolean not null default false,
  review      boolean not null default false,
  lim         integer not null default 3000,
  updated_at  timestamptz not null default now(),
  constraint lec_v2_cfg_one    check (id = 1),
  constraint lec_v2_cfg_lim_ok check (lim between 0 and 100000)
);
insert into public.lec_v2_cfg (id) values (1) on conflict (id) do nothing;

-- v2 연습 판(외우기 mem = 세트 하나 · 쌓인 오답 due = 문항 [{s, k, f}] · 바른 답은 세트에서 다시 읽음)
--   shut = {세트 id: 닫은 때} 그 세트 평가를 열면 그 뒤 답은 기록만 · last_i = 받은 가장 큰 순번 · end_n = 판 끝 줄 수(폰이 알림)
create table if not exists public.lec_set_run (
  id          uuid primary key default gen_random_uuid(),
  sid         text not null,
  set_id      uuid,
  md          text not null,
  no          integer not null,
  day         date not null,
  n           integer not null default 0,
  qs          jsonb not null default '[]'::jsonb,
  seed        integer not null,
  shut        jsonb not null default '{}'::jsonb,
  last_i      integer not null default 0,
  end_n       integer,
  created_at  timestamptz not null default now(),
  constraint lec_set_run_md_ok check (md in ('mem', 'due', 'spell', 'guw', 'gram', 'review')),   -- V2-3 새 판 넷
  constraint lec_set_run_js_ok check (jsonb_typeof(qs) = 'array' and jsonb_typeof(shut) = 'object')
);
create index if not exists lec_set_run_sid on public.lec_set_run (sid, day);

-- 답 한 줄(폰이 만든 id 로 한 번만) · bk = 판 꼴(mem · due 연습 · ev 평가 · log 폰이 만든 판 · 옛 판 = 기록만)
--   sr = 서버 판정 · ok = 카드에 쓸 맞음(힌트 본 답 = 틀림) · pr = 폰 판정 · done = 카드에 반영함 · c0 = 반영 전 카드(다시 셀 때)
--   ta · day = 답한 때(받은 때 − ago · 0~14일 · 판 연 때보다 앞이 아님) · bo = 판 연 때(반영 차례) · bn = 묶음 번호(부름마다 · 호출 셈)
--   why: '' 반영(또는 반영할 것) · log 기록만 · late 카드에 더 늦은 날이 있음 · lim 하루 한도 · shut 평가가 열린 뒤 답 · gone 세트 · 문항 없음 · done 이미 찬 칸
create table if not exists public.lec_set_log (
  id     text primary key,
  sid    text not null,
  cl     text not null default '',
  b      uuid not null,
  bk     text not null,
  i      integer not null,
  n      integer,
  set_id uuid,
  k      text not null default '',
  f      text not null default '',
  v      text not null default '',
  h      boolean not null default false,
  ms     integer,
  nx     integer,
  om     integer,
  pr     boolean,
  sr     boolean,
  ok     boolean not null default false,
  src    text not null default '',
  v1     boolean not null default false,
  ago    bigint not null default 0,
  ta     timestamptz not null,
  day    date not null,
  pt     bigint,
  st     text not null default '',
  bo     timestamptz not null,
  at     timestamptz not null default now(),
  bn     bigint not null default txid_current(),
  done   boolean not null default false,
  late   boolean not null default false,
  why    text not null default '',
  c0     jsonb,
  constraint lec_set_log_id_ok  check (id ~ '^[0-9a-f]{32}$'),
  constraint lec_set_log_bk_ok  check (bk in ('mem', 'due', 'ev', 'log', 'spell', 'guw', 'gram', 'review')),   -- V2-3 새 판 넷
  constraint lec_set_log_i_ok   check (i between 1 and 1000),
  constraint lec_set_log_v_ok   check (char_length(v) <= 400),
  constraint lec_set_log_why_ok check (why in ('', 'log', 'late', 'lim', 'shut', 'gone', 'done'))
);
create index if not exists lec_set_log_b    on public.lec_set_log (b, i);
create index if not exists lec_set_log_day  on public.lec_set_log (day, sid);
create index if not exists lec_set_log_card on public.lec_set_log (sid, set_id, k, day) where done;

-- 폰 보관함 남은 줄(열 때마다 · 남은 줄이 있을 때만 적고 비면 지움): n 줄 수 · age 가장 오래된 줄 나이(ms)
create table if not exists public.lec_v2_box (
  sid   text primary key,
  n     integer not null,
  age   bigint not null,
  at    timestamptz not null default now()
);

revoke all on public.lec_v2_cfg, public.lec_set_run, public.lec_set_log, public.lec_v2_box from public, anon, authenticated;
alter table public.lec_v2_cfg  enable row level security;
alter table public.lec_set_run enable row level security;
alter table public.lec_set_log enable row level security;
alter table public.lec_v2_box  enable row level security;

-- 트리거: 학생 열쇠 · 동의 줄의 sid 가 바뀌면 v2 줄도 옮김 · 동의 줄이 지워지면 v2 줄도 지움(lec__set_mv · lec__set_gone 과 같은 때)
--   log · run = lec_set_try 처럼 모두 옮김(id 기본 키 · sid 고유 없음 = 겹침 0) ·
--   box(sid 한 줄) = lec_rec_ok 처럼 새 sid 에 이미 있으면 새 것을 두고 옛 줄 지움 · 없으면 옮김(on conflict = 같이 들어와도 겹침 오류 0)
create or replace function public.lec__v2_mv() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.sid is distinct from new.sid and coalesce(old.sid, '') <> '' and coalesce(new.sid, '') <> '' then
    update public.lec_set_log xl set sid = new.sid where xl.sid = old.sid;
    update public.lec_set_run xr set sid = new.sid where xr.sid = old.sid;
    insert into public.lec_v2_box (sid, n, age, at)
    select new.sid, xb.n, xb.age, xb.at from public.lec_v2_box xb where xb.sid = old.sid
    on conflict (sid) do nothing;
    delete from public.lec_v2_box xb where xb.sid = old.sid;
  end if;
  return null;
end
$$;

create or replace function public.lec__v2_gone() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.lec_set_log xl where xl.sid = old.sid;
  delete from public.lec_set_run xr where xr.sid = old.sid;
  delete from public.lec_v2_box xb where xb.sid = old.sid;
  return null;
end
$$;

create or replace trigger lec_key_v2_mv after update of sid on public.lec_key
  for each row execute function public.lec__v2_mv();
create or replace trigger lec_consent_v2_mv after update of sid on public.lec_consent
  for each row execute function public.lec__v2_mv();
create or replace trigger lec_consent_v2_gone after delete on public.lec_consent
  for each row execute function public.lec__v2_gone();

-- 스위치(줄이 없으면 모두 끔)
create or replace function public.lec__v2_sw() returns jsonb
language sql stable set search_path = public as $$
  select coalesce((select jsonb_build_object('log', c.log, 'eval', c.eval, 'spell', c.spell, 'guw', c.guw,
                                             'gram', c.gram, 'review', c.review)
                     from public.lec_v2_cfg c where c.id = 1),
                  jsonb_build_object('log', false, 'eval', false, 'spell', false, 'guw', false, 'gram', false, 'review', false))
$$;

-- 숫자 글 → 수(0 이상 · 15 자리까지 · p_max 로 자름) · 꼴이 틀리면 null(바꾸다 오류 나지 않게 검사 뒤에만 바꿈)
create or replace function public.lec__v2_num(p_t text, p_max bigint) returns bigint
language plpgsql immutable set search_path = public as $$
begin
  if coalesce(p_t, '') ~ '^[0-9]{1,15}$' then
    return least(p_t::bigint, p_max);
  end if;
  return null;
end
$$;

-- 폰이 보낸 한 줄 → 고른 칸만(문항 글 · 바른 답 없음) · 꼴이 틀리면 null(받은 것으로 치고 버림 = bad)
--   id 32 글자 16진 · b 판 uuid · i 순번 1~1000 · n 판 끝 줄 수 · s 세트 · k 열쇠 · f 꼴(k 스스로 · sp 단어 쓰기 · se 구문 쓰기 · 쌓인 오답은 판 문항 꼴) ·
--   v 답(400 글자까지 · 넘으면 lg) · h 힌트 봄 · ms 문항 시간 · nx 다음 문항 그리기 · om 판 열기 · pr 폰 판정 · ago 답한 뒤 지난 ms(0~14일) ·
--   pt 폰 시각(ms) · st 판을 열 때 받은 서버 오늘
create or replace function public.lec__v2_row(p_e jsonb) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_id  text;
  v_b   text;
  v_i   bigint;
  v_s   text;
  v_v   text;
begin
  if jsonb_typeof(p_e) is distinct from 'object' then
    return null;
  end if;
  v_id := coalesce(p_e ->> 'id', '');
  v_b := coalesce(p_e ->> 'b', '');
  v_i := public.lec__v2_num(p_e ->> 'i', 100000);
  if v_id !~ '^[0-9a-f]{32}$' or v_b !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or coalesce(v_i, 0) not between 1 and 1000 then
    return null;
  end if;
  v_s := coalesce(p_e ->> 's', '');
  v_v := case when jsonb_typeof(p_e -> 'v') in ('string', 'number') then p_e ->> 'v' else '' end;
  return jsonb_build_object(
    'id', v_id, 'b', v_b, 'i', v_i,
    'n', case when public.lec__v2_num(p_e ->> 'n', 100000) between 1 and 1000 then public.lec__v2_num(p_e ->> 'n', 100000) end,
    's', case when v_s ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then v_s end,
    'k', case when jsonb_typeof(p_e -> 'k') = 'string' then left(p_e ->> 'k', 20) else '' end,
    'f', case when jsonb_typeof(p_e -> 'f') = 'string' then left(p_e ->> 'f', 4) else '' end,
    'v', left(v_v, 400), 'lg', char_length(v_v) > 400,
    'h', coalesce((p_e -> 'h') in ('true'::jsonb, '1'::jsonb), false),
    'ms', public.lec__v2_num(p_e ->> 'ms', 3600000),
    'nx', public.lec__v2_num(p_e ->> 'nx', 600000),
    'om', public.lec__v2_num(p_e ->> 'om', 600000),
    'pr', case when jsonb_typeof(p_e -> 'pr') = 'boolean' then p_e -> 'pr' end,
    'ago', coalesce(public.lec__v2_num(p_e ->> 'ago', 1209600000), 0),
    'pt', public.lec__v2_num(p_e ->> 'pt', 999999999999999),
    'st', case when coalesce(p_e ->> 'st', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then p_e ->> 'st' else '' end);
end
$$;

-- 답한 때 = 받은 때 − ago(0~14일) · 판 연 때보다 앞이면 판 연 때(날짜는 서버 시각으로만 셈 · 폰 시계는 안 믿음)
create or replace function public.lec__v2_ta(p_ago bigint, p_bo timestamptz) returns timestamptz
language sql stable set search_path = public as $$
  select greatest(now() - (least(greatest(coalesce(p_ago, 0), 0), 1209600000)::double precision * interval '1 millisecond'),
                  coalesce(p_bo, '-infinity'::timestamptz))
$$;

-- 카드에 적힌 가장 늦은 날(d · t · z · y) · 없으면 ''
create or replace function public.lec__v2_last(p_c jsonb) returns text
language sql immutable set search_path = public as $$
  select coalesce(max(x.v), '')
    from (select jsonb_array_elements_text(case when jsonb_typeof(p_c -> 'd') = 'array' then p_c -> 'd' else '[]'::jsonb end) as v
          union all
          select jsonb_array_elements_text(case when jsonb_typeof(p_c -> 'y') = 'array' then p_c -> 'y' else '[]'::jsonb end)
          union all
          select p_c ->> 't'
          union all
          select p_c ->> 'z') x
   where x.v ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
$$;

-- 한 줄의 카드 셈(lec__set_mark 그대로 · 구문 2 = 말해서 확인 → v 1 · lec_set_card 와 같음)
create or replace function public.lec__v2_mk(p_c jsonb, p_ok boolean, p_src text, p_v1 boolean, p_day date) returns jsonb
language sql immutable set search_path = public as $$
  select case when p_v1 and p_src = 'say' then public.lec__set_mark(p_c, p_ok, p_src, p_day) || jsonb_build_object('v', 1)
              else public.lec__set_mark(p_c, p_ok, p_src, p_day) end
$$;

-- 표에 넣은 한 줄을 카드에 반영(부르는 쪽이 학생마다 잠금을 잡고 새 줄을 (판 연 때 · 판 · 순번) 차례로 부름):
--   카드에 이 줄 날보다 늦은 날이 있으면 기록만(late) · 같은 카드 · 같은 날에 이 줄보다 뒤 차례 줄이 이미 반영됐으면
--   그 가운데 첫 줄의 반영 전 카드(c0)부터 차례로 다시 셈(그 카드만 · 차례대로 보낸 것과 같은 값) · 돌려줌 ok · late · skip
create or replace function public.lec__v2_apply(p_id text) returns text
language plpgsql volatile set search_path = public as $$
declare
  r      public.lec_set_log;
  v_c    jsonb;
  v_x    record;
  v_has  boolean := false;
begin
  select * into r from public.lec_set_log xl where xl.id = p_id;
  if not found or r.done or r.why <> '' or r.set_id is null or r.k = '' or r.src = '' then
    return 'skip';
  end if;
  insert into public.lec_set_prog (sid, set_id) values (r.sid, r.set_id) on conflict (sid, set_id) do nothing;
  select xp.cards -> r.k into v_c from public.lec_set_prog xp where xp.sid = r.sid and xp.set_id = r.set_id for update;
  if public.lec__v2_last(v_c) > to_char(r.day, 'YYYY-MM-DD') then
    update public.lec_set_log xl set late = true, why = 'late' where xl.id = r.id;
    return 'late';
  end if;
  for v_x in
    select xl.c0 from public.lec_set_log xl
     where xl.sid = r.sid and xl.set_id = r.set_id and xl.k = r.k and xl.day = r.day and xl.done
       and (xl.bo, xl.b, xl.i, xl.id) > (r.bo, r.b, r.i, r.id)
     order by xl.bo, xl.b, xl.i, xl.id
     limit 1
  loop
    v_c := v_x.c0;
    v_has := true;
  end loop;
  update public.lec_set_log xl set done = true, c0 = v_c where xl.id = r.id;
  v_c := public.lec__v2_mk(v_c, r.ok, r.src, r.v1, r.day);
  if v_has then
    for v_x in
      select xl.id, xl.ok, xl.src, xl.v1, xl.day from public.lec_set_log xl
       where xl.sid = r.sid and xl.set_id = r.set_id and xl.k = r.k and xl.day = r.day and xl.done
         and (xl.bo, xl.b, xl.i, xl.id) > (r.bo, r.b, r.i, r.id)
       order by xl.bo, xl.b, xl.i, xl.id
    loop
      update public.lec_set_log xl set c0 = v_c where xl.id = v_x.id;
      v_c := public.lec__v2_mk(v_c, v_x.ok, v_x.src, v_x.v1, v_x.day);
    end loop;
  end if;
  update public.lec_set_prog xp set cards = jsonb_set(xp.cards, array[r.k], v_c), last_at = now()
   where xp.sid = r.sid and xp.set_id = r.set_id;
  return 'ok';
end
$$;

-- 평가 판(시험 · 드릴) 줄 채우기(줄은 lec__v2_row 꼴 · 부르는 쪽이 잠금): 빈 칸만(먼저 온 답이 남음) · 채점은 lec_set_ans 와 같음(200 글자 넘으면 틀림) ·
--   표에 한 줄씩(bk ev) · 카드 = 늦은 줄 빼고 lec__v2_apply · kn 은 늘 · 이 부름으로 판이 다 차면 lec_set_ans 끝 셈 그대로(f1 · 점수 · 통과)
create or replace function public.lec__v2_ev(p_sid text, p_cl text, p_try uuid, p_rows jsonb) returns integer
language plpgsql volatile set search_path = public as $$
declare
  t      public.lec_set_try;
  s      public.lec_set;
  v_e    jsonb;
  v_q    jsonb;
  v_i    integer;
  v_v    text;
  v_r    boolean;
  v_ta   timestamptz;
  v_why  text;
  v_k    text;
  v_n    integer := 0;
  v_was  boolean;
  v_kn   integer;
  v_o2   bigint;  -- V2-5
begin
  select * into t from public.lec_set_try xt
   where xt.id = p_try and xt.sid = p_sid and xt.kind in ('test', 'drill') for update;
  if not found then
    return 0;
  end if;
  v_was := t.done_at is null;
  for v_e in select x.e from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) as x(e)
              where x.e ->> 'b' = p_try::text
              order by (x.e ->> 'i')::integer, (x.e ->> 'ago')::bigint desc, x.e ->> 'id' loop
    v_i := (v_e ->> 'i')::integer - 1;
    v_ta := public.lec__v2_ta((v_e ->> 'ago')::bigint, t.created_at);
    v_v := v_e ->> 'v';
    v_why := '';
    v_r := null;
    v_o2 := null;  -- V2-5
    v_q := case when v_i < t.n then t.qs -> v_i end;
    if v_q is null or btrim(v_v) = '' then
      v_why := 'gone';
    elsif jsonb_typeof(t.ans -> v_i) = 'object' or t.done_at is not null then
      v_why := 'done';
    else
      if v_q ->> 'f' = 'c' then
        v_r := public.lec__set_norm(v_v) = public.lec__set_norm(v_q ->> 'a');
      else
        v_r := public.lec__set_match(v_v, v_q ->> 'a');
      end if;
      v_r := coalesce(v_r, false) and char_length(v_v) <= 200;
      -- V2-5: 쓰기 답이 틀렸으면 켜진 인정 답(V2-5 절이 있을 때만)
      if not v_r and v_q ->> 'f' in ('w', 'r') and to_regprocedure('public.lec__v2_ok2id(uuid,text,text,text)') is not null then
        v_o2 := public.lec__v2_ok2id(t.set_id, coalesce(v_q ->> 'k', ''), case when t.kind = 'test' then 'voc' else 'gram' end, v_v);
        v_r := v_o2 is not null;
      end if;
    end if;
    v_k := coalesce(v_q ->> 'k', '');
    insert into public.lec_set_log (id, sid, cl, b, bk, i, set_id, k, f, v, h, ms, nx, om, pr, sr, ok, src,
                                    ago, ta, day, pt, st, bo, why)
    values (v_e ->> 'id', p_sid, p_cl, t.id, 'ev', v_i + 1, t.set_id, v_k, coalesce(v_q ->> 'f', ''), v_v,
            (v_e ->> 'h')::boolean, (v_e ->> 'ms')::integer, (v_e ->> 'nx')::integer, (v_e ->> 'om')::integer,
            (v_e ->> 'pr')::boolean, v_r, coalesce(v_r, false), t.kind, (v_e ->> 'ago')::bigint, v_ta,
            (v_ta at time zone 'Asia/Seoul')::date, (v_e ->> 'pt')::bigint, v_e ->> 'st', t.created_at, v_why)
    on conflict (id) do nothing;
    if not found or v_why <> '' then
      continue;
    end if;
    if v_o2 is not null then  -- V2-5: 채점 때 인정 답으로 맞음 표시(규칙 판정 = 틀림)
      insert into public.lec_set_fix (ok2, log_id, ok, g) values (v_o2, v_e ->> 'id', true, true);
    end if;
    update public.lec_set_try xt
       set ans = jsonb_set(xt.ans, array[v_i::text], jsonb_build_object('v', v_v, 'r', v_r, 'at', v_ta)),
           got = xt.got + 1,
           sc = xt.sc + case when v_r then 1 else 0 end,
           done_at = case when xt.got + 1 >= xt.n then now() else null end
     where xt.id = t.id
    returning * into t;
    if t.kind = 'test' then
      update public.lec_set_prog xp
         set kn = case when v_r then (case when v_k = any (xp.kn) then xp.kn else xp.kn || v_k end) else array_remove(xp.kn, v_k) end,
             last_at = now()
       where xp.sid = p_sid and xp.set_id = t.set_id;
    end if;
    perform public.lec__v2_apply(v_e ->> 'id');
    v_n := v_n + 1;
  end loop;
  if v_was and t.done_at is not null then
    select * into s from public.lec_set xs where xs.id = t.set_id;
    select count(*) into v_kn
      from public.lec_set_prog xp cross join lateral unnest(xp.kn) as y(kk)
     where xp.sid = p_sid and xp.set_id = t.set_id
       and y.kk in (select u.e ->> 'k' from jsonb_array_elements(s.items) as u(e));
    update public.lec_set_prog xp
       set f1 = coalesce(xp.f1, (t.sc * 100) / t.n),
           last_sc = t.sc,
           best = greatest(xp.best, case when t.kind = 'test' and not t.drawn then (v_kn * 100) / greatest(s.n, 1)
                                         else (t.sc * 100) / t.n end),
           pass_at = case when xp.pass_at is null
                               and (case when t.kind = 'test' and not t.drawn then v_kn >= public.lec__set_need(s.n)
                                         else t.sc >= public.lec__set_need(t.n) end)
                          then now() else xp.pass_at end
     where xp.sid = p_sid and xp.set_id = t.set_id;
  end if;
  return v_n;
end
$$;

-- 평가 줄 받기(lec_set_save_v2 · lec_set_send_v2 가 같이 씀 · 판 주인 확인 뒤): 300 줄 · 256KB 까지 · 학생마다 잠금 · 꼴 틀린 줄 = bad ·
--   다른 판 줄은 받지 않고 둠(폰 보관함에 남음) · got = 보낸 줄 가운데 표에 있는 것 전부(전에 받은 것 포함)
create or replace function public.lec__v2_take(p_sid text, p_cl text, p_try uuid, p_rows jsonb) returns jsonb
language plpgsql volatile set search_path = public as $$
declare
  v_e    jsonb;
  v_r    jsonb;
  v_ok   jsonb := '[]'::jsonb;
  v_bad  jsonb := '[]'::jsonb;
  v_got  jsonb;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  if jsonb_array_length(p_rows) > 300 or octet_length(p_rows::text) > 262144 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  perform pg_advisory_xact_lock(hashtext('lec_v2|' || p_sid));
  for v_e in select x.e from jsonb_array_elements(p_rows) as x(e) loop
    v_r := public.lec__v2_row(v_e);
    if v_r is null then
      if jsonb_typeof(v_e) = 'object' and jsonb_typeof(v_e -> 'id') = 'string' then
        v_bad := v_bad || jsonb_build_array(left(v_e ->> 'id', 40));
      end if;
    elsif v_r ->> 'b' = p_try::text then
      v_ok := v_ok || jsonb_build_array(v_r);
    end if;
  end loop;
  perform public.lec__v2_ev(p_sid, p_cl, p_try, v_ok);
  select coalesce(jsonb_agg(xl.id), '[]'::jsonb) into v_got
    from public.lec_set_log xl
   where xl.sid = p_sid and xl.id in (select x.e ->> 'id' from jsonb_array_elements(v_ok) as x(e));
  return jsonb_build_object('ok', true, 'got', v_got, 'bad', v_bad);
end
$$;

-- 목록 쌓인 오답 수(lec_set_home 의 due 와 같은 셈 · n 전부 · now 오늘 나올 것 · 시험 · 드릴이 열린 세트는 now 에서 뺌)
create or replace function public.lec__v2_due(p_sid text, p_cls text[]) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('n', coalesce(sum(y.n), 0)::integer,
                            'now', coalesce(sum(y.nw) filter (where not public.lec__set_busy(p_sid, y.id)), 0)::integer)
    from (select xs.id, count(*) as n, count(*) filter (where public.lec__set_due_on(c.card, public.lec__set_today())) as nw
            from public.lec_set xs
            join public.lec_set_prog xp on xp.set_id = xs.id and xp.sid = p_sid
           cross join lateral (select xp.cards -> (u.e ->> 'k') as card from jsonb_array_elements(xs.items) as u(e)) c
           where xs.kind in ('voc', 'gram') and public.lec__set_open(xs, p_cls)
             and coalesce(c.card ->> 'z', '') <> ''
           group by xs.id) y
$$;

-- 판 머리(폰이 보관함 줄에 씀): b 판 · no 몇째 판 · seed 섞는 씨앗(학생 + 세트 + 판 번호) · last 받은 가장 큰 순번 · today · ts 서버 시각 · bo 판 연 때
create or replace function public.lec__v2_head(p_run public.lec_set_run) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('b', p_run.id, 'md', p_run.md, 'no', p_run.no, 'seed', p_run.seed, 'last', p_run.last_i,
                            'today', to_char(public.lec__set_today(), 'YYYY-MM-DD'),
                            'ts', floor(extract(epoch from now()) * 1000)::bigint,
                            'bo', floor(extract(epoch from p_run.created_at) * 1000)::bigint)
$$;

-- 구문 쓰기 맞추기 글(class-api.js Lec.setSNormV2 와 같은 셈): «/» → 빈칸 · lec__set_norm · 부호 여덟(, . ? ! ; : " …) 지움 · 빈칸 하나로 · 앞뒤 빈칸
--   낱말 안 아포스트로피 · 하이픈 · 괄호는 그대로 셈(it's ≠ its · well-known ≠ well known · 결론안 여쭐 것 8 기본값)
create or replace function public.lec__set_snorm_v2(p_t text) returns text
language sql immutable set search_path = public as $$
  select btrim(regexp_replace(translate(public.lec__set_norm(replace(coalesce(p_t, ''), '/', ' ')), ',.?!;:"' || chr(8230), ''),
                              '[ ]+', ' ', 'g'), ' ')
$$;

-- 구문 쓰기 채점: 학생 답 1~400 글자 · 맞추기 글이 비지 않고 바른 답(«/» 를 빈칸으로 바꾼 원문)과 통째로 같으면 맞음(덩어리 하나만 = 틀림)
create or replace function public.lec__set_sent_v2(p_v text, p_ans text) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(char_length(p_v) between 1 and 400, false)
         and public.lec__set_snorm_v2(p_v) <> ''
         and public.lec__set_snorm_v2(p_v) = public.lec__set_snorm_v2(p_ans)
$$;

-- 단어 쓰기 «뜻 여럿»: 이 문항 영어와 맞으면 맞음 · 같은 세트에 뜻(맞추기 글 · 빈 뜻 빼고)이 같은 문항이 있으면 그 영어와 맞아도 맞음
--   맞음 셈은 lec__set_match 그대로(괄호 · «/» 다른 답) · 학생 답 1~200 글자
create or replace function public.lec__set_spell_v2(p_v text, p_items jsonb, p_k text) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(char_length(p_v) between 1 and 200, false) and exists (
    select 1
      from (select public.lec__set_norm(t.e ->> 'm') as nm
              from jsonb_array_elements(case when jsonb_typeof(p_items) = 'array' then p_items else '[]'::jsonb end) as t(e)
             where t.e ->> 'k' = p_k
             limit 1) x
     cross join lateral jsonb_array_elements(case when jsonb_typeof(p_items) = 'array' then p_items else '[]'::jsonb end) as o(e)
     where (o.e ->> 'k' = p_k or (x.nm <> '' and public.lec__set_norm(o.e ->> 'm') = x.nm))
       and public.lec__set_match(p_v, o.e ->> 'w'))
$$;

-- 학생: 목록 v2 = lec_set_home 그대로 + v2(스위치) · ts(서버 시각 ms) · todo(오늘 볼 것 · 지금은 쌓인 오답 수)
--   p_box = 폰 보관함 남은 줄 {n, age(ms)} · 남은 줄이 있으면 lec_v2_box 에 적고 0 이면 지움(잃은 답 재기)
create or replace function public.lec_set_home_v2(p_key text, p_box jsonb default null)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  v_r    jsonb;
  v_n    bigint;
  v_age  bigint;
begin
  v_r := public.lec_set_home(p_key);
  if (v_r ->> 'ok') is distinct from 'true' then
    return v_r;
  end if;
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if jsonb_typeof(p_box) = 'object' then
    v_n := public.lec__v2_num(p_box ->> 'n', 1000000);
    v_age := public.lec__v2_num(p_box ->> 'age', 31536000000);
    if coalesce(v_n, 0) > 0 then
      insert into public.lec_v2_box (sid, n, age, at) values (k.sid, v_n, coalesce(v_age, 0), now())
      on conflict (sid) do update set n = excluded.n, age = excluded.age, at = excluded.at;
    else
      delete from public.lec_v2_box xb where xb.sid = k.sid;
    end if;
  end if;
  return v_r || jsonb_build_object('v2', public.lec__v2_sw(), 'ts', floor(extract(epoch from now()) * 1000)::bigint,
                                   'todo', case when coalesce((public.lec__v2_sw() ->> 'eval')::boolean, false)
                                                     and coalesce((public.lec__v2_sw() ->> 'review')::boolean, false)
                                                then public.lec__v2_sum(k.sid, k.cls)   -- V2-3 오늘 볼 것(n · day · ex · kd) · 끄면 V2-1 그대로
                                                else jsonb_build_object('n', coalesce(v_r #> '{due,n}', '0'::jsonb)) end);
end
$$;

-- 학생: v2 연습 판 열기(eval 스위치가 켜졌을 때만 · 끄면 'off' = 화면은 옛 함수로) · 오늘 끝나지 않은 같은 판이 있으면 이어서(닫힌 판은 안 이음)
--   mem = 외우기(lec_set_items 그대로 · 숨김 · 다른 반 · 문법 · 단어 시험이 열려 있으면 testing) + 판 머리
--   due = 쌓인 오답(lec_set_due 와 같은 고름 · 20개 · 하루 10판 · 열린 평가 세트 문항 뺌) + 판 머리 · 연습이라 바른 답을 같이 줌(폰이 채점 · 서버가 다시 채점)
create or replace function public.lec_set_open_v2(p_key text, p_set uuid, p_md text)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  rn     public.lec_set_run;
  v_day  date := public.lec__set_today();
  v_r    jsonb;
  v_qs   jsonb;
  v_no   integer;
  v_cnt  integer;
  v_o2   jsonb;  -- V2-5
begin
  if not coalesce((public.lec__v2_sw() ->> 'eval')::boolean, false) then
    return jsonb_build_object('ok', false, 'err', 'off');
  end if;
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  if p_md is distinct from 'mem' and p_md is distinct from 'due'
     and not coalesce(p_md in ('spell', 'guw', 'gram', 'review'), false) then   -- V2-3 새 판 넷
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  perform pg_advisory_xact_lock(hashtext('lec_v2|' || k.sid));
  if p_md in ('spell', 'guw', 'gram', 'review') then   -- V2-3 새 판 = lec__v2_open3 한 곳(그 모드 스위치 · 판 꾸리기)
    return public.lec__v2_open3(k, p_set, p_md);
  end if;
  if p_md = 'mem' then
    v_r := public.lec_set_items(p_key, p_set);
    if (v_r ->> 'ok') is distinct from 'true' then
      return v_r;
    end if;
    select * into rn from public.lec_set_run xr
     where xr.sid = k.sid and xr.set_id = p_set and xr.md = 'mem' and xr.day = v_day and xr.end_n is null and xr.shut = '{}'::jsonb
     order by xr.created_at desc limit 1;
    if not found then
      select coalesce(max(xr.no), 0) + 1 into v_no from public.lec_set_run xr
       where xr.sid = k.sid and xr.set_id = p_set and xr.md = 'mem';
      insert into public.lec_set_run (sid, set_id, md, no, day, seed)
      values (k.sid, p_set, 'mem', v_no, v_day, hashtext(k.sid || '|' || p_set::text || '|' || v_no::text))
      returning * into rn;
    end if;
    -- V2-5: 켜진 인정 답 {열쇠: [맞춤 글]}(있을 때만 · 폰 채점 = 서버 채점)
    if to_regprocedure('public.lec__v2_ok2s(uuid)') is not null then
      v_o2 := public.lec__v2_ok2s(p_set);
      if v_o2 <> '{}'::jsonb then
        v_r := v_r || jsonb_build_object('ok2', v_o2);
      end if;
    end if;
    return v_r || public.lec__v2_head(rn);
  end if;
  select * into rn from public.lec_set_run xr
   where xr.sid = k.sid and xr.md = 'due' and xr.day = v_day and xr.end_n is null and xr.shut = '{}'::jsonb
   order by xr.created_at desc limit 1;
  if not found then
    select count(*) into v_cnt from public.lec_set_run xr where xr.sid = k.sid and xr.md = 'due' and xr.day = v_day;
    if v_cnt >= 10 then
      return jsonb_build_object('ok', false, 'err', 'limit');
    end if;
    select coalesce(jsonb_agg(z.q order by z.zz, z.on_ desc, z.cr desc, z.o), '[]'::jsonb) into v_qs
      from (select jsonb_build_object(
                     'k', u.e ->> 'k', 's', xs.id,
                     'f', case when xs.kind = 'voc' then 'w' when public.lec__set_opts(u.e ->> 's') is null then 'r' else 'c' end) as q,
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
      return jsonb_build_object('ok', true, 'b', null, 'n', 0, 'q', '[]'::jsonb, 'today', to_char(v_day, 'YYYY-MM-DD'));
    end if;
    select count(*) + 1 into v_no from public.lec_set_run xr where xr.sid = k.sid and xr.md = 'due';
    insert into public.lec_set_run (sid, set_id, md, no, day, n, qs, seed)
    values (k.sid, null, 'due', v_no, v_day, jsonb_array_length(v_qs), v_qs, hashtext(k.sid || '||' || v_no::text))
    returning * into rn;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           's', xs.id, 'k', q.e ->> 'k', 'kd', xs.kind, 't', xs.title, 'f', q.e ->> 'f',
           'p', case when xs.kind = 'voc' then it.e ->> 'm' else it.e ->> 's' end,
           'o', case when xs.kind = 'voc' then null else to_jsonb(public.lec__set_opts(it.e ->> 's')) end,
           'a', case when xs.kind = 'voc' then it.e ->> 'w' else it.e ->> 'a' end,
           'x', case when xs.kind = 'voc' then '' else coalesce(it.e ->> 'x', '') end,
           'pt', case when xs.kind = 'voc' then '' else coalesce(it.e ->> 'p', '') end) order by q.o), '[]'::jsonb)
    into v_r
    from jsonb_array_elements(rn.qs) with ordinality as q(e, o)
    join public.lec_set xs on xs.id = (q.e ->> 's')::uuid
   cross join lateral (select y.e from jsonb_array_elements(xs.items) as y(e) where y.e ->> 'k' = q.e ->> 'k' limit 1) it
   where public.lec__set_open(xs, k.cls) and not public.lec__set_busy(k.sid, xs.id) and not (rn.shut ? xs.id::text);
  if to_regprocedure('public.lec__v2_ok2q(jsonb)') is not null then  -- V2-5: 쓰기 문항에 켜진 인정 답 a2(있을 때만)
    v_r := public.lec__v2_ok2q(v_r);
  end if;
  return jsonb_build_object('ok', true, 'n', jsonb_array_length(v_r), 'q', v_r, 'title', '쌓인 오답') || public.lec__v2_head(rn);
end
$$;

-- 학생: 답 줄 보내기(폰 보관함 · 한 번에 100 줄 · 60KB 까지) → got = 보낸 줄 가운데 표에 있는 id 전부(전에 받은 것 포함) · bad = 꼴 틀린 줄(버림)
--   v2 연습 판 줄 = 답한 때 · 서버 채점 → 표(같은 id 는 한 번만) → 새 줄만 (판 연 때 · 판 · 순번) 차례로 카드에 반영 · 스위치를 꺼도 이미 연 판은 받아 반영
--   평가 판(시험 · 드릴) 줄 = lec_set_save_v2 와 같음 · 그 밖 판(폰이 만든 판 · 옛 판 · log 단계) = 기록만(카드는 옛 함수가 바꿈)
--   평가가 열린 세트의 줄 · 닫힌 뒤 답 = 기록만(shut) · 하루 반영 한도(lec_v2_cfg.lim)를 넘은 줄 = 기록만(lim) · 응답에 바른 답 0
create or replace function public.lec_set_log_v2(p_key text, p_rows jsonb)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  s      public.lec_set;
  rn     public.lec_set_run;
  v_cl   text;
  v_e    jsonb;
  v_r    jsonb;
  v_ok   jsonb := '[]'::jsonb;
  v_bad  jsonb := '[]'::jsonb;
  v_new  text[] := '{}';
  v_b    text;
  v_it   jsonb;
  v_q    jsonb;
  v_f    text;
  v_v    text;
  v_sr   boolean;
  v_okr  boolean;
  v_src  text;
  v_v1   boolean;
  v_why  text;
  v_ta   timestamptz;
  v_set  uuid;
  v_lim  integer;
  v_lday date;
  v_lcnt integer := 0;
  v_id   text;
  v_day  date;
  v_sets uuid[] := '{}';
  v_me   jsonb;
  v_o2   bigint;  -- V2-5
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  if jsonb_array_length(p_rows) > 100 or octet_length(p_rows::text) > 61440 then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  v_cl := coalesce(k.cls[1], '');
  select c.lim into v_lim from public.lec_v2_cfg c where c.id = 1;
  v_lim := coalesce(v_lim, 3000);
  perform pg_advisory_xact_lock(hashtext('lec_v2|' || k.sid));
  -- 1) 꼴 검사
  for v_e in select x.e from jsonb_array_elements(p_rows) as x(e) loop
    v_r := public.lec__v2_row(v_e);
    if v_r is null then
      if jsonb_typeof(v_e) = 'object' and jsonb_typeof(v_e -> 'id') = 'string' then
        v_bad := v_bad || jsonb_build_array(left(v_e ->> 'id', 40));
      end if;
    else
      v_ok := v_ok || jsonb_build_array(v_r);
    end if;
  end loop;
  -- 2) 판마다
  for v_b in select distinct x.e ->> 'b' from jsonb_array_elements(v_ok) as x(e) loop
    select * into rn from public.lec_set_run xr where xr.id = v_b::uuid and xr.sid = k.sid;
    if not found then
      if exists (select 1 from public.lec_set_try xt where xt.id = v_b::uuid and xt.sid = k.sid and xt.kind in ('test', 'drill')) then
        perform public.lec__v2_ev(k.sid, v_cl, v_b::uuid,
                                  (select jsonb_agg(x.e) from jsonb_array_elements(v_ok) as x(e) where x.e ->> 'b' = v_b));
      else
        insert into public.lec_set_log (id, sid, cl, b, bk, i, n, set_id, k, f, v, h, ms, nx, om, pr, ago, ta, day, pt, st, bo, why)
        select x.e ->> 'id', k.sid, v_cl, v_b::uuid, 'log', (x.e ->> 'i')::integer, (x.e ->> 'n')::integer,
               (x.e ->> 's')::uuid, x.e ->> 'k', x.e ->> 'f', x.e ->> 'v', (x.e ->> 'h')::boolean,
               (x.e ->> 'ms')::integer, (x.e ->> 'nx')::integer, (x.e ->> 'om')::integer, (x.e ->> 'pr')::boolean,
               (x.e ->> 'ago')::bigint, public.lec__v2_ta((x.e ->> 'ago')::bigint, null),
               (public.lec__v2_ta((x.e ->> 'ago')::bigint, null) at time zone 'Asia/Seoul')::date,
               (x.e ->> 'pt')::bigint, x.e ->> 'st', public.lec__v2_ta((x.e ->> 'ago')::bigint, null), 'log'
          from jsonb_array_elements(v_ok) as x(e)
         where x.e ->> 'b' = v_b
        on conflict (id) do nothing;
      end if;
      continue;
    end if;
    if rn.md = 'mem' then
      select * into s from public.lec_set xs where xs.id = rn.set_id;
    end if;
    for v_e in select x.e from jsonb_array_elements(v_ok) as x(e) where x.e ->> 'b' = v_b order by (x.e ->> 'i')::integer, (x.e ->> 'ago')::bigint desc, x.e ->> 'id' loop
      v_ta := public.lec__v2_ta((v_e ->> 'ago')::bigint, rn.created_at);
      v_why := '';
      v_sr := null;
      v_okr := false;
      v_src := '';
      v_v1 := false;
      v_it := null;
      v_f := v_e ->> 'f';
      v_v := v_e ->> 'v';
      if rn.md = 'mem' then
        v_set := rn.set_id;
        if s.id is null or not public.lec__set_open(s, k.cls) or s.kind = 'gram' then
          v_why := 'gone';
        else
          select y.e into v_it from jsonb_array_elements(s.items) as y(e) where y.e ->> 'k' = (v_e ->> 'k') limit 1;
          if v_it is null then
            v_why := 'gone';
          elsif v_f = 'k' and (v_v in ('0', '1') or (s.kind = 'gu' and v_v = '2')) then
            v_okr := v_v in ('1', '2');
            v_sr := v_okr;
            v_v1 := v_v = '2';
            v_src := case when s.kind = 'voc' then 'card' else 'say' end;
          elsif v_f = 'sp' and s.kind = 'voc' then
            v_sr := not (v_e ->> 'lg')::boolean and public.lec__set_spell_v2(v_v, s.items, v_e ->> 'k');
            v_okr := v_sr and not (v_e ->> 'h')::boolean;
            v_src := 'card';
          elsif v_f = 'se' and s.kind = 'gu' then
            v_sr := not (v_e ->> 'lg')::boolean and public.lec__set_sent_v2(v_v, v_it ->> 'e');
            v_okr := v_sr and not (v_e ->> 'h')::boolean;
            v_src := 'say';
          else
            v_why := 'gone';
          end if;
        end if;
      elsif rn.md <> 'due' then   -- V2-3 새 판(spell · guw · gram · review) 채점 = lec__v2_judge 한 곳
        v_q := public.lec__v2_judge(rn, k.cls, v_e);
        v_set := (v_q ->> 's')::uuid;
        v_why := v_q ->> 'why';
        v_f := v_q ->> 'f';
        v_sr := (v_q ->> 'sr')::boolean;
        v_okr := coalesce((v_q ->> 'ok')::boolean, false);
        v_src := coalesce(v_q ->> 'src', '');
        if v_why = '' then   -- V2-35 아래 V2-5 인정 답(sp · se · r)이 세트 종류(s.kind)를 읽음 · 이 판 줄의 세트로
          select * into s from public.lec_set xs where xs.id = v_set;
        end if;
      else
        v_set := case when (v_e ->> 's') is not null then (v_e ->> 's')::uuid end;
        select q.e into v_q from jsonb_array_elements(rn.qs) as q(e)
         where q.e ->> 's' = (v_e ->> 's') and q.e ->> 'k' = (v_e ->> 'k') limit 1;
        if v_q is null then
          v_why := 'gone';
        else
          select * into s from public.lec_set xs where xs.id = v_set;
          if not found or not public.lec__set_open(s, k.cls) then
            v_why := 'gone';
          else
            select y.e into v_it from jsonb_array_elements(s.items) as y(e) where y.e ->> 'k' = (v_e ->> 'k') limit 1;
            if v_it is null then
              v_why := 'gone';
            else
              v_f := v_q ->> 'f';
              if v_f = 'c' then
                v_sr := public.lec__set_norm(v_v) = public.lec__set_norm(v_it ->> 'a');
              else
                v_sr := public.lec__set_match(v_v, case when s.kind = 'voc' then v_it ->> 'w' else v_it ->> 'a' end);
              end if;
              v_sr := coalesce(v_sr, false) and not (v_e ->> 'lg')::boolean and btrim(v_v) <> '';
              v_okr := v_sr and not (v_e ->> 'h')::boolean;
              v_src := 'due';
            end if;
          end if;
        end if;
      end if;
      -- V2-5: 쓰기 답(단어 sp · 구문 se · 쌓인 오답 w · r)이 틀렸으면 켜진 인정 답(V2-5 절이 있을 때만 · 400자 넘는 답 빼고)
      v_o2 := null;
      if v_why = '' and v_sr is false and v_f in ('sp', 'se', 'w', 'r') and not (v_e ->> 'lg')::boolean
         and to_regprocedure('public.lec__v2_ok2id(uuid,text,text,text)') is not null then
        v_o2 := public.lec__v2_ok2id(v_set, v_e ->> 'k', s.kind, v_v);
        if v_o2 is not null then
          v_sr := true;
          v_okr := not (v_e ->> 'h')::boolean;
        end if;
      end if;
      -- 평가를 연 세트(닫은 뒤 답 · 지금 열린 시험 · 드릴) = 기록만(바른 답 엿보기 막기 · 옛 lec_set_ans 의 testing 과 같은 뜻)
      if v_why = '' and ((rn.shut ? v_set::text and v_ta >= (rn.shut ->> v_set::text)::timestamptz)
                         or public.lec__set_busy(k.sid, v_set)) then
        v_why := 'shut';
      end if;
      insert into public.lec_set_log (id, sid, cl, b, bk, i, n, set_id, k, f, v, h, ms, nx, om, pr, sr, ok, src, v1,
                                      ago, ta, day, pt, st, bo, why)
      values (v_e ->> 'id', k.sid, v_cl, rn.id, rn.md, (v_e ->> 'i')::integer, (v_e ->> 'n')::integer, v_set,
              v_e ->> 'k', coalesce(v_f, ''), v_v, (v_e ->> 'h')::boolean, (v_e ->> 'ms')::integer, (v_e ->> 'nx')::integer,
              (v_e ->> 'om')::integer, (v_e ->> 'pr')::boolean, v_sr, v_okr, v_src, v_v1,
              (v_e ->> 'ago')::bigint, v_ta, (v_ta at time zone 'Asia/Seoul')::date, (v_e ->> 'pt')::bigint, v_e ->> 'st',
              rn.created_at, v_why)
      on conflict (id) do nothing;
      if found and v_o2 is not null then  -- V2-5: 채점 때 인정 답으로 맞음 표시
        insert into public.lec_set_fix (ok2, log_id, ok, g) values (v_o2, v_e ->> 'id', true, true);
      end if;
      if found and v_why = '' then
        v_new := v_new || (v_e ->> 'id');
      end if;
    end loop;
    update public.lec_set_run xr
       set last_i = greatest(xr.last_i, (select max((x.e ->> 'i')::integer) from jsonb_array_elements(v_ok) as x(e) where x.e ->> 'b' = v_b)),
           end_n = greatest(xr.end_n, (select max((x.e ->> 'n')::integer) from jsonb_array_elements(v_ok) as x(e) where x.e ->> 'b' = v_b))
     where xr.id = rn.id;
  end loop;
  -- 3) 새 줄만 (판 연 때 · 판 · 순번) 차례로 카드에 반영 · 하루 반영 한도(연습 줄만 셈)
  for v_id, v_day, v_set in
    select xl.id, xl.day, xl.set_id from public.lec_set_log xl
     where xl.id = any (v_new) order by xl.bo, xl.b, xl.i, xl.id, xl.id
  loop
    if v_lday is distinct from v_day then
      select count(*) into v_lcnt from public.lec_set_log xl
       where xl.day = v_day and xl.sid = k.sid and xl.done and xl.bk in ('mem', 'due', 'spell', 'guw', 'gram', 'review');   -- V2-3
      v_lday := v_day;
    end if;
    if v_lcnt >= v_lim then
      update public.lec_set_log xl set why = 'lim' where xl.id = v_id;
    elsif public.lec__v2_apply(v_id) = 'ok' then
      v_lcnt := v_lcnt + 1;
      if not (v_set = any (v_sets)) then
        v_sets := v_sets || v_set;
      end if;
    end if;
  end loop;
  -- 4) 답(바른 답 0): got · bad · 반영한 세트의 요약(lec__set_me) · 목록 쌓인 오답 수
  select coalesce(jsonb_agg(xl.id), '[]'::jsonb) into v_r
    from public.lec_set_log xl
   where xl.sid = k.sid and xl.id in (select x.e ->> 'id' from jsonb_array_elements(v_ok) as x(e));
  select coalesce(jsonb_object_agg(xs.id::text, public.lec__set_me(xs, k.sid, public.lec__set_today())), '{}'::jsonb) into v_me
    from public.lec_set xs where xs.id = any (v_sets);
  return jsonb_build_object('ok', true, 'got', v_r, 'bad', v_bad, 'me', v_me, 'due', public.lec__v2_due(k.sid, k.cls));
end
$$;

-- 학생: 평가(단어 시험 · 문법 드릴) 열기 v2(eval 스위치가 켜졌을 때만 · 끄면 'off') = lec_set_test 그대로 열고(하루 한도 · 통과 · 이어서 같음)
--   응답에 바른 답 칸 0(done 을 빼고 sv = 서버에 저장된 내 임시 답 [{i, v}] 만) · 이 세트의 연습 판을 닫음(그 뒤 답은 기록만)
create or replace function public.lec_set_test_v2(p_key text, p_set uuid)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  t      public.lec_set_try;
  v_r    jsonb;
begin
  if not coalesce((public.lec__v2_sw() ->> 'eval')::boolean, false) then
    return jsonb_build_object('ok', false, 'err', 'off');
  end if;
  v_r := public.lec_set_test(p_key, p_set);
  if (v_r ->> 'ok') is distinct from 'true' then
    return v_r;
  end if;
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  select * into t from public.lec_set_try xt where xt.id = (v_r ->> 'try')::uuid;
  update public.lec_set_run xr set shut = xr.shut || jsonb_build_object(p_set::text, now())
   where xr.sid = k.sid and xr.day >= public.lec__set_today() - 14 and not (xr.shut ? p_set::text)
     and (xr.set_id = p_set or (xr.md in ('due', 'review') and xr.qs @> jsonb_build_array(jsonb_build_object('s', p_set))));   -- V2-3 오늘 볼 것 판도
  return (v_r - 'done') || jsonb_build_object(
           'sv', (select coalesce(jsonb_agg(jsonb_build_object('i', v.i - 1, 'v', v.a ->> 'v') order by v.i), '[]'::jsonb)
                    from jsonb_array_elements(t.ans) with ordinality as v(a, i) where jsonb_typeof(v.a) = 'object'),
           'ts', floor(extract(epoch from now()) * 1000)::bigint,
           'bo', floor(extract(epoch from t.created_at) * 1000)::bigint);
end
$$;

-- 학생: 평가 중간 저장(50 문항마다 · 숨길 때) = 빈 칸만 채우고 서버가 채점 · 응답에 바른 답 · 맞음 0(got · bad · left · done 만)
create or replace function public.lec_set_save_v2(p_key text, p_try uuid, p_rows jsonb)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  t      public.lec_set_try;
  v_r    jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into t from public.lec_set_try xt where xt.id = p_try and xt.sid = k.sid and xt.kind in ('test', 'drill');
  if not found then
    return jsonb_build_object('ok', false, 'err', 'try');
  end if;
  v_r := public.lec__v2_take(k.sid, coalesce(k.cls[1], ''), p_try, p_rows);
  if (v_r ->> 'ok') is distinct from 'true' then
    return v_r;
  end if;
  select * into t from public.lec_set_try xt where xt.id = p_try;
  return v_r || jsonb_build_object('left', t.n - t.got, 'done', t.done_at is not null);
end
$$;

-- 학생: 평가 내기 = 빈 칸만 채우고 채점 → 다 찼으면 결과(lec__set_end) · 바른 답(ans = 답한 칸 [{i, v, r, a, x, pt}]) · 목록 숫자(me · due)
--   이미 끝난 판을 다시 내면 같은 결과 · 덜 찼으면 done false · left · miss(빈 칸 차례)
create or replace function public.lec_set_send_v2(p_key text, p_try uuid, p_rows jsonb)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  k      public.lec_key;
  s      public.lec_set;
  t      public.lec_set_try;
  v_r    jsonb;
begin
  select * into k from public.lec_key where kh = public.lec__kh(p_key);
  if not found then
    return jsonb_build_object('ok', false, 'err', 'key');
  end if;
  if not public.lec__agreed(k.sid) then
    return jsonb_build_object('ok', false, 'err', 'consent');
  end if;
  select * into t from public.lec_set_try xt where xt.id = p_try and xt.sid = k.sid and xt.kind in ('test', 'drill');
  if not found then
    return jsonb_build_object('ok', false, 'err', 'try');
  end if;
  v_r := public.lec__v2_take(k.sid, coalesce(k.cls[1], ''), p_try, p_rows);
  if (v_r ->> 'ok') is distinct from 'true' then
    return v_r;
  end if;
  select * into t from public.lec_set_try xt where xt.id = p_try;
  if t.done_at is null then
    return v_r || jsonb_build_object('done', false, 'left', t.n - t.got,
             'miss', (select coalesce(jsonb_agg(v.i - 1 order by v.i), '[]'::jsonb)
                        from jsonb_array_elements(t.ans) with ordinality as v(a, i) where jsonb_typeof(v.a) is distinct from 'object'));
  end if;
  select * into s from public.lec_set xs where xs.id = t.set_id;
  return v_r || jsonb_build_object('done', true, 'end', public.lec__set_end(t, k.sid, k.cls),
                                   'ans', public.lec__set_view(t, null) -> 'done',
                                   'me', case when s.id is null then null else public.lec__set_me(s, k.sid, public.lec__set_today()) end,
                                   'due', public.lec__v2_due(k.sid, k.cls));
end
$$;

-- 선생님: v2 지켜보기(원장님 · 선생님만 · 읽기만 · 학생 이름 없음) · p_days 날(1~60 · 비면 14)
--   days = 날마다 줄 수 · 반영 · 늦은 줄 · 까닭별 · 폰≠서버 판정(cmp 견준 줄 · diff 다른 줄) · 잃은 답(7일 넘은 판의 빈 순번) · 판 열기 · 다음 문항 p95(ms)
--   calls = 반 · 날짜별 호출 수(줄이 들어간 부름 = 묶음 번호 수) · box = 폰 보관함에 줄이 남은 학생 수 · 남은 줄 · 가장 오래된 줄 나이(ms)
create or replace function public.lec_v2_watch(p_days integer default 14)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_to    date := public.lec__set_today();
  v_from  date;
  v_days  jsonb;
  v_calls jsonb;
  v_box   jsonb;
begin
  if not (public.lec_set_is_admin() or public.lec__is_staff()) then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  v_from := v_to - least(greatest(coalesce(p_days, 14), 1), 60);
  select coalesce(jsonb_agg(jsonb_build_object(
           'day', d.day, 'rows', d.n, 'done', d.dn, 'late', d.lt, 'why', d.wy, 'cmp', d.cmp, 'diff', d.df,
           'lost', coalesce(lo.n, 0), 'om95', d.om95, 'nx95', d.nx95) order by d.day), '[]'::jsonb)
    into v_days
    from (select xl.day, count(*) as n, count(*) filter (where xl.done) as dn, count(*) filter (where xl.late) as lt,
                 jsonb_build_object('log', count(*) filter (where xl.why = 'log'), 'lim', count(*) filter (where xl.why = 'lim'),
                                    'shut', count(*) filter (where xl.why = 'shut'), 'gone', count(*) filter (where xl.why = 'gone'),
                                    'done', count(*) filter (where xl.why = 'done')) as wy,
                 count(*) filter (where xl.pr is not null and xl.sr is not null) as cmp,
                 count(*) filter (where xl.pr is not null and xl.sr is not null and xl.pr <> xl.sr) as df,
                 percentile_cont(0.95) within group (order by xl.om::double precision) as om95,
                 percentile_cont(0.95) within group (order by xl.nx::double precision) as nx95
            from public.lec_set_log xl
           where xl.day >= v_from
           group by xl.day) d
    left join (select x.day, sum(x.miss)::integer as n
                 from (select min(xl.day) as day, greatest(coalesce(max(xl.n), 0), max(xl.i)) - count(distinct xl.i) as miss
                         from public.lec_set_log xl
                        where xl.day >= v_from - 7
                        group by xl.b) x
                where x.day < v_to - 7 and x.miss > 0
                group by x.day) lo on lo.day = d.day;
  select coalesce(jsonb_agg(jsonb_build_object('cl', c.cl, 'day', c.day, 'n', c.n) order by c.day, c.cl), '[]'::jsonb) into v_calls
    from (select xl.cl, (xl.at at time zone 'Asia/Seoul')::date as day, count(distinct xl.bn) as n
            from public.lec_set_log xl
           where xl.day >= v_from - 14 and (xl.at at time zone 'Asia/Seoul')::date >= v_from
           group by 1, 2) c;
  select jsonb_build_object('who', count(*), 'n', coalesce(sum(xb.n), 0), 'age', coalesce(max(xb.age), 0), 'at', max(xb.at))
    into v_box
    from public.lec_v2_box xb;
  return jsonb_build_object('ok', true, 'from', v_from, 'to', v_to, 'sw', public.lec__v2_sw(),
                            'days', v_days, 'calls', v_calls, 'box', v_box);
end
$$;

-- 권한: 속 함수 = 밖에서 못 부름 · 학생 함수 여섯 = 누구나(열쇠로 확인) · 지켜보기 = 로그인한 사람만(안에서 원장님 · 선생님 확인)
revoke all on function public.lec__v2_mv(), public.lec__v2_gone(), public.lec__v2_sw(), public.lec__v2_num(text, bigint),
  public.lec__v2_row(jsonb), public.lec__v2_ta(bigint, timestamptz), public.lec__v2_last(jsonb),
  public.lec__v2_mk(jsonb, boolean, text, boolean, date), public.lec__v2_apply(text), public.lec__v2_ev(text, text, uuid, jsonb),
  public.lec__v2_take(text, text, uuid, jsonb), public.lec__v2_due(text, text[]), public.lec__v2_head(public.lec_set_run),
  public.lec__set_snorm_v2(text), public.lec__set_sent_v2(text, text), public.lec__set_spell_v2(text, jsonb, text)
  from public, anon, authenticated;
revoke all on function public.lec_set_home_v2(text, jsonb), public.lec_set_open_v2(text, uuid, text), public.lec_set_log_v2(text, jsonb),
  public.lec_set_test_v2(text, uuid), public.lec_set_save_v2(text, uuid, jsonb), public.lec_set_send_v2(text, uuid, jsonb)
  from public;
grant execute on function public.lec_set_home_v2(text, jsonb), public.lec_set_open_v2(text, uuid, text), public.lec_set_log_v2(text, jsonb),
  public.lec_set_test_v2(text, uuid), public.lec_set_save_v2(text, uuid, jsonb), public.lec_set_send_v2(text, uuid, jsonb)
  to anon, authenticated;
revoke all on function public.lec_v2_watch(integer) from public, anon;
grant execute on function public.lec_v2_watch(integer) to authenticated;

-- ---------------------------------------------------------------- V2-3 (11-20) 세트 학습 v2 학습 흐름 · 다시 보기 일정 · 오늘 볼 것 · 새 연습 판 · 열셋째 스스로 점검
-- 묶음 ③a 서버층(화면은 따로). 더하기만: 속 함수 lec__v2_* 열여섯(트리거 하나 포함) · 찾아보기 하나 · lec_v2_cfg 칸 하나(review_on) ·
--   트리거 하나 · 권한 · 열셋째 스스로 점검(이 절 맨 끝 do 블록).
--   V2-1 안을 넓힌 곳(줄마다 «-- V2-3» 꼬리표): lec_set_run.md · lec_set_log.bk 허용 값 · lec_set_home_v2 의 todo ·
--   lec_set_open_v2 새 판 넷(spell · guw · gram · review → lec__v2_open3) · lec_set_log_v2 새 판 채점(lec__v2_judge) · 하루 한도 셈 ·
--   lec_set_test_v2(오늘 볼 것 판도 닫음)
--   스위치(lec_v2_cfg): 새 판은 eval 과 그 판 스위치가 둘 다 켜졌을 때만 · 목록 todo 는 eval · review 가 둘 다 켜졌을 때만(끄면 V2-1 그대로)
-- 다시 보기 일정(저장하지 않고 부를 때마다 셈 · 흉내 저장소 class-mock.js 가 같은 셈 · 사례표 _check/class_v3_cases.json):
--   처음 배운 날 f = 그 문항 기록 줄(lec_set_log · 지운 문항 줄 뺌) 가운데 가장 이른 날 · 카드 날짜(d · y · t · z)가 더 이르면 그 날 ·
--     둘 다 없고 카드가 있으면 세트를 처음 연 날(first_at · 서울 날짜)
--   시험 = 세트 공개일이 «시험 날 − 70일 ~ 시험 끝 − 1일» 안인 내 학교 시험(그 세트 반의 줄 · 없으면 내 모든 줄) · 앞으로 올 것 가운데
--     가장 이른 것 · 없으면 가장 늦게 지난 것 · 시험 날 = D-9 링과 같은 일정(lec__sched · main · pt-etc 합침 · 학년 예외가 끝나지 않았으면
--     그것 · 아니면 학교 일정 · 시험 기간 첫날) · 다만 학년 예외가 D-20 보다 멀어도 학년 예외를 씀(링은 D-20 안 · 대비 시작부터 보임)
--   R = 시험 날 − f · 첫 = f + min(R/3, 7) · 둘째 = f + 2R/3(나머지 버림 · 최소 1일) · 마지막 = D-6 ~ D-2 를 같은 시험 문항들의 f 차례로
--     고르게(둘째보다 뒤 · 겹치면 다음 날 · D-2 를 넘으면 없음) · R ≤ 5 면 마지막만 · 같은 날은 하나 · 시험이 없으면 f + 1 · 3 · 7 ·
--     시험이 지나면 멈춤 · 그 날이 왔고 그 날 뒤로 아직 안 본(기록 줄 · 카드 날짜 없음) 가장 이른 날 하나 = 볼 날(놓친 날이 여럿이어도 한 번)
--   켠 날(lec_v2_cfg.review_on = review 를 마지막으로 끔 → 켬으로 바꾼 서버 날짜 · 트리거 lec__v2_revon 이 적음 · 다시 켜면 새 날 · 끄면 그대로):
--     그 날 앞 일정 날은 볼 날로 치지 않음(켜는 첫날 옛 세트 일정이 놓친 날로 몰리지 않게 · 놓친 날도 켠 날부터) · 시험 있는 세트 · 없는 세트 모두 ·
--     쌓인 오답 · 처음 배운 날 셈은 그대로 · 칸이 비면(켜 본 적 없음) 자르지 않음
-- 오늘 볼 것 =열린 세트 전부(시험 · 드릴을 연 세트 뺌) · 위 볼 날 + 쌓인 오답(단어 · 문법 z · lec__set_due_on 그대로) ·
--   차례 = 단어 → 구문 → 문법 · 놓친 날(gr 0) → 쌓인 오답(1) → 오늘 날(2) → 시험 지난 세트의 쌓인 오답(3) · 점수 · 통과 · 추천 칸 없음
-- 새 연습 판(판 꾸리기 규칙은 이 절 한 곳 · 폰은 받은 차례대로 · 바른 답을 같이 줌 · 지금 시험 · 드릴을 연 세트 문항은 판에서 뺌):
--   spell 단어 써 보기(sp · 카드 꼴 card = 맞으면 d 만 · 외움 뜻 그대로) · guw 구문 써 보기(gw · 줄 꼴 ar 배열 → se 통째 · say) ·
--   gram 문법(포인트 칸이 있으면 새 포인트 첫 판 = 그 포인트만 8문항까지 · 다음 판부터 배운 포인트를 돌아가며 · 같은 포인트의 안 본 문항 먼저 ·
--   쌓인 오답 먼저 · c 고르기 · r 쓰기) · review 오늘 볼 것 한 판(한 종류 · 20 · 단어 sp · 구문 se · 문법 c · r) ·
--   쌓인 오답 문항 = 카드 꼴 due(V2-1 쌓인 오답 판과 같음) · 그 밖 = card(구문 say) · 힌트 본 답 = 틀림(카드) ·
--   판 20 문항 · 하루 판 200 까지(판마다) · 줄 꼴 = V2-1 그대로(첫 답 = 판 · 문항마다 가장 작은 순번 · h 힌트 · f 단계 · ms)
-- 운영에 넣은 뒤 확인(SQL Editor 에서 · 바꾸는 것 없음):
--   select has_function_privilege('anon', 'public.lec__v2_todo(text, text[], jsonb, date, date)', 'execute') as "속 함수 밖에서 부름(false)";
--   select review, review_on from public.lec_v2_cfg;   -- 켠 날(review 를 켜면 그날 · 비어 있으면 자르지 않음)

-- 켠 날 칸(더하기만 · 비면 자르지 않음) · review 끔 → 켬이면 그날(서버 날짜 lec__set_today)을 적는 트리거(끄거나 다른 칸만 바꾸면 그대로)
alter table public.lec_v2_cfg add column if not exists review_on date;
create or replace function public.lec__v2_revon() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.review and not coalesce(old.review, false) then
    new.review_on := public.lec__set_today();
  end if;
  return new;
end
$$;
create or replace trigger lec_v2_cfg_revon before update on public.lec_v2_cfg
  for each row execute function public.lec__v2_revon();

-- 일정 날짜 칸 → 날짜(앱 examNorm 과 같은 셈: 숫자 무리 넷 · 두 자리 이하 · 두 자리 이하 또는 여덟 자리 하나 · 2000~2100 · 없는 날 null)
create or replace function public.lec__v2_enorm(p jsonb) returns date
language plpgsql immutable set search_path = public as $$
declare
  v_a  text[];
begin
  v_a := array(select x.v
                 from regexp_split_to_table(case jsonb_typeof(p) when 'string' then p #>> '{}' when 'number' then p #>> '{}'
                                                 when 'array' then p::text else '' end, '[^0-9]+') with ordinality as x(v, o)
                where x.v <> '' order by x.o);
  if cardinality(v_a) = 1 and char_length(v_a[1]) = 8 then
    v_a := array[left(v_a[1], 4), substr(v_a[1], 5, 2), substr(v_a[1], 7, 2)];
  elsif not (cardinality(v_a) = 3 and char_length(v_a[1]) = 4 and char_length(v_a[2]) <= 2 and char_length(v_a[3]) <= 2) then
    return null;
  end if;
  if v_a[2]::integer not between 1 and 12 or v_a[3]::integer not between 1 and 31 or v_a[1]::integer not between 2000 and 2100 then
    return null;
  end if;
  return make_date(v_a[1]::integer, v_a[2]::integer, v_a[3]::integer);
exception when others then
  return null;
end
$$;

-- 학년(앱 stuGrade 와 같은 셈 · 반 줄 {g, ig, s, is, cn}): 학년 칸(거짓이면 접수 학년) 끝 숫자 → 학교 이름 뒤 숫자(1~6 · 앱 schoolDisp) →
--   반 이름(H · M · E + 숫자 · 고등 · 중등은 3 까지 · 학교 끝 글자와 맞아야 함 → 아니면 N학년) · 없으면 ''
create or replace function public.lec__v2_grade(p_me jsonb) returns text
language plpgsql immutable set search_path = public as $$
declare
  v_ws   text := '[' || chr(9) || chr(10) || chr(11) || chr(12) || chr(13) || chr(32) || chr(160) || chr(5760) || chr(8192) || '-' || chr(8202)
                 || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279) || ']*';
  v_g    jsonb;
  v_raw  text;
  v_x    text;
  v_sup  integer := 0;
  v_go   boolean := true;
  v_ch   integer;
  v_nm   text;
  v_k    text;
  v_m    text[];
begin
  if jsonb_typeof(p_me) is distinct from 'object' then
    return '';
  end if;
  v_g := case when public.lec__truthy(p_me -> 'g') then p_me -> 'g' when public.lec__truthy(p_me -> 'ig') then p_me -> 'ig' end;
  v_m := regexp_match(case jsonb_typeof(v_g) when 'string' then v_g #>> '{}' when 'number' then v_g #>> '{}'
                                             when 'array' then v_g::text else '' end, '([0-9])[^0-9]*$');
  if v_m is not null then
    return v_m[1];
  end if;
  v_raw := public.lec__stu_school(jsonb_build_object('school', p_me -> 's', 'intake', jsonb_build_object('school', p_me -> 'is')));
  v_x := v_raw;
  for i in 1 .. char_length(v_x) loop
    if ascii(substr(v_x, i, 1)) > 65535 then
      v_sup := v_sup + 1;
    end if;
  end loop;
  while v_go and char_length(v_x) + v_sup > 1 loop
    v_go := false;
    v_ch := ascii(right(v_x, 1));
    if v_ch between 48 and 57 or v_ch in (45, 46, 32) then
      v_x := left(v_x, -1); v_go := true; continue;
    end if;
    if char_length(v_x) + v_sup > 2 and right(v_x, 2) = '학년' then
      v_x := left(v_x, -2); v_go := true; continue;
    end if;
    if char_length(v_x) + v_sup > 2 and v_ch = ascii('반') and ascii(substr(v_x, char_length(v_x) - 1, 1)) between 48 and 57 then
      v_x := left(v_x, -1); v_go := true; continue;
    end if;
  end loop;
  v_x := btrim(v_x, chr(9) || chr(10) || chr(11) || chr(12) || chr(13) || chr(32) || chr(160) || chr(5760) ||
                    chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197) || chr(8198) || chr(8199) ||
                    chr(8200) || chr(8201) || chr(8202) || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279));
  if v_x <> '' and left(v_raw, char_length(v_x)) = v_x then
    v_m := regexp_match(substr(v_raw, char_length(v_x) + 1), '[1-6]');
    if v_m is not null then
      return v_m[1];
    end if;
  end if;
  v_nm := case when public.lec__truthy(p_me -> 'cn')
               then (case jsonb_typeof(p_me -> 'cn') when 'string' then p_me ->> 'cn' when 'number' then p_me ->> 'cn'
                                                     when 'array' then (p_me -> 'cn')::text else '' end)
               else '' end;
  if v_nm = '' then
    return '';
  end if;
  v_k := public.lec__skey(v_raw);
  v_m := regexp_match(v_nm, '([HMEhme])' || v_ws || '([1-6])');
  if v_m is not null then
    if (upper(v_m[1]) in ('H', 'M') and v_m[2] > '3')
       or (v_k <> '' and ((upper(v_m[1]) = 'H' and right(v_k, 1) <> '고') or (upper(v_m[1]) = 'M' and right(v_k, 1) <> '중')
                          or (upper(v_m[1]) = 'E' and right(v_k, 1) <> '초'))) then
      return '';
    end if;
    return v_m[2];
  end if;
  v_m := regexp_match(v_nm, '([1-6])' || v_ws || '학년');
  return coalesce(v_m[1], '');
end
$$;

-- 일정 한 칸의 고친 시각(수만 · 글자 수는 0 · 앱 pickT 는 '5' 꼴 글자도 수로 읽음 = 히즈북스는 늘 수로 씀)
create or replace function public.lec__v2_tnum(p jsonb) returns numeric
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(p -> 't') = 'number' then (p ->> 't')::numeric else 0 end
$$;

-- main · pt-etc 일정 칸 합치기(앱 joinV · mapMerge · pickT): pt-etc 가 없으면 main · main 이 없으면 pt-etc ·
--   같은 칸은 시각(t) 큰 쪽(같으면 pt-etc) · 둘 다 시각이 없으면 main(main 이 null 이면 pt-etc)
create or replace function public.lec__v2_join(p_m jsonb, p_e jsonb) returns jsonb
language sql immutable set search_path = public as $$
  select case when p_e is null or jsonb_typeof(p_e) = 'null'
                then (case when jsonb_typeof(p_m) = 'object' then p_m else '{}'::jsonb end)
              when p_m is null or jsonb_typeof(p_m) = 'null'
                then (case when jsonb_typeof(p_e) = 'object' then p_e else '{}'::jsonb end)
              else coalesce((select jsonb_object_agg(coalesce(a.key, b.key),
                                      case when a.key is null then b.value
                                           when b.key is null then a.value
                                           when public.lec__v2_tnum(a.value) <> 0 or public.lec__v2_tnum(b.value) <> 0
                                             then (case when public.lec__v2_tnum(b.value) >= public.lec__v2_tnum(a.value) then b.value else a.value end)
                                           when jsonb_typeof(a.value) = 'null' then b.value
                                           else a.value end)
                               from jsonb_each(case when jsonb_typeof(p_m) = 'object' then p_m else '{}'::jsonb end) as a
                               full join jsonb_each(case when jsonb_typeof(p_e) = 'object' then p_e else '{}'::jsonb end) as b
                                 on b.key = a.key), '{}'::jsonb) end
$$;

-- 내 학교 시험(lec__sched 답 하나 · 반 줄마다 · 학교 열쇠가 빈 줄 뺌) → [{cid, k, g, e 시험 날, end 시험 끝}] · 두 줄(main · pt-etc)을 다 못 읽었으면 []
--   고름 = 끝나지 않은 학년 예외 → 끝나지 않은 학교 일정 → 지난 학년 예외 → 지난 학교 일정(지운 칸 · 날짜가 틀린 칸 뺌)
create or replace function public.lec__v2_exams(p_sched jsonb, p_day date) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_m    jsonb;
  v_e    jsonb;
  v_es   jsonb;
  v_eg   jsonb;
  v_me   jsonb;
  v_k    text;
  v_g    text;
  v_rg   jsonb;
  v_rs   jsonb;
  v_gd   date;
  v_ge   date;
  v_sd   date;
  v_se   date;
  v_pd   date;
  v_pe   date;
  v_out  jsonb := '[]'::jsonb;
begin
  select x.r into v_m
    from jsonb_array_elements(case when jsonb_typeof(p_sched -> 'rows') = 'array' then p_sched -> 'rows' else '[]'::jsonb end)
         with ordinality as x(r, o)
   where jsonb_typeof(x.r) = 'object' and x.r ->> 'id' = 'main'
   order by x.o desc limit 1;
  select x.r into v_e
    from jsonb_array_elements(case when jsonb_typeof(p_sched -> 'rows') = 'array' then p_sched -> 'rows' else '[]'::jsonb end)
         with ordinality as x(r, o)
   where jsonb_typeof(x.r) = 'object' and x.r ->> 'id' = 'pt-etc'
   order by x.o desc limit 1;
  if v_m is null or v_e is null then
    return v_out;
  end if;
  v_es := public.lec__v2_join(v_m -> 'es', v_e -> 'es');
  v_eg := public.lec__v2_join(v_m -> 'eg', v_e -> 'eg');
  for v_me in
    select x.v
      from jsonb_array_elements(case when jsonb_typeof(p_sched -> 'me') = 'array' then p_sched -> 'me' else '[]'::jsonb end)
           with ordinality as x(v, o)
     where jsonb_typeof(x.v) = 'object'
     order by x.o
  loop
    v_k := public.lec__skey(public.lec__stu_school(jsonb_build_object('school', v_me -> 's',
                                                                      'intake', jsonb_build_object('school', v_me -> 'is'))));
    if v_k <> '' then
      v_g := public.lec__v2_grade(v_me);
      v_rg := case when v_g <> '' then v_eg -> (v_k || '|' || v_g) end;
      v_rs := v_es -> v_k;
      v_gd := case when jsonb_typeof(v_rg) = 'object' and not public.lec__truthy(v_rg -> 'del') then public.lec__v2_enorm(v_rg -> 'date') end;
      v_ge := greatest(v_gd, coalesce(public.lec__v2_enorm(v_rg -> 'end'), v_gd));
      v_sd := case when jsonb_typeof(v_rs) = 'object' and not public.lec__truthy(v_rs -> 'del') then public.lec__v2_enorm(v_rs -> 'date') end;
      v_se := greatest(v_sd, coalesce(public.lec__v2_enorm(v_rs -> 'end'), v_sd));
      v_pd := case when v_gd is not null and v_ge >= p_day then v_gd
                   when v_sd is not null and v_se >= p_day then v_sd
                   when v_gd is not null then v_gd
                   else v_sd end;
      v_pe := case when v_gd is not null and v_ge >= p_day then v_ge
                   when v_sd is not null and v_se >= p_day then v_se
                   when v_gd is not null then v_ge
                   else v_se end;
      if v_pd is not null then
        v_out := v_out || jsonb_build_array(jsonb_build_object(
                   'cid', case when jsonb_typeof(v_me -> 'cid') in ('string', 'number') then v_me ->> 'cid' end,
                   'k', v_k, 'g', v_g, 'e', to_char(v_pd, 'YYYY-MM-DD'), 'end', to_char(v_pe, 'YYYY-MM-DD')));
      end if;
    end if;
  end loop;
  return v_out;
end
$$;

-- 이 학생의 학교 시험(app_state 는 읽기만 · 본앱 일정을 푸는 lec__sched 를 한 번 부름 · 부르는 쪽이 요청마다 한 번만 부르고 값을 넘김)
create or replace function public.lec__v2_ex(p_sid text) returns jsonb
language sql stable set search_path = public as $$
  select public.lec__v2_exams(public.lec__sched((select a.data from public.app_state a where a.id = 'main'),
                                                (select a.data from public.app_state a where a.id = 'pt-etc'), p_sid),
                              public.lec__set_today())
$$;

-- 세트 하나의 시험(공개일 p_on · 세트 반 p_cls): 그 반 줄(없으면 모든 줄) 가운데 «시험 날 − 70 ~ 시험 끝 − 1» 안 →
--   앞으로 올 것 가운데 가장 이른 것 · 없으면 가장 늦게 지난 것 → {e, end} · 없으면 null
create or replace function public.lec__v2_exam_of(p_ex jsonb, p_on date, p_cls text[], p_day date) returns jsonb
language sql immutable set search_path = public as $$
  with c as (
    select (x.v ->> 'e')::date as e, (x.v ->> 'end')::date as d2, x.v ->> 'cid' as cid
      from jsonb_array_elements(case when jsonb_typeof(p_ex) = 'array' then p_ex else '[]'::jsonb end) as x(v)
  ),
  w as (
    select c.e, c.d2
      from c
     where (c.cid = any (p_cls) or not exists (select 1 from c as c2 where c2.cid = any (p_cls)))
       and p_on between c.e - 70 and c.d2 - 1
  )
  select jsonb_build_object('e', to_char(w.e, 'YYYY-MM-DD'), 'end', to_char(w.d2, 'YYYY-MM-DD'))
    from w
   order by (w.e > p_day) desc, (case when w.e > p_day then w.e end), w.e desc, w.d2 desc
   limit 1
$$;

-- 카드에 적힌 가장 이른 날(d · t · z · y) · 없으면 ''(lec__v2_last 의 거꿀)
create or replace function public.lec__v2_first(p_c jsonb) returns text
language sql immutable set search_path = public as $$
  select coalesce(min(x.v), '')
    from (select jsonb_array_elements_text(case when jsonb_typeof(p_c -> 'd') = 'array' then p_c -> 'd' else '[]'::jsonb end) as v
          union all
          select jsonb_array_elements_text(case when jsonb_typeof(p_c -> 'y') = 'array' then p_c -> 'y' else '[]'::jsonb end)
          union all
          select p_c ->> 't'
          union all
          select p_c ->> 'z') x
   where x.v ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
$$;

-- 다시 볼 날(p_f 처음 배운 날 · p_e 시험 날 · p_r 같은 시험 문항 가운데 처음 배운 차례(0부터) · p_n 그 수) → 날짜 차례 · 같은 날 하나
create or replace function public.lec__v2_plan(p_f date, p_e date, p_r integer, p_n integer) returns date[]
language plpgsql immutable set search_path = public as $$
declare
  v_r    integer;
  v_lo   date;
  v_s    date;
  v_out  date[] := '{}';
begin
  if p_f is null then
    return v_out;
  end if;
  if p_e is null then
    return array[p_f + 1, p_f + 3, p_f + 7];
  end if;
  v_r := p_e - p_f;
  if v_r <= 0 then
    return v_out;
  end if;
  v_lo := p_f;
  if v_r > 5 then
    v_lo := p_f + greatest(1, (2 * v_r) / 3);
    v_out := array[p_f + greatest(1, least(v_r / 3, 7)), v_lo];
  end if;
  if coalesce(p_n, 0) > 0 and p_r is not null then
    v_s := p_e - 6 + (p_r * 5) / p_n;
    if v_s <= v_lo then
      v_s := v_lo + 1;
    end if;
    if v_s <= p_e - 2 then
      v_out := v_out || v_s;
    end if;
  end if;
  return array(select distinct x.d from unnest(v_out) as x(d) order by x.d);
end
$$;

-- 오늘 볼 것(학생 p_sid · 반 p_cls · 학교 시험 p_ex = lec__v2_ex · 오늘 p_day · 켠 날 p_ron = lec_v2_cfg.review_on · null = 자르지 않음):
--   열린 세트(시험 · 드릴을 연 세트 뺌)의 문항마다 볼 날이 왔거나(일정 · 켠 날 앞 일정 날은 안 침) 쌓인 오답(단어 · 문법) → 줄 하나 ·
--   gr 차례 무리 · sk 무리 안 차례 글 · fm 오늘 볼 것 판의 꼴(단어 sp · 구문 se · 문법 c · r)
--   부르는 쪽 차례 = 종류(단어 · 구문 · 문법) · gr · sk · 공개일 늦은 것 · 만든 때 늦은 것 · 문항 차례
create or replace function public.lec__v2_todo(p_sid text, p_cls text[], p_ex jsonb, p_day date, p_ron date)
returns table (set_id uuid, kd text, k text, o bigint, gr integer, sk text, on_ date, cr timestamptz, z boolean, fm text)
language sql stable set search_path = public as $$
  with st as (
    select xs.id as sid_, xs.kind as kd_, xs.items, xs.posted_on, xs.created_at, xp.cards, xp.first_at,
           (public.lec__v2_exam_of(p_ex, xs.posted_on, xs.class_ids, p_day) ->> 'e')::date as ex
      from public.lec_set xs
      join public.lec_set_prog xp on xp.set_id = xs.id and xp.sid = p_sid
     where public.lec__set_open(xs, p_cls) and not public.lec__set_busy(p_sid, xs.id)
  ),
  lg as (
    select xl.set_id as ls_, xl.k as lk, min(xl.day) as d0, max(xl.day) as d1
      from public.lec_set_log xl
     where xl.sid = p_sid and xl.why <> 'gone' and xl.set_id in (select st.sid_ from st)
     group by xl.set_id, xl.k
  ),
  it as (
    select st.sid_, st.kd_, st.posted_on, st.created_at, st.ex, u.e ->> 'k' as ik, u.o as io, u.e ->> 's' as iq,
           st.cards -> (u.e ->> 'k') as c,
           coalesce(least(lg.d0, public.lec__date(public.lec__v2_first(st.cards -> (u.e ->> 'k')))),
                    case when jsonb_typeof(st.cards -> (u.e ->> 'k')) = 'object' then (st.first_at at time zone 'Asia/Seoul')::date end) as f,
           greatest(lg.d1, public.lec__date(public.lec__v2_last(st.cards -> (u.e ->> 'k')))) as ls
      from st
     cross join lateral jsonb_array_elements(st.items) with ordinality as u(e, o)
      left join lg on lg.ls_ = st.sid_ and lg.lk = u.e ->> 'k'
  ),
  rk as (
    select it.*, case when it.ex > p_day and it.f < it.ex then it.ex end as ge
      from it
     where it.f is not null
  ),
  rn as (
    select rk.*,
           case when rk.ge is not null
                then (row_number() over (partition by rk.ge order by rk.f, rk.posted_on, rk.created_at, rk.sid_, rk.io) - 1)::integer end as r,
           case when rk.ge is not null then (count(*) over (partition by rk.ge))::integer end as n
      from rk
  ),
  pl as (
    select rn.*,
           (select min(p.d)
              from unnest(case when rn.ex is null or rn.ex > p_day then public.lec__v2_plan(rn.f, rn.ex, rn.r, rn.n) else '{}'::date[] end) as p(d)
             where p.d <= p_day and (rn.ls is null or rn.ls < p.d) and (p_ron is null or p.d >= p_ron)) as pd,
           rn.kd_ in ('voc', 'gram') and public.lec__set_due_on(rn.c, p_day) as zd
      from rn
  )
  select pl.sid_, pl.kd_, pl.ik, pl.io,
         case when pl.pd < p_day then 0 when pl.zd and not coalesce(pl.ex <= p_day, false) then 1 when pl.pd is not null then 2 else 3 end,
         case when pl.pd < p_day then to_char(pl.pd, 'YYYY-MM-DD') when pl.zd then coalesce(pl.c ->> 'z', '') else to_char(pl.f, 'YYYY-MM-DD') end,
         pl.posted_on, pl.created_at, pl.zd,
         case pl.kd_ when 'voc' then 'sp' when 'gu' then 'se' else (case when public.lec__set_opts(pl.iq) is null then 'r' else 'c' end) end
    from pl
   where pl.pd is not null or pl.zd
$$;

-- 목록에 더하는 오늘 볼 것: n(문항 수) · day(받은 날 = 서버 오늘) · ex({세트: 시험 날} · 끝나지 않은 시험이 있는 열린 세트만 · 세트마다 한 번) ·
--   kd(종류마다 수 · 판 끝 «이어서» 단추) · 본앱 일정은 lec__v2_ex 로 한 번만 읽음
create or replace function public.lec__v2_sum(p_sid text, p_cls text[]) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  v_day  date := public.lec__set_today();
  v_ex   jsonb := public.lec__v2_ex(p_sid);
  v_n    jsonb;
  v_sx   jsonb;
begin
  select jsonb_build_object('n', count(*), 'voc', count(*) filter (where z.kd = 'voc'), 'gu', count(*) filter (where z.kd = 'gu'),
                            'gram', count(*) filter (where z.kd = 'gram'))
    into v_n
    from public.lec__v2_todo(p_sid, p_cls, v_ex, v_day, (select c.review_on from public.lec_v2_cfg c where c.id = 1)) z;
  select coalesce(jsonb_object_agg(xs.id::text, x.w ->> 'e'), '{}'::jsonb) into v_sx
    from public.lec_set xs
   cross join lateral (select public.lec__v2_exam_of(v_ex, xs.posted_on, xs.class_ids, v_day) as w) x
   where public.lec__set_open(xs, p_cls) and (x.w ->> 'end')::date >= v_day;
  return jsonb_build_object('n', (v_n ->> 'n')::integer, 'day', to_char(v_day, 'YYYY-MM-DD'), 'ex', v_sx, 'kd', v_n - 'n');
end
$$;

-- 판 문항 한 칸(V2-1 쌓인 오답 판과 같은 꼴 + 구문): s · k · kd · t(세트 이름) · f(판 꼴) · p(문제: 단어 뜻 · 구문 해석 · 문법 문장) ·
--   o(문법 고르기 보기 · 아니면 null) · a(바른 답: 단어 영어 · 구문 영어 · 문법 답) · x(문법 해설 · 없으면 '') · pt(포인트 · 단어 '')
create or replace function public.lec__v2_q(p_s public.lec_set, p_it jsonb, p_f text) returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object(
           's', p_s.id, 'k', p_it ->> 'k', 'kd', p_s.kind, 't', p_s.title, 'f', p_f,
           'p', case p_s.kind when 'voc' then p_it ->> 'm' when 'gu' then p_it ->> 't' else p_it ->> 's' end,
           'o', case when p_s.kind = 'gram' then to_jsonb(public.lec__set_opts(p_it ->> 's')) end,
           'a', case p_s.kind when 'voc' then p_it ->> 'w' when 'gu' then p_it ->> 'e' else p_it ->> 'a' end,
           'x', case when p_s.kind = 'gram' then coalesce(p_it ->> 'x', '') else '' end,
           'pt', case when p_s.kind = 'voc' then '' else coalesce(p_it ->> 'p', '') end)
$$;

-- 판 꾸리기(세트 하나 · 차례대로 [{s, k, f(, z)}]):
--   spell · guw = 아직 안 쓴 문항 → 틀린 문항(구문은 배열만 한 문항도) 먼저 · 맞힌 문항은 오래된 것부터 · 20
--   gram = 포인트 칸이 있고 아직 안 본 무리(포인트 차례 · 빈 포인트도 한 무리)가 있으면 그 무리만 8문항까지(새 포인트 첫 판) ·
--     없으면 배운 무리를 돌아가며(무리 안 = 쌓인 오답 먼저 · 안 본 문항 · 오래 안 본 문항) 20 · 포인트 칸이 없으면 모두 한 무리 · 쌓인 오답 문항 z
create or replace function public.lec__v2_pan(p_sid text, p_s public.lec_set, p_md text, p_day date) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  v_qs  jsonb;
begin
  if p_md in ('spell', 'guw') then
    select coalesce(jsonb_agg(jsonb_build_object('s', p_s.id, 'k', y.k, 'f', case when p_md = 'spell' then 'sp' else 'gw' end)
                              order by y.st, y.lt nulls first, y.o), '[]'::jsonb)
      into v_qs
      from (select u.e ->> 'k' as k, u.o,
                   case when l.id is null then 1 when l.ok and (p_md = 'spell' or l.f = 'se') then 2 else 0 end as st,
                   case when l.ok and (p_md = 'spell' or l.f = 'se') then l.ta end as lt
              from jsonb_array_elements(p_s.items) with ordinality as u(e, o)
              left join lateral (select xl.id, xl.ok, xl.f, xl.ta
                                   from public.lec_set_log xl
                                  where xl.sid = p_sid and xl.set_id = p_s.id and xl.k = u.e ->> 'k' and xl.why not in ('gone', 'log')
                                    and xl.f = any (case when p_md = 'spell' then array['sp'] else array['ar', 'se'] end)
                                  order by xl.ta desc, xl.i desc, xl.id desc
                                  limit 1) l on true
             order by 3, 4 nulls first, 2
             limit 20) y;
    return v_qs;
  end if;
  with it as (
    select u.e ->> 'k' as k, u.o, coalesce(u.e ->> 'p', '') as pt,
           public.lec__set_due_on(xp.cards -> (u.e ->> 'k'), p_day) as zd,
           case when public.lec__set_due_on(xp.cards -> (u.e ->> 'k'), p_day) then coalesce(xp.cards -> (u.e ->> 'k') ->> 'z', '') else '' end as zz,
           greatest(l.d1, public.lec__date(public.lec__v2_last(xp.cards -> (u.e ->> 'k')))) as ls,
           (l.d1 is not null or coalesce(jsonb_typeof(xp.cards -> (u.e ->> 'k')) = 'object', false)) as seen,  -- 진행 줄이 없으면 NULL → 첫 판이 비던 것 막음(11-20 운영 시험 실행)
           case when public.lec__set_opts(u.e ->> 's') is null then 'r' else 'c' end as f
      from jsonb_array_elements(p_s.items) with ordinality as u(e, o)
      left join public.lec_set_prog xp on xp.sid = p_sid and xp.set_id = p_s.id
      left join lateral (select max(xl.day) as d1 from public.lec_set_log xl
                          where xl.sid = p_sid and xl.set_id = p_s.id and xl.k = u.e ->> 'k' and xl.why <> 'gone') l on true
  ),
  g as (
    select it.pt, min(it.o) as po, bool_or(it.seen) as lrn from it group by it.pt
  ),
  hp as (
    select exists (select 1 from g where g.pt <> '') as y
  ),
  nw as (
    select g.pt from g where (select hp.y from hp) and not g.lrn order by g.po limit 1
  ),
  blk as (
    select it.k, it.o, it.f, it.zd, row_number() over (order by it.o) as rk
      from it
     where it.pt = (select nw.pt from nw)
     order by it.o
     limit 8
  ),
  mx as (
    select it.k, it.o, it.f, it.zd, g.po,
           row_number() over (partition by it.pt order by (case when it.zd then 0 else 1 end), it.zz, (case when it.seen then 1 else 0 end),
                                                          it.ls nulls first, it.o) as rk
      from it
      join g on g.pt = it.pt
     where (case when (select hp.y from hp) then g.lrn else true end)
  ),
  sel as (
    select blk.k, blk.o, blk.f, blk.zd, 0 as part, blk.rk, 0::bigint as po from blk
    union all
    select y.k, y.o, y.f, y.zd, 1, y.rk, y.po
      from (select mx.* from mx order by mx.rk, mx.po, mx.o limit (case when exists (select 1 from blk) then 0 else 20 end)) y
  )
  select coalesce(jsonb_agg(case when sel.zd then jsonb_build_object('s', p_s.id, 'k', sel.k, 'f', sel.f, 'z', true)
                                 else jsonb_build_object('s', p_s.id, 'k', sel.k, 'f', sel.f) end
                            order by sel.part, sel.rk, sel.po, sel.o), '[]'::jsonb)
    into v_qs
    from sel;
  return v_qs;
end
$$;

-- 새 판 열기(lec_set_open_v2 가 열쇠 · 동의 · 잠금 뒤에 부름): 그 판 스위치 · 세트(열림 · 종류 · 시험 중이면 testing) ·
--   오늘 끝나지 않은 같은 판이 있으면 이어서(닫힌 판은 안 이음) · 없으면 판 꾸리기(review = 오늘 볼 것 첫 종류 20) · 하루 200 판 ·
--   답 = V2-1 판 머리 + n · q(lec__v2_q · 시험 · 드릴을 연 세트 · 닫힌 세트 문항 뺌) · title · kd(+ review 는 left = 이 판 밖 종류마다 남은 수)
create or replace function public.lec__v2_open3(k public.lec_key, p_set uuid, p_md text) returns jsonb
language plpgsql volatile set search_path = public as $$
declare
  s      public.lec_set;
  rn     public.lec_set_run;
  v_day  date := public.lec__set_today();
  v_set  uuid;
  v_all  jsonb;
  v_qs   jsonb;
  v_q    jsonb;
  v_left jsonb;
  v_no   integer;
  v_cnt  integer;
begin
  if not coalesce((public.lec__v2_sw() ->> p_md)::boolean, false) then
    return jsonb_build_object('ok', false, 'err', 'off');
  end if;
  if p_md <> 'review' then
    select * into s from public.lec_set xs where xs.id = p_set;
    if not found or not public.lec__set_open(s, k.cls) then
      return jsonb_build_object('ok', false, 'err', 'none');
    end if;
    if s.kind is distinct from (case p_md when 'spell' then 'voc' when 'guw' then 'gu' else 'gram' end) then
      return jsonb_build_object('ok', false, 'err', 'kind');
    end if;
    if public.lec__set_busy(k.sid, s.id) then
      return jsonb_build_object('ok', false, 'err', 'testing');
    end if;
    v_set := s.id;
  else
    select coalesce(jsonb_agg(jsonb_build_object('s', z.set_id, 'k', z.k, 'kd', z.kd, 'f', z.fm, 'z', z.z)
                              order by case z.kd when 'voc' then 1 when 'gu' then 2 else 3 end, z.gr, z.sk, z.on_ desc, z.cr desc, z.o),
                    '[]'::jsonb)
      into v_all
      from public.lec__v2_todo(k.sid, k.cls, public.lec__v2_ex(k.sid), v_day, (select c.review_on from public.lec_v2_cfg c where c.id = 1)) z;
  end if;
  select * into rn from public.lec_set_run xr
   where xr.sid = k.sid and xr.md = p_md and xr.set_id is not distinct from v_set and xr.day = v_day and xr.end_n is null
     and xr.shut = '{}'::jsonb
   order by xr.created_at desc limit 1;
  if not found then
    select count(*) into v_cnt from public.lec_set_run xr where xr.sid = k.sid and xr.md = p_md and xr.day = v_day;
    if v_cnt >= 200 then
      return jsonb_build_object('ok', false, 'err', 'limit');
    end if;
    if p_md = 'review' then
      select coalesce(jsonb_agg(case when (y.e ->> 'z')::boolean then jsonb_build_object('s', y.e -> 's', 'k', y.e -> 'k', 'f', y.e -> 'f', 'z', true)
                                     else jsonb_build_object('s', y.e -> 's', 'k', y.e -> 'k', 'f', y.e -> 'f') end order by y.o), '[]'::jsonb)
        into v_qs
        from (select x.e, x.o from jsonb_array_elements(v_all) with ordinality as x(e, o)
               where x.e ->> 'kd' = (v_all -> 0 ->> 'kd') order by x.o limit 20) y;
    else
      v_qs := public.lec__v2_pan(k.sid, s, p_md, v_day);
    end if;
    if jsonb_array_length(v_qs) = 0 then
      return jsonb_build_object('ok', true, 'b', null, 'n', 0, 'q', '[]'::jsonb, 'today', to_char(v_day, 'YYYY-MM-DD'), 'kd', null)
             || case when p_md = 'review' then jsonb_build_object('left', jsonb_build_object('voc', 0, 'gu', 0, 'gram', 0)) else '{}'::jsonb end;
    end if;
    select coalesce(max(xr.no), 0) + 1 into v_no from public.lec_set_run xr
     where xr.sid = k.sid and xr.md = p_md and xr.set_id is not distinct from v_set;
    insert into public.lec_set_run (sid, set_id, md, no, day, n, qs, seed)
    values (k.sid, v_set, p_md, v_no, v_day, jsonb_array_length(v_qs), v_qs,
            hashtext(k.sid || '|' || coalesce(v_set::text, '') || '|' || p_md || '|' || v_no::text))
    returning * into rn;
  end if;
  select coalesce(jsonb_agg(public.lec__v2_q(xs, it.e, q.e ->> 'f')
                            || case when (q.e ->> 'z')::boolean then jsonb_build_object('z', true) else '{}'::jsonb end order by q.o), '[]'::jsonb)
    into v_q
    from jsonb_array_elements(rn.qs) with ordinality as q(e, o)
    join public.lec_set xs on xs.id = (q.e ->> 's')::uuid
   cross join lateral (select y.e from jsonb_array_elements(xs.items) as y(e) where y.e ->> 'k' = q.e ->> 'k' limit 1) it
   where public.lec__set_open(xs, k.cls) and not public.lec__set_busy(k.sid, xs.id) and not (rn.shut ? xs.id::text);
  if to_regprocedure('public.lec__v2_ok2q(jsonb)') is not null then   -- V2-35 쓰기 문항(sp · gw · se · r)에 켜진 인정 답 a2(V2-5 절이 있을 때만 · 폰 채점 = 서버 채점)
    v_q := public.lec__v2_ok2q(v_q);
  end if;
  if p_md = 'review' then
    select jsonb_build_object('voc', count(*) filter (where x.e ->> 'kd' = 'voc'), 'gu', count(*) filter (where x.e ->> 'kd' = 'gu'),
                              'gram', count(*) filter (where x.e ->> 'kd' = 'gram'))
      into v_left
      from jsonb_array_elements(v_all) as x(e)
     where not exists (select 1 from jsonb_array_elements(rn.qs) as q(e) where q.e ->> 's' = x.e ->> 's' and q.e ->> 'k' = x.e ->> 'k');
  end if;
  return jsonb_build_object('ok', true, 'n', jsonb_array_length(v_q), 'q', v_q,
                            'title', case when p_md = 'review' then '오늘 볼 것' else s.title end,
                            'kd', case when p_md = 'review' then v_q -> 0 ->> 'kd' else s.kind end)
         || case when p_md = 'review' then jsonb_build_object('left', v_left) else '{}'::jsonb end
         || public.lec__v2_head(rn);
end
$$;

-- 새 판 한 줄 채점(lec_set_log_v2 가 부름 · 판 문항 꼴대로): sp = 단어 쓰기(뜻 여럿) · gw = 구문(줄 꼴 ar 이면 배열 · 아니면 통째 se) ·
--   se = 통째 · c = 고르기(맞추기 글 같음) · r = 쓰기(lec__set_match) · 400 글자 넘음 · 빈 답 = 틀림 · ok = 맞음이고 힌트 안 봄 ·
--   src = 쌓인 오답 문항 due · 구문 say · 그 밖 card → {why('' · gone), s, f(적을 단계), sr, ok, src}
create or replace function public.lec__v2_judge(p_run public.lec_set_run, p_cls text[], p_e jsonb) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  s      public.lec_set;
  v_q    jsonb;
  v_it   jsonb;
  v_f    text;
  v_v    text := coalesce(p_e ->> 'v', '');
  v_sr   boolean;
begin
  select q.e into v_q from jsonb_array_elements(p_run.qs) as q(e)
   where q.e ->> 's' = (p_e ->> 's') and q.e ->> 'k' = (p_e ->> 'k') limit 1;
  if v_q is null then
    return jsonb_build_object('why', 'gone', 's', p_e ->> 's', 'f', coalesce(p_e ->> 'f', ''));
  end if;
  select * into s from public.lec_set xs where xs.id = (v_q ->> 's')::uuid;
  if not found or not public.lec__set_open(s, p_cls) then
    return jsonb_build_object('why', 'gone', 's', v_q ->> 's', 'f', coalesce(p_e ->> 'f', ''));
  end if;
  select y.e into v_it from jsonb_array_elements(s.items) as y(e) where y.e ->> 'k' = (p_e ->> 'k') limit 1;
  if v_it is null then
    return jsonb_build_object('why', 'gone', 's', s.id, 'f', coalesce(p_e ->> 'f', ''));
  end if;
  v_f := v_q ->> 'f';
  if v_f = 'sp' then
    v_sr := public.lec__set_spell_v2(v_v, s.items, p_e ->> 'k');
  elsif v_f in ('gw', 'se') then
    v_f := case when v_f = 'gw' and (p_e ->> 'f') = 'ar' then 'ar' else 'se' end;
    v_sr := public.lec__set_sent_v2(v_v, v_it ->> 'e');
  elsif v_f = 'c' then
    v_sr := public.lec__set_norm(v_v) = public.lec__set_norm(v_it ->> 'a');
  else
    v_sr := public.lec__set_match(v_v, v_it ->> 'a');
  end if;
  v_sr := coalesce(v_sr, false) and not coalesce((p_e ->> 'lg')::boolean, false) and btrim(v_v) <> '';
  return jsonb_build_object('why', '', 's', s.id, 'f', v_f, 'sr', v_sr, 'ok', v_sr and not coalesce((p_e ->> 'h')::boolean, false),
                            'src', case when coalesce((v_q ->> 'z')::boolean, false) then 'due' when s.kind = 'gu' then 'say' else 'card' end);
end
$$;

-- 판 고르기 · 일정이 학생 줄을 문항마다 찾음(lec_set_log_card 는 반영한 줄만이라 따로)
create index if not exists lec_set_log_seen on public.lec_set_log (sid, set_id, k, day);

-- 권한(V2-3): 속 함수 = 밖에서 못 부름(학생 함수는 V2-1 권한 그대로)
revoke all on function public.lec__v2_enorm(jsonb), public.lec__v2_grade(jsonb), public.lec__v2_tnum(jsonb), public.lec__v2_join(jsonb, jsonb),
  public.lec__v2_exams(jsonb, date), public.lec__v2_ex(text), public.lec__v2_exam_of(jsonb, date, text[], date), public.lec__v2_first(jsonb),
  public.lec__v2_plan(date, date, integer, integer), public.lec__v2_todo(text, text[], jsonb, date, date), public.lec__v2_sum(text, text[]),
  public.lec__v2_q(public.lec_set, jsonb, text), public.lec__v2_pan(text, public.lec_set, text, date),
  public.lec__v2_open3(public.lec_key, uuid, text), public.lec__v2_judge(public.lec_set_run, text[], jsonb), public.lec__v2_revon()
  from public, anon, authenticated;

-- 열셋째 스스로 점검(V2-3): 사례표(_check/class_v3_cases.json · 일정 · 날짜 칸 · 학년 · 학교 시험 · 오늘 볼 것 · 판 꾸리기) ·
--   스위치 끔 = V2-1 그대로(목록 todo · 새 판 'off') · 켬: 켠 날 트리거(켬 · 그대로 · 다시 켬 · 자름) · 목록 오늘 볼 것 · 써 보기 판(바른 답 같이 · 이어서 · 종류 · 없는 세트 ·
--   카드 d 만 · 힌트 본 답 = 틀림) · 구문(배열 · 통째) · 문법(포인트 무리 · 쌓인 오답 = due) · 오늘 볼 것 판(한 종류 · 남은 수 ·
--   시험 중 세트 뺌 · 평가를 열면 판 닫힘 · 닫힌 뒤 답 = 기록만) · 권한
-- 넣은 세트 · 열쇠 · 동의 · 줄 · 스위치는 끝에 되돌려 남지 않습니다
do $$
declare
  r       jsonb;
  r2      jsonb;
  v_t     text;
  v_ks    text := replace(gen_random_uuid()::text, '-', '');
  v_ka    text;
  v_sa    text := 'selftest-v3a|점검가';
  v_case  record;
  v_sc    jsonb;
  v_set   public.lec_set;
  v_b     uuid;
  v_d     date := public.lec__set_today();
begin
  begin
    -- 1) 사례표(_check/class_v3_cases.json 과 같은 값 · class_v3_vec.py render 가 만든 글 · 흉내 저장소도 같은 값)
    for v_case in select * from (values
        ('2026-03-01'::date, '2026-03-01'::date, 0, 1, '[]'::jsonb),
        ('2026-03-01'::date, '2026-03-02'::date, 0, 1, '[]'::jsonb),
        ('2026-03-01'::date, '2026-03-03'::date, 0, 1, '[]'::jsonb),
        ('2026-03-01'::date, '2026-03-04'::date, 0, 1, '["2026-03-02"]'::jsonb),
        ('2026-03-01'::date, '2026-03-06'::date, 0, 1, '["2026-03-02"]'::jsonb),
        ('2026-03-01'::date, '2026-03-06'::date, 4, 5, '["2026-03-04"]'::jsonb),
        ('2026-03-01'::date, '2026-03-07'::date, 0, 1, '["2026-03-03", "2026-03-05"]'::jsonb),
        ('2026-03-01'::date, '2026-03-08'::date, 0, 1, '["2026-03-03", "2026-03-05", "2026-03-06"]'::jsonb),
        ('2026-03-01'::date, '2026-03-08'::date, 4, 5, '["2026-03-03", "2026-03-05", "2026-03-06"]'::jsonb),
        ('2026-03-01'::date, '2026-03-09'::date, 0, 3, '["2026-03-03", "2026-03-06", "2026-03-07"]'::jsonb),
        ('2026-03-01'::date, '2026-03-13'::date, 2, 3, '["2026-03-05", "2026-03-09", "2026-03-10"]'::jsonb),
        ('2026-03-01'::date, '2026-03-22'::date, 0, 2, '["2026-03-08", "2026-03-15", "2026-03-16"]'::jsonb),
        ('2026-03-01'::date, '2026-03-22'::date, 1, 2, '["2026-03-08", "2026-03-15", "2026-03-18"]'::jsonb),
        ('2026-03-01'::date, '2026-03-31'::date, 0, 5, '["2026-03-08", "2026-03-21", "2026-03-25"]'::jsonb),
        ('2026-03-01'::date, '2026-03-31'::date, 4, 5, '["2026-03-08", "2026-03-21", "2026-03-29"]'::jsonb),
        ('2026-03-01'::date, '2026-04-30'::date, 2, 5, '["2026-03-08", "2026-04-10", "2026-04-26"]'::jsonb),
        ('2026-03-01'::date, '2026-04-30'::date, 0, 1, '["2026-03-08", "2026-04-10", "2026-04-24"]'::jsonb),
        ('2026-03-01'::date, '2026-04-30'::date, null::integer, null::integer, '["2026-03-08", "2026-04-10"]'::jsonb),
        ('2026-03-01'::date, '2026-05-30'::date, 9, 10, '["2026-03-08", "2026-04-30", "2026-05-28"]'::jsonb),
        ('2026-03-01'::date, '2026-02-26'::date, 0, 1, '[]'::jsonb),
        ('2026-03-01'::date, null::date, null::integer, null::integer, '["2026-03-02", "2026-03-04", "2026-03-08"]'::jsonb)
      ) as x(f, e, r, n, w) loop
      if to_jsonb(public.lec__v2_plan(v_case.f, v_case.e, v_case.r, v_case.n)) is distinct from v_case.w then
        raise exception '점검 실패(V3 일정 % → % · %/%): %', v_case.f, v_case.e, v_case.r, v_case.n, to_jsonb(public.lec__v2_plan(v_case.f, v_case.e, v_case.r, v_case.n));
      end if;
    end loop;
    for v_case in select * from (values
        ('"2026.04.20"'::jsonb, '2026-04-20'::date),
        ('"20260420"'::jsonb, '2026-04-20'::date),
        ('"2026-4-2"'::jsonb, '2026-04-02'::date),
        ('" 2026/04/20 "'::jsonb, '2026-04-20'::date),
        ('"2026.02.30"'::jsonb, null::date),
        ('"1999.01.01"'::jsonb, null::date),
        ('"2026.13.01"'::jsonb, null::date),
        ('"2026.4"'::jsonb, null::date),
        ('""'::jsonb, null::date),
        ('20260420'::jsonb, '2026-04-20'::date),
        ('0'::jsonb, null::date),
        ('"2026년 4월 27일"'::jsonb, '2026-04-27'::date),
        ('"2026.04.20."'::jsonb, '2026-04-20'::date),
        ('"12026.04.20"'::jsonb, null::date),
        ('"2026.004.20"'::jsonb, null::date),
        ('"x"'::jsonb, null::date)
      ) as x(v, w) loop
      if public.lec__v2_enorm(v_case.v) is distinct from v_case.w then raise exception '점검 실패(V3 날짜 칸 %)', v_case.v; end if;
    end loop;
    for v_case in select * from (values
        ('{"g": "1"}'::jsonb, '1'),
        ('{"g": "고2"}'::jsonb, '2'),
        ('{"g": 3}'::jsonb, '3'),
        ('{"g": "", "ig": "2학년"}'::jsonb, '2'),
        ('{"g": 0, "ig": "1"}'::jsonb, '1'),
        ('{"s": "새솔고 2학년"}'::jsonb, '2'),
        ('{"s": "바다고등학교3"}'::jsonb, '3'),
        ('{"s": "한빛여고 1-3"}'::jsonb, '1'),
        ('{"s": "바다고", "cn": "고1 H2 반"}'::jsonb, '2'),
        ('{"s": "바다고", "cn": "M2"}'::jsonb, ''),
        ('{"s": "바다중", "cn": "m 3반"}'::jsonb, '3'),
        ('{"s": "바다고", "cn": "H5"}'::jsonb, ''),
        ('{"s": "", "cn": "E5"}'::jsonb, '5'),
        ('{"s": "바다초", "cn": "e5"}'::jsonb, '5'),
        ('{"s": "바다고", "cn": "2 학년 A"}'::jsonb, '2'),
        ('{"s": "바다고", "cn": "종합반"}'::jsonb, ''),
        ('{"is": "푸른고 1", "cn": "x"}'::jsonb, '1'),
        ('{"g": "1반", "s": "바다고"}'::jsonb, '1'),
        ('{"s": "바다고7", "cn": "3학년"}'::jsonb, '3'),
        ('{}'::jsonb, '')
      ) as x(v, w) loop
      if public.lec__v2_grade(v_case.v) is distinct from v_case.w then raise exception '점검 실패(V3 학년 %)', v_case.v; end if;
    end loop;
    v_sc := jsonb_build_object('S1', '{"rows": [{"id": "main", "es": {"바다고": {"label": "1학기 중간", "date": "2026.04.20", "end": "2026.04.23", "t": 1}, "새솔고": {"date": "2026.04.10", "t": 1}}, "eg": null}, {"id": "pt-etc", "es": {"바다고": {"date": "2026.04.21", "t": 0}}, "eg": {"바다고|1": {"date": "2026.04.27", "end": "2026.04.29", "t": 5}, "새솔고|2": {"date": "2026.03.30", "del": true, "t": 9}}}], "me": [{"g": "1", "ig": null, "s": "바다고등학교", "is": null, "cn": "고1 A반", "cid": "selftest-v3-c1"}, {"g": null, "ig": null, "s": "새솔고 2학년", "is": null, "cn": "H2 B반", "cid": "selftest-v3-c2"}]}'::jsonb, 'S2', '{"rows": [{"id": "main", "es": {"바다고": {"label": "1학기 중간", "date": "2026.04.20", "end": "2026.04.23", "t": 1}, "새솔고": {"date": "2026.04.10", "t": 1}}, "eg": null}, {"id": "pt-etc", "es": {"바다고": {"date": "2026.04.21", "t": 0}}, "eg": {"바다고|1": {"date": "2026.04.24", "end": "2026.04.29", "t": 6}, "새솔고|2": {"date": "2026.03.30", "del": true, "t": 9}}}], "me": [{"g": "1", "ig": null, "s": "바다고등학교", "is": null, "cn": "고1 A반", "cid": "selftest-v3-c1"}, {"g": null, "ig": null, "s": "새솔고 2학년", "is": null, "cn": "H2 B반", "cid": "selftest-v3-c2"}]}'::jsonb, 'S3', '{"rows": [{"id": "main", "es": {"바다고": {"date": "2026.04.20", "t": 3}}, "eg": {"바다고|1": {"date": "2026.03.10", "t": 1}}}, {"id": "pt-etc", "es": {"바다고": {"date": "2026.04.22", "t": 3}}, "eg": null}], "me": [{"g": "1", "s": "바다고", "cid": "x"}, {"s": "", "cid": "y"}, {"g": "1", "s": "바다고", "cid": "z"}]}'::jsonb, 'S4', '{"rows": [{"id": "main", "es": null, "eg": null}], "me": [{"g": "1", "s": "바다고", "cid": "selftest-v3-c1"}]}'::jsonb);
    for v_case in select * from (values
        ('S1', '2026-03-25'::date, '[{"cid": "selftest-v3-c1", "k": "바다고", "g": "1", "e": "2026-04-27", "end": "2026-04-29"}, {"cid": "selftest-v3-c2", "k": "새솔고", "g": "2", "e": "2026-04-10", "end": "2026-04-10"}]'::jsonb),
        ('S1', '2026-04-28'::date, '[{"cid": "selftest-v3-c1", "k": "바다고", "g": "1", "e": "2026-04-27", "end": "2026-04-29"}, {"cid": "selftest-v3-c2", "k": "새솔고", "g": "2", "e": "2026-04-10", "end": "2026-04-10"}]'::jsonb),
        ('S1', '2026-05-01'::date, '[{"cid": "selftest-v3-c1", "k": "바다고", "g": "1", "e": "2026-04-27", "end": "2026-04-29"}, {"cid": "selftest-v3-c2", "k": "새솔고", "g": "2", "e": "2026-04-10", "end": "2026-04-10"}]'::jsonb),
        ('S2', '2026-04-20'::date, '[{"cid": "selftest-v3-c1", "k": "바다고", "g": "1", "e": "2026-04-24", "end": "2026-04-29"}, {"cid": "selftest-v3-c2", "k": "새솔고", "g": "2", "e": "2026-04-10", "end": "2026-04-10"}]'::jsonb),
        ('S3', '2026-03-01'::date, '[{"cid": "x", "k": "바다고", "g": "1", "e": "2026-03-10", "end": "2026-03-10"}, {"cid": "z", "k": "바다고", "g": "1", "e": "2026-03-10", "end": "2026-03-10"}]'::jsonb),
        ('S3', '2026-03-11'::date, '[{"cid": "x", "k": "바다고", "g": "1", "e": "2026-04-22", "end": "2026-04-22"}, {"cid": "z", "k": "바다고", "g": "1", "e": "2026-04-22", "end": "2026-04-22"}]'::jsonb),
        ('S4', '2026-03-01'::date, '[]'::jsonb)
      ) as x(s, d, w) loop
      if public.lec__v2_exams(v_sc -> v_case.s, v_case.d) is distinct from v_case.w then
        raise exception '점검 실패(V3 학교 시험 % %): %', v_case.s, v_case.d, public.lec__v2_exams(v_sc -> v_case.s, v_case.d);
      end if;
    end loop;
    -- 오늘 볼 것: 가짜 세트 · 진행 · 줄 · 열린 시험(되돌림)
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000001'::uuid, 'voc', '점검 v3 단어 1', array['selftest-v3-c1'], '2026-03-01'::date, '[{"k": "k1", "n": "1", "w": "w1", "m": "뜻1"}, {"k": "k2", "n": "2", "w": "w2", "m": "뜻2"}, {"k": "k3", "n": "3", "w": "w3", "m": "뜻3"}, {"k": "k4", "n": "4", "w": "w4", "m": "뜻4"}, {"k": "k5", "n": "5", "w": "w5", "m": "뜻5"}, {"k": "k6", "n": "6", "w": "w6", "m": "뜻6"}]'::jsonb, 6, '2026-03-01T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000002'::uuid, 'voc', '점검 v3 단어 2', array['selftest-v3-c2'], '2026-03-20'::date, '[{"k": "k1", "n": "1", "w": "x1", "m": "뜻 1"}, {"k": "k2", "n": "2", "w": "x2", "m": "뜻 2"}]'::jsonb, 2, '2026-03-20T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000003'::uuid, 'gu', '점검 v3 구문', array['selftest-v3-c1', 'selftest-v3-c2'], '2026-03-25'::date, '[{"k": "k1", "n": "1", "e": "I / am a boy.", "t": "나는 소년이다.", "p": ""}]'::jsonb, 1, '2026-03-25T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000004'::uuid, 'gram', '점검 v3 문법', array['selftest-v3-c1'], '2026-03-02'::date, '[{"k": "k1", "n": "1", "s": "He (go / goes) home.", "a": "goes", "x": "삼인칭 단수", "p": "수 일치"}, {"k": "k2", "n": "2", "s": "She ___ tall.", "a": "is", "x": "", "p": "be"}]'::jsonb, 2, '2026-03-02T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000005'::uuid, 'voc', '점검 v3 지난 단어', array['selftest-v3-c1'], '2026-01-05'::date, '[{"k": "k1", "n": "1", "w": "old", "m": "옛"}, {"k": "k2", "n": "2", "w": "past", "m": "지난"}]'::jsonb, 2, '2026-01-05T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000006'::uuid, 'voc', '점검 v3 시험 중', array['selftest-v3-c1'], '2026-03-01'::date, '[{"k": "k1", "n": "1", "w": "busy", "m": "바쁜"}]'::jsonb, 1, '2026-03-01T02:00:00+00:00'::timestamptz);
    insert into public.lec_set_prog (sid, set_id, cards, first_at) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000001'::uuid, '{"k1": {"s": 1}, "k2": {"s": 1, "d": ["2026-03-05", "2026-03-10"]}, "k3": {"s": 1}, "k4": {"s": 1, "d": ["2026-03-09"]}, "k6": {"s": 1}}'::jsonb, '2026-03-01T01:00:00+00:00'::timestamptz);
    insert into public.lec_set_prog (sid, set_id, cards, first_at) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000002'::uuid, '{"k1": {"s": 1}, "k2": {"s": 1}}'::jsonb, '2026-03-21T01:00:00+00:00'::timestamptz);
    insert into public.lec_set_prog (sid, set_id, cards, first_at) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000003'::uuid, '{"k1": {"s": 1, "g": 1}}'::jsonb, '2026-03-25T01:00:00+00:00'::timestamptz);
    insert into public.lec_set_prog (sid, set_id, cards, first_at) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000004'::uuid, '{"k1": {"s": 1, "w": 1, "z": "2026-03-20"}, "k2": {"s": 1, "d": ["2026-03-03"], "t": "2026-03-03"}}'::jsonb, '2026-03-03T01:00:00+00:00'::timestamptz);
    insert into public.lec_set_prog (sid, set_id, cards, first_at) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000005'::uuid, '{"k1": {"s": 1}, "k2": {"s": 1}}'::jsonb, '2026-01-06T01:00:00+00:00'::timestamptz);
    insert into public.lec_set_prog (sid, set_id, cards, first_at) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000006'::uuid, '{"k1": {"s": 1, "w": 1, "z": "2026-03-05"}}'::jsonb, '2026-03-01T01:00:00+00:00'::timestamptz);
    insert into public.lec_set_log (id, sid, b, bk, i, set_id, k, f, v, ok, ta, day, bo, why) values
      ('0000000000000000000000000003a001', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000901'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000001'::uuid, 'k1', 'k', '0', false, '2026-03-02T02:00:00+00:00'::timestamptz, '2026-03-02'::date, '2026-03-02T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a002', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000901'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000001'::uuid, 'k4', 'k', '1', true, '2026-03-02T02:00:00+00:00'::timestamptz, '2026-03-02'::date, '2026-03-02T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a003', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000902'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000001'::uuid, 'k4', 'sp', 'w4', true, '2026-03-09T02:00:00+00:00'::timestamptz, '2026-03-09'::date, '2026-03-09T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a004', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000903'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000001'::uuid, 'k6', 'k', '0', false, '2026-04-20T02:00:00+00:00'::timestamptz, '2026-04-20'::date, '2026-04-20T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a005', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000903'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000001'::uuid, 'k5', 'k', '0', false, '2026-03-03T02:00:00+00:00'::timestamptz, '2026-03-03'::date, '2026-03-03T02:00:00+00:00'::timestamptz, 'gone'),
      ('0000000000000000000000000003a006', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000904'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000002'::uuid, 'k1', 'k', '0', false, '2026-03-21T02:00:00+00:00'::timestamptz, '2026-03-21'::date, '2026-03-21T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a007', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000904'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000002'::uuid, 'k2', 'k', '0', false, '2026-03-21T02:00:00+00:00'::timestamptz, '2026-03-21'::date, '2026-03-21T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a008', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000905'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000002'::uuid, 'k2', 'sp', 'x2', true, '2026-03-27T02:00:00+00:00'::timestamptz, '2026-03-27'::date, '2026-03-27T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a009', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000906'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000003'::uuid, 'k1', 'ar', 'I am a boy', true, '2026-03-25T02:00:00+00:00'::timestamptz, '2026-03-25'::date, '2026-03-25T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a00a', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000907'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000005'::uuid, 'k1', 'k', '0', false, '2026-01-06T02:00:00+00:00'::timestamptz, '2026-01-06'::date, '2026-01-06T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a00b', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000907'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000005'::uuid, 'k2', 'k', '0', false, '2026-01-06T02:00:00+00:00'::timestamptz, '2026-01-06'::date, '2026-01-06T02:00:00+00:00'::timestamptz, ''),
      ('0000000000000000000000000003a00c', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000908'::uuid, 'log', 1, '00000000-0000-4000-8000-000000000005'::uuid, 'k2', 'sp', 'past', true, '2026-01-14T02:00:00+00:00'::timestamptz, '2026-01-14'::date, '2026-01-14T02:00:00+00:00'::timestamptz, '');
    insert into public.lec_set_try (sid, set_id, kind, day, n, qs) values ('selftest-v3a|점검가', '00000000-0000-4000-8000-000000000006'::uuid, 'test', '2026-03-01'::date, 1, '[]'::jsonb);
    -- 기대값 = 세트 번호(열쇠 끝 12 자리):문항:무리(gr):차례 글(sk) · 쉼표로 이음
    for v_case in select * from (values
        ('S1', '2026-03-25'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-08,1:k1:0:2026-03-09,1:k2:0:2026-03-12,4:k2:0:2026-03-10,4:k1:1:2026-03-20'),
        ('S1', '2026-04-08'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-08,1:k1:0:2026-03-09,1:k2:0:2026-03-12,2:k1:0:2026-03-27,2:k2:0:2026-04-03,1:k4:2:2026-03-02,3:k1:0:2026-03-30,4:k2:0:2026-03-10,4:k1:0:2026-03-27'),
        ('S1', '2026-04-15'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-08,1:k1:0:2026-03-09,1:k2:0:2026-03-12,1:k4:0:2026-04-08,3:k1:0:2026-04-01,4:k2:0:2026-03-10,4:k1:0:2026-03-27'),
        ('S1', '2026-04-25'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-08,1:k1:0:2026-03-09,1:k2:0:2026-03-12,1:k4:0:2026-04-08,1:k6:0:2026-04-22,3:k1:0:2026-04-01,4:k2:0:2026-03-10,4:k1:0:2026-03-27'),
        ('S1', '2026-05-01'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,4:k1:3:2026-03-20'),
        ('S2', '2026-04-22'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-08,1:k1:0:2026-03-09,1:k2:0:2026-03-12,1:k4:0:2026-04-06,1:k6:2:2026-04-20,3:k1:0:2026-04-01,4:k2:0:2026-03-10,4:k1:0:2026-03-27'),
        ('S4', '2026-03-25'::date, '2026-01-01'::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-02,1:k1:0:2026-03-03,1:k2:0:2026-03-12,2:k1:0:2026-03-22,4:k2:0:2026-03-04,4:k1:0:2026-03-21'),
        ('S1', '2026-03-25'::date, '2026-03-20'::date, '4:k1:1:2026-03-20'),
        ('S1', '2026-04-08'::date, '2026-04-08'::date, '1:k3:2:2026-03-01,1:k1:2:2026-03-02,1:k4:2:2026-03-02,4:k1:1:2026-03-20,4:k2:2:2026-03-03'),
        ('S1', '2026-03-25'::date, '2026-03-09'::date, '1:k1:0:2026-03-09,1:k2:0:2026-03-12,4:k2:0:2026-03-10,4:k1:1:2026-03-20'),
        ('S1', '2026-04-15'::date, '2026-04-10'::date, '4:k1:0:2026-04-14'),
        ('S1', '2026-04-15'::date, '2026-04-15'::date, '4:k1:1:2026-03-20'),
        ('S1', '2026-03-25'::date, null::date, '5:k1:0:2026-01-07,1:k3:0:2026-03-08,1:k1:0:2026-03-09,1:k2:0:2026-03-12,4:k2:0:2026-03-10,4:k1:1:2026-03-20'),
        ('S1', '2026-04-25'::date, '2026-04-20'::date, '1:k1:0:2026-04-21,1:k3:0:2026-04-21,1:k4:0:2026-04-22,1:k6:0:2026-04-22,1:k2:0:2026-04-23,3:k1:0:2026-04-24,4:k2:0:2026-04-22,4:k1:0:2026-04-24'),
        ('S4', '2026-03-25'::date, '2026-03-24'::date, '2:k1:0:2026-03-24,4:k1:1:2026-03-20')
      ) as x(s, d, r, w) loop
      select coalesce(string_agg(ltrim(right(z.set_id::text, 12), '0') || ':' || z.k || ':' || z.gr || ':' || z.sk, ','
               order by case z.kd when 'voc' then 1 when 'gu' then 2 else 3 end, z.gr, z.sk, z.on_ desc, z.cr desc, z.o), '')
        into v_t from public.lec__v2_todo('selftest-v3a|점검가', array['selftest-v3-c1', 'selftest-v3-c2'], public.lec__v2_exams(v_sc -> v_case.s, v_case.d), v_case.d, v_case.r) z;
      if v_t is distinct from v_case.w then raise exception '점검 실패(V3 오늘 볼 것 % % 켠 날 %): %', v_case.s, v_case.d, v_case.r, v_t; end if;
    end loop;
    -- 판 꾸리기(써 보기 · 구문 · 문법 포인트): 사례마다 그때의 줄 · 진행으로 바꿔 넣고 lec__v2_pan
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000011'::uuid, 'gram', '점검 v3 포인트', array['selftest-v3-c1'], '2026-03-01'::date, '[{"k": "a1", "n": "1", "s": "A1 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a2", "n": "2", "s": "A2 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a3", "n": "3", "s": "A3 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a4", "n": "4", "s": "A4 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a5", "n": "5", "s": "A5 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a6", "n": "6", "s": "A6 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a7", "n": "7", "s": "A7 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a8", "n": "8", "s": "A8 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a9", "n": "9", "s": "A9 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "a10", "n": "10", "s": "A10 (x / y)", "a": "x", "x": "", "p": "포인트 A"}, {"k": "b1", "n": "11", "s": "B1 ___", "a": "y", "x": "", "p": "포인트 B"}, {"k": "b2", "n": "12", "s": "B2 ___", "a": "y", "x": "", "p": "포인트 B"}, {"k": "b3", "n": "13", "s": "B3 ___", "a": "y", "x": "", "p": "포인트 B"}, {"k": "n1", "n": "14", "s": "N1 ___", "a": "z", "x": "", "p": ""}, {"k": "n2", "n": "15", "s": "N2 ___", "a": "z", "x": "", "p": ""}]'::jsonb, 15, '2026-03-01T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000012'::uuid, 'gram', '점검 v3 포인트 없음', array['selftest-v3-c1'], '2026-03-01'::date, '[{"k": "q1", "n": "1", "s": "Q1 ___", "a": "q", "x": ""}, {"k": "q2", "n": "2", "s": "Q2 ___", "a": "q", "x": ""}, {"k": "q3", "n": "3", "s": "Q3 ___", "a": "q", "x": ""}, {"k": "q4", "n": "4", "s": "Q4 ___", "a": "q", "x": ""}, {"k": "q5", "n": "5", "s": "Q5 ___", "a": "q", "x": ""}]'::jsonb, 5, '2026-03-01T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000013'::uuid, 'voc', '점검 v3 써 보기', array['selftest-v3-c1'], '2026-03-01'::date, '[{"k": "s1", "n": "1", "w": "sp1", "m": "쓰기1"}, {"k": "s2", "n": "2", "w": "sp2", "m": "쓰기2"}, {"k": "s3", "n": "3", "w": "sp3", "m": "쓰기3"}, {"k": "s4", "n": "4", "w": "sp4", "m": "쓰기4"}, {"k": "s5", "n": "5", "w": "sp5", "m": "쓰기5"}, {"k": "s6", "n": "6", "w": "sp6", "m": "쓰기6"}, {"k": "s7", "n": "7", "w": "sp7", "m": "쓰기7"}, {"k": "s8", "n": "8", "w": "sp8", "m": "쓰기8"}, {"k": "s9", "n": "9", "w": "sp9", "m": "쓰기9"}, {"k": "s10", "n": "10", "w": "sp10", "m": "쓰기10"}, {"k": "s11", "n": "11", "w": "sp11", "m": "쓰기11"}, {"k": "s12", "n": "12", "w": "sp12", "m": "쓰기12"}, {"k": "s13", "n": "13", "w": "sp13", "m": "쓰기13"}, {"k": "s14", "n": "14", "w": "sp14", "m": "쓰기14"}, {"k": "s15", "n": "15", "w": "sp15", "m": "쓰기15"}, {"k": "s16", "n": "16", "w": "sp16", "m": "쓰기16"}, {"k": "s17", "n": "17", "w": "sp17", "m": "쓰기17"}, {"k": "s18", "n": "18", "w": "sp18", "m": "쓰기18"}, {"k": "s19", "n": "19", "w": "sp19", "m": "쓰기19"}, {"k": "s20", "n": "20", "w": "sp20", "m": "쓰기20"}, {"k": "s21", "n": "21", "w": "sp21", "m": "쓰기21"}, {"k": "s22", "n": "22", "w": "sp22", "m": "쓰기22"}, {"k": "s23", "n": "23", "w": "sp23", "m": "쓰기23"}, {"k": "s24", "n": "24", "w": "sp24", "m": "쓰기24"}]'::jsonb, 24, '2026-03-01T01:00:00+00:00'::timestamptz);
    insert into public.lec_set (id, kind, title, class_ids, posted_on, items, n, created_at) values ('00000000-0000-4000-8000-000000000014'::uuid, 'gu', '점검 v3 구문 쓰기', array['selftest-v3-c1'], '2026-03-01'::date, '[{"k": "g1", "n": "1", "e": "It is / 1.", "t": "그것은 1.", "p": ""}, {"k": "g2", "n": "2", "e": "It is / 2.", "t": "그것은 2.", "p": ""}, {"k": "g3", "n": "3", "e": "It is / 3.", "t": "그것은 3.", "p": ""}, {"k": "g4", "n": "4", "e": "It is / 4.", "t": "그것은 4.", "p": ""}]'::jsonb, 4, '2026-03-01T01:00:00+00:00'::timestamptz);
    r2 := '[{"id": "0000000000000000000000000003b001", "s": 11, "k": "a1", "d": "2026-03-09", "f": "c", "ok": true, "why": "", "i": 1, "ta": "2026-03-09T03:00:00+00:00"}, {"id": "0000000000000000000000000003b002", "s": 11, "k": "a2", "d": "2026-03-09", "f": "c", "ok": true, "why": "", "i": 2, "ta": "2026-03-09T03:01:00+00:00"}, {"id": "0000000000000000000000000003b003", "s": 11, "k": "a3", "d": "2026-03-09", "f": "c", "ok": false, "why": "", "i": 3, "ta": "2026-03-09T03:02:00+00:00"}, {"id": "0000000000000000000000000003b004", "s": 11, "k": "a4", "d": "2026-03-09", "f": "c", "ok": true, "why": "", "i": 4, "ta": "2026-03-09T03:03:00+00:00"}, {"id": "0000000000000000000000000003b005", "s": 11, "k": "a5", "d": "2026-03-09", "f": "c", "ok": true, "why": "", "i": 5, "ta": "2026-03-09T03:04:00+00:00"}, {"id": "0000000000000000000000000003b006", "s": 11, "k": "a6", "d": "2026-03-09", "f": "c", "ok": false, "why": "", "i": 6, "ta": "2026-03-09T03:05:00+00:00"}, {"id": "0000000000000000000000000003b007", "s": 11, "k": "a7", "d": "2026-03-09", "f": "c", "ok": true, "why": "", "i": 7, "ta": "2026-03-09T03:06:00+00:00"}, {"id": "0000000000000000000000000003b008", "s": 11, "k": "a8", "d": "2026-03-09", "f": "c", "ok": true, "why": "", "i": 8, "ta": "2026-03-09T03:07:00+00:00"}, {"id": "0000000000000000000000000003b009", "s": 11, "k": "b1", "d": "2026-03-09", "f": "r", "ok": true, "why": "", "i": 11, "ta": "2026-03-09T03:08:00+00:00"}, {"id": "0000000000000000000000000003b00a", "s": 11, "k": "b2", "d": "2026-03-09", "f": "r", "ok": true, "why": "", "i": 12, "ta": "2026-03-09T03:09:00+00:00"}, {"id": "0000000000000000000000000003b00b", "s": 11, "k": "b3", "d": "2026-03-09", "f": "r", "ok": true, "why": "", "i": 13, "ta": "2026-03-09T03:10:00+00:00"}, {"id": "0000000000000000000000000003b00c", "s": 11, "k": "n1", "d": "2026-03-09", "f": "r", "ok": true, "why": "", "i": 21, "ta": "2026-03-09T03:11:00+00:00"}, {"id": "0000000000000000000000000003b00d", "s": 11, "k": "n2", "d": "2026-03-09", "f": "r", "ok": true, "why": "", "i": 22, "ta": "2026-03-09T03:12:00+00:00"}, {"id": "0000000000000000000000000003b00e", "s": 12, "k": "q2", "d": "2026-03-08", "f": "r", "ok": true, "why": "", "i": 1, "ta": "2026-03-08T03:13:00+00:00"}, {"id": "0000000000000000000000000003b00f", "s": 13, "k": "s1", "d": "2026-03-08", "f": "sp", "ok": true, "why": "", "i": 1, "ta": "2026-03-08T03:14:00+00:00"}, {"id": "0000000000000000000000000003b010", "s": 13, "k": "s2", "d": "2026-03-08", "f": "sp", "ok": false, "why": "", "i": 1, "ta": "2026-03-08T03:15:00+00:00"}, {"id": "0000000000000000000000000003b011", "s": 13, "k": "s3", "d": "2026-03-07", "f": "sp", "ok": true, "why": "", "i": 1, "ta": "2026-03-07T03:16:00+00:00"}, {"id": "0000000000000000000000000003b012", "s": 13, "k": "s4", "d": "2026-03-08", "f": "sp", "ok": true, "why": "log", "i": 1, "ta": "2026-03-08T03:17:00+00:00"}, {"id": "0000000000000000000000000003b013", "s": 13, "k": "s5", "d": "2026-03-08", "f": "k", "ok": false, "why": "", "i": 1, "ta": "2026-03-08T03:18:00+00:00"}, {"id": "0000000000000000000000000003b014", "s": 14, "k": "g1", "d": "2026-03-08", "f": "ar", "ok": true, "why": "", "i": 1, "ta": "2026-03-08T03:19:00+00:00"}, {"id": "0000000000000000000000000003b015", "s": 14, "k": "g2", "d": "2026-03-08", "f": "ar", "ok": true, "why": "", "i": 1, "ta": "2026-03-08T03:20:00+00:00"}, {"id": "0000000000000000000000000003b016", "s": 14, "k": "g2", "d": "2026-03-08", "f": "se", "ok": true, "why": "", "i": 2, "ta": "2026-03-08T03:21:00+00:00"}]'::jsonb;
    for v_case in select * from (values
        ('문법 첫 판(새 포인트 A 8)', '00000000-0000-4000-8000-000000000011'::uuid, 'gram', '2026-03-10'::date, 0, '[]'::jsonb, 'a1:c,a2:c,a3:c,a4:c,a5:c,a6:c,a7:c,a8:c'),
        ('문법 둘째 판(새 포인트 B + 배운 A)', '00000000-0000-4000-8000-000000000011'::uuid, 'gram', '2026-03-10'::date, 8, '[]'::jsonb, 'b1:r,b2:r,b3:r'),
        ('문법 섞은 판(쌓인 오답 먼저 · 안 본 문항 먼저)', '00000000-0000-4000-8000-000000000011'::uuid, 'gram', '2026-03-10'::date, 11, '[{"a3": {"s": 1, "w": 1, "z": "2026-03-05"}, "a6": {"s": 1, "w": 1, "z": "2026-03-04"}}]'::jsonb, 'n1:r,n2:r'),
        ('문법 모두 배움(포인트 돌아가며 · 쌓인 오답 먼저)', '00000000-0000-4000-8000-000000000011'::uuid, 'gram', '2026-03-10'::date, 13, '[{"a3": {"s": 1, "w": 1, "z": "2026-03-05"}, "a6": {"s": 1, "w": 1, "z": "2026-03-04"}}]'::jsonb, 'a6:c:z,b1:r,n1:r,a3:c:z,b2:r,n2:r,a9:c,b3:r,a10:c,a1:c,a2:c,a4:c,a5:c,a7:c,a8:c'),
        ('문법 포인트 없음', '00000000-0000-4000-8000-000000000012'::uuid, 'gram', '2026-03-10'::date, 13, '[]'::jsonb, 'q1:r,q2:r,q3:r,q4:r,q5:r'),
        ('문법 포인트 없음 · 본 문항 뒤로', '00000000-0000-4000-8000-000000000012'::uuid, 'gram', '2026-03-10'::date, 14, '[]'::jsonb, 'q1:r,q3:r,q4:r,q5:r,q2:r'),
        ('써 보기 첫 판(차례 · 20)', '00000000-0000-4000-8000-000000000013'::uuid, 'spell', '2026-03-10'::date, 14, '[]'::jsonb, 's1:sp,s2:sp,s3:sp,s4:sp,s5:sp,s6:sp,s7:sp,s8:sp,s9:sp,s10:sp,s11:sp,s12:sp,s13:sp,s14:sp,s15:sp,s16:sp,s17:sp,s18:sp,s19:sp,s20:sp'),
        ('써 보기 틀림 → 안 씀 → 맞음(오래된 것 먼저)', '00000000-0000-4000-8000-000000000013'::uuid, 'spell', '2026-03-10'::date, 19, '[]'::jsonb, 's2:sp,s4:sp,s5:sp,s6:sp,s7:sp,s8:sp,s9:sp,s10:sp,s11:sp,s12:sp,s13:sp,s14:sp,s15:sp,s16:sp,s17:sp,s18:sp,s19:sp,s20:sp,s21:sp,s22:sp'),
        ('구문 써 보기(배열만 = 아직 · 통째 맞음 = 뒤)', '00000000-0000-4000-8000-000000000014'::uuid, 'guw', '2026-03-10'::date, 22, '[]'::jsonb, 'g1:gw,g3:gw,g4:gw,g2:gw')
      ) as x(nm, s, md, d, nl, pg, w) loop
      delete from public.lec_set_log xl where xl.sid = 'selftest-v3a|점검가' and xl.set_id = v_case.s;
      delete from public.lec_set_prog xp where xp.sid = 'selftest-v3a|점검가' and xp.set_id = v_case.s;
      insert into public.lec_set_log (id, sid, b, bk, i, set_id, k, f, v, ok, ta, day, bo, why)
      select y.e ->> 'id', 'selftest-v3a|점검가', '00000000-0000-4000-8000-000000000999'::uuid, 'log', (y.e ->> 'i')::integer, v_case.s, y.e ->> 'k', y.e ->> 'f',
             '', (y.e ->> 'ok')::boolean, (y.e ->> 'ta')::timestamptz, (y.e ->> 'd')::date, (y.e ->> 'ta')::timestamptz, y.e ->> 'why'
        from jsonb_array_elements(r2) with ordinality as y(e, o)
       where y.o <= v_case.nl and ltrim(right(v_case.s::text, 12), '0') = y.e ->> 's';
      insert into public.lec_set_prog (sid, set_id, cards, first_at)
      select 'selftest-v3a|점검가', v_case.s, y.e, '2026-03-09T01:00:00+00:00'::timestamptz from jsonb_array_elements(v_case.pg) as y(e);
      select * into v_set from public.lec_set xs where xs.id = v_case.s;
      r := public.lec__v2_pan('selftest-v3a|점검가', v_set, v_case.md, v_case.d);
      select coalesce(string_agg((x.e ->> 'k') || ':' || (x.e ->> 'f') || case when x.e ? 'z' then ':z' else '' end, ',' order by x.o), '')
        into v_t from jsonb_array_elements(r) with ordinality as x(e, o);
      if v_t is distinct from v_case.w or jsonb_path_exists(r, '$[*] ? (@.s != $s)', jsonb_build_object('s', v_case.s))
         or jsonb_path_exists(r, '$[*].z ? (@ != true)') then
        raise exception '점검 실패(V3 판 꾸리기 «%»): %', v_case.nm, r;
      end if;
    end loop;

    -- 2) 준비: 스위치 모두 끔 · 학생(위 사례표의 학생 · 두 반 · 기록 동의)
    update public.lec_v2_cfg set log = false, eval = false, spell = false, guw = false, gram = false, review = false, lim = 3000
     where id = 1;
    v_ka := 'selftest' || v_ks || 'v3a';
    insert into public.lec_key (kh, sid, rid, pin, sname, cls)
    values (public.lec__kh(v_ka), v_sa, 'selftest-v3a', '', '점검가', array['selftest-v3-c1', 'selftest-v3-c2']);
    insert into public.lec_consent (sid, choice, ver) values (v_sa, 'agree', public.lec__consent_ver());

    -- 3) 스위치 끔 = V2-1 그대로(목록 todo = 쌓인 오답 수 · 새 판 off) · eval 만 켜도 새 판 off · todo 그대로
    r := public.lec_set_home_v2(v_ka, null);
    if (r ->> 'ok') is distinct from 'true' or (r - 'v2' - 'ts' - 'todo') is distinct from public.lec_set_home(v_ka)
       or (r -> 'todo') is distinct from jsonb_build_object('n', coalesce(r #> '{due,n}', '0'::jsonb)) then
      raise exception '점검 실패(V3 스위치 끔 · 목록): %', left(r::text, 600);
    end if;
    if (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000013'::uuid, 'spell') ->> 'err') is distinct from 'off'
       or (public.lec_set_open_v2(v_ka, null, 'review') ->> 'err') is distinct from 'off' then
      raise exception '점검 실패(V3 스위치 끔 · 새 판)';
    end if;
    update public.lec_v2_cfg set log = true, eval = true where id = 1;
    r := public.lec_set_home_v2(v_ka, null);
    if (r -> 'todo') is distinct from jsonb_build_object('n', coalesce(r #> '{due,n}', '0'::jsonb))
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000013'::uuid, 'spell') ->> 'err') is distinct from 'off'
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000014'::uuid, 'guw') ->> 'err') is distinct from 'off'
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000011'::uuid, 'gram') ->> 'err') is distinct from 'off'
       or (public.lec_set_open_v2(v_ka, null, 'review') ->> 'err') is distinct from 'off'
       or (public.lec_set_open_v2(v_ka, null, 'x') ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(V3 판 스위치 끔)';
    end if;

    -- 4) 켬: 켠 날 트리거(끔 → 켬 = 서버 오늘 · 켠 채 칸만 · 다른 칸 · 끄기 = 그대로 · 다시 켬 = 새 날) ·
    --    켠 날 = 오늘이면 놓친 날(gr 0) 없음 · 칸 빔 = 아주 앞 날(자르지 않음) · 아래 점검은 켠 날을 아주 앞으로 두고(옛 일정 날도 침)
    --    목록 todo = lec__v2_sum(n · day 서버 오늘 · ex · kd)
    update public.lec_v2_cfg set spell = true, guw = true, gram = true, review = true where id = 1;
    if (select c.review_on from public.lec_v2_cfg c where c.id = 1) is distinct from v_d then
      raise exception '점검 실패(V3 켠 날 · 켬)';
    end if;
    update public.lec_v2_cfg set review_on = date '2000-01-01' where id = 1;
    update public.lec_v2_cfg set lim = 3000, updated_at = now() where id = 1;
    update public.lec_v2_cfg set review = false where id = 1;
    if (select c.review_on from public.lec_v2_cfg c where c.id = 1) is distinct from date '2000-01-01' then
      raise exception '점검 실패(V3 켠 날 · 그대로)';
    end if;
    update public.lec_v2_cfg set review = true where id = 1;
    if (select c.review_on from public.lec_v2_cfg c where c.id = 1) is distinct from v_d then
      raise exception '점검 실패(V3 켠 날 · 다시 켬)';
    end if;
    if exists (select 1 from public.lec__v2_todo(v_sa, array['selftest-v3-c1', 'selftest-v3-c2'], public.lec__v2_ex(v_sa), v_d, v_d) z
                where z.gr = 0)
       or (select count(*) from public.lec__v2_todo(v_sa, array['selftest-v3-c1', 'selftest-v3-c2'], public.lec__v2_ex(v_sa), v_d, null) z)
          is distinct from
          (select count(*) from public.lec__v2_todo(v_sa, array['selftest-v3-c1', 'selftest-v3-c2'], public.lec__v2_ex(v_sa), v_d, date '2000-01-01') z)
       or (public.lec__v2_sum(v_sa, array['selftest-v3-c1', 'selftest-v3-c2']) ->> 'n')::integer
          is distinct from
          (select count(*) from public.lec__v2_todo(v_sa, array['selftest-v3-c1', 'selftest-v3-c2'], public.lec__v2_ex(v_sa), v_d, v_d) z)::integer then
      raise exception '점검 실패(V3 켠 날 · 자름)';
    end if;
    update public.lec_v2_cfg set review_on = date '2000-01-01' where id = 1;
    r := public.lec_set_home_v2(v_ka, null);
    if (r -> 'todo') is distinct from public.lec__v2_sum(v_sa, array['selftest-v3-c1', 'selftest-v3-c2'])
       or (r #>> '{todo,day}') is distinct from to_char(v_d, 'YYYY-MM-DD')
       or coalesce((r #>> '{todo,n}')::integer, 0) < 1
       or (r #>> '{todo,n}')::integer is distinct from (r #>> '{todo,kd,voc}')::integer + (r #>> '{todo,kd,gu}')::integer + (r #>> '{todo,kd,gram}')::integer then
      raise exception '점검 실패(V3 목록 오늘 볼 것): %', left((r -> 'todo')::text, 600);
    end if;

    -- 5) 써 보기: 판 20 · 바른 답 같이 · 틀린 문항 먼저 · 이어서 같은 판 · 다른 종류 = kind · 없는 세트 = none · 시험 중 = testing
    r := public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000013'::uuid, 'spell');
    v_b := (r ->> 'b')::uuid;
    if (r ->> 'ok') is distinct from 'true' or (r ->> 'n') is distinct from '20' or (r ->> 'md') is distinct from 'spell'
       or (r #>> '{q,0,k}') is distinct from 's2' or (r #>> '{q,0,f}') is distinct from 'sp' or (r #>> '{q,0,a}') is distinct from 'sp2'
       or (r #>> '{q,0,p}') is distinct from '쓰기2' or (r #>> '{q,0,kd}') is distinct from 'voc' or v_b is null
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000013'::uuid, 'spell') ->> 'b')::uuid is distinct from v_b
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000011'::uuid, 'spell') ->> 'err') is distinct from 'kind'
       or (public.lec_set_open_v2(v_ka, gen_random_uuid(), 'spell') ->> 'err') is distinct from 'none'
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000006'::uuid, 'spell') ->> 'err') is distinct from 'testing' then
      raise exception '점검 실패(V3 써 보기 열기): %', left(r::text, 600);
    end if;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', 'a3a' || substr(v_ks, 1, 29), 'b', v_b, 'i', 1, 's', '00000000-0000-4000-8000-000000000013',
                              'k', 's2', 'f', 'sp', 'v', 'sp2', 'h', false, 'ms', 3000),
           jsonb_build_object('id', 'b3b' || substr(v_ks, 1, 29), 'b', v_b, 'i', 2, 's', '00000000-0000-4000-8000-000000000013',
                              'k', 's6', 'f', 'sp', 'v', 'sp6', 'h', true, 'ms', 5000, 'n', 2)));
    if jsonb_array_length(r -> 'got') is distinct from 2
       or not exists (select 1 from public.lec_set_log xl where xl.id = 'a3a' || substr(v_ks, 1, 29) and xl.bk = 'spell' and xl.f = 'sp'
                        and xl.sr and xl.ok and xl.src = 'card' and xl.done and xl.why = '' and xl.ms = 3000)
       or not exists (select 1 from public.lec_set_log xl where xl.id = 'b3b' || substr(v_ks, 1, 29) and xl.sr and not xl.ok and xl.h)
       or not exists (select 1 from public.lec_set_prog xp
                       where xp.sid = v_sa and xp.set_id = '00000000-0000-4000-8000-000000000013'::uuid
                         and xp.cards -> 's2' -> 'd' = jsonb_build_array(to_char(v_d, 'YYYY-MM-DD')) and not (xp.cards -> 's2' ? 't')
                         and xp.cards -> 's6' = '{"s": 1}'::jsonb)
       or (select xr.end_n from public.lec_set_run xr where xr.id = v_b) is distinct from 2
       or (public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000013'::uuid, 'spell') ->> 'no') is distinct from '2' then
      raise exception '점검 실패(V3 써 보기 줄 · 카드): %', left(r::text, 600);
    end if;

    -- 6) 구문 써 보기: 배열(ar · 맞음 = 첫 답) → 통째(se · 첫 글자 힌트 = 틀림) · 틀린 통째 · 카드 꼴 say
    r := public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000014'::uuid, 'guw');
    v_b := (r ->> 'b')::uuid;
    if (r #>> '{q,0,k}') is distinct from 'g1' or (r #>> '{q,0,f}') is distinct from 'gw' or (r #>> '{q,0,a}') is distinct from 'It is / 1.'
       or (r #>> '{q,0,p}') is distinct from '그것은 1.' or (r #>> '{q,3,k}') is distinct from 'g2' then
      raise exception '점검 실패(V3 구문 열기): %', left(r::text, 600);
    end if;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', 'c3c' || substr(v_ks, 1, 29), 'b', v_b, 'i', 1, 's', '00000000-0000-4000-8000-000000000014',
                              'k', 'g1', 'f', 'ar', 'v', 'It is 1.'),
           jsonb_build_object('id', 'd3d' || substr(v_ks, 1, 29), 'b', v_b, 'i', 2, 's', '00000000-0000-4000-8000-000000000014',
                              'k', 'g1', 'f', 'se', 'v', 'it is 1', 'h', true),
           jsonb_build_object('id', 'e3e' || substr(v_ks, 1, 29), 'b', v_b, 'i', 3, 's', '00000000-0000-4000-8000-000000000014',
                              'k', 'g3', 'f', 'se', 'v', 'It is three.')));
    if (select count(*) from public.lec_set_log xl
         where (xl.id = 'c3c' || substr(v_ks, 1, 29) and xl.f = 'ar' and xl.sr and xl.ok and xl.src = 'say')
            or (xl.id = 'd3d' || substr(v_ks, 1, 29) and xl.f = 'se' and xl.sr and not xl.ok)
            or (xl.id = 'e3e' || substr(v_ks, 1, 29) and xl.f = 'se' and not xl.sr and not xl.ok and xl.bk = 'guw')) is distinct from 3::bigint then
      raise exception '점검 실패(V3 구문 줄): %', left(r::text, 600);
    end if;

    -- 7) 문법: 모두 배운 세트 = 포인트 돌아가며 · 쌓인 오답 문항 먼저(z) · 보기 · 해설 칸 · 쌓인 오답 맞음 = due(d · y · t 없음)
    r := public.lec_set_open_v2(v_ka, '00000000-0000-4000-8000-000000000011'::uuid, 'gram');
    v_b := (r ->> 'b')::uuid;
    if (r #>> '{q,0,k}') is distinct from 'a6' or (r #> '{q,0,z}') is distinct from 'true'::jsonb or (r #>> '{q,0,f}') is distinct from 'c'
       or (r #> '{q,0,o}') is distinct from '["x", "y"]'::jsonb or (r #>> '{q,0,a}') is distinct from 'x' or (r #>> '{q,0,pt}') is distinct from '포인트 A'
       or (r #>> '{q,0,x}') is distinct from '' or (r #>> '{q,1,k}') is distinct from 'b1' or (r #>> '{q,1,f}') is distinct from 'r'
       or (r #> '{q,1,o}') is distinct from 'null'::jsonb or (r #> '{q,1,z}') is not null
       or (r #>> '{q,2,k}') is distinct from 'n1' or (r ->> 'n') is distinct from '15' or (r ->> 'kd') is distinct from 'gram' then
      raise exception '점검 실패(V3 문법 열기): %', left(r::text, 600);
    end if;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', 'f3f' || substr(v_ks, 1, 29), 'b', v_b, 'i', 1, 's', '00000000-0000-4000-8000-000000000011',
                              'k', 'a6', 'f', 'c', 'v', 'x')));
    if not exists (select 1 from public.lec_set_log xl where xl.id = 'f3f' || substr(v_ks, 1, 29) and xl.src = 'due' and xl.ok and xl.bk = 'gram')
       or not exists (select 1 from public.lec_set_prog xp
                       where xp.sid = v_sa and xp.set_id = '00000000-0000-4000-8000-000000000011'::uuid
                         and xp.cards -> 'a6' -> 'y' = jsonb_build_array(to_char(v_d, 'YYYY-MM-DD')) and (xp.cards -> 'a6' ->> 'z') = '2026-03-04'
                         and not (xp.cards -> 'a6' ? 't')) then
      raise exception '점검 실패(V3 문법 줄 · 카드): %', left(r::text, 600);
    end if;

    -- 8) 오늘 볼 것 판: 한 종류(단어 먼저 · 써 보기 꼴) · 20 까지 · 남은 수 · 시험 중 세트 문항 0 · 평가를 열면 판 닫힘 · 닫힌 뒤 답 = 기록만
    r := public.lec_set_open_v2(v_ka, null, 'review');
    v_b := (r ->> 'b')::uuid;
    if (r ->> 'ok') is distinct from 'true' or (r ->> 'md') is distinct from 'review' or (r ->> 'kd') is distinct from 'voc'
       or (r ->> 'title') is distinct from '오늘 볼 것' or coalesce((r ->> 'n')::integer, 0) not between 1 and 20
       or exists (select 1 from jsonb_array_elements(r -> 'q') as x(e) where x.e ->> 'kd' <> 'voc' or x.e ->> 'f' <> 'sp' or x.e ->> 'a' is null)
       or r::text like '%00000000-0000-4000-8000-000000000006%'
       or jsonb_typeof(r -> 'left') is distinct from 'object' or coalesce((r #>> '{left,gu}')::integer, 0) < 1
       or not (r::text like '%00000000-0000-4000-8000-000000000001%')
       or (public.lec_set_open_v2(v_ka, null, 'review') ->> 'b')::uuid is distinct from v_b then
      raise exception '점검 실패(V3 오늘 볼 것 판): %', left(r::text, 800);
    end if;
    r2 := public.lec_set_test_v2(v_ka, '00000000-0000-4000-8000-000000000001'::uuid);
    if (r2 ->> 'ok') is distinct from 'true'
       or not exists (select 1 from public.lec_set_run xr where xr.id = v_b and xr.shut ? '00000000-0000-4000-8000-000000000001') then
      raise exception '점검 실패(V3 평가 열면 오늘 볼 것 판 닫힘): %', left(r2::text, 600);
    end if;
    perform public.lec_set_log_v2(v_ka, jsonb_build_array(
              jsonb_build_object('id', '93a' || substr(v_ks, 1, 29), 'b', v_b, 'i', 1, 's', '00000000-0000-4000-8000-000000000001',
                                 'k', 'k1', 'f', 'sp', 'v', 'w1')));
    r := public.lec_set_open_v2(v_ka, null, 'review');
    if not exists (select 1 from public.lec_set_log xl where xl.id = '93a' || substr(v_ks, 1, 29) and xl.why = 'shut' and not xl.done)
       or (r ->> 'b')::uuid is not distinct from v_b or r::text like '%00000000-0000-4000-8000-000000000001%'
       or jsonb_path_exists(r2, '$.**.a') then
      raise exception '점검 실패(V3 평가 중 오늘 볼 것): %', left(r::text, 600);
    end if;

    -- 9) 권한: 새 속 함수는 밖에서 못 부름 · 학생 함수는 V2-1 그대로
    if has_function_privilege('anon', 'public.lec__v2_todo(text, text[], jsonb, date, date)', 'execute')
       or has_function_privilege('anon', 'public.lec__v2_revon()', 'execute')
       or has_function_privilege('authenticated', 'public.lec__v2_open3(public.lec_key, uuid, text)', 'execute')
       or has_function_privilege('anon', 'public.lec__v2_judge(public.lec_set_run, text[], jsonb)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_open_v2(text, uuid, text)', 'execute') then
      raise exception '점검 실패(V3 권한)';
    end if;
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 7) = 'lec__v2'
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(V3 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- 열두째 스스로 점검(V2-1): 판정 표(_check/class_v2_vectors.json) · 없는 열쇠 · 스위치 끔 = 옛 판 그대로 · 폰이 만든 판 = 기록만 ·
--   켬: 외우기 판(이어서 · 같은 줄 두 번 · 앞 순번 늦게) · 쌓인 오답 판(늦게 온 앞 판 줄 = 그 카드만 다시 셈 = 차례대로 보낸 값) ·
--   판 도중 스위치 끔(그래도 반영) · 늦은 날 줄 · 하루 한도 · 평가 열기(바른 답 칸 0 · 연습 판 닫음 · 닫힌 뒤 답 = 기록만) ·
--   중간 저장(바른 답 0 · 먼저 온 답이 남음) · 내기(덜 참 · 끝 · 다시 내도 같은 결과) · 지켜보기(원장님만) · 이름 바뀜 · 지움 · 권한
-- 넣은 세트 · 열쇠 · 동의 · 줄 · 스위치는 끝에 되돌려 남지 않습니다
do $$
declare
  r       jsonb;
  r2      jsonb;
  v_t     text;
  v_ks    text := replace(gen_random_uuid()::text, '-', '');
  v_ka    text;
  v_sa    text := 'selftest-v2a|점검가';
  v_cl    text;
  v_sv    uuid;
  v_sg    uuid;
  v_sr    uuid;
  v_b     uuid;
  v_b2    uuid;
  v_bd    uuid;
  v_try   uuid;
  v_card  jsonb;
  v_c2    jsonb;
  v_qs    jsonb;
  v_items jsonb;
  v_n     integer;
  v_case  record;
  v_d     date := public.lec__set_today();
begin
  begin
    -- 1) 판정 표(_check/class_v2_vectors.json 과 같은 값 · class_v2_vec.py render 가 만든 글)
    for v_case in select * from (values
        ('I / am a boy.', 'i am a boy'),
        ('  Hello,   World!  ', 'hello world'),
        ('don' || chr(8217) || 't', 'don''t'),
        ('Wait' || chr(8230) || ' what?', 'wait what'),
        ('a ; b : c', 'a b c'),
        ('"Quote"', 'quote'),
        ('', ''),
        (null::text, ''),
        (' . , ', ''),
        ('A/B', 'a b'),
        ('x' || chr(160) || 'y', 'x y'),
        ('e-mail', 'e-mail'),
        ('(that)', '(that)'),
        ('one' || chr(9) || 'two' || chr(10) || 'three' || chr(13), 'one two three'),
        ('look ~ up', 'look up'),
        ('cafe' || chr(769), 'caf' || chr(233)),
        (chr(65313) || 'BC', chr(65313) || 'bc')
      ) as x(a, b) loop
      if public.lec__set_snorm_v2(v_case.a) is distinct from v_case.b then raise exception '점검 실패(V2 판정 snorm «%»)', v_case.a; end if;
    end loop;
    for v_case in select * from (values
        ('I am a boy.', 'I / am a boy.', true),
        ('I / am a boy.', 'I / am a boy.', true),
        ('i am a boy.', 'I / am a boy.', true),
        ('I AM A BOY.', 'I / am a boy.', true),
        ('I am a boy.', 'I / am a boy.', true),
        ('I am a boy', 'I / am a boy.', true),
        ('I am a boy. . ', 'I / am a boy.', true),
        ('  I' || chr(9) || ' am a boy.' || chr(10), 'I / am a boy.', true),
        ('I am a boy.', 'I / am a boy.', true),
        ('I' || chr(160) || 'am a boy.', 'I / am a boy.', true),
        ('I am a', 'I / am a boy.', false),
        ('am I a boy.', 'I / am a boy.', false),
        ('I am a boy. too', 'I / am a boy.', false),
        ('I I am a boy.', 'I / am a boy.', false),
        ('I', 'I / am a boy.', false),
        (chr(65321) || ' am a boy.', 'I / am a boy.', false),
        ('She has been to Paris twice.', 'She has been / to Paris / twice.', true),
        ('She has been / to Paris / twice.', 'She has been / to Paris / twice.', true),
        ('she has been to paris twice.', 'She has been / to Paris / twice.', true),
        ('SHE HAS BEEN TO PARIS TWICE.', 'She has been / to Paris / twice.', true),
        ('She has been to Paris twice.', 'She has been / to Paris / twice.', true),
        ('She has been to Paris twice', 'She has been / to Paris / twice.', true),
        ('She has been to Paris twice. . ', 'She has been / to Paris / twice.', true),
        ('  She' || chr(9) || ' has been to Paris twice.' || chr(10), 'She has been / to Paris / twice.', true),
        ('She has been to Paris twice.', 'She has been / to Paris / twice.', true),
        ('She' || chr(160) || 'has been to Paris twice.', 'She has been / to Paris / twice.', true),
        ('She has been to Paris', 'She has been / to Paris / twice.', false),
        ('has She been to Paris twice.', 'She has been / to Paris / twice.', false),
        ('She has been to Paris twice. too', 'She has been / to Paris / twice.', false),
        ('She She has been to Paris twice.', 'She has been / to Paris / twice.', false),
        ('She has been', 'She has been / to Paris / twice.', false),
        (chr(65331) || 'he has been to Paris twice.', 'She has been / to Paris / twice.', false),
        ('What do you want to do after school?', 'What do you / want to do / after school?', true),
        ('What do you / want to do / after school?', 'What do you / want to do / after school?', true),
        ('what do you want to do after school?', 'What do you / want to do / after school?', true),
        ('WHAT DO YOU WANT TO DO AFTER SCHOOL?', 'What do you / want to do / after school?', true),
        ('What do you want to do after school?', 'What do you / want to do / after school?', true),
        ('What do you want to do after school', 'What do you / want to do / after school?', true),
        ('What do you want to do after school? . ', 'What do you / want to do / after school?', true),
        ('  What' || chr(9) || ' do you want to do after school?' || chr(10), 'What do you / want to do / after school?', true),
        ('What do you want to do after school?', 'What do you / want to do / after school?', true),
        ('What' || chr(160) || 'do you want to do after school?', 'What do you / want to do / after school?', true),
        ('What do you want to do after', 'What do you / want to do / after school?', false),
        ('do What you want to do after school?', 'What do you / want to do / after school?', false),
        ('What do you want to do after school? too', 'What do you / want to do / after school?', false),
        ('What What do you want to do after school?', 'What do you / want to do / after school?', false),
        ('What do you', 'What do you / want to do / after school?', false),
        (chr(65335) || 'hat do you want to do after school?', 'What do you / want to do / after school?', false),
        ('It''s not easy to learn English.', 'It''s / not easy / to learn English.', true),
        ('It''s / not easy / to learn English.', 'It''s / not easy / to learn English.', true),
        ('it''s not easy to learn english.', 'It''s / not easy / to learn English.', true),
        ('IT''S NOT EASY TO LEARN ENGLISH.', 'It''s / not easy / to learn English.', true),
        ('It''s not easy to learn English.', 'It''s / not easy / to learn English.', true),
        ('It''s not easy to learn English', 'It''s / not easy / to learn English.', true),
        ('It''s not easy to learn English. . ', 'It''s / not easy / to learn English.', true),
        ('  It''s' || chr(9) || ' not easy to learn English.' || chr(10), 'It''s / not easy / to learn English.', true),
        ('It' || chr(8217) || 's not easy to learn English.', 'It''s / not easy / to learn English.', true),
        ('It''s' || chr(160) || 'not easy to learn English.', 'It''s / not easy / to learn English.', true),
        ('It''s not easy to learn', 'It''s / not easy / to learn English.', false),
        ('not It''s easy to learn English.', 'It''s / not easy / to learn English.', false),
        ('It''s not easy to learn English. too', 'It''s / not easy / to learn English.', false),
        ('It''s It''s not easy to learn English.', 'It''s / not easy / to learn English.', false),
        ('It''s', 'It''s / not easy / to learn English.', false),
        ('Its not easy to learn English.', 'It''s / not easy / to learn English.', false),
        (chr(65321) || 't''s not easy to learn English.', 'It''s / not easy / to learn English.', false),
        ('If I were you, I would take the job.', 'If I were you, / I would / take the job.', true),
        ('If I were you, / I would / take the job.', 'If I were you, / I would / take the job.', true),
        ('if i were you, i would take the job.', 'If I were you, / I would / take the job.', true),
        ('IF I WERE YOU, I WOULD TAKE THE JOB.', 'If I were you, / I would / take the job.', true),
        ('If I were you I would take the job.', 'If I were you, / I would / take the job.', true),
        ('If I were you, I would take the job', 'If I were you, / I would / take the job.', true),
        ('If I were you, I would take the job. . ', 'If I were you, / I would / take the job.', true),
        ('  If' || chr(9) || ' I were you, I would take the job.' || chr(10), 'If I were you, / I would / take the job.', true),
        ('If I were you, I would take the job.', 'If I were you, / I would / take the job.', true),
        ('If' || chr(160) || 'I were you, I would take the job.', 'If I were you, / I would / take the job.', true),
        ('If I were you, I would take the', 'If I were you, / I would / take the job.', false),
        ('I If were you, I would take the job.', 'If I were you, / I would / take the job.', false),
        ('If I were you, I would take the job. too', 'If I were you, / I would / take the job.', false),
        ('If If I were you, I would take the job.', 'If I were you, / I would / take the job.', false),
        ('If I were you,', 'If I were you, / I would / take the job.', false),
        (chr(65321) || 'f I were you, I would take the job.', 'If I were you, / I would / take the job.', false),
        ('He said, "I can do it!"', 'He said, / "I can do it!"', true),
        ('He said, / "I can do it!"', 'He said, / "I can do it!"', true),
        ('he said, "i can do it!"', 'He said, / "I can do it!"', true),
        ('HE SAID, "I CAN DO IT!"', 'He said, / "I can do it!"', true),
        ('He said "I can do it!"', 'He said, / "I can do it!"', true),
        ('He said, "I can do it!"', 'He said, / "I can do it!"', true),
        ('He said, "I can do it!" . ', 'He said, / "I can do it!"', true),
        ('  He' || chr(9) || ' said, "I can do it!"' || chr(10), 'He said, / "I can do it!"', true),
        ('He said, ' || chr(8220) || 'I can do it!' || chr(8221), 'He said, / "I can do it!"', true),
        ('He' || chr(160) || 'said, "I can do it!"', 'He said, / "I can do it!"', true),
        ('He said, "I can do', 'He said, / "I can do it!"', false),
        ('said, He "I can do it!"', 'He said, / "I can do it!"', false),
        ('He said, "I can do it!" too', 'He said, / "I can do it!"', false),
        ('He He said, "I can do it!"', 'He said, / "I can do it!"', false),
        ('He said,', 'He said, / "I can do it!"', false),
        (chr(65320) || 'e said, "I can do it!"', 'He said, / "I can do it!"', false),
        ('Don''t give up on your dream.', 'Don''t / give up / on your dream.', true),
        ('Don''t / give up / on your dream.', 'Don''t / give up / on your dream.', true),
        ('don''t give up on your dream.', 'Don''t / give up / on your dream.', true),
        ('DON''T GIVE UP ON YOUR DREAM.', 'Don''t / give up / on your dream.', true),
        ('Don''t give up on your dream.', 'Don''t / give up / on your dream.', true),
        ('Don''t give up on your dream', 'Don''t / give up / on your dream.', true),
        ('Don''t give up on your dream. . ', 'Don''t / give up / on your dream.', true),
        ('  Don''t' || chr(9) || ' give up on your dream.' || chr(10), 'Don''t / give up / on your dream.', true),
        ('Don' || chr(8217) || 't give up on your dream.', 'Don''t / give up / on your dream.', true),
        ('Don''t' || chr(160) || 'give up on your dream.', 'Don''t / give up / on your dream.', true),
        ('Don''t give up on your', 'Don''t / give up / on your dream.', false),
        ('give Don''t up on your dream.', 'Don''t / give up / on your dream.', false),
        ('Don''t give up on your dream. too', 'Don''t / give up / on your dream.', false),
        ('Don''t Don''t give up on your dream.', 'Don''t / give up / on your dream.', false),
        ('Don''t', 'Don''t / give up / on your dream.', false),
        ('Dont give up on your dream.', 'Don''t / give up / on your dream.', false),
        (chr(65316) || 'on''t give up on your dream.', 'Don''t / give up / on your dream.', false),
        ('The well-known singer came to our town.', 'The well-known singer / came / to our town.', true),
        ('The well-known singer / came / to our town.', 'The well-known singer / came / to our town.', true),
        ('the well-known singer came to our town.', 'The well-known singer / came / to our town.', true),
        ('THE WELL-KNOWN SINGER CAME TO OUR TOWN.', 'The well-known singer / came / to our town.', true),
        ('The well-known singer came to our town.', 'The well-known singer / came / to our town.', true),
        ('The well-known singer came to our town', 'The well-known singer / came / to our town.', true),
        ('The well-known singer came to our town. . ', 'The well-known singer / came / to our town.', true),
        ('  The' || chr(9) || ' well-known singer came to our town.' || chr(10), 'The well-known singer / came / to our town.', true),
        ('The well-known singer came to our town.', 'The well-known singer / came / to our town.', true),
        ('The' || chr(160) || 'well-known singer came to our town.', 'The well-known singer / came / to our town.', true),
        ('The well-known singer came to our', 'The well-known singer / came / to our town.', false),
        ('well-known The singer came to our town.', 'The well-known singer / came / to our town.', false),
        ('The well-known singer came to our town. too', 'The well-known singer / came / to our town.', false),
        ('The The well-known singer came to our town.', 'The well-known singer / came / to our town.', false),
        ('The well-known singer', 'The well-known singer / came / to our town.', false),
        ('The well known singer came to our town.', 'The well-known singer / came / to our town.', false),
        ('The wellknown singer came to our town.', 'The well-known singer / came / to our town.', false),
        (chr(65332) || 'he well-known singer came to our town.', 'The well-known singer / came / to our town.', false),
        ('Please send me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', true),
        ('Please send me / an e-mail / by Friday.', 'Please send me / an e-mail / by Friday.', true),
        ('please send me an e-mail by friday.', 'Please send me / an e-mail / by Friday.', true),
        ('PLEASE SEND ME AN E-MAIL BY FRIDAY.', 'Please send me / an e-mail / by Friday.', true),
        ('Please send me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', true),
        ('Please send me an e-mail by Friday', 'Please send me / an e-mail / by Friday.', true),
        ('Please send me an e-mail by Friday. . ', 'Please send me / an e-mail / by Friday.', true),
        ('  Please' || chr(9) || ' send me an e-mail by Friday.' || chr(10), 'Please send me / an e-mail / by Friday.', true),
        ('Please send me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', true),
        ('Please' || chr(160) || 'send me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', true),
        ('Please send me an e-mail by', 'Please send me / an e-mail / by Friday.', false),
        ('send Please me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', false),
        ('Please send me an e-mail by Friday. too', 'Please send me / an e-mail / by Friday.', false),
        ('Please Please send me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', false),
        ('Please send me', 'Please send me / an e-mail / by Friday.', false),
        ('Please send me an e mail by Friday.', 'Please send me / an e-mail / by Friday.', false),
        ('Please send me an email by Friday.', 'Please send me / an e-mail / by Friday.', false),
        (chr(65328) || 'lease send me an e-mail by Friday.', 'Please send me / an e-mail / by Friday.', false),
        ('Wait... is that your bag?', 'Wait... / is that / your bag?', true),
        ('Wait... / is that / your bag?', 'Wait... / is that / your bag?', true),
        ('wait... is that your bag?', 'Wait... / is that / your bag?', true),
        ('WAIT... IS THAT YOUR BAG?', 'Wait... / is that / your bag?', true),
        ('Wait... is that your bag?', 'Wait... / is that / your bag?', true),
        ('Wait... is that your bag', 'Wait... / is that / your bag?', true),
        ('Wait... is that your bag? . ', 'Wait... / is that / your bag?', true),
        ('  Wait...' || chr(9) || ' is that your bag?' || chr(10), 'Wait... / is that / your bag?', true),
        ('Wait... is that your bag?', 'Wait... / is that / your bag?', true),
        ('Wait...' || chr(160) || 'is that your bag?', 'Wait... / is that / your bag?', true),
        ('Wait... is that your', 'Wait... / is that / your bag?', false),
        ('is Wait... that your bag?', 'Wait... / is that / your bag?', false),
        ('Wait... is that your bag? too', 'Wait... / is that / your bag?', false),
        ('Wait... Wait... is that your bag?', 'Wait... / is that / your bag?', false),
        ('Wait...', 'Wait... / is that / your bag?', false),
        ('Wait' || chr(8230) || ' is that your bag?', 'Wait... / is that / your bag?', true),
        (chr(65335) || 'ait... is that your bag?', 'Wait... / is that / your bag?', false),
        ('We should do one''s best every day.', 'We should / do one''s best / every day.', true),
        ('We should / do one''s best / every day.', 'We should / do one''s best / every day.', true),
        ('we should do one''s best every day.', 'We should / do one''s best / every day.', true),
        ('WE SHOULD DO ONE''S BEST EVERY DAY.', 'We should / do one''s best / every day.', true),
        ('We should do one''s best every day.', 'We should / do one''s best / every day.', true),
        ('We should do one''s best every day', 'We should / do one''s best / every day.', true),
        ('We should do one''s best every day. . ', 'We should / do one''s best / every day.', true),
        ('  We' || chr(9) || ' should do one''s best every day.' || chr(10), 'We should / do one''s best / every day.', true),
        ('We should do one' || chr(8217) || 's best every day.', 'We should / do one''s best / every day.', true),
        ('We' || chr(160) || 'should do one''s best every day.', 'We should / do one''s best / every day.', true),
        ('We should do one''s best every', 'We should / do one''s best / every day.', false),
        ('should We do one''s best every day.', 'We should / do one''s best / every day.', false),
        ('We should do one''s best every day. too', 'We should / do one''s best / every day.', false),
        ('We We should do one''s best every day.', 'We should / do one''s best / every day.', false),
        ('We should', 'We should / do one''s best / every day.', false),
        ('We should do ones best every day.', 'We should / do one''s best / every day.', false),
        (chr(65335) || 'e should do one''s best every day.', 'We should / do one''s best / every day.', false),
        ('Running every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', true),
        ('Running / every morning / keeps me healthy.', 'Running / every morning / keeps me healthy.', true),
        ('running every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', true),
        ('RUNNING EVERY MORNING KEEPS ME HEALTHY.', 'Running / every morning / keeps me healthy.', true),
        ('Running every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', true),
        ('Running every morning keeps me healthy', 'Running / every morning / keeps me healthy.', true),
        ('Running every morning keeps me healthy. . ', 'Running / every morning / keeps me healthy.', true),
        ('  Running' || chr(9) || ' every morning keeps me healthy.' || chr(10), 'Running / every morning / keeps me healthy.', true),
        ('Running every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', true),
        ('Running' || chr(160) || 'every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', true),
        ('Running every morning keeps me', 'Running / every morning / keeps me healthy.', false),
        ('every Running morning keeps me healthy.', 'Running / every morning / keeps me healthy.', false),
        ('Running every morning keeps me healthy. too', 'Running / every morning / keeps me healthy.', false),
        ('Running Running every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', false),
        ('Running', 'Running / every morning / keeps me healthy.', false),
        (chr(65330) || 'unning every morning keeps me healthy.', 'Running / every morning / keeps me healthy.', false),
        ('ㅑ ㅁㅡ ㅁ ㅠㅐㅛ', 'I am a boy.', false),
        ('', 'I am a boy.', false),
        (null::text, 'I am a boy.', false),
        ('.,?!', '.,?!', false),
        ('dont', 'don''t', false),
        ('don' || chr(8217) || 't', 'don''t', true),
        ('well known', 'well-known', false),
        ('email', 'e-mail', false),
        ('its cold', 'it''s cold', false),
        ('I cannot swim', 'I can''t swim', false),
        ('runing', 'running', false),
        ('do ones best', 'do one''s best', false),
        ('do one' || chr(8217) || 's best', 'do one''s best', true),
        ('I like ' || chr(4352) || chr(4469) || chr(4535) || chr(4366) || chr(4469), 'I like 김치.', true),
        ('look ~ up', 'look up', true),
        ('a ; b : c', 'a b c', true),
        ('"Hi," he said.', 'Hi he said', true),
        ('U.S.A. is big', 'USA is big', true),
        ('(that) I read', '(that) I read', true),
        ('that I read', '(that) I read', false),
        ('cafe' || chr(769), 'caf' || chr(233), true),
        (repeat('a word ', 70), repeat('a word ', 70), false),
        (repeat('a word ', 57), repeat('a word ', 57), true),
        (repeat('abcd ', 41), repeat('abcd ', 41), true),
        ('i am a boy', 'I / am a boy.', true),
        ('I am a boy', 'I / am / a / boy', true),
        ('I am a boy!', 'I am a boy.', true),
        ('I am a girl', 'I am a boy.', false),
        ('I am  a boy', 'I am a boy', true),
        ('I am' || chr(12288) || 'a boy', 'I am a boy', true),
        ('I am a boy' || chr(12290), 'I am a boy', false),
        ('I, am, a, boy', 'I am a boy', true),
        ('I am a boy?!', 'I am a boy', true),
        ('Yes / no', 'Yes no', true),
        ('Yes/no', 'Yes no', true),
        ('yesno', 'Yes no', false),
        ('Tom' || chr(8217) || 's book', 'Tom''s book', true),
        ('Toms book', 'Tom''s book', false),
        ('3 apples', '3 apples.', true),
        ('three apples', '3 apples.', false)
      ) as x(a, b, c) loop
      if public.lec__set_sent_v2(v_case.a, v_case.b) is distinct from v_case.c then raise exception '점검 실패(V2 판정 sent «%» «%»)', v_case.a, v_case.b; end if;
    end loop;
    v_items := '[{"k": "k1", "n": "1", "w": "abandon", "m": "버리다"}, {"k": "k2", "n": "2", "w": "discard", "m": " 버리다. "}, {"k": "k3", "n": "3", "w": "give up", "m": "포기하다"}, {"k": "k4", "n": "4", "w": "(to) work", "m": "일하다"}, {"k": "k5", "n": "5", "w": "look up / look up to", "m": "올려다보다"}, {"k": "k6", "n": "6", "w": "run", "m": "달리다"}, {"k": "k7", "n": "7", "w": "sprint", "m": "DALRIDA"}, {"k": "k8", "n": "8", "w": "dash", "m": "dalrida"}, {"k": "k9", "n": "9", "w": "blank", "m": ""}, {"k": "k10", "n": "10", "w": "empty", "m": ""}]'::jsonb;
    for v_case in select * from (values
        ('abandon', 'k1', true),
        ('discard', 'k1', true),
        ('Discard.', 'k1', true),
        ('abandon', 'k2', true),
        ('give up', 'k1', false),
        ('work', 'k4', true),
        ('to work', 'k4', true),
        ('look up to', 'k5', true),
        ('look', 'k5', false),
        ('run', 'k6', true),
        ('sprint', 'k6', false),
        ('dash', 'k7', true),
        ('sprint', 'k8', true),
        ('empty', 'k9', false),
        ('blank', 'k9', true),
        ('', 'k1', false),
        (null::text, 'k1', false),
        ('abandon', 'k99', false),
        ('abandon', null::text, false),
        (repeat('a', 201), 'k1', false),
        ('abandon ', 'k1', true),
        ('abandn', 'k1', false)
      ) as x(a, b, c) loop
      if public.lec__set_spell_v2(v_case.a, v_items, v_case.b) is distinct from v_case.c then raise exception '점검 실패(V2 판정 spell «%» %)', v_case.a, v_case.b; end if;
    end loop;

    -- 2) 준비: 스위치 모두 끔 · 학생 하나(기록 동의) · 단어 · 구문 · 문법 세트 하나씩
    update public.lec_v2_cfg set log = false, eval = false, spell = false, guw = false, gram = false, review = false, lim = 3000
     where id = 1;
    insert into public.lec_v2_cfg (id) values (1) on conflict (id) do nothing;
    v_cl := 'selftest-v2-' || v_ks;
    v_ka := 'selftest' || v_ks || 'v2a';
    insert into public.lec_key (kh, sid, rid, pin, sname, cls) values (public.lec__kh(v_ka), v_sa, 'selftest-v2a', '', '점검가', array[v_cl]);
    insert into public.lec_consent (sid, choice, ver) values (v_sa, 'agree', public.lec__consent_ver());
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('voc', '점검 v2 단어', array[v_cl], v_d - 1,
       '[{"k": "k1", "n": "1", "w": "apple", "m": "사과"}, {"k": "k2", "n": "2", "w": "run", "m": "달리다"},
         {"k": "k3", "n": "3", "w": "sprint", "m": "달리다"}]'::jsonb, 3)
    returning id into v_sv;
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('gu', '점검 v2 구문', array[v_cl], v_d - 1, '[{"k": "k1", "n": "1", "e": "I / am a boy.", "t": "나는 소년이다.", "p": ""}]'::jsonb, 1)
    returning id into v_sr;
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('gram', '점검 v2 문법', array[v_cl], v_d - 1,
       '[{"k": "k1", "n": "1", "s": "He (go / goes) home.", "a": "goes", "x": "삼인칭 단수", "p": "수 일치"}]'::jsonb, 1)
    returning id into v_sg;

    -- 3) 스위치 끔 = 옛 판 그대로(목록 = lec_set_home + v2 · ts · todo) · 새 판 열기 'off' · 폰이 만든 판 줄은 기록만(카드 그대로)
    r := public.lec_set_home_v2(v_ka, null);
    if (r ->> 'ok') is distinct from 'true'
       or (r -> 'v2') is distinct from '{"log": false, "eval": false, "spell": false, "guw": false, "gram": false, "review": false}'::jsonb
       or (r - 'v2' - 'ts' - 'todo') is distinct from public.lec_set_home(v_ka)
       or (r #> '{todo,n}') is distinct from (r #> '{due,n}') then
      raise exception '점검 실패(V2 스위치 끔 · 목록): %', left(r::text, 600);
    end if;
    if (public.lec_set_open_v2(v_ka, v_sv, 'mem') ->> 'err') is distinct from 'off'
       or (public.lec_set_open_v2(v_ka, null, 'due') ->> 'err') is distinct from 'off'
       or (public.lec_set_test_v2(v_ka, v_sv) ->> 'err') is distinct from 'off' then
      raise exception '점검 실패(V2 스위치 끔 · 새 판 열기)';
    end if;
    v_t := md5('v2log' || v_ks);
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', v_t, 'b', gen_random_uuid(), 'i', 1, 's', v_sv, 'k', 'k1', 'f', 'k', 'v', '1', 'ago', 5000),
           jsonb_build_object('id', 'not-hex', 'b', gen_random_uuid(), 'i', 1),
           '"x"'::jsonb));
    if (r -> 'got') is distinct from jsonb_build_array(v_t) or (r -> 'bad') is distinct from '["not-hex"]'::jsonb
       or (select xl.why || xl.bk from public.lec_set_log xl where xl.id = v_t) is distinct from 'loglog'
       or exists (select 1 from public.lec_set_prog xp where xp.sid = v_sa) then
      raise exception '점검 실패(V2 폰이 만든 판 = 기록만): %', left(r::text, 600);
    end if;
    if (public.lec_set_log_v2(v_ka, '{}'::jsonb) ->> 'err') is distinct from 'input'
       or (public.lec_set_log_v2(v_ka, (select jsonb_agg(g) from generate_series(1, 101) as g)) ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(V2 줄 한도)';
    end if;

    -- 4) 없는 열쇠(스위치 켬)
    update public.lec_v2_cfg set log = true, eval = true where id = 1;
    v_t := 'selftest-wrong-key';
    if (public.lec_set_home_v2(v_t, null) ->> 'err') is distinct from 'key'
       or (public.lec_set_open_v2(v_t, v_sv, 'mem') ->> 'err') is distinct from 'key'
       or (public.lec_set_log_v2(v_t, '[]'::jsonb) ->> 'err') is distinct from 'key'
       or (public.lec_set_test_v2(v_t, v_sv) ->> 'err') is distinct from 'key'
       or (public.lec_set_save_v2(v_t, gen_random_uuid(), '[]'::jsonb) ->> 'err') is distinct from 'key'
       or (public.lec_set_send_v2(v_t, gen_random_uuid(), '[]'::jsonb) ->> 'err') is distinct from 'key' then
      raise exception '점검 실패(V2 없는 열쇠)';
    end if;
    if (public.lec_set_open_v2(v_ka, v_sg, 'mem') ->> 'err') is distinct from 'kind'
       or (public.lec_set_open_v2(v_ka, v_sv, 'x') ->> 'err') is distinct from 'input'
       or (public.lec_set_save_v2(v_ka, gen_random_uuid(), '[]'::jsonb) ->> 'err') is distinct from 'try' then
      raise exception '점검 실패(V2 문법 외우기 · 모드 · 남의 판)';
    end if;

    -- 5) 외우기 판: 같은 날 다시 열면 같은 판 · 순번 2 · 3 먼저 → 1 + 2 다시 = 표에 셋 · 카드 = 차례대로 보낸 값(단어 쓰기 «뜻 여럿» 맞음)
    r := public.lec_set_open_v2(v_ka, v_sv, 'mem');
    v_b := (r ->> 'b')::uuid;
    if (r ->> 'ok') is distinct from 'true' or v_b is null or jsonb_array_length(r -> 'items') <> 3 or (r ->> 'no') is distinct from '1'
       or (r ->> 'seed') is distinct from hashtext(v_sa || '|' || v_sv::text || '|1')::text
       or (public.lec_set_open_v2(v_ka, v_sv, 'mem') ->> 'b')::uuid is distinct from v_b then
      raise exception '점검 실패(V2 외우기 판 열기): %', left(r::text, 600);
    end if;
    v_qs := jsonb_build_array(
      jsonb_build_object('id', md5('v2m1' || v_ks), 'b', v_b, 'i', 1, 'k', 'k1', 'f', 'k', 'v', '1', 'ago', 3000),
      jsonb_build_object('id', md5('v2m2' || v_ks), 'b', v_b, 'i', 2, 'k', 'k2', 'f', 'k', 'v', '0', 'ago', 2000),
      jsonb_build_object('id', md5('v2m3' || v_ks), 'b', v_b, 'i', 3, 'k', 'k3', 'f', 'sp', 'v', 'Run', 'pr', true, 'ago', 1000, 'n', 3));
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(v_qs -> 1, v_qs -> 2));
    r2 := public.lec_set_log_v2(v_ka, jsonb_build_array(v_qs -> 0, v_qs -> 1));
    select xp.cards into v_card from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv;
    v_c2 := jsonb_build_object('k1', public.lec__set_mark(null, true, 'card', v_d), 'k2', public.lec__set_mark(null, false, 'card', v_d),
                               'k3', public.lec__set_mark(null, true, 'card', v_d));
    if jsonb_array_length(r -> 'got') <> 2 or jsonb_array_length(r2 -> 'got') <> 2
       or (select count(*) from public.lec_set_log xl where xl.b = v_b) <> 3
       or (select count(*) from public.lec_set_log xl where xl.b = v_b and xl.done) <> 3
       or v_card is distinct from v_c2 or (r2 #>> array['me', v_sv::text, 'seen']) is distinct from '3'
       or (select xr.end_n from public.lec_set_run xr where xr.id = v_b) is distinct from 3
       or r::text like '%apple%' or r2::text like '%sprint%' then
      raise exception '점검 실패(V2 외우기 줄 · 카드 %): % / %', v_card, left(r::text, 300), left(r2::text, 300);
    end if;
    -- 끝난 판은 안 이음(새 판 2) · 구문 외우기 = 2 말해서 확인(v 1) · 구문 쓰기(lec__set_sent_v2)
    r := public.lec_set_open_v2(v_ka, v_sr, 'mem');
    r2 := public.lec_set_log_v2(v_ka, jsonb_build_array(
            jsonb_build_object('id', md5('v2g1' || v_ks), 'b', r ->> 'b', 'i', 1, 'k', 'k1', 'f', 'se', 'v', 'I am a boy', 'ago', 10),
            jsonb_build_object('id', md5('v2g2' || v_ks), 'b', r ->> 'b', 'i', 2, 'k', 'k1', 'f', 'k', 'v', '2', 'ago', 5)));
    select xp.cards -> 'k1' into v_card from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sr;
    if (public.lec_set_open_v2(v_ka, v_sv, 'mem') ->> 'no') is distinct from '2'
       or v_card is distinct from '{"s": 1, "g": 1, "v": 1}'::jsonb then
      raise exception '점검 실패(V2 새 판 · 구문 %): %', v_card, left(r2::text, 300);
    end if;

    -- 6) 쌓인 오답 판(먼저 연 판)의 줄이 뒤에 연 외우기 판 줄보다 늦게 옴 → 그 카드만 다시 셈 = 차례대로 보낸 값
    update public.lec_set_prog xp
       set cards = jsonb_set(xp.cards, '{k2}', jsonb_build_object('s', 1, 'w', 1, 'z', to_char(v_d - 2, 'YYYY-MM-DD')))
     where xp.sid = v_sa and xp.set_id = v_sv;
    r := public.lec_set_open_v2(v_ka, null, 'due');
    v_bd := (r ->> 'b')::uuid;
    if (r ->> 'ok') is distinct from 'true' or v_bd is null or (r ->> 'n') is distinct from '1'
       or (r #>> '{q,0,k}') is distinct from 'k2' or (r #>> '{q,0,a}') is distinct from 'run' then
      raise exception '점검 실패(V2 쌓인 오답 판 열기): %', left(r::text, 600);
    end if;
    update public.lec_set_run xr set created_at = now() - interval '10 minutes' where xr.id = v_bd;
    -- 앞 판(#1 · v_b)은 쌓인 오답 판보다 먼저 연 판: 한 거래 안이라 now() 가 같아 판 연 때(bo)를 20분 앞으로(실제 차례와 같게)
    update public.lec_set_run xr set created_at = now() - interval '20 minutes' where xr.id = v_b;
    update public.lec_set_log xl set bo = now() - interval '20 minutes' where xl.b = v_b;
    v_b2 := (public.lec_set_open_v2(v_ka, v_sv, 'mem') ->> 'b')::uuid;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v2m4' || v_ks), 'b', v_b2, 'i', 1, 'k', 'k2', 'f', 'k', 'v', '1', 'ago', 100)));
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v2d1' || v_ks), 'b', v_bd, 'i', 1, 's', v_sv, 'k', 'k2', 'v', 'walk', 'pr', false, 'ago', 200, 'n', 1)));
    v_c2 := public.lec__set_mark(public.lec__set_mark(jsonb_build_object('s', 1, 'w', 1, 'z', to_char(v_d - 2, 'YYYY-MM-DD')),
                                                      false, 'due', v_d), true, 'card', v_d);
    select xp.cards -> 'k2' into v_card from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv;
    if v_card is distinct from v_c2 or (r -> 'got') is distinct from jsonb_build_array(md5('v2d1' || v_ks))
       or (select xl.sr from public.lec_set_log xl where xl.id = md5('v2d1' || v_ks)) is distinct from false then
      raise exception '점검 실패(V2 늦게 온 앞 판 줄 · 다시 셈): % ≠ %', v_card, v_c2;
    end if;

    -- 7) 판 도중 스위치 끔 → 이미 연 판 줄은 그래도 반영 · 늦은 날 줄(카드에 더 늦은 날) = 기록만 · 하루 한도 = 기록만
    update public.lec_v2_cfg set eval = false where id = 1;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v2m5' || v_ks), 'b', v_b2, 'i', 2, 'k', 'k3', 'f', 'k', 'v', '0', 'ago', 50)));
    if not (select xl.done from public.lec_set_log xl where xl.id = md5('v2m5' || v_ks)) then
      raise exception '점검 실패(V2 판 도중 끔): %', left(r::text, 300);
    end if;
    update public.lec_v2_cfg set eval = true where id = 1;
    update public.lec_set_run xr set created_at = now() - interval '3 days' where xr.id = v_b2;
    select xp.cards into v_card from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v2m6' || v_ks), 'b', v_b2, 'i', 3, 'k', 'k1', 'f', 'k', 'v', '0', 'ago', 172800000)));
    if (select xl.why || '|' || xl.late::text || '|' || xl.day::text from public.lec_set_log xl where xl.id = md5('v2m6' || v_ks))
         is distinct from 'late|true|' || (v_d - 2)::text
       or (select xp.cards from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv) is distinct from v_card then
      raise exception '점검 실패(V2 늦은 날 줄)';
    end if;
    update public.lec_v2_cfg set lim = 0 where id = 1;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v2m7' || v_ks), 'b', v_b2, 'i', 4, 'k', 'k1', 'f', 'k', 'v', '1', 'ago', 0)));
    if (select xl.why from public.lec_set_log xl where xl.id = md5('v2m7' || v_ks)) is distinct from 'lim'
       or (select xp.cards from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv) is distinct from v_card
       or (r -> 'got') is distinct from jsonb_build_array(md5('v2m7' || v_ks)) then
      raise exception '점검 실패(V2 하루 한도)';
    end if;
    update public.lec_v2_cfg set lim = 3000 where id = 1;

    -- 8) 평가 열기: 바른 답 칸 0 · 이 세트 연습 판 닫음 · 닫힌 뒤 답 = 기록만 · 쌓인 오답 판에서 이 세트 문항 뺌
    update public.lec_set_prog xp
       set cards = jsonb_set(xp.cards, '{k3}', jsonb_build_object('s', 1, 'w', 1, 'z', to_char(v_d - 2, 'YYYY-MM-DD')))
     where xp.sid = v_sa and xp.set_id = v_sv;
    r := public.lec_set_test_v2(v_ka, v_sv);
    v_try := (r ->> 'try')::uuid;
    if (r ->> 'ok') is distinct from 'true' or v_try is null or r ? 'done' or not (r ? 'sv')
       or jsonb_path_exists(r, '$.**.a') or jsonb_path_exists(r, '$.**.x') or jsonb_path_exists(r, '$.**.pt')
       or not ((select xr.shut from public.lec_set_run xr where xr.id = v_b2) ? v_sv::text) then
      raise exception '점검 실패(V2 평가 열기 · 바른 답 칸): %', left(r::text, 600);
    end if;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v2m8' || v_ks), 'b', v_b2, 'i', 5, 'k', 'k1', 'f', 'k', 'v', '1', 'ago', 0)));
    r2 := public.lec_set_open_v2(v_ka, null, 'due');
    if (select xl.why from public.lec_set_log xl where xl.id = md5('v2m8' || v_ks)) is distinct from 'shut'
       or r2::text like '%' || v_sv::text || '%' or (public.lec_set_open_v2(v_ka, v_sv, 'mem') ->> 'err') is distinct from 'testing' then
      raise exception '점검 실패(V2 평가 중 연습): % / %', left(r::text, 300), left(r2::text, 300);
    end if;

    -- 9) 중간 저장(바른 답 · 맞음 0 · 먼저 온 답이 남음) → 내기(덜 참 = miss) → 끝 → 다시 내도 같은 결과 · 다시 열면 sv(내 임시 답)
    select xt.qs into v_qs from public.lec_set_try xt where xt.id = v_try;
    v_n := jsonb_array_length(v_qs);
    r := public.lec_set_save_v2(v_ka, v_try, jsonb_build_array(
           jsonb_build_object('id', md5('v2e1' || v_ks), 'b', v_try, 'i', 1, 'v', v_qs #>> '{0,a}', 'ago', 10),
           jsonb_build_object('id', md5('v2e1b' || v_ks), 'b', v_try, 'i', 1, 'v', 'wrong', 'ago', 5)));
    if (r ->> 'ok') is distinct from 'true' or jsonb_array_length(r -> 'got') <> 2 or (r ->> 'left')::integer <> v_n - 1
       or r ? 'ans' or r ? 'end' or r::text like '%' || (v_qs #>> '{0,a}') || '%'
       or (select xt.ans #>> '{0,r}' from public.lec_set_try xt where xt.id = v_try) is distinct from 'true'
       or (select xl.why from public.lec_set_log xl where xl.id = md5('v2e1b' || v_ks)) is distinct from 'done' then
      raise exception '점검 실패(V2 중간 저장): %', left(r::text, 600);
    end if;
    r := public.lec_set_test_v2(v_ka, v_sv);
    if (r ->> 'try')::uuid is distinct from v_try or (r -> 'sv') is distinct from jsonb_build_array(jsonb_build_object('i', 0, 'v', v_qs #>> '{0,a}'))
       or jsonb_path_exists(r, '$.**.a') then
      raise exception '점검 실패(V2 다시 열기 · 임시 답): %', left(r::text, 600);
    end if;
    r := public.lec_set_send_v2(v_ka, v_try, '[]'::jsonb);
    if (r ->> 'done') is distinct from 'false' or jsonb_array_length(r -> 'miss') <> v_n - 1 or r ? 'ans' then
      raise exception '점검 실패(V2 덜 찬 내기): %', left(r::text, 600);
    end if;
    select jsonb_agg(jsonb_build_object('id', md5('v2e' || g || v_ks), 'b', v_try, 'i', g, 'v', v_qs -> (g - 1) ->> 'a', 'ago', 1))
      into v_items
      from generate_series(2, v_n) as g;
    r := public.lec_set_send_v2(v_ka, v_try, coalesce(v_items, '[]'::jsonb));
    r2 := public.lec_set_send_v2(v_ka, v_try, coalesce(v_items, '[]'::jsonb));
    if (r ->> 'done') is distinct from 'true' or (r #>> '{end,sc}')::integer <> v_n or jsonb_array_length(r -> 'ans') <> v_n
       or (r #>> '{ans,0,a}') is null or (r - 'got' - 'bad') is distinct from (r2 - 'got' - 'bad')
       or jsonb_array_length(r -> 'got') <> v_n - 1 or jsonb_array_length(r2 -> 'got') <> v_n - 1
       or (select xp.f1 from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv) is distinct from 100
       or (select xp.pass_at from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv) is null then
      raise exception '점검 실패(V2 내기 · 다시 내기): % / %', left(r::text, 400), left(r2::text, 300);
    end if;

    -- 10) 지켜보기: 로그인 없음 · 바깥 사람 = forbidden · 원장님 = 오늘 줄 수
    foreach v_t in array array['', '{"role":"authenticated","email":"selftest-outsider@gmail.com"}'] loop
      perform set_config('request.jwt.claims', v_t, true);
      if (public.lec_v2_watch(14) ->> 'err') is distinct from 'forbidden' then
        raise exception '점검 실패(V2 지켜보기 막기 «%»)', v_t;
      end if;
    end loop;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":" Benjamin@his.kr "}', true);
    r := public.lec_v2_watch(14);
    if (r ->> 'ok') is distinct from 'true'
       or not exists (select 1 from jsonb_array_elements(r -> 'days') as x(e) where x.e ->> 'day' = v_d::text and (x.e ->> 'rows')::integer >= 10)
       or r::text like '%점검가%' then
      raise exception '점검 실패(V2 지켜보기): %', left(r::text, 600);
    end if;
    perform set_config('request.jwt.claims', '', true);

    -- 11) 폰 보관함 남은 줄: 있으면 적고 0 이면 지움
    perform public.lec_set_home_v2(v_ka, '{"n": 3, "age": 60000}'::jsonb);
    if (select xb.n from public.lec_v2_box xb where xb.sid = v_sa) is distinct from 3 then
      raise exception '점검 실패(V2 보관함 적기)';
    end if;
    perform public.lec_set_home_v2(v_ka, '{"n": 0}'::jsonb);
    if exists (select 1 from public.lec_v2_box xb where xb.sid = v_sa) then
      raise exception '점검 실패(V2 보관함 지우기)';
    end if;

    -- 12) 이름 바뀜(lec__move · 트리거) = v2 줄 따라감 · 동의 줄 지움(lec_forget 과 같은 줄) = v2 줄 지움
    perform public.lec_set_home_v2(v_ka, '{"n": 2, "age": 1000}'::jsonb);
    perform public.lec__move(v_sa, 'selftest-v2b|점검가', '점검가');
    if exists (select 1 from public.lec_set_log xl where xl.sid = v_sa) or exists (select 1 from public.lec_set_run xr where xr.sid = v_sa)
       or exists (select 1 from public.lec_v2_box xb where xb.sid = v_sa)
       or not exists (select 1 from public.lec_set_log xl where xl.sid = 'selftest-v2b|점검가')
       or not exists (select 1 from public.lec_set_run xr where xr.sid = 'selftest-v2b|점검가')
       or (select xb.n from public.lec_v2_box xb where xb.sid = 'selftest-v2b|점검가') is distinct from 2 then
      raise exception '점검 실패(V2 이름 바뀜)';
    end if;
    delete from public.lec_consent where sid = 'selftest-v2b|점검가';
    if exists (select 1 from public.lec_set_log xl where xl.sid = 'selftest-v2b|점검가')
       or exists (select 1 from public.lec_set_run xr where xr.sid = 'selftest-v2b|점검가')
       or exists (select 1 from public.lec_v2_box xb where xb.sid = 'selftest-v2b|점검가') then
      raise exception '점검 실패(V2 지움)';
    end if;

    -- 13) 권한: 학생 함수는 누구나 · 지켜보기는 로그인한 사람만 · 표는 아무도 · 속 함수 전부 밖에서 못 부름
    if not has_function_privilege('anon', 'public.lec_set_log_v2(text, jsonb)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_home_v2(text, jsonb)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_open_v2(text, uuid, text)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_test_v2(text, uuid)', 'execute')
       or not has_function_privilege('anon', 'public.lec_set_save_v2(text, uuid, jsonb)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_set_send_v2(text, uuid, jsonb)', 'execute')
       or has_function_privilege('anon', 'public.lec_v2_watch(integer)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_v2_watch(integer)', 'execute')
       or has_function_privilege('anon', 'public.lec__set_sent_v2(text, text)', 'execute') then
      raise exception '점검 실패(V2 권한)';
    end if;
    select string_agg(c.relname || ' ' || u.rl, ', ') into v_t
      from pg_class c
     cross join unnest(array['anon', 'authenticated']) as u(rl)
     where c.relnamespace = 'public'::regnamespace
       and c.relname in ('lec_v2_cfg', 'lec_set_run', 'lec_set_log', 'lec_v2_box')
       and (has_table_privilege(u.rl, c.oid, 'select,insert,update,delete') or not c.relrowsecurity);
    if v_t is not null then
      raise exception '점검 실패(V2 표 권한): %', v_t;
    end if;
    if exists (select 1 from pg_policies pp
                where pp.schemaname = 'public' and pp.tablename in ('lec_v2_cfg', 'lec_set_run', 'lec_set_log', 'lec_v2_box')) then
      raise exception '점검 실패(V2 표 정책이 있음)';
    end if;
    select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text) into v_t
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and left(p.proname, 5) = 'lec__'
       and p.proname <> 'lec__is_staff'
       and p.prorettype <> 'trigger'::regtype
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'));
    if v_t is not null then
      raise exception '점검 실패(V2 · 속 함수를 밖에서 부를 수 있음): %', v_t;
    end if;

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

-- ---------------------------------------------------------------- V2-5 (11-20) 선생님 현황 · 첫 답 · 인정 답 · 열넷째 스스로 점검
-- 결론안 v2(11-20) 묶음 ⑤: 결과 표에서 학생 줄 → «첫 답에서 틀린 문항» · 결과 표에 «포인트별 반 첫 답 정답률» · 틀린 쓰기 답 «이 답도 맞음»
-- 앞 절은 그대로 두고 더하기만(옛 함수 몸 · 표 칸 바꿈 0 · DROP 0 · V2-1 안은 «-- V2-5» 꼬리표 자리만 넓힘):
--   1) 표 둘(행 보안 · 표로는 아무도 못 읽고 못 씀 · 함수로만): lec_set_ok2(인정 답 · 세트 · 문항 열쇠 · 맞춤 글 · 누가 · 언제 · 되돌림 = 줄 하나 더) ·
--      lec_set_fix(고침 줄 · 원래 답 줄은 그대로 · 그 판 점수 · 통과 · 쌓인 오답(z)만 다시 셈 · 지난 d · t · w 는 안 건드림)
--   2) 속 함수: 맞추기 글 · 켜진 인정 답 · 폰에 실을 인정 답 · 규칙 판정(읽을 때) · 첫 답(새 기록 표 lec_set_log 에서) · z 다시 접기 · 다시 셈 ·
--      켜기 전 기록 다시 매겨 견주기(lec__v2_regrade · 재는 데에만 · 화면 0 · SQL Editor 에서 select public.lec__v2_regrade(null);)
--   3) 선생님 함수 셋(원장님만 · 결과 표 lec_set_staff 와 같은 권한 · 학생 열쇠로는 못 부름): lec_set_staff_v2(결과 표 + 포인트별 반 첫 답 정답률 +
--      인정 답으로 맞은 첫 답이 5% 넘는 문항) · lec_set_wrong1_v2(학생 하나 · 첫 답에서 틀린 문항) · lec_set_ok2_v2(이 답도 맞음 · 되돌리기)
--   4) 열넷째 스스로 점검(가짜 세트 · 열쇠 · 스위치 · 끝에 모두 되돌림)
-- 인정 답 맞추기: 단어 · 문법 = lec__set_norm 이 같음(«/» 로 나누지 않음 · 1~200 글자) · 구문 = lec__set_snorm_v2 가 같음(1~400 글자) · 고르기 문항은 없음
-- 옛 채점 lec_set_ans 는 그대로(인정 답을 안 읽음 · 옛 판 답은 넣을 때 다시 셈) · v2 채점(lec__v2_ev · lec_set_log_v2)과 폰 채점이 인정 답을 읽음
-- 운영에 넣은 뒤 확인(바꾸는 것 없음):
--   select count(*) from public.lec_set_ok2;              -- 0
--   select public.lec__v2_regrade(null);                   -- {"n": 옛 판 쓰기 칸 수, "same": …, "up": 0, "fixed": 0, "sets": […]}

create table if not exists public.lec_set_ok2 (
  id      bigserial primary key,
  set_id  uuid not null references public.lec_set (id) on delete cascade,
  k       text not null,
  m       text not null,
  nm      text not null,
  who     text not null default '',
  at      timestamptz not null default now(),
  undo    boolean not null default false,
  constraint lec_set_ok2_k_ok check (char_length(k) between 1 and 40),
  constraint lec_set_ok2_m_ok check (char_length(m) between 1 and 400 and nm <> '')
);
create index if not exists lec_set_ok2_sk on public.lec_set_ok2 (set_id, k, nm, id);

-- 고침 줄: 옛 판 시험 칸(try_id · i) 또는 v2 줄(log_id) 하나의 지금 맞음(ok) · g = 채점 때 인정 답으로 맞음(규칙으로는 틀림) ·
--   ch = 이 고침이 바꾼 통과(pa · 되돌릴 때 같은 때면 지움) · 줄이 지워지면(동의 지움 · 세트 지움) 같이 지움
create table if not exists public.lec_set_fix (
  id      bigserial primary key,
  ok2     bigint not null references public.lec_set_ok2 (id) on delete cascade,
  try_id  uuid references public.lec_set_try (id) on delete cascade,
  i       integer,
  log_id  text references public.lec_set_log (id) on delete cascade,
  ok      boolean not null,
  g       boolean not null default false,
  ch      jsonb not null default '{}'::jsonb,
  at      timestamptz not null default now(),
  constraint lec_set_fix_ref_ok check ((try_id is null) <> (log_id is null) and (try_id is null) = (i is null)),
  constraint lec_set_fix_ch_ok  check (jsonb_typeof(ch) = 'object')
);
create index if not exists lec_set_fix_try on public.lec_set_fix (try_id, i, id) where try_id is not null;
create index if not exists lec_set_fix_log on public.lec_set_fix (log_id, id) where log_id is not null;
create index if not exists lec_set_fix_ok2 on public.lec_set_fix (ok2);

revoke all on public.lec_set_ok2, public.lec_set_fix from public, anon, authenticated;
revoke all on sequence public.lec_set_ok2_id_seq, public.lec_set_fix_id_seq from public, anon, authenticated;
alter table public.lec_set_ok2 enable row level security;
alter table public.lec_set_fix enable row level security;

-- 인정 답 맞추기 글(class-api.js Lec.setOk2NmV2 와 같은 셈): 단어 · 문법 = lec__set_norm(1~200 글자) · 구문 = lec__set_snorm_v2(1~400 글자) · 꼴이 틀리면 ''
create or replace function public.lec__v2_ok2nm(p_kd text, p_v text) returns text
language sql immutable set search_path = public as $$
  select case when p_kd = 'gu'
              then case when coalesce(char_length(p_v) between 1 and 400, false) then public.lec__set_snorm_v2(p_v) else '' end
              else case when coalesce(char_length(p_v) between 1 and 200, false) then public.lec__set_norm(p_v) else '' end end
$$;

-- 이 답과 맞는 켜진 인정 답 id(그 맞추기 글의 마지막 줄이 되돌림이 아님) · 없으면 null
create or replace function public.lec__v2_ok2id(p_set uuid, p_k text, p_kd text, p_v text) returns bigint
language sql stable set search_path = public as $$
  select y.id
    from (select o.id, o.undo from public.lec_set_ok2 o
           where o.set_id = p_set and o.k = p_k and o.nm = public.lec__v2_ok2nm(p_kd, p_v) and o.nm <> ''
           order by o.id desc limit 1) y
   where not y.undo
$$;

-- 세트의 켜진 인정 답 {열쇠: [맞춤 글 …]}(폰 채점용 · 넣은 차례)
create or replace function public.lec__v2_ok2s(p_set uuid) returns jsonb
language sql stable set search_path = public as $$
  select coalesce(jsonb_object_agg(z.k, z.ms), '{}'::jsonb)
    from (select y.k, jsonb_agg(y.m order by y.id) as ms
            from (select distinct on (o.k, o.nm) o.k, o.nm, o.m, o.id, o.undo
                    from public.lec_set_ok2 o
                   where o.set_id = p_set
                   order by o.k, o.nm, o.id desc) y
           where not y.undo
           group by y.k) z
$$;

-- 쌓인 오답 판 문항(lec_set_open_v2 의 q)에 인정 답 a2 를 실음(쓰기 문항 w · r 만 · 있을 때만 · 차례 그대로)
--   V2-35: V2-3 새 판(lec__v2_open3 의 q)도 같은 함수 · 쓰기 문항 sp(단어) · gw · se(구문 통째) · r(문법) · 고르기 c 는 안 실음
create or replace function public.lec__v2_ok2q(p_q jsonb) returns jsonb
language sql stable set search_path = public as $$
  select coalesce(jsonb_agg(case when z.a2 is null then z.e else z.e || jsonb_build_object('a2', z.a2) end order by z.o), '[]'::jsonb)
    from (select q.e, q.o,
                 case when q.e ->> 'f' in ('w', 'r', 'sp', 'gw', 'se') then   -- V2-35 V2-3 새 판 꼴 sp · gw · se
                   (select jsonb_agg(y.m order by y.id)
                      from (select distinct on (x2.nm) x2.nm, x2.m, x2.id, x2.undo
                              from public.lec_set_ok2 x2
                             where x2.set_id::text = q.e ->> 's' and x2.k = q.e ->> 'k'
                             order by x2.nm, x2.id desc) y
                     where not y.undo)
                 end as a2
            from jsonb_array_elements(case when jsonb_typeof(p_q) = 'array' then p_q else '[]'::jsonb end) with ordinality as q(e, o)) z
$$;

-- 규칙 판정(읽을 때 · 인정 답 없이 · 서버가 매기지 않은 «기록만» 줄용): 단어 쓰기 sp = lec__set_spell_v2 · 구문 쓰기 se · 배열 ar = lec__set_sent_v2 ·
--   고르기 c = lec__set_norm 같음 · 쓰기 w · r = lec__set_match(200 글자까지)
create or replace function public.lec__v2_r0(p_kd text, p_items jsonb, p_k text, p_f text, p_v text) returns boolean
language sql stable set search_path = public as $$
  select coalesce(case
           when p_f = 'sp' and p_kd = 'voc' then public.lec__set_spell_v2(p_v, p_items, p_k)
           when p_f in ('se', 'ar') and p_kd = 'gu' then public.lec__set_sent_v2(p_v, it.e ->> 'e')   -- V2-35 구문 배열 ar(V2-3 lec__v2_judge 와 같은 셈)
           when p_f = 'c' and p_kd = 'gram' then public.lec__set_norm(p_v) = public.lec__set_norm(it.e ->> 'a')
           when p_f in ('w', 'r') and p_kd in ('voc', 'gram')
             then public.lec__set_match(p_v, case when p_kd = 'voc' then it.e ->> 'w' else it.e ->> 'a' end) and char_length(p_v) <= 200
         end, false)
    from (select (select y.e from jsonb_array_elements(case when jsonb_typeof(p_items) = 'array' then p_items else '[]'::jsonb end) as y(e)
                   where y.e ->> 'k' = p_k limit 1) as e) it
$$;

-- 첫 답(새 기록 표 lec_set_log 에서 · 학생 · 문항마다 답한 때 차례 첫 줄): 스스로 확인(k) · 문항 없음(gone) · 이미 찬 칸(done) · 빈 답 뺌 ·
--   b0 = 규칙 판정(채점 때 인정 답으로 맞은 줄 = 틀림 · 힌트 본 연습 답 = 틀림) · o2 = 지금 켜진 인정 답(쓰기 답만) · ok = b0 또는 o2 ·
--   rno = 그 학생이 이 세트에 줄을 남긴 판을 판 연 때 차례로 센 번호
--   V2-35: 이름 lec__v2_ans1(V2-3 의 lec__v2_first(jsonb) = 카드 가장 이른 날과 겹쳐 바꿈) · V2-3 새 판 줄(bk spell · guw · gram · review)도 셈 ·
--     구문 써 보기는 배열 ar 첫 답이 그 문항 첫 답(오늘 볼 것 판은 se) · 힌트 본 답 = 틀림 · 배열 ar 은 인정 답 없음
create or replace function public.lec__v2_ans1(p_set uuid)
returns table (sid text, k text, f text, v text, bk text, h boolean, b0 boolean, o2 bigint, ok boolean, rno integer, ta timestamptz)
language sql stable set search_path = public as $$
  with s as (select xs.id, xs.kind, xs.items from public.lec_set xs where xs.id = p_set),
  rn as (select xl.sid, xl.b, row_number() over (partition by xl.sid order by min(xl.bo), xl.b)::integer as rno
           from public.lec_set_log xl
          where xl.set_id = p_set
          group by xl.sid, xl.b),
  fa as (select distinct on (xl.sid, xl.k) xl.id, xl.sid, xl.k, xl.f, xl.v, xl.bk, xl.h, xl.sr, xl.b, xl.ta
           from public.lec_set_log xl
          where xl.set_id = p_set and xl.k <> '' and xl.why not in ('gone', 'done')
            and xl.f in ('sp', 'se', 'w', 'r', 'c', 'ar') and btrim(xl.v) <> ''   -- V2-35 구문 배열 ar
          order by xl.sid, xl.k, xl.ta, xl.bo, xl.b, xl.i, xl.id)
  select fa.sid, fa.k, fa.f, fa.v, fa.bk, fa.h, x.b0, x.o2, x.b0 or x.o2 is not null, rn.rno, fa.ta
    from fa
    join s on true
    join rn on rn.sid = fa.sid and rn.b = fa.b
   cross join lateral (select (case when fa.sr is null then public.lec__v2_r0(s.kind, s.items, fa.k, fa.f, fa.v)
                                    else fa.sr and not exists (select 1 from public.lec_set_fix fx where fx.log_id = fa.id and fx.g) end)
                              and not (fa.h and fa.bk <> 'ev') as b0,
                              case when fa.f in ('sp', 'se', 'w', 'r') and not (fa.h and fa.bk <> 'ev')
                                   then public.lec__v2_ok2id(p_set, fa.k, s.kind, fa.v) end as o2) x
$$;

-- 쌓인 오답 z · y 다시 접기(lec__set_mark 의 z · y 셈 · 날짜 차례 · 같은 날 하나라도 틀리면 z = 그날 · y 지움 ·
--   다 맞고 z 뒤 날이면 y 에 더함 · 두 날이면 z · y 지움): p_es = lec__v2_fix 의 줄 · p_f = 'cur'(고치기 전) 또는 'tg'(고친 뒤)
create or replace function public.lec__v2_zy(p_es jsonb, p_sid text, p_f text) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_x  record;
  v_z  text := '';
  v_y  text[] := '{}';
begin
  for v_x in
    select e.v ->> 'day' as day, bool_and((e.v ->> p_f)::boolean) as ok
      from jsonb_array_elements(p_es) as e(v)
     where e.v ->> 'sid' = p_sid and (e.v ->> 'cd')::boolean
     group by e.v ->> 'day'
     order by 1
  loop
    if not v_x.ok then
      v_z := v_x.day;
      v_y := '{}';
    elsif v_z <> '' and v_x.day > v_z then
      if cardinality(v_y) >= 1 then
        v_z := '';
        v_y := '{}';
      else
        v_y := array[v_x.day];
      end if;
    end if;
  end loop;
  return jsonb_build_object('z', v_z, 'y', to_jsonb(v_y));
end
$$;

-- 다시 셈(이 답도 맞음 · 되돌리기 뒤 · 그 세트 · 문항만): 쓰기 답 줄 = 옛 판 시험 칸(t · 옛 lec_set_ans) · v2 평가 줄(l · ev · 그 판 칸) ·
--   v2 쌓인 오답 줄(l · due · 카드에 반영한 줄) · 지금 맞음(마지막 고침 줄 · 없으면 원래 판정) ≠ (규칙 또는 켜진 인정 답)이면 고침 줄 + 그 판 점수 ±1
--   V2-35: V2-3 새 판(spell · guw · gram · review)의 쌓인 오답 문항 줄(src due · 카드에 반영한 줄 · 단어 sp · 문법 r)도 l 로 셈 · card · say 줄(d · g 만)은 안 셈
--   학생마다: kn(단어 시험 · 그 문항 마지막 답) · z · y(날짜 차례 다시 접기 · 지금 카드 = 고치기 전 접기일 때만) · 첫 판 f1 · 마지막 판 last_sc(고치기 전 값과 같을 때만) ·
--   통과(없으면 넣고 ch.pa · 되돌려 조건이 깨지면 같은 때 넣은 것만 지움) · d · t · best · last_at 은 그대로 · 돌려줌 = 고친 줄 수
--   덧고침(11-20): w(옛 lec_set_staff «자주 틀린 문제»가 세는 틀린 수)도 z · y 와 같은 지킴 = 지금 카드 w 가 고치기 전 틀린 수와 같을 때만 고친 뒤 수로(0 이면 뺌)
create or replace function public.lec__v2_fix(p_set uuid, p_k text, p_ok2 bigint) returns integer
language plpgsql volatile set search_path = public as $$
declare
  s      public.lec_set;
  p      public.lec_set_prog;
  v_e    record;
  v_x    record;
  v_cur  boolean;
  v_tg   boolean;
  v_id   bigint;
  v_es   jsonb := '[]'::jsonb;
  v_sids text[] := '{}';
  v_sid  text;
  v_n    integer := 0;
  v_a    jsonb;
  v_b    jsonb;
  v_c    jsonb;
  v_c0   jsonb;
  v_kn   integer;
  v_ok   boolean;
  v_pa   text;
  v_ch   jsonb;
  v_w0   integer;
  v_w1   integer;
begin
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found then
    return 0;
  end if;
  -- 1) 이 문항의 쓰기 답 줄(학생 · 날 · 때 차례)
  for v_e in
    select z.* from (
      select 't'::text as src, xt.id as tid, (u.o - 1)::integer as ix, null::text as lid, xt.sid, xt.kind as tk,
             (xt.ans -> (u.o - 1)::integer ->> 'at')::timestamptz as at,
             ((xt.ans -> (u.o - 1)::integer ->> 'at')::timestamptz at time zone 'Asia/Seoul')::date as day,
             coalesce((xt.ans -> (u.o - 1)::integer ->> 'r')::boolean, false) as st,
             coalesce((xt.ans -> (u.o - 1)::integer ->> 'r')::boolean, false) as b0,
             false as hh, xt.ans -> (u.o - 1)::integer ->> 'v' as v, true as cd
        from public.lec_set_try xt
       cross join lateral jsonb_array_elements(xt.qs) with ordinality as u(q, o)
       where ((xt.kind in ('test', 'drill') and xt.set_id = p_set) or (xt.kind = 'due' and u.q ->> 's' = p_set::text))
         and u.q ->> 'k' = p_k and u.q ->> 'f' in ('w', 'r')
         and jsonb_typeof(xt.ans -> (u.o - 1)::integer) = 'object'
         and not exists (select 1 from public.lec_set_log y
                          where y.b = xt.id and y.bk = 'ev' and y.i = u.o and y.why in ('', 'late'))
      union all
      select 'l', case when xl.bk = 'ev' then xl.b end, case when xl.bk = 'ev' then xl.i - 1 end, xl.id, xl.sid, xl.src,
             xl.ta, xl.day,
             case when xl.bk = 'ev' then coalesce(xl.sr, false) else xl.ok end,
             coalesce(xl.sr, false) and not (xl.h and xl.bk <> 'ev')
               and not exists (select 1 from public.lec_set_fix fx where fx.log_id = xl.id and fx.g),
             xl.h and xl.bk <> 'ev', xl.v, xl.done
        from public.lec_set_log xl
       where xl.set_id = p_set and xl.k = p_k and xl.f in ('w', 'r', 'sp')   -- V2-35 sp = V2-3 오늘 볼 것 판의 단어 쌓인 오답
         and ((xl.bk = 'ev' and xl.why in ('', 'late')) or (xl.bk = 'due' and xl.done)
              or (xl.bk in ('spell', 'guw', 'gram', 'review') and xl.src = 'due' and xl.done))   -- V2-35 V2-3 새 판의 쌓인 오답 줄(z 를 바꾼 줄)
    ) z
    order by z.sid, z.day, z.at, z.src, z.lid
  loop
    if v_e.src = 't' then
      select fx.ok into v_cur from public.lec_set_fix fx where fx.try_id = v_e.tid and fx.i = v_e.ix order by fx.id desc limit 1;
    else
      select fx.ok into v_cur from public.lec_set_fix fx where fx.log_id = v_e.lid order by fx.id desc limit 1;
    end if;
    if not found then
      v_cur := v_e.st;
    end if;
    v_tg := v_e.b0 or (not v_e.hh and public.lec__v2_ok2id(p_set, p_k, s.kind, v_e.v) is not null);
    v_id := null;
    if v_cur is distinct from v_tg then
      insert into public.lec_set_fix (ok2, try_id, i, log_id, ok)
      values (p_ok2, case when v_e.src = 't' then v_e.tid end, case when v_e.src = 't' then v_e.ix end,
              case when v_e.src = 'l' then v_e.lid end, v_tg)
      returning id into v_id;
      if v_e.tid is not null then
        update public.lec_set_try xt set sc = xt.sc + case when v_tg then 1 else -1 end where xt.id = v_e.tid;
      end if;
      if not (v_e.sid = any (v_sids)) then
        v_sids := v_sids || v_e.sid;
      end if;
      v_n := v_n + 1;
    end if;
    v_es := v_es || jsonb_build_object('sid', v_e.sid, 'tid', v_e.tid, 'tk', v_e.tk, 'day', v_e.day, 'at', v_e.at,
                                       'cur', v_cur, 'tg', v_tg, 'cd', v_e.cd, 'fid', v_id);
  end loop;
  -- 2) 고친 줄이 있는 학생마다
  foreach v_sid in array v_sids loop
    v_ch := '{}'::jsonb;
    select * into p from public.lec_set_prog xp where xp.sid = v_sid and xp.set_id = p_set for update;
    if not found then
      continue;
    end if;
    -- kn: 단어 시험에서 이 문항 마지막 답(뒤에 고르기 답이 있으면 그대로)
    select e.v into v_a from jsonb_array_elements(v_es) as e(v)
     where e.v ->> 'sid' = v_sid and e.v ->> 'tk' = 'test'
     order by (e.v ->> 'at')::timestamptz desc limit 1;
    if v_a is not null and (v_a ->> 'cur') is distinct from (v_a ->> 'tg') and (p_k = any (p.kn)) = (v_a ->> 'cur')::boolean
       and not exists (select 1 from public.lec_set_try xt
                        cross join lateral jsonb_array_elements(xt.qs) with ordinality as u(q, o)
                        where xt.sid = v_sid and xt.set_id = p_set and xt.kind = 'test' and u.q ->> 'k' = p_k
                          and jsonb_typeof(xt.ans -> (u.o - 1)::integer) = 'object'
                          and (xt.ans -> (u.o - 1)::integer ->> 'at')::timestamptz > (v_a ->> 'at')::timestamptz) then
      update public.lec_set_prog xp
         set kn = case when (v_a ->> 'tg')::boolean then xp.kn || p_k else array_remove(xp.kn, p_k) end
       where xp.sid = v_sid and xp.set_id = p_set
      returning * into p;
    end if;
    -- z · y: 지금 카드가 고치기 전 접기와 같을 때만 고친 뒤 접기로(d · t 그대로 · w 는 아래)
    v_b := public.lec__v2_zy(v_es, v_sid, 'cur');
    v_c := public.lec__v2_zy(v_es, v_sid, 'tg');
    v_c0 := case when jsonb_typeof(p.cards -> p_k) = 'object' then p.cards -> p_k else '{}'::jsonb end;
    if v_b is distinct from v_c and coalesce(v_c0 ->> 'z', '') = v_b ->> 'z'
       and (case when jsonb_typeof(v_c0 -> 'y') = 'array' then v_c0 -> 'y' else '[]'::jsonb end) = v_b -> 'y' then
      v_c0 := v_c0 - 'z' - 'y';
      if v_c ->> 'z' <> '' then
        v_c0 := v_c0 || jsonb_build_object('z', v_c ->> 'z');
        if jsonb_array_length(v_c -> 'y') > 0 then
          v_c0 := v_c0 || jsonb_build_object('y', v_c -> 'y');
        end if;
      end if;
      update public.lec_set_prog xp set cards = jsonb_set(xp.cards, array[p_k], v_c0) where xp.sid = v_sid and xp.set_id = p_set;
    end if;
    -- w(덧고침 11-20 · «자주 틀린 문제» = 카드에 w 가 있는 학생 수): 카드에 반영한 줄의 고치기 전 틀린 수 ≠ 고친 뒤 틀린 수이고 지금 카드 w(없으면 0)가
    --   고치기 전 틀린 수와 같을 때만 고친 뒤 수로(0 이면 w 뺌) · 다르면(v2 기록 앞 옛 틀림 · 고르기 틀림이 섞임) 그대로 · 되돌리기도 같은 길(반대로)
    select count(*) filter (where not (e.v ->> 'cur')::boolean)::integer, count(*) filter (where not (e.v ->> 'tg')::boolean)::integer
      into v_w0, v_w1
      from jsonb_array_elements(v_es) as e(v)
     where e.v ->> 'sid' = v_sid and (e.v ->> 'cd')::boolean;
    if v_w0 <> v_w1 then
      select case when jsonb_typeof(xp.cards -> p_k) = 'object' then xp.cards -> p_k else '{}'::jsonb end into v_c0
        from public.lec_set_prog xp where xp.sid = v_sid and xp.set_id = p_set;
      if (case when jsonb_typeof(v_c0 -> 'w') = 'number' then (v_c0 ->> 'w')::integer else 0 end) = v_w0 then
        v_c0 := v_c0 - 'w';
        if v_w1 > 0 then
          v_c0 := v_c0 || jsonb_build_object('w', v_w1);
        end if;
        update public.lec_set_prog xp set cards = jsonb_set(xp.cards, array[p_k], v_c0) where xp.sid = v_sid and xp.set_id = p_set;
      end if;
    end if;
    -- 점수가 바뀐 끝난 시험 · 드릴: 첫 판이면 f1 · 마지막 판이면 last_sc(고치기 전 값과 같을 때만)
    for v_x in
      select xt.id, xt.n, xt.sc, xt.done_at, sum(case when (e.v ->> 'tg')::boolean then 1 else -1 end)::integer as dl
        from jsonb_array_elements(v_es) as e(v)
        join public.lec_set_try xt on xt.id = (e.v ->> 'tid')::uuid
       where e.v ->> 'sid' = v_sid and (e.v ->> 'fid') is not null
         and xt.kind in ('test', 'drill') and xt.done_at is not null
       group by xt.id, xt.n, xt.sc, xt.done_at
    loop
      update public.lec_set_prog xp set f1 = (v_x.sc * 100) / v_x.n
       where xp.sid = v_sid and xp.set_id = p_set and xp.f1 = ((v_x.sc - v_x.dl) * 100) / v_x.n
         and not exists (select 1 from public.lec_set_try y
                          where y.sid = v_sid and y.set_id = p_set and y.kind in ('test', 'drill') and y.done_at is not null
                            and (y.done_at, y.id) < (v_x.done_at, v_x.id));
      update public.lec_set_prog xp set last_sc = v_x.sc
       where xp.sid = v_sid and xp.set_id = p_set and xp.last_sc = v_x.sc - v_x.dl
         and not exists (select 1 from public.lec_set_try y
                          where y.sid = v_sid and y.set_id = p_set and y.kind in ('test', 'drill') and y.done_at is not null
                            and (y.done_at, y.id) > (v_x.done_at, v_x.id));
    end loop;
    -- 통과: 끝난 판이 조건을 채우면(단어 시험 = 외운 수 · 드릴 · 뽑은 판 = 그 판 점수) 넣고 · 조건이 깨지면 고침이 넣은 때만 지움
    select count(*) into v_kn from unnest(p.kn) as y(kk)
     where y.kk in (select u.e ->> 'k' from jsonb_array_elements(s.items) as u(e));
    v_ok := exists (select 1 from public.lec_set_try y
                     where y.sid = v_sid and y.set_id = p_set and y.kind in ('test', 'drill') and y.done_at is not null
                       and ((y.kind = 'test' and not y.drawn and v_kn >= public.lec__set_need(s.n))
                            or ((y.kind = 'drill' or y.drawn) and y.sc >= public.lec__set_need(y.n))));
    if p.pass_at is null and v_ok then
      v_pa := now()::text;
      update public.lec_set_prog xp set pass_at = v_pa::timestamptz where xp.sid = v_sid and xp.set_id = p_set;
      v_ch := jsonb_build_object('pa', v_pa);
    elsif p.pass_at is not null and not v_ok then
      select fx.ch ->> 'pa' into v_pa
        from public.lec_set_fix fx
        join public.lec_set_ok2 o on o.id = fx.ok2
       where o.set_id = p_set and fx.ch ? 'pa'
         and (exists (select 1 from public.lec_set_try y where y.id = fx.try_id and y.sid = v_sid)
              or exists (select 1 from public.lec_set_log y where y.id = fx.log_id and y.sid = v_sid))
       order by fx.id desc limit 1;
      if found and p.pass_at = v_pa::timestamptz then
        update public.lec_set_prog xp set pass_at = null where xp.sid = v_sid and xp.set_id = p_set;
      end if;
    end if;
    if v_ch <> '{}'::jsonb then
      update public.lec_set_fix fx set ch = v_ch
       where fx.id in (select (e.v ->> 'fid')::bigint from jsonb_array_elements(v_es) as e(v)
                        where e.v ->> 'sid' = v_sid and (e.v ->> 'fid') is not null);
    end if;
  end loop;
  return v_n;
end
$$;

-- 켜기 전 기록 다시 매겨 견주기(재는 데에만 · 화면 0 · 밖에서 못 부름 = SQL Editor 에서만): 옛 판 시험 칸(쓰기 답 · v2 평가 줄이 없는 칸) ·
--   n 칸 수 · same 그대로 · up 지금 인정 답으로 맞음이 될 틀린 답 · fixed 이미 고침 줄이 있는 칸 · sets 세트마다(up 많은 차례) · p_set = null 이면 전부
create or replace function public.lec__v2_regrade(p_set uuid) returns jsonb
language sql stable set search_path = public as $$
  with e as (
    select xs.id as set_id, xs.kind, xt.id as tid, (u.o - 1)::integer as ix, u.q ->> 'k' as k,
           coalesce((xt.ans -> (u.o - 1)::integer ->> 'r')::boolean, false) as r,
           xt.ans -> (u.o - 1)::integer ->> 'v' as v
      from public.lec_set_try xt
     cross join lateral jsonb_array_elements(xt.qs) with ordinality as u(q, o)
      join public.lec_set xs on xs.id = case when xt.kind = 'due' then (u.q ->> 's')::uuid else xt.set_id end
     where u.q ->> 'f' in ('w', 'r') and jsonb_typeof(xt.ans -> (u.o - 1)::integer) = 'object'
       and (p_set is null or xs.id = p_set)
       and not exists (select 1 from public.lec_set_log y where y.b = xt.id and y.bk = 'ev' and y.i = u.o and y.why in ('', 'late'))),
  g as (
    select e.set_id, e.r, e.r or public.lec__v2_ok2id(e.set_id, e.k, e.kind, e.v) is not null as r2,
           exists (select 1 from public.lec_set_fix fx where fx.try_id = e.tid and fx.i = e.ix) as fixd
      from e)
  select jsonb_build_object(
           'n', (select count(*) from g),
           'same', (select count(*) from g where g.r = g.r2),
           'up', (select count(*) from g where g.r2 and not g.r),
           'fixed', (select count(*) from g where g.fixd),
           'sets', coalesce((select jsonb_agg(jsonb_build_object('set', x.set_id, 'n', x.n, 'up', x.up) order by x.up desc, x.n desc, x.set_id)
                               from (select g.set_id, count(*) as n, count(*) filter (where g.r2 and not g.r) as up from g group by g.set_id) x),
                            '[]'::jsonb))
$$;

-- 선생님(원장님): 결과 표 = lec_set_staff 그대로 + pts(포인트별 반 첫 답 정답률 [{p, r(%) , n 문항 수, st 푼 학생 수}] · 낮은 차례 · 포인트 없는 세트 = []) +
--   fx(인정 답으로 맞은 첫 답이 그 문항 첫 답의 5% 넘는 문항 [{k, w 문항 앞 40자, n 첫 답 수, f 인정 답으로 맞은 수}] · 문항 차례) · 숫자는 모두 첫 답 기준 · 서버에서 셈
create or replace function public.lec_set_staff_v2(p_set uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_r    jsonb;
  v_pts  jsonb;
  v_fx   jsonb;
begin
  v_r := public.lec_set_staff(p_set);
  if (v_r ->> 'ok') is distinct from 'true' then
    return v_r;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('p', z.p, 'r', z.r, 'n', z.n, 'st', z.st) order by z.r, z.st desc, z.p collate "C"), '[]'::jsonb)
    into v_pts
    from (select ip.p, ip.n, count(distinct fa.sid)::integer as st,
                 ((count(*) filter (where fa.ok)) * 100 / count(*))::integer as r
            from (select btrim(u.e ->> 'p') as p, array_agg(u.e ->> 'k') as ks, count(*)::integer as n
                    from public.lec_set xs
                   cross join lateral jsonb_array_elements(xs.items) as u(e)
                   where xs.id = p_set and xs.kind in ('gu', 'gram') and coalesce(btrim(u.e ->> 'p'), '') <> ''
                   group by btrim(u.e ->> 'p')) ip
            join public.lec__v2_ans1(p_set) fa on fa.k = any (ip.ks)   -- V2-35 이름
           group by ip.p, ip.n) z;
  select coalesce(jsonb_agg(jsonb_build_object('k', z.k, 'w', z.w, 'n', z.n, 'f', z.f) order by z.o), '[]'::jsonb)
    into v_fx
    from (select fa.k, count(*)::integer as n, (count(*) filter (where fa.ok and not fa.b0))::integer as f, min(u.o) as o,
                 min(left(coalesce(case xs.kind when 'voc' then u.e ->> 'w' when 'gu' then u.e ->> 'e' else u.e ->> 's' end, ''), 40)) as w
            from public.lec__v2_ans1(p_set) fa   -- V2-35 이름
            join public.lec_set xs on xs.id = p_set
           cross join lateral jsonb_array_elements(xs.items) with ordinality as u(e, o)
           where u.e ->> 'k' = fa.k
           group by fa.k) z
   where z.f * 20 > z.n;
  return v_r || jsonb_build_object('pts', v_pts, 'fx', v_fx);
end
$$;

-- 선생님(원장님): 학생 하나가 이 세트에서 첫 답에 틀린 문항(규칙으로 틀린 첫 답 · 인정 답으로 맞게 한 것은 acc true 로 남김 · 문항 차례) ·
--   k · n 번호 · q 문제(단어 = 뜻 · 구문 = 해석 · 문법 = 문장) · a 바른 답 · v 첫 답 · f 꼴 · no 몇 번째 판 · at 답한 때 · acc · can(이 답도 맞음 단추 · 쓰기 답 · 힌트 안 봄)
create or replace function public.lec_set_wrong1_v2(p_set uuid, p_sid text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s      public.lec_set;
  v_rows jsonb;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  if coalesce(btrim(p_sid), '') = '' then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'k', fa.k, 'n', coalesce(u.e ->> 'n', ''),
           'q', case s.kind when 'voc' then u.e ->> 'm' when 'gu' then u.e ->> 't' else u.e ->> 's' end,
           'a', case s.kind when 'voc' then u.e ->> 'w' when 'gu' then u.e ->> 'e' else u.e ->> 'a' end,
           'v', fa.v, 'f', fa.f, 'no', fa.rno, 'at', fa.ta, 'acc', fa.o2 is not null,
           'can', fa.f in ('sp', 'se', 'w', 'r') and not (fa.h and fa.bk <> 'ev')) order by u.o), '[]'::jsonb)
    into v_rows
    from public.lec__v2_ans1(p_set) fa   -- V2-35 이름
   cross join lateral jsonb_array_elements(s.items) with ordinality as u(e, o)
   where fa.sid = p_sid and not fa.b0 and u.e ->> 'k' = fa.k;
  return jsonb_build_object('ok', true, 'set', s.id, 'sid', p_sid, 'items', v_rows);
end
$$;

-- 선생님(원장님): 이 답도 맞음(p_on true) · 되돌리기(false) = 인정 답 표에 줄 하나 더(문항 칸 · 열쇠 그대로) → 그 세트 · 문항 다시 셈 ·
--   이미 그 상태면 again(줄 0) · 고르기 문항 · 없는 문항 · 빈 답 = input · 돌려줌 n = 고친 지난 기록 수
create or replace function public.lec_set_ok2_v2(p_set uuid, p_k text, p_v text, p_on boolean)
returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  s      public.lec_set;
  v_it   jsonb;
  v_nm   text;
  v_cur  public.lec_set_ok2;
  v_id   bigint;
  v_n    integer;
  v_who  text;
begin
  if not public.lec_set_is_admin() then
    return jsonb_build_object('ok', false, 'err', 'forbidden');
  end if;
  select * into s from public.lec_set xs where xs.id = p_set;
  if not found then
    return jsonb_build_object('ok', false, 'err', 'none');
  end if;
  select y.e into v_it from jsonb_array_elements(s.items) as y(e) where y.e ->> 'k' = p_k limit 1;
  v_nm := public.lec__v2_ok2nm(s.kind, p_v);
  if v_it is null or p_on is null or v_nm = '' or (s.kind = 'gram' and public.lec__set_opts(v_it ->> 's') is not null) then
    return jsonb_build_object('ok', false, 'err', 'input');
  end if;
  perform pg_advisory_xact_lock(hashtext('lec_v2_ok2|' || p_set::text));
  select * into v_cur from public.lec_set_ok2 o where o.set_id = p_set and o.k = p_k and o.nm = v_nm order by o.id desc limit 1;
  if (found and not v_cur.undo) = p_on then
    return jsonb_build_object('ok', true, 'on', p_on, 'n', 0, 'again', true);
  end if;
  select st.name into v_who from public.lec__staff() st;   -- V2-35 who = 선생님 이름(lec_lecture.created_by · lec_set.made_by 꼴 · 이메일 0)
  v_who := coalesce(v_who, '');   -- V2-35
  insert into public.lec_set_ok2 (set_id, k, m, nm, who, undo)
  values (p_set, p_k, left(btrim(p_v), 400), v_nm, v_who, not p_on)
  returning id into v_id;
  v_n := public.lec__v2_fix(p_set, p_k, v_id);
  return jsonb_build_object('ok', true, 'on', p_on, 'n', v_n, 'again', false);
end
$$;

-- 권한: 속 함수 = 밖에서 못 부름 · 선생님 함수 셋 = 로그인한 사람만(안에서 원장님 확인 · 결과 표 lec_set_staff 와 같음)
revoke all on function public.lec__v2_ok2nm(text, text), public.lec__v2_ok2id(uuid, text, text, text), public.lec__v2_ok2s(uuid),
  public.lec__v2_ok2q(jsonb), public.lec__v2_r0(text, jsonb, text, text, text), public.lec__v2_ans1(uuid),   -- V2-35 이름
  public.lec__v2_zy(jsonb, text, text), public.lec__v2_fix(uuid, text, bigint), public.lec__v2_regrade(uuid)
  from public, anon, authenticated;
revoke all on function public.lec_set_staff_v2(uuid), public.lec_set_wrong1_v2(uuid, text), public.lec_set_ok2_v2(uuid, text, text, boolean)
  from public, anon;
grant execute on function public.lec_set_staff_v2(uuid), public.lec_set_wrong1_v2(uuid, text), public.lec_set_ok2_v2(uuid, text, text, boolean)
  to authenticated;

-- 열넷째 스스로 점검(V2-5): 선생님 함수 막기(로그인 없음 · 다른 계정) · 옛 판 단어 시험 틀린 쓰기 답 → 이 답도 맞음 → 그 판 점수 · kn · 통과 · f1 · z 다시 셈 ·
--   원래 답 줄 · 세트 문항 · 다른 세트 그대로 · 되돌리기 = 처음과 같음(두 번 왕복) · 첫 답은 새 기록 표에서만 · v2 드릴 첫 답 · 포인트별 정답률(낮은 차례) ·
--   포인트 없는 세트 = 줄 없음 · 5% 표시 · 고르기 문항 = input · 구문 외우기 첫 답(뒤에 맞혀도 남음) · 구문 «/» 안 붙음 · 폰에 실은 인정 답 = 서버 채점 ·
--   평가 여는 응답에 인정 답 0 · 켜기 전 기록 견주기 · 권한 · 덧고침(11-20): 인정 → 자주 틀린 문제(w)에서 빠짐 · 되돌리기 → 돌아옴 · 옛 틀림 섞인 카드 = 그대로
-- 넣은 세트 · 열쇠 · 동의 · 줄 · 스위치는 끝에 되돌려 남지 않습니다
do $$
declare
  r       jsonb;
  r2      jsonb;
  v_t     text;
  v_ks    text := replace(gen_random_uuid()::text, '-', '');
  v_ka    text;
  v_kb    text;
  v_sa    text := 'selftest-v5a|점검가';
  v_sb    text := 'selftest-v5b|점검나';
  v_cl    text;
  v_sv    uuid;
  v_sg    uuid;
  v_sr    uuid;
  v_sx    uuid;
  v_try   uuid;
  v_trx   uuid;
  v_b     uuid;
  v_rows  jsonb;
  v_snap  jsonb;
  v_snx   jsonb;
  v_d     date := public.lec__set_today();
begin
  begin
    -- 1) 준비: 스위치(log · eval 켬) · 학생 둘(기록 동의) · 단어 세트 둘 · 문법(포인트 둘) · 구문(포인트)
    update public.lec_v2_cfg set log = true, eval = true, lim = 3000 where id = 1;
    insert into public.lec_v2_cfg (id, log, eval) values (1, true, true) on conflict (id) do nothing;
    v_cl := 'selftest-v5-' || v_ks;
    v_ka := 'selftest' || v_ks || 'v5a';
    v_kb := 'selftest' || v_ks || 'v5b';
    insert into public.lec_key (kh, sid, rid, pin, sname, cls) values
      (public.lec__kh(v_ka), v_sa, 'selftest-v5a', '', '점검가', array[v_cl]),
      (public.lec__kh(v_kb), v_sb, 'selftest-v5b', '', '점검나', array[v_cl]);
    insert into public.lec_consent (sid, choice, ver) values
      (v_sa, 'agree', public.lec__consent_ver()), (v_sb, 'agree', public.lec__consent_ver());
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('voc', '점검 v5 단어', array[v_cl], v_d - 1, '[{"k": "k1", "n": "1", "w": "colour", "m": "색"}]'::jsonb, 1)
    returning id into v_sv;
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('voc', '점검 v5 다른 단어', array[v_cl], v_d - 1,
       '[{"k": "k1", "n": "1", "w": "color", "m": "색깔"}, {"k": "k2", "n": "2", "w": "green", "m": "초록"}]'::jsonb, 2)
    returning id into v_sx;
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('gram', '점검 v5 문법', array[v_cl], v_d - 1,
       '[{"k": "k1", "n": "1", "s": "He (go / goes) home.", "a": "goes", "x": "", "p": "수 일치"},
         {"k": "k2", "n": "2", "s": "I [is] happy.", "a": "am", "x": "", "p": "be동사"}]'::jsonb, 2)
    returning id into v_sg;
    insert into public.lec_set (kind, title, class_ids, posted_on, items, n) values
      ('gu', '점검 v5 구문', array[v_cl], v_d - 1,
       '[{"k": "k1", "n": "1", "e": "I / am a boy.", "t": "나는 소년이다.", "p": "be동사"}]'::jsonb, 1)
    returning id into v_sr;

    -- 2) 선생님 함수 막기: 로그인 없음 · 바깥 사람 · 학생(anon) = forbidden
    foreach v_t in array array['', '{"role":"authenticated","email":"selftest-outsider@gmail.com"}', '{"role":"anon"}'] loop
      perform set_config('request.jwt.claims', v_t, true);
      if (public.lec_set_staff_v2(v_sv) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_wrong1_v2(v_sv, v_sa) ->> 'err') is distinct from 'forbidden'
         or (public.lec_set_ok2_v2(v_sv, 'k1', 'color', true) ->> 'err') is distinct from 'forbidden' then
        raise exception '점검 실패(V2-5 선생님 함수 막기 «%»)', v_t;
      end if;
    end loop;
    perform set_config('request.jwt.claims', '{"role":"authenticated","email":"benjamin@his.kr"}', true);

    -- 3) 옛 판 단어 시험: 점검가 «color» 틀림 · 점검나 «Colour» 맞음 · 다른 세트에서 점검가 «colr» · «grn» 틀림
    v_try := (public.lec_set_test(v_ka, v_sv) ->> 'try')::uuid;
    r := public.lec_set_ans(v_ka, v_try, 0, 'color');
    r2 := public.lec_set_ans(v_kb, (public.lec_set_test(v_kb, v_sv) ->> 'try')::uuid, 0, 'Colour');
    if (r ->> 'r') is distinct from 'false' or (r2 ->> 'r') is distinct from 'true' then
      raise exception '점검 실패(V2-5 준비 · 옛 판 시험): % / %', left(r::text, 300), left(r2::text, 300);
    end if;
    v_trx := (public.lec_set_test(v_ka, v_sx) ->> 'try')::uuid;
    for g in 0 .. 1 loop
      perform public.lec_set_ans(v_ka, v_trx, g,
                                 case (select xt.qs -> g ->> 'k' from public.lec_set_try xt where xt.id = v_trx) when 'k1' then 'colr' else 'grn' end);
    end loop;
    select jsonb_build_object(
             't', (select jsonb_agg(to_jsonb(xt) order by xt.id) from public.lec_set_try xt where xt.sid in (v_sa, v_sb)),
             'p', (select jsonb_agg(to_jsonb(xp) order by xp.sid, xp.set_id) from public.lec_set_prog xp where xp.sid in (v_sa, v_sb)),
             's', (select jsonb_agg(to_jsonb(xs) order by xs.id) from public.lec_set xs where xs.class_ids = array[v_cl]))
      into v_snap;
    select jsonb_build_object(
             't', (select jsonb_agg(to_jsonb(xt) order by xt.id) from public.lec_set_try xt where xt.set_id = v_sx),
             'p', (select jsonb_agg(to_jsonb(xp) order by xp.sid) from public.lec_set_prog xp where xp.set_id = v_sx))
      into v_snx;

    -- 4) 이 답도 맞음(앞뒤 빈칸 · 대문자가 달라도 같은 답): 그 판 점수 1 · kn · 통과 · f1 · last_sc · z 지움 · w 지움(덧고침 11-20 · «자주 틀린 문제»에서 빠짐 ·
    --    d · t 안 되살림) · 원래 답 줄(r false) · 세트 문항 · 다른 세트 그대로 · 같은 것을 또 누르면 again
    if (public.lec_set_staff(v_sv) -> 'often') is distinct from '[{"k": "k1", "w": "colour", "n": 1}]'::jsonb then
      raise exception '점검 실패(V2-5 준비 · 자주 틀린 문제): %', left((public.lec_set_staff(v_sv) -> 'often')::text, 300);
    end if;
    r := public.lec_set_ok2_v2(v_sv, 'k1', ' COLOR ', true);
    select to_jsonb(xp) into r2 from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv;
    if (r ->> 'ok') is distinct from 'true' or (r ->> 'n') is distinct from '1'
       or (select xt.sc from public.lec_set_try xt where xt.id = v_try) is distinct from 1
       or (select xt.ans #>> '{0,r}' from public.lec_set_try xt where xt.id = v_try) is distinct from 'false'
       or (r2 ->> 'pass_at') is null or (r2 ->> 'f1') is distinct from '100' or (r2 ->> 'last_sc') is distinct from '1'
       or (r2 -> 'kn') is distinct from '["k1"]'::jsonb or (r2 #> '{cards,k1}') is distinct from '{}'::jsonb
       or (public.lec_set_staff(v_sv) -> 'often') is distinct from '[]'::jsonb
       or (select jsonb_agg(to_jsonb(xs) order by xs.id) from public.lec_set xs where xs.class_ids = array[v_cl]) is distinct from (v_snap -> 's')
       or jsonb_build_object(
            't', (select jsonb_agg(to_jsonb(xt) order by xt.id) from public.lec_set_try xt where xt.set_id = v_sx),
            'p', (select jsonb_agg(to_jsonb(xp) order by xp.sid) from public.lec_set_prog xp where xp.set_id = v_sx)) is distinct from v_snx
       or (public.lec_set_ok2_v2(v_sv, 'k1', 'color', true) ->> 'again') is distinct from 'true' then
      raise exception '점검 실패(V2-5 이 답도 맞음 · 다시 셈): % / %', left(r::text, 300), left(r2::text, 600);
    end if;

    -- 5) 되돌리기 = 처음과 같음 · 두 번 왕복해도 같음 · 되돌림도 줄 하나 더(인정 답 표 넷 · 되돌림 둘)
    for g in 1 .. 2 loop
      if g = 2 then
        perform public.lec_set_ok2_v2(v_sv, 'k1', 'color', true);
      end if;
      r := public.lec_set_ok2_v2(v_sv, 'k1', 'Color', false);
      if (r ->> 'n') is distinct from '1'
         or (public.lec_set_staff(v_sv) -> 'often') is distinct from '[{"k": "k1", "w": "colour", "n": 1}]'::jsonb   -- 덧고침: 자주 틀린 문제에 돌아옴
         or jsonb_build_object(
            't', (select jsonb_agg(to_jsonb(xt) order by xt.id) from public.lec_set_try xt where xt.sid in (v_sa, v_sb)),
            'p', (select jsonb_agg(to_jsonb(xp) order by xp.sid, xp.set_id) from public.lec_set_prog xp where xp.sid in (v_sa, v_sb)),
            's', (select jsonb_agg(to_jsonb(xs) order by xs.id) from public.lec_set xs where xs.class_ids = array[v_cl])) is distinct from v_snap then
        raise exception '점검 실패(V2-5 되돌리기 %번째): %', g, left(r::text, 300);
      end if;
    end loop;
    if (select count(*) from public.lec_set_ok2 o where o.set_id = v_sv) <> 4
       or (select count(*) from public.lec_set_ok2 o where o.set_id = v_sv and o.undo) <> 2
       or exists (select 1 from public.lec_set_ok2 o where o.set_id = v_sv and o.who is distinct from 'Benjamin') then   -- V2-35 who = 선생님 이름
      raise exception '점검 실패(V2-5 인정 답 줄)';
    end if;

    -- 6) 첫 답은 새 기록 표에서만(옛 판 답 = 목록 0 · 포인트 없는 단어 세트 = 줄 없음) · v2 드릴: 점검가 k1 «go» · k2 «im» 틀림 · 점검나 둘 다 맞음
    if (public.lec_set_wrong1_v2(v_sv, v_sa) -> 'items') is distinct from '[]'::jsonb
       or (public.lec_set_staff_v2(v_sv) -> 'pts') is distinct from '[]'::jsonb then
      raise exception '점검 실패(V2-5 옛 판 답 · 포인트 없는 세트)';
    end if;
    foreach v_t in array array[v_ka, v_kb] loop
      v_b := (public.lec_set_test_v2(v_t, v_sg) ->> 'try')::uuid;
      select jsonb_agg(jsonb_build_object('id', md5('v5d' || v_t || u.o), 'b', v_b, 'i', u.o, 'ago', 100,
                                          'v', case when v_t = v_ka then (case u.q ->> 'k' when 'k1' then 'go' else 'im' end)
                                                    else (case u.q ->> 'k' when 'k1' then 'goes' else 'am' end) end) order by u.o)
        into v_rows
        from public.lec_set_try xt cross join lateral jsonb_array_elements(xt.qs) with ordinality as u(q, o)
       where xt.id = v_b;
      r := public.lec_set_send_v2(v_t, v_b, v_rows);
      if (r ->> 'done') is distinct from 'true' then
        raise exception '점검 실패(V2-5 준비 · v2 드릴): %', left(r::text, 300);
      end if;
      if v_t = v_ka then
        v_try := v_b;
      end if;
    end loop;
    r := public.lec_set_staff_v2(v_sg);
    r2 := public.lec_set_wrong1_v2(v_sg, v_sa);
    if (r ->> 'ok') is distinct from 'true' or not (r ? 'rows')
       or (r -> 'pts') is distinct from '[{"p": "be동사", "r": 50, "n": 1, "st": 2}, {"p": "수 일치", "r": 50, "n": 1, "st": 2}]'::jsonb
       or (r -> 'fx') is distinct from '[]'::jsonb or jsonb_array_length(r2 -> 'items') <> 2
       or (r2 #>> '{items,0,k}') is distinct from 'k1' or (r2 #>> '{items,0,v}') is distinct from 'go' or (r2 #>> '{items,0,can}') is distinct from 'false'
       or (r2 #>> '{items,1,k}') is distinct from 'k2' or (r2 #>> '{items,1,a}') is distinct from 'am' or (r2 #>> '{items,1,can}') is distinct from 'true'
       or (r2 #>> '{items,1,no}') is distinct from '1' or (r2 #>> '{items,1,acc}') is distinct from 'false'
       or (public.lec_set_wrong1_v2(v_sg, v_sb) -> 'items') is distinct from '[]'::jsonb then
      raise exception '점검 실패(V2-5 첫 답 · 포인트): % / %', left(r::text, 400), left(r2::text, 400);
    end if;

    -- 7) 문법 쓰기 답 인정 → 그 판 점수 · 첫 답 정답률(낮은 차례) · 5% 표시 · z 지움 → 되돌리면 처음 · 고르기 문항 · 없는 문항 = input
    r := public.lec_set_ok2_v2(v_sg, 'k2', 'Im', true);
    r2 := public.lec_set_staff_v2(v_sg);
    if (r ->> 'n') is distinct from '1' or (select xt.sc from public.lec_set_try xt where xt.id = v_try) is distinct from 1
       or (r2 -> 'pts') is distinct from '[{"p": "수 일치", "r": 50, "n": 1, "st": 2}, {"p": "be동사", "r": 100, "n": 1, "st": 2}]'::jsonb
       or (r2 -> 'fx') is distinct from '[{"k": "k2", "w": "I [is] happy.", "n": 2, "f": 1}]'::jsonb
       or (public.lec_set_wrong1_v2(v_sg, v_sa) #>> '{items,1,acc}') is distinct from 'true'
       or (select xp.cards -> 'k2' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sg) ?| array['z', 'w']   -- 덧고침: w 도
       or jsonb_typeof(r2 -> 'often') is distinct from 'array'
       or exists (select 1 from jsonb_array_elements(r2 -> 'often') as o(e) where o.e ->> 'k' = 'k2') then
      raise exception '점검 실패(V2-5 문법 인정): % / %', left(r::text, 300), left(r2::text, 400);
    end if;
    r := public.lec_set_ok2_v2(v_sg, 'k2', 'im', false);
    if (r ->> 'n') is distinct from '1' or (select xt.sc from public.lec_set_try xt where xt.id = v_try) is distinct from 0
       or (public.lec_set_staff_v2(v_sg) -> 'fx') is distinct from '[]'::jsonb
       or (select xp.cards #>> '{k2,z}' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sg) is distinct from to_char(v_d, 'YYYY-MM-DD')
       or (select xp.cards #>> '{k2,w}' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sg) is distinct from '1'
       or not exists (select 1 from jsonb_array_elements(public.lec_set_staff(v_sg) -> 'often') as o(e) where o.e ->> 'k' = 'k2')
       or (public.lec_set_ok2_v2(v_sg, 'k1', 'go', true) ->> 'err') is distinct from 'input'
       or (public.lec_set_ok2_v2(v_sg, 'k9', 'x', true) ->> 'err') is distinct from 'input' then
      raise exception '점검 실패(V2-5 문법 되돌리기 · 고르기)';
    end if;

    -- 8) 구문 외우기: 점검가 첫 답 «I am boy» 틀림 → 같은 판에서 맞힘 → 목록에 남음 · 인정 → 세트 문장 그대로(«/» 안 붙음) ·
    --    점검나 판 열기에 인정 답 · 점검나 «i am boy.» = 서버도 맞음(폰 셈 lec__set_snorm_v2 와 같음) · 되돌리면 첫 답 틀림
    v_b := (public.lec_set_open_v2(v_ka, v_sr, 'mem') ->> 'b')::uuid;
    r := public.lec_set_log_v2(v_ka, jsonb_build_array(
           jsonb_build_object('id', md5('v5g1' || v_ks), 'b', v_b, 'i', 1, 'k', 'k1', 'f', 'se', 'v', 'I am boy', 'ago', 2000),
           jsonb_build_object('id', md5('v5g2' || v_ks), 'b', v_b, 'i', 2, 'k', 'k1', 'f', 'se', 'v', 'I am a boy.', 'ago', 1000)));
    r2 := public.lec_set_wrong1_v2(v_sr, v_sa);
    if jsonb_array_length(r -> 'got') <> 2 or jsonb_array_length(r2 -> 'items') <> 1 or (r2 #>> '{items,0,v}') is distinct from 'I am boy'
       or (r2 #>> '{items,0,a}') is distinct from 'I / am a boy.' or (public.lec_set_open_v2(v_kb, v_sr, 'mem') ? 'ok2') then
      raise exception '점검 실패(V2-5 구문 첫 답): %', left(r2::text, 400);
    end if;
    r := public.lec_set_ok2_v2(v_sr, 'k1', 'I am boy', true);
    r2 := public.lec_set_open_v2(v_kb, v_sr, 'mem');
    v_b := (r2 ->> 'b')::uuid;
    if (r ->> 'n') is distinct from '0' or (r2 -> 'ok2') is distinct from '{"k1": ["I am boy"]}'::jsonb
       or (select xs.items from public.lec_set xs where xs.id = v_sr)
          is distinct from '[{"k": "k1", "n": "1", "e": "I / am a boy.", "t": "나는 소년이다.", "p": "be동사"}]'::jsonb
       or public.lec__set_snorm_v2('i am boy.') is distinct from public.lec__set_snorm_v2('I am boy') then
      raise exception '점검 실패(V2-5 구문 인정 · 폰에 실음): %', left(r2::text, 400);
    end if;
    r := public.lec_set_log_v2(v_kb, jsonb_build_array(
           jsonb_build_object('id', md5('v5g3' || v_ks), 'b', v_b, 'i', 1, 'k', 'k1', 'f', 'se', 'v', 'i am boy.', 'pr', true, 'ago', 10)));
    r2 := public.lec_set_staff_v2(v_sr);
    if (select xl.sr::text || xl.ok::text from public.lec_set_log xl where xl.id = md5('v5g3' || v_ks)) is distinct from 'truetrue'
       or not exists (select 1 from public.lec_set_fix fx where fx.log_id = md5('v5g3' || v_ks) and fx.g)
       or (r2 -> 'pts') is distinct from '[{"p": "be동사", "r": 100, "n": 1, "st": 2}]'::jsonb
       or (r2 #>> '{fx,0,k}') is distinct from 'k1' then
      raise exception '점검 실패(V2-5 구문 인정 뒤 채점): % / %', left(r::text, 300), left(r2::text, 400);
    end if;
    perform public.lec_set_ok2_v2(v_sr, 'k1', 'i am boy', false);
    if (public.lec_set_staff_v2(v_sr) -> 'pts') is distinct from '[{"p": "be동사", "r": 0, "n": 1, "st": 2}]'::jsonb then
      raise exception '점검 실패(V2-5 구문 되돌리기)';
    end if;

    -- 9) 다른 세트 인정(점검가 «colr») = 그 세트만(앞 세트 진도 그대로) · 다시 연 평가 응답에 인정 답 0 · 켜기 전 기록 견주기(맞음이 될 것 1 · 이미 고친 것 1) ·
    --    덧고침: 옛 틀림 섞인 카드(기록 앞 틀림 하나를 w 에 더해 둠 · w 2 ≠ 고치기 전 틀린 수 1) = w 그대로 · 자주 틀린 문제에 남음
    update public.lec_set_prog xp set cards = jsonb_set(xp.cards, '{k1,w}', to_jsonb((xp.cards #>> '{k1,w}')::integer + 1))
     where xp.sid = v_sa and xp.set_id = v_sx and xp.cards #>> '{k1,w}' = '1';
    r := public.lec_set_ok2_v2(v_sx, 'k1', 'colr', true);
    r2 := public.lec_set_test_v2(v_ka, v_sx);
    if (r ->> 'n') is distinct from '1' or (r2 ->> 'ok') is distinct from 'true'
       or (select xp.cards #>> '{k1,w}' from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sx) is distinct from '2'
       or not exists (select 1 from jsonb_array_elements(public.lec_set_staff(v_sx) -> 'often') as o(e) where o.e ->> 'k' = 'k1' and o.e ->> 'n' = '1')
       or jsonb_path_exists(r2, '$.**.a2') or r2 ? 'ok2' or r2::text like '%colr%'
       or (public.lec__v2_regrade(v_sx) ->> 'up') is distinct from '1' or (public.lec__v2_regrade(v_sx) ->> 'fixed') is distinct from '1'
       or not exists (select 1 from jsonb_array_elements(v_snap -> 'p') as e(v)
                       where e.v = (select to_jsonb(xp) from public.lec_set_prog xp where xp.sid = v_sa and xp.set_id = v_sv)) then
      raise exception '점검 실패(V2-5 다른 세트 · 평가 응답 · 견주기): % / %', left(r::text, 300), left(r2::text, 300);
    end if;

    -- 9b) V2-35 V2-3 새 판에도 인정 답: 단어 써 보기 판 문항에 a2(인정 답 있는 문항만) · 그 답 = 서버 채점 맞음(채점 때 인정 답 표시) ·
    --     구문 써 보기 문항에 a2 · 배열(ar)은 인정 답을 안 읽음 · 통째(se)는 읽음(폰 Lec.setCheckV2 와 같음)
    update public.lec_v2_cfg set spell = true, guw = true where id = 1;
    r := public.lec_set_open_v2(v_kb, v_sx, 'spell');
    v_b := (r ->> 'b')::uuid;
    if (r ->> 'ok') is distinct from 'true'
       or not exists (select 1 from jsonb_array_elements(r -> 'q') as q(e) where q.e ->> 'k' = 'k1' and q.e -> 'a2' = '["colr"]'::jsonb)
       or exists (select 1 from jsonb_array_elements(r -> 'q') as q(e) where q.e ->> 'k' = 'k2' and q.e ? 'a2') then
      raise exception '점검 실패(V2-35 써 보기 판 인정 답 실음): %', left(r::text, 400);
    end if;
    r := public.lec_set_log_v2(v_kb, jsonb_build_array(
           jsonb_build_object('id', md5('v35s' || v_ks), 'b', v_b, 'i', 1, 's', v_sx, 'k', 'k1', 'f', 'sp', 'v', 'COLR', 'ago', 10)));
    if (select xl.sr::text || xl.ok::text from public.lec_set_log xl where xl.id = md5('v35s' || v_ks)) is distinct from 'truetrue'
       or not exists (select 1 from public.lec_set_fix fx where fx.log_id = md5('v35s' || v_ks) and fx.g) then
      raise exception '점검 실패(V2-35 써 보기 판 인정 답 채점): %', left(r::text, 300);
    end if;
    perform public.lec_set_ok2_v2(v_sr, 'k1', 'I am boy', true);
    r := public.lec_set_open_v2(v_kb, v_sr, 'guw');
    v_b := (r ->> 'b')::uuid;
    r2 := public.lec_set_log_v2(v_kb, jsonb_build_array(
            jsonb_build_object('id', md5('v35a' || v_ks), 'b', v_b, 'i', 1, 's', v_sr, 'k', 'k1', 'f', 'ar', 'v', 'I am boy', 'ago', 20),
            jsonb_build_object('id', md5('v35e' || v_ks), 'b', v_b, 'i', 2, 's', v_sr, 'k', 'k1', 'f', 'se', 'v', 'i am boy.', 'ago', 10)));
    if (r #> '{q,0,a2}') is distinct from '["I am boy"]'::jsonb
       or (select xl.sr::text from public.lec_set_log xl where xl.id = md5('v35a' || v_ks)) is distinct from 'false'
       or (select xl.sr::text || xl.ok::text from public.lec_set_log xl where xl.id = md5('v35e' || v_ks)) is distinct from 'truetrue' then
      raise exception '점검 실패(V2-35 구문 써 보기 인정 답): % / %', left(r::text, 300), left(r2::text, 300);
    end if;

    -- 10) 권한: 선생님 함수 셋 = 로그인한 사람만 · 표 둘 = 아무도 · 속 함수 = 밖에서 못 부름
    if has_function_privilege('anon', 'public.lec_set_staff_v2(uuid)', 'execute')
       or has_function_privilege('anon', 'public.lec_set_wrong1_v2(uuid, text)', 'execute')
       or has_function_privilege('anon', 'public.lec_set_ok2_v2(uuid, text, text, boolean)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_set_staff_v2(uuid)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_set_wrong1_v2(uuid, text)', 'execute')
       or not has_function_privilege('authenticated', 'public.lec_set_ok2_v2(uuid, text, text, boolean)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__v2_fix(uuid, text, bigint)', 'execute')
       or has_function_privilege('authenticated', 'public.lec__v2_regrade(uuid)', 'execute')
       or has_function_privilege('anon', 'public.lec__v2_ans1(uuid)', 'execute') then   -- V2-35 이름
      raise exception '점검 실패(V2-5 권한)';
    end if;
    select string_agg(c.relname || ' ' || u.rl, ', ') into v_t
      from pg_class c
     cross join unnest(array['anon', 'authenticated']) as u(rl)
     where c.relnamespace = 'public'::regnamespace
       and c.relname in ('lec_set_ok2', 'lec_set_fix')
       and (has_table_privilege(u.rl, c.oid, 'select,insert,update,delete') or not c.relrowsecurity);
    if v_t is not null then
      raise exception '점검 실패(V2-5 표 권한): %', v_t;
    end if;
    perform set_config('request.jwt.claims', '', true);

    raise exception 'LEC_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'LEC_SELFTEST_OK' then raise; end if;
  end;
end
$$;

notify pgrst, 'reload schema';

select '강의실 준비 끝' as "결과",
       '점검 14/14 통과' as "점검",
       (select count(*) from public.lec__roster()) as "학생 수",
       (select count(*) from public.lec_lecture) as "강의 수",
       public.lec__pdf_store() as "PDF 저장 곳",
       public.lec__push_status() as "새 영상 알림",
       public.lec__rec_store() as "녹음 저장 곳",
       (select count(*) from public.lec_set_rec where st = 'done' and done_at < now() - interval '30 days') as "30일 지난 녹음";
