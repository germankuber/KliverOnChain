#!/bin/bash

# =============================================================================
# KliverRegistry Deployment Examples
# =============================================================================

echo "🚀 KliverRegistry Deployment Examples"
echo "======================================"

# Example 1: Basic deployment to Sepolia testnet
echo ""
echo "📝 Example 1: Basic Deployment"
echo "Command: python deploy_contract.py --account kliver --network sepolia"
echo ""

# Example 2: Deployment with custom owner
echo "📝 Example 2: Custom Owner"
echo "Command: python deploy_contract.py --account kliver --network sepolia --owner 0x1234567890abcdef"
echo ""

# Example 3: Deployment with custom RPC
echo "📝 Example 3: Custom RPC"
echo "Command: python deploy_contract.py --account kliver --network sepolia --rpc-url https://my-custom-rpc.com"
echo ""

# Example 4: Quick deployment
echo "📝 Example 4: Quick Deployment (recommended for development)"
echo "Command: python quick_deploy.py"
echo ""

# Example 5: Verbose deployment for debugging
echo "📝 Example 5: Verbose Deployment"
echo "Command: python deploy_contract.py --account kliver --network sepolia --verbose"
echo ""

echo "======================================"
echo "Choose an example to run:"
echo "1) Basic deployment"
echo "2) Custom owner deployment"  
echo "3) Custom RPC deployment"
echo "4) Quick deployment"
echo "5) Verbose deployment"
echo "6) Test deployment environment"
echo "7) Exit"
echo ""

read -p "Enter your choice (1-7): " choice

case $choice in
    1)
        echo "Running basic deployment..."
        python deploy_contract.py --account kliver --network sepolia
        ;;
    2)
        read -p "Enter owner address: " owner
        echo "Running custom owner deployment..."
        python deploy_contract.py --account kliver --network sepolia --owner $owner
        ;;
    3)
        read -p "Enter RPC URL: " rpc
        echo "Running custom RPC deployment..."
        python deploy_contract.py --account kliver --network sepolia --rpc-url $rpc
        ;;
    4)
        echo "Running quick deployment..."
        python quick_deploy.py
        ;;
    5)
        echo "Running verbose deployment..."
        python deploy_contract.py --account kliver --network sepolia --verbose
        ;;
    6)
        echo "Testing deployment environment..."
        python test_deployment.py
        ;;
    7)
        echo "Goodbye! 👋"
        exit 0
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac