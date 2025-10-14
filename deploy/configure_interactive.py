#!/usr/bin/env python3
"""
Kliver Contracts Interactive Configuration Tool

Interactive CLI for configuring deployed Kliver smart contracts.
"""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from kliver_deploy import ConfigManager, ContractDeployer
from kliver_deploy.utils import Colors


def clear_screen():
    """Clear the terminal screen."""
    print("\033[2J\033[H", end="")


def print_header():
    """Print the application header."""
    print(f"{Colors.BOLD}{Colors.INFO}")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Kliver Smart Contracts - Interactive Configuration      ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print(f"{Colors.RESET}\n")


def print_menu():
    """Print the main menu."""
    print(f"{Colors.BOLD}Main Menu:{Colors.RESET}\n")
    print(f"  {Colors.INFO}1.{Colors.RESET} Set Registry Address on TokensCore")
    print(f"  {Colors.INFO}2.{Colors.RESET} Set Registry Address on SessionsMarketplace")
    print(f"  {Colors.INFO}3.{Colors.RESET} Set KliverPox Address on Registry")
    print(f"  {Colors.INFO}4.{Colors.RESET} Set Verifier Address on Registry")
    print(f"  {Colors.INFO}5.{Colors.RESET} Set Payment Token on Marketplace")
    print(f"  {Colors.INFO}6.{Colors.RESET} Set KliverPox Address on Marketplace")
    print(f"  {Colors.INFO}7.{Colors.RESET} Set Purchase Timeout on Marketplace")
    print(f"  {Colors.INFO}8.{Colors.RESET} Get Registry Address (from any contract)")
    print(f"  {Colors.INFO}9.{Colors.RESET} Get KliverPox Address (from Registry)")
    print(f"  {Colors.INFO}10.{Colors.RESET} Get Verifier Address (from Registry)")
    print(f"  {Colors.INFO}11.{Colors.RESET} View All Configured Addresses")
    print(f"  {Colors.INFO}12.{Colors.RESET} Generic Method Invocation")
    print(f"  {Colors.ERROR}0.{Colors.RESET} Exit")
    print()


def get_input(prompt: str, default: str = None) -> str:
    """Get user input with optional default value."""
    if default:
        prompt = f"{prompt} [{default}]: "
    else:
        prompt = f"{prompt}: "
    
    value = input(f"{Colors.INFO}{prompt}{Colors.RESET}").strip()
    return value if value else default


def select_environment() -> str:
    """Let user select environment."""
    print(f"\n{Colors.BOLD}Select Environment:{Colors.RESET}")
    print("  1. local (Local - Katana)")
    print("  2. dev (Development - Sepolia)")
    print("  3. qa (Quality Assurance - Sepolia)")
    print("  4. prod (Production - Mainnet)")
    
    choice = get_input("Enter choice [1-4]", "1")
    
    env_map = {"1": "local", "2": "dev", "3": "qa", "4": "prod"}
    return env_map.get(choice, "local")


def validate_address(address: str) -> bool:
    """Validate a contract address format."""
    if not address:
        return False
    
    # Remove 0x prefix if present
    addr = address.lower().replace('0x', '')
    
    # Check if it's a valid hex string
    try:
        int(addr, 16)
        return True
    except ValueError:
        return False


