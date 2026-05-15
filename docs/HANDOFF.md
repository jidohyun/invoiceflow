# AutoMyInvoice 프로젝트 핸드오프 문서

> **목적**: 컨텍스트가 초기화된 에이전트가 이 문서 하나만 읽고 즉시 다음 작업을 시작할 수 있도록 현재까지의 진행 상황과 다음 액션을 정리합니다.
>
> **마지막 갱신**: 2026-05-15 (Sprint 3 중간 — AMI-84/86 완료)

---

## 1. 프로젝트 한 줄 요약

AutoMyInvoice (AMI) — **Elixir/Phoenix LiveView 기반 자동 송장 리마인더 SaaS**. 모노레포에 웹(Phoenix), Android(Kotlin/Compose), iOS(SwiftUI), AI 서버 포함.

- Repo root: `/Users/jidohyun/Desktop/Backup/InvoiceFlow`
- 기본 브랜치: `main`
- Jira 프로젝트 키: `AMI`, Board ID: `34`
- 프로젝트 규칙 전체는 `CLAUDE.md` 참고

---

## 2. Jira 스프린트 상태 (2026-05-15 기준)

| Sprint | ID | 기간 | 상태 | 진행률 |
|---|---|---|---|---|
| Sprint 1 - 출시 기반 & 안정화 | 68 | 2026-04-01 ~ 04-14 | ✅ **closed** | 16/16 (100%) |
| Sprint 2 - 핵심 경험 완성 | 69 | 2026-04-15 ~ 04-28 | ✅ **closed** | 4/4 (100%) |
| Sprint 3 - 분석 & AI | 70 | 2026-04-29 ~ 05-12 | 🟢 **active** | 2/4 (50%) |
| Sprint 4 - 모바일 & Pro 확장 | 103 | 미정 | ⏸️ future | 0/4 |

### Sprint 1 완료 항목 (참고용)
- 버그 4건: AMI-9 Timezone, AMI-10 통화기호, AMI-11 천단위, AMI-12 i18n `%{count}`
- 스토리: AMI-76 송장 자동 생성, AMI-77 결제 수금/부분결제, AMI-78 자동 리마인더, AMI-79 연체 감지
- 하위작업 8건: AMI-92~99

### Sprint 2 완료 항목
- AMI-80 수금 현황 대시보드
- AMI-81 캐시플로우 예측
- AMI-82 클라이언트 결제 패턴 분석
- AMI-83 리마인더 효과 분석

### Sprint 3 — **현재 진행 중** ⬇️

| Key | 제목 | 상태 | PR |
|---|---|---|---|
| **AMI-84** | 영수증 촬영 → AI 자동 송장 생성 | ✅ **완료** (코드 머지 — Jira 전환 잔여) | #8 → main `a7e7c33` |
| **AMI-85** | 다중 영수증 배치 처리 | ⏳ 해야 할 일 |  |
| **AMI-86** | 내 브랜드로 이메일 커스터마이징 | ✅ **백엔드 완료** (Settings UI 별도) | #10 → main `148d716` |
| **AMI-87** | 비밀번호 없이 로그인 & 계정 복구 | ⏳ 해야 할 일 |  |

#### Sprint 3 인프라/부채 PR (스토리 외)
| PR | 머지 커밋 | 내용 |
|---|---|---|
| #7 | `a628b73` | docker-compose dev 환경 (host port 15433, Elixir 1.19.5/OTP 27 image) |
| #9 | `3184c8b` | CI Elixir/OTP 1.15/26 → 1.19.5/27.2, prod Dockerfile 동일 bump, `Date.shift/2` 회귀 해소, ChromicPDF chromium step 추가 |


스프린트 목표: **대시보드 분석 차트, OCR 강화, 이메일 커스터마이징**

### Sprint 4 (대기) — AMI-88~91
모바일 송장 관리, QR 현장 결제, 다중 통화, 한국 전자세금계산서

