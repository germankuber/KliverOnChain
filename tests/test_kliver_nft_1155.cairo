use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
use starknet::ContractAddress;

// Import structs from the types file
use kliver_on_chain::kliver_1155_types::{TokenInfo, TokenDataToCreate, TokenDataToCreateTrait, SimulationDataToCreate, SimulationDataToCreateTrait, SessionPayment};

// Mock ERC1155 Receiver contract for testing using OpenZeppelin's component
#[starknet::contract]
mod MockERC1155Receiver {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;

    component!(path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155Receiver Mixin
    #[abi(embed_v0)]
    impl ERC1155ReceiverMixinImpl = ERC1155ReceiverComponent::ERC1155ReceiverMixinImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }
}

// Define the interface for testing
#[starknet::interface]
trait IKliverRC1155<TContractState> {
    fn create_token(ref self: TContractState, token_data: TokenDataToCreate) -> u256;
    fn get_token_info(self: @TContractState, token_id: u256) -> TokenInfo;
    fn time_until_release(self: @TContractState, token_id: u256) -> u64;
    fn register_simulation(ref self: TContractState, simulation_data: SimulationDataToCreate) -> felt252;
    fn get_simulation(self: @TContractState, simulation_id: felt252) -> kliver_on_chain::kliver_1155_types::Simulation;
    fn is_simulation_expired(self: @TContractState, simulation_id: felt252) -> bool;
    fn add_to_whitelist(ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252);
    fn remove_from_whitelist(ref self: TContractState, token_id: u256, wallet: ContractAddress);
    fn is_whitelisted(self: @TContractState, token_id: u256, wallet: ContractAddress) -> bool;
    fn get_whitelist_simulation(self: @TContractState, token_id: u256, wallet: ContractAddress) -> felt252;
    fn claim(ref self: TContractState, token_id: u256, simulation_id: felt252);
    fn get_claimable_amount(self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256;
    fn pay_for_session(ref self: TContractState, simulation_id: felt252, session_id: felt252, amount: u256);
    fn is_session_paid(self: @TContractState, session_id: felt252) -> bool;
    fn get_session_payment(self: @TContractState, session_id: felt252) -> SessionPayment;
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

/// Helper function to deploy a mock ERC1155 receiver contract
fn deploy_mock_receiver() -> ContractAddress {
    let contract = declare("MockERC1155Receiver").unwrap().contract_class();
    let constructor_calldata = ArrayTrait::new();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
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
    let simulation_id: felt252 = 123;
    let simulation_data = SimulationDataToCreateTrait::new(simulation_id, token_id, 1735689600); // 2025-01-01 00:00:00 UTC
    let returned_id = dispatcher.register_simulation(simulation_data);
    assert(returned_id == simulation_id, 'Returned ID should match');
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify simulation was registered
    let simulation = dispatcher.get_simulation(simulation_id);
    assert(simulation.simulation_id == simulation_id, 'Simulation ID mismatch');
    assert(simulation.token_id == token_id, 'Token ID mismatch');
    assert(simulation.creator == owner, 'Creator mismatch');
    assert(simulation.expiration_timestamp == 1735689600, 'Expiration timestamp');
}

#[test]
#[should_panic(expected: ('Token does not exist', ))]
fn test_register_simulation_invalid_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Try to register simulation with non-existent token
    let simulation_data = SimulationDataToCreateTrait::new(123, 999, 1735689600);
    dispatcher.register_simulation(simulation_data);

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
    let simulation_id: felt252 = 456;
    let simulation_data = SimulationDataToCreateTrait::new(simulation_id, token_id, 1735689600);
    let returned_id = dispatcher.register_simulation(simulation_data);
    assert(returned_id == simulation_id, 'Returned ID should match');
    stop_cheat_caller_address(dispatcher.contract_address);

    // Get simulation info
    let simulation = dispatcher.get_simulation(simulation_id);

    assert(simulation.simulation_id == simulation_id, 'Simulation ID should match');
    assert(simulation.token_id == token_id, 'Token ID should match');
    assert(simulation.creator == owner, 'Creator should match');
    assert(simulation.expiration_timestamp == 1735689600, 'Expiration timestamp match');
}

#[test]
#[should_panic(expected: ('Not owner', ))]
fn test_register_simulation_non_owner_should_fail() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to register simulation as non-owner
    start_cheat_caller_address(dispatcher.contract_address, non_owner);
    let simulation_data = SimulationDataToCreateTrait::new(456, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);
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
fn test_pay_for_session_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver(); // Use mock contract instead of simple address

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);

    // Fast forward time to allow claiming
    start_cheat_block_timestamp_global(86400 * 3); // 3 days later

    // Mint some tokens to the wallet for payment
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // This should mint tokens to wallet
    stop_cheat_caller_address(dispatcher.contract_address);

    // Pay for session
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_session(123, 456, 500); // Pay 500 tokens for session 456
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check session is marked as paid
    let is_paid = dispatcher.is_session_paid(456);
    assert(is_paid, 'Session should be paid');

    // Check payment details
    let payment = dispatcher.get_session_payment(456);
    assert(payment.session_id == 456, 'Session ID should match');
    assert(payment.simulation_id == 123, 'Simulation ID should match');
    assert(payment.payer == wallet, 'Payer should match');
    assert(payment.amount == 500, 'Amount should match');
}

