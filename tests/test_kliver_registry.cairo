use core::array::ArrayTrait;

// Import contract interfaces from modular structure
use kliver_on_chain::interfaces::character_registry::{
    ICharacterRegistryDispatcher, ICharacterRegistryDispatcherTrait,
};
use kliver_on_chain::components::character_registry_component::CharacterMetadata;
use kliver_on_chain::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};
use kliver_on_chain::interfaces::owner_registry::{IOwnerRegistryDispatcher, IOwnerRegistryDispatcherTrait};
use kliver_on_chain::interfaces::scenario_registry::{
    IScenarioRegistryDispatcher, IScenarioRegistryDispatcherTrait, ScenarioMetadata,
};
use kliver_on_chain::interfaces::session_registry::{
    ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait, SessionMetadata,
};
use kliver_on_chain::interfaces::simulation_registry::{
    ISimulationRegistryDispatcher, ISimulationRegistryDispatcherTrait, SimulationMetadata,
    SimulationWithTokenMetadata,
};
use kliver_on_chain::types::VerificationResult;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

/// Helper function to deploy the NFT contract and mint an NFT to the owner
fn deploy_nft_contract(owner: ContractAddress) -> ContractAddress {
    let nft_contract = declare("KliverNFT").unwrap().contract_class();
    let mut nft_constructor_calldata = ArrayTrait::new();
    nft_constructor_calldata.append(owner.into());
    // ByteArray for base_uri - need to serialize it properly
    let base_uri: ByteArray = "https://api.kliver.io/nft/";
    Serde::serialize(@base_uri, ref nft_constructor_calldata);
    let (nft_address, _) = nft_contract.deploy(@nft_constructor_calldata).unwrap();

    // Mint an NFT to the owner so they can register content
    let nft_dispatcher = IKliverNFTDispatcher { contract_address: nft_address };
    start_cheat_caller_address(nft_address, owner);
    nft_dispatcher.mint_to_user(owner);
    stop_cheat_caller_address(nft_address);

    nft_address
}

/// Helper function to deploy the Tokens Core contract
fn deploy_tokens_core_contract(owner: ContractAddress) -> ContractAddress {
    let contract_tokens_core = declare("KliverTokensCore").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let base_uri: ByteArray = "https://api.kliver.io/tokens-core/";
    Serde::serialize(@base_uri, ref constructor_calldata);
    let (address_tokens_core, _) = contract_tokens_core.deploy(@constructor_calldata).unwrap();
    address_tokens_core
}

/// Helper function to deploy the contract and return all dispatchers
fn deploy_contract() -> (
    ICharacterRegistryDispatcher,
    IScenarioRegistryDispatcher,
    ISimulationRegistryDispatcher,
    IOwnerRegistryDispatcher,
    ISessionRegistryDispatcher,
    ContractAddress,
) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let nft_address = deploy_nft_contract(owner);
    let tokens_core_address = deploy_tokens_core_contract(owner);
    let verifier_address: ContractAddress = 'verifier'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    constructor_calldata.append(nft_address.into());
    constructor_calldata.append(tokens_core_address.into());
    constructor_calldata.append(verifier_address.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (
        ICharacterRegistryDispatcher { contract_address },
        IScenarioRegistryDispatcher { contract_address },
        ISimulationRegistryDispatcher { contract_address },
        IOwnerRegistryDispatcher { contract_address },
        ISessionRegistryDispatcher { contract_address },
        owner,
    )
}

