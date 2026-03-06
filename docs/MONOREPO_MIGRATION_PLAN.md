# InvoiceFlow 모노레포 마이그레이션 계획

## 1. 현재 프로젝트 구조 분석

### 1.1 기술 스택

| 계층 | 기술 |
|------|------|
| 언어 | Elixir 1.15+ |
| 웹 프레임워크 | Phoenix 1.8.3 + LiveView 1.1.0 |
| DB | PostgreSQL (Ecto 3.13) |
| 백그라운드 잡 | Oban 2.17 |
| 이메일 | Swoosh + Resend (prod) |
| 인증 | bcrypt + Ueberauth (Google OAuth) |
| 파일 저장 | ExAWS S3 |
| PDF | ChromicPDF |
| 모니터링 | Sentry + Telemetry |
| CSS | Tailwind CSS v4 + DaisyUI |
| JS 번들러 | esbuild 0.25.4 |

### 1.2 현재 디렉토리 구조

```
InvoiceFlow/
├── lib/
│   ├── invoice_flow/            # 백엔드 도메인 (Context 패턴)
│   │   ├── accounts/            # User, UserToken
│   │   ├── clients/             # Client
│   │   ├── invoices/            # Invoice, InvoiceItem
│   │   ├── reminders/           # Reminder, ReminderTemplate
│   │   ├── payments/            # Payment, PaddleWebhookEvent
│   │   ├── billing/             # Subscription
│   │   ├── extraction/          # ExtractionJob (OCR)
│   │   ├── emails/              # InvoiceEmail
│   │   ├── accounts.ex          # Accounts Context
│   │   ├── clients.ex           # Clients Context
│   │   ├── invoices.ex          # Invoices Context
│   │   ├── reminders.ex         # Reminders Context
│   │   ├── payments.ex          # Payments Context
│   │   ├── billing.ex           # Billing Context
│   │   ├── extraction.ex        # Extraction Context
│   │   ├── pub_sub_topics.ex    # PubSub 토픽 헬퍼
│   │   ├── mailer.ex            # Swoosh Mailer
│   │   ├── repo.ex              # Ecto Repo
│   │   └── application.ex       # OTP Application
│   └── invoice_flow_web/        # 웹 계층 (Phoenix)
│       ├── controllers/         # PageController, UserSession, OAuth, Error
│       ├── live/                 # LiveView 페이지들
│       │   ├── dashboard_live.ex
│       │   ├── invoice_live/    # Index, Show, New, Edit, FormComponent
│       │   ├── client_live/     # Index, Show, New, Edit, FormComponent
│       │   ├── upload_live.ex
│       │   ├── user_settings_live.ex
│       │   ├── user_login_live.ex
│       │   ├── user_registration_live.ex
│       │   └── user_forgot_password_live.ex
│       ├── components/          # CoreComponents, UIComponents, Layouts
│       ├── router.ex
│       ├── endpoint.ex
│       └── user_auth.ex
├── assets/
│   ├── css/app.css              # Tailwind + DaisyUI
│   ├── js/app.js                # Phoenix LiveView JS
│   └── vendor/                  # DaisyUI theme
├── priv/
│   ├── repo/migrations/         # 8개 마이그레이션
│   └── static/                  # 정적 파일
├── config/                      # dev.exs, test.exs, prod.exs, runtime.exs
├── test/                        # ExUnit 테스트
└── mix.exs                      # 의존성 관리
```

### 1.3 DB 스키마 (7 테이블 + Oban)

```
users           - 인증, 프로필, plan 필드
clients         - user_id FK, 고객 정보
invoices        - user_id FK, client_id FK, 송장 데이터
invoice_items   - invoice_id FK, 라인 아이템
reminders       - invoice_id FK, 3단계 리마인더
payments        - invoice_id FK, 결제 기록
extraction_jobs - user_id FK, OCR 추출 결과
oban_jobs       - Oban 백그라운드 잡
```

### 1.4 API 엔드포인트 현황

