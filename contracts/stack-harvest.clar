;; ----------------------------------------------------------
;; Contract: stack-harvest.clar
;; A mega-contract combining staking, yield farming,
;; NFT rewards, DAO governance, treasury, and time-locks.
;; ----------------------------------------------------------

(define-trait i-nft
  ((mint (principal uint) (response uint uint))
   (transfer (uint principal principal) (response bool uint))
   (owner-of (uint) (response (optional principal) uint))))

;; -----------------------
;; Data Maps & Variables
;; -----------------------
(define-map stakes 
  {staker: principal} 
  { 
    amount: uint,
    lock-period: uint,
    start-height: uint,
    claimed: uint 
  })

(define-map rewards
  {staker: principal}
  {
    harvest-tokens: uint,
    nfts-earned: uint
  })

(define-map proposals
  {proposal-id: uint}
  {
    proposer: principal,
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    executed: bool
  })

(define-map treasury
  {id: uint}
  {
    balance: uint
  })

(define-data-var proposal-counter uint u0)
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u100) ;; reward rate per block per STX
(define-data-var nft-counter uint u0)

;; -----------------------
;; Helper Functions
;; -----------------------
;; constant for block height (will be replaced with proper block height checks later)
(define-constant BLOCK-HEIGHT u0)

(define-private (calculate-reward (amount uint) (lock uint) (blocks uint))
  (let ((multiplier (if (> lock u1440) u2 u1))) ;; longer lock = bonus multiplier
    (* amount (var-get reward-rate) multiplier blocks)))

;; -----------------------
;; Staking Functions
;; -----------------------
(define-public (stake (amount uint) (lock-period uint))
  (begin
    (asserts! (> amount u0) (err u1000))
    (asserts! (> lock-period u0) (err u1001))
    (let ((transfer-result (stx-transfer? amount tx-sender (as-contract tx-sender))))
      (if (is-ok transfer-result)
        (begin
          (map-set stakes {staker: tx-sender}
            {
              amount: amount,
              lock-period: lock-period,
              start-height: u0,
              claimed: u0
            })
          (var-set total-staked (+ (var-get total-staked) amount))
          (ok true))
        transfer-result))))

(define-public (unstake)
  (let ((stake-data (map-get? stakes {staker: tx-sender})))
    (match stake-data entry
      (let (
        (amount (get amount entry))
        (start-height (get start-height entry))
        (lock-period (get lock-period entry)))
        (if (>= (- u0 start-height) lock-period)
          (let ((transfer-result (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (if (is-ok transfer-result)
              (begin
                (map-delete stakes {staker: tx-sender})
                (ok true))
              transfer-result))
          (err u100)))
      (err u101))))

;; -----------------------
;; Rewards & NFTs
;; -----------------------
(define-public (claim-reward)
  (let ((stake-data (map-get? stakes {staker: tx-sender})))
    (match stake-data entry
      (let (
        (amount (get amount entry))
        (start-height (get start-height entry))
        (lock-period (get lock-period entry))
        (blocks (- u0 start-height)))
        (let ((reward (calculate-reward amount lock-period blocks)))
          (begin
            (map-set rewards {staker: tx-sender}
              {
                harvest-tokens: reward,
                nfts-earned: (+ (get nfts-earned (default-to {harvest-tokens: u0, nfts-earned: u0} (map-get? rewards {staker: tx-sender}))) u1)
              })
            (var-set nft-counter (+ (var-get nft-counter) u1))
            (ok reward))))
      (err u200))))

;; -----------------------
;; DAO Governance
;; -----------------------
(define-public (create-proposal (description (string-ascii 200)))
  (begin
    (asserts! (not (is-eq description "")) (err u1002))
    (let ((id (+ (var-get proposal-counter) u1)))
      (var-set proposal-counter id)
      (map-set proposals {proposal-id: id}
        {
          proposer: tx-sender,
          description: description,
          votes-for: u0,
          votes-against: u0,
          executed: false
        })
      (ok id))))

(define-public (vote-proposal (proposal-id uint) (support bool))
  (begin
    (asserts! (> proposal-id u0) (err u1003))
    (let ((proposal (map-get? proposals {proposal-id: proposal-id})))
      (match proposal prop
        (let ((executed (get executed prop)))
          (asserts! (not executed) (err u300))
          (ok (if support
            (map-set proposals {proposal-id: proposal-id}
              (merge prop {votes-for: (+ (get votes-for prop) u1)}))
            (map-set proposals {proposal-id: proposal-id}
              (merge prop {votes-against: (+ (get votes-against prop) u1)})))))
        (err u301)))))

(define-public (execute-proposal (proposal-id uint))
  (begin
    (asserts! (> proposal-id u0) (err u1003))
    (let ((proposal (map-get? proposals {proposal-id: proposal-id})))
      (match proposal prop
        (let (
          (executed (get executed prop))
          (votes-for (get votes-for prop))
          (votes-against (get votes-against prop)))
          (asserts! (not executed) (err u400))
          (asserts! (> votes-for votes-against) (err u400))
          (ok (map-set proposals {proposal-id: proposal-id} 
            (merge prop {executed: true}))))
        (err u401)))))

;; -----------------------
;; Treasury Management
;; -----------------------
(define-public (fund-treasury (amount uint))
  (let ((transfer-result (stx-transfer? amount tx-sender (as-contract tx-sender))))
    (if (is-ok transfer-result)
      (begin
        (map-set treasury {id: u1} {balance: (+ amount (get balance (default-to {balance: u0} (map-get? treasury {id: u1}))))})
        (ok true))
      transfer-result)))

(define-public (spend-treasury (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) (err u1004))
    (asserts! (not (is-eq recipient (as-contract tx-sender))) (err u1005))
    (let ((treasury-info (map-get? treasury {id: u1})))
      (match treasury-info tre
        (let ((balance (get balance tre)))
          (asserts! (>= balance amount) (err u500))
          (let ((transfer-result (stx-transfer? amount (as-contract tx-sender) recipient)))
            (if (is-ok transfer-result)
              (begin
                (map-set treasury {id: u1} {balance: (- balance amount)})
                (ok true))
              transfer-result)))
        (err u501)))))
