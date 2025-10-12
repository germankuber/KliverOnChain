use super::super::session_escrow::Session;

#[starknet::interface]
pub trait ISessionEscrow<TContractState> {
    fn publish_session(ref self: TContractState, simulation_id: felt252, session_id: felt252, root_hash: felt252, score: u128, price: u128);
    fn get_sessions_by_simulation(self: @TContractState, simulation_id: felt252) -> Array<Session>;
    fn remove_session(ref self: TContractState, session_id: felt252);
    fn get_session(self: @TContractState, session_id: felt252) -> Session;
    fn session_exists(self: @TContractState, session_id: felt252) -> bool;
}

