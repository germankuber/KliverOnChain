#!/bin/bash

# =============================================================================
# 🚀 KLIVER DEPLOYMENT - QUICK REFERENCE
# =============================================================================

cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════╗
║                   KLIVER CONTRACTS DEPLOYMENT                          ║
║                        Quick Reference Guide                           ║
╚════════════════════════════════════════════════════════════════════════╝

┌────────────────────────────────────────────────────────────────────────┐
│ 🎯 DEPLOYMENT MODES                                                    │
└────────────────────────────────────────────────────────────────────────┘

Mode 1: 🌟 COMPLETE DEPLOYMENT (Recommended)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deploys NFT first, then Registry with auto-linking

  python deploy_contract.py --environment dev --contract all

  ✅ Automatically links NFT → Registry
  ✅ No manual address entry needed
  ✅ Validates everything automatically

  Flow: NFT Deploy → Get NFT Address → Registry Deploy → Link


Mode 2: 📦 NFT-ONLY DEPLOYMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deploys only the NFT contract

  python deploy_contract.py --environment dev --contract nft

  ✅ Deploy NFT independently
  ✅ Save address for later Registry deployment
  ℹ️  Remember to note the NFT address!


Mode 3: 🔗 REGISTRY-ONLY DEPLOYMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deploys Registry using existing NFT (with validation!)

  python deploy_contract.py --environment dev --contract registry \
    --nft-address 0xYOUR_NFT_ADDRESS

  ✅ Validates NFT contract exists
  ✅ Checks NFT is properly deployed
  ❌ Aborts if NFT is invalid
  🔒 Links Registry to validated NFT


┌────────────────────────────────────────────────────────────────────────┐
│ 🏗️ ARCHITECTURE FLOW                                                   │
└────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────┐
  │   Kliver NFT    │ ← Users must own this NFT to register content
  └────────┬────────┘
           │
           │ (NFT address stored in constructor)
           │
           ▼
  ┌─────────────────┐
  │ Kliver Registry │ ← Validates NFT ownership on every registration
  └─────────────────┘
           │
           ├─→ register_character() → checks NFT ✓
           ├─→ register_scenario()   → checks NFT ✓
           └─→ register_simulation() → checks NFT ✓


┌────────────────────────────────────────────────────────────────────────┐
│ 💻 EXAMPLES BY ENVIRONMENT                                             │
└────────────────────────────────────────────────────────────────────────┘

🏗️  DEVELOPMENT (Sepolia Testnet)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  # Complete deployment
  python deploy_contract.py --environment dev --contract all

  # Separate deployments
  python deploy_contract.py --environment dev --contract nft
  python deploy_contract.py --environment dev --contract registry \
    --nft-address 0xNFT_FROM_ABOVE


🧪 QA (Sepolia Testnet)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  # Complete deployment
  python deploy_contract.py --environment qa --contract all

  # With custom owner
  python deploy_contract.py --environment qa --contract all \
    --owner 0x1234567890abcdef


🏭 PRODUCTION (Mainnet) ⚠️
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  # ⚠️ CAUTION: Always test on dev/qa first!
  python deploy_contract.py --environment prod --contract all \
    --owner 0xPRODUCTION_OWNER_ADDRESS


┌────────────────────────────────────────────────────────────────────────┐
│ ⚠️  IMPORTANT VALIDATIONS                                              │
└────────────────────────────────────────────────────────────────────────┘

When deploying Registry separately, the script will:

  1. ✅ Validate NFT contract address format
  2. ✅ Check if NFT contract is deployed
  3. ✅ Verify it responds to standard ERC721 methods
  4. ❌ ABORT deployment if validation fails

This prevents misconfiguration and ensures Registry always has a valid NFT!


┌────────────────────────────────────────────────────────────────────────┐
│ 📊 WHAT YOU'LL SEE                                                     │
└────────────────────────────────────────────────────────────────────────┘

Complete Deployment Output:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🚀 COMPLETE DEPLOYMENT MODE
  This will deploy NFT first, then Registry using the NFT address

  Step 1/2: Deploying NFT Contract
  ✓ Contract deployed at: 0x123NFT...

  Step 2/2: Deploying Registry Contract
  🔍 Validating NFT contract...
  ✓ NFT contract validated
  ✓ Contract deployed at: 0x456REGISTRY...

  ======================================================================
  🎉 DEPLOYMENT SUMMARY
  ======================================================================

  1. KLIVERNFT
     Address:    0x123NFT...
     Explorer:   https://sepolia.starkscan.co/contract/0x123NFT...

  2. KLIVER_REGISTRY
     Address:    0x456REGISTRY...
     Explorer:   https://sepolia.starkscan.co/contract/0x456REGISTRY...
     NFT Link:   0x123NFT...

  ℹ️  Registry is configured to use the NFT contract for author validation
  ======================================================================


┌────────────────────────────────────────────────────────────────────────┐
│ 🔒 SECURITY & VALIDATION                                               │
└────────────────────────────────────────────────────────────────────────┘

  ✅ Constructor Validation:
     - Registry REQUIRES nft_address parameter
     - Cannot deploy Registry without valid NFT

  ✅ Runtime Validation:
     - Every registration checks author NFT ownership
     - Authors without NFT are rejected immediately

  ✅ Deployment Validation:
     - Script verifies NFT exists before deploying Registry
     - Prevents broken configurations


┌────────────────────────────────────────────────────────────────────────┐
│ 🎓 WORKFLOW RECOMMENDATIONS                                            │
└────────────────────────────────────────────────────────────────────────┘

For Development/Testing:
  → Use Mode 1 (--contract all) for simplicity
  → Let the script handle linking automatically

For Production:
  → Use Mode 1 (--contract all) with explicit owner
  → Deploy everything together for consistency
  → Double-check on Starkscan before use

For Upgrades:
  → Keep existing NFT contract
  → Use Mode 3 to redeploy Registry only
  → Validate NFT address carefully


┌────────────────────────────────────────────────────────────────────────┐
│ 📞 NEED HELP?                                                          │
└────────────────────────────────────────────────────────────────────────┘

  📖 Full Guide:       DEPLOYMENT_GUIDE.md
  📝 More Examples:    deployment_examples.sh
  🔧 Script Help:      python deploy_contract.py --help

  🌐 Starkscan:        https://sepolia.starkscan.co
  📚 Docs:             DEPLOYMENT_README.md

EOF
