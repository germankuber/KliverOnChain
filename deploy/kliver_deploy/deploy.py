#!/usr/bin/env python3
"""
Kliver Contracts Deployment CLI

Modern, object-oriented deployment system for Kliver smart contracts.
"""

import click
from typing import Optional, List, Dict, Any

from kliver_deploy import ConfigManager, ContractDeployer
from kliver_deploy.utils import Colors, print_deployment_summary


@click.command()
@click.option('--environment', '-e', required=True, 
              help='Environment to deploy to: dev, qa, or prod')
@click.option('--contract', '-c', default='registry', 
              help='Contract to deploy: registry, nft, kliver_1155, simulation_core, or all')
@click.option('--owner', '-o', 
              help='Owner address for the contract (uses account address if not specified)')
@click.option('--nft-address', '-n', 
              help='NFT contract address (required when deploying registry separately)')
@click.option('--registry-address', 
              help='Registry contract address (required for SimulationCore)')
@click.option('--token-address', 
              help='Token contract address (required for SimulationCore)')
@click.option('--verifier-address', 
              help='Verifier contract address (optional for Registry, uses 0x0 if not provided)')
@click.option('--verbose', '-v', is_flag=True, 
              help='Enable verbose output')
@click.option('--no-compile', is_flag=True, 
              help='Skip compilation step (use existing compiled contracts)')
