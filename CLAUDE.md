# HIS Management System — 작업노트 (CLAUDE.md)

> 이 파일은 **모든 Claude 세션이 자동으로 읽는 작업노트**입니다. PC·폰·웹 어디서 이어가도
> 여기만 보면 지침·현황·규칙을 다 알 수 있게 유지하세요. **작업 후 이 파일도 갱신**해 주세요.

## 0. 사용자(원장 Benjamin)에 대해
- **비개발자**입니다. 항상 **한국어로, 쉽게** 설명하며 진행하세요.
- **디자인/UI 변경은 반드시 Playwright로 렌더링→스크린샷으로 직접 확인한 뒤** 보여주세요(눈으로 안 보고 만들면 어긋남).
- 라이브 사이트: **https://goodmannerboy.github.io/hisbooks/**

## 1. 제품
- 영어학원 **HIS**(Excellence in English, HIS)용 **학원 관리 시스템**.
- 단일 `index.html`(번들러 아티팩트) + **Supabase 클라우드**(로그인·공유DB).
- 목표: 본인 학원 사용 → 추후 **다른 학원에 유료 판매(SaaS)**.

## 2. 현재 상태 (버전 v32.66 기준, 60+ 커밋)
**탭 8개** (`tabsDef`): 
1. `home` 오늘(홈) — 인사+오늘수업+전달사항
2. `bulk` 일간 성장일지
3. `monthly` 월간 성장일지
4. `exams` 성적 성장일지
5. `manage` 종합일지·신규등록(진단/상담)
6. `checkin` 등하원(체크인 자동 출결연동, 반별×요일별 시간표 기반)
7. `schedule` 선생님 일지(주간/월력 시간표+보강+상담기록)
8. `admin` **학원 일지**(**관리자 전용**) — 수강료 장부 + 데이터를 합친 단일 탭. 상단 세그먼트(한눈에/수강료 장부/데이터). `S.adminSeg`('overview'|'fee'|'data')로 전환. 「한눈에」=대시보드: KPI 4개(총 학생·운영 반·오늘 미입력·수강료 미납) + **선생님 현황**(로그인/가입 상태) + 이번 달 수강료 요약 + 데이터·백업. 「수강료 장부」=기존 `isFee` 블록, 「데이터」=기존 `isData` 블록 재사용.
- 비관리자(선생님)는 `admin`(학원 일지) 숨김. 본인 담당 반만 보임(잠금).
- **선생님 현황 데이터**: 로그인 시 cloud gate `recordStaff(id)`가 `data.staff[이름]={name,role,admin,signupAt,lastLogin}`를 기록→app_state로 동기화. `persist()`는 staff 보존(덮어쓰기 방지). 대시보드는 `adminData` IIFE(view==='admin'일 때만 계산)로 렌더.
- 주요 기능: 마일리지(출결0.2·과제차등·시험통과0.5, 결석=0)·티어·장학금, 리포트 4종 통일("A Note for You"+손글씨 서명 '— from {담당쌤}'), 학생 반이동, og:image(카톡 미리보기).

## 3. 아키텍처 / 코드 수정법
- `index.html` = **번들러 아티팩트**. 앱 페이로드는 파일에서 `"<!DOCTYPE html>...`로 시작하는 **JSON 인코딩된 한 줄**(현재 약 170번째 줄). 컴포넌트 로직은 그 안 `<script ... data-dc-script>`(class Component extends DCLogic).
- **데스크톱 Claude Code**: `index.html`을 직접 열어 편집·커밋(로컬 파일).
- **원격/웹 환경**(이 저장소가 클론된 샌드박스): 페이로드가 JSON 인코딩이라 파이썬으로 디코드(json.loads)→편집→재인코딩(json.dumps 후 `/`→`/`, `</script` 없는지 assert) 필요. node --check로 컴포넌트 JS 문법 검증.
- 클라우드 로그인 UI는 페이로드 `<body>` 직후 오버레이(#cloud-gate) + `</body>` 직전 supabase-js(CDN)+로직 주입돼 있음.

## 4. Supabase
- URL: `https://vcfhttzbzgtszpuahibe.supabase.co`
- Publishable key(공개·클라이언트용): `sb_publishable_d-X3ubJw6n4P1zumfRZgrQ_rWDfhmWj`
- 테이블 `public.app_state`(id PK='main', data jsonb, updated_at, client_id) + RLS(authenticated) + realtime. 단일 blob에 전체 학원 데이터 저장, localStorage['his-sys-v4'] 미러+0.7s 디바운스 업서트.
- 로그인 아이디 = `아이디 + @his.kr`(예 benjamin→benjamin@his.kr). `.local`은 Supabase가 거부함.
- 가입코드: **`his`**. 신분: 베이크된 ACCOUNTS(benjamin=관리자) + 자체가입 선생님은 user_metadata{name,role:'teacher'}.
- ⚠️ **미해결 블로커**: Supabase 대시보드 **Authentication→Email→"Confirm email" OFF** 해야 자체 회원가입/로그인 됨. (대시보드에서만 가능, 원장이 직접)

## 5. 배포 / 기기 간 작업
- 저장소 **goodmannerboy/hisbooks**(public), `main` 브랜치 → **GitHub Pages 자동 배포**.
- **PC는 자동 푸시 설정.** 기기 전환 규칙: **끝낸 쪽 push → 시작하는 쪽 pull**. **동시 작업 금지**(충돌).
- 커밋 author: `git config user.email noreply@anthropic.com && git config user.name Claude`. 커밋 메시지에 **버전 `v32.xx` 증가** 스탬프 관례.

## 6. 디자인 토큰
- 딥그린 `#0C4631`, 크림 `#F4ECD7`, 골드 `#C9A227`. 폰트: -apple-system/SF Pro/Apple SD Gothic Neo.
- 헤더: 크림 바탕 + "HIS Management System" 세리프 워드마크(딥그린) + HIS 물고기 마크.

## 7. 남은 일 / 아이디어
- [x] **학원 일지 탭**(수강료+데이터 병합, 한눈에 대시보드, 선생님 현황) 구현·배포. (라이브 검증 필요)
- [ ] **Supabase Confirm email OFF** 확인(블로커). ← 선생님 현황에 선생님이 뜨려면 이게 꺼져 있어야 자체 회원가입/로그인이 됨.
- [ ] **지문분석노트 16개** — HIS 디자인 한 장짜리(요약·흐름·핵심구문·어휘·🎯쪽집게 변형포인트). 샘플 1번 디자인 승인됨(`note_sample` 형식). 원본: 교재 16지문.
- [ ] (추후) 판매용 멀티테넌트(학원별 완전 데이터 분리=Phase B). 현재는 Phase A 단일blob+UI잠금.
