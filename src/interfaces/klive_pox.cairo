use starknet::ContractAddress;

#[starknet::interface]
pub trait IKlivePox<TContractState> {
    // Mint (only registry can call)
    fn mint(
        ref self: TContractState,
        simulation_id: felt252,
        author: ContractAddress,
        character_id: felt252,
        scenario_id: felt252,
        simulation_hash: felt252,
    );

    // Public getters
    fn balance_of(self: @TContractState, user: ContractAddress) -> u256;
    fn owner_of_token(self: @TContractState, token_id: u256) -> ContractAddress;
    fn owner_of_simulation(self: @TContractState, simulation_id: felt252) -> ContractAddress;
}

