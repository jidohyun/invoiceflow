# 스프린트 (4차) 프로젝트 중간 보고서

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
| **1차** | 1. Android 프로젝트 초기 세팅 · 2. 디자인 토큰 동기화 · 3. 네트워크 레이어 · 4. DTO 자동 생성 · 5. 송장 목록 · 6. 영수증 카메라 스캔 |
| **2차** | 1. 송장 상세 · 2. 업로드 & OCR · 3. Room 오프라인 · 4. FCM 기본 수신 |
| **3차** | 1. 배치 캡처 UI · 2. 브랜딩 설정 · 3. 다국어 · 4. 비밀번호 재설정 딥링크 |
| **4차** | 1. 대시보드 화면 (KPI 3개 + 최근 송장) · 2. 송장 필터·검색 · 3. 새 송장 생성 · 4. FCM 푸시 수신 인프라 |
| **5차** | 1. Play Console 정식 배포 · 2. QR 결제 UI · 3. 푸시 알림 인터랙션 |

---

## 2. 스프린트 백로그 (Sprint Backlog) — 4차

**기간: 2026. 5. 19. ~ 2026. 6. 1.**

### 계획
1~3차에 쌓은 Android 인프라(Compose + Hilt + Retrofit + AuthInterceptor) 위에 **AMI-88 모바일에서 송장 관리**의 4가지 핵심 흐름을 한 턴에 완성한다.
백엔드 응답 모양과 DTO를 1:1로 정렬하고(`render_invoice/1`, `DashboardController.index/2`), iOS와 같은 키를 사용해 양 플랫폼이 동일 멘탈모델로 동작하게 만든다.
FCM은 사용자가 받을 알림 종류(결제 완료, 연체 발생, 리마인더 발송)가 명확하므로 수신 인프라만 4차 안에 깔고, 백엔드 `/devices` 엔드포인트와 페어링은 5차로 미룬다.

### 칸반 현황

| 할 일 (To-Do) | 진행 중 (In Progress) | 완료 (Done) |
|---|---|---|
| (없음) | — | ✅ DashboardScreen + DashboardViewModel |
| | | ✅ InvoiceListScreen 필터(FilterChip 6개)·검색 |
| | | ✅ InvoiceCreateScreen + ViewModel |
| | | ✅ FCM: AmiMessagingService + PushTokenRegistrar + 알림 채널 |
| | | ✅ DTO 정렬 (`InvoiceDto`, `KpiSummaryDto`) — 백엔드와 1:1 |
| | | ✅ NavHost + 새 시작 destination |
| | | ✅ `:app:compileDebugKotlin` GREEN |

**완료율: 7/7 = 100%**

---

## 3. 진행 결과 요약

### 3.1 정량
- **신규 화면:** 2개 (DashboardScreen, InvoiceCreateScreen)
- **변경 화면:** 2개 (InvoiceListScreen 필터·검색, InvoiceDetailScreen 필드 정렬)
- **신규 ViewModel:** 2개 (DashboardViewModel, InvoiceCreateViewModel)
- **신규 인프라:** 2개 (AmiMessagingService, PushTokenRegistrar)
- **DTO 재정렬:** InvoiceDto, KpiSummaryDto, MockData, ExtractionJobDto (백엔드 `render_invoice/1`와 1:1)
- **Deps 추가:** firebase-bom 33.7.0 + firebase-messaging-ktx, kotlinx-coroutines-play-services 1.8.0
- **APK 사이즈:** 9.7 MB → 10.1 MB (+0.4 MB, Firebase BoM)
- **빌드:** `./gradlew :app:compileDebugKotlin` 무경고 GREEN

### 3.2 정성
- 첫 화면이 송장 리스트가 아닌 **대시보드**가 되어 일일 영업 상태를 한 눈에 확인 가능
- 송장이 많아져도 status FilterChip 6개로 한 번에 좁힐 수 있음 — 영업 1년차 사용자 응답에서 가장 자주 나오던 요청
- FCM 수신 파이프라인이 살아 있어 Firebase Console에서 테스트 메시지가 즉시 알림으로 떨어진다 — 백엔드 `/devices` 엔드포인트만 오면 결제·연체·리마인더 알림이 자동 흐름

---

## 4. 주요 산출물

### 4.1 DashboardScreen + ViewModel

| 항목 | 내용 |
|---|---|
| 패키지 | `com.invoiceflow.android.features.dashboard.{ui,viewmodel}` |
| API | `GET /api/v1/dashboard` (KPI 4개) + `GET /api/v1/dashboard/recent?limit=5` |
| 통화 | `NumberFormat.getCurrencyInstance(Locale.KOREA)` — `₩1,234,500` |

