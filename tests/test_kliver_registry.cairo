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
    let contract = declare("KliverRegistry").unwrap().contract_class();
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
    let contract = declare("KliverRegistry").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(zero_owner.into());
    let (_contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
}

#[test]
fn test_get_owner() {
    let (contract, expected_owner) = deploy_contract();
    let owner = contract.get_owner();
    assert(owner == expected_owner, 'Owner should match');
    assert(owner != 0.try_into().unwrap(), 'Owner should not be zero');
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