#!/bin/bash

# =============================================================================
# Kliver Contracts Deployment Examples by Environment
# =============================================================================

echo "🚀 Kliver Contracts Deployment Examples"
echo "========================================"

echo "🏗️  DEVELOPMENT ENVIRONMENT (Auto: Sepolia Testnet)"
echo "---------------------------------------------------"
echo "📝 Example 1a: Deploy Registry (Development)"
echo "Command: python deploy_contract.py --environment dev --contract registry"
echo ""
echo "📝 Example 1b: Deploy NFT (Development)"
echo "Command: python deploy_contract.py --environment dev --contract nft --owner 0x1234567890abcdef"
echo ""
echo "📝 Example 1c: Deploy Both (Development)"
echo "Command: python deploy_contract.py --environment dev --contract all --owner 0x1234567890abcdef"
echo ""

echo "🧪 QA ENVIRONMENT (Auto: Sepolia Testnet)"
echo "-----------------------------------------"
echo "📝 Example 2a: Deploy Registry (QA)"
echo "Command: python deploy_contract.py --environment qa --contract registry"
echo ""
echo "📝 Example 2b: Deploy NFT (QA)"
echo "Command: python deploy_contract.py --environment qa --contract nft --owner 0x1234567890abcdef"
echo ""
echo "📝 Example 2c: Deploy Both (QA)"
echo "Command: python deploy_contract.py --environment qa --contract all --owner 0x1234567890abcdef"
echo ""

echo "🏭 PRODUCTION ENVIRONMENT (Auto: Mainnet) ⚠️"
echo "--------------------------------------------"
echo "📝 Example 3a: Deploy Registry (Production)"
echo "Command: python deploy_contract.py --environment prod --contract registry"
echo ""
echo "📝 Example 3b: Deploy NFT (Production)"
echo "Command: python deploy_contract.py --environment prod --contract nft --owner 0x1234567890abcdef"
echo ""
echo "📝 Example 3c: Deploy Both (Production) ⚠️ CAUTION"
echo "Command: python deploy_contract.py --environment prod --contract all --owner 0x1234567890abcdef"
echo ""

# Quick Development Options
echo "⚡ QUICK DEVELOPMENT OPTIONS"
echo "---------------------------"
echo "📝 Example 4: Quick Development Deploy"
echo "Command: python quick_deploy.py"
echo ""
echo "📝 Example 5: Verbose Development Deploy"
echo "Command: python deploy_contract.py --environment dev --contract all --verbose --owner 0x123..."
echo ""
echo "📝 Example 6: Custom RPC Development"
echo "Command: python deploy_contract.py --environment dev --contract all --rpc-url https://my-custom-rpc.com --owner 0x123..."
echo ""

echo "======================================"
echo "🎯 Choose deployment environment and contract:"
echo ""
echo "🏗️  DEV (Auto: Sepolia)"
echo "1) Registry only"
echo "2) NFT only"  
echo "3) Both contracts"
echo ""
echo "🧪 QA (Auto: Sepolia)"
echo "4) Registry only"
echo "5) NFT only"
echo "6) Both contracts"
echo ""
echo "🏭 PROD (Auto: Mainnet) ⚠️"
echo "7) Registry only"
echo "8) NFT only"
echo "9) Both contracts"
echo ""
echo "⚡ UTILITIES"
echo "10) Quick deploy (dev)"
echo "11) Test environment"
echo "12) Exit"
echo ""

read -p "Enter your choice (1-12): " choice

case $choice in
    # DEVELOPMENT ENVIRONMENT
    1)
        echo "🏗️  Running Registry deployment (DEV → Sepolia)..."
        python deploy_contract.py --environment dev --contract registry
        ;;
    2)
        read -p "Enter owner address: " owner
        echo "🏗️  Running NFT deployment (DEV → Sepolia)..."
        python deploy_contract.py --environment dev --contract nft --owner $owner
        ;;
    3)
        read -p "Enter owner address: " owner
        echo "🏗️  Running deployment of both contracts (DEV → Sepolia)..."
        python deploy_contract.py --environment dev --contract all --owner $owner
        ;;
    
    # QA ENVIRONMENT
    4)
        echo "🧪 Running Registry deployment (QA → Sepolia)..."
        python deploy_contract.py --environment qa --contract registry
        ;;
    5)
        read -p "Enter owner address: " owner
        echo "🧪 Running NFT deployment (QA → Sepolia)..."
        python deploy_contract.py --environment qa --contract nft --owner $owner
        ;;
    6)
        read -p "Enter owner address: " owner
        echo "🧪 Running deployment of both contracts (QA → Sepolia)..."
        python deploy_contract.py --environment qa --contract all --owner $owner
        ;;
    
    # PRODUCTION ENVIRONMENT
    7)
        echo "⚠️  🏭 PRODUCTION DEPLOYMENT - Registry only (PROD → Mainnet)"
        read -p "Are you SURE you want to deploy to MAINNET? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            python deploy_contract.py --environment prod --contract registry
        else
            echo "Deployment cancelled."
        fi
        ;;
    8)
        echo "⚠️  🏭 PRODUCTION DEPLOYMENT - NFT only (PROD → Mainnet)"
        read -p "Are you SURE you want to deploy to MAINNET? (yes/no): " confirm
        read -p "Enter owner address: " owner
        if [ "$confirm" = "yes" ]; then
            python deploy_contract.py --environment prod --contract nft --owner $owner
        else
            echo "Deployment cancelled."
        fi
        ;;
    9)
        echo "⚠️  🏭 PRODUCTION DEPLOYMENT - Both contracts (PROD → Mainnet)"
        read -p "Are you ABSOLUTELY SURE you want to deploy BOTH contracts to MAINNET? (yes/no): " confirm
        read -p "Enter owner address: " owner
        if [ "$confirm" = "yes" ]; then
            python deploy_contract.py --environment prod --contract all --owner $owner
        else
            echo "Deployment cancelled."
        fi
        ;;
    
    # UTILITIES
    10)
        echo "⚡ Running quick development deployment..."
        python quick_deploy.py
        ;;
    11)
        echo "🧪 Testing deployment environment..."
        python test_deployment.py
        ;;
    12)
        echo "Goodbye! 👋"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac