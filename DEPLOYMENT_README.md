# KliverRegistry Deployment Scripts

This folder contains automated scripts to deploy the KliverRegistry contract to StarkNet.

## 📋 Prerequisites

1. **Scarb** - To compile the Cairo contract
2. **Starknet Foundry (sncast)** - To interact with StarkNet
3. **Python 3.8+** - To run the deployment scripts
4. **Configured account** - A StarkNet account configured with sncast

## 🛠 Dependencies Installation

```bash
# Install Python dependencies
pip install click colorama requests

# Or using the project's virtual environment
.venv/bin/pip install click colorama requests
```

## 🚀 Usage

### Option 1: Complete Script (Recommended)

The main script with all options:

```bash
# Basic deployment
python deploy_contract.py --account kliver --network sepolia

# Deployment with custom owner
python deploy_contract.py --account kliver --network sepolia --owner 0x1234...

# Deployment with custom RPC
python deploy_contract.py --account kliver --network sepolia --rpc-url https://my-custom-rpc.com

# View complete help
python deploy_contract.py --help
```

### Option 2: Quick Deployment

For quick deployment with default configurations:

```bash
python quick_deploy.py
```

## 📊 Features

### Main Script (`deploy_contract.py`)

- ✅ **Prerequisites verification** - Verifies Scarb, sncast and accounts
- ✅ **Automatic compilation** - Compiles the contract with Scarb
- ✅ **Contract declaration** - Declares and gets class hash
- ✅ **Automatic deployment** - Deploys the contract instance
- ✅ **Transaction confirmation** - Waits for L2 confirmation
- ✅ **Information saving** - Saves deployment details
- ✅ **Colored output** - User-friendly interface with colors
- ✅ **Error handling** - Robust error handling
- ✅ **Explorer links** - Direct links to Starkscan

### Main Features

1. **Automatic Verification**:
   - Verifies that Scarb is installed
   - Verifies that Starknet Foundry is installed
   - Verifies that the specified account exists

2. **Deployment Process**:
   - Contract compilation
   - Declaration and class hash retrieval
   - Deployment with constructor parameters
   - Confirmation verification

3. **Deployment Information**:
   - Automatically saves to JSON file
   - Includes timestamps and links
   - Complete deployment information

## 📄 Output Files

After a successful deployment, a JSON file is generated with the information:

```json
{
  "network": "sepolia",
  "account": "kliver",
  "rpc_url": "https://starknet-sepolia.public.blastapi.io/rpc/v0_8",
  "contract_name": "kliver_registry",
  "class_hash": "0x07c96f4fd2878fb6298c4754749e897f26d08d98f056305ff7bea596c7cbecf9",
  "contract_address": "0x01d4a1a07538737288a76231d06569f5327356dd0a201490ecfaa06ef13d16a2",
  "owner_address": "0x3763a82c5ac6506c9518d21820c38167bbf2b366a2bb30855830467639d6fbf",
  "deployment_timestamp": 1727984573.123,
  "deployment_date": "2025-10-03 15:42:53 UTC",
  "explorer_links": {
    "contract": "https://sepolia.starkscan.co/contract/0x01d4a1a07538737288a76231d06569f5327356dd0a201490ecfaa06ef13d16a2",
    "class": "https://sepolia.starkscan.co/class/0x07c96f4fd2878fb6298c4754749e897f26d08d98f056305ff7bea596c7cbecf9"
  }
}
```

## 🌐 Supported Networks

- **sepolia** - Sepolia Testnet (default)
- **alpha-sepolia** - Alpha Sepolia Testnet
- **mainnet** - StarkNet Mainnet

## 🎯 Usage Examples

```bash
# Deployment to Sepolia with kliver account
python deploy_contract.py -a kliver -n sepolia

# Deployment with specific owner
python deploy_contract.py -a kliver -n sepolia -o 0x123...

# Verbose deployment for debugging
python deploy_contract.py -a kliver -n sepolia --verbose

# Quick deployment (uses default configurations)
python quick_deploy.py
```

## 🔧 Custom Configuration

You can modify the `deployment_config.yml` file to:
- Add new networks
- Configure custom RPC URLs
- Adjust timeouts and retries
- Add account configurations

## ⚠️ Troubleshooting

### Error: "Account not found"
```bash
# List available accounts
sncast account list

# Create new account if necessary
sncast account create --name my_account
```

### Error: "Connection refused"
```bash
# Try with different RPC
python deploy_contract.py -a kliver -n sepolia -r https://another-rpc.com
```

### Error: "Compilation failed"
```bash
# Verify Scarb configuration
scarb --version
scarb check
```

## 📚 References

- [Starknet Book](https://book.starknet.io/)
- [Cairo Book](https://book.cairo-lang.org/)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/)
- [Scarb Documentation](https://docs.swmansion.com/scarb/)

---

**Happy Deploying! 🚀**