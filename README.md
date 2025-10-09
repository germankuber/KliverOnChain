# Kliver OnChain Platform

A comprehensive Cairo smart contract suite for Starknet that includes registry systems for managing AI interactions and an NFT-gated authentication system for the Kliver platform.

## Overview

The Kliver OnChain Platform consists of two main components:

1. **Kliver Registry**: A decentralized solution that tracks and validates character versions, scenarios, simulations, and ownership data for the Kliver platform. **Requires NFT ownership** for content registration.

2. **Kliver NFT**: An ERC721-compliant NFT that serves as the authentication mechanism for the Kliver platform. Users must own a Kliver NFT to register content in the Registry.

Both contracts ensure data integrity through cryptographic hashing and implement robust access control mechanisms with NFT-gated authentication.

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
fn register_character(character_id: felt252, character_hash: felt252)
fn verify_character(character_id: felt252, character_hash: felt252) -> VerificationResult
fn batch_verify_characters(characters: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>
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

## 🚀 Deployment Guide

### 🔑 Key Concept: NFT-Gated Registry

The **Kliver Registry** requires an **NFT contract address** during deployment. This NFT contract is used to validate that authors own a Kliver NFT before they can register characters, scenarios, or simulations.

#### Architecture Flow

```
┌─────────────┐
│  Kliver NFT │ ← Users must own this NFT
└──────┬──────┘
       │
       │ (address passed to constructor)
       │
       ▼
┌──────────────────┐
│ Kliver Registry  │ ← Validates NFT ownership on registration
└──────────────────┘
```

When a user tries to register content:
```
User registers → Registry checks → Does author have NFT?
                                         ↓
                                   ┌─────┴─────┐
                                  YES          NO
                                   ↓            ↓
                            Registration OK   Error: Must own NFT
```

### 📋 Deployment Modes

#### Mode 1: Complete Deployment (Recommended) ✅

Deploy both NFT and Registry with automatic linking.

```bash
python deploy_contract.py --environment dev --contract all
```

**What happens:**
1. ✅ Deploys NFT contract
2. ✅ Deploys Registry contract with NFT address
3. ✅ Automatically links them
4. ✅ Saves deployment info for both

**Use this when:** Starting a fresh deployment

#### Mode 2: NFT Only Deployment

Deploy only the NFT contract.

```bash
python deploy_contract.py --environment dev --contract nft --owner 0x123...
```

**Use this when:** You need to deploy NFT first, then Registry later

#### Mode 3: Registry Only Deployment (Requires NFT)

Deploy Registry using an existing NFT contract.

```bash
python deploy_contract.py --environment dev --contract registry --nft-address 0xABCDEF...
```

**⚠️ Important:** The script will **validate** that the NFT contract exists before deploying Registry!

**Use this when:** 
- NFT is already deployed
- Redeploying Registry with a different configuration

### 🔒 NFT Validation

When deploying Registry separately (`--contract registry`), the script automatically validates:

1. **NFT Contract Exists**: Calls the NFT contract to verify it's deployed
2. **Valid NFT Contract**: Checks it responds to standard ERC721 methods
3. **Deployment Abort**: If validation fails, Registry deployment is aborted

This prevents misconfiguration and ensures the Registry always has a valid NFT reference.

### 🌍 Environment Configuration

Edit `deployment_config.yml` to set up your environments:

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

### 📝 Complete Deployment Examples

#### Development Environment

```bash
# Option 1: Deploy everything (recommended for dev)
python deploy_contract.py --environment dev --contract all

# Option 2: Deploy NFT first, then Registry later
python deploy_contract.py --environment dev --contract nft
# ... note the NFT address from output ...
python deploy_contract.py --environment dev --contract registry --nft-address 0xNFT_ADDRESS

# Option 3: Deploy with custom owner
python deploy_contract.py --environment dev --contract all --owner 0x1234...
```

#### QA Environment

```bash
# Deploy complete system to QA
python deploy_contract.py --environment qa --contract all

# Or separate deployments
python deploy_contract.py --environment qa --contract nft --owner 0x5678...
python deploy_contract.py --environment qa --contract registry --nft-address 0xQA_NFT_ADDR
```

#### Production Environment ⚠️

```bash
# PRODUCTION: Always deploy everything together for consistency
python deploy_contract.py --environment prod --contract all --owner 0xPROD_OWNER

# Only if absolutely necessary, deploy separately:
python deploy_contract.py --environment prod --contract nft --owner 0xPROD_OWNER
python deploy_contract.py --environment prod --contract registry --nft-address 0xPROD_NFT_ADDR
```

### ⚠️ Error Handling

#### Error: "NFT address is required for Registry deployment"

**Cause:** Trying to deploy Registry without specifying NFT address

**Solution:** 
```bash
# Either deploy everything:
python deploy_contract.py --environment dev --contract all

# Or provide NFT address:
python deploy_contract.py --environment dev --contract registry --nft-address 0x123...
```

#### Error: "Invalid NFT contract address or contract not deployed"

**Cause:** Provided NFT address doesn't point to a valid deployed NFT contract

**Solution:**
1. Verify the NFT address is correct
2. Ensure the NFT is deployed on the same network
3. Check the NFT contract on explorer (e.g., Starkscan)

### 📊 Deployment Output Example

```
� COMPLETE DEPLOYMENT MODE
This will deploy NFT first, then Registry using the NFT address

Step 1/2: Deploying NFT Contract
🔨 Compiling contracts...
✓ Compilation successful
📤 Declaring contract...
✓ Contract declared with class hash: 0xABC...
🚀 Deploying KliverNFT...
✓ Contract deployed at address: 0x123NFT...

Step 2/2: Deploying Registry Contract
🔍 Validating NFT contract at 0x123NFT...
✓ NFT contract validated successfully
📤 Declaring contract...
✓ Contract declared with class hash: 0xDEF...
🚀 Deploying kliver_registry...
✓ Contract deployed at address: 0x456REGISTRY...

======================================================================
🎉 DEPLOYMENT SUMMARY
======================================================================

1. KLIVERNFT
   Address:    0x123NFT...
   Explorer:   https://sepolia.starkscan.co/contract/0x123NFT...
   Class Hash: 0xABC...

2. KLIVER_REGISTRY
   Address:    0x456REGISTRY...
   Explorer:   https://sepolia.starkscan.co/contract/0x456REGISTRY...
   Class Hash: 0xDEF...
   NFT Link:   0x123NFT...

Network: SEPOLIA | Owner: 0xOWNER...

ℹ️  Registry is configured to use the NFT contract for author validation
======================================================================
```

### 🔐 Security Notes

1. **Always validate NFT address**: The script does this automatically, but double-check in production
2. **Test on Sepolia first**: Use dev/qa environments before production
3. **Backup deployment info**: JSON files are saved automatically - keep them safe
4. **Verify on Explorer**: Always check deployed contracts on Starkscan

### 💡 Additional Resources

- Check `deployment_examples.sh` for more command examples
- Review `deployment_quick_ref.sh` for visual quick reference

### Command Options Reference

| Option | Values | Description |
|--------|--------|-------------|
| `--environment` | `dev`, `qa`, `prod` | Auto-configures network & account |
| `--contract` | `all`, `nft`, `registry` | Which contract(s) to deploy |
| `--owner` | `0x123...` | Optional owner address (uses account if not specified) |
| `--nft-address` | `0xABC...` | Required when deploying registry separately |



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
registry.register_character('char_v1', 'hash123');

// 2. Verify character version  
let result = registry.verify_character('char_v1', 'hash123');
// Returns: VerificationResult::Valid

// 3. Batch verification
let versions = array![('char_v1', 'hash123'), ('char_v2', 'hash456')];
let results = registry.batch_verify_characters(versions);
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