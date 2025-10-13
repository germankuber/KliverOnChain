use starknet::ContractAddress;
use kliver_on_chain::components::session_registry_component::SessionMetadata;

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct KlivePoxMetadata {
    pub token_id: u256,
    pub session_id: felt252,
    pub root_hash: felt252,
    pub simulation_id: felt252,
    pub author: ContractAddress,
    pub score: u32,
}

#[starknet::interface]
pub trait IKlivePox<TContractState> {
    // Mint (only registry can call)
    fn mint(ref self: TContractState, metadata: SessionMetadata);

    // Public getters
    fn balance_of(self: @TContractState, user: ContractAddress) -> u256;
    fn owner_of_token(self: @TContractState, token_id: u256) -> ContractAddress;
    fn owner_of_simulation(self: @TContractState, simulation_id: felt252) -> ContractAddress;

    // Full metadata getters
    fn get_metadata_by_token(self: @TContractState, token_id: u256) -> KlivePoxMetadata;
    fn get_metadata_by_simulation(self: @TContractState, simulation_id: felt252) -> KlivePoxMetadata;
}
