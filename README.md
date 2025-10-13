# 🎮 Kliver OnChain Platform

<div align="center">

**A comprehensive Cairo smart contract suite for Starknet powering gamified token distribution, simulation-based rewards, and decentralized content management for AI interactions.**

[![Cairo](https://img.shields.io/badge/Cairo-2.8.2-orange?style=flat-square)](https://www.cairo-lang.org/)
[![Starknet](https://img.shields.io/badge/Starknet-0.8.0-blue?style=flat-square)](https://www.starknet.io/)
[![Tests](https://img.shields.io/badge/Tests-167%20Passing-success?style=flat-square)](#testing)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

---

## 📋 Table of Contents

- [System Architecture](#-system-architecture)
- [Contract Overview](#-contract-overview)
- [Deployment Guide](#-deployment-guide)
- [Configuration](#-configuration)
- [Testing](#-testing)
- [API Reference](#-api-reference)

---

## 🏗️ System Architecture

The Kliver OnChain Platform consists of **5 interconnected smart contracts** that work together to provide a complete ecosystem for AI-powered gaming and token economics.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        KLIVER ECOSYSTEM                                 │
│                                                                         │
│  ┌──────────────┐         ┌──────────────┐         ┌───────────────┐  │
│  │   KliverNFT  │         │   Registry   │         │ TokenSimulation│ │
│  │   (ERC721)   │────────►│              │◄────────│   (ERC1155)    │ │
│  └──────────────┘ required└──────────────┘ validates└───────────────┘  │
│         │                        │                          │           │
│         │ validates              │ configures               │           │
│         │                        ▼                          │           │
│         │                 ┌──────────────┐                  │           │
│         └────────────────►│   KliverPox   │◄─────────────────┘           │
│                           │   (PoX NFT)  │                              │
│                           └──────────────┘                              │
│                                  │                                      │
│                                  │ uses                                 │
│                                  ▼                                      │
│                           ┌──────────────┐                              │
│                           │SessionMarket │                              │
│                           │   place      │                              │
│                           └──────────────┘                              │
└─────────────────────────────────────────────────────────────────────────┘
```

### Deployment Flow

The contracts must be deployed and configured in a specific order:

```
1. KliverNFT (Independent)
   └─► 2. TokenSimulation (Independent)
        └─► 3. Registry (needs NFT + TokenSimulation + Verifier)
             └─► 4. KliverPox (needs Registry)
                  │
                  ├─► Registry.set_kliver_pox_address(KliverPox)
                  ├─► TokenSimulation.set_registry_address(Registry)
                  │
                  └─► 5. SessionsMarketplace (needs KliverPox + Verifier + PaymentToken)
```

---

## 📦 Contract Overview

### 1. KliverNFT (Identity & Access)

**Purpose**: User identity and access control via ERC721 badges.

**Key Features**:
- One NFT per user (ERC721)
- Required to register content in Registry
- Used for access control across the platform

**Constructor**:
```cairo
constructor(owner: ContractAddress, base_uri: ByteArray)
```

**Main Functions**:
```cairo
fn mint_to_user(to: ContractAddress, token_id: u256)  // Owner only
fn user_has_nft(user: ContractAddress) -> bool
fn burn_user_nft(token_id: u256)  // Token owner only
```

---

### 2. TokenSimulation (ERC1155 Token Core)

**Purpose**: Multi-token system for game rewards and payments.

**Key Features**:
- Time-based daily token releases
- Simulation-linked token claims
- Whitelist per simulation
- Session/hint payment system

**Constructor**:
```cairo
constructor(owner: ContractAddress, base_uri: ByteArray)
```

**Post-Deployment Configuration**:
```cairo
fn set_registry_address(registry_address: ContractAddress)  // Required!
```

**Main Functions**:
```cairo
fn create_token(release_hour: u64, release_amount: u256, special_release: u256) -> u256
fn register_simulation(simulation_id: felt252, token_id: u256, expiration_timestamp: u64)
fn add_to_whitelist(token_id: u256, simulation_id: felt252, wallet: ContractAddress)
fn claim_tokens(token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256
```

---

### 3. Registry (Content Validation)

**Purpose**: Cryptographic validation of game content (characters, scenarios, simulations, sessions).

**Key Features**:
- Multi-registry system (Character, Scenario, Simulation, Session)
- SHA256 hash storage and verification
- NFT-gated registration
- Immutable content records

**Constructor**:
```cairo
constructor(
    owner: ContractAddress,
    nft_address: ContractAddress,
    token_simulation_address: ContractAddress,
    verifier_address: ContractAddress
)
```

**Post-Deployment Configuration**:
```cairo
fn set_kliver_pox_address(pox_address: ContractAddress)  // Required!
```

**Main Functions**:
```cairo
fn register_character(character_id: felt252, character_hash: felt252)
fn register_scenario(scenario_id: felt252, scenario_hash: felt252)
fn register_simulation(simulation_id: felt252, scenario_id: felt252, character_id: felt252, simulation_hash: felt252, author: ContractAddress)
fn register_session(session_id: felt252, simulation_id: felt252, session_hash: felt252, author: ContractAddress)
fn verify_simulation(simulation_id: felt252, simulation_hash: felt252) -> VerificationResult
```

---

### 4. KliverPox (Proof of Experience NFT)

**Purpose**: Session-based NFTs that represent completed game sessions.

**Key Features**:
- Mints NFT for each completed session
- Stores session metadata (root_hash, score, author)
- Only Registry can mint
- Used by SessionsMarketplace for trading

**Constructor**:
```cairo
constructor(registry_address: ContractAddress)
```

**Main Functions**:
```cairo
fn mint(metadata: SessionMetadata)  // Only Registry can call
fn get_metadata_by_token(token_id: u256) -> KliverPoxMetadata
fn get_metadata_by_session(session_id: felt252) -> KliverPoxMetadata
fn has_session(session_id: felt252) -> bool
fn get_registry_address() -> ContractAddress  // For validation
```

---

### 5. SessionsMarketplace (Session Trading)

**Purpose**: Marketplace for buying/selling completed game sessions with ERC20 payments and ZK proofs.

**Key Features**:
- ERC20 escrow payments
- Challenge-response system with ZK proofs
- Time-boxed purchases with refunds
- Per-buyer order tracking

**Constructor**:
```cairo
constructor(
    pox_address: ContractAddress,
    verifier_address: ContractAddress,
    payment_token_address: ContractAddress,
    purchase_timeout_seconds: u64
)
```

**Main Functions**:
```cairo
fn create_listing(token_id: u256, price: u256)  // Seller
fn open_purchase(listing_id: u256, challenge: felt252, amount: u256)  // Buyer
fn settle_purchase(listing_id: u256, buyer: ContractAddress, challenge_key: u64, proof: Span<felt252>)  // Seller
fn refund_purchase(listing_id: u256)  // Buyer (after timeout)
```

---

## 🚀 Deployment Guide

### Prerequisites

1. **Install Tools**:
   ```bash
   # Scarb (Cairo package manager)
   curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

   # Starknet Foundry (sncast)
   curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh

   # Python 3.8+ (for deployment scripts)
   python3 --version

   # Poetry (Python package manager)
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. **Install Dependencies**:
   ```bash
   # Cairo dependencies
   scarb build

   # Python dependencies
   cd deploy
   poetry install
   ```

3. **Configure Starknet Account**:
   ```bash
   # Create or import account (example for Sepolia)
   sncast account create --name my-account --url https://starknet-sepolia.public.blastapi.io/rpc/v0_8

   # Fund your account with Sepolia ETH from faucet:
   # https://starknet-faucet.vercel.app/
   ```

---

### Deployment Configuration

The deployment system uses `deploy/deployment_config.yml` to manage multiple environments (local, dev, qa, prod).

**File Structure**:
```yaml
environments:
  local:                    # Environment name
    name: "Local Development"
    network: "katana"       # Network type (katana, sepolia, mainnet)
    account: "katana-0"     # Account name from snfoundry.toml
    rpc_url: "http://127.0.0.1:5050"
    explorer: "http://127.0.0.1:5050"
    chain_id: "SN_DEVNET"
    build_target: "dev"     # Scarb build target (dev/release)

    contracts:
      nft:
        name: "KliverNFT"
        sierra_file: "target/dev/kliver_on_chain_KliverNFT.contract_class.json"
        base_uri: "http://localhost:3000/api/nft/metadata"

      kliver_tokens_core:
        name: "KliverTokensCore"
        sierra_file: "target/dev/kliver_on_chain_KliverTokensCore.contract_class.json"
        base_uri: "http://localhost:3000/api/metadata/"

      registry:
        name: "kliver_registry"
        sierra_file: "target/dev/kliver_on_chain_kliver_registry.contract_class.json"
        verifier_address: "0x04db2418fe71fd10e3127a3052e0781fe458b50490c7411ebc49bf60565df6d1"

      kliver_pox:
        name: "KliverPox"
        sierra_file: "target/dev/kliver_on_chain_KliverPox.contract_class.json"

      sessions_marketplace:
        name: "SessionsMarketplace"
        sierra_file: "target/dev/kliver_on_chain_SessionsMarketplace.contract_class.json"
        payment_token_address: "0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
        purchase_timeout_seconds: 600

    deployment_settings:
      wait_timeout: 60      # Max seconds to wait for tx confirmation
      retry_interval: 1     # Seconds between retries
      max_retries: 10       # Max retry attempts
```

**Configuration per Environment**:

| Field | Description | Required |
|-------|-------------|----------|
| `name` | Human-readable environment name | Yes |
| `network` | Network identifier (katana/sepolia/mainnet) | Yes |
| `account` | Account name from `snfoundry.toml` | Yes |
| `rpc_url` | StarkNet RPC endpoint | Yes |
| `build_target` | Scarb build target (dev/release) | Yes |
| `contracts.*.verifier_address` | Verifier contract address | Yes |
| `contracts.*.payment_token_address` | ERC20 payment token | Yes (for marketplace) |
| `contracts.*.purchase_timeout_seconds` | Purchase timeout | Yes (for marketplace) |

---

### Deployment Commands

The deployment system validates all contract dependencies before deploying and automatically configures post-deployment settings.

#### 1. Complete Deployment (Recommended ✅)

Deploy all contracts in the correct order with automatic configuration:

```bash
cd deploy
poetry run python -m kliver_deploy.deploy --environment <env> --contract all
```

**What happens**:
1. ✅ Compiles contracts
2. ✅ Deploys **KliverNFT**
3. ✅ Deploys **TokenSimulation**
4. ✅ Validates NFT and TokenSimulation contracts
5. ✅ Deploys **Registry** (with NFT + TokenSimulation + Verifier)
6. ✅ Validates Registry contract
7. ✅ Deploys **KliverPox** (with Registry)
8. ✅ **Automatically calls** `Registry.set_kliver_pox_address(KliverPox)`
9. ✅ **Automatically calls** `TokenSimulation.set_registry_address(Registry)`
10. ✅ Validates PoX contract
11. ✅ Deploys **SessionsMarketplace** (with PoX + Verifier + PaymentToken)
12. ✅ Verifies all configurations
13. ✅ Outputs JSON with all addresses

**Example**:
```bash
# Local (Katana)
poetry run python -m kliver_deploy.deploy --environment local --contract all --output-json

# Development (Sepolia)
poetry run python -m kliver_deploy.deploy --environment dev --contract all

# Production (Mainnet)
poetry run python -m kliver_deploy.deploy --environment prod --contract all
```

**Output**:
```json
{
  "Nft": "0x05bdcac9b28b3f774a46edf54a0ed89d896c41e7d6be3d341d20048b7e98e29f",
  "Registry": "0x00f78bfac9a9f9e9c8f763f5ca77397720fca3a04085ff0f5032c9bc8c8bae98",
  "TokenSimulation": "0x0170d5558b4306a7533258152d3563988f3d5a96329d16c161c36c4cc10a755d",
  "KliverPox": "0x069eda4b9668e2c442ae412febf4eb792cd851370dd63f771573e41fd9cdb072",
  "MarketPlace": "0x07e039aec176f2dfd935a52e86ebcc120ad122113a1dede8f7555f1f09b0737f"
}
```

---

#### 2. Individual Contract Deployment

Deploy contracts separately (useful for updates or testing):

```bash
# Deploy NFT
poetry run python -m kliver_deploy.deploy \
  --environment dev \
  --contract nft

# Deploy TokenSimulation
poetry run python -m kliver_deploy.deploy \
  --environment dev \
  --contract kliver_tokens_core

# Deploy Registry (requires NFT + TokenSimulation addresses)
poetry run python -m kliver_deploy.deploy \
  --environment dev \
  --contract registry \
  --nft-address 0xNFT_ADDRESS \
  --token-simulation-address 0xTOKEN_ADDRESS

# Deploy KliverPox (requires Registry)
poetry run python -m kliver_deploy.deploy \
  --environment dev \
  --contract kliver_pox \
  --registry-address 0xREGISTRY_ADDRESS

# Deploy SessionsMarketplace (requires PoX + Verifier + PaymentToken)
poetry run python -m kliver_deploy.deploy \
  --environment dev \
  --contract sessions_marketplace \
  --registry-address 0xREGISTRY_ADDRESS \
  --payment-token-address 0xERC20_ADDRESS \
  --purchase-timeout 600
```

**Note**: When deploying individually, you must manually call:
- `Registry.set_kliver_pox_address(pox_address)`
- `TokenSimulation.set_registry_address(registry_address)`

---

#### 3. Deployment Options

| Flag | Description | Required |
|------|-------------|----------|
| `--environment` | Environment name from config (local/dev/qa/prod) | Yes |
| `--contract` | Contract to deploy (nft/kliver_tokens_core/registry/kliver_pox/sessions_marketplace/all) | Yes |
| `--owner` | Owner address (defaults to deployer account) | No |
| `--nft-address` | NFT contract address (for registry) | Conditional |
| `--token-simulation-address` | TokenSimulation address (for registry) | Conditional |
| `--registry-address` | Registry address (for kliver_pox/sessions_marketplace) | Conditional |
| `--verifier-address` | Verifier contract address (overrides config) | No |
| `--payment-token-address` | ERC20 token address (for marketplace) | Conditional |
| `--purchase-timeout` | Purchase timeout in seconds (for marketplace) | Conditional |
| `--no-compile` | Skip compilation (use existing build) | No |
| `--output-json` | Output addresses in JSON format | No |
| `--verbose` | Enable verbose logging | No |

---

### Deployment Validation

The deployment system **automatically validates** all contracts before and after deployment:

#### Pre-Deployment Validation

Before deploying a contract, the system validates all dependencies:

```
🔍 Validating nft contract at 0x05bd...
✓ Nft contract validated successfully

🔍 Validating token_simulation contract at 0x0170...
✓ Token_Simulation contract validated successfully

🔍 Validating pox contract at 0x069e...
✓ Pox contract validated successfully
```

**Validation Methods**:

| Contract | Validation Function | Purpose |
|----------|-------------------|---------|
| NFT | `name()` | Validates ERC721 interface |
| TokenSimulation | `balance_of(0x0, 0x1)` | Validates ERC1155 interface |
| Registry | `get_owner()` | Validates Registry interface |
| PoX | `get_registry_address()` | Validates PoX has correct Registry |
| PaymentToken | `total_supply()` | Validates ERC20 interface (Cairo 1) or skips (Cairo 0) |
| Verifier | N/A | Skipped (interface unknown) |

**If validation fails**, the deployment stops and shows an error:
```
✗ Invalid pox contract address or contract not deployed
✗ Please verify the address and ensure the contract is deployed
```

#### Post-Deployment Verification

After deployment, the system verifies that configurations were set correctly:

```
🔗 Setting KliverPox address in Registry...
✓ Verified KliverPox in Registry: 0x069eda4b9668e2c442ae412febf4eb792cd851370dd63f771573e41fd9cdb072

🔗 Setting registry address on TokenSimulation contract...
✓ Registry address set successfully on TokenSimulation!
🔍 Validating registry address on TokenSimulation contract...
✓ Registry address validated successfully: 0xf78bfac9a9f9e9c8f763f5ca77397720fca3a04085ff0f5032c9bc8c8bae98

✓ Verified SessionsMarketplace uses PoX: 0x069eda4b9668e2c442ae412febf4eb792cd851370dd63f771573e41fd9cdb072
```

**Verification checks**:
- Registry has correct KliverPox address (`get_kliver_pox_address()`)
- TokenSimulation has correct Registry address (`get_registry_address()`)
- SessionsMarketplace has correct PoX address (`get_pox_address()`)

---

### Deployment Artifacts

Each deployment creates a JSON file with complete deployment information:

```bash
deployment_katana_nft_1760363058.json
deployment_katana_registry_1760363082.json
deployment_katana_kliver_pox_1760363093.json
# etc...
```

**Artifact Contents**:
```json
{
  "environment": "local",
  "network": "katana",
  "account": "katana-0",
  "rpc_url": "http://127.0.0.1:5050",
  "contract_name": "KliverPox",
  "contract_type": "kliver_pox",
  "class_hash": "0x715223182925c611d482479ba72e5f3f4f89b34d80c9b858a2a740721ab589d",
  "contract_address": "0x069eda4b9668e2c442ae412febf4eb792cd851370dd63f771573e41fd9cdb072",
  "owner_address": "0x2af9427c5a277474c079a1283c880ee8a6f0f8fbf73ce969c08d88befec1bba",
  "dependencies": [],
  "deployment_timestamp": 1760363093.123,
  "deployment_date": "2025-10-13 15:04:53 UTC",
  "registry_address": "0x00f78bfac9a9f9e9c8f763f5ca77397720fca3a04085ff0f5032c9bc8c8bae98",
  "explorer_links": {
    "contract": "http://127.0.0.1:5050/contract/0x069eda4b...",
    "class": "http://127.0.0.1:5050/class/0x71522318..."
  }
}
```

---

## 🧪 Testing

### Running Tests

```bash
# Build contracts first
scarb build

# Run all tests (167 tests)
snforge test

# Run specific test file
snforge test test_kliver_registry

# Run with verbose output
snforge test -v

# Run specific test
snforge test test_claim_accumulated_days
```

### Test Coverage

The project has **167 comprehensive tests** covering:

- ✅ **Token Economics** (110+ tests)
  - Token creation, simulation registration, whitelist management
  - Time-based claims, accumulated days, special releases
  - Payment system, batch operations, edge cases

- ✅ **Content Validation** (40+ tests)
  - Character/scenario/simulation registration
  - Batch verification, NFT-gated access
  - Hash validation, immutability

- ✅ **NFT System** (15+ tests)
  - Minting, burning, transfers
  - Access control, timestamp tracking

- ✅ **PoX System** (10+ tests)
  - Session minting, metadata storage
  - Registry integration

- ✅ **Marketplace** (20+ tests)
  - Listing creation, order management
  - Escrow, settlements, refunds
  - ZK proof verification

---

## 📚 API Reference

### Quick Reference

**KliverNFT**:
```cairo
fn mint_to_user(to: ContractAddress, token_id: u256)
fn user_has_nft(user: ContractAddress) -> bool
```

**TokenSimulation**:
```cairo
fn create_token(release_hour: u64, release_amount: u256, special_release: u256) -> u256
fn register_simulation(simulation_id: felt252, token_id: u256, expiration_timestamp: u64)
fn add_to_whitelist(token_id: u256, simulation_id: felt252, wallet: ContractAddress)
fn claim_tokens(token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256
fn set_registry_address(registry_address: ContractAddress)
```

**Registry**:
```cairo
fn register_simulation(simulation_id: felt252, scenario_id: felt252, character_id: felt252, simulation_hash: felt252, author: ContractAddress)
fn register_session(session_id: felt252, simulation_id: felt252, session_hash: felt252, author: ContractAddress)
fn verify_simulation(simulation_id: felt252, simulation_hash: felt252) -> VerificationResult
fn set_kliver_pox_address(pox_address: ContractAddress)
```

**KliverPox**:
```cairo
fn mint(metadata: SessionMetadata)  // Only Registry
fn get_metadata_by_session(session_id: felt252) -> KliverPoxMetadata
fn get_registry_address() -> ContractAddress
```

**SessionsMarketplace**:
```cairo
fn create_listing(token_id: u256, price: u256)
fn open_purchase(listing_id: u256, challenge: felt252, amount: u256)
fn settle_purchase(listing_id: u256, buyer: ContractAddress, challenge_key: u64, proof: Span<felt252>)
fn refund_purchase(listing_id: u256)
```

For complete API documentation, see inline code comments in `src/interfaces/`.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

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
