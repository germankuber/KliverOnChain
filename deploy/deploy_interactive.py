#!/usr/bin/env python3
"""
Kliver Contracts Interactive Deployment Tool

Interactive CLI for deploying Kliver smart contracts with step-by-step guidance.
"""

import sys
from pathlib import Path
from typing import Optional, Dict, Any

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
    print("║     Kliver Smart Contracts - Interactive Deployment       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print(f"{Colors.RESET}\n")


def print_menu():
    """Print the main menu."""
    print(f"{Colors.BOLD}Deployment Menu:{Colors.RESET}\n")
    print(f"  {Colors.SUCCESS}1.{Colors.RESET} Deploy All Contracts (Recommended)")
    print(f"  {Colors.INFO}2.{Colors.RESET} Deploy KliverNFT")
    print(f"  {Colors.INFO}3.{Colors.RESET} Deploy KliverTokensCore")
    print(f"  {Colors.INFO}4.{Colors.RESET} Deploy KliverRegistry")
    print(f"  {Colors.INFO}5.{Colors.RESET} Deploy KliverPox")
    print(f"  {Colors.INFO}6.{Colors.RESET} Deploy SessionsMarketplace")
    print(f"  {Colors.INFO}7.{Colors.RESET} Deploy SimpleERC20 (Test Token)")
    print(f"  {Colors.WARNING}8.{Colors.RESET} View Deployment Order Info")
    print(f"  {Colors.ERROR}0.{Colors.RESET} Exit")
    print()


def get_input(prompt: str, default: str = None, allow_empty: bool = False) -> str:
    """Get user input with optional default value."""
    if default:
        prompt = f"{prompt} [{default}]: "
    else:
        prompt = f"{prompt}: "
    
    value = input(f"{Colors.INFO}{prompt}{Colors.RESET}").strip()
    
    if not value and not allow_empty and not default:
        return get_input(prompt.replace(': ', ''), default, allow_empty)
    
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
    env = env_map.get(choice, "local")
    
    # Show warning for prod
    if env == "prod":
        print(f"\n{Colors.ERROR}⚠️  WARNING: You are deploying to PRODUCTION (Mainnet)!{Colors.RESET}")
        confirm = get_input("Are you absolutely sure? Type 'YES' to continue", "").upper()
        if confirm != "YES":
            print(f"{Colors.WARNING}Switching to dev environment{Colors.RESET}")
            env = "dev"
    
    return env


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


def show_deployment_order():
    """Show information about deployment order and dependencies."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}Deployment Order & Dependencies{Colors.RESET}\n")
    
    print(f"{Colors.INFO}═══════════════════════════════════════════════════════════{Colors.RESET}")
    print(f"{Colors.BOLD}Recommended Deployment Order:{Colors.RESET}\n")
    
    print(f"{Colors.SUCCESS}1. KliverNFT{Colors.RESET}")
    print("   → No dependencies")
    print("   → ERC721 badge system for user access")
    print()
    
    print(f"{Colors.SUCCESS}2. KliverTokensCore{Colors.RESET}")
    print("   → No dependencies")
    print("   → ERC1155 multi-token system")
    print("   → Will be configured with Registry after Registry deployment")
    print()
    
    print(f"{Colors.SUCCESS}3. KliverRegistry{Colors.RESET}")
    print("   → Requires: NFT address + TokensCore address")
    print("   → Central hub for all registrations")
    print("   → Coordinates simulations, scenarios, characters, sessions")
    print()
    
    print(f"{Colors.SUCCESS}4. KliverPox{Colors.RESET}")
    print("   → Requires: Registry address")
    print("   → Session NFT minting contract")
    print("   → Will be configured in Registry after deployment")
    print()
    
    print(f"{Colors.SUCCESS}5. SessionsMarketplace (Optional){Colors.RESET}")
    print("   → Requires: Registry address + KliverPox address + Payment Token")
    print("   → Peer-to-peer marketplace for session NFTs")
    print()
    
    print(f"{Colors.INFO}═══════════════════════════════════════════════════════════{Colors.RESET}")
    print(f"\n{Colors.BOLD}Post-Deployment Configuration:{Colors.RESET}\n")
    
    print("After deployment, you must configure:")
    print("  1. TokensCore.set_registry_address(Registry)")
    print("  2. Registry.set_kliver_pox_address(KliverPox)")
    print("  3. Registry.set_verifier_address(Verifier) [optional]")
    print()
    
    print(f"{Colors.WARNING}💡 Tip: Use 'Deploy All Contracts' option for automatic deployment!{Colors.RESET}")
    print()
    
    input("Press Enter to return to menu...")


def deploy_all_contracts():
    """Interactive flow to deploy all contracts."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.SUCCESS}Deploy All Contracts{Colors.RESET}\n")
    print("This will deploy all Kliver contracts in the correct order:")
    print("  1. KliverNFT")
    print("  2. KliverTokensCore")
    print("  3. KliverRegistry")
    print("  4. KliverPox")
    print("  5. Configuration (TokensCore → Registry, Registry → KliverPox)")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Get optional parameters
    print(f"\n{Colors.BOLD}Optional Parameters:{Colors.RESET}")
    print(f"{Colors.INFO}(Press Enter to use defaults from configuration){Colors.RESET}\n")
    
    owner = get_input("Owner address (default: account address)", "", allow_empty=True)
    verifier = get_input("Verifier address (default: 0x0)", "0x0", allow_empty=True)
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment: {environment}")
    print(f"  Owner:       {owner if owner else '(use account address)'}")
    print(f"  Verifier:    {verifier}")
    print()
    print(f"{Colors.WARNING}⚠️  This will deploy 4 contracts and configure them{Colors.RESET}")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute deployment
    try:
        print(f"\n{Colors.INFO}{'='*60}{Colors.RESET}")
        print(f"{Colors.BOLD}Starting Complete Deployment...{Colors.RESET}")
        print(f"{Colors.INFO}{'='*60}{Colors.RESET}\n")
        
        config_manager = ConfigManager()
        
        # Import deploy function
        from kliver_deploy.deploy import deploy_all_contracts as deploy_all
        
        deployments = []
        success = deploy_all(
            config_manager,
            environment,
            owner if owner else None,
            verifier,
            deployments,
            no_compile=False
        )
        
        if success:
            print(f"\n{Colors.SUCCESS}{'='*60}{Colors.RESET}")
            print(f"{Colors.SUCCESS}✅ All Contracts Deployed Successfully!{Colors.RESET}")
            print(f"{Colors.SUCCESS}{'='*60}{Colors.RESET}\n")
            
            print(f"{Colors.BOLD}Save these addresses:{Colors.RESET}")
            for deployment in deployments:
                print(f"  {deployment['contract_type']:20} {deployment['contract_address']}")
            print()
            
            # Create JSON output
            import json
            addresses_json = {}
            for deployment in deployments:
                contract_type = deployment['contract_type']
                # Map contract types to JSON keys
                key_mapping = {
                    'nft': 'Nft',
                    'kliver_tokens_core': 'TokenSimulation',
                    'registry': 'Registry',
                    'kliver_pox': 'KliverPox',
                    'sessions_marketplace': 'MarketPlace',
                    'payment_token': 'PaymentToken'
                }
                json_key = key_mapping.get(contract_type, contract_type)
                addresses_json[json_key] = deployment['contract_address']
            
            # Print JSON
            print(f"{Colors.BOLD}JSON Output:{Colors.RESET}")
            print(json.dumps(addresses_json, indent=2))
            print()
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed. Check logs above.{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        import traceback
        traceback.print_exc()
    
    input("\nPress Enter to continue...")


def deploy_nft():
    """Interactive flow to deploy KliverNFT."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Deploy KliverNFT{Colors.RESET}\n")
    print("ERC721 badge system for platform access control.")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Get parameters
    print(f"\n{Colors.BOLD}Parameters:{Colors.RESET}")
    owner = get_input("Owner address (default: account address)", "", allow_empty=True)
    
    # Load config for base_uri
    config_manager = ConfigManager()
    contract_config = config_manager.get_contract_config(environment, 'nft')
    
    print(f"\n{Colors.INFO}Base URI will be: {contract_config.base_uri}{Colors.RESET}")
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment: {environment}")
    print(f"  Owner:       {owner if owner else '(account address)'}")
    print(f"  Base URI:    {contract_config.base_uri}")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🚀 Deploying KliverNFT...{Colors.RESET}\n")
        
        deployer = ContractDeployer(environment, 'nft', config_manager)
        result = deployer.deploy_full_flow(
            owner if owner else None,
            no_compile=False,
            base_uri=contract_config.base_uri
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ KliverNFT Deployed Successfully!{Colors.RESET}")
            print(f"\n{Colors.BOLD}Contract Address: {Colors.SUCCESS}{result['contract_address']}{Colors.RESET}")
            print(f"Class Hash: {result['class_hash']}")
            print()
            print(f"{Colors.WARNING}💡 Save this address for Registry deployment!{Colors.RESET}")
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def deploy_tokens_core():
    """Interactive flow to deploy KliverTokensCore."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Deploy KliverTokensCore{Colors.RESET}\n")
    print("ERC1155 multi-token system for simulation rewards.")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Get parameters
    print(f"\n{Colors.BOLD}Parameters:{Colors.RESET}")
    owner = get_input("Owner address (default: account address)", "", allow_empty=True)
    
    # Load config for base_uri
    config_manager = ConfigManager()
    contract_config = config_manager.get_contract_config(environment, 'kliver_tokens_core')
    
    print(f"\n{Colors.INFO}Base URI will be: {contract_config.base_uri}{Colors.RESET}")
    print(f"{Colors.WARNING}Note: You'll need to set Registry address after Registry is deployed{Colors.RESET}")
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment: {environment}")
    print(f"  Owner:       {owner if owner else '(account address)'}")
    print(f"  Base URI:    {contract_config.base_uri}")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🚀 Deploying KliverTokensCore...{Colors.RESET}\n")
        
        deployer = ContractDeployer(environment, 'kliver_tokens_core', config_manager)
        result = deployer.deploy_full_flow(
            owner if owner else None,
            no_compile=False,
            base_uri=contract_config.base_uri
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ KliverTokensCore Deployed Successfully!{Colors.RESET}")
            print(f"\n{Colors.BOLD}Contract Address: {Colors.SUCCESS}{result['contract_address']}{Colors.RESET}")
            print(f"Class Hash: {result['class_hash']}")
            print()
            print(f"{Colors.WARNING}💡 Save this address for Registry deployment!{Colors.RESET}")
            print(f"{Colors.WARNING}💡 Remember to call set_registry_address() after Registry is deployed!{Colors.RESET}")
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def deploy_registry():
    """Interactive flow to deploy KliverRegistry."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Deploy KliverRegistry{Colors.RESET}\n")
    print("Central hub coordinating all Kliver contracts.")
    print()
    print(f"{Colors.WARNING}⚠️  Required: NFT and TokensCore addresses{Colors.RESET}")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Get required addresses
    print(f"\n{Colors.BOLD}Required Contract Addresses:{Colors.RESET}")
    nft_address = get_input("KliverNFT contract address")
    
    if not validate_address(nft_address):
        print(f"{Colors.ERROR}❌ Invalid NFT address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    tokens_core_address = get_input("KliverTokensCore contract address")
    
    if not validate_address(tokens_core_address):
        print(f"{Colors.ERROR}❌ Invalid TokensCore address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Get optional parameters
    print(f"\n{Colors.BOLD}Optional Parameters:{Colors.RESET}")
    owner = get_input("Owner address (default: account address)", "", allow_empty=True)
    verifier_address = get_input("Verifier address (default: 0x0)", "0x0")
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment:  {environment}")
    print(f"  Owner:        {owner if owner else '(account address)'}")
    print(f"  NFT:          {nft_address}")
    print(f"  TokensCore:   {tokens_core_address}")
    print(f"  Verifier:     {verifier_address}")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🚀 Deploying KliverRegistry...{Colors.RESET}\n")
        
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        result = deployer.deploy_full_flow(
            owner if owner else None,
            no_compile=False,
            nft_address=nft_address,
            token_simulation_address=tokens_core_address,
            verifier_address=verifier_address
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ KliverRegistry Deployed Successfully!{Colors.RESET}")
            print(f"\n{Colors.BOLD}Contract Address: {Colors.SUCCESS}{result['contract_address']}{Colors.RESET}")
            print(f"Class Hash: {result['class_hash']}")
            print()
            print(f"{Colors.WARNING}💡 Next steps:{Colors.RESET}")
            print(f"   1. Set registry address on TokensCore")
            print(f"   2. Deploy KliverPox")
            print(f"   3. Set KliverPox address on Registry")
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def deploy_pox():
    """Interactive flow to deploy KliverPox."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Deploy KliverPox{Colors.RESET}\n")
    print("Session NFT minting contract (Proof of eXecution).")
    print()
    print(f"{Colors.WARNING}⚠️  Required: Registry address{Colors.RESET}")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Get required address
    print(f"\n{Colors.BOLD}Required Contract Address:{Colors.RESET}")
    registry_address = get_input("KliverRegistry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Get optional parameters
    print(f"\n{Colors.BOLD}Optional Parameters:{Colors.RESET}")
    owner = get_input("Owner address (default: account address)", "", allow_empty=True)
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment: {environment}")
    print(f"  Owner:       {owner if owner else '(account address)'}")
    print(f"  Registry:    {registry_address}")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🚀 Deploying KliverPox...{Colors.RESET}\n")
        
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'kliver_pox', config_manager)
        result = deployer.deploy_full_flow(
            owner if owner else None,
            no_compile=False,
            registry_address=registry_address
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ KliverPox Deployed Successfully!{Colors.RESET}")
            print(f"\n{Colors.BOLD}Contract Address: {Colors.SUCCESS}{result['contract_address']}{Colors.RESET}")
            print(f"Class Hash: {result['class_hash']}")
            print()
            print(f"{Colors.WARNING}💡 Remember to set KliverPox address on Registry!{Colors.RESET}")
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def deploy_marketplace():
    """Interactive flow to deploy SessionsMarketplace."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Deploy SessionsMarketplace{Colors.RESET}\n")
    print("P2P marketplace for trading session NFTs.")
    print()
    print(f"{Colors.WARNING}⚠️  Required: Registry, KliverPox, and Payment Token addresses{Colors.RESET}")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Get required addresses
    print(f"\n{Colors.BOLD}Required Contract Addresses:{Colors.RESET}")
    registry_address = get_input("KliverRegistry contract address")
    
    if not validate_address(registry_address):
        print(f"{Colors.ERROR}❌ Invalid Registry address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    pox_address = get_input("KliverPox contract address")
    
    if not validate_address(pox_address):
        print(f"{Colors.ERROR}❌ Invalid KliverPox address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    payment_token_address = get_input("Payment Token (ERC20) contract address")
    
    if not validate_address(payment_token_address):
        print(f"{Colors.ERROR}❌ Invalid Payment Token address{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Get timeout
    print(f"\n{Colors.BOLD}Marketplace Settings:{Colors.RESET}")
    purchase_timeout = get_input("Purchase timeout in seconds", "86400")  # 24 hours default
    
    try:
        purchase_timeout = int(purchase_timeout)
    except ValueError:
        print(f"{Colors.ERROR}❌ Invalid timeout value{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Get optional parameters
    owner = get_input("Owner address (default: account address)", "", allow_empty=True)
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment:    {environment}")
    print(f"  Owner:          {owner if owner else '(account address)'}")
    print(f"  Registry:       {registry_address}")
    print(f"  KliverPox:      {pox_address}")
    print(f"  Payment Token:  {payment_token_address}")
    print(f"  Timeout:        {purchase_timeout} seconds ({purchase_timeout/3600:.1f} hours)")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🚀 Deploying SessionsMarketplace...{Colors.RESET}\n")
        
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        result = deployer.deploy_full_flow(
            owner if owner else None,
            no_compile=False,
            registry_address=registry_address,
            pox_address=pox_address,
            payment_token_address=payment_token_address,
            purchase_timeout_seconds=purchase_timeout
        )
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ SessionsMarketplace Deployed Successfully!{Colors.RESET}")
            print(f"\n{Colors.BOLD}Contract Address: {Colors.SUCCESS}{result['contract_address']}{Colors.RESET}")
            print(f"Class Hash: {result['class_hash']}")
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def deploy_simple_erc20():
    """Interactive flow to deploy SimpleERC20."""
    clear_screen()
    print_header()
    print(f"{Colors.BOLD}{Colors.INFO}Deploy SimpleERC20{Colors.RESET}\n")
    print("Simple ERC20 token for testing purposes.")
    print(f"{Colors.WARNING}⚠️  For testing only - not for production use{Colors.RESET}")
    print()
    
    # Get environment
    environment = select_environment()
    
    # Confirm
    print(f"\n{Colors.BOLD}Deployment Summary:{Colors.RESET}")
    print(f"  Environment: {environment}")
    print(f"  Token Name:  SimpleToken")
    print(f"  Symbol:      STK")
    print(f"  Supply:      Minted to contract (use transfer to get tokens)")
    print()
    
    confirm = get_input("Proceed with deployment? (y/n)", "y").lower()
    
    if confirm != 'y':
        print(f"{Colors.WARNING}⚠️  Deployment cancelled{Colors.RESET}")
        input("\nPress Enter to continue...")
        return
    
    # Execute
    try:
        print(f"\n{Colors.INFO}🚀 Deploying SimpleERC20...{Colors.RESET}\n")
        
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'simple_erc20', config_manager)
        result = deployer.deploy_full_flow(None, no_compile=False)
        
        if result:
            print(f"\n{Colors.SUCCESS}✅ SimpleERC20 Deployed Successfully!{Colors.RESET}")
            print(f"\n{Colors.BOLD}Contract Address: {Colors.SUCCESS}{result['contract_address']}{Colors.RESET}")
            print(f"Class Hash: {result['class_hash']}")
            print()
            print(f"{Colors.WARNING}💡 Use this address as payment token for SessionsMarketplace{Colors.RESET}")
        else:
            print(f"\n{Colors.ERROR}❌ Deployment failed{Colors.RESET}")
    
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
    
    input("\nPress Enter to continue...")


def main():
    """Main application loop."""
    while True:
        clear_screen()
        print_header()
        print_menu()
        
        choice = get_input("Select an option [0-8]")
        
        if choice == '1':
            deploy_all_contracts()
        elif choice == '2':
            deploy_nft()
        elif choice == '3':
            deploy_tokens_core()
        elif choice == '4':
            deploy_registry()
        elif choice == '5':
            deploy_pox()
        elif choice == '6':
            deploy_marketplace()
        elif choice == '7':
            deploy_simple_erc20()
        elif choice == '8':
            show_deployment_order()
        elif choice == '0':
            clear_screen()
            print(f"{Colors.SUCCESS}👋 Thanks for using Kliver Deployment Tool!{Colors.RESET}\n")
            sys.exit(0)
        else:
            print(f"{Colors.ERROR}❌ Invalid option. Please try again.{Colors.RESET}")
            input("\nPress Enter to continue...")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        clear_screen()
        print(f"\n{Colors.WARNING}⚠️  Deployment cancelled by user{Colors.RESET}\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Colors.ERROR}❌ Unexpected error: {str(e)}{Colors.RESET}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)