현재 **REST API가 없음**. 모든 상호작용이 Phoenix LiveView (WebSocket) 기반.

| 라우트 | 타입 | 설명 |
|--------|------|------|
| `GET /welcome` | 컨트롤러 | 랜딩 페이지 |
| `POST /users/log_in` | 컨트롤러 | 세션 로그인 |
| `GET /auth/google/*` | 컨트롤러 | OAuth |
| `DELETE /users/log_out` | 컨트롤러 | 로그아웃 |
| `live /` | LiveView | 대시보드 |
| `live /invoices/*` | LiveView | 송장 CRUD |
| `live /clients/*` | LiveView | 클라이언트 CRUD |
| `live /upload` | LiveView | OCR 업로드 |
| `live /settings` | LiveView | 사용자 설정 |

---

## 2. 모노레포 목표 구조

```
invoiceflow/
├── apps/
│   ├── server/                  # Elixir/Phoenix 백엔드 (기존 코드 이동)
│   │   ├── lib/
│   │   ├── priv/
│   │   ├── config/
│   │   ├── test/
│   │   └── mix.exs
│   │
│   ├── web/                     # Phoenix LiveView 웹 프론트엔드 (기존 웹 분리)
│   │   ├── lib/invoice_flow_web/
│   │   ├── assets/
│   │   └── mix.exs
│   │
│   ├── android/                 # Android 앱
│   │   ├── app/
│   │   │   ├── src/main/
│   │   │   │   ├── java/com/invoiceflow/
│   │   │   │   │   ├── di/                  # Hilt DI 모듈
│   │   │   │   │   ├── data/
│   │   │   │   │   │   ├── remote/          # Retrofit API 클라이언트
│   │   │   │   │   │   ├── local/           # Room DB (오프라인 캐시)
│   │   │   │   │   │   └── repository/      # Repository 구현체
│   │   │   │   │   ├── domain/
│   │   │   │   │   │   ├── model/           # 도메인 모델
│   │   │   │   │   │   ├── repository/      # Repository 인터페이스
│   │   │   │   │   │   └── usecase/         # UseCase
│   │   │   │   │   └── presentation/
│   │   │   │   │       ├── navigation/      # Navigation Graph
│   │   │   │   │       ├── theme/           # Material3 테마
│   │   │   │   │       └── feature/
│   │   │   │   │           ├── auth/        # 로그인/회원가입
│   │   │   │   │           ├── dashboard/   # 대시보드
│   │   │   │   │           ├── invoice/     # 송장 목록/상세/생성
│   │   │   │   │           ├── client/      # 클라이언트 관리
│   │   │   │   │           ├── upload/      # OCR 업로드
│   │   │   │   │           └── settings/    # 설정
│   │   │   │   └── res/
│   │   │   └── build.gradle.kts
│   │   ├── gradle/
│   │   └── build.gradle.kts                 # 프로젝트 레벨
│   │
│   └── ios/                     # iOS 앱
│       ├── InvoiceFlow/
│       │   ├── App/
│       │   │   └── InvoiceFlowApp.swift
│       │   ├── Core/
│       │   │   ├── Network/                 # URLSession API 클라이언트
│       │   │   ├── Storage/                 # CoreData/SwiftData
│       │   │   └── DI/                      # 의존성 주입 (Swift Package)
│       │   ├── Domain/
│       │   │   ├── Model/                   # 도메인 모델
│       │   │   ├── Repository/              # Repository 프로토콜
│       │   │   └── UseCase/                 # UseCase
│       │   ├── Data/
│       │   │   ├── Remote/                  # API 구현체
│       │   │   ├── Local/                   # 로컬 저장소 구현
│       │   │   └── Repository/              # Repository 구현체
│       │   ├── Presentation/
│       │   │   ├── Navigation/              # NavigationStack 라우팅
│       │   │   ├── Theme/                   # 커스텀 테마
│       │   │   └── Feature/
│       │   │       ├── Auth/                # 로그인/회원가입 View+ViewModel
│       │   │       ├── Dashboard/           # 대시보드
│       │   │       ├── Invoice/             # 송장 CRUD
│       │   │       ├── Client/              # 클라이언트 관리
│       │   │       ├── Upload/              # OCR 업로드 (카메라/갤러리)
│       │   │       └── Settings/            # 설정
│       │   └── Resources/
│       ├── InvoiceFlowTests/
│       ├── InvoiceFlowUITests/
│       └── InvoiceFlow.xcodeproj
│
├── packages/                    # 공유 리소스
│   └── api-spec/                # OpenAPI 스펙 (코드 생성 소스)
│       ├── openapi.yaml
│       └── schemas/
│           ├── invoice.yaml
│           ├── client.yaml
│           ├── user.yaml
│           └── payment.yaml
│
├── docs/                        # 프로젝트 문서
├── scripts/                     # 빌드/배포 스크립트
│   ├── generate-api-clients.sh  # OpenAPI -> 각 플랫폼 클라이언트 생성
│   └── setup.sh                 # 개발환경 초기 설정
├── .github/
│   └── workflows/
│       ├── server.yml           # Elixir CI
│       ├── android.yml          # Android CI
│       └── ios.yml              # iOS CI
├── Makefile                     # 통합 빌드 명령어
└── README.md
```

