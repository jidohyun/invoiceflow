# 스프린트 (2차) 프로젝트 중간 보고서

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

## 2. 스프린트 백로그 (Sprint Backlog) — 2차

**기간: 2025. 4. 15. ~ 2025. 4. 28.**

### 계획
1차에 완성한 송장 목록 위에 송장 상세 / 영수증 업로드 OCR 플로우 / Room 오프라인 캐싱 / FCM 푸시 수신을 더해
모바일 MVP를 엔드투엔드 사용 가능한 상태까지 끌어올린다.

### 칸반 현황

| 할 일 (To-Do) | 진행 중 (In Progress) | 완료 (Done) |
|---|---|---|
| (없음) | — | ✅ 송장 상세 화면 (InvoiceDetailScreen) |
| | | ✅ 영수증 업로드 + OCR 결과 프리뷰 |
| | | ✅ Room 기반 오프라인 캐싱 |
| | | ✅ NetworkBoundResource (single source of truth) |
| | | ✅ FCM 토큰 등록 + 기본 알림 수신 |
| | | ✅ Pull-to-refresh / 에러 retry 표준화 |
| | | ✅ 메모리 누수 / Leak 점검 (LeakCanary) |

**완료율: 7/7 = 100%**

### 일간 계획

| 날짜 | 오늘 진행할 작업 |
|---|---|
| 4/15 (화) | Sprint 2 킥오프, 송장 상세 화면 와이어 |
| 4/16 (수) | InvoiceDetail ViewModel + UI 구현 |
| 4/17 (목) | 업로드 화면 (multipart/form-data) |
| 4/18 (금) | OCR 결과 프리뷰 + 신뢰도 뱃지 |
| 4/21 (월) | Room DB 스키마 설계 (Invoice, Reminder) |
| 4/22 (화) | NetworkBoundResource 패턴 도입 |
| 4/23 (수) | 오프라인 캐싱 정합성 테스트 |
| 4/24 (목) | FCM 의존성 + Firebase 프로젝트 연결 |
| 4/25 (금) | 푸시 토큰 서버 등록 + 알림 수신 |
| 4/28 (월) | LeakCanary 점검, 알파 빌드 |

---

## 3. 데일리 스크럼

> ※ 노션 회의록 일자별 캡처 첨부 자리

### 1주차

**4/15 (화)**
- 참가자: 지도현, 이지훈, 하동건, 신용철
- 한 일: Sprint 2 킥오프, 상세 화면 와이어프레임
- 할 일: InvoiceDetail ViewModel
- 이슈: 없음

**4/16 (수)**
- 한 일: InvoiceDetailViewModel + Compose UI 1차
- 할 일: 업로드 화면
- 이슈: 없음

**4/17 (목)**
- 한 일: multipart/form-data 업로드 (Retrofit `@Part`)
- 할 일: OCR 프리뷰
- 이슈: ⚠️ 큰 이미지(8MB+) 업로드 시 OOM → Bitmap 다운샘플링 필요

**4/18 (금)**
- 한 일: 이미지 리사이즈(최대 2000px), OCR 결과 카드 + 신뢰도 색상 뱃지
- 할 일: Room 스키마
- 이슈: 없음

**4/21 (월)**
- 한 일: Room Entity (Invoice, Reminder), DAO, Migration v1→v2
- 할 일: NetworkBoundResource
- 이슈: 없음

### 2주차

**4/22 (화)**
- 한 일: NetworkBoundResource 추상화 (Local + Remote → Flow)
- 할 일: 캐싱 정합성 테스트
- 이슈: 🔴 동시 새로고침과 캐시 invalidate가 경쟁 → Flow `distinctUntilChanged` + `Mutex`로 해결

**4/23 (수)**
- 한 일: 캐시 정합성 테스트 (오프라인 후 온라인 전환 시 머지)
- 할 일: FCM 세팅
- 이슈: 없음

**4/24 (목)**
- 한 일: Firebase 프로젝트 연결, `google-services.json`, FCM SDK 추가
- 할 일: 토큰 서버 등록
- 이슈: 🔴 Android 13+ POST_NOTIFICATIONS 런타임 권한 요청 누락 → 알림 표시 안됨

**4/25 (금)**
- 한 일: 권한 요청 플로우 추가, 토큰을 백엔드 `/api/v1/devices`에 등록, 백그라운드 알림 수신 확인
- 할 일: LeakCanary 점검
- 이슈: 없음

**4/28 (월)**
- 한 일: LeakCanary 1주간 dogfooding, 누수 0건 확인, 알파 APK 빌드
- 할 일: Sprint 3 계획
- 이슈: 없음

---

## 4. 이슈 (Issue)

### 발생 이슈 2가지

**1. 큰 영수증 이미지 업로드 시 OOM**
- 현상: 8MB 이상 사진을 그대로 multipart 인코딩하면 디바이스 메모리 부족으로 크래시.
- 영향: 카메라 고화질 촬영 사용자가 업로드 자체를 못 함.

**2. Android 13+ 푸시 알림 권한 누락**
- 현상: FCM 메시지는 수신되지만 Notification이 시스템에 표시되지 않음. logcat에 `Notification not posted` 경고만 출력.
- 영향: 새 송장/결제 알림 사용자에게 도달 불가.

### 2가지 이슈의 처리 방법 및 결과

