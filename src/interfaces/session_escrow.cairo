use starknet::ContractAddress;

// Session structure for escrow
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Session {
    pub session_id: felt252,
    pub simulation_id: felt252,
    pub root_hash: felt252,
    pub score: u128,
    pub price: u128,
    pub publisher: ContractAddress,
}

#[starknet::interface]
pub trait ISessionEscrow<TContractState> {
    fn publish_session(
        ref self: TContractState,
        simulation_id: felt252,
        session_id: felt252,
        root_hash: felt252,
        score: u128,
        price: u128,
    );

    fn get_sessions_by_simulation(self: @TContractState, simulation_id: felt252) -> Array<Session>;

    fn remove_session(ref self: TContractState, session_id: felt252);

    fn get_session(self: @TContractState, session_id: felt252) -> Session;

    fn session_exists(self: @TContractState, session_id: felt252) -> bool;
}

