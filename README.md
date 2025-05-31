# 🧠 BitcoinPredict: Decentralized BTC Prediction Markets on Stacks

**BitcoinPredict** is a decentralized prediction market platform built on the [Stacks](https://www.stacks.co/) blockchain. It enables users to forecast Bitcoin (BTC) price movement, stake STX tokens on their predictions, and earn rewards based on outcome accuracy. The system uses a secure oracle for market resolution and ensures fairness through a transparent Clarity smart contract.

---

## 🚀 Features

* **Decentralized Prediction Markets:** Trustless and on-chain BTC price forecasting.
* **STX-Based Staking:** Users stake STX to participate and win.
* **Automated Rewards:** Winnings are distributed proportionally and securely.
* **Oracle Integration:** Markets are resolved using a trusted data source.
* **Fairness & Security:** Enforced through Clarity language and permission checks.
* **Admin Controls:** Configurable minimum stake, fees, and owner withdrawal.

---

## 📐 Architecture Overview

### Smart Contract Components

```plaintext
                    ┌──────────────────────────────────────┐
                    │         BitcoinPredict Contract      │
                    └──────────────────────────────────────┘
                                    │
     ┌──────────────────────────────┼─────────────────────────────────┐
     ▼                              ▼                                 ▼
[Markets Map]                [User Predictions Map]          [Config Variables]
market-id → {                {market-id, user} → {           - oracle-address
  start-price                  prediction, stake,            - minimum-stake
  end-price                   claimed }                      - fee-percentage
  start-block                                                - contract-owner
  end-block
  resolved
  total-up-stake
  total-down-stake
}
```

---

## 🧩 Key Components

### 1. **Markets**

Markets are created by the contract owner. Each market records:

* BTC start and end price (via oracle).
* Prediction window (start and end blocks).
* Total STX staked in each direction (`up` / `down`).
* Resolution status.

### 2. **User Predictions**

Each user can participate once per market, staking a minimum amount of STX. Predictions are recorded with:

* Chosen direction (`"up"` or `"down"`).
* Stake amount.
* Claim status.

### 3. **Oracle Resolution**

Only the designated oracle can finalize market outcomes by submitting the closing price. The outcome determines the winning direction.

### 4. **Reward Distribution**

When resolved, users with correct predictions:

* Receive STX rewards proportional to their stake.
* Pay a small fee (default 2%) which is collected by the contract owner.

---

## ⚙️ Public Functions

### Market Management

```clarity
(create-market start-price start-block end-block) ; Owner only
(resolve-market market-id end-price)              ; Oracle only
```

### User Actions

```clarity
(make-prediction market-id prediction stake)      ; "up"/"down"
(claim-winnings market-id)
```

### Admin Configurations

```clarity
(set-minimum-stake new-minimum)                   ; Owner only
(set-fee-percentage new-fee)                      ; Owner only
(withdraw-fees amount)                            ; Owner only
```

### Read-Only Functions

```clarity
(get-market market-id)
(get-user-prediction market-id user)
(get-contract-balance)
```

---

## 🛠 Example Workflow

1. **Owner** creates a market:

   ```clarity
   (create-market u30000 u1000 u2000)
   ```

2. **User** stakes 2 STX on `"up"`:

   ```clarity
   (make-prediction u0 "up" u2000000)
   ```

3. **Oracle** resolves market with final BTC price:

   ```clarity
   (resolve-market u0 u35000)
   ```

4. **User** claims winnings if prediction was correct:

   ```clarity
   (claim-winnings u0)
   ```

---

## 📜 Requirements

* [Clarity language](https://docs.stacks.co/docs/write-smart-contracts/clarity-language/)
* Deployed on Stacks blockchain
* Oracle setup to provide accurate BTC pricing data

---

## 🛡 Security Considerations

* **Only the oracle** can resolve markets.
* **Only the contract owner** can manage platform settings and withdraw fees.
* **No double staking** or double claiming is allowed.
* All funds are held in contract escrow and transparently tracked on-chain.
