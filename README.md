# Kliver OnChain Platform

A comprehensive Cairo smart contract suite for Starknet that includes registry systems for managing AI interactions and an NFT system for Kliver platform users.

## Overview

The Kliver OnChain Platform consists of two main components:

1. **Kliver Registry**: A decentralized solution that tracks and validates character versions, scenarios, simulations, and ownership data for the Kliver platform.

2. **Kliver NFT**: An ERC721-compliant NFT that is minted for users who log into the Kliver platform, serving as a digital badge of membership and participation.

Both contracts ensure data integrity through cryptographic hashing and implement robust access control mechanisms.

## Features

### 🏛️ **Kliver Registry System**
- **Character Registry**: Manage and validate character versions with cryptographic hashing
- **Scenario Registry**: Track and verify scenario data integrity  
- **Simulation Registry**: Handle simulation metadata and validation
- **Owner Registry**: Manage ownership and access control across the platform
- **Batch Operations**: Efficient bulk verification for multiple entries
- **Cryptographic Verification**: Ensure data integrity through hash validation

### 🎯 **Kliver NFT System**
- **ERC721 Standard**: Full compliance with OpenZeppelin's ERC721 implementation
- **User Badges**: Mint NFTs for users who log into the Kliver platform
- **Ownership Tracking**: Track NFT ownership and transfers
- **Metadata Support**: Built-in support for token metadata and base URI
- **Access Control**: Owner-only minting with secure permissions
- **Upgradeable**: Support for contract upgrades via proxy pattern

### 🔐 **Security & Access Control**
- Owner-based access control for both contracts
- Input validation for all parameters
- Reentrancy protection
- Upgradeable contract architecture
- Comprehensive event logging

### � **Query & Management**
- Efficient verification systems
- Batch operations for gas optimization
- Event-driven architecture for off-chain indexing
- Total supply tracking for NFTs

## Contract Architecture

### Kliver Registry

The registry system is built with a modular architecture:

```cairo
/// Verification result for registry operations
enum VerificationResult {
    Valid,
    Invalid,
    NotFound,
}
```

**Registry Modules:**
- `CharacterRegistry`: Manages character version validation
- `ScenarioRegistry`: Handles scenario data verification
- `SimulationRegistry`: Tracks simulation metadata
- `OwnerRegistry`: Manages ownership and permissions
- `KliverRegistry`: Main orchestrator contract

### Kliver NFT

Standard ERC721 implementation with Kliver-specific features:

```cairo
/// Kliver NFT Interface
trait IKliverNFT {
    fn mint_to_user(to: ContractAddress, token_id: u256);
    fn total_supply() -> u256;
    // Standard ERC721 methods via OpenZeppelin
}
```

**Key Components:**
- **ERC721Component**: OpenZeppelin's battle-tested NFT implementation
- **OwnableComponent**: Access control for administrative functions
- **UpgradeableComponent**: Support for contract upgrades
- **SRC5Component**: Interface introspection for Starknet

## Key Business Rules

### 🏛️ **Registry System Rules**
1. **Data Integrity**: All entries must be validated through cryptographic hashing
2. **Ownership Control**: Only authorized addresses can register new entries
3. **Immutability**: Once registered, hashes cannot be modified (only verified)
4. **Batch Operations**: Support for efficient bulk operations

### 🎯 **NFT System Rules**
1. **Single NFT per User**: Each user receives one NFT upon platform login
2. **Owner-Only Minting**: Only the contract owner can mint new NFTs
3. **Standard Compliance**: Full ERC721 compatibility for marketplace integration
4. **Metadata Management**: Centralized base URI with token-specific metadata

## API Reference

### Kliver Registry Functions

#### Character Registry
```cairo
fn register_character_version(character_version_id: felt252, character_version_hash: felt252)
fn verify_character_version(character_version_id: felt252, character_version_hash: felt252) -> VerificationResult
fn batch_verify_character_versions(character_versions: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
```

