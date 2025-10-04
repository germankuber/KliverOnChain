use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use core::array::ArrayTrait;

// Import contract interfaces from modular structure
use kliver_on_chain::character_registry::{ICharacterRegistryDispatcher, ICharacterRegistryDispatcherTrait};
use kliver_on_chain::scenario_registry::{IScenarioRegistryDispatcher, IScenarioRegistryDispatcherTrait};
use kliver_on_chain::simulation_registry::{ISimulationRegistryDispatcher, ISimulationRegistryDispatcherTrait};
use kliver_on_chain::owner_registry::{IOwnerRegistryDispatcher, IOwnerRegistryDispatcherTrait};
use kliver_on_chain::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait};
use kliver_on_chain::types::VerificationResult;

/// Helper function to deploy the contract and return all dispatchers
fn deploy_contract() -> (ICharacterRegistryDispatcher, IScenarioRegistryDispatcher, ISimulationRegistryDispatcher, IOwnerRegistryDispatcher, ISessionRegistryDispatcher, ContractAddress) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    (
        ICharacterRegistryDispatcher { contract_address },
        IScenarioRegistryDispatcher { contract_address },
        ISimulationRegistryDispatcher { contract_address },
        IOwnerRegistryDispatcher { contract_address },
        ISessionRegistryDispatcher { contract_address },
        owner
    )
}

/// Helper for character registry tests
fn deploy_for_characters() -> (ICharacterRegistryDispatcher, ContractAddress, ContractAddress) {
    let (char_dispatcher, _, _, _, _, owner) = deploy_contract();
    (char_dispatcher, char_dispatcher.contract_address, owner)
}

/// Helper for scenario registry tests
fn deploy_for_scenarios() -> (IScenarioRegistryDispatcher, ContractAddress, ContractAddress) {
    let (_, scenario_dispatcher, _, _, _, owner) = deploy_contract();
    (scenario_dispatcher, scenario_dispatcher.contract_address, owner)
}

fn deploy_for_simulations() -> (ISimulationRegistryDispatcher, ContractAddress, ContractAddress) {
    let (_, _, sim_dispatcher, _, _, owner) = deploy_contract();
    (sim_dispatcher, sim_dispatcher.contract_address, owner)
}

fn deploy_for_sessions() -> (ISessionRegistryDispatcher, ContractAddress, ContractAddress) {
    let (_, _, _, _, session_dispatcher, owner) = deploy_contract();
    (session_dispatcher, session_dispatcher.contract_address, owner)
}

#[test]
fn test_constructor() {
    let (_, _, _, owner_dispatcher, _, expected_owner) = deploy_contract();
    let actual_owner = owner_dispatcher.get_owner();
    assert(actual_owner == expected_owner, 'Wrong owner');
}

