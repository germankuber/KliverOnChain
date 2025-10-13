use kliver_on_chain::interfaces::marketplace_interface::{
    IMarketplaceDispatcher, IMarketplaceDispatcherTrait, ListingStatus, OrderStatus,
};
use kliver_on_chain::mocks::mock_erc20::MockERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use kliver_on_chain::interfaces::kliver_pox::{IKliverPoxDispatcher, IKliverPoxDispatcherTrait};
use kliver_on_chain::components::session_registry_component::SessionMetadata;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use starknet::ContractAddress;

fn SELLER() -> ContractAddress { 'seller'.try_into().unwrap() }
fn BUYER() -> ContractAddress { 'buyer'.try_into().unwrap() }
fn BUYER2() -> ContractAddress { 'buyer2'.try_into().unwrap() }

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

fn deploy_kliver_pox(registry: ContractAddress) -> IKliverPoxDispatcher {
    let contract = declare("KliverPox").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IKliverPoxDispatcher { contract_address: addr }
}

fn deploy_mock_verifier() -> ContractAddress {
    let contract = declare("MockVerifier").unwrap().contract_class();
    let (addr, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    addr
}

fn deploy_marketplace(
    pox: ContractAddress,
    verifier: ContractAddress,
    token: ContractAddress,
    timeout: u64,
) -> IMarketplaceDispatcher {
    let contract = declare("SessionsMarketplace").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(pox.into());
    calldata.append(verifier.into());
    calldata.append(token.into());
    calldata.append(timeout.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IMarketplaceDispatcher { contract_address: addr }
}

fn mint_session(pox: IKliverPoxDispatcher, registry_addr: ContractAddress, meta: SessionMetadata) {
    start_cheat_caller_address(pox.contract_address, registry_addr);
    pox.mint(meta);
    stop_cheat_caller_address(pox.contract_address);
}

#[test]
fn test_open_purchase_and_refund_flow() {
    // Setup: buyer has funds
    let price: u256 = 1000;
    let token = deploy_mock_erc20(BUYER(), price * 2);
    let registry_addr: ContractAddress = 'registry'.try_into().unwrap();
    let pox = deploy_kliver_pox(registry_addr);
    let verifier = deploy_mock_verifier();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(pox.contract_address, verifier, token.contract_address, timeout);

    // Register a session owned by SELLER
    let session_id = 'session_1';
    let sim_id = 'sim_1';
    let root = 'root_1';
    let meta = SessionMetadata { session_id, root_hash: root, simulation_id: sim_id, author: SELLER(), score: 123_u32 };
    mint_session(pox, registry_addr, meta);
    let token_meta = pox.get_metadata_by_session(session_id);
    let token_id = token_meta.token_id;

    // Create listing as SELLER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let listing_id = marketplace.create_listing(token_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Approve marketplace to spend buyer's tokens
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);

    // Open purchase as BUYER (set timestamp first)
    let challenge_felt = 1234567890; // felt
    let _challenge_key: u64 = 1234567890_u64;
    start_cheat_block_timestamp(marketplace.contract_address, 1000);
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.open_purchase(listing_id, challenge_felt, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Another buyer can open a parallel order against the same listing
    // Fund BUYER2 by transferring from BUYER
    start_cheat_caller_address(token.contract_address, BUYER());
    let _oktf = token.transfer(BUYER2(), price);
    stop_cheat_caller_address(token.contract_address);
    start_cheat_caller_address(token.contract_address, BUYER2());
    let _ok2 = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);
    start_cheat_caller_address(marketplace.contract_address, BUYER2());
    marketplace.open_purchase(listing_id, 9999999999, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Listing remains Open; orders are tracked per (listing_id, buyer)
    let st = marketplace.get_listing_status(listing_id);
    assert!(st == ListingStatus::Open);

    // Check order view
    let (challenge_r, amount_r) = marketplace.get_order_info('session_1', BUYER());
    assert!(challenge_r == challenge_felt);
    assert!(amount_r == price);
    let status_r = marketplace.get_order_status('session_1', BUYER());
    assert!(status_r == OrderStatus::Open);

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
    assert!(st2 == ListingStatus::Open);
}

#[test]
fn test_successful_sale_releases_escrow() {
    let price: u256 = 500;
    // Fund BUYER with enough tokens to open an order and also fund BUYER2
    let token = deploy_mock_erc20(BUYER(), price * 2);
    let registry_addr: ContractAddress = 'registry'.try_into().unwrap();
    let pox = deploy_kliver_pox(registry_addr);
    let verifier = deploy_mock_verifier();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(pox.contract_address, verifier, token.contract_address, timeout);

    // Register session owned by SELLER and list
    let session_id = 'session_2';
    let sim_id = 'sim_2';
    let root = 'root_2';
    let meta2 = SessionMetadata { session_id, root_hash: root, simulation_id: sim_id, author: SELLER(), score: 100_u32 };
    mint_session(pox, registry_addr, meta2);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let token_id2 = pox.get_metadata_by_session(session_id).token_id;
    let listing_id = marketplace.create_listing(token_id2, price);
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

    // A second buyer opens a competing order
    // Fund BUYER2 before approval
    start_cheat_caller_address(token.contract_address, BUYER());
    let _oktf2 = token.transfer(BUYER2(), price);
    stop_cheat_caller_address(token.contract_address);
    start_cheat_caller_address(token.contract_address, BUYER2());
    let _ok2 = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);
    start_cheat_caller_address(marketplace.contract_address, BUYER2());
    marketplace.open_purchase(listing_id, 9999999999, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Seller submits proof and completes sale for BUYER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let proof: Array<felt252> = array![1, 2, 3];
    marketplace.settle_purchase(listing_id, BUYER(), challenge_key2, proof.span());
    stop_cheat_caller_address(marketplace.contract_address);

    // Listing remains Open; order is Settled
    let st = marketplace.get_listing_status(listing_id);
    assert!(st == ListingStatus::Open);
    let status_buyer = marketplace.get_order_status('session_2', BUYER());
    assert!(status_buyer == OrderStatus::Settled);
    // Second buyer's order remains open
    let status_buyer2 = marketplace.get_order_status('session_2', BUYER2());
    assert!(status_buyer2 == OrderStatus::Open);
}

#[test]
#[should_panic(expected: ('Cannot refund yet',))]
fn test_refund_before_timeout_panics() {
    let price: u256 = 777;
    let token = deploy_mock_erc20(BUYER(), price);
    let registry_addr: ContractAddress = 'registry'.try_into().unwrap();
    let pox = deploy_kliver_pox(registry_addr);
    let verifier = deploy_mock_verifier();
    let timeout: u64 = 100;
    let marketplace = deploy_marketplace(pox.contract_address, verifier, token.contract_address, timeout);

    // Register session and create listing
    let meta3 = SessionMetadata { session_id: 'session_refund', root_hash: 'root_r', simulation_id: 'sim_r', author: SELLER(), score: 1_u32 };
    mint_session(pox, registry_addr, meta3);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let token_id3 = pox.get_metadata_by_session('session_refund').token_id;
    let listing_id = marketplace.create_listing(token_id3, price);
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
    let registry_addr: ContractAddress = 'registry'.try_into().unwrap();
    let pox = deploy_kliver_pox(registry_addr);
    let verifier = deploy_mock_verifier();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(pox.contract_address, verifier, token.contract_address, timeout);

    // Register session owned by SELLER and list
    let meta4 = SessionMetadata { session_id: 'session_3', root_hash: 'root_3', simulation_id: 'sim_3', author: SELLER(), score: 1_u32 };
    mint_session(pox, registry_addr, meta4);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let token_id4 = pox.get_metadata_by_session('session_3').token_id;
    let listing_id = marketplace.create_listing(token_id4, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Approve correct price but send wrong amount
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(marketplace.contract_address, BUYER());
    let one: u256 = u256 { low: 1, high: 0 };
    let wrong_amount: u256 = price - one;
    marketplace.open_purchase(listing_id, 'challenge', wrong_amount);
}

#[test]
fn test_refund_immediate_after_close() {
    // Setup
    let price: u256 = 999;
    let token = deploy_mock_erc20(BUYER(), price);
    let registry_addr: ContractAddress = 'registry'.try_into().unwrap();
    let pox = deploy_kliver_pox(registry_addr);
    let verifier = deploy_mock_verifier();
    let timeout: u64 = 100;
    let marketplace = deploy_marketplace(pox.contract_address, verifier, token.contract_address, timeout);

    // Mint session and list by SELLER
    let meta = SessionMetadata { session_id: 'session_close_refund', root_hash: 'root_r', simulation_id: 'sim_r', author: SELLER(), score: 1_u32 };
    mint_session(pox, registry_addr, meta);
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    let token_id = pox.get_metadata_by_session('session_close_refund').token_id;
    let listing_id = marketplace.create_listing(token_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Buyer approves and opens purchase
    start_cheat_caller_address(token.contract_address, BUYER());
    let _ok = token.approve(marketplace.contract_address, price);
    stop_cheat_caller_address(token.contract_address);
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.open_purchase(listing_id, 'challenge_refund', price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Seller closes listing
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.close_listing(listing_id);
    stop_cheat_caller_address(marketplace.contract_address);

    // Buyer can refund immediately (no timeout needed)
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.refund_purchase(listing_id);
    stop_cheat_caller_address(marketplace.contract_address);

    // Check statuses and balance
    let st = marketplace.get_listing_status(listing_id);
    assert!(st == ListingStatus::Closed);
    let order_status = marketplace.get_order_status_by_listing(listing_id, BUYER());
    assert!(order_status == OrderStatus::Refunded);
    let bal = token.balance_of(BUYER());
    assert!(bal == price);
}
