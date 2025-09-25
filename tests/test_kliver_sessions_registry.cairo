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
    let interactions_hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);
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
    let interactions_hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);
    
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
    contract.complete_step_success(user_id, challenge_id, session_id, step1);
    
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
    contract.complete_step_success(user1, challenge_id, session_id, step_id);
    contract.complete_step_success(user2, challenge_id, session_id, step_id);
    
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
    contract.complete_step_success('user', 'challenge', 'session', 'step');
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
    contract.register_interaction('user', 'challenge', 'session', 'step', 1, 'hash', 101);
}

#[test]
fn test_register_interaction_max_score_valid() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Score of 100 should be valid (max allowed)
    let result = contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash', 100);
    assert_eq!(result, true);
    
    // Verify the interaction was registered
    let count = contract.get_step_interaction_count(user_id, challenge_id, session_id, step_id);
    assert_eq!(count, 1);
    
    // Verify user stats updated with max score
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_interactions, 1);
    assert_eq!(stats.total_score, 100);
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
    let hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);
    
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
    contract.complete_step_success(user1, challenge_id, session_id, step_id);
    contract.complete_step_success(user2, challenge_id, session_id, step_id);
    
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

// ================================
// CRITICAL VALIDATION TESTS - ZERO IDS
// ================================

#[test]
#[should_panic(expected: 'User ID cannot be zero')]
fn test_register_interaction_zero_user_id() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        0, // zero user_id
        'challenge456',
        'session789',
        'step001',
        1,
        'hash123',
        85
    );
}

#[test]
#[should_panic(expected: 'Challenge ID cannot be zero')]
fn test_register_interaction_zero_challenge_id() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        'user123',
        0, // zero challenge_id
        'session789',
        'step001',
        1,
        'hash123',
        85
    );
}

#[test]
#[should_panic(expected: 'Session ID cannot be zero')]
fn test_register_interaction_zero_session_id() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        'user123',
        'challenge456',
        0, // zero session_id
        'step001',
        1,
        'hash123',
        85
    );
}

#[test]
#[should_panic(expected: 'Step ID cannot be zero')]
fn test_register_interaction_zero_step_id() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        'user123',
        'challenge456',
        'session789',
        0, // zero step_id
        1,
        'hash123',
        85
    );
}

#[test]
#[should_panic(expected: 'Message hash cannot be zero')]
fn test_register_interaction_zero_message_hash() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        'user123',
        'challenge456',
        'session789',
        'step001',
        1,
        0, // zero message_hash
        85
    );
}

// ================================
// POSITION VALIDATION TESTS
// ================================

#[test]
#[should_panic(expected: 'Position must be > 0')]
fn test_register_interaction_zero_position() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        'user123',
        'challenge456',
        'session789',
        'step001',
        0, // zero position
        'hash123',
        85
    );
}

#[test]
#[should_panic(expected: 'Invalid interaction position')]
fn test_register_interaction_wrong_position() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register first interaction correctly
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    
    // Try to register interaction at position 3 (should be 2)
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 85);
}

// ================================
// SCORE VALIDATION TESTS
// ================================

#[test]
fn test_register_interaction_score_boundary_values() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    
    // Test minimum valid score (0)
    let result1 = contract.register_interaction(user_id, challenge_id, session_id, step1, 1, 'hash1', 0);
    assert_eq!(result1, true);
    
    // Test maximum valid score (100)
    let result2 = contract.register_interaction(user_id, challenge_id, session_id, step2, 1, 'hash2', 100);
    assert_eq!(result2, true);
}

#[test]
#[should_panic(expected: 'Score too high')]
fn test_register_interaction_score_over_limit() {
    let (contract, _) = deploy_contract();
    
    contract.register_interaction(
        'user123',
        'challenge456',
        'session789',
        'step001',
        1,
        'hash123',
        10001 // Over the limit
    );
}

// ================================
// STEP COMPLETION VALIDATION TESTS
// ================================