#### Scenario Registry  
```cairo
fn register_scenario_version(scenario_version_id: felt252, scenario_version_hash: felt252)
fn verify_scenario_version(scenario_version_id: felt252, scenario_version_hash: felt252) -> VerificationResult
```

#### Simulation Registry
```cairo
fn register_simulation_version(simulation_version_id: felt252, simulation_version_hash: felt252) 
fn verify_simulation_version(simulation_version_id: felt252, simulation_version_hash: felt252) -> VerificationResult
```

### Kliver NFT Functions

#### Core NFT Operations
```cairo
fn mint_to_user(to: ContractAddress, token_id: u256)  // Owner only
fn total_supply() -> u256
```

#### Standard ERC721 (via OpenZeppelin)
```cairo
fn balance_of(account: ContractAddress) -> u256
fn owner_of(token_id: u256) -> ContractAddress  
fn transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256)
fn approve(to: ContractAddress, token_id: u256)
fn name() -> ByteArray
fn symbol() -> ByteArray
fn token_uri(token_id: u256) -> ByteArray
```

### Administrative Functions

#### Registry Management
```cairo
fn transfer_ownership(new_owner: ContractAddress)  // Owner only
```

#### NFT Management  
```cairo
fn transfer_ownership(new_owner: ContractAddress)  // Owner only
fn upgrade(new_class_hash: ClassHash)  // Owner only, upgradeable pattern
```

## Deployment by Environment

The project supports deployment to multiple environments with specific configurations:

### 🏗️ Development Environment 
**Network**: Automatically uses Sepolia Testnet  
**Use for**: Local development, feature testing, experimentation

```bash
# Registry only
poetry run python deploy_contract.py --environment dev --contract registry

# NFT only  
poetry run python deploy_contract.py --environment dev --contract nft

# Both contracts (deploy individually)
poetry run python deploy_contract.py --environment dev --contract registry
poetry run python deploy_contract.py --environment dev --contract nft

# Quick deploy (development)
poetry run python quick_deploy.py
```

### 🧪 QA Environment
**Network**: Automatically uses Sepolia Testnet  
**Use for**: QA testing, integration testing, pre-production validation

```bash
# Registry only
poetry run python deploy_contract.py --environment qa --contract registry

# NFT only
poetry run python deploy_contract.py --environment qa --contract nft

# Both contracts (deploy individually)
poetry run python deploy_contract.py --environment qa --contract registry
poetry run python deploy_contract.py --environment qa --contract nft
```

### 🏭 Production Environment ⚠️
**Network**: Automatically uses Mainnet  
**Use for**: Live production deployment - **USE WITH EXTREME CAUTION**

```bash
# Registry only
poetry run python deploy_contract.py --environment prod --contract registry

# NFT only
poetry run python deploy_contract.py --environment prod --contract nft

# Both contracts (CAUTION! Deploy individually)
poetry run python deploy_contract.py --environment prod --contract registry
poetry run python deploy_contract.py --environment prod --contract nft
```

### Environment Configuration

Each environment automatically configures the appropriate network and settings:

| Environment | Auto Network | Account | Purpose | Build Target |
|-------------|-------------|---------|---------|-------------|
| **`dev`** | Sepolia | `dev-kliver` | Development & testing | `target/dev/` |
| **`qa`** | Sepolia | `qa-kliver` | QA & integration | `target/dev/` |
| **`prod`** | Mainnet | `prod-kliver` | Live deployment | `target/release/` |

### Command Options

| Option | Description | Example |
|--------|-------------|----------|
| `--environment` | Environment (auto-configures network & account) | `dev`, `qa`, `prod` |
| `--contract` | Contract to deploy | `registry`, `nft` |
| `--owner` | Owner address (optional, uses account if not specified) | `0x1234567890abcdef` |
| `--verbose` | Detailed output | Add `-v` flag |
| `--rpc-url` | Custom RPC URL (optional override) | `https://custom-rpc.com` |

> **Notes**: 
> - No need to specify `--account` or `--network` - they are automatically selected based on `--environment`
> - The `--owner` parameter is optional; if not provided, the script uses the account address as owner
> - Use `poetry run` to execute the script with proper dependencies

