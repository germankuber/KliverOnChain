# 🎮 Kliver OnChain Platform

<div align="center">

**Cairo smart contract suite for Starknet powering gamified token distribution, simulation-based rewards, and decentralized session marketplace with ZK proofs.**

[![Cairo](https://img.shields.io/badge/Cairo-2.8.2-orange?style=flat-square)](https://www.cairo-lang.org/)
[![Starknet](https://img.shields.io/badge/Starknet-0.8.0-blue?style=flat-square)](https://www.starknet.io/)
[![Tests](https://img.shields.io/badge/Tests-180%20Passing-success?style=flat-square)](#testing)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

---

## 📋 Table of Contents

- [System Architecture](#-system-architecture)
- [Smart Contracts](#-smart-contracts)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [API Reference](#-api-reference)

---

## 🏗️ System Architecture

### Contract Dependencies

```
┌─────────────┐       ┌──────────────┐       ┌──────────────┐
│  KliverNFT  │──────►│   Registry   │◄──────│TokensCore    │
│  (ERC721)   │       │              │       │  (ERC1155)   │
└─────────────┘       └──────┬───────┘       └──────────────┘
                             │
                             ▼
                      ┌──────────────┐
                      │  KliverPox   │
                      │  (PoX NFT)   │
                      └──────┬───────┘
                             │
                             ▼
                      ┌──────────────┐
                      │SessionsMarket│
                      │    place     │
                      └──────────────┘
```

### Deployment Order

```
1. KliverNFT           (Independent)
2. KliverTokensCore    (Independent)
3. Registry            (needs: NFT + TokensCore + Verifier)
   └─► Post-config:    TokensCore.set_registry_address(Registry)
4. KliverPox           (needs: Registry)
   └─► Post-config:    Registry.set_kliver_pox_address(KliverPox)
5. SessionsMarketplace (needs: KliverPox + Verifier + PaymentToken)
```

---

## 📦 Smart Contracts

### 1. **KliverNFT** - Identity & Access Control

ERC721 badge system for platform access.

**Constructor**:
```cairo
constructor(owner: ContractAddress, base_uri: ByteArray)
```

**Key Functions**:
```cairo
fn mint_to_user(to: ContractAddress, token_id: u256)  // Owner only
fn user_has_nft(user: ContractAddress) -> bool
fn burn_user_nft(token_id: u256)
```

---

### 2. **KliverTokensCore** - Multi-Token System (ERC1155)

Time-based token distribution with simulation-linked claims.

**Constructor**:
```cairo
constructor(owner: ContractAddress, base_uri: ByteArray)
```

**Post-Deployment** ⚠️:
```cairo
fn set_registry_address(registry_address: ContractAddress)  // Required!
```

**Core Functions**:
```cairo
fn create_token(release_hour: u64, release_amount: u256, special_release: u256) -> u256
fn register_simulation(simulation_id: felt252, token_id: u256, expiration: u64)
fn add_to_whitelist(token_id: u256, simulation_id: felt252, wallet: ContractAddress)
fn claim_tokens(token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256
```

**Features**:
- Daily token releases at configured hour
- Whitelist per simulation
- Accumulated days tracking
- Special release tokens

---

### 3. **Registry** - Content Validation

Cryptographic validation hub for all game content (characters, scenarios, simulations, sessions).

**Constructor**:
```cairo
constructor(
    owner: ContractAddress,
    nft_address: ContractAddress,
    token_simulation_address: ContractAddress,
    verifier_address: ContractAddress
)
```

**Post-Deployment** ⚠️:
```cairo
fn set_kliver_pox_address(pox_address: ContractAddress)  // Required!
```

**Registration Functions**:
```cairo
fn register_character(character_id: felt252, character_hash: felt252)
fn register_scenario(scenario_id: felt252, scenario_hash: felt252)
fn register_simulation(simulation_id: felt252, scenario_id: felt252,
                      character_id: felt252, simulation_hash: felt252,
                      author: ContractAddress)
fn register_session(metadata: SessionMetadata)  // Validates + mints in KliverPox
```

**Validation Functions**:
```cairo
fn verify_character(character_id: felt252, hash: felt252) -> VerificationResult
fn verify_simulation(simulation_id: felt252, hash: felt252) -> VerificationResult
fn batch_verify_simulations(simulations: Span<SimulationVerification>) -> Span<VerificationResult>
```

**Features**:
- SHA256 hash storage
- NFT-gated registration
- Immutable content records
- Batch verification support

---

### 4. **KliverPox** - Proof of Experience NFT

Session-based NFTs representing completed game sessions.

**Constructor**:
```cairo
constructor(registry_address: ContractAddress)
```

**Functions**:
```cairo
fn mint(metadata: SessionMetadata)  // Only Registry can call
fn get_metadata_by_token(token_id: u256) -> KliverPoxMetadata
fn get_metadata_by_session(session_id: felt252) -> KliverPoxMetadata
fn has_session(session_id: felt252) -> bool
```

**Metadata Structure**:
```cairo
struct KliverPoxMetadata {
    token_id: u256,
    session_id: felt252,
    root_hash: felt252,
    simulation_id: felt252,
    author: ContractAddress,
    score: u32
}
```

---

### 5. **SessionsMarketplace** - Session Trading Platform

Decentralized marketplace for buying/selling sessions with ERC20 payments and ZK proof verification.

**Constructor**:
```cairo
constructor(
    pox_address: ContractAddress,
    verifier_address: ContractAddress,
    payment_token_address: ContractAddress,
    purchase_timeout_seconds: u64
)
```

**Seller Functions**:
```cairo
fn create_listing(token_id: u256, price: u256)
fn close_listing(token_id: u256)
fn settle_purchase(token_id: u256, buyer: ContractAddress, challenge: u64, proof: Span<felt252>)
```

**Buyer Functions**:
```cairo
fn open_purchase(token_id: u256, challenge: u64, amount: u256)  // challenge: 10-digit number
fn refund_purchase(token_id: u256)  // After timeout or if listing closed
```

**View Functions**:
```cairo
fn get_listing(token_id: u256) -> Listing
fn get_order(token_id: u256, buyer: ContractAddress) -> Order
fn get_listing_history(token_id: u256) -> Span<u256>  // All listing IDs
```

**Features**:
- ERC20 escrow payments
- Challenge-response with ZK proofs (challenge: 1000000000-9999999999)
- Time-boxed purchases with automatic refunds
- Multi-buyer support per listing
- Complete listing history per token

**Flow**:
```
1. Seller: create_listing(token_id, price)
2. Buyer: open_purchase(token_id, challenge, price)
   └─► Funds locked in escrow
3. Seller: settle_purchase(token_id, buyer, challenge, proof)
   └─► ZK proof verified → funds released
4. Buyer (if timeout): refund_purchase(token_id)
   └─► Funds returned after timeout
```

---

## 🚀 Deployment

### Prerequisites

```bash
# Install Scarb (Cairo package manager)
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Install Starknet Foundry
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh

# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Install dependencies
scarb build
cd deploy && poetry install
```

### Configuration

Edit `deploy/deployment_config.yml`:

```yaml
environments:
  dev:
    name: "Development"
    network: "sepolia"
    account: "my-account"  # From snfoundry.toml
    rpc_url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8"
    build_target: "dev"

    contracts:
      registry:
        verifier_address: "0x..."  # Required
      sessions_marketplace:
        payment_token_address: "0x..."  # ERC20 token
        purchase_timeout_seconds: 86400  # 24 hours
```

### Deploy All Contracts

**Recommended approach** - deploys everything in correct order with automatic configuration:

```bash
cd deploy
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract all \
  --output-json
```

**Output**:
```json
{
  "nft": "0x05bd...",
  "kliver_tokens_core": "0x0170...",
  "registry": "0x00f7...",
  "kliver_pox": "0x069e...",
  "sessions_marketplace": "0x07e0..."
}
```

### Deploy Individual Contracts

```bash
# NFT
poetry run python kliver_deploy/deploy.py --environment dev --contract nft

# TokensCore
poetry run python kliver_deploy/deploy.py --environment dev --contract kliver_tokens_core

# Registry (requires NFT + TokensCore)
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract registry \
  --nft-address 0xNFT_ADDR \
  --token-simulation-address 0xTOKEN_ADDR

# KliverPox (requires Registry)
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract kliver_pox \
  --registry-address 0xREGISTRY_ADDR

# SessionsMarketplace (requires KliverPox)
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract sessions_marketplace \
  --pox-address 0xPOX_ADDR \
  --verifier-address 0xVERIFIER_ADDR \
  --payment-token-address 0xERC20_ADDR \
  --purchase-timeout 86400
```

⚠️ **Manual configuration required** when deploying individually:
```bash
# After deploying Registry and KliverPox
sncast invoke \
  --contract-address 0xREGISTRY_ADDR \
  --function set_kliver_pox_address \
  --calldata 0xPOX_ADDR

# After deploying Registry and TokensCore
sncast invoke \
  --contract-address 0xTOKENS_CORE_ADDR \
  --function set_registry_address \
  --calldata 0xREGISTRY_ADDR
```

### Deployment Options

| Flag | Description | Required |
|------|-------------|----------|
| `--environment` | Environment (local/dev/qa/prod) | ✅ Yes |
| `--contract` | Contract name or `all` | ✅ Yes |
| `--owner` | Owner address (defaults to deployer) | No |
| `--nft-address` | NFT contract address | For registry |
| `--token-simulation-address` | TokensCore address | For registry |
| `--registry-address` | Registry address | For kliver_pox |
| `--pox-address` | KliverPox address | For marketplace |
| `--verifier-address` | Verifier contract | Overrides config |
| `--payment-token-address` | ERC20 payment token | For marketplace |
| `--purchase-timeout` | Timeout in seconds | For marketplace |
| `--no-compile` | Skip compilation | No |
| `--output-json` | JSON output | No |

### Deployment Artifacts

Each deployment creates a JSON file:
```bash
deployment_sepolia_kliver_pox_1760363093.json
```

Contains:
```json
{
  "environment": "dev",
  "network": "sepolia",
  "contract_name": "KliverPox",
  "contract_address": "0x069eda4b...",
  "class_hash": "0x71522318...",
  "owner_address": "0x2af9427c...",
  "deployment_date": "2025-10-13 15:04:53 UTC",
  "explorer_links": {
    "contract": "https://sepolia.starkscan.co/contract/0x069eda4b...",
    "class": "https://sepolia.starkscan.co/class/0x71522318..."
  }
}
```

---

## 🧪 Testing

### Run Tests

```bash
# Build and run all tests
scarb build
scarb test

# Run specific test
scarb test test_claim_accumulated_days

# Run with verbose output
scarb test -v
```

### Test Coverage

**180 comprehensive tests** covering:

- ✅ **Token Economics** (110+ tests)
  - Token creation, claims, whitelist management
  - Time-based releases, accumulated days
  - Edge cases and validations

- ✅ **Content Validation** (40+ tests)
  - Registration (character, scenario, simulation, session)
  - Batch verification, hash validation
  - NFT-gated access control

- ✅ **NFT System** (15+ tests)
  - Minting, burning, access control

- ✅ **PoX System** (10+ tests)
  - Session minting, metadata storage
  - Registry integration

- ✅ **Marketplace** (10+ tests)
  - Listing management, escrow, refunds
  - Challenge validation, proof verification

---

## 📚 API Reference

### Quick Reference

**KliverNFT**:
```cairo
mint_to_user(to: ContractAddress, token_id: u256)
user_has_nft(user: ContractAddress) -> bool
burn_user_nft(token_id: u256)
```

**KliverTokensCore**:
```cairo
create_token(release_hour: u64, release_amount: u256, special: u256) -> u256
register_simulation(simulation_id: felt252, token_id: u256, expiration: u64)
add_to_whitelist(token_id: u256, simulation_id: felt252, wallet: ContractAddress)
claim_tokens(token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256
set_registry_address(registry: ContractAddress)  // Post-deployment
```

**Registry**:
```cairo
register_character(character_id: felt252, hash: felt252)
register_scenario(scenario_id: felt252, hash: felt252)
register_simulation(simulation_id: felt252, scenario_id: felt252,
                   character_id: felt252, hash: felt252, author: ContractAddress)
register_session(metadata: SessionMetadata)
verify_simulation(simulation_id: felt252, hash: felt252) -> VerificationResult
set_kliver_pox_address(pox: ContractAddress)  // Post-deployment
```

**KliverPox**:
```cairo
mint(metadata: SessionMetadata)  // Only Registry
get_metadata_by_session(session_id: felt252) -> KliverPoxMetadata
get_metadata_by_token(token_id: u256) -> KliverPoxMetadata
has_session(session_id: felt252) -> bool
```

**SessionsMarketplace**:
```cairo
// Seller
create_listing(token_id: u256, price: u256)
close_listing(token_id: u256)
settle_purchase(token_id: u256, buyer: ContractAddress, challenge: u64, proof: Span<felt252>)

// Buyer
open_purchase(token_id: u256, challenge: u64, amount: u256)  // challenge: 1000000000-9999999999
refund_purchase(token_id: u256)

// View
get_listing(token_id: u256) -> Listing
get_order(token_id: u256, buyer: ContractAddress) -> Order
get_order_status(token_id: u256, buyer: ContractAddress) -> OrderStatus
get_token_listing_count(token_id: u256) -> u256
```

**Data Structures**:
```cairo
struct SessionMetadata {
    session_id: felt252,
    root_hash: felt252,
    simulation_id: felt252,
    author: ContractAddress,
    score: u32
}

struct Listing {
    session_id: felt252,
    root: felt252,
    seller: ContractAddress,
    buyer: ContractAddress,
    status: ListingStatus,  // Open, Closed
    challenge: u64,
    price: u256
}

struct Order {
    session_id: felt252,
    buyer: ContractAddress,
    challenge: u64,
    amount: u256,
    status: OrderStatus  // Open, Settled, Refunded
}
```

For complete documentation, see inline comments in `src/interfaces/`.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

---

## 👥 Contact

- **Developer**: German Kuber
- **GitHub**: [@germankuber](https://github.com/germankuber)
- **Project**: [KliverOnChain](https://github.com/germankuber/KliverOnChain)

---

<div align="center">

**Built with ❤️ using Cairo and Starknet**

[Report Bug](https://github.com/germankuber/KliverOnChain/issues) • [Request Feature](https://github.com/germankuber/KliverOnChain/issues)

</div>