def set_registry_on_tokens_core():
    """Interactive flow to set registry on TokensCore."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set Registry Address on TokensCore{Colors.RESET}\n")
    print("This configures the TokensCore contract to know the Registry address.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Addresses:{Colors.RESET}")
    tokens_core_address = get_input("TokensCore contract address")
    
    if not validate_address(tokens_core_address):
        print(f"{Colors.ERROR}❌ Invalid TokensCore address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    registry_address = get_input("Registry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:  {environment}")
    print(f"  TokensCore:   {tokens_core_address}")
    print(f"  Registry:     {registry_address}")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'kliver_tokens_core', config_manager)
        
        result = deployer.set_registry_address(
            contract_address=tokens_core_address,
            registry_address=registry_address,
            contract_name="TokensCore"
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Configuration successful!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def set_registry_on_marketplace():
    """Interactive flow to set registry on SessionsMarketplace."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set Registry Address on SessionsMarketplace{Colors.RESET}\n")
    print("This configures the SessionsMarketplace contract to know the Registry address.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Addresses:{Colors.RESET}")
    marketplace_address = get_input("SessionsMarketplace contract address")
    
    if not validate_address(marketplace_address):
        print(f"{Colors.ERROR}❌ Invalid SessionsMarketplace address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    registry_address = get_input("Registry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:  {environment}")
    print(f"  Marketplace:  {marketplace_address}")
    print(f"  Registry:     {registry_address}")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        result = deployer.set_registry_address(
            contract_address=marketplace_address,
            registry_address=registry_address,
            contract_name="SessionsMarketplace"
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Configuration successful!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def set_pox_on_registry():
    """Interactive flow to set KliverPox on Registry."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set KliverPox Address on Registry{Colors.RESET}\n")
    print("This configures the Registry to use KliverPox for minting session NFTs.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Addresses:{Colors.RESET}")
    registry_address = get_input("Registry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    pox_address = get_input("KliverPox contract address")
    
    if not validate_address(pox_address):
        print(f"{Colors.ERROR}❌ Invalid KliverPox address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:  {environment}")
    print(f"  Registry:     {registry_address}")
    print(f"  KliverPox:    {pox_address}")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        result = deployer.set_kliver_pox_address(
            registry_address=registry_address,
            pox_address=pox_address
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Configuration successful!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def set_verifier_on_registry():
    """Interactive flow to set Verifier on Registry."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set Verifier Address on Registry{Colors.RESET}\n")
    print("This configures the Registry to use a Verifier for ZK proof validation.")
    print(f"{Colors.WARNING}Note: You can set this to 0x0 if not using ZK proofs yet.{Colors.RESET}")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Addresses:{Colors.RESET}")
    registry_address = get_input("Registry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    verifier_address = get_input("Verifier contract address (or 0x0)")
    
    if not validate_address(verifier_address):
        print(f"{Colors.ERROR}❌ Invalid Verifier address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:  {environment}")
    print(f"  Registry:     {registry_address}")
    print(f"  Verifier:     {verifier_address}")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        result = deployer.set_verifier_address(
            registry_address=registry_address,
            verifier_address=verifier_address
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Configuration successful!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def get_registry_address():
    """Interactive flow to get registry address from a contract."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Get Registry Address{Colors.RESET}\n")
    print("Query the Registry address from TokensCore or SessionsMarketplace.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Address:{Colors.RESET}")
    contract_address = get_input("Contract address (TokensCore or Marketplace)")
    
    if not validate_address(contract_address):
        print(f"{Colors.ERROR}❌ Invalid contract address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔍 Querying...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        result = deployer.call_view_method(
            contract_address=contract_address,
            method_name="get_registry_address"
        )
        
        if result:
            print(f"{Colors.SUCCESS}✅ Registry Address: {Colors.BOLD}{result}{Colors.RESET}")
        else:
            print(f"{Colors.ERROR}❌ Failed to get address{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def get_pox_address():
    """Interactive flow to get KliverPox address from Registry."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Get KliverPox Address{Colors.RESET}\n")
    print("Query the KliverPox address from Registry.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Address:{Colors.RESET}")
    registry_address = get_input("Registry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔍 Querying...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        result = deployer.call_view_method(
            contract_address=registry_address,
            method_name="get_kliver_pox_address"
        )
        
        if result:
            print(f"{Colors.SUCCESS}✅ KliverPox Address: {Colors.BOLD}{result}{Colors.RESET}")
        else:
            print(f"{Colors.ERROR}❌ Failed to get address{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def get_verifier_address():
    """Interactive flow to get Verifier address from Registry."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Get Verifier Address{Colors.RESET}\n")
    print("Query the Verifier address from Registry.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Address:{Colors.RESET}")
    registry_address = get_input("Registry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔍 Querying...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        result = deployer.call_view_method(
            contract_address=registry_address,
            method_name="get_verifier_address"
        )
        
        if result:
            print(f"{Colors.SUCCESS}✅ Verifier Address: {Colors.BOLD}{result}{Colors.RESET}")
        else:
            print(f"{Colors.ERROR}❌ Failed to get address{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def view_all_addresses():
    """View all configured addresses for a deployment."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}View All Configured Addresses{Colors.RESET}\n")
    print("Query all addresses from your deployed contracts.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Your Contract Addresses:{Colors.RESET}")
    print(f"{Colors.WARNING}(Press Enter to skip any contract you haven't deployed){Colors.RESET}\n")
    
    tokens_core = get_input("TokensCore address (optional)")
    registry = get_input("Registry address (optional)")
    marketplace = get_input("SessionsMarketplace address (optional)")
    
    if not (tokens_core or registry or marketplace):
        print(f"{Colors.ERROR}❌ Please provide at least one contract address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute queries
    try:
        print(f"\n{Colors.INFO}🔍 Querying all addresses...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        print(f"{Colors.BOLD}{'='*60}{Colors.RESET}")
        print(f"{Colors.BOLD}Configuration Status{Colors.RESET}")
        print(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")
        
        if tokens_core and validate_address(tokens_core):
            print(f"{Colors.INFO}TokensCore ({tokens_core[:10]}...):{Colors.RESET}")
            reg_addr = deployer.call_view_method(tokens_core, "get_registry_address")
            if reg_addr:
                print(f"  → Registry: {Colors.SUCCESS}{reg_addr}{Colors.RESET}")
            else:
                print(f"  → Registry: {Colors.ERROR}Not set or query failed{Colors.RESET}")
            print()
        
        if registry and validate_address(registry):
            print(f"{Colors.INFO}Registry ({registry[:10]}...):{Colors.RESET}")
            pox_addr = deployer.call_view_method(registry, "get_kliver_pox_address")
            if pox_addr:
                print(f"  → KliverPox: {Colors.SUCCESS}{pox_addr}{Colors.RESET}")
            else:
                print(f"  → KliverPox: {Colors.ERROR}Not set or query failed{Colors.RESET}")
            
            ver_addr = deployer.call_view_method(registry, "get_verifier_address")
            if ver_addr:
                print(f"  → Verifier: {Colors.SUCCESS}{ver_addr}{Colors.RESET}")
            else:
                print(f"  → Verifier: {Colors.ERROR}Not set or query failed{Colors.RESET}")
            print()
        
        if marketplace and validate_address(marketplace):
            print(f"{Colors.INFO}SessionsMarketplace ({marketplace[:10]}...):{Colors.RESET}")
            reg_addr = deployer.call_view_method(marketplace, "get_registry_address")
            if reg_addr:
                print(f"  → Registry: {Colors.SUCCESS}{reg_addr}{Colors.RESET}")
            else:
                print(f"  → Registry: {Colors.ERROR}Not set or query failed{Colors.RESET}")
            print()
        
        print(f"{Colors.BOLD}{'='*60}{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def generic_invoke():
    """Generic method invocation."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Generic Method Invocation{Colors.RESET}\n")
    print(f"{Colors.WARNING}⚠️  Advanced feature - Use with caution{Colors.RESET}")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Details:{Colors.RESET}")
    contract_address = get_input("Contract address")
    
    if not validate_address(contract_address):
        print(f"{Colors.ERROR}❌ Invalid contract address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    method_name = get_input("Method name (e.g., set_registry_address)")
    
    if not method_name:
        print(f"{Colors.ERROR}❌ Method name is required{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Get calldata
    print(f"\n{Colors.INFO}Enter calldata (one parameter per line, empty line to finish):{Colors.RESET}")
    calldata = []
    while True:
        param = input(f"  Parameter {len(calldata) + 1}: ").strip()
        if not param:
            break
        calldata.append(param)
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:  {environment}")
    print(f"  Contract:     {contract_address}")
    print(f"  Method:       {method_name}")
    print(f"  Calldata:     {calldata if calldata else '(none)'}")
    print()
    
    confirm = get_input("Proceed with invocation? (y/n)", "n").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Invoking method...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        result = deployer.invoke_setter_method(
            contract_address=contract_address,
            method_name=method_name,
            calldata=calldata
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Method invoked successfully!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
        else:
            print(f"\n{Colors.ERROR}❌ Invocation failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def set_payment_token_on_marketplace():
    """Interactive flow to set Payment Token on Marketplace."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set Payment Token on SessionsMarketplace{Colors.RESET}\n")
    print("This configures the ERC20 token to be used for payments in the marketplace.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Addresses:{Colors.RESET}")
    marketplace_address = get_input("SessionsMarketplace contract address")
    
    if not validate_address(marketplace_address):
        print(f"{Colors.ERROR}❌ Invalid Marketplace address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    payment_token_address = get_input("Payment Token (ERC20) contract address")
    
    if not validate_address(payment_token_address):
        print(f"{Colors.ERROR}❌ Invalid Payment Token address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:     {environment}")
    print(f"  Marketplace:     {marketplace_address}")
    print(f"  Payment Token:   {payment_token_address}")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        result = deployer.set_payment_token(
            marketplace_address=marketplace_address,
            payment_token_address=payment_token_address
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Payment Token configured successfully!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def set_pox_on_marketplace():
    """Interactive flow to set KliverPox on Marketplace."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set KliverPox Address on SessionsMarketplace{Colors.RESET}\n")
    print("This configures the Marketplace to mint POX NFTs when sales complete.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Contract Addresses:{Colors.RESET}")
    marketplace_address = get_input("SessionsMarketplace contract address")
    
    if not validate_address(marketplace_address):
        print(f"{Colors.ERROR}❌ Invalid Marketplace address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    pox_address = get_input("KliverPox contract address")
    
    if not validate_address(pox_address):
        print(f"{Colors.ERROR}❌ Invalid KliverPox address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:     {environment}")
    print(f"  Marketplace:     {marketplace_address}")
    print(f"  KliverPox:       {pox_address}")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        result = deployer.set_pox_address_on_marketplace(
            marketplace_address=marketplace_address,
            pox_address=pox_address
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ KliverPox configured successfully!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def set_purchase_timeout_on_marketplace():
    """Interactive flow to set Purchase Timeout on Marketplace."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Set Purchase Timeout on SessionsMarketplace{Colors.RESET}\n")
    print("This sets how long buyers have to submit proof after opening a purchase.")
    print()
    
    # Get parameters
    environment = select_environment()
    
    print(f"\n{Colors.BOLD}Enter Configuration:{Colors.RESET}")
    marketplace_address = get_input("SessionsMarketplace contract address")
    
    if not validate_address(marketplace_address):
        print(f"{Colors.ERROR}❌ Invalid Marketplace address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    timeout_str = get_input("Purchase timeout in seconds (e.g., 86400 for 24 hours)")
    
    try:
        timeout = int(timeout_str)
        if timeout <= 0:
            print(f"{Colors.ERROR}❌ Timeout must be positive{Colors.RESET}")
            input("\nPress Enter to continue...")
            return
    except ValueError:
        print(f"{Colors.ERROR}❌ Invalid timeout value{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Confirm
    print(f"\n{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Environment:     {environment}")
    print(f"  Marketplace:     {marketplace_address}")
    print(f"  Timeout:         {timeout} seconds ({timeout/3600:.1f} hours)")
    print()
    
    confirm = get_input("Proceed with configuration? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Operation cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🔧 Configuring...{Colors.RESET}\n")
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        result = deployer.set_purchase_timeout(
            marketplace_address=marketplace_address,
            timeout_seconds=timeout
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ Purchase timeout configured successfully!{Colors.RESET}")
            print(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                print(f"  {result['validation']}")
        else:
            print(f"\n{Colors.ERROR}❌ Configuration failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def main():
    """Main application loop."""
    while True:
        clear_screen()
        print_header()
        print_menu()
        
        choice = get_input("Select an option [0-12]")
        
        if choice == '1':
            set_registry_on_tokens_core()
        elif choice == '2':
            set_registry_on_marketplace()
        elif choice == '3':
            set_pox_on_registry()
        elif choice == '4':
            set_verifier_on_registry()
        elif choice == '5':
            set_payment_token_on_marketplace()
        elif choice == '6':
            set_pox_on_marketplace()
        elif choice == '7':
            set_purchase_timeout_on_marketplace()
        elif choice == '8':
            get_registry_address()
        elif choice == '9':
            get_pox_address()
        elif choice == '10':
            get_verifier_address()
        elif choice == '11':
            view_all_addresses()
        elif choice == '12':
            generic_invoke()
        elif choice == '0':
            clear_screen()
            print(f"{Colors.SUCCESS}👋 Thanks for using Kliver Configuration Tool!{Colors.RESET}\n")
            sys.exit(0)
        else:
            print(f"{Colors.ERROR}❌ Invalid option. Please try again.{Colors.RESET}")
            input("\nPress Enter to continue...")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        clear_screen()
        print(f"\n{Colors.WARNING}⚠️  Configuration cancelled by user{Colors.RESET}\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Unexpected error: {str(e)}{Colors.RESET}\n")
        sys.exit(1)