---

## 3. 핵심 선결 과제: REST API 레이어 추가

현재 모든 비즈니스 로직이 LiveView에 직접 연결되어 있어, 모바일 앱이 사용할 REST API가 없음.

### 3.1 API 설계

**Base URL:** `/api/v1`

**인증:** Bearer Token (JWT 또는 Phoenix Token)

```
POST   /api/v1/auth/register        # 회원가입
POST   /api/v1/auth/login           # 로그인 -> 토큰 발급
POST   /api/v1/auth/refresh         # 토큰 갱신
POST   /api/v1/auth/google          # Google OAuth 토큰 교환
DELETE /api/v1/auth/logout           # 로그아웃

GET    /api/v1/dashboard             # KPI 데이터
GET    /api/v1/dashboard/recent      # 최근 송장

GET    /api/v1/invoices              # 송장 목록 (?status=&q=&page=&per_page=)
POST   /api/v1/invoices              # 송장 생성
GET    /api/v1/invoices/:id          # 송장 상세
PUT    /api/v1/invoices/:id          # 송장 수정
DELETE /api/v1/invoices/:id          # 송장 삭제
POST   /api/v1/invoices/:id/send     # 송장 발송
POST   /api/v1/invoices/:id/mark_paid # 결제 완료 처리

GET    /api/v1/clients               # 클라이언트 목록
POST   /api/v1/clients               # 클라이언트 생성
GET    /api/v1/clients/:id           # 클라이언트 상세
PUT    /api/v1/clients/:id           # 클라이언트 수정
DELETE /api/v1/clients/:id           # 클라이언트 삭제

POST   /api/v1/upload                # 파일 업로드 (OCR)
GET    /api/v1/extraction/:id        # 추출 결과 조회

GET    /api/v1/settings              # 사용자 설정
PUT    /api/v1/settings              # 설정 업데이트
PUT    /api/v1/settings/password     # 비밀번호 변경

POST   /api/v1/webhooks/paddle       # Paddle 결제 웹훅 (기존 계획)
```

### 3.2 API 인증 방식

```elixir
# lib/invoice_flow_web/plugs/api_auth.ex
defmodule InvoiceFlowWeb.Plugs.ApiAuth do
  # Phoenix.Token 기반 Bearer 인증
  # - 로그인 시 Phoenix.Token.sign() 으로 토큰 발급
  # - 요청 시 Authorization: Bearer <token> 헤더 검증
  # - 토큰 max_age: 30일 (refresh로 갱신)
end
```

### 3.3 JSON 응답 포맷

```json
{
  "data": { ... },
  "meta": {
    "total": 42,
    "page": 1,
    "per_page": 20
  }
}

// 에러
{
  "error": {
    "code": "validation_error",
    "message": "Invalid input",
    "details": { "field": ["can't be blank"] }
  }
}
```

