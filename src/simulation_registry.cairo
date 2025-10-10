use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Simulation metadata for registration
#[derive(Drop, Serde, Copy)]
pub struct SimulationMetadata {
    pub simulation_id: felt252,
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
    pub simulation_hash: felt252,
    pub token_id: u256,
    pub expiration_timestamp: u64,
}


/// Simulation Registry Interface
#[starknet::interface]
pub trait ISimulationRegistry<TContractState> {
    /// Register a simulation with its metadata (only owner) - Does not call token core
    fn register_simulation(ref self: TContractState, metadata: SimulationMetadata);
    /// Register a simulation with its metadata AND register it in the token core (only owner)
    fn register_simulation_with_token(ref self: TContractState, metadata: SimulationMetadata);
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
    /// Get complete simulation information
    fn get_simulation_info(self: @TContractState, simulation_id: felt252) -> SimulationMetadata;
    /// Check if a simulation exists
    fn simulation_exists(self: @TContractState, simulation_id: felt252) -> bool;
}

/// Simulation Registered Event
#[derive(Drop, starknet::Event)]
pub struct SimulationRegistered {
    #[key]
    pub simulation_id: felt252,
    pub simulation_hash: felt252,
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
}
