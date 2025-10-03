#!/usr/bin/env python3
"""
Quick Deploy Script - Simplified version for rapid deployment

This is a streamlined version of the deployment script for when you just
want to quickly deploy with default settings.
"""

import subprocess
import sys
from pathlib import Path

def quick_deploy():
    """Quick deployment with sensible defaults"""
    print("🚀 Quick KliverRegistry Deployment")
    print("-" * 40)
    
    # Default settings
    account = "kliver"
    network = "sepolia" 
    rpc_url = "https://starknet-sepolia.public.blastapi.io/rpc/v0_8"
    
    print(f"Account: {account}")
    print(f"Network: {network}")
    print(f"RPC: {rpc_url}")
    print("-" * 40)
    
    try:
        # Run the full deployment script
        cmd = [
            sys.executable, 
            "deploy_contract.py",
            "--account", account,
            "--network", network,
            "--rpc-url", rpc_url,
            "--verbose"
        ]
        
        subprocess.run(cmd, check=True, cwd=Path.cwd())
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Deployment failed with exit code: {e.returncode}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n⚠️  Deployment interrupted")
        sys.exit(1)

if __name__ == '__main__':
    quick_deploy()