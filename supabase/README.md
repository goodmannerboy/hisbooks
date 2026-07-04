# 미등원 자동 알림톡 — 배포 안내

미등원(수업 시작 지났는데 등원 체크인 없는 학생)을 **10분마다 자동 감지 → 학부모에게 카카오 알림톡**(문자 자동 대체) 발송. 한 학생당 하루 1회, «결석 예정» 학생 제외.

- **두뇌(감지·판단·중복방지)** = 이 함수 `functions/noshow-alert/index.ts`
- **발송관(카카오/통신사)** = 솔라피 (카카오 공식 대행사, 코드로 대체 불가)

## 원장님 준비물 (솔라피에서 발급)
| 값 | 어디서 |
|---|---|
| `SOLAPI_API_KEY` / `SOLAPI_API_SECRET` | 솔라피 → API Key |
| `SOLAPI_SENDER` | 등록한 발신번호 (예: `0541234567`) |
| `SOLAPI_PFID` | 카카오 채널 발신프로필 ID |
| `SOLAPI_TEMPLATE_ID` | 승인된 «미등원» 알림톡 템플릿 ID |

**알림톡 템플릿 문구(카카오에 제출):**
> [히즈어학원] #{학생이름} 학생이 수업 시간이 지났는데 아직 등원하지 않았습니다. 확인 부탁드립니다.

## 배포 순서 (Claude가 옆에서 도와드림)
1. **DB 셋업** — Supabase 대시보드 → SQL Editor → `setup.sql` 실행 (`<PROJECT_REF>`·`<SERVICE_ROLE_KEY>` 실제 값으로)
2. **함수 배포** — `supabase functions deploy noshow-alert` (Supabase CLI, 로그인 필요)
3. **비밀키 설정** — `supabase secrets set SOLAPI_API_KEY=... SOLAPI_API_SECRET=... SOLAPI_SENDER=... SOLAPI_PFID=... SOLAPI_TEMPLATE_ID=...`
   ⚠️ 실제 키 입력은 **원장님이 직접** (보안상 Claude가 키를 다루지 않음)
4. **테스트** — 미등원 1명 상황 만들고 함수 1회 호출 → 카톡 도착 확인. (키 없으면 함수는 "DRY-RUN"으로 대상만 계산)

## 동작 규칙 (앱과 동일)
- 수업 시작시각 = 선생님 일지 **시간표**(`schedule.times[요일].start`) 기준, **지각기준 정시(0분)**
- 정시 지남 + 등원 체크인 없음 + `noShowExcused`(결석예정) 아님 + 학부모 연락처 있음 → 발송 대상
- `noshow_alerts` 테이블로 하루 1회 중복 방지
