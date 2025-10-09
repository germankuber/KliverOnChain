use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
use starknet::ContractAddress;

// Import structs from the types file
use kliver_on_chain::kliver_1155_types::{TokenInfo, SessionPayment, HintPayment};

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
    fn create_token(ref self: TContractState, release_hour: u64, release_amount: u256, special_release: u256) -> u256;
    fn get_token_info(self: @TContractState, token_id: u256) -> TokenInfo;
    fn time_until_release(self: @TContractState, token_id: u256) -> u64;
    fn register_simulation(ref self: TContractState, simulation_id: felt252, token_id: u256, expiration_timestamp: u64) -> felt252;
    fn get_simulation(self: @TContractState, simulation_id: felt252) -> kliver_on_chain::kliver_1155_types::Simulation;
    fn is_simulation_expired(self: @TContractState, simulation_id: felt252) -> bool;
    fn add_to_whitelist(ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252);
    fn remove_from_whitelist(ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252);
    fn is_whitelisted(self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> bool;
    fn claim(ref self: TContractState, token_id: u256, simulation_id: felt252);
    fn get_claimable_amount(self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256;
    fn pay_for_session(ref self: TContractState, simulation_id: felt252, session_id: felt252, amount: u256);
    fn is_session_paid(self: @TContractState, session_id: felt252) -> bool;
    fn get_session_payment(self: @TContractState, session_id: felt252) -> SessionPayment;
    fn pay_for_hint(ref self: TContractState, simulation_id: felt252, hint_id: felt252, amount: u256);
    fn is_hint_paid(self: @TContractState, hint_id: felt252) -> bool;
    fn get_hint_payment(self: @TContractState, hint_id: felt252) -> HintPayment;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn balance_of(self: @TContractState, account: ContractAddress, token_id: u256) -> u256;
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

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(1, 1000000000000000000, 0); // 1 ETH in wei, no special
    stop_cheat_caller_address(dispatcher.contract_address);

    // Assert the returned token_id is 1 (first token)
    assert(token_id == 1, 'Token ID should be 1');
}

#[test]
fn test_create_token_storage() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let release_hour: u64 = 1;
    let release_amount: u256 = 1000000000000000000;

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(release_hour, release_amount, 0);
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
    let token_id_1 = dispatcher.create_token(1, 1000, 0);

    // Create second token
    let token_id_2 = dispatcher.create_token(2, 2000, 0);

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
    let token_id_1 = dispatcher.create_token(1, 1000, 0);

    let token_id_2 = dispatcher.create_token(2, 2000, 0);

    let token_id_3 = dispatcher.create_token(3, 3000, 0);

    stop_cheat_caller_address(dispatcher.contract_address);

    // Check each token info
    let info_1 = dispatcher.get_token_info(token_id_1);
    let info_2 = dispatcher.get_token_info(token_id_2);
    let info_3 = dispatcher.get_token_info(token_id_3);

    assert(info_1.release_hour == 1, 'Token 1 release hour');
    assert(info_1.release_amount == 1000, 'Token 1 release amount');

    assert(info_2.release_hour == 2, 'Token 2 release hour');
    assert(info_2.release_amount == 2000, 'Token 2 release amount');

    assert(info_3.release_hour == 3, 'Token 3 release hour');
    assert(info_3.release_amount == 3000, 'Token 3 release amount');
}

#[test]
fn test_create_token_different_callers() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create token with owner
    let token_id_1 = dispatcher.create_token(1, 1000, 0);

    // Create token with owner again
    let token_id_2 = dispatcher.create_token(2, 2000, 0);

    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that tokens were created with different IDs
    assert(token_id_1 == 1, 'First token ID should be 1');
    assert(token_id_2 == 2, 'Second token ID should be 2');

    // Check token info is stored correctly
    let info_1 = dispatcher.get_token_info(token_id_1);
    let info_2 = dispatcher.get_token_info(token_id_2);

    assert(info_1.release_hour == 1, 'Token 1 release hour');
    assert(info_1.release_amount == 1000, 'Token 1 release amount');
    assert(info_2.release_hour == 2, 'Token 2 release hour');
    assert(info_2.release_amount == 2000, 'Token 2 release amount');
}

