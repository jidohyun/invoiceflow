# TODOS

## Payment Reversal/Refund Path
- **What:** record_payment로 기록된 수동 결제를 취소/환불하는 기능 추가
- **Why:** 실수로 결제 기록을 잘못 입력하면 되돌릴 수 없음. Paddle webhook은 refund 이벤트를 처리하지만 수동 결제에는 취소 경로가 없음.
- **Pros:** 사용자 실수 복구, 데이터 정확성 보장
- **Cons:** 상태 전환 복잡도 증가 (paid → partially_paid → sent 역방향 전환 필요)
- **Context:** Sprint 1에서 record_payment/2를 paid_amount 누적 방식으로 구현. 별도 payments 테이블이 아니라 invoice.paid_amount 필드를 직접 조작하므로, 환불 시 paid_amount를 차감하고 상태를 역전환해야 함. @valid_transitions에 역방향 전환 추가 필요.
- **Depends on:** record_payment 구현 완료 후
- **Added:** 2026-03-31 by /plan-eng-review (outside voice finding)
