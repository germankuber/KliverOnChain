use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Simulation Registry Interface
#[starknet::interface]
pub trait ISimulationRegistry<TContractState> {
    /// Register a simulation with its ID and hash (only owner)
    fn register_simulation(ref self: TContractState, simulation_id: felt252, simulation_hash: felt252);
    /// Verify if a simulation ID matches its expected hash
    fn verify_simulation(self: @TContractState, simulation_id: felt252, simulation_hash: felt252) -> VerificationResult;
    /// Verify multiple simulations at once
    fn batch_verify_simulations(self: @TContractState, simulations: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a simulation ID
    fn get_simulation_hash(self: @TContractState, simulation_id: felt252) -> felt252;
}

/// Simulation Registered Event
#[derive(Drop, starknet::Event)]
pub struct SimulationRegistered {
    #[key]
    pub simulation_id: felt252,
    pub simulation_hash: felt252,
    pub registered_by: ContractAddress,
}