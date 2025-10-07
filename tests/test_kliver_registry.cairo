use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use core::array::ArrayTrait;

// Import contract interfaces from modular structure
use kliver_on_chain::character_registry::{ICharacterRegistryDispatcher, ICharacterRegistryDispatcherTrait, CharacterMetadata};
use kliver_on_chain::scenario_registry::{IScenarioRegistryDispatcher, IScenarioRegistryDispatcherTrait};
use kliver_on_chain::simulation_registry::{ISimulationRegistryDispatcher, ISimulationRegistryDispatcherTrait, SimulationMetadata};
use kliver_on_chain::owner_registry::{IOwnerRegistryDispatcher, IOwnerRegistryDispatcherTrait};
use kliver_on_chain::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait, SessionMetadata, SessionInfo};
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

fn deploy_for_simulations() -> (ISimulationRegistryDispatcher, ICharacterRegistryDispatcher, IScenarioRegistryDispatcher, ContractAddress, ContractAddress) {
    let (char_dispatcher, scenario_dispatcher, sim_dispatcher, _, _, owner) = deploy_contract();
    (sim_dispatcher, char_dispatcher, scenario_dispatcher, sim_dispatcher.contract_address, owner)
}

fn deploy_for_sessions() -> (ISessionRegistryDispatcher, ISimulationRegistryDispatcher, ICharacterRegistryDispatcher, IScenarioRegistryDispatcher, ContractAddress, ContractAddress) {
    let (char_dispatcher, scenario_dispatcher, sim_dispatcher, _, session_dispatcher, owner) = deploy_contract();
    (session_dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, session_dispatcher.contract_address, owner)
}

/// Helper function to register a test character and return its ID
fn register_test_character(char_dispatcher: ICharacterRegistryDispatcher, contract_address: ContractAddress, owner: ContractAddress) -> felt252 {
    let character_id: felt252 = 'test_char_123';
    let character_hash: felt252 = 'char_hash_456';
    
    let metadata = CharacterMetadata {
        character_version_id: character_id,
        character_version_hash: character_hash,
        author: owner,
    };
    
    start_cheat_caller_address(contract_address, owner);
    char_dispatcher.register_character_version(metadata);
    stop_cheat_caller_address(contract_address);
    
    character_id
}

/// Helper function to register a test scenario and return its ID
fn register_test_scenario(scenario_dispatcher: IScenarioRegistryDispatcher, contract_address: ContractAddress, owner: ContractAddress) -> felt252 {
    let scenario_id: felt252 = 'test_scen_123';
    let scenario_hash: felt252 = 'scen_hash_456';
    
    start_cheat_caller_address(contract_address, owner);
    scenario_dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);
    
    scenario_id
}

