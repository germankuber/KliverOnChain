#!/usr/bin/env python3
"""
Kliver Contracts Deployment CLI

Modern, object-oriented deployment system for Kliver smart contracts.
"""

import click
from typing import Optional, List, Dict, Any

from kliver_deploy import ConfigManager, ContractDeployer
from kliver_deploy.utils import Colors, print_deployment_summary, print_deployment_json, format_address


@click.command()
@click.option('--environment', '-e', required=True, 
              help='Environment to deploy to: dev, qa, or prod')
@click.option('--contract', '-c', default='registry',
              help='Contract to deploy: registry, nft, kliver_tokens_core, or all')
@click.option('--owner', '-o', 
              help='Owner address for the contract (uses account address if not specified)')
@click.option('--nft-address', '-n',
              help='NFT contract address (required when deploying registry separately)')
@click.option('--tokens-core-address',
              help='Tokens Core contract address (required when deploying registry separately)')
@click.option('--verifier-address',
              help='Verifier contract address (optional for Registry, uses 0x0 if not provided)')
@click.option('--registry-address',
              help='Registry contract address (required for session_marketplace, sessions_marketplace if deploying separately)')
@click.option('--payment-token-address',
              help='Payment ERC20 address (required for sessions_marketplace)')
@click.option('--purchase-timeout', type=int,
              help='Purchase timeout in seconds (required for sessions_marketplace)')
@click.option('--verbose', '-v', is_flag=True, 
              help='Enable verbose output')
@click.option('--no-compile', is_flag=True, 
              help='Skip compilation step (use existing compiled contracts)')
@click.option('--output-json', is_flag=True, 
              help='Output deployment addresses in JSON format')
def deploy(environment: str, contract: str, owner: Optional[str],
           nft_address: Optional[str], tokens_core_address: Optional[str], verifier_address: Optional[str],
           registry_address: Optional[str], payment_token_address: Optional[str], purchase_timeout: Optional[int],
           verbose: bool, no_compile: bool, output_json: bool):
    """
    Deploy Kliver contracts to StarkNet using environment-based configuration.
    
    This modern deployment system provides:
    - Clean object-oriented architecture
    - Environment-based configuration management
    - Robust error handling and validation
    - Comprehensive deployment tracking
    
    DEPLOYMENT MODES:

    1. Deploy Everything (NFT → Token1155 → Registry → Configure Token1155):
        python deploy.py --environment dev --contract all

    2. Deploy Individual Contracts:
        python deploy.py --environment dev --contract nft
        python deploy.py --environment dev --contract kliver_tokens_core
        python deploy.py --environment dev --contract registry --nft-address 0x456... --tokens-core-address 0x789...

    3. Contract Dependencies:
        - NFT: No dependencies
        - Token1155: No dependencies (configured with Registry address after deployment)
        - Registry: Requires NFT address and Tokens Core address
    
    Example usage:
        python deploy.py --environment dev --contract all
        python deploy.py --environment qa --contract registry --nft-address 0x123... --tokens-core-address 0x456...
        python deploy.py --environment prod --contract kliver_tokens_core
    """
    
    try:
        # Initialize configuration manager
        config_manager = ConfigManager()
        
        # Validate environment
        available_envs = config_manager.get_available_environments()
        if environment not in available_envs:
            click.echo(f"{Colors.ERROR}❌ Invalid environment '{environment}'. Available: {available_envs}{Colors.RESET}")
            exit(1)
        
        # Load environment configuration
        env_config = config_manager.get_environment_config(environment)
        click.echo(f"{Colors.SUCCESS}✓ Environment '{environment}' loaded:{Colors.RESET}")
        click.echo(f"  Environment: {env_config.name}")
        click.echo(f"  Network: {env_config.network}")
        click.echo(f"  Account: {env_config.account}")
        click.echo(f"  RPC URL: {env_config.rpc_url}")
        
        # Validate contract type
        available_contracts = config_manager.get_available_contracts(environment)
        if contract not in available_contracts + ['all']:
            click.echo(f"{Colors.ERROR}❌ Invalid contract type '{contract}'. Available: {available_contracts + ['all']}{Colors.RESET}")
            exit(1)
            
        deployments: List[Dict[str, Any]] = []
        success = True
        
        if contract == 'all':
            success = deploy_all_contracts(
                config_manager, environment, owner, verifier_address, deployments, no_compile,
                payment_token_address=payment_token_address, purchase_timeout=purchase_timeout
            )
        else:
            success = deploy_single_contract(
                config_manager, environment, contract, owner,
                nft_address, tokens_core_address, registry_address, verifier_address,
                deployments=deployments, no_compile=no_compile,
                payment_token_address=payment_token_address, purchase_timeout=purchase_timeout,
            )
        
        # Show final summary
        if success and deployments:
            if output_json:
                print_deployment_json(deployments)
            elif contract == 'all':
                # Comprehensive summary already printed in deploy_all_contracts
                pass
            else:
                # Print comprehensive summary for single contract deployments
                print_comprehensive_summary(deployments, env_config.network)
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Deployment failed. Check the logs above for details.{Colors.RESET}")
            exit(1)
            
    except KeyboardInterrupt:
        click.echo(f"\n{Colors.WARNING}⚠️  Deployment interrupted by user{Colors.RESET}")
        exit(1)
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Unexpected error: {str(e)}{Colors.RESET}")
        if verbose:
            import traceback
            traceback.print_exc()
        exit(1)


