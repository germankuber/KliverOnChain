use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use core::array::ArrayTrait;

// Import contract interfaces
use kliver_on_chain::{
    ICharacterRegistryDispatcher, ICharacterRegistryDispatcherTrait,
    IScenarioRegistryDispatcher, IScenarioRegistryDispatcherTrait,
    ISimulationRegistryDispatcher, ISimulationRegistryDispatcherTrait,
    IOwnerRegistryDispatcher, IOwnerRegistryDispatcherTrait,
};

/// Helper function to deploy the contract and return all dispatchers
fn deploy_contract() -> (ICharacterRegistryDispatcher, IScenarioRegistryDispatcher, ISimulationRegistryDispatcher, IOwnerRegistryDispatcher, ContractAddress) {
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
        owner
    )
}

/// Helper for character registry tests
fn deploy_for_characters() -> (ICharacterRegistryDispatcher, ContractAddress, ContractAddress) {
    let (char_dispatcher, _, _, _, owner) = deploy_contract();
    (char_dispatcher, char_dispatcher.contract_address, owner)
}

/// Helper for scenario registry tests  
fn deploy_for_scenarios() -> (IScenarioRegistryDispatcher, ContractAddress, ContractAddress) {
    let (_, scenario_dispatcher, _, _, owner) = deploy_contract();
    (scenario_dispatcher, scenario_dispatcher.contract_address, owner)
}

/// Helper for simulation registry tests
fn deploy_for_simulations() -> (ISimulationRegistryDispatcher, ContractAddress, ContractAddress) {
    let (_, _, sim_dispatcher, _, owner) = deploy_contract();
    (sim_dispatcher, sim_dispatcher.contract_address, owner)
}

#[test]
fn test_constructor() {
    let (_, _, _, owner_dispatcher, expected_owner) = deploy_contract();
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
        let (_, _, _, owner_dispatcher, expected_owner) = deploy_contract();
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
        let is_valid = dispatcher.verify_character_version(character_version_id, character_version_hash);
        assert!(is_valid);
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
        let is_valid = dispatcher.verify_character_version(character_version_id, wrong_hash);
        assert!(!is_valid);
    }

    #[test]
    fn test_verify_character_version_non_existent() {
        let (dispatcher, _, _) = deploy_for_characters();

        let non_existent_id: felt252 = 999;
        let some_hash: felt252 = 456;

        // Try to verify a character version that doesn't exist
        let is_valid = dispatcher.verify_character_version(non_existent_id, some_hash);
        assert!(!is_valid);
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
    let is_valid = dispatcher.verify_scenario(scenario_id, scenario_hash);
    assert!(is_valid);
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
    let is_valid = dispatcher.verify_simulation(simulation_id, simulation_hash);
    assert!(is_valid);
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