#[test]
#[should_panic(expected: 'Step already completed')]
fn test_complete_already_completed_step() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register interaction and complete step
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.complete_step_success(user_id, challenge_id, session_id, step_id);
    
    // Try to complete again - should fail
    contract.complete_step_success(user_id, challenge_id, session_id, step_id);
}

#[test]
#[should_panic(expected: 'Step already completed')]
fn test_register_interaction_after_step_completed() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register interaction and complete step
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.complete_step_success(user_id, challenge_id, session_id, step_id);
    
    // Try to register another interaction - should fail
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 85);
}

#[test]
#[should_panic(expected: 'No interactions found')]
fn test_complete_step_no_interactions() {
    let (contract, _) = deploy_contract();
    
    // Try to complete step without any interactions
    contract.complete_step_success('user123', 'challenge456', 'session789', 'step001');
}

// ================================
// ZERO ID VALIDATION FOR COMPLETE_STEP
// ================================

#[test]
#[should_panic(expected: 'User ID cannot be zero')]
fn test_complete_step_zero_user_id() {
    let (contract, _) = deploy_contract();
    
    contract.complete_step_success(0, 'challenge456', 'session789', 'step001');
}

#[test]
#[should_panic(expected: 'Challenge ID cannot be zero')]
fn test_complete_step_zero_challenge_id() {
    let (contract, _) = deploy_contract();
    
    contract.complete_step_success('user123', 0, 'session789', 'step001');
}

#[test]
#[should_panic(expected: 'Session ID cannot be zero')]
fn test_complete_step_zero_session_id() {
    let (contract, _) = deploy_contract();
    
    contract.complete_step_success('user123', 'challenge456', 0, 'step001');
}

#[test]
#[should_panic(expected: 'Step ID cannot be zero')]
fn test_complete_step_zero_step_id() {
    let (contract, _) = deploy_contract();
    
    contract.complete_step_success('user123', 'challenge456', 'session789', 0);
}

// ================================
// ZERO ID VALIDATION FOR GET_COMPLETED_STEP
// ================================

#[test]
#[should_panic(expected: 'User ID cannot be zero')]
fn test_get_completed_step_zero_user_id() {
    let (contract, _) = deploy_contract();
    
    contract.get_completed_step(0, 'challenge456', 'session789', 'step001');
}

#[test]
#[should_panic(expected: 'Challenge ID cannot be zero')]
fn test_get_completed_step_zero_challenge_id() {
    let (contract, _) = deploy_contract();
    
    contract.get_completed_step('user123', 0, 'session789', 'step001');
}

#[test]
#[should_panic(expected: 'Session ID cannot be zero')]
fn test_get_completed_step_zero_session_id() {
    let (contract, _) = deploy_contract();
    
    contract.get_completed_step('user123', 'challenge456', 0, 'step001');
}

#[test]
#[should_panic(expected: 'Step ID cannot be zero')]
fn test_get_completed_step_zero_step_id() {
    let (contract, _) = deploy_contract();
    
    contract.get_completed_step('user123', 'challenge456', 'session789', 0);
}

// ================================
// EMPTY STATE AND EDGE CASES
// ================================

#[test]
fn test_get_user_stats_non_existent_user() {
    let (contract, _) = deploy_contract();
    
    // Get stats for user that never interacted
    let stats = contract.get_user_stats('non_existent_user');
    
    assert_eq!(stats.total_interactions, 0);
    assert_eq!(stats.total_completed_steps, 0);
    assert_eq!(stats.total_score, 0);
    assert_eq!(stats.last_activity, 0);
}

#[test]
fn test_get_step_interactions_empty_step() {
    let (contract, _) = deploy_contract();
    
    // Get interactions for step with no interactions
    let interactions = contract.get_step_interactions(
        'user123', 'challenge456', 'session789', 'step001'
    );
    
    assert_eq!(interactions.len(), 0);
}