### Interactive Deployment Menu

Run the environment-aware interactive script:
```bash
./deployment_examples.sh
```

This provides a comprehensive menu with:
- ✅ Environment-specific options (Dev/Test/Prod)
- ✅ Contract-specific choices (Registry/NFT/Both)
- ✅ Safety confirmations for production
- ✅ Account and network validation

### Account Setup by Environment

Before deploying, ensure you have accounts configured for each environment:

```bash
# Development account (will deploy to Sepolia)
starkli account fetch <dev-address> --output ~/.starkli-wallets/deployer/dev-kliver.json

# QA account (will deploy to Sepolia)  
starkli account fetch <qa-address> --output ~/.starkli-wallets/deployer/qa-kliver.json

# Production account (will deploy to Mainnet) 
starkli account fetch <prod-address> --output ~/.starkli-wallets/deployer/prod-kliver.json
```

### Environment Auto-Configuration

When you use `--environment`, the system automatically:
- ✅ **Selects the correct network** (dev/qa → Sepolia, prod → Mainnet)
- ✅ **Uses the right account** (dev-kliver, qa-kliver, prod-kliver)
- ✅ **Chooses build target** (dev/qa → target/dev/, prod → target/release/)
- ✅ **Sets timeout values** (dev: 120s, qa: 180s, prod: 300s)

## 🚀 Smart Deployment Features

The deployment script includes intelligent features for a smooth experience:

### ⏳ Automatic Transaction Waiting
- **Smart Declaration**: Automatically waits for declaration transactions to be confirmed (every 5 seconds)
- **Prevents Failures**: Ensures class is available before attempting deployment  
- **Timeout Protection**: Maximum 5 minutes wait time with clear progress updates

### 🔄 Duplicate Declaration Handling
- **Already Declared**: Detects when contracts are already declared and extracts the existing class hash
- **No Re-declaration**: Skips unnecessary declarations to save time and gas
- **Seamless Continuation**: Proceeds directly to deployment with existing class hash

### 🎯 Contract-Specific Parameters
- **Registry**: Requires only owner address (automatically uses account if not specified)
- **NFT**: Automatically includes required base URI parameter (empty ByteArray: `0 0 0`)
- **Smart Detection**: Handles different constructor requirements automatically

### 📊 Clean Output & Logging
- **Concise Logs**: Shows only essential information, eliminates verbose command output
- **Progress Indicators**: Clear progress updates with emojis and status messages
- **Smart Formatting**: Truncated addresses for readability (`0x517f65712...eec0c`)
- **Success Summary**: Clean final summary with contract address and explorer links

### 🛡️ Error Handling & Recovery
- **Multiple Patterns**: Tries different regex patterns to parse contract addresses
- **Clear Error Messages**: Detailed error information when something fails
- **Graceful Degradation**: Continues deployment even with minor parsing issues

### 📝 Example Deployment Output

```bash
$ poetry run python deploy_contract.py --environment qa --contract registry

🎯 Deploying kliver_registry to sepolia
Account: qa | Network: sepolia
--------------------------------------------------
🔍 Checking prerequisites...
✓ Prerequisites OK
✓ Using account 'qa': 0x517f65712...eec0c
Owner: 0x517f65712...eec0c
🔨 Compiling contracts...
✓ Compilation successful
📤 Declaring kliver_registry...
✓ Contract already declared with class hash: 0x07c96f4fd...cbecf9
ℹ️  Skipping declaration, proceeding with deployment...
🚀 Deploying kliver_registry...
✓ Contract deployed at address: 0x07c4815ef6...77da6
✓ Deployment info saved to: deployment_sepolia_1759519469.json

🎉 DEPLOYMENT SUCCESSFUL!
Contract: 0x07c4815ef629823a8ac87dfa8bc6675e059c780e8041b923cc9f9fe6d4d77da6
Explorer: https://sepolia.starkscan.co/contract/0x07c4815ef629823a8ac87dfa8bc6675e059c780e8041b923cc9f9fe6d4d77da6
Class Hash: 0x07c96f4fd2878fb6298c4754749e897f26d08d98f056305ff7bea596c7cbecf9
Network: sepolia | Owner: 0x517f65712...eec0c
```