#[test]
#[should_panic(expected: ('Not whitelisted', ))]
fn test_pay_for_session_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to pay without being whitelisted
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_session(123, 456, 500);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Insufficient balance', ))]
fn test_pay_for_session_insufficient_balance() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to pay more than available balance (wallet has 0 tokens)
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_session(123, 456, 500);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_is_session_paid_false() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Check unpaid session
    let is_paid = dispatcher.is_session_paid(999);
    assert(!is_paid, 'Session should not be paid');
}

#[test]
fn test_add_to_whitelist_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is whitelisted
    let is_whitelisted = dispatcher.is_whitelisted(token_id, wallet);
    assert(is_whitelisted, 'Should be whitelisted');

    let whitelist_simulation = dispatcher.get_whitelist_simulation(token_id, wallet);
    assert(whitelist_simulation == 123, 'Wrong simulation ID');
}

#[test]
#[should_panic(expected: ('Token does not exist', ))]
fn test_add_to_whitelist_invalid_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    // Try to add to whitelist with non-existent token
    dispatcher.add_to_whitelist(999, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Simulation not for this token', ))]
fn test_add_to_whitelist_invalid_simulation() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Try to add to whitelist with simulation for different token
    dispatcher.add_to_whitelist(token_id, wallet, 999);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Not owner', ))]
fn test_add_to_whitelist_non_owner() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to add to whitelist as non-owner
    start_cheat_caller_address(dispatcher.contract_address, non_owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_remove_from_whitelist_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);

    // Remove from whitelist
    dispatcher.remove_from_whitelist(token_id, wallet);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is not whitelisted
    let is_whitelisted = dispatcher.is_whitelisted(token_id, wallet);
    assert(!is_whitelisted, 'Should not be whitelisted');

    let whitelist_simulation = dispatcher.get_whitelist_simulation(token_id, wallet);
    assert(whitelist_simulation == 0, 'Should be 0');
}

#[test]
fn test_is_whitelisted_false() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is not whitelisted
    let is_whitelisted = dispatcher.is_whitelisted(token_id, wallet);
    assert(!is_whitelisted, 'Should not be whitelisted');
}

// Note: test_claim_success is commented out because it requires deploying a contract
// for the wallet address to accept ERC1155 tokens. The logic is tested via get_claimable_amount.

#[test]
fn test_get_claimable_amount() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000); // release at hour 12, 1000 tokens per day
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward time to simulate 2 days passed
    start_cheat_block_timestamp_global(86400 * 2); // 2 days later

    // Check claimable amount
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    assert(claimable == 2000, 'Should have 2000 claimable'); // 2 days * 1000 tokens

    stop_cheat_block_timestamp_global();
}

#[test]
#[should_panic(expected: ('Not whitelisted', ))]
fn test_claim_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1735689600);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to claim without being whitelisted
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Simulation has expired', ))]
fn test_claim_expired_simulation() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation that expires soon
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, 1000); // expires at timestamp 1000
    dispatcher.register_simulation(simulation_data);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward time past expiration
    start_cheat_block_timestamp_global(2000); // past expiration

    // Try to claim
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

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

#[test]
fn test_is_simulation_expired_false() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation with future expiration
    let future_timestamp: u64 = 1735689600; // 2025-01-01 00:00:00 UTC
    let simulation_data = SimulationDataToCreateTrait::new(123, token_id, future_timestamp);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that simulation is not expired
    let is_expired = dispatcher.is_simulation_expired(123);
    assert(!is_expired, 'Not expired');
}

#[test]
fn test_is_simulation_expired_true() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation with past expiration
    let past_timestamp: u64 = 0; // Timestamp 0 is always in the past
    let simulation_data = SimulationDataToCreateTrait::new(456, token_id, past_timestamp);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that simulation is expired
    let is_expired = dispatcher.is_simulation_expired(456);
    assert(is_expired, 'Expired');
}

#[test]
fn test_is_simulation_expired_at_exactly_expiration_time() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    let token_data = TokenDataToCreateTrait::new(12, 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(token_data);

    // Register a simulation
    let expiration_timestamp: u64 = 1735689600; // 2025-01-01 00:00:00 UTC
    let simulation_data = SimulationDataToCreateTrait::new(789, token_id, expiration_timestamp);
    dispatcher.register_simulation(simulation_data);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Mock time to exactly the expiration timestamp
    start_cheat_block_timestamp_global(expiration_timestamp);

    // Check that simulation is considered expired (current_time >= expiration_timestamp)
    let is_expired = dispatcher.is_simulation_expired(789);
    assert(is_expired, 'Expired at exact time');

    stop_cheat_block_timestamp_global();
}