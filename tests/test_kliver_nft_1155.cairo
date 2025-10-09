use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::{ContractAddress, syscalls::{call_contract_syscall}};
use core::array::ArrayTrait;
use core::traits::TryInto;

// Import structs from the types file
use kliver_on_chain::kliver_1155_types::{TokenInfo, TokenDataToCreate, TokenCreated};

/// Helper function to deploy the KliverRC1155 contract
fn deploy_contract(owner: ContractAddress) -> ContractAddress {
    let contract = declare("KliverRC1155").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let base_uri: ByteArray = "https://api.kliver.io/1155/";
    Serde::serialize(@base_uri, ref constructor_calldata);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

/// Helper function to call create_token
fn call_create_token(contract_address: ContractAddress, caller: ContractAddress, token_data: TokenDataToCreate) -> u256 {
    start_cheat_caller_address(contract_address, caller);

    let mut calldata = ArrayTrait::new();
    Serde::serialize(@token_data, ref calldata);

    let result = call_contract_syscall(contract_address, selector!("create_token"), calldata.span()).unwrap();
    let token_id: u256 = (*result.at(0)).try_into().unwrap();

    stop_cheat_caller_address(contract_address);
    token_id
}

/// Helper function to call get_token_info
fn call_get_token_info(contract_address: ContractAddress, token_id: u256) -> (u64, u256) {
    let mut calldata = ArrayTrait::new();
    calldata.append(token_id.low.into());
    calldata.append(token_id.high.into());

    let result = call_contract_syscall(contract_address, selector!("get_token_info"), calldata.span()).unwrap();

    let release_hour: u64 = (*result.at(0)).try_into().unwrap();
    let release_amount_low: u128 = (*result.at(1)).try_into().unwrap();
    let release_amount_high: u128 = (*result.at(2)).try_into().unwrap();
    let release_amount = u256 { low: release_amount_low, high: release_amount_high };

    (release_hour, release_amount)
}

#[test]
fn test_create_token_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_contract(owner);
    let token_data = TokenDataToCreate {
        release_hour: 12345,
        release_amount: 1000000000000000000, // 1 ETH in wei
    };

    let token_id = call_create_token(contract_address, owner, token_data);

    // Assert the returned token_id is 1 (first token)
    assert(token_id == 1, 'Token ID should be 1');
}

#[test]
fn test_create_token_storage() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_contract(owner);
    let release_hour: u64 = 12345;
    let release_amount: u256 = 1000000000000000000;
    let token_data = TokenDataToCreate {
        release_hour,
        release_amount,
    };

    let token_id = call_create_token(contract_address, owner, token_data);

    // Check storage using get_token_info
    let (stored_release_hour, stored_release_amount) = call_get_token_info(contract_address, token_id);

    assert(stored_release_hour == release_hour, 'Release hour should match');
    assert(stored_release_amount == release_amount, 'Release amount should match');
}

#[test]
fn test_create_token_next_id_increment() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_contract(owner);

    // Create first token
    let token_data_1 = TokenDataToCreate { release_hour: 1000, release_amount: 1000 };
    let token_id_1 = call_create_token(contract_address, owner, token_data_1);

    // Create second token
    let token_data_2 = TokenDataToCreate { release_hour: 2000, release_amount: 2000 };
    let token_id_2 = call_create_token(contract_address, owner, token_data_2);

    assert(token_id_1 == 1, 'First token ID should be 1');
    assert(token_id_2 == 2, 'Second token ID should be 2');
}

#[test]
fn test_get_token_info_multiple_tokens() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_contract(owner);

    // Create multiple tokens
    let token_data_1 = TokenDataToCreate { release_hour: 1000, release_amount: 1000 };
    let token_id_1 = call_create_token(contract_address, owner, token_data_1);

    let token_data_2 = TokenDataToCreate { release_hour: 2000, release_amount: 2000 };
    let token_id_2 = call_create_token(contract_address, owner, token_data_2);

    let token_data_3 = TokenDataToCreate { release_hour: 3000, release_amount: 3000 };
    let token_id_3 = call_create_token(contract_address, owner, token_data_3);

    // Check each token info
    let (release_hour_1, release_amount_1) = call_get_token_info(contract_address, token_id_1);
    let (release_hour_2, release_amount_2) = call_get_token_info(contract_address, token_id_2);
    let (release_hour_3, release_amount_3) = call_get_token_info(contract_address, token_id_3);

    assert(release_hour_1 == 1000, 'Token 1 release hour');
    assert(release_amount_1 == 1000, 'Token 1 release amount');

    assert(release_hour_2 == 2000, 'Token 2 release hour');
    assert(release_amount_2 == 2000, 'Token 2 release amount');

    assert(release_hour_3 == 3000, 'Token 3 release hour');
    assert(release_amount_3 == 3000, 'Token 3 release amount');
}

#[test]
fn test_create_token_different_callers() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_contract(owner);

    // Create token with owner
    let token_data_1 = TokenDataToCreate { release_hour: 1000, release_amount: 1000 };
    let token_id_1 = call_create_token(contract_address, owner, token_data_1);

    // Create token with owner again
    let token_data_2 = TokenDataToCreate { release_hour: 2000, release_amount: 2000 };
    let token_id_2 = call_create_token(contract_address, owner, token_data_2);

    // Check that tokens were created with different IDs
    assert(token_id_1 == 1, 'First token ID should be 1');
    assert(token_id_2 == 2, 'Second token ID should be 2');

    // Check token info is stored correctly
    let (release_hour_1, release_amount_1) = call_get_token_info(contract_address, token_id_1);
    let (release_hour_2, release_amount_2) = call_get_token_info(contract_address, token_id_2);

    assert(release_hour_1 == 1000, 'Token 1 release hour');
    assert(release_amount_1 == 1000, 'Token 1 release amount');
    assert(release_hour_2 == 2000, 'Token 2 release hour');
    assert(release_amount_2 == 2000, 'Token 2 release amount');
}

#[test]
fn test_create_token_non_owner_should_fail() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();

    let token_data = TokenDataToCreate { release_hour: 1000, release_amount: 1000 };

    start_cheat_caller_address(contract_address, non_owner);

    let mut calldata = ArrayTrait::new();
    Serde::serialize(@token_data, ref calldata);

    // This should fail because non_owner is not the owner
    let result = call_contract_syscall(contract_address, selector!("create_token"), calldata.span());

    // The call should fail
    assert(result.is_err(), 'Call should have failed');
}