def print_comprehensive_summary(deployments: List[Dict[str, Any]], network: str):
    """Print a comprehensive professional deployment summary."""
    print(f"\n{Colors.BOLD}{'='*100}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}🎯 COMPLETE DEPLOYMENT SUMMARY - {network.upper()}{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*100}{Colors.RESET}")

    for i, deployment in enumerate(deployments, 1):
        print(f"\n{Colors.BOLD}{Colors.BLUE}Contract {i}: {deployment['contract_name'].upper()}{Colors.RESET}")
        print(f"{Colors.BOLD}{'-'*50}{Colors.RESET}")

        # Basic contract info
        print(f"📋 {Colors.BOLD}Contract Details:{Colors.RESET}")
        print(f"   Name: {deployment['contract_name']}")
        print(f"   Type: {deployment['contract_type']}")
        print(f"   Address: {Colors.SUCCESS}{deployment['contract_address']}{Colors.RESET}")
        print(f"   Class Hash: {deployment['class_hash']}")
        print(f"   Owner: {format_address(deployment['owner'])}")

        # Deployment transaction
        if deployment.get('deployment_tx_hash'):
            print(f"\n🚀 {Colors.BOLD}Deployment Transaction:{Colors.RESET}")
            print(f"   Transaction Hash: {Colors.INFO}{deployment['deployment_tx_hash']}{Colors.RESET}")
            print(f"   Status: {Colors.SUCCESS}✓ Confirmed{Colors.RESET}")

        # Constructor parameters
        if deployment.get('constructor_params'):
            print(f"\n⚙️  {Colors.BOLD}Constructor Parameters:{Colors.RESET}")
            for param, value in deployment['constructor_params'].items():
                if isinstance(value, str) and len(value) > 40:
                    print(f"   {param}: {Colors.CYAN}{value[:37]}...{Colors.RESET}")
                elif param.endswith('_address'):
                    print(f"   {param}: {Colors.INFO}{value}{Colors.RESET}")
                else:
                    print(f"   {param}: {value}")

        # Post-deployment operations
        if deployment.get('post_deployment_ops'):
            print(f"\n🔧 {Colors.BOLD}Post-Deployment Operations:{Colors.RESET}")
            for j, op in enumerate(deployment['post_deployment_ops'], 1):
                print(f"   {j}. {Colors.BOLD}{op['method']}(){Colors.RESET}")
                if op.get('tx_hash'):
                    print(f"      Transaction: {Colors.INFO}{op['tx_hash']}{Colors.RESET}")
                if op.get('params'):
                    print(f"      Parameters: {op['params']}")
                if op.get('validation'):
                    print(f"      Validation: {Colors.SUCCESS}{op['validation']}{Colors.RESET}")

        # Dependencies
        deps = []
        for key, value in deployment.items():
            if key.endswith('_address') and key != 'contract_address':
                deps.append(f"{key.replace('_address', '').title()}: {value}")

        if deps:
            print(f"\n🔗 {Colors.BOLD}Dependencies:{Colors.RESET}")
            for dep in deps:
                print(f"   {dep}")

    print(f"\n{Colors.BOLD}{'='*100}{Colors.RESET}")
    print(f"{Colors.SUCCESS}✅ ALL CONTRACTS DEPLOYED AND CONFIGURED SUCCESSFULLY!{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*100}{Colors.RESET}")


