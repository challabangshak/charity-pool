(use-trait token-trait .token.token-trait)

(define-constant contract-owner tx-sender)
(define-constant min-arbitrator-stake u5000)
(define-constant dispute-fee u500)
(define-constant arbitration-period u2880) ;; 48 hours in blocks
(define-constant evidence-period u1440) ;; 24 hours in blocks
(define-constant arbitrator-reward-percentage u20)

;; Data structures for dispute management
(define-map disputes
  { dispute-id: uint }
  { plaintiff: principal,
    defendant: principal,
    dispute-type: (string-ascii 32),
    description: (string-ascii 512),
    evidence-hash: (buff 32),
    stake-amount: uint,
    created-at: uint,
    evidence-deadline: uint,
    arbitration-deadline: uint,
    status: (string-ascii 17),
    arbitrator-count: uint,
    ruling-votes-for: uint,
    ruling-votes-against: uint,
    final-ruling: (optional bool),
    resolution-description: (string-ascii 256) })

;; Track arbitrator participation and stakes
(define-map arbitrator-stakes
  { arbitrator: principal, dispute-id: uint }
  { stake-amount: uint,
    vote: (optional bool),
    stake-time: uint,
    reward-claimed: bool })

;; Arbitrator reputation and qualifications
(define-map arbitrator-profiles
  { arbitrator: principal }
  { total-cases: uint,
    successful-rulings: uint,
    reputation-score: uint,
    stake-balance: uint,
    registration-time: uint,
    active: bool })

;; Evidence submissions for disputes
(define-map dispute-evidence
  { dispute-id: uint, evidence-id: uint }
  { submitter: principal,
    evidence-hash: (buff 32),
    description: (string-ascii 256),
    submission-time: uint })

;; Appeal mechanism for disputed rulings
(define-map appeals
  { appeal-id: uint }
  { original-dispute-id: uint,
    appellant: principal,
    appeal-reason: (string-ascii 256),
    additional-stake: uint,
    status: (string-ascii 17),
    created-at: uint })

;; Global counters and settings
(define-data-var dispute-counter uint u0)
(define-data-var evidence-counter uint u0)
(define-data-var appeal-counter uint u0)
(define-data-var arbitrator-reward-pool uint u0)

;; Register as an arbitrator with minimum stake
(define-public (register-arbitrator (stake-amount uint))
  (begin
    (asserts! (>= stake-amount min-arbitrator-stake) (err u2001))
    (asserts! (is-none (map-get? arbitrator-profiles { arbitrator: tx-sender })) (err u2002))
    
    (try! (contract-call? .token transfer (as-contract tx-sender) stake-amount))
    
    (map-set arbitrator-profiles
      { arbitrator: tx-sender }
      { total-cases: u0,
        successful-rulings: u0,
        reputation-score: u100,
        stake-balance: stake-amount,
        registration-time: (unwrap-panic (get-stacks-block-info? time u0)),
        active: true })
    
    (ok true)))

;; Create a new dispute with required stake
(define-public (create-dispute 
    (defendant principal)
    (dispute-type (string-ascii 32))
    (description (string-ascii 512))
    (evidence-hash (buff 32))
    (stake-amount uint))
  (let ((dispute-id (+ (var-get dispute-counter) u1))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    
    (asserts! (>= stake-amount dispute-fee) (err u2003))
    (asserts! (not (is-eq tx-sender defendant)) (err u2004))
    
    (try! (contract-call? .token transfer (as-contract tx-sender) stake-amount))
    
    (var-set dispute-counter dispute-id)
    (map-set disputes
      { dispute-id: dispute-id }
      { plaintiff: tx-sender,
        defendant: defendant,
        dispute-type: dispute-type,
        description: description,
        evidence-hash: evidence-hash,
        stake-amount: stake-amount,
        created-at: current-time,
        evidence-deadline: (+ current-time evidence-period),
        arbitration-deadline: (+ current-time arbitration-period),
        status: "evidence-phase",
        arbitrator-count: u0,
        ruling-votes-for: u0,
        ruling-votes-against: u0,
        final-ruling: none,
        resolution-description: "" })
    
    (ok dispute-id)))

;; Submit evidence for an ongoing dispute
(define-public (submit-evidence 
    (dispute-id uint)
    (evidence-hash (buff 32))
    (description (string-ascii 256)))
  (let ((dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err u2005)))
        (evidence-id (+ (var-get evidence-counter) u1))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    
    (asserts! (is-eq (get status dispute) "evidence-phase") (err u2006))
    (asserts! (<= current-time (get evidence-deadline dispute)) (err u2007))
    (asserts! (or (is-eq tx-sender (get plaintiff dispute)) 
                  (is-eq tx-sender (get defendant dispute))) (err u2008))
    
    (var-set evidence-counter evidence-id)
    (map-set dispute-evidence
      { dispute-id: dispute-id, evidence-id: evidence-id }
      { submitter: tx-sender,
        evidence-hash: evidence-hash,
        description: description,
        submission-time: current-time })
    
    (ok evidence-id)))

