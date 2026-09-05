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

## 1-1. ✅완료(v33.135, 2026-09-01): 성적통지서 «답안 지도 + 약점 진단» 확장
- 스펙·확정 시안·유형표: `신규생통지서 시안/SPEC-답안지도.md` (2026-09-01 원장 컨펌) — **전 항목 구현·배포 완료**.
- 구현: ①레이더→«영역별 성취도» 섹션 우측 컴팩트 통합(2열 그리드, rv `ltRadarLabelsC` — 같은 svg viewBox 축소
  렌더 + 라벨은 % 좌표) ②도넛=실제 점수 `{{ ltScoreShow }}`+등급 필 `{{ ltGradePillTxt }}`, 캡션 «종합 점수 · 등급»
  ③레이더 자리=sc-if 분기: `ltHasMap`(45문항 답안 지도 — `ltMapRows`, 셀 스타일은 전부 rv에서 계산해 style 보간,
  오답=#F9E3D8+정답 원문자 fromCharCode(9311+k), 금테=inset 1.5px #C9A227) / `ltNoMap`(수기=기존 레이더 그대로)
  ④진단 본문 뒤 골드 형광 강조 span `{{ ltDiagExtra }}` — 오답을 유형표로 묶어 영역 상위 2·유형 상위 2+번호,
  오답 중 3점 비중 ≥60%면 «기본 문항은 탄탄…» 구절 선행 ⑤도넛·표 총점=배점 기준 실제 점수, 표 등급 칸도 동일
  기준(`ltAvgGradeNum` 재정의; 성취도 헤더 «평균 N%»만 평균 유지) ⑥수기(제출 없음/10문항 미만)=기존 레이아웃.
- 신규 메서드: `_ltItemTypes()`(45문항 유형표 3형 내장 — 시험 개정 시에만 재생성), `_ltAnswerMap(data,sid,subj)`
  (examSets lt2026* submissions 판독 → total·rows·extra, 실패 시 null=수기 분기).
- 검증: 김서인 재현(70점·오답13) 실렌더 — 도넛 70·3등급, 오답 13칸 원문자 전수 일치, 금테 10칸, 진단 문장
  유형·번호 정확(«글의 순서·주제 유형(34·40·41)») + 수기 학생 기존 레이더 유지. 게이트 4종 통과.

## 2. 현재 상태 (버전 v32.66 기준, 60+ 커밋)
**상단 탭 4개**(v32.600, `tabsDef`): **오늘 · 학생일지 · 선생님 일지 · 학원 일지**. «학생일지»=일간·월간·성적 통합 탭(key는 여전히 'bulk'; 클릭=openBulk()로 일간 도착; 활성=view∈{bulk,monthly,exams}; 내부 [일간·월간·성적] 세그먼트 바 rv `isGrowthTab`/`growthSegBtns`, isBulk 첫 가드 직전 마크업). ⚠️ 내부 view id(bulk/monthly/exams)와 모든 가드·rv는 그대로 — 탭 껍데기만 바뀜. 모바일 하단바 bulk 라벨='학생일지'. 아래는 기존 view 8개 설명: 
**레벨테스트 상태 카드 (커밋 eff908c, 2026-07-28, 원장 위젯 시안 컨펌)**: 신규진단 레벨테스트 카드를 상태 기반으로 재설계 — 스캔 전=드롭존 하나(수기 정답수/문항수 8칸·OMR 스트립 제거), 스캔 후=결과 요약(총점/판정레벨/D지수 칩 + 영역 바, 50% 미만 '약점' 코랄) + [문항별 확인·수정](lt2026 examSets 프리셋 모달)/[다시 스캔]. 과목 자동 추론(subject 기본값일 때 학교/학년의 초/고), **주소 기입란 제거**(iAddress rv·모델은 유지). 패치 lt_state_card.py. 관련: add_lt_omr.py(v32.908)·add_lt_examsets.py(v32.909)·EXAM-GRADING-SPEC 4단계. ⚠️ 이 폴더는 병렬 세션이 함께 작업 중(v32.97x) — index.html 패치 전 git log 확인 권장.

**v32.909 (2026-07-27)**: 레벨테스트 3종을 **기존 정답키 시험 도구(examSets)에 프리셋 통합**(원장 지시: 기존 툴 재사용). 기존 모달 목록에 '레벨테스트 2026 · 초등/중등/고등' 상시 존재, 기존 OMR·탭입력·알림장 그대로 사용, 채점 시 신규진단 intake.lt 자동 동기화. 신규진단 스트립은 같은 엔진의 단축 입구로 재배선([문항별 확인·수정]=기존 모달 오픈). 상세는 EXAM-GRADING-SPEC 4단계.
**v32.908 (2026-07-27)**: 신규진단 레벨테스트 **OMR 스캔 자동 입력**(EXAM-GRADING-SPEC 4단계 1차) — lt 입력 카드에 OMR 스트립, 스캔(이미지·PDF) 올리면 내장 정답키(초/중/고 45문항)로 자동 채점 → 영역별 정답수/문항수 8필드 자동 기입 → 기존 통지서(#intakecap) 즉시 갱신, diagnosis에 총점·판정레벨·D지수 프리필. 패치 `add_lt_omr.py`, 정답키 원본은 바탕화면 히즈문서/레벨테스트/2026리뉴얼(src/export_appkeys.py). 부팅·콘솔 검증 완료(로그인 화면 렌더 OK). ⚠️ 로그인 후 신규진단 모달 실사용 확인은 원장 계정으로 필요.

1. `home` 오늘(홈) — 인사+오늘수업+전달사항. **행동 허브 1차(v32.663, 원장 승인 1번)**: «오늘 내 수업» 각 반 행에 등원 n/m·결석예정 칩(초록)+미등원 이름(빨강)+«일지 쓰기» 금색 필 — homeData 슬롯 빌더에서 4단 가드(checkins→_cdClosed→noShowExcused→스케줄)+퇴원/pending 제외, 행 클릭=openBulkFor(임시입력 복원 경로). ⚠️ 홈 수업 목록은 schedule.days 배열 기반(숫자키 아님) — 하니스 데이터에 days:[요일] 필수. **오늘의 라인업(v32.670, 원장 승인 운영①)**: 각 반 행 칩 아래 브리핑 줄(반당 최대 6) — 🎂 생일(_isBirthday)→💛 케어 큐(_careCue: 결석 복귀/시험 급락)→📎 작은 기록(_smallNotesFor 최신 1건 26자) 순, 휴원일(_cdClosed)엔 통째 숨김, slots.push brief→classes map brief/hasBrief→cl.brief sc-for 마크업(칩 sc-if 뒤·flex:1 div 안). 리츠칼튼 데일리 라인업 컨셉 — 선생님이 수업 전 30초에 오늘 마음 쓸 학생 파악.
2. `bulk` 일간 성장일지 — **임시입력 클라우드 동기화(v32.660, 원장 «나갔다 오면 시험 기록 사라짐»)**: 일간일지 입력(점수·출결·코멘트 등)은 저장 전엔 원래 기기 로컬(hizsys_draft_반_날짜)에만 있어 다른 기기/카톡 인앱(저장소 증발)에서 유실 — 이제 `data.bulkDrafts[classId|date]={rows,lesson,nextPrep,session,skip,t,by}`로 didUpdate에서 5s 스로틀 동기화(rows 비면 스킵), openBulk·반전환 복원 시 로컬 vs 클라우드 t 비교 최신 승리(⚠️ rows 빈 로컬본은 항상 클라우드에 양보 — 빈 채 열어둔 기기가 이김 방지), 저장(saveBulk 2곳)=«{del:1,t}» tombstone+로컬 제거, merge=키별 LWW(_hisMapMerge, noShowExcused 뒤)+_absorbFresh 동일, 14일 경과분 자동 정리(블롭 비대 방지). 검증=격리 merge 유닛 6/6+실브라우저 «타기기 복원→저장→tombstone» E2E. **점수 일괄 입력(v32.674, 원장 승인 — 매일 3종 시험 워크플로 ①)**: 상단 «⚡ 점수 일괄 입력» 버튼(bulk-actions 첫 자리) → 최상위 모달(S.qsOpen, v619 규칙) — 그리드(학생 세로×문법/주요구문/독해어휘/히즈어휘), input마다 id qs-{과목ci}-{학생qi}·**tabindex 행 우선(v32.695, 원장 «학생마다 작성 후 다음 학생») ti=(qi+1)*20+ci**·Enter=우측 다음 과목(줄 끝=다음 학생 첫 칸, 스킵 «–» 칸은 for 12회 탐색으로 건너뜀), oninput=setBulk(기존 draft 경로라 카드·클라우드 임시저장·전체저장 흐름 그대로), skip 과목은 «–». rv qsRows는 qsOpen일 때만 계산(bulkCk 옆). **모달=시험 관제판(v32.676, 원장 «점수설정·시험설정»)**: 헤더가 과목 토글 필(toggleBulkTestAll — top키+전 학생 per-student skip 동시 브로드캐스트, 카드 토글과 일치)+«만점» 입력(setBulkTotalAll — 전 학생 {k}T 일괄, draft 경로), OFF 과목=열 전체 «–». **이모지 절제(v32.678, 원장 «AI스러워»)**: 트레이닝·점수일괄입력 계열 이모지 전부 제거(버튼·모달 헤더·어휘은행 카드·오답 재도전 배지 — 텍스트+컬러만; 🏆 아이콘 버튼·기존 승인 이모지는 유지). 새 기능 버튼에 이모지 붙이지 말 것. **상단바 한 줄(v32.675, 원장 «한줄로»)**: 바 padding 13/16·gap 10, 반 셀렉터 168px, 버튼 4개 42px 컴팩트, «장학마일리지 안내»=🏆 아이콘 버튼(title 툴팁), 칩 미등원 3명 초과 «외 N» — 1500px에서 diff -2px 실측(flex-wrap 유지라 좁은 화면 자연 줄바꿈). 배경: 출제=클래스카드·응시=종이 유지, 전기(옮겨적기)만 제거 — 다음 단계 후보=HIS 답안카드 카메라 채점(원장 HIS-OMR판독기.html 실험 연계). **결석 연쇄 자동화(v32.691, 원장 «결석=과제 미완료·시험 미실시»)**: 3계층 — ①setBulk 결석 클릭=과제 미완료(기존)+bulk.skip[sid] 4과목 전스킵, 결석→다른 출결로 바꾸면 스킵·미완료 원복 ②loadDraft 유도 결석(autoAttendance) 기본값=과제 미완료(무조건)+kOn 4종 false ③saveBulk 2곳=저장 직전 attendance 결석이면 sk 강제 4과목+빈 과제만 미완료 채움(선생님 명시 변경은 존중) — ⚠️ saveBulk에서 autoAttendance 채움을 스킵 적용보다 먼저로 순서 이동(안 하면 유도 결석 미반영). 검증=E2E(유도 미완 pill·결석 클릭 그리드 «–»·저장 기록 gOn~hOn false+미완료, 수동·유도 모두). **숫자칸 휠 가드(v32.661)**: componentDidMount 전역 위임 wheel 리스너(capture, passive)가 포커스된 input[type=number] 위 휠에 blur — 시험점수·만점·마일리지 등 숫자칸 12곳 전부 스크롤 오변경 차단(페이지 스크롤은 유지). ⚠️ 하니스 교훈: 시드 스크립트가 리로드마다 his-sys-v4를 되돌리면 앱이 저장한 걸 지워 가짜 버그가 보임 — 리로드 검증엔 seed-once(`if(!getItem)`) 하니스(harness_bulkexc_once.py) 사용. **등하원 통합 1차(v32.646, 역할분리 IA 원장 합의)**: 학생 카드 헤더 아래 등하원 스트립(rv `r.ck`: 등원=초록 «등원 HH:MM·하원 —», 미등원+오늘+스케줄=붉은 «아직 등원 전·수업 시작 HH:MM», 과거/무스케줄=숨김; **v32.656 결석예정 반영**: noShowExcused(키 sid|date, del 가드) 있으면 체크인 분기 다음·붉은 분기 전에 그레이지 «결석 예정·사유» 스트립(#F1EFE8/#6b6350=관제판 exc 톤), 칩도 결석예정은 미등원서 빼고 «등원 n/m · 결석예정 k» — 등하원 표시 신설 시 noShowExcused 가드 필수) + 반 상단 «등원 n/m·미등원 이름» 칩(rv `bulkCk`, 오늘+스케줄 반만)=클릭 시 `bulkCkGo` 핸들러로 선생님일지›등하원 이동. 정정·결석예정 등 관리는 등하원 탭에 유지(확인=일지, 관리=운영센터 원칙). **생일 가시화(v32.653)**: 홈 인사말 아래 «오늘 생일» 금색 카드(homeBdays rv, visibleClasses 기반=선생님 자기 학생만)+관제판·등하원 현황 행 «생일» 태그. ⚠️ 다단계 apply 스크립트는 중간 실패 시 앞선 편집도 유실(쓰기 1회) — 실패 후 «적용됐다» 가정 금지, 파일 재확인. 결석예정 학생칸=내용폭 칩 flex-wrap(v32.651, 3등분 그리드 금지 — 넓은 화면서 이름·버튼 벌어짐). **2차(v32.647)**: 미등원 스트립에 «수동 등원 기록» 버튼(`r.onManualIn`=confirm 후 `setCheckinEdit` 재사용, LWW 안전) + 수업종료 후 하원 없으면 sub=«하원 미기록»(호박 #9A6A16, `r.ck.subFg`) — 단일 sc-for+동적 sc-if 버튼이라 바인딩 정상(v619 함정은 이중 sc-for만). E2E 검증법=harness_bulkck2.py(수업종료 시각 하니스)+playwright dialog accept→칩/스트립 갱신+localStorage checkins 확인. **3차(v32.648)**: 등하원 탭 내부 순서=①미등원 안전망 ②오늘 현황 ③결석예정 ④휴원일 ⑤학생모드 시작(빈도·시급순, 이전 역사순에서 재정렬). 블록 이동은 균형 파서(div/sc-if/sc-for depth)로 최상위 5블록 경계 추출→재조립+태그쌍 수 assert(§7-1 예방).
2-a. **케어 큐+작은 기록(v32.669, 원장 승인 고객감동 ②→①)**: **케어 큐**=_careCue(data,classId,sid,date) 유도 신호 2종 — ①직전 일지 기록이 결석→«결석 후 첫 수업이에요»(키오스크 인사도 «다시 만나 반가워요,»로, checkinResult.careBack) ②최근 7일 내 시험이 직전 대비 10%p 이상 하락→«격려가 필요한 날». 일간일지 카드 케어 스트립(크림+💛, «선생님만 보여요», 오늘 날짜만)+bulkRows r.care. **작은 기록**=리츠칼튼 취향노트: `data.smallNotes[uid]={sid,text(60자),by,at,t}` 키별 LWW+«{del:1,t}» tombstone(merge smallNotes 블록), 입력·목록=종합일지 프로필 «💛 작은 기록» 카드(#sn-input 비제어, profilecap 캡처영역 **밖**=학부모 카톡 미포함, intake 내부용 섹션 앞), 일간일지 카드에 최신 2건 📎 한 줄(r.sn). 검증=키오스크 복귀인사+카드 힌트 2종+평온학생 무힌트+추가/저장/표시 E2E.
3. `monthly` 월간 성장일지
4. `exams` 성적 성장일지
5. `manage` 종합일지·신규등록(진단/상담). **성장 필름(v32.668, 원장 승인 혁신1번)**: 종합일지 프로필 액션 줄 «🎞 성장 필름» 버튼(profile.onFilm→openFilm) → 딥그린 전체화면 5장 시네마(S.filmSid/filmStep, 5.2s 자동 전환+이전/다음/점 내비): ①타이틀(«{이름}의 계절», 최근 120일) ②숫자(수업·일지·시험 수) ③성적 곡선(exams pct polyline, fmDash 드로잉, «+N점 성장» fmPop) ④선생님 코멘트 명장면 3개(길이순) ⑤티어 엠블럼+«{이름}[이]는 자라고 있습니다 — from 담당쌤»(받침 조사 판별 subj). rv `film`은 profile shorthand 있는 큰 rv에(⚠️ feeData쪽 rv에 넣으면 no-op 바인딩 — v665와 같은 함정), 마크업은 profile overlay 앞(같은 스코프), fm 키프레임 3종은 페이로드 head hb 옆. 상담·재등록 자리에서 태블릿/PC로 보여주는 용도(호스팅·개인정보 無). 검증=종합 버튼→프로필→필름 5장 실렌더+조사+닫기 복귀.
6. `checkin` 등하원(체크인 자동 출결연동, 반별×요일별 시간표 기반). **등하원 알림 = 별도 발송 시스템 대신 ①성장일지 통합 ②미등원 안전망**(v32.409, 출결연구소 대체): ①일간 성장일지 캡처카드에 `TODAY 등원·하원 시각 + 출결pill` 스트립(빌더 `_ckReport`, 캡처카드 '오늘 수업 내용' 위; v32.693 **TODAY 스트립 A안 타임라인(원장 채택)**: 등원 기록 있으면 «●등원 HH:MM ─그라데이션 선─ 하원 HH:MM●»(하원 전=반쪽 선+«—»+빈 점), 결석은 문장형 — 사유有=그레이지 «●{사유} — 미리 연락 주신 결석이에요/예정이에요»(exPast 시제), 무단=빨강 «등원 기록이 없는 날이에요» — _ckReport에 tl/outDisp/outFg/lineBg/outDotStyle/hasMsg/msg/msgFg 추가+마크업 교체(s.ck 스코프). 검증=4상태 실렌더 스크린샷. v32.688~689 **결석예정 시제 정합(원장 확정: 기준=수업 시작)**: 사유 있는 결석 표기가 «지난 날짜 or 오늘 수업 시작(_classStart) 후»면 «결석 예정 · 사유»→«결석 · 사유»로(그레이지 톤 유지) — 캡처카드(_ckReport exPast)·일간 카드 스트립(r.ck exP1)·관제판(en&&now>en) 3곳 동일 규칙. 검증=종료반/미래반 2케이스 3표면 실렌더. v32.687 **종료 후 미등원 표기 정합**: 수업 종료(_classEnd) 경과+미등원이면 일간 카드 스트립=«미등원 결석 처리»(수동 등원 버튼 유지)·관제판 pill=«미등원 결석»(missN KPI 불변) — 종료 후에도 «아직 등원 전»이라던 모순 제거, 자동결석 pill과 한목소리. ⚠️ 하니스에 sc.end 필수(_classEnd가 sc.times[day].end→sc.end→c.endTime 순, 없으면 종료 분기 전체 무발동). v32.686 **결석 사유 표기**: TODAY 스트립 출결 pill이 결석+noShowExcused(!del) 매칭이면 그레이지(#F1EFE8/#6b6350) «결석 예정 · 사유»로(무사유 예정=«결석 예정», 무단결석=기존 빨간 «결석» 유지) — _ckReport 한 곳, 카드 헤더 붉은 출결 배지는 공식 상태라 그대로. 검증=3케이스 캡처카드 DOM 실측; v32.586 **하루 폴백** — 일지 날짜에 체크인 없으면 전날 기록 표시(원장 지정 하루까지만), 출결=결석이면 미표시) → 늘 보내던 카톡 성장일지에 그대로 얹힘. ②수업시작+지각기준 지났는데 체크인 없는 학생만 선생님일지›등하원 상단 실시간 패널(`noShowList`/rv `noShow`)+연락 버튼. 스케줄 포맷 `c.schedule[요일번호]="HH:MM"`(sat=6). **학생 셀프 체크인**: 뒷4자리 입력 시 단일매칭이면 자동 «첫=등원/다음=하원»(`_smartType`), «학생 모드 시작»→전체화면 잠금 키오스크(`isKiosk`, 세로 키패드, 형제선택, 성공화면 2s 자동초기화(원장 확정 v32.582), 나가기 PIN `data.kioskPin||'0000'`). **생일 학생**(intake.birth 월·일=오늘(달력 기준, _ckDate 아님), `_isBirthday` — 구분자 있는 모든 형식+붙여쓴 8/6/4자리 인식(v32.653), 상담폼 생년월일 입력은 oIBirth가 YYYY.MM.DD 자동 포맷)은 성공화면 대신 전체화면 축하 오버레이(`kBirthday` sc-if, z-16). ⚠️ **디자인=평소 등하원 성공화면(kHasResult)과 톤앤매너 통일**(v32.623 원장 지시): 크림 그라데이션 bg·나눔명조 세리프 큰 이름(호격 kBirthVoc)·Cormorant 금색 라벨(Happy Birthday)·금색 헤어라인·하단 큰 시각(kResultTimeLabel/T12/AmPm 재사용, `#1E3932`/`#B8934E`/`#00704A`). 성공화면 스타일 바꾸면 생일화면도 같이 맞출 것. 키오스크 화면 전용(학부모 카톡 전송 아님). **다가올 생일(v32.700)**: 홈 생일 카드에 «다가오는 생일» 연한 점선 필(«이름 D-n · 요일», 1~6일 뒤, `_bdayUpcoming` 헬퍼, k순 정렬) — 시각 위계로 오늘/대기(진한 필)와 구분, **라인업엔 미포함**(오늘 것만 원칙). 표시 전용(도장·데이터 무변경). 검증=E2E(D-2·D-5 표시/D-8 제외/오늘·대기 병행)+실렌더. **늦은 생일 가시화(v32.699, 원장 «등원할 때까지 오늘·선생님에게 나타나도록»)**: 늦은 생일 대기자(_bdayLate y≠0 & bdayCele[sid].y≠y)를 ①홈 «오늘 생일» 금색 카드에 «반명 · 지난 생일, 등원 때 축하 대기»로 ②오늘의 라인업 브리핑에 🎂 «{이름} 지난 생일 — 오늘 오면 축하해 주세요»로 표시 — 키오스크 축하(도장) 즉시 자동 소멸, 6일 창 지나도 소멸. 검증=E2E 5지표(대기 표시·라벨·축하완료 제외·당일 병행·라인업). ⚠️ 홈 수업 슬롯 하니스엔 sc.days(요일명 배열)+**sc.start** 둘 다 필수(start 없으면 슬롯 전체 미렌더). **EXAM MODE 최종(v32.709~710, 원장 «레지스터 올려»+«D-값 우측정렬»)**: 배치=좌(아이브로·라벨·안내문)/우(D-값 세리프 22px). 최종 컨테이너(v32.711)=**박스 아님** — A안 헤어라인 행에 바탕만 #FBEFEA(위아래 붉은 헤어라인, 라운드·측면 테두리 없음). : A안 타이포(아이브로·소라벨·세리프 22px D-값·우측 안내)+**연붉은 배경판**(#FBEFEA·rgba(178,58,44,.3) 테두리·radius 11) 결합 — 헤어라인만으론 경보 강도 부족 판정. v32.708의 헤어라인 행은 이 배경판으로 대체. 원래 A안: 캡처카드 스트립=붉은 박스→**헤어라인 행**(TODAY와 형제 문법): EXAM MODE 아이브로+라벨 소문자+**D-값 세리프 22px 명조·타뷸러**+우측 안내문(_examDday에 val 필드 추가, s.ddayLb/ddayVal/ddaySub). 앱 배지 3곳(홈 cl.ddayLb/Val·일간바 bulkDdayLb/Val·반카드 c.ddayLb2/Val2 ×3복제)=필 안에서 라벨 70%/D-값 타뷸러 굵게 분리. ⚠️ 배지 텍스트가 두 span으로 분리 — innerText 연속 문자열 프로브 깨짐(공백 제거 비교로). **장기 카운트다운 확정(v32.707, 원장 «고3 수능 D-100, 온도 배지 불필요»)**: 배지 색 단계화 폐기(빨강 단일 유지), 수동 점화는 거리 무제한(수능 D-100 실측) — 캡처카드 문구만 거리 중립화(«시험 대비 중입니다»/시험 중=«시험 기간입니다 — 끝까지 함께해요», _examDday.sub→s.ddaySub). **대비 시작 점화(v32.706, 원장 «미리 입력·선생님이 켬, 안전망 D-20»)**: 점화 조건=«수동(examDday.on=1, armExamDday) OR D-20 이내 OR 시험 중» — 그 전엔 배지·리포트 조용(캘린더는 항상 표시). 반별 일정 카드: 대비 전=회색 «대비 전 · D-n»+초록 «대비 시작» 버튼(ddayPreTxt/onDdayArm, D-20 이내로 들어오면 자동이라 버튼·회색 사라짐), 점화 후=빨간 배지. **날짜(date) 변경 시 on 자동 해제**(다음 시험 재사용 안전 — 대비 중 날짜 조정하면 재점화 필요, D-20 이내면 자동이라 무영향). 검증=E2E 4단계(D-30 대비전+버튼/D-15 자동/클릭 점화/날짜변경 해제). **시험 기간 지원(v32.705, 원장 «시험은 기간»)**: examDday에 `end`(선택) — 카드 입력 «~ 종료(선택)»(3복제). `_examDday`=종료일까지 유효(td>=start면 during:true·배지 «{라벨} 시험 중», 소멸 기준=end 경과), `_examChips`=기간 내 전 날짜 매칭(주간 헤더 칩이 기간만큼). 월간=v704 단일칩 주입 제거→**spanEvents에 파생 주입**(type '학교시험'=기존 TYPE_COLOR 연어색, 단일일도 date==endDate 막대) + **spanBars 클릭=학생관리 점프**(onTap, 파생 exd_만·수동 이벤트는 no-op; admin→adminSeg student / schedule→stu+board). 검증=3시점 배지(D-5/시험 중/소멸)+월간 막대+클릭 점프 E2E. ⚠️ spanBar 스타일 프로브는 렌더 후 «height: 16px»로 정규화 — 셀렉터는 computed로. **경영 계기판(v32.713, 원장 승인 ⑤⑥)**: 학원일지›한눈에 KPI 아래 카드 2개 — ①«경영 추이 · 최근 12개월»: `_bizSeries`(재원=registeredAt/enrollDate~withdrawnAt 구간 카운트+leftStudents 포함, 신규/퇴원=월 매칭, 완납 매출=stu.fees[ym].status 완납 amount 합) → SVG 폴리라인 2개(재원 딥그린 실선+매출 골드 점선, rv 좌표 문자열 bizT.enPts/revPts)+6개월 표(월/재원/신규/퇴원/완납매출) ②«상담→등록 전환»: `_bizChannels`(intake.channel 집계, joined=!pending) 채널별 상담/등록/전환율 표. ⑥유입경로 입력=상담 폼 등록 동기 위 칩 5종(블로그/네이버/지인 소개/간판·거리/기타, iChannels→setIntake('channel')). rv bizT는 adminData 앞(한눈에 스코프). ⚠️ SVG 안 sc-for <text>(월 라벨)는 미렌더 — 범례·표로 대체돼 있음, svg 내부 sc-for 쓰지 말 것. 검증=시드 수치 표 일치(+2/-1/+1, 60·30·65만)+전환율(100/100/0%)+칩 사전선택·전환 E2E. **시험 캘린더 파생 표시(v32.704, 원장 «달력표시»)**: 시험일이 주간(dayHdr h.exams 칩)·월간(evs에 type '시험' 주입, onEdit no-op) 캘린더에 **파생 렌더** — 복사 등록 아님(저장은 examDday 한 곳, 날짜 수정=즉시 이동·경과=자동 소멸·어긋남 원리적 불가). 헬퍼 `_examNorm`(관대 파싱 단일화, _examDday도 사용)+`_examChips(data,'Y.M.D')`(_schedClasses 가시성 필터=선생님은 자기 반 시험만). 캘린더는 D-14 제한 없이 전체 표시(배지=임박 2주, 캘린더=학기 조망). 검증=주간 헤더+월간 칸 실렌더(붙여쓰기 날짜 입력으로 파서 겸사). **시험 D-day 모드(v32.702, 원장 승인 ③)**: 반별 학교 시험 등록 `data.examDday[classId]={label,date,t}`(키별 LWW merge, 라벨·날짜 다 비우면 {del:1}) — 등록 UI=반별 일정 카드(3복제 전부)에 «학교 시험» 라벨+날짜 입력(oninput 즉시 저장, setExamDday)+빨간 배지. `_examDday(data,cid)`=날짜 관대 파싱(v32.703: 마침표·하이픈·슬래시·붙여쓰기 8자리·한자리 월일 전부 인식, 월1~12·일1~31 검증, 예시 문구=«히즈고 중간»)+D-14 이내·미래만 {label,date,n,badge}. 표시 4곳: ①홈 수업 행(슬롯 dday→**classes 매핑에도 dday 복사 필수** — 매핑이 키를 골라 담아 슬롯만 넣으면 무시됨) ②일간일지 상단바 빨간 배지(⚡ 앞, bulkDday) ③캡처카드 «EXAM MODE {배지} · 시험 대비 집중 주간» 빨간 스트립(TODAY 위) ④반별 일정 카드 배지. 검증=E2E(D-9 표시·D-20 창밖 제외·바+캡처·입력 로드·비움 저장). ⚠️ «반별 일정» 섹션은 학원일지›학생관리에 렌더(선생님일지 일정 탭 아님 — 하니스 검증 시 주의). **신규생 웰컴 여정(v32.701, 원장 승인 ②)**: ①등록 확정 시 웰컴 카드 오버레이(딥그린+금색 «{이름}의 히즈 여정이 시작됩니다»+약속 3줄+SINCE 등록일, 이미지 복사=captureEl) — 확정 경로 2곳 모두 발동: confirmEnrollIntake(종합일지 진단·상담)와 confirmStudentDirect(학원일지 접수 대기 패널) 둘 다 welcomeSid 세팅, **마크업·rv도 두 스코프에 복제**(manage=film 옆 #welcomecap / admin=pendingIntake 옆 #welcomecap2 — id 다르게, 각자 onCopy가 자기 id 캡처) ②첫 등원 키오스크 세리머니: 등원 카운트 _n===1이면 kCere «Welcome · 첫 등원 · 히즈에서의 첫날을 환영해요»(days 세리머니 분기 앞, 생일 우선 유지). 검증=E2E(첫 등원 발동·기존 학생 무발동·패널 확정→카드 렌더+복사 버튼). ⚠️ intake 오버레이의 x-import on-click은 헤드리스 합성 클릭으로 미발화(테스트 한계) — 실사용은 정상 바인딩. **늦은 생일 축하(v32.696, 원장 «생일 당일 결석해도 다음 등원 때»)**: 생일 당일이 아니어도 «생일 후 1~6일 이내 첫 등원»이면 생일 오버레이 발동(`_bdayLate(stu)`가 해당 생일의 연도 반환, 0=대상 아님) + 금색 한 줄 «조금 늦었지만, 마음은 그대로예요 — 생일 축하해»(rv kBdayLateLine, 기존 축하문 아래). 중복 방지=`data.bdayCele[sid]={y:생일연도,t}` 도장(연도 다르면 다시 축하, merge 키별 LWW 기재) — doCheckin 동기부(_lastCkBday·차임 bdayin/bday)와 setState 조립부 **양쪽 모두** 늦은 생일 판정 필요(동기부는 state.data 기준, 조립부는 dd 기준). 티어 승급은 원래부터 «다음 등원» 방식(tierCele label 비교)이라 놓칠 수 없음, 등원 100/200/300도 체크인 시점 카운트라 무관. 검증=E2E 4케이스(3일 전 미축하=늦은줄 O·도장 O / 당일=늦은줄 X / 올해 이미 축하=무발동 / 9일 전=범위 밖 무발동) + 실렌더 2장.
**문구 톤=오은영+김창옥(v32.719, 원장 확정)**: 응원 풀 100개+개인화 템플릿 전면 재작성 — 감정 읽기·존재 인정(«오기 싫은 날도 있지. 그래도 온 너라서 더 대단해»)·«~구나» 화법·부담형(도전/최고기록) 금지·따뜻한 유머 — **새 응원 문구 추가 시 이 톤 준수**(성과 압박 금지, 마음·과정 인정). **응원 문구 증강+학생별 커스텀(v32.718, 원장 «문구 증강·커스터마이징»)**: `_autoMsg(word, seed, pers)` — 풀 확장(등원 40·하원 40·월/금 등원 각 4·금 하원 4·**심야 하원 LATE 4**(21시~새벽5시 prepend)), 선택=기존 해시(이름+날짜) 유지. **개인화**: doCheckin이 표시 직전 `_pers={m:필수,s:가중}` 계산(기록 안 씀, 표시 전용) → checkinResult.p로 rv 2곳(kResultBody/kResultMsg) 전달 — ①m(항상 표시): 등원 누적 96~99/196~199/296~299회 «오늘로 N번째… 코앞» ②s(해시 60% 확률): 누적 50회 단위·단어 자산 30개↑(_waCount)·티어(마일 20↑, tierInfo.label)·최근 7일 시험 만점 과목(gS/stS/rS/hS≥T)·이달 개근(기록 4개↑ 무결석) — 등/하원별 문구 분리. 검증=추출 유닛(변주 25/30·must 100%·soft 57.5%·결정론)+실브라우저 키오스크 E2E(99회 학생=마일스톤 줄, 신규 학생=일반 풀+웰컴 세리머니 병행, 스크린샷). ⚠️ 키오스크 하니스는 launch args `--disable-audio-output` 필수(없으면 AudioContext close 가짜 에러). ⚠️ 성공화면 이름은 호격(성 제외 «보통아») — E2E 텍스트 프로브에 풀네임 쓰지 말 것. **[버그수정] 홈 화면 반 누락(v32.721, 원장 «히즈동지H1_B.T반이 안나와»)**: 홈(오늘) 슬롯만 `sc.days`+`sc.times[요일]`을 **직접** 읽어서 ①구형식 `schedule[요일숫자]='22:30'` ②`c.startTime` 폴백 을 못 봤음 — 같은 반이 일간일지에선 «수업 시작 22:30»으로 정상 인식되어 **화면 간 불일치**로 나타남(진단 열쇠). 수정=홈 슬롯도 `_classStart/_classEnd(c,_w9,today,S.data)` 사용으로 통일 → 전 형식 인식+세션 오버레이 자동 반영. ⚠️ **시간표를 읽는 새 코드는 반드시 `_classStart`/`_classEnd`를 쓸 것**(sc.days 직접 읽기 금지 — 이 버그의 재발원). 검증=4형식 재현 하니스(정상/구형식/startTime폴백/오늘아님 대조군/보강 오버레이). **날짜별 수업 오버레이 엔진(v32.720)**: `data.sessions[cid|date]`={off:1,to} 휴강 / {start,end,from} 보강, `data.mkup[sid|date]`={cid,start,end,from} 학생별 보강 — 둘 다 키별 LWW+tombstone merge. `_sessOv(dd,cid,date)` → `_classStart(c,w,date,dd)`/`_classEnd` 가 오버레이 우선 적용(off=수업없음→결석판정 꺼짐, start=수업생성→보강일 살아남), 소비처 16곳(결석판정·autoAttendance·홈미등원·캡처카드·bulk 3곳·_ckReport·홈rv·ckEdit) 전부 date+data 전달. 액션=moveSession/clearSession/setStudentMakeup/clearStudentMakeup/_mkupOf/_mkupList. **UI 완성(v32.723)**: 진입=홈 수업카드 «이동» 칩(slots.push onMove — ⚠️ slots→homeData.classes 매핑에 onMove 복사 필수, dday 때와 같은 함정 재발했음)+일간일지 상단바 «수업 이동» 버튼(트레이닝 옆, S.activeClassId+S.bulk.date). CLASS MOVE 모달(S.mv, 마크업은 홈·일간 두 스코프 복제): 모드 토글(다른 날로 보강/이번만 휴강)→날짜(`_mvNorm` 관대 파싱: _examNorm+월/일만 입력 시 올해·지난날짜면 내년)→시간(원래 시간 프리필)→타반 충돌 경고(구간 겹침, 비차단)→미리보기→확정(mvConfirm)→완료 화면=학부모 안내문 자동 생성+클립보드 복사. 이동·휴강된 날 다시 열면 상태줄+«원래대로 되돌리기»(mvUndo→clearSession 양쪽 tombstone). **휴강한 반은 홈에서 숨기지 않고 «휴강 · 보강 X로 이동» 슬롯으로 표시**(_off9 — 등원카운트·브리핑·일지쓰기 칩은 생략). 검증=E2E 9단계(이동버튼→모달→충돌경고→해소→확정→sessions 데이터→휴강 표시→일간일지 되돌리기→복원) ALL PASS. ⚠️ E2E 내비 클릭은 `locator('visible=true')` 필터 필수(숨은 dc-tpl 텍스트에 걸림). **오답노트를 성적일지로 이동+시험별 태깅(v32.746, 원장 «①+②»)**: 오답노트(clip)는 학교시험·모의고사 오답이라 성적 탭(=성적일지, examAgg(data,S.activeClassId,S.examStudentId))으로 진입 이동. ①성적 탭 «시험 기록» 헤더에 섹션 «오답노트»(onExamClips=openClips(cid,sid)). ②각 시험 항목(examRows)에 «오답노트»(r.onClips=openClips(cid,sid,r.title))→작업실 clip-exam 입력에 시험명 자동 채움(clipWorkOpen setTimeout에서 _clipPreExam 주입)→그 시험 오답으로 분류. ⚠️ **클립 드로어는 manage(종합일지) 뷰 전용** — openClips에 view:manage+profileStudentId+profileReturnView 추가해 어느 진입이든 종합일지로 이동해 열고 닫으면 복귀. (어휘·구문 오답은 여전히 트레이닝 wrongBank 재출제로 분리 — 이미지 vs 텍스트). 검증=E2E(성적탭 섹션+시험별 버튼 2개, 시험별→시험명 «9월 모평» 자동태깅). **저장 상태 표시(v32.745, 원장 «①»)**: 헤더 우측(검색·시계 사이) «● 저장됨 · 방금 / 저장 중… / 오프라인 · 저장됨» pill. persist()에 로컬저장 완료 마커(this._saveState='saved',_saveAt), _persistSoon()에 'saving', componentDidMount 폴러(setInterval 1.2s: navigator.onLine 오프라인 감지+ago 계산, this.state._syncText 변할 때만 setState=저churn). rv syncText/Color/Dot 패스스루. ⚠️ 클라우드 IIFE(Supabase upsert, __cloud_at) 무손상 — 로컬 저장은 동기·확실이라 «저장됨»은 정직(클라우드는 뒤따름). 검증=E2E(초기 저장됨→편집→방금→오프라인·저장됨→복귀). **남은 검수 대기**: ②실행취소 토스트 ④하루 마감 체크리스트 ⌘K. **일간일지 회차 결정론화(v32.744, 원장 «매번 달라짐»)**: 근본원인=`autoSession`이 «그 반 전체 기록 중 최대 회차+1»(날짜 무관·최댓값이 움직여 흔들림·과거날짜도 미래번호·기기 두 대 동시 열면 같은 번호 충돌·빈 회차 저장 시 꼬임). 교체=`_sessionForDate(data,classId,date)`=그 반 records의 distinct 날짜 정렬 후 이 날짜의 순번(신규 날짜면 삽입). 같은 날짜=항상 같은 회차(결정론), 새 날짜=마지막+1, 과거 끼움=제자리, 기록없는 반=1. **저장된 회차 존중**(session: draft.session || savedSession || _sessionForDate — savedSession 우선이라 역사 안 바꿈). 적용=openBulk 2곳 fallback + 반선택 초기 newSess. ⚠️ autoSession은 남겨둠(다른 참조 없으면 무해). 검증=추출 유닛(레거시 12/5/공백 회차 무시하고 1·2·3·4·과거2·타반1·결정론)+실화면(기록 7/01뿐일 때 오늘=회차2, 예전이면 13). **빈 화면·토스트 말투 통일(v32.742, 원장 «①»)**: 내부 UI 정중체→브랜드 톤 — 없습니다→없어요(학생·기록·원생·선생님 20곳)+찾을 수 없습니다→찾을 수 없어요(not-found 토스트 11)+«누적하세요→쌓아가요». ⚠️ **유지(바꾸지 말 것)**: 학부모용(부탁드립니다·진행됩니다·말씀드립니다), 파괴적 경고(되돌릴 수 없습니다=전체 초기화). 검수 결과 이 앱은 빈화면 아래 폼/버튼이 이미 인라인이라(좋은 설계) «다음행동 버튼» 대신 톤이 실제 빈틈이었음. 남은 검수 대기: ②실행취소 토스트 ④하루 마감 체크리스트 ⑥동기화 상태 ⌘K 단축키. **전역 학생 검색/스포트라이트(v32.742→실제 v32.741, 원장 «③»)**: 상단 헤더(flex 스페이서 뒤·시계 앞)에 돋보기 버튼→풀스크린 오버레이(fixed z-9500). openGlobalSearch(setTimeout 60ms로 #gs-input 포커스)/closeGlobalSearch/setGlobalSearch/gsJump(=searchProfile 재사용). rv(top-level): gsResults(visibleClasses 담임 스코프—선생님 자기 반만, 이름·학교 부분일치, 퇴원생 뒤로 정렬 slice 30), gsCount/gsNone(결과0)/gsIdle(입력전)/gsTyping. 마크업=이니셜 아바타(name.slice(-2))+이름+«반·학교·담임» 메타, 탭→gsJump. ⚠️ 상태 init 불필요(setState가 동적 추가, rv가 undefined falsy 처리). 검증=E2E 5(안내/필터/점프/결과없음/담임스코프 누출없음). **미완 검수 제안(대기)**: ①말투 통일(없습니다38 vs 없어요14) ④하루 마감 체크리스트 ②실행취소 토스트 ⑥동기화 상태 표시. **일간일지 «수업 보강»=홈 «+ 보강 예약» 통일(v32.740, 원장 지시)**: onMvOpenDaily를 openMove(activeClass, bulkDate)→`openMovePickClass()`로 변경 — 일간일지 버튼도 반 선택→다가오는 수업→이동(어느 반이든·미래). ⚠️ 이 변경으로 «수업 보강»이 특정 날짜 세션을 직접 열지 않으므로, 휴강 세션 되돌리기는 보강 대상일(overlay start라 _upcomingSessions에 나타남) 선택 또는 캘린더 칩(cal_e2e) 경유. mv_e2e 되돌리기 스텝을 «반선택→보강대상일 tmr» 경유로 갱신. **미래 보강 예약 확장(v32.738 홈 any-class / v32.739 학생)**: ①홈 «오늘 내 수업» 헤더에 «+ 보강 예약» 버튼(openMovePickClass→step pickClass→visibleClasses 목록→_mvPickClass→pickFrom)—오늘 수업 없는 반도 미리 예약. ⚠️mvClassList는 top-level rv라 homeData의 user 대신 S.currentUser, 버튼 바인딩은 {{ onMovePickClass }}(homeData. 접두 금지—크래시). ②결석 관리 «사전 등록된 결석 예정» 각 항목에 «보강 예약/보강 확인» 버튼(_pre에 _cmap[sid]→cid, onMakeup=openStuMakeup(미래 결석일))—미래 결석 사전 등록 후 그 자리에서 학생 보강 예약. 검증=오늘없는반 예약 E2E+학생 미래보강 E2E+회귀 3종. ⚠️mv/mk 모달 마크업 스코프=각 5/4곳, 회귀 테스트의 «보강» 셀렉터는 exact=True 필요(«+ 보강 예약»과 충돌). **미래 보강 예약(v32.737, 원장 «A안»)**: 홈 수업카드 «보강»을 openMove(today)→`openMoveSchedule(cid)`로 변경 — CLASS MOVE 모달이 `step:pickFrom`으로 열려 그 반의 **다가오는 수업 6~8개를 칩**으로 제시(`_upcomingSessions`: today부터 42일 스캔, `_classStart`가 빈값이면(=휴강/비수업일) 제외, 오늘 배지). 칩 탭=`_mvPickFrom(date)`가 from 설정+원래 시간 자동 채움+step 해제→기존 이동 단계로. 당일이 아니어도 미래 수업을 미리 휴강/보강 예약 가능. ⚠️ mvHasOv/mvPick rv에 `step!=='pickFrom'` 게이트 필수(안 하면 수업 선택과 모드 선택이 동시 노출), mvTitle은 from 빈값 대응. 모달 마크업 5스코프 일괄. 검증=미래 수업(다음주) 선택→저장 E2E + 기존 9단계 회귀(«보강»→«오늘» 선택 경유). **남은 일**: 학생별 보강도 «다가오는 결석 예정일» 예약(현재 결석 관리 당일 기준). **학생별 보강 UI(v32.724)**: 진입=결석 관리 화면(등하원 탭) 결석·결석예정 학생 칩 — isExc일 때만 «보강 잡기»(이미 있으면 «보강 확인»+파랑 배지 «보강 M월 D일 시각») 노출. STUDENT MAKEUP 모달(S.mk, 인디고 #303f9f — CLASS MOVE 딥그린과 구분, 마크업=closedAdmin 카드 앞 그 화면 스코프): 날짜 입력 시 `_mkSet`이 그 반이 그날 수업 있으면 시간 자동 채움 → 확정=setStudentMakeup(from=결석일) → 안내문 생성+복사. «보강 확인»→현황줄+«보강 취소»(잡힌 보강의 실제 날짜 키를 _mkupFor로 찾아 tombstone). **홈 «오늘 보강» 섹션**: homeData.makeups=_mkupList(오늘) — 시간·이름·반·«M월 D일 결석 보강» 배지, 탭=모달 재열기. 헬퍼 `_mkupFor(dd,sid,fromDate)`=결석일 기준 역조회. 검증=E2E 6단계 ALL PASS. ⚠️ E2E 클릭은 하니스 에러배너가 가로채므로 JS 직접 click(clickTxt 패턴) 사용. **자동 이탈 위험 신호(v32.734, 원장 «A 가자»)**: `_churnRisk(data)` — 학생별 4신호 조합(재원 14일 미만 제외): ①결석 잦음=28일 결석≥3 또는 (4회+ 중 30%+) ②과제 미완 반복=14일 미완≥3 ③점수 하락=직전 시험 대비 delta≤-12 ④4주+ 미상담=마지막 상담 cDays≥28. **신호 2개 이상만 노출**(오탐 최소화), 2개=주의(노랑)·3개+=위험(빨강), 신호 수 desc 정렬. 재료는 기존 rows0/_absMap과 동일 소스(records 28d/14d 윈도우·exams·counsels)라 새 입력 0. rv `homeChurn`(user==='관리자'만), 원장 홈 «이탈 위험 N명» 카드(보고·건의함 앞)=학생별 신호칩+탭→학생관리 점프. ⚠️ 기존 «관리 필요»(단일 bool 카운트)와 별개 — 이건 신호를 분해·명명해 «왜»를 보여주는 조기경보. 검증=E2E(위험3신호/주의2신호/1신호 정상 제외/신규 제외/정렬/신호칩 텍스트). **임계값은 튜닝 가능**(원장 요청 시 조정). **B안 담임 스코프(v32.735, 원장 «B안»)**: 선생님도 이탈 신호를 보되 **자기 반만** — `_churnRisk(data, user)`가 담임(user!=='관리자')이면 owner 반으로 필터(다른 반 학생 절대 노출 안 됨, visibleClasses와 동일 원칙). homeChurn 관리자 게이트 제거→전원 계산, 제목 분기(원장=«이탈 위험»/선생님=«우리 반 · 챙길 학생»), 카드 마크업 isAdmin 래퍼 제거. ⚠️ 마크업 편집 시 `</span>`는 비이스케이프·`<\/div>`/`<\/sc-if>`는 이스케이프(혼재) — Edit 도구로 실바이트 확인 후 처리. 검증=스코프 E2E(관리자 2반 전체 / 담임 자기 반 1명·타반 미노출 확인). **공지·답글 읽음 확인+선생님 알림(v32.733, 원장 «답글·공지 알람+읽음 확인»)**: 통합 `data.msgReads[msgId+"|"+reader]={t}` 키별 LWW merge. msgId: 공지=notice 키(`all|uid`/`teacher|uid`), 답글=`rr:`+reportId. 리더 분리=lastIndexOf("|")(공지 키에 |가 있어도 안전). `markMsgRead(mid)`(중복 무시·persist), `_msgReaders(mid)`, `_msgReadAt`. **선생님(알림)**: myNotices 미확인=골드 카드(cardStyle)+헤더 «새 소식 N»(myUnread)+«확인했어요»(onRead→markMsgRead(k)); 답글 미확인=NEW 배지+확인 버튼(onReplyRead→markMsgRead(rr:id)). **원장(읽음)**: sentNotices에 «N/전체 읽음»(all=_msgReaders 수/owners.length, 개별=읽음/안 읽음), homeReports 답변 옆 «읽음/안 읽음»(replyReadFlag=작성자 r.by가 rr:id 읽었나). ⚠️ 원장(관리자)은 자기 공지 미확인 제외(user!=='관리자' 가드). 검증=다중 사용자 E2E(선생님 확인→msgReads 저장→원장 1/2 읽음). **남은 일**: 알림톡/푸시 실발송(원장 승인 시), 개별 학부모 공지 읽음(현재 선생님 대상만). **«아이 이야기» 리네임+온보딩(v32.730, 원장 A안 채택)**: 기능명 «작은 기록»→**«아이 이야기»**(목적 직결 — 성적 아닌 아이 자체 기억). 문구 통일: 일간카드 라벨/안내문(«수업 중 알게 된 아이 얘기 한 줄 — 다음 시간 대화가 되고, 상담 때 참고돼요»)/칩(«지난 기억:»), 종합일지 섹션, 상담 헤더 3스코프. (v32.731 원장 지시로 첫 방문 힌트 배너 제거 — snHintShow/dismissSnHint/snHintSeen/his-sn-hint 전부 삭제, 안내문 placeholder만으로 목적 전달). ⚠️ 새 응원/온보딩 문구는 [[project-mirror-reading]] 취지대로 최소·이득직결. 검증=E2E 4단계. **작은 기록 저장·열람 지도(v32.729)**: 저장처=본체 `data.smallNotes[uid]={sid,text,by,at,t}` 키별 LWW(클라우드 동기화, 영구). 열람처 3곳=①홈 수업카드 브리핑(📎 최근) ②종합일지 섹션(전체·삭제) ③**상담·진단 화면(v32.729 신설)** — «{학생} 상담 기록» 헤더 아래·진단 요약 위에 최신 20건(cslNotes rv, 내용+날짜·작성자), 상담 시 참고자료. 마크업 3스코프(counselOpen sc-if 내부). **작은 기록 입구 이사(v32.728, 원장 «위치가 숨겨져 있어»)**: 입력 위치=일간일지 학생 카드 «선생님 코멘트» 바로 아래 상시 한 줄(💛 작은 기록 · 최근 1개 표시 · 입력 · 기록 버튼). 학생별 드래프트 `S.snd[sid]`+`addSmallNoteDaily(sid)`(기존 addSmallNote는 종합일지 sn-input 고정 id라 카드 다중에 부적합). 종합일지 섹션은 아카이브(목록·삭제) 용도 유지, 저장 구조(smallNotes 키별 LWW)·홈 브리핑 📎 흐름 불변. ⚠️ **일간일지 카드의 rv는 bulk rows(`.map((stu)` — setBulk 경로, 2.62M 부근)** — recordFor 기반 rows rv(2.44M 부근)가 아님. 카드에 키 추가 시 반드시 onSuggest/onComment가 있는 rv에 넣을 것(잘못 넣으면 바인딩 자체가 안 붙어 input 값이 즉시 리셋됨 — 실제로 밟은 함정). **결석 사유 단일 표기(v32.726)**: TODAY 스트립에서 사유는 타임라인 문구(«{사유} — 미리 연락 주신 결석이에요») 한 곳만 — 우측 출결 배지(attLabel)는 순수 상태(«결석»/«결석 예정»)만. 사유를 배지에 다시 붙이지 말 것. **캘린더 파생 표시(v32.725)**: 월간 캘린더 dayMap에 파생 주입(원본 복사 금지, examDday 선례) — sessions off=«{반} 휴강»(type '휴강'→TYPE_COLOR 폴백 회색) / start=«{반} 보강»(type '보강' 골드 #D9B65C, time 표시) / mkup=«{호격} 보강»(골드), _schedClasses 가시성 필터. **칩 클릭 경로**: 칩은 onclick=schedMonthCal.onChipClick 위임(data-evid)+evIdMap — evs 매핑 onEdit이 아님! onChipClick에 ssn_(→openMove)/mkp_(→openStuMakeup) 분기, ⚠️ evIdMap은 **매핑된 evs**를 저장하므로 파생 필드(_sid/_cid/_from/_nm)를 evs 매핑에 복사해야 모달에 전달됨(누락 시 «학생·오늘»로 열리는 버그 — 실제로 밟았음). 모달 마크업은 schedMonthCal.dayNames sc-for 앞 3스코프에 mv+mk 복제(기존 마크업 추출 재사용 패턴). 검증=E2E(칩 3종 렌더+휴강 칩→CLASS MOVE 되돌리기 화면+규호 보강 칩→STUDENT MAKEUP 현황 화면). **남은 일**: 보강일 키오스크 등원 시 보강 배지(선택), 알림톡 연동 발송(원장 승인 시), 파생 칩 상세 시트(editViewOpen)의 수정·삭제 버튼은 파생에 노출 안 됨(onChipClick에서 선분기)이나 시트 경유 진입은 없는지 재확인 여지. **키오스크 «순간» 세리머니(v32.667, 원장 승인 혁신3번)**: 등원 체크인 때 ①티어 승급(studentMileage→tierInfo 라벨 변화+마일 증가 시 — `data.tierCele[sid]={label,mile,ts}` baseline 방식: 첫 인식은 조용히 기록만(도입 시 전원 폭죽 방지), 이후 승급만 세리머니, merge=키별 LWW(ts) 격리검증) ②등원 100·200·300번째(checkins 전수 카운트, 그날 첫 등원만) — 생일과 동톤 전체화면(kCere sc-if, Cormorant 금색 아이브로 Tier Up/Milestone+엠블럼 imgSrc+나눔명조 호격+하단 시각, hb키프레임 재사용, 3.5s=_lastCkCere). 생일이 우선(bday면 세리머니 스킵), 사운드는 기존 in 차임 그대로(엔진 불가침). ⚠️ **템플릿 img src에 {{ }} 보간 금지(v32.671 사고)**: 하이드레이션 전 브라우저가 «{{ kCereEmblem }}»을 문자 그대로 GET → 404 → 라이브 [bundle] 진단배너(부팅마다 2줄). 동적 이미지는 반드시 기존 `data-tierbg=«{{ }}»`+applyTierBg(didUpdate) 패턴으로(v671에서 세리머니·필름 엠블럼 교체, div+background-size:contain). 검증법=repo를 localhost http.server로 띄워 부팅 4xx·배너 0 확인(file:// 하니스는 물고기png 상대경로 404가 배너를 오염시켜 판정 불가). 같이 정리(v671): EB Garamond 죽은 폰트 src 84개(라틴 등 14개 uuid가 번들 매니페스트에 없음 — 옛 폰트 다이어트 잔재)를 local(«EB Garamond»)로 교체(라이브 폰트 404 소멸, 워드마크는 원래 폴백 렌더라 화면 변화 0). ⚠️ hb 애니메이션은 transform을 덮어씀 — 오버레이 중앙정렬은 translateX(-50%) 금지, «left:0;right:0;text-align:center»로(v667에서 우측 밀림 사고). ⚠️ 키오스크 하니스로 새벽 검증 시 어제(d(1)) 체크인 시드 금지 — _ckDate 논리날짜라 smartType이 하원으로 감. **무빙 연출**(v32.624 원장 지시 «화려하고 다이내믹 고급»): 단계별 등장(hbRise/hbName/hbLine)+금색 Happy Birthday 반짝임 스윕(hbShine 루프)+떠오르는 금색 파티클6(hbFloat)+등장 링2겹(hbRing). ⚠️ 키프레임 7종은 **페이로드 head의 `<style>`**에 주입(하이드레이션 규칙, hb 접두사). **재생시간=생일만 3.5초**(일반 2초): `doCheckin`이 학생 생일여부를 `this._lastCkBday`에 **동기 기록**(setState 전, getClass로 조회) → `_kioskResetSoon`이 `self._lastCkBday?3500:2000`. 가상시간 헤드리스는 무한애니로 하단 시각 프레임을 못 잡으니 실브라우저(localhost)로 검증할 것. **생일 전용 차임**(v32.625 원장 지시 «애플풍 고급»): `_tick`의 `bday` 분기 = «해피 버스데이 투 유» 끝소절(F5 F5 E5 C5 D5 C5) 오르골/글라스벨 음색(sine 1·2·3·4.2 하모닉+기음 ±3c 디튠+저음 C4)+lowpass 4700. ⚠️ **사운드 엔진 근본설계(v32.640 최종, 원장 «몇번째 반복이냐 근본원인 제거해»)**: 그동안 모든 사운드 버그의 뿌리 = «노드를 언제 disconnect할지»를 매번 다른 불안한 방법으로 추측(리버브 방치/에코 방치/타이머 경합/GC 의존/상시 keepalive)→구형 TV DSP서 축적·과부하(«처음 괜찮다 시간지나면 딜레이»). **해결=모든 노드가 자기 재생 끝나는 순간 `onended`로 스스로 disconnect**(추측 제거, 축적 물리적 불가). `osc()`=o.onended서 o+g끊고 그룹카운트--, `melody`의 체인 lowpass=마지막 voice 끝나면(grp.n=0) disconnect, `noiseHit`=ns.onended서 ns+bp+ng 끊음. ①**ConvolverNode·IR·DelayNode·상시 keepalive 전부 금지**(전부 축적원). ②**타이머/GC로 정리 금지** — 오직 onended. ③유휴 후 첫키 무음은 keepalive 아니라 **resume-then-play**(v638: suspended면 `ac.resume().then()`으로 깨운 뒤 `ac.currentTime` 다시 읽어 미래 예약)로 해결. ④**자가복구**(v639): suspended 연속2회면 컨텍스트 close후 `new AudioContext()` 재생성. `_tick`=오케스트레이터(resume/자가복구/진단), `_tickPlay`=합성(onended 자기철거). **⑤지연증가 자가치유(v32.662)**: 축적·suspend·wedge 다 막아도 남던 «running인데 TV 출력버퍼가 늘어져 시간 지나면 딜레이» 경로 차단 — `_tick`이 키마다 `ac.outputLatency` 계측, 첫 정상값을 기준 `_acL0`(캡 0.25s)로 «L>0.5s 절대상한 OR 기준×2.5(최소 0.35s)»를 **2회 연속** 넘으면(`_acLagN`) 제스처 중 컨텍스트 close→`new AC()` 재생성(+`_acHealN`, 진단 R{n} 공유, 1회 튐=오탐 무시, 부팅부터 늘어진 기기도 절대상한이 잡음). 게이트 G7로 자동검증(인스턴스 `outputLatency` defineProperty 가짜주입→조기발동X·2회째 재생성O 확인). **검증법(필수 2종)**: (a)`_tickPlay(k,off)` 직접 OfflineAudioContext 렌더로 7종 진폭 계측(scratchpad tick_render_test.html — `_tick`은 비동기라 오프라인 부적합), (b)**축적=0 증명**: 실 AudioContext에 `_tickPlay` 150회 연속 호출+connect/disconnect 계측→4초 후 destination 잔존노드 0개 확인(accum_test.html). ⚠️ **잔존=0 계측 시 2가지 필수**(2026-07-18 «가짜 누수 8개» 소동 교훈 — 엔진은 8종×10회 격리+혼합 100회 모두 잔존 0으로 무죄 재확인됨): ①샌드박스 셸에서 띄운 크롬은 헤드리스·헤드풀 불문 오디오 장치 접근이 막혀 AudioContext가 state=running인데 **시계 동결**(resume 무한대기·onended 미발화) → playwright launch에 `--disable-audio-output`(+`--autoplay-policy=no-user-gesture-required`) 플래그로 가짜 출력 싱크 구동 필수. ②잔존 판정 대기는 **벽시계 고정 N초 금지** — 오디오 시계가 «마지막 예약시각+최장 여운(bday 저음 3.49s)+0.1s여유»를 지날 때까지 `ac.currentTime` 폴링으로 기다린 뒤 계측(벽시계 4s 고정 대기는 시계가 느린 기기에서 아직 정당하게 재생 중인 bday 여운 노드들을 누수로 오판). **⑮키패드 무음화(v32.717, 원장 «완벽한 엔지니어링 진행» 확정)**: `_tickPlay` 첫 줄 가드 `if(!(k==='ok'||'in'||'out'||'bday'||'bdayin')) return;` — 숫자·del·clear·오입력 블립 전부 합성 스킵(무음), **`_tick` 오케스트레이터는 불가침**(숫자키가 유휴 리셋 I·resume·힐·진단의 웨이크업 콜 역할이라 — 로그상 I는 항상 첫 숫자키에서 발동, 4자리 누르는 동안 엔진이 정비된 뒤 차임이 울리는 구조 유지). 차임·세리머니(ok/in/out/bday/bdayin)는 앞 4키가 깨워둔 엔진 위에서 기존 경로 그대로. 진단 블랙박스도 무음 키에 계속 줄 기록(L 계측 유지). 검증=오프라인 렌더 9종(무음 4종 진폭 0 / 소리 5종 정상·firstMs 6)+localhost 부팅 스모크(에러·4xx·배너 0). 버전 도장 V698→**V717**(다음 로그 판정 기준). 근거=168ms는 webOS 바닥이라 «키를 누르면 늦게 따라오는 소리»가 어색함의 정체 — 확인 피드백은 pointerdown 즉시 화면(점 채움)이 담당, 차임은 성공 화면 연출에 묶여 지연 비지각. **⑭최종 종결(v32.714, 실기기 로그 6차 — V698·R 실측 완비)**: 힐 정상 발동 확인됐으나 **R 직후 L=224→200→160…(스파이크 후 136 복귀), L88은 생성 직후 신기루** — «빠른 엔진 뽑기» 가설 실측 기각. ~130ms=webOS 파이프라인 바닥 «확정»(PC D3vs는 b10). 조치=중간대역 재생성 룰렛 은퇴(문턱=절대 0.5s만, 이득 없는 224ms 스파이크 제거) — 웨지 T힐·유휴 I리셋·resume 타임아웃은 유지. 게이트=L168×4 무힐+0.6s 힐 검증. **이 딜레이의 유일한 남은 레버=TV 음향 설정(음향모드 표준·AI사운드 OFF·내장 스피커)** — 이후 이 건으로 코드 수정 금지. **⑬버전 도장(v32.698, 실기기 로그 5차 — R 여전히 0건)**: v697 배포 후 로그도 R 0건 → **원인은 코드 아니라 «기기가 새 버전 미수신»**(키오스크 자동 새로고침=새벽3~7시 or 48h, 로그는 옛 코드가 생성). 진단 줄에 버전 부재로 «몇 번 버전이 이 로그를 만들었나» 판별 불가가 반복의 뿌리 → 유휴리셋(I) 줄에 `V698` 토큰 추가(세션 시작마다 실행 중 버전 노출, 오디오 엔진 불가침). ⚠️ 다음 로그 판정법: **I 줄에 V698 있어야 v697 힐 코드 존재** — 있는데도 L168+R없음이면 그때 비로소 코드 재검토, V698 없으면 기기 미갱신(잠금화면 버전 확인·?hisreset=1). 재현 게이트=lbest0.168+L168 → R1 발동+I줄 V698 확인. 향후 이 토큰은 릴리스마다 수동 bump(V698→…).
**⑫자기무력화 결함 수정(v32.697, 실기기 로그 4차 — R 표시 0건이 증거)**: v692의 «lbest×2» 문턱은 **lbest가 높게 굳으면 문턱도 같이 올라가 영원히 발동 못 하는 자기무력화 구조**였음(lbest는 v692 적용 이후 관측치만 담는데 이 기기는 L136~168만 봐서 문턱 272~336ms → L168도 미달 → 로그에 R 0건, 하루치 전 구간 침묵). 수정=**절대 상한 도입 `TH=min(0.12, max(0.09, lbest*2))`** — lbest가 아무리 커도 L>120ms면 힐 시도, lbest 낮으면(40ms) 기존 90ms 유지. +**헛돌이 백오프**: 힐 직전 L을 `_acHealPrevL`에 저장→다음 측정에서 20% 이상 안 낮아지면 `_acLagFail`++, 3회 연속 실패 시 쿨다운 5분→30분(개선되면 리셋). 검증=실기기 재현 게이트(lbest 0.168 주입+L168 → 2키째 R1 발동·쿨다운 유지·L40 개선 시 무발동·lbest 갱신). ⚠️ 로그 판독 요령: **R 직후 줄의 L값이 «뽑기» 성패** — R 후 L 하락=재생성 전략 유효, R 후에도 동일=webOS 바닥(TV 음향설정만 남음).
**⑪최저기록 기준선(v32.692, 실기기 로그 3차 — 20:29 유휴리셋 직후 L40×2 실측!)**: TV 싱크가 40ms까지 가능함이 증명됨(평소 136~168) → 지연 자가치유 기준선을 «컨텍스트 생성 시 L»(_acL0, 높게 태어나면 평생 방치)에서 «기기 역대 최저 L»(localStorage __his_lbest, 영구)로 교체 — 40을 본 기기는 문턱 90ms가 되어 136짜리 엔진을 5분당 1회 재생성 시도(빠른 엔진 뽑기), 40을 못 본 기기는 문턱 안 낮아져 공회전 0. 검증=G7 게이트(40 기준→136×2 힐·쿨다운). **⑩최종 판정(2026-07-18 밤, 실기기 로그 2차)**: latencyHint:0 적용 후에도 D7qr L112~176·b43(그래프 버퍼 43ms 양자화), I 리셋 무효과, 전부 r — **딜레이 ~0.13s = webOS 오디오 파이프라인 하드웨어 바닥 확정(브라우저 무죄, 웹코드로 불가)**. 남은 레버=TV 설정(음향모드 «표준»·AI사운드 OFF·부가효과 OFF·내장 스피커) — 원장 안내 완료, 효과는 블랙박스 L값으로 판정(40~60대=성공). ⚠️ 이후 이 건으로 코드 패치 금지(추측 수리 회귀) — 로그의 L·b 판독부터. **⑨중간 비대 자가치유(v32.685, 원장 «처음 괜찮다 시간 지나면»)**: v662 문턱(절대 0.5s·바닥 0.35s)이 40→136ms 같은 «귀에 들리지만 350ms 미만» 비대를 영원히 방치하던 사각지대 → 바닥 0.09s·기준×2·**5분 쿨다운**(_acLagHealT, 재생성해도 안 낮아지는 기기서 힐 루프 방지)+블랙박스 동기화 120줄(하루 궤적). 가짜 outputLatency 주입 E2E(40→136×2=R1 힐·쿨다운 유지). 내일 로그 판정법: 아침 L 낮고 저녁 L 높은데 R 힐 후 L 하락=완치 / R 후에도 L 그대로=webOS HAL 소관→TV 음향설정(표준·AI사운드 OFF)이 최종 수단. **⑧실기기 진단 확정+최소지연 힌트(v32.684, 첫 블랙박스 데이터)**: 원장 붙여넣은 D7qr 로그 판독 — 전부 r(웨지·축적·재생성 0)+상시 L136 = 딜레이의 정체는 **webOS 출력 파이프라인 상수 지연 136ms**(엔진 무죄 실측 증명, I 유휴리셋 정상 작동). 대응=AC 생성 5곳 전부 `_newAC(AC)`(latencyHint:0 요청, 실패 폴백) — ⚠️ 생성 지점은 _tick 4곳+**keepalive 첫 터치 프리웜(new AC2) 1곳**(여길 빼먹으면 힌트 무효 — 프리웜이 먼저 만듦). 진단 라인에 b=baseLatency(그래프측) 추가 — 다음 로그에서 L136 하락 여부로 힌트 효과 판정, 불변이면 하드웨어 바닥=TV 음향 설정(음향모드 표준·AI사운드 OFF·블루투스 해제) 안내가 최종 수단. **⑦유휴 90s 무조건 재생성(v32.680, 원장 «항상 딜레이»)**: webOS가 outputLatency=0을 주면 v662 지연감지가 영영 발동 못 하는 사각지대 → 측정 무관하게 «유휴 90초 후 첫 키=엔진 close→new AC»(제스처 안 생성=즉시 running, 진단표식 I) — TV 출력버퍼 비대가 세션 단위로 리셋됨. 상시 딜레이가 이걸로도 남으면=TV 하드웨어 파이프라인(사운드모드 DSP/블루투스) 소관, 블랙박스 L값 부재 여부로 판별. **⑥무음 키 원천 제거+블랙박스(v32.679, 원장 «10번째 재발»)**: (a)resume 250ms 타임아웃 레이스 — suspended에서 resume이 250ms 내 안 풀리면(webOS wedge) 그 자리에서 close→new AC→같은 키 즉시 재생(예전엔 그 키 무음+다음 키 복구였음, 진단코드 T). (b)비행기록계 `_adiag`: 키마다 «시각 키 상태 w깨움ms L지연ms R복구수 g간격» 라인을 localStorage __his_adiag(300줄 링)+3분 스로틀(경고=즉시)로 data.audioDiag[기기id]={ev:최근60,t} 클라우드 동기화(기기별 LWW merge 기재) → 학원일지›데이터 «키오스크 소리 진단» 카드(기기별 로그+«진단 기록 복사»). **재발 시 프로토콜: 원장이 PC 데이터탭에서 복사→Claude에게 붙여넣기 = 실기기 데이터로 진단**(추측 수리 금지). 검증=가짜 suspended AC 주입 E2E(T힐·같은 키 발음·기록·동기화·카드·복사 전부 통과). 화면진단 `#kio-adbg`(좌하단): 키 누르면 «r5L20>»=running/5번/지연20ms(L값 커지면 축적, s=suspended문제, R{n}=자가복구발동). 새 소리 추가 시 반드시 onended 자기철거로. ③**suspended면 `ac.resume().then(재생)`으로 깨운 뒤 `ac.currentTime` 다시 읽어 미래 시각에 예약**(v32.638 근본수정 — 유휴 TV는 suspend로 시계 동결, resume 안 기다리고 동결된 과거시각에 예약하면 느린 TV가 깨어난 뒤 webOS가 그 소리를 버려 완전 무음. PC크롬은 resume 즉시라 재현 안 돼 그동안 못 잡음). `_tick`=오케스트레이터(resume/진단), `_tickPlay`=합성. running이면 즉시 재생. ④**자가복구**(v32.639): suspended가 연속 2회면(=resume이 영영 안 먹는 webOS wedge) 그 AudioContext를 close하고 `new AudioContext()`로 재생성(제스처 중 생성이라 running)+`_acKeep=null`로 keepalive 재무장+`_acHealN` 카운트(진단 R{n}). ⚠️ **실 스탠바이미 검증 불가가 근본 제약** — «100% 장담» 금지, «자가복구+화면진단(#kio-adbg)»으로 대응. 재발 시 원장이 진단표시 읽어주면 실기기 상태 파악. ④**keepalive는 극미세 노이즈(진폭 0.0015, -56dB)**(v32.635) — 디지털 완전무음이면 TV DSP가 오디오 경로를 재워 유휴 후 첫 키가 늦음. ⑤키패드 즉시반응 위임 리스너는 **pointerdown**(v32.635, touchstart에서 교체 — 기기가 터치를 포인터로 보내도 누르는 순간 발화, _tsG 클릭가드 그대로). 새 소리 추가 시 이 원칙들 준수. `doCheckin`이 생일이면 **등원=`bdayin`(첫소절 G4 G4 A4 G4 C5 B4, 저음 루트 G3)·하원=`bday`(마지막소절)**로 구분(v32.626 원장 지시). **일반 학생도 등/하원 구분**(v32.628 원장 확정): 등원=`in`(도→솔 상승 글라스벨)·하원=`out`(솔→도 하강, 여운 김), 리버브 1.1s IR `self._ckIR` 캐시(wet .20/.22). **키패드 숫자·enter = «벨벳 마스터+멜로디 입력»**(v32.644 원장 확정 «비기»): 벨벳 탭(590→470 스윕·저음 받침 295·상음 1180·펠트 노이즈 1500, lowpass 3400 grp, 타건마다 ±1.2% 랜덤=악기 질감) + **자리수(checkinDigits.length 0~3)에 따라 ×[1,1.122,1.26,1.498] 도레미솔 상승**(4자리=낮은 멜로디, 차임이 화답; 지우면 상태 기반이라 자동 도부터). osc()에 atk 파라미터 있음(기본 0.014). clear/del 저음 블립 유지, `ok` 분기=학생모드 시작음으로 존치. **v32.645 즉답화**(원장 «딜레이·둔탁»): `_tickPlay` 예약 여유 30ms→**6ms**(v638의 30ms가 전 소리 일괄 지연시켰음 — resume-then-play 구조라 6ms 안전), 벨벳에 어택 트랜지언트(2800Hz 노이즈 8ms)+lowpass 3900로 TV 스피커 먹먹함 해소. ⚠️ 예약 여유를 다시 키우지 말 것(딜레이 체감), 발음시점 검증=오프라인 렌더 firstMs(6~7ms 정상). ES5(스탠바이미 Chrome108). ⚠️ WebAudio 합성 전용 규칙 그대로(소리파일 X). 검증=`_tick(k){...}` 추출→독립 html `new T()`+`_tick('bday')` 무예외+AC running(헤드리스는 소리 안 나므로 실브라우저 javascript_tool로). **키패드 터치 즉시반응**(v32.627, 원장 «스탠바이미 인식 느림»): 키패드 버튼 `data-kk` + componentDidMount의 document 위임 `touchstart`(passive)가 손끝 닿는 순간 `kioskKey(k,true)` 실행(클릭은 손 뗀 뒤에야 발생하는 문제 해결) + `kioskKey(d,ft)` 이중입력 가드(`_tsG`: 터치 실행 키는 650ms 내 동일키 click 1회 무시) + 키오스크 루트 `touch-action:manipulation`. ⚠️ 키패드 입력 검증법: 상태·전역 접근 불가 → **`AudioContext.prototype.createOscillator` 패치로 호출 수 계측**(클릭=1, 터치+클릭=1이면 가드 정상, 연속 2탭=2). 입력 표시는 kDots(점4개, kBoxes rv는 미사용 잔존). **폰·태블릿 반응형**(v32.629): isKiosk 블록 clamp 최소 px를 «390px에서 비율항 지배»로 재계산(min=min(기존, max(11, 계수*3.9)), vh는 *8)+letter-spacing 4px→0.37vmin — **TV·태블릿은 중간 비율항 지배라 불변**(실측: TV 버튼 162px·태블릿 115px 동일, 폰 59px). 새 키오스크 UI 요소엔 px min을 «폰 390 기준»으로 잡을 것. 검증=실브라우저 resize+getBoundingClientRect 실측(헤드리스 스크린샷은 무한애니 스테일 프레임이라 부정확). 지각=정시(lateMin=0). **미등원 자동 결석**(v32.636): `autoAttendance`가 «체크인 없음+그날 스케줄 있음+(지난 날짜 or 오늘 수업종료(_classEnd) 경과)»면 '결석' 반환 — **유도(derived) 방식이라 기록을 안 쓰고** 전 표시 지점(rec.attendance||autoAttendance 패턴 9곳)에 자동 반영, 늦은 체크인 시 즉시 출석/지각 복귀, 수동 출결 항상 우선, 소급 하한 2026.07.15. **v32.657 결석예정 연계**: 무체크인 분기 첫머리에 noShowExcused(!del, 같은 소급 하한)면 즉시 «결석» — loadDraft가 이걸 draft 기본값으로 쓰므로 일간일지 출결 pill 자동 «결석»+마일리지 0, 현황·캡처카드 등 전 지점 자동 전파(유도라 기록 안 씀). ⚠️ 등하원 상태를 새로 표시/계산하는 코드는 반드시 «checkins → 휴원일(_cdClosed) → noShowExcused → 스케줄» 4단 확인(한 곳이라도 빼면 v656~658 같은 불일치 재발). **v32.658 휴원일 연계**: autoAttendance·일간 스트립·칩·관제판에 _cdClosed 가드(휴원일=자동결석·붉은표시·집계 전부 중지, 관제판은 금색 «오늘은 휴원일» 배너+KPI 0; 실제 체크인 기록 표시·현황 관리(취소/하원입력)는 휴원일에도 유지). 검증 팁: body.textContent 검사는 sc-if 숨김 템플릿 잔재에 오탐 — 가시성(getBoundingClientRect+display) 필터로 확인할 것. **v32.659 퇴원생 전수감사 완료**: 등하원 전 표면(관제판·일간 스트립/칩·현황·안전망·결석예정 패널·드롭다운·findByLast4) withdrawn/pending 제외 확인 — 유일 구멍이던 사전등록 목록 _nmap에 필터 추가(퇴원생 유령 결석예정 제거) + 미사용 죽은 메서드 checkinTodayList/excusedList 삭제(호출 0곳 확인 후 — 필터 없는 채 방치돼 미래 오용 위험이었음). 검증법=메서드 4개(autoAttendance/_classStart/_classEnd/_weekday) 추출 유닛테스트(scratchpad att_test.html, 9케이스). **자정 넘김 = 논리적 날짜 `_ckDate()`(v32.557)**: 새벽 5시 이전의 체크인/하원은 전날 날짜로 기록(고등부 야간수업 — 예전엔 새벽 하원이 다음날 새 등원으로 오기록). doCheckin·_smartType·수동매칭 라벨·checkinTodayByTeacher 적용, noShow/스케줄 로직은 실제 날짜 유지. ⚠️ **키오스크 소리 = WebAudio 합성 전용 + 상시 미디어(화면유지 영상) 금지**(v32.566 종결): 스탠바이미 브라우저는 짧은 소리 파일(<audio>/<video>) 출력 불가 & 상시 영상이 페이지 오디오세션을 뺏어 WebAudio까지 무음화. 화면유지=Wake Lock 단독. 상세 규칙: 메모리 [[project-checkin-alimtalk]]. 상세: 메모리 [[project-checkin-alimtalk]].
7. `schedule` 선생님 일지 — 상단 **한 줄 4탭**(v32.595, `schedSegBtns`): **학생관리·일정·등하원·보고**. 내부 상태는 여전히 `S.scheduleSeg`('stu'|'checkin'|'talk') + `S.schedTop`('board'|'cal') 조합 — 학생관리=stu+board(반별 보드 `isSchedStu`), 일정=stu+cal(주간+월력+보강 `isSchedJournal`, schedWeek/schedMonthCal/schedClasses), 등하원=`isCheckin`, 보고=`isSchedTalk`. 탭 클릭이 scheduleSeg+schedTop 동시 세팅. 옛 하위 토글(반별/주간·월력)은 `isSchedMainTab:false`로 숨김(rv `schedMainBtns`는 미사용 잔존).
- **취약유형 프로파일 노출 확대(v32.672, 원장 승인 베테랑②)**: 오답유형(exams[].wrongTypes) 누적 분석은 **기존 기능**(examAgg의 weakTypes/weakTop — 종합일지 프로필 «자주 틀리는 유형(오답 빈도)» 막대 카드+성적탭 «집중 보강» 라인). v672 추가=한눈에 보이는 배지: ①학생 행 공유 rv(trendLabel 옆 weak — «취약 {유형} ×{횟수}», 오답 2회 이상만)+행 마크업 3곳(선생님일지·학원일지 복제) ②보드 타일 빌더 2곳(rows0, attn 뒤 weak1)+r 타일 3곳·sr 타일 1곳. ⚠️ 학생 행·타일·프로필이 각각 다른 템플릿/rv — 학생 표시 추가 시 전부 별도 패치 필요. 검증=오답 3회 학생 행 배지+프로필 카드 3유형 막대, 무오답 학생 무배지.
- **이탈 징후 조기경보(v32.666, 원장 승인 1순위②)**: 학생관리 «관리 필요»(attn) 판정에 출결 신호 추가 — 최근 28일 일지에서 «결석 ≥3회 OR (기록≥4 & 결석률≥30%)»면 시험 없이도 관리 필요(기존 시험 신호 grade≥4/delta≤-8은 OR 보존). 구현=보드 빌더 2곳(복제, const now 앵커)에 _cut28+_absMap(레코드 1패스, attendance||autoAttendance) → KPI·필터·타일 붉은 강조·관리필요 패널에 자동 전파. 검증=결석3회 학생만 KPI 1·패널 표시, 성실 학생 제외. **+과제 신호(v32.673, 원장 승인 베테랑④)**: _absMap 같은 패스에 _cut14 «최근 14일 homework===미완료 ≥3회»(_a4.hw)→attnHw OR — 출결·과제·시험 3신호 체제. 검증=미완3회 학생만 관리필요 1.
- **선생님별 보기 필터**(v32.438): 학원 일지 뺀 모든 콘텐츠 탭(일간·월간·성적·종합일지 등)에서 원장이 **관리자 신분 유지한 채** 특정 선생님 학생만 보기. 핵심=`visibleClasses(data,user)` 메서드가 «user==='관리자' && `S.schedTeacher` 선택 && `S.view!=='admin'`»일 때 그 선생님 반으로 필터. 셀렉터=`.main-pad` 상단 `viewTeacherUI`(관리자+콘텐츠탭에서만). 신분전환 헤더 셀렉터(setUser→currentUser)와는 별개. 선생님 일지의 `schedTeacher`(schedTeacherUI/_schedClasses) 공유.
8. `admin` **학원 일지**(**관리자 전용, 전체 모니터링 허브**) — 세그먼트 **5개** `S.adminSeg`: **한눈에**(overview 대시보드: KPI+선생님 현황+수강료 요약)·**학생관리**(student=반별 보드, isSchedStu 마크업 복제→`isAdminStudent`; 상단 신규생 접수바+«접수 대기» 패널; **v32.654 순서=접수→KPI/필터→«＋ 반 추가»→반별 보드→전체 일정 캘린더**(캘린더가 중간에 끼어 반추가·보드를 밀어내던 것 스왑, 균형 파서) ⚠️ 이 뷰 모바일 390 넘침 7개는 기존 이슈로 별도 태스크)·**등하원**(`isAdminCheckin`/`adminCk` rv, v32.649 원장 «전체가 다 보여야»: 오늘 등하원 관제판 — 기준일 `_ckDate`, 수업 있는 반만 시작시간순 카드, 학생 상태 pill 5종(등원/하원/하원 미기록=종료 후 호박/미등원=시작 후 빨강/결석 예정+사유/수업 전), KPI 5(대상·등원·미등원·하원완료·하원미기록), 선생님필터 무관 전체. **+관리 기능 전체**(v32.650 원장 «입력기능 다»): `isCheckin` 가드를 (schedule+checkin)∥(admin+checkin)으로 확장하고 등하원 관리 블록(미등원 안전망·현황(취소/하원입력)·결석예정·휴원일·학생모드, 21KB)을 isSchedule 래퍼 밖 최상위(isFee 앞)로 이동 — **복제 아닌 공유**(한 곳 수정=양쪽 반영), 관제판 아래에 이어 렌더)·**수강료 장부**(`isFee`)·**데이터**(`isData`). ⚠️ 세그먼트 배열 **2곳**(rv `adminSegs` + 다른 rv `const segs`). (v32.439/440) 학원 일지는 선생님필터 제외(항상 전체). ⚠️ 보드·캘린더 마크업이 선생님 일지와 **복제(중복)** 상태 — 한쪽 수정 시 양쪽 반영 필요.
- **퇴원생 데이터**(v32.463, v32.471 데이터탭으로 이동): `isWithdrawn`/`withdrawnData` rv 가드=`adminSeg==='data'` → 데이터 탭 안에 «퇴원생 데이터»(위: 담당쌤별 퇴원+삭제아카이브 목록·사유·재원기간, seen{}로 id 중복제거)+«백업·취합»(아래) 함께 렌더. 삭제 학생 아카이브는 [[04 Supabase]] `leftStudents`.
- 비관리자(선생님)는 `admin`(학원 일지) 숨김. 본인 담당 반만 보임(잠금).
- **선생님 현황 데이터**: 로그인 시 cloud gate `recordStaff(id)`가 `data.staff[이름]={name,role,admin,signupAt,lastLogin}`를 기록→app_state로 동기화. `persist()`는 staff 보존(덮어쓰기 방지). 대시보드는 `adminData` IIFE(view==='admin'일 때만 계산)로 렌더.
- **수강료 장부 «카드매출(결제선생) 붙여넣기» = 기존 기능**(납입 장부 서브탭 상단, `parsePaste`+`doMergeFee`): 결제선생 엑셀/표 복사→붙여넣기→헤더 자동인식(이름·결제일·금액·상태·카드사, 무헤더=이름/결제일/금액/상태 순 가정)→이름 매칭으로 완납+납입일+카드사+금액 기록, 취소=제외·미매칭=보고. **v32.655 보강: 동명이인은 건너뛰고 메시지로 안내**(예전엔 byName 덮어쓰기로 마지막 학생에게 조용히 오기록 — 학생 식별을 이름 하나로 하는 로직은 항상 동명이인 가드 필수). **미납 후속 동선(v32.664, 원장 승인 2번)**: 한눈에 «수강료 미납» KPI 클릭=장부 미납 필터로 즉시 이동(adminData kpis에 onTap/cursor — 전 KPI에 기본값 필수, 없으면 {{ k.cursor }} undefined) + 장부 필터 칩 행 우측 «📋 미납 명단 복사»(copyUnpaidList: 재원생만, «[HIS] YYYY.MM 수강료 미납 N명+줄별 이름(반)» — 동명이인 반으로 구별, clipboard 실패 시 execCommand 폴백, 메시지=feeCopyMsg). ⚠️ 같은 대사 기능을 새로 만들지 말 것(v655 작업 중 중복 구현했다 발견·롤백) — 장부 관련 요청은 먼저 isLedgerSub 블록·doMergeFee부터 확인. 하니스 참고: file:// 하니스에선 vendor 스크립트 CORS로 «[bundle] error» 배너가 뜸=아티팩트(회귀 아님).
- 주요 기능: 마일리지(출결0.2·과제차등·시험통과0.5, 결석=0)·티어·장학금, 리포트 4종 통일("A Note for You"+손글씨 서명 '— from {담당쌤}'), 학생 반이동, og:image(카톡 미리보기).
- ⚠️ **신규생 «등록 확정» 게이팅**(v32.460): 신규 상담 접수(`startNewIntake`)한 학생은 `pending:true`로 생성되어 «등록 확정»(`confirmEnrollIntake`) 전까지 **아무 집계·장부·보드에 안 뜸**. 구현=`visibleClasses(data,user)`가 반환 직전 각 반의 `students`에서 `st.pending` 학생을 제외(pending 없는 반은 원본 참조 그대로, 있는 반만 얕은 복사). 이 관문을 쓰는 모든 표시 지점(수강료 장부 feeData, KPI board=전체원생·이번달신규, 학생관리/반별 보드 schedClasses 등)이 자동으로 확정 학생만 표시. **확정 시** `delete stu.pending` + `enrollDate`·`registeredAt`=today 설정 → 전 화면에 신규로 반영(신규 KPI/배지는 `registeredAt` 기준). pending 학생은 **접수 워크스페이스(종합일지›신규등록 `unassignedNew` «반배정 대기»)에는 계속 보임**(원본 dd.classes 직접 읽어 visibleClasses 안 거침) → 거기서 상담·레벨테스트·반배정·확정 진행. 소급 적용 안 됨(플래그 없는 기존 학생은 계속 표시). 수강료 장부 행엔 신규/퇴원 배지(v32.459), 학생 삭제=`removeStudent(cid,sid)`(v32.458).

## 2-1. 모바일/앱화 목표 (2026-07-14 원장 선언)
- **궁극 목표: 폰·태블릿에서 선생님이 입력하고 고객(학부모)이 쓰는 앱 수준 경험.** PC 전용이라는 옛 전제 폐기 — 신규 UI는 폰 폭(390px)까지 고려할 것(키오스크는 v32.629 반응형 완료).
- ⚠️ **iOS(WebKit) 검증 필수**: 원장·학부모 폰=아이폰/카톡 인앱(WKWebKit). Chrome만 검증하면 iOS에서 깨질 수 있음(v32.630 흰화면 사고). **로컬 재현법 = `py -3 -m playwright` + webkit** (`p.webkit.launch()`, viewport 390×844) — 실제 iOS 엔진으로 렌더·콘솔·좌표 실측 가능. 하니스에서 게이트는 CSS로만 숨기므로 **게이트 JS의 body 스크롤락이 남아 창스크롤 불가 = 하니스 아티팩트**(회귀 판정 시 git HEAD 하니스와 «전후 측정치 비교»로 판정).
- ⚠️ **앱 루트 높이 규칙(v32.630)**: 페이로드 CSS `.sc-host > div{min-height:0 !important}`가 루트의 min-height:100vh를 죽임 → 루트는 인라인 `flex:1 0 auto`로 높이 확보(Chrome=내용 높이 유지, WebKit=sc-host 채움). 이 flex를 제거하면 iOS 전체가 흰화면 재발.
- 로드맵: ①모바일 웹 다듬기(**진행중** — v32.631 1차: 폰 헤더 컴팩트(hdr-ms/hdr-div/hdr-role 숨김+hdr-user 컴팩트), 일간일지 bulk-actions 줄바꿈+시험그리드 m-test4 2열, 4개 뷰 390px 넘침 0 달성) ②PWA(홈화면 설치+아이콘+전체화면) ③학부모용 화면 분리.
- **모바일 CSS는 페이로드 head `@media (max-width:760px)` 블록 한 곳에 집약**(`.main-pad { overflow-x:hidden }` 줄이 블록 끝 앵커). 인라인 스타일 요소는 class를 부여해 이 블록에서 !important로 다듬는 패턴. 검증 스크립트=scratchpad `wk_survey.py`(4개 뷰 하니스 생성→WebKit 390 렌더→가로넘침 요소 자동 검출).
- **키오스크 가로화면(PC·태블릿 landscape) 압축 레이아웃**(v32.632): 클래스 kio-hero/kio-note/kio-col/kio-pad + 페이로드 head `@media (orientation:landscape) and (max-height:1200px)` — 키패드 vh 기반으로 줄여 1920×966에서 12키 전부 표시. 세로(스탠바이미)는 미적용·불변. 키오스크 진입 시 body overflow hidden(시작/부팅복원 2곳), 종료 시 복원(배경 스크롤바 제거). **키오스크 자동복원 = 세로 화면 전용**(v32.633 원장 확정 «PC는 오늘로»): 부팅복원·visibilitychange 복원 2곳에 `innerHeight>=innerWidth` 조건 — PC(가로)는 __his_kiosk 플래그가 있어도 항상 홈 부팅, 스탠바이미(세로)만 잠금 복원. 수동 학생모드는 어디서든 가능(가로 기기는 새로고침 시 해제).
- ⚠️ **페이로드에 삽입하는 모든 조각(CSS 포함)의 쌍따옴표는 반드시 `\"` 이스케이프**(v32.632 사고: CSS selector의 비이스케이프 `"`가 JSON 문자열을 끊어 전체 앱 빈화면). CSS attribute selector는 `[data-kk=clear]`처럼 무따옴표 권장. 편집 후 검증: 페이로드 라인에서 `"<!DOCTYPE`부터 `json.raw_decode`로 문자열 파스 성공 확인.

## 3. 아키텍처 / 코드 수정법
- `index.html` = **번들러 아티팩트**. 앱 페이로드는 파일에서 `"<!DOCTYPE html>...`로 시작하는 **JSON 인코딩된 한 줄**(현재 약 170번째 줄). 컴포넌트 로직은 그 안 `<script ... data-dc-script>`(class Component extends DCLogic).
- **데스크톱 Claude Code**: `index.html`을 직접 열어 편집·커밋(로컬 파일).
- **원격/웹 환경**(이 저장소가 클론된 샌드박스): 페이로드가 JSON 인코딩이라 파이썬으로 디코드(json.loads)→편집→재인코딩(json.dumps 후 `/`→`/`, `</script` 없는지 assert) 필요. node --check로 컴포넌트 JS 문법 검증.
- 클라우드 로그인 UI는 페이로드 `<body>` 직후 오버레이(#cloud-gate) + `</body>` 직전 supabase-js(CDN)+로직 주입돼 있음.
- ⚠️ **head에 넣을 것(파비콘·스타일 등)은 반드시 «페이로드 head»(escaped, 첫 `<\/head>` 앞)에**: 하이드레이션이 바깥 head를 페이로드 head로 교체해서 바깥 head 것은 부팅 후 소멸(파비콘 지구본 사고·v508 게이트스타일 교훈). 스크래퍼용(og:image 등)은 바깥 head로 충분(JS 안 돌리니까) — 라이브 브라우저가 봐야 하는 건 페이로드 head.
- ⚠️ **학생 id 중복 가능성(중요)**: 일부 학생들이 같은 내부 id를 공유하는 데이터가 존재함(원인 미상 — 파일 합치기/명단붙여넣기 추정). 이러면 `document.getElementById('cap-'+id)`가 DOM에서 먼저 나온 다른 학생 카드를 반환해 **엉뚱한 학생이 복사됨**(v32.359에서 지윤→보경 버그). 근본 우회: 캡처 카드에 `data-sname`(학생 이름) 부여 + `_capEl(capId, sname)` 헬퍼로 이름 일치 카드를 선택(id 대신 이름으로 식별). copyRow/previewCard/previewTitle/큐 모두 이름 기반. id로 학생을 찾는 다른 로직(records/mileage recordFor 등)도 같은 중복 위험이 있으니, 학생 관련 신규 기능은 id 유일성을 가정하지 말 것. (근본 해결은 로드 시 중복 id 재배정이지만 records 분리 불가로 데이터 손상 위험 → 원장 확인 없이 자동 수정 금지.)
- ⚠️ **DC 템플릿 이벤트 바인딩 규칙(중요)**: `onclick="{{ ... }}"`에는 **인라인 화살표함수를 쓰면 안 됨** — `{{ () => this.setState({...}) }}`, `{{ () => this.openBulk() }}` 같은 인라인 표현식은 프레임워크가 핸들러로 **바인딩하지 못해 버튼이 완전히 먹통**이 됨(`button.onclick`이 null, scp 클래스 미부여). **반드시 핸들러 "참조"**를 써야 함: rv(렌더값) 객체에 `navGoFee: (() => this.setState({...}))` 처럼 함수 프로퍼티를 만들고 `onclick="{{ navGoFee }}"`로 참조. (v32.349에서 홈 빠른이동 3개+모바일 하단바 5개 버튼이 이 문제로 전부 먹통이던 것을 root rv에 `navGoHome/navGoBulk/navGoCheckin/navGoSchedule/navGoAdmin/navGoFee` 핸들러 추가해 수정. 새 네비 버튼 만들 때 이 패턴 준수.)
- ⚠️ **중첩 sc-for 안 «동적으로 나타나는» sc-if 버튼은 onclick 미바인딩(v32.619 교훈)**: `<sc-for><sc-for>` 이중 루프 안에서 `hint-placeholder-val="{{ false }}"`(초기 숨김)인 sc-if가 상태변경으로 나중에 나타나면, 그 안의 버튼은 **onclick이 null로 바인딩 안 됨**(핸들러 참조 `t.onSave`가 정상이어도). 단일 sc-for의 동적 sc-if(예: 홈 보고 답변 편집기)는 정상 바인딩되므로 «이중 sc-for + 동적 sc-if» 조합이 원인. **해결=인라인 편집 대신 최상위(루프 밖) 모달**로: 편집 버튼(초기 렌더에 보이는 것=바인딩됨)이 `S.editKey` 세팅→루트 rv가 `editOpen:!!S.editKey`로 모달 표시, 모달 핸들러는 루트 rv 레벨. 진단법: 헤드리스로 문제 버튼의 `.onclick`이 `null`인지(정상 버튼은 `function`) 확인. ⚠️ **검증 시 `_persistSoon`은 700ms 디바운스** — 클릭 직후 동기적으로 localStorage 읽으면 옛값(상태는 즉시, 저장은 지연). 브라우저 검증은 저장 후 1~2s 대기 후 읽을 것.
- ⚠️ **캡처 요소 조기닫힘 주의(v32.578 교훈)**: `captureEl(id)`류 이미지 캡처는 **DOM 요소의 실제 범위**만 찍는다. 템플릿에 잉여 `<\/div>`가 끼면 캡처 요소가 조기 종료돼 나머지 섹션이 형제로 새어나가는데, **화면은 멀쩡해 보여서**(형제여도 순서대로 렌더) 캡처했을 때만 잘림이 드러남(종합일지 `#profilecap`이 헤더 직후+레이더 직전 2개의 조기닫힘으로 카톡 복사 시 헤더만 나오던 버그). 진단법: 하니스에 `#캡처id{outline:6px solid red !important;}` CSS 주입 후 헤드리스 스크린샷으로 빨간 박스 범위 확인 + `<div`/`<\/div>` 깊이 시뮬레이션(캡처 요소 open→`END CAPTURE REGION` 주석까지 depth가 음수로 떨어지는 지점=잉여 닫힘). ⚠️ **잉여 닫힘을 "제거만" 하면 안 됨**(v32.578→579 사고): 문서 전체 균형이 깨져 안 닫힌 래퍼가 템플릿상 뒤에 오는 뷰(선생님일지·학원일지)를 삼켜 빈화면 재발. 제거한 개수만큼 그 컨테이너의 진짜 끝(모달이면 액션버튼 뒤)에 `<\/div>` 재삽입 필수. 캡처 카드 구조 수정 후엔 ①빨간박스 ②깊이 시뮬레이션 ③**선생님일지·학원일지 등 뒤 뷰들 실렌더**까지 반드시 검증.

## 4. Supabase
- ⚠️ **supabase-js는 반드시 버전 고정 `@2.49.4`**(jsdelivr+unpkg 두 로더 모두, v32.527). 절대 `@2`(자동 최신)로 되돌리지 말 것 — 최신 릴리스가 옵셔널체이닝(`?.`)·널병합(`??`)·논리대입(`||=`) 포함 번들로 배포되면서 **스탠바이미(LG webOS) 등 구형 브라우저에서 파싱 자체가 깨져** «[bundle] Script error.»+클라우드 연결 실패(0 학생)를 유발했음. 버전 올릴 땐 UMD 번들을 받아 위 3개 문법이 0개인지 grep 확인 후 교체. CDN 로더 3종(supabase/pdf/xlsx)엔 `crossOrigin='anonymous'` 유지(교차출처 에러 가림 해제). 바깥 head의 전역 진단배너(`__hisBoom`, v32.525~527)는 앱(.sc-host) 미렌더 시에만 2.5s 지연 후 표시+앱 살아나면 자동 해제.
- ⚠️ **무료 egress(월 5GB) 초과로 프로젝트 잠김 사건**(2026-07-16, «exceed_egress_quota»): 복구는 **원장만**(Supabase 대시보드: 월 결제주기 초기화 대기 or Pro 업그레이드 $25/mo·250GB). **egress 주범=①realtime postgres_changes 구독**(저장1회→전체 data 행을 접속 전기기에 브로드캐스트, 상시 키오스크+폰들이 곱셈) **②flushPush 저장마다 전체 data 재읽기 병합**. **수정(v32.641)**: realtime 구독 호출 제거(45초 게이트 폴링이 동기화 담당) + flushPush 병합읽기를 updated_at 게이팅(클라우드 미변경 시 full read 생략) + push 후 `window.__hisLastPullTs=at`. **2026-07-16 원장 Pro 업그레이드 완료($25/mo, 250GB)** + 원칙 확정: **«전송량 통제보다 사용자 효율·편리가 최우선»**(원장 지시). ⚠️ 단 realtime postgres_changes 재도입은 여전히 금지 — 전체 blob을 전 기기에 쏘고 즉시 또 pull하는 «이중 비용»인데 체감 이득은 12s 폴링 대비 수 초뿐. **현행 동기화(v32.643)**: 클라우드 push **2s 병합**(로컬 저장 즉시)+hide/pagehide 즉시 flush, 폴링 **12s**(updated_at 수십 byte 확인→변경시만 full pull), 병합읽기 updated_at 게이팅, `__his_egq` 일일 수신 계측(진단 배너 «오늘수신=N회/XX KB»). 기기 간 반영 통상 5~8s·최악 ~14s. **egress 수학 = blob크기 × pull횟수 × 기기수** — 튜닝 시 이 3인자와 UX(반영 지연)를 함께 저울질하되 Pro 여유(250GB) 안에서 UX 우선. 근본적으로 단일 blob 설계가 egress 비용원 — 향후 SaaS화 시 테이블 분리/델타 업데이트 검토.
- URL: `https://vcfhttzbzgtszpuahibe.supabase.co`
- Publishable key(공개·클라이언트용): `sb_publishable_d-X3ubJw6n4P1zumfRZgrQ_rWDfhmWj`
- **자동 백업 스냅샷(v32.665, 원장 승인 1순위①)**: 게이트 `hisAutoSnap`이 로그인 기기에서 매일 1회(부팅+25s, 이후 1시간마다 체크, 기기별 `__his_snapDone` 날짜 가드) 현재 데이터를 같은 app_state 테이블의 별도 행 `snap_YYYY.MM.DD`로 upsert + 15일 초과분 delete(like snap_% + updated_at lt). 브리지 `window.__hisSnap{run,list,restore}` — restore=①현재 상태를 snap_before_restore로 보관 ②스냅샷 읽기 ③main 통째 교체+로컬 미러 교체+reload(merge 아닌 overwrite — 복원 후 다른 기기 새로고침 필요). UI=학원일지›데이터 «자동 백업» 카드(마지막 백업 날짜·지금 백업·백업 목록·이 시점으로 복원 2단 confirm, rv는 데이터 탭 전용 rv(«// data» 주석, resetAllMileage/exportData 있는 곳)에 — feeData 쪽 rv에 넣으면 no-op kd(){} 바인딩됨). ⚠️ 페이로드 안 JS 문자열에 개행 넣을 땐 `\\n`(4글자) — `\n`은 JSON 디코드 후 실개행=문법 파괴(v665 사고). ⚠️ RLS가 snap_% 행 insert를 막으면 콘솔 [snap] fail — 원장이 첫 백업 후 데이터 탭 «백업 목록»으로 확인 필요. 검증=UI 모의브리지 E2E+게이트 가짜 sb 격리(저장/정리/dedup/force/복원 3단 전부 통과).
- 테이블 `public.app_state`(id PK='main', data jsonb, updated_at, client_id) + RLS(authenticated) + realtime. 단일 blob에 전체 학원 데이터 저장, localStorage['his-sys-v4'] 미러+0.7s 디바운스 업서트.
- ⚠️ **동기화 = «합치기»(merge, v32.435~).** 예전엔 «마지막 저장이 통째로 이기는» 방식이라, 다른 기기가 옛 데이터로 올리면 그 사이 추가된 상담·성장일지·성적·출결 등이 통째로 유실됐음(원장 «상담 저장했는데 사라짐» 사고). **수정: 클라우드 게이트 IIFE의 `mergeAppData(base=클라우드, over=로컬)`가 모든 컬렉션을 합침** — 배열은 고유키 합집합(counsels/cash/reports=id, records=`classId|studentId|date`, exams=`examSetId|studentId`또는id, classes·students·makeups=id, teacherCalendar=이벤트id), 객체맵은 키 합집합(checkins=in/out병합, sent/capSent/noShowExcused=OR, fees=월, monthly/profile/notices/testNames, scholarshipPayments=내용중복제거, staff=최소가입·최신로그인), counselQ=질문합집합, 스칼라=최신값(단 adminPin/kioskPin은 빈값 덮어쓰기 방지). **`flushPush`=올리기 전 클라우드 읽어 합쳐 올림(read-merge-write), 부팅=클라우드로 로컬 덮기 대신 로컬+클라우드 합치기.** 병합 실패 시 전부 기존 동작으로 안전 폴백. ⚠️ **트레이드오프**: «누적기록 절대 안 지움» 최우선이라, 한 기기에서 **삭제**한 항목이 다른 기기의 옛 사본이 올라오면 **되살아날 수 있음**(삭제는 모든 기기 새로고침 후 진행 권장). 별도 함수 `this.mergeData`(컴포넌트 내)는 «수동 가져오기»용(동기화와 별개, 일부 컬렉션만).
- ✅ **학생 삭제 = 표식(tombstone)으로 유지**(v32.462, 위 트레이드오프의 예외): union 병합이 삭제를 되살리던 문제 해결. `removeStudent(cid,sid)`가 삭제 id를 `data.deletedStudents[]`에 기록 → `mergeAppData`가 이 배열을 `_hisUnionStr`로 합집합(`out.deletedStudents`)한 뒤 **병합된 out.classes에서 해당 id 학생을 filter로 제거**(함수 끝 catch-all 직전, try/catch 폴백). 양방향·순서무관(헤드리스 실행 검증). 표식 없는 학생은 기존대로 union 보존. ⚠️ **다른 컬렉션(상담·출결 등)의 삭제는 여전히 tombstone 없음** → 되살아날 수 있으니 필요 시 같은 패턴(전용 deletedX 배열+merge strip) 확장. **퇴원(withdrawn)은 삭제 아님**(데이터 유지, 표식 안 함). ✅ **보고·건의함 삭제 = `deletedReports[]` tombstone**(v32.597, 원장 «삭제했는데 여전히 나타남»): deleteReport가 id 기록 → merge가 union 후 out.reports에서 strip(deletedClasses 블록 뒤). 격리 4/4. ✅ **보고 원장 답변**(v32.598): `replyReport(id,text)`가 r.reply/replyAt/`rT`(LWW 스탬프) 저장 → reports 병합이 rT 큰 쪽 통째 승리(read는 OR 보존, 무rT 레거시=over승). UI=홈 보고함 답변/수정 인라인 편집기(S.reportReplyId/Text) + 선생님일지›보고에 «내가 보낸 보고·건의»(myReports rv, 답변 읽기전용). ✅ **답글 스레드**(v32.617): r.thread=[{id,by,text,at,t}] 추가전용 — «답글 달기»(홈 양쪽 카드, S.reportCmtId/Text, addReportComment), 병합=reports elMerge에서 thread를 id 합집합(LWW 패자 쪽 답글도 보존), 알림 notifier·홈탭 배지에 답글 diff 포함. ✅ **홈 «보고 · 건의» 섹션**(v32.605): 전원 홈 작성기(id 'home-report-input'+homeReportCat 칩, `homeSubmitReport`)+내 목록(homeMyReports rv: 답변표시·인라인 수정 `editReport`(text+rT 재스탬프)·삭제 confirm→deleteReport). 원장 보고함(homeReports)에도 본문 수정·삭제 버튼(editing/showText/onEditStart 등, 편집상태 S.reportEditId/Text 공유). v599의 homeMyReplies rv/마크업은 이걸로 대체·삭제됨. ✅ **시험기록 삭제 = `deletedExams[]` tombstone**(v32.514, 원장 «성적 삭제 안됨»): `deleteExam`이 삭제 id를 `data.deletedExams[]`에 push → `mergeAppData`가 union 후 `out.exams`에서 그 id를 strip(deletedStudents strip 바로 뒤 try/catch). **id 기준이라 재채점(새 uid)은 생존**. 헤드리스 격리 7/7 검증. ✅ **휴원일 해제 = tombstone 아닌 LWW 맵**(closedDays, v32.511 [[project-checkin-alimtalk]]). ⚠️ **옛 코드 기기의 클라우드 재오염 사건**(v32.588 종결, 원장 «5945→민혜원» 장기 미해결 건): 구버전 앱이 도는 기기(캐시된 옛 index.html)는 옛 필드병합으로 push할 때마다 **틀린 연락처를 최신 intakeT 도장 위에 덮어써**(프랑켄슈타인: 잘못된 값+올바른 타임스탬프) 클라우드를 계속 재오염시킴. PC가 5144로 보여도 그건 **로컬 사본**(내보내기 JSON=state 스냅샷이지 클라우드 원본 아님!) — 신선한 기기가 5945를 보면 클라우드가 오염된 것. **진단법**: checkins의 `t` 스탬프 유무로 어떤 기록이 구버전 기기에서 왔는지 식별. **해결 도구(v32.588)**: ①주소 `?hisreset=1` = 그 기기 localStorage/세션 전체 삭제 후 깨끗한 재부팅(TV 등 브라우저 설정 못 찾는 기기용) ②키오스크 잠금화면 좌하단 상시 버전 표시 ③재오염된 클라우드 값은 PC에서 해당 학생 intake 재저장(새 intakeT 도장)으로 승리시켜 복구 ④키오스크 매일 새벽 자동 reload(v32.587). **모든 상시 기기는 새 버전 배포 후 반드시 fresh load 확인**(잠금화면 버전으로). ✅ **등하원 기록(checkins) = 기록별 LWW + «취소» 버튼**(v32.583, 원장 «민혜원 오등원으로 결석예정 패널 미표시» 사고): 등하원›오늘 등하원 현황 각 행에 «취소» 버튼(`clearCheckin(sid,date,nm)`, confirm 후 `checkins[k]={del:1,t:Date.now()}` 삭제표식 저장). `doCheckin`은 매 기록에 `t` 스탬프+표식 위 재체크인 시 표식 초기화. merge와 `_absorbFresh`의 checkins가 **t 있는 쪽 기록별 LWW**(무T 레거시=기존 in/out 필드병합 유지). 표시 지점 8곳(autoAttendance·checkinTodayList/ByTeacher·noShowList·결석예정 rv·수동매칭 rv·_smartType·_ckReport)에 `del` 가드 → 취소 즉시 «안 온 학생»에 복귀·자동출결/일간 스트립도 제거. 격리 병합테스트 7/7+실브라우저 클릭 검증. ✅ **일간일지 기록(records) = 기록별 LWW**(v32.551): 병합이 «올리는 쪽 무조건 승»이라 상시 켜진 키오스크 등 다른 기기의 옛 사본 푸시가 원장 수정(출결·과제·점수→마일리지)을 되덮던 사고(«마일리지가 맘대로 바뀜») → 일간일지 저장 2지점 `editT: Date.now()` 스탬프 + merge에서 editT 큰 쪽 기록이 통째 승리(동률/무T=기존 over승, mileageConfirmed는 양쪽 OR 보존). 격리테스트 24/24. ✅ **학생 intake(연락처 등) = 학생별 LWW**(v32.547): 필드별 «빈값 못 덮음» 규칙 탓에 잘못 저장된 보호자번호를 지워도 부활(원장 테스트번호→민혜원 매칭 고착 사고) → intake 저장 4지점이 `stu.intakeT=Date.now()` 스탬프 + merge에서 intakeT 큰 쪽 intake가 통째로 승리(지움 반영), 무T 레거시는 기존 필드병합 유지. 같이 v32.547: **pending 학생은 findByLast4(키오스크/수동 매칭)에서 제외**. ✅ **notices(전달사항) = 누적형**(v32.612): 키가 `수신자|고유id`(레거시 키 'all'/이름 호환)라 새 공지가 이전 것을 안 덮음 — 원장 목록 최신 10개(수정=noticeEditKey로 제자리, 수신자 바꾸면 옛 키 del+새 키)·선생님 홈 최신 5개+날짜. ✅ **notices(전달사항) = 키별 LWW 맵**(v32.542): 예전 키 합집합이 삭제를 되살림 → `clearNotice`가 키 삭제 대신 `{del:1,t}` 표식 저장 + `sendNotice`가 `t:Date.now()` 스탬프 + merge에서 키별 t 비교(최신승). 모든 표시 지점이 `.text` 유무로 거르므로 구버전 기기에서도 삭제 표식이 숨겨짐. 보낸 공지 행에 «수정»(입력칸 프리필)·«삭제» 버튼(v32.542, 격리테스트 16/16). ✅ **kioskNote(A NOTE FOR YOU) = LWW 스칼라**(v32.532): merge 스칼라 목록에 없는 키는 `out=_hisClone(base)` 때문에 **클라우드 첫 값이 영구 승리**(원장 «rf» 사고 — 어느 기기에서 바꿔도 되돌아감). 수정 = `setKioskNote`가 `kioskNoteT=Date.now()` 스탬프 + merge에서 T 비교로 최신 편집 승리(격리 유닛테스트 7/7). ⚠️ **새 편집가능 스칼라 필드를 추가할 땐 반드시 merge 처리**(명시 목록 or LWW+타임스탬프)를 같이 넣을 것 — 안 넣으면 첫 저장값에 영구 고착됨. merge 검증법: 페이로드에서 `function _hisClone`~`mergeAppData` 끝까지 IndexOf(문자 오프셋, grep 바이트오프셋 쓰면 한글 때문에 어긋남)로 추출→JSON 언이스케이프→독립 html에서 유닛테스트(v32.532의 `window.__hisMergeTest` 노출도 있음, 단 로그인 후 스코프).
- ✅ **삭제생 아카이브 `leftStudents`**(v32.463): 삭제해도 데이터가 남도록 `removeStudent`가 splice 전에 학생정보{id,name,cls,owner,registeredAt,withdrawnAt,reason,leftAt}를 `data.leftStudents[]`에 push(그 뒤 tombstone). `mergeAppData`가 `leftStudents`를 `_hisArrMerge`(키 `ls:id`)로 union 병합 → tombstone strip은 classes[].students만 지우므로 아카이브는 보존(헤드리스 검증). **학원일지 세그먼트 «퇴원생»**(`adminSeg:'withdrawn'`, `isWithdrawn` 가드, `withdrawnData` rv): 재원 명단의 `withdrawn:true`(«퇴원» 배지)+삭제 아카이브 `leftStudents`(«삭제됨» 배지)를 담당쌤(owner)별 그룹핑, seen{}로 id 중복제거, 인원수·사유·재원기간(개월)·퇴원일 표 + 누적/이번달 KPI. adminSegs 배열은 **2곳**(rv `adminSegs` + 다른 rv `const segs`)이라 세그먼트 추가 시 둘 다 수정.
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

## 6-1b. OT 자료 (ot-orientation.html + 히즈 오리엔테이션 (오프라인).html)
- 원장 제작 DC 슬라이드 덱(24장, 페이로드 JSON 청크들). 앱 안 «🎓 오리엔테이션(OT)» 링크로 열림. 두 파일의 슬라이드 내용 동일 — **수정 시 반드시 둘 다**.
- **v2026-08-31 재배치(원장 지시 «독해 묶음·문법 묶음으로 플로우 설명»)**: 온라인 챕터 해체 — Online Learning 장을
  둘로 분할해 «Reading Online»(쉐도잉·어휘, 마이북과 리마스터 사이)과 «Grammar Online»(문법 퀴즈, 문법 묶음 끝)으로.
  Ch.05 Online 표지 삭제(장수 유지: 온라인 26·오프라인 25), 목차 7→6챕터(Seven→Six chapters), 챕터 번호
  시험대비 06→05·관리 07→06·수강료 아이브로 07→06, **커리큘럼↔시간표 순서 교체**. 같은 날 수강료 28/32/36만 갱신.
  ⚠️ 재배치는 세그먼트(앞 주석~<\/section>) 단위로 잘라 재조립 — 검증은 전 장 ArrowRight 순회 + JS오류 0.
  ⚠️ 프로브 주의: divider 아이브로는 text-transform:uppercase 라 innerText 가 «CHAPTER 05»로 잡힌다.
  오답 리마스터 장 불일치는 2026-08-31 오프라인에 복제해 해소 — 두 파일 모두 26장 동일.
- **v2026-07-20 갱신(v32.715)**: ①«히즈 리딩 리마스터» 슬라이드 신설(25장 됨, 9번째 — 독해 챕터 끝 «Reading Practice»와 «Ch.04 Grammar» 디바이더 사이(원장 지시로 시험대비 챕터→독해 챕터 이동), data-label=리딩 리마스터, 주석 08b): 확정 문구만 사용(안내문 1줄 «시간은 절반, 효과는 두 배…25분», 동형 재출제·두 점수 판독·인출 훈련 카드 3+수업 흐름 4단계 딥그린 밴드+회차 RM {YYMM}-{학년}, 캐치프레이즈 금지 — 메모리 [[project-mirror-reading]]) ②첫 장·끝 장 SINCE 2014 세리프(EB Garamond 이탤릭 금색): 온라인 Title=상단 우측(+POHANG · KOREA), 오프라인 Title=H1 위 아이브로(두 파일 Title 디자인이 서로 다름 주의!), Thank You=전화번호 아래 레터스페이스. ⚠️ 페이로드 JSON에 `\'` 무효 이스케이프 주의(단일따옴표는 이스케이프 불필요 — font-family:'Pretendard' 그대로).
- **v2026-07-18 갱신**: Check-in 슬라이드(18/24, data-label=Check-in) 우측을 폐기된 «학부모 카톡 미등원 자동 알림» 목업 → **실제 화면**(키오스크 체크인 성공+리포트 TODAY 스트립 스크린샷, base64 JPEG/PNG)+현행 3원칙(셀프 체크인 자동 등하원 구분/미등원=선생님 즉시 표시·연락/사전연락 결석=«결석 · 사유» 구분)으로 교체, 스피커노트·아이브로우(Smart Check-in & Care)도 갱신. 스크린샷 생성=하니스(가짜 학생 «이체크», intake.studentContact 뒷4자리 — findByLast4는 parentContact/studentContact만 봄). 원본 섹션은 숨김 템플릿이라 element.screenshot 불가 — 검증은 ArrowRight 내비로 실슬라이드 스크린샷.

## 6-2. 히즈어학원 공식 홈페이지 (home.html, 2026-07-14 개설)
- **주소**: https://goodmannerboy.github.io/hisbooks/home.html — 원장 제작 단일 번들(React, 24MB)을 그대로 호스팅. 주 타깃=학부모·학생(프랜차이즈 스토리는 추후).
- 이 번들러는 **부팅 시 head를 재구성해 title·파비콘이 증발**(우리 앱과 다른 방식이지만 같은 증상) → 파일 끝 keeper 스크립트(setTimeout 5회+visibilitychange)가 title «히즈어학원»+파비콘 재주입. og 메타는 바깥 head로 충분(스크래퍼는 JS 안 돌림).
- 원장이 새 버전 파일을 주면: home.html 교체 → title/og/keeper 다시 심기(위 패턴) → 렌더 검증 → push.
- ✅ **다이어트 완료(2026-07-14)**: 23.2MB→**1.7MB**. 원흉=내장 폰트 18벌(같은 폰트 woff2·woff·ttf 3중 포맷, 한글 풀글리프 각 ~1MB) — CDN(pretendard/구글폰트)으로도 로드되고 있어 중복이라 500KB 초과 내장 폰트만 base64 무효화(작은 서브셋·이미지 1.2MB 유지). 페이로드 폰트맵 구조=`"id":{"mime":"font/woff2","data":"base64"}`(escaped `\/` 포함 — 블롭 워커에 이스케이프 처리 필수). 풀페이지 렌더 비교 동일 확인. 원본 24MB는 원장 바탕화면 파일로 보존.
- 남은 로드맵: ①**모바일 반응형**(현재 데스크톱 고정폭 — 폰에선 축소 표시, viewport meta 넣으면 깨지므로 반응형 리디자인과 함께) ②커스텀 도메인(원장 구매 후 연결) ③네이버 서치어드바이저 등록 ④프랜차이즈(가맹) 스토리 섹션.

## 7. 남은 일 / 아이디어
- [★v32.758 구문 형광펜 스캔 — 회색조 스캔 대응 (2026-07-23, 원장이 실제 스캔 PDF 20260723182458 제공)] 원장 실제 스캔 검증 결과: 스캐너가 **완전 회색조(캔버스 satMax=0.000)**로 저장 → 노란 형광펜 색이 사라져 색기반 `_detectHi` 0검출. (그 파일 자체도 형광펜 미표시 빈 시험지였음.) 단 OCR은 인쇄 영어를 거의 완벽 판독(문장 1·2·4 정확) 확인. **대응**: `_detectHi`에 **회색조 자동감지 + 대체 검출** 추가 — 이미지 채도≈0이면 `isGray=1`, 마스크를 `v in [0.74,0.95]`(형광펜이 회색조에서 남기는 옅은 회색 배경 띠)로 전환, 최소폭 `W*0.14`(문장 밴드용, 번호배지 필터). **색 스캔은 isGray=0으로 기존 로직 완전 무변화(회귀 0)**. 회색조 잡음(Name칸·헤더)은 `_senProcess`가 **저장 구문세트 매칭되는 것만 채택**(`if(!m && bank.length) return`)해 자동 제거. 검증: 합성 회색조(satMax0) 캔버스에 형광펜 띠+Name칸 잡음 → 검출 2박스→매칭필터로 형광펜 문장만 정확복원+Name/미표시 제외, 색검출·구문생성기·오답3유형 회귀 전부 통과. ⚠️ **실물 최종튜닝 대기**: 원장 실제 형광펜 칠한 회색조 스캔 1장 있으면 v임계값을 스캐너에 맞춰 확정(현재 0.74~0.95는 노란형광펜 회색화 추정치). 전제: 그 구문세트를 «세트 저장» 필수(매칭·한국어·잡음필터용). 최선책은 여전히 컬러 스캔(색검출 확실).
- [★v32.757 구문 형광펜 스캔 → 오답 구문 자동 수집 (2026-07-23, 원장 «구문도 형광펜으로 표시된 문장 인쇄영어활자야»)] 어휘 형광펜 스캔처럼 구문(문장)도 자동 수집. **저수준 OCR 도구 전부 재사용**(프로덕션 검증된 어휘 스캔 것): `_trCanvases`(이미지/PDF→캔버스)·`_detectHi`(HSV 노랑~연두 마스크+행 갭필+연결성분→박스)·`_cropOcr`(크롭+eng OCR)·`_loadOcr`·`_lev`. 신규: `trSenScan`(파일선택)→`_senProcess`, `_mergeBoxes`(문장이 여러 줄→세로 인접 박스 병합), `_matchSen`+`_normSen`(정규식 없이 char-code 정규화; 저장 구문세트 localStorage와 lev+단어겹침 대조로 **OCR 노이즈 있어도 정확 문장+한국어 복원**), `_senBankAll`(his_sen_v1 전 세트를 매칭 은행으로). 결과를 `trSenBuilder(prefill)`로 생성기에 자동 채움(체크 상태로). ⚠️ **팝업 제스처 타이밍**: OCR은 비동기→그 후 window.open은 차단됨. 그래서 `_senProcess`가 스캔 시작(파일선택 제스처) 즉시 `win=trSenBuilder()`로 빈 생성기를 먼저 열고(=`return w` 추가), OCR 끝나면 `win.senPrefill(pre)`로 채움. ⚠️ 신규 메서드 정규식 0(char-code)→백슬래시 0, 큰따옴표 0 → JSON 안전. 인쇄 영어 활자라 OCR 정확도 높음(원장 지적). 검증: 합성 형광펜 캔버스로 `_detectHi` 실검출 2박스→병합→노이즈 OCR('questionabIe'/'requlrements')→저장세트 대조로 A·B 정확복원+한국어+미표시 C 제외, prefill 팝업 자동채움, 오답3유형·구문생성기 회귀 전부 통과(pageerror 0). 구문 은행 = 생성기에서 «세트 저장»한 것(어휘 vocaBank 대응). 후속: 구문세트를 스캔/엑셀로 일괄 입력.
- [★v32.756 구문/문장 시험지 생성기 (2026-07-23, 원장 «둘다 애플 엔지니어링» 中 2단계 — 클래스카드 문장세트 대응)] 트레이닝 modal에 «구문 시험지» 버튼(onTrSen) 추가 → **자족형 생성기 창**(`trSenBuilder()`)이 새 창으로 열림. **핵심 안전 설계**: 앱 본체는 버튼1+바인딩1+메서드1만 추가; 생성기 로직은 전부 팝업에 담되 **`</script>`·큰따옴표·백슬래시 원천 회피** — 정적 HTML은 `w.document.write(doc)`, 스크립트는 `w.document.createElement('script'); sc.textContent=js; body.appendChild` 로 주입(HTML파싱 안 거침→script-close 문제 없음), 특수문자는 `String.fromCharCode`(탭9/개행10/CR13/따옴표39), 파싱은 정규식 없이(한글경계는 charCode 0xAC00~0xD7A3 루프). doc/js는 큰따옴표·백슬래시·백틱·`${`·개행 0개라 앱 JSON 무손상(패치 전 senbuilder.html 독립검증 후 임베드). **기능**: 구문 붙여넣기(탭/`|`/한글경계 구분 자동)→문장 체크리스트→유형 4종(의미쓰기 영→한 / 영작 한→영 / 빈칸채우기 40%랜덤 / 어순배열 셔플토큰)→클래스카드 형태 시험지+정답지 렌더, 인쇄형태(시험지+정답지/시험지만/정답지만)+단(1/2)+문항셔플, **localStorage(his_sen_v1) 세트 저장/불러오기/삭제**(원장이 강별 구문세트 재사용). ⚠️ 어휘 오답(wrongBank)과 달리 구문은 자동 오답누적 경로 없음 — 교사가 붙여넣고 틀린 문장 체크(클래스카드 문장세트와 동일 방식, set기반). 검증: 독립 senbuilder 4유형+저장 통과 → 앱 임베드 후 부팅·오답 시험지 3유형 회귀·구문 버튼→팝업 파싱·3유형 렌더 전부 통과(앱/팝업 pageerror 0), JSON·양 메서드 괄호·sc 균형. 후속 후보: 빈칸 개수/힌트 옵션, 구문세트를 스캔/엑셀로 일괄 넣기.
- [★v32.755 오답 시험지 인쇄 옵션 패널 (2026-07-23, 원장 «둘다 애플 엔지니어링» 中 1단계)] `trPrintWrong` 인쇄문서 툴바에 클래스카드식 인쇄 옵션 추가 — **단(2/1/3) · 글자(보통/크게/작게) · 행간(보통/넓게/좁게)**, 앞서의 인쇄형태(시험지+정답지/시험지만/정답지만)와 함께. **전부 순수 CSS 라디오**(스크립트·큰따옴표 없음): 숨긴 라디오 name=col/fs/ls + `#c1:checked ~ .body .grid{column-count:1}` `#fL:checked ~ .body .q{font-size:15.5px}` `#lW:checked ~ .body .q{padding:10px 0;line-height:1.95}` 식. 툴바 flex-wrap, .seg 세그먼트 라벨(활성=금색), 인쇄버튼 margin-left:auto. 실브라우저: 토글→column-count/폰트/표시 실반영 확인, E2E 3유형 통과. 미착수 남음: 구문/문장 오답(2단계).
- [★v32.754 오답 시험지 형태를 클래스카드 「시험지 인쇄」처럼 (2026-07-23, 원장이 클래스카드 PrintSet 소스 붙여넣으며 «시험지 형태» 지정)] 원장이 클래스카드 단어세트+문장(구문)세트 PrintSet 화면 소스를 붙여넣어 «시험지 형태» 레퍼런스 제시. AskUserQuestion(형태맞춤/구문오답추가/옵션패널)에 무응답 → 위험 없고 데이터 추가 불필요한 **형태 맞춤**만 선반영. `trPrintWrong(type)` 인쇄문서를 클래스카드 형태로 재작성: 연두 헤더밴드(#D9F3B8)+코너 삼각형(#C7EA99/#B8E386)+HIS 로고박스+제목/부제(히즈어학원·유형)+우측 이름/점수 박스, 별면 정답지(초록 헤더 동일), 하단 「Excellence in English, HIS」+날짜 footer, **인쇄 형태 선택**(시험지+정답지/시험지만/정답지만) — **스크립트·큰따옴표 없이** 순수 CSS로: 숨긴 라디오 3개(pfAll/pfQ/pfA)+`#pfQ:checked ~ .body .pg.ak{display:none}` / `#pfA:checked ~ .body .pg:not(.ak){display:none}`, 인쇄는 `onclick='print()'`(문자열 인자 없음). 데이터 로직(wrongBank 수집·vocaBank en→ko·셔플·4지선다 distractor)은 v32.753 그대로. ⚠️ 페이로드 규칙 재확인: 메서드는 작은따옴표+백틱만(큰따옴표·백슬래시·개행·`</script>` 금지)이라 라디오 CSS로 인쇄형태 구현(스크립트 회피). 검증: 실브라우저 E2E 3유형(정답인덱스·졸업제외)+JSON·괄호·sc-if/for 균형+스크린샷 육안(클래스카드 형태 일치). **미착수(원장 확답 대기)**: 구문/문장 오답 시험지(빈칸채우기·어순배열·문장쓰기 — 문장 은행 필요), 인쇄 옵션 패널(단/폰트/행간/문항수).
- [★v32.753 오답 실물 시험지·정답지 앱 내 자동 생성 (2026-07-23, 원장 «태블릿 키오스크 없애고 클래스카드처럼 바로 오답 실물 시험지 정답지 생성 채택»)] 원장이 클래스카드 «시험지 인쇄» 화면 소스를 보여주며 방향 확정 — 태블릿 응시 방식 폐기, 앱에서 오답 실물 시험지+정답지를 바로 출제. **새 메서드 `trPrintWrong(type)`**(`trPaperOpen` 앞 삽입): 학생(trSid) `wrongBank`에서 `sid|en` 키·`!del`(졸업 제외) 오답 수집→`vocaBank` 전 단원에서 en→ko 매칭(강 선택 불필요, 전체 오답)→문항 셔플→**자족형 인쇄문서를 새 창(window.open)**으로 출력. 3유형: `ko`(단어→뜻 쓰기 주관식)/`en`(뜻→영어 쓰기)/`mc`(4지선다, 정답 뜻+어휘은행 pool에서 distractor 3개 랜덤·셔플·정답 인덱스 `it._ai`). 문서=시험지 `.pg` + 정답지 `.pg.ak`(page-break-after:always), 2단 `column-count`, `@media print{.bar 숨김}`, **`<script>` 태그 없음 → 인쇄는 인라인 `onclick='window.print()'`**(외부 `</script>` 위험 회피), 팝업차단 가드. 트레이닝 모달 setup에 버튼 3개(`onTrPrintKo/En/Mc`, «종이시험 오답 입력» 뒤). ⚠️ 페이로드 규칙: 메서드는 **작은따옴표+백틱만(큰따옴표·백슬래시·개행·`</script>` 금지)**이라 JSON 무손상; 템플릿 버튼은 `\"`·`<\/` 이스케이프. 검증: 실브라우저 E2E 3유형 팝업(신산 오답 3개=shallow/manipulate/incorporate, 졸업 superior 제외, 뜻 매칭, mc 보기 12개·정답인덱스 정확), JSON·괄호·sc-if/for 균형, 스크린샷 육안(클래스카드급 품질). 후속 후보: 클래스카드 «세트 가져오기»용 오답 엑셀 내보내기(공식 수동 import, 스크래핑 아님).
- [★v32.752 답지 어휘 확인·수정 편집목록 (2026-07-23, 원장 «90%가 아니라 100% 세계최고 정밀»)] 순수 OCR은 희귀 글자(«얕은»의 얕 등)·스캔노이즈로 리터럴 100% 불가(정식 kor 모델 6.95MB로도 fast와 동일 10/11, 같은 «얕은» 실패 — 모델 문제 아님 확인). 그래서 **인식 최대치 + 사람 1회 확인**으로 은행 100% 보장: 스캔 그리드에 `#scan-vocab` 편집목록(`_renderScanVocab` 명령형, componentDidUpdate 훅) — 답지에서 읽은 [영어|뜻] 쌍을 편집 input으로 표시(뜻 빈칸=빨간 테두리), 선생님이 어색한 것만 수정→`scanApply`가 편집된 `_scanAkRows`(en&&ko 필터)로 `vocaBank` 등록. `_scanRun`이 akPairs→`_scanAkRows`[{en,ko}]+`_scanVocabSeq`. **소요시간 실측: 답지+3학생(4쪽) ~4.8초, 학생만 3쪽 ~2.6초(학생 1명당 ~1초; 첫 사용은 엔진 다운로드로 +몇초, 이후 캐시)**. 검증: 편집목록 18칸 렌더+편집값 은행 반영, 프로덕션 404 0·JS0. ⚠️ 답지 OCR이 아예 못 읽은 단어(shallow처럼 rows에 없음)는 편집목록에 행이 없어 추가 불가 — 그건 어휘은행 화면에서 별도 추가(후속: 편집목록에 «행 추가» 버튼). ⚠️ 순수인식 100% 약속 금지(정직): «인식+확인=결과 100%»로 안내.
- [★v32.751 답지 같이 스캔→어휘은행 자동생성 (2026-07-23, 원장 «스캔파일에 답지도 같이 넣으면 바로»)] 반 스캔 PDF에 **답지(정답지)를 같이 넣으면** 어휘은행 사전등록 없이 바로 동작. `_trScanClass`가 2단계: ①모든 페이지 이름 OCR로 분류 — **명단과 매칭 안 되는 페이지=답지**(학생지엔 인쇄 이름, 답지엔 없음) ②답지는 `_akPairs`(kor+eng 워커, 단어 bbox 기반: 영어 단어 아래 셀의 한글 토큰 집계→«영어-뜻» 쌍)로 추출→어휘은행 자동 등록(`scanApply`가 `vocaBank[단원]={w,t}`, 단원명=`_akUnitName` 제목에서 «어휘 2410»), 학생지는 그 은행으로 오답 매칭. 총문항·종류는 **학생 페이지**(답지 아님, 제목 «2410»/인쇄뜻 노이즈 회피)에서 감지. `_scanPageScore`(이름 재OCR 없이 점수+오답), `_loadOcr` 비캐싱(kor+eng 워커 매번 생성·종료). 실측 답지 영어↔뜻 짝 **10/11(~90%)** — 한글 뜻은 인쇄체라도 영어·이름보다 약해 은행 ~90%(누락 단어는 그 학생 오답 미수집·은행에서 수정 가능; **원장 B안 채택, 정확도 트레이드오프 고지**). 검증=[답지+3학생] PDF에서 어휘은행 «어휘 2410» 9개 자동생성+점수 8/7/9 정확+오답 5/6 수집, 은행 있는 경로 6/6 회귀 OK, 프로덕션 404 0·JS0. ⚠️ 답지 감지는 이름 미매칭 기반 — 학생 이름 OCR 실패 페이지는 답지로 오분류될 수 있음(그리드에 그 학생 누락→선생님이 확인). ⚠️ new Function eval이므로 메서드 괄호 균형 필수(_akPairs 닫는 괄호 누락으로 «missing )» 배포 전 발견·수정).
- [★v32.750 반 스캔에 학생별 오답 단어 수집 통합 (2026-07-23, 원장 «각 학생별 오답 저장→오답 기반 재출제»)] 반 시험지 스캔 한 번에 **점수 + 학생별 오답 단어 수집 + 저장**을 일괄 처리. `_scanPage`가 페이지별로 형광 박스를 점수(개수)로 세는 김에 각 박스를 `_cropOcr`(eng)로 읽어 `_allBankWords`(전체 어휘은행 union) 대상 `_matchWord` fuzzy 매칭→학생별 오답 단어 수집. `scanApply`가 점수(setBulk)에 더해 각 학생 오답을 `wrongBank[sid|en]`(n+1·s0·today·t)로 저장+`_persistSoon`→기존 트레이닝 재출제 루프 자동 합류. 확인 그리드에 학생별 «오답 N개: word…» 표시(수집 단어가 은행에 있어야 뜻이 있어 재출제 의미 — 모의고사 등 은행에 없는 단어는 점수만). `_cropOcr` 크롭 여백 확대(padX14·padY7 — 최장/모서리 단어 클리핑 방지, v32.747에도 반영). 검증=3학생 PDF에서 점수 3/3+학생별 오답 6/6(신산 incorporate·manipulate / 김민준 shallow·superior·abundant / 이서연 consumer) wrongBank 등록 + 실UI E2E + 프로덕션 404 0·JS0. ⚠️ 최종 영구저장은 기존 «전체 저장 후 카톡 전송»(saveBulk→records)에서 확정(스캔은 draft 기입+5초 자동 임시저장; wrongBank는 즉시 persist). 오답 단어는 학생별 dedup.
- [★v32.749 자동감지 강화 (2026-07-23, 원장 «시험종류·문항수도 파일에서 자동인식»)] 업로드만 하면 **시험 종류(제목 OCR 키워드: 문법/어법→g·구문→st·독해→r·어휘→h)** 와 **총문항(페이지 번호 최대값)** 을 자동 감지해 미리 채움(칩은 setup→grid로 이동, 감지값 선택된 채 수정 가능). `_scanDetectType`(제목 kor OCR)·`_scanDetectTotal`(전체 eng OCR 최대 번호)·`scanSetTotal`(총문항 바꾸면 형광개수 기준 점수 즉시 재계산+그리드 재렌더). `_trScanClass`가 {rows,col,total} 반환. `_loadOcr` **비캐싱**으로 변경(종료된 워커 재사용 버그 방지 — kor/eng 워커는 쓰고 매번 terminate). 실제 어휘 시험지에서 제목«어휘»·번호 1~50 자동감지 검증, 실UI E2E(파일만 올림→h/10 자동감지→점수 3/3→기입) + 총문항 수정 재계산(총20→18점) + 프로덕션 404 0·JS0.
- [★반 뭉치 시험지 스캔→학생별 점수 자동기입 배포완료 v32.748 (2026-07-23)] **채점한 반 전체 시험지 PDF 붙여넣기 → 학생별 점수 자동 인식 → 일간일지 점수란 자동 기입(원장 «궁극적으로 스캔 PDF→일간일지 학생별 자동입력»)**: 일간일지 툴바(트레이닝 옆) «시험지 스캔 채점» 버튼 → 모달: ①시험 종류 칩(문법=gS/gT·주요구문=stS/stT·독해어휘=rS/rT·히즈어휘=hS/hT) + 총문항 칩(10~50) 선택 ②«채점한 시험지 PDF 올리기»(여러 장=반 전체) → `_trScanClass`가 페이지별로 **상단 16% 이름 OCR(kor 모델)→명단 fuzzy 매칭(`_matchStudent`, 제목 글자 섞여도 substring+레벤슈타인으로 학생 특정)** + **형광 개수(`_detectHi`)→점수=총문항−개수** ③**확인 그리드**(명령형 렌더 `_renderScanGrid`→`#scan-grid`, componentDidUpdate 훅 — 클립 작업실과 같은 setState-금지 명령형 패턴): 페이지별 [학생 드롭다운(자동배정 미리선택)·점수 input] 즉석 수정 ④«N명 점수 기입»(`scanApply`)→각 행 `setBulk(sid, colS, 점수)`+`setBulk(sid, colT, 총문항)`으로 일간일지 자동기입(트레이닝 자동기입과 같은 경로). **원장 확인: 실제 반 시험지는 학생 이름이 인쇄됨** → 인쇄 한글이름 OCR 검증 6/6(제목 노이즈에도 명단 매칭 정확). 검증=3학생 합성 PDF(신산8·김민준7·이서연9, 총10)로 엔진 3/3 + 실UI 전경로(학생일지→스캔채점→히즈어휘·총10→PDF→그리드 3/3 자동배정·점수정확→기입→bulk.rows hS/hT 확인) + 프로덕션 레이아웃 404 0·JS오류 0. 엔진=`_loadOcr(lang)`(언어별 워커 캐시, 'kor' 추가), `_matchStudent`, `_trScanClass`, `_renderScanGrid`, `scanApply`. 자산: `ocr/kor.traineddata.gz`(1.1MB fast) 추가. ⚠️ setBulk는 `state.bulk.date`+active class에 씀(일간일지 문맥에서 열어야 함). ⚠️ 점수=총문항−형광개수라 **총문항을 맞게 골라야**(그리드에서 행별 수정 가능). 남은 후보: 주요구문(문장 위 형광)·번호 기반 식별 병행, 스캔 결과에서 오답 단어까지 wrongBank 동시수집(v32.747과 결합).
- [★형광펜 OCR 오답 자동수집 배포완료 v32.747 (2026-07-23)] **종이 어휘시험 형광펜 오답→자동 인식→재출제(원장 «OCR 재출제까지 가자»→«애플 엔지니어링 가자»)**: 트레이닝 종이오답(trPaper) 화면에 «형광펜 시험지 올리기» 버튼 추가 — 채점한 시험지에서 **틀린 인쇄영어 위에만 노란 형광펜**을 칠해 사진·PDF로 올리면 ①형광 검출(`_detectHi`: 캔버스 getImageData→HSV 38~92°·S≥.25·V≥.55 마스크 + 가로 close(gap≤W·1.2%+6) + 연결성분 BFS(area≥max(500,W·H/2600)), cv2 로직 JS 포팅) ②각 형광 크롭 OCR(`_loadOcr` 지연로딩 Tesseract.js **자체호스팅** — 저장소 `ocr/` 폴더 8.6MB = tesseract.min.js + worker.min.js + tesseract-core-simd-lstm.wasm(.js) + eng.traineddata.gz(**fast** 모델), 외부 CDN 금지 준수) ③은행 대조 fuzzy(`_matchWord` 레벤슈타인, 토큰 단위도 비교해 «49 incorporate» 같은 문제번호 노이즈 제거) → `trPaperSel` 자동선택 + «N개 자동 선택: incorporate, …» 확인줄(`trScanMsg`) → 선생님 확인 후 기존 `trPaperSave`→`wrongBank[sid|en]`→재출제 루프에 그대로 합류. **지연로딩**이라 평소 앱 속도 무영향(선생님이 버튼 누를 때만 8.6MB 1회 다운로드·브라우저 캐시). 검증=실제 어휘 시험지 스캔(노란형광 6단어·«-6점»)으로 **검출 6/6·OCR 6/6·매칭 6/6·wrongBank 등록 6/6**, 실UI 전경로 E2E(학생일지→트레이닝→학생·강 선택→종이시험 오답 입력→형광펜 올리기→파일선택창→자동선택 렌더→오답 6개 등록→재출제 안내) + **프로덕션 레이아웃(실 hisbooks 서빙) 404 0·JS오류 0·ocr/ 경로 정상**. ⚠️ 앱은 **StreamableComponent + DCLogic(React+Babel 인브라우저)** 구조 — 로직 메서드는 `wrapper.logic`에 있고 **외부에서 logic.setState 호출 시 DOM 리렌더 안 됨**(state는 갱신됨) → E2E는 실클릭 또는 `.logic` 직접호출+`.state` 판독으로 검증. ⚠️ 거대 «"<!DOCTYPE …"» 문자열이 앱 전체(JS 포함)를 담은 **유효 JSON** → 그 안에 넣는 메서드의 정규식 backslash는 **이중 이스케이프**(`/\\.pdf$/i`, `/\\s+/g` — 파일엔 `\\.`,`\\s`). ⚠️ PDF 경로만 pdf.js(CDN) 의존, **이미지 경로는 완전 오프라인**. 남은 후보: 주요구문(문장) 형광 오답도 같은 틀로 확장, 검출 실패 시 «검출 크롭 보고 선생님이 은행단어 확정» 하이브리드.
- [x] **학원 일지 탭**(수강료+데이터 병합, 한눈에 대시보드, 선생님 현황) 구현·배포. (라이브 검증 필요)
- [ ] **Supabase Confirm email OFF** 확인(블로커). ← 선생님 현황에 선생님이 뜨려면 이게 꺼져 있어야 자체 회원가입/로그인이 됨.
- [★단어 자산+오답 졸업식 v32.694 (원장 «①+② 세트»)] **단어 자산 통장**: 트레이닝 정답 단어가 data.wordAsset[sid]={강:16진 비트마스크,t}로 영구 적립(맞힌 적 있으면 자산, 절대 안 줄어듦) — trStart 풀에 un/ix 부착→_trFinish에서 _waSetBit, 표시=_waCount. merge=**학생별 강 마스크 비트 OR**(단조 증가, 격리 4케이스 검증 — LWW 아님!). 용량=강당 hex 십수 자(50명×100강≈75KB). **오답 졸업식**: _trFinish 졸업(s>=2→del) 시 grads 수집→done 화면 골드 박스 «오늘 완전히 정복한 단어»+«단어 자산 N개»; 주간 집계=wrongBank del 항목의 t 도장(추가 저장소 0). **캡처카드**: TODAY 스트립 위 골드 «WORD ASSET 단어 자산 N개 · 이번 주 완전 정복 K개»(s.wa rv, n>0일 때만). 검증=E2E(6문항 전정답→자산 6·cherry 졸업·카드 줄)+병합 격리. ⚠️ vocaBank 강 재등록(교체) 시 단어 순서 바뀌면 기존 비트와 어긋남 — 강 교체는 «같은 목록 수정»만 권장, 대개편 시 새 강 번호 사용.
- [★어휘 오답 연동 v32.683] **종이 어휘시험→트레이닝 오답 루프 통합(원장 «어휘오답 연동가자»)**: 트레이닝 setup에 «종이시험 오답 입력» 버튼(trPaperOpen — 학생·강 선택 검증) → paper 단계(S.trStep, trPaperSel 맵): 선택 강 단어 전체가 영어+뜻 칩(빨강 토글)으로 → «오답 N개 등록»(trPaperSave)=wrongBank[sid|en] n+1·s0·t(졸업 표식도 부활) → setup 복귀+녹색 확인(trPMsg). 이후 기존 30% 재출제 루프에 자동 합류. 검증=E2E(칩 2개 등록→wrongBank 기록→즉시 시험 시작→pleasure·compel «오답 재도전» 배지 재출제 실측). 종이(어휘 격자 시험지)와 디지털 트레이닝이 한 오답 루프가 됨.
- [★오답노트 2차 v32.682] **반 뭉치 스캔 모드(원장 실물 확인: 학원 매일 주요구문·어휘시험 13p 스택 스캔)**: 작업실에 학생 선택 칩(#clip-studs, 명령형 렌더 — setState 금지 설계 유지, _clipCurSid) — PDF 한 번 열고 페이지 넘기며 학생 바꿔 클립, 담은목록 칩=«이름 N번», 저장=학생별 그룹핑(clipSavePend가 비열림 학생은 load(클라우드/로컬 t비교)→concat→save 체인). 검증=실제 학원 시험지 13p PDF로 혜원3번/승윤4번 분배 E2E. 학원 시험지 실물 형식: 주요구문지=문장4개+해석 손글씨+빨간펜(점수 16/20 우상단), 어휘지=50단어 4열 격자+뜻 손글씨+빨간 표시(-N). 다음 후보: 어휘시험 오답 단어→트레이닝 wrongBank 연동(재출제), 오답노트 A4 인쇄.
- [★오답노트(문제 원본 아카이브) 1차 배포 v32.681 (2026-07-18)] **시험지 스캔→틀린 문제 실물 클립→학생별 영구 보관(원장 «문제 덩어리 자체 저장» 혁신)**: 진입=종합일지 프로필 액션 줄 «오답노트» 버튼(profile.onClips→openClips) → 드로어(S.clipOpen, 미해결/전체 배지+카드 그리드) → «시험지에서 잘라 담기» 작업실(S.clipWork): 시험지 열기(PDF=_loadPdfLib 재사용·페이지 넘김·사진도 가능) → 캔버스 위 **드래그 한 번=크롭**(JPEG q0.82·폭≤1000px, 문항번호 자동+1, 담은 목록 칩) → 저장. 아키텍처: ①이미지는 본체 blob에 절대 안 넣음 — **클라우드 별도 행 clip_<sid>**(게이트 브리지 window.__hisClip{load,save}, 스냅 패턴)+로컬 미러 his_clip_<sid>(t 비교 최신 승, 클라우드 실패=«이 기기에는 보관됨» 폴백) ②작업실 캔버스·담은목록은 **전부 명령형**(#clip-stage/#clip-pend, setState 중 rerender가 캔버스 지우는 것 방지 — 작업실 열려있는 동안 setState 금지 설계) ③드로어 이미지는 img src 금지 규칙대로 **data-clipimg+didUpdate 배경주입**(componentDidUpdate에 [data-clipimg] 패스). 항목={id,img,exam,qno,date,solved,t}, 재도전 성공 토글=졸업 표시(삭제 아님). ⚠️ clip_ 행은 통째 upsert(LWW 아님) — 두 기기가 같은 학생 클립을 동시 편집하면 나중 저장이 이김. 검증=실제 동지여고 기말 스캔 PDF 6p로 E2E(렌더→드래그 클립→자동+1→페이지 넘김→저장→드로어 배경주입→재도전 토글→로컬 미러) + localhost 부팅 4xx/배너 0. **남은 일(원장 승인 시)**: 오답노트 A4 인쇄(잘린 문제 자동 조판+풀이 공간), 답안카드(OMR) 판독 연동=틀린 번호 자동, 히즈 자체 시험지 자동 클립, 미해결 수 프로필 배지.
- [★Phase1 배포완료 v32.677 (2026-07-18 심야)] **히즈 트레이닝 1차**: 어휘 은행=학원일지›데이터 «🎯 어휘 은행» 카드(importVocaBank: 엑셀 붙여넣기 «영어(탭)뜻(탭)강», 3열 없으면 vb-unit 강번호 입력 사용, 같은 강=교체, delVocaUnit=«{del:1,t}») → data.vocaBank[강]={w:[[en,ko]],t} 강별 LWW(merge smallNotes 뒤). 응시=일간일지 상단바 «🎯 트레이닝» 버튼(⚡ 옆) → 최상위 모달(S.trOpen/trStep setup|quiz|done): 학생 1명+강 멀티+문항수(10/15/20) → trStart()가 오답 우선 30%(wrongBank 매칭 🔁 재도전 배지)+랜덤으로 4지선다 생성(오답 뜻 3개=같은 풀) → trPick 즉시 피드백(정답 초록 700ms/오답 빨강 1600ms) → _trFinish가 setBulk(sid,hS=맞은수,hT=문항수)로 일지 «히즈어휘» 칸 자동 기입(만점=문항수, 기존 draft 클라우드 동기화 경로) + data.wrongBank[sid|en]={n,last,s,t} 갱신(틀림=n+1·s0, 맞음=s+1, s>=2면 «{del:1,t}» 졸업) — wrongBank/vocaBank 둘 다 키별 LWW merge 기반영. rv·핸들러 전부 bulk 큰 rv(qsOpen 옆)+참조 패턴. 검증=실브라우저 E2E(은행 등록→1회차 cherry 오답 9/10 기입→2회차 재출제·재도전 성공·streak) + localhost 부팅 4xx/배너 0. **Phase2 남은 일**: 오답장 카드(종합일지), 간격재출제 고도화(last 날짜 1·3·7일 가중), 구문·문법 유형, 종이 인쇄, 태블릿 학생모드 응시(뒷4자리). 원 설계(아래) 유지.
- [★설계 최종확정 2026-07-18 심야·새 세션 «히즈 트레이닝 시작»으로 착수] **히즈 트레이닝 = 자체 시험 엔진(클래스카드 연동 대신 직접 구축, 원장 «오답 누적·재출제 애플혁신»)**: 심장=오답 루프(출제→응시→자동채점→일지 자동기입→오답 누적→다음 시험에 재출제(간격반복 1·3·7일, 맞출 때까지)). ①문항은행: 엑셀 붙여넣기 등록 — 어휘{영어,뜻,강}, 구문{영문,해석}, 문법{발문,선지,정답,유형태그}; 저장=app_state 별도 행 bank_%(스냅샷 패턴, blob 비대 방지). ②자동출제: 범위(학생별 지원)→뜻고르기 4지선다·스펠입력·어순배열 결정론 생성+선지 셔플, 구성비 새70%+그 학생 오답30%. ③응시모드: 학생모드(키오스크) 확장 — 뒷4자리→오늘 내 시험→제출 즉시 채점(태블릿/PC/스탠바이미). ④연동: 제출=setBulk 경로로 일지 시험칸 자동 기입(v674 그리드·클라우드 draft 재사용)→저장 시 마일리지·리포트·취약배지 자동. ⑤오답장: data.wrongBank[sid][itemId]={wrong,last,streak} 키별 LWW(+merge 필수)+종합일지 «오답장» 카드. ⑥종이 지원: 같은 은행에서 A4 시험지+정답표 인쇄(오답 포함, 분석노트 렌더 기술). 역할 정리: 클래스카드=학습(암기·게임) 유지, 시험·데이터=히즈. 참고: 클래스카드 결과 붙여넣기 파서는 설계까지 완료 후 원장 지시로 자체 엔진으로 선회(공식 API 없음 확인, 비공식 자동화 금지). 클래스카드 리포트 복사 텍스트 형식(파서 필요 시): 이름 줄→아이디 줄→쪽지→학습률들→«최종»→«NN 점»/«미응시». 착수 순서: Phase1=어휘 은행+4지선다 자동출제+응시모드 MVP+일지 연동 → Phase2=오답 재출제 엔진+오답장 → Phase3=구문·문법 유형+종이 인쇄. 이전 로드맵: **일일 시험 시스템(태블릿 자동채점→일지 전자동, 2026-07-18 원장 합의)**: 현장=매 수업 반마다 문법·주요구문·어휘 3종 시험(출제=클래스카드 유료, 응시=종이(학교시험 훈련 목적), 어휘는 학생별 범위 다름, 채점·전기=수기였음→v674 ⚡일괄입력+v676 관제판으로 전기 해소). **3계단 로드맵**: ①문항 은행(자동채점 선행조건 — 구문=문장+해석 붙여넣기→어순배열·빈칸 자동생성(결정론적, AI 무필요), 문법=엑셀 문항 붙여넣기{발문·선지·정답·유형태그}, 어휘=단어 리스트→4지선다 자동생성+학생별 범위 지정; 저장=app_state 별도 행(스냅샷 bank_% 패턴, blob 비대 방지)) ②태블릿 응시 모드(키오스크 학생모드 확장: 뒷4자리→오늘 내 시험→응시→제출; 브라우저 되는 아무 태블릿, 구매 예정) ③자동 연동(제출 즉시 채점→setBulk 경로로 일간일지 시험칸 자동 기입→마일리지·오답유형(wrongTypes)·취약배지 자동; examSets/submissions 병합 구조 기존재). 운영 그림=문법은 종이+⚡빠른입력 유지, 어휘·구문은 태블릿 전자동. 원칙: AI 무감수 출제 금지(Phase4=Claude API 초안+원장 감수 큐는 선택), 틀린 문항 자동 재출제(망각곡선)가 은행+채점의 핵심 보너스. 착수 순서=①부터(태블릿 없이도 종이 인쇄용으로 즉시 유용). 관련: 원장 HIS-OMR판독기.html 실험(카메라 채점 대안), 클래스카드=어휘 학습용 유지.
- [진행중] **영어 분석노트(지문분석)** — 사양서: `HIS-분석노트-사양서.md`(⚠️ 2026-07-21 바탕화면 정리 시점에 파일 유실 확인 — 디스크에 없음, 아래 규칙이 사실상 사양). **범용 템플릿 파일: `C:\Users\User\Desktop\C\C\HIS-분석노트.html`**(13~16번 지문본은 같은 폴더 `HIS-분석노트-13-16.html`) (index.html과 별개의 독립 산출물, 학생 배포용 A4 PDF). 파일 안 `DATA` 배열에 지문 객체만 추가하면 페이지 자동 증가. **지문 1~4 실제 원문 완성·출제자 감수 통과**(원장이 8지문 원문 제공함). 폰트는 고정이 아니라 `fitVars()`로 **지문 길이별 자동 스케일**(6문장=크게~12문장=작게)→어떤 길이든 항상 1페이지. 헤더 로고는 **실제 HIS 로고**(물고기 안 HIS + 눈점 + 십자꼬리 SVG + "Excellence in English, HIS" 태그라인). 렌더 검증법: node 없음 → **헤드리스 크롬**으로 스크린샷+PDF 생성(`chrome --headless=new --screenshot`/`--print-to-pdf`, `--user-data-dir`를 매번 새 폴더로 줘야 안 깨짐). ⚠️ PDF 페이지수=1이어도 `.page`가 `overflow:hidden`이라 내용 잘림을 감출 수 있음 → **반드시 스크린샷(window 820x1240)으로 마지막 문장까지 안 잘렸는지 눈으로 확인**할 것. 폰트 키우면 사양서대로 일러스트/마인드맵/노트칸/행여백을 줄여 공간 확보. **디자인 확정 사항(원장 승인)**: ①영어 청크는 양쪽정렬로 우측까지 꽉 채우고 chunk가 통째로 줄바꿈되지 않게(단어 단위만) `display:inline`+justify. ②문장성분 청크(S·V·O·C·Adv) 사이엔 `/`, 형용사/관계절(Adj) 청크는 `( )`로 감쌈(청록). ③마인드맵은 **단계=색 위계**(`STAGE` 표): 주장=빨강·반론=주황·예시=노랑·전개=초록·도입=회색·결론=딥그린, 연한 틴트카드+좌측 액센트. ⚠️ **주장의 정의(원장 확정 규칙, 모든 지문 적용)**: **주장 = 글쓴이 입장에서 전체 글을 통해 독자에게 하고 싶은 말(핵심 메시지)이 함축되어 있는 한 문장.** 이 문장을 마인드맵 빨강 `주장` 노드(최고강조) + 핵심 주제문(노란 형광)으로 **일치**시킴. 지문 속 인물/기관의 말(정부·전문가 등)은 글쓴이 주장이 아니므로 `전개`(초록, 검토 대상)나 `도입`으로 내리고, 그에 대한 반박은 `반론`(주황)으로. (지문1 실제: ①②③④=도입, ⑤⑥⑦·⑧⑨=전개(정부 해명), ⑩=글쓴이 주장=핵심주제문.) ④**쪽집게 변형문제 유형(칩) 표준 세트(원장 지정)**: 어법성 판단 / 요지·주장·주제·제목 / 빈칸 추론 / 어휘 추론 / 문장 삽입 / 글의 순서 / 밑줄 함축의미 / 요약문 완성 (+내용 일치·지칭). 각 지문 특성에 맞는 6개를 골라 `predictTypes`에 넣음(비유문=순서·삽입, 연구·해명문=요약문·빈칸 등). **남은 일: 5~8번 지문 DATA 채우기(원문은 원장이 이미 제공, 위 규칙대로 문법·주장·마인드맵·전용일러스트·쪽집게 채우고 자체 감수).**
- [참고자료·요청 시 제작] **메타인지 플로우 학습지 포맷(두 번째 확정 포맷)** — 자료: `C:\Users\User\Downloads\고2 메타인지 플로우.zip`(안에 `design_handoff_his_worksheets/`). ⚠️ **원장 지시: 지금 만들지 말고 다음에 요청할 때 이 스펙대로 제작**. 패키지 내 **`CLAUDE.md`가 전체 스펙 single source of truth**, 완성 샘플 `samples/metacognition_UNIT19.dc.html`(메타인지 플로우)·`samples/bbr_U04_P11.dc.html`(빠바 구문분석=내 분석노트와 유사), 마스코트 장면 이미지 `assets/u18~u20-scene.png`(오리지널·저작권 안전, 기존 IP 금지) + `his-logo-wide.jpg`. **메타인지 플로우 규격 요약**: A4 794×1123px, `position:absolute` 좌표, 색=forest green`#003322`/cream`#F4ECD7`/brass`#B5882F`/카드`#FFFCF2`, **Pretendard 고딕 전용**(세리프·이탤릭 X, 꼬리말 태그라인만 serif italic), **흑백인쇄 최우선**(밝은 배경+진한 텍스트, 진한 배경블록 지양), 이모지 금지. 위→아래: ①머릿말(112px 크림, 하단 2.5px#003322, 로고 `left:-21px`, 황금비 구분선 `left:531px`, 우측 타이틀블록 `left:553px`=해석컬럼선 정렬, UNIT배지+"메타인지 한 장 정리"+한글제목21px/800+유형). ②지문/해석 **좌영어:우해석=7:3**(flex 7/1px디바이더/flex 3), ❶❷ 번호(brass 700) 1:1, **둘 다 justify**, 영어 14px/줄간격2.4, 해석 10.5px/줄간격 조절로 **두 단 바닥선 줄맞춤**, 핵심요지 문장 1개 양쪽 하이라이트 `#FBEAC0`(text`#4A3A12`). ③메타인지 전개요소 카드 3~5개(지문에 있는 것만 순서대로) — **고정색: 도입`#1F5C8A`·전개`#1B7A47`·예시`#2E8B82`·반론`#7A4A8C`·주장`#B23A2C`·결론`#8A6520`**(밝은 배경+상단 3px룰+배지+영어 어휘칩, 카드>4개면 칩 2개로). ④하단 마스코트 장면 이미지(좌 약64%)+글의 요지 카드(우, `#FFFCF2`+브라스룰, 한글1문장+영어1문장 고딕). ⑤꼬리말 우측정렬 `Excellence in English in HIS`(serif italic#73531A)+`히즈어학원 · <회차>`. 빠바 SVOC 색: `.s{#003322}·.v{#1F5C8A}·.o{#8A6520}·.sc{#7A4A8C}·.m{#4A5147}`. 여러 장 PDF: `.page` 래퍼+`padding-bottom:297mm`+`@page{size:210mm 297mm;margin:0}`.
- [✅ 2026-07-21 확정 12장] **현관 게시판 리뉴얼 A4 12장**: 바탕화면 `C\HIS-게시판-리뉴얼` 폴더(`HIS-게시판-인쇄용-12장.pdf`+원본 HTML+미리보기 12장). 원장 «선생님 사진 다 빼고 애플·스타벅스» + «OT 내용 빼지 말고 게시판에» + «월간·성적도 실물로» — ①브랜드 선언판(v2 원장 문구: «영어 실력은, 성실함에서 자랍니다.» / 크레도 T. Dana · T. Joey · T. Benjamin) ②커리큘럼(E→M→H→A→HA, 45+45분, A/B반 요일, 금=NUAE·클리닉) ③독해 4단계 사이클+한 권의 영어책 ④문법 4단계+히즈 온라인 3종 ⑤리딩 리마스터(확정 문구·RM 회차코드) ⑥시험대비(내신대비집·지문분석·역설계·4주 로드맵, «너는 문제 없어, 영어가 문제집.») ⑦등하원 ⑧성장 리포트(일간 실물+EXAM MODE D-day 스트립 목업: 앱 v711 규격 #FBEFEA 바탕·위아래 붉은 헤어라인·좌 아이브로/라벨·우 D-값 세리프 27px nowrap) ⑨월간 성장일지(실물 2컷=OT 슬라이드21 크롭: 영역별 성장 비교+성취평가표) ⑩성적 성장일지(실물 1컷=OT 슬라이드22 크롭: 추이·시험표·취약유형·1년성장). ⑧⑨⑩=원장 지시로 **딥그린 배경**(표지와 같은 그라데이션+SINCE 2014 텍스트 헤더, 리포트 크림 실물이 OT처럼 도드라짐 — 크림 배경으로 되돌리지 말 것) ⑪히즈 트레이닝 ⑫장학마일리지. ②~⑥·⑨·⑩은 OT 슬라이드 25장에서 추출(SWOT·강사평가 상세=내부용 제외, 수강안내·EDIYA 장=원장 지시 삭제). 리포트 실물 이미지 추출법=OT를 헤드리스로 열어 ArrowRight로 해당 슬라이드 이동 후 전체 스크린샷→PIL 크롭(숨김 템플릿이라 element.screenshot 불가). ⚠️ 원본 HTML의 로고는 110px로 다이어트됨(1.6MB 원본을 페이지마다 중복 삽입하면 17MB 됨). 재생성=scratchpad board_render12.py 패턴(playwright .page 스크린샷+pg.pdf). 서류 2칸=원본 의무 게시 유지.
- [✅ 2026-07-20] **유튜브 채널 리뉴얼 패키지**: 저장소(hisbooks) 안 `HIS-유튜브-리뉴얼` 폴더 — 채널배너 2048×1152(안전영역 1235×338 중앙 설계, v2=원장 지시로 SINCE 2014 세리프 아이브로+blog.naver.com/his-language+골드 이중 프레임·다이아 포인트의 럭셔리 플라크), 프로필 2종(A=딥그린+골드 물고기 추천/B=크림), 썸네일 템플릿 3종(①강의·해설=크림 ②시험분석=딥그린 ③현장스토리=사진+크림카드, 1280×720), 채널 적용 미리보기 목업, 적용가이드.md(채널 소개문 포함). 대상=youtube.com/channel/UC7vOZSIP0ffzskrWccqgiXw(@hislanguage, 구독 1.39천). 재생성=원본HTML/build_yt.py(HTML→playwright 렌더). 로고 자산=HIS-장학마일리지-안내판/assets 골드 워터마크 알파마스크 재틴트(green/gold/cream 투명 PNG, 원본HTML/assets). ⚠️ 워터마크 물고기 scaleX(-1) 반전 금지(HIS 글자 거울상). 원장 업로드 대기(YouTube Studio→맞춤설정→브랜딩).
- [✅ 실적용 패키지 완성 2026-07-14] **네이버 블로그 홈페이지형 스킨** — 산출물: `C:\Users\User\Desktop\C\히즈\블로그·홍보\네이버세팅\HIS-네이버블로그-스킨\`(최신 확장본은 `Desktop\C\HIS-네이버블로그-스킨\`)(00-미리보기 · 01-타이틀배너 966×560 · 02-위젯코드 5개 · 03-모바일커버 800×1120 · 적용가이드.md). 대상=blog.naver.com/his-language, 실제 카테고리번호 **ROOM=1·BOOKS=23·FLOW=8·RADAR=15**(m.blog API로 확인). **위젯 이미지 5종은 저장소 `blog/` 폴더(GitHub Pages, 340px=170표시 @2x)로 호스팅 — 위젯직접등록 코드가 참조하므로 파일명·경로 변경 금지**(5/5 라이브 200 확인). 로고 워터마크는 태그라인 어중간 잘림 방지 위해 **물고기만 크롭**(알파 행스캔으로 블록 분리, fish-green/cream.png) — 다른 산출물에도 이 패턴 권장. 경쟁 벤치마크=blog.naver.com/pkf78(«대단한 영어», 포항 이동 — 매일 적중분석+학교명 SEO 도배 전략). 문구·글 수 바뀌어 재생성 필요하면 적용가이드.md 하단 «관리 메모» 참고. 원본 자료 zip: `C:\Users\User\Desktop\C\히즈\블로그·홍보\학원 블로그 디자인 리뉴얼.zip`(README-원본사양·사진·OT 이미지 포함), 원장 제작 24MB 블로그 홈 시안: `C:\Users\User\Desktop\C\히즈\블로그·홍보\히즈어학원 블로그 홈 (단일파일).html`. 대상=네이버 블로그 `blog.naver.com/his-language`(수능/입시+초중등 영어 HIS). 폴더 내 **`README.md`가 전체 스펙 single source of truth**(디자인 토큰·화면구성·네이버 적용 가이드 다 있음). 시안 3종 중 **시안 A(Ivory Editorial, 웜 아이보리 매거진풍)=채택**(`HIS 블로그 리뉴얼 시안.dc.html`의 맨 왼쪽 프레임). PC 타이틀배너 산출물=`HIS 타이틀배너 PC 966.dc.html`(966×300, 크림 #F3ECD6 배경+안쪽 테두리+"수능·내신·초중등 영어 전문" eyebrow+그린 로고 184px). 로고 PNG 2종=`assets/his-logo-green.png`(밝은배경용)·`his-logo-cream.png`(다크배경용). **핵심 색**: green-900 `#003322`·green-700 `#0D5B3E`·ink `#1D2B22`·body `#5C5A52`·muted `#9A8F6E`·cream `#F4EED8`·bg-page `#FAF6EC`·bg-banner `#F3ECD6`·border `#E6DCBF`. **폰트**: 국문 Pretendard, 영문 디스플레이/슬로건 Cormorant Garamond(주로 italic). ⚠️ **네이버 현실 제약**(README): 커스텀 코드 주입 불가 → 디자인은 (1)PC 타이틀배너 이미지 966px (2)모바일 커버 이미지 (3)메뉴/카테고리 구조(학원소개·수능내신·초중등·수강후기·입시칼럼·공지) (4)스킨 배경 아이보리 `#FAF6EC` 단색으로 "떨어뜨려" 적용. 자체 랜딩페이지로 갈 경우엔 README대로 풀 구현 가능. **미확정(작업 전 원장 확인)**: 실제 전화번호·상담시간·카톡채널, 최종 카테고리, 실제 수업 사진(현재 플레이스홀더). 렌더 검증=`.dc.html`은 support.js(Design Component 런타임) 필요 → 헤드리스 크롬으로 스크린샷/이미지 산출.
- [ ] (추후) 판매용 멀티테넌트(학원별 완전 데이터 분리=Phase B). 현재는 Phase A 단일blob+UI잠금.

## 8. 구조 검사기 + 알림톡 서버 일원화 (2026-07-29, v33.005~014)

### 8-1. 구조 검사기 `_check/his-check.py` — **앱 수정 후 반드시 실행**
```
py _check/his-check.py          # 검사   /  --save 기준선 갱신  /  --all 전체 나열
```
«통과 — 새 코드는 깨끗합니다» 나오면 커밋 가능. 기준선(`_check/baseline.json`)은 **코드 내용 지문(sha1)** 으로
식별해 무관한 편집에 흔들리지 않음. 규칙 7종: R0 파일 무결성 / R1 학생 명단 직접 읽기 / R2 시간표 직접 읽기 /
R3 기기 간 합치기 누락 / R4 복제 화면 불일치 / R5 프레임워크 함정(인라인 화살표 onclick·img src 보간) /
R6 앱 밖 서버 규칙 누락. **현재 기준선 = R1 16건 + R2 5건**(기존 부채, 새 코드는 0).
실제로 이 검사기가 작업 중 `alertBlock` 병합 누락을 먼저 잡아냄.
정본 함수: 학생 명단=`visibleClasses`/`_schedClasses`, 시간=`_classStart`/`_classEnd`.

### 8-2. 전수 조사에서 나온 구조적 구멍(우선순위)
①퇴원 예정 학생 화면 부재(수정됨 v33.013) ②상담 기준 2개(수정됨 v33.013) ③앱↔서버 규칙 이중화(수정됨 v33.014)
④반 명단 직접 읽기 88곳 vs 정본 17곳 ⑤시간표 직접 읽기 ~21곳 ⑥복제 마크업 3벌×4블록
⑦오답노트 `clip_` 행만 병합 없음 ⑧학생 id 중복(기존 미해결). ④~⑧ 미착수.

### 8-3. 알림톡 서버 일원화 (v33.014, **원장 Deploy 완료 확인**)
**발견한 실전 위험**: 옛 서버 `classStart(c,w)`가 `sessions`를 **인자로도 안 받아** 「이번만 휴강」·보강 이동을
전혀 못 봄 → 휴강한 날에도 미등원 알림 발송되는 상태였음(옛 코드 실행으로 확인).
**수정**: 서버가 `sessOv`(휴강 off/보강 start·end)·`hasMakeup`(개인 보강)·`alertBlock` 반영.
판정부를 순수함수 `pickTargets(data,dateStr,w,nowMin)`로 분리(테스트 가능).
**이중 안전망**: 앱 `_writeAlertBlock(dd,date)`가 매일 `data.alertBlock[날짜]={sids,closed,t}`에
«오늘 보내면 안 되는 학생»(시작 전·퇴원·접수대기·휴강반·개인보강)을 기록 → 서버가 추가로 뺌.
**명부는 빼기만 하므로 과발송 방향으로 갈 수 없음**(앱이 안 돌면 서버 자체 규칙만 작동 = 현행 이하로 안 나빠짐).
merge는 **합집합 + closed OR**(LWW 아님 — 어느 기기든 「빼라」면 빠짐, 순서 무관 격리검증).
검증법=`index.ts` 원문에서 판정부 추출→TS 표기 제거→Playwright 브라우저 실행, 13시나리오
(평상시/휴원일/휴강/보강이동/개인보강/등원완료/결석예정/되돌림/퇴원/명부제외/명부휴원/구형식/번호없음) 전부 통과.
서버 코드 사본: `C:\\Users\\User\\Desktop\\C\\_tools\\히즈-알림톡-서버-코드.txt` (배포는 원장이 대시보드에서 직접).

### 8-4. 같은 기간 UI 변경
v33.006 「내 학생 한눈에」를 「오늘의 관제」와 같은 한 박스 카드로 + 필터 칩 줄 제거(타일 클릭이 필터 역할, 재클릭 해제)
+ 「최근 하락」 타일 신설(칩에만 있던 기능 이전). v33.010 미상담 경보 **8주(56일)** — 목표는 4주지만
경보는 8주(리포트가 매달 나가는 학원이라 6주면 상시 점등). 「관리 필요」 신호 임계값도 56일로 통일.
v33.011 미상담 타일 금색→**경고 붉은색**(금색=장학마일리지 등 «좋은 것» 색이라 경보에 부적합, 원장 지적).
v33.009 상담을 **학생/학부모로 구분 저장**(`counsel.who`) — 토글·질문뱅크 분리·이력 라벨·「학생 N일 전 · 학부모 N일 전」;
**옛 기록은 임의로 학생으로 몰지 않고 「상담」으로 둠**. v33.008 상담 입력칸 위 작성 가이드(관찰→조치→확인 3단,
피하기 예시는 실제 반복되던 문장 사용). v33.012 **반 삭제로 보관함(`leftStudents`)에 들어간 퇴원생도
「이번 달 퇴원」에 집계**(원인: 학생관리가 반 명단만 봄, 「· 삭제된 반」 라벨 표시).
v33.013 「퇴원 예정」 KPI 타일+필터+상시 행 배지(예약 퇴원이 처리일까지 안 보이던 문제), 미상담 계산에서
**내용 빈 상담 기록 제외**(종합 화면 카운트와 기준 일치) + 종합 헤더 「마지막 상담」 줄.

### 8-5. 다음 후보
B(경계 상태 표준 시드: 퇴원·반삭제·시작전·휴원일·보강·접수대기 한 벌로 전 화면 회귀),
④⑤ 정본 함수로 정리(검사기 목록 순서대로), 상담 3칸 구조+조치 버튼(실행되는 조치)+학부모 카톡 초안 자동생성.

### 8-6. 등록·퇴원 동기화 사고 종결 (2026-07-29 심야, v33.021~031)
**한 뿌리**: 학생의 등록 상태(pending/registeredAt/startPlan)·퇴원 상태(withdrawn/withdrawPlanned)가
**타임스탬프 없이** 병합돼 옛 사본이 계속 이김 → 등록 확정 되돌아감·퇴원 예정 증발·공지 중복이 전부 이것.
**수정 사슬**(중간 실수 포함 — 반복 금지):
①v33.021 wdT / v33.022 enrT 도장 도입 ②그러나 병합에서 enr 블록이 intakeT 병합 **앞**에 있어 되덮임 → v33.029 «상담 병합 뒤»로 이동
③받을 때(_absorbFresh)는 아예 통째 덮어씀 → v33.027 학생별 enrT/wdT/intakeT 가드 추가
④날짜 입력칸 24곳이 oninput(글자마다 저장→커서 튐→8/29 오염) → v33.030 onchange
⑤시작일 수정(onEnrollStart)이 enrT 미도장이라 병합에서 짐 → v33.031 도장 추가
⑥구버전 기기가 도장까지 복사한 오염 사본 = 동률 → v33.031 동률이면 «이 기기(방금 누른 쪽)» 승.
**영구 게이트 3종 — 앱 수정 후 모두 실행**:
`py _check/his-check.py`(구조 7규칙) · `py _check/his-seed.py`(경계상태 46항목) ·
`py _check/his-sync.py`(**실제 mergeAppData+_absorbFresh 추출 실행**, 다기기 15시나리오 — v33.030에서 2건 검출 실증).
⚠️ 학생 객체에 **편집 가능한 필드를 새로 추가하면 반드시**: 도장(T) 찍기 + mergeAppData LWW + _absorbFresh 가드 + his-sync 시나리오 추가.
⚠️ 운영 전제: 구버전이 캐시된 기기는 새로고침 전까지 재오염 가능(키오스크는 새벽 자동 리로드, 급하면 ?hisreset=1).

### 8-7. 학생 id 중복 대참사 + 반 이동 유령 종결 (2026-08-03~04, v33.032~041)
**사고**: 같은 내부 id를 공유하는 학생들(§3 기존 알려진 오염)을 id 기반 병합·정리 코드가 «같은 학생»으로 취급 →
①신규생(최영서·최윤영)의 8/4 시작일이 기존원생 7명에게 복사(«곧 함께하는 학생»에 기존원생 등장)
②신규생 항목 자체가 기존원생 항목에 흡수돼 소멸 ③유령 사본이 무관 학생 보관함 기록을 이름-정리로 삭제.
**수정 사슬**:
- v33.032~033 `stuClass[sid]={cid,t,nm}` 소속 LWW 도장 — 반 이동 유령 부활 근절(merge 끝+absorbFresh 양쪽 강제, 도장 없는 중복은 home+pending+enrT 가중 스코어로 정리)
- v33.034 보관함 자동정리를 이름→id 기준으로
- v33.035 `_fixStartGhost()` 자동 수리: records/checkins/exams/counsels first-seen 근거로 기존원생에 잘못 붙은 미래 시작일 자동 제거(부팅 +1.2s)
- v33.036 **이름 게이트 전면 적용**: mergeFn·absorbFresh·소속 강제·중복 정리 모두 «이름 다르면(공백 제거 비교) 불간섭» — **id 기반 학생 병합/정리 코드는 반드시 이름 게이트 필수(재발 방지 핵심 규칙)**
- v33.037 «기존 원생» 수동 확정 버튼 → v33.040에서 UI 제거(선생님 혼동, `markExistingStu`는 콘솔 비상용 잔존)
- v33.038 «백업에서 학생 되찾기»: 데이터 탭 자동 백업 카드 → `recoverStudentFromSnap()`이 `__hisSnap.list/get`로 최신 15개 스냅샷에서 이름 검색 → **새 uid 부여**해 접수 대기로 복원(재충돌 방지). 최영서·최윤영 실복원 완료.
- v33.039 보고함 «답변»/«답글 달기» 통합 — 답변 전용 편집기 제거, 대화 스레드(답글) 하나로(옛 r.reply는 읽기 전용 표시 유지)
- v33.041 **[첫 수업] 공지 중복 근절**: `_firstDayNotice` 키가 `'all|'+uid()`(무작위)라 도장 미동기 기기 2대가 각자 생성→합집합 2개. 키를 `'all|fd_'+학생id+'_'+날짜` 결정론으로(어느 기기든 같은 키=1개) + 부팅 시 내용 동일 중복 자동 정리. ⚠️ **자동 생성 공지·기록의 키는 반드시 결정론(대상+날짜)으로** — uid() 키+도장 조합은 다기기에서 반드시 중복남([신규 등록] v33.019와 같은 뿌리).
**게이트 확장**: his-sync에 ⑭ 같은 번호 다른 이름 3종(섞임·삭제 금지) — 현재 26 시나리오. his-check R0에 dc-script `new Function` 문법 검사(괄호 하나로 앱 전체 사망하는 사고 배포 전 차단).
**미해결 뿌리**: 중복 id 재배정(records 연결 위험, 원장과 함께 진행 필요 — §3 경고 그대로).

### 8-8. SINCE 정책 확정 + 학생 여정 카운터 (2026-08-04, v33.042~046)
- v33.042 홈 미등원·휴원 배너를 home-wrap 안으로(데스크톱서 420px 고아 배너 정합) — `.home-alert` 클래스+미디어쿼리.
- v33.043~044 **SINCE(등록일) 2차 사고 복구**: _fixStartGhost가 기존원생 등록일을 «첫 활동일(6/26)»로 채워 SINCE 오염 →
  v33.043 스냅샷 복구는 «백업도 오염이면 실패+완료도장» 결함 → v33.044 `_fixSinceLocal()` **결정론 복구**(백업 불필요):
  시그니처 = 등록일 존재 + enrT≥2026.08.03 + 등록일<2026.08.03 + 등록일==첫 활동일(4소스 각각/최솟값) → 등록일 삭제(SINCE=상담일 복귀),
  07.28+ 등록확정일도 삭제. **매 부팅 실행·자연 멱등(도장 없음)**. ⚠️ 일회성 복구에 localStorage 완료도장 금지 — 실패해도 도장 찍혀 죽는다.
  **정책 확정(원장)**: 기존 학생 SINCE=상담일 / 신규 학생(오늘부터)=시작일(confirm 2곳 startPlan 우선) / 상담 기록은 «기존원생 증거» 아님(_fixStartGhost서 제외 — 신규생도 상담 있음).
- v33.045 **학생 여정 카운터**(원장 승인): `_stuOwnRecs(data,sid,name)` = 학생 기록 전 반 통합 + **id중복 게이트**(같은 번호·다른 이름 학생이 있는 반의 기록 제외).
  일간 캡처카드 «수업 N회차»→**«함께한 N번째 수업»**(결석 제외·보강 포함·반 이동 이어짐), 종합일지 lifetimeAgg 누계 전 반 통합(결석 포함 유지=출석 분모).
  반 회차(선생님 일간일지 상단)·월간 «수업 총 N회»·성적 추이는 불변. ⚠️ 학생 기록을 id로 전 반 스캔하는 새 코드는 _stuOwnRecs를 쓸 것(직접 filter 금지).
- v33.046 함께한 수업 **100단위 MILESTONE 스트립**(캡처카드, WORD ASSET 앞) — 100·200·300 되는 날 하루만 자동 표시·다음 수업엔 소멸. rv `s.sesMile`.
- **v33.123 (원장 검수 요청)**: 학생별 회차를 **`_stuSessN`(서로 다른 날짜 수)** 로 통일 — 같은 날짜 기록 두 벌
  (반 이동 잔재)이 회차를 부풀리던 결함 수리. 기준 확정: 학생 회차 = 전 반 통합·결석 제외·카드 날짜까지의
  **날짜 수** / 반 회차(`_sessionForDate`) = 반 단위 날짜 순번 — 서로 별개 숫자.
  ⚠️ 학생 수업 수를 세는 새 코드는 기록 개수 count 금지 — `_stuSessN` 사용(중복 기록 방어).
- **v33.125 (원장 승인 시안)**: 캡처카드 «오늘 수업 내용/다음 수업 과제» = **2열**(1:1.15, 가운데 →),
  본문 16px 유지 + **행잉 인덴트**(rv `lessonLines`/`prepLines` 줄 배열 → sc-for, pre-wrap 한 덩어리로는
  항목별 행잉 불가). 제목 짙게(#0C4631/#6B4F14) 16px + 밑줄 2px. 우상단 원위치 강조: 날짜 세리프 21px,
  «함께한 N번째»의 숫자만 골드 세리프 19px+골드 밑줄, 회차 없으면 sessionLabel 폴백(sc-if `hasSessionN`/`noSessionN`).
  v33.124 에서 상단 «회차» 입력칸 제거(자동 계산이라 불필요 — session 자동 저장은 유지).
- v33.039 보고함 답변/답글 통합, v33.040 «기존 원생» 버튼 제거, v33.041 [첫 수업] 공지 결정론 키 — 8-7 참조.
- v33.051~052 **캡처카드 내보내기 폭 고정(원장 확정)**: «황금비 자동 맞춤»(_capFit data-capgold, 폭≈높이×0.618) 전면 제거 — 내용 길이 따라 이미지 폭이 매일 흔들리던 원인. 일간·월간·종합·성적·신규진단 통지서 전부 680px(data-capw, v33.053에서 통일). **원칙: 학부모 발송 이미지는 폭 고정·높이만 가변(인스타 피드 방식) — 새 캡처카드에 data-capgold 붙이지 말 것.**

### 8-9. 키오스크 차임 지연 — 종결 선언 뒤집힘 (2026-08-06, v33.057)
**v32.714 «~130ms는 webOS 바닥, 코드 수정 금지» 결론은 틀렸다.** 실기기 로그 7차 + 코드 전수 재조사(4축 병렬)로 확정:
- **근본 원인**: `_tickPlay`가 차임을 `ac.currentTime + _lead`에 예약하는데 `_lead = max(outputLatency, baseLatency*2) + 30ms`.
  **outputLatency는 «예약된 소리가 그래프를 떠난 뒤» 출력 장치까지 걸리는 시간** — 예약 시각에 미리 더하면 상쇄가 아니라 이중 계상.
  실제 체감 = `_lead + L = 2L + 30ms`. TV(L168) 기준 **366ms**였다. 로그에는 L만 찍혀서 이 두 배를 아무도 못 봤다.
  → `_lead = baseLatency`(최소 6ms·최대 120ms)로 수정. TV 211ms(**155ms 단축**), 오프라인 렌더 발음 6ms(v32.645 문서값 복원, 직전엔 최소 50ms 바닥).
  ⚠️ **예약 여유(lead)에 outputLatency를 넣지 말 것** — v32.645가 «6ms, 다시 키우지 말 것»이라 적어둔 것을 지연치유 작업(v32.662~714)이 되살린 회귀였다.
- `_adiag`(localStorage 읽기-수정-쓰기)가 소리보다 **먼저** 실행되던 것을 뒤로 옮김(임계 경로 제거).
- 진단 라인 확장: `s`(sampleRate) `d`(실제 예약 여유) `p`(손끝→예약 ms), 버전 도장 **V746→V756**(V746은 v32.746 이후 방치돼 판별 불능이었음).
- **로그 판독 규칙 정정**: `V`는 독립 토큰이 아니라 `I` 줄에만 붙는 종속 리터럴이고, `I`(유휴 리셋)는 `!__hisKiosk`라 **키오스크에선 원리적으로 안 찍힘**. `K`=키오스크 keepalive 표식. 즉 **«V 없음 = 옛 버전»은 오독**이며 K 기기가 곧 키오스크다.
- 힐(재생성)이 L168에서 한 번도 안 뜬 이유: 지연 힐 문턱이 **절대 500ms** 하나뿐(v32.714에서 중간대역 은퇴). I 직후 궤적 4회가 모두 176~200ms로 단조 수렴 → «빠른 엔진 뽑기» 재기각, L40은 «아직 측정 안 된 값».
- v33.058 **진단 신뢰성 3종**(적대적 심사 지적): ①버전 도장을 **모든 줄에 상시 인쇄(V758)** — `I`는 `!__hisKiosk` 조건이라 키오스크에선 원리적으로 안 찍혀 «수리가 그 기기에 갔는지»를 확인할 수 없었다(v32.698 오판 구조가 그대로 남아 있었음). ②`d`/`p` 토큰 오염 제거 — `_tick` 진입 시 키마다 초기화(무음 숫자키 줄이 직전 차임 값을 재인쇄하고 있었음). ③`_kioskWakeRelease`의 `_acKeep.stop()` → `.src.stop()`(없는 메서드라 keepalive가 정리되지 않던 버그).
  ⚠️ **계측을 새로 붙일 땐 «그 값이 어느 줄에 찍히는가»부터 확인할 것** — 종속 토큰(I)에 매달면 정작 필요한 기기에서 사라진다.
- **실측으로 확인된 나머지 사실**: 앱 내부 지연(pointerdown→소리 예약)은 **1~2ms**로 이미 최적. 대신 **화면 렌더가 느리다** — 키패드 숫자 1개당 화면 반영이 데이터 0KB에서 32ms, 830KB에서 **156ms**(=키를 누를 때마다 전 데이터를 훑어 앱 전체를 다시 그림). TV에서는 수백 ms. **다음 개선 후보 1순위.**

### 8-9b. 키오스크 키패드 지연 — 진짜 원인은 «1.2초 타이머의 전체 복구 루틴» (2026-09-05, v33.147~150)
**원장 신고**: 스탠바이미 등하원 키패드 반응이 너무 느림. §8-9 가 «소리»를 종결했지만 «화면»은 미착수였다.
**CPU 프로파일러 실측으로 밝힌 원인 4개** (추측으로는 절대 못 찾았을 것 — 1·2위가 예상 밖이었다):
1. **[최대] 저장상태 표시용 `_saveIv`(1.2초 폴러)가 매 틱마다 데이터 복구 루틴 전체를 재실행**하고 있었다.
   `_fixStartGhost·_fixDupRoster·_fixFakeNew·_fixSinceLocal` 를 매 틱 새로 setTimeout 예약(쌓임) + 
   `_fixOnce931·_scrubMisCopied973·_guardNotStarted979·_dedupPending·_firstDayNotice` 를 동기 실행.
   이들은 전부 `JSON.parse(JSON.stringify(data))`(800KB 통째 복제) + 전수 스캔이다 → 메인스레드 상시 포화.
   키 입력이 느린 게 아니라 **누를 때마다 이미 바쁜 스레드에 착륙**하고 있었다.
   → 10분 1회로 제한(`_repT9`) + **키오스크 중에는 정지**. 헤더 `offsetHeight` 강제 레이아웃도 키오스크 중 생략.
2. `renderVals` 무가드 대형 계산 18곳(classReport·dashAgg·bulkRows·homeKpi·compRows·manageStudents·
   adminData·schedMonthCal…) — 키오스크에서도 매 렌더 계산. → `const _kio = (S.kiosk === true)` 로 스킵.
   ⚠ **비키오스크 경로는 코드가 완전히 동일**(`_kio ? 기본값 : 원식`)이라 일반 화면 회귀 위험이 원리적으로 0.
3. 키오스크가 별도 뷰가 아니라 «오버레이»라 **배경 화면이 계속 렌더**되고 있었다(startKiosk 가 view 를 안 바꿈).
   → 뷰 플래그 16개(isHome·isBulk·…·isAdminCheckin)에 `!_kio` → DOM 1,629노드 → 173노드.
4. `recordFor` 가 인덱스 없이 records 전수 `.find` → **WeakMap<data,{len,map}> 인덱스화**(`_smCache` 선례).
   앱 전체(일간일지·홈·학생관리) 공통 이득. 첫 일치 우선 의미 보존, records 길이 변화 시 재구축.
5. 1~3번째 숫자는 **리렌더 자체를 안 함**(`_kFast`): `state.checkinDigits` 를 직접 갱신 + 점만 명령형 칠하기.
**실측(6배 CPU 스로틀, 810KB)**: tDom 484.9→**3.3ms** · tPaint 889.8→**39.6ms** · 데이터 영향 **5.69배→1.00배**.
⚠ **명령형 갱신은 «단일 소유»여야 한다** — 처음엔 점 스타일을 템플릿 보간(`{{ d.fill }}`)으로 두고 명령형으로도
칠했더니, clear 후 React 가 «내가 마지막에 그린 값과 같다»고 판단해 DOM 을 안 고쳐 **점이 남는 잔상 버그**가 났다
(E2E 가 잡음). 해결=템플릿에서 보간을 빼 React 가 점 스타일을 아예 관리하지 않게 하고, `_paintDots()` 를
`_kFast` 와 `componentDidUpdate`(키오스크일 때만) 양쪽에서 호출해 어떤 렌더 경로로 와도 상태와 일치시킴.
⚠ **성능 추정 금지 — 프로파일러부터**: 처음엔 renderVals 를 범인으로 보고 수리했는데(그것도 실제 이득),
CPU 프로파일이 진짜 1위(복구 루틴 폭주)를 따로 지목했다. «메서드를 no-op 으로 바꿔 시간 차이를 보는» 귀속법은
renderVals 가 예외로 조기 종료해 **가짜 절감**이 나오니 쓰지 말 것 — CDP `Profiler` 를 쓸 것.
⚠ 이 저장소는 키패드에 **del 키가 없다**(1~9·0·clear·enter). E2E 에 없는 키를 넣지 말 것.
하니스: `scratchpad/kio_perf.py`(tSync/tDom/tFrame/tPaint+rvMs, `--cpu 6` 이 TV 근사), `kiosk_e2e.py`(20항목),
`ab_profile.py`(before/after 동일 세션 A/B). 진단 도장 **V765 → V33150**.

### 8-9c. 앱 전체 속도 검수 (2026-09-05, v33.151~152) — 화면별 실측 기준선과 4개 구조 수리
**측정법**: `scratchpad/app_perf.py` — 821KB(학생 64·기록 2,560·시험 708·상담 192) 시드, 6배 CPU 스로틀, 화면별
`renderVals()` 1회 + «setState 1회→DOM 반영» 중앙값. 수리 전→후(ms): 월간 입력 **5,138→1,140**(DOM 6,269→1,726노드),
선생님일지 **6,473→2,926**(rv 1,126→445), 일간 974→411(rv 334→105), 홈 473→355(rv 490→176), 성적 360→244,
학생관리 rv 795→403. (TV 근사값이며 PC 실측은 약 1/6.)
**수리 4개** (비키오스크 경로 코드 동일성 원칙 유지 — 가드는 전부 `조건 ? 기본값 : 원식`):
1. **기록·시험 인덱스 `_ri(data)`** — WeakMap<data,{n,ne,cs,ss,es}>(반|학생·학생·시험(학생)), `_recsCS/_recsS/_exsS`.
   monthAgg·studentMileage(미스 경로)·getSinceDate·_stuOwnRecs·examsFor 의 전수 `.filter` 를 인덱스 조회로.
   ⚠ 인덱스 배열은 **공유 객체** — 반드시 `.filter()`/`.slice()` 로 새 배열을 만든 뒤 `sort` 할 것(examsFor 가 그 예).
2. **`monthAgg` 결과 캐시** — data 신원+records 길이+(반|학생|월) 키. 본체는 `_monthAggRaw` 로 이름 변경.
   호출부(monthlyItems)가 결과 객체에 속성을 덧붙이므로 **얕은 복사로 반환**. 인덱스만으로는 안 줄던 이유:
   비용의 본체가 필터가 아니라 기록당 `mileageDetail`×20회 `num`(렌더 1회 83,736회 호출)이었다 — 포함시간 계측으로 확인.
3. **화면별 계산 가드** — classReport(일간만)·dashAgg(종합일지만: dash* 소비처가 isManage)·monthSet/compMonthList(월간만)·
   manageStudents/Classes(종합일지만)·bulkRows(일간만)·homeKpi(홈만). 소비처는 템플릿 sc-if 스택 스캔으로 확인했으나
   **미닫힘 sc-if 3개(isAdminStudent·isAdminSchedule·isSchedule)** 때문에 그 이후 구간은 스택이 오염됨 — 스캔 결과를
   맹신하지 말고 기존 rv 게이트와 교차 확인할 것.
4. **월간 숨은 캡처카드 게이팅** — 반 전원 카드(학생당 ~650노드)를 늘 렌더하던 것을 `ms.capOn`(활성 학생·전송 큐 현재
   학생·복사 대기 학생)만 렌더. 우측 패널은 카드 DOM 을 renderVals 중 읽으므로 **카드가 생긴 «다음» 렌더가 필요** —
   componentDidUpdate 에서 `_mcapSeenA/_mcapSeenQ` 로 id 당 1회만 `_monthlyRenderKey` bump(무한루프 방지).
   행 «복사»는 카드가 없으면 `_mcapRetry` 에 닫힘 저장 + 활성 전환 후 didUpdate 에서 재호출(onCopy 를 `const fn` 형태로).
   ⚠ 기존 `_cduMain(_, prevState)` 의 prevState 는 런타임이 인자 1개만 넘겨 **undefined** — 그 안의 `_monthlyRenderKey`
   갱신 로직은 죽어 있었다(전 카드 상시 렌더라 티가 안 났음). 새 재읽기 로직은 prevState 에 의존하지 않는다.
**기타**: tierInfo 의 52KB 엠블럼 배열 리터럴 → `this._tierT` 캐시(호출마다 재할당하던 GC 압력 제거).
componentDidUpdate 의 `[data-clipimg]` 스캔은 clipOpen 일 때만, `_resizeMonthlyComments` 는 월간·일간에서만.
**남은 병목(미착수)**: 선생님일지·학생관리의 1,244 DOM 노드 템플릿 재조립(보드 타일 64개+달력 42칸) — 남은 2.9초(6배)의
대부분. 일간일지 숨은 캡처카드(`#cap-{sid}` 전원)도 월간과 같은 방식으로 게이팅 가능하나 §3 캡처 함정(id 중복·_capEl
이름 매칭)이 있어 별도 E2E 설계가 선행돼야 한다.
검증: `monthly_e2e.py`(17항목: 활성 카드 1장·전환·비활성 행 복사·큐 5명 전환·복귀) + `kiosk_e2e.py`(20항목) + 게이트 6종.

### 8-22. 성적 성장일지 — 시험 종류별 추이 분리 + 시험명 자동 유지 (2026-09-05, v33.153, 원장 지시)
- **추이 3분할**: `examAgg` 에 `trendCats`(모의고사 #0C4631 / 학교시험 #8A6520 / 학원시험 #2B6CB0, 데이터 있는 것만) —
  성적 탭 차트는 `<sc-for ex.trendCats as tc>` 로 종류별 카드. 기존 단일 `trendPath/hasTrend` 는 호환용으로 유지.
- **분류기 `_examCat(e)`**: `category` 가 3종이면 그대로, 아니면 시험명 키워드로 추론(중간·기말·내신→학교시험 /
  학원·단원·주간·리마스터·어휘·구문·문법·레벨→학원시험 / 기본 모의고사). ⚠ OMR 자동채점 기록은 `rec.category = es.name`
  (시험 **이름**)으로 저장되는 구조라 분류기가 필수 — category 를 3종 enum 으로 믿지 말 것.
- **시험명 자동 유지**: 새 기록 저장 후 초안이 `category·date·total` 만 남기고 `title` 을 비우던 것을 title 도 유지 →
  같은 반 다음 학생으로 바꾸면 시험 4항목이 그대로, 점수만 입력. 폼에 안내 문구 + **같은 학생 중복 입력 경고**
  (`exDupWarn`: 같은 시험명(+날짜)이 이미 있으면 붉은 배너, 수정 모드에선 미표시).
- 시험명 예시: «26년 9월 고1 전국연합학력평가 / 26년 2학기 중간고사»(성적 탭), 정답키 모달도 동일 예시.
- 검증: `exams_e2e.py` 14항목(3분할·분류기·저장 후 유지·학생 전환·중복 경고·예시) + 게이트 6종.

### 8-10. 유령 반 재발 근절 (2026-08-06, v33.060)
**증상**: 삭제한 반(«포항동지여고 2학년»)이 학생 6명을 담은 채 계속 되살아남 — 여러 번 지워도 재발.
**근본 원인 = 삭제 표식 무력화 구멍 2개**:
- `mergeAppData`의 deletedClasses strip에 `(!c.students || c.students.length===0)` 가드가 있어
  **학생이 담긴 옛 사본은 표식이 있어도 살아남았다.** 그래서 클라우드가 영원히 안 씻기고 매번 부활.
  → 표식 있으면 **무조건 제거**하되, 안에 있던 학생은 `leftStudents`(보관함)로 이관해 «되살리기» 가능하게 보존.
- `_absorbFresh`에는 **삭제 표식 처리가 아예 없었다** → 12초 폴링이 받은 사본을 그대로 적용.
  → merge와 동일 규칙 추가(합집합 표식 + 학생 보관함 이관).
⚠️ **삭제 표식(tombstone)에 «안전 가드»를 달면 표식이 무력화된다** — 지켜야 할 것은 «데이터 보존»이지 «삭제 취소»가 아니다.
보존은 보관함 이관으로 하고, 표식 자체는 무조건 존중할 것. (deletedStudents는 이름 게이트 O, deletedClasses는 가드 X가 정답)
**게이트**: his-sync에 ⑮ 유령 반 6종 추가(올릴 때·순서 무관·받을 때·보관함 보존) → **29항목**.
운영: 자동 정리(`_purgeGhost0804`)는 «전원이 타반에 동명 재원»일 때만 실행하고, 아니면 보류 안내만 —
실제로 그 6명은 타반에 없어 보류가 정상 동작이었음. 정리는 원장이 반 카드 «삭제»→명단 확인→보관함 이관 확정.
- v33.064 **간헐 1초 멈춤(p 스파이크) 제거**: 실기기 로그 8차에서 V758·d43 적용 확인, 평시 p4~7ms 정상이나
  «직전 체크인 뒷정리·유휴 복귀 동기화가 다음 학생 타이핑에 착륙»할 때 p974~p1519. 수리 3종 —
  ①doCheckin 깊은 복제(1.5MB×2/회)→변이 맵 3개(checkins·bdayCele·tierCele)만 얕은 복제(64→3ms, GC 쓰레기 소멸)
  ②_tick의 죽은 __his_lbest 저장소 RMW 제거 ③_adiag 저장소 기록은 setTimeout(0), 클라우드 동기화는 60ms→8초+얕은 복제.
  ⚠️ **setState 업데이터에서 JSON.parse(JSON.stringify(전체)) 금지(핫패스)** — 변이 필드만 얕은 복제(변이 전수조사 필수).
  ⚠️ 키 입력 핫패스에 localStorage 읽기·쓰기 넣지 말 것(webOS는 동기 디스크 IO).

### 8-11. 키오스크 차임 — 종결 (2026-08-06, v33.066, 원장 지시)
**결론: 이 기기에서 «즉각적인» 차임은 웹 코드로 불가능하다.** 앱 내부 지연은 p1~p7ms로 이미 최적이고
(_lead 이중 계상 제거 v33.057 + 핫패스 정리 v33.064), 남은 것은 `L=136~176ms`의 webOS 출력 파이프라인 —
이건 앱이 손댈 수 있는 값이 아니다. 원장 지시로 **차임을 끄고 성공 화면이 확인을 담당**하도록 종결.
- `data.kioskChime`(기본 false=꺼짐) + `kioskChimeT` 스칼라 LWW 병합, `_tickPlay` 진입부에서 차단(엔진 무손상).
- 되돌리기: 학원일지 › 등하원 › 학생 모드 카드의 «소리 꺼짐/소리 켬» 스위치.
⚠️ **버전 도장은 릴리스마다 반드시 올릴 것** — v33.064에서 안 올려 «수리가 TV에 들어갔는지»를 로그로 판별할 수
없었다(같은 실수 v32.698). 현재 V765.
⚠️ 이 건으로 «지연을 없앴다»는 주장 금지 — 남은 지연은 하드웨어 상수이며, 필요하면 TV 음향설정(음향모드 표준·
AI사운드 OFF·내장 스피커)이 유일한 레버.

### 8-12. 자동 «지각»이 안 먹던 구멍 (2026-08-23, v33.068)
**증상**(원장 신고): 22:45 등원(수업 22:30 시작)인데 일간일지 출결이 «출석»으로 남음.
**원인 3종** — 전수 재현으로 특정:
1. **저장 뒤 등원**: `loadDraft`가 저장된 기록이 있으면 그 값을 그대로 돌려주고 `autoAttendance`를 아예 안 물어봄.
   선생님이 수업 시작 때 일지를 저장해 두면, 그 뒤 학생이 늦게 와도 «출석»이 고정.
   → **등원 기록 시각 `ck.t` > 일지 저장 시각 `editT` 이면 자동 출결로 갱신**(등원 뒤 선생님이 직접 고른 값은 editT가 더 최신이라 불간섭).
2. **저장본 출결이 빈 값**이면 자동값도 무시 → 비어 있으면 자동값 채움.
3. `_classStart`는 «요일이 수업일일 때만» 시각을 주므로, **요일 시간표 없이 `c.startTime`만 있는 반은 항상 «출석»**
   → 지각 판정에 한해 `c.startTime` 폴백(휴강 오버레이면 제외).
⚠️ **자동 판정값을 저장된 기록에서 다시 계산할 땐 «시각 비교»로 선생님 의사를 지킬 것** — 마커 없이 덮으면 수동 선택이 사라진다.
⚠️ 지각 기준은 여전히 **정시**(lateMin=0 하드코딩). 반별 «지각 기준(분)» 입력칸은 판정에 미반영 — 유예를 원하면 별도 작업.
**his-seed 자정 가드 양방향화**: 23:20 이후 / 00:00~01:30 에는 «지금을 감싸는 수업시간»을 만들 수 없어(자정 넘김)
관제판·안전망 계열 7항목을 건너뛴다(그 시간대 실행 시 확인 39항목). 앱 무죄는 «00:00~01:00 창» 별도 검증으로 확인.

### 8-13. 시험 D-day 학교 기준 전환 (2026-08-27, v33.069, 원장 승인)
**배경**: 포항H1_B.T처럼 여러 학교가 섞인 반은 반 단위 examDday로 표현 불가 — 시험일은 «학교의 사실».
**구조**: `data.examSchool[학교키]={label,date,end,on,name,t}` 키별 LWW(+his-sync ⑯). 계산은 `_examCalc(레코드)`로 일원화.
- `_examDdayStu(data,cid,stu)` = 학생 학교 우선. ⚠️ **폴백은 «그 학교 레코드가 아예 없을 때만»** — 레코드가 있는데
  계산이 null(시험 끝남·대비 전)이면 반 공통으로 내려가지 않는다(남의 학교 시험이 카드에 찍히는 사고 차단).
- `_examDdayClass(data,c)` = 반 종합(최임박 + «외 N건», 퇴원·pending·시작전 제외).
- 소비 재배선: 학생 단위=캡처카드 4키 / 반 단위=홈 수업행·일간 상단바·반 카드 배지(각 3) / 파생 5곳(주간 칩·월간·홈 미니·주간 일정 2벌).
- 입력: 반별 일정 카드 «학교별 시험» — 그 반 재원생 학교 자동 수집, **학교명 타이핑 금지**(표기 갈라짐 방지),
  onchange 저장(v33.030), 학교줄에도 «대비 전·D-N [대비 시작]»(armExamSchool). 반 공통 칸은 폴백용으로 유지.
- `_schoolKey`: 공백 제거 + 접미 축약(여자고등학교→여고 등) + **끝 학년·반 토큰 제거**(«한울고 2-3»=«한울고등학교2학년»=«한울고»,
  교명 중간 숫자 «제철3고»는 보존). ⚠️ 과정규화 금지 — 지역 접두(동지고/포항동지고)는 다른 키로 남김(사용자 병합은 2차).
⚠️ **rv 계산부에서 `var self=this` 금지 구간 주의**: 홈 미니·주간 exEvs 등 `function(){}` 스코프에서는 this가 컴포넌트가
아니라서 rv 전체가 조용히 죽는다(pageerror 0인데 화면 빔 — 이번에 홈·주간 전체 사망으로 실측). 헬퍼는 로컬 함수로 인라인할 것.
**2차 전부 적용 완료(v33.070, 원장 번복 후 지시)**: 학년 예외 examSchoolG[학교키|학년](있으면 공통보다 우선, _stuGrade) · 관리자 «학교 시험 한눈에» 카드(반별 일정 상단, 미입력 상단·임박순, 행 편집+[학년별]+[표기 통일]) · 종료일 자동 +3일(endAuto) · by 기록 · 반 공통 «미기재 N명 적용» · 반 단위 val에 «+N»(조각 렌더 대응) · unifySchool(학생 school 일괄 정정+intakeT, 레코드 이관). 기존 목록 참고: 학교+학년 분리 키 / 종료일 자동 +3일 / 학교 시험 한눈 표 / 최종 수정자 표기 /
반 공통 칸 «미기재 학생 N명에게 적용» 카운트 / 표기 갈라진 학교 병합 UI.

### 8-14. 시험일 입력 창구 단일화 (2026-08-27, v33.071~073, 원장 승인)
**원칙 확정: «쓰는 곳 하나, 보는 곳 여럿»** — 시험일 입력은 «학교 시험 한눈에» 카드 한 곳뿐.
- v33.071: [첫 수업] 공지 톰스톤 존중(삭제하면 재생성 금지 — del 키도 «존재»로 취급), 한눈 표 학교명 클린(_schoolDisp),
  선생님도 자기 반 스코프(visibleClasses)로 한눈 표 사용([표기 통일]은 관리자 전용), 3열 카드 그리드(auto-fill 400px).
- v33.072: **학교 시험 파생 표시 = 월간 일정에만**(원장 지시) — 주간 칩·홈 주간·오늘/다가오는 일정 주입 제거.
  판정(배지·리포트 EXAM MODE)은 캘린더와 무관하게 전부 유지.
- v33.073: 반 카드의 시험 입력칸 전부 제거 → 읽기 전용 요약 한 줄
  ([학교별 D-day/미입력 배지] [학교 미기재 N명, 툴팁=학생 이름] [반 공통(이전) 값+관리자 «비우기»] [입력 안내]).
  기존 examDday 값은 판정 폴백으로 계속 작동. examSchools rv 등 구 입력용 rv는 미사용으로 잔존(무해).
⚠️ **같은 데이터의 입력 UI를 두 곳 이상 만들지 말 것** — 우선순위 규칙을 설명해야 하는 순간 설계 실패.
⚠️ 반 카드 시험 요약은 «일정 설정» 펼침 영역 안에 있음(E2E 검증 시 펼친 뒤 확인).

### 8-15. 시험일 입력 경로 전수 감사 (2026-08-27, v33.074~078)
원장 신고(«날짜칸에 1,2 같은 값이 저장되고 미입력 배지가 사라짐») → 입력 경로 4축 병렬 감사(에이전트 53개),
후보 48건 중 **실제 결함 31건 확정** → 3배치로 전부 수리.
- **v33.074**: 미입력 판정을 «글자 있음»→«유효한 날짜(_examNorm)», 미완성 값에 빨간 힌트(값은 보존), 정렬 고정(입력 중 카드 이동 제거).
- **v33.075 배치A(핵심 3뿌리)**:
  ① `_examDdayStu`가 레코드 «존재»만으로 폴백을 막던 것 → **유효하고 살아있을 때만** 사용.
     (미완성·라벨만·만료 학년예외 → 다음 단계로 자연 폴백. 학년 만료 시 학교 공통으로, 학교 무효 시 반 공통으로)
  ② `examSum`(반 카드 칩)이 학년 예외를 무시하고 _examCalc 기준으로 «미입력»을 찍던 것 →
     `_examRecFor`/`_examChip` 공용 헬퍼로 판정 통일, 상태 4종(D-day/대비 전/지난 시험/미입력)+«외 N건».
  ③ **`_absorbFresh`에 exam 3종이 없었음**(철칙 위반) → 키별 LWW 추가 + 시험 저장은 즉시 persist.
     (전: 입력 직후 12초 폴링이 걸리면 값이 사라졌다 되돌아옴 — «분명히 입력했는데» 의 정체)
- **v33.076~077 배치B(입력 정확성)**: `_examNorm` 자릿수 상한·실달력 왕복검증·연도 밴드
  (2026.10.123→10.23 둔갑, 2026.02.31/6.31/11.31 통과하던 것 전부 거부),
  종료일 endBad 힌트+endAuto는 유효할 때만 해제+날짜 비우면 자동종료 정리,
  `_schoolKey` 꼬리 확장(괄호·슬래시·«N년»·«가반», 숫자만 남으면 미기재), 이름표는 저장된 name 우선.
- **v33.078 배치C(가시성·이관)**: 한눈 표 상태 배지 3종(대비 전 D-n/지난 시험/학년 일부 N/M),
  학년만 채운 학교가 «미입력»으로 뜨던 것 해소, unifySchool이 examSchoolG 이관+학생 반 표기 보존,
  월간 캘린더에 학년 예외 주입.
⚠️ **판정 함수에서 «레코드 존재»로 early-return 하지 말 것** — 유효성·생존까지 확인해야 폴백이 살아난다.
⚠️ **새 편집가능 맵은 merge와 _absorbFresh 양쪽에** — 한쪽만이면 폴링에 값이 사라진다(his-sync ⑱로 고정, 39항목).

### 8-16. 모의고사 자동채점 — 틀린 유형 누락 + 반 무관 채점 (2026-08-29, v33.106~107)
**게이트 신설 `_check/his-exam.py` — 채점 코드를 고치면 반드시 실행**(실제 채점 코드로 학생을 채점해 검증, 현재 27항목).
- **v33.106**: 자동채점(`applyOmr`)·손입력(`setExamAnswer`) 둘 다 문항 유형(`q.type`/`q.group`)을 안 써서
  **틀린 유형이 전부 빈칸**이었다 — 점수·등급은 정확했기에 겉으로 정상으로 보였고, 성적표 «틀린 문항 유형»·
  종합일지 약점 막대·«취약 ○○ ×N» 배지·이탈위험 판단이 전부 죽어 있었다(손입력 시험만 채워짐).
  두 경로 모두 수집(같은 유형 두 번 틀리면 두 번 셈), 미응답도 오답, `_gradeOf` 상한을 9등급으로(10등급이 나오고 있었음).
- **v33.107 (원장 지시: «성적은 반에 상관없이 생년월일 기반, 등록된 모든 학생 기준»)**:
  - 판정을 **`_omrMatch(dd, 생년월일)`** 로 분리(게이트가 실제 코드로 검사 가능). 대상=**등록된 모든 학생(반 무관)**.
  - ⚠️ **같은 생년월일 학생이 둘이면 조용히 «마지막 학생»에게 채점되고 있었다** — 같은 학년 30명이면 생일이 겹칠
    확률 ~70%다. 이제 겹치면 **채점하지 않고 겹친 이름을 안내**(동명이인 장부 v32.655와 같은 원칙).
  - 퇴원생이 재원생의 점수를 가로챌 수 있던 것 → 재원생 우선, 퇴원생만 맞으면 안내만.
  - `examAgg`·`getSinceDate`·`copyExamReport` 가 «지금 열려 있는 반»에서만 학생을 찾아 다른 반 학생이면
    이름·학교·등록일이 빈칸 → `_stuById`(전 반 조회) 폴백.
  - 성적 탭 학생 목록에 «다른 반이지만 성적 기록이 있는 학생»을 반 이름과 함께 추가 —
    **`visibleClasses` 범위 안에서만**(선생님은 자기 반만, 담임 스코프 유지).
  - 손입력 시험 기록의 `classId` 가 «그때 열려 있던 반»으로 찍히던 것 → 학생의 실제 반으로.
⚠️ **이름·생년월일 같은 «사람 식별자»로 학생을 찾는 코드는 반드시 중복 가드**를 둘 것 — 하나만 고르고 넘어가면
조용히 엉뚱한 학생에게 기록이 들어간다(동명이인 v32.655, 학생 id 중복 §8-7, 생년월일 v33.107 — 같은 뿌리).

### 8-17. 일간일지 코멘트 문구 엔진 (2026-08-29, v33.108~109, 원장 지시)
**지시**: «일간일지 코멘트 추천을 등하원 추천문구처럼 오은영·김창옥 어투로, 명언·세계 감성문구·통찰 문구로».
**전**: `suggestComment`/`suggestBulkComment` 가 모든 학생·모든 날에 **똑같은 6문장**을 찍었다
(«출결 관리에 조금 더 신경 써 주세요 / 과제 수행을 독려 부탁드립니다» — 사무 문체, 책임을 학부모에게 넘기는 말).
다시 눌러도 같은 문장이라 «추천»의 의미가 없었다.
**후(`_cmtDraft`, 등하원 `_autoMsg` 와 같은 구조)**: ①상황 9종(첫수업·결석·지각·과제미완·상승·하락·저조·우수·평상)별
관찰 문장 ②오은영·김창옥 어투의 «아이를 향한 시선» ③상황에 맞는 명언·세계 속담 36편(출처 표기).
이름은 조사까지 맞춰 부르고(`_nmJosa` — 민준이는 / 지혜는), `_cmtPrev` 로 직전 기록과 비교해 오르내림을 읽는다.
결정론(같은 학생·같은 날=같은 초안) + `_cmtTick` 으로 **다시 누르면 다음 변주**. 60일 연속 서로 다른 문장 56개.
- ⚠️ **여러 갈래를 한 해시에서 뽑을 땐 꼬리표를 앞에 붙일 것** — `base+suf` 로 하면 세 갈래가 같은 중간값에서
  갈라져 조합 수가 lcm 으로 줄어든다(실측 60일 중 28개만 달랐음). `suf+'|'+base` 로 고쳐 56개.
- 카드(`_cmtSplit`): 코멘트 **마지막 줄이 «문장 — 출처» 꼴이면** 얇은 구분선 아래 세리프 이탤릭으로 분리.
  실렌더 전에는 명언이 선생님이 쓴 네 번째 문장처럼 읽혔다. 손으로 쓴 코멘트도 같은 꼴이면 똑같이 인용문이 된다.
- **명언은 출처가 확실한 것만** — 고전(노자·공자·맹자·아리스토텔레스·괴테·루소·유클리드·안중근)과
  나라별 속담, 확인되는 근대 인용(에디슨·헬렌 켈러·마리 퀴리·아인슈타인·피카소·헨리 포드·존 셰드·
  제임스 볼드윈·마틴 루서 킹)만 썼다. 널리 도는 오귀속(«하버드 도서관», 대나무 4년 등)은 뺐다.
  ⚠️ 새 문구를 넣을 땐 출처를 반드시 확인할 것 — 학부모에게 나가는 글이다.
**게이트 `_check/his-comment.py` (14항목)** — 조사 정확성 48조합·상황별 문구·60일 반복률·인용문 분리.
### 8-20. 성적 추이 심화 — 월간 성적 줄 + 상담 약한 유형 (2026-08-30, v33.113, 지난 회의 1·2단계)
- **착수 전 실측 교훈**: 종합일지 카드(profilecap)에는 «시험 성적 추이» 그래프가 **이미 있었다**.
  처음 조사가 76KB 캡처 구획의 앞 26KB만 훑어 «없다»고 오판 → 흐름 줄을 넣었다가 같은 카드에 같은
  데이터 세 벌이 놓인 걸 실렌더로 확인하고 걷어냈다(rv·헬퍼까지 — 죽은 코드 안 남김).
  ⚠️ **큰 캡처 구획(profilecap 76KB 등)을 조사할 땐 구획 끝(END CAPTURE 주석)까지 읽고 판단할 것.**
- **월간 일지 카드(monthcap)**: `monthAgg` 에 `mExam` — «성적 | 시험 N회 · 평균 M점 (100점 환산) ·
  지난달보다 ±k점» 한 줄(그 달 시험 없으면 미표시). `ms.m.*` 로 직접 흐르므로 매핑 함정 없음.
  ⚠️ **월 키 형식이 화면마다 다르다** — `monthlyMonth` 는 `2026-08`(대시), 시험 날짜는 `2026.08.23`(점).
  월 비교는 숫자만 남겨서(`replace(/[^0-9]/g,'')`) 할 것 — 실제로 이걸로 한 번 어긋났다.
- **상담·진단 화면**: 상담 기록 패널 머리에 «자주 틀리는 유형: 어법 4회 · 어휘 2회» 한 줄
  (`st.cslWeak`, 마크업 3벌). 패널이 열려 있을 때만 examAgg 호출(닫힌 행 렌더 비용 0).
- 3단계(내신 시험 전후 비교)는 미착수 — examSchool 날짜 기준 대비 효과 분석, 1·2단계 쌓인 뒤.

### 8-21. 학생 3중 복제·전원 신규 배지·수강료 납입 기록 소실 (2026-08-31, v33.116, 원장 신고 3건)
**증상**: 포항동지여고 6명이 장부에 3번씩 · 기존 학생 전원에 «신규» 배지 · 1~7월 장부 이상 + 7월 납입 기록 소실.
**결함 A**: `addRoster`(일괄 등록)가 **이미 재원 중인지 확인하지 않고** 모든 줄을 새 학생(새 id,
registeredAt=오늘)으로 생성 — 재붙여넣기마다 전원 복제, 사본은 «신규» 배지, id가 달라 같은-id 정리에 안 걸림.
**결함 B**: 같은 id 다반 정리가 merge에만 있고 `_absorbFresh`에 없었음.
**결함 C**: fees 병합이 달 단위 «over 통째 승»인데 **시각 도장이 없어** 다른 기기의 빈 스캐폴드
(`{paid:'',status:'미납'}` — 장부 칸만 건드려도 생성됨)가 채워진 납입 기록을 덮었고,
받을 때는 학생 fees 가드가 **아예 없어** 오염이 12초 폴링으로 전 기기 전파.
**수리**: ①등록 가드(이름+`_schoolKey` 정규화 학교 — 표기 갈린 «동지여자고등학교2학년»=«동지여고» 매칭,
건너뛴 이름 안내) ②`_fixDupRoster` 부팅 청소 — **기록 있는 사본 하나 남기고 기록 전무한 빈 사본만**
보관함 이관+삭제 표식(기록 있는 사본 둘 이상=동명이인 가능성 → 불간섭) ③absorb 같은-id 정리 패리티
④fees `t` 도장(setFee·toggleFee·doMergeFee) ⑤병합=도장 LWW+무도장 동률은 «내용 있는 쪽 승»
⑥absorb 학생 fees 달별 병합. his-sync 9항목 추가(47→**56**).
⚠️ **사람이 반복 입력하는 모든 대량 입력구(붙여넣기·가져오기)는 반드시 기존 재원 매칭 가드** —
장부 동명이인(v32.655)·생년월일(v33.107)과 같은 뿌리. 학교 비교는 `_schoolKey`로.
⚠️ **레거시 무도장 맵(fees처럼)의 병합에 «최신 승»을 붙일 땐 무도장 동률의 승자 규칙을 «내용»으로** —
빈 스캐폴드가 이기는 순간 기록이 소리 없이 증발한다.
**v33.118 (원장 신고: 최민경·소승현 퇴원생 되살아남)**: v33.116 청소의 잔여 구멍 — 원본이 퇴원이면
재원 그룹에 빈 사본만 남아 «하나는 남긴다» 규칙으로 살아남았다. 보완: 같은 이름+학교의 퇴원 이력
(퇴원 학생·보관함)이 있으면 기록 없는 빈 재원 사본을 **전부** 이관(그룹 크기 1 포함).
재등록 보호: 사본 등록일 > 퇴원일이면 남김. ⚠️ «하나는 남긴다» 류 규칙은 반드시 퇴원·삭제 이력과 대조할 것.
**v33.119 (원장 신고: 7월 기록 소실·1~5월 가짜 기록)**: ①결제선생 붙여넣기 **달 검증** — 결제일 과반이
장부 달과 다르면 반영 안 하고 안내(엉뚱한 달 기록 차단) ②데이터 탭 «수강료 기록 복구·정리» 카드 —
[1~5월 기록 지우기](빈 값+새 도장으로 지워 병합 부활 차단, confirm) / [백업에서 납입 기록 채우기]
(`__hisSnap.list/get` 최신 12개, 2026.06 이후 **빈 칸만** 채움, 절대 안 덮음).
⚠️ fees 를 «지울» 땐 키 삭제 금지 — 달 합집합 병합이라 옛 사본이 되살린다. 빈 값+새 t 도장으로.
**v33.120**: 채우기가 보관함(leftStudents) 사본의 snap.fees 까지 훑어 이름+`_schoolKey`로 재원생에 복원
(중복 사본 행에 적은 납입 기록 회수 경로) + 스냅샷 한도 30·snap_before_restore 포함.
**v33.121 (가짜 신규 배지)**: 26.08.04 등록일 = 8월 초 도장 사고가 기존 학생에게 찍은 잔재 →
`_fixFakeNew`(매 부팅 멱등): 2026.08.01 이전 활동이 있는 학생의 사고 구간(08.03~05) 등록일·확정일·
시작일 삭제 + enrT 재도장. 진짜 신규(이전 활동 없음·구간 밖)는 불간섭.

### 8-19. 일간일지 코멘트 = 감성 한 줄로 전환 (2026-08-30, v33.111, 원장 지시)
**지시**: «학습평가는 할 필요 없고, 언어의 온도·모든 순간이 너였다·여덟 단어·모리와 함께한 화요일·
사랑의 기술·소년과 두더지와 여우와 말·고요할수록 밝아지는 것들·나는 나로 살기로 했다·혜민 스님 책·
전세계 베스트셀러·오은영·김창옥·드라마·영화 작가들의 멘트처럼 인생을 통찰하는 감성 한 줄로 매번 다르게».
- v33.108~109 의 «관찰 + 시선 + 명언» 세 겹을 **한 줄 하나**로 교체. 상황 분기(결석·지각·과제·상승·하락)
  **전부 제거** — 출결이든 점수든 코멘트는 달라지지 않는다(학습평가를 안 하므로). 성적·출결은 카드의
  다른 칸이 이미 다 보여 준다.
- 문장 **188편**(`_cmtLines`). 고른 자리 = `(이름·번호 해시 + 그 학생의 누적 수업 수 + 다시 누른 횟수) % 188`
  → 같은 날 같은 반이어도 학생마다 다르고, 한 학생은 **188회 수업 동안 한 번도 안 겹친다**(게이트로 실측).
- ⚠️ **저작권 원칙(고정)**: 지시하신 책들은 저작권이 살아 있다. **그 안의 문장을 그대로 담아 매일
  학부모에게 보내면 안 된다.** 그래서 «그 책들의 어투와 결»로 직접 쓴 문장만 담았고 출처를 붙이지 않았다.
  게이트에 «출처(— 이름)를 붙인 인용문이 섞이지 않음» 항목을 두어 나중에 누가 책 문장을 붙여넣지 못하게 막았다.
  (v33.109 의 고전 인용 36편 — 노자·공자 등 저작권이 지난 것 — 은 이 전환으로 함께 빠졌다.)
- 제거된 것: `_cmtPools`·`_nmJosa`·`_recPct`·`_cmtPrev` (죽은 코드 남기지 않음). `_cmtSplit`(v33.109)은
  남아 있지만 한 줄 코멘트는 갈라지지 않는다 — 선생님이 손으로 «문장 — 출처» 꼴을 쓰면 그때만 동작.
- **v33.112 원장 정정: «구루·현자가 학생한테 전달하는 내용이지 부모한테 하는 말이 아니다.»**
  v33.111 은 문장이 학부모를 향해 있었다(아이는… / 오늘 아이를 안아 주세요…). 188편 전부
  **학생에게 직접 건네는 말**로 다시 썼다 — 반말, 스승의 어투, 판단하지 않음.
  결: 자라는 일과 시간 / 실패와 두려움 / 너 자신 / 배우는 태도 / 사람과 세상 / 오늘과 삶.
  ⚠️ **이 자리는 학생에게 하는 말이다.** 문구를 더할 때 «아이·부모·주세요» 같은 3인칭·부모 대상 표현과
  존댓말 종결(습니다·입니다·해요·세요)을 쓰지 말 것 — 게이트가 막는다.
**게이트 `_check/his-comment.py` 재작성 (13항목)** — 한 줄 여부·길이·**학습평가 안 함(출결·점수 바꿔도 동일)**·
**학생에게 건네는 말(부모 대상 표현·존댓말 종결 없음)**·다시 누를 때마다 다름·학생마다 다름·
한 바퀴 무중복·평가 낱말 없음·출처 인용 없음.

### 8-18. 일간일지 «이전 과제 확인» — 기본 펼침 + 표시 유실 (2026-08-30, v33.110, 원장 지시)
**지시**: «이전과제 확인이 자동으로 펼쳐진 상태가 안 되면 보고서 전송할 때도 안 보인다, 기본이 펼쳐진 상태로».
**재현해 보니 세 겹이었다**:
- `loadDraft` 가 `hwCheck` 를 **아예 만들지 않아** 일간일지를 열면 늘 비어 있었다(학생마다 버튼을 눌러야 보임).
- 저장할 때만 `_autoHwCheck` 가 채워서 **화면에는 없는데 학부모 카드에는 나왔다** — 선생님이 확인할 방법이 없음.
- `loadDraft` 가 **저장된 `hwCheck` 도 안 읽었다.** 항목마다 완료·일부·미완을 매겨 저장해도 다시 열면 사라지고,
  그대로 다시 저장하면 `_autoHwCheck` 가 다시 돌아 **전부 «완료»로 덮었다**(항목 하나는 통째로 사라짐 — 실측).
  안 해온 과제가 학부모에게 «완료 ○»로 나가는 상태였다.
**수리**: `loadDraft` 가 ①저장된 `hwCheck` 복원 ②없으면 `_autoHwCheck` 로 직전 회차 과제에서 자동 생성
③`_autoHwCheck` 는 `d.hwCheck` 가 **아예 없을 때만** 실행(다 지운 목록도 뜻으로 존중)
④**`getDraftBulk` 가 손대지 않은 행은 `loadDraft` 로 폴백** — 이게 없으면 화면에 자동으로 뜬 항목을 누르는 순간
`getDraftBulk` 가 `undefined` 를 돌려 **목록 전체가 «{status}» 한 줄로 덮였다**(실측).
⚠️ **화면에 그려진 값과 «손댄 값»이 다른 곳에 있으면 반드시 폴백을 둘 것** — `bulk.rows` 만 읽는 헬퍼는
자동 생성·기본값으로 그려진 행에서 빈 값을 돌려주고, 그 위에 쓰면 보이던 것이 통째로 날아간다.
⚠️ 캡처카드는 `<input value>` 안의 글자를 `innerText` 로 못 읽는다 — 화면 검증은 입력칸 값을 직접 읽을 것.
**게이트 `_check/his-homework.py` (14항목)** — 기본 펼침·버튼-항목 짝·표시 유지·재저장 비덮어쓰기·결석 제외·
다 지운 목록 존중·학부모 카드 노출. 새로고침 후 **진짜 클릭**으로 확인한다.

⚠️ **미해결(별건)**: 월간 코멘트의 규칙 기반 폴백(`makeRuleBased`)에는 아직 옛 사무 문체가 남아 있다
(평소엔 AI 생성이 쓰이고 실패했을 때만 나온다). 자동 결석으로 `gOn` 이 꺼진 뒤 출결을 출석으로 되돌려도
`On` 플래그는 복구되지 않는다(v32.691 이후 계속된 동작 — 점수·마일리지 전반에 영향).
