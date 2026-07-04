# HIS Management System — 작업노트 (CLAUDE.md)

> 이 파일은 **모든 Claude 세션이 자동으로 읽는 작업노트**입니다. PC·폰·웹 어디서 이어가도
> 여기만 보면 지침·현황·규칙을 다 알 수 있게 유지하세요. **작업 후 이 파일도 갱신**해 주세요.
>
> 🎨 **디자인/UI 작업 전에는 반드시 [`DESIGN.md`](DESIGN.md)를 먼저 읽으세요.** 원장이 지금까지 내린
> 모든 디자인 지침(색·버튼·카드·레이아웃·리포트·일정·이모지 규칙 등)이 카테고리별로 정리돼 있습니다.
> 새 디자인 결정이 확정되면 DESIGN.md에도 규칙으로 추가하세요.

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
6. `checkin` 등하원(체크인 자동 출결연동, 반별×요일별 시간표 기반). **등하원 알림 = 별도 발송 시스템 대신 ①성장일지 통합 ②미등원 안전망**(v32.409, 출결연구소 대체): ①일간 성장일지 캡처카드에 `TODAY 등원·하원 시각 + 출결pill` 스트립(빌더 `_ckReport`, 캡처카드 '오늘 수업 내용' 위) → 늘 보내던 카톡 성장일지에 그대로 얹힘. ②수업시작+지각기준 지났는데 체크인 없는 학생만 선생님일지›등하원 상단 실시간 패널(`noShowList`/rv `noShow`)+연락 버튼. 스케줄 포맷 `c.schedule[요일번호]="HH:MM"`(sat=6). **학생 셀프 체크인**: 뒷4자리 입력 시 단일매칭이면 자동 «첫=등원/다음=하원»(`_smartType`), «학생 모드 시작»→전체화면 잠금 키오스크(`isKiosk`, 세로 키패드, 형제선택, 성공화면 2.6s 자동초기화, 나가기 PIN `data.kioskPin||'0000'`). 지각=정시(lateMin=0). 상세: 메모리 [[project-checkin-alimtalk]].
7. `schedule` 선생님 일지 — **애플식 세그먼트 4개**(`S.scheduleSeg`, 기본 'stu'): 내 학생(반별 보드·본인 담당 반만)·시간표(주간+월력+보강+상담)·등하원(체크인)·보고(원장님께 보고·건의). 세그먼트 바는 뷰 최상단, 색만 바뀌고 내용만 교체. rv `isSchedStu/isSchedJournal('cal')/isCheckin/isSchedTalk`. (v32.408)
8. `admin` **학원 일지**(**관리자 전용**) — 수강료 장부 + 데이터를 합친 단일 탭. 상단 세그먼트(한눈에/수강료 장부/데이터). `S.adminSeg`('overview'|'fee'|'data')로 전환. 「한눈에」=대시보드: KPI 4개(총 학생·운영 반·오늘 미입력·수강료 미납) + **선생님 현황**(로그인/가입 상태) + 이번 달 수강료 요약 + 데이터·백업. 「수강료 장부」=기존 `isFee` 블록, 「데이터」=기존 `isData` 블록 재사용.
- 비관리자(선생님)는 `admin`(학원 일지) 숨김. 본인 담당 반만 보임(잠금).
- **선생님 현황 데이터**: 로그인 시 cloud gate `recordStaff(id)`가 `data.staff[이름]={name,role,admin,signupAt,lastLogin}`를 기록→app_state로 동기화. `persist()`는 staff 보존(덮어쓰기 방지). 대시보드는 `adminData` IIFE(view==='admin'일 때만 계산)로 렌더.
- 주요 기능: 마일리지(출결0.2·과제차등·시험통과0.5, 결석=0)·티어·장학금, 리포트 4종 통일("A Note for You"+손글씨 서명 '— from {담당쌤}'), 학생 반이동, og:image(카톡 미리보기).

