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
    environment = "dev"
    
    print(f"Environment: {environment} (auto-configured)")
    print("-" * 40)
    
    try:
        # Run the full deployment script
        cmd = [
            sys.executable, 
            "deploy_contract.py",
            "--environment", environment,
            "--contract", "registry",
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