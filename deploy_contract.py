#!/usr/bin/env python3
"""
Kliver Contracts Deployment Script

This script automates the complete deployment process for Kliver contracts
including KliverRegistry and KliverNFT contracts to StarkNet.

Usag        print(f"{Colors.INFO}📤 Declaring {contract_name}...{Colors.RESET}")
        
        command = [
            "sncast", "--account", self.account, "declare",
            "--contract-name", contract_name,
            "--url", self.rpc_url
        ]
        
        result = self._run_command(command, f"Declaring {contract_name}")thon deploy_contract.py --account kliver --network sepolia --contract registry
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

    def __init__(self, account: str, network: str, contract_type: str, rpc_url: Optional[str] = None, env_config: Optional[Dict[str, Any]] = None):
        self.account = account
        self.network = network
        self.contract_type = contract_type
        self.rpc_url = rpc_url or self._get_default_rpc_url(network)
        self.env_config = env_config

        # Define contract configurations
        self.contracts = {
            "registry": {
                "name": "kliver_registry",
                "class_name": "KliverRegistry"
            },
            "nft": {
                "name": "KliverNFT",
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

    def _string_to_bytearray_calldata(self, text: str) -> list:
        """Convert a string to Cairo ByteArray calldata format [data_len, word1, word2, ..., pending_word, pending_word_len]"""
        if not text:
            return ["0", "0", "0"]

        # Encode string to bytes
        text_bytes = text.encode('utf-8')

        # Split into 31-byte chunks (Cairo felts can hold 31 bytes max)
        chunk_size = 31
        chunks = []

        for i in range(0, len(text_bytes), chunk_size):
            chunk = text_bytes[i:i + chunk_size]
            # Convert chunk to integer (big-endian)
            chunk_int = int.from_bytes(chunk, byteorder='big')
            chunks.append(str(chunk_int))

        # Last chunk becomes pending_word
        if chunks:
            pending_word = chunks[-1]
            full_words = chunks[:-1] if len(chunks) > 1 else []
            last_chunk_len = len(text_bytes) % chunk_size
            if last_chunk_len == 0 and len(text_bytes) > 0:
                last_chunk_len = chunk_size
        else:
            pending_word = "0"
            full_words = []
            last_chunk_len = 0

        # Format: [data_len, word1, word2, ..., pending_word, pending_word_len]
        result = [str(len(full_words))] + full_words + [pending_word, str(last_chunk_len)]
        return result
    
    def _run_command(self, command: list, description: str, show_output: bool = False) -> Dict[str, Any]:
        """Execute a shell command and return the result"""
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True,
                cwd=Path.cwd()
            )
            
            if show_output and result.stdout.strip():
                print(f"{Colors.INFO}➤ {description}...{Colors.RESET}")
                print(f"{result.stdout.strip()}")
                
            return {
                "success": True,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
            
        except subprocess.CalledProcessError as e:
            print(f"{Colors.ERROR}✗ {description} failed{Colors.RESET}")
            if e.stderr:
                print(f"{Colors.ERROR}Error: {e.stderr.strip()}{Colors.RESET}")
            return {
                "success": False,
                "stdout": e.stdout or "",
                "stderr": e.stderr or "",
                "returncode": e.returncode
            }
    
    def check_prerequisites(self) -> bool:
        """Check if all required tools and configurations are available"""
        print(f"{Colors.INFO}🔍 Checking prerequisites...{Colors.RESET}")
        
        # Check Scarb
        result = self._run_command(["scarb", "--version"], "Checking Scarb")
        if not result["success"]:
            print(f"{Colors.ERROR}✗ Scarb not found. Please install Scarb first.{Colors.RESET}")
            return False
        
        # Check Starknet Foundry
        result = self._run_command(["sncast", "--version"], "Checking Starknet Foundry")
        if not result["success"]:
            print(f"{Colors.ERROR}✗ Starknet Foundry not found. Please install Starknet Foundry first.{Colors.RESET}")
            return False
        
        # Check available accounts (silently)
        result = self._run_command(["sncast", "account", "list"], "Checking accounts")
        if not result["success"]:
            print(f"{Colors.ERROR}✗ Could not access accounts. Please check your Starknet configuration.{Colors.RESET}")
            return False
            
        print(f"{Colors.SUCCESS}✓ Prerequisites OK{Colors.RESET}")
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
        print(f"{Colors.INFO}🔨 Compiling contracts...{Colors.RESET}")
        
        result = self._run_command(["scarb", "build"], "Compiling contracts")
        if result["success"]:
            print(f"{Colors.SUCCESS}✓ Compilation successful{Colors.RESET}")
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
        
        # Handle both success and "already declared" cases
        all_output = result.get("stdout", "") + result.get("stderr", "")
        
        # First check if we have a successful new declaration
        # Support both formats: "class_hash: 0x..." and "Class Hash:       0x..."
        class_hash_pattern = r"(?:class_hash:|Class Hash:)\s*(0x[a-fA-F0-9]+)"
        tx_hash_pattern = r"(?:transaction_hash:|Transaction Hash:)\s*(0x[a-fA-F0-9]+)"
        
        class_hash_match = re.search(class_hash_pattern, all_output)
        
        if class_hash_match:
            # Case 1: New declaration successful - we found class_hash in output
            class_hash = class_hash_match.group(1)
            print(f"{Colors.SUCCESS}✓ Contract declared with class hash: {class_hash}{Colors.RESET}")
            
            # Check for transaction hash and wait for confirmation
            tx_hash_match = re.search(tx_hash_pattern, all_output)
            if tx_hash_match:
                tx_hash = tx_hash_match.group(1)
                print(f"{Colors.INFO}📋 Transaction hash: {tx_hash}{Colors.RESET}")
                
                if not self.wait_for_transaction(tx_hash):
                    print(f"{Colors.ERROR}Declaration transaction not confirmed. Deployment may fail.{Colors.RESET}")
                    return None
            
            return class_hash
            
        else:
            # Case 2: No class_hash found - check if it's "already declared" error
            already_declared_pattern = r"Class with hash (0x[a-fA-F0-9]+) is already declared"
            
            match = re.search(already_declared_pattern, all_output)
            if match:
                class_hash = match.group(1)
                print(f"{Colors.SUCCESS}✓ Contract already declared with class hash: {class_hash}{Colors.RESET}")
                print(f"{Colors.INFO}ℹ️  Skipping declaration, proceeding with deployment...{Colors.RESET}")
                return class_hash
            
            # Case 3: Command succeeded but no class_hash found (probably already declared but different message format)
            elif result["success"]:
                print(f"{Colors.WARNING}⚠️  Declaration command succeeded but no class hash found in output{Colors.RESET}")
                print(f"{Colors.WARNING}This usually means the contract was already declared. Please check manually or use --force{Colors.RESET}")
                print(f"{Colors.ERROR}Full output: {all_output}{Colors.RESET}")
                return None
            
            else:
                # Case 4: Actual failure
                print(f"{Colors.ERROR}Declaration failed{Colors.RESET}")
                print(f"{Colors.ERROR}Error: {all_output}{Colors.RESET}")
                return None
    
    def wait_for_transaction(self, tx_hash: str, max_attempts: int = 60) -> bool:
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
                
            if attempt < max_attempts - 1:  # Don't sleep on the last attempt
                print(f"{Colors.WARNING}⏳ Transaction still pending... waiting 5 seconds (attempt {attempt + 1}/{max_attempts}){Colors.RESET}")
                time.sleep(5)
            
        print(f"{Colors.ERROR}✗ Transaction confirmation timeout after {max_attempts * 5} seconds{Colors.RESET}")
        return False
    
    def deploy_contract(self, class_hash: str, owner_address: str, nft_address: Optional[str] = None) -> Optional[str]:
        """Deploy the contract and return the contract address"""
        contract_config = self.contracts[self.contract_type]
        contract_name = contract_config["name"]

        print(f"{Colors.INFO}🚀 Deploying {contract_name}...{Colors.RESET}")

        # Build constructor calldata based on contract type
        if self.contract_type == "nft":
            # NFT requires: owner + base_uri (ByteArray)
            # Get base_uri from environment config
            base_uri = ""
            if self.env_config and "contracts" in self.env_config:
                nft_config = self.env_config["contracts"].get("nft", {})
                base_uri = nft_config.get("base_uri", "")

            if base_uri:
                print(f"{Colors.INFO}📋 Using base URI: {base_uri}{Colors.RESET}")
                base_uri_calldata = self._string_to_bytearray_calldata(base_uri)
            else:
                print(f"{Colors.WARNING}⚠️  No base_uri configured, using empty ByteArray{Colors.RESET}")
                base_uri_calldata = ["0", "0", "0"]

            constructor_calldata = [owner_address] + base_uri_calldata
        elif self.contract_type == "registry":
            # Registry requires: owner + nft_address
            if not nft_address:
                print(f"{Colors.ERROR}✗ NFT address is required for Registry deployment{Colors.RESET}")
                return None
            print(f"{Colors.INFO}📋 Using NFT address: {nft_address}{Colors.RESET}")
            constructor_calldata = [owner_address, nft_address]
        else:
            # Other contracts require only owner
            constructor_calldata = [owner_address]

        command = [
            "sncast", "--account", self.account, "deploy",
            "--class-hash", class_hash,
            "--constructor-calldata"
        ] + constructor_calldata + ["--url", self.rpc_url]
        
        result = self._run_command(command, f"Deploying {contract_name}")
        
        if not result["success"]:
            return None
            
        # Parse contract address from output
        # Support both formats: "contract_address: 0x..." and "Contract Address: 0x..."
        contract_address_pattern = r"(?:contract_address:|Contract Address:)\s*(0x[a-fA-F0-9]+)"
        match = re.search(contract_address_pattern, result["stdout"])
        
        if match:
            contract_address = match.group(1)
            print(f"{Colors.SUCCESS}✓ Contract deployed at address: {contract_address}{Colors.RESET}")
            
            # Look for transaction hash and wait for confirmation
            tx_hash_pattern = r"(?:transaction_hash:|Transaction Hash:)\s*(0x[a-fA-F0-9]+)"
            tx_match = re.search(tx_hash_pattern, result["stdout"])
            if tx_match:
                tx_hash = tx_match.group(1)
                print(f"{Colors.INFO}📋 Deployment transaction hash: {tx_hash}{Colors.RESET}")
                
                # CRITICAL: Wait for deployment transaction to be confirmed before proceeding
                print(f"{Colors.BOLD}⏳ Waiting for deployment to be confirmed on the network...{Colors.RESET}")
                if not self.wait_for_transaction(tx_hash):
                    print(f"{Colors.ERROR}✗ Deployment transaction not confirmed. Contract may not be available yet.{Colors.RESET}")
                    return None
                    
                print(f"{Colors.SUCCESS}✓ Contract deployment confirmed on L2!{Colors.RESET}")
            else:
                print(f"{Colors.WARNING}⚠️  No transaction hash found in deployment output{Colors.RESET}")
            
            return contract_address
        else:
            print(f"{Colors.ERROR}Could not parse contract address from deployment output{Colors.RESET}")
            print(f"{Colors.ERROR}Full output for debugging:{Colors.RESET}")
            print(f"{result['stdout']}")
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
    
    def validate_nft_contract(self, nft_address: str) -> bool:
        """Validate that the provided address is a valid NFT contract"""
        print(f"{Colors.INFO}🔍 Validating NFT contract at {nft_address}...{Colors.RESET}")
        
        # Try to call a method on the NFT contract to validate it exists and is an NFT
        command = [
            "sncast", "--account", self.account, "call",
            "--contract-address", nft_address,
            "--function", "name",  # Standard ERC721 function
            "--url", self.rpc_url
        ]
        
        result = self._run_command(command, "Validating NFT contract")
        
        if result["success"]:
            print(f"{Colors.SUCCESS}✓ NFT contract validated successfully{Colors.RESET}")
            return True
        else:
            print(f"{Colors.ERROR}✗ Invalid NFT contract address or contract not deployed{Colors.RESET}")
            print(f"{Colors.ERROR}Please ensure the NFT contract is deployed first{Colors.RESET}")
            return False

    def deploy_full_flow(self, owner_address: Optional[str] = None, nft_address: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Execute the complete deployment flow for a single contract"""
        contract_config = self.contracts[self.contract_type]
        contract_name = contract_config["name"]
        
        print(f"{Colors.BOLD}🎯 Deploying {contract_name} to {self.network}{Colors.RESET}")
        print(f"{Colors.INFO}Account: {self.account} | Network: {self.network}{Colors.RESET}")
        print("-" * 50)
        
        # Check prerequisites
        if not self.check_prerequisites():
            return None
            
        # Get account info
        account_address = self.get_account_info()
        if not account_address:
            return None
            
        # Use account address as owner if not specified
        if not owner_address:
            owner_address = account_address
            print(f"{Colors.INFO}Owner: {owner_address[:10]}...{owner_address[-4:]}{Colors.RESET}")
        
        # Validate NFT address if deploying registry
        if self.contract_type == "registry":
            if not nft_address:
                print(f"{Colors.ERROR}✗ NFT address is required for Registry deployment{Colors.RESET}")
                print(f"{Colors.INFO}Use --nft-address option or deploy with --contract all{Colors.RESET}")
                return None
            
            if not self.validate_nft_contract(nft_address):
                return None
            
        # Compile contract
        if not self.compile_contract():
            print(f"{Colors.ERROR}✗ Compilation failed{Colors.RESET}")
            return None
            
        # Declare contract
        class_hash = self.declare_contract()
        if not class_hash:
            print(f"{Colors.ERROR}Declaration failed. Deployment aborted.{Colors.RESET}")
            return None
            
        # Deploy contract
        contract_address = self.deploy_contract(class_hash, owner_address, nft_address)
        if not contract_address:
            print(f"{Colors.ERROR}Deployment failed.{Colors.RESET}")
            return None
            
        # Save deployment info
        self.save_deployment_info(class_hash, contract_address, owner_address)
        
        # Print success summary
        print(f"\n{Colors.SUCCESS}🎉 DEPLOYMENT SUCCESSFUL!{Colors.RESET}")
        print(f"{Colors.BOLD}Contract: {Colors.SUCCESS}{contract_address}{Colors.RESET}")
        print(f"{Colors.BOLD}Explorer: {Colors.INFO}https://sepolia.starkscan.co/contract/{contract_address}{Colors.RESET}")
        print(f"Class Hash: {class_hash}")
        print(f"Network: {self.network} | Owner: {owner_address[:10]}...{owner_address[-4:]}")
        if nft_address:
            print(f"NFT Contract: {nft_address}")
        
        # Return deployment info for summary
        return {
            "contract_name": self.contracts[self.contract_type]["name"],
            "contract_address": contract_address,
            "class_hash": class_hash,
            "network": self.network,
            "owner": owner_address,
            "nft_address": nft_address if nft_address else None
        }

