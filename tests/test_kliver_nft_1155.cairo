// Import structs from the types file
use kliver_on_chain::kliver_1155_types::{
    ClaimableAmountResult, HintPayment, SessionPayment, TokenInfo, WalletMultiTokenSummary,
    WalletTokenSummary,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
    start_cheat_caller_address, stop_cheat_block_timestamp_global, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Mock ERC1155 Receiver contract for testing using OpenZeppelin's component
#[starknet::contract]
mod MockERC1155Receiver {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;

    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent,
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155Receiver Mixin
    #[abi(embed_v0)]
    impl ERC1155ReceiverMixinImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverMixinImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }
}

// Define the interface for testing
#[starknet::interface]
trait IKliverRC1155<TContractState> {
    fn create_token(
        ref self: TContractState, release_hour: u64, release_amount: u256, special_release: u256,
    ) -> u256;
    fn get_token_info(self: @TContractState, token_id: u256) -> TokenInfo;
    fn time_until_release(self: @TContractState, token_id: u256) -> u64;
    fn set_registry_address(ref self: TContractState, new_registry_address: ContractAddress);
    fn get_registry_address(self: @TContractState) -> ContractAddress;
    fn register_simulation(
        ref self: TContractState, simulation_id: felt252, token_id: u256, expiration_timestamp: u64,
    ) -> felt252;
    fn get_simulation(
        self: @TContractState, simulation_id: felt252,
    ) -> kliver_on_chain::kliver_1155_types::Simulation;
    fn is_simulation_expired(self: @TContractState, simulation_id: felt252) -> bool;
    fn update_simulation_expiration(
        ref self: TContractState, simulation_id: felt252, new_expiration_timestamp: u64,
    );
    fn add_to_whitelist(
        ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252,
    );
    fn remove_from_whitelist(
        ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252,
    );
    fn is_whitelisted(
        self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress,
    ) -> bool;
    fn claim(ref self: TContractState, token_id: u256, simulation_id: felt252);
    fn get_claimable_amount(
        self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress,
    ) -> u256;
    fn get_claimable_amounts_batch(
        self: @TContractState,
        token_id: u256,
        simulation_ids: Span<felt252>,
        wallets: Span<ContractAddress>,
    ) -> Array<ClaimableAmountResult>;
    fn get_wallet_token_summary(
        self: @TContractState,
        token_id: u256,
        wallet: ContractAddress,
        simulation_ids: Span<felt252>,
    ) -> WalletTokenSummary;
    fn get_wallet_simulations_summary(
        self: @TContractState, wallet: ContractAddress, simulation_ids: Span<felt252>,
    ) -> WalletMultiTokenSummary;
    fn pay_for_session(
        ref self: TContractState, simulation_id: felt252, session_id: felt252, amount: u256,
    );
    fn is_session_paid(self: @TContractState, session_id: felt252) -> bool;
    fn get_session_payment(self: @TContractState, session_id: felt252) -> SessionPayment;
    fn pay_for_hint(
        ref self: TContractState, simulation_id: felt252, hint_id: felt252, amount: u256,
    );
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

/// Helper function to setup registry for testing
/// This function sets the registry address and returns it
fn setup_registry(dispatcher: IKliverRC1155Dispatcher, owner: ContractAddress) -> ContractAddress {
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.set_registry_address(registry);
    stop_cheat_caller_address(dispatcher.contract_address);
    registry
}

/// Helper function to setup simulation with registry configured
/// Returns: (simulation_id, registry_address)
fn setup_simulation_with_registry(
    dispatcher: IKliverRC1155Dispatcher,
    owner: ContractAddress,
    token_id: u256,
    expiration_timestamp: u64,
) -> (felt252, ContractAddress) {
    // Setup registry
    let registry = setup_registry(dispatcher, owner);

    // Register simulation from registry address
    let simulation_id: felt252 = 'sim_1';
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(simulation_id, token_id, expiration_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);

    (simulation_id, registry)
}

/// Helper function to create a token as owner
/// Returns: token_id
fn create_token_as_owner(
    dispatcher: IKliverRC1155Dispatcher,
    owner: ContractAddress,
    release_hour: u64,
    release_amount: u256,
    special_release: u256,
) -> u256 {
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(release_hour, release_amount, special_release);
    stop_cheat_caller_address(dispatcher.contract_address);
    token_id
}

/// Helper function to register simulation with registry
/// Returns: simulation_id
fn register_simulation_with_registry(
    dispatcher: IKliverRC1155Dispatcher,
    owner: ContractAddress,
    simulation_id: felt252,
    token_id: u256,
    expiration_timestamp: u64,
) -> felt252 {
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(simulation_id, token_id, expiration_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);
    simulation_id
}

/// Helper function to add wallet to whitelist as owner
fn add_to_whitelist_as_owner(
    dispatcher: IKliverRC1155Dispatcher,
    owner: ContractAddress,
    token_id: u256,
    wallet: ContractAddress,
    simulation_id: felt252,
) {
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, simulation_id);
    stop_cheat_caller_address(dispatcher.contract_address);
}

/// Helper function to setup a complete simulation (token + simulation + whitelist)
/// Returns: (token_id, simulation_id)
fn setup_complete_simulation(
    dispatcher: IKliverRC1155Dispatcher,
    owner: ContractAddress,
    wallet: ContractAddress,
    release_hour: u64,
    release_amount: u256,
    special_release: u256,
    simulation_id: felt252,
    expiration_timestamp: u64,
) -> (u256, felt252) {
    // Create token
    let token_id = create_token_as_owner(
        dispatcher, owner, release_hour, release_amount, special_release,
    );

    // Register simulation
    register_simulation_with_registry(
        dispatcher, owner, simulation_id, token_id, expiration_timestamp,
    );

    // Add to whitelist
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, simulation_id);

    (token_id, simulation_id)
}

/// Helper to set timestamp globally
fn set_block_timestamp(timestamp: u64) {
    start_cheat_block_timestamp_global(timestamp);
}

/// Helper to reset timestamp
fn reset_block_timestamp() {
    stop_cheat_block_timestamp_global();
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
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 0);

    // Set registry address
    dispatcher.set_registry_address(registry);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    start_cheat_caller_address(dispatcher.contract_address, registry);
    let simulation_id: felt252 = 123;
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    let returned_id = dispatcher
        .register_simulation(simulation_id, token_id, 1735689600); // 2025-01-01 00:00:00 UTC
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    assert(returned_id == simulation_id, 'Returned ID should match');
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify simulation was registered
    let simulation = dispatcher.get_simulation(simulation_id);
    assert(simulation.simulation_id == simulation_id, 'Simulation ID mismatch');
    assert(simulation.token_id == token_id, 'Token ID mismatch');
    assert(simulation.creator == registry, 'Creator mismatch');
    assert(simulation.expiration_timestamp == 1735689600, 'Expiration timestamp');
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
fn test_register_simulation_invalid_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let registry = setup_registry(dispatcher, owner);

    start_cheat_caller_address(dispatcher.contract_address, registry);

    // Try to register simulation with non-existent token
    // This should panic because the token 999 doesn't exist
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
    stop_cheat_caller_address(dispatcher.contract_address);

    // Setup registry and register a simulation
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    let simulation_id: felt252 = 456;
    let returned_id = dispatcher.register_simulation(simulation_id, token_id, 1735689600);
    assert(returned_id == simulation_id, 'Returned ID should match');
    stop_cheat_caller_address(dispatcher.contract_address);

    // Get simulation info
    let simulation = dispatcher.get_simulation(simulation_id);

    assert(simulation.simulation_id == simulation_id, 'Simulation ID should match');
    assert(simulation.token_id == token_id, 'Token ID should match');
    assert(simulation.creator == registry, 'Creator should match');
    assert(simulation.expiration_timestamp == 1735689600, 'Expiration timestamp match');
}

#[test]
#[should_panic(expected: ('Only registry can call',))]
fn test_register_simulation_non_owner_should_fail() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Setup registry
    setup_registry(dispatcher, owner);

    // Try to register simulation as non-registry
    start_cheat_caller_address(dispatcher.contract_address, non_owner);
    dispatcher.register_simulation(456, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Not owner',))]
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
    let wallet: ContractAddress =
        deploy_mock_receiver(); // Use mock contract instead of simple address

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Setup registry and register a simulation
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Add to whitelist
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

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
#[should_panic(expected: ('Not whitelisted',))]
fn test_pay_for_session_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(2, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to pay without being whitelisted
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_session(123, 456, 500);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_pay_for_session_insufficient_balance() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Add to whitelist
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    let wallet: ContractAddress =
        deploy_mock_receiver(); // Use mock contract instead of simple address

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Add to whitelist
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

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
#[should_panic(expected: ('Not whitelisted',))]
fn test_pay_for_hint_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to pay without being whitelisted
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.pay_for_hint(123, 789, 300);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_pay_for_hint_insufficient_balance() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Add to whitelist
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation from registry
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add to whitelist
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Check that wallet is whitelisted for simulation 123
    let is_whitelisted = dispatcher.is_whitelisted(token_id, 123, wallet);
    assert(is_whitelisted, 'Should be whitelisted');
}

#[test]
#[should_panic(expected: ('Token does not exist',))]
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
#[should_panic(expected: ('Simulation not for this token',))]
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
#[should_panic(expected: ('Not owner',))]
fn test_add_to_whitelist_non_owner() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    let token_id = dispatcher
        .create_token(12, 1000, 0); // release at hour 12, 1000 tokens per day, no special

    // Register a simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
#[should_panic(expected: ('Not whitelisted',))]
fn test_claim_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to claim without being whitelisted
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Simulation has expired',))]
fn test_claim_expired_simulation() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create a token first
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);

    // Register a simulation that expires soon
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1000); // expires at timestamp 1000
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

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
#[should_panic(expected: ('Token does not exist',))]
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, future_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 0);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Register a simulation with past expiration using helper
    let past_timestamp: u64 = 0; // Timestamp 0 is always in the past
    let (simulation_id, _) = setup_simulation_with_registry(
        dispatcher, owner, token_id, past_timestamp,
    );

    // Check that simulation is expired
    let is_expired = dispatcher.is_simulation_expired(simulation_id);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(789, token_id, expiration_timestamp);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
#[should_panic(expected: ('Nothing to claim yet',))]
fn test_claim_before_release_hour_second_time_fails() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();

    // Create token: release_hour=14, release_amount=1000, special_release=500
    // removed token_data creation
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500);

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
#[should_panic(expected: ('Invalid release hour',))]
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
#[should_panic(expected: ('Invalid release hour',))]
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
#[should_panic(expected: ('No release amount set',))]
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
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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
#[should_panic(expected: ('Nothing to claim',))]
fn test_claim_second_time_only_special_token_fails() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();

    // Create token with ONLY special_release
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 0, 1000);

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
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

// ==================== WALLET TOKEN SUMMARY TESTS ====================

#[test]
fn test_get_wallet_token_summary_debug() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 2 days
    start_cheat_block_timestamp_global(86400 * 2 + 13 * 3600);

    // First check with individual method
    let individual_amount = dispatcher.get_claimable_amount(token_id, 123, wallet);

    // Query summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let summary = dispatcher.get_wallet_token_summary(token_id, wallet, simulation_ids.span());

    // Verify they match
    assert(summary.simulations_data.len() == 1, 'Should have 1 simulation');
    let sim_data = summary.simulations_data.at(0);
    assert(sim_data.claimable_amount == @individual_amount, 'Should match individual');
    assert(summary.total_claimable == individual_amount, 'Total should match');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_wallet_token_summary_basic() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500); // 12h, 1000/day, 500 special

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 2 days
    start_cheat_block_timestamp_global(86400 * 2 + 13 * 3600);

    // Get expected amount
    let expected_amount = dispatcher.get_claimable_amount(token_id, 123, wallet);

    // Query summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let summary = dispatcher.get_wallet_token_summary(token_id, wallet, simulation_ids.span());

    // Verify summary
    assert(summary.token_id == token_id, 'Wrong token_id');
    assert(summary.wallet == wallet, 'Wrong wallet');
    assert(summary.current_balance == 0, 'Balance should be 0');
    assert(summary.token_info.release_hour == 12, 'Wrong release_hour');
    assert(summary.token_info.release_amount == 1000, 'Wrong release_amount');
    assert(summary.token_info.special_release == 500, 'Wrong special_release');
    assert(summary.total_claimable == expected_amount, 'Wrong total_claimable');
    assert(summary.simulations_data.len() == 1, 'Should have 1 simulation');

    let sim_data = summary.simulations_data.at(0);
    assert(*sim_data.simulation_id == 123, 'Wrong simulation_id');
    assert(sim_data.claimable_amount == @expected_amount, 'Wrong claimable_amount');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_wallet_token_summary_multiple_simulations() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 300); // 14h, 1000/day, 300 special

    // Register 3 simulations
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(111, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(222, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(333, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add to whitelist for all 3
    dispatcher.add_to_whitelist(token_id, wallet, 111);
    dispatcher.add_to_whitelist(token_id, wallet, 222);
    dispatcher.add_to_whitelist(token_id, wallet, 333);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 3 days
    start_cheat_block_timestamp_global(86400 * 3 + 15 * 3600);

    // Get expected amounts
    let amount1 = dispatcher.get_claimable_amount(token_id, 111, wallet);
    let amount2 = dispatcher.get_claimable_amount(token_id, 222, wallet);
    let amount3 = dispatcher.get_claimable_amount(token_id, 333, wallet);
    let expected_total = amount1 + amount2 + amount3;

    // Query summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(111);
    simulation_ids.append(222);
    simulation_ids.append(333);

    let summary = dispatcher.get_wallet_token_summary(token_id, wallet, simulation_ids.span());

    assert(summary.total_claimable == expected_total, 'Wrong total_claimable');
    assert(summary.simulations_data.len() == 3, 'Should have 3 simulations');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_wallet_token_summary_filters_expired() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);

    // Register 2 simulations - one expires soon
    let current_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(111, token_id, current_time + 86400); // Expires in 1 day
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(222, token_id, current_time + 86400 * 10); // Expires in 10 days
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    dispatcher.add_to_whitelist(token_id, wallet, 111);
    dispatcher.add_to_whitelist(token_id, wallet, 222);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 2 days (111 is now expired)
    start_cheat_block_timestamp_global(current_time + 86400 * 2);

    // Query summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(111); // Expired
    simulation_ids.append(222); // Active

    let summary = dispatcher.get_wallet_token_summary(token_id, wallet, simulation_ids.span());

    // Should only include simulation 222
    assert(summary.simulations_data.len() == 1, 'Should have 1 simulation');
    let sim_data = summary.simulations_data.at(0);
    assert(*sim_data.simulation_id == 222, 'Should be sim 222');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_wallet_token_summary_filters_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);

    // Register 3 simulations but only whitelist for 2
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(111, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(222, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(333, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    dispatcher.add_to_whitelist(token_id, wallet, 111);
    // NOT whitelisted for 222
    dispatcher.add_to_whitelist(token_id, wallet, 333);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_block_timestamp_global(86400 * 2);

    // Query summary with all 3
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(111);
    simulation_ids.append(222); // Not whitelisted
    simulation_ids.append(333);

    let summary = dispatcher.get_wallet_token_summary(token_id, wallet, simulation_ids.span());

    // Should only include 111 and 333
    assert(summary.simulations_data.len() == 2, 'Should have 2 simulations');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_wallet_token_summary_with_balance() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet = deploy_mock_receiver();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);

    // Register simulation and whitelist
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward and claim
    start_cheat_block_timestamp_global(86400 * 2 + 13 * 3600);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123); // Claims 2500
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward more
    start_cheat_block_timestamp_global(86400 * 5 + 13 * 3600);

    // Get expected values
    let expected_balance = dispatcher.balance_of(wallet, token_id);
    let expected_claimable = dispatcher.get_claimable_amount(token_id, 123, wallet);

    // Query summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let summary = dispatcher.get_wallet_token_summary(token_id, wallet, simulation_ids.span());

    // Should have balance from previous claim
    assert(summary.current_balance == expected_balance, 'Wrong balance');
    // Should have new days claimable
    assert(summary.total_claimable == expected_claimable, 'Wrong total_claimable');

    stop_cheat_block_timestamp_global();
}

// ==================== BATCH GET CLAIMABLE AMOUNTS TESTS ====================

#[test]
fn test_get_claimable_amounts_batch_debug() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500); // 12h, 1000/day, 500 special

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 2 days
    start_cheat_block_timestamp_global(86400 * 2 + 13 * 3600); // 2 days + 13h

    // First test individual method
    let individual_amount = dispatcher.get_claimable_amount(token_id, 123, wallet);

    // Then test batch method
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let mut wallets = ArrayTrait::new();
    wallets.append(wallet);

    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    assert(results.len() == 1, 'Should have 1 result');

    let result = results.at(0);
    assert(*result.simulation_id == 123, 'Wrong sim_id');
    assert(*result.wallet == wallet, 'Wrong wallet');
    assert(*result.amount == individual_amount, 'Amount should match individual');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_claimable_amounts_batch_single_simulation_multiple_wallets() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    let wallet1: ContractAddress = 'wallet1'.try_into().unwrap();
    let wallet2: ContractAddress = 'wallet2'.try_into().unwrap();
    let wallet3: ContractAddress = 'wallet3'.try_into().unwrap();

    // Create token with special release
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500); // 12h, 1000/day, 500 special

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add all wallets to whitelist
    dispatcher.add_to_whitelist(token_id, wallet1, 123);
    dispatcher.add_to_whitelist(token_id, wallet2, 123);
    dispatcher.add_to_whitelist(token_id, wallet3, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 2 days
    start_cheat_block_timestamp_global(86400 * 2 + 13 * 3600); // 2 days + 13h

    // First check individual amounts to see what they should be
    let individual1 = dispatcher.get_claimable_amount(token_id, 123, wallet1);
    let individual2 = dispatcher.get_claimable_amount(token_id, 123, wallet2);
    let individual3 = dispatcher.get_claimable_amount(token_id, 123, wallet3);

    // Prepare batch query
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let mut wallets = ArrayTrait::new();
    wallets.append(wallet1);
    wallets.append(wallet2);
    wallets.append(wallet3);

    // Execute batch query
    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    // Verify results
    assert(results.len() == 3, 'Should have 3 results');

    // All should match individual calculations
    let result1 = results.at(0);
    assert(*result1.simulation_id == 123, 'Result1: wrong sim_id');
    assert(*result1.wallet == wallet1, 'Result1: wrong wallet');
    assert(result1.amount == @individual1, 'Result1: should match');

    let result2 = results.at(1);
    assert(*result2.simulation_id == 123, 'Result2: wrong sim_id');
    assert(*result2.wallet == wallet2, 'Result2: wrong wallet');
    assert(result2.amount == @individual2, 'Result2: should match');

    let result3 = results.at(2);
    assert(*result3.simulation_id == 123, 'Result3: wrong sim_id');
    assert(*result3.wallet == wallet3, 'Result3: wrong wallet');
    assert(result3.amount == @individual3, 'Result3: should match');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_claimable_amounts_batch_multiple_simulations_single_wallet() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 300); // 14h, 1000/day, 300 special

    // Register multiple simulations
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(111, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(222, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(333, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add wallet to all simulations
    dispatcher.add_to_whitelist(token_id, wallet, 111);
    dispatcher.add_to_whitelist(token_id, wallet, 222);
    dispatcher.add_to_whitelist(token_id, wallet, 333);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 3 days
    start_cheat_block_timestamp_global(86400 * 3 + 15 * 3600); // 3 days + 15h

    // Check individual amounts first
    let individual1 = dispatcher.get_claimable_amount(token_id, 111, wallet);
    let individual2 = dispatcher.get_claimable_amount(token_id, 222, wallet);
    let individual3 = dispatcher.get_claimable_amount(token_id, 333, wallet);

    // Prepare batch query
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(111);
    simulation_ids.append(222);
    simulation_ids.append(333);

    let mut wallets = ArrayTrait::new();
    wallets.append(wallet);

    // Execute batch query
    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    // Verify results
    assert(results.len() == 3, 'Should have 3 results');

    // All should match individual calculations
    let result1 = results.at(0);
    assert(*result1.simulation_id == 111, 'Result1: wrong sim_id');
    assert(*result1.wallet == wallet, 'Result1: wrong wallet');
    assert(result1.amount == @individual1, 'Result1: should match');

    let result2 = results.at(1);
    assert(*result2.simulation_id == 222, 'Result2: wrong sim_id');
    assert(*result2.wallet == wallet, 'Result2: wrong wallet');
    assert(result2.amount == @individual2, 'Result2: should match');

    let result3 = results.at(2);
    assert(*result3.simulation_id == 333, 'Result3: wrong sim_id');
    assert(*result3.wallet == wallet, 'Result3: wrong wallet');
    assert(result3.amount == @individual3, 'Result3: should match');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_claimable_amounts_batch_multiple_simulations_multiple_wallets() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    let wallet1: ContractAddress = 'wallet1'.try_into().unwrap();
    let wallet2: ContractAddress = 'wallet2'.try_into().unwrap();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(10, 500, 200); // 10h, 500/day, 200 special

    // Register simulations
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(100, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(200, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add wallets to simulations
    dispatcher.add_to_whitelist(token_id, wallet1, 100);
    dispatcher.add_to_whitelist(token_id, wallet1, 200);
    dispatcher.add_to_whitelist(token_id, wallet2, 100);
    dispatcher.add_to_whitelist(token_id, wallet2, 200);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 1 day
    start_cheat_block_timestamp_global(86400 + 11 * 3600); // 1 day + 11h

    // Check individual amounts first
    let individual_sim100_w1 = dispatcher.get_claimable_amount(token_id, 100, wallet1);
    let individual_sim100_w2 = dispatcher.get_claimable_amount(token_id, 100, wallet2);
    let individual_sim200_w1 = dispatcher.get_claimable_amount(token_id, 200, wallet1);
    let individual_sim200_w2 = dispatcher.get_claimable_amount(token_id, 200, wallet2);

    // Prepare batch query
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(100);
    simulation_ids.append(200);

    let mut wallets = ArrayTrait::new();
    wallets.append(wallet1);
    wallets.append(wallet2);

    // Execute batch query
    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    // Verify results - should have 2 simulations × 2 wallets = 4 results
    assert(results.len() == 4, 'Should have 4 results');

    // Result 0: sim 100, wallet1
    let result0 = results.at(0);
    assert(*result0.simulation_id == 100, 'Result0: wrong sim_id');
    assert(*result0.wallet == wallet1, 'Result0: wrong wallet');
    assert(result0.amount == @individual_sim100_w1, 'Result0: should match');

    // Result 1: sim 100, wallet2
    let result1 = results.at(1);
    assert(*result1.simulation_id == 100, 'Result1: wrong sim_id');
    assert(*result1.wallet == wallet2, 'Result1: wrong wallet');
    assert(result1.amount == @individual_sim100_w2, 'Result1: should match');

    // Result 2: sim 200, wallet1
    let result2 = results.at(2);
    assert(*result2.simulation_id == 200, 'Result2: wrong sim_id');
    assert(*result2.wallet == wallet1, 'Result2: wrong wallet');
    assert(result2.amount == @individual_sim200_w1, 'Result2: should match');

    // Result 3: sim 200, wallet2
    let result3 = results.at(3);
    assert(*result3.simulation_id == 200, 'Result3: wrong sim_id');
    assert(*result3.wallet == wallet2, 'Result3: wrong wallet');
    assert(result3.amount == @individual_sim200_w2, 'Result3: should match');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_claimable_amounts_batch_after_some_claims() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    let wallet1 = deploy_mock_receiver();
    let wallet2 = deploy_mock_receiver();

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500); // 12h, 1000/day, 500 special

    // Register simulation
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add wallets
    dispatcher.add_to_whitelist(token_id, wallet1, 123);
    dispatcher.add_to_whitelist(token_id, wallet2, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward 2 days
    start_cheat_block_timestamp_global(86400 * 2 + 13 * 3600); // 2 days + 13h

    // Wallet1 claims
    start_cheat_caller_address(dispatcher.contract_address, wallet1);
    dispatcher.claim(token_id, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward to 5 days total
    start_cheat_block_timestamp_global(86400 * 5 + 13 * 3600); // 5 days + 13h

    // Check individual amounts
    let individual1 = dispatcher.get_claimable_amount(token_id, 123, wallet1);
    let individual2 = dispatcher.get_claimable_amount(token_id, 123, wallet2);

    // Now check batch
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let mut wallets = ArrayTrait::new();
    wallets.append(wallet1);
    wallets.append(wallet2);

    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    assert(results.len() == 2, 'Should have 2 results');

    // Wallet1: Already claimed at day 2, now at day 5
    let result1 = results.at(0);
    assert(*result1.simulation_id == 123, 'Result1: wrong sim_id');
    assert(*result1.wallet == wallet1, 'Result1: wrong wallet');
    assert(result1.amount == @individual1, 'Result1: should match');

    // Wallet2: Never claimed
    let result2 = results.at(1);
    assert(*result2.simulation_id == 123, 'Result2: wrong sim_id');
    assert(*result2.wallet == wallet2, 'Result2: wrong wallet');
    assert(result2.amount == @individual2, 'Result2: should match');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_get_claimable_amounts_batch_empty_arrays() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Query with empty arrays
    let simulation_ids = ArrayTrait::new();
    let wallets = ArrayTrait::new();

    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    // Should return empty array
    assert(results.len() == 0, 'Should have 0 results');
}

#[test]
fn test_get_claimable_amounts_batch_before_release_hour() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    let wallet1: ContractAddress = 'wallet1'.try_into().unwrap();
    let wallet2: ContractAddress = 'wallet2'.try_into().unwrap();

    // Create token with release at 14h
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(14, 1000, 500); // 14h, 1000/day, 500 special

    // Register simulation at day 0, 00:00
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, 1735689600);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Add wallets
    dispatcher.add_to_whitelist(token_id, wallet1, 123);
    dispatcher.add_to_whitelist(token_id, wallet2, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Set time to day 0, 10:00 (before release_hour 14:00)
    start_cheat_block_timestamp_global(10 * 3600); // 10 hours

    // Prepare batch query
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(123);

    let mut wallets = ArrayTrait::new();
    wallets.append(wallet1);
    wallets.append(wallet2);

    // Execute batch query
    let results = dispatcher
        .get_claimable_amounts_batch(token_id, simulation_ids.span(), wallets.span());

    // Verify results - should only have special_release
    assert(results.len() == 2, 'Should have 2 results');

    let result1 = results.at(0);
    assert(*result1.amount == 500, 'Result1: should be 500');

    let result2 = results.at(1);
    assert(*result2.amount == 500, 'Result2: should be 500');

    stop_cheat_block_timestamp_global();
}

// ==================== UPDATE SIMULATION EXPIRATION TESTS ====================

#[test]
fn test_update_simulation_expiration_success() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    // Create token
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);

    // Register simulation with expiration in 10 days
    let current_time = starknet::get_block_timestamp();
    let initial_expiration = current_time + (86400 * 10);
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, initial_expiration);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Verify initial expiration
    let simulation = dispatcher.get_simulation(123);
    assert(simulation.expiration_timestamp == initial_expiration, 'Wrong initial expiration');

    // Update expiration to 30 days from now
    let new_expiration = current_time + (86400 * 30);
    dispatcher.update_simulation_expiration(123, new_expiration);

    // Verify expiration was updated
    let updated_simulation = dispatcher.get_simulation(123);
    assert(updated_simulation.expiration_timestamp == new_expiration, 'Expiration not updated');
    assert(updated_simulation.simulation_id == 123, 'Simulation ID changed');
    assert(updated_simulation.token_id == token_id, 'Token ID changed');

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Simulation does not exist',))]
fn test_update_simulation_expiration_nonexistent() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Try to update non-existent simulation
    let current_time = starknet::get_block_timestamp();
    let new_expiration = current_time + 86400;
    dispatcher.update_simulation_expiration(999, new_expiration);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Not owner',))]
fn test_update_simulation_expiration_not_owner() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let non_owner: ContractAddress = 'non_owner'.try_into().unwrap();

    // Create token and simulation as owner
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);
    let current_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, current_time + 86400);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Try to update as non-owner
    start_cheat_caller_address(dispatcher.contract_address, non_owner);
    dispatcher.update_simulation_expiration(123, current_time + (86400 * 2));
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Expiration must be future',))]
fn test_update_simulation_expiration_past_timestamp() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create token and simulation
    let token_id = dispatcher.create_token(12, 1000, 500);
    let current_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, current_time + 86400);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Fast forward time
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_block_timestamp_global(current_time + 1000);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Try to update with timestamp in the past (before current time)
    dispatcher.update_simulation_expiration(123, current_time + 500);

    stop_cheat_caller_address(dispatcher.contract_address);
    stop_cheat_block_timestamp_global();
}

#[test]
#[should_panic(expected: ('Expiration must be future',))]
fn test_update_simulation_expiration_current_timestamp() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create token and simulation
    let token_id = dispatcher.create_token(12, 1000, 500);
    let current_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, current_time + 86400);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Try to update with current timestamp (not future)
    dispatcher.update_simulation_expiration(123, current_time);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_update_simulation_expiration_extend_expired() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create token and simulation that expires soon
    let token_id = dispatcher.create_token(12, 1000, 500);
    let initial_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, initial_time + 100); // Expires in 100 seconds
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward time so simulation is expired
    start_cheat_block_timestamp_global(initial_time + 200);

    // Verify simulation is expired
    let is_expired = dispatcher.is_simulation_expired(123);
    assert(is_expired, 'Should be expired');

    // Owner extends expiration
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let new_expiration = initial_time + 86400; // Extend to 1 day
    dispatcher.update_simulation_expiration(123, new_expiration);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify simulation is no longer expired
    let is_still_expired = dispatcher.is_simulation_expired(123);
    assert(!is_still_expired, 'Should not be expired');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_update_simulation_expiration_multiple_times() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);

    start_cheat_caller_address(dispatcher.contract_address, owner);

    // Create token and simulation
    let token_id = dispatcher.create_token(12, 1000, 500);
    let current_time = starknet::get_block_timestamp();
    let initial_expiration = current_time + 86400;
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, initial_expiration);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // First update
    let expiration_1 = current_time + (86400 * 5);
    dispatcher.update_simulation_expiration(123, expiration_1);
    let sim_1 = dispatcher.get_simulation(123);
    assert(sim_1.expiration_timestamp == expiration_1, 'First update failed');

    // Second update
    let expiration_2 = current_time + (86400 * 10);
    dispatcher.update_simulation_expiration(123, expiration_2);
    let sim_2 = dispatcher.get_simulation(123);
    assert(sim_2.expiration_timestamp == expiration_2, 'Second update failed');

    // Third update
    let expiration_3 = current_time + (86400 * 20);
    dispatcher.update_simulation_expiration(123, expiration_3);
    let sim_3 = dispatcher.get_simulation(123);
    assert(sim_3.expiration_timestamp == expiration_3, 'Third update failed');

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_update_simulation_expiration_does_not_affect_claims() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet = deploy_mock_receiver();

    // Create token and simulation with long expiration
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);
    let current_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, current_time + (86400 * 5)); // 5 days expiration
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward and claim
    start_cheat_block_timestamp_global(current_time + (86400 / 2) + 13 * 3600); // Half day + 13h
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    let balance_before = dispatcher.balance_of(wallet, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Update expiration to even longer
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.update_simulation_expiration(123, current_time + (86400 * 10));
    stop_cheat_caller_address(dispatcher.contract_address);

    // Claim again after update
    start_cheat_block_timestamp_global(current_time + 86400 + 13 * 3600); // 1 day + 13h
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    let balance_after = dispatcher.balance_of(wallet, token_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify claims still work normally
    assert(balance_after > balance_before, 'Claim should have worked');

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_update_simulation_expiration_allows_future_claims() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet = deploy_mock_receiver();

    // Create token and simulation with short expiration
    start_cheat_caller_address(dispatcher.contract_address, owner);
    let token_id = dispatcher.create_token(12, 1000, 500);
    let current_time = starknet::get_block_timestamp();
    stop_cheat_caller_address(dispatcher.contract_address);
    let registry = setup_registry(dispatcher, owner);
    start_cheat_caller_address(dispatcher.contract_address, registry);
    dispatcher.register_simulation(123, token_id, current_time + 100);
    stop_cheat_caller_address(dispatcher.contract_address);
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.add_to_whitelist(token_id, wallet, 123);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Fast forward past expiration
    start_cheat_block_timestamp_global(current_time + 200);

    // Verify can't claim (expired)
    let is_expired = dispatcher.is_simulation_expired(123);
    assert(is_expired, 'Should be expired');

    // Owner extends expiration
    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.update_simulation_expiration(123, current_time + 86400);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Now claim should work
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, 123);
    let balance = dispatcher.balance_of(wallet, token_id);
    assert(balance > 0, 'Should have claimed tokens');
    stop_cheat_caller_address(dispatcher.contract_address);

    stop_cheat_block_timestamp_global();
}

// ==================== GET WALLET SIMULATIONS SUMMARY TESTS ====================

#[test]
fn test_get_wallet_simulations_summary_single_token() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create one token
    let token_id = create_token_as_owner(dispatcher, owner, 12, 1000, 500);

    // Create two simulations for the same token
    let sim_1 = register_simulation_with_registry(dispatcher, owner, 'sim_1', token_id, 1735689600);
    let sim_2 = register_simulation_with_registry(dispatcher, owner, 'sim_2', token_id, 1735689600);

    // Add wallet to whitelist for both simulations
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_1);
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_2);

    // Advance time
    set_block_timestamp(86400); // 1 day later

    // Call get_wallet_simulations_summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);
    simulation_ids.append(sim_2);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    // Should have 1 summary (1 token)
    assert(result.summaries.len() == 1, 'Should have 1 summary');

    let summary = result.summaries.at(0);
    assert(*summary.token_id == token_id, 'Token ID should match');
    assert(*summary.wallet == wallet, 'Wallet should match');
    assert(summary.simulations_data.len() == 2, 'Should have 2 simulations');
    assert(*summary.total_claimable > 0, 'Should have claimable');

    reset_block_timestamp();
}

#[test]
fn test_get_wallet_simulations_summary_multiple_tokens() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create two different tokens
    let token_id_1 = create_token_as_owner(dispatcher, owner, 12, 1000, 500);
    let token_id_2 = create_token_as_owner(dispatcher, owner, 14, 2000, 0);

    // Create simulations for different tokens
    let sim_1 = register_simulation_with_registry(
        dispatcher, owner, 'sim_1', token_id_1, 1735689600,
    );
    let sim_2 = register_simulation_with_registry(
        dispatcher, owner, 'sim_2', token_id_1, 1735689600,
    );
    let sim_3 = register_simulation_with_registry(
        dispatcher, owner, 'sim_3', token_id_2, 1735689600,
    );
    let sim_4 = register_simulation_with_registry(
        dispatcher, owner, 'sim_4', token_id_2, 1735689600,
    );

    // Add wallet to whitelist
    add_to_whitelist_as_owner(dispatcher, owner, token_id_1, wallet, sim_1);
    add_to_whitelist_as_owner(dispatcher, owner, token_id_1, wallet, sim_2);
    add_to_whitelist_as_owner(dispatcher, owner, token_id_2, wallet, sim_3);
    add_to_whitelist_as_owner(dispatcher, owner, token_id_2, wallet, sim_4);

    // Advance time
    set_block_timestamp(86400 * 2); // 2 days later

    // Call get_wallet_simulations_summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);
    simulation_ids.append(sim_2);
    simulation_ids.append(sim_3);
    simulation_ids.append(sim_4);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    // Should have 2 summaries (2 tokens)
    assert(result.summaries.len() == 2, 'Should have 2 summaries');

    // Verify first summary
    let summary_1 = result.summaries.at(0);
    assert(*summary_1.token_id == token_id_1, 'Token 1 ID should match');
    assert(summary_1.simulations_data.len() == 2, 'Token 1: 2 simulations');

    // Verify second summary
    let summary_2 = result.summaries.at(1);
    assert(*summary_2.token_id == token_id_2, 'Token 2 ID should match');
    assert(summary_2.simulations_data.len() == 2, 'Token 2: 2 simulations');

    reset_block_timestamp();
}

#[test]
fn test_get_wallet_simulations_summary_filters_not_whitelisted() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    let token_id = create_token_as_owner(dispatcher, owner, 12, 1000, 500);

    // Create three simulations
    let sim_1 = register_simulation_with_registry(dispatcher, owner, 'sim_1', token_id, 1735689600);
    let sim_2 = register_simulation_with_registry(dispatcher, owner, 'sim_2', token_id, 1735689600);
    let sim_3 = register_simulation_with_registry(dispatcher, owner, 'sim_3', token_id, 1735689600);

    // Only add wallet to whitelist for sim_1 and sim_3 (not sim_2)
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_1);
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_3);

    // Advance time
    set_block_timestamp(86400);

    // Call get_wallet_simulations_summary with all 3 simulations
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);
    simulation_ids.append(sim_2); // Not whitelisted
    simulation_ids.append(sim_3);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    // Should have 1 summary with only 2 simulations (sim_2 filtered out)
    assert(result.summaries.len() == 1, 'Should have 1 summary');

    let summary = result.summaries.at(0);
    assert(summary.simulations_data.len() == 2, 'Should have 2 simulations');

    reset_block_timestamp();
}

#[test]
fn test_get_wallet_simulations_summary_filters_expired() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token
    let token_id = create_token_as_owner(dispatcher, owner, 12, 1000, 500);

    // Create simulations with different expiration times
    let sim_1 = register_simulation_with_registry(
        dispatcher, owner, 'sim_1', token_id, 1735689600,
    ); // Future
    let sim_2 = register_simulation_with_registry(
        dispatcher, owner, 'sim_2', token_id, 1000,
    ); // Past

    // Add wallet to whitelist for both
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_1);
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_2);

    // Advance time past sim_2 expiration
    set_block_timestamp(2000);

    // Call get_wallet_simulations_summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);
    simulation_ids.append(sim_2);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    // Should have 1 summary with only 1 simulation (sim_2 expired)
    assert(result.summaries.len() == 1, 'Should have 1 summary');

    let summary = result.summaries.at(0);
    assert(summary.simulations_data.len() == 1, 'Should have 1 simulation');

    // Verify it's sim_1 (not expired)
    let sim_data = summary.simulations_data.at(0);
    assert(*sim_data.simulation_id == sim_1, 'Should be sim_1');

    reset_block_timestamp();
}

