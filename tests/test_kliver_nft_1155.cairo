use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
use starknet::ContractAddress;

// Import structs from the types file
use kliver_on_chain::kliver_1155_types::{TokenInfo, TokenDataToCreate, TokenDataToCreateTrait, Simulation};

// Define the interface for testing
#[starknet::interface]
trait IKliverRC1155<TContractState> {
    fn create_token(ref self: TContractState, token_data: TokenDataToCreate) -> u256;
    fn get_token_info(self: @TContractState, token_id: u256) -> TokenInfo;
    fn time_until_release(self: @TContractState, token_id: u256) -> u64;
    fn register_simulation(ref self: TContractState, simulation_id: u256, token_id: u256);
    fn get_simulation(self: @TContractState, simulation_id: u256) -> kliver_on_chain::kliver_1155_types::Simulation;
    fn get_owner(self: @TContractState) -> ContractAddress;
}

/// Helper function to deploy the KliverRC1155 contract
fn deploy_contract(owner: ContractAddress) -> IKliverRC1155Dispatcher {
    let contract = declare("KliverRC1155").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let base_uri: ByteArray = "https://api.kliver.io/1155/";
    Serde::serialize(@base_uri, ref constructor_calldata);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    IKliverRC1155Dispatcher { contract_address }
}

#[test]
fn test_create_token_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let token_data = TokenDataToCreateTrait::new(12345, 1000000000000000000); // 1 ETH in wei

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Assert the returned token_id is 1 (first token)
    assert(token_id == 1, 'Token ID should be 1');
}

#[test]
fn test_create_token_storage() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let release_hour: u64 = 12345;
    let release_amount: u256 = 1000000000000000000;
    let token_data = TokenDataToCreateTrait::new(release_hour, release_amount);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check storage using get_token_info
    let token_info = dispatcher.get_token_info(token_id);

    assert(token_info.release_hour == release_hour, 'Release hour should match');
    assert(token_info.release_amount == release_amount, 'Release amount should match');
}

#[test]
fn test_create_token_next_id_increment() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create first token
    let token_data_1 = TokenDataToCreateTrait::new(1000, 1000);
    let token_id_1 = dispatcher.create_token(token_data_1);

    // Create second token
    let token_data_2 = TokenDataToCreateTrait::new(2000, 2000);
    let token_id_2 = dispatcher.create_token(token_data_2);

    stop_cheat_caller_address(dispatcher.contract_address);

    assert(token_id_1 == 1, 'First token ID should be 1');
    assert(token_id_2 == 2, 'Second token ID should be 2');
}

#[test]
fn test_get_token_info_multiple_tokens() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create multiple tokens
    let token_data_1 = TokenDataToCreateTrait::new(1000, 1000);
    let token_id_1 = dispatcher.create_token(token_data_1);

    let token_data_2 = TokenDataToCreateTrait::new(2000, 2000);
    let token_id_2 = dispatcher.create_token(token_data_2);

    let token_data_3 = TokenDataToCreateTrait::new(3000, 3000);
    let token_id_3 = dispatcher.create_token(token_data_3);

    stop_cheat_caller_address(dispatcher.contract_address);

    // Check each token info
    let info_1 = dispatcher.get_token_info(token_id_1);
    let info_2 = dispatcher.get_token_info(token_id_2);
    let info_3 = dispatcher.get_token_info(token_id_3);

    assert(info_1.release_hour == 1000, 'Token 1 release hour');
    assert(info_1.release_amount == 1000, 'Token 1 release amount');

    assert(info_2.release_hour == 2000, 'Token 2 release hour');
    assert(info_2.release_amount == 2000, 'Token 2 release amount');

    assert(info_3.release_hour == 3000, 'Token 3 release hour');
    assert(info_3.release_amount == 3000, 'Token 3 release amount');
}

#[test]
fn test_create_token_different_callers() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create token with owner
    let token_data_1 = TokenDataToCreateTrait::new(1000, 1000);
    let token_id_1 = dispatcher.create_token(token_data_1);

    // Create token with owner again
    let token_data_2 = TokenDataToCreateTrait::new(2000, 2000);
    let token_id_2 = dispatcher.create_token(token_data_2);

    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that tokens were created with different IDs
    assert(token_id_1 == 1, 'First token ID should be 1');
    assert(token_id_2 == 2, 'Second token ID should be 2');

    // Check token info is stored correctly
    let info_1 = dispatcher.get_token_info(token_id_1);
    let info_2 = dispatcher.get_token_info(token_id_2);

    assert(info_1.release_hour == 1000, 'Token 1 release hour');
    assert(info_1.release_amount == 1000, 'Token 1 release amount');
    assert(info_2.release_hour == 2000, 'Token 2 release hour');
    assert(info_2.release_amount == 2000, 'Token 2 release amount');
}

#[test]
fn test_register_simulation_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_id: u256 = 123;
    dispatcher.register_simulation(simulation_id, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify simulation was registered
    let simulation = dispatcher.get_simulation(simulation_id);
    assert(simulation.simulation_id == simulation_id, 'Simulation ID mismatch');
    assert(simulation.token_id == token_id, 'Token ID mismatch');
    assert(simulation.creator == owner, 'Creator mismatch');
}

#[test]
#[should_panic(expected: ('Token does not exist', ))]
fn test_register_simulation_invalid_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Try to register simulation with non-existent token
    let simulation_id: u256 = 123;
    let invalid_token_id: u256 = 999;
    dispatcher.register_simulation(simulation_id, invalid_token_id);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_get_simulation() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_id: u256 = 456;
    dispatcher.register_simulation(simulation_id, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Get simulation info
    let simulation = dispatcher.get_simulation(simulation_id);

    assert(simulation.simulation_id == simulation_id, 'Simulation ID should match');
    assert(simulation.token_id == token_id, 'Token ID should match');
    assert(simulation.creator == owner, 'Creator should match');
}

#[test]
#[should_panic(expected: ('Not owner', ))]
fn test_create_token_non_owner_should_fail() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();

    let token_data = TokenDataToCreateTrait::new(1000, 1000);

    start_cheat_caller_address(dispatcher.contract_address, non_owner);

    // This should fail because non_owner is not the owner
    dispatcher.create_token(token_data);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_time_until_release_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token with release_hour = 12 (noon)
    let token_data = TokenDataToCreateTrait::new(12, 1000);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Mock current time to be 6 AM (6 hours before release)
    start_cheat_block_timestamp_global(6 * 3600); // 6 AM

    let time_until_release = dispatcher.time_until_release(token_id);

    // Should be 6 hours = 21600 seconds
    assert(time_until_release == 21600, 'Should be 6 hours until release');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_time_until_release_tomorrow() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token with release_hour = 6 (6 AM)
    let token_data = TokenDataToCreateTrait::new(6, 1000);

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Mock current time to be 8 AM (2 hours after release time)
    start_cheat_block_timestamp_global(8 * 3600); // 8 AM

    let time_until_release = dispatcher.time_until_release(token_id);

    // Should be 22 hours until next release (24 - 2 = 22 hours = 79200 seconds)
    assert(time_until_release == 79200, '22 hours until release');

    stop_cheat_block_timestamp_global();
}

#[test]
#[should_panic(expected: ('Token does not exist', ))]
fn test_time_until_release_nonexistent_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Try to get time until release for a token that doesn't exist
    dispatcher.time_until_release(999);
}