#[test]
fn test_is_step_completed_non_existent_step() {
    let (contract, _) = deploy_contract();
    
    // Check if non-existent step is completed
    let is_completed = contract.is_step_completed(
        'user123', 'challenge456', 'session789', 'step001'
    );
    
    assert_eq!(is_completed, false);
}

#[test]
fn test_get_step_interaction_count_empty_step() {
    let (contract, _) = deploy_contract();
    
    // Count interactions for empty step
    let count = contract.get_step_interaction_count(
        'user123', 'challenge456', 'session789', 'step001'
    );
    
    assert_eq!(count, 0);
}

// ================================
// ADVANCED PAGINATION TESTS
// ================================

#[test]
fn test_pagination_exact_boundary() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register exactly 15 interactions
    let mut i: u32 = 1;
    while i <= 15 {
        let hash = 'hash' + i.into();
        contract.register_interaction(user_id, challenge_id, session_id, step_id, i, hash, 50 + i);
        i += 1;
    };
    
    // Test pagination at exact boundary
    let interactions = contract.get_step_interactions_paginated(
        user_id, challenge_id, session_id, step_id, 10, 5
    );
    
    assert_eq!(interactions.len(), 5); // Should get exactly 5 results
}

#[test]
fn test_pagination_single_result() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register 3 interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 85);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 90);
    
    // Get single result
    let interactions = contract.get_step_interactions_paginated(
        user_id, challenge_id, session_id, step_id, 1, 1
    );
    
    assert_eq!(interactions.len(), 1);
    assert_eq!(*interactions.at(0).scoring, 85); // Second interaction (index 1)
}

#[test]
fn test_pagination_all_results() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register 5 interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 85);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 3, 'hash3', 90);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 4, 'hash4', 75);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 5, 'hash5', 95);
    
    // Request more than available
    let interactions = contract.get_step_interactions_paginated(
        user_id, challenge_id, session_id, step_id, 0, 100
    );
    
    assert_eq!(interactions.len(), 5); // Should return all 5
}
// ================================
// HASH CONSISTENCY TESTS
// ================================

#[test]
fn test_completed_step_hash_consistency() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id1: felt252 = 'session789';
    let session_id2: felt252 = 'session790';
    let step_id: felt252 = 'step001';
    
    // Register same interactions in two different sessions
    contract.register_interaction(user_id, challenge_id, session_id1, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id1, step_id, 2, 'hash2', 90);
    
    contract.register_interaction(user_id, challenge_id, session_id2, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id2, step_id, 2, 'hash2', 90);
    
    // Complete both steps
    let hash1 = contract.complete_step_success(user_id, challenge_id, session_id1, step_id);
    let hash2 = contract.complete_step_success(user_id, challenge_id, session_id2, step_id);
    
    // Same interactions should produce same hash
    assert_eq!(hash1, hash2);
}

#[test]
fn test_completed_step_hash_different_order() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id1: felt252 = 'session789';
    let session_id2: felt252 = 'session790';
    let step_id: felt252 = 'step001';
    
    // Register interactions in different order but same content
    contract.register_interaction(user_id, challenge_id, session_id1, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id1, step_id, 2, 'hash2', 90);
    
    contract.register_interaction(user_id, challenge_id, session_id2, step_id, 1, 'hash2', 90);
    contract.register_interaction(user_id, challenge_id, session_id2, step_id, 2, 'hash1', 80);
    
    // Complete both steps
    let hash1 = contract.complete_step_success(user_id, challenge_id, session_id1, step_id);
    let hash2 = contract.complete_step_success(user_id, challenge_id, session_id2, step_id);
    
    // Different content should produce different hashes
    assert!(hash1 != hash2);
}

// ================================
// CONTRACT STATS EDGE CASES
// ================================

#[test]
fn test_contract_stats_with_zero_activity() {
    let (contract, _) = deploy_contract();
    
    // Check stats on fresh contract
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 0);
    assert_eq!(total_steps, 0);
}

#[test]
fn test_contract_stats_after_multiple_completions() {
    let (contract, _) = deploy_contract();
    
    let user1: felt252 = 'user1';
    let user2: felt252 = 'user2';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    
    // User 1 completes 2 steps with different interaction counts
    contract.register_interaction(user1, challenge_id, session_id, step1, 1, 'hash1', 80);
    contract.register_interaction(user1, challenge_id, session_id, step1, 2, 'hash2', 90);
    contract.register_interaction(user1, challenge_id, session_id, step1, 3, 'hash3', 85);
    contract.complete_step_success(user1, challenge_id, session_id, step1);
    
    contract.register_interaction(user1, challenge_id, session_id, step2, 1, 'hash4', 95);
    contract.complete_step_success(user1, challenge_id, session_id, step2);
    
    // User 2 completes 1 step
    contract.register_interaction(user2, challenge_id, session_id, step1, 1, 'hash5', 70);
    contract.register_interaction(user2, challenge_id, session_id, step1, 2, 'hash6', 75);
    contract.complete_step_success(user2, challenge_id, session_id, step1);
    
    // Check global stats
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 6); // 3 + 1 + 2
    assert_eq!(total_steps, 3); // 2 + 1
}

// ================================
// COMPLEX INTEGRATION WORKFLOWS
// ================================

#[test]
fn test_concurrent_users_same_challenge() {
    let (contract, _) = deploy_contract();
    
    let user1: felt252 = 'user1';
    let user2: felt252 = 'user2';
    let user3: felt252 = 'user3';
    let challenge_id: felt252 = 'same_challenge';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // All users work on same challenge/step concurrently
    contract.register_interaction(user1, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user2, challenge_id, session_id, step_id, 1, 'hash2', 85);
    contract.register_interaction(user3, challenge_id, session_id, step_id, 1, 'hash3', 90);
    
    contract.register_interaction(user1, challenge_id, session_id, step_id, 2, 'hash4', 75);
    contract.register_interaction(user2, challenge_id, session_id, step_id, 2, 'hash5', 95);
    
    // Complete steps
    contract.complete_step_success(user1, challenge_id, session_id, step_id);
    contract.complete_step_success(user2, challenge_id, session_id, step_id);
    contract.complete_step_success(user3, challenge_id, session_id, step_id);
    
    // Verify individual user stats
    let stats1 = contract.get_user_stats(user1);
    let stats2 = contract.get_user_stats(user2);
    let stats3 = contract.get_user_stats(user3);
    
    assert_eq!(stats1.total_interactions, 2);
    assert_eq!(stats1.total_completed_steps, 1);
    assert_eq!(stats1.total_score, 155); // 80 + 75
    
    assert_eq!(stats2.total_interactions, 2);
    assert_eq!(stats2.total_completed_steps, 1);
    assert_eq!(stats2.total_score, 180); // 85 + 95
    
    assert_eq!(stats3.total_interactions, 1);
    assert_eq!(stats3.total_completed_steps, 1);
    assert_eq!(stats3.total_score, 90);
    
    // Verify global stats
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 5); // 2 + 2 + 1
    assert_eq!(total_steps, 3);
}