---

## 4. 마이그레이션 단계별 계획

### Phase 0: 준비 (1주)

- [ ] 모노레포 루트 디렉토리 구조 생성
- [ ] 기존 Elixir 프로젝트를 `apps/server/`로 이동
- [ ] `apps/web/`으로 웹 계층 참조 분리 (Umbrella 또는 동일 앱 유지)
- [ ] Makefile 작성 (통합 빌드 명령어)
- [ ] `.github/workflows/` CI 기본 구조

> **결정 사항:** Elixir Umbrella 프로젝트 vs 단일 앱 유지
>
> **권장: 단일 앱 유지.** Phoenix Context 패턴이 이미 도메인을 잘 분리하고 있고,
> server/web 분리는 디렉토리 이동만으로 충분. Umbrella의 복잡성은 불필요.

### Phase 1: REST API 레이어 (2주)

- [ ] `api` pipeline에 JSON 인증 plug 추가
- [ ] `InvoiceFlowWeb.Plugs.ApiAuth` 구현 (Phoenix.Token 기반)
- [ ] API 컨트롤러 생성:
  - [ ] `AuthController` - 회원가입, 로그인, 토큰 갱신, Google OAuth
  - [ ] `InvoiceController` - CRUD + send + mark_paid
  - [ ] `ClientController` - CRUD
  - [ ] `DashboardController` - KPI, recent invoices
  - [ ] `UploadController` - 파일 업로드 + 추출 결과
  - [ ] `SettingsController` - 사용자 설정
- [ ] JSON View 모듈 (또는 Jason.Encoder 구현)
- [ ] API 테스트 (ConnTest)
- [ ] OpenAPI 스펙 생성 (`packages/api-spec/openapi.yaml`)
- [ ] Rate limiting plug (API용)

**핵심 원칙:** 기존 Context 함수(`Invoices.create_invoice/2`, `Invoices.send_invoice/1` 등)를
그대로 호출. 새로운 비즈니스 로직 없이 HTTP 래퍼만 추가.

### Phase 2: Android 앱 (4-5주)

#### 2.1 프로젝트 초기 설정 (3일)

- [ ] Android Studio 프로젝트 생성 (`apps/android/`)
- [ ] build.gradle.kts 설정
  - compileSdk: 35, minSdk: 26, targetSdk: 35
  - Kotlin 2.0+, AGP 8.x
- [ ] 의존성 구성:

```kotlin
// build.gradle.kts
dependencies {
    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2025.01.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // Hilt DI
    implementation("com.google.dagger:hilt-android:2.53.1")
    ksp("com.google.dagger:hilt-compiler:2.53.1")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // Room (오프라인 캐시)
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    // DataStore (토큰 저장)
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Image Loading
    implementation("io.coil-kt:coil-compose:2.7.0")

    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:21.3.0")

    // CameraX (OCR 촬영)
    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")
}
```

- [ ] Hilt Application 클래스 설정

#### 2.2 아키텍처 (MVI 패턴) (2일)

```
┌─────────────┐    ┌──────────┐    ┌────────────┐
│  Composable │───>│ ViewModel│───>│  UseCase   │
│   (View)    │<───│  (MVI)   │<───│            │
└─────────────┘    └──────────┘    └────────────┘
     Intent ──>      State ──>      Repository ──>  API/DB
```

```kotlin
// MVI Base
sealed interface UiIntent
sealed interface UiState
sealed interface UiEffect  // one-shot events (toast, navigation)

abstract class MviViewModel<I : UiIntent, S : UiState, E : UiEffect> : ViewModel() {
    private val _state = MutableStateFlow(initialState())
    val state: StateFlow<S> = _state.asStateFlow()

    private val _effect = Channel<E>(Channel.BUFFERED)
    val effect: Flow<E> = _effect.receiveAsFlow()

    abstract fun initialState(): S
    abstract fun handleIntent(intent: I)

    protected fun setState(reducer: S.() -> S) {
        _state.update(reducer)
    }

    protected fun sendEffect(effect: E) {
        viewModelScope.launch { _effect.send(effect) }
    }
}
```

