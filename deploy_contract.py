#!/usr/bin/env python3
"""
Kliver Contracts Deployment Script

This script automates the complete deployment process for Kliver contracts
including KliverRegistry and KliverNFT contracts to StarkNet.

Usage:
    python deploy_contract.py --account kliver --network sepolia --contract registry
    python deploy_contract.py --account kliver --network sepolia --contract nft --owner 0x123...
    python deploy_contract.py --account kliver --network sepolia --contract all
    python deploy_contract.py --help
"""

import click
import subprocess
import json
import time
import re
import yaml
from pathlib import Path
from colorama import Fore, Style, init
from typing import Optional, Dict, Any

# Initialize colorama for cross-platform colored output
init()

def load_environment_config(environment: str) -> Dict[str, Any]:
    """Load environment configuration from deployment_config.yml"""
    config_path = Path.cwd() / "deployment_config.yml"
    
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
    except ImportError:
        # Fallback if yaml is not available - create a simple parser
        import re
        with open(config_path, 'r') as f:
            content = f.read()
        
        # Simple YAML-like parsing for our specific structure
        config = {"environments": {}}
        lines = content.split('\n')
        current_env = None
        
        for line in lines:
            line = line.strip()
            if line.startswith('  dev:') or line.startswith('  qa:') or line.startswith('  prod:'):
                current_env = line.split(':')[0].strip()
                config["environments"][current_env] = {}
            elif current_env and ':' in line and not line.startswith('#'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip().strip('"')
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                config["environments"][current_env][key] = value
    
    if environment not in config.get("environments", {}):
        raise ValueError(f"Environment '{environment}' not found in configuration. Available: {list(config.get('environments', {}).keys())}")
    
    env_config = config["environments"][environment]
    
    # Ensure all required fields are present
    required_fields = ['network', 'rpc_url', 'account', 'name']
    for field in required_fields:
        if field not in env_config:
            raise ValueError(f"Missing required field '{field}' in environment '{environment}' configuration")
    
    return env_config

class Colors:
    """Color constants for terminal output"""
    SUCCESS = Fore.GREEN
    ERROR = Fore.RED
    WARNING = Fore.YELLOW
    INFO = Fore.BLUE
    BOLD = Style.BRIGHT
    RESET = Style.RESET_ALL

class ContractDeployer:
    """Main class for handling contract deployment operations"""
    
    def __init__(self, account: str, network: str, contract_type: str, rpc_url: Optional[str] = None):
        self.account = account
        self.network = network
        self.contract_type = contract_type
        self.rpc_url = rpc_url or self._get_default_rpc_url(network)
        
        # Define contract configurations
        self.contracts = {
            "registry": {
                "name": "kliver_registry",
                "class_name": "KliverRegistry"
            },
            "nft": {
                "name": "kliver_nft", 
                "class_name": "KliverNFT"
            }
        }
        
    def _get_default_rpc_url(self, network: str) -> str:
        """Get default RPC URL for the specified network"""
        rpc_urls = {
            "sepolia": "https://starknet-sepolia.public.blastapi.io/rpc/v0_8",
            "alpha-sepolia": "https://starknet-sepolia.public.blastapi.io/rpc/v0_8",
            "mainnet": "https://starknet-mainnet.public.blastapi.io/rpc/v0_8"
        }
        return rpc_urls.get(network, rpc_urls["sepolia"])
    
    def _run_command(self, command: list, description: str) -> Dict[str, Any]:
        """Execute a shell command and return the result"""
        print(f"{Colors.INFO}➤ {description}...{Colors.RESET}")
        print(f"{Colors.BOLD}Command: {' '.join(command)}{Colors.RESET}")
        
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True,
                cwd=Path.cwd()
            )
            
            print(f"{Colors.SUCCESS}✓ {description} completed successfully{Colors.RESET}")
            if result.stdout.strip():
                print(f"Output:\n{result.stdout}")
                
            return {
                "success": True,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
            
        except subprocess.CalledProcessError as e:
            print(f"{Colors.ERROR}✗ {description} failed{Colors.RESET}")
            print(f"Error: {e.stderr}")
            return {
                "success": False,
                "stdout": e.stdout,
                "stderr": e.stderr,
                "returncode": e.returncode
            }
    
    def check_prerequisites(self) -> bool:
        """Check if all required tools and configurations are available"""
        print(f"{Colors.BOLD}🔍 Checking prerequisites...{Colors.RESET}")
        
        # Check if scarb is installed
        scarb_check = self._run_command(["scarb", "--version"], "Checking Scarb installation")
        if not scarb_check["success"]:
            print(f"{Colors.ERROR}Scarb is not installed. Please install Scarb first.{Colors.RESET}")
            return False
            
        # Check if sncast is installed
        sncast_check = self._run_command(["sncast", "--version"], "Checking Starknet Foundry installation")
        if not sncast_check["success"]:
            print(f"{Colors.ERROR}Starknet Foundry (sncast) is not installed. Please install it first.{Colors.RESET}")
            return False
            
        # Check if account exists
        account_check = self._run_command(["sncast", "account", "list"], "Checking available accounts")
        if not account_check["success"]:
            return False
            
        if self.account not in account_check["stdout"]:
            print(f"{Colors.ERROR}Account '{self.account}' not found in available accounts{Colors.RESET}")
            return False
            
        print(f"{Colors.SUCCESS}✓ All prerequisites checked{Colors.RESET}")
        return True
    
    def get_account_info(self) -> Optional[str]:
        """Get account information and return the account address"""
        print(f"{Colors.BOLD}📋 Getting account information...{Colors.RESET}")
        
        result = self._run_command(["sncast", "account", "list"], "Retrieving account details")
        if not result["success"]:
            return None
            
        # Parse account address from output
        account_pattern = rf"{self.account}:.*?address: (0x[a-fA-F0-9]+)"
        match = re.search(account_pattern, result["stdout"], re.DOTALL)
        
        if match:
            address = match.group(1)
            print(f"{Colors.SUCCESS}✓ Found account '{self.account}' with address: {address}{Colors.RESET}")
            return address
        else:
            print(f"{Colors.ERROR}Could not parse address for account '{self.account}'{Colors.RESET}")
            return None
    
    def compile_contract(self) -> bool:
        """Compile the contract using Scarb"""
        print(f"\n{Colors.BOLD}🔨 Compiling contract...{Colors.RESET}")
        
        result = self._run_command(["scarb", "build"], "Compiling KliverRegistry contract")
        return result["success"]
    
    def declare_contract(self) -> Optional[str]:
        """Declare the contract and return the class hash"""
        contract_config = self.contracts[self.contract_type]
        contract_name = contract_config["name"]
        
        print(f"\n{Colors.BOLD}📤 Declaring contract...{Colors.RESET}")
        
        command = [
            "sncast", "--account", self.account, "declare",
            "--contract-name", contract_name,
            "--url", self.rpc_url
        ]
        
        result = self._run_command(command, f"Declaring {contract_name} to {self.network}")
        
        if not result["success"]:
            return None
            
        # Parse class hash from output
        class_hash_pattern = r"class_hash: (0x[a-fA-F0-9]+)"
        match = re.search(class_hash_pattern, result["stdout"])
        
        if match:
            class_hash = match.group(1)
            print(f"{Colors.SUCCESS}✓ Contract declared with class hash: {class_hash}{Colors.RESET}")
            return class_hash
        else:
            print(f"{Colors.ERROR}Could not parse class hash from declaration output{Colors.RESET}")
            return None
    
    def wait_for_transaction(self, tx_hash: str, max_attempts: int = 30) -> bool:
        """Wait for transaction confirmation"""
        print(f"{Colors.INFO}⏳ Waiting for transaction confirmation: {tx_hash}{Colors.RESET}")
        
        for attempt in range(max_attempts):
            command = [
                "sncast", "--account", self.account, "tx-status",
                tx_hash, "--url", self.rpc_url
            ]
            
            result = self._run_command(command, f"Checking transaction status (attempt {attempt + 1})")
            
            if result["success"] and "AcceptedOnL2" in result["stdout"]:
                print(f"{Colors.SUCCESS}✓ Transaction confirmed on L2{Colors.RESET}")
                return True
            elif result["success"] and "Succeeded" in result["stdout"]:
                print(f"{Colors.SUCCESS}✓ Transaction execution succeeded{Colors.RESET}")
                return True
                
            print(f"{Colors.WARNING}⏳ Transaction still pending... (attempt {attempt + 1}/{max_attempts}){Colors.RESET}")
            time.sleep(2)
            
        print(f"{Colors.ERROR}✗ Transaction confirmation timeout{Colors.RESET}")
        return False
    
    def deploy_contract(self, class_hash: str, owner_address: str) -> Optional[str]:
        """Deploy the contract and return the contract address"""
        print(f"\n{Colors.BOLD}🚀 Deploying contract...{Colors.RESET}")
        
        command = [
            "sncast", "--account", self.account, "deploy",
            "--class-hash", class_hash,
            "--constructor-calldata", owner_address,
            "--url", self.rpc_url
        ]
        
        contract_config = self.contracts[self.contract_type]
        contract_name = contract_config["name"]
        result = self._run_command(command, f"Deploying {contract_name} with owner {owner_address}")
        
        if not result["success"]:
            return None
            
        # Parse contract address from output
        contract_address_pattern = r"contract_address: (0x[a-fA-F0-9]+)"
        match = re.search(contract_address_pattern, result["stdout"])
        
        if match:
            contract_address = match.group(1)
            print(f"{Colors.SUCCESS}✓ Contract deployed at address: {contract_address}{Colors.RESET}")
            return contract_address
        else:
            print(f"{Colors.ERROR}Could not parse contract address from deployment output{Colors.RESET}")
            return None
    
    def save_deployment_info(self, class_hash: str, contract_address: str, owner_address: str):
        """Save deployment information to a JSON file"""
        deployment_info = {
            "network": self.network,
            "account": self.account,
            "rpc_url": self.rpc_url,
            "contract_name": self.contracts[self.contract_type]["name"],
            "class_hash": class_hash,
            "contract_address": contract_address,
            "owner_address": owner_address,
            "deployment_timestamp": time.time(),
            "deployment_date": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
            "explorer_links": {
                "contract": f"https://sepolia.starkscan.co/contract/{contract_address}",
                "class": f"https://sepolia.starkscan.co/class/{class_hash}"
            }
        }
        
        filename = f"deployment_{self.network}_{int(time.time())}.json"
        with open(filename, 'w') as f:
            json.dump(deployment_info, f, indent=2)
            
        print(f"{Colors.SUCCESS}✓ Deployment info saved to: {filename}{Colors.RESET}")
    
    def deploy_full_flow(self, owner_address: Optional[str] = None) -> bool:
        """Execute the complete deployment flow"""
        contract_config = self.contracts[self.contract_type]
        contract_name = contract_config["name"]
        
        print(f"{Colors.BOLD}🎯 Starting {contract_name} deployment to {self.network}{Colors.RESET}")
        print(f"Account: {self.account}")
        print(f"Contract Type: {self.contract_type}")
        print(f"RPC URL: {self.rpc_url}")
        print("-" * 60)
        
        # Check prerequisites
        if not self.check_prerequisites():
            return False
            
        # Get account info
        account_address = self.get_account_info()
        if not account_address:
            return False
            
        # Use account address as owner if not specified
        if not owner_address:
            owner_address = account_address
            print(f"{Colors.INFO}Using account address as contract owner: {owner_address}{Colors.RESET}")
            
        # Compile contract
        if not self.compile_contract():
            print(f"{Colors.ERROR}Compilation failed. Deployment aborted.{Colors.RESET}")
            return False
            
        # Declare contract
        class_hash = self.declare_contract()
        if not class_hash:
            print(f"{Colors.ERROR}Declaration failed. Deployment aborted.{Colors.RESET}")
            return False
            
        # Deploy contract
        contract_address = self.deploy_contract(class_hash, owner_address)
        if not contract_address:
            print(f"{Colors.ERROR}Deployment failed.{Colors.RESET}")
            return False
            
        # Save deployment info
        self.save_deployment_info(class_hash, contract_address, owner_address)
        
        # Print success summary
        print(f"\n{Colors.BOLD}{Colors.SUCCESS}🎉 DEPLOYMENT SUCCESSFUL! 🎉{Colors.RESET}")
        print("-" * 60)
        print(f"Network: {self.network}")
        print(f"Contract Type: {self.contract_type}")
        print(f"Contract Name: {contract_name}")
        print(f"Class Hash: {class_hash}")
        print(f"Contract Address: {contract_address}")
        print(f"Owner Address: {owner_address}")
        print(f"Explorer: https://sepolia.starkscan.co/contract/{contract_address}")
        print("-" * 60)
        
        return True

@click.command()
@click.option('--environment', '-e', required=True, help='Environment to deploy to: dev, qa, or prod')
@click.option('--contract', '-c', default='registry', help='Contract to deploy: registry, nft, or all')
@click.option('--rpc-url', '-r', help='Custom RPC URL (optional - overrides environment config)')
@click.option('--owner', '-o', help='Owner address for the contract (uses account address if not specified)')
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose output')
def deploy(environment: str, contract: str, rpc_url: Optional[str], owner: Optional[str], verbose: bool):
    """
    Deploy Kliver contracts to StarkNet using environment-based configuration
    
    This script handles the complete deployment process:
    1. Loads environment configuration (auto-selects network, account, etc.)
    2. Checks prerequisites (Scarb, Starknet Foundry)
    3. Compiles the contracts
    4. Declares the contracts to get class hashes
    5. Deploys the contract instances
    6. Saves deployment information
    
    Example usage:
        python deploy_contract.py --environment dev --contract registry
        python deploy_contract.py --environment qa --contract nft --owner 0x123...
        python deploy_contract.py --environment prod --contract all --owner 0x123...
    """
    
    try:
        # Load environment configuration
        try:
            env_config = load_environment_config(environment)
            account = env_config['account']
            network = env_config['network']
            if not rpc_url:
                rpc_url = env_config['rpc_url']
            
            click.echo(f"{Colors.SUCCESS}✓ Environment '{environment}' loaded:{Colors.RESET}")
            click.echo(f"  Environment: {env_config['name']}")
            click.echo(f"  Network: {network}")
            click.echo(f"  Account: {account}")
            click.echo(f"  RPC URL: {rpc_url}")
            
        except Exception as e:
            click.echo(f"{Colors.ERROR}❌ Failed to load environment config: {str(e)}{Colors.RESET}")
            exit(1)
        
        if contract not in ['registry', 'nft', 'all']:
            click.echo(f"{Colors.ERROR}❌ Invalid contract type. Use: registry, nft, or all{Colors.RESET}")
            exit(1)
            
        success = True
        
        if contract == 'all':
            # Deploy registry first
            deployer_registry = ContractDeployer(account, network, 'registry', rpc_url)
            registry_success = deployer_registry.deploy_full_flow(owner)
            
            # Deploy NFT second
            deployer_nft = ContractDeployer(account, network, 'nft', rpc_url)
            nft_success = deployer_nft.deploy_full_flow(owner)
            
            success = registry_success and nft_success
        else:
            deployer = ContractDeployer(account, network, contract, rpc_url)
            success = deployer.deploy_full_flow(owner)
        
        if success:
            click.echo(f"\n{Colors.SUCCESS}✅ Deployment completed successfully!{Colors.RESET}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Deployment failed. Check the logs above for details.{Colors.RESET}")
            exit(1)
            
    except KeyboardInterrupt:
        click.echo(f"\n{Colors.WARNING}⚠️  Deployment interrupted by user{Colors.RESET}")
        exit(1)
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Unexpected error: {str(e)}{Colors.RESET}")
        exit(1)

if __name__ == '__main__':
    deploy()