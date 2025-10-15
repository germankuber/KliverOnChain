use kliver_on_chain::interfaces::marketplace_interface::{
    IMarketplaceDispatcher, IMarketplaceDispatcherTrait,
};
use kliver_on_chain::mocks::mock_erc20::MockERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress};
use core::num::traits::Zero;

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn NON_OWNER() -> ContractAddress {
    'non_owner'.try_into().unwrap()
}

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

fn deploy_marketplace(
    pox: ContractAddress,
    registry: ContractAddress,
    token: ContractAddress,
    timeout: u64,
) -> IMarketplaceDispatcher {
    let contract = declare("SessionsMarketplace").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(pox.into());
    calldata.append(registry.into());
    calldata.append(token.into());
    calldata.append(timeout.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IMarketplaceDispatcher { contract_address: addr }
}

// ============================================================================
// Tests for set_payment_token
// ============================================================================

#[test]
fn test_set_payment_token_success() {
    let initial_token: ContractAddress = 'initial_token'.try_into().unwrap();
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - the default test caller becomes the owner
    let marketplace = deploy_marketplace(pox, registry, initial_token, timeout);

    // Verify initial token
    let current_token = marketplace.get_payment_token();
    assert(current_token == initial_token, 'Initial token mismatch');

    // Deploy new token
    let new_token = deploy_mock_erc20(OWNER(), 1000000);

    // Set new payment token (default test caller is the owner)
    marketplace.set_payment_token(new_token.contract_address);

    // Verify token was updated
    let updated_token = marketplace.get_payment_token();
    assert(updated_token == new_token.contract_address, 'Token not updated');
}

#[test]
#[should_panic(expected: ('Only owner can set token',))]
fn test_set_payment_token_only_owner() {
    let initial_token: ContractAddress = 'initial_token'.try_into().unwrap();
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(pox, registry, initial_token, timeout);

    let new_token = deploy_mock_erc20(OWNER(), 1000000);

    // Try to set as non-owner (should panic)
    start_cheat_caller_address(marketplace.contract_address, NON_OWNER());
    marketplace.set_payment_token(new_token.contract_address);
}

#[test]
#[should_panic(expected: ('Invalid payment token',))]
fn test_set_payment_token_zero_address() {
    let initial_token: ContractAddress = 'initial_token'.try_into().unwrap();
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(pox, registry, initial_token, timeout);

    let zero_address: ContractAddress = Zero::zero();

    // Try to set zero address (should panic)
    marketplace.set_payment_token(zero_address);
}

// ============================================================================
// Tests for set_pox_address
// ============================================================================

#[test]
fn test_set_pox_address_success() {
    let initial_pox: ContractAddress = 'initial_pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let token: ContractAddress = 'token'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(initial_pox, registry, token, timeout);

    // Verify initial pox
    let current_pox = marketplace.get_pox_address();
    assert(current_pox == initial_pox, 'Initial pox mismatch');

    // Set new pox address
    let new_pox: ContractAddress = 'new_pox'.try_into().unwrap();
    marketplace.set_pox_address(new_pox);

    // Verify pox was updated
    let updated_pox = marketplace.get_pox_address();
    assert(updated_pox == new_pox, 'Pox not updated');
}

#[test]
#[should_panic(expected: ('Only owner can set pox',))]
fn test_set_pox_address_only_owner() {
    let initial_pox: ContractAddress = 'initial_pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let token: ContractAddress = 'token'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(initial_pox, registry, token, timeout);

    let new_pox: ContractAddress = 'new_pox'.try_into().unwrap();

    // Try to set as non-owner (should panic)
    start_cheat_caller_address(marketplace.contract_address, NON_OWNER());
    marketplace.set_pox_address(new_pox);
}

#[test]
#[should_panic(expected: ('Invalid pox address',))]
fn test_set_pox_address_zero_address() {
    let initial_pox: ContractAddress = 'initial_pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let token: ContractAddress = 'token'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(initial_pox, registry, token, timeout);

    let zero_address: ContractAddress = Zero::zero();

    // Try to set zero address (should panic)
    marketplace.set_pox_address(zero_address);
}

// ============================================================================
// Tests for set_purchase_timeout
// ============================================================================

#[test]
fn test_set_purchase_timeout_success() {
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let token: ContractAddress = 'token'.try_into().unwrap();
    let initial_timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(pox, registry, token, initial_timeout);

    // Verify initial timeout
    let current_timeout = marketplace.get_purchase_timeout();
    assert(current_timeout == initial_timeout, 'Initial timeout mismatch');

    // Set new timeout
    let new_timeout: u64 = 200;
    marketplace.set_purchase_timeout(new_timeout);

    // Verify timeout was updated
    let updated_timeout = marketplace.get_purchase_timeout();
    assert(updated_timeout == new_timeout, 'Timeout not updated');
}

#[test]
#[should_panic(expected: ('Only owner can set timeout',))]
fn test_set_purchase_timeout_only_owner() {
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let token: ContractAddress = 'token'.try_into().unwrap();
    let initial_timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(pox, registry, token, initial_timeout);

    let new_timeout: u64 = 200;

    // Try to set as non-owner (should panic)
    start_cheat_caller_address(marketplace.contract_address, NON_OWNER());
    marketplace.set_purchase_timeout(new_timeout);
}

#[test]
#[should_panic(expected: ('Timeout must be positive',))]
fn test_set_purchase_timeout_zero_value() {
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let token: ContractAddress = 'token'.try_into().unwrap();
    let initial_timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(pox, registry, token, initial_timeout);

    // Try to set zero timeout (should panic)
    marketplace.set_purchase_timeout(0);
}

// ============================================================================
// Integration tests - Multiple setters
// ============================================================================

#[test]
fn test_multiple_setters_integration() {
    let initial_pox: ContractAddress = 'initial_pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let initial_token: ContractAddress = 'initial_token'.try_into().unwrap();
    let initial_timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(initial_pox, registry, initial_token, initial_timeout);

    // Change all configurable parameters
    let new_pox: ContractAddress = 'new_pox'.try_into().unwrap();
    let new_token = deploy_mock_erc20(OWNER(), 1000000);
    let new_timeout: u64 = 300;

    marketplace.set_payment_token(new_token.contract_address);
    marketplace.set_pox_address(new_pox);
    marketplace.set_purchase_timeout(new_timeout);

    // Verify all updates
    assert(marketplace.get_payment_token() == new_token.contract_address, 'Token not updated');
    assert(marketplace.get_pox_address() == new_pox, 'Pox not updated');
    assert(marketplace.get_purchase_timeout() == new_timeout, 'Timeout not updated');
}

#[test]
fn test_set_same_values_multiple_times() {
    let token: ContractAddress = 'token'.try_into().unwrap();
    let pox: ContractAddress = 'pox'.try_into().unwrap();
    let registry: ContractAddress = 'registry'.try_into().unwrap();
    let timeout: u64 = 100;

    // Deploy marketplace - default caller is owner
    let marketplace = deploy_marketplace(pox, registry, token, timeout);

    // Set new values
    let new_pox: ContractAddress = 'new_pox'.try_into().unwrap();
    marketplace.set_pox_address(new_pox);
    
    // Set the same value again (should succeed)
    marketplace.set_pox_address(new_pox);

    // Verify pox address
    assert(marketplace.get_pox_address() == new_pox, 'Pox address mismatch');
}