#### 2.3 기능별 구현 (3-4주)

| 주차 | 기능 | 화면 |
|------|------|------|
| 1주 | Auth + Navigation | 로그인, 회원가입, Google Sign-In, 네비게이션 그래프 |
| 2주 | Dashboard + Invoice List | KPI 카드, 최근 송장, 필터/검색, 탭 |
| 3주 | Invoice CRUD + Client | 송장 생성/상세/수정, 클라이언트 CRUD |
| 4주 | Upload + Settings | 카메라/갤러리 업로드, OCR 결과, 설정 |

#### 2.4 Android 화면 -> 기존 Context 매핑

| Android 화면 | API 호출 | Phoenix Context 함수 |
|-------------|----------|---------------------|
| 로그인 | `POST /api/v1/auth/login` | `Accounts.get_user_by_email_and_password/2` |
| 대시보드 | `GET /api/v1/dashboard` | `Invoices.total_outstanding/1`, `collection_rate/1` |
| 송장 목록 | `GET /api/v1/invoices` | `Invoices.list_invoices/2`, `count_by_status/1` |
| 송장 생성 | `POST /api/v1/invoices` | `Invoices.create_invoice/2` |
| 송장 발송 | `POST /api/v1/invoices/:id/send` | `Invoices.send_invoice/1` |
| 클라이언트 목록 | `GET /api/v1/clients` | `Clients.list_clients/1` |
| OCR 업로드 | `POST /api/v1/upload` | `Extraction.create_extraction_job/2` |

### Phase 3: iOS 앱 (4-5주)

#### 3.1 프로젝트 초기 설정 (3일)

- [ ] Xcode 프로젝트 생성 (`apps/ios/`)
- [ ] 최소 지원 버전: iOS 17.0+
- [ ] Swift Package Manager 의존성:

```swift
// Package.swift (또는 Xcode SPM)
dependencies: [
    // Networking
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),

    // DI
    .package(url: "https://github.com/hmlongco/Factory.git", from: "2.4.0"),

    // Image Loading
    .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),

    // Keychain (토큰 저장)
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),

    // Google Sign-In
    .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "8.0.0"),
]
```

#### 3.2 아키텍처 (SwiftUI + MVI)

```
┌──────────┐    ┌───────────────┐    ┌──────────┐
│ SwiftUI  │───>│  Store (MVI)  │───>│ UseCase  │
│  View    │<───│ @Observable   │<───│          │
└──────────┘    └───────────────┘    └──────────┘
    Intent ──>     State ──>          Repository ──> API/Storage
               <── Effect (one-shot)
```

Android와 동일한 MVI 패턴을 Swift로 구현하여 플랫폼 간 아키텍처 일관성 유지.