#[test]
#[should_panic]
fn test_constructor_zero_owner() {
    let zero_owner: ContractAddress = 0.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(zero_owner.into());
    let (_contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
}

    #[test]
    fn test_get_owner_returns_correct_owner() {
        let (_, _, _, owner_dispatcher, _, expected_owner) = deploy_contract();
        let owner = owner_dispatcher.get_owner();
        assert_eq!(owner, expected_owner);
    }

    #[test]
    fn test_verify_character_version_valid() {
        let (dispatcher, contract_address, owner) = deploy_for_characters();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(character_version_id, character_version_hash);
        stop_cheat_caller_address(contract_address);

        // Then verify it
        let result = dispatcher.verify_character_version(character_version_id, character_version_hash);
        assert!(result == VerificationResult::Match);
    }

    #[test]
    fn test_verify_character_version_invalid_hash() {
        let (dispatcher, contract_address, owner) = deploy_for_characters();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;
        let wrong_hash: felt252 = 789;

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(character_version_id, character_version_hash);
        stop_cheat_caller_address(contract_address);

        // Then verify with wrong hash
        let result = dispatcher.verify_character_version(character_version_id, wrong_hash);
        assert!(result == VerificationResult::Mismatch);
    }

    #[test]
    fn test_verify_character_version_non_existent() {
        let (dispatcher, _, _) = deploy_for_characters();

        let non_existent_id: felt252 = 999;
        let some_hash: felt252 = 456;

                // Try to verify non-existent character version
        let result = dispatcher.verify_character_version(non_existent_id, some_hash);
        assert!(result == VerificationResult::NotFound);
    }

    #[test]
    #[should_panic(expected: ('Version ID cannot be zero', ))]
    fn test_verify_character_version_zero_id_should_fail() {
        let (dispatcher, _, _) = deploy_for_characters();

        let character_version_hash: felt252 = 456;

        // Try to verify with zero ID (should panic)
        dispatcher.verify_character_version(0, character_version_hash);
    }

    #[test]
    #[should_panic(expected: ('Version hash cannot be zero', ))]
    fn test_verify_character_version_zero_hash_should_fail() {
        let (dispatcher, _, _) = deploy_for_characters();

        let character_version_id: felt252 = 123;

        // Try to verify with zero hash (should panic)
        dispatcher.verify_character_version(character_version_id, 0);
    }

    #[test]
    fn test_get_character_version_hash_success() {
        let (dispatcher, contract_address, owner) = deploy_for_characters();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(character_version_id, character_version_hash);
        stop_cheat_caller_address(contract_address);

        // Then get the hash
        let retrieved_hash = dispatcher.get_character_version_hash(character_version_id);
        assert_eq!(retrieved_hash, character_version_hash);
    }

    #[test]
    #[should_panic(expected: ('Character version not found', ))]
    fn test_get_character_version_hash_not_found() {
        let (dispatcher, _, _) = deploy_for_characters();

        let non_existent_id: felt252 = 999;

        // Try to get hash for non-existent character version
        dispatcher.get_character_version_hash(non_existent_id);
    }

    #[test]
    #[should_panic(expected: ('Version ID cannot be zero', ))]
    fn test_get_character_version_hash_zero_id() {
        let (dispatcher, _, _) = deploy_for_characters();

        // Try to get hash with zero ID
        dispatcher.get_character_version_hash(0);
    }

#[test]
fn test_register_character_version_success() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 'character123';
    let character_version_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    contract.register_character_version(character_version_id, character_version_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Version ID already registered', ))]
fn test_register_character_version_duplicate() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 'character123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    
    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    contract.register_character_version(character_version_id, hash1);
    
    // Second registration with same version ID should fail
    contract.register_character_version(character_version_id, hash2);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Version ID cannot be zero', ))]
fn test_register_character_version_zero_id() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 0;
    let character_version_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract_address, owner);
    contract.register_character_version(character_version_id, character_version_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Version hash cannot be zero', ))]
fn test_register_character_version_zero_hash() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 'character123';
    let character_version_hash: felt252 = 0;
    
    start_cheat_caller_address(contract_address, owner);
    contract.register_character_version(character_version_id, character_version_hash);
    stop_cheat_caller_address(contract_address);
}

// ===== SCENARIO TESTS =====

#[test]
fn test_register_scenario_success() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 'scenario123';
    let scenario_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Scenario already registered', ))]
fn test_register_scenario_duplicate() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 'scenario123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    
    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    dispatcher.register_scenario(scenario_id, hash1);
    
    // Second registration with same scenario ID should fail
    dispatcher.register_scenario(scenario_id, hash2);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_verify_scenario_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    let scenario_id: felt252 = 123;
    let scenario_hash: felt252 = 456;

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);

    // Then verify it
    let result = dispatcher.verify_scenario(scenario_id, scenario_hash);
    assert!(result == VerificationResult::Match);
}

#[test]
fn test_get_scenario_hash_success() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    let scenario_id: felt252 = 123;
    let scenario_hash: felt252 = 456;

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);

    // Then get the hash
    let retrieved_hash = dispatcher.get_scenario_hash(scenario_id);
    assert_eq!(retrieved_hash, scenario_hash);
}

