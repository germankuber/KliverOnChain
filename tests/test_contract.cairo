use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};
use starknet::ContractAddress;
use core::array::ArrayTrait;

// Import contract interface and structs
use kliver_on_chain::{
    IKliverSessionsRegistryDispatcher, 
    IKliverSessionsRegistryDispatcherTrait
};

/// Helper function to deploy the contract
fn deploy_contract() -> (IKliverSessionsRegistryDispatcher, ContractAddress) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract = declare("KliverSessionsRegistry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    (IKliverSessionsRegistryDispatcher { contract_address }, owner)
}

// ================================
// BASIC INTERACTION REGISTRATION TESTS
// ================================

#[test]
fn test_register_single_interaction() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    let interaction_pos: u32 = 1;
    let message_hash: felt252 = 'hash123';
    let scoring: u32 = 85;
    
    let result = contract.register_interaction(
        user_id, challenge_id, session_id, step_id, 
        interaction_pos, message_hash, scoring
    );
    
    assert_eq!(result, true);
    
    // Verify interaction count
    let count = contract.get_step_interaction_count(user_id, challenge_id, session_id, step_id);
    assert_eq!(count, 1);

    // Verify user stats updated
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_interactions, 1);
    assert_eq!(stats.total_score, 85);
}

#[test]
fn test_register_multiple_interactions_sequential() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register three interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 90);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 75);
    
    // Verify total count
    let count = contract.get_step_interaction_count(user_id, challenge_id, session_id, step_id);
    assert_eq!(count, 3);

    // Verify user stats
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_interactions, 3);
    assert_eq!(stats.total_score, 245); // 80 + 90 + 75
}

#[test]
fn test_register_interactions_different_steps() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_1: felt252 = 'step001';
    let step_2: felt252 = 'step002';
    
    // Register in step 1
    contract.register_interaction(user_id, challenge_id, session_id, step_1, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_1, 2, 'hash2', 85);
    
    // Register in step 2
    contract.register_interaction(user_id, challenge_id, session_id, step_2, 1, 'hash3', 90);
    
    // Verify counts
    let count_step_1 = contract.get_step_interaction_count(user_id, challenge_id, session_id, step_1);
    let count_step_2 = contract.get_step_interaction_count(user_id, challenge_id, session_id, step_2);
    
    assert_eq!(count_step_1, 2);
    assert_eq!(count_step_2, 1);
}

// ================================
// STEP COMPLETION TESTS
// ================================

#[test]
fn test_complete_step_basic() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register some interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 95);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 75);
    
    // Complete step
    let interactions_hash = contract.complete_step(user_id, challenge_id, session_id, step_id);
    assert!(interactions_hash != 0);
    
    // Verify step is marked as completed
    let is_completed = contract.is_step_completed(user_id, challenge_id, session_id, step_id);
    assert_eq!(is_completed, true);

    // Verify user stats updated
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_completed_steps, 1);
}

#[test]
fn test_complete_step_and_get_completed_step() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Set timestamp
    start_cheat_block_timestamp(contract.contract_address, 1500);
    
    // Register interactions with different scores
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 95); // max score
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 75);
    
    // Complete step
    let interactions_hash = contract.complete_step(user_id, challenge_id, session_id, step_id);
    
    // Get completed step info
    let completed_step = contract.get_completed_step(user_id, challenge_id, session_id, step_id);
    
    assert_eq!(completed_step.interactions_hash, interactions_hash);
    assert_eq!(completed_step.max_score, 95); // Should be the highest score
    assert_eq!(completed_step.total_interactions, 3);
    assert!(completed_step.timestamp > 0);
    
    stop_cheat_block_timestamp(contract.contract_address);
}

// ================================
// PAGINATION TESTS
// ================================

#[test]
fn test_get_step_interactions_paginated() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register 5 interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 10);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 20);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 30);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 4, 'hash4', 40);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 5, 'hash5', 50);
    
    // Get first 3 interactions
    let page1 = contract.get_step_interactions_paginated(user_id, challenge_id, session_id, step_id, 0, 3);
    assert_eq!(page1.len(), 3);
    assert_eq!((*page1.at(0)).scoring, 10);
    assert_eq!((*page1.at(1)).scoring, 20);
    assert_eq!((*page1.at(2)).scoring, 30);
    
    // Get next 2 interactions
    let page2 = contract.get_step_interactions_paginated(user_id, challenge_id, session_id, step_id, 3, 3);
    assert_eq!(page2.len(), 2);
    assert_eq!((*page2.at(0)).scoring, 40);
    assert_eq!((*page2.at(1)).scoring, 50);
}

// ================================
// STATISTICS TESTS
// ================================