def deploy_all_contracts(config_manager: ConfigManager, environment: str,
                         owner: Optional[str], verifier_address: Optional[str],
                         deployments: List[Dict[str, Any]], no_compile: bool = False,
                         payment_token_address: Optional[str] = None, purchase_timeout: Optional[int] = None) -> bool:
    """Deploy all contracts in the correct order."""
    click.echo(f"\n{Colors.BOLD}🚀 COMPLETE DEPLOYMENT MODE{Colors.RESET}")
    click.echo(f"{Colors.INFO}This will deploy: NFT → Token1155 → Registry (+ optional Marketplaces){Colors.RESET}\n")

    deployed_addresses = {}

    # Step 1: Deploy NFT
    click.echo(f"{Colors.BOLD}Step 1/3: Deploying NFT Contract{Colors.RESET}")
    nft_deployer = ContractDeployer(environment, 'nft', config_manager)

    # Get base_uri from config
    contract_config = config_manager.get_contract_config(environment, 'nft')
    nft_result = nft_deployer.deploy_full_flow(owner, no_compile=no_compile, base_uri=contract_config.base_uri)

    if nft_result:
        deployments.append(nft_result)
        deployed_addresses['nft'] = nft_result['contract_address']
        click.echo(f"\n{Colors.SUCCESS}✓ NFT deployed successfully at: {deployed_addresses['nft']}{Colors.RESET}\n")
    else:
        click.echo(f"\n{Colors.ERROR}✗ NFT deployment failed. Aborting.{Colors.RESET}")
        return False

    # Step 2: Deploy Token1155
    click.echo(f"{Colors.BOLD}Step 2/3: Deploying Token1155 Contract{Colors.RESET}")
    token_deployer = ContractDeployer(environment, 'kliver_tokens_core', config_manager)

    # Get base_uri from config
    token_config = config_manager.get_contract_config(environment, 'kliver_tokens_core')
    token_result = token_deployer.deploy_full_flow(owner, no_compile=no_compile, base_uri=token_config.base_uri)

    if token_result:
        deployments.append(token_result)
        deployed_addresses['token'] = token_result['contract_address']
        click.echo(f"\n{Colors.SUCCESS}✓ Token1155 deployed successfully at: {deployed_addresses['token']}{Colors.RESET}\n")
    else:
        click.echo(f"\n{Colors.ERROR}✗ Token1155 deployment failed. Aborting.{Colors.RESET}")
        return False

    # Step 3: Deploy Registry
    click.echo(f"{Colors.BOLD}Step 3/4: Deploying Registry Contract{Colors.RESET}")
    registry_deployer = ContractDeployer(environment, 'registry', config_manager)

    # Get verifier_address from config if not provided (for Registry deployments)
    if not verifier_address and contract == 'registry':
        registry_config = config_manager.get_contract_config(environment, 'registry')
        verifier_address = registry_config.verifier_address or "0x0"

    registry_result = registry_deployer.deploy_full_flow(
        owner,
        no_compile=no_compile,
        nft_address=deployed_addresses['nft'],
        tokens_core_address=deployed_addresses['token'],
        verifier_address=verifier_address
    )

    if registry_result:
        deployments.append(registry_result)
        deployed_addresses['registry'] = registry_result['contract_address']
        click.echo(f"\n{Colors.SUCCESS}✓ Registry deployed successfully at: {deployed_addresses['registry']}{Colors.RESET}\n")
    else:
        click.echo(f"\n{Colors.ERROR}✗ Registry deployment failed. Aborting.{Colors.RESET}")
        return False

    # Step 4: Configure Token1155 with Registry address
    click.echo(f"{Colors.BOLD}Step 4/4: Configuring Token1155 with Registry address{Colors.RESET}")
    click.echo(f"{Colors.INFO}Setting registry address on Token1155 contract...{Colors.RESET}")

    # Call set_registry_address on the Token1155 contract
    set_registry_result = registry_deployer.set_registry_on_tokencore(
        deployed_addresses['token'],
        deployed_addresses['registry'],
        owner
    )

    if set_registry_result:
        # Add post-deployment operation to the token deployment details
        if token_result and 'post_deployment_ops' not in token_result:
            token_result['post_deployment_ops'] = []
        if token_result:
            token_result['post_deployment_ops'].append(set_registry_result)

        click.echo(f"\n{Colors.SUCCESS}✓ Token1155 configured with Registry address{Colors.RESET}\n")

        # Optionally deploy marketplaces if configured
        # SessionMarketplace (simple)
        try:
            env_contracts = config_manager.load_config()["environments"][environment]["contracts"]
        except Exception:
            env_contracts = {}

        if 'session_marketplace' in env_contracts:
            click.echo(f"\n{Colors.BOLD}Step 5: Deploying SessionMarketplace (simple){Colors.RESET}")
            sm_deployer = ContractDeployer(environment, 'session_marketplace', config_manager)
            sm_result = sm_deployer.deploy_full_flow(owner, no_compile=no_compile,
                                                     registry_address=deployed_addresses['registry'])
            if sm_result:
                deployments.append(sm_result)
                deployed_addresses['session_marketplace'] = sm_result['contract_address']
                click.echo(f"{Colors.SUCCESS}✓ SessionMarketplace deployed at: {sm_result['contract_address']}{Colors.RESET}")
            else:
                click.echo(f"{Colors.ERROR}✗ SessionMarketplace deployment failed (skipping).{Colors.RESET}")

        if 'sessions_marketplace' in env_contracts:
            click.echo(f"\n{Colors.BOLD}Step 6: Deploying SessionsMarketplace (advanced){Colors.RESET}")
            adv_conf = config_manager.get_contract_config(environment, 'sessions_marketplace')
            adv_deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
            # Resolve payment token and timeout
            pay_token = payment_token_address or adv_conf.payment_token_address
            timeout_s = purchase_timeout or adv_conf.purchase_timeout_seconds
            if not pay_token or not timeout_s:
                click.echo(f"{Colors.WARNING}⚠️  Missing payment token or timeout for SessionsMarketplace. Skipping.{Colors.RESET}")
            else:
                adv_result = adv_deployer.deploy_full_flow(owner, no_compile=no_compile,
                                                           registry_address=deployed_addresses['registry'],
                                                           payment_token_address=pay_token,
                                                           purchase_timeout_seconds=timeout_s)
                if adv_result:
                    deployments.append(adv_result)
                    deployed_addresses['sessions_marketplace'] = adv_result['contract_address']
                    click.echo(f"{Colors.SUCCESS}✓ SessionsMarketplace deployed at: {adv_result['contract_address']}{Colors.RESET}")
                else:
                    click.echo(f"{Colors.ERROR}✗ SessionsMarketplace deployment failed (skipping).{Colors.RESET}")

        return True
    else:
        click.echo(f"\n{Colors.ERROR}✗ Failed to configure Token1155 with Registry address{Colors.RESET}")
        return False


