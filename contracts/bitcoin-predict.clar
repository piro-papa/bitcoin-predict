;; Title: BitcoinPredict: Decentralized Prediction Markets

;; BitcoinPredict is a decentralized prediction market platform built on Stacks
;; that allows users to create and participate in BTC price prediction markets.
;; Users can stake STX on whether prices will go up or down within a specified
;; timeframe and earn rewards for correct predictions.

;;  Administrative Setup

(define-constant contract-owner tx-sender)

;; Error codes with descriptive names for better debugging and user feedback
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-prediction (err u102))
(define-constant err-market-closed (err u103))
(define-constant err-already-claimed (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-invalid-parameter (err u106))

;;  Platform Configuration

;; Oracle address that provides trusted price data for market resolution
(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Minimum stake required to participate in prediction markets (1 STX)
(define-data-var minimum-stake uint u1000000)

;; Platform fee percentage taken from winning payouts (2%)
(define-data-var fee-percentage uint u2)

;; Counter for unique market identification
(define-data-var market-counter uint u0)

;;  Data Structures 

;; Market data structure stores all relevant information about prediction markets
(define-map markets
  uint ;; market-id
  {
    start-price: uint, ;; Initial price when market opens
    end-price: uint, ;; Final price when market closes
    total-up-stake: uint, ;; Total STX staked on upward movement
    total-down-stake: uint, ;; Total STX staked on downward movement
    start-block: uint, ;; Block height when market opens
    end-block: uint, ;; Block height when market closes
    resolved: bool, ;; Whether market has been resolved
  }
)

;; User predictions tracks individual user stakes and claim status
(define-map user-predictions
  {
    market-id: uint,
    user: principal,
  }
  {
    prediction: (string-ascii 4),
    stake: uint,
    claimed: bool,
  }
)

;;  Market Creation Functions 

;; Creates a new prediction market with specified parameters
(define-public (create-market
    (start-price uint)
    (start-block uint)
    (end-block uint)
  )
  (let ((market-id (var-get market-counter)))
    ;; Only contract owner can create markets
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Validate market parameters
    (asserts! (> end-block start-block) err-invalid-parameter)
    (asserts! (> start-price u0) err-invalid-parameter)
    ;; Initialize market data
    (map-set markets market-id {
      start-price: start-price,
      end-price: u0,
      total-up-stake: u0,
      total-down-stake: u0,
      start-block: start-block,
      end-block: end-block,
      resolved: false,
    })
    ;; Increment market counter for next market
    (var-set market-counter (+ market-id u1))
    (ok market-id)
  )
)

;; User Prediction Functions 

;; Places a prediction stake in an active market
(define-public (make-prediction
    (market-id uint)
    (prediction (string-ascii 4))
    (stake uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) err-not-found))
      (current-block stacks-block-height)
    )
    ;; Validate market is open for predictions
    (asserts!
      (and
        (> current-block (get start-block market))
        (< current-block (get end-block market))
      )
      err-market-closed
    )
    ;; Validate prediction direction and stake amount
    (asserts! (or (is-eq prediction "up") (is-eq prediction "down"))
      err-invalid-prediction
    )
    (asserts! (> stake (var-get minimum-stake)) err-invalid-prediction)
    (asserts! (< stake (stx-get-balance tx-sender)) err-insufficient-balance)
    ;; Transfer stake to contract
    (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
    ;; Record user prediction
    (map-set user-predictions {
      market-id: market-id,
      user: tx-sender,
    } {
      prediction: prediction,
      stake: stake,
      claimed: false,
    })
    ;; Update market stake totals
    (map-set markets market-id
      (merge market {
        total-up-stake: (if (is-eq prediction "up")
          (+ (get total-up-stake market) stake)
          (get total-up-stake market)
        ),
        total-down-stake: (if (is-eq prediction "down")
          (+ (get total-down-stake market) stake)
          (get total-down-stake market)
        ),
      })
    )
    (ok true)
  )
)

;; Market Resolution Functions

;; Resolves a market with final price data
(define-public (resolve-market
    (market-id uint)
    (end-price uint)
  )
  (let ((market (unwrap! (map-get? markets market-id) err-not-found)))
    ;; Only authorized oracle can resolve markets
    (asserts! (is-eq tx-sender (var-get oracle-address)) err-owner-only)
    ;; Validate market is ready for resolution
    (asserts! (> stacks-block-height (get end-block market)) err-market-closed)
    (asserts! (not (get resolved market)) err-market-closed)
    (asserts! (> end-price u0) err-invalid-parameter)
    ;; Update market with final price and mark as resolved
    (map-set markets market-id
      (merge market {
        end-price: end-price,
        resolved: true,
      })
    )
    (ok true)
  )
)

;; Rewards Distribution Functions

;; Claims winnings for a resolved market
(define-public (claim-winnings (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) err-not-found))
      (prediction (unwrap!
        (map-get? user-predictions {
          market-id: market-id,
          user: tx-sender,
        })
        err-not-found
      ))
    )
    ;; Validate market is resolved and winnings not yet claimed
    (asserts! (get resolved market) err-market-closed)
    (asserts! (not (get claimed prediction)) err-already-claimed)
    (let (
        ;; Determine winning direction based on start vs end price
        (winning-prediction (if (> (get end-price market) (get start-price market))
          "up"
          "down"
        ))
        (total-stake (+ (get total-up-stake market) (get total-down-stake market)))
        (winning-stake (if (is-eq winning-prediction "up")
          (get total-up-stake market)
          (get total-down-stake market)
        ))
      )
      ;; Verify user made the correct prediction
      (asserts! (is-eq (get prediction prediction) winning-prediction)
        err-invalid-prediction
      )
      (let (
          ;; Calculate winnings proportional to stake ratio
          (winnings (/ (* (get stake prediction) total-stake) winning-stake))
          (fee (/ (* winnings (var-get fee-percentage)) u100))
          (payout (- winnings fee))
        )
        ;; Transfer winnings to user and fee to contract owner
        (try! (as-contract (stx-transfer? payout (as-contract tx-sender) tx-sender)))
        (try! (as-contract (stx-transfer? fee (as-contract tx-sender) contract-owner)))
        ;; Mark prediction as claimed
        (map-set user-predictions {
          market-id: market-id,
          user: tx-sender,
        }
          (merge prediction { claimed: true })
        )
        (ok payout)
      )
    )
  )
)

;; Read-Only Functions 

;; Returns market details
(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

;; Returns user prediction details
(define-read-only (get-user-prediction
    (market-id uint)
    (user principal)
  )
  (map-get? user-predictions {
    market-id: market-id,
    user: user,
  })
)

;; Returns current contract STX balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;;  Administrative Functions 

;; Updates minimum stake requirement
(define-public (set-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-minimum u0) err-invalid-parameter)
    (ok (var-set minimum-stake new-minimum))
  )
)

;; Updates platform fee percentage
(define-public (set-fee-percentage (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< new-fee u100) err-invalid-parameter)
    (ok (var-set fee-percentage new-fee))
  )
)

;; Withdraws accumulated fees to contract owner
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< amount (stx-get-balance (as-contract tx-sender)))
      err-insufficient-balance
    )
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) contract-owner)))
    (ok amount)
  )
)