/// Helper function to register a test simulation with metadata and return its ID
fn register_test_simulation(
    sim_dispatcher: ISimulationRegistryDispatcher, 
    char_dispatcher: ICharacterRegistryDispatcher,
    scenario_dispatcher: IScenarioRegistryDispatcher,
    contract_address: ContractAddress, 
    owner: ContractAddress
) -> felt252 {
    // First register character and scenario
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'test_sim_123';
    let simulation_hash: felt252 = 'sim_hash_456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    sim_dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
    
    simulation_id
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

        let metadata = CharacterMetadata {
            character_version_id,
            character_version_hash,
            author: owner,
        };

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(metadata);
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

        let metadata = CharacterMetadata {
            character_version_id,
            character_version_hash,
            author: owner,
        };

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(metadata);
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

        let metadata = CharacterMetadata {
            character_version_id,
            character_version_hash,
            author: owner,
        };

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(metadata);
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
    fn test_get_character_version_info_success() {
        let (dispatcher, contract_address, owner) = deploy_for_characters();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;

        let metadata = CharacterMetadata {
            character_version_id,
            character_version_hash,
            author: owner,
        };

        // First register the character version
        start_cheat_caller_address(contract_address, owner);
        dispatcher.register_character_version(metadata);
        stop_cheat_caller_address(contract_address);

        // Then get the complete info
        let retrieved_metadata = dispatcher.get_character_version_info(character_version_id);
        assert_eq!(retrieved_metadata.character_version_id, character_version_id);
        assert_eq!(retrieved_metadata.character_version_hash, character_version_hash);
        assert_eq!(retrieved_metadata.author, owner);
    }

    #[test]
    #[should_panic(expected: ('Character version not found', ))]
    fn test_get_character_version_info_not_found() {
        let (dispatcher, _, _) = deploy_for_characters();

        let non_existent_id: felt252 = 999;

        // Try to get info for non-existent character version
        dispatcher.get_character_version_info(non_existent_id);
    }

#[test]
fn test_register_character_version_success() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 'character123';
    let character_version_hash: felt252 = 'hash456';
    
    let metadata = CharacterMetadata {
        character_version_id,
        character_version_hash,
        author: owner,
    };
    
    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    contract.register_character_version(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Version ID already registered', ))]
fn test_register_character_version_duplicate() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 'character123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    
    let metadata1 = CharacterMetadata {
        character_version_id,
        character_version_hash: hash1,
        author: owner,
    };
    
    let metadata2 = CharacterMetadata {
        character_version_id,
        character_version_hash: hash2,
        author: owner,
    };
    
    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    contract.register_character_version(metadata1);
    
    // Second registration with same version ID should fail
    contract.register_character_version(metadata2);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Version ID cannot be zero', ))]
fn test_register_character_version_zero_id() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 0;
    let character_version_hash: felt252 = 'hash456';
    
    let metadata = CharacterMetadata {
        character_version_id,
        character_version_hash,
        author: owner,
    };
    
    start_cheat_caller_address(contract_address, owner);
    contract.register_character_version(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Version hash cannot be zero', ))]
fn test_register_character_version_zero_hash() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_version_id: felt252 = 'character123';
    let character_version_hash: felt252 = 0;
    
    let metadata = CharacterMetadata {
        character_version_id,
        character_version_hash,
        author: owner,
    };
    
    start_cheat_caller_address(contract_address, owner);
    contract.register_character_version(metadata);
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

#[test]
fn test_verify_scenario_invalid_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    let scenario_id: felt252 = 123;
    let scenario_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);

    // Then verify with wrong hash
    let result = dispatcher.verify_scenario(scenario_id, wrong_hash);
    assert!(result == VerificationResult::Mismatch);
}

#[test]
fn test_verify_scenario_non_existent() {
    let (dispatcher, _, _) = deploy_for_scenarios();

    let non_existent_id: felt252 = 999;
    let some_hash: felt252 = 456;

    // Try to verify non-existent scenario
    let result = dispatcher.verify_scenario(non_existent_id, some_hash);
    assert!(result == VerificationResult::NotFound);
}

#[test]
#[should_panic(expected: ('Scenario ID cannot be zero', ))]
fn test_register_scenario_zero_id() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 0;
    let scenario_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Scenario hash cannot be zero', ))]
fn test_register_scenario_zero_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 'scenario123';
    let scenario_hash: felt252 = 0;
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(scenario_id, scenario_hash);
    stop_cheat_caller_address(contract_address);
}

// ===== SIMULATION TESTS =====

#[test]
fn test_register_simulation_success() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Character not found', ))]
fn test_register_simulation_invalid_character() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Only register scenario, not character
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id: 'invalid_char',  // This character doesn't exist
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    // Should panic - character not found
    dispatcher.register_simulation(metadata);
}

#[test]
#[should_panic(expected: ('Scenario not found', ))]
fn test_register_simulation_invalid_scenario() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Only register character, not scenario
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id: 'invalid_scenario',  // This scenario doesn't exist
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    // Should panic - scenario not found
    dispatcher.register_simulation(metadata);
}