#[test]
fn test_user_multiple_challenges_stats() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge1: felt252 = 'challenge1';
    let challenge2: felt252 = 'challenge2';
    let challenge3: felt252 = 'challenge3';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // User participates in multiple challenges
    
    // Challenge 1 - 3 interactions
    contract.register_interaction(user_id, challenge1, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge1, session_id, step_id, 2, 'hash2', 90);
    contract.register_interaction(user_id, challenge1, session_id, step_id, 3, 'hash3', 85);
    contract.complete_step_success(user_id, challenge1, session_id, step_id);
    
    // Challenge 2 - 2 interactions
    contract.register_interaction(user_id, challenge2, session_id, step_id, 1, 'hash4', 95);
    contract.register_interaction(user_id, challenge2, session_id, step_id, 2, 'hash5', 75);
    contract.complete_step_success(user_id, challenge2, session_id, step_id);
    
    // Challenge 3 - 1 interaction
    contract.register_interaction(user_id, challenge3, session_id, step_id, 1, 'hash6', 100);
    contract.complete_step_success(user_id, challenge3, session_id, step_id);
    
    // Check user's accumulated stats across all challenges
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_interactions, 6); // 3 + 2 + 1
    assert_eq!(stats.total_completed_steps, 3);
    assert_eq!(stats.total_score, 525); // 80+90+85 + 95+75 + 100
    
    // Verify each challenge separately
    let count1 = contract.get_step_interaction_count(user_id, challenge1, session_id, step_id);
    let count2 = contract.get_step_interaction_count(user_id, challenge2, session_id, step_id);
    let count3 = contract.get_step_interaction_count(user_id, challenge3, session_id, step_id);
    
    assert_eq!(count1, 3);
    assert_eq!(count2, 2);
    assert_eq!(count3, 1);
}

// ================================
// MISSING CRITICAL TESTS - PRIORITY HIGH
// ================================

#[test]
#[should_panic(expected: 'Max interactions exceeded')]
fn test_register_interaction_max_interactions_exceeded() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register exactly 15 interactions (the maximum allowed)
    let mut i: u32 = 1;
    while i <= 15 {
        let hash = 'hash' + i.into();
        contract.register_interaction(user_id, challenge_id, session_id, step_id, i, hash, 50 + i);
        i += 1;
    };
    
    // Verify we can register up to 15
    let count = contract.get_step_interaction_count(user_id, challenge_id, session_id, step_id);
    assert_eq!(count, 15);
    
    // Try to register the 16th interaction - should fail
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 16, 'hash16', 95);
}

// ================================
// MISSING ADMIN TESTS - PRIORITY MEDIUM
// ================================

#[test]
#[should_panic(expected: 'Contract paused')]
fn test_admin_cannot_interact_when_paused() {
    let (contract, owner) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Owner pauses the contract
    start_cheat_caller_address(contract.contract_address, owner);
    contract.pause();
    stop_cheat_caller_address(contract.contract_address);
    
    // Verify contract is paused
    assert_eq!(contract.is_paused(), true);
    
    // Even the owner cannot register interactions when paused
    start_cheat_caller_address(contract.contract_address, owner);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    stop_cheat_caller_address(contract.contract_address);
}

// ================================
// MISSING COMPLEX WORKFLOW - PRIORITY LOW
// ================================