/// Helper function to deploy contract with NFT dispatcher access
fn deploy_contract_with_nft() -> (
    ICharacterRegistryDispatcher,
    IScenarioRegistryDispatcher,
    ISimulationRegistryDispatcher,
    IOwnerRegistryDispatcher,
    ISessionRegistryDispatcher,
    IKliverNFTDispatcher,
    ContractAddress,
    ContractAddress,
    ContractAddress // tokens_core_address
) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let nft_address = deploy_nft_contract(owner);
    let tokens_core_address = deploy_tokens_core_contract(owner);
    let verifier_address: ContractAddress = 'verifier'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    constructor_calldata.append(nft_address.into());
    constructor_calldata.append(tokens_core_address.into());
    constructor_calldata.append(verifier_address.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    // Configure the registry address in the tokens_core contract
    start_cheat_caller_address(tokens_core_address, owner);
    let mut calldata = ArrayTrait::new();
    calldata.append(contract_address.into());
    starknet::syscalls::call_contract_syscall(
        tokens_core_address, selector!("set_registry_address"), calldata.span(),
    )
        .unwrap();
    stop_cheat_caller_address(tokens_core_address);

    (
        ICharacterRegistryDispatcher { contract_address },
        IScenarioRegistryDispatcher { contract_address },
        ISimulationRegistryDispatcher { contract_address },
        IOwnerRegistryDispatcher { contract_address },
        ISessionRegistryDispatcher { contract_address },
        IKliverNFTDispatcher { contract_address: nft_address },
        owner,
        nft_address,
        tokens_core_address,
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

fn deploy_for_simulations() -> (
    ISimulationRegistryDispatcher,
    ICharacterRegistryDispatcher,
    IScenarioRegistryDispatcher,
    ContractAddress,
    ContractAddress,
) {
    let (char_dispatcher, scenario_dispatcher, sim_dispatcher, _, _, owner) = deploy_contract();
    (sim_dispatcher, char_dispatcher, scenario_dispatcher, sim_dispatcher.contract_address, owner)
}

fn deploy_for_sessions() -> (
    ISessionRegistryDispatcher,
    ISimulationRegistryDispatcher,
    ICharacterRegistryDispatcher,
    IScenarioRegistryDispatcher,
    IKliverNFTDispatcher,
    ContractAddress,
    ContractAddress,
    ContractAddress,
) {
    let (
        char_dispatcher,
        scenario_dispatcher,
        sim_dispatcher,
        _,
        session_dispatcher,
        nft_dispatcher,
        owner,
        nft_address,
        _tokens_core_address,
    ) =
        deploy_contract_with_nft();
    (
        session_dispatcher,
        sim_dispatcher,
        char_dispatcher,
        scenario_dispatcher,
        nft_dispatcher,
        session_dispatcher.contract_address,
        owner,
        nft_address,
    )
}

/// Helper function to register a test character and return its ID
fn register_test_character(
    char_dispatcher: ICharacterRegistryDispatcher,
    contract_address: ContractAddress,
    owner: ContractAddress,
) -> felt252 {
    let character_id: felt252 = 'test_char_123';
    let character_hash: felt252 = 'char_hash_456';

    let metadata = CharacterMetadata {
        character_id: character_id, character_hash: character_hash, author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    char_dispatcher.register_character(metadata);
    stop_cheat_caller_address(contract_address);

    character_id
}

/// Helper function to register a test scenario and return its ID
fn register_test_scenario(
    scenario_dispatcher: IScenarioRegistryDispatcher,
    contract_address: ContractAddress,
    owner: ContractAddress,
) -> felt252 {
    let scenario_id: felt252 = 'test_scen_123';
    let scenario_hash: felt252 = 'scen_hash_456';

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    scenario_dispatcher.register_scenario(metadata);
    stop_cheat_caller_address(contract_address);

    scenario_id
}

/// Helper function to register a test simulation with metadata and return its ID
fn register_test_simulation(
    sim_dispatcher: ISimulationRegistryDispatcher,
    char_dispatcher: ICharacterRegistryDispatcher,
    scenario_dispatcher: IScenarioRegistryDispatcher,
    contract_address: ContractAddress,
    owner: ContractAddress,
) -> felt252 {
    // First register character and scenario
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'test_sim_123';
    let simulation_hash: felt252 = 'sim_hash_456';
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
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
    let nft_address: ContractAddress = 'nft_contract'.try_into().unwrap();
    let kliver_tokens_core_address: ContractAddress = 'kliver_tokens_core'.try_into().unwrap();
    let verifier_address: ContractAddress = 'verifier'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(zero_owner.into());
    constructor_calldata.append(nft_address.into());
    constructor_calldata.append(kliver_tokens_core_address.into());
    constructor_calldata.append(verifier_address.into());
    let (_contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
}

#[test]
fn test_constructor_zero_nft_address() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let zero_nft: ContractAddress = 0.try_into().unwrap();
    let kliver_tokens_core_address: ContractAddress = 'kliver_tokens_core'.try_into().unwrap();
    let verifier_address: ContractAddress = 'verifier'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    constructor_calldata.append(zero_nft.into());
    constructor_calldata.append(kliver_tokens_core_address.into());
    constructor_calldata.append(verifier_address.into());

    match contract.deploy(@constructor_calldata) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(errors) => {
            assert(*errors.at(0) == 'NFT address cannot be zero', 'Wrong error message');
        },
    }
}

#[test]
fn test_constructor_zero_tokens_core_address() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let nft_address: ContractAddress = 'nft'.try_into().unwrap();
    let zero_tokens_core: ContractAddress = 0.try_into().unwrap();
    let verifier_address: ContractAddress = 'verifier'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    constructor_calldata.append(nft_address.into());
    constructor_calldata.append(zero_tokens_core.into());
    constructor_calldata.append(verifier_address.into());

    match contract.deploy(@constructor_calldata) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(errors) => {
            assert(*errors.at(0) == 'Tokens core addr cannot be zero', 'Wrong error message');
        },
    }
}