#[test]
fn test_get_simulation_info_success() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
    
    // Get simulation info
    let info = dispatcher.get_simulation_info(simulation_id);
    assert(info.simulation_id == simulation_id, 'Wrong simulation ID');
    assert(info.simulation_hash == simulation_hash, 'Wrong simulation hash');
    assert(info.author == owner, 'Wrong author');
    assert(info.character_id == character_id, 'Wrong character_id');
    assert(info.scenario_id == scenario_id, 'Wrong scenario_id');
}

#[test]
fn test_verify_simulation_valid() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };

    // First register the simulation
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);

    // Then verify it
    let result = dispatcher.verify_simulation(simulation_id, simulation_hash);
    assert!(result == VerificationResult::Match);
}

#[test]
fn test_get_simulation_hash_success() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };

    // First register the simulation
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);

    // Then get the hash
    let retrieved_hash = dispatcher.get_simulation_hash(simulation_id);
    assert_eq!(retrieved_hash, simulation_hash);
}

#[test]
fn test_verify_simulation_invalid_hash() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };

    // First register the simulation
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);

    // Then verify with wrong hash
    let result = dispatcher.verify_simulation(simulation_id, wrong_hash);
    assert!(result == VerificationResult::Mismatch);
}

#[test]
fn test_verify_simulation_non_existent() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    let non_existent_id: felt252 = 999;
    let some_hash: felt252 = 456;

    // Try to verify non-existent simulation
    let result = dispatcher.verify_simulation(non_existent_id, some_hash);
    assert!(result == VerificationResult::NotFound);
}

#[test]
#[should_panic(expected: ('Simulation not found', ))]
fn test_get_simulation_hash_not_found() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    let non_existent_id: felt252 = 999;

    // Try to get hash for non-existent simulation
    dispatcher.get_simulation_hash(non_existent_id);
}

#[test]
#[should_panic(expected: ('Simulation not found', ))]
fn test_get_simulation_info_not_found() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    let non_existent_id: felt252 = 999;

    // Try to get info for non-existent simulation
    dispatcher.get_simulation_info(non_existent_id);
}