#[test]
fn test_complex_session_workflow() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session1: felt252 = 'session1';
    let session2: felt252 = 'session2';
    let session3: felt252 = 'session3';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    let step3: felt252 = 'step003';
    
    // Set initial timestamp
    start_cheat_block_timestamp(contract.contract_address, 1000);
    
    // Session 1: User completes multiple steps
    // Step 1 - 2 interactions
    contract.register_interaction(user_id, challenge_id, session1, step1, 1, 's1_step1_1', 80);
    contract.register_interaction(user_id, challenge_id, session1, step1, 2, 's1_step1_2', 85);
    contract.complete_step_success(user_id, challenge_id, session1, step1);
    
    // Step 2 - 3 interactions
    contract.register_interaction(user_id, challenge_id, session1, step2, 1, 's1_step2_1', 90);
    contract.register_interaction(user_id, challenge_id, session1, step2, 2, 's1_step2_2', 75);
    contract.register_interaction(user_id, challenge_id, session1, step2, 3, 's1_step2_3', 95);
    contract.complete_step_success(user_id, challenge_id, session1, step2);
    
    // Advance time for Session 2
    start_cheat_block_timestamp(contract.contract_address, 2000);
    
    // Session 2: User works on different steps
    // Step 1 - 1 interaction (different session, same step name)
    contract.register_interaction(user_id, challenge_id, session2, step1, 1, 's2_step1_1', 88);
    contract.complete_step_success(user_id, challenge_id, session2, step1);
    
    // Step 3 - 4 interactions
    contract.register_interaction(user_id, challenge_id, session2, step3, 1, 's2_step3_1', 70);
    contract.register_interaction(user_id, challenge_id, session2, step3, 2, 's2_step3_2', 85);
    contract.register_interaction(user_id, challenge_id, session2, step3, 3, 's2_step3_3', 92);
    contract.register_interaction(user_id, challenge_id, session2, step3, 4, 's2_step3_4', 78);
    contract.complete_step_success(user_id, challenge_id, session2, step3);
    
    // Advance time for Session 3
    start_cheat_block_timestamp(contract.contract_address, 3000);
    
    // Session 3: User works on one step only
    // Step 2 - 2 interactions (different session, same step name as session1)
    contract.register_interaction(user_id, challenge_id, session3, step2, 1, 's3_step2_1', 82);
    contract.register_interaction(user_id, challenge_id, session3, step2, 2, 's3_step2_2', 89);
    contract.complete_step_success(user_id, challenge_id, session3, step2);
    
    // Verify user's accumulated stats across all sessions
    let user_stats = contract.get_user_stats(user_id);
    assert_eq!(user_stats.total_interactions, 12); // 2+3+1+4+2 = 12
    assert_eq!(user_stats.total_completed_steps, 5); // 5 completed steps across sessions
    assert_eq!(user_stats.total_score, 1009); // Sum of all scores: (80+85+90+75+95) + (88+70+85+92+78) + (82+89)
    
    // Verify individual session/step combinations are isolated
    
    // Session 1 verification
    let s1_step1_count = contract.get_step_interaction_count(user_id, challenge_id, session1, step1);
    let s1_step2_count = contract.get_step_interaction_count(user_id, challenge_id, session1, step2);
    assert_eq!(s1_step1_count, 2);
    assert_eq!(s1_step2_count, 3);
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session1, step1), true);
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session1, step2), true);
    
    // Session 2 verification
    let s2_step1_count = contract.get_step_interaction_count(user_id, challenge_id, session2, step1);
    let s2_step3_count = contract.get_step_interaction_count(user_id, challenge_id, session2, step3);
    assert_eq!(s2_step1_count, 1);
    assert_eq!(s2_step3_count, 4);
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session2, step1), true);
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session2, step3), true);
    
    // Session 3 verification
    let s3_step2_count = contract.get_step_interaction_count(user_id, challenge_id, session3, step2);
    assert_eq!(s3_step2_count, 2);
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session3, step2), true);
    
    // Verify cross-session isolation (same step name, different sessions)
    let s1_step1_interactions = contract.get_step_interactions(user_id, challenge_id, session1, step1);
    let s2_step1_interactions = contract.get_step_interactions(user_id, challenge_id, session2, step1);
    assert_eq!(s1_step1_interactions.len(), 2);
    assert_eq!(s2_step1_interactions.len(), 1);
    
    // Verify completed step data for different sessions
    let s1_step1_completed = contract.get_completed_step(user_id, challenge_id, session1, step1);
    let s2_step1_completed = contract.get_completed_step(user_id, challenge_id, session2, step1);
    
    assert_eq!(s1_step1_completed.total_interactions, 2);
    assert_eq!(s1_step1_completed.max_score, 85); // max(80, 85)
    
    assert_eq!(s2_step1_completed.total_interactions, 1);
    assert_eq!(s2_step1_completed.max_score, 88);
    
    // Verify different hashes for different sessions (even same step name)
    assert!(s1_step1_completed.interactions_hash != s2_step1_completed.interactions_hash);
    
    // Verify global contract stats
    let (total_interactions, total_steps) = contract.get_total_stats();
    assert_eq!(total_interactions, 12);
    assert_eq!(total_steps, 5);
    
    stop_cheat_block_timestamp(contract.contract_address);
}