#[test]
fn test_get_wallet_simulations_summary_empty_array() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Call with empty array
    let simulation_ids = ArrayTrait::new();
    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    // Should return empty array
    assert(result.summaries.len() == 0, 'Should have 0 summaries');
}

#[test]
fn test_get_wallet_simulations_summary_with_balance() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = deploy_mock_receiver();

    // Create token
    let token_id = create_token_as_owner(dispatcher, owner, 12, 1000, 500);

    // Create simulation
    let sim_1 = register_simulation_with_registry(dispatcher, owner, 'sim_1', token_id, 1735689600);

    // Add wallet to whitelist
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_1);

    // Advance time and claim some tokens
    set_block_timestamp(86400);
    start_cheat_caller_address(dispatcher.contract_address, wallet);
    dispatcher.claim(token_id, sim_1);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Advance time more for additional claimable
    set_block_timestamp(86400 * 2);

    // Call get_wallet_simulations_summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    assert(result.summaries.len() == 1, 'Should have 1 summary');

    let summary = result.summaries.at(0);
    assert(*summary.current_balance > 0, 'Should have balance');
    assert(*summary.total_claimable > 0, 'Should have more claimable');

    reset_block_timestamp();
}

#[test]
fn test_get_wallet_simulations_summary_three_tokens() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create three different tokens
    let token_id_1 = create_token_as_owner(dispatcher, owner, 10, 1000, 100);
    let token_id_2 = create_token_as_owner(dispatcher, owner, 12, 2000, 200);
    let token_id_3 = create_token_as_owner(dispatcher, owner, 14, 3000, 300);

    // Create simulations across different tokens
    let sim_1 = register_simulation_with_registry(
        dispatcher, owner, 'sim_1', token_id_1, 1735689600,
    );
    let sim_2 = register_simulation_with_registry(
        dispatcher, owner, 'sim_2', token_id_2, 1735689600,
    );
    let sim_3 = register_simulation_with_registry(
        dispatcher, owner, 'sim_3', token_id_2, 1735689600,
    );
    let sim_4 = register_simulation_with_registry(
        dispatcher, owner, 'sim_4', token_id_3, 1735689600,
    );

    // Add wallet to whitelist
    add_to_whitelist_as_owner(dispatcher, owner, token_id_1, wallet, sim_1);
    add_to_whitelist_as_owner(dispatcher, owner, token_id_2, wallet, sim_2);
    add_to_whitelist_as_owner(dispatcher, owner, token_id_2, wallet, sim_3);
    add_to_whitelist_as_owner(dispatcher, owner, token_id_3, wallet, sim_4);

    // Advance time
    set_block_timestamp(86400);

    // Call get_wallet_simulations_summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);
    simulation_ids.append(sim_2);
    simulation_ids.append(sim_3);
    simulation_ids.append(sim_4);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    // Should have 3 summaries (3 tokens)
    assert(result.summaries.len() == 3, 'Should have 3 summaries');

    // Verify distribution
    let summary_1 = result.summaries.at(0);
    assert(summary_1.simulations_data.len() == 1, 'Token 1: 1 simulation');

    let summary_2 = result.summaries.at(1);
    assert(summary_2.simulations_data.len() == 2, 'Token 2: 2 simulations');

    let summary_3 = result.summaries.at(2);
    assert(summary_3.simulations_data.len() == 1, 'Token 3: 1 simulation');

    reset_block_timestamp();
}