#[test]
#[should_panic(expected: ('Simulation ID cannot be zero', ))]
fn test_register_simulation_zero_id() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 0;
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Simulation hash cannot be zero', ))]
fn test_register_simulation_zero_hash() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 0;
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Author cannot be zero', ))]
fn test_register_simulation_zero_author() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();
    
    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let zero_author: ContractAddress = 0.try_into().unwrap();
    let metadata = SimulationMetadata {
        simulation_id,
        author: zero_author,
        character_id,
        scenario_id,
        simulation_hash,
    };
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
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

    let metadata1 = CharacterMetadata {
        character_version_id: char_id_1,
        character_version_hash: char_hash_1,
        author: owner,
    };
    let metadata2 = CharacterMetadata {
        character_version_id: char_id_2,
        character_version_hash: char_hash_2,
        author: owner,
    };
    let metadata3 = CharacterMetadata {
        character_version_id: char_id_3,
        character_version_hash: char_hash_3,
        author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character_version(metadata1);
    dispatcher.register_character_version(metadata2);
    dispatcher.register_character_version(metadata3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1);
    batch_array.append(metadata2);
    batch_array.append(metadata3);

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

    let metadata1_register = CharacterMetadata {
        character_version_id: char_id_1,
        character_version_hash: char_hash_1,
        author: owner,
    };
    let metadata2_register = CharacterMetadata {
        character_version_id: char_id_2,
        character_version_hash: 201,
        author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character_version(metadata1_register);
    dispatcher.register_character_version(metadata2_register); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let metadata1_verify = CharacterMetadata {
        character_version_id: char_id_1,
        character_version_hash: char_hash_1,
        author: owner,
    };
    let metadata2_verify = CharacterMetadata {
        character_version_id: char_id_2,
        character_version_hash: wrong_hash_2,
        author: owner,
    };
    let metadata3_verify = CharacterMetadata {
        character_version_id: char_id_3,
        character_version_hash: 202,
        author: owner,
    };

    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1_verify);    // Should be valid
    batch_array.append(metadata2_verify);   // Should be invalid (wrong hash)
    batch_array.append(metadata3_verify);            // Should be invalid (not registered)

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
    let (dispatcher, _, owner) = deploy_for_characters();

    // Prepare batch verification array with zero values
    let metadata1 = CharacterMetadata {
        character_version_id: 0,
        character_version_hash: 200,
        author: owner,
    };
    let metadata2 = CharacterMetadata {
        character_version_id: 100,
        character_version_hash: 0,
        author: owner,
    };
    let metadata3 = CharacterMetadata {
        character_version_id: 0,
        character_version_hash: 0,
        author: owner,
    };

    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1);        // Zero ID
    batch_array.append(metadata2);        // Zero hash
    batch_array.append(metadata3);          // Both zero

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
        let metadata = CharacterMetadata {
            character_version_id: i.into(),
            character_version_hash: (i + 100).into(),
            author: owner,
        };
        dispatcher.register_character_version(metadata);
        i += 1;
    };
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array with 10 items
    let mut batch_array = ArrayTrait::new();
    let mut j = 1;
    while j != 11 {
        let metadata = CharacterMetadata {
            character_version_id: j.into(),
            character_version_hash: (j + 100).into(),
            author: owner,
        };
        batch_array.append(metadata);
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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    // Register multiple simulations
    let sim_id_1: felt252 = 100;
    let sim_hash_1: felt252 = 200;
    let sim_id_2: felt252 = 101;
    let sim_hash_2: felt252 = 201;
    let sim_id_3: felt252 = 102;
    let sim_hash_3: felt252 = 202;
    
    let metadata_1 = SimulationMetadata {
        simulation_id: sim_id_1,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: sim_hash_1,
    };
    let metadata_2 = SimulationMetadata {
        simulation_id: sim_id_2,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: sim_hash_2,
    };
    let metadata_3 = SimulationMetadata {
        simulation_id: sim_id_3,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: sim_hash_3,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata_1);
    dispatcher.register_simulation(metadata_2);
    dispatcher.register_simulation(metadata_3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata_1);
    batch_array.append(metadata_2);
    batch_array.append(metadata_3);

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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);
    
    // Register only some simulations
    let sim_id_1: felt252 = 100;
    let sim_hash_1: felt252 = 200;
    let sim_id_2: felt252 = 101;
    let sim_hash_2: felt252 = 201;
    let wrong_hash_2: felt252 = 999; // Wrong hash
    let sim_id_3: felt252 = 102; // Not registered
    
    let metadata_1 = SimulationMetadata {
        simulation_id: sim_id_1,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: sim_hash_1,
    };
    let metadata_2 = SimulationMetadata {
        simulation_id: sim_id_2,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: sim_hash_2,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata_1);
    dispatcher.register_simulation(metadata_2); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array with metadata for verification
    let metadata_1_check = metadata_1; // Should be valid
    let metadata_2_wrong = SimulationMetadata {
        simulation_id: sim_id_2,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: wrong_hash_2, // Wrong hash
    };
    let metadata_3_not_registered = SimulationMetadata {
        simulation_id: sim_id_3,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: 202, // Not registered
    };
    
    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata_1_check);      // Should be valid
    batch_array.append(metadata_2_wrong);    // Should be invalid (wrong hash)
    batch_array.append(metadata_3_not_registered);             // Should be invalid (not registered)

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
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

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
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();
    
    // First register a simulation
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);
    
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 'author'.try_into().unwrap();
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Session already registered', ))]
fn test_register_session_duplicate() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();
    
    // First register a simulation
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);
    
    let session_id: felt252 = 'session123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    let author: ContractAddress = 'author'.try_into().unwrap();
    let metadata1 = SessionMetadata { simulation_id, author, score: 100_u32 };
    let metadata2 = SessionMetadata { simulation_id, author, score: 200_u32 };

    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    dispatcher.register_session(session_id, hash1, metadata1);

    // Second registration with same session ID should fail
    dispatcher.register_session(session_id, hash2, metadata2);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Session ID cannot be zero', ))]