;; Join as arbitrator for a specific dispute
(define-public (join-arbitration (dispute-id uint) (stake-amount uint))
  (let ((dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err u2009)))
        (arbitrator-profile (unwrap! (map-get? arbitrator-profiles { arbitrator: tx-sender }) (err u2010)))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    
    (asserts! (>= stake-amount min-arbitrator-stake) (err u2011))
    (asserts! (get active arbitrator-profile) (err u2012))
    (asserts! (or (is-eq (get status dispute) "evidence-phase") 
                  (is-eq (get status dispute) "arbitration-phase")) (err u2013))
    (asserts! (> (get arbitration-deadline dispute) current-time) (err u2014))
    (asserts! (is-none (map-get? arbitrator-stakes { arbitrator: tx-sender, dispute-id: dispute-id })) (err u2015))
    
    (try! (contract-call? .token transfer (as-contract tx-sender) stake-amount))
    
    (map-set arbitrator-stakes
      { arbitrator: tx-sender, dispute-id: dispute-id }
      { stake-amount: stake-amount,
        vote: none,
        stake-time: current-time,
        reward-claimed: false })
    
    ;; Update dispute with new arbitrator count
    (map-set disputes
      { dispute-id: dispute-id }
      { plaintiff: (get plaintiff dispute),
        defendant: (get defendant dispute),
        dispute-type: (get dispute-type dispute),
        description: (get description dispute),
        evidence-hash: (get evidence-hash dispute),
        stake-amount: (get stake-amount dispute),
        created-at: (get created-at dispute),
        evidence-deadline: (get evidence-deadline dispute),
        arbitration-deadline: (get arbitration-deadline dispute),
        status: "arbitration-phase",
        arbitrator-count: (+ (get arbitrator-count dispute) u1),
        ruling-votes-for: (get ruling-votes-for dispute),
        ruling-votes-against: (get ruling-votes-against dispute),
        final-ruling: (get final-ruling dispute),
        resolution-description: (get resolution-description dispute) })
    
    (ok true)))

;; Cast ruling vote as arbitrator
(define-public (cast-arbitration-vote (dispute-id uint) (vote-for-plaintiff bool))
  (let ((dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err u2016)))
        (arbitrator-stake (unwrap! (map-get? arbitrator-stakes { arbitrator: tx-sender, dispute-id: dispute-id }) (err u2017)))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    
    (asserts! (is-eq (get status dispute) "arbitration-phase") (err u2018))
    (asserts! (<= current-time (get arbitration-deadline dispute)) (err u2019))
    (asserts! (is-none (get vote arbitrator-stake)) (err u2020))
    
    ;; Record the vote
    (map-set arbitrator-stakes
      { arbitrator: tx-sender, dispute-id: dispute-id }
      { stake-amount: (get stake-amount arbitrator-stake),
        vote: (some vote-for-plaintiff),
        stake-time: (get stake-time arbitrator-stake),
        reward-claimed: (get reward-claimed arbitrator-stake) })
    
    ;; Update vote counts
    (if vote-for-plaintiff
        (map-set disputes
          { dispute-id: dispute-id }
          { plaintiff: (get plaintiff dispute),
            defendant: (get defendant dispute),
            dispute-type: (get dispute-type dispute),
            description: (get description dispute),
            evidence-hash: (get evidence-hash dispute),
            stake-amount: (get stake-amount dispute),
            created-at: (get created-at dispute),
            evidence-deadline: (get evidence-deadline dispute),
            arbitration-deadline: (get arbitration-deadline dispute),
            status: (get status dispute),
            arbitrator-count: (get arbitrator-count dispute),
            ruling-votes-for: (+ (get ruling-votes-for dispute) u1),
            ruling-votes-against: (get ruling-votes-against dispute),
            final-ruling: (get final-ruling dispute),
            resolution-description: (get resolution-description dispute) })
        (map-set disputes
          { dispute-id: dispute-id }
          { plaintiff: (get plaintiff dispute),
            defendant: (get defendant dispute),
            dispute-type: (get dispute-type dispute),
            description: (get description dispute),
            evidence-hash: (get evidence-hash dispute),
            stake-amount: (get stake-amount dispute),
            created-at: (get created-at dispute),
            evidence-deadline: (get evidence-deadline dispute),
            arbitration-deadline: (get arbitration-deadline dispute),
            status: (get status dispute),
            arbitrator-count: (get arbitrator-count dispute),
            ruling-votes-for: (get ruling-votes-for dispute),
            ruling-votes-against: (+ (get ruling-votes-against dispute) u1),
            final-ruling: (get final-ruling dispute),
            resolution-description: (get resolution-description dispute) }))
    
    (ok true)))

