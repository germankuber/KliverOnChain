# Kliver Smart Contract Deployment System

A modern, object-oriented deployment system for Kliver smart contracts on StarkNet.

## 🏗️ Architecture

```
deploy/
├── kliver_deploy/           # Main Python package
│   ├── __init__.py         # Package initialization
│   ├── config.py           # Configuration management
│   ├── contracts.py        # Contract definitions
│   ├── deployer.py         # Main deployment orchestrator
│   ├── utils.py            # Utility functions
│   ├── deploy.py           # CLI implementation
│   └── cli.py              # CLI module
├── deployment_config.yml    # Environment configurations
├── pyproject.toml          # Poetry configuration
└── README.md               # This file
```

## 🚀 Features

- **Object-Oriented Design**: Clean separation of concerns
- **Environment Management**: Dev, QA, and Production configurations
- **Contract Validation**: Automated dependency validation
- **Transaction Tracking**: Real-time deployment monitoring
- **Error Handling**: Comprehensive error reporting
- **Extensible**: Easy to add new contracts

## 📦 Installation

```bash
cd deploy
poetry install
```

## 🎯 Usage

### Deploy All Contracts
```bash
poetry run python -m kliver_deploy.deploy --environment dev --contract all
```

### Deploy Individual Contracts
```bash
# Deploy NFT only
poetry run python -m kliver_deploy.deploy --environment dev --contract nft

# Deploy Token1155 only  
poetry run python -m kliver_deploy.deploy --environment dev --contract kliver_1155

# Deploy Registry (requires NFT address)
poetry run python -m kliver_deploy.deploy --environment dev --contract registry --nft-address 0x123...
```

### Alternative Script Usage
```bash
# Direct script execution
poetry run python kliver_deploy/deploy.py --environment dev --contract all

# Using the convenience script
poetry run kliver-deploy --environment dev --contract all
```

## 🔧 Configuration

The system uses `deployment_config.yml` for environment-specific configurations:

```yaml
environments:
  dev:
    name: "Development"
    network: "sepolia"
    account: "dev"
    rpc_url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8"
    contracts:
      nft:
        name: "kliver_on_chain_KliverNFT"
        base_uri: "https://api-dev.kliver.ai/api/nft/metadata"
      registry:
        name: "kliver_on_chain_KliverRegistry"
        verifier_address: "0x0"
      # ... more contracts
```

## 📋 Contract Dependencies

- **KliverNFT**: No dependencies
- **KliverNFT1155**: No dependencies
- **KliverRegistry**: Requires NFT address + optional verifier address

## 🔍 Deployment Order (--contract all)

1. **KliverNFT** → Base ERC721 contract
2. **KliverRegistry** → Uses NFT for validation
3. **KliverNFT1155** → ERC1155 token contract

## 🧪 Development

### Project Structure
```python
# Main classes
ConfigManager      # Handles YAML configuration
ContractDeployer   # Main deployment orchestrator
BaseContract       # Abstract contract interface
```

### Adding New Contracts
1. Create contract class in `contracts.py`
2. Add configuration to `deployment_config.yml`
3. Update `CONTRACTS` dictionary in `contracts.py`

### Running Tests
```bash
poetry run pytest
```

### Code Formatting
```bash
poetry run black .
poetry run isort .
```

## 📊 Output Features

- **Colored Output**: Success/error/warning indicators
- **Progress Tracking**: Step-by-step deployment progress
- **Transaction Monitoring**: Real-time tx confirmation
- **Deployment Summary**: Clean final summary with explorer links
- **JSON Logging**: Detailed deployment records

## 🔒 Security Features

- **Pre-deployment Validation**: Contract dependencies verified
- **Transaction Confirmation**: Waits for L2 confirmation
- **Error Recovery**: Handles network issues gracefully
- **Configuration Validation**: Validates all required fields

## 🌍 Multi-Environment Support

| Environment | Network | Purpose |
|-------------|---------|---------|
| `dev` | Sepolia | Development and testing |
| `qa` | Sepolia | Integration testing |
| `prod` | Mainnet | Production deployment |

## 📝 Example Output

```
🚀 COMPLETE DEPLOYMENT MODE
This will deploy: NFT → Registry → Token1155

Step 1/4: Deploying NFT Contract
🎯 Deploying KliverNFT to sepolia
✓ Prerequisites OK
✓ Contract deployed at address: 0x123...

Step 2/4: Deploying Registry Contract
🔍 Validating NFT contract at 0x123...
✓ Contract deployed at address: 0x456...

🎉 DEPLOYMENT SUMMARY
======================================================================
1. KLIVERNFT
   Address:    0x123...
   Explorer:   https://sepolia.starkscan.co/contract/0x123...
======================================================================
```

## 🆘 Troubleshooting

### Common Issues
- **Missing dependencies**: Ensure Scarb and Starknet Foundry are installed
- **Account not found**: Check your Starknet account configuration
- **Transaction timeout**: Network congestion, try again later
- **Contract validation failed**: Verify dependency addresses are correct

### Debug Mode
```bash
poetry run python -m kliver_deploy.deploy --environment dev --contract all --verbose
```