## Development Setup

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)  
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) (Testing framework)
- Cairo 2.8.2+
- Python 3.8+ (for deployment scripts)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/germankuber/KliverOnChain.git
cd KliverOnChain
```

2. Install Cairo dependencies:
```bash
scarb build
```

3. Install Python dependencies (for deployment):
```bash
pip install starknet-py pyyaml
```

### Running Tests

Execute the comprehensive test suite:

```bash
# Build contracts first
scarb build

# Run all tests
scarb test

# Run specific test files
snforge test tests/test_kliver_registry.cairo
```

### Test Coverage

The project includes comprehensive tests covering:
- ✅ Registry operations and validation
- ✅ NFT minting and transfers  
- ✅ Access control and ownership
- ✅ Hash verification systems
- ✅ Batch operations
- ✅ Edge cases and error conditions
- ✅ OpenZeppelin component integration

## Usage Examples

### Registry Operations

```cairo
// 1. Register a character version (owner only)
registry.register_character_version('char_v1', 'hash123');

// 2. Verify character version  
let result = registry.verify_character_version('char_v1', 'hash123');
// Returns: VerificationResult::Valid

// 3. Batch verification
let versions = array![('char_v1', 'hash123'), ('char_v2', 'hash456')];
let results = registry.batch_verify_character_versions(versions);
```

### NFT Operations

```cairo  
// 1. Mint NFT to new user (owner only)
nft.mint_to_user(user_address, token_id);

// 2. Check NFT ownership
let owner = nft.owner_of(token_id);
let balance = nft.balance_of(user_address);

// 3. Transfer NFT
nft.transfer_from(from_address, to_address, token_id);

// 4. Get token metadata
let metadata_uri = nft.token_uri(token_id);
```

## Contract Specifications

### Kliver Registry
| Feature | Implementation |
|---------|---------------|
| **Architecture** | Modular registry system |
| **Verification** | Cryptographic hash validation |
| **Access Control** | Owner-based permissions |
| **Batch Operations** | Gas-optimized bulk processing |

### Kliver NFT  
| Feature | Implementation |
|---------|---------------|
| **Standard** | ERC721 (OpenZeppelin) |
| **Upgradeable** | Yes (proxy pattern) |
| **Metadata** | Base URI + token ID |
| **Supply** | Unlimited (owner-controlled) |

## Events

### Registry Events

```cairo
struct CharacterVersionRegistered {
    character_version_id: felt252,
    character_version_hash: felt252,
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
```

### NFT Events

```cairo
struct UserNFTMinted {
    token_id: u256,
    to: ContractAddress,
    timestamp: u64,
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
```

## Security Considerations

### Input Validation
- All function parameters are validated for zero values
- Hash integrity validation through cryptographic checks
- Access control on all administrative functions

### Access Control
- Owner-only functions for registry management and NFT minting
- Ownership transfer capability for both contracts
- Upgradeable architecture with controlled access

### Data Protection
- Immutable hash storage once registered
- Protection against hash collision attacks
- Event-driven transparency for all operations

## Gas Optimization

Both contracts implement gas optimization strategies:

### Registry Optimizations
- Efficient storage layout using Cairo's `Map` type
- Batch operations for multiple verifications
- Minimal state reads in verification functions

### NFT Optimizations  
- OpenZeppelin's battle-tested implementations
- Efficient token enumeration patterns
- Optimized transfer mechanics

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write comprehensive tests for new features
- Follow Cairo naming conventions
- Document all public functions
- Maintain gas efficiency
- Ensure backward compatibility

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

- **Developer**: German Kuber
- **GitHub**: [@germankuber](https://github.com/germankuber)
- **Project**: [KliverOnChain](https://github.com/germankuber/KliverOnChain)

---

**Built with ❤️ using Cairo and Starknet**