#[test]
fn test_get_owner_returns_correct_owner() {
    let (_, _, _, owner_dispatcher, _, expected_owner) = deploy_contract();
    let owner = owner_dispatcher.get_owner();
    assert_eq!(owner, expected_owner);
}

#[test]
fn test_get_nft_address() {
    let (_, _, _, owner_dispatcher, _, owner) = deploy_contract();
    let nft_address = owner_dispatcher.get_nft_address();

    // Verify the address is not zero
    let zero_address: ContractAddress = 0.try_into().unwrap();
    assert(nft_address != zero_address, 'NFT address should not be zero');

    // Verify that the NFT contract at this address responds correctly
    let nft_dispatcher = IKliverNFTDispatcher { contract_address: nft_address };
    let has_nft = nft_dispatcher.user_has_nft(owner);
    assert_eq!(has_nft, true, "Owner should have NFT");
}

#[test]
fn test_get_tokens_core_address() {
    let (_, _, _, owner_dispatcher, _, _) = deploy_contract();
    let tokens_core_address = owner_dispatcher.get_tokens_core_address();

    // Verify the address is not zero
    let zero_address: ContractAddress = 0.try_into().unwrap();
    assert(tokens_core_address != zero_address, 'Tokens core addr != 0');
}

#[test]
fn test_verify_character_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    let character_id: felt252 = 123;
    let character_hash: felt252 = 456;

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    // First register the character
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character(metadata);
    stop_cheat_caller_address(contract_address);

    // Then verify it
    let result = dispatcher.verify_character(character_id, character_hash);
    assert!(result == VerificationResult::Match);
}

#[test]
fn test_verify_character_invalid_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    let character_id: felt252 = 123;
    let character_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    // First register the character
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character(metadata);
    stop_cheat_caller_address(contract_address);

    // Then verify with wrong hash
    let result = dispatcher.verify_character(character_id, wrong_hash);
    assert!(result == VerificationResult::Mismatch);
}

#[test]
fn test_verify_character_non_existent() {
    let (dispatcher, _, _) = deploy_for_characters();

    let non_existent_id: felt252 = 999;
    let some_hash: felt252 = 456;

    // Try to verify non-existent character
    let result = dispatcher.verify_character(non_existent_id, some_hash);
    assert!(result == VerificationResult::NotFound);
}

#[test]
#[should_panic(expected: ('Character ID cannot be zero',))]
fn test_verify_character_zero_id_should_fail() {
    let (dispatcher, _, _) = deploy_for_characters();

    let character_hash: felt252 = 456;

    // Try to verify with zero ID (should panic)
    dispatcher.verify_character(0, character_hash);
}

#[test]
#[should_panic(expected: ('Character hash cannot be zero',))]
fn test_verify_character_zero_hash_should_fail() {
    let (dispatcher, _, _) = deploy_for_characters();

    let character_id: felt252 = 123;

    // Try to verify with zero hash (should panic)
    dispatcher.verify_character(character_id, 0);
}

#[test]
fn test_get_character_hash_success() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    let character_id: felt252 = 123;
    let character_hash: felt252 = 456;

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    // First register the character version
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character(metadata);
    stop_cheat_caller_address(contract_address);

    // Then get the hash
    let retrieved_hash = dispatcher.get_character_hash(character_id);
    assert_eq!(retrieved_hash, character_hash);
}

#[test]
#[should_panic(expected: ('Character not found',))]
fn test_get_character_hash_not_found() {
    let (dispatcher, _, _) = deploy_for_characters();

    let non_existent_id: felt252 = 999;

    // Try to get hash for non-existent character version
    dispatcher.get_character_hash(non_existent_id);
}

#[test]
#[should_panic(expected: ('Character ID cannot be zero',))]
fn test_get_character_hash_zero_id() {
    let (dispatcher, _, _) = deploy_for_characters();

    // Try to get hash with zero ID
    dispatcher.get_character_hash(0);
}

