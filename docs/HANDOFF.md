# AutoMyInvoice 프로젝트 핸드오프 문서

> **목적**: 컨텍스트가 초기화된 에이전트가 이 문서 하나만 읽고 즉시 다음 작업을 시작할 수 있도록 현재까지의 진행 상황과 다음 액션을 정리합니다.
>
> **마지막 갱신**: 2026-05-15

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
| Sprint 3 - 분석 & AI | 70 | 2026-04-29 ~ 05-12 | 🟢 **active** | 0/4 (착수 전) |
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

### Sprint 3 — **지금 작업해야 하는 4건** ⬇️

| Key | 제목 | 상태 |
|---|---|---|
| **AMI-84** | 영수증 촬영 → AI 자동 송장 생성 | 해야 할 일 |
| **AMI-85** | 다중 영수증 배치 처리 | 해야 할 일 |
| **AMI-86** | 내 브랜드로 이메일 커스터마이징 | 해야 할 일 |
| **AMI-87** | 비밀번호 없이 로그인 & 계정 복구 | 해야 할 일 |

스프린트 목표: **대시보드 분석 차트, OCR 강화, 이메일 커스터마이징**

### Sprint 4 (대기) — AMI-88~91
모바일 송장 관리, QR 현장 결제, 다중 통화, 한국 전자세금계산서

### 백로그
63건. 인프라/보안(AMI-13~21), 송장강화(AMI-22~28), 설정(AMI-25~27), 분석(AMI-32~35), AI OCR(AMI-36~38), 모바일/Pro(AMI-41~51), 기술부채 작업(AMI-52~58), 에픽 묶음(AMI-59~75).

---

## 3. 작업 디렉토리 현재 상태 ⚠️

**커밋되지 않은 변경사항이 다수 존재합니다.** 작업 시작 전에 반드시 정리하세요.

### 미커밋 modified (33개 파일)
주로 LiveView 페이지 (`lib/auto_my_invoice_web/live/*`), 이메일 템플릿, 컴포넌트, 컨트롤러. Sprint 1~2 작업의 잔여 변경으로 추정.

### 미커밋 untracked (주요)
- `docs/PROJECT_PLAN.md`, `docs/QA_REPORT_2026-03-11.md`, `docs/sprint_reports/` (1~2차 스프린트 보고서 8건)
- `invoice_flow/` (중복 디렉토리 — 백로그 AMI-58 정리 대상)
- `priv/repo/migrations/20260414000001_change_invoices_currency_default_to_krw.exs`
- `priv/static/uploads/test-*.png` (52개 테스트 업로드 이미지 — `.gitignore` 추가 권장)

### 원격 동기화
```
Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded.
```
→ **시작 전 `git pull --ff-only` 필요**

### 최근 커밋
```
f295c45 feat: complete Sprint 2 analytics dashboard with demo data
2d25e63 feat: complete Sprint 1 collection flow
431da7f chore: add gstack skill routing rules to CLAUDE.md
```

---

## 4. 다음 에이전트가 즉시 해야 할 일

### Step 0: 환경 동기화
```bash
git pull --ff-only origin main
mix deps.get
make precommit  # compile + format + test, 통과 확인
```

### Step 1: 미커밋 변경사항 처리 결정
사용자에게 확인 후 둘 중 선택:
1. **(권장)** 33개 modified를 의미 단위로 쪼개 커밋. `git diff` 검토 → `feat:`/`fix:`/`refactor:` 타입별 분리.
2. 변경사항이 Sprint 1~2 잔재라면 단일 `chore: cleanup post-sprint-2 leftovers` 커밋.

`priv/static/uploads/test-*.png`는 `.gitignore`에 추가하고 커밋 대상에서 제외할 것.

### Step 2: Sprint 3 첫 작업 — AMI-84 추천
**영수증 촬영 → AI 자동 송장 생성**이 다른 3건의 전제(OCR 파이프라인이 86 이메일 브랜딩과 87 매직링크보다 의존성 적음, 85 배치는 84의 단일처리 위에 얹는 구조).

작업 시작 시:
```bash
git checkout -b feat/ami-84-receipt-to-invoice
```

Jira 트랜지션:
- 상태를 `진행 중`으로 이동 (`mcp__jira__jira_transition_issue` 사용)
- 작업 완료 시 `완료`로 이동, PR에 `AMI-84` 키 포함

### Step 3: Sprint 3 작업 순서 권장
1. **AMI-84** OCR 단건 (Claude Vision 파이프라인은 1차 스프린트에서 95% 정확도 달성. `lib/auto_my_invoice/extraction.ex` 확장)
2. **AMI-85** 다중 배치 (Oban fan-out 패턴)
3. **AMI-86** 이메일 브랜딩 (사용자별 로고/색상, `emails/*.ex` 템플릿화)
4. **AMI-87** 매직링크 로그인 + 비밀번호 재설정 플로우 (`Accounts` 컨텍스트 확장)

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
test/                        # ExUnit (133+ 테스트 통과 유지)
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