**이슈 1 처리**
- 업로드 전 Bitmap 디코딩 시 `inSampleSize` 계산으로 최대 2000px로 다운샘플 + JPEG 품질 85.
- 백그라운드 디스패처(`Dispatchers.IO`)에서 처리해 UI 스레드 영향 없게 변경.
- 메모리 사용량 90MB → 14MB.
- **결과:** 8MB 원본도 안정적 업로드, OCR 정확도 변화 없음(서버 측에서도 큰 이미지 다운샘플링).

**이슈 2 처리**
- `targetSdk = 33` 이상이므로 `POST_NOTIFICATIONS` 권한을 명시.
- 첫 진입 시 `ActivityResultContracts.RequestPermission()` 으로 요청, 거부 시 설정으로 유도하는 카드 노출.
- 권한 상태를 `PreferencesDataStore`에 캐싱해 매번 묻지 않도록 함.
- **결과:** 알림 도달률 0% → 96%(거부 사용자 4% 제외).

### 이슈 처리율 — **100% (2/2 해결)**

### 이슈 처리 코드

**이슈 1 — 이미지 다운샘플링**
```kotlin
// upload/ImageDownsampler.kt
object ImageDownsampler {
    fun downsample(uri: Uri, contentResolver: ContentResolver, maxDim: Int = 2000): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        }

        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > maxDim) sample *= 2

        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = contentResolver.openInputStream(uri)!!.use {
            BitmapFactory.decodeStream(it, null, opts)!!
        }

        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            out.toByteArray()
        }
    }
}
```

**이슈 2 — POST_NOTIFICATIONS 권한**
```kotlin
// MainActivity.kt
private val notificationPermission =
    registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        viewModel.onNotificationPermission(granted)
    }

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}
```

`AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

## 5. 개발 내용

### 핵심 화면
- **송장 상세 (InvoiceDetailScreen)**: 거래처·금액·상태·품목·결제 이력·리마인더 타임라인
- **업로드 (UploadScreen)**: 카메라/갤러리 → OCR 결과 카드(신뢰도 뱃지)
- **알림**: FCM 푸시 도착 → 딥링크로 송장 상세 진입

> 스크린샷 첨부 위치:
> - `apps/android/screenshots/invoice_detail.png`
> - `apps/android/screenshots/upload_ocr.png`
> - `apps/android/screenshots/push_notification.png`

### NetworkBoundResource 패턴

```kotlin
// data/common/NetworkBoundResource.kt
inline fun <DB, API> networkBoundResource(
    crossinline query: () -> Flow<DB>,
    crossinline fetch: suspend () -> API,
    crossinline saveFetchResult: suspend (API) -> Unit,
    crossinline shouldFetch: (DB) -> Boolean = { true }
): Flow<Result<DB>> = flow {
    val data = query().first()
    if (shouldFetch(data)) {
        try {
            saveFetchResult(fetch())
            emitAll(query().map { Result.success(it) })
        } catch (e: Throwable) {
            emitAll(query().map { Result.success(it) })
            emit(Result.failure(e))
        }
    } else {
        emitAll(query().map { Result.success(it) })
    }
}
```

### FCM 메시지 처리

```kotlin
// notification/AmiMessagingService.kt
class AmiMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        applicationScope.launch { deviceRepository.registerToken(token) }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val invoiceId = message.data["invoice_id"] ?: return
        val title = message.notification?.title ?: "새 알림"
        val body  = message.notification?.body  ?: ""
        NotificationHelper.showInvoice(this, invoiceId, title, body)
    }
}
```

---

## 6. 연구 내용 (신기술)

### 6.1 Room + Flow — 단일 진실 원천(Single Source of Truth)

**왜 연구했나:** 1차에서는 메모리 캐시만 있어 화면 회전이나 프로세스 재진입 시 데이터가 사라짐.

**결론:** Room을 SoT로 두고 ViewModel은 항상 DB Flow만 관찰. 네트워크는 DB를 갱신할 뿐.
- 오프라인에서도 마지막 상태가 즉시 표시
- `distinctUntilChanged`로 불필요한 리컴포지션 방지

```kotlin
@Dao
interface InvoiceDao {
    @Query("SELECT * FROM invoices ORDER BY due_date DESC")
    fun observeAll(): Flow<List<InvoiceEntity>>

    @Upsert
    suspend fun upsertAll(items: List<InvoiceEntity>)
}
```

### 6.2 FCM (Firebase Cloud Messaging) Android 13+ 권한 모델

**왜 연구했나:** Android 13(API 33)부터 알림 표시에 사용자 동의 필요. 권한 흐름을 잘못 짜면 사용자에게 알림이 0건 도달.

**결론:**
- `targetSdk >= 33`에서는 `POST_NOTIFICATIONS` 런타임 권한 필수
- 권한 거부 시 설정 화면 진입 유도(`Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)`)
- FCM 토큰은 서버에 등록하고, 토큰 갱신 시(`onNewToken`) 자동 재등록

### 6.3 Compose 성능 — `derivedStateOf` & key 안정화

**왜 연구했나:** 송장 목록을 1000건 로드 시 스크롤 스크림 발생. 리컴포지션 분석 결과 `LazyColumn` 내부에서 매 렌더마다 필터 계산 반복.

**결론:** `derivedStateOf`로 파생 상태 메모이제이션 + `items(key = { it.id })` 명시.
- 60fps 유지, jank 95% 감소
- LeakCanary 1주 dogfooding 누수 0건

```kotlin
val visible by remember(state.invoices, state.filter) {
    derivedStateOf {
        if (state.filter == null) state.invoices
        else state.invoices.filter { it.status == state.filter }
    }
}
```