### 백로그
63건. 인프라/보안(AMI-13~21), 송장강화(AMI-22~28), 설정(AMI-25~27), 분석(AMI-32~35), AI OCR(AMI-36~38), 모바일/Pro(AMI-41~51), 기술부채 작업(AMI-52~58), 에픽 묶음(AMI-59~75).

---

## 3. 작업 디렉토리 현재 상태

### Clean working tree
미커밋 변경 없음. `main` 과 `origin/main` 동기화 완료.

### 최근 커밋 (2026-05-15 기준)
```
148d716 feat(AMI-86): brand-aware emails (company_name + brand_color) (#10)
3184c8b fix(ci): bump Elixir/OTP to 1.19.5/27.2 to unblock Server CI (#9)
a7e7c33 fix: production-ready AMI-84 receipt-to-invoice extraction (#8)
a628b73 chore: add docker compose dev environment (#7)
a0538a0 style: apply mix format across codebase
```

### 테스트 / CI
- `mix test` (Docker, Elixir 1.19.5/OTP 27): **287 tests, 0 failures**
- Server CI (GitHub Actions): 🟢 **green** (Sprint 3 hotfix 이후 회복)

### 환경
- **Docker-only**: 호스트에 native Elixir/Mix/Postgres 없음. `make docker.test`, `make docker.precommit`, `make docker.server` 사용.
- **Postgres**: host port `15433` (15432 는 fishing-pond 사용 중)
- **Compose**: `docker-compose.yml` + `Dockerfile.dev` (Elixir 1.19.5 / OTP 27.2.4)
- **CI**: `.github/workflows/server.yml` (chromium 설치, credo 정보용)

---

## 4. 다음 에이전트가 즉시 해야 할 일

### Step 0: 환경 동기화
```bash
cd ~/auto-my-invoice
git pull --ff-only origin main
make docker.test  # 287/0 통과 확인
```

### Step 1: 진행할 Sprint 3 잔여 작업 선택
권장 순서:
1. **(가장 작음) AMI-86 Settings UI** — 백엔드는 머지 완료. `/settings` LiveView 에 `company_name` 입력 + `brand_color` color picker 추가. `User.profile_changeset/2` 가 이미 `brand_color` 받음. 별도 PR.
2. **AMI-85 다중 영수증 배치** — Oban fan-out 패턴. LiveView 업로드 다중화, ExtractionJob N건 fan-out, 진행 상황 PubSub.
3. **AMI-87 매직링크** — `Accounts` 컨텍스트 확장. 토큰 테이블 + 이메일 송신. 보안 영향 큼.

### Step 2: 미해결 운영 이슈 (작업 전에 확인)
- **Jira AMI-84 / AMI-86 → "완료" 전환 잔여**: 이번 세션에서 Atlassian MCP 가 3연속 실패 후 unreachable. 새 세션에서 회복 시 한 번에 두 건 transition. PR 본문에 `Closes AMI-XX` 포함되어 있어 GitHub-Jira 연동이 살아있으면 자동 전환됐을 가능성도 있음 — 먼저 Jira 대시보드 확인.
- **`mix credo --strict` 차단 해제**: 사전 부채(W1/R9/RD2/D3, ~57건) 때문에 CI 에서 `continue-on-error: true` 로 격리. 자세한 cleanup 계획은 [`docs/CREDO_CLEANUP_EPIC.md`](./CREDO_CLEANUP_EPIC.md) 참고.
- **Node20 deprecation**: GitHub Actions 가 2026-06-02 부터 Node24 로 강제. `actions/cache@v4`, `actions/checkout@v4` 새 버전 확인.

### Step 3: 작업 시작 시 공통
```bash
git checkout -b feat/ami-XX-<slug>
# (옵션) .hermes/seeds/AMI-XX.md 에 bounded seed 작성
make docker.test  # baseline 확보
# TDD: RED → GREEN → REFACTOR
make docker.precommit
gh pr create --base main --head feat/ami-XX-<slug>
```

