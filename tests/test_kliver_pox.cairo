use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

use kliver_on_chain::interfaces::kliver_pox::{IKliverPoxDispatcher, IKliverPoxDispatcherTrait};
use kliver_on_chain::components::session_registry_component::SessionMetadata;
use kliver_on_chain::types::{VerificationResult, SessionVerificationRequest};

fn REGISTRY() -> ContractAddress { 'registry'.try_into().unwrap() }
fn AUTHOR() -> ContractAddress { 'author'.try_into().unwrap() }

fn deploy_kliver_pox(registry: ContractAddress) -> IKliverPoxDispatcher {
    let contract = declare("KliverPox").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IKliverPoxDispatcher { contract_address: addr }
}

#[test]
fn test_mint_by_registry_success() {
    let dispatcher = deploy_kliver_pox(REGISTRY());

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


    // Metadata by token
    let meta_t = dispatcher.get_metadata_by_token(1);
    assert!(meta_t.token_id == 1, "token id");
    assert!(meta_t.session_id == 'session_1', "session id");
    assert!(meta_t.root_hash == 'hash_1', "root hash");
    assert!(meta_t.simulation_id == 'sim_1', "sim id");
    assert!(meta_t.author == AUTHOR(), "author");
    assert!(meta_t.score == 111_u32, "score");

    // Metadata by session
    let meta_s = dispatcher.get_metadata_by_session('session_1');
    assert!(meta_s.token_id == 1, "token id");
    assert!(meta_s.session_id == 'session_1', "session id");
    assert!(meta_s.root_hash == 'hash_1', "root hash");
    assert!(meta_s.simulation_id == 'sim_1', "sim id");
    assert!(meta_s.author == AUTHOR(), "author");
    assert!(meta_s.score == 111_u32, "score");
}

#[test]
#[should_panic(expected: ('Only registry can call',))]
fn test_mint_by_non_registry_panics() {
    let dispatcher = deploy_kliver_pox(REGISTRY());

    // Call mint from a different caller
    start_cheat_caller_address(dispatcher.contract_address, 'not_registry'.try_into().unwrap());
    let meta = SessionMetadata { session_id: 's', root_hash: 'h', simulation_id: 'sim_x', author: AUTHOR(), score: 1_u32 };
    dispatcher.mint(meta);
}

#[test]
#[should_panic(expected: ('Simulation already minted',))]
fn test_double_mint_same_session_panics() {
    let dispatcher = deploy_kliver_pox(REGISTRY());
    start_cheat_caller_address(dispatcher.contract_address, REGISTRY());
    let meta1 = SessionMetadata { session_id: 'dup_s', root_hash: 'hash_dup', simulation_id: 'sim_dup', author: AUTHOR(), score: 7_u32 };
    dispatcher.mint(meta1);
    // second mint for same session id should panic (unicidad por session)
    let meta2 = SessionMetadata { session_id: 'dup_s', root_hash: 'hash_dup', simulation_id: 'sim_dup2', author: AUTHOR(), score: 8_u32 };
    dispatcher.mint(meta2);
}

#[test]
#[should_panic(expected: ('Token not found',))]
fn test_owner_of_token_not_found_panics() {
    let dispatcher = deploy_kliver_pox(REGISTRY());
    // Query non-existent token id
    let _ = dispatcher.owner_of_token(999);
}

#[test]
fn test_verify_sessions_by_session_id_all_valid() {
    let dispatcher = deploy_kliver_pox(REGISTRY());
    
    // Mint 3 sessions
    start_cheat_caller_address(dispatcher.contract_address, REGISTRY());
    let meta1 = SessionMetadata {
        session_id: 'session_1',
        root_hash: 'hash_1',
        simulation_id: 'sim_1',
        author: AUTHOR(),
        score: 100_u32,
    };
    let meta2 = SessionMetadata {
        session_id: 'session_2',
        root_hash: 'hash_2',
        simulation_id: 'sim_2',
        author: AUTHOR(),
        score: 200_u32,
    };
    let meta3 = SessionMetadata {
        session_id: 'session_3',
        root_hash: 'hash_3',
        simulation_id: 'sim_3',
        author: AUTHOR(),
        score: 300_u32,
    };
    dispatcher.mint(meta1);
    dispatcher.mint(meta2);
    dispatcher.mint(meta3);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append(SessionVerificationRequest { session_id: 'session_1', root_hash: 'hash_1' });
    batch_array.append(SessionVerificationRequest { session_id: 'session_2', root_hash: 'hash_2' });
    batch_array.append(SessionVerificationRequest { session_id: 'session_3', root_hash: 'hash_3' });

    // Batch verify
    let results = dispatcher.verify_sessions_by_session_id(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let result_1 = *results.at(0);
    let result_2 = *results.at(1);
    let result_3 = *results.at(2);

    assert_eq!(result_1.session_id, 'session_1');
    assert!(result_1.result == VerificationResult::Match);
    assert_eq!(result_2.session_id, 'session_2');
    assert!(result_2.result == VerificationResult::Match);
    assert_eq!(result_3.session_id, 'session_3');
    assert!(result_3.result == VerificationResult::Match);
}

#[test]
fn test_verify_sessions_by_session_id_mixed_results() {
    let dispatcher = deploy_kliver_pox(REGISTRY());
    
    // Mint only 2 sessions
    start_cheat_caller_address(dispatcher.contract_address, REGISTRY());
    let meta1 = SessionMetadata {
        session_id: 'session_valid',
        root_hash: 'hash_correct',
        simulation_id: 'sim_1',
        author: AUTHOR(),
        score: 100_u32,
    };
    let meta2 = SessionMetadata {
        session_id: 'session_wrong',
        root_hash: 'hash_original',
        simulation_id: 'sim_2',
        author: AUTHOR(),
        score: 200_u32,
    };
    dispatcher.mint(meta1);
    dispatcher.mint(meta2);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Prepare batch verification array with mixed results
    let mut batch_array = ArrayTrait::new();
    batch_array.append(SessionVerificationRequest { session_id: 'session_valid', root_hash: 'hash_correct' }); // Match
    batch_array.append(SessionVerificationRequest { session_id: 'session_wrong', root_hash: 'hash_incorrect' }); // Mismatch
    batch_array.append(SessionVerificationRequest { session_id: 'session_not_found', root_hash: 'hash_any' }); // NotFound

    // Batch verify
    let results = dispatcher.verify_sessions_by_session_id(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let result_1 = *results.at(0);
    let result_2 = *results.at(1);
    let result_3 = *results.at(2);

    assert_eq!(result_1.session_id, 'session_valid');
    assert!(result_1.result == VerificationResult::Match);
    assert_eq!(result_2.session_id, 'session_wrong');
    assert!(result_2.result == VerificationResult::Mismatch);
    assert_eq!(result_3.session_id, 'session_not_found');
    assert!(result_3.result == VerificationResult::NotFound);
}

#[test]
fn test_verify_sessions_by_session_id_empty_array() {
    let dispatcher = deploy_kliver_pox(REGISTRY());
    
    // Prepare empty batch verification array
    let batch_array = ArrayTrait::new();

    // Batch verify
    let results = dispatcher.verify_sessions_by_session_id(batch_array);

    // Check results - should be empty
    assert_eq!(results.len(), 0);
}

// removed: owner_of_simulation tests
