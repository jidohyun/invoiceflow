# Sprint 4 킥오프 노트

| 항목 | 내용 |
|---|---|
| **기간** | 2026. 5. 19. ~ 2026. 6. 1. (2주) |
| **Sprint ID** | 103 (board 34) |
| **목표** | 모바일 앱 MVP 진입, Pro 플랜 기능, 현지화·세금계산서 |

---

## Sprint 3 회고 한 줄 요약

7일 안에 AMI-84~87 4건 + /qa 회귀 4건을 모두 처리해 **테스트 254 → 296 (+42), 회귀 0건, Health score 91 → ~99**로 마감. Sprint 3는 `state=closed`, Sprint 4는 `state=active`.

---

## Sprint 4 스토리 & 작업 양 사전 조사

| # | 스토리 | 백엔드 작업량 | 외부 의존 | 위험도 |
|---|---|---|---|---|
| AMI-88 | 모바일에서 송장 관리 | **거의 0** — `/api/v1` 이미 완성 (`auth/register`, `auth/login`, `invoices` CRUD, `dashboard`, `analytics`) | FCM/APNs 키 발급 | 🟢 낮음 |
| AMI-89 | QR코드 현장 결제 | **중간** — "즉시 송장" 액션 + QR 생성 (`eqrcode` lib) + Paddle 결제 링크 즉시 발행 | Paddle (이미 통합) | 🟡 중간 |
| AMI-90 | 해외 통화 송장 | **중간** — ExchangeRate API 클라이언트, `Invoice.amount_krw` 환산 캐시 컬럼, 대시보드 합산 KRW 환산 | ExchangeRate.host API | 🟡 중간 |
| AMI-91 | 한국 전자세금계산서 | **큼** — 코드 0줄. 홈택스 API 클라이언트, 3.3% 원천징수 계산, `tax_invoices` 테이블, 발행 비동기 워커 | **홈택스 sandbox + 공인인증서** | 🔴 높음 |

### 권장 우선순위
1. **AMI-90 (해외 통화)** — 외부 의존(환율 API)이 단순 GET, 캐싱 무난
2. **AMI-89 (QR 결제)** — Paddle 이미 통합되어 있음, QR은 라이브러리 1개로 끝
3. **AMI-88 (모바일)** — 백엔드 거의 0이라 모바일팀 작업 지원만
4. **AMI-91 (전자세금계산서)** — sandbox 발급 절차가 길어 sprint 첫날 신청부터 시작, 막히면 stub-only 상태로 deferred 후보

---

## Sprint 4 진입 전 정리 결과

- [x] Sprint 3 (id 70) `closed` 전환, incompletes → backlog (0건)
- [x] Sprint 4 (id 103) `active` 전환, AMI-88~91 4건 자동 포함 확인
- [x] `project_status.md` 메모리 2026-05-18 기준으로 갱신
- [x] 296 tests GREEN, `mix compile --warnings-as-errors` 무경고
- [x] main ahead 0, push 동기화

## Sprint 4 첫날 To-Do (제안)

1. **홈택스 sandbox 신청** — AMI-91이 막힐 위험이 가장 크니 첫날 신청 → 답변 1~3 영업일 소요
2. **ExchangeRate API 키 발급** — exchangerate.host / openexchangerates.org 둘 중 선택
3. **`invoices.amount_krw` 마이그레이션 설계** — Invoice 단위 KRW 환산 캐시 (대시보드 집계 가속)
4. **`tax_invoices` 스키마 초안** — Invoice 1:1 관계, `nts_confirm_no`(국세청 확인번호), `withholding_tax_amount`
5. **Android/iOS 카운터파트 동기화** — AMI-88은 거의 모바일팀 단독 작업, 백엔드는 검수 PR만

---

## 메모

- /qa 자동화 회귀 패턴은 3차에서 검증됨. Sprint 4 진입 후 큰 변경(특히 AMI-91 세금계산서) 머지 직후 1회 돌리는 흐름 권장.
- Playwright MCP가 중간에 끊기는 이슈 → 4차 도구 정리 항목으로 두고, 단위 테스트 + Sprint 종료 직전 1회 시각 검증 흐름은 유지.
- 메모리 파일은 31일치 stale 경고가 떴음 → Sprint 4 끝 무렵 한 번 더 갱신 필수.