#[test]
fn test_register_simulation_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 0);

    // Register a simulation
    let simulation_id: felt252 = 123;
    let returned_id = dispatcher.register_simulation(simulation_id, token_id, 1735689600); // 2025-01-01 00:00:00 UTC
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
    dispatcher.register_simulation(123, 999, 1735689600);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_get_simulation() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 0);

    // Register a simulation
    let simulation_id: felt252 = 456;
    let returned_id = dispatcher.register_simulation(simulation_id, token_id, 1735689600);
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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to register simulation as non-owner
    start_cheat_caller_address(dispatcher.contract_address, non_owner);
    dispatcher.register_simulation(456, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Not owner', ))]
fn test_create_token_non_owner_should_fail() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, non_owner);

    // This should fail because non_owner is not the owner
    dispatcher.create_token(1000, 1000, 0);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_time_until_release_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token with release_hour = 12 (noon)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(2, 1000, 0 );

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

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
fn test_pay_for_hint_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver(); // Use mock contract instead of simple address

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);

    // Fast forward time to allow claiming
    start_cheat_block_timestamp_global(86400 * 3); // 3 days later

    // Mint some tokens to the wallet for payment
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // This should mint tokens to wallet
    stop_cheat_caller_address(dispatcher.contract_address);

    // Pay for hint
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_hint(123, 789, 300); // Pay 300 tokens for hint 789
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check hint is marked as paid
    let is_paid = dispatcher.is_hint_paid(789);
    assert(is_paid, 'Hint should be paid');

    // Check payment details
    let payment = dispatcher.get_hint_payment(789);
    assert(payment.hint_id == 789, 'Hint ID should match');
    assert(payment.simulation_id == 123, 'Simulation ID should match');
    assert(payment.payer == wallet, 'Payer should match');
    assert(payment.amount == 300, 'Amount should match');
}

#[test]
#[should_panic(expected: ('Not whitelisted', ))]
fn test_pay_for_hint_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to pay without being whitelisted
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_hint(123, 789, 300);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Insufficient balance', ))]
fn test_pay_for_hint_insufficient_balance() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to pay more than available balance (wallet has 0 tokens)
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_hint(123, 789, 500);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_is_hint_paid_false() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Check unpaid hint
    let is_paid = dispatcher.is_hint_paid(999);
    assert(!is_paid, 'Hint should not be paid');
}

#[test]
fn test_add_to_whitelist_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is whitelisted for simulation 123
    let is_whitelisted = dispatcher.is_whitelisted(token_id, 123, wallet);
    assert(is_whitelisted, 'Should be whitelisted');
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
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);

    // Remove from whitelist
    dispatcher.remove_from_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is not whitelisted for simulation 123
    let is_whitelisted = dispatcher.is_whitelisted(token_id, 123, wallet);
    assert(!is_whitelisted, 'Should not be whitelisted');
}

#[test]
fn test_is_whitelisted_false() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    
    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is not whitelisted for simulation 123
    let is_whitelisted = dispatcher.is_whitelisted(token_id, 123, wallet);
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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0); // release at hour 12, 1000 tokens per day, no special

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);

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
// Test 1: First claim with special_release before release_hour
#[test]
fn test_first_claim_before_release_hour_with_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation at day 0, 00:00
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Set time to day 0, 10:00 (before release_hour 14:00)
    start_cheat_block_timestamp_global(10 * 3600); // 10 hours
    
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // Should only have special_release (500), no normal days yet
    assert(claimable == 500, 'Should have 500 (special only)');
    
    stop_cheat_block_timestamp_global();
}

// Test 2: First claim with special_release after release_hour same day
#[test]
fn test_first_claim_after_release_hour_with_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation at day 0, 00:00
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Set time to day 0, 16:00 (after release_hour 14:00)
    start_cheat_block_timestamp_global(16 * 3600); // 16 hours
    
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // Should have special_release (500) + 1 day (1000) = 1500
    assert(claimable == 1500, 'Should have 1500 (special+1)');
    
    stop_cheat_block_timestamp_global();
}

// Test 3: First claim multiple days later with special_release
#[test]
fn test_first_claim_multiple_days_later_with_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation at day 0, 00:00
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Set time to day 3, 16:00
    start_cheat_block_timestamp_global(3 * 86400 + 16 * 3600);
    
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // Day 0 14:00 released (1000)
    // Day 1 14:00 released (1000)
    // Day 2 14:00 released (1000)
    // Day 3 14:00 released (1000)
    // Special: 500
    // Total: 500 + 4000 = 4500
    assert(claimable == 4500, 'Should have 4500');
    
    stop_cheat_block_timestamp_global();
}