```swift
// MARK: - MVI 프로토콜

protocol MviIntent {}
protocol MviState {}
protocol MviEffect {}

// MARK: - MVI Store (Base)

@Observable
class MviStore<I: MviIntent, S: MviState, E: MviEffect> {
    private(set) var state: S

    // Effect를 AsyncStream으로 전달 (one-shot: toast, navigation)
    let effects: AsyncStream<E>
    private let effectContinuation: AsyncStream<E>.Continuation

    init(initialState: S) {
        self.state = initialState
        var continuation: AsyncStream<E>.Continuation!
        self.effects = AsyncStream { continuation = $0 }
        self.effectContinuation = continuation
    }

    func send(_ intent: I) {
        // Override in subclass
    }

    func reduce(_ reducer: (inout S) -> Void) {
        reducer(&state)
    }

    func emit(_ effect: E) {
        effectContinuation.yield(effect)
    }
}

// MARK: - Example: Invoice List

enum InvoiceListIntent: MviIntent {
    case loadInvoices
    case filterByStatus(String?)
    case search(String)
    case sendInvoice(String)  // invoice id
    case markPaid(String)
}

struct InvoiceListState: MviState {
    var invoices: [Invoice] = []
    var counts: [String: Int] = [:]
    var isLoading = false
    var filter: InvoiceFilter = .init()
    var error: String?
}

enum InvoiceListEffect: MviEffect {
    case showToast(String)
    case navigateToDetail(String)
}

@Observable
final class InvoiceListStore: MviStore<InvoiceListIntent, InvoiceListState, InvoiceListEffect> {
    private let listInvoicesUseCase: ListInvoicesUseCase
    private let sendInvoiceUseCase: SendInvoiceUseCase

    init(listInvoicesUseCase: ListInvoicesUseCase, sendInvoiceUseCase: SendInvoiceUseCase) {
        self.listInvoicesUseCase = listInvoicesUseCase
        self.sendInvoiceUseCase = sendInvoiceUseCase
        super.init(initialState: InvoiceListState())
    }

    override func send(_ intent: InvoiceListIntent) {
        switch intent {
        case .loadInvoices:
            Task { @MainActor in
                reduce { $0.isLoading = true }
                do {
                    let result = try await listInvoicesUseCase.execute(filter: state.filter)
                    reduce { $0.invoices = result.invoices; $0.counts = result.counts }
                } catch {
                    reduce { $0.error = error.localizedDescription }
                }
                reduce { $0.isLoading = false }
            }
        case .filterByStatus(let status):
            reduce { $0.filter.status = status }
            send(.loadInvoices)
        case .search(let query):
            reduce { $0.filter.query = query }
            send(.loadInvoices)
        case .sendInvoice(let id):
            Task { @MainActor in
                do {
                    try await sendInvoiceUseCase.execute(invoiceId: id)
                    emit(.showToast("Invoice sent successfully"))
                    send(.loadInvoices)
                } catch {
                    emit(.showToast("Failed to send: \(error.localizedDescription)"))
                }
            }
        case .markPaid(let id):
            // similar pattern
            break
        }
    }
}

// MARK: - SwiftUI View에서 사용

struct InvoiceListView: View {
    @State private var store: InvoiceListStore

    var body: some View {
        List(store.state.invoices) { invoice in
            InvoiceRow(invoice: invoice)
        }
        .overlay { if store.state.isLoading { ProgressView() } }
        .task { store.send(.loadInvoices) }
        .task { for await effect in store.effects { handleEffect(effect) } }
    }

    private func handleEffect(_ effect: InvoiceListEffect) {
        switch effect {
        case .showToast(let message):
            // show toast
            break
        case .navigateToDetail(let id):
            // navigate
            break
        }
    }
}
```

#### 3.3 기능별 구현 (3-4주)

| 주차 | 기능 | 화면 |
|------|------|------|
| 1주 | Auth + Navigation | 로그인, 회원가입, Google Sign-In, NavigationStack |
| 2주 | Dashboard + Invoice List | KPI 카드, 최근 송장, 필터/검색 |
| 3주 | Invoice CRUD + Client | 송장 생성/상세/수정, 클라이언트 CRUD |
| 4주 | Upload + Settings | PHPicker/카메라, OCR 결과, 설정 |

#### 3.4 iOS 특화 기능

- **PHPickerViewController**: 갤러리 이미지 선택
- **AVCaptureSession**: 카메라로 송장 촬영
- **VNRecognizeTextRequest**: 기기 내 1차 OCR (선택적, 서버 전송 전 프리뷰)
- **WidgetKit**: 대시보드 KPI 위젯
- **Push Notification**: 리마인더 발송/결제 완료 알림

### Phase 4: 공유 리소스 및 CI/CD (1주)

- [ ] OpenAPI 스펙에서 클라이언트 코드 자동 생성
  - Android: `openapi-generator` Kotlin 클라이언트
  - iOS: `openapi-generator` Swift 클라이언트
