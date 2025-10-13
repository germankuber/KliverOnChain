#[starknet::interface]
pub trait ITokenCore<TContractState> {
    fn register_simulation(
        ref self: TContractState, simulation_id: felt252, token_id: u256, expiration_timestamp: u64,
    ) -> felt252;
}