#[test]
#[should_panic(expected: ('Scenario not found', ))]
fn test_get_scenario_hash_not_found() {
    let (dispatcher, _, _) = deploy_for_scenarios();

    let non_existent_id: felt252 = 999;

    // Try to get hash for non-existent scenario
    dispatcher.get_scenario_hash(non_existent_id);
}

// ===== SIMULATION TESTS =====

#[test]
fn test_register_simulation_success() {
    let (dispatcher, contract_address, owner) = deploy_for_simulations();
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_simulation(simulation_id, simulation_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_verify_simulation_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_simulations();

    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;

    // First register the simulation
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(simulation_id, simulation_hash);
    stop_cheat_caller_address(contract_address);

    // Then verify it
    let result = dispatcher.verify_simulation(simulation_id, simulation_hash);
    assert!(result == VerificationResult::Match);
}

#[test]
fn test_get_simulation_hash_success() {
    let (dispatcher, contract_address, owner) = deploy_for_simulations();

    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;

    // First register the simulation
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(simulation_id, simulation_hash);
    stop_cheat_caller_address(contract_address);

    // Then get the hash
    let retrieved_hash = dispatcher.get_simulation_hash(simulation_id);
    assert_eq!(retrieved_hash, simulation_hash);
}

// ===== BATCH CHARACTER VERSION TESTS =====

#[test]
fn test_batch_verify_character_versions_all_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    // Register multiple character versions
    let char_id_1: felt252 = 100;
    let char_hash_1: felt252 = 200;
    let char_id_2: felt252 = 101;
    let char_hash_2: felt252 = 201;
    let char_id_3: felt252 = 102;
    let char_hash_3: felt252 = 202;

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character_version(char_id_1, char_hash_1);
    dispatcher.register_character_version(char_id_2, char_hash_2);
    dispatcher.register_character_version(char_id_3, char_hash_3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append((char_id_1, char_hash_1));
    batch_array.append((char_id_2, char_hash_2));
    batch_array.append((char_id_3, char_hash_3));

    // Batch verify
    let results = dispatcher.batch_verify_character_versions(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_1) = *results.at(0);
    let (result_id_2, result_2) = *results.at(1);
    let (result_id_3, result_3) = *results.at(2);

    assert_eq!(result_id_1, char_id_1);
    assert!(result_1 == VerificationResult::Match);
    assert_eq!(result_id_2, char_id_2);
    assert!(result_2 == VerificationResult::Match);
    assert_eq!(result_id_3, char_id_3);
    assert!(result_3 == VerificationResult::Match);
}

#[test]
fn test_batch_verify_character_versions_mixed_results() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    // Register only some character versions
    let char_id_1: felt252 = 100;
    let char_hash_1: felt252 = 200;
    let char_id_2: felt252 = 101;
    let wrong_hash_2: felt252 = 999; // Wrong hash
    let char_id_3: felt252 = 102; // Not registered

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character_version(char_id_1, char_hash_1);
    dispatcher.register_character_version(char_id_2, 201); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append((char_id_1, char_hash_1));    // Should be valid
    batch_array.append((char_id_2, wrong_hash_2));   // Should be invalid (wrong hash)
    batch_array.append((char_id_3, 202));            // Should be invalid (not registered)

    // Batch verify
    let results = dispatcher.batch_verify_character_versions(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_1) = *results.at(0);
    let (result_id_2, result_2) = *results.at(1);
    let (result_id_3, result_3) = *results.at(2);

    assert_eq!(result_id_1, char_id_1);
    assert!(result_1 == VerificationResult::Match);      // Should be Match
    assert_eq!(result_id_2, char_id_2);
    assert!(result_2 == VerificationResult::Mismatch);   // Should be Mismatch (wrong hash)
    assert_eq!(result_id_3, char_id_3);
    assert!(result_3 == VerificationResult::NotFound);   // Should be NotFound (not registered)
}

#[test]
fn test_batch_verify_character_versions_with_zero_values() {
    let (dispatcher, _, _) = deploy_for_characters();

    // Prepare batch verification array with zero values
    let mut batch_array = ArrayTrait::new();
    batch_array.append((0, 200));        // Zero ID
    batch_array.append((100, 0));        // Zero hash
    batch_array.append((0, 0));          // Both zero

    // Batch verify
    let results = dispatcher.batch_verify_character_versions(batch_array);

    // Check results - all should be NotFound due to zero values
    assert_eq!(results.len(), 3);
    let (result_id_1, result_1) = *results.at(0);
    let (result_id_2, result_2) = *results.at(1);
    let (result_id_3, result_3) = *results.at(2);

    assert_eq!(result_id_1, 0);
    assert!(result_1 == VerificationResult::NotFound);     // Should be NotFound (zero ID)
    assert_eq!(result_id_2, 100);
    assert!(result_2 == VerificationResult::NotFound);     // Should be NotFound (zero hash)
    assert_eq!(result_id_3, 0);
    assert!(result_3 == VerificationResult::NotFound);     // Should be NotFound (both zero)
}

#[test]
fn test_batch_verify_character_versions_empty_array() {
    let (dispatcher, _, _) = deploy_for_characters();

    // Prepare empty batch verification array
    let batch_array = ArrayTrait::new();

    // Batch verify
    let results = dispatcher.batch_verify_character_versions(batch_array);

    // Check results - should be empty
    assert_eq!(results.len(), 0);
}

#[test]
fn test_batch_verify_character_versions_large_batch() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    // Register multiple character versions
    start_cheat_caller_address(contract_address, owner);
    let mut i = 1;
    while i != 11 {
        dispatcher.register_character_version(i.into(), (i + 100).into());
        i += 1;
    };
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array with 10 items
    let mut batch_array = ArrayTrait::new();
    let mut j = 1;
    while j != 11 {
        batch_array.append((j.into(), (j + 100).into()));
        j += 1;
    };

    // Batch verify
    let results = dispatcher.batch_verify_character_versions(batch_array);

    // Check results - all should be Match
    assert_eq!(results.len(), 10);
    let mut k = 0;
    while k != 10 {
        let (result_id, result) = *results.at(k);
        assert_eq!(result_id, (k + 1).into());
        assert!(result == VerificationResult::Match);
        k += 1;
    };
}

// ===== BATCH SCENARIO TESTS =====

#[test]
fn test_batch_verify_scenarios_all_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    // Register multiple scenarios
    let scenario_id_1: felt252 = 100;
    let scenario_hash_1: felt252 = 200;
    let scenario_id_2: felt252 = 101;
    let scenario_hash_2: felt252 = 201;
    let scenario_id_3: felt252 = 102;
    let scenario_hash_3: felt252 = 202;

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id_1, scenario_hash_1);
    dispatcher.register_scenario(scenario_id_2, scenario_hash_2);
    dispatcher.register_scenario(scenario_id_3, scenario_hash_3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append((scenario_id_1, scenario_hash_1));
    batch_array.append((scenario_id_2, scenario_hash_2));
    batch_array.append((scenario_id_3, scenario_hash_3));

    // Batch verify
    let results = dispatcher.batch_verify_scenarios(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_valid_1) = *results.at(0);
    let (result_id_2, result_valid_2) = *results.at(1);
    let (result_id_3, result_valid_3) = *results.at(2);

    assert_eq!(result_id_1, scenario_id_1);
    assert!(result_valid_1 == VerificationResult::Match);
    assert_eq!(result_id_2, scenario_id_2);
    assert!(result_valid_2 == VerificationResult::Match);
    assert_eq!(result_id_3, scenario_id_3);
    assert!(result_valid_3 == VerificationResult::Match);
}

