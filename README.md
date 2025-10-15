# Kliver OnChain

**Cairo smart contract suite for Starknet powering the Kliver platform: gamified token distribution, simulation-based rewards, and decentralized session marketplace.**

[![Cairo](https://img.shields.io/badge/Cairo-2.8.2-orange?style=flat-square)](https://www.cairo-lang.org/)
[![Starknet](https://img.shields.io/badge/Starknet-0.8.0-blue?style=flat-square)](https://www.starknet.io/)
[![Tests](https://img.shields.io/badge/Tests-180%20Passing-success?style=flat-square)](#testing)

---

## Table of Contents

- [General Architecture](#general-architecture)
- [Main Contracts](#main-contracts)
- [Deployment](#deployment)
- [Testing](#testing)

---

## General Architecture

The Kliver OnChain system consists of 5 interconnected smart contracts that manage identity, tokens, content validation, proof of experience, and a decentralized marketplace.

### Dependency Diagram

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
3. Registry            (Requires: NFT + TokensCore + Verifier*)
   └─► Configuration:  TokensCore.set_registry_address(Registry)
4. KliverPox           (Requires: Registry)
   └─► Configuration:  Registry.set_kliver_pox_address(KliverPox)
5. SessionsMarketplace (Requires: KliverPox + Registry + PaymentToken*)

* = External dependency (deployed separately)
```

---

## Main Contracts

### 1. KliverNFT - Identity System

**Purpose:** ERC721 badge system for platform access control.

**Features:**
- One NFT per user (non-transferable/soulbound)
- Owner-controlled minting
- Permission validation for registrations

**Main functions:**
- `mint_to_user(to, token_id)` - Mint NFT to user
- `user_has_nft(user) -> bool` - Verify access
- `burn_user_nft(token_id)` - Burn user's NFT

---

### 2. KliverTokensCore - Multi-Token System

**Purpose:** ERC1155 token distribution system with time-based releases linked to simulations.

**Features:**
- Daily token releases at configurable hours
- Claims linked to specific simulations
- Whitelist system per simulation
- Special one-time release tokens
- Accumulated days tracking
- Session and hint payments

**Main functions:**
- `create_token(release_hour, release_amount, special_release) -> u256` - Create token type
- `register_simulation(simulation_id, token_id, expiration)` - Link token to simulation
- `add_to_whitelist(token_id, simulation_id, wallet)` - Add to whitelist
- `claim(token_id, simulation_id)` - Claim daily tokens
- `pay_for_session(simulation_id, session_id, amount)` - Pay with tokens

**Post-deployment:**
- Requires configuration: `set_registry_address(registry_address)`

---

### 3. Registry - Validation Hub

**Purpose:** Cryptographic validation center for all game content (characters, scenarios, simulations, sessions).

**Features:**
- SHA256 hash storage
- NFT-protected registration
- Batch verification support
- Component-based modular architecture
- Immutable content validation

**Main functions:**
- `register_character(character_id, hash)` - Register character
- `register_scenario(scenario_id, hash)` - Register scenario
- `register_simulation(simulation_id, scenario_id, character_id, hash, author)` - Register simulation
- `register_session(metadata)` - Register session and mint in KliverPox
- `verify_simulation(simulation_id, hash) -> VerificationResult` - Verify simulation
- `verify_simulations(simulations) -> Array<Result>` - Batch verification

**Post-deployment:**
- Requires configuration: `set_kliver_pox_address(pox_address)`

---

### 4. KliverPox - Proof of eXecution NFT

**Purpose:** NFTs representing completed game sessions (Proof of eXecution).

**Features:**
- Session metadata storage
- Indexing by token and session_id
- Root hash registry for verification
- Scoring system
- Mintable only by Registry

**Main functions:**
- `mint(metadata)` - Mint PoX NFT (Registry only)
- `get_metadata_by_token(token_id) -> KliverPoxMetadata` - Get metadata by token
- `get_metadata_by_session(session_id) -> KliverPoxMetadata` - Get metadata by session
- `has_session(session_id) -> bool` - Check if session exists

**Metadata:**
```cairo
struct KliverPoxMetadata {
    token_id: u256,
    session_id: felt252,
    root_hash: felt252,           // ZK root for verification
    simulation_id: felt252,
    author: ContractAddress,
    score: u32
}
```

---

### 5. SessionsMarketplace - P2P Trading

**Purpose:** Decentralized marketplace for buying/selling sessions with ZK proof verification.

**Features:**
- Escrow payments with ERC20 tokens
- Challenge-response system with ZK proofs
- Orders with automatic timeout
- Multiple buyers per listing
- Complete listing history
- Automatic refunds after timeout

**Seller functions:**
- `create_listing(token_id, price)` - Create listing
- `close_listing(token_id)` - Close listing
- `settle_purchase(token_id, buyer, challenge, proof)` - Settle sale with proof

**Buyer functions:**
- `open_purchase(token_id, challenge, amount)` - Open order with challenge (10-digit number)
- `refund_purchase(token_id)` - Recover funds after timeout

**Query functions:**
- `get_listing(token_id) -> Listing` - Get active listing
- `get_order(token_id, buyer) -> Order` - Get order
- `get_listing_history(token_id) -> Span<u256>` - Listing history

**Purchase flow:**
```
1. Seller: create_listing(token_id, price)
2. Buyer: open_purchase(token_id, challenge, price)
   └─► Funds locked in escrow
3. Seller: settle_purchase(token_id, buyer, challenge, proof)
   └─► Proof verified → funds released
4. Buyer (if timeout): refund_purchase(token_id)
   └─► Funds returned
```

---

## Deployment

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

### Complete Deployment (Recommended)

Deploys all contracts in the correct order with automatic configuration:

```bash
cd deploy
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract all \
  --output-json
```

**Output:**
```json
{
  "Nft": "0x052b1adc747e150870ef1d0de8b14d15ba9209814f90a3f99d032d59f46ff939",
  "TokenSimulation": "0x043ea8c61ad673ccb6662bec74a88e19cb0f6b782a0a87a80a2868cf2752cc18",
  "Registry": "0x0494de6d83afb23643f21201c552e716cf7fe1ff8dd6400e150c9010ebe02892",
  "KliverPox": "0x019452d409c98507d83aded94fac6781cc6266279246a42eb1ac882368de1552",
  "MarketPlace": "0x06ab7e68c323a453299cde01a6c2398162fc252c0f3e4c77abcda9054ec79e26"
}
```

**Live deployment on Sepolia:**
- **KliverNFT**: [`0x052b1adc...f46ff939`](https://sepolia.starkscan.co/contract/0x052b1adc747e150870ef1d0de8b14d15ba9209814f90a3f99d032d59f46ff939)
- **KliverTokensCore**: [`0x043ea8c6...2752cc18`](https://sepolia.starkscan.co/contract/0x043ea8c61ad673ccb6662bec74a88e19cb0f6b782a0a87a80a2868cf2752cc18)
- **Registry**: [`0x0494de6d...ebe02892`](https://sepolia.starkscan.co/contract/0x0494de6d83afb23643f21201c552e716cf7fe1ff8dd6400e150c9010ebe02892)
- **KliverPox**: [`0x019452d4...68de1552`](https://sepolia.starkscan.co/contract/0x019452d409c98507d83aded94fac6781cc6266279246a42eb1ac882368de1552)
- **SessionsMarketplace**: [`0x06ab7e68...4ec79e26`](https://sepolia.starkscan.co/contract/0x06ab7e68c323a453299cde01a6c2398162fc252c0f3e4c77abcda9054ec79e26)

### Interactive Deployment

For a step-by-step guided experience:

```bash
cd deploy
poetry run python deploy_interactive.py
```

**Interactive mode features:**
- Intuitive visual menu
- Parameter validation
- Confirmation before each deployment
- Dependency order information
- Automatic JSON output

### Individual Deployment

If you prefer to deploy contracts separately:

```bash
# 1. NFT
poetry run python kliver_deploy/deploy.py --environment dev --contract nft

# 2. TokensCore
poetry run python kliver_deploy/deploy.py --environment dev --contract kliver_tokens_core

# 3. Registry (requires NFT + TokensCore)
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract registry \
  --nft-address 0xNFT_ADDR \
  --token-simulation-address 0xTOKEN_ADDR

# 4. KliverPox (requires Registry)
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract kliver_pox \
  --registry-address 0xREGISTRY_ADDR

# 5. SessionsMarketplace (requires KliverPox)
poetry run python kliver_deploy/deploy.py \
  --environment dev \
  --contract sessions_marketplace \
  --pox-address 0xPOX_ADDR \
  --registry-address 0xREGISTRY_ADDR \
  --payment-token-address 0xERC20_ADDR \
  --purchase-timeout 86400
```

**Manual configuration required** when deploying individually:

```bash
# Configure Registry in TokensCore
sncast invoke \
  --contract-address 0xTOKENS_CORE_ADDR \
  --function set_registry_address \
  --calldata 0xREGISTRY_ADDR

# Configure KliverPox in Registry
sncast invoke \
  --contract-address 0xREGISTRY_ADDR \
  --function set_kliver_pox_address \
  --calldata 0xPOX_ADDR
```

### Post-Deployment Configuration

To configure already deployed contracts:

```bash
cd deploy
poetry run python configure_interactive.py
```

**Available options:**
- Configure Registry in TokensCore
- Configure KliverPox in Registry
- Configure Verifier in Registry
- Configure Payment Token in Marketplace
- View configured addresses
- Generic method invocation

### Deployment Parameters

| Flag | Description | Required |
|------|-------------|----------|
| `--environment` | Environment (local/dev/qa/prod) | Yes |
| `--contract` | Contract name or `all` | Yes |
| `--owner` | Owner address (defaults to deployer) | No |
| `--nft-address` | NFT contract address | For registry |
| `--token-simulation-address` | TokensCore address | For registry |
| `--registry-address` | Registry address | For kliver_pox/marketplace |
| `--pox-address` | KliverPox address | For marketplace |
| `--verifier-address` | Verifier contract | Overrides config |
| `--payment-token-address` | ERC20 payment token | For marketplace |
| `--purchase-timeout` | Timeout in seconds | For marketplace |
| `--no-compile` | Skip compilation | No |
| `--output-json` | JSON output format | No |

### Deployment Artifacts

Each deployment generates a JSON file:

```
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

## Testing

### Run Tests

```bash
# Build and run all tests
scarb build
scarb test

# Specific test
scarb test test_claim_accumulated_days

# Verbose mode
scarb test -v
```

### Test Coverage

**180 tests** covering:

- **Token Economics (110+ tests)**
  - Token creation, claims, whitelist management
  - Time-based releases and accumulated days
  - Edge cases and validations

- **Content Validation (40+ tests)**
  - Registration of characters, scenarios, simulations, and sessions
  - Batch verification and hash validation
  - NFT-gated access control

- **NFT System (15+ tests)**
  - Minting, burning, and access control

- **PoX System (10+ tests)**
  - Session minting and metadata storage
  - Registry integration

- **Marketplace (10+ tests)**
  - Listing management, escrow, and refunds
  - Challenge validation and proof verification

---

## More Information

To learn more about Kliver and our platform, visit:

**[kliver.ai](http://kliver.ai)**

---

## License

MIT License - see [LICENSE](LICENSE) file

---

**Built with Cairo and Starknet**