def deploy_single_contract(config_manager: ConfigManager, environment: str,
                          contract: str, owner: Optional[str],
                          nft_address: Optional[str], tokens_core_address: Optional[str],
                          registry_address: Optional[str], verifier_address: Optional[str],
                          deployments: List[Dict[str, Any]], no_compile: bool = False,
                          payment_token_address: Optional[str] = None, purchase_timeout: Optional[int] = None) -> bool:
    """Deploy a single contract."""
    
    deployer = ContractDeployer(environment, contract, config_manager)
    
    # Prepare deployment parameters based on contract type
    deploy_kwargs = {}
    
    if contract == 'nft':
        click.echo(f"\n{Colors.BOLD}🎯 NFT-ONLY DEPLOYMENT{Colors.RESET}\n")
        contract_config = config_manager.get_contract_config(environment, contract)
        deploy_kwargs['base_uri'] = contract_config.base_uri
        
    elif contract == 'registry':
        if not nft_address:
            click.echo(f"\n{Colors.ERROR}❌ NFT address is required when deploying Registry separately{Colors.RESET}")
            click.echo(f"{Colors.INFO}Use: --nft-address 0x... or deploy with --contract all{Colors.RESET}\n")
            return False

        if not tokens_core_address:
            click.echo(f"\n{Colors.ERROR}❌ Tokens Core address is required when deploying Registry separately{Colors.RESET}")
            click.echo(f"{Colors.INFO}Use: --tokens-core-address 0x... or deploy with --contract all{Colors.RESET}\n")
            return False

        click.echo(f"\n{Colors.BOLD}🎯 SEPARATE REGISTRY DEPLOYMENT{Colors.RESET}")
        click.echo(f"{Colors.INFO}Using NFT contract at: {nft_address}{Colors.RESET}")
        click.echo(f"{Colors.INFO}Using Tokens Core contract at: {tokens_core_address}{Colors.RESET}\n")

        deploy_kwargs['nft_address'] = nft_address
        deploy_kwargs['tokens_core_address'] = tokens_core_address
        if not verifier_address:
            registry_config = config_manager.get_contract_config(environment, contract)
            verifier_address = registry_config.verifier_address or "0x0"
        deploy_kwargs['verifier_address'] = verifier_address
        
    elif contract == 'kliver_tokens_core':
        click.echo(f"\n{Colors.BOLD}🎯 TOKEN1155-ONLY DEPLOYMENT{Colors.RESET}\n")
        contract_config = config_manager.get_contract_config(environment, contract)
        deploy_kwargs['base_uri'] = contract_config.base_uri
    elif contract == 'session_marketplace':
        click.echo(f"\n{Colors.BOLD}🎯 SESSION MARKETPLACE DEPLOYMENT{Colors.RESET}\n")
        if not registry_address:
            click.echo(f"{Colors.ERROR}❌ Registry address is required --registry-address 0x...{Colors.RESET}")
            return False
        deploy_kwargs['registry_address'] = registry_address
    elif contract == 'sessions_marketplace':
        click.echo(f"\n{Colors.BOLD}🎯 SESSIONS MARKETPLACE DEPLOYMENT{Colors.RESET}\n")
        if not registry_address:
            click.echo(f"{Colors.ERROR}❌ Registry address is required --registry-address 0x...{Colors.RESET}")
            return False
        if not payment_token_address:
            contract_config = config_manager.get_contract_config(environment, contract)
            payment_token_address = contract_config.payment_token_address
        if not purchase_timeout:
            contract_config = config_manager.get_contract_config(environment, contract)
            purchase_timeout = contract_config.purchase_timeout_seconds
        if not payment_token_address or not purchase_timeout:
            click.echo(f"{Colors.ERROR}❌ Require --payment-token-address and --purchase-timeout (or config).{Colors.RESET}")
            return False
        deploy_kwargs.update({
            'registry_address': registry_address,
            'payment_token_address': payment_token_address,
            'purchase_timeout_seconds': purchase_timeout,
        })
    
    # Deploy the contract
    result = deployer.deploy_full_flow(owner, no_compile=no_compile, **deploy_kwargs)
    
    if result:
        deployments.append(result)
        return True
    else:
        return False


if __name__ == '__main__':
    deploy()
