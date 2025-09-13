;; Social Impact Leaderboard - Simplified Version
;; Public ranking system that showcases donor contributions with social badges
;; Gamifies charitable giving through competitive rankings and achievement unlocks

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u400))
(define-constant err-invalid-period (err u401))
(define-constant err-leaderboard-not-found (err u402))

;; Badge tiers
(define-constant BADGE_BRONZE u1)
(define-constant BADGE_SILVER u2)
(define-constant BADGE_GOLD u3)
(define-constant BADGE_PLATINUM u4)
(define-constant BADGE_DIAMOND u5)

;; Simple donor profiles
(define-map donor-profiles
    { donor: principal }
    {
        display-name: (string-ascii 50),
        total-impact-score: uint,
        current-season-score: uint,
        highest-badge: uint,
        last-activity: uint
    }
)

;; Season leaderboards
(define-map season-leaderboards
    { season: uint, rank: uint }
    {
        donor: principal,
        score: uint,
        badge-tier: uint
    }
)

(define-data-var current-season uint u1)
(define-data-var season-start-block uint u0)

;; Setup or update donor profile
(define-public (setup-donor-profile (display-name (string-ascii 50)))
    (begin
        (map-set donor-profiles
            { donor: tx-sender }
            {
                display-name: display-name,
                total-impact-score: u0,
                current-season-score: u0,
                highest-badge: u0,
                last-activity: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Record donation impact
(define-public (record-donation-impact 
    (donor principal)
    (donation-amount uint)
    (impact-multiplier uint)
)
    (let 
        (
            (profile (default-to 
                {
                    display-name: "Anonymous",
                    total-impact-score: u0,
                    current-season-score: u0,
                    highest-badge: u0,
                    last-activity: u0
                }
                (map-get? donor-profiles { donor: donor })
            ))
            (impact-score (/ (* donation-amount impact-multiplier) u100))
            (new-total-score (+ (get total-impact-score profile) impact-score))
            (new-badge (get-badge-tier new-total-score))
        )
        
        ;; Update donor profile
        (map-set donor-profiles
            { donor: donor }
            (merge profile {
                total-impact-score: new-total-score,
                current-season-score: (+ (get current-season-score profile) impact-score),
                highest-badge: (if (> new-badge (get highest-badge profile)) new-badge (get highest-badge profile)),
                last-activity: stacks-block-height
            })
        )
        
        ;; Update leaderboard position
        (map-set season-leaderboards
            { season: (var-get current-season), rank: u1 }
            {
                donor: donor,
                score: (+ (get current-season-score profile) impact-score),
                badge-tier: new-badge
            }
        )
        
        (ok impact-score)
    )
)

;; Get badge tier based on total score
(define-private (get-badge-tier (total-score uint))
    (if (>= total-score u1000000) BADGE_DIAMOND
        (if (>= total-score u500000) BADGE_PLATINUM
            (if (>= total-score u100000) BADGE_GOLD
                (if (>= total-score u50000) BADGE_SILVER
                    (if (>= total-score u10000) BADGE_BRONZE u0)
                )
            )
        )
    )
)

;; Start new season
(define-public (start-new-season)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (var-set current-season (+ (var-get current-season) u1))
        (var-set season-start-block stacks-block-height)
        (ok (var-get current-season))
    )
)

;; Read-only functions
(define-read-only (get-donor-profile (donor principal))
    (map-get? donor-profiles { donor: donor })
)

(define-read-only (get-leaderboard-entry (season uint) (rank uint))
    (map-get? season-leaderboards { season: season, rank: rank })
)

(define-read-only (get-current-season)
    (var-get current-season)
)

(define-read-only (get-badge-name (badge-tier uint))
    (if (is-eq badge-tier BADGE_DIAMOND) "Diamond Philanthropist"
        (if (is-eq badge-tier BADGE_PLATINUM) "Platinum Supporter" 
            (if (is-eq badge-tier BADGE_GOLD) "Gold Contributor"
                (if (is-eq badge-tier BADGE_SILVER) "Silver Donor"
                    (if (is-eq badge-tier BADGE_BRONZE) "Bronze Helper"
                        "Unranked"
                    )
                )
            )
        )
    )
)