PR 본문에 `Closes AMI-XX` 포함 (Jira 자동 전환). 커밋 메시지는 Lore format + `Co-Authored-By: Claude Opus 4.7`.

---

## 5. 핵심 도메인 및 파일 위치

```
lib/auto_my_invoice/          # 도메인 컨텍스트
  accounts/                  # 인증 (AMI-87 작업 위치)
  invoices/                  # 송장 도메인
  emails/                    # 이메일 발송 (AMI-86 작업 위치)
  extraction.ex              # AI OCR (AMI-84/85 작업 위치)
  pdf/                       # PDF 생성
lib/auto_my_invoice_web/
  controllers/api/           # REST API v1 (6개 컨트롤러)
  plugs/                     # ApiAuth Bearer 인증
  live/                      # LiveView 페이지
  components/                # 공유 UI 컴포넌트
apps/android/                # Kotlin + Compose + Hilt + MVI
apps/ios/                    # Swift + SwiftUI + Factory + MVI
packages/api-spec/openapi.yaml  # API 변경 시 반드시 동시 업데이트
test/                        # ExUnit (287+ 테스트 통과 유지)
docs/sprint_reports/         # 스프린트 보고서 1~2차 (참고 자료)
```

---

## 6. 작업 규칙 (CLAUDE.md 발췌)

### 커밋 전
```bash
make precommit  # compile --warnings-as-errors + format + test
```

### 커밋 메시지
```
<type>: <description>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
타입: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`. 제목 50자 이내 영문.

### API 변경 시 체크리스트
1. `test/auto_my_invoice_web/controllers/api/` 테스트 추가
2. `packages/api-spec/openapi.yaml` 스펙 업데이트
3. `json_helpers.ex` 직렬화 확인
4. `fallback_controller.ex` 에러 핸들링 확인

### 함수/파일 크기
- 함수 50줄 이내, 파일 800줄 이내
- 컨트롤러는 Context 함수만 호출 (비즈니스 로직 금지)
- `Ecto.Changeset`으로 검증
- 테스트 커버리지 80% 유지

### Git 워크플로우
- `main` 직접 push 금지
- 브랜치명: `feat/<name>`, `fix/<name>`, `refactor/<scope>` 등
- 신규 브랜치는 `git push -u origin <branch>`
- PR 본문에 `Closes AMI-XX` 포함

---

## 7. 주요 MCP/도구 참고

- **Jira MCP**: `mcp__jira__*` (인증된 상태). 스프린트/이슈 조작에 사용.
- **code-review-graph MCP**: 코드 탐색 시 `Grep`보다 우선 사용 (`semantic_search_nodes`, `query_graph`, `detect_changes`).
- **mgrep 스킬**: 일반 검색은 `mgrep` 사용 (built-in Grep/WebSearch 비활성).

---

## 8. 위험/주의 사항

1. **`invoice_flow/` 중복 디렉토리** — AMI-58로 정리 예정. 실수로 수정하지 말 것.
2. **테스트 업로드 이미지 52개** untracked — `.gitignore` 정리 필수.
3. **Sprint 1·2 잔여 modified 33개** — 정체와 영향 범위 파악 후 정리.
4. **timezone 처리** (AMI-9 이미 수정됨) — 신규 작업 시 `Etc/UTC` ↔ 사용자 TZ 변환 일관성 유지.

---

## 9. 빠른 시작 명령어

```bash
# 환경 점검
make help
mix deps.get
make precommit

# 개발 서버
make server          # localhost:4000

# 테스트
make test            # 전체
make api-test        # API만

# Jira 작업 시작
# 1) AMI-84 상태를 '진행 중'으로
# 2) git checkout -b feat/ami-84-receipt-to-invoice
# 3) 작업 → make precommit → 커밋 → PR
```

---

**다음 에이전트에게**: 이 문서가 부정확하거나 누락된 부분이 있으면 작업 종료 시 함께 갱신하고 커밋하세요. 핸드오프 품질이 곧 다음 사람의 속도입니다.
