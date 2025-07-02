(use-trait token-trait .token.token-trait)

(define-constant contract-owner tx-sender)
(define-constant min-verifier-stake u1000)
(define-constant verification-period u1440)
(define-constant consensus-threshold u70)

(define-map impact-claims
  { claim-id: uint }
  { charity: principal,
    description: (string-ascii 256),
    beneficiaries-claimed: uint,
    evidence-hash: (buff 32),
    submitted-at: uint,
    verification-deadline: uint,
    status: (string-ascii 16),
    total-verifiers: uint,
    consensus-score: uint })

(define-map verifier-stakes
  { verifier: principal, claim-id: uint }
  { stake-amount: uint,
    verification-score: uint,
    submitted-at: uint,
    rewarded: bool })

(define-map verifier-reputation
  { verifier: principal }
  { total-verifications: uint,
    accuracy-score: uint,
    total-rewards: uint })

(define-map charity-impact-scores
  { charity: principal }
  { verified-claims: uint,
    total-beneficiaries: uint,
    credibility-score: uint,
    last-updated: uint })

(define-data-var claim-counter uint u0)
(define-data-var verification-reward-pool uint u0)

(define-public (submit-impact-claim
    (description (string-ascii 256))
    (beneficiaries uint)
    (evidence-hash (buff 32)))
  (let ((claim-id (+ (var-get claim-counter) u1))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    (var-set claim-counter claim-id)
    (map-set impact-claims
      { claim-id: claim-id }
      { charity: tx-sender,
        description: description,
        beneficiaries-claimed: beneficiaries,
        evidence-hash: evidence-hash,
        submitted-at: current-time,
        verification-deadline: (+ current-time verification-period),
        status: "pending",
        total-verifiers: u0,
        consensus-score: u0 })
    (ok claim-id)))

(define-public (verify-impact-claim (claim-id uint) (score uint) (stake-amount uint))
  (let ((claim (unwrap! (map-get? impact-claims { claim-id: claim-id }) (err u1200)))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    (asserts! (>= stake-amount min-verifier-stake) (err u1201))
    (asserts! (<= score u100) (err u1202))
    (asserts! (is-eq (get status claim) "pending") (err u1203))
    (asserts! (<= current-time (get verification-deadline claim)) (err u1204))
    (asserts! (is-none (map-get? verifier-stakes { verifier: tx-sender, claim-id: claim-id })) (err u1205))
    
    (try! (contract-call? .token transfer (as-contract tx-sender) stake-amount))
    
    (map-set verifier-stakes
      { verifier: tx-sender, claim-id: claim-id }
      { stake-amount: stake-amount,
        verification-score: score,
        submitted-at: current-time,
        rewarded: false })
    
    (let ((updated-verifiers (+ (get total-verifiers claim) u1))
          (weighted-score (/ (* score stake-amount) min-verifier-stake))
          (new-consensus (/ (+ (* (get consensus-score claim) (get total-verifiers claim)) weighted-score) updated-verifiers)))
      
      (map-set impact-claims
        { claim-id: claim-id }
        { charity: (get charity claim),
          description: (get description claim),
          beneficiaries-claimed: (get beneficiaries-claimed claim),
          evidence-hash: (get evidence-hash claim),
          submitted-at: (get submitted-at claim),
          verification-deadline: (get verification-deadline claim),
          status: (get status claim),
          total-verifiers: updated-verifiers,
          consensus-score: new-consensus })
      
      (update-verifier-reputation tx-sender)
      (ok true))))


(define-private (update-verifier-reputation (verifier principal))
  (let ((current-rep (default-to 
                     { total-verifications: u0, accuracy-score: u0, total-rewards: u0 }
                     (map-get? verifier-reputation { verifier: verifier }))))
    (map-set verifier-reputation
      { verifier: verifier }
      { total-verifications: (+ (get total-verifications current-rep) u1),
        accuracy-score: (get accuracy-score current-rep),
        total-rewards: (get total-rewards current-rep) })))

(define-private (update-charity-impact-score (charity principal) (beneficiaries uint))
  (let ((current-score (default-to
                       { verified-claims: u0, total-beneficiaries: u0, credibility-score: u0, last-updated: u0 }
                       (map-get? charity-impact-scores { charity: charity })))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    (let ((new-verified (+ (get verified-claims current-score) u1))
          (new-beneficiaries (+ (get total-beneficiaries current-score) beneficiaries))
          (new-credibility (/ (* new-beneficiaries u100) new-verified)))
      (map-set charity-impact-scores
        { charity: charity }
        { verified-claims: new-verified,
          total-beneficiaries: new-beneficiaries,
          credibility-score: new-credibility,
          last-updated: current-time }))))

(define-private (distribute-verification-rewards (claim-id uint))
  (let ((claim (unwrap-panic (map-get? impact-claims { claim-id: claim-id }))))
    (if (is-eq (get status claim) "verified")
        (reward-accurate-verifiers claim-id (get consensus-score claim))
        (penalize-inaccurate-verifiers claim-id (get consensus-score claim)))))

(define-private (reward-accurate-verifiers (claim-id uint) (consensus uint))
  (ok true))

(define-private (penalize-inaccurate-verifiers (claim-id uint) (consensus uint))
  (ok true))

(define-public (fund-verification-rewards (amount uint))
  (begin
    (try! (contract-call? .token transfer (as-contract tx-sender) amount))
    (var-set verification-reward-pool (+ (var-get verification-reward-pool) amount))
    (ok true)))

(define-public (claim-verification-reward (claim-id uint))
  (let ((verifier-stake (unwrap! (map-get? verifier-stakes { verifier: tx-sender, claim-id: claim-id }) (err u1210)))
        (claim (unwrap! (map-get? impact-claims { claim-id: claim-id }) (err u1211))))
    (asserts! (not (get rewarded verifier-stake)) (err u1212))
    (asserts! (or (is-eq (get status claim) "verified") (is-eq (get status claim) "rejected")) (err u1213))
    
    (let ((verifier-score (get verification-score verifier-stake))
          (consensus-score (get consensus-score claim))
          (accuracy (if (>= consensus-score consensus-threshold)
                       (- u100 (if (> verifier-score consensus-score) 
                                  (- verifier-score consensus-score)
                                  (- consensus-score verifier-score)))
                       (if (< verifier-score consensus-threshold)
                           (- u100 (- consensus-threshold verifier-score))
                           u0))))
      
      (let ((reward-amount (/ (* (get stake-amount verifier-stake) accuracy) u100)))
        ;; (if (> reward-amount u0)
        ;;     (try! (contract-call? .token transfer tx-sender reward-amount))
        ;;     (ok u0))
        
        (map-set verifier-stakes
          { verifier: tx-sender, claim-id: claim-id }
          { stake-amount: (get stake-amount verifier-stake),
            verification-score: (get verification-score verifier-stake),
            submitted-at: (get submitted-at verifier-stake),
            rewarded: true })
        
        (let ((current-rep (unwrap-panic (map-get? verifier-reputation { verifier: tx-sender }))))
          (map-set verifier-reputation
            { verifier: tx-sender }
            { total-verifications: (get total-verifications current-rep),
              accuracy-score: (/ (+ (* (get accuracy-score current-rep) (- (get total-verifications current-rep) u1)) accuracy) (get total-verifications current-rep)),
              total-rewards: (+ (get total-rewards current-rep) reward-amount) }))
        
        (ok reward-amount)))))

(define-read-only (get-impact-claim (claim-id uint))
  (map-get? impact-claims { claim-id: claim-id }))

(define-read-only (get-verifier-stake (verifier principal) (claim-id uint))
  (map-get? verifier-stakes { verifier: verifier, claim-id: claim-id }))

(define-read-only (get-verifier-reputation (verifier principal))
  (default-to { total-verifications: u0, accuracy-score: u0, total-rewards: u0 }
    (map-get? verifier-reputation { verifier: verifier })))

(define-read-only (get-charity-impact-score (charity principal))
  (default-to { verified-claims: u0, total-beneficiaries: u0, credibility-score: u0, last-updated: u0 }
    (map-get? charity-impact-scores { charity: charity })))

(define-read-only (get-verification-stats)
  { total-claims: (var-get claim-counter),
    reward-pool: (var-get verification-reward-pool) })