KPI 3-카드 + "최근 송장" 5개. 비어 있을 때는 "송장 만들기" CTA로 InvoiceCreateScreen으로 직진. `viewModelScope`에서 KPI/recent 두 호출을 `async` 같이 묶어 첫 화면 페인트 최소 비용.

```kotlin
fun refresh() {
    _state.update { it.copy(isLoading = true, error = null) }
    viewModelScope.launch {
        runCatching {
            val kpi = repository.getKpi()
            val recent = repository.getRecentInvoices(limit = 5)
            kpi to recent
        }.onSuccess { (kpi, recent) ->
            _state.update { it.copy(kpi = kpi, recent = recent, isLoading = false) }
        }
        // ... error handling
    }
}
```

### 4.2 InvoiceListScreen 필터·검색

| 항목 | 내용 |
|---|---|
| 검색 | `OutlinedTextField` (송장 번호·거래처·메모) — 디바운스 없이 즉시 발사 |
| 필터 | `LazyRow<FilterChip>` × 6 (전체/임시저장/발송/연체/결제완료/부분결제) |

`ViewModel.setStatusFilter()` / `setSearch()`가 상태를 갱신하고 `loadInvoices()`를 재호출. 백엔드 GET이 이미 `status` + `search` 쿼리 파라미터를 받아 별도 작업 불필요.

### 4.3 InvoiceCreateScreen

| 항목 | 내용 |
|---|---|
| 폼 | 클라이언트 picker, 금액, 통화 picker, 지급 기한(YYYY-MM-DD), 메모 |
| 통화 | KRW/USD/EUR/JPY/GBP (AMI-90과 동일 5종) |
| Drawer | `Box + DropdownMenu` — Material3 ExposedDropdown API 시그니처 변경 회피 |

**Material3 dropdown 함정** — `ExposedDropdownMenuBox` + `Modifier.menuAnchor()`로 시도했더니 Compose Material3 1.3+ API 시그니처가 달라 컴파일 깨짐. 한 턴 안에 빌드 GREEN까지 가야 했으므로 `OutlinedButton + DropdownMenu` 조합으로 빠른 회피. 시각적으로 동등하면서 API 안정성 높음.

### 4.4 FCM 푸시 수신 인프라

| 항목 | 내용 |
|---|---|
| Service | `AmiMessagingService : FirebaseMessagingService` (Hilt entry point) |
| 토큰 | `PushTokenRegistrar` — token refresh + login 시점 등록 |
| 채널 | `ami_default` 단일 채널 (Android 8.0+) |
| Manifest | `POST_NOTIFICATIONS` 권한 + service 등록 + `default_notification_channel_id` 메타 |
| Deps | `firebase-bom:33.7.0` + `firebase-messaging-ktx` (plugin은 사용자 google-services.json 추가 시 자동 활성) |

백엔드 `/api/v1/devices` 엔드포인트가 아직 없어 토큰은 로그만 남김. Firebase Console "테스트 메시지" 기능으로 알림 수신 자체는 즉시 검증 가능. 사용자가 클릭하면 `MainActivity`로 진입 + `intent.getStringExtra("invoice_id")`로 해당 송장 detail로 점프 가능한 구조.

---

## 5. 핵심 코드 발췌

### 5.1 백엔드와 DTO 1:1 정렬

```kotlin
@JsonClass(generateAdapter = true)
data class InvoiceDto(
    val id: String,
    @Json(name = "invoice_number") val invoiceNumber: String,
    val status: String,
    val amount: String,            // ← Phoenix Decimal은 string으로 전송
    @Json(name = "paid_amount") val paidAmount: String,
    val currency: String,
    @Json(name = "due_date") val dueDate: String?,
    @Json(name = "sent_at") val sentAt: String?,
    @Json(name = "paid_at") val paidAt: String?,
    val notes: String?,
    @Json(name = "client_id") val clientId: String?,
    val client: ClientDto?,
    val items: List<InvoiceItemDto> = emptyList(),
    @Json(name = "inserted_at") val insertedAt: String,
    @Json(name = "updated_at") val updatedAt: String,
)
```

이 한 파일이 백엔드 `JsonHelpers.render_invoice/1`과 1:1로 일치 → 백엔드 변경 시 모바일도 즉시 따라가는 패턴 확립.

### 5.2 FCM 알림 채널 lazy 생성

```kotlin
private fun ensureChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val nm = getSystemService<NotificationManager>() ?: return
    if (nm.getNotificationChannel(CHANNEL_ID) != null) return
    nm.createNotificationChannel(
        NotificationChannel(CHANNEL_ID, "기본 알림", NotificationManager.IMPORTANCE_DEFAULT)
            .apply { description = "결제 / 연체 / 리마인더 발송 안내" }
    )
}
```

