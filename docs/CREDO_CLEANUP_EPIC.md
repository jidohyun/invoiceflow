# Credo Strict Cleanup Epic

> **상태**: 📋 계획됨 (별도 epic, Sprint 4+ 대상)
> **목적**: `mix credo --strict` 를 CI 차단 검사로 복원
> **작성**: 2026-05-15 (Sprint 3 중간)

## 배경

`Sprint 3` 의 PR #9 (`fix(ci): bump Elixir/OTP`) 에서 CI 를 unblock 하기 위해 `mix credo --strict` 를 `mix credo` (기본 모드) 로 약화시켰고, 그것도 통과 못 해서 `continue-on-error: true` 로 정보용 단계로 격리했습니다. 이 epic 은 누적된 credo 부채를 갚고 다시 `--strict` 로 복원합니다.

## 현재 부채 (Sprint 3 hotfix 시점 측정)

`mix credo --strict` 실행 결과 (2026-05-15, Elixir 1.19.5):
```
831 mods/funs, found 1 warning, 9 refactoring opportunities,
                       39 code readability issues, 8 software design suggestions.
```

**총 57개 (사전 부채, 본 sprint 작업과 무관)**

### 주요 위반 패턴 (CI 로그 + 로컬 실행 기준)

| 분류 | 위치 | 예시 |
|---|---|---|
| Readability — alias not alphabetically ordered | `test/auto_my_invoice/workers/reminder_scheduler_test.exs:5`, `test/auto_my_invoice/workers/reminder_worker_test.exs:5` | `alias AutoMyInvoice.Workers.ReminderScheduler` 정렬 |
| Readability — number underscore | `test/auto_my_invoice/workers/reminder_scheduler_test.exs:67` | `86400` → `86_400` |
| Readability — nested module alias | `test/support/data_case.ex:39,40` | nested module 최상단에서 alias |
| Refactoring — large function | `lib/auto_my_invoice_web/controllers/api/auth_controller.ex:69 (verify_google_id_token)`, `lib/auto_my_invoice_web/controllers/user_oauth_controller.ex:11 (callback)`, `lib/auto_my_invoice_web/controllers/api/upload_controller.ex:21 (create)` | 함수 분리 |
| Refactoring — large function | `lib/auto_my_invoice_web/components/ui_components.ex:182 (insert_commas)`, `lib/auto_my_invoice/pdf/invoice_pdf.ex:141 (render_items), :201 (add_thousand_separator)`, `lib/auto_my_invoice/emails/reminder_email.ex:302 (add_thousand_separator)`, `lib/auto_my_invoice/emails/overdue_email.ex:149 (add_thousand_separator)` | 함수 분리 |
| Warning — Length.length(_) | `test/auto_my_invoice/reminders_test.exs:363` | `length(list) > 0` → `list != []` |
| Software design — TODO 주석 잔재 | `lib/auto_my_invoice/errors.ex:1` 등 | TODO 처리 |

## Out of Scope (이 epic 에서 다루지 않음)

- 의존성 deprecation warning (tesla 사용 deprecation, swoosh Elixir 요구 1.16 미달) — 본 epic 으로 처리되지 않음. 별도 `chore: drop unused deps` 또는 `chore: update deps` epic.
- `lib/db_connection/util.ex:35` 의 `Process.set_label/1 undefined` (외부 dep 의 자체 부채) — Elixir 1.20+ 에서 해소될 가능성, 직접 손대지 않음.

## Plan (TDD 순서)

### Phase 1 — 자동 픽서블 (1 commit)
가장 안전한 readability 이슈부터:
1. Readability — `mix credo --only readability --strict` 후 alias 정렬 / 숫자 underscore / nested module alias 일괄 수정.
2. `mix test` 회귀 확인.
3. 단일 commit `refactor(credo): readability — alias order, number underscore, nested aliases`.

### Phase 2 — Warning (1 commit)
4. `Reminders.length(list) > 0` 패턴 → `list != []`.
5. 단일 commit `refactor(credo): replace length-comparison with empty-list check`.

### Phase 3 — Refactoring (3-5 commits, 함수별 분리)
6. PDF / Email 의 `add_thousand_separator` 류 — 헬퍼 모듈 (예: `AutoMyInvoice.NumberFormat`) 추출. 3개 호출처(`invoice_pdf.ex`, `reminder_email.ex`, `overdue_email.ex`, `ui_components.ex`) DRY.
7. `AuthController.verify_google_id_token` — 함수 분해 + 테스트 보강.
8. `UserOauthController.callback` — 함수 분해 + 분기 단순화.
9. `UploadController.create` — 함수 분해 + 가드 정리.
10. `invoice_pdf.ex` `render_items` — 함수 분해.

### Phase 4 — Software design (1 commit)
11. TODO/FIXME 주석 잔재 정리. `Errors` 모듈 docstring 보강.

### Phase 5 — CI 복원 (1 commit, **블록터**)
12. `.github/workflows/server.yml`:
    - `mix credo` (informational) → `mix credo --strict` (차단)
    - `continue-on-error: true` 제거
13. CI 재실행해서 green 확인.

## 권장 작업 단위
- **각 phase 별 별도 PR** 권장 (review 부담 분산).
- 또는 epic 브랜치 (`refactor/credo-strict-cleanup`) 에 PR-stack 으로 쌓아 한 번에 squash.

## 위험
- `add_thousand_separator` 헬퍼 DRY 추출 시, 음수 처리 등 엣지케이스가 호출처마다 미세하게 다를 수 있음 → 추출 전 호출처 동작을 테스트로 고정한 뒤 통합.
- Controller 분해 시 plug pipeline 의존성을 깨지 않도록 주의.

## 추적
- 새 epic 티켓 생성 권장 (Jira `AMI-XX: credo --strict cleanup`)
- 본 문서 위치: `docs/CREDO_CLEANUP_EPIC.md`
- 관련 PR: #9 (격리 commit)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
