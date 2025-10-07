# Kliver Contracts Deployment Guide 🚀

## Overview

This guide explains how to deploy Kliver smart contracts with proper NFT-gated authentication. The deployment script supports multiple modes to ensure flexibility and security.

## 🔑 Key Concept: NFT-Gated Registry

The **Kliver Registry** requires an **NFT contract address** during deployment. This NFT contract is used to validate that authors own a Kliver NFT before they can register characters, scenarios, or simulations.

### Architecture Flow

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

## 📋 Deployment Modes

### Mode 1: Complete Deployment (Recommended) ✅

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

---

### Mode 2: NFT Only Deployment

Deploy only the NFT contract.

```bash
python deploy_contract.py --environment dev --contract nft --owner 0x123...
```

**What happens:**
1. ✅ Deploys NFT contract
2. ✅ Saves NFT deployment info

**Use this when:** You need to deploy NFT first, then Registry later

---

### Mode 3: Registry Only Deployment (Requires NFT)

Deploy Registry using an existing NFT contract.

```bash
python deploy_contract.py --environment dev --contract registry --nft-address 0xABCDEF...
```

**What happens:**
1. ✅ Validates the NFT contract exists and is valid
2. ✅ Deploys Registry with the NFT address
3. ✅ Links them for author validation

**Use this when:** 
- NFT is already deployed
- Redeploying Registry with a different configuration

**⚠️ Important:** The script will **validate** that the NFT contract exists before deploying Registry!

---

## 🔒 NFT Validation

When deploying Registry separately (`--contract registry`), the script automatically validates:

1. **NFT Contract Exists**: Calls the NFT contract to verify it's deployed
2. **Valid NFT Contract**: Checks it responds to standard ERC721 methods
3. **Deployment Abort**: If validation fails, Registry deployment is aborted

This prevents misconfiguration and ensures the Registry always has a valid NFT reference.

---

## 🌍 Environment Configuration

Environments are defined in `deployment_config.yml`:

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

---

## 📝 Complete Examples

### Development Environment

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

### QA Environment

```bash
# Deploy complete system to QA
python deploy_contract.py --environment qa --contract all

# Or separate deployments
python deploy_contract.py --environment qa --contract nft --owner 0x5678...
python deploy_contract.py --environment qa --contract registry --nft-address 0xQA_NFT_ADDR
```

### Production Environment ⚠️

```bash
# PRODUCTION: Always deploy everything together for consistency
python deploy_contract.py --environment prod --contract all --owner 0xPROD_OWNER

# Only if absolutely necessary, deploy separately:
python deploy_contract.py --environment prod --contract nft --owner 0xPROD_OWNER
python deploy_contract.py --environment prod --contract registry --nft-address 0xPROD_NFT_ADDR
```

---

## 🎯 Common Workflows

### Workflow 1: Fresh Start

```bash
# Deploy everything at once
python deploy_contract.py --environment dev --contract all

# Output will show both contracts with their relationship
```

### Workflow 2: Incremental Deployment

```bash
# Step 1: Deploy NFT
python deploy_contract.py --environment dev --contract nft
# Output: NFT deployed at 0xABC123...

# Step 2: Deploy Registry using NFT address
python deploy_contract.py --environment dev --contract registry --nft-address 0xABC123...
# Script validates NFT before deploying Registry
```

### Workflow 3: Registry Upgrade

```bash
# Use existing NFT, redeploy only Registry
python deploy_contract.py --environment prod --contract registry --nft-address 0xEXISTING_NFT
```

---

## ⚠️ Error Handling

### Error: "NFT address is required for Registry deployment"

**Cause:** Trying to deploy Registry without specifying NFT address

**Solution:** 
```bash
# Either deploy everything:
python deploy_contract.py --environment dev --contract all

# Or provide NFT address:
python deploy_contract.py --environment dev --contract registry --nft-address 0x123...
```

### Error: "Invalid NFT contract address or contract not deployed"

**Cause:** Provided NFT address doesn't point to a valid deployed NFT contract

**Solution:**
1. Verify the NFT address is correct
2. Ensure the NFT is deployed on the same network
3. Check the NFT contract on explorer (e.g., Starkscan)

---

## 📊 Deployment Output

### Complete Deployment Output Example

```
🚀 COMPLETE DEPLOYMENT MODE
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

---

## 🔐 Security Notes

1. **Always validate NFT address**: The script does this automatically, but double-check in production
2. **Test on Sepolia first**: Use dev/qa environments before production
3. **Backup deployment info**: JSON files are saved automatically - keep them safe
4. **Verify on Explorer**: Always check deployed contracts on Starkscan

---

## 📞 Support

For issues or questions:
- Check `deployment_examples.sh` for more examples
- Review `DEPLOYMENT_README.md` for detailed docs
- Check deployment logs in saved JSON files

---

## 🎓 Understanding the Flow

```
User registers content → Registry checks author
                            ↓
                    Does author have NFT?
                            ↓
                    ┌───────┴───────┐
                   YES             NO
                    ↓               ↓
            Registration OK    Error: Must own NFT
```

The NFT address you provide during Registry deployment is **permanently stored** in the Registry contract and used for all future author validations!
