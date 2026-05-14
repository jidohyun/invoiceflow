# 스프린트 (1차) 프로젝트 중간 보고서

| 항목 | 내용 |
|---|---|
| **프로젝트명** | AutoMyInvoice — AI 기반 자동 송장 리마인더 SaaS |
| **학번** | _(학번 기재)_ |
| **성명** | **하동건** |
| **역할** | iOS 앱 개발 |

---

## 1. 제품 백로그 (Product Backlog)

| 스프린트 | 제품 백로그 (iOS 파트) |
|---|---|
| **1차** | 1. iOS 프로젝트 세팅 (SwiftUI + Factory + MVI) · 2. 네트워크 레이어 (URLSession + async/await) · 3. 송장 목록 화면 · 4. 송장 상세 뷰 · 5. 카메라 연동(AVFoundation) 영수증 업로드 |
| **2차** | 1. 송장 작성·수정 폼 · 2. OCR 결과 프리뷰 화면 · 3. Keychain 토큰 저장 · 4. 오프라인 캐싱 (SwiftData) |
| **3차** | 1. Magic Link 로그인 · 2. 이메일 커스터마이징 UI · 3. 다국어(ko/en) |
| **4차** | 1. TestFlight 배포 · 2. QR 결제 UI · 3. 푸시 알림(APNs) |

---

## 2. 스프린트 백로그 (Sprint Backlog) — 1차

**기간: 2025. 4. 1. ~ 2025. 4. 14.**

### 계획
iOS 앱 MVP의 기반(프로젝트 구조, DI, 네트워크)을 완성하고 송장 목록·상세·카메라 업로드 3개 화면을 엔드투엔드로 증명한다.

### 칸반 현황

| 할 일 (To-Do) | 진행 중 (In Progress) | 완료 (Done) |
|---|---|---|
| (없음) | — | ✅ iOS 프로젝트 세팅 (SwiftUI + Factory) |
| | | ✅ MVI 아키텍처 레이어 설계 |
| | | ✅ URLSession async/await 네트워크 |
| | | ✅ 송장 목록 화면 |
| | | ✅ 송장 상세 뷰 |
| | | ✅ AVFoundation 카메라 연동 |
| | | ✅ 영수증 촬영 → 서버 업로드 엔드투엔드 |

**완료율: 7/7 = 100%**

### 일간 계획

| 날짜 | 오늘 진행할 작업 |
|---|---|
| 4/1 (화) | 킥오프, Xcode 환경 세팅 |
| 4/2 (수) | iOS 프로젝트 생성 + Factory DI |
| 4/3 (목) | MVI 설계 문서 작성, 폴더 구조 확정 |
| 4/4 (금) | 송장 목록 프로토타입 |
| 4/7 (월) | URLSession 기반 NetworkClient 구현 |
| 4/8 (화) | 송장 상세 뷰 구현 |
| 4/9 (수) | 업로드 화면 + 사진 선택 |
| 4/10 (목) | AVFoundation 카메라 뷰 구현 |
| 4/11 (금) | 카메라 촬영 → 서버 업로드 엔드투엔드 |
| 4/14 (월) | TestFlight 알파 빌드 + 테스트 |

---

## 3. 데일리 스크럼

> ※ 노션 회의록 일자별 캡처 첨부 자리

### 1주차

**4/1 (화)**
- 참가자: 지도현, 이지훈, 하동건, 신용철
- 한 일: 킥오프, Xcode 15.4 설치
- 할 일: iOS 프로젝트 생성
- 이슈: 없음

**4/2 (수)**
- 한 일: SwiftUI + Factory DI 스캐폴딩
- 할 일: 아키텍처 선택 (MVVM vs MVI)
- 이슈: ⚠️ Xcode 버전 팀 간 불일치 → 15.4로 통일하기로 합의

**4/3 (목)**
- 한 일: MVI 채택, 폴더 구조(Core/Feature/Infra) 확정
- 할 일: 송장 목록 프로토타입
- 이슈: 없음