def deploy(environment: str, contract: str, owner: Optional[str], 
           nft_address: Optional[str], registry_address: Optional[str], 
           token_address: Optional[str], verifier_address: Optional[str], 
           verbose: bool, no_compile: bool):
    """
    Deploy Kliver contracts to StarkNet using environment-based configuration.
    
    This modern deployment system provides:
    - Clean object-oriented architecture
    - Environment-based configuration management
    - Robust error handling and validation
    - Comprehensive deployment tracking
    
    DEPLOYMENT MODES:
    
    1. Deploy Everything (NFT → Registry → Token1155 → SimulationCore):
        python deploy.py --environment dev --contract all
    
    2. Deploy Individual Contracts:
        python deploy.py --environment dev --contract nft
        python deploy.py --environment dev --contract kliver_1155
        python deploy.py --environment dev --contract registry --nft-address 0x456...
        python deploy.py --environment dev --contract simulation_core --registry-address 0x123... --token-address 0x789...
    
    3. Contract Dependencies:
        - NFT: No dependencies
        - Token1155: No dependencies  
        - Registry: Requires NFT address
        - SimulationCore: Requires Registry + Token1155 addresses
    
    Example usage:
        python deploy.py --environment dev --contract all
        python deploy.py --environment qa --contract simulation_core --registry-address 0x123... --token-address 0x789...
        python deploy.py --environment prod --contract kliver_1155
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
                config_manager, environment, owner, verifier_address, deployments, no_compile
            )
        else:
            success = deploy_single_contract(
                config_manager, environment, contract, owner, 
                nft_address, registry_address, token_address, verifier_address,
                deployments, no_compile
            )
        
        # Show final summary
        if success and deployments:
            print_deployment_summary(deployments, env_config.network)
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
        if verbose:
            import traceback
            traceback.print_exc()
        exit(1)


def deploy_all_contracts(config_manager: ConfigManager, environment: str, 
                        owner: Optional[str], verifier_address: Optional[str],
                        deployments: List[Dict[str, Any]], no_compile: bool = False) -> bool:
    """Deploy all contracts in the correct order."""
    click.echo(f"\n{Colors.BOLD}🚀 COMPLETE DEPLOYMENT MODE{Colors.RESET}")
    click.echo(f"{Colors.INFO}This will deploy: NFT → Registry → Token1155 → SimulationCore{Colors.RESET}\n")
    
    deployed_addresses = {}
    
    # Step 1: Deploy NFT
    click.echo(f"{Colors.BOLD}Step 1/4: Deploying NFT Contract{Colors.RESET}")
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

    # Step 2: Deploy Registry
    click.echo(f"{Colors.BOLD}Step 2/4: Deploying Registry Contract{Colors.RESET}")
    registry_deployer = ContractDeployer(environment, 'registry', config_manager)
    
    # Get verifier_address from config if not provided
    if not verifier_address:
        registry_config = config_manager.get_contract_config(environment, 'registry')
        verifier_address = registry_config.verifier_address or "0x0"
    
    registry_result = registry_deployer.deploy_full_flow(
        owner, 
        no_compile=no_compile,
        nft_address=deployed_addresses['nft'],
        verifier_address=verifier_address
    )
    
    if registry_result:
        deployments.append(registry_result)
        deployed_addresses['registry'] = registry_result['contract_address']
        click.echo(f"\n{Colors.SUCCESS}✓ Registry deployed successfully at: {deployed_addresses['registry']}{Colors.RESET}\n")
    else:
        click.echo(f"\n{Colors.ERROR}✗ Registry deployment failed. Aborting.{Colors.RESET}")
        return False

    # Step 3: Deploy Token1155
    click.echo(f"{Colors.BOLD}Step 3/4: Deploying Token1155 Contract{Colors.RESET}")
    token_deployer = ContractDeployer(environment, 'kliver_1155', config_manager)
    
    # Get base_uri from config
    token_config = config_manager.get_contract_config(environment, 'kliver_1155')
    token_result = token_deployer.deploy_full_flow(owner, no_compile=no_compile, base_uri=token_config.base_uri)
    
    if token_result:
        deployments.append(token_result)
        deployed_addresses['token'] = token_result['contract_address']
        click.echo(f"\n{Colors.SUCCESS}✓ Token1155 deployed successfully at: {deployed_addresses['token']}{Colors.RESET}\n")
    else:
        click.echo(f"\n{Colors.ERROR}✗ Token1155 deployment failed. Aborting.{Colors.RESET}")
        return False

    # Step 4: Deploy SimulationCore
    click.echo(f"{Colors.BOLD}Step 4/4: Deploying SimulationCore Contract{Colors.RESET}")
    core_deployer = ContractDeployer(environment, 'simulation_core', config_manager)
    
    core_result = core_deployer.deploy_full_flow(
        owner,
        no_compile=no_compile,
        registry_address=deployed_addresses['registry'],
        token_address=deployed_addresses['token']
    )
    
    if core_result:
        deployments.append(core_result)
        click.echo(f"\n{Colors.SUCCESS}✓ SimulationCore deployed successfully{Colors.RESET}\n")
        return True
    else:
        click.echo(f"\n{Colors.ERROR}✗ SimulationCore deployment failed{Colors.RESET}")
        return False


def deploy_single_contract(config_manager: ConfigManager, environment: str, 
                          contract: str, owner: Optional[str],
                          nft_address: Optional[str], registry_address: Optional[str], 
                          token_address: Optional[str], verifier_address: Optional[str],
                          deployments: List[Dict[str, Any]], no_compile: bool = False) -> bool:
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
        
        click.echo(f"\n{Colors.BOLD}🎯 SEPARATE REGISTRY DEPLOYMENT{Colors.RESET}")
        click.echo(f"{Colors.INFO}Using NFT contract at: {nft_address}{Colors.RESET}\n")
        
        deploy_kwargs['nft_address'] = nft_address
        if not verifier_address:
            registry_config = config_manager.get_contract_config(environment, contract)
            verifier_address = registry_config.verifier_address or "0x0"
        deploy_kwargs['verifier_address'] = verifier_address
        
    elif contract == 'kliver_1155':
        click.echo(f"\n{Colors.BOLD}🎯 TOKEN1155-ONLY DEPLOYMENT{Colors.RESET}\n")
        contract_config = config_manager.get_contract_config(environment, contract)
        deploy_kwargs['base_uri'] = contract_config.base_uri
        
    elif contract == 'simulation_core':
        if not registry_address:
            click.echo(f"\n{Colors.ERROR}❌ Registry address is required for SimulationCore{Colors.RESET}")
            click.echo(f"{Colors.INFO}Use: --registry-address 0x... or deploy with --contract all{Colors.RESET}\n")
            return False
        if not token_address:
            click.echo(f"\n{Colors.ERROR}❌ Token address is required for SimulationCore{Colors.RESET}")
            click.echo(f"{Colors.INFO}Use: --token-address 0x... or deploy with --contract all{Colors.RESET}\n")
            return False
        
        click.echo(f"\n{Colors.BOLD}🎯 SEPARATE SIMULATIONCORE DEPLOYMENT{Colors.RESET}")
        click.echo(f"{Colors.INFO}Using Registry contract at: {registry_address}{Colors.RESET}")
        click.echo(f"{Colors.INFO}Using Token contract at: {token_address}{Colors.RESET}\n")
        
        deploy_kwargs['registry_address'] = registry_address
        deploy_kwargs['token_address'] = token_address
    
    # Deploy the contract
    result = deployer.deploy_full_flow(owner, no_compile=no_compile, **deploy_kwargs)
    
    if result:
        deployments.append(result)
        return True
    else:
        return False


if __name__ == '__main__':
    deploy()