use kliver_on_chain::pox_nft::{IPoxNFTDispatcher, IPoxNFTDispatcherTrait, PoxInfo};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_pox_nft() -> (IPoxNFTDispatcher, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let contract = declare("PoxNFT").unwrap().contract_class();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    // base_uri ByteArray empty
    constructor_calldata.append(0);
    constructor_calldata.append(0);
    constructor_calldata.append(0);
    constructor_calldata.append(registry.into());

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    (IPoxNFTDispatcher { contract_address }, owner, registry)
}

#[test]
fn test_constructor_sets_registry() {
    let (dispatcher, _, registry) = deploy_pox_nft();
    let stored = dispatcher.get_registry();
    assert(stored == registry, 'Registry mismatch');
}

#[test]
fn test_set_registry_owner_only() {
    let (dispatcher, owner, _) = deploy_pox_nft();
    let new_registry: ContractAddress = 'new_registry'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.set_registry(new_registry);
    stop_cheat_caller_address(dispatcher.contract_address);

    let stored = dispatcher.get_registry();
    assert(stored == new_registry, 'Registry not updated');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_registry_not_owner() {
    let (dispatcher, _, _) = deploy_pox_nft();
    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();
    let new_registry: ContractAddress = 'new_registry'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, not_owner);
    dispatcher.set_registry(new_registry);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid address',))]
fn test_set_registry_zero_address() {
    let (dispatcher, owner, _) = deploy_pox_nft();
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.set_registry(zero);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_mint_only_registry_and_stores_info() {
    let (dispatcher, owner, registry) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Mint as registry
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(11, 22, 33, 44, author);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check basic ownership
    assert(dispatcher.user_has_nft(author), 'Author should have NFT');
    let token_id = dispatcher.get_user_token_id(author);
    assert(token_id == 1, 'Token id should be 1');
    assert(dispatcher.total_supply() == 1, 'Total supply should be 1');

    // Check info
    let info = dispatcher.get_pox_info(token_id);
    assert(info.session_id == 11, 'session_id wrong');
    assert(info.root_hash == 22, 'root_hash wrong');
    assert(info.simulation_id == 33, 'simulation_id wrong');
    assert(info.score == 44, 'score wrong');
}

#[test]
#[should_panic(expected: ('Only registry can call',))]
fn test_mint_not_registry_reverts() {
    let (dispatcher, owner, _registry) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();
    let not_registry: ContractAddress = 'not_registry'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, not_registry);
    dispatcher.mint(1, 2, 3, 4, author);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid address',))]
fn test_mint_zero_author_reverts() {
    let (dispatcher, _owner, registry) = deploy_pox_nft();
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(1, 2, 3, 4, zero);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('User already has POX NFT',))]
fn test_mint_twice_same_author_reverts() {
    let (dispatcher, _owner, registry) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(1, 2, 3, 4, author);
    dispatcher.mint(5, 6, 7, 8, author);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('POX NFT is non-transferable',))]
fn test_transfer_blocked() {
    let (dispatcher, _owner, registry) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();
    let other: ContractAddress = 'other'.try_into().unwrap();

    // Mint as registry
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(1, 2, 3, 4, author);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Attempt transfer via ERC721 interface should fail
    let erc721 = IERC721Dispatcher { contract_address: dispatcher.contract_address };
    let token_id = dispatcher.get_user_token_id(author);
    start_cheat_caller_address(dispatcher.contract_address, author);
    erc721.transfer_from(author, other, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic]
fn test_burn_blocked() {
    let (dispatcher, _owner, registry) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Mint as registry
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(1, 2, 3, 4, author);
    stop_cheat_caller_address(dispatcher.contract_address);

    let erc721 = IERC721Dispatcher { contract_address: dispatcher.contract_address };
    let token_id = dispatcher.get_user_token_id(author);
    let zero: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, author);
    // Attempt burn via transfer-to-zero should revert
    erc721.transfer_from(author, zero, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Token not found',))]
fn test_get_pox_info_nonexistent_token() {
    let (dispatcher, _, _) = deploy_pox_nft();
    dispatcher.get_pox_info(999);
}
