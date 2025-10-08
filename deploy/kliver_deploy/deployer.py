"""
Main deployment orchestrator for Kliver contracts.
"""

import json
import time
from pathlib import Path
from typing import Optional, Dict, Any

from .config import ConfigManager, NetworkConfig, ContractConfig, DeploymentSettings
from .contracts import get_contract, BaseContract
from .utils import CommandRunner, StarknetUtils, TransactionWaiter, Colors, format_address


class ContractDeployer:
    """Main class for handling contract deployment operations."""

    def __init__(self, environment: str, contract_type: str, config_manager: Optional[ConfigManager] = None):
        """
        Initialize ContractDeployer.
        
        Args:
            environment: Target environment (dev, qa, prod)
            contract_type: Type of contract to deploy
            config_manager: Optional ConfigManager instance
        """
        self.environment = environment
        self.contract_type = contract_type
        self.config_manager = config_manager or ConfigManager()
        
        # Load configurations
        self.network_config = self.config_manager.get_environment_config(environment)
        self.contract_config = self.config_manager.get_contract_config(environment, contract_type)
        self.deployment_settings = self.config_manager.get_deployment_settings(environment)
        
        # Get contract instance
        self.contract = get_contract(contract_type)
        
        # Initialize transaction waiter
        self.tx_waiter = TransactionWaiter(self.network_config.account, self.network_config.rpc_url)

    def check_prerequisites(self) -> bool:
        """Check if all required tools and configurations are available."""
        print(f"{Colors.INFO}🔍 Checking prerequisites...{Colors.RESET}")
        
        # Check Scarb
        result = CommandRunner.run_command(["scarb", "--version"], "Checking Scarb")
        if not result["success"]:
            print(f"{Colors.ERROR}✗ Scarb not found. Please install Scarb first.{Colors.RESET}")
            return False
        
        # Check Starknet Foundry
        result = CommandRunner.run_command(["sncast", "--version"], "Checking Starknet Foundry")
        if not result["success"]:
            print(f"{Colors.ERROR}✗ Starknet Foundry not found. Please install Starknet Foundry first.{Colors.RESET}")
            return False
        
        # Check available accounts
        result = CommandRunner.run_command(["sncast", "account", "list"], "Checking accounts")
        if not result["success"]:
            print(f"{Colors.ERROR}✗ Could not access accounts. Please check your Starknet configuration.{Colors.RESET}")
            return False
            
        print(f"{Colors.SUCCESS}✓ Prerequisites OK{Colors.RESET}")
        return True

    def get_account_info(self) -> Optional[str]:
        """Get account information and return the account address."""
        print(f"{Colors.BOLD}📋 Getting account information...{Colors.RESET}")
        
        result = CommandRunner.run_command(["sncast", "account", "list"], "Retrieving account details")
        if not result["success"]:
            return None
            
        # Parse account address from output
        import re
        account_pattern = rf"{self.network_config.account}:.*?address: (0x[a-fA-F0-9]+)"
        match = re.search(account_pattern, result["stdout"], re.DOTALL)
        
        if match:
            address = match.group(1)
            print(f"{Colors.SUCCESS}✓ Found account '{self.network_config.account}' with address: {address}{Colors.RESET}")
            return address
        else:
            print(f"{Colors.ERROR}Could not parse address for account '{self.network_config.account}'{Colors.RESET}")
            return None

    def compile_contract(self) -> bool:
        """Compile the contract using Scarb."""
        print(f"{Colors.INFO}🔨 Compiling contracts...{Colors.RESET}")
        
        result = CommandRunner.run_command(["scarb", "build"], "Compiling contracts")
        if result["success"]:
            print(f"{Colors.SUCCESS}✓ Compilation successful{Colors.RESET}")
        return result["success"]

    def declare_contract(self) -> Optional[str]:
        """Declare the contract and return the class hash."""
        print(f"\n{Colors.BOLD}📤 Declaring contract...{Colors.RESET}")
        
        command = [
            "sncast", "--account", self.network_config.account, "declare",
            "--contract-name", self.contract_config.name,
            "--url", self.network_config.rpc_url
        ]
        
        result = CommandRunner.run_command(command, f"Declaring {self.contract_config.name} to {self.network_config.network}")
        
        # Handle both success and "already declared" cases
        all_output = result.get("stdout", "") + result.get("stderr", "")
        
        try:
            # Try to parse class hash
            class_hash = StarknetUtils.parse_class_hash(all_output)
            print(f"{Colors.SUCCESS}✓ Contract declared with class hash: {class_hash}{Colors.RESET}")
            
            # Check for transaction hash and wait for confirmation
            try:
                tx_hash = StarknetUtils.parse_transaction_hash(all_output)
                print(f"{Colors.INFO}📋 Transaction hash: {tx_hash}{Colors.RESET}")
                
                if not self.tx_waiter.wait_for_confirmation(tx_hash):
                    print(f"{Colors.ERROR}Declaration transaction not confirmed. Deployment may fail.{Colors.RESET}")
                    return None
            except ValueError:
                # No transaction hash found, might be already declared
                pass
            
            return class_hash
            
        except ValueError:
            # Check if it's "already declared" error
            import re
            already_declared_pattern = r"Class with hash (0x[a-fA-F0-9]+) is already declared"
            match = re.search(already_declared_pattern, all_output)
            
            if match:
                class_hash = match.group(1)
                print(f"{Colors.SUCCESS}✓ Contract already declared with class hash: {class_hash}{Colors.RESET}")
                print(f"{Colors.INFO}ℹ️  Skipping declaration, proceeding with deployment...{Colors.RESET}")
                return class_hash
            
            # Actual failure
            print(f"{Colors.ERROR}Declaration failed{Colors.RESET}")
            print(f"{Colors.ERROR}Error: {all_output}{Colors.RESET}")
            return None

    def deploy_contract(self, class_hash: str, owner_address: str, **kwargs) -> Optional[str]:
        """Deploy the contract and return the contract address."""
        print(f"{Colors.INFO}🚀 Deploying {self.contract_config.name}...{Colors.RESET}")

        # Validate dependencies
        if not self.contract.validate_dependencies(**kwargs):
            return None

        # Get constructor calldata
        constructor_calldata = self.contract.get_constructor_calldata(owner_address, **kwargs)

        command = [
            "sncast", "--account", self.network_config.account, "deploy",
            "--class-hash", class_hash,
            "--constructor-calldata"
        ] + constructor_calldata + ["--url", self.network_config.rpc_url]
        
        result = CommandRunner.run_command(command, f"Deploying {self.contract_config.name}")
        
        if not result["success"]:
            print(f"{Colors.ERROR}Deployment command failed:{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return None
        
        try:
            contract_address = StarknetUtils.parse_contract_address(result["stdout"])
            print(f"{Colors.SUCCESS}✓ Contract deployed at address: {contract_address}{Colors.RESET}")
            
            # Wait for deployment transaction confirmation
            try:
                tx_hash = StarknetUtils.parse_transaction_hash(result["stdout"])
                print(f"{Colors.INFO}📋 Deployment transaction hash: {tx_hash}{Colors.RESET}")
                
                print(f"{Colors.BOLD}⏳ Waiting for deployment to be confirmed on the network...{Colors.RESET}")
                if not self.tx_waiter.wait_for_confirmation(tx_hash):
                    print(f"{Colors.ERROR}✗ Deployment transaction not confirmed. Contract may not be available yet.{Colors.RESET}")
                    return None
                    
                print(f"{Colors.SUCCESS}✓ Contract deployment confirmed on L2!{Colors.RESET}")
                
            except ValueError:
                print(f"{Colors.WARNING}⚠️  No transaction hash found in deployment output{Colors.RESET}")
            
            return contract_address
            
        except ValueError as e:
            print(f"{Colors.ERROR}Could not parse contract address from deployment output{Colors.RESET}")
            print(f"{Colors.ERROR}Error: {str(e)}{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return None

    def validate_contract(self, contract_address: str, contract_type: str) -> bool:
        """Validate that a contract exists and is of the expected type."""
        print(f"{Colors.INFO}🔍 Validating {contract_type} contract at {contract_address}...{Colors.RESET}")
        
        # Define validation functions based on contract type
        validation_functions = {
            "nft": "name",  # ERC721
            "registry": "get_owner",  # Registry specific
            "kliver_1155": "balance_of",  # ERC1155
        }
        
        function_name = validation_functions.get(contract_type)
        if not function_name:
            print(f"{Colors.WARNING}⚠️  No validation function defined for {contract_type}{Colors.RESET}")
            return True
        
        # Prepare calldata based on function
        calldata = []
        if function_name == "balance_of":
            calldata = ["0x0", "0x1"]  # dummy address and token id
        
        command = [
            "sncast", "--account", self.network_config.account, "call",
            "--contract-address", contract_address,
            "--function", function_name,
            "--url", self.network_config.rpc_url
        ]
        
        if calldata:
            command.extend(["--calldata"] + calldata)
        
        result = CommandRunner.run_command(command, f"Validating {contract_type} contract")
        
        if result["success"]:
            print(f"{Colors.SUCCESS}✓ {contract_type.title()} contract validated successfully{Colors.RESET}")
            return True
        else:
            print(f"{Colors.ERROR}✗ Invalid {contract_type} contract address or contract not deployed{Colors.RESET}")
            return False

    def save_deployment_info(self, class_hash: str, contract_address: str, owner_address: str, **kwargs):
        """Save deployment information to a JSON file."""
        # Get dependency info
        dependency_info = self.contract.get_dependency_info(**kwargs)
        
        deployment_info = {
            "environment": self.environment,
            "network": self.network_config.network,
            "account": self.network_config.account,
            "rpc_url": self.network_config.rpc_url,
            "contract_name": self.contract_config.name,
            "contract_type": self.contract_type,
            "class_hash": class_hash,
            "contract_address": contract_address,
            "owner_address": owner_address,
            "dependencies": dependency_info,
            "deployment_timestamp": time.time(),
            "deployment_date": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
            "explorer_links": {
                "contract": f"{self.network_config.explorer}/contract/{contract_address}",
                "class": f"{self.network_config.explorer}/class/{class_hash}"
            }
        }
        
        # Add specific dependency addresses
        for key, value in kwargs.items():
            if key.endswith('_address') and value:
                deployment_info[key] = value
        
        filename = f"deployment_{self.network_config.network}_{self.contract_type}_{int(time.time())}.json"
        filepath = Path.cwd() / filename
        
        with open(filepath, 'w') as f:
            json.dump(deployment_info, f, indent=2)
            
        print(f"{Colors.SUCCESS}✓ Deployment info saved to: {filename}{Colors.RESET}")

    def deploy_full_flow(self, owner_address: Optional[str] = None, **kwargs) -> Optional[Dict[str, Any]]:
        """Execute the complete deployment flow for a single contract."""
        print(f"{Colors.BOLD}🎯 Deploying {self.contract_config.name} to {self.network_config.network}{Colors.RESET}")
        print(f"{Colors.INFO}Account: {self.network_config.account} | Network: {self.network_config.network}{Colors.RESET}")
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
            print(f"{Colors.INFO}Owner: {format_address(owner_address)}{Colors.RESET}")
        
        # Validate dependencies (e.g., NFT contract for Registry)
        for dep_type, dep_address in kwargs.items():
            if dep_type.endswith('_address') and dep_address:
                dep_contract_type = dep_type.replace('_address', '')
                if not self.validate_contract(dep_address, dep_contract_type):
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
        contract_address = self.deploy_contract(class_hash, owner_address, **kwargs)
        if not contract_address:
            print(f"{Colors.ERROR}Deployment failed.{Colors.RESET}")
            return None
            
        # Save deployment info
        self.save_deployment_info(class_hash, contract_address, owner_address, **kwargs)
        
        # Print success summary
        print(f"\n{Colors.SUCCESS}🎉 DEPLOYMENT SUCCESSFUL!{Colors.RESET}")
        print(f"{Colors.BOLD}Contract: {Colors.SUCCESS}{contract_address}{Colors.RESET}")
        print(f"{Colors.BOLD}Explorer: {Colors.INFO}{self.network_config.explorer}/contract/{contract_address}{Colors.RESET}")
        print(f"Class Hash: {class_hash}")
        print(f"Network: {self.network_config.network} | Owner: {format_address(owner_address)}")
        
        # Show dependencies
        for info in self.contract.get_dependency_info(**kwargs):
            print(f"{info}")
        
        # Return deployment info for summary
        result = {
            "contract_name": self.contract_config.name,
            "contract_type": self.contract_type,
            "contract_address": contract_address,
            "class_hash": class_hash,
            "network": self.network_config.network,
            "owner": owner_address,
        }
        
        # Add dependency addresses
        for key, value in kwargs.items():
            if key.endswith('_address') and value:
                result[key] = value
                
        return result