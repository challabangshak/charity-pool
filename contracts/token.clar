(define-fungible-token stk-token)

(define-map balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)

(define-public (transfer (recipient principal) (amount uint))
  (let ((sender-balance (default-to u0 (map-get? balances tx-sender))))
    (asserts! (>= sender-balance amount) (err u100))
    (asserts! (not (is-eq tx-sender recipient)) (err u101))
    (try! (ft-transfer? stk-token amount tx-sender recipient))
    (ok true)
  ))

(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (asserts! (not (is-eq tx-sender recipient)) (err u101))
    (asserts! (not (is-eq recipient (var-get contract-owner))) (err u101))
    (asserts! (> u0 amount) (err u100))
    (try! (ft-mint? stk-token amount recipient))
    (ok true)
  ))

(define-read-only (get-balance (owner principal)) (default-to u0 (map-get? balances owner)))


(define-data-var contract-owner principal tx-sender)

(define-trait token-trait (
  (transfer (principal principal uint) (response bool uint))
))

