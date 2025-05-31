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