#[test]
fn test_batch_verify_scenarios_mixed_results() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    // Register only some scenarios
    let scenario_id_1: felt252 = 100;
    let scenario_hash_1: felt252 = 200;
    let scenario_id_2: felt252 = 101;
    let wrong_hash_2: felt252 = 999; // Wrong hash
    let scenario_id_3: felt252 = 102; // Not registered

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id_1, scenario_hash_1);
    dispatcher.register_scenario(scenario_id_2, 201); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append((scenario_id_1, scenario_hash_1));    // Should be valid
    batch_array.append((scenario_id_2, wrong_hash_2));       // Should be invalid (wrong hash)
    batch_array.append((scenario_id_3, 202));                // Should be invalid (not registered)

    // Batch verify
    let results = dispatcher.batch_verify_scenarios(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_valid_1) = *results.at(0);
    let (result_id_2, result_valid_2) = *results.at(1);
    let (result_id_3, result_valid_3) = *results.at(2);

    assert_eq!(result_id_1, scenario_id_1);
    assert!(result_valid_1 == VerificationResult::Match);      // Should be Match
    assert_eq!(result_id_2, scenario_id_2);
    assert!(result_valid_2 == VerificationResult::Mismatch);   // Should be Mismatch (wrong hash)
    assert_eq!(result_id_3, scenario_id_3);
    assert!(result_valid_3 == VerificationResult::NotFound);   // Should be NotFound (not registered)
}

#[test]
fn test_batch_verify_scenarios_empty_array() {
    let (dispatcher, _, _) = deploy_for_scenarios();

    // Prepare empty batch verification array
    let batch_array = ArrayTrait::new();

    // Batch verify
    let results = dispatcher.batch_verify_scenarios(batch_array);

    // Check results - should be empty
    assert_eq!(results.len(), 0);
}

// ===== BATCH SIMULATION TESTS =====

#[test]
fn test_batch_verify_simulations_all_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register multiple simulations
    let sim_id_1: felt252 = 100;
    let sim_hash_1: felt252 = 200;
    let sim_id_2: felt252 = 101;
    let sim_hash_2: felt252 = 201;
    let sim_id_3: felt252 = 102;
    let sim_hash_3: felt252 = 202;

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(sim_id_1, sim_hash_1);
    dispatcher.register_simulation(sim_id_2, sim_hash_2);
    dispatcher.register_simulation(sim_id_3, sim_hash_3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append((sim_id_1, sim_hash_1));
    batch_array.append((sim_id_2, sim_hash_2));
    batch_array.append((sim_id_3, sim_hash_3));

    // Batch verify
    let results = dispatcher.batch_verify_simulations(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_valid_1) = *results.at(0);
    let (result_id_2, result_valid_2) = *results.at(1);
    let (result_id_3, result_valid_3) = *results.at(2);

    assert_eq!(result_id_1, sim_id_1);
    assert!(result_valid_1 == VerificationResult::Match);
    assert_eq!(result_id_2, sim_id_2);
    assert!(result_valid_2 == VerificationResult::Match);
    assert_eq!(result_id_3, sim_id_3);
    assert!(result_valid_3 == VerificationResult::Match);
}

