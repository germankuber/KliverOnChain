// Import NFT interface
use kliver_on_chain::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
    start_cheat_caller_address, stop_cheat_block_timestamp_global, stop_cheat_caller_address,
};
use starknet::ContractAddress;

/// Helper function to deploy the NFT contract
fn deploy_nft_contract() -> (IKliverNFTDispatcher, ContractAddress) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract = declare("KliverNFT").unwrap().contract_class();

    // Base URI as ByteArray - empty for now
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    // Empty ByteArray: 0 length segments
    constructor_calldata.append(0);
    constructor_calldata.append(0);
    constructor_calldata.append(0);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (IKliverNFTDispatcher { contract_address }, owner)
}

#[test]
fn test_nft_constructor() {
    let (dispatcher, expected_owner) = deploy_nft_contract();

    // Test that contract was initialized correctly
    // We can test this by trying to mint (should work for owner)
    let user: ContractAddress = 'user'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, expected_owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify NFT was minted
    let has_nft = dispatcher.user_has_nft(user);
    assert(has_nft, 'NFT should be minted');
}

#[test]
fn test_mint_to_user_success() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify NFT was minted
    let has_nft = dispatcher.user_has_nft(user);
    assert(has_nft, 'User should have NFT');

    let token_id = dispatcher.get_user_token_id(user);
    assert(token_id == 1, 'Token ID should be 1');

    let total_supply = dispatcher.total_supply();
    assert(total_supply == 1, 'Total supply should be 1');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_to_user_not_owner() {
    let (dispatcher, _) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();
    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, not_owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid address',))]
fn test_mint_to_user_zero_address() {
    let (dispatcher, owner) = deploy_nft_contract();
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(zero_address);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('User already has Kliver NFT',))]
fn test_mint_to_user_already_has_nft() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    // Try to mint again - should fail
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_user_has_nft() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user_with_nft: ContractAddress = 'user1'.try_into().unwrap();
    let user_without_nft: ContractAddress = 'user2'.try_into().unwrap();

    // Mint NFT to first user
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user_with_nft);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check NFT status
    let has_nft_1 = dispatcher.user_has_nft(user_with_nft);
    let has_nft_2 = dispatcher.user_has_nft(user_without_nft);

    assert(has_nft_1, 'User should have NFT');
    assert(!has_nft_2, 'User should not have NFT');
}

#[test]
fn test_get_user_token_id() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user1: ContractAddress = 'user1'.try_into().unwrap();
    let user2: ContractAddress = 'user2'.try_into().unwrap();

    // Mint NFTs
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user1);
    dispatcher.mint_to_user(user2);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check token IDs
    let token_id_1 = dispatcher.get_user_token_id(user1);
    let token_id_2 = dispatcher.get_user_token_id(user2);
    let token_id_none = dispatcher.get_user_token_id('no_nft'.try_into().unwrap());

    assert(token_id_1 == 1, 'User1 token ID wrong');
    assert(token_id_2 == 2, 'User2 token ID wrong');
    assert(token_id_none == 0, 'No NFT token ID wrong');
}

#[test]
fn test_total_supply() {
    let (dispatcher, owner) = deploy_nft_contract();

    // Initially should be 0
    let initial_supply = dispatcher.total_supply();
    assert(initial_supply == 0, 'Initial supply should be 0');

    // Mint some NFTs
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user('user1'.try_into().unwrap());
    dispatcher.mint_to_user('user2'.try_into().unwrap());
    dispatcher.mint_to_user('user3'.try_into().unwrap());
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check total supply
    let final_supply = dispatcher.total_supply();
    assert(final_supply == 3, 'Final supply should be 3');
}

#[test]
fn test_get_minted_at() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    // Set block timestamp to a known value
    let expected_timestamp: u64 = 1000000;
    start_cheat_block_timestamp_global(expected_timestamp);

    // Mint NFT
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    stop_cheat_block_timestamp_global();

    // Get token ID and check minted timestamp
    let token_id = dispatcher.get_user_token_id(user);
    let minted_at = dispatcher.get_minted_at(token_id);

    // Timestamp should match what we set
    assert(minted_at == expected_timestamp, 'Wrong timestamp');
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_get_minted_at_nonexistent_token() {
    let (dispatcher, _) = deploy_nft_contract();

    // Try to get timestamp for non-existent token
    dispatcher.get_minted_at(999);
}

#[test]
fn test_burn_user_nft_success() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    // Mint NFT first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify NFT exists
    let has_nft_before = dispatcher.user_has_nft(user);
    assert(has_nft_before, 'NFT should exist');

    // Burn NFT
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.burn_user_nft(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify NFT was burned
    let has_nft_after = dispatcher.user_has_nft(user);
    assert(!has_nft_after, 'NFT not burned');

    let token_id = dispatcher.get_user_token_id(user);
    assert(token_id == 0, 'Token ID should be 0 after burn');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_burn_user_nft_not_owner() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();
    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();

    // Mint NFT first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to burn as non-owner
    start_cheat_caller_address(dispatcher.contract_address, not_owner);
    dispatcher.burn_user_nft(user);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('User has no NFT to burn',))]
fn test_burn_user_nft_no_nft() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    // Try to burn NFT when user doesn't have one
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.burn_user_nft(user);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Kliver NFT is soulbound',))]
fn test_nft_transfer_blocked() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user1: ContractAddress = 'user1'.try_into().unwrap();
    let user2: ContractAddress = 'user2'.try_into().unwrap();

    // Mint NFT to user1
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user1);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Get the token ID
    let token_id = dispatcher.get_user_token_id(user1);

    // Create ERC721 dispatcher
    let erc721_dispatcher = IERC721Dispatcher { contract_address: dispatcher.contract_address };

    // Approve user1 to transfer (as owner of the token)
    start_cheat_caller_address(dispatcher.contract_address, user1);
    erc721_dispatcher.approve(user1, token_id);

    // Try to transfer NFT from user1 to user2 - should be blocked
    erc721_dispatcher.transfer_from(user1, user2, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_nft_minting_allowed() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    // Minting should be allowed (from = 0, to = user)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    let has_nft = dispatcher.user_has_nft(user);
    assert(has_nft, 'Minting should be allowed');
}

#[test]
fn test_nft_burning_allowed() {
    let (dispatcher, owner) = deploy_nft_contract();
    let user: ContractAddress = 'user'.try_into().unwrap();

    // Mint NFT first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.mint_to_user(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Burning should be allowed (from = user, to = 0)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.burn_user_nft(user);
    stop_cheat_caller_address(dispatcher.contract_address);

    let has_nft = dispatcher.user_has_nft(user);
    assert(!has_nft, 'Burning should be allowed');
}
