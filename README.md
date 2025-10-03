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

## Deployment

The project includes automated deployment scripts for both contracts:

### Deploy Registry Only
```bash
python deploy_contract.py --contract registry
```

### Deploy NFT Only  
```bash
python deploy_contract.py --contract nft
```

### Deploy Both Contracts
```bash
python deploy_contract.py --contract registry
python deploy_contract.py --contract nft
```

### Configuration

Update `deployment_config.yml` to configure deployment parameters:

```yaml
contracts:
  registry:
    name: "kliver_on_chain_KliverRegistry" 
    constructor_args: []
  nft:
    name: "kliver_on_chain_KliverNFT"
    constructor_args:
      - "0x1234..."  # Owner address
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

### Basic Interaction Flow

```cairo
// 1. Register interactions
contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, hash1, 85);
contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, hash2, 92);

// 2. Complete step successfully
let interaction_hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);

// 3. Check completion status
let is_completed = contract.is_step_completed(user_id, challenge_id, session_id, step_id);
let has_failures = contract.session_has_failed_step(user_id, challenge_id, session_id);
```

### Failure Handling

```cairo
// 1. Complete a step as failed
contract.complete_step_failed(user_id, challenge_id, session_id, step1);

// 2. This will now fail - session has a failed step
contract.complete_step_success(user_id, challenge_id, session_id, step2); // ❌ Reverts

// 3. But this will work - can still fail additional steps
contract.complete_step_failed(user_id, challenge_id, session_id, step2); // ✅ Works
```

## Constants & Limits

| Parameter | Value | Description |
|-----------|-------|-------------|
| `MAX_SCORE` | 100 | Maximum scoring value |
| `MIN_SCORE` | 0 | Minimum scoring value |
| `MAX_INTERACTIONS_PER_STEP` | 15 | Maximum interactions per step |
| `MAX_PAGINATION_LIMIT` | 100 | Maximum items per page |

## Events

The contract emits the following events:

### `InteractionRegistered`
```cairo
struct InteractionRegistered {
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252,
    interaction_pos: u32,
    message_hash: felt252,
    scoring: u32,
    timestamp: u64,
}
```

### `StepCompleted`
```cairo
struct StepCompleted {
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252,
    interactions_hash: felt252,
    max_score: u32,
    total_interactions: u32,
    player: ContractAddress,
    timestamp: u64,
}
```

## Security Considerations

### Input Validation
- All function parameters are validated for zero values
- Scoring is bounded between 0-100
- Interaction positions must be sequential
- Pagination limits are enforced

### Access Control
- Owner-only functions for administration
- Pause mechanism for emergency stops
- Ownership transfer capability

### State Protection
- Steps cannot be completed twice
- Session failure state is immutable
- Interaction sequence integrity is enforced

## Gas Optimization

The contract implements several gas optimization strategies:
- Efficient storage layout using Cairo's `Map` type
- Minimal state reads through careful function design
- Optimized loops using `!= condition + 1` pattern
- Event emission only for state changes

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