;; Finalize dispute resolution after arbitration period
(define-public (finalize-dispute (dispute-id uint) (resolution-description (string-ascii 256)))
  (let ((dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err u2021)))
        (current-time (unwrap-panic (get-stacks-block-info? time u0))))
    
    (asserts! (is-eq (get status dispute) "arbitration-phase") (err u2022))
    (asserts! (> current-time (get arbitration-deadline dispute)) (err u2023))
    (asserts! (> (get arbitrator-count dispute) u0) (err u2024))
    
    ;; Determine ruling based on majority vote
    (let ((ruling (> (get ruling-votes-for dispute) (get ruling-votes-against dispute))))
      
      (map-set disputes
        { dispute-id: dispute-id }
        { plaintiff: (get plaintiff dispute),
          defendant: (get defendant dispute),
          dispute-type: (get dispute-type dispute),
          description: (get description dispute),
          evidence-hash: (get evidence-hash dispute),
          stake-amount: (get stake-amount dispute),
          created-at: (get created-at dispute),
          evidence-deadline: (get evidence-deadline dispute),
          arbitration-deadline: (get arbitration-deadline dispute),
          status: "resolved",
          arbitrator-count: (get arbitrator-count dispute),
          ruling-votes-for: (get ruling-votes-for dispute),
          ruling-votes-against: (get ruling-votes-against dispute),
          final-ruling: (some ruling),
          resolution-description: resolution-description })
      
      ;; Distribute stakes based on ruling
      (if ruling
          (try! (contract-call? .token transfer (get plaintiff dispute) (get stake-amount dispute)))
          (try! (contract-call? .token transfer (get defendant dispute) (get stake-amount dispute))))
      
      (ok ruling))))

;; Claim arbitrator rewards for successful participation
(define-public (claim-arbitrator-reward (dispute-id uint))
  (let ((dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) (err u2025)))
        (arbitrator-stake (unwrap! (map-get? arbitrator-stakes { arbitrator: tx-sender, dispute-id: dispute-id }) (err u2026))))
    
    (asserts! (is-eq (get status dispute) "resolved") (err u2027))
    (asserts! (not (get reward-claimed arbitrator-stake)) (err u2028))
    (asserts! (is-some (get vote arbitrator-stake)) (err u2029))
    
    ;; Check if arbitrator voted with majority
    (let ((arbitrator-vote (unwrap-panic (get vote arbitrator-stake)))
          (final-ruling (unwrap-panic (get final-ruling dispute))))
      
      (if (is-eq arbitrator-vote final-ruling)
          ;; Reward successful arbitrator
          (let ((reward-amount (/ (* (get stake-amount arbitrator-stake) arbitrator-reward-percentage) u100)))
            
            (map-set arbitrator-stakes
              { arbitrator: tx-sender, dispute-id: dispute-id }
              { stake-amount: (get stake-amount arbitrator-stake),
                vote: (get vote arbitrator-stake),
                stake-time: (get stake-time arbitrator-stake),
                reward-claimed: true })
            
            ;; Update arbitrator reputation
            (update-arbitrator-reputation tx-sender true)
            
            (try! (contract-call? .token transfer tx-sender (+ (get stake-amount arbitrator-stake) reward-amount)))
            (ok reward-amount))
          ;; Penalize incorrect arbitrator
          (begin
            (map-set arbitrator-stakes
              { arbitrator: tx-sender, dispute-id: dispute-id }
              { stake-amount: (get stake-amount arbitrator-stake),
                vote: (get vote arbitrator-stake),
                stake-time: (get stake-time arbitrator-stake),
                reward-claimed: true })
            
            (update-arbitrator-reputation tx-sender false)
            (ok u0))))))

;; Update arbitrator reputation based on performance
(define-private (update-arbitrator-reputation (arbitrator principal) (successful bool))
  (let ((profile (unwrap-panic (map-get? arbitrator-profiles { arbitrator: arbitrator }))))
    (let ((new-total-cases (+ (get total-cases profile) u1))
          (new-successful (if successful (+ (get successful-rulings profile) u1) (get successful-rulings profile))))
      
      (map-set arbitrator-profiles
        { arbitrator: arbitrator }
        { total-cases: new-total-cases,
          successful-rulings: new-successful,
          reputation-score: (/ (* new-successful u100) new-total-cases),
          stake-balance: (get stake-balance profile),
          registration-time: (get registration-time profile),
          active: (get active profile) }))))

;; Read-only functions for querying system state
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id }))

(define-read-only (get-arbitrator-profile (arbitrator principal))
  (map-get? arbitrator-profiles { arbitrator: arbitrator }))

(define-read-only (get-arbitrator-stake (arbitrator principal) (dispute-id uint))
  (map-get? arbitrator-stakes { arbitrator: arbitrator, dispute-id: dispute-id }))

(define-read-only (get-dispute-evidence (dispute-id uint) (evidence-id uint))
  (map-get? dispute-evidence { dispute-id: dispute-id, evidence-id: evidence-id }))

(define-read-only (get-system-stats)
  { total-disputes: (var-get dispute-counter),
    total-evidence: (var-get evidence-counter),
    reward-pool: (var-get arbitrator-reward-pool) })



