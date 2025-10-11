use kliver_on_chain::sessions_marketplace::SessionsMarketplace::{
    IMarketplaceDispatcher, IMarketplaceDispatcherTrait, ListingStatus, OrderStatus,
};
use kliver_on_chain::mocks::mock_erc20::MockERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use kliver_on_chain::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait};
use kliver_on_chain::components::session_registry_component::SessionMetadata;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use starknet::ContractAddress;

fn SELLER() -> ContractAddress { 'seller'.try_into().unwrap() }
fn BUYER() -> ContractAddress { 'buyer'.try_into().unwrap() }

fn deploy_mock_erc20(to: ContractAddress, amount: u256) -> IERC20Dispatcher {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append('MOCK');
    calldata.append('MCK');
    calldata.append(to.into());
    // u256 amount as (low, high)
    calldata.append(amount.low.into());
    calldata.append(amount.high.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address: addr }
}

fn deploy_mock_registry() -> ISessionRegistryDispatcher {
    let contract = declare("MockSessionRegistry").unwrap().contract_class();
    let (addr, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    ISessionRegistryDispatcher { contract_address: addr }
}


fn deploy_marketplace(
    registry: ContractAddress,
    token: ContractAddress,
    timeout: u64,
) -> IMarketplaceDispatcher {
    let contract = declare("SessionsMarketplace").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    calldata.append(token.into());
    calldata.append(timeout.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IMarketplaceDispatcher { contract_address: addr }
}

fn register_session(
    registry: ISessionRegistryDispatcher,
    session_id: felt252,
    simulation_id: felt252,
    root: felt252,
    author: ContractAddress,
    score: u32,
) {
    let m = SessionMetadata { session_id, root_hash: root, simulation_id, author, score };
    registry.register_session(m);
}

#[test]
fn test_open_purchase_and_refund_flow() {
    // Setup: buyer has funds
    let price: u256 = 1000;
    let token = deploy_mock_erc20(BUYER(), price * 2);
    let registry = deploy_mock_registry();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(registry.contract_address, token.contract_address, timeout);

    // Register a session owned by SELLER
    let session_id = 'session_1';
    let sim_id = 'sim_1';
    let root = 'root_1';
    register_session(registry, session_id, sim_id, root, SELLER(), 123);

    // Create listing as SELLER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let listing_id = marketplace.create_listing(session_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Approve marketplace to spend buyer's tokens
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);

    // Open purchase as BUYER (set timestamp first)
    let challenge_felt = 1234567890; // felt
    let challenge_key: u64 = 1234567890_u64;
    start_cheat_block_timestamp(marketplace.contract_address, 1000);
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.open_purchase(listing_id, challenge_felt, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Listing remains Open; order is tracked per (session_id, buyer)
    let st = marketplace.get_listing_status(listing_id);
    assert!(st == ListingStatus::Open, "Listing stays open with per-buyer order");

    // Check order view
    let (challenge_r, amount_r) = marketplace.get_order_info('session_1', BUYER());
    assert!(challenge_r == challenge_felt, "Challenge stored in order");
    assert!(amount_r == price, "Amount stored in order");
    let status_r = marketplace.get_order_status('session_1', BUYER());
    assert!(status_r == OrderStatus::Open, "Order should be open");

    // Immediate refund should fail (Not expired)
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    // Expect panic if not expired yet
    // Note: Forge does not support inline should_panic blocks; this is covered in a separate test.
    stop_cheat_caller_address(marketplace.contract_address);

    // Advance time and refund: set to >= opened_at + timeout
    start_cheat_block_timestamp(marketplace.contract_address, 1011);

    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.refund_purchase(listing_id);
    stop_cheat_caller_address(marketplace.contract_address);
    stop_cheat_block_timestamp(marketplace.contract_address);

    // Listing should be Open again
    let st2 = marketplace.get_listing_status(listing_id);
    assert!(st2 == ListingStatus::Open, "Should be open after refund");
}

#[test]
fn test_successful_sale_releases_escrow() {
    let price: u256 = 500;
    let token = deploy_mock_erc20(BUYER(), price);
    let registry = deploy_mock_registry();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(registry.contract_address, token.contract_address, timeout);

    // Register session owned by SELLER and list
    let session_id = 'session_2';
    let sim_id = 'sim_2';
    let root = 'root_2';
    register_session(registry, session_id, sim_id, root, SELLER(), 100);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let listing_id = marketplace.create_listing(session_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Approve and open purchase as BUYER
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    let challenge_felt2 = 2222222222;
    let challenge_key2: u64 = 2222222222_u64;
    marketplace.open_purchase(listing_id, challenge_felt2, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Seller submits proof and completes sale
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let proof: Array<felt252> = array![1, 2, 3];
    marketplace.settle_purchase(listing_id, BUYER(), challenge_key2, proof.span());
    stop_cheat_caller_address(marketplace.contract_address);

    // Listing should be Sold
    let st = marketplace.get_listing_status(listing_id);
    assert!(st == ListingStatus::Sold, "Should be sold");
    let status2 = marketplace.get_order_status('session_2', BUYER());
    assert!(status2 == OrderStatus::Sold, "Order should be marked sold");
}

#[test]
#[should_panic(expected: ('Not expired',))]
fn test_refund_before_timeout_panics() {
    let price: u256 = 777;
    let token = deploy_mock_erc20(BUYER(), price);
    let registry = deploy_mock_registry();
    let timeout: u64 = 100;
    let marketplace = deploy_marketplace(registry.contract_address, token.contract_address, timeout);

    // Register session and create listing
    register_session(registry, 'session_refund', 'sim_r', 'root_r', SELLER(), 1);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let listing_id = marketplace.create_listing('session_refund', price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Approve and open purchase as BUYER at time t=500
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_block_timestamp(marketplace.contract_address, 500);
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    let challenge_r_felt = 3333333333;
    marketplace.open_purchase(listing_id, challenge_r_felt, price);
    // Try to refund immediately (should panic Not expired)
    marketplace.refund_purchase(listing_id);
}

#[test]
#[should_panic(expected: ('Invalid amount',))]
fn test_open_purchase_invalid_amount() {
    let price: u256 = 1000;
    let token = deploy_mock_erc20(BUYER(), price);
    let registry = deploy_mock_registry();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(registry.contract_address, token.contract_address, timeout);

    // Register session owned by SELLER and list
    register_session(registry, 'session_3', 'sim_3', 'root_3', SELLER(), 1);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let listing_id = marketplace.create_listing('session_3', price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Approve correct price but send wrong amount
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.open_purchase(listing_id, 'challenge', price - 1);
}
