use kliver_on_chain::interfaces::pox_nft::{IPoxNFTDispatcher, IPoxNFTDispatcherTrait, PoxInfo};
use kliver_on_chain::interfaces::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_kliver_nft() -> (IKliverNFTDispatcher, ContractAddress) {
    let owner: ContractAddress = 'owner_kliver'.try_into().unwrap();
    let contract = declare("KliverNFT").unwrap().contract_class();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    // Empty ByteArray
    constructor_calldata.append(0);
    constructor_calldata.append(0);
    constructor_calldata.append(0);

    let (addr, _) = contract.deploy(@constructor_calldata).unwrap();
    (IKliverNFTDispatcher { contract_address: addr }, owner)
}

fn deploy_pox_nft() -> (IPoxNFTDispatcher, ContractAddress, ContractAddress, IKliverNFTDispatcher, ContractAddress) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let (kliver, kliver_owner) = deploy_kliver_nft();
    let contract = declare("PoxNFT").unwrap().contract_class();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    // base_uri ByteArray empty
    constructor_calldata.append(0);
    constructor_calldata.append(0);
    constructor_calldata.append(0);
    constructor_calldata.append(registry.into());
    constructor_calldata.append(kliver.contract_address.into());

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    (IPoxNFTDispatcher { contract_address }, owner, registry, kliver, kliver_owner)
}

#[test]
fn test_constructor_sets_registry() {
    let (dispatcher, _, registry, kliver, _) = deploy_pox_nft();
    let stored = dispatcher.get_registry();
    assert(stored == registry, 'Registry mismatch');
    let kliver_addr = dispatcher.get_kliver_nft();
    assert(kliver_addr == kliver.contract_address, 'Kliver NFT mismatch');
}

#[test]
fn test_set_registry_owner_only() {
    let (dispatcher, owner, _, _, _) = deploy_pox_nft();
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
    let (dispatcher, _, _, _, _) = deploy_pox_nft();
    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();
    let new_registry: ContractAddress = 'new_registry'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, not_owner);
    dispatcher.set_registry(new_registry);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid address',))]
fn test_set_registry_zero_address() {
    let (dispatcher, owner, _, _, _) = deploy_pox_nft();
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.set_registry(zero);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_mint_only_registry_and_stores_info() {
    let (dispatcher, _owner, registry, kliver, kliver_owner) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Ensure author owns a Kliver NFT
    start_cheat_caller_address(kliver.contract_address, kliver_owner);
    kliver.mint_to_user(author);
    stop_cheat_caller_address(kliver.contract_address);

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
    let (dispatcher, _owner, _registry, _kliver, _ko) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();
    let not_registry: ContractAddress = 'not_registry'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, not_registry);
    dispatcher.mint(1, 2, 3, 4, author);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid address',))]
fn test_mint_zero_author_reverts() {
    let (dispatcher, _owner, registry, _kliver, _ko) = deploy_pox_nft();
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(1, 2, 3, 4, zero);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_mint_twice_same_author_ok() {
    let (dispatcher, _owner, registry, kliver, kliver_owner) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Give author a Kliver NFT first
    start_cheat_caller_address(kliver.contract_address, kliver_owner);
    kliver.mint_to_user(author);
    stop_cheat_caller_address(kliver.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(1, 2, 3, 4, author);
    dispatcher.mint(5, 6, 7, 8, author);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Two tokens minted for same author; total supply 2
    assert(dispatcher.total_supply() == 2, 'Should have two POX NFTs');
}

#[test]
#[should_panic(expected: ('POX NFT is non-transferable',))]
fn test_transfer_blocked() {
    let (dispatcher, _owner, registry, kliver, kliver_owner) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();
    let other: ContractAddress = 'other'.try_into().unwrap();

    // Give author a Kliver NFT first
    start_cheat_caller_address(kliver.contract_address, kliver_owner);
    kliver.mint_to_user(author);
    stop_cheat_caller_address(kliver.contract_address);

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
    let (dispatcher, _owner, registry, kliver, kliver_owner) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Give author a Kliver NFT first
    start_cheat_caller_address(kliver.contract_address, kliver_owner);
    kliver.mint_to_user(author);
    stop_cheat_caller_address(kliver.contract_address);

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
fn test_set_kliver_owner_only() {
    let (dispatcher, owner, _, _, _) = deploy_pox_nft();
    let new_kliver: ContractAddress = 'new_kliver'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.set_kliver_nft(new_kliver);
    stop_cheat_caller_address(dispatcher.contract_address);

    let stored = dispatcher.get_kliver_nft();
    assert(stored == new_kliver, 'Kliver NFT not updated');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_kliver_not_owner() {
    let (dispatcher, _, _, _, _) = deploy_pox_nft();
    let new_kliver: ContractAddress = 'new_kliver'.try_into().unwrap();

    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, not_owner);
    dispatcher.set_kliver_nft(new_kliver);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid address',))]
fn test_set_kliver_zero() {
    let (dispatcher, owner, _, _, _) = deploy_pox_nft();
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.set_kliver_nft(zero);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Token not found',))]
fn test_get_pox_info_nonexistent_token() {
    let (dispatcher, _, _, _, _) = deploy_pox_nft();
    dispatcher.get_pox_info(999);
}

#[test]
#[should_panic(expected: ('Author has no Kliver NFT',))]
fn test_mint_requires_kliver_nft() {
    let (dispatcher, _owner, registry, _kliver, _ko) = deploy_pox_nft();
    let author: ContractAddress = 'author'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.mint(11, 22, 33, 44, author);
    stop_cheat_caller_address(dispatcher.contract_address);
}
