pub use kliver_on_chain::components::simulation_registry_component::{
    SimulationMetadata, SimulationWithTokenMetadata,
};
use crate::types::VerificationResult;

#[starknet::interface]
pub trait ISimulationRegistry<TContractState> {
    fn register_simulation(ref self: TContractState, metadata: SimulationMetadata);
    fn register_simulation_with_token(ref self: TContractState, metadata: SimulationWithTokenMetadata);
    fn verify_simulation(self: @TContractState, simulation_id: felt252, simulation_hash: felt252) -> VerificationResult;
    fn batch_verify_simulations(self: @TContractState, simulations: Array<SimulationMetadata>) -> Array<(felt252, VerificationResult)>;
    fn get_simulation_hash(self: @TContractState, simulation_id: felt252) -> felt252;
    fn get_simulation_info(self: @TContractState, simulation_id: felt252) -> SimulationMetadata;
    fn get_simulation_with_token_info(self: @TContractState, simulation_id: felt252) -> SimulationWithTokenMetadata;
    fn simulation_exists(self: @TContractState, simulation_id: felt252) -> bool;
}