// ================================
// STEP COMPLETION STATUS TESTS
// ================================

#[test]
fn test_complete_step_failed() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register some interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 80);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 90);
    
    // Complete step as failed
    let hash = contract.complete_step_failed(user_id, challenge_id, session_id, step_id);
    assert!(hash != 0);
    
    // Verify step is completed
    let is_completed = contract.is_step_completed(user_id, challenge_id, session_id, step_id);
    assert_eq!(is_completed, true);
    
    // Verify session has failed step
    let has_failed = contract.session_has_failed_step(user_id, challenge_id, session_id);
    assert_eq!(has_failed, true);
    
    // Get completed step and verify status
    let completed_step = contract.get_completed_step(user_id, challenge_id, session_id, step_id);
    assert_eq!(completed_step.max_score, 90);
    assert_eq!(completed_step.total_interactions, 2);
    // Note: We can't directly test the enum status in the test due to Cairo limitations
}

#[test]
fn test_complete_step_success_function() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register some interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 75);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 85);
    
    // Complete step using the new success function
    let hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);
    assert!(hash != 0);
    
    // Verify step is completed
    let is_completed = contract.is_step_completed(user_id, challenge_id, session_id, step_id);
    assert_eq!(is_completed, true);
    
    // Verify session does not have failed step
    let has_failed = contract.session_has_failed_step(user_id, challenge_id, session_id);
    assert_eq!(has_failed, false);
    
    // Get completed step and verify
    let completed_step = contract.get_completed_step(user_id, challenge_id, session_id, step_id);
    assert_eq!(completed_step.max_score, 85);
    assert_eq!(completed_step.total_interactions, 2);
}

#[test]
#[should_panic(expected: 'Session has failed step')]
fn test_cannot_complete_step_success_after_failed() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    
    // Complete first step as failed
    contract.register_interaction(user_id, challenge_id, session_id, step1, 1, 'hash1', 40);
    contract.complete_step_failed(user_id, challenge_id, session_id, step1);
    
    // Try to complete second step successfully using the new function - should fail
    contract.register_interaction(user_id, challenge_id, session_id, step2, 1, 'hash2', 95);
    contract.complete_step_success(user_id, challenge_id, session_id, step2); // This should panic
}

#[test]
fn test_complete_step_success() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step_id: felt252 = 'step001';
    
    // Register some interactions
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, 'hash1', 85);
    contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, 'hash2', 95);
    
    // Complete step successfully
    let hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);
    assert!(hash != 0);
    
    // Verify step is completed
    let is_completed = contract.is_step_completed(user_id, challenge_id, session_id, step_id);
    assert_eq!(is_completed, true);
    
    // Verify session does not have failed step
    let has_failed = contract.session_has_failed_step(user_id, challenge_id, session_id);
    assert_eq!(has_failed, false);
    
    // Get completed step and verify
    let completed_step = contract.get_completed_step(user_id, challenge_id, session_id, step_id);
    assert_eq!(completed_step.max_score, 95);
    assert_eq!(completed_step.total_interactions, 2);
}

#[test]
#[should_panic(expected: 'Session has failed step')]
fn test_cannot_complete_success_after_failed() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    
    // Complete first step as failed
    contract.register_interaction(user_id, challenge_id, session_id, step1, 1, 'hash1', 50);
    contract.complete_step_failed(user_id, challenge_id, session_id, step1);
    
    // Try to complete second step successfully - should fail
    contract.register_interaction(user_id, challenge_id, session_id, step2, 1, 'hash2', 90);
    contract.complete_step_success(user_id, challenge_id, session_id, step2); // This should panic
}

