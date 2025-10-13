use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

use kliver_on_chain::interfaces::klive_pox::{IKlivePoxDispatcher, IKlivePoxDispatcherTrait};
use kliver_on_chain::components::session_registry_component::SessionMetadata;

fn REGISTRY() -> ContractAddress { 'registry'.try_into().unwrap() }
fn AUTHOR() -> ContractAddress { 'author'.try_into().unwrap() }

fn deploy_klive_pox(registry: ContractAddress) -> IKlivePoxDispatcher {
    let contract = declare("KlivePox").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IKlivePoxDispatcher { contract_address: addr }
}

#[test]
fn test_mint_by_registry_success() {
    let dispatcher = deploy_klive_pox(REGISTRY());

    // Only registry can mint
    start_cheat_caller_address(dispatcher.contract_address, REGISTRY());
    let meta = SessionMetadata {
        session_id: 'session_1',
        root_hash: 'hash_1',
        simulation_id: 'sim_1',
        author: AUTHOR(),
        score: 111_u32,
    };
    dispatcher.mint(meta);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Author balance should be 1
    let bal = dispatcher.balance_of(AUTHOR());
    assert!(bal == 1, "Author should have 1 token");

    // First token id is 1
    let owner_t1 = dispatcher.owner_of_token(1);
    assert!(owner_t1 == AUTHOR(), "Owner of token 1 must be author");

    // Owner by simulation id
    let owner_sim = dispatcher.owner_of_simulation('sim_1');
    assert!(owner_sim == AUTHOR(), "Owner by simulation must be author");

    // Metadata by token
    let meta_t = dispatcher.get_metadata_by_token(1);
    assert!(meta_t.token_id == 1, 'token id');
    assert!(meta_t.session_id == 'session_1', 'session id');
    assert!(meta_t.root_hash == 'hash_1', 'root hash');
    assert!(meta_t.simulation_id == 'sim_1', 'sim id');
    assert!(meta_t.author == AUTHOR(), 'author');
    assert!(meta_t.score == 111_u32, 'score');

    // Metadata by session
    let meta_s = dispatcher.get_metadata_by_session('session_1');
    assert!(meta_s.token_id == 1, 'token id');
    assert!(meta_s.session_id == 'session_1', 'session id');
    assert!(meta_s.root_hash == 'hash_1', 'root hash');
    assert!(meta_s.simulation_id == 'sim_1', 'sim id');
    assert!(meta_s.author == AUTHOR(), 'author');
    assert!(meta_s.score == 111_u32, 'score');
}

#[test]
#[should_panic(expected: ('Only registry can call',))]
fn test_mint_by_non_registry_panics() {
    let dispatcher = deploy_klive_pox(REGISTRY());

    // Call mint from a different caller
    start_cheat_caller_address(dispatcher.contract_address, 'not_registry'.try_into().unwrap());
    let meta = SessionMetadata { session_id: 's', root_hash: 'h', simulation_id: 'sim_x', author: AUTHOR(), score: 1_u32 };
    dispatcher.mint(meta);
}

#[test]
#[should_panic(expected: ('Simulation already minted',))]
fn test_double_mint_same_simulation_panics() {
    let dispatcher = deploy_klive_pox(REGISTRY());
    start_cheat_caller_address(dispatcher.contract_address, REGISTRY());
    let meta1 = SessionMetadata { session_id: 'dup_s', root_hash: 'hash_dup', simulation_id: 'sim_dup', author: AUTHOR(), score: 7_u32 };
    dispatcher.mint(meta1);
    // second mint for same simulation id should panic
    let meta2 = SessionMetadata { session_id: 'dup_s2', root_hash: 'hash_dup', simulation_id: 'sim_dup', author: AUTHOR(), score: 8_u32 };
    dispatcher.mint(meta2);
}

#[test]
#[should_panic(expected: ('Token not found',))]
fn test_owner_of_token_not_found_panics() {
    let dispatcher = deploy_klive_pox(REGISTRY());
    // Query non-existent token id
    let _ = dispatcher.owner_of_token(999);
}

#[test]
fn test_owner_of_simulation_not_minted_returns_zero() {
    let dispatcher = deploy_klive_pox(REGISTRY());
    let zero: ContractAddress = 0.try_into().unwrap();
    let owner = dispatcher.owner_of_simulation('no_sim');
    assert!(owner == zero, "Unminted simulation should return zero address");
}