**4/4 (금)**
- 한 일: 송장 목록 화면 스켈레톤 + 더미 데이터 프리뷰
- 할 일: 네트워크 레이어 설계
- 이슈: 없음

**4/7 (월)**
- 한 일: URLSession 기반 NetworkClient (async/await)
- 할 일: 송장 상세 뷰
- 이슈: 없음

### 2주차

**4/8 (화)**
- 한 일: 송장 상세 뷰 구현 (금액·기한·상태·품목)
- 할 일: 업로드 화면
- 이슈: 없음

**4/9 (수)**
- 한 일: 포토 라이브러리 선택 UI
- 할 일: 카메라 뷰
- 이슈: 🔴 `PHPickerViewController` 퍼미션 다이얼로그가 SwiftUI에서 의도대로 뜨지 않음 → `UIViewControllerRepresentable`로 래핑 후 해결

**4/10 (목)**
- 한 일: AVFoundation 기반 카메라 뷰 구현
- 할 일: 촬영 → 서버 업로드 엔드투엔드
- 이슈: 없음

**4/11 (금)**
- 한 일: 영수증 촬영 → multipart/form-data 업로드 → OCR 엔드투엔드 성공
- 할 일: TestFlight 빌드 준비
- 이슈: 🔴 실기기에서 카메라 권한 미설정 → `Info.plist` NSCameraUsageDescription 추가 후 해결

**4/14 (월)**
- 한 일: Xcode Archive → TestFlight 알파 업로드
- 할 일: Sprint 2 계획
- 이슈: 없음

---

## 4. 이슈 (Issue)

### 발생 이슈 2가지

**1. PHPicker가 SwiftUI에서 바로 동작하지 않음**
- 현상: `.sheet` 내부에 `PHPickerViewController`를 직접 올렸더니 권한 프롬프트가 뜨지 않고 빈 화면만 노출.
- 영향: 포토 라이브러리 업로드 기능 막힘.

**2. 실기기에서 카메라 권한 미설정으로 크래시**
- 현상: 시뮬레이터에선 동작하던 카메라 뷰가 실기기 진입 시 즉시 크래시 (`NSCameraUsageDescription` 미존재 예외).
- 영향: 전체 촬영 플로우 불가.

### 2가지 이슈의 처리 방법 및 결과

**이슈 1 처리**
- `UIViewControllerRepresentable`로 `PHPickerViewController`를 래핑한 `PhotoPicker` SwiftUI 뷰 구현.
- `Coordinator` 패턴으로 `PHPickerViewControllerDelegate`의 결과를 `@Binding` 으로 전달.
- **결과:** SwiftUI `.sheet` 내부에서 정상 동작, 권한 프롬프트도 정상 노출.

**이슈 2 처리**
- `Info.plist`에 `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` 두 키 추가.
- 카메라 뷰 진입 전 `AVCaptureDevice.requestAccess(for: .video)`로 명시적 권한 요청.
- **결과:** 실기기 TestFlight 빌드에서 카메라 촬영 정상 동작.

### 이슈 처리율 — **100% (2/2 해결)**

### 이슈 처리 코드

**이슈 1 — PHPicker SwiftUI 래퍼**
```swift
// Presentation/Common/PhotoPicker.swift
import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                return
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    self?.parent.selectedImage = image as? UIImage
                    self?.parent.dismiss()
                }
            }
        }
    }
}
```

**이슈 2 — 카메라 권한 요청**
```swift
// Presentation/Upload/CameraAccessHelper.swift
enum CameraAccessHelper {
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
```

`Info.plist`에 추가:
```xml
<key>NSCameraUsageDescription</key>
<string>영수증 촬영으로 송장을 자동 생성하기 위해 카메라 권한이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>저장된 영수증 이미지를 선택해 업로드하려면 접근 권한이 필요합니다.</string>
```

---

## 5. 개발 내용