fn test_register_session_zero_id() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();
    
    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);
    
    let session_id: felt252 = 0;
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 'author'.try_into().unwrap();
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Root hash cannot be zero', ))]
fn test_register_session_zero_hash() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();
    
    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);
    
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 0;
    let author: ContractAddress = 'author'.try_into().unwrap();
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Author cannot be zero', ))]
fn test_register_session_zero_author() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();
    
    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);
    
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 0.try_into().unwrap();
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_verify_session_valid() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // First register the session
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);

    // Then verify it
    let result = dispatcher.verify_session(session_id, root_hash);
    assert!(result == VerificationResult::Match);
}

#[test]
fn test_verify_session_invalid_hash() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // First register the session
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);

    // Then verify with wrong hash
    let result = dispatcher.verify_session(session_id, wrong_hash);
    assert!(result == VerificationResult::Mismatch);
}

#[test]
fn test_verify_session_non_existent() {
    let (dispatcher, _, _, _, _, _) = deploy_for_sessions();

    let non_existent_id: felt252 = 999;
    let some_hash: felt252 = 456;

    // Try to verify non-existent session
    let result = dispatcher.verify_session(non_existent_id, some_hash);
    assert!(result == VerificationResult::NotFound);
}

#[test]
fn test_get_session_info_success() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // First register the session
    start_cheat_caller_address(contract_address, owner);
    let metadata = SessionMetadata { simulation_id, author, score: 150_u32 };
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);

    // Then get the session info
    let session_info = dispatcher.get_session_info(session_id);
    assert_eq!(session_info.root_hash, root_hash);
    assert_eq!(session_info.simulation_id, simulation_id);
    assert_eq!(session_info.author, author);
    assert_eq!(session_info.score, 150_u32);
}

#[test]
#[should_panic(expected: ('Session not found', ))]
fn test_get_session_info_not_found() {
    let (dispatcher, _, _, _, _, _) = deploy_for_sessions();

    let non_existent_id: felt252 = 999;

    // Try to get info for non-existent session
    dispatcher.get_session_info(non_existent_id);
}

#[test]
fn test_grant_access_success() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();
    let grantee: ContractAddress = 'grantee'.try_into().unwrap();

    // First register the session
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);

    // Grant access
    dispatcher.grant_access(session_id, grantee);
    stop_cheat_caller_address(contract_address);

    // Verify access was granted
    assert!(dispatcher.has_access(session_id, grantee));
}

#[test]
fn test_has_access_returns_false_for_no_access() {
    let (dispatcher, sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) = deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner);

    let session_id: felt252 = 123;
    let root_hash: felt252 = 456;
    let author: ContractAddress = 'author'.try_into().unwrap();
    let random_addr: ContractAddress = 'random'.try_into().unwrap();

    // Register the session but don't grant access
    let metadata = SessionMetadata { simulation_id, author, score: 100_u32 };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);

    // Check access (should be false)
    assert!(!dispatcher.has_access(session_id, random_addr));
}

#[test]
#[should_panic(expected: ('Session not found', ))]
fn test_grant_access_nonexistent_session() {
    let (dispatcher, _, _, _, contract_address, owner) = deploy_for_sessions();

    let non_existent_session: felt252 = 999;
    let grantee: ContractAddress = 'grantee'.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    // Try to grant access to non-existent session
    dispatcher.grant_access(non_existent_session, grantee);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Simulation not found', ))]
fn test_register_session_invalid_simulation() {
    let (dispatcher, _, _, _, contract_address, owner) = deploy_for_sessions();
    
    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let invalid_simulation_id: felt252 = 'nonexistent_sim';
    let author: ContractAddress = 'author'.try_into().unwrap();
    let metadata = SessionMetadata { simulation_id: invalid_simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    // Should panic - simulation doesn't exist
    dispatcher.register_session(session_id, root_hash, metadata);
    stop_cheat_caller_address(contract_address);
}