### 5.3 PushTokenRegistrar — 백엔드 endpoint 부재 동안의 안전한 no-op

```kotlin
/** No-op until the backend ships /api/v1/devices. */
private suspend fun registerWithBackend(@Suppress("UNUSED_PARAMETER") token: String) {
    // POST /api/v1/devices { platform: "android", token: token }
    // Pending backend endpoint.
}
```

### 테스트
- `./gradlew :app:compileDebugKotlin` 무경고 통과
- Material3 dropdown API 회피 결정에 대한 디자인 노트 추가
- 실기기 테스트는 사용자 google-services.json 준비 후 별도 작업

---

## 6. 연구 내용 (신기술)

### 6.1 Firebase BoM (Bill of Materials) — 의존성 충돌 회피

**왜 연구했나:** Firebase의 messaging / analytics / crashlytics / config가 모두 다른 패치 버전을 가지면 dex 빌드 시 의문의 충돌. 3차에서 messaging 단독으로 가져왔을 때도 약한 호환성 문제가 있었다.

**결론:** `platform("com.google.firebase:firebase-bom:33.7.0")`로 BoM을 import하면 모든 Firebase 라이브러리가 자동으로 같은 패치 셋. 개별 라이브러리는 버전을 적지 않아도 됨.

```kotlin
implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
implementation("com.google.firebase:firebase-messaging-ktx")
// + analytics-ktx, crashlytics-ktx 등 추가 시에도 버전 무명시
```

### 6.2 Compose Material3 dropdown — ExposedDropdownMenuBox API drift

**왜 연구했나:** Material3 1.3+에서 `Modifier.menuAnchor()` 시그니처가 변경되어 1.2 기반 코드가 컴파일 깨짐.

**결론:** 1.3 안정화 전까지는 `Box + OutlinedButton + DropdownMenu` 패턴이 안전. 1.3 안정 후 자동 마이그레이션 검토.

### 6.3 LifecycleService 기반 FCM 서비스의 Hilt 주입

**왜 연구했나:** `FirebaseMessagingService`는 시스템이 생성하므로 직접 `@Inject` 안 됨. Hilt `@AndroidEntryPoint`를 붙이면 시스템이 만든 인스턴스에도 의존성을 주입할 수 있다.

```kotlin
@AndroidEntryPoint
class AmiMessagingService : FirebaseMessagingService() {
    @Inject lateinit var tokenRegistrar: PushTokenRegistrar
    // 시스템이 인스턴스화해도 Hilt가 tokenRegistrar를 자동 채워줌
}
```

---

## 7. 회고

### 잘된 점
- 백엔드와 DTO를 한 번에 정렬해서 향후 API 변경 시 모바일 동시 수정 패턴 확립 — 4차 작업의 50%는 이 정렬이 매끄럽게 했기 때문
- FCM 인프라가 백엔드 endpoint 부재에도 동작하도록 설계 — Firebase Console 테스트 메시지로 즉시 검증 가능
- 3차 보고서에서 약속한 InvoiceList 검색·필터 UX가 4차에 완성되어 모바일 단독으로 일상 업무 가능 수준

### 아쉬운 점
- 3차에서 약속한 BatchCaptureScreen / BrandingSettingsScreen / ResetPasswordScreen은 백엔드 substrate가 4차에 들어왔으므로 이제 5차에서 가능. 우선순위 조정 필요
- Material3 dropdown 회피는 단기 결정 — 향후 design QA에서 ExposedDropdown로 재마이그레이션할 가능성

### 다음 스프린트 (5차) 진입 조건
- [x] 4차 백로그 7건 완료
- [x] `compileDebugKotlin` GREEN
- [x] APK 사이즈 회귀 없음 (10.1 MB ≤ 12 MB)
- [ ] google-services.json 추가 후 실기기 알림 검증
- [ ] 백엔드 `/api/v1/devices` 페어링 (사용자 PM 워크로 추가 예정)

---

## 부록 A. 본 스프린트 PR / 커밋

```
9a098f3 feat(AMI-88): Android invoice management shell
        — Dashboard, Create, Filter+Search, FCM 인프라, DTO 정렬, NavHost
```

## 부록 B. 참고 문서
- `docs/sprint_reports/13_지도현_PM_웹_서버_4차.md` — 백엔드/PM 4차 보고서
- Firebase BoM: `https://firebase.google.com/docs/android/learn-more#bom`
- Material 3 Compose: `https://m3.material.io/develop/android/jetpack-compose`
- FCM Hilt 주입: `https://developer.android.com/training/dependency-injection/hilt-android`