### 핵심 화면
- **송장 목록 (InvoiceListView)**: `List` + 상태 뱃지 + 당겨서 새로고침
- **송장 상세 (InvoiceDetailView)**: 거래처·금액·기한·품목·리마인더 타임라인
- **업로드 (UploadView)**: 카메라 촬영 / 포토 라이브러리 선택 → 서버 OCR

> 스크린샷 첨부 위치:
> - `apps/ios/screenshots/invoice_list.png`
> - `apps/ios/screenshots/invoice_detail.png`
> - `apps/ios/screenshots/camera_upload.png`

### 네트워크 레이어 (async/await)

```swift
// Infra/Network/APIClient.swift
final class APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let tokenProvider: () -> String?

    init(baseURL: URL, session: URLSession = .shared, tokenProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as: T.Type) async throws -> T {
        var req = URLRequest(url: baseURL.appending(path: endpoint.path))
        req.httpMethod = endpoint.method

        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            req.httpBody = try JSONEncoder.api.encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(response: response)
        }
        return try JSONDecoder.api.decode(T.self, from: data)
    }
}
```

### MVI — 송장 목록

```swift
// Presentation/InvoiceList/InvoiceListViewModel.swift
@MainActor
final class InvoiceListViewModel: ObservableObject {
    @Published private(set) var state = State()

    struct State {
        var invoices: [Invoice] = []
        var isLoading = false
        var error: String?
    }

    enum Intent {
        case load
        case refresh
        case filter(String?)
    }

    private let repository: InvoiceRepository

    init(repository: InvoiceRepository = Container.shared.invoiceRepository()) {
        self.repository = repository
    }

    func send(_ intent: Intent) {
        Task { await reduce(intent) }
    }

    private func reduce(_ intent: Intent) async {
        switch intent {
        case .load, .refresh:
            state.isLoading = true
            do {
                state.invoices = try await repository.list()
                state.error = nil
            } catch {
                state.error = error.localizedDescription
            }
            state.isLoading = false

        case .filter(let status):
            // ...
        }
    }
}
```

---

## 6. 연구 내용 (신기술)

### 6.1 Factory — 가벼운 SwiftUI DI 컨테이너

**왜 연구했나:** Swinject는 타입 안전성이 약하고, 수동 init 주입은 Compose와 달리 의존성이 복잡해지면 관리 부담이 큼.

**결론:** `Factory` 패키지가 프로토콜 기반 + 테스트에서 쉽게 교체 가능 + 컴파일 타임 안전.

```swift
// Infra/DI/Container+App.swift
import Factory

extension Container {
    var apiClient: Factory<APIClient> {
        self { APIClient(baseURL: AppConfig.apiBaseURL, tokenProvider: TokenStore.read) }
            .singleton
    }

    var invoiceRepository: Factory<InvoiceRepository> {
        self { DefaultInvoiceRepository(client: self.apiClient()) }
    }
}
```

뷰에서 사용:
```swift
init(repository: InvoiceRepository = Container.shared.invoiceRepository()) {
    self.repository = repository
}
```

### 6.2 Swift Concurrency — async/await + Task

**왜 연구했나:** Combine 대비 코드량 감소, 에러 처리 명확, 콜백 지옥 해소.

**적용:**
```swift
func loadInvoices() async {
    do {
        let invoices = try await repository.list()
        state.invoices = invoices
    } catch {
        state.error = error.localizedDescription
    }
}
```

`URLSession.data(for:)` / `AVCaptureDevice.requestAccess` 등 iOS 15+ 표준 API가 모두 async를 제공해 자연스러움.

### 6.3 AVFoundation 카메라 캡처 파이프라인

**왜 연구했나:** 기본 `UIImagePickerController`는 UI 커스터마이징이 어려움. 영수증 자동 프레이밍 UX를 위해 AVFoundation 레벨에서 프리뷰 + 셔터 버튼 직접 구현.

**적용:**
```swift
final class CameraViewModel: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            throw CameraError.unavailable
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
        session.addOutput(photoOutput)
    }

    func capture(onImage: @escaping (UIImage) -> Void) {
        self.onImage = onImage
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        onImage?(image)
    }
}
```
