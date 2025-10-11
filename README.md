# 🎮 Kliver OnChain Platform

<div align="center">

**A comprehensive Cairo smart contract suite for Starknet powering gamified token distribution, simulation-based rewards, and decentralized content management for AI interactions.**

[![Cairo](https://img.shields.io/badge/Cairo-2.8.2-orange?style=flat-square)](https://www.cairo-lang.org/)
[![Starknet](https://img.shields.io/badge/Starknet-0.8.0-blue?style=flat-square)](https://www.starknet.io/)
[![Tests](https://img.shields.io/badge/Tests-167%20Passing-success?style=flat-square)](#running-tests)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

## 🌟 Overview

The Kliver OnChain Platform is a sophisticated blockchain infrastructure that combines **token economics**, **simulation-based mechanics**, and **content validation** into a unified ecosystem.

### System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         KLIVER ONCHAIN ECOSYSTEM                            │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                        USER INTERACTION LAYER                         │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                     │                                       │
│         ┌───────────────────────────┼───────────────────────────┐           │
│         │                           │                           │           │
│         ▼                           ▼                           ▼           │
│  ┌─────────────┐            ┌──────────────┐           ┌──────────────┐   │
│  │ Kliver 1155 │            │   Kliver     │           │  Kliver NFT  │   │
│  │  (ERC1155)  │◄───────────│   Registry   │◄──────────│   (ERC721)   │   │
│  └─────────────┘   validates└──────────────┘  requires └──────────────┘   │
│         │                           │                           │           │
│         │                           │                           │           │
└─────────┼───────────────────────────┼───────────────────────────┼───────────┘
          │                           │                           │
          ▼                           ▼                           ▼
    ┌──────────┐              ┌─────────────┐            ┌────────────┐
    │  TOKENS  │              │ VALIDATION  │            │   ACCESS   │
    ├──────────┤              ├─────────────┤            ├────────────┤
    │• Create  │              │• Characters │            │• User Auth │
    │• Claim   │              │• Scenarios  │            │• Badges    │
    │• Pay     │              │• Simulations│            │• Identity  │
    │• Transfer│              │• Sessions   │            │• Ownership │
    └──────────┘              └─────────────┘            └────────────┘
          │                           │                           │
          └───────────────────────────┴───────────────────────────┘
                                      │
                                      ▼
                           ┌──────────────────┐
                           │  GAME MECHANICS  │
                           ├──────────────────┤
                           │ • Simulations    │
                           │ • Whitelist      │
                           │ • Time-Based     │
                           │ • Rewards        │
                           │ • Payments       │
                           └──────────────────┘
```

### 🎯 The Three Pillars

#### 1. 🏆 Kliver 1155 (Token Economics Engine)
The **heart** of the ecosystem - manages all token operations and game mechanics.

```
Token Lifecycle:
┌──────────┐    ┌────────────┐    ┌─────────┐    ┌──────────┐
│  CREATE  │───►│ SIMULATION │───►│WHITELIST│───►│  CLAIM   │
│  TOKEN   │    │  REGISTER  │    │  ADD    │    │ REWARDS  │
└──────────┘    └────────────┘    └─────────┘    └──────────┘
     │                 │                │              │
     ▼                 ▼                ▼              ▼
 Configure       Set Expiration   Grant Access   Daily Drops
 Release Time    Link to Game     Per Wallet     + Special
```

**Key Features:**
- Multi-token system (ERC1155)
- Time-based daily releases
- Simulation-linked claims
- Whitelist per simulation
- Session/hint payments
- Batch operations

#### 2. 🏛️ Kliver Registry (Content Validation)
Ensures **integrity** of game content through cryptographic verification.

```
Content Flow:
┌──────────┐    ┌───────────┐    ┌──────────┐    ┌────────┐
│  CREATE  │───►│ REGISTER  │───►│  VERIFY  │───►│  LINK  │
│ CONTENT  │    │   HASH    │    │   HASH   │    │  GAME  │
└──────────┘    └───────────┘    └──────────┘    └────────┘
     │                 │                │              │
     ▼                 ▼                ▼              ▼
 Characters      SHA256 Hash      Immutable      Simulations
 Scenarios       Storage          Validation     Sessions
```

**Key Features:**
- Multi-registry system
- Cryptographic hashing
- NFT-gated registration
- Batch verification
- Immutable records

#### 3. 🎯 Kliver NFT (Identity & Access)
Provides **authentication** and access control across the platform.

```
Identity Flow:
┌──────────┐    ┌──────────┐    ┌───────────┐    ┌─────────┐
│   USER   │───►│   MINT   │───►│   OWNS    │───►│ ACCESS  │
│  LOGIN   │    │   NFT    │    │   BADGE   │    │REGISTRY │
└──────────┘    └──────────┘    └───────────┘    └─────────┘
     │                 │                │              │
     ▼                 ▼                ▼              ▼
 Platform        ERC721 Token    User Identity   Register
  Entry          1 per User      Verification    Content
```

**Key Features:**
- ERC721 standard
- User badges
- Access control
- Transfer mechanics
- Upgradeable

---

## ✨ Features

### 🏆 Kliver 1155 - Token Economics Engine

#### 🪙 Multi-Token System
- **ERC1155 Standard**: Full OpenZeppelin ERC1155Component implementation
- **Dynamic Token Creation**: Owner can create unlimited token types
- **Token Metadata**: Complete TokenInfo tracking:
  ```cairo
  struct TokenInfo {
      release_hour: u64,        // Hour of day for daily release (0-23)
      release_amount: u256,     // Amount released daily
      special_release: u256,    // One-time bonus on first claim
  }
  ```
- **Balance Management**: Standard ERC1155 balance_of, balance_of_batch operations
- **Token Transfers**: Full support for single and batch transfers
- **Supply Tracking**: Track total tokens in circulation per token_id

#### ⏰ Time-Based Release System
- **Daily Distribution**: Configure release hour (0-23 UTC) for automatic daily drops
- **Release Amount**: Set daily claimable amount per token type
- **Special Release**: One-time bonus added to first claim only
- **Accumulated Days**: Automatically calculates unclaimed days since last claim
- **Time Validation**: Smart contract calculates exact release times
- **Flexible Claiming**: Claim anytime after release hour - accumulated days stack up

**Example Flow:**
```
Token created with:
- release_hour: 14 (2 PM UTC)
- release_amount: 100 tokens
- special_release: 500 tokens

Day 1 at 3 PM: User claims → Gets 500 + 100 = 600 tokens
Day 3 at 5 PM: User claims → Gets 100 * 2 = 200 tokens (2 days accumulated)
Day 4 at 1 PM: User tries to claim → Fails (before 2 PM release hour)
Day 4 at 3 PM: User claims → Gets 100 tokens (1 day)
```

#### 🎮 Simulation-Based Claims
- **Simulation Registry**: Link tokens to game simulations with unique simulation_id
  ```cairo
  struct Simulation {
      creator: ContractAddress,
      token_id: u256,
      expiration_timestamp: u64,
  }
  ```
- **Multi-Simulation Support**: One token can have unlimited active simulations
- **Whitelist per Simulation**: Granular access control using three-key storage:
  ```cairo
  Map<(token_id, simulation_id, wallet), bool>
  ```
- **Claim Tracking**: Per-wallet, per-simulation history:
  ```cairo
  struct ClaimInfo {
      has_claimed_special: bool,    // First claim bonus taken?
      last_claim_timestamp: u64,    // When was last claim?
  }
  ```
- **Expiration Control**: Set and update simulation lifespans
- **Validation**: Automatic checks for:
  - Is wallet whitelisted for this simulation?
  - Has simulation expired?
  - Is it past release hour?
  - How many days to pay out?

**Example Workflow:**
```
1. Create Token #1 (daily: 100, special: 500)
2. Register Simulation "MISSION_ALPHA" for Token #1
3. Add wallets to "MISSION_ALPHA" whitelist
4. User completes mission → Eligible to claim
5. User claims → Contract checks whitelist → Pays out tokens
6. Simulation expires → Users can no longer claim
7. Owner extends expiration → Claims resume
```

#### 💰 Payment System
- **Session Payments**: Users pay tokens to enter game sessions
  ```cairo
  fn pay_for_session(
      token_id: u256,
      simulation_id: felt252,
      wallet: ContractAddress,
      session_id: felt252,
      amount: u256
  )
  ```
- **Hint Payments**: Users pay tokens to unlock in-game hints
  ```cairo
  fn pay_for_hint(
      token_id: u256,
      simulation_id: felt252,
      wallet: ContractAddress,
      hint_id: felt252,
      amount: u256
  )
  ```
- **Payment Tracking**: Immutable records of all payments
  ```cairo
  Map<(token_id, simulation_id, wallet, session_id), SessionPayment>
  Map<(token_id, simulation_id, wallet, hint_id), HintPayment>
  ```
- **Flexible Pricing**: Game can set different costs per session/hint
- **Balance Verification**: Automatic check that user has enough tokens
- **Whitelist Validation**: Only whitelisted users can make payments

#### 📦 Batch Operations

##### get_claimable_amounts_batch
Query claimable amounts for multiple simulation/wallet combinations in ONE call.

```cairo
fn get_claimable_amounts_batch(
    token_id: u256,
    simulation_ids: Array<felt252>,
    wallets: Array<ContractAddress>
) -> Array<ClaimableAmountResult>
```

**Returns:**
```cairo
struct ClaimableAmountResult {
    simulation_id: felt252,
    wallet: ContractAddress,
    amount: u256,  // 0 if not whitelisted, expired, or before release hour
}
```

**Use Case**: Check multiple users' eligibility across multiple simulations efficiently.

##### get_wallet_token_summary
Get EVERYTHING about a wallet's relationship with a token in ONE call.

```cairo
fn get_wallet_token_summary(
    token_id: u256,
    wallet: ContractAddress,
    simulation_ids: Array<felt252>
) -> WalletTokenSummary
```

**Returns:**
```cairo
struct WalletTokenSummary {
    token_id: u256,
    wallet: ContractAddress,
    current_balance: u256,              // Wallet's current token balance
    token_info: TokenInfo,              // Token config (release_hour, amounts)
    total_claimable: u256,              // Sum of all claimable amounts
    simulations_data: Array<SimulationClaimData>,  // Per-simulation breakdown
}

struct SimulationClaimData {
    simulation_id: felt252,
    claimable_amount: u256,  // 0 if not eligible
}
```

**Use Case**: Display user dashboard showing balance + all pending rewards in one query.

#### 🔧 Advanced Features

##### update_simulation_expiration
Extend or revive simulation expiration times (owner only).

```cairo
fn update_simulation_expiration(
    simulation_id: felt252,
    new_expiration_timestamp: u64
)
```

**Features:**
- Validates new timestamp is in the future
- Emits event with old and new expiration
- Allows reviving expired simulations
- Does not affect existing claim history
- Enables users to claim again if simulation was expired

**Use Case**: Extend a popular game simulation without losing user progress.

##### Dynamic Whitelist Management
Add or remove wallets from simulations anytime.

```cairo
fn add_to_whitelist(token_id: u256, simulation_id: felt252, wallet: ContractAddress)
fn remove_from_whitelist(token_id: u256, simulation_id: felt252, wallet: ContractAddress)
fn is_whitelisted(token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> bool
```

**Use Case**: Add players as they complete prerequisites, remove cheaters.

---

### 🏛️ Kliver Registry - Content Validation System

#### 📚 Multi-Registry Architecture

Five specialized registries working together:

1. **CharacterRegistry**: Manage AI character versions
   ```cairo
   fn register_character(character_id: felt252, character_hash: felt252)
   fn verify_character(character_id: felt252, character_hash: felt252) -> VerificationResult
   fn get_character_info(character_id: felt252) -> CharacterInfo
   ```

2. **ScenarioRegistry**: Track game scenario data
   ```cairo
   fn register_scenario(scenario_id: felt252, scenario_hash: felt252)
   fn verify_scenario(scenario_id: felt252, scenario_hash: felt252) -> VerificationResult
   ```

3. **SimulationRegistry**: Handle simulation metadata
   ```cairo
   fn register_simulation(simulation_id: felt252, scenario_id: felt252, character_id: felt252, simulation_hash: felt252, author: ContractAddress)
   fn verify_simulation(simulation_id: felt252, simulation_hash: felt252) -> VerificationResult
   fn simulation_exists(simulation_id: felt252) -> bool
   ```

4. **SessionRegistry**: Manage user game sessions
   ```cairo
   fn register_session(session_id: felt252, simulation_id: felt252, session_hash: felt252, author: ContractAddress)
   fn grant_access(session_id: felt252, user: ContractAddress)
   fn has_access(session_id: felt252, user: ContractAddress) -> bool
   ```

5. **OwnerRegistry**: Centralized ownership control
   ```cairo
   fn get_owner() -> ContractAddress
   fn get_nft_address() -> ContractAddress
   ```

#### ✅ Verification System

**Verification Results:**
```cairo
enum VerificationResult {
    Valid,      // Hash matches registered value
    Invalid,    // Hash exists but doesn't match
    NotFound,   // ID not registered
}
```

**Batch Verification** (gas optimized):
```cairo
fn batch_verify_characters(characters: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
fn batch_verify_scenarios(scenarios: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
fn batch_verify_simulations(simulations: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
```

**Use Case**: Verify integrity of a batch of game assets before loading a session.

#### 🎫 NFT-Gated Registration

**Concept**: Only users who own a Kliver NFT can register content.

```
Registration Flow:
┌──────────┐    ┌───────────┐    ┌──────────┐    ┌─────────┐
│   USER   │───►│ HAS NFT?  │───►│ REGISTER │───►│ STORE   │
│  WANTS   │    │  CHECK    │    │   HASH   │    │  HASH   │
│ REGISTER │    └───────────┘    └──────────┘    └─────────┘
└──────────┘           │                │              │
                       │                │              │
                  ┌────▼────┐      ┌───▼───┐     ┌────▼────┐
                  │   NO    │      │  YES  │     │ EMIT    │
                  │  FAIL   │      │  OK   │     │ EVENT   │
                  └─────────┘      └───────┘     └─────────┘
```

**Implementation:**
- Registry constructor takes NFT contract address
- Every register call validates NFT ownership
- Immutable NFT address (set at deployment)

---

### 🎯 Kliver NFT - Identity & Access System

#### 🎨 Core NFT Features

**ERC721 Implementation** (OpenZeppelin):
```cairo
// Standard ERC721
fn balance_of(account: ContractAddress) -> u256
fn owner_of(token_id: u256) -> ContractAddress
fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256)
fn approve(to: ContractAddress, token_id: u256)
fn get_approved(token_id: u256) -> ContractAddress
fn set_approval_for_all(operator: ContractAddress, approved: bool)
fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool

// Metadata
fn name() -> ByteArray
fn symbol() -> ByteArray
fn token_uri(token_id: u256) -> ByteArray

// Enumeration
fn total_supply() -> u256
```

**Kliver-Specific**:
```cairo
fn mint_to_user(to: ContractAddress, token_id: u256)  // Owner only
fn burn_user_nft(token_id: u256)  // Token owner only
fn get_user_token_id(user: ContractAddress) -> u256
fn user_has_nft(user: ContractAddress) -> bool
fn get_minted_at(token_id: u256) -> u64
```

#### 🔐 Access Control

**Ownable Pattern:**
- Only contract owner can mint NFTs
- Transfer ownership capability
- Owner-only administrative functions

**Burn Mechanics:**
- Users can burn their own NFTs
- Cannot burn someone else's NFT
- Permanently removes token from circulation

#### 🚀 Advanced Features

**Upgradeable Architecture:**
```cairo
fn upgrade(new_class_hash: ClassHash)  // Owner only
```

**Timestamp Tracking:**
- Every minted NFT records minting time
- Query historical minting data
- Audit trail for NFT creation

**User Queries:**
- Check if user has NFT (for gating)
- Get user's token ID quickly
- Query minting timestamp

---

### 🛒 Session Marketplace

Marketplace for registered sessions with two options depending on your needs.

```
Seller            Marketplace              Registry              Buyer
  |  publish(session, price) → validate(owner, root, sim) →
  |                         ←      ok (root, author)

Simple: purchase(session) → mark Sold, emit events

Avanzado:
  approve + open_order(listing, challenge, amount)
  submit_proof(listing, buyer, zk, [root, challenge]) → verify → release escrow → Sold
  refund_purchase(listing) si timeout
```

- Simple version (`SessionMarketplace`)
  - Constructor: `constructor(registry_address)`.
  - Publish: `publish_session(simulation_id, session_id, price)`.
    - Validates in the Registry that the session exists, the caller is the author, and the `simulation_id` matches.
    - Uses the Registry `root_hash`; the listing does not store score.
  - Purchase: `purchase_session(session_id)` marks `Sold` and emits events.

- Advanced version (`SessionsMarketplace`)
  - Constructor: `constructor(registry, verifier, payment_token, purchase_timeout_seconds)`.
  - Per-buyer order (ERC20 escrow + timeout):
    - `open_purchase(listing_id, challenge, amount)` moves `amount` into the contract escrow and records `opened_at`.
    - `settle_purchase(listing_id, buyer, challenge_key, proof, [root, challenge])` verifies and releases escrow to the seller → `Sold`.
    - `refund_purchase(listing_id)` returns escrow to the buyer if the timeout expires.
  - Order queries: `is_order_closed(session_id, buyer)`, `get_order_status(...)`, `get_order_info(...)`.

When to use which
- Simple: when you don’t need on-chain escrow or ZK proofs.
- Advanced: when you want atomic ERC20 payments with challenge/zk and time-boxed refunds.

Quick examples
- Simple
  ```cairo
  // Publish (validates author + root against Registry)
  session_marketplace.publish_session('SIM_A', 'SESSION_1', 50);
  // Purchase
  session_marketplace.purchase_session('SESSION_1');
  ```

- Avanzado
  ```cairo
  // Buyer approves and opens an order with a challenge
  erc20.approve(sessions_marketplace, 100);
  sessions_marketplace.open_purchase(1, 'CHALLENGE_X', 100);
  // Seller settles with zk-proof + challenge key
  sessions_marketplace.settle_purchase(1, buyer, 1234567890_u64, proof, array![root, 'CHALLENGE_X'].span());
  // If timeout expires, the buyer can refund
  sessions_marketplace.refund_purchase(1);
  ```

Code locations
- Simple contract: `src/session_marketplace.cairo`
- Advanced contract: `src/sessions_marketplace.cairo`
- Simple tests: `tests/test_session_marketplace.cairo`
- Advanced tests (orders): `tests/test_sessions_marketplace_orders.cairo`

Deployment checklist
- Simple
  - Deploy/get `Registry` and note its `address`.
  - Deploy `SessionMarketplace` with `constructor(registry_address)`.
  - Publish sessions with `publish_session(sim_id, session_id, price)`.
  - Consume with `purchase_session(session_id)` and listen to events.

- Advanced
  - Deploy/get `Registry` and `Verifier`.
  - Deploy/get the payment `ERC20` (or your protocol token).
  - Deploy `SessionsMarketplace` with `(registry, verifier, payment_token, purchase_timeout_seconds)`.
  - Seller: `create_listing(session_id, price)` (validates against Registry and stores root).
  - Buyer: `approve(marketplace, amount)` then `open_purchase(listing_id, challenge, amount)`.
  - Seller: `settle_purchase(listing_id, buyer, challenge_key, proof, [root, challenge])`.
  - Buyer: if expired, `refund_purchase(listing_id)`.

---

## 🔐 Security & Access Control

### Kliver 1155 Security

| Check | Implementation |
|-------|----------------|
| **Owner Control** | `_assert_only_owner()` on admin functions |
| **Time Validation** | Current timestamp must be >= release time |
| **Whitelist Check** | Must be whitelisted for simulation |
| **Expiration Check** | Simulation must not be expired |
| **Balance Check** | Must have sufficient tokens for payments |
| **Token Existence** | Token must exist (release_hour != max) |
| **Simulation Existence** | Simulation creator != zero address |
| **Input Validation** | All parameters validated for zero values |

### Kliver Registry Security

| Check | Implementation |
|-------|----------------|
| **NFT Ownership** | Validates NFT balance before registration |
| **Hash Validation** | Ensures non-zero hashes |
| **ID Validation** | Ensures non-zero IDs |
| **Duplicate Prevention** | Checks if already registered |
| **Owner Control** | Owner-only administrative functions |
| **Immutable Storage** | Hashes cannot be modified after registration |

### Kliver NFT Security

| Check | Implementation |
|-------|----------------|
| **Owner Control** | Only owner can mint |
| **Burn Authorization** | Only token owner can burn |
| **Zero Address Check** | Prevents minting to zero address |
| **Duplicate Prevention** | One NFT per user enforcement |
| **OpenZeppelin Security** | Battle-tested ERC721 implementation |

---

## 📚 API Reference

### Kliver 1155 API

#### Token Management (Owner Only)

```cairo
// Create a new token type
fn create_token(
    release_hour: u64,        // 0-23 (hour of day for daily release)
    release_amount: u256,     // Amount released daily
    special_release: u256     // One-time bonus on first claim
) -> u256  // Returns new token_id

// Get token configuration
fn get_token_info(token_id: u256) -> TokenInfo

// Calculate time until next release
fn time_until_release(token_id: u256) -> u64  // Returns seconds, or 0 if ready
```

#### Simulation Management (Owner Only)

```cairo
// Register a simulation for a token
fn register_simulation(
    simulation_id: felt252,
    token_id: u256,
    expiration_timestamp: u64
)

// Update simulation expiration
fn update_simulation_expiration(
    simulation_id: felt252,
    new_expiration_timestamp: u64
)

// Query simulation
fn get_simulation(simulation_id: felt252) -> Simulation
fn is_simulation_expired(simulation_id: felt252) -> bool
```

#### Whitelist Management (Owner Only)

```cairo
// Add wallet to simulation whitelist
fn add_to_whitelist(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress
)

// Remove wallet from simulation whitelist
fn remove_from_whitelist(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress
)

// Check whitelist status
fn is_whitelisted(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress
) -> bool
```

#### Claiming Rewards

```cairo
// Claim accumulated rewards
fn claim_tokens(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress
) -> u256  // Returns amount claimed

// Query claimable amount
fn get_claimable_amount(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress
) -> u256  // Returns 0 if not eligible

// Batch query claimable amounts
fn get_claimable_amounts_batch(
    token_id: u256,
    simulation_ids: Array<felt252>,
    wallets: Array<ContractAddress>
) -> Array<ClaimableAmountResult>

// Get comprehensive wallet summary
fn get_wallet_token_summary(
    token_id: u256,
    wallet: ContractAddress,
    simulation_ids: Array<felt252>
) -> WalletTokenSummary
```

#### Payment System

```cairo
// Pay tokens for session access
fn pay_for_session(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    session_id: felt252,
    amount: u256
)

// Pay tokens for hint
fn pay_for_hint(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    hint_id: felt252,
    amount: u256
)

// Check payment status
fn is_session_paid(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    session_id: felt252
) -> bool

fn is_hint_paid(
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    hint_id: felt252
) -> bool
```

#### Standard ERC1155 (via OpenZeppelin)

```cairo
fn balance_of(account: ContractAddress, token_id: u256) -> u256
fn balance_of_batch(accounts: Array<ContractAddress>, token_ids: Array<u256>) -> Array<u256>
fn safe_transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256, value: u256, data: Span<felt252>)
fn safe_batch_transfer_from(from: ContractAddress, to: ContractAddress, token_ids: Array<u256>, values: Array<u256>, data: Span<felt252>)
fn set_approval_for_all(operator: ContractAddress, approved: bool)
fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool
```

---

### Kliver Registry API

#### Character Registry

```cairo
fn register_character(character_id: felt252, character_hash: felt252)
fn verify_character(character_id: felt252, character_hash: felt252) -> VerificationResult
fn get_character_info(character_id: felt252) -> CharacterInfo
fn get_character_hash(character_id: felt252) -> felt252
fn batch_verify_characters(characters: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
```

#### Scenario Registry

```cairo
fn register_scenario(scenario_id: felt252, scenario_hash: felt252)
fn verify_scenario(scenario_id: felt252, scenario_hash: felt252) -> VerificationResult
fn get_scenario_info(scenario_id: felt252) -> ScenarioInfo
fn get_scenario_hash(scenario_id: felt252) -> felt252
fn batch_verify_scenarios(scenarios: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
```

#### Simulation Registry

```cairo
fn register_simulation(simulation_id: felt252, scenario_id: felt252, character_id: felt252, simulation_hash: felt252, author: ContractAddress)
fn verify_simulation(simulation_id: felt252, simulation_hash: felt252) -> VerificationResult
fn get_simulation_info(simulation_id: felt252) -> SimulationInfo
fn get_simulation_hash(simulation_id: felt252) -> felt252
fn simulation_exists(simulation_id: felt252) -> bool
fn batch_verify_simulations(simulations: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
```

#### Session Registry

```cairo
fn register_session(session_id: felt252, simulation_id: felt252, session_hash: felt252, author: ContractAddress)
fn grant_access(session_id: felt252, user: ContractAddress)
fn has_access(session_id: felt252, user: ContractAddress) -> bool
fn get_session_info(session_id: felt252) -> SessionInfo
```

---

### Kliver NFT API

#### Core Functions

```cairo
fn mint_to_user(to: ContractAddress, token_id: u256)  // Owner only
fn burn_user_nft(token_id: u256)  // Token owner only
fn total_supply() -> u256
fn get_user_token_id(user: ContractAddress) -> u256
fn user_has_nft(user: ContractAddress) -> bool
fn get_minted_at(token_id: u256) -> u64
```

#### Standard ERC721 (via OpenZeppelin)

```cairo
fn balance_of(account: ContractAddress) -> u256
fn owner_of(token_id: u256) -> ContractAddress
fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256)
fn safe_transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>)
fn approve(to: ContractAddress, token_id: u256)
fn get_approved(token_id: u256) -> ContractAddress
fn set_approval_for_all(operator: ContractAddress, approved: bool)
fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool
fn name() -> ByteArray
fn symbol() -> ByteArray
fn token_uri(token_id: u256) -> ByteArray
```

---

## 📊 Events

### Kliver 1155 Events

```cairo
// Token Management
struct TokenCreated {
    token_id: u256,
    release_hour: u64,
    release_amount: u256,
    special_release: u256,
}

// Simulation Management
struct SimulationRegistered {
    simulation_id: felt252,
    token_id: u256,
    expiration_timestamp: u64,
}

struct SimulationExpirationUpdated {
    simulation_id: felt252,
    old_expiration: u64,
    new_expiration: u64,
}

// Whitelist Management
struct AddedToWhitelist {
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
}

struct RemovedFromWhitelist {
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
}

// Claims
struct TokensClaimed {
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    amount: u256,
    days_claimed: u64,
    included_special: bool,
}

// Payments
struct SessionPaid {
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    session_id: felt252,
    amount: u256,
}

struct HintPaid {
    token_id: u256,
    simulation_id: felt252,
    wallet: ContractAddress,
    hint_id: felt252,
    amount: u256,
}
```

### Kliver Registry Events

```cairo
struct CharacterVersionRegistered {
    character_id: felt252,
    character_hash: felt252,
    registered_by: ContractAddress,
}

struct ScenarioVersionRegistered {
    scenario_version_id: felt252,
    scenario_version_hash: felt252,
    registered_by: ContractAddress,
}

struct SimulationVersionRegistered {
    simulation_version_id: felt252,
    simulation_version_hash: felt252,
    registered_by: ContractAddress,
}

struct SessionRegistered {
    session_id: felt252,
    simulation_id: felt252,
    author: ContractAddress,
}

struct AccessGranted {
    session_id: felt252,
    user: ContractAddress,
}
```

### Kliver NFT Events

```cairo
struct UserNFTMinted {
    token_id: u256,
    to: ContractAddress,
    timestamp: u64,
}

struct UserNFTBurned {
    token_id: u256,
    from: ContractAddress,
}

// Standard ERC721 Events (via OpenZeppelin)
struct Transfer {
    from: ContractAddress,
    to: ContractAddress,
    token_id: u256,
}

struct Approval {
    owner: ContractAddress,
    approved: ContractAddress,
    token_id: u256,
}

struct ApprovalForAll {
    owner: ContractAddress,
    operator: ContractAddress,
    approved: bool,
}
```

---

## 🚀 Deployment Guide

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) (Testing framework)
- Cairo 2.8.2+
- Python 3.8+ (for deployment scripts)
- Starknet account configured

### Environment Setup

1. Clone the repository:
```bash
git clone https://github.com/germankuber/KliverOnChain.git
cd KliverOnChain
```

2. Install Cairo dependencies:
```bash
scarb build
```

3. Install Python dependencies:
```bash
pip install starknet-py pyyaml
```

4. Configure environments in `deployment_config.yml`:
```yaml
environments:
  dev:
    name: "Development"
    network: "sepolia"
    account: "kliver-dev"
    rpc_url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8"
    
  qa:
    name: "QA"
    network: "sepolia"
    account: "kliver-qa"
    rpc_url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8"
    
  prod:
    name: "Production"
    network: "mainnet"
    account: "kliver-prod"
    rpc_url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_8"
```

### Deployment Options

#### Option 1: Complete Deployment (Recommended) ✅

Deploy all three contracts together:

```bash
python deploy_contract.py --environment dev --contract all
```

**What happens:**
1. ✅ Deploys Kliver NFT
2. ✅ Deploys Kliver Registry (linked to NFT)
3. ✅ Deploys Kliver 1155
4. ✅ Saves deployment info

#### Option 2: Individual Deployments

Deploy contracts separately:

```bash
# Deploy NFT first
python deploy_contract.py --environment dev --contract nft --owner 0x123...

# Deploy Registry (requires NFT address)
python deploy_contract.py --environment dev --contract registry --nft-address 0xNFT_ADDR

# Deploy Kliver Tokens Core
python deploy_contract.py --environment dev --contract kliver_tokens_core --owner 0x123...
```

### Deployment Examples

#### Development Environment

```bash
# Quick deploy everything
python deploy_contract.py --environment dev --contract all

# Or step by step
python deploy_contract.py --environment dev --contract nft
python deploy_contract.py --environment dev --contract registry --nft-address 0xABC...
python deploy_contract.py --environment dev --contract kliver_tokens_core
```

#### Production Environment

```bash
# Always deploy everything together in production
python deploy_contract.py --environment prod --contract all --owner 0xPROD_OWNER
```

### Post-Deployment

After deployment, you'll receive:

```
======================================================================
🎉 DEPLOYMENT SUMMARY
======================================================================

1. KLIVERNFT
   Address:    0x123...
   Explorer:   https://sepolia.starkscan.co/contract/0x123...

2. KLIVER_REGISTRY
   Address:    0x456...
   Explorer:   https://sepolia.starkscan.co/contract/0x456...
   NFT Link:   0x123...

3. KLIVER_1155
   Address:    0x789...
   Explorer:   https://sepolia.starkscan.co/contract/0x789...

Network: SEPOLIA | Owner: 0xOWNER...
======================================================================
```

---

## 🧪 Testing

### Running Tests

```bash
# Build contracts
scarb build

# Run all tests (167 tests)
snforge test

# Run specific test file
snforge test test_kliver_nft_1155

# Run tests matching pattern
snforge test update_simulation_expiration

# Verbose output
snforge test -v
```

### Test Coverage

The project has **167 comprehensive tests** covering:

#### Kliver 1155 Tests (110+ tests)
- ✅ Token creation and configuration
- ✅ Simulation registration and expiration
- ✅ Whitelist add/remove operations
- ✅ Time-based release calculations
- ✅ Claiming mechanics (first claim, accumulated days, special release)
- ✅ Payment system (sessions and hints)
- ✅ Batch operations
- ✅ Wallet summary queries
- ✅ Expiration updates
- ✅ Edge cases and error conditions

#### Kliver Registry Tests (40+ tests)
- ✅ Character registration and verification
- ✅ Scenario registration and verification
- ✅ Simulation registration and verification
- ✅ Session registration and access control
- ✅ Batch verification operations
- ✅ NFT-gated registration validation
- ✅ Error handling

#### Kliver NFT Tests (15+ tests)
- ✅ NFT minting
- ✅ Burning mechanics
- ✅ Transfer operations
- ✅ Ownership queries
- ✅ Access control
- ✅ Timestamp tracking

### Test Example

```cairo
#[test]
fn test_claim_accumulated_days() {
    let (contract, token_id, simulation_id, wallet) = setup();
    
    // First claim
    contract.claim_tokens(token_id, simulation_id, wallet);
    
    // Forward time 3 days
    start_cheat_block_timestamp_global(get_block_timestamp() + 86400 * 3);
    
    // Second claim should give 3 days worth
    let amount = contract.claim_tokens(token_id, simulation_id, wallet);
    assert_eq!(amount, release_amount * 3);
}
```

---

## 💡 Usage Examples

### Example 1: Complete Token Lifecycle

```cairo
// 1. Create token (owner)
let token_id = kliver_tokens_core.create_token(
    14,      // Release at 2 PM UTC
    100,     // 100 tokens daily
    500      // 500 token first-time bonus
);

// 2. Register simulation (owner)
kliver_tokens_core.register_simulation(
    'MISSION_ALPHA',
    token_id,
    1735689600  // Expires Jan 1, 2025
);

// 3. Add users to whitelist (owner)
kliver_tokens_core.add_to_whitelist(token_id, 'MISSION_ALPHA', user1);
kliver_tokens_core.add_to_whitelist(token_id, 'MISSION_ALPHA', user2);

// 4. User completes mission and claims (user)
let amount = kliver_tokens_core.claim_tokens(token_id, 'MISSION_ALPHA', user1);
// amount = 600 (500 special + 100 daily)

// 5. User waits 3 days and claims again
// amount = 300 (100 daily * 3 days)

// 6. User pays for hint (user)
kliver_tokens_core.pay_for_hint(token_id, 'MISSION_ALPHA', user1, 'HINT_1', 50);

// 7. Simulation expires, owner extends it (owner)
kliver_tokens_core.update_simulation_expiration('MISSION_ALPHA', 1767225600);
```

### Example 2: Batch Queries

```cairo
// Query multiple users across multiple simulations
let simulations = array!['SIM_1', 'SIM_2', 'SIM_3'];
let wallets = array![user1, user2, user3];

let results = kliver_tokens_core.get_claimable_amounts_batch(
    token_id,
    simulations,
    wallets
);

// Get comprehensive wallet summary
let summary = kliver_tokens_core.get_wallet_token_summary(
    token_id,
    user1,
    array!['SIM_1', 'SIM_2']
);
// summary contains: balance, token_info, total_claimable, per-simulation data
```

### Example 3: Content Validation

```cairo
// 1. User mints NFT (prerequisite)
kliver_nft.mint_to_user(author, token_id);

// 2. Author registers character (requires NFT)
kliver_registry.register_character('CHAR_V1', hash('character_data'));

// 3. Author registers scenario
kliver_registry.register_scenario('SCENARIO_V1', hash('scenario_data'));

// 4. Author registers simulation
kliver_registry.register_simulation(
    'SIM_V1',
    'SCENARIO_V1',
    'CHAR_V1',
    hash('simulation_data'),
    author
);

// 5. Game verifies content before loading
let result = kliver_registry.verify_simulation('SIM_V1', hash('simulation_data'));
assert(result == VerificationResult::Valid);

// 6. Batch verify multiple assets
let assets = array![
    ('CHAR_V1', hash('character_data')),
    ('CHAR_V2', hash('character_data_2'))
];
let results = kliver_registry.batch_verify_characters(assets);
```

---

## 🏗️ Architecture Deep Dive

### Kliver 1155 Storage Architecture

```
Token Storage:
├─ tokens: Map<u256, TokenInfo>              // Token configurations
├─ simulations: Map<felt252, Simulation>     // Simulation metadata
├─ whitelist: Map<(u256, felt252, ContractAddress), bool>  // Access control
├─ claims: Map<(u256, felt252, ContractAddress), ClaimInfo>  // Claim history
├─ session_payments: Map<(u256, felt252, ContractAddress, felt252), SessionPayment>
├─ hint_payments: Map<(u256, felt252, ContractAddress, felt252), HintPayment>
└─ next_token_id: u256                       // Token ID counter
```

**Key Design Decisions:**

1. **Three-Key Whitelist**: `(token_id, simulation_id, wallet)` enables:
   - One token to have multiple simulations
   - Each simulation to have independent whitelist
   - Same wallet in different simulations of same token

2. **Claim Info Per Simulation**: Tracks progress separately for each simulation
   - Prevents double-claiming special release across simulations
   - Allows independent claim timelines

3. **Flexible Payment Tracking**: Four-key maps enable:
   - Track payments per token, simulation, wallet, AND specific session/hint
   - Prevent duplicate payments
   - Immutable payment history

### Time Calculation Logic

```cairo
fn calculate_claimable_amount(
    token_info: TokenInfo,
    claim_info: ClaimInfo,
    current_time: u64
) -> (u256, u64, bool) {
    // 1. Check if we've reached release hour today
    let today_release_time = get_release_time_for_day(current_time, token_info.release_hour);
    
    if current_time < today_release_time {
        // Before release hour today, use yesterday as reference
        today_release_time -= 86400;
    }
    
    // 2. Calculate days elapsed since last claim
    let last_claim_release = get_release_time_for_day(claim_info.last_claim_timestamp, token_info.release_hour);
    let days_elapsed = (today_release_time - last_claim_release) / 86400;
    
    // 3. Calculate amount
    let mut amount = token_info.release_amount * days_elapsed;
    let mut include_special = false;
    
    if !claim_info.has_claimed_special {
        amount += token_info.special_release;
        include_special = true;
    }
    
    (amount, days_elapsed, include_special)
}
```

### Event-Driven Architecture

All state changes emit events for:
- Off-chain indexing
- UI real-time updates
- Analytics and monitoring
- Audit trails

```
Smart Contract Event → Starknet Event Log → Indexer → Database → Frontend
```

---

## 🔧 Gas Optimization

### Batch Operations
- **Single call** instead of N calls
- Reduced L1 data gas costs
- Loop optimization in Cairo

### Storage Layout
- Efficient Map usage
- Minimal state reads
- Tuple keys for nested mappings

### Time Calculations
- Pre-computed release times
- Cached timestamp operations
- Integer arithmetic only

---

## 📖 Best Practices

### For Token Creators

1. **Set Realistic Release Hours**: Consider user timezones
2. **Test Expirations**: Give enough time for users to participate
3. **Monitor Whitelist**: Add/remove users as needed
4. **Extend Simulations**: Use `update_simulation_expiration` for popular games
5. **Balance Token Supply**: Consider daily release * expected participants * duration

### For Game Developers

1. **Verify Content**: Always use `verify_simulation` before loading
2. **Batch Queries**: Use batch operations to reduce RPC calls
3. **Check Eligibility**: Use `get_wallet_token_summary` for user dashboards
4. **Handle Edge Cases**: Check for expired simulations, non-whitelisted users
5. **Event Subscriptions**: Listen to events for real-time updates

### For Users

1. **Claim Regularly**: Don't let days accumulate unnecessarily
2. **Check Eligibility**: Use read functions before attempting claims
3. **Watch Expirations**: Simulations have deadlines
4. **Manage Balances**: Ensure enough tokens for session/hint payments

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`snforge test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- ✅ Write comprehensive tests for new features
- ✅ Follow Cairo naming conventions
- ✅ Document all public functions
- ✅ Maintain gas efficiency
- ✅ Ensure backward compatibility
- ✅ Update README with new features

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Contact

- **Developer**: German Kuber
- **GitHub**: [@germankuber](https://github.com/germankuber)
- **Project**: [KliverOnChain](https://github.com/germankuber/KliverOnChain)

---

## 🙏 Acknowledgments

- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts) - ERC721 & ERC1155 implementations
- [Starknet Foundation](https://www.starknet.io/) - L2 infrastructure
- [Cairo Language](https://www.cairo-lang.org/) - Smart contract language
- Kliver Platform Team - Product requirements and testing

---

<div align="center">

**Built with ❤️ using Cairo and Starknet**

[Documentation](#) • [Report Bug](https://github.com/germankuber/KliverOnChain/issues) • [Request Feature](https://github.com/germankuber/KliverOnChain/issues)

</div>