// Test 4: Second claim - no special release
#[test]
fn test_second_claim_no_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver(); // Use mock receiver
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // First claim at day 0, 16:00
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // Claims 500 (special) + 1000 (day 0) = 1500
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Check claimable amount immediately after (should be 0)
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    assert(claimable == 0, 'Should have 0 immediately');
    
    // Move to day 1, 10:00 (before release_hour)
    start_cheat_block_timestamp_global(86400 + 10 * 3600);
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    assert(claimable == 0, 'Should have 0 before 14:00');
    
    // Move to day 1, 15:00 (after release_hour)
    start_cheat_block_timestamp_global(86400 + 15 * 3600);
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    assert(claimable == 1000, 'Should have 1000 (1 day)');
    
    stop_cheat_block_timestamp_global();
}

// Test 5: Accumulated days with second claim
// Test 5: Accumulated days with second claim
#[test]
fn test_accumulated_days_second_claim() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver(); // Use mock receiver
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // First claim at day 1, 20:00
    start_cheat_block_timestamp_global(86400 + 20 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // Claims special + 2 days
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Skip to day 4, 13:00 (before release_hour)
    start_cheat_block_timestamp_global(4 * 86400 + 13 * 3600);
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // Already claimed: day 0 + day 1 (released at day 1 14:00)
    // Available: day 2 + day 3
    // Day 4 not released yet (13:00 < 14:00)
    assert(claimable == 2000, 'Should have 2000 (2 days)');
    
    // Move to day 4, 15:00 (after release_hour)
    start_cheat_block_timestamp_global(4 * 86400 + 15 * 3600);
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // Now day 4 is also released
    assert(claimable == 3000, 'Should have 3000 (3 days)');
    
    stop_cheat_block_timestamp_global();
}

// Test 6: No special release (special_release = 0)
#[test]
fn test_no_special_release() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();
    
    // Create token: release_hour=14, release_amount=1000, special_release=0 (no special)
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Check at day 0, 16:00
    start_cheat_block_timestamp_global(16 * 3600);
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // No special, just 1 day released
    assert(claimable == 1000, 'Should have 1000 (no special)');
    
    stop_cheat_block_timestamp_global();
}

// Test 7: Release hour edge case - exactly at release_hour
#[test]
fn test_exactly_at_release_hour() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Exactly at day 0, 14:00
    start_cheat_block_timestamp_global(14 * 3600);
    let claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);
    // At exactly 14:00, day should be released (>= check)
    assert(claimable == 1500, 'Should have 1500 at 14:00');
    
    stop_cheat_block_timestamp_global();
}
#[test]
#[should_panic(expected: ('Not whitelisted', ))]
fn test_claim_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
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
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation that expires soon
    dispatcher.register_simulation(123, token_id, 1000); // expires at timestamp 1000

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
    // removed token_data creation

    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(6, 1000, 0);
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
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation with future expiration
    let future_timestamp: u64 = 1735689600; // 2025-01-01 00:00:00 UTC
    dispatcher.register_simulation(123, token_id, future_timestamp);
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
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation with past expiration
    let past_timestamp: u64 = 0; // Timestamp 0 is always in the past
    dispatcher.register_simulation(456, token_id, past_timestamp);
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
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    let expiration_timestamp: u64 = 1735689600; // 2025-01-01 00:00:00 UTC
    dispatcher.register_simulation(789, token_id, expiration_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Mock time to exactly the expiration timestamp
    start_cheat_block_timestamp_global(expiration_timestamp);

    // Check that simulation is considered expired (current_time >= expiration_timestamp)
    let is_expired = dispatcher.is_simulation_expired(789);
    assert(is_expired, 'Expired at exact time');

    stop_cheat_block_timestamp_global();
}
// ============= CLAIM TESTS WITH SPECIAL RELEASE =============

// Test 1: First claim with special_release before release_hour - mints only special
#[test]
fn test_claim_first_before_release_hour_only_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation at day 0, 00:00
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim at day 0, 10:00 (before release_hour 14:00)
    start_cheat_block_timestamp_global(10 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify balance: only special (500), no normal days yet
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance == 500, 'Should have 500 tokens');
    
    stop_cheat_block_timestamp_global();
}

