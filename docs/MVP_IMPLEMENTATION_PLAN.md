# InvoiceFlow MVP 구현 계획

## 현재 상태 (2026-03-06)

### 완료된 작업

| ID | 기능 | 설명 | 검증 |
|----|------|------|------|
| A1 | Send Invoice | draft->sent 전환, 이메일 발송, 리마인더 3건 스케줄링 | E2E 검증 완료 |
| B1 | 대시보드 KPI | Total Outstanding, Collection Rate, Active Reminders 실데이터 연결 | E2E 검증 완료 |
| B2 | Recent Invoices | 최근 5건 송장 테이블 (Invoice#, Client, Amount, Due Date, Status 뱃지) | E2E 검증 완료 |
| B4 | 송장 필터/검색 | 탭별 카운트 뱃지, URL 기반 필터(?status=&q=), DB 레벨 ILIKE 검색 | E2E 검증 완료 |
| -- | 이메일 템플릿 | HTML+텍스트 송장 이메일 (5개 통화 심볼 지원) | 코드 검증 완료 |

### 기존 구현 (이전 세션)

- 회원가입/로그인 (이메일 + Google/GitHub OAuth)
- 클라이언트 CRUD (생성, 목록, 상세, 수정, 삭제)
- 송장 CRUD (생성, 목록, 상세, 수정, 삭제, 라인 아이템)
- 대시보드 레이아웃 (사이드바, 테마 토글)
- 랜딩 페이지 (Hero, Features, Pricing, Footer)
- 설정 페이지 (Company, Timezone, Brand tone)
- Upload 페이지 UI (드래그앤드롭 영역)
- DB 스키마 (users, invoices, invoice_items, clients, reminders, payments, extraction_jobs)
- Oban 인프라 (oban_jobs 테이블)

---

## 남은 작업

### Phase A: 핵심 비즈니스 로직

#### A2. Oban ReminderWorker (높은 우선순위)

**목표:** 마감일 기준 D+1, D+7, D+14에 자동 리마인더 이메일 발송

**구현 범위:**
- [ ] `lib/invoice_flow/workers/reminder_worker.ex` 생성
  - Oban Worker 모듈 (`use Oban.Worker, queue: :mailers`)
  - reminder 레코드 조회 -> 이메일 생성 -> Swoosh 발송
  - 발송 성공 시 reminder.status = "sent", sent_at 업데이트
  - 발송 실패 시 Oban 재시도 정책 활용
- [ ] 리마인더 이메일 템플릿 3종 생성 (`lib/invoice_flow/emails/reminder_email.ex`)
  - Step 1 (D+1): 친근한 확인 요청 톤
  - Step 2 (D+7): 부드러운 독촉 톤
  - Step 3 (D+14): 최종 경고 톤 (사용자 설정 가능)
- [ ] Oban Cron 설정 (`config/config.exs`)
  - 매일 오전 9시(수신자 타임존) reminder 스캔 -> Worker enqueue
- [ ] `send_invoice/1`에서 Oban Job 스케줄링 연동
  - reminder 레코드에 `oban_job_id` 저장
- [ ] 결제 완료 시 미발송 리마인더 취소 로직
  - `Reminders.cancel_pending_reminders/1` -> Oban.cancel_job/1

**관련 파일:**
- `lib/invoice_flow/workers/reminder_worker.ex` (신규)
- `lib/invoice_flow/emails/reminder_email.ex` (신규)
- `lib/invoice_flow/reminders.ex`
- `lib/invoice_flow/invoices.ex`
- `config/config.exs` (Oban crontab)

**참고:** 현재 `Reminders.schedule_reminders/1`은 DB 레코드만 생성함. Oban Job enqueue 로직 추가 필요.

---

#### A3. OCR 추출 Worker (높은 우선순위)

**목표:** 업로드된 PDF/이미지에서 AI가 송장 정보(금액, 마감일, 클라이언트)를 자동 추출

**구현 범위:**
- [ ] `lib/invoice_flow/workers/ocr_extraction_worker.ex` 생성
  - Oban Worker (`use Oban.Worker, queue: :ai`)
  - OpenAI Vision API (GPT-4o) 호출
  - 추출 결과를 ExtractionJob 레코드에 저장
  - PubSub broadcast로 LiveView 실시간 업데이트
- [ ] `lib/invoice_flow/extraction.ex` 확장
  - `create_extraction_job/2` - 업로드 파일로부터 job 생성
  - `complete_extraction/2` - AI 결과 저장
  - `create_invoice_from_extraction/2` - 추출 결과로 송장 자동 생성
- [ ] `lib/invoice_flow_web/live/upload_live.ex` 업데이트
  - LiveView Upload 핸들러 연결 (allow_upload, handle_progress)
  - 업로드 완료 -> OcrExtractionWorker enqueue
  - PubSub subscribe -> 추출 결과 실시간 표시
  - 추출 결과 확인/수정 UI -> 송장 생성
- [ ] OpenAI API 클라이언트 모듈
  - `lib/invoice_flow/ai/vision_client.ex` (Req HTTP 클라이언트)
  - 프롬프트 엔지니어링: 금액, 마감일, 클라이언트명, 항목 추출

**관련 파일:**
- `lib/invoice_flow/workers/ocr_extraction_worker.ex` (신규)
- `lib/invoice_flow/ai/vision_client.ex` (신규)
- `lib/invoice_flow/extraction.ex`
- `lib/invoice_flow/extraction/extraction_job.ex`
- `lib/invoice_flow_web/live/upload_live.ex`

**환경 변수:** `OPENAI_API_KEY`

---

#### A4. Paddle Webhook Controller (중간 우선순위)

**목표:** 클라이언트 결제 완료 시 송장 상태 자동 업데이트

**구현 범위:**
- [ ] `lib/invoice_flow_web/controllers/paddle_webhook_controller.ex` 생성
  - POST `/api/webhooks/paddle` 엔드포인트
  - Paddle 서명 검증 (hmac-sha256)
  - `transaction.completed` 이벤트 처리
- [ ] 송장 상태 업데이트 플로우
  - Paddle transaction_id로 송장 매칭
  - `Invoices.mark_as_paid/1` 호출
  - `Reminders.cancel_pending_reminders/1` 호출
  - PubSub broadcast -> 대시보드 실시간 반영
- [ ] Payment 레코드 생성
  - `Payments.record_payment/2` - webhook 데이터로 payment 기록
  - raw_webhook JSON 저장 (감사 추적)
- [ ] 라우터에 webhook 경로 추가
  - API pipeline (CSRF 보호 제외)

**관련 파일:**
- `lib/invoice_flow_web/controllers/paddle_webhook_controller.ex` (신규)
- `lib/invoice_flow/payments.ex`
- `lib/invoice_flow/invoices.ex`
- `lib/invoice_flow/reminders.ex`
- `lib/invoice_flow_web/router.ex`

**환경 변수:** `PADDLE_WEBHOOK_SECRET`, `PADDLE_API_KEY`

---

### Phase B: 대시보드 & 실시간

#### B3. PubSub 실시간 업데이트 (중간 우선순위)

**목표:** 결제 완료, 리마인더 발송 시 대시보드 자동 갱신

**구현 범위:**
- [ ] `dashboard_live.ex`에 PubSub subscribe 추가
  - `invoice:*` 토픽 구독
  - `handle_info`에서 KPI 재계산 및 Recent Invoices 갱신
- [ ] 송장 목록 페이지 실시간 업데이트
  - 상태 변경 시 목록 자동 갱신
  - 카운트 뱃지 실시간 반영

**관련 파일:**
- `lib/invoice_flow_web/live/dashboard_live.ex`
- `lib/invoice_flow_web/live/invoice_live/index.ex`
- `lib/invoice_flow/pub_sub_topics.ex`

---

### Phase C: 결제 & 구독

#### C1. Paddle Billing 구독 연동 (중간 우선순위)

**목표:** Free/Starter/Pro 플랜 구독 결제 처리

**구현 범위:**
- [ ] Paddle Billing API 클라이언트 모듈
  - `lib/invoice_flow/billing/paddle_client.ex`
  - 구독 생성, 업그레이드, 취소 API
- [ ] 구독 관리 LiveView
  - `/settings/billing` 페이지
  - 현재 플랜 표시, 업그레이드 버튼
  - Paddle Checkout 오버레이 연동
- [ ] Webhook 처리 확장
  - `subscription.created`, `subscription.updated`, `subscription.canceled`
  - User 레코드에 plan 필드 업데이트

**관련 파일:**
- `lib/invoice_flow/billing/paddle_client.ex` (신규)
- `lib/invoice_flow/billing.ex`
- `lib/invoice_flow_web/live/billing_live.ex` (신규)

**환경 변수:** `PADDLE_API_KEY`, `PADDLE_PRICE_ID_STARTER`, `PADDLE_PRICE_ID_PRO`

---

#### C2. 플랜 게이팅 (중간 우선순위)

**목표:** Free 플랜 월 3건 송장 제한, Starter 무제한

**구현 범위:**
- [ ] `lib/invoice_flow/billing/plan_gate.ex`
  - `can_create_invoice?/1` - 현재 월 송장 수 체크
  - `plan_limits/1` - 플랜별 제한 반환
- [ ] 송장 생성 시 게이팅 적용
  - `InvoiceLive.New`에서 제한 초과 시 업그레이드 유도 모달
- [ ] 대시보드에 사용량 표시
  - "3/3 invoices used this month" 프로그레스 바

**관련 파일:**
- `lib/invoice_flow/billing/plan_gate.ex` (신규)
- `lib/invoice_flow/accounts.ex` (plan_limits 함수 추가)
- `lib/invoice_flow_web/live/invoice_live/new.ex`
- `lib/invoice_flow_web/live/dashboard_live.ex`

---

#### C3. 송장별 Paddle 결제 링크 (중간 우선순위)

**목표:** 각 송장에 고유 Paddle 결제 URL 삽입

**구현 범위:**
- [ ] 송장 생성/발송 시 Paddle 결제 링크 자동 생성
  - Paddle API: transaction 생성 -> checkout URL 반환
  - invoice.paddle_payment_link 필드에 저장
- [ ] 리마인더 이메일에 결제 링크 포함
  - "Pay Now" CTA 버튼
- [ ] 송장 상세 페이지에 결제 링크 표시

**관련 파일:**
- `lib/invoice_flow/billing/paddle_client.ex`
- `lib/invoice_flow/invoices.ex`
- `lib/invoice_flow/emails/reminder_email.ex`
- `lib/invoice_flow_web/live/invoice_live/show.ex`

---

### Phase D: 인프라 & 품질

#### D1. 이메일 추적 (낮은 우선순위)

**목표:** 리마인더 이메일 오픈율/클릭률 추적

**구현 범위:**
- [ ] Tracking pixel 삽입 (1x1 투명 이미지)
  - `/api/track/open/:reminder_id` 엔드포인트
- [ ] 결제 링크 리다이렉트 추적
  - `/api/track/click/:reminder_id` -> Paddle URL 리다이렉트
- [ ] 리마인더 레코드 업데이트 (opened_at, clicked_at)
- [ ] 대시보드 분석: "몇 번째 리마인더에서 결제 완료" 통계

---

#### D2. PDF 내보내기 (중간 우선순위)

**목표:** 송장을 PDF로 생성하여 다운로드/이메일 첨부

**구현 범위:**
- [ ] ChromicPDF 또는 Typst 기반 PDF 렌더링
  - `lib/invoice_flow/pdf/invoice_pdf.ex`
  - 송장 HTML 템플릿 -> PDF 변환
- [ ] 송장 상세 페이지에 "Download PDF" 버튼
- [ ] 이메일 발송 시 PDF 첨부 옵션
- [ ] S3/Tigris 업로드 (invoice.pdf_url 저장)

**의존성:** `chromic_pdf` hex 패키지

---

#### D3. Fly.io 배포 (중간 우선순위)

**목표:** 프로덕션 배포 파이프라인

**구현 범위:**
- [ ] `Dockerfile` 생성 (Elixir release 빌드)
- [ ] `fly.toml` 설정
  - health check, auto-scaling, secrets
- [ ] `rel/overlays/bin/migrate` 스크립트
- [ ] PostgreSQL Fly Postgres 설정
- [ ] 환경 변수 설정 (fly secrets set)
  - DATABASE_URL, SECRET_KEY_BASE, OPENAI_API_KEY, PADDLE_*

---

#### D4. CI/CD 파이프라인 (낮은 우선순위)

**목표:** 코드 품질 자동 검증

**구현 범위:**
- [ ] `.github/workflows/ci.yml`
  - `mix test` - 테스트 실행
  - `mix credo --strict` - 코드 스타일
  - `mix dialyzer` - 타입 체크
  - `mix format --check-formatted` - 포맷 확인
- [ ] PR 머지 시 자동 배포 (Fly.io GitHub integration)

---

## 추천 구현 순서

```
Week 1-2: A2 (ReminderWorker) -> B3 (PubSub 실시간) -> D1 (이메일 추적)
Week 3-4: A3 (OCR Worker) -> D2 (PDF 내보내기)
Week 5-6: A4 (Paddle Webhook) -> C3 (결제 링크) -> C1 (구독 연동)
Week 7-8: C2 (플랜 게이팅) -> D3 (Fly.io 배포) -> D4 (CI/CD)
```

## 기술 참고

- **Oban Workers**: `lib/invoice_flow/workers/` 디렉토리에 생성, `queue` 별 분리 (`:mailers`, `:ai`, `:default`)
- **PubSub Topics**: `lib/invoice_flow/pub_sub_topics.ex`에 토픽 헬퍼 정의됨
- **이메일**: Swoosh + Resend adapter (prod), Local adapter (dev)
- **AI**: OpenAI GPT-4o Vision API, Req HTTP 클라이언트
- **결제**: Paddle Billing API v2