#[test]
fn test_get_character_info_success() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    let character_id: felt252 = 123;
    let character_hash: felt252 = 456;

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    // First register the character version
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character(metadata);
    stop_cheat_caller_address(contract_address);

    // Then get the complete info
    let retrieved_metadata = dispatcher.get_character_info(character_id);
    assert_eq!(retrieved_metadata.character_id, character_id);
    assert_eq!(retrieved_metadata.character_hash, character_hash);
    assert_eq!(retrieved_metadata.author, owner);
}

#[test]
#[should_panic(expected: ('Character not found',))]
fn test_get_character_info_not_found() {
    let (dispatcher, _, _) = deploy_for_characters();

    let non_existent_id: felt252 = 999;

    // Try to get info for non-existent character version
    dispatcher.get_character_info(non_existent_id);
}

#[test]
fn test_register_character_success() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_id: felt252 = 'character123';
    let character_hash: felt252 = 'hash456';

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    contract.register_character(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Character ID already registered',))]
fn test_register_character_duplicate() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_id: felt252 = 'character123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';

    let metadata1 = CharacterMetadata { character_id, character_hash: hash1, author: owner };

    let metadata2 = CharacterMetadata { character_id, character_hash: hash2, author: owner };

    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    contract.register_character(metadata1);

    // Second registration with same version ID should fail
    contract.register_character(metadata2);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Character ID cannot be zero',))]
fn test_register_character_zero_id() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_id: felt252 = 0;
    let character_hash: felt252 = 'hash456';

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    contract.register_character(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Character hash cannot be zero',))]
fn test_register_character_zero_hash() {
    let (contract, contract_address, owner) = deploy_for_characters();
    let character_id: felt252 = 'character123';
    let character_hash: felt252 = 0;

    let metadata = CharacterMetadata { character_id, character_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    contract.register_character(metadata);
    stop_cheat_caller_address(contract_address);
}

// ===== SCENARIO TESTS =====

#[test]
fn test_register_scenario_success() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 'scenario123';
    let scenario_hash: felt252 = 'hash456';

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_scenario(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Scenario already registered',))]
fn test_register_scenario_duplicate() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 'scenario123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';

    let metadata1 = ScenarioMetadata { scenario_id, scenario_hash: hash1, author: owner };

    let metadata2 = ScenarioMetadata { scenario_id, scenario_hash: hash2, author: owner };

    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    dispatcher.register_scenario(metadata1);

    // Second registration with same scenario ID should fail
    dispatcher.register_scenario(metadata2);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_verify_scenario_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    let scenario_id: felt252 = 123;
    let scenario_hash: felt252 = 456;

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata);
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

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata);
    stop_cheat_caller_address(contract_address);

    // Then get the hash
    let retrieved_hash = dispatcher.get_scenario_hash(scenario_id);
    assert_eq!(retrieved_hash, scenario_hash);
}

#[test]
#[should_panic(expected: ('Scenario not found',))]
fn test_get_scenario_hash_not_found() {
    let (dispatcher, _, _) = deploy_for_scenarios();

    let non_existent_id: felt252 = 999;

    // Try to get hash for non-existent scenario
    dispatcher.get_scenario_hash(non_existent_id);
}

#[test]
fn test_get_scenario_info_success() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    let scenario_id: felt252 = 123;
    let scenario_hash: felt252 = 456;

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata);
    stop_cheat_caller_address(contract_address);

    // Then get the complete info
    let retrieved_metadata = dispatcher.get_scenario_info(scenario_id);
    assert_eq!(retrieved_metadata.scenario_id, scenario_id);
    assert_eq!(retrieved_metadata.scenario_hash, scenario_hash);
    assert_eq!(retrieved_metadata.author, owner);
}

#[test]
#[should_panic(expected: ('Scenario not found',))]
fn test_get_scenario_info_not_found() {
    let (dispatcher, _, _) = deploy_for_scenarios();

    let non_existent_id: felt252 = 999;

    // Try to get info for non-existent scenario
    dispatcher.get_scenario_info(non_existent_id);
}

#[test]
fn test_verify_scenario_invalid_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();

    let scenario_id: felt252 = 123;
    let scenario_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    // First register the scenario
    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata);
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
#[should_panic(expected: ('Scenario ID cannot be zero',))]
fn test_register_scenario_zero_id() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 0;
    let scenario_hash: felt252 = 'hash456';

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Scenario hash cannot be zero',))]
fn test_register_scenario_zero_hash() {
    let (dispatcher, contract_address, owner) = deploy_for_scenarios();
    let scenario_id: felt252 = 'scenario123';
    let scenario_hash: felt252 = 0;

    let metadata = ScenarioMetadata { scenario_id, scenario_hash, author: owner };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata);
    stop_cheat_caller_address(contract_address);
}

