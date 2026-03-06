# InvoiceFlow — 자동 송장 리마인더 SaaS

### Product Requirements Document (PRD)

| 항목   | 내용         |
| ------ | ------------ |
| 버전   | v3.0         |
| 작성일 | 2026년 3월   |
| 상태   | In Progress  |
| 작성자 | Product Team |

---

## 목차

1. [제품 개요](#1-제품-개요)
2. [기능 요구사항](#2-기능-요구사항)
3. [기술 스택 및 아키텍처](#3-기술-스택-및-아키텍처)
4. [사용자 여정](#4-사용자-여정)
5. [비즈니스 모델 및 가격 정책](#5-비즈니스-모델-및-가격-정책)
6. [출시 로드맵](#6-출시-로드맵)
7. [성공 지표](#7-성공-지표)
8. [리스크 및 대응 방안](#8-리스크-및-대응-방안)

---

## 1. 제품 개요

### 1.1 제품 비전

InvoiceFlow는 프리랜서, 소규모 사업자, 에이전시가 **송장 발송 후 대금 회수까지 걸리는 시간을 단축**하고, 미수금 추적에 소모되는 반복 업무를 자동화하는 SaaS 서비스입니다.

Net 30 결제 조건 기준으로 **3단계 AI 리마인더 이메일을 자동 발송**하고, Paddle 결제 연동을 통해 클라이언트가 결제하는 즉시 상태를 업데이트합니다.

### 1.2 핵심 가치 제안

|               |                                                                                        |
| ------------- | -------------------------------------------------------------------------------------- |
| **문제**      | 송장 발행 후 결제 독촉 이메일을 수동으로 보내는 데 매주 수 시간 낭비, 미수금 누락 발생 |
| **솔루션**    | AI 템플릿 기반 3단계 자동 이메일 + Paddle 실시간 결제 연동으로 완전 자동화             |
| **차별화**    | 경쟁사 대비 50% 저렴한 $9/월, 모바일 네이티브 앱(Android/iOS), Paddle 즉시 결제 업데이트 |

### 1.3 타겟 고객

| 구분      | 대상                                                |
| --------- | --------------------------------------------------- |
| 주요 타겟 | 프리랜서 디자이너/개발자, 1~10인 에이전시, 컨설턴트 |
| 보조 타겟 | 소규모 서비스업 (청소, 인테리어, 이벤트 플래너 등)  |
| 지역      | 북미, 유럽, 한국 (다국어 지원 로드맵)               |
| 결제 규모 | 월 송장 5~50건, 건당 $500~$50,000                   |

### 1.4 비즈니스 목표

- 출시 후 6개월 내 유료 구독자 **1,000명** 달성
- 연간 반복 매출(ARR) **$108,000** (Year 1 목표)
- 평균 대금 회수 기간 Net 30 → **Net 18**로 단축
- NPS **50 이상** 달성

---

## 2. 기능 요구사항

### 2.1 웹 대시보드 (Phoenix LiveView) ✅ 구현 완료

> Phoenix LiveView를 활용하여 **서버 렌더링 기반 실시간 인터랙티브 UI**를 구현합니다. JavaScript 번들 없이 WebSocket을 통해 실시간 상태 동기화가 이루어지며, SEO 친화적인 초기 렌더링과 즉각적인 사용자 인터랙션을 동시에 달성합니다.

#### 2.1.1 송장 업로드 및 생성

- ✅ PDF/이미지 송장 파일 드래그 앤 드롭 업로드 (LiveView Upload)
- ✅ 업로드 진행률 실시간 표시 (LiveView 프로그레스 바)
- ✅ 업로드된 송장에서 AI가 자동으로 금액, 마감일, 클라이언트 정보 추출 (OCR + LLM)
- ✅ AI 추출 결과 실시간 스트리밍 표시 (LiveView async assign)
- ✅ 수동 입력 폼으로 송장 직접 생성 (LiveView Form + Ecto Changeset 검증)
- ✅ 송장 번호 자동 생성 (`INV-YYYYMM-XXXX` 형식)
- [ ] PDF 내보내기 및 공유 링크 생성

#### 2.1.2 AI 이메일 리마인더 자동화

Net 30 결제 조건 기준, 3단계 이메일을 자동 발송합니다:

| 단계      | 발송 시점 | 톤 & 내용                                                     |
| --------- | --------- | ------------------------------------------------------------- |
| **1단계** | 마감 D+1  | 친근하고 감사한 톤. "확인 부탁드립니다" 수준의 결제 확인 요청 |
| **2단계** | 마감 D+7  | 부드러운 독촉 — 마감 상기, 도움 제안 포함                     |
| **3단계** | 마감 D+14 | 최종 경고 — 연체료/법적 조치 가능성 언급 (사용자 설정 가능)   |

- ✅ 각 단계별 이메일 템플릿 (Swoosh + HTML/Text 듀얼 포맷, 5개 통화 지원)
- ✅ Oban 기반 스케줄링으로 정확한 시점에 발송 (D+1, D+7, D+14)
- [ ] 이메일 발송 전 LiveView 실시간 미리보기 및 수동 편집
- [ ] 발송 시간 최적화 (수신자 타임존 기준 오전 9시~11시)
- [ ] 이메일 오픈율, 클릭률 추적 (대시보드 실시간 반영)

#### 2.1.3 대시보드 및 분석

- ✅ 미수금 현황 (총 미수금액, 연체 건수, 수금률 KPI 카드)
- ✅ 이번 달 수금액 표시
- ✅ 최근 송장 목록 (상태별 필터링, 검색)
- ✅ PubSub 기반 실시간 데이터 업데이트 (결제 완료 시 대시보드 즉시 반영)
- [ ] 클라이언트별 결제 이력 및 평균 결제 기간
- [ ] 월별 매출 트렌드 차트

---

### 2.2 REST API (모바일 앱용) ✅ 구현 완료

> 모바일 앱이 사용할 REST API 레이어가 Phoenix 위에 구현되었습니다. 기존 Context 함수를 그대로 호출하는 HTTP 래퍼로, 새로운 비즈니스 로직 없이 동작합니다.

#### 2.2.1 API 엔드포인트 (25개)

| 그룹 | 엔드포인트 | 상태 |
|------|-----------|------|
| **인증** | POST `/api/v1/auth/register`, `/login`, `/refresh`, `/google` | ✅ |
| **인증** | DELETE `/api/v1/auth/logout` | ✅ |
| **대시보드** | GET `/api/v1/dashboard`, `/dashboard/recent` | ✅ |
| **송장** | GET/POST `/api/v1/invoices`, GET/PUT/DELETE `/api/v1/invoices/:id` | ✅ |
| **송장 액션** | POST `/api/v1/invoices/:id/send`, `/mark_paid` | ✅ |
| **클라이언트** | GET/POST `/api/v1/clients`, GET/PUT/DELETE `/api/v1/clients/:id` | ✅ |
| **업로드** | POST `/api/v1/upload`, GET `/api/v1/extraction/:id` | ✅ |
| **설정** | GET/PUT `/api/v1/settings` | ✅ |

#### 2.2.2 API 인증

- ✅ **Phoenix.Token 기반 Bearer 인증** (30일 만료, refresh 지원)
- ✅ Google OAuth ID Token 교환 엔드포인트
- ✅ 통합 에러 응답 포맷 (`FallbackController`)

#### 2.2.3 응답 포맷

```json
// 성공
{ "data": { ... }, "meta": { "total": 42, "counts": { ... } } }

// 에러
{ "error": { "code": "validation_error", "message": "Invalid input", "details": { ... } } }
```

---

### 2.3 모바일 앱 (네이티브 Android + iOS)

> 모바일 앱은 **각 플랫폼 네이티브**로 개발합니다. Android는 Kotlin + Jetpack Compose, iOS는 Swift + SwiftUI를 사용하며, 양 플랫폼 모두 **MVI (Model-View-Intent) 아키텍처**를 적용하여 구조적 일관성을 유지합니다.

#### 2.3.1 Android 앱 (Kotlin)

| 기술 | 용도 |
|------|------|
| Jetpack Compose | 선언적 UI |
| Hilt | 의존성 주입 |
| Retrofit + KotlinX Serialization | API 통신 |
| Room | 오프라인 캐시 |
| DataStore | 토큰 저장 |
| CameraX | OCR 촬영 |
| Google Sign-In | OAuth |

#### 2.3.2 iOS 앱 (Swift)

| 기술 | 용도 |
|------|------|
| SwiftUI | 선언적 UI |
| Factory | 의존성 주입 |
| Alamofire | API 통신 |
| SwiftData | 오프라인 캐시 |
| KeychainAccess | 토큰 저장 |
| AVCaptureSession / PHPicker | 카메라/갤러리 |
| Google Sign-In iOS | OAuth |

#### 2.3.3 MVI 아키텍처 (양 플랫폼 공통)

```
┌─────────────┐    ┌──────────┐    ┌────────────┐
│    View      │───>│  Store   │───>│  UseCase   │
│ (Compose/    │<───│  (MVI)   │<───│            │
│  SwiftUI)    │    └──────────┘    └────────────┘
└─────────────┘
  Intent ──>      State ──>      Repository ──>  REST API / Local DB
              <── Effect (toast, navigation)
```

- **Intent**: 사용자 액션 (로드, 필터, 생성, 삭제 등)
- **State**: UI 상태 (목록, 로딩, 에러 등)
- **Effect**: 일회성 이벤트 (토스트, 네비게이션)

#### 2.3.4 모바일 핵심 기능

- [ ] 로그인/회원가입 (이메일 + Google OAuth)
- [ ] 대시보드 (KPI 카드, 최근 송장)
- [ ] 송장 목록/상세/생성/수정 (필터링, 검색)
- [ ] 클라이언트 CRUD
- [ ] 카메라/갤러리 OCR 업로드
- [ ] 설정 (프로필, 타임존)
- [ ] 푸시 알림 (리마인더 발송, 결제 완료, OCR 완료, 연체 경고)
- [ ] 오프라인 지원 (캐시 조회, 생성 큐잉)

#### 2.3.5 모바일-서버 통신

- REST API (`/api/v1/*`) 통한 JSON 통신
- Phoenix.Token Bearer 인증 (DataStore/Keychain에 저장)
- MVP: 30초 간격 폴링으로 실시간 업데이트
- v2: Phoenix Channels WebSocket으로 마이그레이션

---

### 2.4 Paddle 결제 연동

> **핵심 흐름:** Paddle Checkout 링크를 송장에 삽입 → 클라이언트 결제 완료 즉시 Webhook으로 상태 자동 업데이트

- 각 송장에 고유 Paddle 결제 링크 자동 생성
- 결제 완료 시 송장 상태 '결제 완료'로 즉시 업데이트 (Phoenix PubSub 전파)
- 리마인더 이메일 자동 중단 (Oban 작업 취소)
- 결제 영수증 클라이언트 자동 발송
- 부분 결제 처리 및 잔액 추적

---

## 3. 기술 스택 및 아키텍처

### 3.1 기술 스택

| 레이어            | 기술                                | 비고                                               |
| ----------------- | ----------------------------------- | -------------------------------------------------- |
| **웹 프론트엔드** | Phoenix LiveView 1.1+               | 서버 렌더링 실시간 UI, Tailwind CSS v4 + DaisyUI   |
| **컴포넌트**      | Phoenix.Component + HEEx            | CoreComponents, UiComponents                       |
| **모바일 Android** | Kotlin + Jetpack Compose + Hilt    | MVI 아키텍처, Retrofit, Room                       |
| **모바일 iOS**    | Swift + SwiftUI + Factory           | MVI 아키텍처, Alamofire, SwiftData                 |
| **백엔드**        | Elixir 1.15+ / Phoenix 1.8+        | LiveView (웹) + REST API (모바일) + PubSub         |
| **REST API**      | Phoenix Controllers + JSON          | Phoenix.Token Bearer 인증, 25개 엔드포인트         |
| **데이터베이스**  | PostgreSQL (Ecto 3.13)              | 7개 테이블 + Oban jobs                             |
| **캐싱**          | Cachex                              | 인메모리 캐싱                                      |
| **백그라운드 잡** | Oban 2.17                           | 5개 큐 (default, reminders, extraction, pdf, email) |
| **실시간 통신**   | Phoenix PubSub                      | LiveView 실시간 업데이트                           |
| **AI / OCR**      | OpenAI GPT-4o + Vision API          | 송장 정보 추출, 이메일 생성                        |
| **이메일 발송**   | Swoosh + Resend (prod)              | HTML/Text 듀얼 포맷, 5개 통화 지원                 |
| **인증 (웹)**     | phx_gen_auth + Ueberauth Google     | 세션 기반 인증, bcrypt                             |
| **인증 (API)**    | Phoenix.Token Bearer                | 30일 만료, refresh 지원                            |
| **결제**          | Paddle Billing API + Webhooks       | 구독 및 송장 결제                                  |
| **파일 저장소**   | S3 (ExAws)                          | 송장 PDF, 업로드 이미지 저장                       |
| **PDF 생성**      | ChromicPDF                          | 송장 PDF 렌더링                                    |
| **인프라**        | Fly.io                              | Elixir 네이티브 클러스터링                         |
| **CI/CD**         | GitHub Actions                      | 플랫폼별 path-filtered 워크플로우                  |
| **모니터링**      | Sentry + LiveDashboard + Telemetry  | 에러 추적 + 실시간 성능 모니터링                   |
| **API 스펙**      | OpenAPI 3.1                         | `packages/api-spec/openapi.yaml`                   |

### 3.2 모노레포 구조

```
InvoiceFlow/
├── lib/                        # Elixir 백엔드 + 웹 (단일 앱)
│   ├── invoice_flow/           # 도메인 Context (Accounts, Invoices, Clients, ...)
│   └── invoice_flow_web/       # Phoenix 웹 계층
│       ├── controllers/api/    # REST API 컨트롤러 (6개) ✅
│       ├── plugs/              # ApiAuth Bearer 인증 ✅
│       ├── live/               # LiveView 페이지들
│       └── components/         # 공유 컴포넌트
├── apps/
│   ├── android/                # Android 앱 (Kotlin, Compose, MVI)
│   └── ios/                    # iOS 앱 (Swift, SwiftUI, MVI)
├── packages/
│   └── api-spec/               # OpenAPI 3.1 스펙 ✅
│       ├── openapi.yaml
│       └── schemas/
├── config/                     # Elixir 환경별 설정
├── test/                       # ExUnit 테스트 (133개 통과)
├── scripts/                    # 빌드/배포 스크립트 ✅
├── .github/workflows/          # 플랫폼별 CI ✅
├── docs/                       # 프로젝트 문서
└── Makefile                    # 통합 빌드 명령어 ✅
```

### 3.3 애플리케이션 Supervision Tree

```
InvoiceFlow.Application
├── InvoiceFlow.Repo (Ecto PostgreSQL)
├── InvoiceFlowWeb.Endpoint (Phoenix HTTP/WebSocket)
├── InvoiceFlow.PubSub (Phoenix.PubSub)
├── InvoiceFlow.Mailer (Swoosh)
├── Oban (백그라운드 작업 큐)
│   ├── InvoiceFlow.Workers.ReminderWorker
│   ├── InvoiceFlow.Workers.OcrExtractionWorker
│   ├── InvoiceFlow.Workers.PdfGenerationWorker
│   └── InvoiceFlow.Workers.EmailTrackingWorker
├── InvoiceFlow.Cache (Cachex)
└── InvoiceFlow.Telemetry (메트릭 수집)
```

### 3.4 시스템 아키텍처 흐름

```
[사용자 - 웹 브라우저]
  │
  ├─ Phoenix LiveView (WebSocket)
  │     ├─ 송장 업로드 (LiveView Upload)
  │     │     └─ Oban Worker: OCR + GPT-4o 정보 추출 → Ecto → PostgreSQL
  │     │           └─ PubSub broadcast → LiveView 실시간 결과 표시
  │     │
  │     ├─ 대시보드 (LiveView 실시간)
  │     │     └─ PubSub subscribe → 결제/리마인더 이벤트 실시간 반영
  │     │
  │     └─ 송장 관리 (LiveView CRUD)
  │           └─ Ecto Changeset 검증 → PostgreSQL
  │
  ├─ Oban Cron (매일 실행)
  │     └─ 마감일 체크 → ReminderWorker 트리거
  │           └─ Swoosh + Resend: 이메일 발송
  │
  └─ 클라이언트
        └─ 이메일 내 Paddle 링크 클릭 → 결제 완료
              └─ Phoenix Controller: Paddle Webhook 수신
                    └─ PubSub broadcast → 상태 "결제 완료"
                          ├─ LiveView 대시보드 즉시 업데이트
                          └─ Oban: 리마인더 작업 취소

[사용자 - 모바일 앱 (Android/iOS 네이티브)]
  │
  ├─ Phoenix REST API (/api/v1/*)
  │     ├─ Phoenix.Token Bearer 인증
  │     ├─ 송장 CRUD + 발송 + 결제완료
  │     ├─ 클라이언트 CRUD
  │     ├─ 대시보드 KPI + 최근 송장
  │     ├─ OCR 업로드 + 추출 결과
  │     └─ 사용자 설정
  │
  └─ 푸시 알림 (향후)
        └─ Oban Worker → pigeon → FCM/APNs → 모바일 앱
```

### 3.5 컨텍스트 (도메인) 설계

| Context                  | 책임                                      | 주요 Schema                            |
| ------------------------ | ----------------------------------------- | -------------------------------------- |
| `InvoiceFlow.Accounts`   | 사용자 인증, 프로필, OAuth, 플랜 관리     | User, UserToken                        |
| `InvoiceFlow.Invoices`   | 송장 CRUD, 상태 전환, 집계 쿼리           | Invoice, InvoiceItem                   |
| `InvoiceFlow.Clients`    | 클라이언트 정보 관리                      | Client                                 |
| `InvoiceFlow.Reminders`  | 리마인더 스케줄링, 이메일 발송            | Reminder, ReminderTemplate             |
| `InvoiceFlow.Payments`   | Paddle 연동, 결제 상태                    | Payment, PaddleWebhookEvent            |
| `InvoiceFlow.Billing`    | 구독 플랜, 사용량 추적                    | Subscription                           |
| `InvoiceFlow.Extraction` | AI OCR, 송장 데이터 추출                  | ExtractionJob                          |
| `InvoiceFlow.Emails`     | 송장 이메일 생성 (HTML/Text)              | InvoiceEmail                           |

### 3.6 데이터베이스 스키마 (7 테이블 + Oban)

```
users           - email, hashed_password, company_name, timezone, brand_tone,
                  google_uid, avatar_url, plan, paddle_customer_id
clients         - user_id FK, name, email, company, phone, address
invoices        - user_id FK, client_id FK, invoice_number (auto),
                  amount, paid_amount, currency, due_date, status,
                  sent_at, paid_at, notes
invoice_items   - invoice_id FK, description, quantity, unit_price, position
reminders       - invoice_id FK, step (1/2/3), scheduled_at, sent_at,
                  status, email_subject, email_body, oban_job_id
payments        - invoice_id FK, paddle_transaction_id, amount, status, paid_at
extraction_jobs - user_id FK, status, original_filename, content_type,
                  confidence_score, extracted_data, error_message, oban_job_id
oban_jobs       - Oban 백그라운드 잡 (자동 관리)
```

### 3.7 API 인증 흐름

```
[모바일 앱]                    [Phoenix API]
    │                              │
    ├─ POST /auth/login ──────────>│
    │  {email, password}           │
    │                              ├─ Accounts.get_user_by_email_and_password
    │<─── {token, user} ──────────┤  Phoenix.Token.sign(user_id)
    │                              │
    ├─ GET /invoices ─────────────>│
    │  Authorization: Bearer <tok> │
    │                              ├─ ApiAuth plug → Phoenix.Token.verify
    │<─── {data: [...]} ──────────┤  Invoices.list_invoices(user_id)
```

---

## 4. 사용자 여정

### 4.1 웹 — 프리랜서 Alice의 시나리오

| 단계            | 액션                                                                     |
| --------------- | ------------------------------------------------------------------------ |
| 1. 회원가입     | Google OAuth로 30초 만에 가입 (Ueberauth), Paddle 연동 설정              |
| 2. 송장 업로드  | LiveView 드래그 앤 드롭으로 PDF 송장 업로드, 실시간 프로그레스 바 표시   |
| 3. AI 추출 확인 | Oban Worker가 OCR 처리, PubSub로 LiveView에 실시간 결과 스트리밍         |
| 4. 자동화 시작  | Net 30 체크 후 Oban Cron이 D+1, D+7, D+14 ReminderWorker 자동 예약      |
| 5. 결제 알림    | Paddle Webhook → PubSub → LiveView 대시보드 즉시 업데이트 + 모바일 푸시 |

### 4.2 모바일 — 배관공 Bob의 현장 시나리오

| 단계              | 액션                                                              |
| ----------------- | ----------------------------------------------------------------- |
| 1. 현장 도착      | 네이티브 앱 열기 → 카메라로 송장 촬영                            |
| 2. OCR 추출       | POST /api/v1/upload → 서버 OCR 처리 → 추출 결과 확인             |
| 3. 송장 생성/발송 | POST /api/v1/invoices → POST /api/v1/invoices/:id/send           |
| 4. 결제 확인      | 클라이언트 결제 → 대시보드 폴링 → 앱 알림 (향후 푸시)            |

---

## 5. 비즈니스 모델 및 가격 정책

### 5.1 가격 플랜

| 플랜           | 가격   | 포함 기능                                                    |
| -------------- | ------ | ------------------------------------------------------------ |
| **Free**       | $0/월  | 월 3건 송장, 기본 이메일 템플릿 1종, 모바일 앱 기본          |
| **Starter**    | $9/월  | 무제한 송장, AI 리마인더 전 단계, Paddle 연동, 분석 대시보드 |
| **Pro**        | $29/월 | 팀 멤버 5명, 커스텀 브랜딩, 우선 지원, API 액세스            |

> **전환 전략:** Free 플랜 3건 제한으로 첫 달 사용 후 자연스럽게 $9 Starter 플랜으로 업그레이드 유도

### 5.2 수익 예측 (Year 1)

| 분기 | 유료 구독자 | MRR                        |
| ---- | ----------- | -------------------------- |
| Q1   | 200명       | $1,800                     |
| Q2   | 500명       | $4,500                     |
| Q3   | 800명       | $7,200                     |
| Q4   | 1,200명     | $10,800 → **ARR $129,600** |

### 5.3 경쟁사 비교

| 서비스          | 가격      | 특징                                          |
| --------------- | --------- | --------------------------------------------- |
| **InvoiceFlow** | **$9/월** | AI 리마인더 + Paddle 연동 + 네이티브 모바일앱 |
| FreshBooks      | $17/월~   | 회계 중심, 리마인더 수동                      |
| Invoice Ninja   | $10/월    | 오픈소스 기반, 자동화 제한적                  |
| Harvest         | $12/월    | 시간 추적 중심, 송장 보조적                   |

---

## 6. 출시 로드맵

### Phase 0 — 모노레포 구조 ✅ 완료

- [x] 모노레포 루트 디렉토리 구조 (`apps/`, `packages/`, `scripts/`)
- [x] Makefile 통합 빌드 명령어 (17개 타겟)
- [x] `.github/workflows/` 플랫폼별 CI (server, android, ios)
- [x] OpenAPI 3.1 스펙 (`packages/api-spec/openapi.yaml`)
- [x] 개발환경 초기 설정 및 API 클라이언트 생성 스크립트

### Phase 1 — REST API 레이어 ✅ 완료

- [x] Phoenix.Token 기반 Bearer 인증 (`ApiAuth` plug)
- [x] 통합 에러 처리 (`FallbackController`)
- [x] JSON 직렬화 헬퍼 (`JsonHelpers`)
- [x] API 컨트롤러 6개:
  - [x] `AuthController` — 회원가입, 로그인, 토큰 갱신, Google OAuth
  - [x] `InvoiceController` — CRUD + send + mark_paid
  - [x] `ClientController` — CRUD
  - [x] `DashboardController` — KPI, recent invoices
  - [x] `UploadController` — 파일 업로드 + 추출 결과
  - [x] `SettingsController` — 사용자 설정
- [x] API 테스트 (17개 테스트 통과)
- [x] 전체 테스트 통과 (133개, 0 failures)

### Phase 2 — MVP 웹 기능 완성 (진행 중)

- [x] Phoenix 프로젝트 초기 설정 (Ecto, Oban, Swoosh)
- [x] phx_gen_auth 기반 이메일/비밀번호 인증 + Google OAuth
- [x] Invoices Context: 송장 CRUD LiveView
- [x] Clients Context: 클라이언트 CRUD LiveView
- [x] LiveView Upload: PDF/이미지 드래그 앤 드롭 업로드
- [x] Extraction Context: OCR 정보 추출 (Oban Worker)
- [x] Reminders Context: 3단계 이메일 자동 발송 (D+1, D+7, D+14)
- [x] 송장 발송 워크플로우 (상태 전환 + 리마인더 예약 + 이메일 전송)
- [x] 대시보드 KPI (미수금, 연체, 수금률, 이번 달 수금액)
- [x] 송장 필터링 (상태별 탭 + URL 기반) + 검색
- [x] 랜딩 페이지 + 브랜드 디자인 시스템
- [ ] Paddle 결제 Webhook 연동
- [ ] PDF 내보내기 및 공유 링크
- [ ] Fly.io 배포 파이프라인

### Phase 3 — Android 앱 (4-5주)

- [ ] Android Studio 프로젝트 설정 (`apps/android/`)
- [ ] MVI 아키텍처 기반 구현 (Compose + Hilt + Retrofit + Room)
- [ ] Week 1: Auth + Navigation (로그인, 회원가입, Google Sign-In)
- [ ] Week 2: Dashboard + Invoice List (KPI, 필터/검색)
- [ ] Week 3: Invoice CRUD + Client CRUD
- [ ] Week 4: Upload (CameraX) + Settings

### Phase 4 — iOS 앱 (4-5주, Phase 3과 병렬)

- [ ] Xcode 프로젝트 설정 (`apps/ios/`)
- [ ] MVI 아키텍처 기반 구현 (SwiftUI + Factory + Alamofire + SwiftData)
- [ ] Week 1: Auth + NavigationStack
- [ ] Week 2: Dashboard + Invoice List
- [ ] Week 3: Invoice CRUD + Client CRUD
- [ ] Week 4: Upload (PHPicker/카메라) + Settings

### Phase 5 — 통합 및 확장

- [ ] 푸시 알림 인프라 (pigeon → FCM + APNs)
- [ ] OpenAPI → 클라이언트 코드 자동 생성 (Kotlin/Swift)
- [ ] 이메일 오픈/클릭 추적
- [ ] Phoenix Channels 모바일 실시간 업데이트
- [ ] Pro 플랜 (팀 기능, API 키 관리)
- [ ] 다국어 지원 (Gettext 한국어, 스페인어)

### 타임라인

```
Phase 0 (완료)  : 모노레포 구조 + CI/CD
Phase 1 (완료)  : REST API 25개 엔드포인트 + 테스트
Phase 2 (진행중): MVP 웹 기능 완성
Phase 3 (4-5주) : Android 앱 ─┐
Phase 4 (4-5주) : iOS 앱     ─┤ 병렬 진행
Phase 5 (2주)   : 통합 + 확장 ┘
```

---

## 7. 성공 지표

| 지표        | 목표값                                    |
| ----------- | ----------------------------------------- |
| 활성화율    | 가입 후 7일 내 첫 송장 업로드율 > **60%** |
| 전환율      | Free → Starter 전환율 > **25%**           |
| 리텐션      | Month 3 유지율 > **70%**                  |
| 핵심 성과   | 리마인더 발송 후 결제 완료율 > **45%**    |
| 수금 단축   | 평균 결제 수령 기간 **Net 18** 이하       |
| 이메일 성과 | 리마인더 이메일 오픈율 > **55%**          |
| 모바일      | MAU 대비 모바일 사용자 비율 > **40%**     |
| 만족도      | NPS > **50**                              |
| 서버 성능   | API 응답 지연 < **100ms** (p95)           |
| 가용성      | 월간 가동률 > **99.9%**                   |
| 테스트      | 코드 커버리지 > **80%**                   |

---

## 8. 리스크 및 대응 방안

| 리스크                      | 대응 방안                                                                     |
| --------------------------- | ----------------------------------------------------------------------------- |
| AI OCR 정확도 부족          | 수동 수정 UX 최우선 설계, 사용자 피드백으로 모델 개선                         |
| 이메일 스팸 필터            | Resend SPF/DKIM 설정, Swoosh 발송 빈도 최적화, 사용자 도메인 연결            |
| Paddle 의존성               | 추후 Stripe 병렬 지원으로 리스크 분산                                         |
| 경쟁사 가격 인하            | UX 차별화 및 AI 기능 고도화로 가치 방어                                       |
| GDPR / 개인정보             | 데이터 최소 수집, Fly.io EU 리전 옵션, 개인정보 처리방침 완비                 |
| 네이티브 앱 이중 개발 부담  | MVI 패턴 통일로 구조적 일관성, OpenAPI 코드 생성으로 API 계층 자동화          |
| API 스펙-구현 불일치        | 컨트롤러 테스트에서 스펙 검증, OpenAPI 자동 생성 고려                         |
| 이미지 업로드 모바일 구현   | 서명된 URL 직접 업로드 방식 고려                                              |
| Google OAuth 모바일 플로우  | ID Token 교환 방식으로 통일 (API 엔드포인트 구현 완료)                        |
| 오프라인-온라인 동기화 충돌 | 서버 타임스탬프 기반 LWW (Last-Write-Wins)                                    |
| BEAM VM 운영 경험 부족      | Fly.io 매니지드 환경 활용, LiveDashboard + Sentry로 관측성 확보               |

---

## 9. 기술 스택 선택 근거

### 9.1 왜 Elixir + Phoenix LiveView인가

| 관점              | 이점                                                                                    |
| ----------------- | --------------------------------------------------------------------------------------- |
| **실시간 UX**     | LiveView WebSocket 기반으로 JS 프레임워크 없이 실시간 대시보드, 업로드 프로그레스 구현   |
| **동시성**        | BEAM VM의 경량 프로세스로 수천 개의 동시 WebSocket 연결 처리                             |
| **내결함성**      | OTP Supervisor Tree로 개별 작업 실패 시 자동 복구                                       |
| **백그라운드 잡** | Oban이 PostgreSQL 기반으로 별도 Redis 없이 안정적인 작업 큐 제공                         |
| **배포 효율**     | 프론트엔드 빌드 파이프라인 불필요, 단일 릴리스로 웹 + API + WebSocket 배포               |
| **비용 절감**     | 별도 프론트엔드 서버 불필요, Redis 불필요                                                |

### 9.2 왜 네이티브 모바일인가 (React Native 대신)

| 관점                | 이점                                                             |
| ------------------- | ---------------------------------------------------------------- |
| **최적 성능**       | 각 플랫폼 네이티브 렌더링으로 최고 성능과 UX 제공               |
| **플랫폼 API 접근** | CameraX, Room, SwiftData 등 최신 플랫폼 API 직접 활용            |
| **MVI 일관성**      | 양 플랫폼 동일한 MVI 아키텍처로 구조적 이해 용이                |
| **독립 배포**       | 각 앱 독립적 빌드/배포 가능, 한 플랫폼 이슈가 다른 플랫폼에 영향 없음 |
| **OpenAPI 코드젠**  | openapi-generator로 각 플랫폼용 타입 안전 API 클라이언트 자동 생성 |

---

_InvoiceFlow PRD v3.0 — Confidential & Internal Use Only_