#[test]
fn test_get_wallet_simulations_summary_calculates_total_claimable() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_contract(owner);
    let wallet: ContractAddress = 'wallet'.try_into().unwrap();

    // Create token: release_amount=1000, special_release=500
    let token_id = create_token_as_owner(dispatcher, owner, 12, 1000, 500);

    // Create two simulations
    let sim_1 = register_simulation_with_registry(dispatcher, owner, 'sim_1', token_id, 1735689600);
    let sim_2 = register_simulation_with_registry(dispatcher, owner, 'sim_2', token_id, 1735689600);

    // Add wallet to whitelist
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_1);
    add_to_whitelist_as_owner(dispatcher, owner, token_id, wallet, sim_2);

    // Advance time (1 day after creation)
    set_block_timestamp(86400 + 13 * 3600); // Day 1, 13:00 (after release_hour 12)

    // Call get_wallet_simulations_summary
    let mut simulation_ids = ArrayTrait::new();
    simulation_ids.append(sim_1);
    simulation_ids.append(sim_2);

    let result = dispatcher.get_wallet_simulations_summary(wallet, simulation_ids.span());

    assert(result.summaries.len() == 1, 'Should have 1 summary');

    let summary = result.summaries.at(0);
    // Timestamp: Day 1, 13:00 (after release_hour 12)
    // Creation: Day 0, 00:00 (midnight, normalized)
    // Claimable days: 2 (Day 0 complete + Day 1 because 13:00 >= 12:00)
    // Each simulation: special (500) + 2 days (2000) = 2500
    // Total for both: 2500 * 2 = 5000
    assert(*summary.total_claimable == 5000, 'Total should be 5000');

    reset_block_timestamp();
}