## 3. 아키텍처 / 코드 수정법
- `index.html` = **번들러 아티팩트**. 앱 페이로드는 파일에서 `"<!DOCTYPE html>...`로 시작하는 **JSON 인코딩된 한 줄**(현재 약 170번째 줄). 컴포넌트 로직은 그 안 `<script ... data-dc-script>`(class Component extends DCLogic).
- **데스크톱 Claude Code**: `index.html`을 직접 열어 편집·커밋(로컬 파일).
- **원격/웹 환경**(이 저장소가 클론된 샌드박스): 페이로드가 JSON 인코딩이라 파이썬으로 디코드(json.loads)→편집→재인코딩(json.dumps 후 `/`→`/`, `</script` 없는지 assert) 필요. node --check로 컴포넌트 JS 문법 검증.
- 클라우드 로그인 UI는 페이로드 `<body>` 직후 오버레이(#cloud-gate) + `</body>` 직전 supabase-js(CDN)+로직 주입돼 있음.
- ⚠️ **학생 id 중복 가능성(중요)**: 일부 학생들이 같은 내부 id를 공유하는 데이터가 존재함(원인 미상 — 파일 합치기/명단붙여넣기 추정). 이러면 `document.getElementById('cap-'+id)`가 DOM에서 먼저 나온 다른 학생 카드를 반환해 **엉뚱한 학생이 복사됨**(v32.359에서 지윤→보경 버그). 근본 우회: 캡처 카드에 `data-sname`(학생 이름) 부여 + `_capEl(capId, sname)` 헬퍼로 이름 일치 카드를 선택(id 대신 이름으로 식별). copyRow/previewCard/previewTitle/큐 모두 이름 기반. id로 학생을 찾는 다른 로직(records/mileage recordFor 등)도 같은 중복 위험이 있으니, 학생 관련 신규 기능은 id 유일성을 가정하지 말 것. (근본 해결은 로드 시 중복 id 재배정이지만 records 분리 불가로 데이터 손상 위험 → 원장 확인 없이 자동 수정 금지.)
- ⚠️ **DC 템플릿 이벤트 바인딩 규칙(중요)**: `onclick="{{ ... }}"`에는 **인라인 화살표함수를 쓰면 안 됨** — `{{ () => this.setState({...}) }}`, `{{ () => this.openBulk() }}` 같은 인라인 표현식은 프레임워크가 핸들러로 **바인딩하지 못해 버튼이 완전히 먹통**이 됨(`button.onclick`이 null, scp 클래스 미부여). **반드시 핸들러 "참조"**를 써야 함: rv(렌더값) 객체에 `navGoFee: (() => this.setState({...}))` 처럼 함수 프로퍼티를 만들고 `onclick="{{ navGoFee }}"`로 참조. (v32.349에서 홈 빠른이동 3개+모바일 하단바 5개 버튼이 이 문제로 전부 먹통이던 것을 root rv에 `navGoHome/navGoBulk/navGoCheckin/navGoSchedule/navGoAdmin/navGoFee` 핸들러 추가해 수정. 새 네비 버튼 만들 때 이 패턴 준수.)

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

## 7-1. [해결됨] "선생님일지·학원일지 빈화면/스크롤" 버그 — 진짜 원인은 템플릿 구조 오류 (근본 수정 v32.348)
- **증상**: 선생님 일지/학원 일지 탭이 빈 화면으로 보이거나, 스크롤을 한참 내려야 내용이 나옴. 학원일지는 헤더+세그먼트탭이 사라지고 하위 콘텐츠만 겹쳐 보이기도 함.
- **진짜 근본 원인(v32.348에서 규명)**: 프레임워크 버그가 **아니었음**. 템플릿 페이로드에서 **`<div class="main-pad">`(스크롤 컨테이너 `<main class="scroll-y">` 안의 내용 래퍼)가 너무 일찍 닫혀 있었음.** 정상 5개 뷰(`isHome`/`isManage`/`isBulk`/`isMonthly`/`isExams`)는 전부 `.main-pad` 안에 있는데, `isAdminView`(학원일지)와 `isSchedule`(선생님일지) 두 `<sc-if>` 블록만 `.main-pad`가 닫힌 **뒤에**(=`<main>`의 직계 자식, main-pad의 형제) 위치해 있었음. 그래서 이 두 뷰만 스크롤 영역 밖/앱 레이아웃 밖으로 밀려나 빈화면·겹침이 발생.
- **근본 수정**: `.main-pad`의 닫는 `</div>`를 뒤로 옮겨서 `isAdminView`+`isSchedule`까지 감싸도록 함(신규생 상담 overlay는 `position:fixed`라 안에 들어가도 무방). 이 한 번의 구조 수정으로 두 뷰가 다른 5개 뷰와 **완전히 동일한 DOM 위치**(main 안)에 렌더됨. 브라우저 실측으로 6개 탭 전부 stray 0개·정상 렌더 확인.
- **제거된 임시 우회코드**: v32.326~347에서 시도했던 `_fixStrayView()` 메서드, `componentDidMount`의 MutationObserver 감시, 진단용 에러배너(`__his_err_banner`)를 **전부 삭제**함. 이제 코드가 깨끗함. (교훈: DOM을 사후에 JS로 옮기거나 스타일 패치하지 말고, **템플릿 구조에서 `.main-pad` 안/밖 여부부터 확인**할 것.)
- **재발 시 진단법**: 새 탭 추가 시 그 뷰의 `<sc-if>` 블록이 `.main-pad`(약 254623~) 안에 있는지 확인. 콘솔 빠른 체크: `[...document.querySelector('.sc-host').children].filter(c=>c.tagName==='DIV'&&!c.contains(document.querySelector('main.scroll-y'))&&!c.querySelector('header')).length` 가 0보다 크면 그 뷰가 main 밖으로 샌 것 → 템플릿에서 `.main-pad` 밖에 있는지 확인.

## 7. 남은 일 / 아이디어
- [x] **학원 일지 탭**(수강료+데이터 병합, 한눈에 대시보드, 선생님 현황) 구현·배포. (라이브 검증 필요)
- [ ] **Supabase Confirm email OFF** 확인(블로커). ← 선생님 현황에 선생님이 뜨려면 이게 꺼져 있어야 자체 회원가입/로그인이 됨.
- [진행중] **영어 분석노트(지문분석)** — 사양서: `C:\Users\User\Desktop\HIS-분석노트-사양서.md`. **범용 템플릿 파일: `C:\Users\User\Desktop\HIS-분석노트.html`** (index.html과 별개의 독립 산출물, 학생 배포용 A4 PDF). 파일 안 `DATA` 배열에 지문 객체만 추가하면 페이지 자동 증가. **지문 1~4 실제 원문 완성·출제자 감수 통과**(원장이 8지문 원문 제공함). 폰트는 고정이 아니라 `fitVars()`로 **지문 길이별 자동 스케일**(6문장=크게~12문장=작게)→어떤 길이든 항상 1페이지. 헤더 로고는 **실제 HIS 로고**(물고기 안 HIS + 눈점 + 십자꼬리 SVG + "Excellence in English, HIS" 태그라인). 렌더 검증법: node 없음 → **헤드리스 크롬**으로 스크린샷+PDF 생성(`chrome --headless=new --screenshot`/`--print-to-pdf`, `--user-data-dir`를 매번 새 폴더로 줘야 안 깨짐). ⚠️ PDF 페이지수=1이어도 `.page`가 `overflow:hidden`이라 내용 잘림을 감출 수 있음 → **반드시 스크린샷(window 820x1240)으로 마지막 문장까지 안 잘렸는지 눈으로 확인**할 것. 폰트 키우면 사양서대로 일러스트/마인드맵/노트칸/행여백을 줄여 공간 확보. **디자인 확정 사항(원장 승인)**: ①영어 청크는 양쪽정렬로 우측까지 꽉 채우고 chunk가 통째로 줄바꿈되지 않게(단어 단위만) `display:inline`+justify. ②문장성분 청크(S·V·O·C·Adv) 사이엔 `/`, 형용사/관계절(Adj) 청크는 `( )`로 감쌈(청록). ③마인드맵은 **단계=색 위계**(`STAGE` 표): 주장=빨강·반론=주황·예시=노랑·전개=초록·도입=회색·결론=딥그린, 연한 틴트카드+좌측 액센트. ⚠️ **주장의 정의(원장 확정 규칙, 모든 지문 적용)**: **주장 = 글쓴이 입장에서 전체 글을 통해 독자에게 하고 싶은 말(핵심 메시지)이 함축되어 있는 한 문장.** 이 문장을 마인드맵 빨강 `주장` 노드(최고강조) + 핵심 주제문(노란 형광)으로 **일치**시킴. 지문 속 인물/기관의 말(정부·전문가 등)은 글쓴이 주장이 아니므로 `전개`(초록, 검토 대상)나 `도입`으로 내리고, 그에 대한 반박은 `반론`(주황)으로. (지문1 실제: ①②③④=도입, ⑤⑥⑦·⑧⑨=전개(정부 해명), ⑩=글쓴이 주장=핵심주제문.) ④**쪽집게 변형문제 유형(칩) 표준 세트(원장 지정)**: 어법성 판단 / 요지·주장·주제·제목 / 빈칸 추론 / 어휘 추론 / 문장 삽입 / 글의 순서 / 밑줄 함축의미 / 요약문 완성 (+내용 일치·지칭). 각 지문 특성에 맞는 6개를 골라 `predictTypes`에 넣음(비유문=순서·삽입, 연구·해명문=요약문·빈칸 등). **남은 일: 5~8번 지문 DATA 채우기(원문은 원장이 이미 제공, 위 규칙대로 문법·주장·마인드맵·전용일러스트·쪽집게 채우고 자체 감수).**
- [참고자료·요청 시 제작] **메타인지 플로우 학습지 포맷(두 번째 확정 포맷)** — 자료: `C:\Users\User\Downloads\고2 메타인지 플로우.zip`(안에 `design_handoff_his_worksheets/`). ⚠️ **원장 지시: 지금 만들지 말고 다음에 요청할 때 이 스펙대로 제작**. 패키지 내 **`CLAUDE.md`가 전체 스펙 single source of truth**, 완성 샘플 `samples/metacognition_UNIT19.dc.html`(메타인지 플로우)·`samples/bbr_U04_P11.dc.html`(빠바 구문분석=내 분석노트와 유사), 마스코트 장면 이미지 `assets/u18~u20-scene.png`(오리지널·저작권 안전, 기존 IP 금지) + `his-logo-wide.jpg`. **메타인지 플로우 규격 요약**: A4 794×1123px, `position:absolute` 좌표, 색=forest green`#003322`/cream`#F4ECD7`/brass`#B5882F`/카드`#FFFCF2`, **Pretendard 고딕 전용**(세리프·이탤릭 X, 꼬리말 태그라인만 serif italic), **흑백인쇄 최우선**(밝은 배경+진한 텍스트, 진한 배경블록 지양), 이모지 금지. 위→아래: ①머릿말(112px 크림, 하단 2.5px#003322, 로고 `left:-21px`, 황금비 구분선 `left:531px`, 우측 타이틀블록 `left:553px`=해석컬럼선 정렬, UNIT배지+"메타인지 한 장 정리"+한글제목21px/800+유형). ②지문/해석 **좌영어:우해석=7:3**(flex 7/1px디바이더/flex 3), ❶❷ 번호(brass 700) 1:1, **둘 다 justify**, 영어 14px/줄간격2.4, 해석 10.5px/줄간격 조절로 **두 단 바닥선 줄맞춤**, 핵심요지 문장 1개 양쪽 하이라이트 `#FBEAC0`(text`#4A3A12`). ③메타인지 전개요소 카드 3~5개(지문에 있는 것만 순서대로) — **고정색: 도입`#1F5C8A`·전개`#1B7A47`·예시`#2E8B82`·반론`#7A4A8C`·주장`#B23A2C`·결론`#8A6520`**(밝은 배경+상단 3px룰+배지+영어 어휘칩, 카드>4개면 칩 2개로). ④하단 마스코트 장면 이미지(좌 약64%)+글의 요지 카드(우, `#FFFCF2`+브라스룰, 한글1문장+영어1문장 고딕). ⑤꼬리말 우측정렬 `Excellence in English in HIS`(serif italic#73531A)+`히즈어학원 · <회차>`. 빠바 SVOC 색: `.s{#003322}·.v{#1F5C8A}·.o{#8A6520}·.sc{#7A4A8C}·.m{#4A5147}`. 여러 장 PDF: `.page` 래퍼+`padding-bottom:297mm`+`@page{size:210mm 297mm;margin:0}`.
- [참고자료·요청 시 제작] **네이버 블로그 리뉴얼 디자인** — 자료: `C:\Users\User\Desktop\HIS-블로그리뉴얼\`(원본 zip: `C:\Users\User\Downloads\학원 블로그 디자인 리뉴얼.zip`). ⚠️ **원장 지시: 지금 만들지 말고 다음에 요청할 때 참고**. 대상=네이버 블로그 `blog.naver.com/his-language`(수능/입시+초중등 영어 HIS). 폴더 내 **`README.md`가 전체 스펙 single source of truth**(디자인 토큰·화면구성·네이버 적용 가이드 다 있음). 시안 3종 중 **시안 A(Ivory Editorial, 웜 아이보리 매거진풍)=채택**(`HIS 블로그 리뉴얼 시안.dc.html`의 맨 왼쪽 프레임). PC 타이틀배너 산출물=`HIS 타이틀배너 PC 966.dc.html`(966×300, 크림 #F3ECD6 배경+안쪽 테두리+"수능·내신·초중등 영어 전문" eyebrow+그린 로고 184px). 로고 PNG 2종=`assets/his-logo-green.png`(밝은배경용)·`his-logo-cream.png`(다크배경용). **핵심 색**: green-900 `#003322`·green-700 `#0D5B3E`·ink `#1D2B22`·body `#5C5A52`·muted `#9A8F6E`·cream `#F4EED8`·bg-page `#FAF6EC`·bg-banner `#F3ECD6`·border `#E6DCBF`. **폰트**: 국문 Pretendard, 영문 디스플레이/슬로건 Cormorant Garamond(주로 italic). ⚠️ **네이버 현실 제약**(README): 커스텀 코드 주입 불가 → 디자인은 (1)PC 타이틀배너 이미지 966px (2)모바일 커버 이미지 (3)메뉴/카테고리 구조(학원소개·수능내신·초중등·수강후기·입시칼럼·공지) (4)스킨 배경 아이보리 `#FAF6EC` 단색으로 "떨어뜨려" 적용. 자체 랜딩페이지로 갈 경우엔 README대로 풀 구현 가능. **미확정(작업 전 원장 확인)**: 실제 전화번호·상담시간·카톡채널, 최종 카테고리, 실제 수업 사진(현재 플레이스홀더). 렌더 검증=`.dc.html`은 support.js(Design Component 런타임) 필요 → 헤드리스 크롬으로 스크린샷/이미지 산출.
- [ ] (추후) 판매용 멀티테넌트(학원별 완전 데이터 분리=Phase B). 현재는 Phase A 단일blob+UI잠금.
