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