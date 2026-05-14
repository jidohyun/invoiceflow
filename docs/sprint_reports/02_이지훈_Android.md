# 스프린트 (1차) 프로젝트 중간 보고서

| 항목 | 내용 |
|---|---|
| **프로젝트명** | AutoMyInvoice — AI 기반 자동 송장 리마인더 SaaS |
| **학번** | _(학번 기재)_ |
| **성명** | **이지훈** |
| **역할** | Android 앱 개발 |

---

## 1. 제품 백로그 (Product Backlog)

| 스프린트 | 제품 백로그 (Android 파트) |
|---|---|
| **1차** | 1. Android 프로젝트 초기 세팅 (Compose + Hilt + MVI) · 2. 디자인 토큰 웹과 동기화 · 3. 네트워크 레이어 (Retrofit + OkHttp) · 4. OpenAPI 3.1 스펙 기반 DTO 자동 생성 · 5. 송장 목록 화면 · 6. 영수증 카메라 스캔 버튼 |
| **2차** | 1. 송장 상세 화면 · 2. 업로드 & OCR 플로우 · 3. 오프라인 캐싱 (Room) · 4. 푸시 알림(FCM) 기본 수신 |
| **3차** | 1. 영수증 배치 촬영 UI · 2. 브랜딩 설정 화면 · 3. 다국어 지원 (ko/en) |
| **4차** | 1. 모바일 MVP TestFlight/Play Console 배포 · 2. QR 현장 결제 UI · 3. 푸시 알림 인터랙션 |

---

## 2. 스프린트 백로그 (Sprint Backlog) — 1차

**기간: 2025. 4. 1. ~ 2025. 4. 14.**

### 계획
Android 앱 MVP의 기반 인프라(프로젝트 구조, DI, 디자인 시스템, 네트워크)를 완성하고
핵심 화면 하나(송장 목록)에서 API 연동을 엔드투엔드로 증명한다.

### 칸반 현황