#[test]
fn test_user_stats_accumulation() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    
    // Set initial timestamp
    start_cheat_block_timestamp(contract.contract_address, 1000);
    
    // Register interactions in step 1
    contract.register_interaction(user_id, challenge_id, session_id, step1, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step1, 2, 'hash2', 90);
    
    // Register interactions in step 2
    contract.register_interaction(user_id, challenge_id, session_id, step2, 1, 'hash3', 70);
    
    // Check stats after interactions only
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_interactions, 3);
    assert_eq!(stats.total_score, 240); // 80 + 90 + 70
    assert_eq!(stats.total_completed_steps, 0);
    
    // Advance time and complete step 1
    start_cheat_block_timestamp(contract.contract_address, 2000);
    contract.complete_step(user_id, challenge_id, session_id, step1);
    
    // Check stats after completion
    let stats_after = contract.get_user_stats(user_id);
    assert_eq!(stats_after.total_interactions, 3);
    assert_eq!(stats_after.total_score, 240);
    assert_eq!(stats_after.total_completed_steps, 1);
    assert!(stats_after.last_activity > stats.last_activity);
    
    stop_cheat_block_timestamp(contract.contract_address);
}

#[test]
fn test_total_contract_stats() {
    let (contract, _) = deploy_contract();
    
    let user1: felt252 = 'user1';
    let user2: felt252 = 'user2';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Initial stats should be zero
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 0);
    assert_eq!(total_steps, 0);
    
    // User 1 interactions
    contract.register_interaction(user1, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user1, challenge_id, session_id, step_id, 2, 'hash2', 90);
    
    // User 2 interactions
    contract.register_interaction(user2, challenge_id, session_id, step_id, 1, 'hash3', 75);
    
    // Check interactions count
    let (total_interactions_after, total_steps_after) = contract.get_total_stats();
    assert_eq!(total_interactions_after, 3);
    assert_eq!(total_steps_after, 0);
    
    // Complete steps
    contract.complete_step(user1, challenge_id, session_id, step_id);
    contract.complete_step(user2, challenge_id, session_id, step_id);
    
    // Check final stats
    let (final_interactions, final_steps) = contract.get_total_stats();
    assert_eq!(final_interactions, 3);
    assert_eq!(final_steps, 2);
}

// ================================
// ADMIN FUNCTIONS TESTS
// ================================

#[test]
fn test_pause_unpause() {
    let (contract, owner) = deploy_contract();
    
    // Initially should not be paused
    assert_eq!(contract.is_paused(), false);
    
    // Pause contract as owner
    start_cheat_caller_address(contract.contract_address, owner);
    contract.pause();
    stop_cheat_caller_address(contract.contract_address);
    
    assert_eq!(contract.is_paused(), true);
    
    // Unpause contract as owner
    start_cheat_caller_address(contract.contract_address, owner);
    contract.unpause();
    stop_cheat_caller_address(contract.contract_address);
    
    assert_eq!(contract.is_paused(), false);
}

#[test]
fn test_ownership_transfer() {
    let (contract, owner) = deploy_contract();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    
    // Check initial owner
    assert_eq!(contract.get_owner(), owner);
    
    // Transfer ownership
    start_cheat_caller_address(contract.contract_address, owner);
    contract.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract.contract_address);
    
    // Check new owner
    assert_eq!(contract.get_owner(), new_owner);
}

// ================================
// SECURITY TESTS (SHOULD PANIC)
// ================================

#[test]
#[should_panic(expected: 'Contract paused')]
fn test_register_interaction_when_paused() {
    let (contract, owner) = deploy_contract();
    
    // Pause contract
    start_cheat_caller_address(contract.contract_address, owner);
    contract.pause();
    stop_cheat_caller_address(contract.contract_address);
    
    // Try to register interaction when paused
    contract.register_interaction('user', 'challenge', 'session', 'step', 1, 'hash', 80);
}

#[test]
#[should_panic(expected: 'Contract paused')]
fn test_complete_step_when_paused() {
    let (contract, owner) = deploy_contract();
    
    // Register interaction first
    contract.register_interaction('user', 'challenge', 'session', 'step', 1, 'hash', 80);
    
    // Pause contract
    start_cheat_caller_address(contract.contract_address, owner);
    contract.pause();
    stop_cheat_caller_address(contract.contract_address);
    
    // Try to complete step when paused
    contract.complete_step('user', 'challenge', 'session', 'step');
}

#[test]
#[should_panic(expected: 'Not owner')]
fn test_pause_not_owner() {
    let (contract, _) = deploy_contract();
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();
    
    start_cheat_caller_address(contract.contract_address, non_owner);
    contract.pause();
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Not owner')]
fn test_transfer_ownership_not_owner() {
    let (contract, _) = deploy_contract();
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    
    start_cheat_caller_address(contract.contract_address, non_owner);
    contract.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract.contract_address);
}

// ================================
// VALIDATION TESTS (SHOULD PANIC)
// ================================

