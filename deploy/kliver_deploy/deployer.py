"""
Main deployment orchestrator for Kliver contracts.
"""

import json
import time
from pathlib import Path
from typing import Optional, Dict, Any, List

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
        self.tx_waiter = TransactionWaiter(self.network_config.account, self.network_config.rpc_url, self.network_config.network)

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

        def _net_flags() -> list[str]:
            return ["--network", self.network_config.network] if self.network_config.network in ("mainnet", "sepolia") else []

        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "declare", "--network", self.network_config.network,
                "--contract-name", self.contract_config.name,
            ]
        else:
            # For local/katana networks, use profile instead of --url to get proper account resolution
            command = [
                "sncast", "--profile", self.network_config.network,
                "declare",
                "--contract-name", self.contract_config.name,
            ]
        
        result = CommandRunner.run_command(command, f"Declaring {self.contract_config.name} to {self.network_config.network}")

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

    def deploy_contract(self, class_hash: str, owner_address: str, **kwargs) -> Optional[Dict[str, Any]]:
        """Deploy the contract and return deployment details."""
        print(f"{Colors.INFO}🚀 Deploying {self.contract_config.name}...{Colors.RESET}")

        # Validate dependencies
        if not self.contract.validate_dependencies(**kwargs):
            return None

        # Get constructor calldata
        constructor_calldata = self.contract.get_constructor_calldata(owner_address, **kwargs)

        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "deploy", "--network", self.network_config.network,
                "--class-hash", class_hash,
            ]
            if constructor_calldata:  # Only add --constructor-calldata if there are parameters
                command.extend(["--constructor-calldata"] + constructor_calldata)
        else:
            command = [
                "sncast", "--profile", self.network_config.network,
                "deploy",
                "--class-hash", class_hash,
            ]
            if constructor_calldata:  # Only add --constructor-calldata if there are parameters
                command.extend(["--constructor-calldata"] + constructor_calldata)

        result = CommandRunner.run_command(command, f"Deploying {self.contract_config.name}")

        if not result["success"]:
            print(f"{Colors.ERROR}Deployment command failed:{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return None

        try:
            contract_address = StarknetUtils.parse_contract_address(result["stdout"])
            print(f"{Colors.SUCCESS}✓ Contract deployed at address: {contract_address}{Colors.RESET}")

            deployment_tx_hash = None
            # Wait for deployment transaction confirmation
            try:
                deployment_tx_hash = StarknetUtils.parse_transaction_hash(result["stdout"])
                print(f"{Colors.INFO}📋 Deployment transaction hash: {deployment_tx_hash}{Colors.RESET}")

                print(f"{Colors.BOLD}⏳ Waiting for deployment to be confirmed on the network...{Colors.RESET}")
                if not self.tx_waiter.wait_for_confirmation(deployment_tx_hash):
                    print(f"{Colors.ERROR}✗ Deployment transaction not confirmed. Contract may not be available yet.{Colors.RESET}")
                    return None

                print(f"{Colors.SUCCESS}✓ Contract deployment confirmed on L2!{Colors.RESET}")

            except ValueError:
                print(f"{Colors.WARNING}⚠️  No transaction hash found in deployment output{Colors.RESET}")

            # Return deployment details
            return {
                "contract_address": contract_address,
                "deployment_tx_hash": deployment_tx_hash,
                "constructor_calldata": constructor_calldata,
                "constructor_params": self._format_constructor_params(owner_address, **kwargs)
            }

        except ValueError as e:
            print(f"{Colors.ERROR}Could not parse contract address from deployment output{Colors.RESET}")
            print(f"{Colors.ERROR}Error: {str(e)}{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return None

    def set_registry_on_tokencore(self, tokencore_address: str, registry_address: str, owner_address: str) -> Optional[Dict[str, Any]]:
        """Set the registry address on the TokenSimulation contract."""
        print(f"{Colors.INFO}🔗 Setting registry address on TokenSimulation contract...{Colors.RESET}")

        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "invoke", "--network", self.network_config.network,
                "--contract-address", tokencore_address,
                "--function", "set_registry_address",
                "--calldata", registry_address,
            ]
        else:
            command = [
                "sncast", "--profile", self.network_config.network,
                "invoke",
                "--contract-address", tokencore_address,
                "--function", "set_registry_address",
                "--calldata", registry_address,
            ]

        result = CommandRunner.run_command(command, f"Setting registry address on TokenSimulation")

        if not result["success"]:
            print(f"{Colors.ERROR}Failed to set registry address on TokenSimulation:{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return None

        try:
            # Debug: print the output to see what we're parsing
            print(f"{Colors.INFO}DEBUG - Command output:{Colors.RESET}")
            print(f"STDOUT: {result['stdout']}")
            print(f"STDERR: {result['stderr']}")

            tx_hash = StarknetUtils.parse_transaction_hash(result["stdout"])
            print(f"{Colors.INFO}📋 Transaction hash: {tx_hash}{Colors.RESET}")

            print(f"{Colors.BOLD}⏳ Waiting for transaction to be confirmed...{Colors.RESET}")
            if not self.tx_waiter.wait_for_confirmation(tx_hash):
                print(f"{Colors.ERROR}✗ Transaction not confirmed.{Colors.RESET}")
                return None

            print(f"{Colors.SUCCESS}✓ Registry address set successfully on TokenSimulation!{Colors.RESET}")

            # Validate that the registry address was set correctly
            if not self.validate_registry_address_set(tokencore_address, registry_address):
                print(f"{Colors.ERROR}✗ Registry address validation failed.{Colors.RESET}")
                return None

            return {
                "method": "set_registry_address",
                "tx_hash": tx_hash,
                "calldata": [registry_address],
                "params": {"registry_address": registry_address},
                "validation": "✓ Registry address validated"
            }

        except ValueError as e:
            print(f"{Colors.ERROR}Could not parse transaction hash from output{Colors.RESET}")
            print(f"{Colors.ERROR}Error: {str(e)}{Colors.RESET}")
            return None

    def validate_registry_address_set(self, tokencore_address: str, expected_registry_address: str) -> bool:
        """Validate that the registry address was set correctly on the TokenSimulation contract."""
        print(f"{Colors.INFO}🔍 Validating registry address on TokenSimulation contract...{Colors.RESET}")

        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "call", "--network", self.network_config.network,
                "--contract-address", tokencore_address,
                "--function", "get_registry_address",
            ]
        else:
            command = [
                "sncast", "--profile", self.network_config.network,
                "call",
                "--contract-address", tokencore_address,
                "--function", "get_registry_address",
            ]

        result = CommandRunner.run_command(command, f"Validating registry address on TokenSimulation")

        if not result["success"]:
            print(f"{Colors.ERROR}Failed to call get_registry_address on TokenSimulation:{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return False

        try:
            # Parse the returned registry address from the output
            import re
            # The output should contain something like "0x[address]"
            match = re.search(r'0x[a-fA-F0-9]+', result["stdout"])
            if not match:
                print(f"{Colors.ERROR}Could not parse registry address from call output{Colors.RESET}")
                print(f"{Colors.ERROR}Output: {result['stdout']}{Colors.RESET}")
                return False

            returned_address = match.group(0).lower()
            expected_address = expected_registry_address.lower()

            # Normalize addresses by removing leading zeros after 0x for comparison
            def normalize_address(addr: str) -> str:
                if addr.startswith('0x'):
                    # Remove leading zeros after 0x, but keep at least one zero if the address is all zeros
                    hex_part = addr[2:].lstrip('0')
                    return '0x' + (hex_part if hex_part else '0')
                return addr

            normalized_returned = normalize_address(returned_address)
            normalized_expected = normalize_address(expected_address)

            if normalized_returned == normalized_expected:
                print(f"{Colors.SUCCESS}✓ Registry address validated successfully: {returned_address}{Colors.RESET}")
                return True
            else:
                print(f"{Colors.ERROR}✗ Registry address mismatch!{Colors.RESET}")
                print(f"{Colors.ERROR}Expected: {expected_address}{Colors.RESET}")
                print(f"{Colors.ERROR}Got: {returned_address}{Colors.RESET}")
                print(f"{Colors.ERROR}Normalized Expected: {normalized_expected}{Colors.RESET}")
                print(f"{Colors.ERROR}Normalized Got: {normalized_returned}{Colors.RESET}")
                return False

        except Exception as e:
            print(f"{Colors.ERROR}Error validating registry address: {str(e)}{Colors.RESET}")
            return False

    def _format_constructor_params(self, owner_address: str, **kwargs) -> Dict[str, Any]:
        """Format constructor parameters for display."""
        params = {"owner": owner_address}

        # Add contract-specific parameters
        for key, value in kwargs.items():
            if key == 'base_uri':
                params['base_uri'] = value
            elif key.endswith('_address'):
                params[key] = value
            elif key == 'verifier_address':
                params['verifier_address'] = value
            elif key == 'purchase_timeout_seconds':
                params['purchase_timeout_seconds'] = value

        return params

    def print_professional_summary(self, deployment_details: Dict[str, Any], post_deployment_ops: List[Dict[str, Any]] = None):
        """Print a professional deployment summary."""
        print(f"\n{Colors.BOLD}{'='*80}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}🎯 CONTRACT DEPLOYMENT SUMMARY{Colors.RESET}")
        print(f"{Colors.BOLD}{'='*80}{Colors.RESET}")

        # Contract Info
        print(f"{Colors.BOLD}📋 Contract Information:{Colors.RESET}")
        print(f"  Name: {deployment_details['contract_name']}")
        print(f"  Type: {deployment_details['contract_type']}")
        print(f"  Address: {Colors.SUCCESS}{deployment_details['contract_address']}{Colors.RESET}")
        print(f"  Class Hash: {deployment_details['class_hash']}")
        print(f"  Network: {deployment_details['network']}")
        print(f"  Owner: {format_address(deployment_details['owner'])}")

        # Deployment Transaction
        if deployment_details.get('deployment_tx_hash'):
            print(f"\n{Colors.BOLD}🚀 Deployment Transaction:{Colors.RESET}")
            print(f"  Transaction Hash: {Colors.INFO}{deployment_details['deployment_tx_hash']}{Colors.RESET}")
            print(f"  Status: {Colors.SUCCESS}✓ Confirmed{Colors.RESET}")

        # Constructor Parameters
        if deployment_details.get('constructor_params'):
            print(f"\n{Colors.BOLD}⚙️  Constructor Parameters:{Colors.RESET}")
            for param, value in deployment_details['constructor_params'].items():
                if param == 'base_uri':
                    print(f"  {param}: {Colors.CYAN}{value}{Colors.RESET}")
                elif param.endswith('_address') or param == 'verifier_address':
                    print(f"  {param}: {Colors.INFO}{value}{Colors.RESET}")
                else:
                    print(f"  {param}: {value}")

        # Post-deployment Operations
        if post_deployment_ops:
            print(f"\n{Colors.BOLD}🔧 Post-Deployment Operations:{Colors.RESET}")
            for i, op in enumerate(post_deployment_ops, 1):
                print(f"  {i}. {Colors.BOLD}{op['method']}(){Colors.RESET}")
                if op.get('tx_hash'):
                    print(f"     Transaction: {Colors.INFO}{op['tx_hash']}{Colors.RESET}")
                if op.get('params'):
                    print(f"     Parameters: {op['params']}")
                if op.get('validation'):
                    print(f"     Validation: {Colors.SUCCESS}{op['validation']}{Colors.RESET}")

        # Explorer Links
        if deployment_details.get('contract_address'):
            explorer_url = f"{self.network_config.explorer}/contract/{deployment_details['contract_address']}"
            print(f"\n{Colors.BOLD}🔗 Explorer Links:{Colors.RESET}")
            print(f"  Contract: {Colors.CYAN}{explorer_url}{Colors.RESET}")
            if deployment_details.get('class_hash'):
                class_url = f"{self.network_config.explorer}/class/{deployment_details['class_hash']}"
                print(f"  Class: {Colors.CYAN}{class_url}{Colors.RESET}")

        print(f"{Colors.BOLD}{'='*80}{Colors.RESET}")

    def validate_contract(self, contract_address: str, contract_type: str) -> bool:
        """Validate that a contract exists and is of the expected type."""
        print(f"{Colors.INFO}🔍 Validating {contract_type} contract at {contract_address}...{Colors.RESET}")

        # Define validation functions based on contract type
        validation_functions = {
            "nft": "name",           # ERC721
            "registry": "get_owner",  # Registry specific
            "token": "balance_of",  # ERC1155
            "token_simulation": "balance_of",  # ERC1155 (TokenSimulation)
            "pox": "get_registry_address",  # KliverPox - validates it has registry
            "verifier": None,  # TODO: Add verifier validation once we know the interface
            "payment_token": "total_supply",  # ERC20 - validates it's a token contract
        }

        function_name = validation_functions.get(contract_type)

        # Special case: verifier contract - we don't know the interface yet
        if contract_type == "verifier":
            print(f"{Colors.WARNING}⚠️  Verifier contract validation not implemented yet - skipping{Colors.RESET}")
            print(f"{Colors.INFO}ℹ️  Assuming verifier address {contract_address} is valid{Colors.RESET}")
            return True

        if not function_name:
            print(f"{Colors.ERROR}✗ No validation function defined for {contract_type}{Colors.RESET}")
            print(f"{Colors.ERROR}✗ Cannot proceed with deployment without validation{Colors.RESET}")
            return False

        # Prepare calldata based on function
        calldata = []
        if function_name == "balance_of":
            calldata = ["0x0", "0x1"]  # dummy address and token id for ERC1155

        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "call", "--network", self.network_config.network,
                "--contract-address", contract_address,
                "--function", function_name,
            ]
        else:
            command = [
                "sncast", "--profile", self.network_config.network,
                "call",
                "--contract-address", contract_address,
                "--function", function_name,
            ]

        if calldata:
            command.extend(["--calldata"] + calldata)

        result = CommandRunner.run_command(command, f"Validating {contract_type} contract")

        if result["success"]:
            print(f"{Colors.SUCCESS}✓ {contract_type.title()} contract validated successfully{Colors.RESET}")
            return True
        else:
            # Special case: payment_token might be Cairo 0 contract (can't validate with sncast)
            all_output = result.get("stdout", "") + result.get("stderr", "")
            if contract_type == "payment_token" and ("Cairo Zero" in all_output or "Transformation of arguments" in all_output):
                print(f"{Colors.WARNING}⚠️  Payment token appears to be a Cairo 0 contract - cannot validate with sncast{Colors.RESET}")
                print(f"{Colors.INFO}ℹ️  Assuming payment token address {contract_address} is valid{Colors.RESET}")
                return True

            print(f"{Colors.ERROR}✗ Invalid {contract_type} contract address or contract not deployed{Colors.RESET}")
            print(f"{Colors.ERROR}✗ Please verify the address and ensure the contract is deployed{Colors.RESET}")
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

    def deploy_full_flow(self, owner_address: Optional[str] = None, no_compile: bool = False, **kwargs) -> Optional[Dict[str, Any]]:
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

        # Compile contract (skip if no_compile is True)
        if not no_compile:
            if not self.compile_contract():
                print(f"{Colors.ERROR}✗ Compilation failed{Colors.RESET}")
                return None
        else:
            print(f"{Colors.INFO}⏭️ Skipping compilation (--no-compile flag set){Colors.RESET}")

        # Declare contract
        class_hash = self.declare_contract()
        if not class_hash:
            print(f"{Colors.ERROR}Declaration failed. Deployment aborted.{Colors.RESET}")
            return None

        # Deploy contract
        deployment_result = self.deploy_contract(class_hash, owner_address, **kwargs)
        if not deployment_result:
            print(f"{Colors.ERROR}Deployment failed.{Colors.RESET}")
            return None

        contract_address = deployment_result["contract_address"]

        # Save deployment info
        self.save_deployment_info(class_hash, contract_address, owner_address, **kwargs)

        # Collect deployment details for professional summary
        deployment_details = {
            "contract_name": self.contract_config.name,
            "contract_type": self.contract_type,
            "contract_address": contract_address,
            "class_hash": class_hash,
            "network": self.network_config.network,
            "owner": owner_address,
            "deployment_tx_hash": deployment_result.get("deployment_tx_hash"),
            "constructor_params": deployment_result.get("constructor_params", {}),
        }

        # Add dependency addresses
        for key, value in kwargs.items():
            if key.endswith('_address') and value:
                deployment_details[key] = value

        # Print professional summary
        self.print_professional_summary(deployment_details)

        return deployment_details

    def invoke_setter_method(
        self,
        contract_address: str,
        method_name: str,
        calldata: List[str],
        description: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Generic method to invoke a setter function on a contract.
        
        Args:
            contract_address: Address of the contract to invoke
            method_name: Name of the method to call (e.g., 'set_registry_address')
            calldata: List of parameters for the method
            description: Optional description for logging
            
        Returns:
            Dictionary with transaction details or None if failed
        """
        desc = description or f"Invoking {method_name}"
        print(f"{Colors.INFO}🔧 {desc}...{Colors.RESET}")

        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "invoke", "--network", self.network_config.network,
                "--contract-address", contract_address,
                "--function", method_name,
                "--calldata", *calldata,
            ]
        else:
            command = [
                "sncast", "--profile", self.network_config.network,
                "invoke",
                "--contract-address", contract_address,
                "--function", method_name,
                "--calldata", *calldata,
            ]

        result = CommandRunner.run_command(command, desc)

        if not result["success"]:
            print(f"{Colors.ERROR}Failed to invoke {method_name}:{Colors.RESET}")
            print(f"{Colors.ERROR}STDOUT: {result['stdout']}{Colors.RESET}")
            print(f"{Colors.ERROR}STDERR: {result['stderr']}{Colors.RESET}")
            return None

        try:
            tx_hash = StarknetUtils.parse_transaction_hash(result["stdout"])
            print(f"{Colors.INFO}📋 Transaction hash: {tx_hash}{Colors.RESET}")

            print(f"{Colors.BOLD}⏳ Waiting for transaction to be confirmed...{Colors.RESET}")
            if not self.tx_waiter.wait_for_confirmation(tx_hash):
                print(f"{Colors.ERROR}✗ Transaction not confirmed.{Colors.RESET}")
                return None

            print(f"{Colors.SUCCESS}✓ {method_name} executed successfully!{Colors.RESET}")

            return {
                "method": method_name,
                "tx_hash": tx_hash,
                "calldata": calldata,
                "contract_address": contract_address,
            }

        except ValueError as e:
            print(f"{Colors.ERROR}Could not parse transaction hash from output{Colors.RESET}")
            print(f"{Colors.ERROR}Error: {str(e)}{Colors.RESET}")
            return None

    def call_view_method(
        self,
        contract_address: str,
        method_name: str,
        calldata: Optional[List[str]] = None
    ) -> Optional[str]:
        """
        Generic method to call a view function on a contract.
        
        Args:
            contract_address: Address of the contract to call
            method_name: Name of the method to call (e.g., 'get_registry_address')
            calldata: Optional list of parameters for the method
            
        Returns:
            Parsed result or None if failed
        """
        if self.network_config.network in ("mainnet", "sepolia"):
            command = [
                "sncast", "--account", self.network_config.account,
                "call", "--network", self.network_config.network,
                "--contract-address", contract_address,
                "--function", method_name,
            ]
        else:
            command = [
                "sncast", "--profile", self.network_config.network,
                "call",
                "--contract-address", contract_address,
                "--function", method_name,
            ]

        if calldata:
            command.extend(["--calldata", *calldata])

        result = CommandRunner.run_command(command, f"Calling {method_name}", verbose=False)

        if not result["success"]:
            return None

        try:
            # Try to parse as address first
            return StarknetUtils.parse_contract_address_from_call(result["stdout"])
        except ValueError:
            # If not an address, return raw output
            return result["stdout"].strip()

    def set_registry_address(
        self,
        contract_address: str,
        registry_address: str,
        contract_name: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Set registry address on TokensCore or SessionsMarketplace.
        
        Args:
            contract_address: Address of the contract (TokensCore or SessionsMarketplace)
            registry_address: Address of the Registry contract
            contract_name: Optional name for better logging
            
        Returns:
            Transaction details or None if failed
        """
        name = contract_name or "contract"
        result = self.invoke_setter_method(
            contract_address=contract_address,
            method_name="set_registry_address",
            calldata=[registry_address],
            description=f"Setting registry address on {name}"
        )
        
        if result:
            # Validate
            actual = self.call_view_method(contract_address, "get_registry_address")
            if actual:
                expected = registry_address.lower().replace('0x', '').lstrip('0')
                returned = actual.lower().replace('0x', '').lstrip('0')
                if expected == returned:
                    print(f"{Colors.SUCCESS}✓ Registry address validated on {name}{Colors.RESET}")
                    result["validation"] = "✓ Registry address validated"
                else:
                    print(f"{Colors.WARNING}⚠️ Registry address mismatch on {name}{Colors.RESET}")
        
        return result

    def set_kliver_pox_address(
        self,
        registry_address: str,
        pox_address: str
    ) -> Optional[Dict[str, Any]]:
        """
        Set KliverPox address on Registry.
        
        Args:
            registry_address: Address of the Registry contract
            pox_address: Address of the KliverPox contract
            
        Returns:
            Transaction details or None if failed
        """
        result = self.invoke_setter_method(
            contract_address=registry_address,
            method_name="set_kliver_pox_address",
            calldata=[pox_address],
            description="Setting KliverPox address on Registry"
        )
        
        if result:
            # Validate
            actual = self.call_view_method(registry_address, "get_kliver_pox_address")
            if actual:
                expected = pox_address.lower().replace('0x', '').lstrip('0')
                returned = actual.lower().replace('0x', '').lstrip('0')
                if expected == returned:
                    print(f"{Colors.SUCCESS}✓ KliverPox address validated on Registry{Colors.RESET}")
                    result["validation"] = "✓ KliverPox address validated"
                else:
                    print(f"{Colors.WARNING}⚠️ KliverPox address mismatch{Colors.RESET}")
        
        return result

    def set_verifier_address(
        self,
        registry_address: str,
        verifier_address: str
    ) -> Optional[Dict[str, Any]]:
        """
        Set Verifier address on Registry.
        
        Args:
            registry_address: Address of the Registry contract
            verifier_address: Address of the Verifier contract
            
        Returns:
            Transaction details or None if failed
        """
        result = self.invoke_setter_method(
            contract_address=registry_address,
            method_name="set_verifier_address",
            calldata=[verifier_address],
            description="Setting Verifier address on Registry"
        )
        
        if result:
            # Validate
            actual = self.call_view_method(registry_address, "get_verifier_address")
            if actual:
                expected = verifier_address.lower().replace('0x', '').lstrip('0')
                returned = actual.lower().replace('0x', '').lstrip('0')
                if expected == returned:
                    print(f"{Colors.SUCCESS}✓ Verifier address validated on Registry{Colors.RESET}")
                    result["validation"] = "✓ Verifier address validated"
                else:
                    print(f"{Colors.WARNING}⚠️ Verifier address mismatch{Colors.RESET}")
        
        return result

    def set_payment_token(
        self,
        marketplace_address: str,
        payment_token_address: str
    ) -> Optional[Dict[str, Any]]:
        """
        Set Payment Token address on SessionsMarketplace.
        
        Args:
            marketplace_address: Address of the SessionsMarketplace contract
            payment_token_address: Address of the ERC20 payment token
            
        Returns:
            Transaction details or None if failed
        """
        result = self.invoke_setter_method(
            contract_address=marketplace_address,
            method_name="set_payment_token",
            calldata=[payment_token_address],
            description="Setting Payment Token address on Marketplace"
        )
        
        if result:
            # Validate
            actual = self.call_view_method(marketplace_address, "get_payment_token")
            if actual:
                expected = payment_token_address.lower().replace('0x', '').lstrip('0')
                returned = actual.lower().replace('0x', '').lstrip('0')
                if expected == returned:
                    print(f"{Colors.SUCCESS}✓ Payment Token address validated on Marketplace{Colors.RESET}")
                    result["validation"] = "✓ Payment Token address validated"
                else:
                    print(f"{Colors.WARNING}⚠️ Payment Token address mismatch{Colors.RESET}")
        
        return result

    def set_pox_address_on_marketplace(
        self,
        marketplace_address: str,
        pox_address: str
    ) -> Optional[Dict[str, Any]]:
        """
        Set KliverPox address on SessionsMarketplace.
        
        Args:
            marketplace_address: Address of the SessionsMarketplace contract
            pox_address: Address of the KliverPox contract
            
        Returns:
            Transaction details or None if failed
        """
        result = self.invoke_setter_method(
            contract_address=marketplace_address,
            method_name="set_pox_address",
            calldata=[pox_address],
            description="Setting KliverPox address on Marketplace"
        )
        
        if result:
            # Validate
            actual = self.call_view_method(marketplace_address, "get_pox_address")
            if actual:
                expected = pox_address.lower().replace('0x', '').lstrip('0')
                returned = actual.lower().replace('0x', '').lstrip('0')
                if expected == returned:
                    print(f"{Colors.SUCCESS}✓ KliverPox address validated on Marketplace{Colors.RESET}")
                    result["validation"] = "✓ KliverPox address validated"
                else:
                    print(f"{Colors.WARNING}⚠️ KliverPox address mismatch{Colors.RESET}")
        
        return result

    def set_purchase_timeout(
        self,
        marketplace_address: str,
        timeout_seconds: int
    ) -> Optional[Dict[str, Any]]:
        """
        Set purchase timeout on SessionsMarketplace.
        
        Args:
            marketplace_address: Address of the SessionsMarketplace contract
            timeout_seconds: Timeout in seconds
            
        Returns:
            Transaction details or None if failed
        """
        result = self.invoke_setter_method(
            contract_address=marketplace_address,
            method_name="set_purchase_timeout",
            calldata=[str(timeout_seconds)],
            description="Setting purchase timeout on Marketplace"
        )
        
        if result:
            # Validate
            actual = self.call_view_method(marketplace_address, "get_purchase_timeout")
            if actual:
                if actual == str(timeout_seconds):
                    print(f"{Colors.SUCCESS}✓ Purchase timeout validated on Marketplace ({timeout_seconds}s){Colors.RESET}")
                    result["validation"] = f"✓ Purchase timeout validated ({timeout_seconds}s)"
                else:
                    print(f"{Colors.WARNING}⚠️ Purchase timeout mismatch (expected: {timeout_seconds}, got: {actual}){Colors.RESET}")
        
        return result

