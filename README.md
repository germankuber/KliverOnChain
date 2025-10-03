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

## 🚀 Quick Deployment

### Deploy Both Contracts (Recommended)
```bash
# QA Environment (Sepolia testnet)
poetry run python deploy_contract.py --environment qa --contract registry
poetry run python deploy_contract.py --environment qa --contract nft

# Production Environment (Mainnet - CAUTION!)
poetry run python deploy_contract.py --environment prod --contract registry  
poetry run python deploy_contract.py --environment prod --contract nft
```

### Deploy Individual Contracts
```bash
# Registry only
poetry run python deploy_contract.py --environment qa --contract registry

# NFT only
poetry run python deploy_contract.py --environment qa --contract nft
```

### Command Options
| Option | Values | Description |
|--------|--------|-------------|
| `--environment` | `dev`, `qa`, `prod` | Auto-configures network & account |
| `--contract` | `registry`, `nft` | Which contract to deploy |
| `--owner` | `0x123...` | Optional owner address (uses account if not specified) |

### What happens automatically:
- ✅ **Network selection**: qa/dev → Sepolia, prod → Mainnet  
- ✅ **Account selection**: Uses environment-specific account
- ✅ **Transaction waiting**: Waits for declaration confirmation (5s intervals)
- ✅ **Smart error handling**: Handles "already declared" cases
- ✅ **Clean output**: Shows essential info with colored addresses

## � Example Output

```bash
$ poetry run python deploy_contract.py --environment qa --contract registry

🎯 Deploying kliver_registry to sepolia
Account: qa | Network: sepolia
--------------------------------------------------
🔍 Checking prerequisites...
✓ Prerequisites OK
� Declaring kliver_registry...
✓ Contract already declared with class hash: 0x07c96f4fd...cbecf9
🚀 Deploying kliver_registry...
✓ Contract deployed at address: 0x07c4815ef6...77da6

🎉 DEPLOYMENT SUCCESSFUL!
Contract: 0x07c4815ef629823a8ac87dfa8bc6675e059c780e8041b923cc9f9fe6d4d77da6
Explorer: https://sepolia.starkscan.co/contract/0x07c4815ef629823a8ac87dfa8bc6675e059c780e8041b923cc9f9fe6d4d77da6
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