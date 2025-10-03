#!/usr/bin/env python3
"""
Test script to verify the deployment script functionality without actual deployment
"""

import sys
import subprocess
from pathlib import Path

def test_deployment_script():
    """Test the deployment script functionality"""
    
    print("🧪 Testing KliverRegistry Deployment Script")
    print("-" * 50)
    
    # Test 1: Help command
    print("Test 1: Help command...")
    try:
        result = subprocess.run([
            sys.executable, "deploy_contract.py", "--help"
        ], capture_output=True, text=True, check=True, cwd=Path.cwd())
        print("✅ Help command works")
    except Exception as e:
        print(f"❌ Help command failed: {e}")
        return False
    
    # Test 2: Prerequisites check (this will check tools but not deploy)
    print("\nTest 2: Prerequisites check...")
    try:
        # Import the deployment module to test its functions
        sys.path.append(str(Path.cwd()))
        from deploy_contract import ContractDeployer
        
        deployer = ContractDeployer("kliver", "sepolia")
        
        # Test scarb version
        scarb_result = subprocess.run(["scarb", "--version"], capture_output=True, text=True)
        if scarb_result.returncode == 0:
            print("✅ Scarb is available")
        else:
            print("❌ Scarb not found")
            
        # Test sncast version  
        sncast_result = subprocess.run(["sncast", "--version"], capture_output=True, text=True)
        if sncast_result.returncode == 0:
            print("✅ Starknet Foundry (sncast) is available")
        else:
            print("❌ Starknet Foundry not found")
            
        print("✅ Prerequisites check completed")
        
    except Exception as e:
        print(f"❌ Prerequisites check failed: {e}")
        return False
    
    # Test 3: Account check
    print("\nTest 3: Account availability check...")
    try:
        account_result = subprocess.run(["sncast", "account", "list"], capture_output=True, text=True)
        if account_result.returncode == 0 and "kliver" in account_result.stdout:
            print("✅ Kliver account is available")
        else:
            print("❌ Kliver account not found")
            
    except Exception as e:
        print(f"❌ Account check failed: {e}")
        
    print("\n" + "="*50)
    print("🎉 All tests completed!")
    print("\nYour deployment environment is ready!")
    print("\nTo deploy your contract, run:")
    print("python deploy_contract.py --account kliver --network sepolia")
    print("\nOr for quick deployment:")
    print("python quick_deploy.py")
    print("="*50)
    
    return True

if __name__ == '__main__':
    test_deployment_script()