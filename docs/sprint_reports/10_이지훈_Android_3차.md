# 스프린트 (3차) 프로젝트 중간 보고서

| 항목 | 내용 |
|---|---|
| **프로젝트명** | AutoMyInvoice — AI 기반 자동 송장 리마인더 SaaS |
| **학번** | _(학번 기재)_ |
| **성명** | **이지훈** |
| **역할** | Android 앱 개발 |

---

## 1. 제품 백로그 (Product Backlog)

해당 스프린트 동안 진행할 제품 백로그를 우선순위 높은 순으로 왼쪽부터 기재.
이전 스프린트에서 완성하지 못한 기능은 다음 스프린트에 추가.

| 스프린트 | 제품 백로그 (Android 파트) |
|---|---|
| **1차** | 1. Android 프로젝트 초기 세팅 (Compose + Hilt + MVI) · 2. 디자인 토큰 웹과 동기화 · 3. 네트워크 레이어 (Retrofit + OkHttp) · 4. OpenAPI 3.1 스펙 기반 DTO 자동 생성 · 5. 송장 목록 화면 · 6. 영수증 카메라 스캔 버튼 |
| **2차** | 1. 송장 상세 화면 · 2. 업로드 & OCR 플로우 · 3. 오프라인 캐싱 (Room) · 4. 푸시 알림(FCM) 기본 수신 |
| **3차** | 1. 영수증 배치 촬영 UI (최대 10장) · 2. 브랜딩 설정 화면 (회사명·브랜드 컬러) · 3. 다국어 지원 (ko/en) · 4. 비밀번호 재설정 딥링크 수용 |
| **4차** | 1. 모바일 MVP TestFlight/Play Console 배포 · 2. QR 현장 결제 UI · 3. 푸시 알림 인터랙션 |

---

## 2. 스프린트 백로그 (Sprint Backlog) — 3차

**기간: 2026. 5. 12. ~ 2026. 5. 18.**

### 계획
2차에 완성한 송장 상세·OCR 업로드·Room 캐싱 위에 **다중 촬영**과 **개인화** 레이어를 얹는다.
웹팀이 AMI-85로 백엔드 다중 처리 (`max_entries: 10`, 파일당 ExtractionJob 1건)를 열어 주었으니
Android에서도 카메라 다중 캡처 → 큐잉 → 진행률 → 부분 완료 표시 UX를 똑같이 맞춘다.
AMI-86 백엔드가 추가한 `users.brand_color` / `company_name`을 설정 화면에서 편집 가능하게 만들고,
AMI-87 비밀번호 재설정 이메일 링크가 앱 딥링크로 떨어졌을 때 인앱 화면으로 받아 처리한다.
**ko/en 다국어**는 stringsResource 분리부터 시작.

### 칸반 현황

| 할 일 (To-Do) | 진행 중 (In Progress) | 완료 (Done) |
|---|---|---|
| (없음) | — | ✅ 영수증 배치 캡처 UI (최대 10장) |
| | | ✅ 업로드 큐 + 파일별 진행률 카드 |
| | | ✅ BrandingSettingsScreen (회사명·브랜드 컬러 픽커) |
| | | ✅ Strings 자원 분리 (values/, values-en/) |
| | | ✅ App Links 등록 — `/users/reset_password/{token}` |
| | | ✅ ResetPasswordScreen + Form Validation |
| | | ✅ 회귀: OkHttp 인증 인터셉터 토큰 만료 fallback |

**완료율: 7/7 = 100%**

### 일간 계획

| 날짜 | 오늘 진행할 작업 |
|---|---|
| 5/12 (월) | Sprint 3 킥오프, 카메라 다중 캡처 PoC |
| 5/13 (화) | CameraX `ImageCapture.takePictureMultiple` 큐 도입 |
| 5/14 (수) | 업로드 큐 자료구조 (LinkedHashMap, 파일별 상태) |
| 5/15 (목) | 진행률 카드 컴포넌트 + Recomposition 최적화 |
| 5/16 (금) | BrandingSettings 화면 + 색상 픽커 (ColorPicker compose) |
| 5/17 (토) | i18n strings 추출 + values-en/ 번역 1차 |
| 5/18 (일) | App Links Manifest 설정 + ResetPassword 화면 |

---

## 3. 진행 결과 요약

### 3.1 정량
- **신규 화면:** 3개 (BatchCaptureScreen, BrandingSettingsScreen, ResetPasswordScreen)
- **신규 컴포넌트:** UploadQueueCard, ColorSwatchPicker, LocaleAwareCurrencyText
- **JUnit + Compose Test:** 47 → **62** (+15)
- **다국어:** 총 134개 문자열 영어 1차 번역 완료 (감수 잔여)
- **APK 사이즈:** 9.4 MB → 9.7 MB (+0.3 MB, CameraX-extensions + ColorPicker 라이브러리)

### 3.2 정성
- "한 번에 한 장씩"의 모바일 OCR 사용 흐름이 끊기던 부분이 사라짐 → 영업 종료 후 그날 모은 영수증 다발을 1분 안에 송장 초안으로 전환 가능
- 브랜드 컬러가 모바일에서도 즉시 반영되어 미리보기로 확인 가능 → 데스크톱·모바일 결과물 동일성 확보
- 영어 UI 1차 번역으로 향후 글로벌 출시 시 LO(현지화) 작업 베이스 마련
- App Links로 이메일 링크 진입 시 브라우저 우회 없이 앱이 직접 받음 → 4차 매직 UX 인입 통로 확보

---

## 4. 주요 산출물

### 4.1 영수증 배치 캡처 UI

| 항목 | 내용 |
|---|---|
| 패키지 | `com.automyinvoice.android.feature.capture` |
| 화면 | `BatchCaptureScreen`, `BatchCaptureViewModel` (MVI) |
| 의존성 추가 | `androidx.camera:camera-extensions:1.4.0`, `coil-compose:2.7.0` |
| Max | 10장 (서버 백엔드 한도와 동일) |

핵심 상태 모델:
```kotlin
data class BatchCaptureState(
    val pending: List<CapturedPhoto> = emptyList(),
    val uploading: Map<String, UploadProgress> = emptyMap(),
    val completed: List<CompletedExtraction> = emptyList(),
    val failed: List<FailedExtraction> = emptyList(),
    val totalSlots: Int = 10,
) {
    val remainingSlots: Int = (totalSlots - pending.size - uploading.size).coerceAtLeast(0)
    val isFull: Boolean = remainingSlots == 0
}
```

사용자 인터랙션:
1. 셔터 탭 → `CapturedPhoto`가 `pending` 큐에 적재
2. "업로드 & 추출" 버튼 → 큐의 모든 항목이 동시 업로드 시작
3. 카드별 진행 바 (0~100), 추출 완료 시 신뢰도 뱃지 + "송장 만들기" CTA
4. 슬롯이 다 차면 셔터 비활성 + "최대 10장" 안내

### 4.2 BrandingSettingsScreen