// ===== SIMULATION TESTS =====

#[test]
fn test_register_simulation_success() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Character not found',))]
fn test_register_simulation_invalid_character() {
    let (dispatcher, _char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Only register scenario, not character
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id: 'invalid_char', // This character doesn't exist
        scenario_id,
        simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    // Should panic - character not found
    dispatcher.register_simulation(metadata);
}

#[test]
#[should_panic(expected: ('Scenario not found',))]
fn test_register_simulation_invalid_scenario() {
    let (dispatcher, char_dispatcher, _scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Only register character, not scenario
    let character_id = register_test_character(char_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id,
        author: owner,
        character_id,
        scenario_id: 'invalid_scenario', // This scenario doesn't exist
        simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    // Should panic - scenario not found
    dispatcher.register_simulation(metadata);
}

#[test]
fn test_get_simulation_info_success() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 123;
    let simulation_hash: felt252 = 456;
    let wrong_hash: felt252 = 789;
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
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
#[should_panic(expected: ('Simulation not found',))]
fn test_get_simulation_hash_not_found() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    let non_existent_id: felt252 = 999;

    // Try to get hash for non-existent simulation
    dispatcher.get_simulation_hash(non_existent_id);
}

#[test]
#[should_panic(expected: ('Simulation not found',))]
fn test_get_simulation_info_not_found() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    let non_existent_id: felt252 = 999;

    // Try to get info for non-existent simulation
    dispatcher.get_simulation_info(non_existent_id);
}

#[test]
#[should_panic(expected: ('Simulation ID cannot be zero',))]
fn test_register_simulation_zero_id() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 0;
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Simulation hash cannot be zero',))]
fn test_register_simulation_zero_hash() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 0;
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Author cannot be zero',))]
fn test_register_simulation_zero_author() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let zero_author: ContractAddress = 0.try_into().unwrap();
    let metadata = SimulationMetadata {
        simulation_id, author: zero_author, character_id, scenario_id, simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_register_simulation_with_token_invalid_token() {
    let (
        char_dispatcher,
        scenario_dispatcher,
        sim_dispatcher,
        _owner_dispatcher,
        _session_dispatcher,
        _nft_dispatcher,
        owner,
        _nft_address,
        _tokens_core_address,
    ) =
        deploy_contract_with_nft();
    let contract_address = sim_dispatcher.contract_address;

    // Registry address is already configured in deploy_contract_with_nft()

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let author: ContractAddress = owner;
    let non_existent_token_id: u256 = 999; // Token that doesn't exist
    let expiration_timestamp: u64 = 1735689600;

    let metadata = SimulationWithTokenMetadata {
        simulation_id,
        author,
        character_id,
        scenario_id,
        simulation_hash,
        token_id: non_existent_token_id,
        expiration_timestamp,
    };

    start_cheat_caller_address(contract_address, owner);
    // This should panic because token 999 doesn't exist in the ERC1155 contract
    sim_dispatcher.register_simulation_with_token(metadata);
    stop_cheat_caller_address(contract_address);
}

// ===== BATCH CHARACTER VERSION TESTS =====

#[test]
fn test_batch_verify_characters_all_valid() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    // Register multiple character versions
    let char_id_1: felt252 = 100;
    let char_hash_1: felt252 = 200;
    let char_id_2: felt252 = 101;
    let char_hash_2: felt252 = 201;
    let char_id_3: felt252 = 102;
    let char_hash_3: felt252 = 202;

    let metadata1 = CharacterMetadata {
        character_id: char_id_1, character_hash: char_hash_1, author: owner,
    };
    let metadata2 = CharacterMetadata {
        character_id: char_id_2, character_hash: char_hash_2, author: owner,
    };
    let metadata3 = CharacterMetadata {
        character_id: char_id_3, character_hash: char_hash_3, author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character(metadata1);
    dispatcher.register_character(metadata2);
    dispatcher.register_character(metadata3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1);
    batch_array.append(metadata2);
    batch_array.append(metadata3);

    // Batch verify
    let results = dispatcher.batch_verify_characters(batch_array);

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
fn test_batch_verify_characters_mixed_results() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    // Register only some character versions
    let char_id_1: felt252 = 100;
    let char_hash_1: felt252 = 200;
    let char_id_2: felt252 = 101;
    let wrong_hash_2: felt252 = 999; // Wrong hash
    let char_id_3: felt252 = 102; // Not registered

    let metadata1_register = CharacterMetadata {
        character_id: char_id_1, character_hash: char_hash_1, author: owner,
    };
    let metadata2_register = CharacterMetadata {
        character_id: char_id_2, character_hash: 201, author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_character(metadata1_register);
    dispatcher.register_character(metadata2_register); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let metadata1_verify = CharacterMetadata {
        character_id: char_id_1, character_hash: char_hash_1, author: owner,
    };
    let metadata2_verify = CharacterMetadata {
        character_id: char_id_2, character_hash: wrong_hash_2, author: owner,
    };
    let metadata3_verify = CharacterMetadata {
        character_id: char_id_3, character_hash: 202, author: owner,
    };

    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1_verify); // Should be valid
    batch_array.append(metadata2_verify); // Should be invalid (wrong hash)
    batch_array.append(metadata3_verify); // Should be invalid (not registered)

    // Batch verify
    let results = dispatcher.batch_verify_characters(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_1) = *results.at(0);
    let (result_id_2, result_2) = *results.at(1);
    let (result_id_3, result_3) = *results.at(2);

    assert_eq!(result_id_1, char_id_1);
    assert!(result_1 == VerificationResult::Match); // Should be Match
    assert_eq!(result_id_2, char_id_2);
    assert!(result_2 == VerificationResult::Mismatch); // Should be Mismatch (wrong hash)
    assert_eq!(result_id_3, char_id_3);
    assert!(result_3 == VerificationResult::NotFound); // Should be NotFound (not registered)
}

#[test]
fn test_batch_verify_characters_with_zero_values() {
    let (dispatcher, _, owner) = deploy_for_characters();

    // Prepare batch verification array with zero values
    let metadata1 = CharacterMetadata { character_id: 0, character_hash: 200, author: owner };
    let metadata2 = CharacterMetadata { character_id: 100, character_hash: 0, author: owner };
    let metadata3 = CharacterMetadata { character_id: 0, character_hash: 0, author: owner };

    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1); // Zero ID
    batch_array.append(metadata2); // Zero hash
    batch_array.append(metadata3); // Both zero

    // Batch verify
    let results = dispatcher.batch_verify_characters(batch_array);

    // Check results - all should be NotFound due to zero values
    assert_eq!(results.len(), 3);
    let (result_id_1, result_1) = *results.at(0);
    let (result_id_2, result_2) = *results.at(1);
    let (result_id_3, result_3) = *results.at(2);

    assert_eq!(result_id_1, 0);
    assert!(result_1 == VerificationResult::NotFound); // Should be NotFound (zero ID)
    assert_eq!(result_id_2, 100);
    assert!(result_2 == VerificationResult::NotFound); // Should be NotFound (zero hash)
    assert_eq!(result_id_3, 0);
    assert!(result_3 == VerificationResult::NotFound); // Should be NotFound (both zero)
}

#[test]
fn test_batch_verify_characters_empty_array() {
    let (dispatcher, _, _) = deploy_for_characters();

    // Prepare empty batch verification array
    let batch_array = ArrayTrait::new();

    // Batch verify
    let results = dispatcher.batch_verify_characters(batch_array);

    // Check results - should be empty
    assert_eq!(results.len(), 0);
}

#[test]
fn test_batch_verify_characters_large_batch() {
    let (dispatcher, contract_address, owner) = deploy_for_characters();

    // Register multiple character versions
    start_cheat_caller_address(contract_address, owner);
    let mut i = 1;
    while i != 11 {
        let metadata = CharacterMetadata {
            character_id: i.into(), character_hash: (i + 100).into(), author: owner,
        };
        dispatcher.register_character(metadata);
        i += 1;
    }
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array with 10 items
    let mut batch_array = ArrayTrait::new();
    let mut j = 1;
    while j != 11 {
        let metadata = CharacterMetadata {
            character_id: j.into(), character_hash: (j + 100).into(), author: owner,
        };
        batch_array.append(metadata);
        j += 1;
    }

    // Batch verify
    let results = dispatcher.batch_verify_characters(batch_array);

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

    let metadata1 = ScenarioMetadata {
        scenario_id: scenario_id_1, scenario_hash: scenario_hash_1, author: owner,
    };
    let metadata2 = ScenarioMetadata {
        scenario_id: scenario_id_2, scenario_hash: scenario_hash_2, author: owner,
    };
    let metadata3 = ScenarioMetadata {
        scenario_id: scenario_id_3, scenario_hash: scenario_hash_3, author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata1);
    dispatcher.register_scenario(metadata2);
    dispatcher.register_scenario(metadata3);
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1);
    batch_array.append(metadata2);
    batch_array.append(metadata3);

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

    let metadata1_register = ScenarioMetadata {
        scenario_id: scenario_id_1, scenario_hash: scenario_hash_1, author: owner,
    };
    let metadata2_register = ScenarioMetadata {
        scenario_id: scenario_id_2, scenario_hash: 201, author: owner,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_scenario(metadata1_register);
    dispatcher.register_scenario(metadata2_register); // Register with different hash
    stop_cheat_caller_address(contract_address);

    // Prepare batch verification array
    let metadata1_verify = ScenarioMetadata {
        scenario_id: scenario_id_1, scenario_hash: scenario_hash_1, author: owner,
    };
    let metadata2_verify = ScenarioMetadata {
        scenario_id: scenario_id_2, scenario_hash: wrong_hash_2, author: owner,
    };
    let metadata3_verify = ScenarioMetadata {
        scenario_id: scenario_id_3, scenario_hash: 202, author: owner,
    };

    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata1_verify); // Should be valid
    batch_array.append(metadata2_verify); // Should be invalid (wrong hash)
    batch_array.append(metadata3_verify); // Should be invalid (not registered)

    // Batch verify
    let results = dispatcher.batch_verify_scenarios(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_valid_1) = *results.at(0);
    let (result_id_2, result_valid_2) = *results.at(1);
    let (result_id_3, result_valid_3) = *results.at(2);

    assert_eq!(result_id_1, scenario_id_1);
    assert!(result_valid_1 == VerificationResult::Match); // Should be Match
    assert_eq!(result_id_2, scenario_id_2);
    assert!(result_valid_2 == VerificationResult::Mismatch); // Should be Mismatch (wrong hash)
    assert_eq!(result_id_3, scenario_id_3);
    assert!(result_valid_3 == VerificationResult::NotFound); // Should be NotFound (not registered)
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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

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
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

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
        simulation_hash: wrong_hash_2 // Wrong hash
    };
    let metadata_3_not_registered = SimulationMetadata {
        simulation_id: sim_id_3,
        author: owner,
        character_id,
        scenario_id,
        simulation_hash: 202 // Not registered
    };

    let mut batch_array = ArrayTrait::new();
    batch_array.append(metadata_1_check); // Should be valid
    batch_array.append(metadata_2_wrong); // Should be invalid (wrong hash)
    batch_array.append(metadata_3_not_registered); // Should be invalid (not registered)

    // Batch verify
    let results = dispatcher.batch_verify_simulations(batch_array);

    // Check results
    assert_eq!(results.len(), 3);
    let (result_id_1, result_valid_1) = *results.at(0);
    let (result_id_2, result_valid_2) = *results.at(1);
    let (result_id_3, result_valid_3) = *results.at(2);

    assert_eq!(result_id_1, sim_id_1);
    assert!(result_valid_1 == VerificationResult::Match); // Should be Match
    assert_eq!(result_id_2, sim_id_2);
    assert!(result_valid_2 == VerificationResult::Mismatch); // Should be Mismatch (wrong hash)
    assert_eq!(result_id_3, sim_id_3);
    assert!(result_valid_3 == VerificationResult::NotFound); // Should be NotFound (not registered)
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
    let (
        dispatcher,
        sim_dispatcher,
        char_dispatcher,
        scenario_dispatcher,
        nft_dispatcher,
        contract_address,
        owner,
        nft_address,
    ) =
        deploy_for_sessions();

    // First register a simulation
    let simulation_id = register_test_simulation(
        sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner,
    );

    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Mint NFT to author so they can be validated
    start_cheat_caller_address(nft_address, owner);
    nft_dispatcher.mint_to_user(author);
    stop_cheat_caller_address(nft_address);

    let metadata = SessionMetadata { session_id, root_hash, simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    // Should not panic - first registration
    dispatcher.register_session(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Session already registered',))]
fn test_register_session_duplicate() {
    let (
        dispatcher,
        sim_dispatcher,
        char_dispatcher,
        scenario_dispatcher,
        nft_dispatcher,
        contract_address,
        owner,
        nft_address,
    ) =
        deploy_for_sessions();

    // First register a simulation
    let simulation_id = register_test_simulation(
        sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner,
    );

    let session_id: felt252 = 'session123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Mint NFT to author
    start_cheat_caller_address(nft_address, owner);
    nft_dispatcher.mint_to_user(author);
    stop_cheat_caller_address(nft_address);

    let metadata1 = SessionMetadata {
        session_id, root_hash: hash1, simulation_id, author, score: 100_u32,
    };
    let metadata2 = SessionMetadata {
        session_id, root_hash: hash2, simulation_id, author, score: 200_u32,
    };

    start_cheat_caller_address(contract_address, owner);
    // First registration should succeed
    dispatcher.register_session(metadata1);

    // Second registration with same session ID should fail
    dispatcher.register_session(metadata2);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Session ID cannot be zero',))]
fn test_register_session_zero_id() {
    let (
        dispatcher,
        sim_dispatcher,
        char_dispatcher,
        scenario_dispatcher,
        nft_dispatcher,
        contract_address,
        owner,
        nft_address,
    ) =
        deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(
        sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner,
    );

    let session_id: felt252 = 0;
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Mint NFT to author
    start_cheat_caller_address(nft_address, owner);
    nft_dispatcher.mint_to_user(author);
    stop_cheat_caller_address(nft_address);

    let metadata = SessionMetadata { session_id, root_hash, simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Root hash cannot be zero',))]
fn test_register_session_zero_hash() {
    let (
        dispatcher,
        sim_dispatcher,
        char_dispatcher,
        scenario_dispatcher,
        nft_dispatcher,
        contract_address,
        owner,
        nft_address,
    ) =
        deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(
        sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner,
    );

    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 0;
    let author: ContractAddress = 'author'.try_into().unwrap();

    // Mint NFT to author
    start_cheat_caller_address(nft_address, owner);
    nft_dispatcher.mint_to_user(author);
    stop_cheat_caller_address(nft_address);

    let metadata = SessionMetadata { session_id, root_hash, simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Author cannot be zero',))]
fn test_register_session_zero_author() {
    let (
        dispatcher,
        sim_dispatcher,
        char_dispatcher,
        scenario_dispatcher,
        _nft_dispatcher,
        contract_address,
        owner,
        _nft_address,
    ) =
        deploy_for_sessions();

    // Register a simulation first
    let simulation_id = register_test_simulation(
        sim_dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner,
    );

    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let author: ContractAddress = 0.try_into().unwrap();
    let metadata = SessionMetadata { session_id, root_hash, simulation_id, author, score: 100_u32 };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_session(metadata);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Author must own a Kliver NFT',))]
fn test_register_session_invalid_simulation() {
    let (dispatcher, _, _, _, _, contract_address, owner, _) = deploy_for_sessions();

    let session_id: felt252 = 'session123';
    let root_hash: felt252 = 'hash456';
    let invalid_simulation_id: felt252 = 'nonexistent_sim';
    let author: ContractAddress = 'author'.try_into().unwrap();
    let metadata = SessionMetadata {
        session_id, root_hash, simulation_id: invalid_simulation_id, author, score: 100_u32,
    };

    start_cheat_caller_address(contract_address, owner);
    // Should panic - simulation doesn't exist
    dispatcher.register_session(metadata);
    stop_cheat_caller_address(contract_address);
}

// ===== SIMULATION EXISTS TESTS =====

#[test]
fn test_simulation_exists_true() {
    let (dispatcher, char_dispatcher, scenario_dispatcher, contract_address, owner) =
        deploy_for_simulations();

    // Register character and scenario first
    let character_id = register_test_character(char_dispatcher, contract_address, owner);
    let scenario_id = register_test_scenario(scenario_dispatcher, contract_address, owner);

    let simulation_id: felt252 = 'sim123';
    let simulation_hash: felt252 = 'hash456';
    let metadata = SimulationMetadata {
        simulation_id, author: owner, character_id, scenario_id, simulation_hash,
    };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.register_simulation(metadata);
    stop_cheat_caller_address(contract_address);

    // Test simulation_exists
    let exists = dispatcher.simulation_exists(simulation_id);
    assert(exists, 'Simulation should exist');
}

#[test]
fn test_simulation_exists_false() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    let nonexistent_simulation_id: felt252 = 'nonexistent';

    // Test simulation_exists for non-registered simulation
    let exists = dispatcher.simulation_exists(nonexistent_simulation_id);
    assert(!exists, 'Simulation should not exist');
}

#[test]
fn test_simulation_exists_zero_id() {
    let (dispatcher, _, _, _, _) = deploy_for_simulations();

    // Test simulation_exists with zero ID
    let exists = dispatcher.simulation_exists(0);
    assert(!exists, 'Zero ID should not exist');
}
