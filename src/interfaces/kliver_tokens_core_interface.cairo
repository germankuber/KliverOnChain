use starknet::ContractAddress;
use super::super::kliver_tokens_core_types::{
    ClaimableAmountResult, HintPayment, SessionPayment, Simulation, TokenInfo,
    WalletMultiTokenSummary, WalletTokenSummary,
};

#[starknet::interface]
pub trait IKliverTokensCore<TContractState> {
    fn set_registry_address(ref self: TContractState, new_registry_address: ContractAddress);
    fn get_registry_address(self: @TContractState) -> ContractAddress;
    fn create_token(ref self: TContractState, release_hour: u64, release_amount: u256, special_release: u256) -> u256;
    fn get_token_info(self: @TContractState, token_id: u256) -> TokenInfo;
    fn time_until_release(self: @TContractState, token_id: u256) -> u64;
    fn register_simulation(ref self: TContractState, simulation_id: felt252, token_id: u256, expiration_timestamp: u64) -> felt252;
    fn get_simulation(self: @TContractState, simulation_id: felt252) -> Simulation;
    fn is_simulation_expired(self: @TContractState, simulation_id: felt252) -> bool;
    fn update_simulation_expiration(ref self: TContractState, simulation_id: felt252, new_expiration_timestamp: u64);
    fn add_to_whitelist(ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252);
    fn remove_from_whitelist(ref self: TContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252);
    fn is_whitelisted(self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> bool;
    fn claim(ref self: TContractState, token_id: u256, simulation_id: felt252);
    fn get_claimable_amount(self: @TContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress) -> u256;
    fn get_claimable_amounts_batch(self: @TContractState, token_id: u256, simulation_ids: Span<felt252>, wallets: Span<ContractAddress>) -> Array<ClaimableAmountResult>;
    fn get_wallet_token_summary(self: @TContractState, token_id: u256, wallet: ContractAddress, simulation_ids: Span<felt252>) -> WalletTokenSummary;
    fn get_wallet_simulations_summary(self: @TContractState, wallet: ContractAddress, simulation_ids: Span<felt252>) -> WalletMultiTokenSummary;
    fn pay_for_session(ref self: TContractState, simulation_id: felt252, session_id: felt252, amount: u256);
    fn is_session_paid(self: @TContractState, session_id: felt252) -> bool;
    fn get_session_payment(self: @TContractState, session_id: felt252) -> SessionPayment;
    fn pay_for_hint(ref self: TContractState, simulation_id: felt252, hint_id: felt252, amount: u256);
    fn is_hint_paid(self: @TContractState, hint_id: felt252) -> bool;
    fn get_hint_payment(self: @TContractState, hint_id: felt252) -> HintPayment;
    fn get_owner(self: @TContractState) -> ContractAddress;
}

