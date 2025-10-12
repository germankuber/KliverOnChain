use starknet::ContractAddress;

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum ListingStatus {
    Available,
    Sold,
    Cancelled,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct SessionListing {
    pub session_id: felt252,
    pub simulation_id: felt252,
    pub root_hash: felt252,
    pub price: u128,
    pub seller: ContractAddress,
    pub buyer: ContractAddress,
    pub status: ListingStatus,
}

#[starknet::interface]
pub trait ISessionMarketplace<TContractState> {
    fn publish_session(ref self: TContractState, simulation_id: felt252, session_id: felt252, price: u128);
    fn purchase_session(ref self: TContractState, session_id: felt252);
    fn get_sessions_by_simulation(self: @TContractState, simulation_id: felt252) -> Array<SessionListing>;
    fn remove_session(ref self: TContractState, session_id: felt252);
    fn get_session(self: @TContractState, session_id: felt252) -> SessionListing;
    fn session_exists(self: @TContractState, session_id: felt252) -> bool;
    fn is_available(self: @TContractState, session_id: felt252) -> bool;
}