- [ ] GitHub Actions 워크플로우:
  - `server.yml`: `mix test`, `mix credo`, `mix format --check-formatted`
  - `android.yml`: `./gradlew testDebug`, `./gradlew lintDebug`
  - `ios.yml`: `xcodebuild test`
- [ ] 푸시 알림 인프라 (FCM + APNs)
- [ ] Fastlane 배포 파이프라인 (Android + iOS)

---

## 5. 타임라인 요약

```
Phase 0 (1주)  : 모노레포 구조 + 기존 코드 이동
Phase 1 (2주)  : REST API 레이어 추가 + OpenAPI 스펙
Phase 2 (4-5주): Android 앱 (Kotlin, Hilt, Compose, MVI)
Phase 3 (4-5주): iOS 앱 (Swift, SwiftUI, MVI)
Phase 4 (1주)  : CI/CD + 공유 리소스 + 푸시 알림
─────────────────────────────────────────────────
총 예상: 12-14주 (Phase 2, 3 병렬 진행 시 8-10주)
```

### 병렬 진행 가능 구간

```
Week 1    : [Phase 0 - 모노레포 구조]
Week 2-3  : [Phase 1 - REST API]
Week 4-8  : [Phase 2 - Android] ←── 병렬 ──→ [Phase 3 - iOS]
Week 9    : [Phase 4 - CI/CD + 통합]
```

---

## 6. 기술적 고려사항

### 6.1 오프라인 지원 전략

| 플랫폼 | 로컬 DB | 동기화 |
|--------|---------|--------|
| Android | Room | API 호출 실패 시 큐잉, 네트워크 복구 시 재전송 |
| iOS | SwiftData | 동일 |

**오프라인 가능 기능:** 송장 목록 조회(캐시), 송장 생성(큐잉), 설정 변경(큐잉)
**온라인 필수 기능:** 송장 발송, OCR 업로드, 결제 처리

### 6.2 푸시 알림

```
서버 (Oban Worker) ──> FCM/APNs ──> 모바일 앱

알림 트리거:
- 리마인더 발송 완료
- 결제 완료 (Paddle webhook)
- OCR 추출 완료
- 송장 연체 경고
```

Elixir 라이브러리: `pigeon` (FCM + APNs 통합)

### 6.3 인증 흐름 (모바일)

```
[모바일 앱]                    [Phoenix API]
    │                              │
    ├─ POST /auth/login ──────────>│
    │  {email, password}           │
    │                              ├─ Accounts.get_user_by_email_and_password
    │<─── {token, user} ──────────┤
    │                              │
    ├─ GET /invoices ─────────────>│
    │  Authorization: Bearer <tok> │
    │                              ├─ ApiAuth plug -> 토큰 검증
    │<─── {data: [...]} ──────────┤
```

### 6.4 실시간 업데이트 (향후)

현재 LiveView PubSub 시스템은 WebSocket 기반.
모바일에서는 다음 옵션 중 선택:

1. **폴링 (MVP)**: 30초 간격 대시보드 갱신 - 가장 단순
2. **SSE (Server-Sent Events)**: 단방향 실시간 - 중간 복잡도
3. **Phoenix Channels**: 양방향 WebSocket - 기존 인프라 활용 가능

**권장:** MVP는 폴링, v2에서 Phoenix Channels 추가.

---

## 7. 위험 요소 및 대응

| 위험 | 영향 | 대응 |
|------|------|------|
| REST API 없는 상태에서 모바일 개발 불가 | 차단 | Phase 1을 최우선으로 완료 |
| OpenAPI 스펙-구현 불일치 | 런타임 에러 | 컨트롤러 테스트에서 스펙 검증 |
| 이미지 업로드 (multipart) 모바일 구현 복잡 | 지연 | 서명된 URL 직접 업로드 방식 고려 |
| Google OAuth 모바일 플로우 다름 | 인증 실패 | ID Token 교환 방식으로 통일 |
| 오프라인-온라인 동기화 충돌 | 데이터 손실 | 서버 타임스탬프 기반 LWW (Last-Write-Wins) |