#[test]
fn test_can_complete_multiple_failed_steps() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    
    // Complete first step as failed
    contract.register_interaction(user_id, challenge_id, session_id, step1, 1, 'hash1', 50);
    contract.complete_step_failed(user_id, challenge_id, session_id, step1);
    
    // Complete second step as failed - should work
    contract.register_interaction(user_id, challenge_id, session_id, step2, 1, 'hash2', 60);
    let hash2 = contract.complete_step_failed(user_id, challenge_id, session_id, step2);
    assert!(hash2 != 0);
    
    // Verify both steps are completed
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session_id, step1), true);
    assert_eq!(contract.is_step_completed(user_id, challenge_id, session_id, step2), true);
    
    // Verify session has failed step
    assert_eq!(contract.session_has_failed_step(user_id, challenge_id, session_id), true);
}

#[test]
fn test_different_sessions_independent() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session1: felt252 = 'session789';
    let session2: felt252 = 'session999';
    let step_id: felt252 = 'step001';
    
    // Complete step in session1 as failed
    contract.register_interaction(user_id, challenge_id, session1, step_id, 1, 'hash1', 50);
    contract.complete_step_failed(user_id, challenge_id, session1, step_id);
    
    // Complete step in session2 successfully - should work
    contract.register_interaction(user_id, challenge_id, session2, step_id, 1, 'hash2', 90);
    let hash2 = contract.complete_step_success(user_id, challenge_id, session2, step_id);
    assert!(hash2 != 0);
    
    // Verify session1 has failed step but session2 doesn't
    assert_eq!(contract.session_has_failed_step(user_id, challenge_id, session1), true);
    assert_eq!(contract.session_has_failed_step(user_id, challenge_id, session2), false);
}

#[test]
fn test_session_has_failed_step_empty_session() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session_id: felt252 = 'session789';
    
    // Check empty session - should return false
    let has_failed = contract.session_has_failed_step(user_id, challenge_id, session_id);
    assert_eq!(has_failed, false);
}

#[test]
fn test_workflow_with_mixed_completions() {
    let (contract, _) = deploy_contract();
    
    let user_id: felt252 = 'user123';
    let challenge_id: felt252 = 'challenge456';
    let session1: felt252 = 'session_success';
    let session2: felt252 = 'session_mixed';
    let step1: felt252 = 'step001';
    let step2: felt252 = 'step002';
    let step3: felt252 = 'step003';
    
    // Session 1: Complete steps successfully
    contract.register_interaction(user_id, challenge_id, session1, step1, 1, 'hash1', 80);
    contract.complete_step_success(user_id, challenge_id, session1, step1);
    
    contract.register_interaction(user_id, challenge_id, session1, step2, 1, 'hash2', 90);
    contract.complete_step_success(user_id, challenge_id, session1, step2);
    
    // Session 2: Complete first step successfully, then fail second step
    contract.register_interaction(user_id, challenge_id, session2, step1, 1, 'hash3', 85);
    contract.complete_step_success(user_id, challenge_id, session2, step1);
    
    contract.register_interaction(user_id, challenge_id, session2, step2, 1, 'hash4', 70);
    contract.complete_step_failed(user_id, challenge_id, session2, step2);
    
    // Verify session states
    assert_eq!(contract.session_has_failed_step(user_id, challenge_id, session1), false);
    assert_eq!(contract.session_has_failed_step(user_id, challenge_id, session2), true);
    
    // Try to complete another step in session2 successfully - should fail
    contract.register_interaction(user_id, challenge_id, session2, step3, 1, 'hash5', 95);
    
    // This should panic with 'Session has failed step'
    // We can't test this directly in this test since it would cause a panic
    // But we verified it works in test_cannot_complete_success_after_failed
    
    // Verify user stats accumulated correctly
    let stats = contract.get_user_stats(user_id);
    assert_eq!(stats.total_interactions, 5); // 1+1+1+1+1
    assert_eq!(stats.total_completed_steps, 4); // 2 successful + 1 successful + 1 failed
    assert_eq!(stats.total_score, 420); // 80+90+85+70+95 = 420
}