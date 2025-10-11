pub use kliver_on_chain::components::simulation_registry_component::{
    SimulationMetadata, SimulationWithTokenMetadata,
};
use crate::types::VerificationResult;

/// Simulation Registry Interface
#[starknet::interface]
pub trait ISimulationRegistry<TContractState> {
    /// Register a simulation with its metadata (only owner) - Does not call token core
    fn register_simulation(ref self: TContractState, metadata: SimulationMetadata);
    /// Register a simulation with its metadata AND register it in the token core (only owner)
    fn register_simulation_with_token(
        ref self: TContractState, metadata: SimulationWithTokenMetadata,
    );
    /// Verify if a simulation ID matches its expected hash
    fn verify_simulation(
        self: @TContractState, simulation_id: felt252, simulation_hash: felt252,
    ) -> VerificationResult;
    /// Verify multiple simulations at once
    fn batch_verify_simulations(
        self: @TContractState, simulations: Array<SimulationMetadata>,
    ) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a simulation ID
    fn get_simulation_hash(self: @TContractState, simulation_id: felt252) -> felt252;
    /// Get complete simulation information (without token data)
    fn get_simulation_info(self: @TContractState, simulation_id: felt252) -> SimulationMetadata;
    /// Get complete simulation information including token data
    fn get_simulation_with_token_info(
        self: @TContractState, simulation_id: felt252,
    ) -> SimulationWithTokenMetadata;
    /// Check if a simulation exists
    fn simulation_exists(self: @TContractState, simulation_id: felt252) -> bool;
}