| 할 일 (To-Do) | 진행 중 (In Progress) | 완료 (Done) |
|---|---|---|
| (없음) | — | ✅ Android 프로젝트 스캐폴딩 (Compose + Hilt + MVI) |
| | | ✅ 디자인 토큰(색상·타이포) 웹과 동기화 |
| | | ✅ Retrofit + OkHttp 네트워크 레이어 |
| | | ✅ OpenAPI 스펙 기반 DTO 자동 생성 |
| | | ✅ 송장 목록 화면 구현 |
| | | ✅ 영수증 카메라 스캔 버튼 추가 |
| | | ✅ API 레이어 OpenAPI 정합성 정렬 (PR #6) |

**완료율: 7/7 = 100%**

### 일간 계획

| 날짜 | 오늘 진행할 작업 |
|---|---|
| 4/1 (화) | 킥오프, Android Studio 환경 세팅 |
| 4/2 (수) | Compose + Hilt + MVI 구조 설계·적용 |
| 4/3 (목) | 디자인 토큰(Color, Typography, Shape) 적용 |
| 4/4 (금) | Theme & 공통 Composable 컴포넌트 |
| 4/7 (월) | Retrofit + OkHttp 인터셉터 + Bearer 토큰 |
| 4/8 (화) | OpenAPI 기반 DTO 자동 생성 (openapi-generator) |
| 4/9 (수) | 송장 목록 ViewModel + Reducer |
| 4/10 (목) | 송장 목록 LazyColumn UI |
| 4/11 (금) | 영수증 카메라 스캔 버튼 추가 |
| 4/14 (월) | API 레이어 점검 PR 머지, 알파 빌드 |

---

## 3. 데일리 스크럼

> ※ 노션 회의록 일자별 캡처 첨부 자리

### 1주차

**4/1 (화)**
- 참가자: 지도현, 이지훈, 하동건, 신용철
- 한 일: 킥오프, Android Studio + JDK 17 환경 세팅
- 할 일: 프로젝트 스캐폴딩 시작
- 이슈: 없음

**4/2 (수)**
- 한 일: Compose + Hilt 초기 설정 완료, MVI 아키텍처 레이어 정리
- 할 일: 디자인 토큰 초안 적용
- 이슈: ⚠️ Compose BOM 버전과 Kotlin 버전 충돌 → 2.0.0 매트릭스로 통일

**4/3 (목)**
- 한 일: 디자인 토큰 Color/Typography/Shape 적용
- 할 일: 공통 Composable(Button, Card) 만들기
- 이슈: 없음

**4/4 (금)**
- 한 일: Theme 완성, DarkTheme/LightTheme 분리
- 할 일: 네트워크 레이어 설계
- 이슈: 없음

**4/7 (월)**
- 한 일: Retrofit + OkHttp 인터셉터 + Bearer 토큰 + Moshi 직렬화
- 할 일: OpenAPI 기반 DTO 자동 생성
- 이슈: 없음

### 2주차

**4/8 (화)**
- 한 일: openapi-generator로 Kotlin DTO 자동 생성 성공
- 할 일: 송장 목록 화면 ViewModel
- 이슈: 🔴 서버 응답 필드 명(snake_case vs camelCase)이 스펙과 불일치 → PM과 협의 후 스펙 기준으로 정렬

**4/9 (수)**
- 한 일: InvoiceListViewModel (MVI Intent/State/Reducer)
- 할 일: LazyColumn UI 구현
- 이슈: 없음

**4/10 (목)**
- 한 일: 송장 목록 UI 완성 + Preview
- 할 일: 카메라 버튼 추가
- 이슈: 없음

**4/11 (금)**
- 한 일: 송장 목록 상단 FAB에 카메라 스캔 버튼 추가
- 할 일: API 전체 정합성 점검
- 이슈: 없음

**4/14 (월)**
- 한 일: API 레이어 OpenAPI 정합성 정렬 PR 머지, 알파 APK 빌드
- 할 일: Sprint 2 계획
- 이슈: 없음

---

## 4. 이슈 (Issue)

### 발생 이슈 2가지

**1. Compose BOM · Kotlin 버전 매트릭스 충돌**
- 현상: `compose-bom:2024.02.00` + Kotlin `1.9.x` 조합에서 Compose Compiler 플러그인 버전 에러로 빌드 실패.
- 영향: 초기 이틀간 개발 블로킹.

**2. API 응답 필드명이 OpenAPI 스펙과 불일치**
- 현상: 서버가 일부 필드를 camelCase로 응답하는 반면, OpenAPI 스펙은 snake_case로 명시 → Moshi 파싱 실패.
- 영향: 송장 목록 화면 API 연동 실패.

### 2가지 이슈의 처리 방법 및 결과

**이슈 1 처리**
- Compose BOM을 `2024.04.00`으로 올리고 Kotlin `2.0.0` + Compose Compiler Plugin으로 전환.
- `libs.versions.toml`에 한 곳에서 버전 고정, 모듈별로는 참조만 하게 구조 개편.
- **결과:** 빌드 안정화, 향후 버전 매트릭스 충돌 재발 방지.

**이슈 2 처리**
- PM과 협의, OpenAPI 스펙(snake_case)을 SSOT로 확정. 서버 JSON 인코더를 snake_case로 통일.
- 클라이언트는 `@SerializedName`/Moshi `@Json` 어노테이션 없이도 스펙 기반 자동 생성 DTO를 그대로 사용 가능하게 정리.
- **결과:** 자동 생성 DTO로 송장 목록 API 성공적으로 연동, 스펙-구현 정합성 확보. (PR #6)

### 이슈 처리율 — **100% (2/2 해결)**

### 이슈 처리 코드

**이슈 1 — Compose BOM 버전 정렬**
```toml
# gradle/libs.versions.toml
[versions]
kotlin = "2.0.0"
compose-bom = "2024.04.00"
compose-compiler = "1.5.14"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }

[plugins]
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
```

**이슈 2 — 서버 snake_case 강제 디코딩**
```kotlin
// network/NetworkModule.kt
val moshi = Moshi.Builder()
    .add(KotlinJsonAdapterFactory())
    .build()

val retrofit = Retrofit.Builder()
    .baseUrl(BuildConfig.API_BASE_URL)
    .addConverterFactory(MoshiConverterFactory.create(moshi))
    .client(okHttpClient)
    .build()

// OpenAPI 자동 생성 DTO (필드명 자동 매핑)
@JsonClass(generateAdapter = true)
data class InvoiceDto(
    val id: String,
    val invoice_number: String,
    val amount: String,
    val currency: String,
    val due_date: String,
    val status: String
)
```

---

## 5. 개발 내용

### 핵심 화면
- **송장 목록 (InvoiceListScreen)**: LazyColumn, 상태별 색상 뱃지, 당겨서 새로고침, 카메라 FAB

> 스크린샷 첨부 위치:
> - `apps/android/screenshots/invoice_list.png`
> - `apps/android/screenshots/camera_fab.png`

### MVI 구조

```kotlin
// InvoiceListViewModel.kt
sealed interface InvoiceListIntent {
    data object Load : InvoiceListIntent
    data object Refresh : InvoiceListIntent
    data class FilterByStatus(val status: String?) : InvoiceListIntent
}

data class InvoiceListState(
    val isLoading: Boolean = false,
    val invoices: List<Invoice> = emptyList(),
    val filter: String? = null,
    val error: String? = null
)

@HiltViewModel
class InvoiceListViewModel @Inject constructor(
    private val repository: InvoiceRepository
) : ViewModel() {
    private val _state = MutableStateFlow(InvoiceListState())
    val state: StateFlow<InvoiceListState> = _state.asStateFlow()

    fun onIntent(intent: InvoiceListIntent) {
        when (intent) {
            is InvoiceListIntent.Load -> loadInvoices()
            is InvoiceListIntent.Refresh -> loadInvoices(force = true)
            is InvoiceListIntent.FilterByStatus -> {
                _state.update { it.copy(filter = intent.status) }
                loadInvoices()
            }
        }
    }

    private fun loadInvoices(force: Boolean = false) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        repository.listInvoices(status = _state.value.filter).onSuccess { list ->
            _state.update { it.copy(isLoading = false, invoices = list, error = null) }
        }.onFailure { e ->
            _state.update { it.copy(isLoading = false, error = e.message) }
        }
    }
}
```

### Compose UI

```kotlin
@Composable
fun InvoiceListScreen(
    viewModel: InvoiceListViewModel = hiltViewModel(),
    onInvoiceClick: (String) -> Unit,
    onCameraClick: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = onCameraClick) {
                Icon(Icons.Default.CameraAlt, contentDescription = "영수증 촬영")
            }
        }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding)) {
            items(state.invoices, key = { it.id }) { invoice ->
                InvoiceRow(invoice = invoice, onClick = { onInvoiceClick(invoice.id) })
            }
        }
    }
}
```

---

## 6. 연구 내용 (신기술)

### 6.1 MVI (Model-View-Intent) 아키텍처

**왜 연구했나:** MVVM은 상태가 분산되기 쉬워 디버깅이 어려움. Compose + 단방향 데이터 흐름에 부합하는 MVI가 적합.

**결론:** `Intent → Reducer → State → View` 단방향 파이프라인으로 통일.
- `State`는 불변 data class, Compose에서 `collectAsStateWithLifecycle`로 관찰.
- 모든 사이드이펙트(API 호출 등)는 ViewModel 내부에 격리.

### 6.2 OpenAPI Generator → Kotlin DTO 자동 생성

**왜 연구했나:** 수동으로 DTO를 작성하면 서버 스펙 변경 시 동기화 부담이 큼.

**적용:**
```gradle
plugins {
  id("org.openapi.generator") version "7.5.0"
}

openApiGenerate {
    generatorName.set("kotlin")
    inputSpec.set("$rootDir/../../packages/api-spec/openapi.yaml")
    outputDir.set("$buildDir/generated/openapi")
    apiPackage.set("com.automyinvoice.api")
    modelPackage.set("com.automyinvoice.api.model")
    configOptions.set(mapOf(
        "library" to "jvm-retrofit2",
        "serializationLibrary" to "moshi"
    ))
}
```
스펙이 바뀌면 `./gradlew openApiGenerate` 한 줄로 DTO·API 인터페이스 재생성.

### 6.3 Hilt 의존성 주입 + Compose 통합

**왜 연구했나:** 멀티 모듈 구성에서 싱글턴(OkHttp, Retrofit, Repository)을 안전하게 주입해야 함.

**적용:**
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides @Singleton
    fun provideOkHttp(authInterceptor: AuthInterceptor): OkHttpClient =
        OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(HttpLoggingInterceptor().setLevel(HttpLoggingInterceptor.Level.BODY))
            .build()

    @Provides @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(client)
            .addConverterFactory(MoshiConverterFactory.create())
            .build()
}
```

`@HiltViewModel` + `hiltViewModel()` 조합으로 Compose 화면에서 선언형으로 주입.
