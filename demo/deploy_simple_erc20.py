#!/usr/bin/env python3
"""
Deploy SimpleERC20 Token
Example deployment script for the demo ERC20 token implementation
"""

import asyncio
import json
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair


async def deploy_simple_erc20():
    """Deploy SimpleERC20 token contract"""
    
    # Configuration
    RPC_URL = "http://127.0.0.1:5050"  # Katana default
    
    # Account from Katana (first default account)
    ACCOUNT_ADDRESS = "0x6162896d1d7ab204c7ccac6dd5f8e9e7c25ecd5ae4fcb4ad32e57786bb46e03"
    PRIVATE_KEY = "0x1800000000300000180000000000030000000000003006001800006600"
    
    # Token parameters
    TOKEN_NAME = "Kliver Demo Token"
    TOKEN_SYMBOL = "KDEMO"
    INITIAL_SUPPLY = 1_000_000 * 10**18  # 1 million tokens with 18 decimals
    
    print("🚀 Deploying SimpleERC20 Token...")
    print(f"Network: {RPC_URL}")
    print(f"Token Name: {TOKEN_NAME}")
    print(f"Token Symbol: {TOKEN_SYMBOL}")
    print(f"Initial Supply: {INITIAL_SUPPLY}")
    
    # Initialize client and account
    client = FullNodeClient(node_url=RPC_URL)
    key_pair = KeyPair.from_private_key(int(PRIVATE_KEY, 16))
    account = Account(
        client=client,
        address=ACCOUNT_ADDRESS,
        key_pair=key_pair,
        chain=StarknetChainId.TESTNET,
    )
    
    print(f"\n📋 Deployer Account: {hex(account.address)}")
    
    # Load compiled contract
    with open("target/dev/kliver_on_chain_SimpleERC20.contract_class.json", "r") as f:
        contract_class = json.load(f)
    
    with open("target/dev/kliver_on_chain_SimpleERC20.compiled_contract_class.json", "r") as f:
        compiled_contract_class = json.load(f)
    
    # Declare contract
    print("\n📝 Declaring contract...")
    declare_result = await Contract.declare_v2(
        account=account,
        compiled_contract=contract_class,
        compiled_contract_casm=compiled_contract_class,
        max_fee=int(1e16),
    )
    await declare_result.wait_for_acceptance()
    print(f"✅ Contract declared!")
    print(f"   Class Hash: {hex(declare_result.class_hash)}")
    
    # Prepare constructor arguments
    # Constructor expects: initial_supply, recipient, name, symbol
    constructor_args = {
        "initial_supply": INITIAL_SUPPLY,
        "recipient": account.address,
        "name": TOKEN_NAME,
        "symbol": TOKEN_SYMBOL,
    }
    
    # Deploy contract
    print("\n🔨 Deploying contract...")
    deploy_result = await declare_result.deploy_v1(
        constructor_args=constructor_args,
        max_fee=int(1e16),
    )
    await deploy_result.wait_for_acceptance()
    
    contract_address = deploy_result.deployed_contract.address
    print(f"✅ Contract deployed successfully!")
    print(f"   Contract Address: {hex(contract_address)}")
    
    # Save deployment info
    deployment_info = {
        "contract_name": "SimpleERC20",
        "contract_address": hex(contract_address),
        "class_hash": hex(declare_result.class_hash),
        "deployer": hex(account.address),
        "token_name": TOKEN_NAME,
        "token_symbol": TOKEN_SYMBOL,
        "initial_supply": str(INITIAL_SUPPLY),
        "network": RPC_URL,
    }
    
    output_file = "deploy/deployment_simple_erc20.json"
    with open(output_file, "w") as f:
        json.dump(deployment_info, f, indent=2)
    
    print(f"\n💾 Deployment info saved to: {output_file}")
    
    # Verify deployment by reading token info
    print("\n🔍 Verifying deployment...")
    token_contract = Contract(
        address=contract_address,
        abi=contract_class["abi"],
        provider=account,
    )
    
    name = await token_contract.functions["name"].call()
    symbol = await token_contract.functions["symbol"].call()
    total_supply = await token_contract.functions["total_supply"].call()
    balance = await token_contract.functions["balance_of"].call(account.address)
    
    print(f"   Name: {name.name}")
    print(f"   Symbol: {symbol.symbol}")
    print(f"   Total Supply: {total_supply.total_supply}")
    print(f"   Deployer Balance: {balance.balance}")
    
    print("\n✨ Deployment completed successfully!")
    
    return deployment_info


if __name__ == "__main__":
    asyncio.run(deploy_simple_erc20())
