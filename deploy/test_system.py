#!/usr/bin/env python3
"""
Simple test script to verify the new deployment system works.
"""

import sys
from pathlib import Path

# Add the parent directory to sys.path so we can import from kliver_deploy
sys.path.insert(0, str(Path(__file__).parent))

from kliver_deploy.config import ConfigManager
from kliver_deploy.deployer import ContractDeployer

def test_config():
    """Test configuration loading."""
    print("🧪 Testing configuration loading...")
    
    try:
        config_manager = ConfigManager()
        env_config = config_manager.get_environment_config("qa")
        print(f"✅ Environment config loaded: {env_config.name}")
        
        contract_config = config_manager.get_contract_config("qa", "nft")
        print(f"✅ Contract config loaded: {contract_config.name}")
        
        return True
    except Exception as e:
        print(f"❌ Config test failed: {e}")
        return False

def test_deployer():
    """Test deployer initialization."""
    print("🧪 Testing deployer initialization...")
    
    try:
        deployer = ContractDeployer("qa", "nft")
        print(f"✅ Deployer initialized for: {deployer.contract_config.name}")
        return True
    except Exception as e:
        print(f"❌ Deployer test failed: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Testing new deployment system...\n")
    
    success = True
    success &= test_config()
    success &= test_deployer()
    
    if success:
        print("\n🎉 All tests passed! The new system should work.")
    else:
        print("\n❌ Some tests failed. Need to fix issues.")
    
    sys.exit(0 if success else 1)