@click.command()
@click.option('--environment', '-e', required=True, help='Environment to deploy to: dev, qa, or prod')
@click.option('--contract', '-c', default='registry', help='Contract to deploy: registry, nft, or all')
@click.option('--rpc-url', '-r', help='Custom RPC URL (optional - overrides environment config)')
@click.option('--owner', '-o', help='Owner address for the contract (uses account address if not specified)')
@click.option('--nft-address', '-n', help='NFT contract address (required when deploying registry separately)')
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose output')
def deploy(environment: str, contract: str, rpc_url: Optional[str], owner: Optional[str], nft_address: Optional[str], verbose: bool):
    """
    Deploy Kliver contracts to StarkNet using environment-based configuration
    
    This script handles the complete deployment process:
    1. Loads environment configuration (auto-selects network, account, etc.)
    2. Checks prerequisites (Scarb, Starknet Foundry)
    3. Compiles the contracts
    4. Declares the contracts to get class hashes
    5. Deploys the contract instances
    6. Saves deployment information
    
    DEPLOYMENT MODES:
    
    1. Deploy Everything (NFT + Registry):
        python deploy_contract.py --environment dev --contract all
        This will deploy NFT first, then use its address for Registry
    
    2. Deploy NFT Only:
        python deploy_contract.py --environment dev --contract nft --owner 0x123...
    
    3. Deploy Registry Only (requires NFT address):
        python deploy_contract.py --environment dev --contract registry --nft-address 0x456...
        The script will validate that the NFT contract exists before deploying Registry
    
    Example usage:
        python deploy_contract.py --environment dev --contract all
        python deploy_contract.py --environment qa --contract nft --owner 0x123...
        python deploy_contract.py --environment prod --contract registry --nft-address 0x456...
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
            
        deployments = []
        success = True
        
        if contract == 'all':
            click.echo(f"\n{Colors.BOLD}🚀 COMPLETE DEPLOYMENT MODE{Colors.RESET}")
            click.echo(f"{Colors.INFO}This will deploy NFT first, then Registry using the NFT address{Colors.RESET}\n")
            
            # Step 1: Deploy NFT first
            click.echo(f"{Colors.BOLD}Step 1/2: Deploying NFT Contract{Colors.RESET}")
            deployer_nft = ContractDeployer(account, network, 'nft', rpc_url, env_config)
            nft_result = deployer_nft.deploy_full_flow(owner)
            if nft_result:
                deployments.append(nft_result)
                nft_deployed_address = nft_result['contract_address']
                click.echo(f"\n{Colors.SUCCESS}✓ NFT deployed successfully at: {nft_deployed_address}{Colors.RESET}\n")
            else:
                success = False
                click.echo(f"\n{Colors.ERROR}✗ NFT deployment failed. Aborting.{Colors.RESET}")

            # Step 2: Deploy Registry using NFT address
            if success:
                click.echo(f"{Colors.BOLD}Step 2/2: Deploying Registry Contract{Colors.RESET}")
                deployer_registry = ContractDeployer(account, network, 'registry', rpc_url, env_config)
                registry_result = deployer_registry.deploy_full_flow(owner, nft_deployed_address)
                if registry_result:
                    deployments.append(registry_result)
                    click.echo(f"\n{Colors.SUCCESS}✓ Registry deployed successfully{Colors.RESET}\n")
                else:
                    success = False
                    click.echo(f"\n{Colors.ERROR}✗ Registry deployment failed{Colors.RESET}")
        
        elif contract == 'registry':
            # Deploying registry separately - requires NFT address
            if not nft_address:
                click.echo(f"\n{Colors.ERROR}❌ NFT address is required when deploying Registry separately{Colors.RESET}")
                click.echo(f"{Colors.INFO}Use: --nft-address 0x... or deploy with --contract all{Colors.RESET}\n")
                exit(1)
            
            click.echo(f"\n{Colors.BOLD}🎯 SEPARATE REGISTRY DEPLOYMENT{Colors.RESET}")
            click.echo(f"{Colors.INFO}Using NFT contract at: {nft_address}{Colors.RESET}\n")
            
            deployer = ContractDeployer(account, network, contract, rpc_url, env_config)
            result = deployer.deploy_full_flow(owner, nft_address)
            if result:
                deployments.append(result)
            else:
                success = False
        
        else:  # NFT only
            click.echo(f"\n{Colors.BOLD}🎯 NFT-ONLY DEPLOYMENT{Colors.RESET}\n")
            deployer = ContractDeployer(account, network, contract, rpc_url, env_config)
            result = deployer.deploy_full_flow(owner)
            if result:
                deployments.append(result)
            else:
                success = False
        
        # Show final summary
        if success and deployments:
            print_deployment_summary(deployments, network)
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

def print_deployment_summary(deployments: list, network: str):
    """Print a clean summary of all deployments"""
    if not deployments:
        return
        
    print(f"\n{Colors.BOLD}{'='*70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.SUCCESS}🎉 DEPLOYMENT SUMMARY{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*70}{Colors.RESET}")
    
    nft_address = None
    registry_deployment = None
    
    for i, deployment in enumerate(deployments, 1):
        contract_name = deployment['contract_name']
        contract_address = deployment['contract_address']
        
        # Track NFT address for later
        if contract_name == "KliverNFT":
            nft_address = contract_address
        
        # Track registry deployment
        if contract_name == "kliver_registry":
            registry_deployment = deployment
        
        print(f"\n{Colors.BOLD}{i}. {contract_name.upper()}{Colors.RESET}")
        print(f"   Address:    {Colors.SUCCESS}{Colors.BOLD}{contract_address}{Colors.RESET}")
        print(f"   Explorer:   {Colors.INFO}https://sepolia.starkscan.co/contract/{contract_address}{Colors.RESET}")
        print(f"   Class Hash: {deployment['class_hash'][:10]}...{deployment['class_hash'][-8:]}")
        
        # Show NFT address if this is registry and we have NFT info
        if contract_name == "kliver_registry" and deployment.get('nft_address'):
            print(f"   NFT Link:   {Colors.WARNING}{deployment['nft_address']}{Colors.RESET}")
    
    print(f"\n{Colors.BOLD}Network: {network.upper()} | Owner: {deployments[0]['owner'][:10]}...{deployments[0]['owner'][-4:]}{Colors.RESET}")
    
    # Show relationship if both were deployed
    if nft_address and registry_deployment:
        print(f"\n{Colors.INFO}ℹ️  Registry is configured to use the NFT contract for author validation{Colors.RESET}")
    
    print(f"{Colors.BOLD}{'='*70}{Colors.RESET}")

if __name__ == '__main__':
    deploy()