#[test]
#[should_panic(expected: 'Score too high')]
fn test_register_interaction_score_too_high() {
    let (contract, _) = deploy_contract();
    contract.register_interaction('user', 'challenge', 'session', 'step', 1, 'hash', 10001);
}

#[test]
#[should_panic(expected: 'Invalid pagination')]
fn test_pagination_limit_too_high() {
    let (contract, _) = deploy_contract();
    contract.get_step_interactions_paginated('user', 'challenge', 'session', 'step', 0, 101);
}

#[test]
#[should_panic(expected: 'Invalid pagination')]
fn test_pagination_limit_zero() {
    let (contract, _) = deploy_contract();
    contract.get_step_interactions_paginated('user', 'challenge', 'session', 'step', 0, 0);
}

#[test]
#[should_panic(expected: 'Invalid pagination')]
fn test_pagination_start_out_of_bounds() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register only 2 interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 90);
    
    // Try to start pagination beyond available interactions
    contract.get_step_interactions_paginated(user_id, challenge_id, session_id, step_id, 5, 10);
}

#[test]
#[should_panic(expected: 'Zero address')]
fn test_transfer_ownership_zero_address() {
    let (contract, owner) = deploy_contract();
    let zero_address: ContractAddress = 0_felt252.try_into().unwrap();
    
    start_cheat_caller_address(contract.contract_address, owner);
    contract.transfer_ownership(zero_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Contract already paused')]
fn test_pause_already_paused() {
    let (contract, owner) = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, owner);
    contract.pause();
    contract.pause(); // Try to pause again
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Contract not paused')]
fn test_unpause_not_paused() {
    let (contract, owner) = deploy_contract();
    
    start_cheat_caller_address(contract.contract_address, owner);
    contract.unpause(); // Try to unpause when not paused
    stop_cheat_caller_address(contract.contract_address);
}

// ================================
// COMPLEX WORKFLOW TESTS
// ================================

#[test]
fn test_full_workflow_with_stats() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Set initial timestamp
    start_cheat_block_timestamp(contract.contract_address, 1000);
    
    // Register interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 70);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 85);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 92);
    
    // Check stats before completion
    let stats_before = contract.get_user_stats(user_id);
    assert_eq!(stats_before.total_interactions, 3);
    assert_eq!(stats_before.total_score, 247); // 70 + 85 + 92
    assert_eq!(stats_before.total_completed_steps, 0);
    
    // Advance time and complete step
    start_cheat_block_timestamp(contract.contract_address, 2000);
    let hash = contract.complete_step(user_id, challenge_id, session_id, step_id);
    
    // Check stats after completion
    let stats_after = contract.get_user_stats(user_id);
    assert_eq!(stats_after.total_interactions, 3);
    assert_eq!(stats_after.total_score, 247);
    assert_eq!(stats_after.total_completed_steps, 1);
    assert!(stats_after.last_activity > stats_before.last_activity);
    
    // Verify completed step
    let completed = contract.get_completed_step(user_id, challenge_id, session_id, step_id);
    assert_eq!(completed.max_score, 92);
    assert_eq!(completed.total_interactions, 3);
    assert_eq!(completed.interactions_hash, hash);
    
    // Check contract total stats
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 3);
    assert_eq!(total_steps, 1);
    
    stop_cheat_block_timestamp(contract.contract_address);
}

#[test]
fn test_multiple_users_isolated_stats() {
    let (contract, _) = deploy_contract();
    
    let user1: felt252 = 'user1';
    let user2: felt252 = 'user2';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // User 1 interactions
    contract.register_interaction(user1, challenge_id, session_id, step_id, 1, 'h1u1', 80);
    contract.register_interaction(user1, challenge_id, session_id, step_id, 2, 'h2u1', 90);
    
    // User 2 interactions  
    contract.register_interaction(user2, challenge_id, session_id, step_id, 1, 'h1u2', 60);
    contract.register_interaction(user2, challenge_id, session_id, step_id, 2, 'h2u2', 70);
    contract.register_interaction(user2, challenge_id, session_id, step_id, 3, 'h3u2', 85);
    
    // Complete both steps
    contract.complete_step(user1, challenge_id, session_id, step_id);
    contract.complete_step(user2, challenge_id, session_id, step_id);
    
    // Check isolated stats
    let stats1 = contract.get_user_stats(user1);
    let stats2 = contract.get_user_stats(user2);
    
    assert_eq!(stats1.total_interactions, 2);
    assert_eq!(stats1.total_score, 170); // 80 + 90
    assert_eq!(stats1.total_completed_steps, 1);
    
    assert_eq!(stats2.total_interactions, 3);
    assert_eq!(stats2.total_score, 215); // 60 + 70 + 85
    assert_eq!(stats2.total_completed_steps, 1);
    
    // Check global stats
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 5); // 2 + 3
    assert_eq!(total_steps, 2);
}