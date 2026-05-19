# v1 Roadmap — 운영 가능한 첫 릴리즈

| 항목 | 내용 |
|---|---|
| **목표** | 실제 사용자 트래픽을 받을 수 있는 웹 단독 운영 환경 |
| **범위** | Phoenix 웹 앱 + 백엔드. 모바일·Pro 플랜은 v1.x로 분리. |
| **모드** | Sprint 종료. 백로그 단일 큐, 1건씩 진행. |
| **작성** | 2026-05-19, AMI-91 머지 직후 |

---

## v1에 들어가는 것 / 들어가지 않는 것

### ✅ 포함
- 송장 생성·발송·수금·연체·리마인더 풀 플로우 (Sprint 1·2)
- 분석 대시보드 (수금추이·캐시플로우·클라이언트 인사이트, Sprint 2)
- AI OCR (단건+다중 배치, Sprint 3 AMI-84/85)
- 이메일 브랜딩 (Sprint 3 AMI-86)
- 비밀번호 재설정 (Sprint 3 AMI-87)
- 다중 통화 + KRW 환산 합산 (Sprint 4 AMI-90)
- QR 즉시 결제 (Sprint 4 AMI-89)
- 전자세금계산서 stub (Sprint 4 AMI-91, 운영 진입 시 LiveClient swap)
- **운영 인프라·보안 — 본 문서의 1단계 큐**

### ❌ 제외 (v1.x 이후)
- 모바일 앱 출시 (Sprint 4 substrate 완료, 정식 배포는 별도)
- Pro 플랜 (팀·API키·고급 브랜딩)
- 다국어 (한국어 단일)
- 커스텀 리마인더 템플릿 (기본 톤 3종으로 출시)
- Hometax 실 연동 (sandbox 자격 도착 후)

---

## 1단계 큐 (v1 차단 — 운영 시작 전 필수)

순서는 의존성 + 보안 위험도 + ROI 기준. 위에서부터 1건씩.

| # | Key | 제목 | 메모 |
|---|---|---|---|
| 1 | AMI-13 | 환경변수 기반 시크릿 관리 | 다른 모든 인프라의 기반. `.env.example` → runtime.exs 전수 점검 |
| 2 | AMI-14 | Paddle Webhook 서명 검증 | 결제 무결성 차단 위험 — 최우선 보안 |
| 3 | AMI-17 | HTTPS 강제 리디렉트 | force_ssl + HSTS, 운영 도메인 진입 직전 |
| 4 | AMI-20 | CORS 설정 | API 사용자 모바일/외부 통합 대비 |
| 5 | AMI-15 | API Rate Limiting | Hammer/PlugAttack — 무료 티어 남용 차단 |
| 6 | AMI-16 | 이메일 발송 프로덕션 설정 | SES/SendGrid + SPF/DKIM/DMARC |
| 7 | AMI-19 | Sentry 에러 모니터링 | 운영 진입 즉시 가시화 |
| 8 | AMI-18 | DB 마이그레이션 자동화 | release task로 boot 시 자동 migrate |
| 9 | AMI-59 | 프로덕션 인프라 구축 | Fly.io 1순위 후보 (Phoenix 친화) |

---

## 2단계 큐 (v1 권장 — 출시 직전 확인)

| # | Key | 제목 | 메모 |
|---|---|---|---|
| 10 | AMI-21 | CI/CD 파이프라인 | GitHub Actions: lint + test + format + dialyzer 게이트 |
| 11 | AMI-61 | CI/CD & 배포 자동화 | 10번 + 자동 deploy (Fly.io launch hook) |
| 12 | AMI-54 | 입력 검증 강화 | API 컨트롤러 changeset 전수 점검 |
| 13 | AMI-55 | 테스트 커버리지 80% | mix test --cover + ExCoveralls |
| 14 | AMI-60 | API 보안 강화 | 13/14/15/20 통합 검증 |

---

## 3단계 큐 (이미 코드 머지 — Jira만 일괄 close)

코드는 이전 스프린트에 들어왔으나 Jira transition만 남은 이슈. 별도 정리 작업 1번으로 묶어 처리:

AMI-22, AMI-23, AMI-24, AMI-25, AMI-26, AMI-27, AMI-28, AMI-29, AMI-30, AMI-31, AMI-32, AMI-33, AMI-34, AMI-35, AMI-36, AMI-37, AMI-38, AMI-40, AMI-42, AMI-50, AMI-51, AMI-63, AMI-64, AMI-65, AMI-66, AMI-67, AMI-68, AMI-69, AMI-70, AMI-74, AMI-75

총 **31건**. Sprint 1~4 작업물의 후속 Jira 정리에 해당. v1 차단 큐와 별개로 시간 날 때 일괄 처리.

---

## 4단계 큐 (v1.x 이후 — 백로그)

| Key | 제목 | v1.x 분리 사유 |
|---|---|---|
| AMI-39 | 커스텀 리마인더 템플릿 | Pro 의존 |
| AMI-41 | 푸시 알림 인프라 (APNs) | iOS 출시와 결합 |
| AMI-43/44/71/72 | 모바일 앱 MVP | 별도 출시 사이클 |
| AMI-45/46/47/48/73 | Pro 플랜 | 결제·과금 별도 |
| AMI-49 | 다국어 (i18n) | 한국어 단일 출시 후 |
| AMI-52/53/56/57/58/62 | 코드 품질 부채 | 출시 후 정기 정리 |

---

## 진행 원칙

1. **1건씩 atomic** — 한 이슈를 끝까지 (코드 + 테스트 + 머지 + Jira Done) 끝낸 다음 다음 이슈
2. **모든 변경은 main fast-forward** (브랜치 → 머지 → 푸시 → Jira Done → 브랜치 삭제)
3. **회귀 0건** — 매 머지 전 `mix test` 통과 확인
4. **외부 비밀은 항상 환경변수** — AMI-13이 1번인 이유
5. **운영 진입 직전 마지막 게이트**: AMI-21/55/60 통과 + `/qa` 1회 패스 + ROADMAP_V1 큐 1·2단계 0건

## 큐 갱신 규칙

- 새 발견 사항(예: /qa 회귀 4건 같은 것)은 우선순위 평가 후 1·2·4단계 어디로 갈지 결정
- 우선순위 변경 시 본 문서를 먼저 갱신, 그 다음 작업 시작
- 단계가 모두 비면 모드 재정렬 (v1 출시 → v1.x 시작)