// Test 2: First claim with special_release after release_hour - mints special + normal
#[test]
fn test_claim_first_after_release_hour_with_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim at day 0, 16:00 (after release_hour 14:00)
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify balance: special (500) + 1 day (1000) = 1500
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance == 1500, 'Should have 1500 tokens');
    
    stop_cheat_block_timestamp_global();
}

// Test 3: First claim multiple days later with special_release
#[test]
fn test_claim_first_multiple_days_with_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim at day 3, 16:00
    start_cheat_block_timestamp_global(3 * 86400 + 16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify balance: special (500) + 4 days (4000) = 4500
    // Days released: day 0, 1, 2, 3 (all at 14:00)
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance == 4500, 'Should have 4500 tokens');
    
    stop_cheat_block_timestamp_global();
}

// Test 4: Second claim does NOT include special_release
#[test]
fn test_claim_second_no_special() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // First claim at day 0, 16:00
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    let balance_after_first = dispatcher.balance_of(wallet, token_id);
    assert(balance_after_first == 1500, 'First: 1500 tokens');
    
    // Second claim at day 1, 16:00
    start_cheat_block_timestamp_global(86400 + 16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify balance increased by only 1000 (no special in second claim)
    let balance_after_second = dispatcher.balance_of(wallet, token_id);
    assert(balance_after_second == 2500, 'Second: 2500 total');
    
    stop_cheat_block_timestamp_global();
}

// Test 5: Multiple accumulated days in second claim
#[test]
fn test_claim_accumulated_days() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // First claim at day 1, 20:00
    start_cheat_block_timestamp_global(86400 + 20 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // Claims special + 2 days
    stop_cheat_caller_address(dispatcher.contract_address);
    
    let balance_after_first = dispatcher.balance_of(wallet, token_id);
    assert(balance_after_first == 2500, 'First: 2500 (500+2000)');
    
    // Second claim at day 4, 15:00 (skip days 2 and 3)
    start_cheat_block_timestamp_global(4 * 86400 + 15 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // Should claim days 2, 3, 4 = 3000
    stop_cheat_caller_address(dispatcher.contract_address);
    
    let balance_after_second = dispatcher.balance_of(wallet, token_id);
    assert(balance_after_second == 5500, 'Second: 5500 total');
    
    stop_cheat_block_timestamp_global();
}

// Test 6: Claim with NO special_release (special_release = 0)
#[test]
fn test_claim_no_special_release() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token with NO special_release
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 0);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim at day 0, 16:00 (after release_hour)
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify balance: only 1000 (no special)
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance == 1000, 'Should have 1000 (no special)');
    
    stop_cheat_block_timestamp_global();
}

// Test 7: Claim exactly at release_hour
#[test]
fn test_claim_exactly_at_release_hour() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim exactly at day 0, 14:00
    start_cheat_block_timestamp_global(14 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify balance: special (500) + 1 day (1000) = 1500
    // At exactly 14:00, the day should be released (>= check)
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance == 1500, 'Should have 1500 at 14:00');
    
    stop_cheat_block_timestamp_global();
}

// Test 8: Claim before release_hour second time should fail
#[test]
#[should_panic(expected: ('Nothing to claim yet', ))] 
fn test_claim_before_release_hour_second_time_fails() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // First claim at day 0, 16:00
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    
    // Try to claim again on day 1 at 10:00 (before release_hour)
    start_cheat_block_timestamp_global(86400 + 10 * 3600);
    dispatcher.claim(token_id, 123); // Should panic
    
    stop_cheat_caller_address(dispatcher.contract_address);
    stop_cheat_block_timestamp_global();
}