| 항목 | 내용 |
|---|---|
| 화면 | `BrandingSettingsScreen` (Settings 탭 내 신규) |
| 편집 필드 | `companyName`, `brandColor` (#RRGGBB) |
| 미리보기 | 이메일 헤더 + "결제" 버튼 컬러를 실시간 렌더 |

`PATCH /api/v1/settings/branding`(웹팀 AMI-86 API 재사용)을 호출하고 응답 즉시 로컬 `BrandingPreferences` DataStore에도 저장 → 다음 부팅부터 오프라인에서도 동일 컬러로 송장 미리보기 렌더.

### 4.3 ResetPasswordScreen + App Links

App Links Manifest:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="auto-my-invoice.com"
        android:pathPrefix="/users/reset_password/" />
</intent-filter>
```

이메일에서 링크 탭 시 브라우저 대신 앱이 받아 `ResetPasswordScreen(token)`을 열고, 사용자가 새 비밀번호 입력 → `POST /api/v1/auth/reset_password` 호출 → 로그인 화면으로 push. 백엔드가 같은 트랜잭션에서 옛 토큰을 전부 무효화하므로 이전 세션도 즉시 끊긴다.

### 4.4 다국어 (ko/en)

- `values/strings.xml` 134개 키를 표준화 (`@string/upload_zone_hint` 등)
- `values-en/strings.xml`에 1차 번역
- 통화/날짜는 `LocaleAwareCurrencyText` 컴포저블이 `java.text.NumberFormat.getCurrencyInstance(locale)` 사용
- 한국 사용자(`ko-KR`)는 천단위 `,` + `₩`, 영어 사용자는 ISO 코드 + 부호로 표시

---

## 5. 핵심 코드 발췌

### 5.1 다중 업로드 큐 — MVI Intent → State 전환

```kotlin
sealed interface BatchCaptureIntent {
    data class AddPhoto(val photo: CapturedPhoto) : BatchCaptureIntent
    data object SubmitAll : BatchCaptureIntent
    data class CancelPending(val id: String) : BatchCaptureIntent
    data class DismissResult(val id: String) : BatchCaptureIntent
}

class BatchCaptureViewModel @Inject constructor(
    private val uploadRepo: ExtractionRepository,
) : ViewModel() {
    private val _state = MutableStateFlow(BatchCaptureState())
    val state: StateFlow<BatchCaptureState> = _state.asStateFlow()

    fun reduce(intent: BatchCaptureIntent) {
        when (intent) {
            is BatchCaptureIntent.AddPhoto ->
                _state.update { s ->
                    if (s.isFull) s else s.copy(pending = s.pending + intent.photo)
                }

            BatchCaptureIntent.SubmitAll -> submitAll()

            is BatchCaptureIntent.CancelPending ->
                _state.update { s -> s.copy(pending = s.pending.filterNot { it.id == intent.id }) }

            is BatchCaptureIntent.DismissResult ->
                _state.update { s -> s.copy(completed = s.completed.filterNot { it.id == intent.id }) }
        }
    }

    private fun submitAll() = viewModelScope.launch {
        val toUpload = _state.value.pending
        _state.update { it.copy(pending = emptyList(),
                                uploading = toUpload.associateBy({ it.id }) { UploadProgress.Queued }) }

        toUpload.forEach { photo ->
            uploadRepo.uploadAndExtract(photo)
                .onEach { progress -> _state.update { mergeProgress(it, photo.id, progress) } }
                .launchIn(this)
        }
    }
}
```

### 5.2 카메라 다중 캡처 — CameraX

```kotlin
@Composable
fun CameraCaptureSurface(onCaptured: (CapturedPhoto) -> Unit) {
    val context = LocalContext.current
    val controller = remember { LifecycleCameraController(context) }
    AndroidView(factory = { PreviewView(it).apply { this.controller = controller } })

    Button(onClick = {
        val file = File(context.cacheDir, "rcpt-${UUID.randomUUID()}.jpg")
        controller.takePicture(
            ImageCapture.OutputFileOptions.Builder(file).build(),
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(out: ImageCapture.OutputFileResults) {
                    onCaptured(CapturedPhoto(id = UUID.randomUUID().toString(),
                                             localUri = Uri.fromFile(file)))
                }
                override fun onError(e: ImageCaptureException) { Log.e("Capture", "fail", e) }
            }
        )
    }) { Text(stringResource(R.string.batch_capture_shutter)) }
}
```

### 5.3 통화 i18n — Locale-aware Composable

```kotlin
@Composable
fun LocaleAwareCurrencyText(amount: BigDecimal, currencyCode: String) {
    val locale = LocalConfiguration.current.locales[0]
    val formatter = remember(locale, currencyCode) {
        NumberFormat.getCurrencyInstance(locale).apply {
            currency = Currency.getInstance(currencyCode)
        }
    }
    Text(formatter.format(amount))
}
```

### 테스트
- JUnit/Robolectric: BatchCaptureViewModel reduce/submit 14건 추가
- Compose Test: ColorSwatchPicker 색상 변경 → 미리보기 색 변경 1건
- 회귀: OkHttp 인터셉터 401 응답 시 RefreshToken 1회만 발사 (Race condition 회귀)

---

## 6. 연구 내용 (신기술)

### 6.1 CameraX `LifecycleCameraController` — 빠른 연속 캡처

**왜 연구했나:** 영업 종료 직후 영수증 다발을 1초 안에 연속 촬영하려면 셔터 응답이 부드러워야 한다. `ImageCapture` 단독 사용은 콜백 한 번에 한 장만 안정적.

**결론:** `LifecycleCameraController` + `setEnabledUseCases(IMAGE_CAPTURE)`로 카메라 권한·라이프사이클을 한 객체에 위임. 캡처 콜백 안에서 즉시 `pending` 큐에 적재해 다음 셔터를 받을 수 있게 비동기 처리. 평균 셔터 인터벌 0.6초.

### 6.2 DataStore (Preferences) — 브랜드 설정 영구화

**왜 연구했나:** 브랜드 컬러는 송장 미리보기·앱 액센트 컬러로 두루 쓰여 첫 화면에서부터 필요. SharedPreferences는 동기 I/O라 콜드스타트를 늦춤.

**결론:** Jetpack `androidx.datastore:datastore-preferences`로 비동기 Flow 기반 영구화. Hilt 모듈에서 단일 인스턴스 제공.

```kotlin
val Context.brandingDataStore by preferencesDataStore("branding")

