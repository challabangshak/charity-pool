;; Donor Badge NFT Contract
;; Rewards donors with collectible NFT badges based on cumulative donation amounts

;; Error constants
(define-constant ERR_NOT_ELIGIBLE (err u200))
(define-constant ERR_ALREADY_CLAIMED (err u201))
(define-constant ERR_INVALID_BADGE_LEVEL (err u202))
(define-constant ERR_TOKEN_NOT_FOUND (err u203))

;; Badge tier thresholds
(define-constant BRONZE_THRESHOLD u1000)   ;; 1,000 tokens donated
(define-constant SILVER_THRESHOLD u10000)  ;; 10,000 tokens donated  
(define-constant GOLD_THRESHOLD u100000)   ;; 100,000 tokens donated

;; Badge tier constants
(define-constant BRONZE_TIER u1)
(define-constant SILVER_TIER u2)
(define-constant GOLD_TIER u3)

;; NFT definition for donor badges
(define-non-fungible-token donor-badge uint)

;; Track the next available badge token ID
(define-data-var next-badge-id uint u1)

;; Store badge information for each token
(define-map badge-data 
  { token-id: uint }
  { owner: principal, tier: uint, claimed-at: uint, donation-amount: uint })

;; Track the highest badge tier claimed by each donor
(define-map donor-badge-levels
  { donor: principal }
  { highest-tier: uint })

;; Store badge tier metadata
(define-map badge-tier-metadata
  { tier: uint }
  { name: (string-ascii 32), description: (string-ascii 128), image-uri: (string-ascii 128) })

;; Initialize badge tier metadata
(map-set badge-tier-metadata { tier: BRONZE_TIER } 
  { name: "Bronze Supporter", 
    description: "Thank you for your generosity! First milestone reached with 1,000+ tokens donated.", 
    image-uri: "https://badges.charity-pool.org/bronze.png" })

(map-set badge-tier-metadata { tier: SILVER_TIER }
  { name: "Silver Champion", 
    description: "Outstanding commitment! You've donated over 10,000 tokens to make a difference.", 
    image-uri: "https://badges.charity-pool.org/silver.png" })

(map-set badge-tier-metadata { tier: GOLD_TIER }
  { name: "Gold Guardian", 
    description: "Extraordinary philanthropist! Your 100,000+ token donations are changing lives.", 
    image-uri: "https://badges.charity-pool.org/gold.png" })

;; Determine badge tier based on donation amount
(define-private (calculate-tier (donation-total uint))
  (if (>= donation-total GOLD_THRESHOLD)
    GOLD_TIER
    (if (>= donation-total SILVER_THRESHOLD)
      SILVER_TIER
      (if (>= donation-total BRONZE_THRESHOLD)
        BRONZE_TIER
        u0))))

;; Check if donor is eligible for a new badge tier
(define-private (is-eligible-for-tier (donor principal) (new-tier uint))
  (let ((current-tier (default-to u0 (get highest-tier (map-get? donor-badge-levels { donor: donor })))))
    (and (> new-tier u0) (> new-tier current-tier))))

;; Main function to claim a donor badge
(define-public (claim-badge)
  (let (
    ;; Get donor's total donations from charity-pool leaderboard
    (leaderboard-entry (contract-call? .charity-pool get-leaderboard tx-sender))
    (donation-total (get total leaderboard-entry))
    (eligible-tier (calculate-tier donation-total))
    (current-highest-tier (default-to u0 (get highest-tier (map-get? donor-badge-levels { donor: tx-sender }))))
    (badge-id (var-get next-badge-id))
  )
    ;; Check if donor is eligible for any badge
    (asserts! (> eligible-tier u0) ERR_NOT_ELIGIBLE)
    
    ;; Check if this is a new tier (higher than previously claimed)
    (asserts! (is-eligible-for-tier tx-sender eligible-tier) ERR_ALREADY_CLAIMED)
    
    ;; Mint the NFT badge
    (try! (nft-mint? donor-badge badge-id tx-sender))
    
    ;; Store badge data
    (map-set badge-data
      { token-id: badge-id }
      { owner: tx-sender, 
        tier: eligible-tier, 
        claimed-at: stacks-block-height,
        donation-amount: donation-total })
    
    ;; Update donor's highest tier
    (map-set donor-badge-levels
      { donor: tx-sender }
      { highest-tier: eligible-tier })
    
    ;; Increment badge ID for next mint
    (var-set next-badge-id (+ badge-id u1))
    
    ;; Return success with badge details
    (ok { badge-id: badge-id, tier: eligible-tier, donation-total: donation-total })))

;; Check if donor can claim a higher tier badge
(define-read-only (check-badge-eligibility (donor principal))
  (let (
    (leaderboard-entry (contract-call? .charity-pool get-leaderboard donor))
    (donation-total (get total leaderboard-entry))
    (eligible-tier (calculate-tier donation-total))
    (current-tier (default-to u0 (get highest-tier (map-get? donor-badge-levels { donor: donor }))))
  )
    { eligible: (is-eligible-for-tier donor eligible-tier),
      current-tier: current-tier,
      eligible-tier: eligible-tier,
      donation-total: donation-total }))

;; Get badge details by token ID
(define-read-only (get-badge-details (token-id uint))
  (map-get? badge-data { token-id: token-id }))

;; Get donor's current badge level
(define-read-only (get-donor-badge-level (donor principal))
  (default-to { highest-tier: u0 } (map-get? donor-badge-levels { donor: donor })))

;; Get badge tier metadata
(define-read-only (get-badge-tier-info (tier uint))
  (map-get? badge-tier-metadata { tier: tier }))

;; NFT URI function for metadata
(define-read-only (get-token-uri (token-id uint))
  (let ((badge-info (map-get? badge-data { token-id: token-id })))
    (match badge-info
      badge (let ((tier-metadata (unwrap! (map-get? badge-tier-metadata { tier: (get tier badge) }) 
                                  (ok none))))
              (ok (some (get image-uri tier-metadata))))
      (ok none))))

;; Get NFT owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? donor-badge token-id)))

;; Transfer badge (standard NFT function)
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_ELIGIBLE)
    (try! (nft-transfer? donor-badge token-id sender recipient))
    (ok true)))

;; Get total number of badges minted
(define-read-only (get-total-badges-minted)
  (- (var-get next-badge-id) u1))

;; Get all badge tiers and their thresholds (helper for frontend)
(define-read-only (get-all-tier-thresholds)
  { bronze: BRONZE_THRESHOLD, 
    silver: SILVER_THRESHOLD, 
    gold: GOLD_THRESHOLD })

;; Check if a specific tier badge exists for donor
(define-read-only (has-badge-tier (donor principal) (tier uint))
  (let ((current-level (get highest-tier (get-donor-badge-level donor))))
    (>= current-level tier)))