#[test]
fn test_batch_verify_simulations_mixed_results() {
    let (dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register only some simulations
    let sim_id_1: felt252 = 100;
    let sim_hash_1: felt252 = 200;
    let sim_id_2: felt252 = 101;
    let wrong_hash_2: felt252 = 999; // Wrong hash
    let sim_id_3: felt252 = 102; // Not registered

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(sim_id_1, sim_hash_1);
    dispatcher.register_simulation(sim_id_2, 201); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append((sim_id_1, sim_hash_1));      // Should be valid
    batch_array.append((sim_id_2, wrong_hash_2));    // Should be invalid (wrong hash)
    batch_array.append((sim_id_3, 202));             // Should be invalid (not registered)

    // Batch verify
    let results = dispatcher.batch_verify_simulations(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_valid_1) = *results.at(0);
    let (result_id_2, result_valid_2) = *results.at(1);
    let (result_id_3, result_valid_3) = *results.at(2);

    assert_eq!(result_id_1, sim_id_1);
    assert!(result_valid_1 == VerificationResult::Match);      // Should be Match
    assert_eq!(result_id_2, sim_id_2);
    assert!(result_valid_2 == VerificationResult::Mismatch);   // Should be Mismatch (wrong hash)
    assert_eq!(result_id_3, sim_id_3);
    assert!(result_valid_3 == VerificationResult::NotFound);   // Should be NotFound (not registered)
}

#[test]
fn test_batch_verify_simulations_empty_array() {
    let (dispatcher, _, _) = deploy_for_simulations();

    // Prepare empty batch verification array
    let batch_array = ArrayTrait::new();

    // Batch verify
    let results = dispatcher.batch_verify_simulations(batch_array);

    // Check results - should be empty
    assert_eq!(results.len(), 0);
}

// ===== SESSION REGISTRY TESTS =====

#[test]
fn test_register_session_success() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 'author'.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Session already registered', ))]
fn test_register_session_duplicate() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();
    let session_id: felt252 = 'session123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    let author: ContractAddress = 'author'.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    dispatcher.register_session(session_id, hash1, author);

    // Second registration with same session ID should fail
    dispatcher.register_session(session_id, hash2, author);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Session ID cannot be zero', ))]
fn test_register_session_zero_id() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();
    let session_id: felt252 = 0;
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 'author'.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Root hash cannot be zero', ))]
fn test_register_session_zero_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 0;
    let author: ContractAddress = 'author'.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Author cannot be zero', ))]
fn test_register_session_zero_author() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_verify_session_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // First register the session
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);

    // Then verify it
    let result = dispatcher.verify_session(session_id, root_hash);
    assert!(result == VerificationResult::Match);
}

#[test]
fn test_verify_session_invalid_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // First register the session
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);

    // Then verify with wrong hash
    let result = dispatcher.verify_session(session_id, wrong_hash);
    assert!(result == VerificationResult::Mismatch);
}

#[test]
fn test_verify_session_non_existent() {
    let (dispatcher, _, _) = deploy_for_sessions();

    let non_existent_id: felt252 = 999;
    let some_hash: felt252 = 456;

    // Try to verify non-existent session
    let result = dispatcher.verify_session(non_existent_id, some_hash);
    assert!(result == VerificationResult::NotFound);
}

#[test]
fn test_get_session_info_success() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // First register the session
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);

    // Then get the session info
    let (retrieved_hash, retrieved_author) = dispatcher.get_session_info(session_id);
    assert_eq!(retrieved_hash, root_hash);
    assert_eq!(retrieved_author, author);
}

#[test]
#[should_panic(expected: ('Session not found', ))]
fn test_get_session_info_not_found() {
    let (dispatcher, _, _) = deploy_for_sessions();

    let non_existent_id: felt252 = 999;

    // Try to get info for non-existent session
    dispatcher.get_session_info(non_existent_id);
}

#[test]
fn test_grant_access_success() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();
    let grantee: ContractAddress = 'grantee'.try_into().unwrap();

    // First register the session
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);

    // Grant access
    dispatcher.grant_access(session_id, grantee);
    stop_cheat_caller_address(contract_address);

    // Verify access was granted
    assert!(dispatcher.has_access(session_id, grantee));
}

#[test]
fn test_has_access_returns_false_for_no_access() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();
    let random_addr: ContractAddress = 'random'.try_into().unwrap();

    // Register the session but don't grant access
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, author);
    stop_cheat_caller_address(contract_address);

    // Check access (should be false)
    assert!(!dispatcher.has_access(session_id, random_addr));
}

#[test]
#[should_panic(expected: ('Session not found', ))]
fn test_grant_access_nonexistent_session() {
    let (dispatcher, contract_address, owner) = deploy_for_sessions();

    let non_existent_session: felt252 = 999;
    let grantee: ContractAddress = 'grantee'.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    // Try to grant access to non-existent session
    dispatcher.grant_access(non_existent_session, grantee);
    stop_cheat_caller_address(contract_address);
}