object BrandingKeys {
    val COMPANY_NAME = stringPreferencesKey("company_name")
    val BRAND_COLOR  = stringPreferencesKey("brand_color")
}
```

### 6.3 Android App Links — autoVerify

**왜 연구했나:** 사용자가 이메일에서 비밀번호 재설정 링크를 탭할 때 브라우저로 열리면 모바일 사용 흐름이 끊긴다. 가능한 한 앱이 받아야 한다.

**결론:** `android:autoVerify="true"` 설정 + 서버에 `/.well-known/assetlinks.json` 배포 → Android Verifier가 매니페스트와 서버를 cross-check 후 자동으로 앱이 등록된다. iOS의 Universal Links와 동등.

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.automyinvoice.android",
    "sha256_cert_fingerprints": ["AA:BB:..."]
  }
}]
```

---

## 7. 회고

### 잘된 점
- 백엔드 AMI-85 변경(파일당 ExtractionJob 1건) 설계를 그대로 따라 모바일 큐 모델을 단순화 — 백엔드/모바일 멘탈모델 일치
- DataStore 도입으로 콜드스타트 50ms 단축 (앱 콜드 시작 시간 1.30s → 1.25s 측정)
- ColorPicker 컴포저블을 OSS(`mhssn83/compose-color-picker`)로 가져와 0일 만에 브랜드 컬러 UX 완성

### 아쉬운 점
- 다국어 1차 번역은 기계 번역 베이스라 톤이 어색. QA에서 표현 다듬기 패스 1회 필요
- App Links 검증이 서버에 `assetlinks.json` 배포된 뒤에야 작동 → 4차 배포 단계에 의존

### 다음 스프린트 (4차) 진입 조건
- [x] 3차 백로그 7건 완료
- [x] 신규 화면 3개 컴포즈 프리뷰 / 다이내믹 미리보기 통과
- [x] APK 사이즈 회귀 없음 (목표 10MB 이하 유지)
- [ ] 영어 번역 감수 (4차 진입 직전 수행)
- [ ] Play Console internal testing 트랙 업로드 (4차 1주차 목표)

---

## 부록 A. 본 스프린트 PR 목록 (Android repo)

```
#127 feat(capture): batch capture screen with 10-slot upload queue
#128 feat(settings): branding settings (company_name + brand_color)
#129 feat(i18n): extract strings.xml + add values-en
#130 feat(auth): reset password screen + app links
#131 fix(network): only one refresh-token call during 401 storms
```

## 부록 B. 참고 문서
- `packages/api-spec/openapi.yaml` — `POST /api/v1/auth/reset_password`, `PATCH /api/v1/settings/branding`
- `docs/sprint_reports/09_지도현_PM_웹_서버_3차.md` — 백엔드 3차 보고서 (연동 포인트)
- Material 3 Color Spec — `https://m3.material.io/styles/color/dynamic-color/user-generated-color`
