(use-trait token-trait .token.token-trait)
(define-constant contract-owner tx-sender)

;; Declare the maps and variables at the top level of your contract
(define-map stakers { staker: principal } { amount: uint }) ;; Track user stakes
(define-map votes { voter: principal } { charity: principal }) ;; Track user votes
(define-map leaderboard { contributor: principal } { total: uint }) ;; Track contributions for leaderboards

(define-data-var donation-percentage (tuple (value uint)) (tuple (value u10))) ;; Default: 10%
(define-data-var total-donated (tuple (value uint)) (tuple (value u0))) ;; Total donated initialized to 0
(define-data-var total-staked (tuple (value uint)) (tuple (value u0))) ;; Total staked initialized to 0
;; (define-data-var charity-address principal none) ;; Charity address initialized to none
(define-data-var charity-address (optional principal) none) ;; Charity address initialized to none

(define-public (stake (amount uint))
  (begin
    ;; Attempt to transfer tokens from the sender to the contract
    (try! (contract-call? .token transfer  (as-contract tx-sender) amount))

    ;; Retrieve the current stake of the sender, defaulting to 0 if not present
    (let ((current-stake (default-to u0 (get amount (map-get? stakers { staker: tx-sender })))))      
     
      ;; Update the staker's balance in the map
      (map-set stakers { staker: tx-sender } { amount: (+ current-stake amount) })

      ;; Update the total staked amount correctly
      (let ((current-total-staked (get value (var-get total-staked))))
        (var-set total-staked (tuple (value (+ current-total-staked amount)))))

      ;; Return a success message
      (ok "Stake successful"))))
(define-public (withdraw)
  (let ((staker-data (map-get? stakers { staker: tx-sender })))
    (let ((user-stake (default-to u0 (get amount staker-data))))
      (asserts! (> user-stake u0) (err u101))
      (let ((donation-percentage-data (var-get donation-percentage))
            (donation (/ (* user-stake (get value donation-percentage-data)) u100))
            (reward (- user-stake donation)))
        
        ;; Attempt to transfer the reward back to the user
        (try! (contract-call? .token transfer (as-contract tx-sender) reward))

        ;; Retrieve current total-donated and total-staked values
        (let ((current-total-donated (get value (var-get total-donated)))
              (current-total-staked (get value (var-get total-staked))))
          
          ;; Update total-donated and total-staked
          (var-set total-donated (tuple (value (+ current-total-donated donation))))
          (var-set total-staked (tuple (value (- current-total-staked user-stake))))

          ;; Remove the user's stake from the stakers map
          (map-delete stakers { staker: tx-sender })

          ;; Return success message
          (ok "Withdrawal successful"))))))

(define-public (set-donation-percentage (percentage uint))
  (begin
    (asserts! (<= percentage u100) (err u102))
    (var-set donation-percentage (tuple (value percentage)))
    (ok "Donation percentage updated")))

(define-public (vote (charity principal))
  (begin
    ;; Check if the user has already voted
    (asserts! (is-none (map-get? votes { voter: tx-sender })) (err u103))

    ;; Record the user's vote
    (map-set votes { voter: tx-sender } { charity: charity })

    (ok "Vote submitted")))


(define-public (distribute-donations)
  (let ((current-total-staked (get value (var-get total-staked)))
        (current-donation-percentage (get value (var-get donation-percentage)))
        (maybe-charity (var-get charity-address)))

    (if (is-some maybe-charity)
        (let ((charity-principal (unwrap-panic maybe-charity)))
          
          (let ((total-donations (/ (* current-total-staked current-donation-percentage) u100)))

            (update-leaderboard charity-principal total-donations)

            (var-set total-donated (tuple (value (+ (get value (var-get total-donated)) total-donations))))

            (ok "Donations distributed")))
        (err u1)
    )
  )
)

(define-private (update-leaderboard (charity principal) (amount uint))
  ;; Update the charity's total in the leaderboard map
  (let ((current-total (default-to u0 (get total (map-get? leaderboard { contributor: charity })))))
    (map-set leaderboard { contributor: charity } { total: (+ current-total amount) })))


(define-public (set-charity (charity principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (ok (var-set charity-address (some charity)))))
(define-read-only (get-leaderboard (charity principal))
  (default-to { total: u0 } (map-get? leaderboard { contributor: charity })))


(define-map staking-duration { staker: principal } { start-time: uint })

(define-public (calculate-rewards (staker principal)) 
  (let ((stake-start (default-to u0 (get start-time (map-get? staking-duration { staker: staker }))))
        (current-time (unwrap-panic (get-block-info? time u0)))
        (duration (- current-time stake-start))
        (bonus-rate u5))
    (ok (/ (* duration bonus-rate) u100))))


(define-map verified-charities { charity: principal } { verified: bool, verification-date: uint })

(define-public (verify-charity (charity principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u1))
    (ok (map-set verified-charities 
                 { charity: charity } 
                 { verified: true, 
                   verification-date: (unwrap-panic (get-block-info? time u0)) }))))
