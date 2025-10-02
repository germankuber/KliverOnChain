use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use core::array::ArrayTrait;

// Import contract interface
use kliver_on_chain::{
    IKliverRegistryDispatcher,
    IKliverRegistryDispatcherTrait
};

/// Helper function to deploy the contract
fn deploy_contract() -> (IKliverRegistryDispatcher, ContractAddress) {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract = declare("kliver_registry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    (IKliverRegistryDispatcher { contract_address }, owner)
}

#[test]
fn test_constructor() {
    let (contract, expected_owner) = deploy_contract();
    let actual_owner = contract.get_owner();
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
        let (dispatcher, expected_owner) = deploy_contract();
        let owner = dispatcher.get_owner();
        assert_eq!(owner, expected_owner);
    }

    #[test]
    fn test_verify_character_version_valid() {
        let (dispatcher, owner) = deploy_contract();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;

        // First register the character version
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.register_character_version(character_version_id, character_version_hash);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Then verify it
        let is_valid = dispatcher.verify_character_version(character_version_id, character_version_hash);
        assert!(is_valid);
    }

    #[test]
    fn test_verify_character_version_invalid_hash() {
        let (dispatcher, owner) = deploy_contract();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;
        let wrong_hash: felt252 = 789;

        // First register the character version
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.register_character_version(character_version_id, character_version_hash);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Then verify with wrong hash
        let is_valid = dispatcher.verify_character_version(character_version_id, wrong_hash);
        assert!(!is_valid);
    }

    #[test]
    fn test_verify_character_version_non_existent() {
        let (dispatcher, _) = deploy_contract();

        let non_existent_id: felt252 = 999;
        let some_hash: felt252 = 456;

        // Try to verify a character version that doesn't exist
        let is_valid = dispatcher.verify_character_version(non_existent_id, some_hash);
        assert!(!is_valid);
    }

    #[test]
    #[should_panic(expected: ('Version ID cannot be zero', ))]
    fn test_verify_character_version_zero_id_should_fail() {
        let (dispatcher, _) = deploy_contract();

        let character_version_hash: felt252 = 456;

        // Try to verify with zero ID (should panic)
        dispatcher.verify_character_version(0, character_version_hash);
    }

    #[test]
    #[should_panic(expected: ('Version hash cannot be zero', ))]
    fn test_verify_character_version_zero_hash_should_fail() {
        let (dispatcher, _) = deploy_contract();

        let character_version_id: felt252 = 123;

        // Try to verify with zero hash (should panic)
        dispatcher.verify_character_version(character_version_id, 0);
    }

    #[test]
    fn test_get_character_version_hash_success() {
        let (dispatcher, owner) = deploy_contract();

        let character_version_id: felt252 = 123;
        let character_version_hash: felt252 = 456;

        // First register the character version
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher.register_character_version(character_version_id, character_version_hash);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Then get the hash
        let retrieved_hash = dispatcher.get_character_version_hash(character_version_id);
        assert_eq!(retrieved_hash, character_version_hash);
    }

    #[test]
    #[should_panic(expected: ('Character version not found', ))]
    fn test_get_character_version_hash_not_found() {
        let (dispatcher, _) = deploy_contract();

        let non_existent_id: felt252 = 999;

        // Try to get hash for non-existent character version
        dispatcher.get_character_version_hash(non_existent_id);
    }

    #[test]
    #[should_panic(expected: ('Version ID cannot be zero', ))]
    fn test_get_character_version_hash_zero_id() {
        let (dispatcher, _) = deploy_contract();

        // Try to get hash with zero ID
        dispatcher.get_character_version_hash(0);
    }

#[test]
fn test_register_character_version_success() {
    let (contract, owner) = deploy_contract();
    let character_version_id: felt252 = 'character123';
    let character_version_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract.contract_address, owner);
    // Should not panic - first registration
    contract.register_character_version(character_version_id, character_version_hash);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Version ID already registered', ))]
fn test_register_character_version_duplicate() {
    let (contract, owner) = deploy_contract();
    let character_version_id: felt252 = 'character123';
    let hash1: felt252 = 'hash456';
    let hash2: felt252 = 'hash789';
    
    start_cheat_caller_address(contract.contract_address, owner);
    // First registration should succeed
    contract.register_character_version(character_version_id, hash1);
    
    // Second registration with same version ID should fail
    contract.register_character_version(character_version_id, hash2);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Version ID cannot be zero', ))]
fn test_register_character_version_zero_id() {
    let (contract, owner) = deploy_contract();
    let character_version_id: felt252 = 0;
    let character_version_hash: felt252 = 'hash456';
    
    start_cheat_caller_address(contract.contract_address, owner);
    contract.register_character_version(character_version_id, character_version_hash);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: ('Version hash cannot be zero', ))]
fn test_register_character_version_zero_hash() {
    let (contract, owner) = deploy_contract();
    let character_version_id: felt252 = 'character123';
    let character_version_hash: felt252 = 0;
    
    start_cheat_caller_address(contract.contract_address, owner);
    contract.register_character_version(character_version_id, character_version_hash);
    stop_cheat_caller_address(contract.contract_address);
}