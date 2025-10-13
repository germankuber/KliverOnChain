#!/usr/bin/env python3
"""
Interact with SimpleERC20 Token
Example script showing how to interact with the deployed ERC20 token
"""

import asyncio
import json
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair


async def interact_with_token():
    """Interact with deployed SimpleERC20 token"""
    
    # Configuration
    RPC_URL = "http://127.0.0.1:5050"  # Katana default
    
    # Load deployment info
    with open("deploy/deployment_simple_erc20.json", "r") as f:
        deployment_info = json.load(f)
    
    TOKEN_ADDRESS = deployment_info["contract_address"]
    
    # Accounts from Katana (first two default accounts)
    ACCOUNT1_ADDRESS = "0x6162896d1d7ab204c7ccac6dd5f8e9e7c25ecd5ae4fcb4ad32e57786bb46e03"
    ACCOUNT1_PRIVATE_KEY = "0x1800000000300000180000000000030000000000003006001800006600"
    
    ACCOUNT2_ADDRESS = "0x6b86e40118f29ebe393a75469b4d926c7a44c2e2681b6d319520b7c1156d114"
    ACCOUNT2_PRIVATE_KEY = "0x33003003001800039600"
    
    print("🎯 Interacting with SimpleERC20 Token...")
    print(f"Token Address: {TOKEN_ADDRESS}")
    
    # Initialize client
    client = FullNodeClient(node_url=RPC_URL)
    
    # Initialize accounts
    key_pair1 = KeyPair.from_private_key(int(ACCOUNT1_PRIVATE_KEY, 16))
    account1 = Account(
        client=client,
        address=ACCOUNT1_ADDRESS,
        key_pair=key_pair1,
        chain=StarknetChainId.TESTNET,
    )
    
    key_pair2 = KeyPair.from_private_key(int(ACCOUNT2_PRIVATE_KEY, 16))
    account2 = Account(
        client=client,
        address=ACCOUNT2_ADDRESS,
        key_pair=key_pair2,
        chain=StarknetChainId.TESTNET,
    )
    
    # Load contract ABI
    with open("target/dev/kliver_on_chain_SimpleERC20.contract_class.json", "r") as f:
        contract_class = json.load(f)
    
    # Initialize contract with account1
    token = Contract(
        address=TOKEN_ADDRESS,
        abi=contract_class["abi"],
        provider=account1,
    )
    
    print("\n📊 Initial Token Info:")
    
    # Get token info
    name = await token.functions["name"].call()
    symbol = await token.functions["symbol"].call()
    decimals = await token.functions["decimals"].call()
    total_supply = await token.functions["total_supply"].call()
    
    print(f"   Name: {name.name}")
    print(f"   Symbol: {symbol.symbol}")
    print(f"   Decimals: {decimals.decimals}")
    print(f"   Total Supply: {total_supply.total_supply}")
    
    # Check balances
    balance1 = await token.functions["balance_of"].call(account1.address)
    balance2 = await token.functions["balance_of"].call(account2.address)
    
    print(f"\n💰 Initial Balances:")
    print(f"   Account 1: {balance1.balance}")
    print(f"   Account 2: {balance2.balance}")
    
    # Transfer tokens from account1 to account2
    print("\n📤 Transferring tokens...")
    transfer_amount = 100_000 * 10**18  # 100k tokens
    
    transfer_call = await token.functions["transfer"].invoke(
        account2.address,
        transfer_amount,
        max_fee=int(1e16)
    )
    await transfer_call.wait_for_acceptance()
    print(f"   ✅ Transferred {transfer_amount} tokens to Account 2")
    print(f"   Transaction hash: {hex(transfer_call.hash)}")
    
    # Check new balances
    balance1_after = await token.functions["balance_of"].call(account1.address)
    balance2_after = await token.functions["balance_of"].call(account2.address)
    
    print(f"\n💰 Balances After Transfer:")
    print(f"   Account 1: {balance1_after.balance}")
    print(f"   Account 2: {balance2_after.balance}")
    
    # Approve account2 to spend tokens from account1
    print("\n✅ Approving allowance...")
    approve_amount = 50_000 * 10**18  # 50k tokens
    
    approve_call = await token.functions["approve"].invoke(
        account2.address,
        approve_amount,
        max_fee=int(1e16)
    )
    await approve_call.wait_for_acceptance()
    print(f"   ✅ Approved {approve_amount} tokens for Account 2")
    print(f"   Transaction hash: {hex(approve_call.hash)}")
    
    # Check allowance
    allowance = await token.functions["allowance"].call(account1.address, account2.address)
    print(f"\n📝 Allowance:")
    print(f"   Account 2 can spend: {allowance.remaining} tokens from Account 1")
    
    # Use transferFrom (account2 transfers from account1 to itself)
    print("\n📥 Using transferFrom...")
    token_with_account2 = Contract(
        address=TOKEN_ADDRESS,
        abi=contract_class["abi"],
        provider=account2,
    )
    
    transfer_from_amount = 25_000 * 10**18  # 25k tokens
    
    transfer_from_call = await token_with_account2.functions["transfer_from"].invoke(
        account1.address,
        account2.address,
        transfer_from_amount,
        max_fee=int(1e16)
    )
    await transfer_from_call.wait_for_acceptance()
    print(f"   ✅ TransferFrom executed: {transfer_from_amount} tokens")
    print(f"   Transaction hash: {hex(transfer_from_call.hash)}")
    
    # Final balances
    balance1_final = await token.functions["balance_of"].call(account1.address)
    balance2_final = await token.functions["balance_of"].call(account2.address)
    allowance_final = await token.functions["allowance"].call(account1.address, account2.address)
    
    print(f"\n💰 Final Balances:")
    print(f"   Account 1: {balance1_final.balance}")
    print(f"   Account 2: {balance2_final.balance}")
    print(f"\n📝 Remaining Allowance:")
    print(f"   Account 2 can still spend: {allowance_final.remaining} tokens from Account 1")
    
    print("\n✨ Interaction completed successfully!")


if __name__ == "__main__":
    asyncio.run(interact_with_token())
