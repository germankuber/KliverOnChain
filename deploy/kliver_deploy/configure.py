#!/usr/bin/env python3
"""
Kliver Contracts Configuration CLI

Tool for configuring deployed contracts (setting addresses, updating references, etc.)
"""

import click
from typing import Optional

from kliver_deploy import ConfigManager, ContractDeployer
from kliver_deploy.utils import Colors


@click.group()
def cli():
    """Kliver Smart Contracts Configuration Tool"""
    pass


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--contract-address', '-c', required=True,
              help='Address of the TokensCore or SessionsMarketplace contract')
@click.option('--registry-address', '-r', required=True,
              help='Address of the Registry contract')
@click.option('--contract-type', '-t', default='kliver_tokens_core',
              help='Contract type: kliver_tokens_core or sessions_marketplace')
def set_registry(environment: str, contract_address: str, registry_address: str, contract_type: str):
    """
    Set registry address on TokensCore or SessionsMarketplace contract.
    
    Examples:
        python -m kliver_deploy.configure set-registry -e dev -c 0x123... -r 0x456... -t kliver_tokens_core
        python -m kliver_deploy.configure set-registry -e dev -c 0x789... -r 0x456... -t sessions_marketplace
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, contract_type, config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Setting Registry Address{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Contract: {contract_address}")
        click.echo(f"  Registry: {registry_address}")
        click.echo(f"  Type: {contract_type}\n")
        
        result = deployer.set_registry_address(
            contract_address=contract_address,
            registry_address=registry_address,
            contract_name=contract_type
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ Registry address set successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                click.echo(f"  {result['validation']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to set registry address{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--registry-address', '-r', required=True,
              help='Address of the Registry contract')
@click.option('--pox-address', '-p', required=True,
              help='Address of the KliverPox contract')
def set_pox(environment: str, registry_address: str, pox_address: str):
    """
    Set KliverPox address on Registry contract.
    
    Example:
        python -m kliver_deploy.configure set-pox -e dev -r 0x123... -p 0x456...
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Setting KliverPox Address{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Registry: {registry_address}")
        click.echo(f"  KliverPox: {pox_address}\n")
        
        result = deployer.set_kliver_pox_address(
            registry_address=registry_address,
            pox_address=pox_address
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ KliverPox address set successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                click.echo(f"  {result['validation']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to set KliverPox address{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--registry-address', '-r', required=True,
              help='Address of the Registry contract')
@click.option('--verifier-address', '-v', required=True,
              help='Address of the Verifier contract')
def set_verifier(environment: str, registry_address: str, verifier_address: str):
    """
    Set Verifier address on Registry contract.
    
    Example:
        python -m kliver_deploy.configure set-verifier -e dev -r 0x123... -v 0x456...
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Setting Verifier Address{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Registry: {registry_address}")
        click.echo(f"  Verifier: {verifier_address}\n")
        
        result = deployer.set_verifier_address(
            registry_address=registry_address,
            verifier_address=verifier_address
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ Verifier address set successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                click.echo(f"  {result['validation']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to set verifier address{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--contract-address', '-c', required=True,
              help='Address of the contract')
@click.option('--method', '-m', required=True,
              help='View method to call (e.g., get_registry_address)')
def get_address(environment: str, contract_address: str, method: str):
    """
    Get an address from a contract (call a view method).
    
    Examples:
        python -m kliver_deploy.configure get-address -e dev -c 0x123... -m get_registry_address
        python -m kliver_deploy.configure get-address -e dev -c 0x456... -m get_kliver_pox_address
        python -m kliver_deploy.configure get-address -e dev -c 0x789... -m get_verifier_address
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔍 Getting Address{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Contract: {contract_address}")
        click.echo(f"  Method: {method}\n")
        
        result = deployer.call_view_method(
            contract_address=contract_address,
            method_name=method
        )
        
        if result:
            click.echo(f"{Colors.SUCCESS}✅ Result: {result}{Colors.RESET}")
            exit(0)
        else:
            click.echo(f"{Colors.ERROR}❌ Failed to call method{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--marketplace-address', '-m', required=True,
              help='Address of the SessionsMarketplace contract')
@click.option('--payment-token-address', '-p', required=True,
              help='Address of the ERC20 payment token')
def set_payment_token(environment: str, marketplace_address: str, payment_token_address: str):
    """
    Set payment token address on SessionsMarketplace contract.
    
    Example:
        python -m kliver_deploy.configure set-payment-token -e dev -m 0x123... -p 0x456...
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Setting Payment Token Address{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Marketplace: {marketplace_address}")
        click.echo(f"  Payment Token: {payment_token_address}\n")
        
        result = deployer.set_payment_token(
            marketplace_address=marketplace_address,
            payment_token_address=payment_token_address
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ Payment Token address set successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                click.echo(f"  {result['validation']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to set payment token address{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--marketplace-address', '-m', required=True,
              help='Address of the SessionsMarketplace contract')
@click.option('--pox-address', '-p', required=True,
              help='Address of the KliverPox contract')
def set_marketplace_pox(environment: str, marketplace_address: str, pox_address: str):
    """
    Set KliverPox address on SessionsMarketplace contract.
    
    Example:
        python -m kliver_deploy.configure set-marketplace-pox -e dev -m 0x123... -p 0x456...
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Setting KliverPox Address on Marketplace{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Marketplace: {marketplace_address}")
        click.echo(f"  KliverPox: {pox_address}\n")
        
        result = deployer.set_pox_address_on_marketplace(
            marketplace_address=marketplace_address,
            pox_address=pox_address
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ KliverPox address set successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                click.echo(f"  {result['validation']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to set KliverPox address{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--marketplace-address', '-m', required=True,
              help='Address of the SessionsMarketplace contract')
@click.option('--timeout', '-t', required=True, type=int,
              help='Purchase timeout in seconds')
def set_timeout(environment: str, marketplace_address: str, timeout: int):
    """
    Set purchase timeout on SessionsMarketplace contract.
    
    Example:
        python -m kliver_deploy.configure set-timeout -e dev -m 0x123... -t 86400
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'sessions_marketplace', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Setting Purchase Timeout{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Marketplace: {marketplace_address}")
        click.echo(f"  Timeout: {timeout} seconds ({timeout/3600:.1f} hours)\n")
        
        result = deployer.set_purchase_timeout(
            marketplace_address=marketplace_address,
            timeout_seconds=timeout
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ Purchase timeout set successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            if result.get('validation'):
                click.echo(f"  {result['validation']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to set purchase timeout{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


@cli.command()
@click.option('--environment', '-e', required=True,
              help='Environment: dev, qa, or prod')
@click.option('--contract-address', '-c', required=True,
              help='Address of the contract')
@click.option('--method', '-m', required=True,
              help='Method to invoke')
@click.option('--calldata', '-d', multiple=True,
              help='Calldata parameters (can be specified multiple times)')
def invoke(environment: str, contract_address: str, method: str, calldata: tuple):
    """
    Generic method to invoke any setter on a contract.
    
    Example:
        python -m kliver_deploy.configure invoke -e dev -c 0x123... -m set_registry_address -d 0x456...
    """
    try:
        config_manager = ConfigManager()
        deployer = ContractDeployer(environment, 'registry', config_manager)
        
        click.echo(f"\n{Colors.BOLD}🔧 Invoking Method{Colors.RESET}")
        click.echo(f"  Environment: {environment}")
        click.echo(f"  Contract: {contract_address}")
        click.echo(f"  Method: {method}")
        click.echo(f"  Calldata: {list(calldata)}\n")
        
        result = deployer.invoke_setter_method(
            contract_address=contract_address,
            method_name=method,
            calldata=list(calldata)
        )
        
        if result:
            click.echo(f"\n{Colors.SUCCESS}✅ Method invoked successfully!{Colors.RESET}")
            click.echo(f"  Transaction: {result['tx_hash']}")
            exit(0)
        else:
            click.echo(f"\n{Colors.ERROR}❌ Failed to invoke method{Colors.RESET}")
            exit(1)
            
    except Exception as e:
        click.echo(f"\n{Colors.ERROR}❌ Error: {str(e)}{Colors.RESET}")
        exit(1)


if __name__ == '__main__':
    cli()
