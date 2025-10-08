#!/usr/bin/env python3
"""
Debug script to see exactly what configuration is being loaded.
"""

import sys
from pathlib import Path

# Add the parent directory to sys.path so we can import from kliver_deploy
sys.path.insert(0, str(Path(__file__).parent))

from kliver_deploy.config import ConfigManager

def debug_config():
    """Debug configuration loading."""
    print("🔍 Debugging configuration loading...")
    
    config_manager = ConfigManager()
    print(f"Config path: {config_manager.config_path}")
    print(f"Config exists: {config_manager.config_path.exists()}")
    
    if config_manager.config_path.exists():
        config = config_manager.load_config()
        nft_config = config['environments']['qa']['contracts']['nft']
        print(f"NFT config name: {nft_config['name']}")
        print(f"NFT config sierra_file: {nft_config['sierra_file']}")
        print(f"NFT config base_uri: {nft_config.get('base_uri', 'N/A')}")

if __name__ == "__main__":
    debug_config()