// Test 9: Three consecutive claims
#[test]
fn test_claim_three_consecutive() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim 1: day 0, 16:00
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    let balance1 = dispatcher.balance_of(wallet, token_id);
    assert(balance1 == 1500, 'Claim 1: 1500');
    
    // Claim 2: day 1, 16:00
    start_cheat_block_timestamp_global(86400 + 16 * 3600);
    dispatcher.claim(token_id, 123);
    let balance2 = dispatcher.balance_of(wallet, token_id);
    assert(balance2 == 2500, 'Claim 2: 2500');
    
    // Claim 3: day 2, 16:00
    start_cheat_block_timestamp_global(2 * 86400 + 16 * 3600);
    dispatcher.claim(token_id, 123);
    let balance3 = dispatcher.balance_of(wallet, token_id);
    assert(balance3 == 3500, 'Claim 3: 3500');
    
    stop_cheat_caller_address(dispatcher.contract_address);
    stop_cheat_block_timestamp_global();
}

// ============= VALIDATION TESTS FOR CREATE_TOKEN =============

// Test 1: Should fail with invalid release_hour >= 24
#[test]
#[should_panic(expected: ('Invalid release hour', ))]
fn test_create_token_invalid_release_hour_too_high() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Try to create token with release_hour = 24 (invalid)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_token(24, 1000, 500); // Should panic
    stop_cheat_caller_address(dispatcher.contract_address);
}

// Test 2: Should fail with invalid release_hour = 25
#[test]
#[should_panic(expected: ('Invalid release hour', ))]
fn test_create_token_invalid_release_hour_25() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Try to create token with release_hour = 25 (way too high)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_token(25, 1000, 0); // Should panic
    stop_cheat_caller_address(dispatcher.contract_address);
}

// Test 3: Should succeed with release_hour = 23 (max valid)
#[test]
fn test_create_token_release_hour_23_valid() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Create token with release_hour = 23 (11 PM, valid)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(23, 1000, 500);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify it was created
    let token_info = dispatcher.get_token_info(token_id);
    assert(token_info.release_hour == 23, 'Should be 23');
    assert(token_id == 1, 'Should be token 1');
}

// Test 4: Should succeed with release_hour = 0 (midnight, valid)
#[test]
fn test_create_token_release_hour_0_valid() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Create token with release_hour = 0 (midnight, valid)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(0, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify it was created
    let token_info = dispatcher.get_token_info(token_id);
    assert(token_info.release_hour == 0, 'Should be 0');
}

// Test 5: Should fail with both release_amount and special_release = 0
#[test]
#[should_panic(expected: ('No release amount set', ))]
fn test_create_token_no_release_mechanism() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Try to create token with both amounts = 0
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.create_token(14, 0, 0); // Should panic
    stop_cheat_caller_address(dispatcher.contract_address);
}

// Test 6: Should succeed with release_amount = 0 but special_release > 0
#[test]
fn test_create_token_only_special_release() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Create token with only special_release (no daily release)
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 0, 1000);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify it was created
    let token_info = dispatcher.get_token_info(token_id);
    assert(token_info.release_amount == 0, 'Release amount should be 0');
    assert(token_info.special_release == 1000, 'Special should be 1000');
}

// Test 7: Should succeed with special_release = 0 but release_amount > 0
#[test]
fn test_create_token_only_daily_release() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    
    // Create token with only daily release (no special)
    // removed token_data creation
    
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Verify it was created
    let token_info = dispatcher.get_token_info(token_id);
    assert(token_info.release_amount == 1000, 'Release amount should be 1000');
    assert(token_info.special_release == 0, 'Special should be 0');
}

// Test 8: Claim with token that has only special_release (no daily)
#[test]
fn test_claim_only_special_release_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token with ONLY special_release, no daily release
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 0, 2000);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Claim after several days
    start_cheat_block_timestamp_global(3 * 86400 + 16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // Should only receive special_release (2000), no daily amounts
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance == 2000, 'Should only have special');
    
    stop_cheat_block_timestamp_global();
}

// Test 9: Second claim with only special_release token should fail
#[test]
#[should_panic(expected: ('Nothing to claim', ))] 
fn test_claim_second_time_only_special_token_fails() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();
    
    // Create token with ONLY special_release
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 0, 1000);
    
    // Register simulation
    dispatcher.register_simulation(123, token_id, 1735689600);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
    
    // First claim
    start_cheat_block_timestamp_global(16 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    
    // Try to claim again - should fail (no daily release)
    start_cheat_block_timestamp_global(2 * 86400 + 16 * 3600);
    dispatcher.claim(token_id, 123); // Should panic
    
    stop_cheat_caller_address(dispatcher.contract_address);
    stop_cheat_block_timestamp_global();
}